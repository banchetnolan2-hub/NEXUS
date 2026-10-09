extends SimBehavior
## Manual switch: outputs a constant signal chosen by the player.


func _define() -> Dictionary:
	return {
		"id": &"switch", "name": "Interrupteur", "category": &"logic", "icon": "power",
		"description": "Produit un signal actif ou inactif selon sa position.",
		"function": "Commande manuelle",
		"size": Vector2i(1, 1),
		"ports": [
			{ "id": &"out", "type": NxPort.SIGNAL, "dir": NxPort.OUT, "label": "Sortie",
				"pos": Vector3(0.5, 0.3, 0.0), "multi": true },
		],
		"params": [
			{ "id": "on", "label": "Position", "kind": "bool", "default": true,
				"desc": "Activé = signal actif." },
		],
	}


func reset_state(c: SimComponent) -> void:
	super(c)
	c.state.out = false


func eval_logic(c: SimComponent, _w: SimWorld) -> void:
	c.state.out = c.is_enabled() and bool(c.param("on"))


func update(c: SimComponent, _w: SimWorld, _dt: float) -> void:
	if not c.is_enabled():
		set_status(c, &"disabled", "Désactivé")
	elif c.state.out:
		set_status(c, &"running", "Signal actif")
	else:
		set_status(c, &"idle", "Signal inactif")


func live_values(c: SimComponent) -> Array:
	return [["Signal de sortie", "ACTIF" if c.state.get("out", false) else "inactif"]]
