class_name NxSidePanel
extends PanelContainer
## Collapsible side panel (component library, inspector...).
##
## Build it from code, then fill `get_content()`. When collapsed the panel
## shrinks to a thin strip that only shows its icon button, so the 3D view
## gets the space back.

signal collapsed_changed(collapsed: bool)

enum Side { LEFT, RIGHT }

const P := preload("res://ui/theme/nx_palette.gd")
const COLLAPSED_WIDTH := 52.0

var title := ""
var icon_name := ""
var side: int = Side.LEFT
var expanded_width := 300.0
var collapsed := false
## Shortcut text appended to the collapse button tooltip, e.g. "Ctrl+L".
var shortcut_hint := ""
## Wraps the content in a vertical scroll area (for panels whose content can
## exceed the screen height). Leave false when the content scrolls itself.
var scrollable := false

var _content: VBoxContainer
var _title_box: HBoxContainer
var _toggle: Button
var _body: Control
var _separator: HSeparator
var _collapsed_icon: Button
var _tween: Tween


func _init(p_title: String = "", p_icon: String = "", p_side: int = Side.LEFT, p_width: float = 300.0,
		p_scrollable: bool = false) -> void:
	title = p_title
	icon_name = p_icon
	side = p_side
	expanded_width = p_width
	scrollable = p_scrollable
	theme_type_variation = &"SidePanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build()


func _build() -> void:
	custom_minimum_size.x = expanded_width
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	var header_margin := MarginContainer.new()
	for m in ["margin_left", "margin_right"]:
		header_margin.add_theme_constant_override(m, P.SPACE_M)
	header_margin.add_theme_constant_override("margin_top", 10)
	header_margin.add_theme_constant_override("margin_bottom", 10)
	column.add_child(header_margin)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", P.SPACE_S)
	header_margin.add_child(header)

	_title_box = HBoxContainer.new()
	_title_box.add_theme_constant_override("separation", 10)
	_title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := TextureRect.new()
	icon.texture = NxIcons.get_icon(icon_name)
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = P.ACCENT
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title_box.add_child(icon)
	var title_label := Label.new()
	title_label.text = title
	title_label.theme_type_variation = &"TitleLabel"
	title_label.add_theme_font_size_override("font_size", P.FONT_BODY)
	_title_box.add_child(title_label)
	header.add_child(_title_box)

	# Icon shown alone when collapsed; clicking it expands the panel.
	_collapsed_icon = Button.new()
	_collapsed_icon.theme_type_variation = &"ToolButton"
	_collapsed_icon.icon = NxIcons.get_icon(icon_name)
	_collapsed_icon.visible = false
	_collapsed_icon.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_collapsed_icon.pressed.connect(func() -> void: set_collapsed(false))
	header.add_child(_collapsed_icon)

	_toggle = Button.new()
	_toggle.theme_type_variation = &"ToolButton"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.pressed.connect(func() -> void: set_collapsed(true))
	header.add_child(_toggle)
	if side == Side.RIGHT:
		header.move_child(_toggle, 0)

	_separator = HSeparator.new()
	column.add_child(_separator)

	var body_margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		body_margin.add_theme_constant_override(m, P.SPACE_M)
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body_margin)
	_body = body_margin

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", P.SPACE_M)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if scrollable:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_margin.add_child(scroll)
		_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_content)
	else:
		body_margin.add_child(_content)


func _ready() -> void:
	_refresh_tooltips()


func get_content() -> VBoxContainer:
	return _content


func toggle() -> void:
	set_collapsed(not collapsed)


func set_collapsed(value: bool, animate: bool = true) -> void:
	if collapsed == value:
		return
	collapsed = value
	var target := COLLAPSED_WIDTH if collapsed else expanded_width
	if _tween and _tween.is_valid():
		_tween.kill()
	if collapsed:
		_set_expanded_visuals(false)
	var duration := UI.anim_time(P.ANIM_NORMAL) if animate else 0.0
	if duration <= 0.0:
		custom_minimum_size.x = target
		size.x = target
		_set_expanded_visuals(not collapsed)
	else:
		_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_method(_set_width, size.x, target, duration)
		if not collapsed:
			_tween.tween_callback(_set_expanded_visuals.bind(true))
	collapsed_changed.emit(collapsed)


func _set_width(w: float) -> void:
	custom_minimum_size.x = w
	size.x = w


func _set_expanded_visuals(expanded: bool) -> void:
	_title_box.visible = expanded
	_toggle.visible = expanded
	_separator.visible = expanded
	_body.visible = expanded
	_collapsed_icon.visible = not expanded
	_refresh_tooltips()


func _refresh_tooltips() -> void:
	var hint := " (%s)" % shortcut_hint if not shortcut_hint.is_empty() else ""
	var arrow := "chevron_left" if side == Side.LEFT else "chevron_right"
	_toggle.icon = NxIcons.get_icon(arrow)
	UI.set_tooltip(_toggle, "Réduire le panneau" + hint)
	UI.set_tooltip(_collapsed_icon, "Afficher : %s%s" % [title, hint])
