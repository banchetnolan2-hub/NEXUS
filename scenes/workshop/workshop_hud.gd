class_name WorkshopHUD
extends Control
## Workshop interface layout: toolbar on top, library on the left, inspector
## on the right, status bar at the bottom and a contextual hint above the 3D
## view. The centre area lets the mouse through to the 3D world.
##
## Each part lives in scenes/workshop/hud/; this script only assembles them.

signal menu_requested
signal save_requested
signal settings_requested
signal help_requested

const P := preload("res://ui/theme/nx_palette.gd")

var library: NxSidePanel
var inspector: NxSidePanel
var toolbar: WorkshopToolbar
var status_bar: WorkshopStatusBar
var library_panel := LibraryPanel.new()
var inspector_panel := InspectorPanel.new()
## The empty centre area above the 3D view.
var viewport_area: Control

var _controller: BuildController
var _hint_label: Label
var _hint_panel: PanelContainer


func bind(controller: BuildController, runner: SimulationRunner, thumbnails: NxThumbnails) -> void:
	_controller = controller
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	toolbar = WorkshopToolbar.new()
	toolbar.bind(controller, runner)
	toolbar.menu_requested.connect(func() -> void: menu_requested.emit())
	toolbar.save_requested.connect(func() -> void: save_requested.emit())
	toolbar.settings_requested.connect(func() -> void: settings_requested.emit())
	toolbar.help_requested.connect(func() -> void: help_requested.emit())
	toolbar.library_toggle_requested.connect(toggle_library)
	toolbar.inspector_toggle_requested.connect(toggle_inspector)
	column.add_child(toolbar)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_theme_constant_override("separation", 10)
	column.add_child(middle)

	library = NxSidePanel.new("Bibliothèque", "layers", NxSidePanel.Side.LEFT, 312)
	library.shortcut_hint = "Ctrl+L"
	library_panel.build(library.get_content(), controller, thumbnails)
	middle.add_child(library)

	viewport_area = Control.new()
	viewport_area.name = "ViewportArea"
	viewport_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_area.mouse_filter = Control.MOUSE_FILTER_PASS
	viewport_area.mouse_entered.connect(func() -> void: controller.pointer_in_view = true)
	viewport_area.mouse_exited.connect(func() -> void:
		controller.pointer_in_view = false
		controller.view.set_hovered(-1)
		if controller.tool == BuildController.Tool.PLACE:
			controller.view.hide_ghost())
	middle.add_child(viewport_area)
	_build_hint(viewport_area)

	inspector = NxSidePanel.new("Inspecteur", "info", NxSidePanel.Side.RIGHT, 320, true)
	inspector.shortcut_hint = "Ctrl+I"
	inspector_panel.build(inspector.get_content(), controller, runner)
	middle.add_child(inspector)

	status_bar = WorkshopStatusBar.new()
	status_bar.bind(runner, controller.world)
	column.add_child(status_bar)

	library.collapsed_changed.connect(func(c: bool) -> void: toolbar.library_toggle.set_pressed_no_signal(not c))
	inspector.collapsed_changed.connect(func(c: bool) -> void: toolbar.inspector_toggle.set_pressed_no_signal(not c))
	controller.hint_changed.connect(_on_hint)
	_on_hint(controller.current_hint())
	controller.selection_changed.connect(func(id: int) -> void:
		if id != -1 and inspector.collapsed:
			inspector.set_collapsed(false))
	_adapt_to_width()
	get_viewport().size_changed.connect(_adapt_to_width)


func _process(delta: float) -> void:
	inspector_panel.process(delta)


func toggle_library() -> void:
	library.toggle()


func toggle_inspector() -> void:
	inspector.toggle()


## On narrow windows, keep only one panel open so the 3D view stays usable.
func _adapt_to_width() -> void:
	var width := get_viewport_rect().size.x
	if width < 1180 and not library.collapsed and not inspector.collapsed:
		library.set_collapsed(true, false)


func _build_hint(area: Control) -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.theme_type_variation = &"HintPanel"
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.offset_bottom = -6
	area.add_child(_hint_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(row)
	row.add_child(NxHud.icon_rect("mouse", 15, P.ACCENT))
	_hint_label = Label.new()
	_hint_label.theme_type_variation = &"CaptionLabel"
	_hint_label.add_theme_color_override("font_color", P.TEXT)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_hint_label)


func _on_hint(text: String) -> void:
	_hint_label.text = text
	_hint_panel.visible = not text.is_empty()
	var warn := text.begins_with("Placement impossible") or text.begins_with("Déplacement impossible") \
		or text.begins_with("Connexion incompatible") or text.begins_with("Reliez une sortie") \
		or text.contains("déjà")
	_hint_label.add_theme_color_override("font_color", P.WARNING if warn else P.TEXT)
	# Re-centre after the text width changed.
	_hint_panel.reset_size()
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 6)
