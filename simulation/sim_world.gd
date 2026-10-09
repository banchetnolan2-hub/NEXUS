class_name SimWorld
extends RefCounted
## The whole machine installation as pure data + a deterministic solver.
##
## No node, no rendering: the workshop scene mirrors this object visually and
## the tests drive it directly. One call to step(dt) advances the simulation by
## a fixed time step:
##   1. logic signals (several passes so chains settle)
##   2. mechanical load requested by every motor
##   3. electrical networks: supply vs demand -> satisfaction ratio
##   4. shaft speeds (target x overload factor x power ratio, x gear ratios)
##   5. per-machine update (fluid transfers, tank draw, status)

signal structure_changed
signal params_changed(component_id: int)

const GRID_HALF := 16                 ## Build area: cells -16..15 on both axes.
const CELL_SIZE := 1.0
const MAX_LOGIC_PASSES := 8

var components: Dictionary = {}       ## id -> SimComponent
var connections: Array[Dictionary] = []  ## { id, type, from: {c, p}, to: {c, p} }
var next_id := 1
var next_link_id := 1
var time := 0.0
var running := false                  ## Set by the simulation runner.
var load_warnings: PackedStringArray = []

## Totals of the last step, for the status bar.
var total_supply_kw := 0.0
var total_demand_kw := 0.0


# -----------------------------------------------------------------------------
# Placement
# -----------------------------------------------------------------------------

static func footprint_size(type: StringName, rot: int) -> Vector2i:
	var size: Vector2i = NxRegistry.behavior(type).definition().size
	return Vector2i(size.y, size.x) if rot % 2 == 1 else size


static func footprint_cells(type: StringName, cell: Vector2i, rot: int) -> Array[Vector2i]:
	var size := footprint_size(type, rot)
	var cells: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			cells.append(cell + Vector2i(x, y))
	return cells


## World-space centre of a footprint (y = 0).
static func footprint_center(type: StringName, cell: Vector2i, rot: int) -> Vector3:
	var size := footprint_size(type, rot)
	return Vector3((cell.x + size.x * 0.5) * CELL_SIZE, 0.0, (cell.y + size.y * 0.5) * CELL_SIZE)


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= -GRID_HALF and cell.y >= -GRID_HALF and cell.x < GRID_HALF and cell.y < GRID_HALF


## Returns { ok: bool, reason: String }.
func can_place(type: StringName, cell: Vector2i, rot: int, ignore_id: int = -1) -> Dictionary:
	if not NxRegistry.has_type(type):
		return { "ok": false, "reason": "Composant inconnu." }
	var occupied := _occupied_cells(ignore_id)
	for c in footprint_cells(type, cell, rot):
		if not in_bounds(c):
			return { "ok": false, "reason": "Hors de la zone de construction." }
		if occupied.has(c):
			return { "ok": false, "reason": "Emplacement occupé par « %s »." % components[occupied[c]].display_name() }
	return { "ok": true, "reason": "" }


func add_component(type: StringName, cell: Vector2i, rot: int = 0, params: Dictionary = {}) -> SimComponent:
	if not can_place(type, cell, rot).ok:
		return null
	var c := SimComponent.new()
	c.id = next_id
	next_id += 1
	c.type = type
	c.cell = cell
	c.rot = posmod(rot, 4)
	c.behavior = NxRegistry.behavior(type)
	c.params = c.behavior.default_params()
	for key in params:
		set_param(c, key, params[key], false)
	c.behavior.reset_state(c)
	components[c.id] = c
	structure_changed.emit()
	return c


func move_component(id: int, cell: Vector2i, rot: int) -> bool:
	var c: SimComponent = components.get(id)
	if c == null or not can_place(c.type, cell, posmod(rot, 4), id).ok:
		return false
	c.cell = cell
	c.rot = posmod(rot, 4)
	structure_changed.emit()
	return true


func remove_component(id: int) -> void:
	if not components.has(id):
		return
	connections = connections.filter(func(l: Dictionary) -> bool:
		return l.from.c != id and l.to.c != id)
	components.erase(id)
	structure_changed.emit()


func component_at(cell: Vector2i) -> SimComponent:
	var occupied := _occupied_cells(-1)
	return components.get(occupied.get(cell, -1))


func sorted_ids() -> Array:
	var ids := components.keys()
	ids.sort()
	return ids


## Sets a parameter with validation against its definition.
func set_param(c: SimComponent, key: String, value: Variant, notify: bool = true) -> bool:
	var pdef := {}
	for p in c.def().params:
		if p.id == key:
			pdef = p
	if pdef.is_empty():
		return false
	match pdef.kind:
		"bool":
			value = bool(value)
		"enum":
			value = clampi(int(value), 0, pdef.options.size() - 1)
		_:
			if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or is_nan(float(value)):
				return false
			value = clampf(snappedf(float(value), pdef.get("step", 0.0)), pdef.min, pdef.max)
	c.params[key] = value
	c.behavior.on_param_changed(c, key, self)
	if notify:
		params_changed.emit(c.id)
	return true


