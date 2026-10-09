class_name NxSettingRow
extends HBoxContainer
## A settings line: title and short description on the left, control on the right.

var title_label: Label
var description_label: Label
var control_slot: HBoxContainer


func _init(title: String = "", description: String = "") -> void:
	add_theme_constant_override("separation", NxPalette.SPACE_XL)
	custom_minimum_size.y = 44

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 2)
	add_child(text_box)

	title_label = Label.new()
	title_label.text = title
	text_box.add_child(title_label)

	description_label = Label.new()
	description_label.theme_type_variation = &"CaptionLabel"
	description_label.text = description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.visible = not description.is_empty()
	text_box.add_child(description_label)

	control_slot = HBoxContainer.new()
	control_slot.alignment = BoxContainer.ALIGNMENT_END
	control_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control_slot.custom_minimum_size.x = 280
	add_child(control_slot)


func set_control(control: Control) -> Control:
	for child in control_slot.get_children():
		child.queue_free()
	if control is NxSliderField or control is OptionButton:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_slot.add_child(control)
	return control


func set_row_enabled(enabled: bool) -> void:
	modulate.a = 1.0 if enabled else 0.45
	for child in control_slot.get_children():
		if child is BaseButton:
			child.disabled = not enabled
