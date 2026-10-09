class_name NxEmptyState
extends VBoxContainer
## Centered placeholder shown when a list or panel has nothing to display.


func _init(icon_name: String = "info", title: String = "", message: String = "") -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", NxPalette.SPACE_S)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var icon := TextureRect.new()
	icon.texture = NxIcons.get_icon(icon_name)
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = NxPalette.TEXT_DIM
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(icon)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", NxPalette.TEXT_MUTED)
	add_child(title_label)

	if not message.is_empty():
		var message_label := Label.new()
		message_label.theme_type_variation = &"CaptionLabel"
		message_label.text = message
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message_label.custom_minimum_size.x = 180
		message_label.add_theme_color_override("font_color", NxPalette.TEXT_DIM)
		add_child(message_label)
