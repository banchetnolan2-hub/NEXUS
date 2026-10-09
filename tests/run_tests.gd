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
		test_sim_power_and_mechanics,
		test_sim_fluids_and_logic,
		test_sim_connection_rules,
		test_sim_placement,
		test_sim_serialize_roundtrip,
		test_undo_redo,
		test_save_migration_v1,
		test_demo_template_runs,
		test_workshop_gameplay_loop,
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
	check_eq(read.data.version, 2.0, "version stored")
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
	await _wait(5)
	check(ui.has_open_dialog(), "New game asks for a name and a template")
	_key(KEY_ENTER)
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



# -----------------------------------------------------------------------------
# V2: simulation, construction, gameplay loop
# -----------------------------------------------------------------------------

func _run_world(w: SimWorld, seconds: float) -> void:
	for i in int(seconds / SimulationRunner.TICK):
		w.step(SimulationRunner.TICK)


func test_sim_power_and_mechanics() -> void:
	var w := SimWorld.new()
	var g := w.add_component(&"generator", Vector2i(0, 0), 0, { "capacity": 20.0 })
	var m := w.add_component(&"motor", Vector2i(3, 0), 0, { "target_rpm": 1000.0 })
	var t := w.add_component(&"transmission", Vector2i(6, 0), 0, { "ratio": 2.0 })
	var f := w.add_component(&"fan", Vector2i(8, 0), 0, { "load": 1.0 })
	check(w.connect_ports(g.id, &"power", m.id, &"power").ok, "power link")
	check(w.connect_ports(m.id, &"shaft_out", t.id, &"shaft_in").ok, "shaft link 1")
	check(w.connect_ports(t.id, &"shaft_out", f.id, &"shaft_in").ok, "shaft link 2")
	_run_world(w, 1.0)
	check(is_equal_approx(m.state.rpm, 1000.0), "motor reaches its target")
	check(is_equal_approx(f.state.rpm, 2000.0), "transmission ratio applied (got %s)" % f.state.rpm)
	check(is_equal_approx(f.state.load_kw, 1.0 * 2000.0 / 1500.0), "fan load follows its speed")
	check(m.state.power_kw > 0.25, "motor consumes power")
	check_eq(m.state.status, &"running", "motor running")
	# Overload: the motor slows down instead of exceeding its rating.
	w.set_param(f, "load", 8.0)
	_run_world(w, 0.2)
	check(m.state.rpm < 1000.0, "overloaded motor slows down")
	check_eq(m.state.status, &"warning", "overload reported")
	# Not enough energy: machines report it and slow down.
	w.set_param(f, "load", 1.0)
	w.set_param(g, "capacity", 1.0)
	_run_world(w, 0.2)
	check(m.state.power_ratio < 1.0, "power ratio below 1")
	check(m.state.rpm < 1000.0, "under-powered motor slows down")
	check(String(m.state.status_text).contains("Énergie insuffisante"), "insufficient energy reported")
	check(g.state.output_kw <= 1.0 + 0.0001, "generator never exceeds its capacity")
	# A disabled machine consumes nothing.
	w.set_param(m, "enabled", false)
	_run_world(w, 0.2)
	check_eq(m.state.get("power_kw", 0.0), 0.0, "disabled motor consumes nothing")
	check_eq(f.state.rpm, 0.0, "fan stops when its motor is disabled")
	# Unpowered motor.
	var lonely := w.add_component(&"motor", Vector2i(0, 5))
	_run_world(w, 0.1)
	check_eq(lonely.state.status, &"error", "unpowered motor reports an error")
	var supplied_demand := w.total_demand_kw
	w.add_component(&"lamp", Vector2i(0, 8))
	_run_world(w, 0.1)
	check_eq(w.total_demand_kw, supplied_demand, "isolated machines are not counted in the energy balance")
	check_eq(lonely.state.rpm, 0.0, "unpowered motor does not turn")


