extends SimBehavior
## Electrical generator: supplies its network up to its rated production.


func _define() -> Dictionary:
	return {
		"id": &"generator", "name": "Générateur", "category": &"energy", "icon": "bolt",
		"description": "Produit de l'électricité pour toutes les machines reliées à son réseau.",
		"function": "Source d'énergie",
		"size": Vector2i(2, 2),
		"ports": [
			{ "id": &"power", "type": NxPort.POWER, "dir": NxPort.BOTH, "label": "Sortie électrique",
				"pos": Vector3(1.0, 0.55, 0.0), "multi": true },
		],
		"params": [
			{ "id": "capacity", "label": "Production maximale", "kind": "float", "min": 1.0, "max": 20.0,
				"step": 0.5, "unit": "kW", "default": 8.0,
				"desc": "Puissance électrique disponible pour le réseau." },
		],
	}


func power_supply_kw(c: SimComponent, _w: SimWorld) -> float:
	return float(c.param("capacity"))


func update(c: SimComponent, w: SimWorld, _dt: float) -> void:
	if not c.is_enabled():
		set_status(c, &"disabled", "Désactivé")
	elif not w.has_power_link(c):
		set_status(c, &"idle", "Aucune machine reliée")
	elif float(c.state.get("output_kw", 0.0)) > 0.0:
		var demand: float = c.state.get("network_demand_kw", 0.0)
		if demand > float(c.state.get("network_supply_kw", 0.0)) + 0.001:
			set_status(c, &"warning", "Surchargé : la demande dépasse la production")
		else:
			set_status(c, &"running", "En production")
	else:
		set_status(c, &"idle", "Prêt, aucune demande")


func live_values(c: SimComponent) -> Array:
	var cap: float = c.param("capacity")
	var out: float = c.state.get("output_kw", 0.0)
	return [
		["Production", "%s kW" % fmt(out, 2)],
		["Charge", "%d %%" % roundi(out / cap * 100.0) if cap > 0 else "—"],
		["Demande du réseau", "%s kW" % fmt(c.state.get("network_demand_kw", 0.0), 2)],
	]
