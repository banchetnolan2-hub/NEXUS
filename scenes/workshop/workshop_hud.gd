class_name WorkshopHUD
extends Control
## Workshop interface: toolbar, component library, inspector and status bar.
##
## Panels float above the 3D view and collapse to thin strips so the player
## keeps the space for the construction. The centre area lets mouse events
## through to the 3D world.

signal menu_requested
signal save_requested
signal settings_requested

const P := preload("res://ui/theme/nx_palette.gd")

var library: NxSidePanel
var inspector: NxSidePanel

var _name_label: Label
var _dirty_dot: Label
var _status_label: Label
var _sim_label: Label
var _fps_label: Label
var _library_list: VBoxContainer
var _search: LineEdit
var _filter := &""
var _filter_group := ButtonGroup.new()
var _name_edit: LineEdit
var _library_toggle: Button
var _inspector_toggle: Button
var _fps_timer := 0.0


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	column.add_child(_build_toolbar())

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_theme_constant_override("separation", 10)
	column.add_child(middle)

	library = NxSidePanel.new("Bibliothèque", "layers", NxSidePanel.Side.LEFT, 300)
	library.shortcut_hint = "Ctrl+L"
	_build_library(library.get_content())
	middle.add_child(library)

	var viewport_area := Control.new()
	viewport_area.name = "ViewportArea"
	viewport_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(viewport_area)

	inspector = NxSidePanel.new("Inspecteur", "info", NxSidePanel.Side.RIGHT, 300, true)
	inspector.shortcut_hint = "Ctrl+I"
	_build_inspector(inspector.get_content())
	middle.add_child(inspector)

	column.add_child(_build_status_bar())

	library.collapsed_changed.connect(func(c: bool) -> void: _library_toggle.set_pressed_no_signal(not c))
	inspector.collapsed_changed.connect(func(c: bool) -> void: _inspector_toggle.set_pressed_no_signal(not c))
	Game.dirty_changed.connect(func(_d: bool) -> void: _refresh_session())
	Game.session_changed.connect(_refresh_session)
	_refresh_session()


func _process(delta: float) -> void:
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func toggle_library() -> void:
	library.toggle()


func toggle_inspector() -> void:
	inspector.toggle()


func set_status(text: String) -> void:
	_status_label.text = text


# -----------------------------------------------------------------------------
# Toolbar
# -----------------------------------------------------------------------------

func _build_toolbar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"BarPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)

	row.add_child(_tool("menu", "Menu (Échap)", func() -> void: menu_requested.emit()))
	row.add_child(_bar_separator())

	var title_box := HBoxContainer.new()
	title_box.add_theme_constant_override("separation", 6)
	title_box.custom_minimum_size.x = 200
	var mark := TextureRect.new()
	mark.texture = NxIcons.get_icon("blueprint")
	mark.custom_minimum_size = Vector2(18, 18)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.modulate = P.ACCENT
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_box.add_child(mark)
	_name_label = Label.new()
	_name_label.theme_type_variation = &"TitleLabel"
	_name_label.add_theme_font_size_override("font_size", P.FONT_BODY)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.custom_minimum_size.x = 180
	title_box.add_child(_name_label)
	_dirty_dot = Label.new()
	_dirty_dot.text = "●"
	_dirty_dot.add_theme_color_override("font_color", P.WARNING)
	_dirty_dot.add_theme_font_size_override("font_size", 10)
	_dirty_dot.mouse_filter = Control.MOUSE_FILTER_PASS
	UI.set_tooltip(_dirty_dot, "Modifications non enregistrées")
	title_box.add_child(_dirty_dot)
	row.add_child(title_box)

	row.add_child(_bar_separator())
	row.add_child(_tool("save", "Enregistrer (Ctrl+S)", func() -> void: save_requested.emit()))
	row.add_child(_tool("undo", "Annuler (Ctrl+Z) — disponible avec la construction", Callable(), true))
	row.add_child(_tool("redo", "Rétablir (Ctrl+Y) — disponible avec la construction", Callable(), true))

	row.add_child(_spacer())

	# Simulation controls, centred. Enabled once machines exist (step 4).
	var sim := PanelContainer.new()
	sim.theme_type_variation = &"InsetPanel"
	sim.add_theme_stylebox_override("panel", NxThemeBuilder.flat(P.BG_0, P.RADIUS_M, P.BORDER, 1, 4, 2))
	var sim_row := HBoxContainer.new()
	sim_row.add_theme_constant_override("separation", 2)
	sim.add_child(sim_row)
	var sim_hint := "La simulation sera disponible avec les premières machines."
	sim_row.add_child(_tool("play", "Démarrer la simulation (Espace)\n" + sim_hint, Callable(), true))
	sim_row.add_child(_tool("pause", "Mettre en pause\n" + sim_hint, Callable(), true))
	sim_row.add_child(_tool("reset", "Réinitialiser la simulation\n" + sim_hint, Callable(), true))
	row.add_child(sim)

	row.add_child(_spacer())

	_library_toggle = _tool("panel_left", "Bibliothèque (Ctrl+L)", func() -> void: toggle_library())
	_library_toggle.toggle_mode = true
	_library_toggle.button_pressed = true
	row.add_child(_library_toggle)
	_inspector_toggle = _tool("panel_right", "Inspecteur (Ctrl+I)", func() -> void: toggle_inspector())
	_inspector_toggle.toggle_mode = true
	_inspector_toggle.button_pressed = true
	row.add_child(_inspector_toggle)
	row.add_child(_bar_separator())
	row.add_child(_tool("settings", "Paramètres", func() -> void: settings_requested.emit()))
	return bar