func test_sim_fluids_and_logic() -> void:
	var w := SimWorld.new()
	var g := w.add_component(&"generator", Vector2i(-8, 0), 0, { "capacity": 10.0 })
	var a := w.add_component(&"tank", Vector2i(-4, 0), 0, { "capacity": 1000.0, "initial": 100.0 })
	var p := w.add_component(&"pump", Vector2i(0, 0), 0, { "flow": 10.0 })
	var b := w.add_component(&"tank", Vector2i(3, 0), 0, { "capacity": 500.0, "initial": 10.0, "draw": 2.0 })
	var s := w.add_component(&"level_sensor", Vector2i(3, 4), 0, { "low": 20.0, "high": 60.0 })
	w.connect_ports(a.id, &"fluid_out", p.id, &"fluid_in")
	w.connect_ports(p.id, &"fluid_out", b.id, &"fluid_in")
	w.connect_ports(g.id, &"power", p.id, &"power")
	w.connect_ports(b.id, &"probe", s.id, &"probe")
	w.connect_ports(s.id, &"out", p.id, &"command")
	var total_before: float = a.state.amount + b.state.amount
	_run_world(w, 1.0)
	check(s.state.out, "sensor active under the low threshold")
	check(p.state.flow > 9.0, "pump runs when commanded (flow %s)" % p.state.flow)
	# Fluid is conserved except what the factory draws.
	var drawn := 2.0 * 1.0
	check(absf(a.state.amount + b.state.amount + drawn - total_before) < 0.01, "fluid conserved")
	# Hysteresis: pumps until the high threshold, then stops.
	_run_world(w, 60.0)
	var max_level := 0.0
	var min_level := 100.0
	for i in 2000:
		w.step(SimulationRunner.TICK)
		var lvl: float = b.state.amount / 500.0 * 100.0
		max_level = maxf(max_level, lvl)
		min_level = minf(min_level, lvl)
		check(a.state.amount >= 0.0 and b.state.amount <= 500.0 + 0.0001, "tanks stay within bounds")
		if a.state.amount < 0.0:
			break
	check(max_level <= 61.0 + 0.5, "level stays under the high threshold + one step (max %s)" % max_level)
	check(min_level >= 19.0, "level refilled at the low threshold (min %s)" % min_level)
	# Logic gate.
	var sw := w.add_component(&"switch", Vector2i(-8, 6), 0, { "on": false })
	var gate := w.add_component(&"logic_gate", Vector2i(-6, 6))
	w.connect_ports(sw.id, &"out", gate.id, &"in_a")
	w.connect_ports(s.id, &"out", gate.id, &"in_b")
	w.set_param(gate, "mode", 2)
	w.step(0.05)
	check(gate.state.out, "NOT gate inverts an inactive input")
	w.set_param(sw, "on", true)
	w.step(0.05)
	check(not gate.state.out, "NOT gate output follows the switch")
	# Empty source: never negative.
	w.set_param(a, "initial", 0.0)
	a.state.amount = 0.0
	b.state.amount = 0.0
	_run_world(w, 2.0)
	check_eq(a.state.amount, 0.0, "empty tank stays at zero")
	check_eq(p.state.status, &"warning", "pump reports an empty source")


func test_sim_connection_rules() -> void:
	var w := SimWorld.new()
	var g := w.add_component(&"generator", Vector2i(0, 0))
	var m := w.add_component(&"motor", Vector2i(3, 0))
	var f := w.add_component(&"fan", Vector2i(6, 0))
	var f2 := w.add_component(&"fan", Vector2i(8, 0))
	var t := w.add_component(&"tank", Vector2i(0, 4))
	check(not w.check_connection(g.id, &"power", t.id, &"fluid_in").ok, "incompatible types refused")
	check(not w.check_connection(f.id, &"shaft_in", f2.id, &"shaft_in").ok, "input to input refused")
	check(not w.check_connection(m.id, &"power", m.id, &"shaft_out").ok, "self link refused")
	var r := w.connect_ports(f.id, &"shaft_in", m.id, &"shaft_out")
	check(r.ok, "link can be made from the input side")
	check_eq(r.link.from.c, m.id, "direction normalised (from = output)")
	check(not w.check_connection(m.id, &"shaft_out", f2.id, &"shaft_in").ok, "single-link port refused when used")
	check(not w.check_connection(m.id, &"shaft_out", f.id, &"shaft_in").ok, "duplicate refused")
	check(w.connect_ports(g.id, &"power", m.id, &"power").ok, "power link")
	w.remove_component(m.id)
	check_eq(w.connections.size(), 0, "removing a machine removes its links")


func test_sim_placement() -> void:
	var w := SimWorld.new()
	var g := w.add_component(&"generator", Vector2i(0, 0))
	check(g != null, "placed")
	check(not w.can_place(&"fan", Vector2i(1, 1), 0).ok, "overlap refused")
	check(w.can_place(&"fan", Vector2i(2, 1), 0).ok, "adjacent cell allowed")
	check(not w.can_place(&"fan", Vector2i(SimWorld.GRID_HALF, 0), 0).ok, "outside the area refused")
	check_eq(SimWorld.footprint_size(&"motor", 1), Vector2i(1, 2), "rotation swaps the footprint")
	var m := w.add_component(&"motor", Vector2i(4, 0))
	check(w.move_component(m.id, Vector2i(4, 0), 1), "rotating in place")
	check(not w.move_component(m.id, Vector2i(1, 0), 0), "moving onto another machine refused")
	check_eq(w.component_at(Vector2i(4, 1)).id, m.id, "rotated footprint occupies the new cells")


