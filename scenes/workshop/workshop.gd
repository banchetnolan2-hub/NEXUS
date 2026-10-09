extends Node3D
## Workshop: the main game screen.
##
## Wires the pure simulation (SimWorld + SimulationRunner) to its 3D mirror
## (WorldView), the construction tools (BuildController), the camera and the
## HUD. Game.workshop_data holds the serialized installation between saves.

const PauseMenu := preload("res://scenes/workshop/pause_menu.gd")
const SettingsScreen := preload("res://ui/screens/settings_screen.gd")
const HelpDialog := preload("res://scenes/workshop/hud/help_dialog.gd")

@onready var _hud: WorkshopHUD = %WorkshopHUD
@onready var _camera: WorkshopCamera = %Camera
@onready var _sun: DirectionalLight3D = %Sun
@onready var _floor: MeshInstance3D = %Floor

var world: SimWorld
var runner: SimulationRunner
var controller: BuildController
var view: WorldView
var thumbnails: NxThumbnails


func _ready() -> void:
	if not Game.has_session():
		Game.new_session()
	_floor.material_override = NxMaterials.grid_floor()
	_sun.rotation_degrees = Vector3(-55, 32, 0)

	world = SimWorld.deserialize(Game.workshop_data.get("world", {}))
	runner = SimulationRunner.new()
	runner.name = "Simulation"
	runner.world = world
	add_child(runner)

	view = WorldView.new()
	view.name = "WorldView"
	add_child(view)
	view.set_world(world)

	controller = BuildController.new()
	controller.name = "BuildController"
	add_child(controller)
	controller.setup(world, view, _camera)
	controller.edited.connect(_on_edited)

	thumbnails = NxThumbnails.new()
	thumbnails.name = "Thumbnails"
	add_child(thumbnails)

	_camera.restore(Game.workshop_data.get("camera", {}))
	_hud.bind(controller, runner, thumbnails)
	_hud.menu_requested.connect(open_pause_menu)
	_hud.save_requested.connect(save)
	_hud.settings_requested.connect(open_settings)
	_hud.help_requested.connect(open_help)

	# Statuses reflect the installation before the first run.
	world.step(0.0)
	if not world.load_warnings.is_empty():
		UI.toast("Certains éléments de la sauvegarde ont été ignorés (%d)." % world.load_warnings.size(), &"warning", 6.0)
		for w in world.load_warnings:
			push_warning(w)
	# Unsaved changes are protected when the window is closed.
	get_tree().auto_accept_quit = false


func _exit_tree() -> void:
	get_tree().auto_accept_quit = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if UI.has_open_dialog() or UI.is_transitioning():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var handled := true
	if key.keycode == KEY_ESCAPE:
		open_pause_menu()
	elif key.keycode == KEY_SPACE and not key.ctrl_pressed:
		runner.toggle()
	elif key.keycode == KEY_F1:
		open_help()
	elif key.ctrl_pressed and key.keycode == KEY_S:
		save()
	elif key.ctrl_pressed and key.keycode == KEY_R:
		runner.reset()
	elif key.ctrl_pressed and key.keycode == KEY_L:
		_hud.toggle_library()
	elif key.ctrl_pressed and key.keycode == KEY_I:
		_hud.toggle_inspector()
	elif key.ctrl_pressed and key.keycode == KEY_F:
		if _hud.library.collapsed:
			_hud.library.set_collapsed(false)
		_hud.library_panel.focus_search()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# -----------------------------------------------------------------------------
# Actions
# -----------------------------------------------------------------------------

func save() -> void:
	var result := Game.save_session(serialize())
	if result.ok:
		UI.toast("Atelier « %s » enregistré." % Game.session_name, &"success")
	else:
		UI.show_error("Enregistrement impossible", result.error +
			"\n\nVotre précédente sauvegarde n'a pas été modifiée.")


## Workshop content stored in the save file.
func serialize() -> Dictionary:
	return { "world": world.serialize(), "camera": _camera.serialize() }


func open_pause_menu() -> void:
	if UI.has_open_dialog():
		return
	if runner.is_running():
		runner.pause()
	var menu := PauseMenu.new()
	menu.save_requested.connect(save)
	menu.settings_requested.connect(open_settings)
	menu.main_menu_requested.connect(request_main_menu)
	menu.quit_requested.connect(request_quit)
	UI.open_dialog(menu)


func open_settings() -> void:
	UI.open_dialog(SettingsScreen.new())


func open_help() -> void:
	if not UI.has_open_dialog():
		UI.open_dialog(HelpDialog.new())


func request_main_menu() -> void:
	_leave(func() -> void: UI.change_scene(Game.MENU_SCENE))


func request_quit() -> void:
	_leave(func() -> void: get_tree().quit())


func _on_edited() -> void:
	Game.workshop_data = serialize()
	Game.mark_dirty()


## Runs `action` directly, or after confirmation if there are unsaved changes.
func _leave(action: Callable) -> void:
	if not Game.dirty:
		action.call()
		return
	var dialog := NxDialog.new("Modifications non enregistrées", 480)
	dialog.title_icon = "warning"
	dialog.add_text("« %s » contient des modifications qui n'ont pas été enregistrées." % Game.session_name)
	dialog.add_button("Annuler", NxDialog.GHOST)
	dialog.add_footer_spacer()
	dialog.add_button("Quitter sans enregistrer", NxDialog.DANGER, action)
	dialog.add_button("Enregistrer et quitter", NxDialog.PRIMARY, func() -> void:
		save()
		if not Game.dirty:
			action.call())
	UI.open_dialog(dialog)