# -----------------------------------------------------------------------------
# Connections
# -----------------------------------------------------------------------------

## World position of a port.
func port_position(c: SimComponent, port_id: StringName) -> Vector3:
	var p := c.port_def(port_id)
	if p.is_empty():
		return footprint_center(c.type, c.cell, c.rot)
	var local: Vector3 = p.pos
	return footprint_center(c.type, c.cell, c.rot) + local.rotated(Vector3.UP, -c.rot * PI * 0.5)


## Returns { ok: bool, reason: String, link: Dictionary }.
func check_connection(a_id: int, a_port: StringName, b_id: int, b_port: StringName) -> Dictionary:
	var a: SimComponent = components.get(a_id)
	var b: SimComponent = components.get(b_id)
	if a == null or b == null:
		return _refuse("Composant introuvable.")
	if a_id == b_id:
		return _refuse("Un composant ne peut pas être relié à lui-même.")
	var pa := a.port_def(a_port)
	var pb := b.port_def(b_port)
	if pa.is_empty() or pb.is_empty():
		return _refuse("Port introuvable.")
	if pa.type != pb.type:
		return _refuse("Connexion incompatible : %s ne peut pas être relié à %s." % [
			NxPort.type_name(pa.type).to_lower(), NxPort.type_name(pb.type).to_lower()])
	var from := { "c": a_id, "p": a_port }
	var to := { "c": b_id, "p": b_port }
	if pa.dir != NxPort.BOTH or pb.dir != NxPort.BOTH:
		if pa.dir == pb.dir:
			return _refuse("Reliez une sortie à une entrée (ici : deux %s)." %
				("entrées" if pa.dir == NxPort.IN else "sorties"))
		if pa.dir == NxPort.IN:
			var tmp := from
			from = to
			to = tmp
	for l in connections:
		if (l.from.c == from.c and l.from.p == from.p and l.to.c == to.c and l.to.p == to.p) \
				or (l.from.c == to.c and l.from.p == to.p and l.to.c == from.c and l.to.p == from.p):
			return _refuse("Ces deux ports sont déjà reliés.")
	for end in [from, to]:
		var comp: SimComponent = components[end.c]
		var pd := comp.port_def(end.p)
		if not pd.get("multi", false) and not links_of(end.c, end.p).is_empty():
			return _refuse("Le port « %s » de %s est déjà utilisé." % [pd.label, comp.display_name()])
	return { "ok": true, "reason": "", "link": { "type": pa.type, "from": from, "to": to } }


func connect_ports(a_id: int, a_port: StringName, b_id: int, b_port: StringName) -> Dictionary:
	var check := check_connection(a_id, a_port, b_id, b_port)
	if not check.ok:
		return check
	var link: Dictionary = check.link
	link.id = next_link_id
	next_link_id += 1
	connections.append(link)
	structure_changed.emit()
	return check


func disconnect_link(link_id: int) -> void:
	var before := connections.size()
	connections = connections.filter(func(l: Dictionary) -> bool: return l.id != link_id)
	if connections.size() != before:
		structure_changed.emit()


## Other ends linked to a port: [{ c: SimComponent, p: StringName, link: Dictionary }].
func links_of(id: int, port: StringName) -> Array:
	var result := []
	for l in connections:
		if l.from.c == id and l.from.p == port:
			result.append({ "c": components.get(l.to.c), "p": l.to.p, "link": l })
		elif l.to.c == id and l.to.p == port:
			result.append({ "c": components.get(l.from.c), "p": l.from.p, "link": l })
	return result