func test_sim_serialize_roundtrip() -> void:
	var w := SimWorld.deserialize(NxTemplates.build(&"demo"))
	_run_world(w, 3.0)
	var json := JSON.stringify(w.serialize())
	var w2 := SimWorld.deserialize(JSON.parse_string(json))
	check_eq(w2.components.size(), w.components.size(), "components restored")
	check_eq(w2.connections.size(), w.connections.size(), "connections restored")
	check(w2.load_warnings.is_empty(), "no warning on a clean save")
	for id in w.components:
		var a: SimComponent = w.components[id]
		var b: SimComponent = w2.components[id]
		check_eq(b.cell, a.cell, "position kept")
		check_eq(b.rot, a.rot, "rotation kept")
		check_eq(b.params, a.params, "settings kept")
		if a.type == &"tank":
			check(is_equal_approx(b.state.amount, a.state.amount), "tank content kept")
	var data: Dictionary = w.serialize()
	data.components.append({ "id": 999, "type": "teleporter", "cell": [10, 10] })
	var w3 := SimWorld.deserialize(data)
	check_eq(w3.components.size(), w.components.size(), "unknown machine skipped, others kept")
	check_eq(w3.load_warnings.size(), 1, "unknown machine reported")


func test_undo_redo() -> void:
	var w := SimWorld.new()
	var stack := NxUndoStack.new()
	stack.record(w, "Placer")
	var g := w.add_component(&"generator", Vector2i(0, 0))
	stack.record(w, "Régler", "param:%d:capacity" % g.id)
	w.set_param(g, "capacity", 3.0)
	stack.record(w, "Régler", "param:%d:capacity" % g.id)
	w.set_param(g, "capacity", 4.0)
	stack.undo(w)
	check_eq(w.components[g.id].params.capacity, 8.0, "merged slider edits undone in one step")
	stack.undo(w)
	check(w.components.is_empty(), "placement undone")
	stack.redo(w)
	check_eq(w.components.size(), 1, "placement redone")
	check(stack.can_redo(), "second redo available")


func test_save_migration_v1() -> void:
	var dir := _use_save_dir("mig")
	var v1 := { "format": "nexus-save", "version": 1,
		"meta": { "name": "Ancien", "created": 1, "modified": 2 },
		"workshop": { "components": [], "connections": [] } }
	var path := dir.path_join("ancien.nexus")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	var r: Dictionary = _saves().read_save(path)
	check(r.ok, "v1 save loads")
	check(r.data.workshop.has("world"), "v1 save migrated to the v2 layout")
	var w := SimWorld.deserialize(r.data.workshop.world)
	check(w.components.is_empty(), "migrated world is valid")


func test_demo_template_runs() -> void:
	var w := SimWorld.deserialize(NxTemplates.build(&"demo"))
	check(w.components.size() >= 10, "demo has machines")
	check_eq(w.connections.size(), 12, "demo is wired")
	_run_world(w, 5.0)
	var fan_rpm := 0.0
	var pump_flow := 0.0
	for id in w.components:
		var c: SimComponent = w.components[id]
		if c.type == &"fan":
			fan_rpm = c.state.rpm
		if c.type == &"pump":
			pump_flow = c.state.flow
		check(c.state.status != &"error", "%s has no error (%s)" % [c.display_name(), c.state.status_text])
	check(fan_rpm > 100.0, "fan turns in the demo")
	check(pump_flow > 0.0, "pump runs in the demo")


## Full loop through the real workshop scene (see tests/workshop_loop_test.gd,
## loaded at runtime because it uses classes that depend on the autoloads).
func test_workshop_gameplay_loop() -> void:
	var script: GDScript = load("res://tests/workshop_loop_test.gd")
	check(script != null and script.can_instantiate(), "workshop_loop_test.gd compiles")
	if script == null or not script.can_instantiate():
		return
	var t: RefCounted = script.new()
	await t.run(self)


func _click_world(cam: Camera3D, point: Vector3) -> void:
	await _click_screen(cam.unproject_position(point))


## `pos` is in viewport (logical) coordinates; events are sent in window
## coordinates like real mouse input, so the stretch transform is applied.
func _click_screen(pos: Vector2) -> void:
	pos = root.get_final_transform() * pos
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.warp_mouse(pos)
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = pos
		ev.global_position = pos
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await process_frame
