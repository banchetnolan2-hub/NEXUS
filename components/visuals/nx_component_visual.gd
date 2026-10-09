class_name NxComponentVisual
extends Node3D
## 3D representation of one machine, built from primitives.
##
## Purely visual: it reads a SimComponent every frame (apply_state) to spin
## rotors, fill tanks and colour the status light. Build with
## NxComponentVisual.create(type); the same model serves for the placement
## ghost (set_ghost) and the library thumbnails.

const P := preload("res://ui/theme/nx_palette.gd")
## Visual spin is slowed down so real speeds stay readable on screen.
const SPIN_SCALE := 0.08

var type: StringName
var size := Vector2i.ONE
## Local bounds used for picking (computed after building).
var local_bounds := AABB()

var _rotors: Array[Dictionary] = []   # { node, axis: Vector3, source: "rpm"|"flow"|"output" }
var _level_node: Node3D
var _level_height := 1.0
var _bulb_mat: StandardMaterial3D
var _status_mat: StandardMaterial3D
var _lever: Node3D
var _ghost := false


static func create(component_type: StringName) -> NxComponentVisual:
	var v := NxComponentVisual.new()
	v.type = component_type
	v.size = NxRegistry.definition(component_type).size
	v.name = String(component_type)
	v._build()
	v._compute_bounds()
	return v


# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------

func apply_state(c: SimComponent, delta: float) -> void:
	for r in _rotors:
		var speed := 0.0
		match r.source:
			"rpm":
				speed = float(c.state.get("rpm", 0.0)) * TAU / 60.0 * SPIN_SCALE
			"flow":
				speed = float(c.state.get("flow", 0.0)) * 0.6
			"output":
				speed = float(c.state.get("output_kw", 0.0)) * 0.5
		if c.type == &"transmission" and r.get("output", false):
			speed *= float(c.param("ratio"))
		r.node.rotate_object_local(r.axis, speed * delta)
	if _level_node:
		var lvl := clampf(float(c.state.get("amount", 0.0)) / float(c.param("capacity")), 0.0, 1.0)
		_level_node.scale.y = maxf(lvl, 0.001)
		_level_node.position.y = 0.16 + _level_height * lvl * 0.5
	if _bulb_mat:
		var b: float = c.state.get("brightness", 0.0)
		_bulb_mat.emission_energy_multiplier = 0.05 + b * 4.0
		_bulb_mat.albedo_color = Color("3a3420").lerp(Color("ffe08a"), b)
	if _lever:
		var target := deg_to_rad(-35.0 if c.param("on") else 35.0)
		_lever.rotation.z = lerpf(_lever.rotation.z, target, minf(1.0, delta * 12.0))
	if _status_mat:
		var col := status_color(c.state.get("status", &"idle"))
		_status_mat.albedo_color = col
		_status_mat.emission = col


static func status_color(status: StringName) -> Color:
	match status:
		&"running":
			return P.SUCCESS
		&"warning":
			return P.WARNING
		&"error":
			return P.DANGER
		&"disabled":
			return Color("3a404a")
	return Color("6b7585")


## Turns the model into a translucent placement preview.
func set_ghost(valid: bool) -> void:
	_ghost = true
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var col := P.ACCENT if valid else P.DANGER
	mat.albedo_color = Color(col, 0.38)
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.no_depth_test = false
	for mi in _meshes(self):
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# -----------------------------------------------------------------------------
# Building
# -----------------------------------------------------------------------------

