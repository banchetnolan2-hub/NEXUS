extends SimBehavior
## Electric pump: moves fluid from the tank on its inlet to the tank on its
## outlet. An optional command signal starts and stops it.

const BASE_KW := 0.15
const KW_PER_LPS := 0.09


func _define() -> Dictionary:
	return {
		"id": &"pump", "name": "Pompe", "category": &"fluid", "icon": "droplet",
		"description": "Transfère le fluide d'un réservoir à un autre. Peut être commandée par un signal.",
		"function": "Déplace le fluide",
		"size": Vector2i(1, 1),
		"ports": [
			{ "id": &"fluid_in", "type": NxPort.FLUID, "dir": NxPort.IN, "label": "Aspiration",
				"pos": Vector3(-0.5, 0.3, 0.0) },
			{ "id": &"fluid_out", "type": NxPort.FLUID, "dir": NxPort.OUT, "label": "Refoulement",
				"pos": Vector3(0.5, 0.3, 0.0) },
			{ "id": &"power", "type": NxPort.POWER, "dir": NxPort.BOTH, "label": "Alimentation",
				"pos": Vector3(0.0, 0.55, -0.5), "multi": true },
			{ "id": &"command", "type": NxPort.SIGNAL, "dir": NxPort.IN, "label": "Commande",
				"pos": Vector3(0.0, 0.55, 0.5) },
		],
		"params": [
			{ "id": "flow", "label": "Débit cible", "kind": "float", "min": 0.0, "max": 20.0,
				"step": 0.5, "unit": "L/s", "default": 8.0, "desc": "Volume transféré par seconde à pleine puissance." },
		],
	}


func _commanded(c: SimComponent, w: SimWorld) -> bool:
	var sig: Variant = w.input_signal(c, &"command")
	return sig == null or bool(sig)


func eval_logic(c: SimComponent, w: SimWorld) -> void:
	c.state.commanded = _commanded(c, w)


func power_demand_kw(c: SimComponent, _w: SimWorld) -> float:
	var flow: float = c.param("flow")
	if not c.state.get("commanded", true) or flow <= 0.0:
		return 0.0
	return BASE_KW + KW_PER_LPS * flow


func update(c: SimComponent, w: SimWorld, dt: float) -> void:
	c.state.flow = 0.0
	if not c.is_enabled():
		set_status(c, &"disabled", "Désactivée")
		return
	if not c.state.get("commanded", true):
		set_status(c, &"idle", "En attente : signal de commande inactif")
		return
	var src := w.linked_component(c, &"fluid_in")
	var dst := w.linked_component(c, &"fluid_out")
	if src == null or dst == null or not src.state.has("amount") or not dst.state.has("amount"):
		set_status(c, &"error", "Reliez un réservoir à l'aspiration et au refoulement")
		return
	if float(c.param("flow")) <= 0.0:
		set_status(c, &"idle", "Débit cible nul")
		return
	if not check_power(c, w):
		return
	var ratio: float = c.state.get("power_ratio", 0.0)
	var wanted: float = float(c.param("flow")) * ratio * dt
	var dst_free: float = float(dst.param("capacity")) - float(dst.state.amount)
	var moved: float = clampf(minf(wanted, minf(src.state.amount, dst_free)), 0.0, INF)
	src.state.amount -= moved
	dst.state.amount += moved
	c.state.flow = moved / dt if dt > 0.0 else 0.0
	if src.state.amount <= 0.0 and moved < wanted:
		set_status(c, &"warning", "Réservoir d'aspiration vide")
	elif dst_free <= 0.0001:
		set_status(c, &"idle", "Réservoir de refoulement plein")
	elif ratio < 0.999:
		set_status(c, &"warning", "Énergie insuffisante : débit réduit")
	else:
		set_status(c, &"running", "En marche")


func live_values(c: SimComponent) -> Array:
	return [
		["Débit", "%s L/s" % fmt(c.state.get("flow", 0.0), 1)],
		["Consommation", "%s kW" % fmt(c.state.get("power_kw", 0.0), 2)],
		["Commande", "Active" if c.state.get("commanded", true) else "Inactive"],
	]
