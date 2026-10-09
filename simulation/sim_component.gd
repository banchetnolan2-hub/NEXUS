class_name SimComponent
extends RefCounted
## One placed machine: identity, placement, settings and runtime state.
##
## Behaviour lives in the SimBehavior of its type (see NxRegistry); this
## object only holds data so it can be saved, copied and inspected.

var id := 0
var type: StringName
var cell := Vector2i.ZERO
## Quarter turns around the vertical axis (0..3).
var rot := 0
## Player settings, keyed by parameter id (see the behaviour definition).
var params: Dictionary = {}
## Runtime values computed by the simulation (rpm, amount, signal...).
var state: Dictionary = {}
var behavior: SimBehavior


func def() -> Dictionary:
	return behavior.definition()


func display_name() -> String:
	return def().name


func param(key: String) -> Variant:
	return params.get(key, behavior.param_default(key))


func is_enabled() -> bool:
	return bool(params.get("enabled", true))


func port_def(port_id: StringName) -> Dictionary:
	for p in def().ports:
		if p.id == port_id:
			return p
	return {}


func serialize() -> Dictionary:
	return {
		"id": id,
		"type": String(type),
		"cell": [cell.x, cell.y],
		"rot": rot,
		"params": params.duplicate(true),
		"state": behavior.persistent_state(self),
	}
