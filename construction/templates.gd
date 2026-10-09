class_name NxTemplates
extends RefCounted
## Starting installations offered by "Nouvelle partie".

const TEMPLATES := [
	{ "id": &"empty", "name": "Atelier vide", "icon": "grid",
		"description": "Une zone de construction libre, sans aucune machine." },
	{ "id": &"demo", "name": "Exemple : remplissage automatique", "icon": "blueprint",
		"description": "Une chaîne moteur → ventilateur et un réservoir rempli par une pompe que pilote un capteur." },
]


## Serialized world for a template id.
static func build(id: StringName) -> Dictionary:
	var w := SimWorld.new()
	if id == &"demo":
		_demo(w)
	return w.serialize()


static func _demo(w: SimWorld) -> void:
	var gen := w.add_component(&"generator", Vector2i(-7, -2), 0, { "capacity": 12.0 })
	var motor := w.add_component(&"motor", Vector2i(-3, -5))
	var gear := w.add_component(&"transmission", Vector2i(0, -5))
	var fan := w.add_component(&"fan", Vector2i(2, -5))
	var source := w.add_component(&"tank", Vector2i(-4, 2), 0, { "capacity": 3000.0, "initial": 100.0 })
	var pump := w.add_component(&"pump", Vector2i(0, 2))
	var target := w.add_component(&"tank", Vector2i(3, 2), 0, { "initial": 30.0, "draw": 5.0 })
	var sensor := w.add_component(&"level_sensor", Vector2i(3, 5), 0, { "low": 40.0, "high": 80.0 })
	var sw := w.add_component(&"switch", Vector2i(0, 5))
	var gate := w.add_component(&"logic_gate", Vector2i(1, 5))
	var lamp := w.add_component(&"lamp", Vector2i(6, 5))
	w.connect_ports(gen.id, &"power", motor.id, &"power")
	w.connect_ports(motor.id, &"shaft_out", gear.id, &"shaft_in")
	w.connect_ports(gear.id, &"shaft_out", fan.id, &"shaft_in")
	w.connect_ports(source.id, &"fluid_out", pump.id, &"fluid_in")
	w.connect_ports(pump.id, &"fluid_out", target.id, &"fluid_in")
	w.connect_ports(gen.id, &"power", pump.id, &"power")
	w.connect_ports(target.id, &"probe", sensor.id, &"probe")
	w.connect_ports(sensor.id, &"out", gate.id, &"in_a")
	w.connect_ports(sw.id, &"out", gate.id, &"in_b")
	w.connect_ports(gate.id, &"out", pump.id, &"command")
	w.connect_ports(gen.id, &"power", lamp.id, &"power")
	w.connect_ports(sensor.id, &"out", lamp.id, &"command")
