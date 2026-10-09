extends SimBehavior
## Indicator lamp: an electrical consumer switched by a signal.


func _define() -> Dictionary:
	return {
		"id": &"lamp", "name": "Voyant lumineux", "category": &"energy", "icon": "info",
		"description": "Consommateur électrique commandé par un signal : s'allume quand il est actif et alimenté.",
		"function": "Sortie commandée",
		"size": Vector2i(1, 1),
		"ports": [
			{ "id": &"power", "type": NxPort.POWER, "dir": NxPort.BOTH, "label": "Alimentation",
				"pos": Vector3(-0.5, 0.25, 0.0), "multi": true },
			{ "id": &"command", "type": NxPort.SIGNAL, "dir": NxPort.IN, "label": "Commande",
				"pos": Vector3(0.5, 0.25, 0.0) },
		],
		"params": [
			{ "id": "power_kw", "label": "Puissance", "kind": "float", "min": 0.1, "max": 3.0,
				"step": 0.1, "unit": "kW", "default": 0.5, "desc": "Consommation quand il est allumé." },
		],
	}


func eval_logic(c: SimComponent, w: SimWorld) -> void:
	var sig: Variant = w.input_signal(c, &"command")
	c.state.commanded = sig == null or bool(sig)


func power_demand_kw(c: SimComponent, _w: SimWorld) -> float:
	return float(c.param("power_kw")) if c.state.get("commanded", true) else 0.0


func update(c: SimComponent, w: SimWorld, _dt: float) -> void:
	c.state.brightness = 0.0
	if not c.is_enabled():
		set_status(c, &"disabled", "Désactivé")
	elif not c.state.get("commanded", true):
		set_status(c, &"idle", "Éteint : commande inactive")
	elif check_power(c, w):
		c.state.brightness = float(c.state.get("power_ratio", 0.0))
		if c.state.brightness < 0.999:
			set_status(c, &"warning", "Énergie insuffisante : éclairage faible")
		else:
			set_status(c, &"running", "Allumé")


func live_values(c: SimComponent) -> Array:
	return [
		["Luminosité", "%d %%" % roundi(float(c.state.get("brightness", 0.0)) * 100.0)],
		["Consommation", "%s kW" % SimBehavior.fmt(c.state.get("power_kw", 0.0), 2)],
	]
