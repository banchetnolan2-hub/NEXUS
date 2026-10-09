extends SceneTree
## Minimal headless test runner (no external dependency).
## Usage: godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 when every test passes, 1 otherwise.

const TEST_DIR := "user://_tests"

var _failures: Array[String] = []
var _passed := 0
var _current := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var tests: Array[Callable] = [
		test_autoloads_present,
		test_settings_sanitize,
		test_settings_roundtrip,
		test_settings_corrupted_file,
		test_save_write_and_read,
		test_save_listing_and_latest,
		test_save_rejects_invalid_files,
		test_save_keeps_backup,
		test_save_unique_paths,
		test_game_session_flow,
		test_format_relative_time,
		test_theme_variations,
		test_icons_load,
		test_catalog_categories,
		test_scenes_instantiate,
		test_end_to_end_flow,
	]
	for test in tests:
		_current = test.get_method()
		var before := _failures.size()
		await test.call()
		if _failures.size() == before:
			_passed += 1
			print("  ok    ", _current)
		else:
			print("  FAIL  ", _current)
	_cleanup()
	print("\n%d passed, %d failed" % [_passed, tests.size() - _passed])
	for f in _failures:
		print("  - ", f)
	quit(0 if _failures.is_empty() else 1)


# -----------------------------------------------------------------------------
# Assertions
# -----------------------------------------------------------------------------

func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [_current, message])


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func _settings() -> Node:
	return root.get_node("Settings")


func _saves() -> Node:
	return root.get_node("SaveManager")


## A fresh Settings instance writing to a test file and touching no engine state.
func _new_settings(path: String) -> Node:
	var s: Node = load("res://autoload/settings.gd").new()
	s.file_path = path
	s.autosave = false
	s.apply_changes = false
	return s


func _use_save_dir(dir_name: String) -> String:
	var dir := TEST_DIR.path_join(dir_name)
	_remove_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	_saves().save_dir = dir
	return dir


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	for d in dir.get_directories():
		_remove_dir(path.path_join(d))
	DirAccess.remove_absolute(path)


func _cleanup() -> void:
	_saves().save_dir = _saves().SAVE_DIR
	_remove_dir(TEST_DIR)


# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

func test_autoloads_present() -> void:
	for autoload in ["Settings", "SaveManager", "Game", "UI"]:
		check(root.has_node(autoload), "autoload %s missing" % autoload)


func test_settings_sanitize() -> void:
	var s := _new_settings(TEST_DIR.path_join("s1.cfg"))
	s.set_value(&"audio/master", 2.5)
	check_eq(s.get_value(&"audio/master"), 1.0, "volume is clamped to 1")
	s.set_value(&"audio/master", -1)
	check_eq(s.get_value(&"audio/master"), 0.0, "volume is clamped to 0 (int accepted)")
	s.set_value(&"graphics/quality", 99)
	check_eq(s.get_value(&"graphics/quality"), 3, "quality is clamped")
	s.set_value(&"interface/tooltips", "yes")
	check_eq(s.get_value(&"interface/tooltips"), true, "wrong type is rejected")
	s.set_value(&"graphics/resolution", Vector2i(10, 10))
	check_eq(s.get_value(&"graphics/resolution"), Vector2i(1600, 900), "tiny resolution rejected")
	s.set_value(&"controls/camera_sensitivity", NAN)
	check_eq(s.get_value(&"controls/camera_sensitivity"), 1.0, "NaN rejected")
	s.free()


