class_name LibraryPanel
extends RefCounted
## Fills the library side panel: search, category filters, component cards
## and a preview of the hovered/selected component. Clicking a card starts
## placing that component.

const P := preload("res://ui/theme/nx_palette.gd")

var _controller: BuildController
var _search: LineEdit
var _list: VBoxContainer
var _filter := &""
var _filter_group := ButtonGroup.new()
var _cards: Dictionary = {}        # type -> Button
var _thumbs: Dictionary = {}       # type -> TextureRect
var _preview: VBoxContainer
var _preview_type: StringName


func build(content: VBoxContainer, controller: BuildController, thumbnails: NxThumbnails) -> void:
	_controller = controller
	_search = LineEdit.new()
	_search.placeholder_text = "Rechercher un composant…"
	_search.clear_button_enabled = true
	_search.right_icon = NxIcons.get_icon("search")
	_search.text_changed.connect(func(_t: String) -> void: _refresh())
	content.add_child(_search)

	var chips := HFlowContainer.new()
	content.add_child(chips)
	chips.add_child(_chip("Tout", "", &""))
	for c in NxCatalog.CATEGORIES:
		chips.add_child(_chip(c.name, c.icon, c.id))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	content.add_child(HSeparator.new())
	_preview = VBoxContainer.new()
	_preview.add_theme_constant_override("separation", 6)
	content.add_child(_preview)

	controller.tool_changed.connect(_on_tool_changed)
	if thumbnails:
		thumbnails.thumbnail_ready.connect(_on_thumbnail)
	_refresh()
	_show_preview(&"")


func focus_search() -> void:
	_search.grab_focus()


func _chip(text: String, icon_name: String, category: StringName) -> Button:
	var chip := Button.new()
	chip.text = text
	chip.theme_type_variation = &"ChipButton"
	chip.toggle_mode = true
	chip.button_group = _filter_group
	chip.button_pressed = category == _filter
	chip.focus_mode = Control.FOCUS_NONE
	if not icon_name.is_empty():
		chip.icon = NxIcons.get_icon(icon_name)
		for item in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			chip.add_theme_color_override(item, P.domain_color(category))
	chip.pressed.connect(func() -> void:
		_filter = category
		_refresh())
	return chip


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	_cards.clear()
	_thumbs.clear()
	var query := _search.text.strip_edges().to_lower()
	var shown := 0
	for cat in NxCatalog.CATEGORIES:
		if _filter != &"" and cat.id != _filter:
			continue
		var matches: Array[StringName] = []
		for type in NxRegistry.types(cat.id):
			var d := NxRegistry.definition(type)
			var haystack := ("%s %s %s %s" % [d.name, d.description, d.function, cat.name]).to_lower()
			if query.is_empty() or haystack.contains(query):
				matches.append(type)
		if matches.is_empty():
			continue
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		var dot := ColorRect.new()
		dot.color = P.domain_color(cat.id)
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(dot)
		header.add_child(NxHud.section("%s · %d" % [cat.name, matches.size()]))
		if shown > 0:
			var gap := Control.new()
			gap.custom_minimum_size.y = 4
			_list.add_child(gap)
		_list.add_child(header)
		for type in matches:
			_list.add_child(_card(type))
			shown += 1
	if shown == 0:
		_list.add_child(NxEmptyState.new("search", "Aucun résultat",
			"Essayez un autre mot-clé ou une autre catégorie."))
	_on_tool_changed(_controller.tool, _controller.place_type if _controller.tool == BuildController.Tool.PLACE else &"")


