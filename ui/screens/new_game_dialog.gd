extends NxDialog
## "Nouvelle partie": workshop name and starting template.

signal confirmed(name: String, template: StringName)

var _name_edit: LineEdit
var _group := ButtonGroup.new()
var _template := &"empty"


func _init() -> void:
	super("Nouvelle partie", 560)
	title_icon = "plus"
	var label := Label.new()
	label.text = "Nom de l'atelier"
	label.theme_type_variation = &"MutedLabel"
	add_content(label)
	_name_edit = LineEdit.new()
	_name_edit.text = Game.DEFAULT_NAME
	_name_edit.max_length = 48
	_name_edit.select_all_on_focus = true
	_name_edit.text_submitted.connect(func(_t: String) -> void: _confirm())
	add_content(_name_edit)

	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	add_content(gap)
	var tlabel := Label.new()
	tlabel.text = "Point de départ"
	tlabel.theme_type_variation = &"MutedLabel"
	add_content(tlabel)
	for t in NxTemplates.TEMPLATES:
		add_content(_template_card(t))

	add_button("Annuler", NxDialog.GHOST)
	add_button("Créer l'atelier", NxDialog.PRIMARY, _confirm, true, "arrow_right")


func _template_card(t: Dictionary) -> Button:
	var card := Button.new()
	card.theme_type_variation = &"LibraryCard"
	card.toggle_mode = true
	card.button_group = _group
	card.button_pressed = t.id == _template
	card.custom_minimum_size.y = 84
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(func() -> void: _template = t.id)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(NxHud.badge(t.icon, NxPalette.ACCENT, 22, 9))
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := Label.new()
	title.text = t.name
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var desc := Label.new()
	desc.text = t.description
	desc.theme_type_variation = &"CaptionLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(desc)
	return card


func _ready() -> void:
	super()
	_name_edit.grab_focus.call_deferred()


func _confirm() -> void:
	var n := _name_edit.text.strip_edges()
	if n.is_empty():
		n = Game.DEFAULT_NAME
	confirmed.emit(n, _template)
	close(n)
