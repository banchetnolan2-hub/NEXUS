extends SimBehavior
## Industrial fan: a mechanical receiver whose load grows with its speed.

const REFERENCE_RPM := 1500.0
const AIRFLOW_AT_REFERENCE := 4.0  # m³/s


func _define() -> Dictionary:
	return {
		"id": &"fan", "name": "Ventilateur industriel", "category": &"mechanical", "icon": "reset",
		"description": "Machine réceptrice entraînée par un arbre. Plus elle tourne vite, plus elle demande de puissance.",
		"function": "Machine réceptrice",
		"size": Vector2i(1, 1),
		"ports": [
			{ "id": &"shaft_in", "type": NxPort.SHAFT, "dir": NxPort.IN, "label": "Arbre d'entrée",
				"pos": Vector3(-0.5, 0.45, 0.0) },
		],
		"params": [
			{ "id": "load", "label": "Charge à 1 500 tr/min", "kind": "float", "min": 0.5, "max": 8.0,
				"step": 0.5, "unit": "kW", "default": 3.0,
				"desc": "Puissance absorbée à 1 500 tr/min ; proportionnelle à la vitesse." },
		],
	}


func mech_role(_c: SimComponent) -> int:
	return Mech.SINK


func mech_load_kw(c: SimComponent, rpm: float) -> float:
	return float(c.param("load")) * maxf(rpm, 0.0) / REFERENCE_RPM


func update(c: SimComponent, w: SimWorld, _dt: float) -> void:
	if not c.is_enabled():
		set_status(c, &"disabled", "Désactivé")
	elif w.links_of(c.id, &"shaft_in").is_empty():
		set_status(c, &"error", "Aucun entraînement : reliez un arbre")
	elif float(c.state.get("rpm", 0.0)) > 0.5:
		set_status(c, &"running", "En rotation")
	else:
		set_status(c, &"idle", "À l'arrêt")


func live_values(c: SimComponent) -> Array:
	var rpm: float = c.state.get("rpm", 0.0)
	return [
		["Vitesse", "%d tr/min" % roundi(rpm)],
		["Puissance absorbée", "%s kW" % fmt(c.state.get("load_kw", 0.0), 2)],
		["Débit d'air", "%s m³/s" % fmt(AIRFLOW_AT_REFERENCE * rpm / REFERENCE_RPM, 2)],
	]
