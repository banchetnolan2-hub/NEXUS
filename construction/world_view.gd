class_name WorldView
extends Node3D
## Visual mirror of a SimWorld: machine models, connection tubes, ports,
## selection frames and the placement ghost. Holds no game state itself.

const P := preload("res://ui/theme/nx_palette.gd")

enum PortsMode { NONE, SELECTED, ALL }

const LINK_RADIUS := {
	NxPort.POWER: 0.035, NxPort.SHAFT: 0.055, NxPort.FLUID: 0.075,
	NxPort.SIGNAL: 0.028, NxPort.PROBE: 0.025,
}

var world: SimWorld
var selected_id := -1
var hovered_id := -1
var ports_mode: int = PortsMode.SELECTED

var _visuals: Dictionary = {}        # id -> NxComponentVisual
var _links: Dictionary = {}          # link id -> { node: MeshInstance3D, mat, type }
var _ports: Dictionary = {}          # "id:port" -> MeshInstance3D
var _hover_port_key := ""
var _ghost: NxComponentVisual
var _ghost_type: StringName
var _ghost_valid := true
var _ghost_cells: MeshInstance3D
var _pending_link: MeshInstance3D
var _selection_frame: Node3D
var _hover_frame: Node3D
var _links_root: Node3D
var _time := 0.0


func _ready() -> void:
	_links_root = Node3D.new()
	_links_root.name = "Links"
	add_child(_links_root)
	_selection_frame = Node3D.new()
	add_child(_selection_frame)
	_hover_frame = Node3D.new()
	add_child(_hover_frame)
	_build_bounds()


func set_world(w: SimWorld) -> void:
	if world and world.structure_changed.is_connected(sync):
		world.structure_changed.disconnect(sync)
	world = w
	world.structure_changed.connect(sync)
	sync()


func _process(delta: float) -> void:
	if world == null:
		return
	_time += delta
	for id in _visuals:
		var c: SimComponent = world.components.get(id)
		if c:
			_visuals[id].apply_state(c, delta)
	for link_id in _links:
		_update_link_activity(_links[link_id])


# -----------------------------------------------------------------------------
# Synchronisation
# -----------------------------------------------------------------------------

## Rebuilds visuals to match the world structure (cheap for dozens of machines).
func sync() -> void:
	for id in _visuals.keys():
		if not world.components.has(id):
			_visuals[id].queue_free()
			_visuals.erase(id)
	for id in world.components:
		var c: SimComponent = world.components[id]
		var v: NxComponentVisual = _visuals.get(id)
		if v == null:
			v = NxComponentVisual.create(c.type)
			add_child(v)
			_visuals[id] = v
		v.position = SimWorld.footprint_center(c.type, c.cell, c.rot)
		v.rotation.y = -c.rot * PI * 0.5
	_rebuild_links()
	_rebuild_ports()
	if not world.components.has(selected_id):
		selected_id = -1
	if not world.components.has(hovered_id):
		hovered_id = -1
	_update_frames()


func _rebuild_links() -> void:
	for link_id in _links:
		_links[link_id].node.queue_free()
	_links.clear()
	for l in world.connections:
		var a: SimComponent = world.components.get(l.from.c)
		var b: SimComponent = world.components.get(l.to.c)
		if a == null or b == null:
			continue
		var p1 := world.port_position(a, l.from.p)
		var p2 := world.port_position(b, l.to.p)
		var mat := StandardMaterial3D.new()
		var col := NxPort.color(l.type)
		mat.albedo_color = col.darkened(0.25)
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.2
		mat.roughness = 0.4
		mat.metallic = 0.3 if l.type == NxPort.SHAFT else 0.0
		var mi := MeshInstance3D.new()
		mi.mesh = tube_mesh(curve_points(p1, p2, l.type), LINK_RADIUS.get(l.type, 0.04))
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_links_root.add_child(mi)
		_links[l.id] = { "node": mi, "mat": mat, "link": l }


func _update_link_activity(entry: Dictionary) -> void:
	var l: Dictionary = entry.link
	var a: SimComponent = world.components.get(l.from.c)
	var b: SimComponent = world.components.get(l.to.c)
	if a == null or b == null:
		return
	var active := false
	match l.type:
		NxPort.POWER:
			active = float(a.state.get("network_demand_kw", 0.0)) > 0.0 \
				and float(a.state.get("network_supply_kw", 0.0)) > 0.0
		NxPort.SHAFT:
			active = absf(float(a.state.get("rpm", 0.0))) > 0.5
		NxPort.FLUID:
			active = float(a.state.get("flow", 0.0)) > 0.0 or float(b.state.get("flow", 0.0)) > 0.0
		NxPort.SIGNAL:
			active = a.behavior.signal_out(a, l.from.p)
		NxPort.PROBE:
			active = true
	var mat: StandardMaterial3D = entry.mat
	var goal := 0.15
	if active:
		goal = 1.1 + 0.5 * sin(_time * 5.0 + float(l.id))
	mat.emission_energy_multiplier = goal


