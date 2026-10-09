extends Node3D
## Workshop: the main game screen (3D world + HUD).
##
## Step 1 provides the layout, saving and navigation. Camera controls, the
## placement grid and components arrive in the next steps.

const PauseMenu := preload("res://scenes/workshop/pause_menu.gd")
const SettingsScreen := preload("res://ui/screens/settings_screen.gd")

@onready var _hud: WorkshopHUD = %WorkshopHUD
@onready var _camera: Camera3D = %Camera
@onready var _sun: DirectionalLight3D = %Sun
@onready var _floor: MeshInstance3D = %Floor


func _ready() -> void:
	if not Game.has_session():
		Game.new_session()
	_floor.material_override = NxMaterials.grid_floor()
	_sun.rotation_degrees = Vector3(-52, 38, 0)
	_camera.look_at(Vector3.ZERO)

	_hud.menu_requested.connect(open_pause_menu)
	_hud.save_requested.connect(save)
	_hud.settings_requested.connect(open_settings)
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
	elif key.ctrl_pressed and key.keycode == KEY_S:
		save()
	elif key.ctrl_pressed and key.keycode == KEY_L:
		_hud.toggle_library()
	elif key.ctrl_pressed and key.keycode == KEY_I:
		_hud.toggle_inspector()
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


## Workshop content to store in the save file.
func serialize() -> Dictionary:
	var data := Game.workshop_data.duplicate(true)
	data["components"] = data.get("components", [])
	data["connections"] = data.get("connections", [])
	return data


func open_pause_menu() -> void:
	if UI.has_open_dialog():
		return
	var menu := PauseMenu.new()
	menu.save_requested.connect(save)
	menu.settings_requested.connect(open_settings)
	menu.main_menu_requested.connect(request_main_menu)
	menu.quit_requested.connect(request_quit)
	UI.open_dialog(menu)


func open_settings() -> void:
	UI.open_dialog(SettingsScreen.new())


func request_main_menu() -> void:
	_leave(func() -> void: UI.change_scene(Game.MENU_SCENE))


func request_quit() -> void:
	_leave(func() -> void: get_tree().quit())


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
