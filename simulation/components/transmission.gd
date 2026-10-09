extends SimBehavior
## Gearbox: multiplies the shaft speed by its ratio.


func _define() -> Dictionary:
	return {
		"id": &"transmission", "name": "Transmission", "category": &"mechanical", "icon": "rotate",
		"description": "Boîte d'engrenages : modifie la vitesse entre son entrée et sa sortie.",
		"function": "Change la vitesse",
		"ports": [
			{ "id": &"shaft_in", "type": NxPort.SHAFT, "dir": NxPort.IN, "label": "Arbre d'entrée",
				"pos": Vector3(-0.5, 0.45, 0.0) },
			{ "id": &"shaft_out", "type": NxPort.SHAFT, "dir": NxPort.OUT, "label": "Arbre de sortie",
				"pos": Vector3(0.5, 0.45, 0.0) },
		],
		"params": [
			{ "id": "ratio", "label": "Rapport", "kind": "float", "min": 0.25, "max": 4.0,
				"step": 0.25, "unit": "×", "default": 2.0,
				"desc": "Vitesse de sortie = vitesse d'entrée × rapport." },
		],
	}


func mech_role(_c: SimComponent) -> int:
	return Mech.PASS


func mech_ratio(c: SimComponent) -> float:
	return float(c.param("ratio"))


func update(c: SimComponent, w: SimWorld, _dt: float) -> void:
	if not c.is_enabled():
		set_status(c, &"disabled", "Désactivée")
	elif w.links_of(c.id, &"shaft_in").is_empty():
		set_status(c, &"idle", "Entrée non reliée")
	elif float(c.state.get("rpm", 0.0)) > 0.5:
		set_status(c, &"running", "En rotation")
	else:
		set_status(c, &"idle", "À l'arrêt")


func live_values(c: SimComponent) -> Array:
	var rpm: float = c.state.get("rpm", 0.0)
	return [
		["Vitesse d'entrée", "%d tr/min" % roundi(rpm)],
		["Vitesse de sortie", "%d tr/min" % roundi(rpm * float(c.param("ratio")) if c.is_enabled() else 0.0)],
	]
