extends SimBehavior
## Logic gate: AND, OR or NOT of its inputs. Unconnected inputs are inactive.

enum Mode { AND, OR, NOT }


func _define() -> Dictionary:
	return {
		"id": &"logic_gate", "name": "Porte logique", "category": &"logic", "icon": "logic",
		"description": "Combine deux signaux (ET, OU) ou inverse le signal A (NON).",
		"function": "Combine des signaux",
		"size": Vector2i(1, 1),
		"ports": [
			{ "id": &"in_a", "type": NxPort.SIGNAL, "dir": NxPort.IN, "label": "Entrée A",
				"pos": Vector3(-0.5, 0.3, -0.22) },
			{ "id": &"in_b", "type": NxPort.SIGNAL, "dir": NxPort.IN, "label": "Entrée B",
				"pos": Vector3(-0.5, 0.3, 0.22) },
			{ "id": &"out", "type": NxPort.SIGNAL, "dir": NxPort.OUT, "label": "Sortie",
				"pos": Vector3(0.5, 0.3, 0.0), "multi": true },
		],
		"params": [
			{ "id": "mode", "label": "Fonction", "kind": "enum", "default": Mode.AND,
				"options": ["ET : A et B actifs", "OU : A ou B actif", "NON : inverse A"], "desc": "" },
		],
	}


func reset_state(c: SimComponent) -> void:
	super(c)
	c.state.out = false


func eval_logic(c: SimComponent, w: SimWorld) -> void:
	var a := bool(w.input_signal(c, &"in_a") == true)
	var b := bool(w.input_signal(c, &"in_b") == true)
	c.state.a = a
	c.state.b = b
	if not c.is_enabled():
		c.state.out = false
		return
	match int(c.param("mode")):
		Mode.AND:
			c.state.out = a and b
		Mode.OR:
			c.state.out = a or b
		_:
			c.state.out = not a


func update(c: SimComponent, _w: SimWorld, _dt: float) -> void:
	if not c.is_enabled():
		set_status(c, &"disabled", "Désactivée")
	elif c.state.out:
		set_status(c, &"running", "Sortie active")
	else:
		set_status(c, &"idle", "Sortie inactive")


func live_values(c: SimComponent) -> Array:
	var on := func(v: Variant) -> String: return "ACTIF" if v else "inactif"
	return [
		["Entrée A", on.call(c.state.get("a", false))],
		["Entrée B", on.call(c.state.get("b", false))],
		["Sortie", on.call(c.state.get("out", false))],
	]
