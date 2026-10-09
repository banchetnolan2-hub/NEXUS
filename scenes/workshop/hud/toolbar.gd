class_name WorkshopToolbar
extends PanelContainer
## Top bar: menu, workshop name, save/undo, construction tools, simulation
## controls and panel toggles.

signal menu_requested
signal save_requested
signal settings_requested
signal help_requested
signal library_toggle_requested
signal inspector_toggle_requested

const P := preload("res://ui/theme/nx_palette.gd")

var library_toggle: Button
var inspector_toggle: Button

var _controller: BuildController
var _runner: SimulationRunner
var _name_label: Label
var _dirty_dot: Label
var _undo: Button
var _redo: Button
var _tool_select: Button
var _tool_connect: Button
var _play: Button
var _reset: Button
var _speed_buttons: Array[Button] = []


func _init() -> void:
	theme_type_variation = &"BarPanel"


func bind(controller: BuildController, runner: SimulationRunner) -> void:
	_controller = controller
	_runner = runner
	_build()
	controller.tool_changed.connect(func(_t: int, _p: StringName) -> void: _refresh_tools())
	controller.undo_stack.changed.connect(_refresh_undo)
	runner.state_changed.connect(func(_s: int) -> void: _refresh_sim())
	runner.speed_changed.connect(func(_s: float) -> void: _refresh_sim())
	Game.dirty_changed.connect(func(_d: bool) -> void: _refresh_session())
	Game.session_changed.connect(_refresh_session)
	_refresh_tools()
	_refresh_undo()
	_refresh_sim()
	_refresh_session()


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)

	row.add_child(NxHud.tool_button("menu", "Menu (Échap)", func() -> void: menu_requested.emit()))
	row.add_child(NxHud.separator())

	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	title.add_child(NxHud.icon_rect("blueprint", 18, P.ACCENT))
	_name_label = Label.new()
	_name_label.theme_type_variation = &"TitleLabel"
	_name_label.add_theme_font_size_override("font_size", P.FONT_BODY)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.custom_minimum_size.x = 150
	title.add_child(_name_label)
	_dirty_dot = Label.new()
	_dirty_dot.text = "●"
	_dirty_dot.add_theme_color_override("font_color", P.WARNING)
	_dirty_dot.add_theme_font_size_override("font_size", 10)
	_dirty_dot.mouse_filter = Control.MOUSE_FILTER_PASS
	UI.set_tooltip(_dirty_dot, "Modifications non enregistrées")
	title.add_child(_dirty_dot)
	row.add_child(title)

	row.add_child(NxHud.separator())
	row.add_child(NxHud.tool_button("save", "Enregistrer (Ctrl+S)", func() -> void: save_requested.emit()))
	_undo = NxHud.tool_button("undo", "Annuler (Ctrl+Z)", func() -> void: _controller.undo())
	_redo = NxHud.tool_button("redo", "Rétablir (Ctrl+Y)", func() -> void: _controller.redo())
	row.add_child(_undo)
	row.add_child(_redo)

	row.add_child(NxHud.spacer())

	# Construction tools.
	var tools := _segment_group()
	_tool_select = _segment(tools, "cursor", "Sélection", "Sélection (V)\nCliquer pour sélectionner, glisser pour déplacer.")
	_tool_select.pressed.connect(func() -> void: _controller.set_tool(BuildController.Tool.SELECT))
	_tool_connect = _segment(tools, "link", "Connexion", "Connexion (C)\nCliquer sur un port puis sur un port compatible.")
	_tool_connect.pressed.connect(func() -> void: _controller.set_tool(BuildController.Tool.CONNECT))
	row.add_child(tools.get_parent())

	row.add_child(NxHud.separator())

	# Simulation.
	_play = Button.new()
	_play.theme_type_variation = &"PlayButton"
	_play.focus_mode = Control.FOCUS_NONE
	_play.custom_minimum_size.x = 104
	_play.pressed.connect(func() -> void: _runner.toggle())
	row.add_child(_play)
	_reset = NxHud.tool_button("reset", "Réinitialiser la simulation (Ctrl+R)\nRevient à l'état d'avant le lancement.",
		func() -> void: _runner.reset())
	row.add_child(_reset)
	var speeds := _segment_group()
	for i in SimulationRunner.SPEEDS.size():
		var value: float = SimulationRunner.SPEEDS[i]
		var b := _segment(speeds, "", "×%d" % int(value), "Vitesse de simulation ×%d" % int(value))
		b.pressed.connect(func() -> void: _runner.set_speed(value))
		_speed_buttons.append(b)
	row.add_child(speeds.get_parent())

	row.add_child(NxHud.spacer())

	row.add_child(NxHud.tool_button("info", "Aide et contrôles (F1)", func() -> void: help_requested.emit()))
	library_toggle = NxHud.tool_button("panel_left", "Bibliothèque (Ctrl+L)", func() -> void: library_toggle_requested.emit())
	library_toggle.toggle_mode = true
	library_toggle.button_pressed = true
	row.add_child(library_toggle)
	inspector_toggle = NxHud.tool_button("panel_right", "Inspecteur (Ctrl+I)", func() -> void: inspector_toggle_requested.emit())
	inspector_toggle.toggle_mode = true
	inspector_toggle.button_pressed = true
	row.add_child(inspector_toggle)
	row.add_child(NxHud.separator())
	row.add_child(NxHud.tool_button("settings", "Paramètres", func() -> void: settings_requested.emit()))


func _segment_group() -> HBoxContainer:
	var group := PanelContainer.new()
	group.theme_type_variation = &"SegmentGroup"
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	group.add_child(box)
	return box


func _segment(box: HBoxContainer, icon_name: String, text: String, tip: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"SegmentButton"
	b.text = text
	if not icon_name.is_empty():
		b.icon = NxIcons.get_icon(icon_name)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	UI.set_tooltip(b, tip)
	box.add_child(b)
	return b


func _refresh_tools() -> void:
	_tool_select.set_pressed_no_signal(_controller.tool != BuildController.Tool.CONNECT)
	_tool_connect.set_pressed_no_signal(_controller.tool == BuildController.Tool.CONNECT)


func _refresh_undo() -> void:
	var stack := _controller.undo_stack
	_undo.disabled = not stack.can_undo()
	_redo.disabled = not stack.can_redo()
	UI.set_tooltip(_undo, "Annuler (Ctrl+Z)" + ("\n" + stack.undo_label() if stack.can_undo() else ""))
	UI.set_tooltip(_redo, "Rétablir (Ctrl+Y)" + ("\n" + stack.redo_label() if stack.can_redo() else ""))


func _refresh_sim() -> void:
	var running := _runner.state == SimulationRunner.State.RUNNING
	_play.text = "Pause" if running else ("Reprendre" if _runner.state == SimulationRunner.State.PAUSED else "Lancer")
	_play.icon = NxIcons.get_icon("pause" if running else "play")
	UI.set_tooltip(_play, ("Mettre en pause" if running else "Lancer la simulation") + " (Espace)")
	_reset.disabled = _runner.state == SimulationRunner.State.STOPPED
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(is_equal_approx(SimulationRunner.SPEEDS[i], _runner.speed))


func _refresh_session() -> void:
	_name_label.text = Game.session_name
	_dirty_dot.visible = Game.dirty
