class_name NxHud
extends RefCounted
## Small builders shared by the workshop HUD modules.

const P := preload("res://ui/theme/nx_palette.gd")


static func tool_button(icon_name: String, tip: String, action: Callable = Callable(),
		variation: StringName = &"ToolButton") -> Button:
	var button := Button.new()
	button.theme_type_variation = variation
	button.icon = NxIcons.get_icon(icon_name)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	UI.set_tooltip(button, tip)
	if action.is_valid():
		button.pressed.connect(action)
	return button


static func separator() -> Control:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(9, 22)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return sep


static func spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


static func section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.uppercase = true
	label.theme_type_variation = &"SectionLabel"
	return label


static func icon_rect(icon_name: String, px: float, color: Color) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = NxIcons.get_icon(icon_name)
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = color
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Coloured badge with an icon (domain colour background).
static func badge(icon_name: String, color: Color, px: float = 20.0, pad: int = 7) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		NxThemeBuilder.flat(Color(color, 0.15), P.RADIUS_M, Color.TRANSPARENT, 0, pad, pad))
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon_rect(icon_name, px, color))
	return panel


## Status pill: coloured dot + text.
static func status_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"Pill"
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)
	var dot := Label.new()
	dot.name = "Dot"
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 10)
	row.add_child(dot)
	var text := Label.new()
	text.name = "Text"
	text.theme_type_variation = &"CaptionLabel"
	row.add_child(text)
	return pill


static func set_pill(pill: PanelContainer, status: StringName, text: String) -> void:
	var col := NxComponentVisual.status_color(status)
	var row := pill.get_child(0)
	(row.get_node("Dot") as Label).add_theme_color_override("font_color", col)
	var label := row.get_node("Text") as Label
	label.text = text
	label.add_theme_color_override("font_color", col.lerp(P.TEXT, 0.35))
	pill.add_theme_stylebox_override("panel",
		NxThemeBuilder.flat(Color(col, 0.12), 11, Color.TRANSPARENT, 0, 9, 2))


## 83.4 -> "01:23"
static func format_time(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%02d:%02d" % [s / 60, s % 60]