func test_settings_roundtrip() -> void:
	var path := TEST_DIR.path_join("s2.cfg")
	var a := _new_settings(path)
	a.set_value(&"audio/sfx", 0.35)
	a.set_value(&"controls/invert_y", true)
	a.set_value(&"graphics/resolution", Vector2i(1920, 1080))
	a.set_value(&"interface/ui_scale", 1.2)
	check_eq(a.save_settings(), OK, "settings saved")
	a.free()

	var b := _new_settings(path)
	check_eq(b.load_settings(), OK, "settings loaded")
	check(is_equal_approx(b.get_value(&"audio/sfx"), 0.35), "sfx volume persisted")
	check_eq(b.get_value(&"controls/invert_y"), true, "invert persisted")
	check_eq(b.get_value(&"graphics/resolution"), Vector2i(1920, 1080), "resolution persisted")
	check(is_equal_approx(b.get_value(&"interface/ui_scale"), 1.2), "ui scale persisted")
	b.reset_to_defaults()
	check_eq(b.get_value(&"controls/invert_y"), false, "reset restores defaults")
	b.free()


func test_settings_corrupted_file() -> void:
	var path := TEST_DIR.path_join("s3.cfg")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[audio\nmaster = ???\n")
	f.close()
	var s := _new_settings(path)
	check(s.load_settings() != OK, "corrupted file reported")
	check_eq(s.get_value(&"audio/master"), 0.8, "defaults kept")
	s.free()


func test_save_write_and_read() -> void:
	_use_save_dir("w")
	var workshop := { "components": [{ "type": "motor", "pos": [1, 0, 2] }], "connections": [] }
	var result: Dictionary = _saves().write_save("", "Mon atelier", workshop)
	check(result.ok, "write ok: %s" % result.error)
	check(FileAccess.file_exists(result.path), "file exists")
	check(not FileAccess.file_exists(result.path + ".tmp"), "temporary file removed")
	var read: Dictionary = _saves().read_save(result.path)
	check(read.ok, "read ok: %s" % read.error)
	check_eq(read.data.meta.name, "Mon atelier", "name stored")
	check_eq(read.data.version, 1.0, "version stored")
	check_eq(read.data.workshop.components[0].type, "motor", "content stored")


func test_save_listing_and_latest() -> void:
	_use_save_dir("l")
	check(not _saves().has_saves(), "no saves in empty dir")
	check(_saves().latest_save().is_empty(), "no latest save")
	var a: Dictionary = _saves().write_save("", "Alpha", { "components": [] })
	check(a.ok, "first save ok")
	check(_saves().has_saves(), "has saves after writing")
	var list: Array = _saves().list_saves()
	check_eq(list.size(), 1, "one save listed")
	check_eq(_saves().latest_save().name, "Alpha", "latest is Alpha")


func test_save_rejects_invalid_files() -> void:
	var dir := _use_save_dir("bad")
	var cases := {
		"broken.nexus": "{ not json",
		"other.nexus": JSON.stringify({ "format": "something-else", "version": 1 }),
		"future.nexus": JSON.stringify({ "format": "nexus-save", "version": 999, "meta": {}, "workshop": {} }),
		"partial.nexus": JSON.stringify({ "format": "nexus-save", "version": 1 }),
	}
	for file_name in cases:
		var f := FileAccess.open(dir.path_join(file_name), FileAccess.WRITE)
		f.store_string(cases[file_name])
		f.close()
	for file_name in cases:
		var result: Dictionary = _saves().read_save(dir.path_join(file_name))
		check(not result.ok, "%s rejected" % file_name)
		check(not String(result.error).is_empty(), "%s has an explanation" % file_name)
	var list: Array = _saves().list_saves()
	check_eq(list.size(), cases.size(), "invalid saves are still listed")
	check(not _saves().has_saves(), "invalid saves do not enable Continue")
	# Files are never modified by reading them.
	check_eq(FileAccess.get_file_as_string(dir.path_join("broken.nexus")), "{ not json", "file untouched")


func test_save_keeps_backup() -> void:
	_use_save_dir("bak")
	var first: Dictionary = _saves().write_save("", "Bak", { "components": [], "v": 1 })
	var second: Dictionary = _saves().write_save(first.path, "Bak", { "components": [], "v": 2 })
	check(second.ok, "overwrite ok")
	check_eq(second.path, first.path, "same file reused")
	check(FileAccess.file_exists(first.path + ".bak"), "backup kept")
	var current: Dictionary = _saves().read_save(first.path)
	check_eq(current.data.workshop.v, 2.0, "new content written")
	var backup: Dictionary = _saves().read_save(first.path + ".bak")
	check_eq(backup.data.workshop.v, 1.0, "backup holds previous content")
	check_eq(int(current.data.meta.created), int(backup.data.meta.created), "creation date preserved")


func test_save_unique_paths() -> void:
	_use_save_dir("u")
	var a: Dictionary = _saves().write_save("", "Même nom", { "components": [] })
	var b: Dictionary = _saves().write_save("", "Même nom", { "components": [] })
	check(a.path != b.path, "two new saves with the same name do not collide")
	var weird: String = _saves().new_save_path("  ../:*?  ")
	check(weird.begins_with(_saves().save_dir), "path stays in the save directory")


func test_game_session_flow() -> void:
	_use_save_dir("g")
	var game: Node = root.get_node("Game")
	game.new_session("Session test")
	check(game.has_session(), "session created")
	check(not game.dirty, "new session is clean")
	game.mark_dirty()
	check(game.dirty, "dirty flag set")
	var saved: Dictionary = game.save_session()
	check(saved.ok, "session saved")
	check(not game.dirty, "saving clears dirty flag")
	game.new_session()
	var loaded: Dictionary = game.load_session(saved.path)
	check(loaded.ok, "session loaded")
	check_eq(game.session_name, "Session test", "name restored")
	var bad: Dictionary = game.load_session(_saves().save_dir.path_join("missing.nexus"))
	check(not bad.ok, "missing file reported")
	check_eq(game.session_name, "Session test", "failed load keeps the current session")


func test_format_relative_time() -> void:
	var now := 1_800_000_000
	check_eq(NxFormat.relative_time(now - 10, now), "à l'instant", "seconds")
	check_eq(NxFormat.relative_time(now - 300, now), "il y a 5 min", "minutes")
	check_eq(NxFormat.relative_time(now - 7200, now), "il y a 2 h", "hours")
	check_eq(NxFormat.relative_time(now - 90000, now), "hier", "yesterday")
	check_eq(NxFormat.percent(0.756), "76 %", "percent")


func test_theme_variations() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	check(theme != null, "project theme loaded")
	if theme == null:
		return
	for variation in ["PrimaryButton", "GhostButton", "DangerButton", "ToolButton", "MenuEntryButton",
			"NavButton", "ChipButton", "Card", "SidePanel", "BarPanel", "DialogPanel", "ToastPanel",
			"KeyCap", "Wordmark", "Headline", "TitleLabel", "SectionLabel", "MutedLabel",
			"CaptionLabel", "ValueLabel"]:
		check(theme.is_type_variation(variation, theme.get_type_variation_base(variation)) \
			and theme.get_type_variation_base(variation) != &"", "variation %s defined" % variation)
	check(theme.default_font != null, "default font set")
	for icon in ["checked", "unchecked"]:
		check(theme.get_icon(icon, "CheckButton") != null, "CheckButton icon %s" % icon)
	# The saved theme must match the builder (regenerate with tools/build_theme.gd).
	var built: Theme = NxThemeBuilder.build()
	check_eq(theme.get_type_variation_list(&"Button").size(), built.get_type_variation_list(&"Button").size(),
		"nexus_theme.tres is up to date with nx_theme_builder.gd")


func test_icons_load() -> void:
	var names := NxIcons.list_icons()
	check(names.size() >= 40, "icon set found (%d)" % names.size())
	for icon_name in names:
		check(NxIcons.get_icon(icon_name) != null, "icon %s loads" % icon_name)


func test_catalog_categories() -> void:
	var ids := []
	for c in NxCatalog.CATEGORIES:
		ids.append(c.id)
		check(NxIcons.get_icon(c.icon) != null, "category icon %s" % c.icon)
	check_eq(ids, [&"mechanical", &"energy", &"fluid", &"logic"], "the four domains")


func test_scenes_instantiate() -> void:
	root.get_node("Game").new_session()
	for path in ["res://scenes/main_menu/main_menu.tscn", "res://scenes/workshop/workshop.tscn",
			"res://scenes/dev/ui_gallery.tscn"]:
		var packed: PackedScene = load(path)
		check(packed != null, "%s loads" % path)
		if packed == null:
			continue
		var node := packed.instantiate()
		check(node != null, "%s instantiates" % path)
		root.add_child(node)
		for i in 5:
			await process_frame
		node.queue_free()
		await process_frame
	# The workshop sets auto_accept_quit = false while open and restores it.
	check(auto_accept_quit, "auto_accept_quit restored after leaving the workshop")


## Drives the real game: main menu -> new game -> save -> back -> continue.
func test_end_to_end_flow() -> void:
	_use_save_dir("e2e")
	var ui: Node = root.get_node("UI")
	var game: Node = root.get_node("Game")
	var settings: Node = root.get_node("Settings")
	var saved_autosave: bool = settings.autosave
	settings.autosave = false
	settings.set_value(&"interface/reduce_motion", true)

	change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	await _wait(10)
	var menu := current_scene
	check(menu.get_node("%Continue").disabled, "Continue disabled without saves")

	menu.get_node("%NewGame").pressed.emit()
	await _wait(30)
	check_eq(current_scene.name, &"Workshop", "New game opens the workshop")

	_key(KEY_S, true)
	await _wait(5)
	check(_saves().has_saves(), "Ctrl+S writes a save")
	check(not game.dirty, "session clean after save")

	_key(KEY_ESCAPE)
	await _wait(5)
	check(ui.has_open_dialog(), "Escape opens the pause menu")
	_key(KEY_ESCAPE)
	await _wait(10)
	check(not ui.has_open_dialog(), "Escape closes the pause menu")

	var hud: Node = current_scene.get_node("%WorkshopHUD")
	_key(KEY_L, true)
	await _wait(5)
	check(hud.library.collapsed, "Ctrl+L collapses the library")
	_key(KEY_I, true)
	await _wait(5)
	check(hud.inspector.collapsed, "Ctrl+I collapses the inspector")

	# Unsaved changes ask for confirmation before leaving.
	game.session_name = "Renommé"
	game.mark_dirty()
	current_scene.request_main_menu()
	await _wait(5)
	check(ui.has_open_dialog(), "leaving with unsaved changes asks first")
	check_eq(current_scene.name, &"Workshop", "still in the workshop while asking")
	ui.close_all_dialogs()
	await _wait(5)
	game.dirty = false
	current_scene.request_main_menu()
	await _wait(30)
	check_eq(current_scene.name, &"MainMenu", "back to the main menu")

	var cont: Button = current_scene.get_node("%Continue")
	check(not cont.disabled, "Continue enabled once a save exists")
	check(current_scene.get_node("%ContinueDetail").text.begins_with(game.DEFAULT_NAME), "Continue shows the save name")

	settings.set_value(&"interface/tooltips", false)
	check_eq(current_scene.get_node("%Load").tooltip_text, "", "tooltips can be disabled")
	settings.set_value(&"interface/tooltips", true)
	check(current_scene.get_node("%Load").tooltip_text != "", "tooltips restored")

	cont.pressed.emit()
	await _wait(30)
	check_eq(current_scene.name, &"Workshop", "Continue reopens the workshop")
	check_eq(game.session_name, game.DEFAULT_NAME, "Continue loads the saved session")

	settings.set_value(&"interface/reduce_motion", false)
	settings.autosave = saved_autosave
	ui.close_all_dialogs()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _key(keycode: Key, ctrl: bool = false) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.ctrl_pressed = ctrl
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await process_frame
