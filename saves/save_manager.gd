extends Node
## Reads and writes NEXUS save files (autoload "SaveManager").
##
## A save is a JSON document with a format id and a version number:
##   {
##     "format": "nexus-save",
##     "version": 1,
##     "meta": { "name": "...", "created": <unix>, "modified": <unix>, "game_version": "..." },
##     "workshop": { ... }
##   }
## Writes are atomic: the data goes to a temporary file which is verified
## before it replaces the previous save, and the previous save is kept as
## a ".bak" file. A file that fails to load is never overwritten automatically.

signal saves_changed

const SAVE_DIR := "user://saves"
const EXTENSION := "nexus"
const FORMAT_ID := "nexus-save"
const FORMAT_VERSION := 1

## Directory scanned for saves; tests point it elsewhere.
var save_dir := SAVE_DIR


# -----------------------------------------------------------------------------
# Listing
# -----------------------------------------------------------------------------

## Returns one entry per save file, most recently modified first.
## Entry keys: path, name, created, modified, valid, error.
func list_saves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return result
	for file in dir.get_files():
		if file.get_extension() != EXTENSION:
			continue
		result.append(read_info(save_dir.path_join(file)))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.modified > b.modified)
	return result


func has_saves() -> bool:
	return not latest_save().is_empty()


## Most recent valid save, or an empty Dictionary.
func latest_save() -> Dictionary:
	for info in list_saves():
		if info.valid:
			return info
	return {}


## Reads only what is needed to display a save in a list.
func read_info(path: String) -> Dictionary:
	var info := {
		"path": path,
		"name": path.get_file().get_basename(),
		"created": 0,
		"modified": FileAccess.get_modified_time(path),
		"valid": false,
		"error": "",
	}
	var result := read_save(path)
	if result.ok:
		var meta: Dictionary = result.data.meta
		info.name = str(meta.get("name", info.name))
		info.created = int(meta.get("created", 0))
		info.modified = int(meta.get("modified", info.modified))
		info.valid = true
	else:
		info.error = result.error
	return info


# -----------------------------------------------------------------------------
# Reading
# -----------------------------------------------------------------------------

## Loads and validates a save. Returns { ok: bool, data: Dictionary, error: String }.
func read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail("Le fichier de sauvegarde est introuvable.")
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return _fail("Le fichier de sauvegarde est vide ou illisible.")
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("Le fichier est endommagé (ligne %d : %s)." % [json.get_error_line(), json.get_error_message()])
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return _fail("Le fichier ne contient pas une sauvegarde NEXUS.")
	if data.get("format") != FORMAT_ID:
		return _fail("Le fichier ne contient pas une sauvegarde NEXUS.")
	var version := int(data.get("version", 0))
	if version <= 0:
		return _fail("La version de la sauvegarde est invalide.")
	if version > FORMAT_VERSION:
		return _fail("Cette sauvegarde provient d'une version plus récente de NEXUS (format %d)." % version)
	data = _migrate(data, version)
	if typeof(data.get("meta")) != TYPE_DICTIONARY or typeof(data.get("workshop")) != TYPE_DICTIONARY:
		return _fail("La sauvegarde est incomplète.")
	return { "ok": true, "data": data, "error": "" }


# -----------------------------------------------------------------------------
# Writing
# -----------------------------------------------------------------------------

## Writes a save. `path` may be empty to create a new file from `name`.
## Returns { ok: bool, path: String, error: String }.
func write_save(path: String, name: String, workshop: Dictionary) -> Dictionary:
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		return { "ok": false, "path": path, "error": "Impossible de créer le dossier des sauvegardes." }
	if path.is_empty():
		path = new_save_path(name)

	var now := int(Time.get_unix_time_from_system())
	var created := now
	if FileAccess.file_exists(path):
		var previous := read_save(path)
		if previous.ok:
			created = int(previous.data.meta.get("created", now))

	var document := {
		"format": FORMAT_ID,
		"version": FORMAT_VERSION,
		"meta": {
			"name": name,
			"created": created,
			"modified": now,
			"game_version": ProjectSettings.get_setting("application/config/version", "0.0.0"),
		},
		"workshop": workshop,
	}

	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return { "ok": false, "path": path, "error": "Écriture impossible : %s." % error_string(FileAccess.get_open_error()) }
	file.store_string(JSON.stringify(document, "\t"))
	file.close()

	# Verify the temporary file before touching the existing save.
	var check := read_save(tmp_path)
	if not check.ok:
		DirAccess.remove_absolute(tmp_path)
		return { "ok": false, "path": path, "error": "Vérification de la sauvegarde échouée : " + check.error }

	if FileAccess.file_exists(path):
		var bak := path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	err = DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		return { "ok": false, "path": path, "error": "Impossible de finaliser la sauvegarde : %s." % error_string(err) }

	saves_changed.emit()
	return { "ok": true, "path": path, "error": "" }


func delete_save(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var err := DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(path + ".bak")
	saves_changed.emit()
	return err == OK


## Builds a unique file path from a display name.
func new_save_path(name: String) -> String:
	var slug := name.strip_edges().to_lower().validate_filename().replace(" ", "_")
	if slug.is_empty():
		slug = "atelier"
	slug = slug.left(40)
	var path := save_dir.path_join("%s.%s" % [slug, EXTENSION])
	var n := 2
	while FileAccess.file_exists(path):
		path = save_dir.path_join("%s_%d.%s" % [slug, n, EXTENSION])
		n += 1
	return path


# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------

## Upgrades older documents to FORMAT_VERSION. Add one step per new version.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var _version := from_version
	# Example for the future:
	# if _version == 1:
	#     data = _migrate_1_to_2(data)
	#     _version = 2
	return data


func _fail(message: String) -> Dictionary:
	return { "ok": false, "data": {}, "error": message }
