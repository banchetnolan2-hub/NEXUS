class_name NxCatalog
extends RefCounted
## Component categories shown in the library.
##
## Components will register here from step 3; categories are fixed by the
## design (mechanics, energy, fluids, logic).

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


## Component definitions available in the library (none yet in step 1).
static func components() -> Array[Dictionary]:
	return []
