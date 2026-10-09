extends SimBehavior
## Electric motor: drives a shaft at a target speed. Consumption follows the
## mechanical load; it slows down when overloaded or under-powered.

const RATED_KW := 6.0
const IDLE_KW := 0.25
const EFFICIENCY := 0.9
const MAX_RPM := 3000.0


func _define() -> Dictionary:
	return {
		"id": &"motor", "name": "Moteur électrique", "category": &"mechanical", "icon": "gear",
		"description": "Transforme l'électricité en rotation. Sa vitesse baisse s'il est surchargé ou mal alimenté.",
		"function": "Entraîne un arbre",
		"size": Vector2i(2, 1),
		"ports": [
			{ "id": &"power", "type": NxPort.POWER, "dir": NxPort.BOTH, "label": "Alimentation",
				"pos": Vector3(-0.9, 0.45, 0.0), "multi": true },
			{ "id": &"shaft_out", "type": NxPort.SHAFT, "dir": NxPort.OUT, "label": "Arbre de sortie",
				"pos": Vector3(1.0, 0.45, 0.0) },
		],
		"params": [
			{ "id": "target_rpm", "label": "Vitesse cible", "kind": "float", "min": 0.0, "max": MAX_RPM,
				"step": 50.0, "unit": "tr/min", "default": 1500.0,
				"desc": "Vitesse de rotation visée à la sortie du moteur." },
		],
	}


func mech_role(_c: SimComponent) -> int:
	return Mech.SOURCE


func mech_target_rpm(c: SimComponent) -> float:
	return float(c.param("target_rpm")) if c.is_enabled() else 0.0


func mech_rated_kw(_c: SimComponent) -> float:
	return RATED_KW


func power_demand_kw(c: SimComponent, _w: SimWorld) -> float:
	if float(c.param("target_rpm")) <= 0.0:
		return 0.0
	var mech: float = minf(float(c.state.get("mech_required_kw", 0.0)), RATED_KW)
	return IDLE_KW + mech / EFFICIENCY


func update(c: SimComponent, w: SimWorld, _dt: float) -> void:
	if not c.is_enabled():
		set_status(c, &"disabled", "Désactivé")
	elif float(c.param("target_rpm")) <= 0.0:
		set_status(c, &"idle", "Vitesse cible nulle")
	elif not check_power(c, w):
		pass
	elif float(c.state.get("power_ratio", 1.0)) < 0.999:
		set_status(c, &"warning", "Énergie insuffisante : vitesse réduite")
	elif c.state.get("overload", false):
		set_status(c, &"warning", "Surcharge : la charge dépasse %s kW" % fmt(RATED_KW, 0))
	else:
		set_status(c, &"running", "En marche")


func live_values(c: SimComponent) -> Array:
	return [
		["Vitesse", "%d tr/min" % roundi(c.state.get("rpm", 0.0))],
		["Consommation", "%s kW" % fmt(c.state.get("power_kw", 0.0), 2)],
		["Charge mécanique", "%s / %s kW" % [fmt(c.state.get("mech_required_kw", 0.0), 2), fmt(RATED_KW, 0)]],
		["Énergie reçue", "%d %%" % roundi(float(c.state.get("power_ratio", 0.0)) * 100.0)],
	]
