class_name NxKeyHint
extends HBoxContainer
## Keyboard hint: one or more key caps followed by a short label.
##     NxKeyHint.new(["Ctrl", "S"], "Enregistrer")


func _init(keys: PackedStringArray = PackedStringArray(), label_text: String = "") -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in keys:
		var cap := PanelContainer.new()
		cap.theme_type_variation = &"KeyCap"
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key_label := Label.new()
		key_label.text = key
		key_label.theme_type_variation = &"CaptionLabel"
		key_label.add_theme_color_override("font_color", NxPalette.TEXT)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(key_label)
		add_child(cap)
	if not label_text.is_empty():
		var text := Label.new()
		text.text = label_text
		text.theme_type_variation = &"CaptionLabel"
		text.add_theme_color_override("font_color", NxPalette.TEXT_DIM)
		var spacer := Control.new()
		spacer.custom_minimum_size.x = 2
		add_child(spacer)
		add_child(text)
