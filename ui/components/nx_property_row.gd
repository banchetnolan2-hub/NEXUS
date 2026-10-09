class_name NxPropertyRow
extends HBoxContainer
## Read-only "name ........ value" line used by inspectors.

var name_label: Label
var value_label: Label


func _init(property_name: String = "", value_text: String = "") -> void:
	add_theme_constant_override("separation", NxPalette.SPACE_M)
	name_label = Label.new()
	name_label.theme_type_variation = &"MutedLabel"
	name_label.text = property_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	add_child(name_label)

	value_label = Label.new()
	value_label.theme_type_variation = &"ValueLabel"
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(value_label)


func set_value_text(text: String, color: Color = NxPalette.TEXT) -> void:
	value_label.text = text
	value_label.add_theme_color_override("font_color", color)
