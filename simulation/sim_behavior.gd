class_name SimBehavior
extends RefCounted
## Base class of a machine type: declares its ports, parameters and
## behaviour. Subclasses override only what they need.
##
## Definition format (returned by definition()):
##   id, name, category (&"mechanical" | &"energy" | &"fluid" | &"logic"),
##   icon, description, function (short role), size (Vector2i cells),
##   ports: [{ id, type (NxPort), dir (NxPort.IN/OUT/BOTH), label, pos (Vector3), multi (bool) }]
##   params: [{ id, label, kind ("float" | "bool" | "enum"), min, max, step, unit,
##              default, options (enum), desc }]
##
## Each simulation step calls, in this order:
##   eval_logic (several passes) -> power_demand / power_supply -> update.
## Mechanical roles (mech_role, mech_ratio, mech_load_kw) are solved by SimWorld.

enum Mech { NONE, SOURCE, PASS, SINK }

var _def_cache: Dictionary = {}


func definition() -> Dictionary:
	if _def_cache.is_empty():
		_def_cache = _define()
		# Every machine can be switched off.
		var params: Array = _def_cache.get("params", [])
		params.push_front({ "id": "enabled", "label": "Activé", "kind": "bool", "default": true,
			"desc": "Une machine désactivée ne consomme ni ne produit rien." })
		_def_cache.params = params
		if not _def_cache.has("size"):
			_def_cache.size = Vector2i.ONE
	return _def_cache


## Override: returns the definition dictionary (without the "enabled" param).
func _define() -> Dictionary:
	return {}


func param_default(key: String) -> Variant:
	for p in definition().params:
		if p.id == key:
			return p.default
	return null


func default_params() -> Dictionary:
	var result := {}
	for p in definition().params:
		result[p.id] = p.default
	return result


## Runtime state at creation and after a simulation reset.
func reset_state(c: SimComponent) -> void:
	c.state = { "status": &"idle", "status_text": "À l'arrêt" }


## State saved with the workshop (e.g. tank contents). Empty by default.
func persistent_state(_c: SimComponent) -> Dictionary:
	return {}


func restore_state(_c: SimComponent, _saved: Dictionary) -> void:
	pass


func eval_logic(_c: SimComponent, _w: SimWorld) -> void:
	pass


## Signal produced on an output port (logic).
func signal_out(c: SimComponent, _port: StringName) -> bool:
	return bool(c.state.get("out", false))


func power_supply_kw(_c: SimComponent, _w: SimWorld) -> float:
	return 0.0


func power_demand_kw(_c: SimComponent, _w: SimWorld) -> float:
	return 0.0


func mech_role(_c: SimComponent) -> int:
	return Mech.NONE


func mech_ratio(_c: SimComponent) -> float:
	return 1.0


## Sources only: speed the source tries to reach, and its rated power.
func mech_target_rpm(_c: SimComponent) -> float:
	return 0.0


func mech_rated_kw(_c: SimComponent) -> float:
	return 0.0


## Called after a parameter changed (validation already done).
func on_param_changed(_c: SimComponent, _key: String, _w: SimWorld) -> void:
	pass


## Mechanical power absorbed at a given shaft speed (sinks only).
func mech_load_kw(_c: SimComponent, _rpm: float) -> float:
	return 0.0


func update(_c: SimComponent, _w: SimWorld, _dt: float) -> void:
	pass


## Live values for the inspector: [[label, text], ...]. Only real state.
func live_values(_c: SimComponent) -> Array:
	return []


static func set_status(c: SimComponent, status: StringName, text: String) -> void:
	c.state.status = status
	c.state.status_text = text


## Common electrical checks for consumers. Sets an error/warning status and
## returns false when the machine cannot run at all.
static func check_power(c: SimComponent, w: SimWorld) -> bool:
	if not w.has_power_link(c):
		set_status(c, &"error", "Aucune alimentation : reliez un câble à un générateur")
		return false
	if float(c.state.get("power_ratio", 0.0)) <= 0.0:
		set_status(c, &"error", "Non alimenté : aucun générateur actif sur ce réseau")
		return false
	return true


static func fmt(value: float, decimals: int = 1) -> String:
	var s := String.num(value, decimals)
	return s.replace(".", ",")