## Cable path between two ports: a lifted Bézier curve.
static func curve_points(p1: Vector3, p2: Vector3, type: StringName) -> PackedVector3Array:
	var dist := p1.distance_to(p2)
	var lift := 0.25 + dist * 0.12 if type != NxPort.FLUID else 0.1 + dist * 0.05
	if type == NxPort.SHAFT:
		lift = 0.05
	var c1 := p1 + Vector3(0, lift, 0)
	var c2 := p2 + Vector3(0, lift, 0)
	var pts := PackedVector3Array()
	var steps := clampi(int(dist * 6.0), 8, 48)
	for i in steps + 1:
		var t := float(i) / steps
		var u := 1.0 - t
		pts.append(u * u * u * p1 + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * p2)
	return pts


## Tube mesh along a polyline.
static func tube_mesh(points: PackedVector3Array, radius: float, sides: int = 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for i in points.size():
		var tangent: Vector3
		if i == 0:
			tangent = points[1] - points[0]
		elif i == points.size() - 1:
			tangent = points[i] - points[i - 1]
		else:
			tangent = points[i + 1] - points[i - 1]
		tangent = tangent.normalized()
		if tangent.length() < 0.001:
			tangent = Vector3.RIGHT
		var up := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
		var side := tangent.cross(up).normalized()
		var up2 := side.cross(tangent).normalized()
		var ring := PackedVector3Array()
		var ring_n := PackedVector3Array()
		for s in sides:
			var a := TAU * s / sides
			var n := side * cos(a) + up2 * sin(a)
			ring.append(points[i] + n * radius)
			ring_n.append(n)
		rings.append(ring)
		normals.append(ring_n)
	for i in points.size() - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			var quad := [[i, s], [i + 1, s], [i + 1, s2], [i, s], [i + 1, s2], [i, s2]]
			for v in quad:
				st.set_normal(normals[v[0]][v[1]])
				st.add_vertex(rings[v[0]][v[1]])
	return st.commit()


# -----------------------------------------------------------------------------
# Ports
# -----------------------------------------------------------------------------

func _rebuild_ports() -> void:
	for key in _ports:
		_ports[key].queue_free()
	_ports.clear()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	sphere.radial_segments = 16
	sphere.rings = 8
	for id in world.components:
		var c: SimComponent = world.components[id]
		for p in c.def().ports:
			var mi := MeshInstance3D.new()
			mi.mesh = sphere
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = NxPort.color(p.type)
			mat.no_depth_test = true
			mat.render_priority = 2
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = world.port_position(c, p.id)
			add_child(mi)
			_ports["%d:%s" % [id, p.id]] = mi
	_update_ports_visibility()


func set_ports_mode(mode: int) -> void:
	ports_mode = mode
	_update_ports_visibility()


func set_hover_port(port: Dictionary) -> void:
	_hover_port_key = "" if port.is_empty() else "%d:%s" % [port.c, port.p]
	_update_ports_visibility()


func _update_ports_visibility() -> void:
	for key in _ports:
		var id := int(key.get_slice(":", 0))
		var visible_now := ports_mode == PortsMode.ALL or (ports_mode == PortsMode.SELECTED and id == selected_id)
		var mi: MeshInstance3D = _ports[key]
		mi.visible = visible_now
		mi.scale = Vector3.ONE * (1.6 if key == _hover_port_key else 1.0)


## Port closest to a screen position: { c: id, p: port id } or {}.
func pick_port(camera: Camera3D, screen_pos: Vector2, radius_px: float = 18.0) -> Dictionary:
	var best := {}
	var best_d := radius_px
	for key in _ports:
		var mi: MeshInstance3D = _ports[key]
		if not mi.visible or camera.is_position_behind(mi.global_position):
			continue
		var d := camera.unproject_position(mi.global_position).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = { "c": int(key.get_slice(":", 0)), "p": StringName(key.get_slice(":", 1)) }
	return best


# -----------------------------------------------------------------------------
# Picking, selection
# -----------------------------------------------------------------------------

## Machine hit by a ray (nearest), or -1.
func pick_component(origin: Vector3, direction: Vector3) -> int:
	var best := -1
	var best_d := INF
	for id in _visuals:
		var v: NxComponentVisual = _visuals[id]
		var inv := v.global_transform.affine_inverse()
		var hit: Variant = v.local_bounds.intersects_ray(inv * origin, inv.basis * direction)
		if hit != null:
			var d := origin.distance_to(v.global_transform * (hit as Vector3))
			if d < best_d:
				best_d = d
				best = id
	return best


func set_selected(id: int) -> void:
	selected_id = id
	_update_frames()
	_update_ports_visibility()


func set_hovered(id: int) -> void:
	if hovered_id == id:
		return
	hovered_id = id
	_update_frames()


func visual_of(id: int) -> NxComponentVisual:
	return _visuals.get(id)


func _update_frames() -> void:
	_place_frame(_selection_frame, selected_id)
	_place_frame(_hover_frame, hovered_id if hovered_id != selected_id else -1)


func _place_frame(frame: Node3D, id: int) -> void:
	var c: SimComponent = world.components.get(id) if world else null
	frame.visible = c != null
	if c == null:
		return
	var size := SimWorld.footprint_size(c.type, c.rot)
	frame.position = SimWorld.footprint_center(c.type, c.cell, c.rot)
	if frame.get_meta(&"size", Vector2i.ZERO) != size:
		for child in frame.get_children():
			child.queue_free()
		var selected := frame == _selection_frame
		var outline := _make_frame(Vector2(size), P.ACCENT if selected else Color(P.TEXT, 0.5),
			0.05 if selected else 0.025)
		remove_child(outline)
		frame.add_child(outline)
		outline.visible = true
		frame.set_meta(&"size", size)


## Rectangle outline of the given size (metres), centred on the origin.
func _make_frame(frame_size: Vector2, color: Color, width: float) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	for i in 4:
		var bar := MeshInstance3D.new()
		var m := BoxMesh.new()
		var horizontal := i < 2
		m.size = Vector3(frame_size.x + width, 0.02, width) if horizontal else Vector3(width, 0.02, frame_size.y + width)
		bar.mesh = m
		bar.material_override = mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var side_sign := -1.0 if i % 2 == 0 else 1.0
		bar.position = Vector3(0, 0.012, side_sign * frame_size.y * 0.5) if horizontal \
			else Vector3(side_sign * frame_size.x * 0.5, 0.012, 0)
		root.add_child(bar)
	root.visible = false
	add_child(root)
	return root


func _build_bounds() -> void:
	var side := float(SimWorld.GRID_HALF) * 2.0
	var frame := _make_frame(Vector2(side, side), Color(P.ACCENT, 0.45), 0.08)
	frame.visible = true
	frame.name = "BuildArea"


# -----------------------------------------------------------------------------
# Placement ghost and pending connection
# -----------------------------------------------------------------------------

func show_ghost(type: StringName, cell: Vector2i, rot: int, valid: bool) -> void:
	if _ghost == null or _ghost_type != type or _ghost_valid != valid:
		hide_ghost()
		_ghost = NxComponentVisual.create(type)
		_ghost.set_ghost(valid)
		_ghost_type = type
		_ghost_valid = valid
		add_child(_ghost)
		_ghost_cells = MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		_ghost_cells.mesh = plane
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(P.ACCENT if valid else P.DANGER, 0.22)
		_ghost_cells.material_override = mat
		add_child(_ghost_cells)
	_ghost.position = SimWorld.footprint_center(type, cell, rot)
	_ghost.rotation.y = -rot * PI * 0.5
	var size := SimWorld.footprint_size(type, rot)
	_ghost_cells.position = _ghost.position + Vector3(0, 0.015, 0)
	_ghost_cells.scale = Vector3(size.x, 1, size.y)


func hide_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if _ghost_cells:
		_ghost_cells.queue_free()
		_ghost_cells = null


func show_pending_link(from: Vector3, to: Vector3, type: StringName, valid: bool) -> void:
	if _pending_link == null:
		_pending_link = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pending_link.material_override = mat
		add_child(_pending_link)
	var col := NxPort.color(type) if valid else P.DANGER
	(_pending_link.material_override as StandardMaterial3D).albedo_color = Color(col, 0.8)
	if from.distance_to(to) > 0.05:
		_pending_link.mesh = tube_mesh(curve_points(from, to, type), 0.03, 6)


func hide_pending_link() -> void:
	if _pending_link:
		_pending_link.queue_free()
		_pending_link = null