func _tool(icon_name: String, tip: String, action: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"ToolButton"
	button.icon = NxIcons.get_icon(icon_name)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = disabled
	# Disabled buttons still explain themselves on hover.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	UI.set_tooltip(button, tip)
	if action.is_valid():
		button.pressed.connect(action)
	return button


func _bar_separator() -> Control:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(9, 22)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return sep


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


# -----------------------------------------------------------------------------
# Library
# -----------------------------------------------------------------------------

func _build_library(content: VBoxContainer) -> void:
	_search = LineEdit.new()
	_search.placeholder_text = "Rechercher un composant…"
	_search.clear_button_enabled = true
	_search.right_icon = NxIcons.get_icon("search")
	_search.text_changed.connect(func(_t: String) -> void: _refresh_library())
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
	_library_list = VBoxContainer.new()
	_library_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library_list.add_theme_constant_override("separation", P.SPACE_S)
	scroll.add_child(_library_list)
	_refresh_library()


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
		chip.add_theme_color_override("icon_normal_color", P.domain_color(category))
		chip.add_theme_color_override("icon_hover_color", P.domain_color(category))
		chip.add_theme_color_override("icon_pressed_color", P.domain_color(category))
	chip.pressed.connect(func() -> void:
		_filter = category
		_refresh_library())
	return chip


func _refresh_library() -> void:
	for child in _library_list.get_children():
		child.queue_free()
	var query := _search.text.strip_edges().to_lower()
	var shown := 0
	for c in NxCatalog.CATEGORIES:
		if _filter != &"" and c.id != _filter:
			continue
		if not query.is_empty() and not (c.name.to_lower().contains(query) or c.description.to_lower().contains(query)):
			continue
		_library_list.add_child(_category_card(c))
		shown += 1
	if shown == 0:
		_library_list.add_child(NxEmptyState.new("search", "Aucun résultat",
			"Essayez un autre mot-clé ou une autre catégorie."))


func _category_card(c: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.add_theme_stylebox_override("panel", NxThemeBuilder.flat(P.BG_2, P.RADIUS_M, P.BORDER, 1, P.SPACE_M, P.SPACE_M))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", P.SPACE_M)
	card.add_child(row)

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", NxThemeBuilder.flat(Color(P.domain_color(c.id), 0.14), P.RADIUS_M, Color.TRANSPARENT, 0, 7, 7))
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var icon := TextureRect.new()
	icon.texture = NxIcons.get_icon(c.icon)
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = P.domain_color(c.id)
	badge.add_child(icon)
	row.add_child(badge)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var title := Label.new()
	title.text = c.name
	title.add_theme_font_override("font", get_theme_font("font", "TitleLabel"))
	title.add_theme_font_size_override("font_size", P.FONT_LABEL)
	text.add_child(title)
	var desc := Label.new()
	desc.text = c.description
	desc.theme_type_variation = &"CaptionLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	var count := Label.new()
	count.text = "Aucun composant pour l'instant"
	count.theme_type_variation = &"CaptionLabel"
	count.add_theme_color_override("font_color", P.TEXT_DIM)
	text.add_child(count)
	return card


# -----------------------------------------------------------------------------
# Inspector
# -----------------------------------------------------------------------------

func _build_inspector(content: VBoxContainer) -> void:
	content.add_child(_section("Atelier"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = Game.DEFAULT_NAME
	_name_edit.max_length = 48
	UI.set_tooltip(_name_edit, "Nom de l'atelier, utilisé pour la sauvegarde.")
	_name_edit.text_submitted.connect(func(_t: String) -> void: _commit_name())
	_name_edit.focus_exited.connect(_commit_name)
	content.add_child(_name_edit)

	var props := VBoxContainer.new()
	props.add_theme_constant_override("separation", 6)
	content.add_child(props)
	props.add_child(NxPropertyRow.new("Composants", "0"))
	props.add_child(NxPropertyRow.new("Connexions", "0"))
	var sim_row := NxPropertyRow.new("Simulation", "Arrêtée")
	sim_row.set_value_text("Arrêtée", P.TEXT_MUTED)
	props.add_child(sim_row)
	props.add_child(NxPropertyRow.new("Grille", "1,0 m"))

	content.add_child(_section("Sélection"))
	content.add_child(NxEmptyState.new("cursor", "Aucun objet sélectionné",
		"Sélectionnez une machine pour afficher ses réglages et son état."))

	content.add_child(_section("Raccourcis"))
	var keys := VBoxContainer.new()
	keys.add_theme_constant_override("separation", 6)
	keys.add_child(NxKeyHint.new(["Échap"], "Menu"))
	keys.add_child(NxKeyHint.new(["Ctrl", "S"], "Enregistrer"))
	keys.add_child(NxKeyHint.new(["Ctrl", "L"], "Bibliothèque"))
	keys.add_child(NxKeyHint.new(["Ctrl", "I"], "Inspecteur"))
	keys.add_child(NxKeyHint.new(["F11"], "Plein écran"))
	content.add_child(keys)


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.uppercase = true
	label.theme_type_variation = &"SectionLabel"
	return label


func _commit_name() -> void:
	var new_name := _name_edit.text.strip_edges()
	if new_name.is_empty():
		new_name = Game.DEFAULT_NAME
	if new_name != Game.session_name:
		Game.session_name = new_name
		Game.mark_dirty()
	_refresh_session()


# -----------------------------------------------------------------------------
# Status bar
# -----------------------------------------------------------------------------

func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"BarPanel"
	bar.add_theme_stylebox_override("panel", NxThemeBuilder.flat(Color(P.BG_1, 0.92), P.RADIUS_M, P.BORDER, 1, P.SPACE_M, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", P.SPACE_L)
	bar.add_child(row)

	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_color_override("font_color", P.SUCCESS)
	dot.add_theme_font_size_override("font_size", 10)
	row.add_child(dot)
	_status_label = _status_text("Prêt")
	_status_label.add_theme_color_override("font_color", P.TEXT_MUTED)
	row.add_child(_status_label)
	row.add_child(_spacer())
	_sim_label = _status_text("Simulation : arrêtée")
	row.add_child(_sim_label)
	row.add_child(_status_text("Grille : 1,0 m"))
	_fps_label = _status_text("— FPS")
	_fps_label.custom_minimum_size.x = 56
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_fps_label)
	return bar


func _status_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"CaptionLabel"
	label.add_theme_color_override("font_color", P.TEXT_DIM)
	return label


func _refresh_session() -> void:
	_name_label.text = Game.session_name
	_dirty_dot.visible = Game.dirty
	if not _name_edit.has_focus():
		_name_edit.text = Game.session_name
	if Game.save_path.is_empty():
		set_status("Prêt — atelier non enregistré")
	elif Game.dirty:
		set_status("Modifications non enregistrées")
	else:
		set_status("Prêt")