func links_of_component(id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for l in connections:
		if l.from.c == id or l.to.c == id:
			result.append(l)
	return result


## First component linked to a port, or null.
func linked_component(c: SimComponent, port: StringName) -> SimComponent:
	var links := links_of(c.id, port)
	return links[0].c if not links.is_empty() else null


## Signal arriving on an input port: null when nothing is connected.
func input_signal(c: SimComponent, port: StringName) -> Variant:
	var links := links_of(c.id, port)
	if links.is_empty():
		return null
	var other: SimComponent = links[0].c
	return other.behavior.signal_out(other, links[0].p)


# -----------------------------------------------------------------------------
# Simulation
# -----------------------------------------------------------------------------

func step(dt: float) -> void:
	var ids := sorted_ids()

	# 1. Logic: repeat so that chains of gates settle within one step.
	for pass_index in MAX_LOGIC_PASSES:
		var changed := false
		for id in ids:
			var c: SimComponent = components[id]
			var before: Variant = c.state.get("out")
			c.behavior.eval_logic(c, self)
			if c.state.get("out") != before:
				changed = true
		if not changed:
			break

	# 2. Mechanical load seen by every source.
	var trees := {}
	for id in ids:
		var c: SimComponent = components[id]
		c.state.rpm = 0.0
		c.state.erase("driven_by")
	for id in ids:
		var c: SimComponent = components[id]
		if c.behavior.mech_role(c) != SimBehavior.Mech.SOURCE:
			continue
		var tree := _mech_tree(c)
		trees[id] = tree
		var target: float = c.behavior.mech_target_rpm(c)
		var required := 0.0
		for node in tree:
			var sink: SimComponent = node.c
			if sink.behavior.mech_role(sink) == SimBehavior.Mech.SINK and sink.is_enabled():
				required += sink.behavior.mech_load_kw(sink, target * node.ratio)
		c.state.mech_required_kw = required

	# 3. Electrical networks.
	_solve_power(ids)

	# 4. Shaft speeds.
	for id in trees:
		var src: SimComponent = components[id]
		var target: float = src.behavior.mech_target_rpm(src)
		var rated: float = src.behavior.mech_rated_kw(src)
		var required: float = src.state.mech_required_kw
		var overload := minf(1.0, rated / required) if required > rated else 1.0
		src.state.overload = required > rated
		var rpm: float = target * overload * float(src.state.get("power_ratio", 1.0))
		src.state.rpm = rpm
		for node in trees[id]:
			var n: SimComponent = node.c
			if not n.is_enabled():
				continue
			n.state.rpm = rpm * node.ratio
			n.state.driven_by = id
			if n.behavior.mech_role(n) == SimBehavior.Mech.SINK:
				n.state.load_kw = n.behavior.mech_load_kw(n, n.state.rpm) if n.is_enabled() else 0.0

	# 5. Machine updates.
	for id in ids:
		var c: SimComponent = components[id]
		c.behavior.update(c, self, dt)
	time += dt


## Components driven by a source: [{ c, ratio }] following shaft links.
func _mech_tree(source: SimComponent) -> Array:
	var result := []
	var visited := { source.id: true }
	var frontier := [{ "c": source, "ratio": 1.0 }]
	while not frontier.is_empty():
		var node: Dictionary = frontier.pop_front()
		var c: SimComponent = node.c
		var out_ratio: float = node.ratio
		if c != source:
			if not c.is_enabled():
				continue
			out_ratio *= c.behavior.mech_ratio(c)
		for port in c.def().ports:
			if port.type != NxPort.SHAFT or port.dir != NxPort.OUT:
				continue
			for link in links_of(c.id, port.id):
				var next: SimComponent = link.c
				if next == null or visited.has(next.id):
					continue
				visited[next.id] = true
				var entry := { "c": next, "ratio": out_ratio }
				result.append(entry)
				if next.behavior.mech_role(next) == SimBehavior.Mech.PASS:
					frontier.append(entry)
	return result


func _solve_power(ids: Array) -> void:
	# Union-find over power links.
	var parent := {}
	for id in ids:
		parent[id] = id
	for l in connections:
		if l.type == NxPort.POWER and parent.has(l.from.c) and parent.has(l.to.c):
			var ra: int = _find(parent, l.from.c)
			var rb: int = _find(parent, l.to.c)
			if ra != rb:
				parent[ra] = rb
	var networks := {}
	for id in ids:
		var c: SimComponent = components[id]
		if not _has_power_port(c):
			c.state.power_ratio = 1.0
			continue
		var root: int = _find(parent, id)
		if not networks.has(root):
			networks[root] = { "supply": 0.0, "demand": 0.0, "members": [] }
		var net: Dictionary = networks[root]
		net.members.append(c)
		var supply: float = c.behavior.power_supply_kw(c, self) if c.is_enabled() else 0.0
		var demand: float = c.behavior.power_demand_kw(c, self) if c.is_enabled() else 0.0
		c.state.supply_kw = supply
		c.state.demand_kw = demand
		net.supply += supply
		net.demand += demand
	total_supply_kw = 0.0
	total_demand_kw = 0.0
	for root in networks:
		var net: Dictionary = networks[root]
		var ratio := 1.0 if net.demand <= 0.0 else minf(1.0, net.supply / net.demand)
		var delivered: float = minf(net.supply, net.demand)
		# Totals only cover networks fed by a generator: an isolated machine
		# is reported by its own status, not as part of the balance.
		if net.supply > 0.0:
			total_supply_kw += net.supply
			total_demand_kw += net.demand
		for c in net.members:
			c.state.power_ratio = ratio
			c.state.network_supply_kw = net.supply
			c.state.network_demand_kw = net.demand
			c.state.power_kw = c.state.demand_kw * ratio
			c.state.output_kw = 0.0 if net.supply <= 0.0 else delivered * c.state.supply_kw / net.supply


func _has_power_port(c: SimComponent) -> bool:
	for p in c.def().ports:
		if p.type == NxPort.POWER:
			return true
	return false


func has_power_link(c: SimComponent) -> bool:
	for p in c.def().ports:
		if p.type == NxPort.POWER and not links_of(c.id, p.id).is_empty():
			return true
	return false


func _find(parent: Dictionary, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


## Dynamic state to restore when the simulation is reset.
func capture_dynamic() -> Dictionary:
	var snap := { "time": time, "states": {} }
	for id in components:
		var c: SimComponent = components[id]
		snap.states[id] = c.behavior.persistent_state(c)
	return snap


func restore_dynamic(snap: Dictionary) -> void:
	time = snap.get("time", 0.0)
	for id in components:
		var c: SimComponent = components[id]
		c.behavior.reset_state(c)
		if snap.states.has(id):
			c.behavior.restore_state(c, snap.states[id])


# -----------------------------------------------------------------------------
# Serialization
# -----------------------------------------------------------------------------

func serialize() -> Dictionary:
	var comps := []
	for id in sorted_ids():
		comps.append(components[id].serialize())
	var links := []
	for l in connections:
		links.append({ "id": l.id, "type": String(l.type),
			"from": [l.from.c, String(l.from.p)], "to": [l.to.c, String(l.to.p)] })
	return { "next_id": next_id, "next_link_id": next_link_id, "time": time,
		"components": comps, "connections": links }


## Replaces this world's content with another world's (undo, load).
func replace_with(other: SimWorld) -> void:
	components = other.components
	connections = other.connections
	next_id = other.next_id
	next_link_id = other.next_link_id
	time = other.time
	load_warnings = other.load_warnings
	structure_changed.emit()


## Rebuilds the world from serialize() data. Unknown or invalid entries are
## skipped and listed in load_warnings instead of failing the whole load.
static func deserialize(data: Dictionary) -> SimWorld:
	var w := SimWorld.new()
	w.time = float(data.get("time", 0.0))
	var max_id := 0
	for entry in data.get("components", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var type := StringName(str(entry.get("type", "")))
		if not NxRegistry.has_type(type):
			w.load_warnings.append("Composant inconnu ignoré : %s" % type)
			continue
		var cell_arr: Array = entry.get("cell", [0, 0])
		var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
		var rot := posmod(int(entry.get("rot", 0)), 4)
		var id := int(entry.get("id", 0))
		if id <= 0 or w.components.has(id) or not w.can_place(type, cell, rot).ok:
			w.load_warnings.append("Composant invalide ignoré : %s" % type)
			continue
		var c := SimComponent.new()
		c.id = id
		c.type = type
		c.cell = cell
		c.rot = rot
		c.behavior = NxRegistry.behavior(type)
		c.params = c.behavior.default_params()
		w.components[id] = c
		var saved_params: Dictionary = entry.get("params", {})
		for key in saved_params:
			w.set_param(c, key, saved_params[key], false)
		c.behavior.reset_state(c)
		c.behavior.restore_state(c, entry.get("state", {}))
		max_id = maxi(max_id, id)
	w.next_id = maxi(int(data.get("next_id", 1)), max_id + 1)
	var max_link := 0
	for entry in data.get("connections", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var from: Array = entry.get("from", [])
		var to: Array = entry.get("to", [])
		if from.size() != 2 or to.size() != 2:
			continue
		var check := w.check_connection(int(from[0]), StringName(from[1]), int(to[0]), StringName(to[1]))
		if not check.ok:
			w.load_warnings.append("Connexion ignorée : " + check.reason)
			continue
		var link: Dictionary = check.link
		link.id = int(entry.get("id", 0))
		if link.id <= 0:
			link.id = max_link + 1
		max_link = maxi(max_link, link.id)
		w.connections.append(link)
	w.next_link_id = maxi(int(data.get("next_link_id", 1)), max_link + 1)
	return w


func _occupied_cells(ignore_id: int) -> Dictionary:
	var result := {}
	for id in components:
		if id == ignore_id:
			continue
		var c: SimComponent = components[id]
		for cell in footprint_cells(c.type, c.cell, c.rot):
			result[cell] = id
	return result


func _refuse(reason: String) -> Dictionary:
	return { "ok": false, "reason": reason, "link": {} }
