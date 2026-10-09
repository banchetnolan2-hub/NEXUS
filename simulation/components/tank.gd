extends SimBehavior
## Tank: stores fluid between 0 and its capacity. Can supply a constant
## draw that represents the factory using the fluid.


func _define() -> Dictionary:
	return {
		"id": &"tank", "name": "Réservoir", "category": &"fluid", "icon": "droplet",
		"description": "Stocke du fluide. Ne peut jamais dépasser sa capacité ni descendre sous zéro.",
		"function": "Stockage",
		"size": Vector2i(2, 2),
		"ports": [
			{ "id": &"fluid_in", "type": NxPort.FLUID, "dir": NxPort.IN, "label": "Arrivée",
				"pos": Vector3(-1.0, 0.35, 0.0) },
			{ "id": &"fluid_out", "type": NxPort.FLUID, "dir": NxPort.OUT, "label": "Sortie",
				"pos": Vector3(1.0, 0.35, 0.0) },
			{ "id": &"probe", "type": NxPort.PROBE, "dir": NxPort.OUT, "label": "Prise de mesure",
				"pos": Vector3(0.0, 1.4, 1.0), "multi": true },
		],
		"params": [
			{ "id": "capacity", "label": "Capacité", "kind": "float", "min": 100.0, "max": 5000.0,
				"step": 50.0, "unit": "L", "default": 1000.0, "desc": "Volume maximal." },
			{ "id": "initial", "label": "Niveau initial", "kind": "float", "min": 0.0, "max": 100.0,
				"step": 5.0, "unit": "%", "default": 50.0,
				"desc": "Remplissage au début de la simulation (et après réinitialisation)." },
			{ "id": "draw", "label": "Consommation de l'usine", "kind": "float", "min": 0.0, "max": 20.0,
				"step": 0.5, "unit": "L/s", "default": 0.0,
				"desc": "Fluide prélevé en continu pendant la simulation." },
		],
	}


func reset_state(c: SimComponent) -> void:
	super(c)
	c.state.amount = float(c.param("capacity")) * float(c.param("initial")) / 100.0
	c.state.draw_rate = 0.0


func persistent_state(c: SimComponent) -> Dictionary:
	return { "amount": c.state.get("amount", 0.0) }


func restore_state(c: SimComponent, saved: Dictionary) -> void:
	if saved.has("amount"):
		c.state.amount = clampf(float(saved.amount), 0.0, float(c.param("capacity")))


func on_param_changed(c: SimComponent, key: String, w: SimWorld) -> void:
	if not c.state.has("amount"):
		return
	if key == "initial" and not w.running and is_equal_approx(w.time, 0.0):
		c.state.amount = float(c.param("capacity")) * float(c.param("initial")) / 100.0
	c.state.amount = clampf(c.state.amount, 0.0, float(c.param("capacity")))


func free_space(c: SimComponent) -> float:
	return float(c.param("capacity")) - float(c.state.get("amount", 0.0))


func level(c: SimComponent) -> float:
	return float(c.state.get("amount", 0.0)) / float(c.param("capacity"))


func update(c: SimComponent, _w: SimWorld, dt: float) -> void:
	var draw: float = float(c.param("draw")) if c.is_enabled() else 0.0
	var taken: float = minf(draw * dt, c.state.amount)
	c.state.amount -= taken
	c.state.draw_rate = taken / dt if dt > 0.0 else 0.0
	if not c.is_enabled():
		set_status(c, &"disabled", "Désactivé (aucun prélèvement)")
	elif draw > 0.0 and c.state.amount <= 0.0:
		set_status(c, &"warning", "Vide : la consommation n'est plus assurée")
	elif level(c) >= 0.999:
		set_status(c, &"idle", "Plein")
	elif draw > 0.0:
		set_status(c, &"running", "Alimente l'usine")
	else:
		set_status(c, &"idle", "En stockage")


func live_values(c: SimComponent) -> Array:
	return [
		["Contenu", "%d / %d L" % [roundi(c.state.get("amount", 0.0)), roundi(c.param("capacity"))]],
		["Niveau", "%d %%" % roundi(level(c) * 100.0)],
		["Prélèvement", "%s L/s" % fmt(c.state.get("draw_rate", 0.0), 1)],
	]
