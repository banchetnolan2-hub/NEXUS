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
	settings.autosave = false
	settings.set_value(&"interface/reduce_motion", true)

	change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	await _frames(90)
	await _shot("01_main_menu")

	ui.open_dialog(load("res://ui/screens/settings_screen.gd").new())
	await _frames(20)
	await _shot("02_settings")
	ui.close_all_dialogs()
	await _frames(10)

	ui.open_dialog(load("res://ui/screens/load_dialog.gd").new())
	await _frames(20)
	await _shot("03_load_dialog")
	ui.close_all_dialogs()
	await _frames(10)

	root.get_node("Game").new_session()
	change_scene_to_file("res://scenes/workshop/workshop.tscn")
	await _frames(60)
	ui.toast("Atelier « Atelier sans titre » enregistré.", &"success")
	await _frames(20)
	await _shot("04_workshop")

	current_scene.open_pause_menu()
	await _frames(20)
	await _shot("05_pause_menu")
	ui.close_all_dialogs()
	await _frames(10)

	var hud: Node = current_scene.get_node("%WorkshopHUD")
	hud.library.set_collapsed(true, false)
	hud.inspector.set_collapsed(true, false)
	await _frames(20)
	await _shot("06_workshop_collapsed")

	change_scene_to_file("res://scenes/dev/ui_gallery.tscn")
	await _frames(40)
	await _shot("07_ui_gallery")
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
