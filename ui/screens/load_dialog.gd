extends NxDialog
## Lists the saves and lets the player open or delete one.
##
## Damaged saves stay listed (with the reason) so they are never silently lost.

signal save_chosen(path: String)

var _list: VBoxContainer
var _selected_path := ""
var _open_button: Button
var _delete_button: Button
var _group := ButtonGroup.new()


func _init() -> void:
	super("Charger une sauvegarde", 620)
	title_icon = "folder_open"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 320
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_content(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_delete_button = add_button("Supprimer", NxDialog.GHOST, _on_delete, true, "trash")
	add_footer_spacer()
	add_button("Annuler", NxDialog.GHOST)
	_open_button = add_button("Ouvrir", NxDialog.PRIMARY, _on_open, true)


func _ready() -> void:
	super()
	_populate()


func _populate() -> void:
	for child in _list.get_children():
		child.queue_free()
	_selected_path = ""
	var saves := SaveManager.list_saves()
	if saves.is_empty():
		_list.add_child(NxEmptyState.new("folder_open", "Aucune sauvegarde",
			"Les ateliers enregistrés apparaîtront ici. Créez une nouvelle partie puis enregistrez-la avec Ctrl+S."))
	for info in saves:
		_list.add_child(_make_entry(info))
	_update_buttons()
	# Preselect the most recent valid save.
	for button in _group.get_buttons():
		if not button.disabled:
			button.button_pressed = true
			_selected_path = button.get_meta(&"path")
			_update_buttons()
			break


func _make_entry(info: Dictionary) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _group
	button.theme_type_variation = &"NavButton"
	button.custom_minimum_size.y = 58
	button.set_meta(&"path", info.path)
	button.icon = NxIcons.get_icon("file" if info.valid else "warning")
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = " "  # Text drawn by the child labels below.
	button.pressed.connect(func() -> void:
		_selected_path = info.path
		_update_buttons())
	button.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT and info.valid:
			_selected_path = info.path
			_on_open())

	var labels := VBoxContainer.new()
	labels.set_anchors_preset(Control.PRESET_FULL_RECT)
	labels.offset_left = 46
	labels.offset_right = -12
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.add_theme_constant_override("separation", 2)
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(labels)

	var name_label := Label.new()
	name_label.text = info.name
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(name_label)

	var detail := Label.new()
	detail.theme_type_variation = &"CaptionLabel"
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if info.valid:
		detail.text = "Modifiée %s" % NxFormat.relative_time(info.modified)
	else:
		detail.text = "Illisible : %s" % info.error
		detail.add_theme_color_override("font_color", NxPalette.WARNING)
		button.add_theme_color_override("icon_normal_color", NxPalette.WARNING)
	labels.add_child(detail)
	return button


func _update_buttons() -> void:
	var info := _selected_info()
	_open_button.disabled = info.is_empty() or not info.valid
	_delete_button.disabled = info.is_empty()


func _selected_info() -> Dictionary:
	if _selected_path.is_empty():
		return {}
	for info in SaveManager.list_saves():
		if info.path == _selected_path:
			return info
	return {}


func _on_open() -> void:
	var info := _selected_info()
	if info.is_empty() or not info.valid:
		return
	save_chosen.emit(info.path)
	close(info.path)


func _on_delete() -> void:
	var info := _selected_info()
	if info.is_empty():
		return
	UI.confirm("Supprimer la sauvegarde ?",
		"« %s » sera définitivement supprimée. Cette action est irréversible." % info.name,
		"Supprimer", func() -> void:
			if SaveManager.delete_save(info.path):
				UI.toast("Sauvegarde supprimée.", &"success")
			else:
				UI.toast("La sauvegarde n'a pas pu être supprimée.", &"error")
			_populate())
