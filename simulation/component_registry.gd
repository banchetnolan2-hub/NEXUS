class_name NxRegistry
extends RefCounted
## Registry of machine types. To add a machine: write its SimBehavior in
## simulation/components/, add it to TYPES, and (optionally) a visual in
## components/visuals/nx_component_visuals.gd.

const TYPES := [
	preload("res://simulation/components/generator.gd"),
	preload("res://simulation/components/lamp.gd"),
	preload("res://simulation/components/motor.gd"),
	preload("res://simulation/components/transmission.gd"),
	preload("res://simulation/components/fan.gd"),
	preload("res://simulation/components/tank.gd"),
	preload("res://simulation/components/pump.gd"),
	preload("res://simulation/components/switch.gd"),
	preload("res://simulation/components/level_sensor.gd"),
	preload("res://simulation/components/logic_gate.gd"),
]

static var _behaviors: Dictionary = {}
static var _order: Array[StringName] = []


static func _ensure() -> void:
	if not _behaviors.is_empty():
		return
	for script in TYPES:
		var b: SimBehavior = script.new()
		var id: StringName = b.definition().id
		_behaviors[id] = b
		_order.append(id)


static func has_type(type: StringName) -> bool:
	_ensure()
	return _behaviors.has(type)


static func behavior(type: StringName) -> SimBehavior:
	_ensure()
	return _behaviors.get(type)


static func definition(type: StringName) -> Dictionary:
	return behavior(type).definition()


## Type ids in library order, optionally filtered by category.
static func types(category: StringName = &"") -> Array[StringName]:
	_ensure()
	var result: Array[StringName] = []
	for id in _order:
		if category == &"" or _behaviors[id].definition().category == category:
			result.append(id)
	return result
