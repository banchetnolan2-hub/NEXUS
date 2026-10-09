class_name NxDialog
extends Control
## Modal dialog of the NEXUS design system.
##
## Layout: dimmed backdrop, centred panel with a header (title + close
## button), a body and an optional footer of buttons. Keyboard focus is kept
## inside the dialog while it is open and Escape closes it when `closable`.
##
##     var dialog := NxDialog.new("Titre", 480)
##     dialog.add_text("Message")
##     dialog.add_button("Annuler")
##     dialog.add_button("Valider", NxDialog.PRIMARY, _on_validate)
##     UI.open_dialog(dialog)

signal closed(result: Variant)

const P := preload("res://ui/theme/nx_palette.gd")

const PRIMARY := &"PrimaryButton"
const SECONDARY := &""
const GHOST := &"GhostButton"
const DANGER := &"DangerButton"

var title := "":
	set(value):
		title = value
		if _title_label:
			_title_label.text = value
## Width of the panel in pixels (before UI scaling); clamped to the screen.
var panel_width := 520.0
## Escape key, close button and backdrop clicks close the dialog.
var closable := true
## Optional icon shown before the title.
var title_icon := ""

var _panel: PanelContainer
var _body: VBoxContainer
var _footer_wrap: MarginContainer
var _footer: HBoxContainer
var _title_label: Label
var _header: HBoxContainer
var _closing := false
var _result: Variant = null


func _init(p_title: String = "", p_width: float = 520.0) -> void:
	title = p_title
	panel_width = p_width
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = P.OVERLAY
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"DialogPanel"
	center.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_panel.add_child(column)

	# Header
	var header_margin := _margin(P.SPACE_XL, P.SPACE_L, P.SPACE_M, P.SPACE_L)
	column.add_child(header_margin)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", P.SPACE_M)
	header_margin.add_child(header)
	_header = header
	_title_label = Label.new()
	_title_label.theme_type_variation = &"TitleLabel"
	_title_label.text = title
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title_label)
	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.theme_type_variation = &"ToolButton"
	close_btn.icon = NxIcons.get_icon("close")
	close_btn.tooltip_text = "Fermer (Échap)"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func() -> void: close())
	header.add_child(close_btn)

	var sep := HSeparator.new()
	column.add_child(sep)

	# Body
	var body_margin := _margin(P.SPACE_XL, P.SPACE_XL, P.SPACE_XL, P.SPACE_XL)
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body_margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", P.SPACE_M)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_child(_body)

	# Footer
	_footer_wrap = _margin(P.SPACE_XL, 0, P.SPACE_XL, P.SPACE_XL)
	_footer_wrap.visible = false
	column.add_child(_footer_wrap)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", P.SPACE_S)
	_footer_wrap.add_child(_footer)


func _ready() -> void:
	if not title_icon.is_empty():
		var icon_rect := _make_title_icon()
		_header.add_child(icon_rect)
		_header.move_child(icon_rect, 0)
	_update_width()
	get_viewport().size_changed.connect(_update_width)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_panel.pivot_offset = _panel.size * 0.5
	modulate.a = 0.0
	_panel.scale = Vector2(0.97, 0.97)
	var t := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "modulate:a", 1.0, UI.anim_time(P.ANIM_NORMAL))
	t.tween_property(_panel, "scale", Vector2.ONE, UI.anim_time(P.ANIM_NORMAL))
	_focus_first.call_deferred()


# -----------------------------------------------------------------------------
# Content API
# -----------------------------------------------------------------------------

## Container receiving the dialog content.
func get_body() -> VBoxContainer:
	return _body


func get_footer() -> HBoxContainer:
	return _footer


func add_content(control: Control) -> Control:
	_body.add_child(control)
	return control


func add_text(text: String, variation: StringName = &"MutedLabel") -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 200
	_body.add_child(label)
	return label


## Adds a footer button. The dialog closes after `callback` unless `keep_open`.
func add_button(text: String, variation: StringName = SECONDARY, callback: Callable = Callable(),
		keep_open: bool = false, icon_name: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(110, 38)
	if not icon_name.is_empty():
		button.icon = NxIcons.get_icon(icon_name)
	button.pressed.connect(func() -> void:
		if callback.is_valid():
			callback.call()
		if not keep_open:
			close(text))
	_footer.add_child(button)
	_footer_wrap.visible = true
	return button


## Adds a flexible spacer to the footer (to push buttons apart).
func add_footer_spacer() -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(spacer)
	_footer_wrap.visible = true


func close(result: Variant = null) -> void:
	if _closing:
		return
	_closing = true
	_result = result
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_parallel().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "modulate:a", 0.0, UI.anim_time(P.ANIM_FAST))
	t.tween_property(_panel, "scale", Vector2(0.98, 0.98), UI.anim_time(P.ANIM_FAST))
	t.chain().tween_callback(_finish_close)


func is_closing() -> bool:
	return _closing


# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------

func _finish_close() -> void:
	closed.emit(_result)
	queue_free()


func _gui_input(event: InputEvent) -> void:
	# Clicking the dimmed backdrop closes a closable dialog.
	if closable and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not _panel.get_global_rect().has_point(event.global_position):
		accept_event()
		close()


func _input(event: InputEvent) -> void:
	# _input (not _unhandled_input) so the dialog wins over the scene below,
	# which is later in the tree and would otherwise receive Escape first.
	if _closing or not UI.is_top_dialog(self):
		return
	if event.is_action_pressed("ui_cancel", false, true):
		get_viewport().set_input_as_handled()
		if closable:
			close()


func _update_width() -> void:
	var available := get_viewport_rect().size.x - P.SPACE_XXL * 2
	_panel.custom_minimum_size.x = minf(panel_width, available)


func _on_focus_changed(control: Control) -> void:
	# Keep keyboard focus inside the top-most dialog.
	if _closing or control == null or not UI.is_top_dialog(self):
		return
	if not is_ancestor_of(control):
		_focus_first.call_deferred()


func _focus_first() -> void:
	if _closing or not is_inside_tree():
		return
	var target := _find_focusable(_body)
	if target == null:
		target = _find_focusable(_footer, true)
	if target:
		target.grab_focus()


func _find_focusable(root: Node, prefer_last: bool = false) -> Control:
	var found: Control = null
	for child in root.get_children():
		if child is Control and child.is_visible_in_tree():
			if child.focus_mode == Control.FOCUS_ALL and not (child is BaseButton and child.disabled):
				if not prefer_last:
					return child
				found = child
			var nested := _find_focusable(child, prefer_last)
			if nested:
				if not prefer_last:
					return nested
				found = nested
	return found


func _make_title_icon() -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = NxIcons.get_icon(title_icon)
	rect.custom_minimum_size = Vector2(20, 20)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = P.ACCENT
	return rect


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	return m
