extends RefCounted
## Self-test shipped inside the exported game.
##
## Run:  NEXUS.exe -- --selftest      (Linux/macOS: ./NEXUS -- --selftest)
## Checks that the exported build finds its resources, writes to the user
## folder, plays the demo, saves and reloads. Uses separate files so the
## player's own saves and settings are never touched. Writes a report to
## <user folder>/selftest/report.txt and exits with code 0 (ok) or 1.

const DIR := "user://selftest"

var _tree: SceneTree
var _lines: PackedStringArray = []
var _failures := 0


func run(tree: SceneTree) -> void:
	_tree = tree
	DirAccess.make_dir_recursive_absolute(DIR)
	_log("NEXUS %s — autotest" % ProjectSettings.get_setting("application/config/version"))
	_log("Exécutable : %s" % OS.get_executable_path())
	_log("Dossier utilisateur : %s" % OS.get_user_data_dir())
	_log("Rendu : %s · %s" % [ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		RenderingServer.get_video_adapter_name()])

	# 1. Resources embedded in the build.
	_check(ThemeDB.get_project_theme() != null, "thème de l'interface chargé")
	_check(NxIcons.list_icons().size() >= 40, "icônes présentes (%d)" % NxIcons.list_icons().size())
	_check(load("res://resources/fonts/Inter-Regular.ttf") != null, "polices présentes")
	_check(NxRegistry.types().size() == 10, "10 types de machines enregistrés")
	_check(NxMaterials.grid_floor().shader != null, "shader de la grille chargé")
	_check(not OS.get_user_data_dir().begins_with(OS.get_executable_path().get_base_dir()),
		"données utilisateur hors du dossier du jeu")

	# 2. Settings round-trip in a separate file.
	var settings: Node = load("res://autoload/settings.gd").new()
	settings.file_path = DIR.path_join("settings_test.cfg")
	settings.autosave = false
	settings.apply_changes = false
	settings.set_value(&"audio/master", 0.42)
	_check(settings.save_settings() == OK, "écriture des paramètres")
	var settings2: Node = load("res://autoload/settings.gd").new()
	settings2.file_path = settings.file_path
	settings2.apply_changes = false
	settings2.load_settings()
	_check(is_equal_approx(settings2.get_value(&"audio/master"), 0.42), "relecture des paramètres")
	settings.free()
	settings2.free()

	# 3. Main menu.
	var ui: Node = _tree.root.get_node("UI")
	var game: Node = _tree.root.get_node("Game")
	var saves: Node = _tree.root.get_node("SaveManager")
	saves.save_dir = DIR.path_join("saves")
	var old := DirAccess.open(saves.save_dir)
	if old:
		for file in old.get_files():
			old.remove(file)
	_tree.change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	await _frames(60)
	_check(_tree.current_scene != null and _tree.current_scene.name == &"MainMenu", "menu principal affiché")
	await _shot("menu")

	# 4. New game from the demo, simulate, observe.
	game.new_session("Autotest", &"demo")
	_tree.change_scene_to_file("res://scenes/workshop/workshop.tscn")
	await _frames(60)
	var ws: Node = _tree.current_scene
	_check(ws != null and ws.name == &"Workshop", "atelier ouvert")
	if ws == null or ws.name != &"Workshop":
		return _finish()
	ws.runner.start()
	ws.runner.advance(100)
	var fan_rpm := 0.0
	var pump_flow := 0.0
	for id in ws.world.components:
		var c: SimComponent = ws.world.components[id]
		if c.type == &"fan":
			fan_rpm = c.state.rpm
		elif c.type == &"pump":
			pump_flow = c.state.flow
	_check(fan_rpm > 100.0, "simulation mécanique (ventilateur %d tr/min)" % roundi(fan_rpm))
	_check(pump_flow > 0.0, "simulation des fluides (pompe %.1f L/s)" % pump_flow)
	await _frames(30)
	await _shot("workshop")

	# 5. Save, reload.
	var result: Dictionary = game.save_session(ws.serialize())
	_check(result.ok, "sauvegarde écrite : %s" % ProjectSettings.globalize_path(result.get("path", "")))
	var count: int = ws.world.components.size()
	game.new_session()
	var loaded: Dictionary = game.load_session(result.get("path", ""))
	_check(loaded.ok, "sauvegarde relue")
	var w := SimWorld.deserialize(game.workshop_data.get("world", {}))
	_check(w.components.size() == count, "machines rechargées (%d)" % w.components.size())
	_check(not saves.latest_save().is_empty(), "« Continuer » détecte la sauvegarde")
	ui.close_all_dialogs()
	_finish()


func _finish() -> void:
	_log("RÉSULTAT : %s (%d échec(s))" % ["OK" if _failures == 0 else "ÉCHEC", _failures])
	var f := FileAccess.open(DIR.path_join("report.txt"), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	_tree.root.get_node("Game").dirty = false
	_tree.quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
	_log(("  [ok]    " if ok else "  [ÉCHEC] ") + label)


func _log(text: String) -> void:
	_lines.append(text)
	print(text)


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _shot(shot_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := _tree.root.get_texture().get_image()
	if img:
		var path := DIR.path_join(shot_name + ".png")
		img.save_png(path)
		_log("  capture : %s" % ProjectSettings.globalize_path(path))