func _card(type: StringName) -> Button:
	var d := NxRegistry.definition(type)
	var color := P.domain_color(d.category)
	var card := Button.new()
	card.theme_type_variation = &"LibraryCard"
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size.y = 74
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.set_tooltip(card, "%s\n%s\nCliquez puis cliquez dans l'atelier pour le placer." % [d.name, d.description])
	card.pressed.connect(func() -> void:
		if _controller.tool == BuildController.Tool.PLACE and _controller.place_type == type:
			_controller.set_tool(BuildController.Tool.SELECT)
		else:
			_controller.begin_place(type))
	card.mouse_entered.connect(func() -> void: _show_preview(type))
	_cards[type] = card

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var thumb_box := PanelContainer.new()
	thumb_box.add_theme_stylebox_override("panel",
		NxThemeBuilder.flat(Color(color, 0.1), P.RADIUS_M, Color.TRANSPARENT, 0, 2, 2))
	thumb_box.custom_minimum_size = Vector2(54, 54)
	thumb_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thumb := TextureRect.new()
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_thumb(thumb, type)
	thumb_box.add_child(thumb)
	_thumbs[type] = thumb
	row.add_child(thumb_box)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = d.name
	name_label.add_theme_font_override("font", card.get_theme_font("font", "TitleLabel"))
	name_label.add_theme_font_size_override("font_size", P.FONT_LABEL)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name_label)
	var fn := Label.new()
	fn.text = d.function
	fn.theme_type_variation = &"CaptionLabel"
	fn.add_theme_color_override("font_color", color.lerp(P.TEXT, 0.25))
	fn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(fn)
	var desc := Label.new()
	desc.text = d.description
	desc.theme_type_variation = &"CaptionLabel"
	desc.add_theme_color_override("font_color", P.TEXT_DIM)
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(desc)
	return card


func _set_thumb(rect: TextureRect, type: StringName) -> void:
	var tex := NxThumbnails.get_thumbnail(type)
	if tex:
		rect.texture = tex
		rect.modulate = Color.WHITE
	else:
		var d := NxRegistry.definition(type)
		rect.texture = NxIcons.get_icon(d.icon)
		rect.modulate = P.domain_color(d.category)


func _on_thumbnail(type: StringName, _tex: Texture2D) -> void:
	if _thumbs.has(type) and is_instance_valid(_thumbs[type]):
		_set_thumb(_thumbs[type], type)
	if _preview_type == type:
		_show_preview(type)


func _on_tool_changed(tool: int, place_type: StringName) -> void:
	for type in _cards:
		if is_instance_valid(_cards[type]):
			_cards[type].set_pressed_no_signal(tool == BuildController.Tool.PLACE and type == place_type)
	if tool == BuildController.Tool.PLACE:
		_show_preview(place_type)


func _show_preview(type: StringName) -> void:
	_preview_type = type
	for child in _preview.get_children():
		child.queue_free()
	if type == &"":
		var hint := Label.new()
		hint.text = "Survolez un composant pour voir ses détails. Cliquez dessus, puis dans l'atelier pour le placer."
		hint.theme_type_variation = &"CaptionLabel"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size.x = 200
		_preview.add_child(hint)
		return
	var d := NxRegistry.definition(type)
	var color := P.domain_color(d.category)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_preview.add_child(top)
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(84, 84)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_thumb(thumb, type)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", NxThemeBuilder.flat(P.BG_0, P.RADIUS_M, P.BORDER, 1, 4, 4))
	frame.add_child(thumb)
	top.add_child(frame)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	top.add_child(info)
	var title := Label.new()
	title.text = d.name
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", P.FONT_BODY)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(title)
	var size: Vector2i = d.size
	var meta := Label.new()
	meta.text = "%s · %d × %d cases" % [NxCatalog.category(d.category).name, size.x, size.y]
	meta.theme_type_variation = &"CaptionLabel"
	meta.add_theme_color_override("font_color", color.lerp(P.TEXT, 0.3))
	info.add_child(meta)
	for port in d.ports:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 9)
		dot.add_theme_color_override("font_color", NxPort.color(port.type))
		line.add_child(dot)
		var pl := Label.new()
		var dir_text := { NxPort.IN: "entrée", NxPort.OUT: "sortie", NxPort.BOTH: "réseau" }
		pl.text = "%s (%s)" % [port.label, dir_text.get(port.dir, "")]
		pl.theme_type_variation = &"CaptionLabel"
		line.add_child(pl)
		info.add_child(line)
	var desc := Label.new()
	desc.text = d.description
	desc.theme_type_variation = &"CaptionLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 200
	_preview.add_child(desc)
