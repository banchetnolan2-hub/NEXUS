extends Node
## Current play session (autoload "Game").
##
## Holds which workshop is open, where it is saved and whether it has unsaved
## changes. Scenes read the session; SaveManager does the file work.

signal session_changed
signal dirty_changed(dirty: bool)

const DEFAULT_NAME := "Atelier sans titre"
const WORKSHOP_SCENE := "res://scenes/workshop/workshop.tscn"
const MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

var session_name := DEFAULT_NAME
var save_path := ""
## Serialized workshop content (components, connections, camera...).
var workshop_data: Dictionary = {}
var dirty := false:
	set(value):
		if dirty == value:
			return
		dirty = value
		dirty_changed.emit(dirty)


func _ready() -> void:
	# Exported builds can check themselves: NEXUS.exe -- --selftest
	if "--selftest" in OS.get_cmdline_user_args() or "--selftest" in OS.get_cmdline_args():
		_run_self_test.call_deferred()


func _run_self_test() -> void:
	var script: GDScript = load("res://tests/export_smoke.gd")
	if script == null or not script.can_instantiate():
		push_error("Autotest indisponible dans cette version.")
		get_tree().quit(2)
		return
	await script.new().run(get_tree())


func has_session() -> bool:
	return not workshop_data.is_empty()


func new_session(name: String = DEFAULT_NAME, template: StringName = &"empty") -> void:
	session_name = name
	save_path = ""
	workshop_data = { "world": NxTemplates.build(template), "camera": {} }
	dirty = false
	session_changed.emit()


## Loads a save into the session. Returns the SaveManager result.
func load_session(path: String) -> Dictionary:
	var result := SaveManager.read_save(path)
	if not result.ok:
		return result
	session_name = str(result.data.meta.get("name", DEFAULT_NAME))
	save_path = path
	workshop_data = result.data.workshop
	dirty = false
	session_changed.emit()
	return result


## Writes the session to disk. `workshop` replaces the stored content when given.
func save_session(workshop: Dictionary = {}) -> Dictionary:
	if not workshop.is_empty():
		workshop_data = workshop
	var result := SaveManager.write_save(save_path, session_name, workshop_data)
	if result.ok:
		save_path = result.path
		dirty = false
	return result


func mark_dirty() -> void:
	dirty = true
