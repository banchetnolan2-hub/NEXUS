extends SimBehavior
## Level sensor: measures a tank and outputs a signal with hysteresis
## between a low and a high threshold.

enum Mode { REFILL, ALARM }


func _define() -> Dictionary:
	return {
		"id": &"level_sensor", "name": "Capteur de niveau", "category": &"logic", "icon": "eye",
		"description": "Mesure le niveau d'un réservoir et produit un signal selon deux seuils.",
		"function": "Mesure → signal",
		"size": Vector2i(1, 1),
		"ports": [
			{ "id": &"probe", "type": NxPort.PROBE, "dir": NxPort.IN, "label": "Mesure",
				"pos": Vector3(0.0, 0.35, -0.5) },
			{ "id": &"out", "type": NxPort.SIGNAL, "dir": NxPort.OUT, "label": "Sortie",
				"pos": Vector3(0.0, 0.35, 0.5), "multi": true },
		],
		"params": [
			{ "id": "mode", "label": "Mode", "kind": "enum", "default": Mode.REFILL,
				"options": ["Remplissage : actif sous le seuil bas", "Alerte : actif au-dessus du seuil haut"],
				"desc": "Le signal garde son état entre les deux seuils (hystérésis)." },
			{ "id": "low", "label": "Seuil bas", "kind": "float", "min": 0.0, "max": 100.0,
				"step": 5.0, "unit": "%", "default": 25.0, "desc": "" },
			{ "id": "high", "label": "Seuil haut", "kind": "float", "min": 0.0, "max": 100.0,
				"step": 5.0, "unit": "%", "default": 90.0, "desc": "" },
		],
	}


func reset_state(c: SimComponent) -> void:
	super(c)
	c.state.out = false


func eval_logic(c: SimComponent, w: SimWorld) -> void:
	var tank := w.linked_component(c, &"probe")
	if tank == null or not tank.state.has("amount") or not c.is_enabled():
		c.state.out = false
		c.state.erase("measure")
		return
	var level: float = float(tank.state.amount) / float(tank.param("capacity")) * 100.0
	c.state.measure = level
	var low: float = c.param("low")
	var high: float = c.param("high")
	if int(c.param("mode")) == Mode.REFILL:
		if level <= low:
			c.state.out = true
		elif level >= high:
			c.state.out = false
	else:
		if level >= high:
			c.state.out = true
		elif level <= low:
			c.state.out = false


func update(c: SimComponent, w: SimWorld, _dt: float) -> void:
	if not c.is_enabled():
		set_status(c, &"disabled", "Désactivé")
	elif w.linked_component(c, &"probe") == null:
		set_status(c, &"error", "Reliez la prise de mesure d'un réservoir")
	elif c.state.out:
		set_status(c, &"running", "Sortie active")
	else:
		set_status(c, &"idle", "Sortie inactive")


func live_values(c: SimComponent) -> Array:
	var measure: Variant = c.state.get("measure")
	return [
		["Mesure", "—" if measure == null else "%d %%" % roundi(measure)],
		["Seuils", "%d %% / %d %%" % [roundi(c.param("low")), roundi(c.param("high"))]],
		["Signal de sortie", "ACTIF" if c.state.get("out", false) else "inactif"],
	]
