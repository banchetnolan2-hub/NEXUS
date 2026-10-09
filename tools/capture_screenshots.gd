extends SceneTree
## Captures reference screenshots of the main screens (visual review / docs).
## Usage (needs a display, e.g. xvfb-run on Linux):
##   godot --path . -s res://tools/capture_screenshots.gd -- <output_dir>

var _out := "user://screenshots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var ui: Node = root.get_node("UI")
	var settings: Node = root.get_node("Settings")
	var game: Node = root.get_node("Game")
	settings.autosave = false
	settings.set_value(&"interface/reduce_motion", true)

	change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	await _frames(90)
	await _shot("01_main_menu")

	ui.open_dialog(load("res://ui/screens/new_game_dialog.gd").new())
	await _frames(20)
	await _shot("02_new_game")
	ui.close_all_dialogs()
	await _frames(10)

	ui.open_dialog(load("res://ui/screens/settings_screen.gd").new())
	await _frames(20)
	await _shot("03_settings")
	ui.close_all_dialogs()
	await _frames(10)

	# Demo workshop, running.
	game.new_session("Exemple", &"demo")
	change_scene_to_file("res://scenes/workshop/workshop.tscn")
	await _frames(120)  # Thumbnails render.
	var ws: Node = current_scene
	ws.runner.start()
	ws.runner.set_speed(4.0)
	await _frames(90)
	await _shot("04_workshop_running")

	# Selection + inspector.
	var pump_id := -1
	for id in ws.world.components:
		if ws.world.components[id].type == &"pump":
			pump_id = id
	ws.controller.select(pump_id)
	await _frames(20)
	await _shot("05_inspector_pump")

	# Connection tool.
	ws.controller.select(-1)
	ws.controller.set_tool(1 + 1)  # CONNECT
	await _frames(10)
	await _shot("06_connection_tool")

	# Placement ghost (valid then invalid).
	ws.runner.pause()
	ws.controller.begin_place(&"motor")
	ws.controller.view.show_ghost(&"motor", Vector2i(6, -2), 0, true)
	ws.controller.view.show_ghost(&"tank", Vector2i(-3, 2), 0, false)
	await _frames(10)
	await _shot("07_placement_ghost")
	ws.controller.set_tool(0)

	ws.open_help()
	await _frames(20)
	await _shot("08_help")
	ui.close_all_dialogs()
	await _frames(10)

	game.new_session("Atelier sans titre", &"empty")
	change_scene_to_file("res://scenes/workshop/workshop.tscn")
	await _frames(60)
	await _shot("09_workshop_empty")

	change_scene_to_file("res://scenes/dev/ui_gallery.tscn")
	await _frames(40)
	await _shot("10_ui_gallery")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := _out.path_join(shot_name + ".png")
	img.save_png(path)
	print("saved ", path)
