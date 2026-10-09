class_name NxCatalog
extends RefCounted
## Component categories shown in the library. Machine types themselves are
## registered in NxRegistry (simulation/component_registry.gd).

const CATEGORIES := [
	{ "id": &"mechanical", "name": "Mécanique", "icon": "gear",
		"description": "Moteurs, axes, engrenages et transmissions." },
	{ "id": &"energy", "name": "Énergie", "icon": "bolt",
		"description": "Générateurs, batteries, câbles et consommateurs." },
	{ "id": &"fluid", "name": "Fluides", "icon": "droplet",
		"description": "Réservoirs, pompes, tuyaux et vannes." },
	{ "id": &"logic", "name": "Logique", "icon": "logic",
		"description": "Interrupteurs, capteurs et portes logiques." },
]


static func category(id: StringName) -> Dictionary:
	for c in CATEGORIES:
		if c.id == id:
			return c
	return {}


## Machine type ids of a category, in library order.
static func components(category: StringName = &"") -> Array[StringName]:
	return NxRegistry.types(category)