func _build() -> void:
	var steel := NxMaterials.steel()
	var accent := NxMaterials.painted(P.domain_color(NxRegistry.definition(type).category))
	var sx := size.x * 0.92
	var sz := size.y * 0.92
	# Base plate with a domain-coloured edge on the front.
	_box(Vector3(sx, 0.1, sz), Vector3(0, 0.05, 0), NxMaterials.base_plate())
	_box(Vector3(sx * 0.6, 0.02, 0.05), Vector3(0, 0.1, sz * 0.5 - 0.06), accent)

	match type:
		&"generator":
			_box(Vector3(1.2, 0.8, 1.2), Vector3(-0.15, 0.5, 0), steel)
			for i in 5:
				_box(Vector3(0.04, 0.6, 1.25), Vector3(-0.65 + i * 0.25, 0.5, 0), NxMaterials.machined())
			_cylinder(0.32, 0.5, Vector3(0.7, 0.5, 0), accent, Vector3(0, 0, 90))
			var fly := _pivot(Vector3(0.98, 0.5, 0))
			_rotors.append({ "node": fly, "axis": Vector3.RIGHT, "source": "output" })
			_cylinder(0.26, 0.06, Vector3.ZERO, NxMaterials.machined(), Vector3(0, 0, 90), fly)
			_box(Vector3(0.06, 0.4, 0.06), Vector3.ZERO, steel, fly)
			_box(Vector3(0.2, 0.25, 0.2), Vector3(0.0, 0.95, 0.4), NxMaterials.painted(P.ENERGY))
		&"motor":
			_box(Vector3(1.1, 0.12, 0.5), Vector3(-0.1, 0.16, 0), steel)
			_cylinder(0.3, 1.1, Vector3(-0.15, 0.45, 0), steel, Vector3(0, 0, 90))
			for i in 6:
				_cylinder(0.33, 0.04, Vector3(-0.55 + i * 0.16, 0.45, 0), NxMaterials.machined(), Vector3(0, 0, 90))
			_cylinder(0.31, 0.1, Vector3(0.45, 0.45, 0), accent, Vector3(0, 0, 90))
			var shaft := _pivot(Vector3(0.75, 0.45, 0))
			_rotors.append({ "node": shaft, "axis": Vector3.RIGHT, "source": "rpm" })
			_cylinder(0.06, 0.5, Vector3.ZERO, NxMaterials.machined(), Vector3(0, 0, 90), shaft)
			_box(Vector3(0.04, 0.2, 0.04), Vector3(0.1, 0, 0), accent, shaft)
			_box(Vector3(0.3, 0.18, 0.25), Vector3(-0.45, 0.82, 0), steel)
		&"transmission":
			_box(Vector3(0.62, 0.55, 0.62), Vector3(0, 0.42, 0), steel)
			var in_shaft := _pivot(Vector3(-0.38, 0.45, 0))
			_cylinder(0.06, 0.28, Vector3.ZERO, NxMaterials.machined(), Vector3(0, 0, 90), in_shaft)
			_box(Vector3(0.04, 0.16, 0.04), Vector3.ZERO, accent, in_shaft)
			_rotors.append({ "node": in_shaft, "axis": Vector3.RIGHT, "source": "rpm" })
			var out_shaft := _pivot(Vector3(0.38, 0.45, 0))
			_cylinder(0.06, 0.28, Vector3.ZERO, NxMaterials.machined(), Vector3(0, 0, 90), out_shaft)
			_box(Vector3(0.04, 0.16, 0.04), Vector3.ZERO, accent, out_shaft)
			_rotors.append({ "node": out_shaft, "axis": Vector3.RIGHT, "source": "rpm", "output": true })
			var gear := _pivot(Vector3(0, 0.74, 0))
			var gm := MeshInstance3D.new()
			gm.mesh = NxGearMesh.build(14, 0.22, 0.06)
			gm.material_override = NxMaterials.painted(P.MECHANICAL)
			gear.add_child(gm)
			_rotors.append({ "node": gear, "axis": Vector3.UP, "source": "rpm" })
		&"fan":
			_box(Vector3(0.3, 0.3, 0.5), Vector3(-0.25, 0.25, 0), steel)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.34
			ring.outer_radius = 0.4
			var ring_node := _add(ring, Vector3(0.05, 0.55, 0), steel)
			ring_node.rotation_degrees = Vector3(0, 0, 90)
			var hub := _pivot(Vector3(0.05, 0.55, 0))
			_rotors.append({ "node": hub, "axis": Vector3.RIGHT, "source": "rpm" })
			_cylinder(0.08, 0.14, Vector3.ZERO, accent, Vector3(0, 0, 90), hub)
			for i in 4:
				var blade := _box(Vector3(0.03, 0.3, 0.09), Vector3.ZERO, NxMaterials.machined(), hub)
				blade.rotation.x = i * PI / 2.0
				blade.position = Vector3(0, 0.17, 0).rotated(Vector3.RIGHT, i * PI / 2.0)
		&"tank":
			_level_height = 1.25
			var shell := _cylinder(0.82, 1.45, Vector3(0, 0.83, 0), NxMaterials.glass())
			shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_cylinder(0.86, 0.1, Vector3(0, 0.15, 0), steel)
			_cylinder(0.86, 0.1, Vector3(0, 1.55, 0), steel)
			_cylinder(0.3, 0.12, Vector3(0, 1.65, 0), NxMaterials.machined())
			for a in 4:
				var post := Vector3(0.8, 0.83, 0).rotated(Vector3.UP, a * PI / 2.0 + PI / 4.0)
				_cylinder(0.04, 1.45, post, steel)
			_level_node = _cylinder(0.76, _level_height, Vector3(0, 0.8, 0), NxMaterials.fluid())
			_cylinder(0.08, 0.3, Vector3(0, 1.4, 0.9), accent, Vector3(90, 0, 0))
		&"pump":
			_cylinder(0.28, 0.35, Vector3(0, 0.3, 0), steel)
			_cylinder(0.08, 0.3, Vector3(-0.32, 0.3, 0), NxMaterials.painted(P.FLUID), Vector3(0, 0, 90))
			_cylinder(0.08, 0.3, Vector3(0.32, 0.3, 0), NxMaterials.painted(P.FLUID), Vector3(0, 0, 90))
			_cylinder(0.18, 0.3, Vector3(0, 0.62, 0), accent)
			var imp := _pivot(Vector3(0, 0.79, 0))
			_rotors.append({ "node": imp, "axis": Vector3.UP, "source": "flow" })
			for i in 3:
				var vane := _box(Vector3(0.3, 0.04, 0.05), Vector3.ZERO, NxMaterials.machined(), imp)
				vane.rotation.y = i * PI / 3.0
		&"level_sensor":
			_cylinder(0.05, 0.6, Vector3(0, 0.4, -0.15), steel)
			_box(Vector3(0.42, 0.3, 0.12), Vector3(0, 0.78, -0.1), steel)
			_box(Vector3(0.3, 0.16, 0.02), Vector3(0, 0.8, -0.03), NxMaterials.glow(P.LOGIC, 1.2))
		&"switch":
			_box(Vector3(0.5, 0.3, 0.4), Vector3(0, 0.25, 0), steel)
			_box(Vector3(0.36, 0.02, 0.26), Vector3(0, 0.41, 0), accent)
			_lever = _pivot(Vector3(0, 0.42, 0))
			_cylinder(0.025, 0.3, Vector3(0, 0.15, 0), NxMaterials.machined(), Vector3.ZERO, _lever)
			var knob := SphereMesh.new()
			knob.radius = 0.05
			knob.height = 0.1
			_add(knob, Vector3(0, 0.3, 0), NxMaterials.painted(P.DANGER), _lever)
		&"logic_gate":
			_box(Vector3(0.6, 0.16, 0.5), Vector3(0, 0.18, 0), NxMaterials.base_plate())
			_box(Vector3(0.44, 0.06, 0.36), Vector3(0, 0.29, 0), accent)
			for side in [-1, 1]:
				for i in 3:
					_box(Vector3(0.05, 0.08, 0.04), Vector3(-0.15 + i * 0.15, 0.14, side * 0.27), NxMaterials.machined())
		&"lamp":
			_cylinder(0.12, 0.12, Vector3(0, 0.16, 0), steel)
			_cylinder(0.04, 0.5, Vector3(0, 0.45, 0), steel)
			_bulb_mat = StandardMaterial3D.new()
			_bulb_mat.emission_enabled = true
			_bulb_mat.emission = Color("ffd479")
			_bulb_mat.albedo_color = Color("3a3420")
			_bulb_mat.roughness = 0.3
			var bulb := SphereMesh.new()
			bulb.radius = 0.16
			bulb.height = 0.32
			_add(bulb, Vector3(0, 0.82, 0), _bulb_mat)
			_cylinder(0.1, 0.08, Vector3(0, 0.68, 0), NxMaterials.machined())

	# Status light on a corner of the base.
	_status_mat = StandardMaterial3D.new()
	_status_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_status_mat.emission_enabled = true
	_status_mat.emission_energy_multiplier = 1.6
	_status_mat.albedo_color = status_color(&"idle")
	var dot := SphereMesh.new()
	dot.radius = 0.045
	dot.height = 0.09
	_add(dot, Vector3(sx * 0.5 - 0.1, 0.14, sz * 0.5 - 0.1), _status_mat)


func _compute_bounds() -> void:
	var first := true
	for mi in _meshes(self):
		var box: AABB = _local_transform_of(mi) * mi.get_aabb()
		local_bounds = box if first else local_bounds.merge(box)
		first = false
	# Never thinner than the footprint, so small parts stay easy to click.
	var foot := AABB(Vector3(-size.x * 0.5, 0, -size.y * 0.5), Vector3(size.x, 0.3, size.y))
	local_bounds = local_bounds.merge(foot)


func _local_transform_of(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			result.append(child)
		result.append_array(_meshes(child))
	return result


func _pivot(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	return n


func _add(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	(parent if parent else self).add_child(mi)
	return mi


func _box(box_size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = box_size
	return _add(m, pos, mat, parent)


func _cylinder(radius: float, height: float, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 32
	m.rings = 1
	var mi := _add(m, pos, mat, parent)
	mi.rotation_degrees = rot_deg
	return mi
