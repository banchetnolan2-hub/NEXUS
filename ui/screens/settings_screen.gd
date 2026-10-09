extends NxDialog
## Settings dialog: category navigation on the left, rows on the right.
##
## Rows are declared in PAGES and bound to Settings keys. Every change is
## applied and saved immediately, so there is no "Apply" button.

const PAGES := [
	{
		"id": "audio", "title": "Audio", "icon": "volume",
		"rows": [
			{ "key": &"audio/master", "type": "slider", "label": "Volume général",
				"desc": "Volume de l'ensemble du jeu." },
			{ "key": &"audio/sfx", "type": "slider", "label": "Effets sonores",
				"desc": "Machines, simulation et environnement." },
			{ "key": &"audio/ui", "type": "slider", "label": "Sons de l'interface",
				"desc": "Clics et notifications." },
		],
	},
	{
		"id": "graphics", "title": "Graphismes", "icon": "monitor",
		"rows": [
			{ "key": &"graphics/quality", "type": "option", "label": "Qualité graphique",
				"desc": "Ombres, anticrénelage et occlusion ambiante.", "items": "quality" },
			{ "key": &"graphics/window_mode", "type": "option", "label": "Mode d'affichage",
				"desc": "F11 bascule entre fenêtre et plein écran.", "items": "window_mode" },
			{ "key": &"graphics/resolution", "type": "option", "label": "Résolution de la fenêtre",
				"desc": "Utilisée en mode fenêtré.", "items": "resolution" },
			{ "key": &"graphics/vsync", "type": "toggle", "label": "Synchronisation verticale",
				"desc": "Évite les déchirures d'image." },
		],
	},
	{
		"id": "controls", "title": "Contrôles", "icon": "mouse",
		"rows": [
			{ "key": &"controls/camera_sensitivity", "type": "slider", "label": "Sensibilité de la caméra",
				"desc": "Vitesse de rotation de la caméra à la souris.",
				"min": 0.2, "max": 3.0, "step": 0.05, "format": "multiplier" },
			{ "key": &"controls/invert_y", "type": "toggle", "label": "Inverser l'axe vertical",
				"desc": "Inverse le mouvement vertical de la caméra." },
		],
	},
	{
		"id": "interface", "title": "Interface", "icon": "interface",
		"rows": [
			{ "key": &"interface/ui_scale", "type": "slider", "label": "Échelle de l'interface",
				"desc": "Taille des textes et des panneaux.",
				"min": 0.8, "max": 1.25, "step": 0.05, "format": "percent", "live": false },
			{ "key": &"interface/tooltips", "type": "toggle", "label": "Infobulles",
				"desc": "Affiche une explication au survol des éléments." },
			{ "key": &"interface/reduce_motion", "type": "toggle", "label": "Réduire les animations",
				"desc": "Transitions instantanées." },
		],
	},
]

var _nav_group := ButtonGroup.new()
var _pages: Dictionary = {}      # id -> Control
var _controls: Dictionary = {}   # key -> { row: NxSettingRow, control: Control }
var _page_host: Control
var _current_page := ""
static var _last_page := "audio"


func _init() -> void:
	super("Paramètres", 820)
	title_icon = "settings"
	_build_layout()
	add_button("Valeurs par défaut", NxDialog.GHOST, _on_reset_pressed, true, "reset")
	add_footer_spacer()
	add_button("Fermer", NxDialog.PRIMARY)


func _ready() -> void:
	super()
	Settings.setting_changed.connect(_on_setting_changed)
	_show_page(_last_page)


func _build_layout() -> void:
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", NxPalette.SPACE_XL)
	split.custom_minimum_size.y = 380
	add_content(split)

	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = 180
	nav.add_theme_constant_override("separation", 4)
	split.add_child(nav)

	var vsep := VSeparator.new()
	split.add_child(vsep)

	_page_host = Control.new()
	_page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_page_host)

	for page in PAGES:
		var nav_button := Button.new()
		nav_button.text = page.title
		nav_button.icon = NxIcons.get_icon(page.icon)
		nav_button.theme_type_variation = &"NavButton"
		nav_button.toggle_mode = true
		nav_button.button_group = _nav_group
		nav_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav_button.pressed.connect(_show_page.bind(page.id))
		nav_button.set_meta(&"page", page.id)
		nav.add_child(nav_button)

		var scroll := ScrollContainer.new()
		scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.visible = false
		_page_host.add_child(scroll)

		var rows := VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("separation", NxPalette.SPACE_L)
		scroll.add_child(rows)

		var heading := Label.new()
		heading.text = page.title
		heading.theme_type_variation = &"SectionLabel"
		heading.uppercase = true
		rows.add_child(heading)
		for row_def in page.rows:
			rows.add_child(_build_row(row_def))
		_pages[page.id] = scroll


func _build_row(def: Dictionary) -> NxSettingRow:
	var row := NxSettingRow.new(def.label, def.get("desc", ""))
	var key: StringName = def.key
	var control: Control
	match def.type:
		"slider":
			var field := NxSliderField.new(def.get("min", 0.0), def.get("max", 1.0), def.get("step", 0.01))
			if def.get("format", "percent") == "multiplier":
				field.formatter = func(v: float) -> String: return NxSliderField.format_multiplier(v)
			field.value = Settings.get_value(key)
			if def.get("live", true):
				field.value_changed.connect(func(v: float) -> void: Settings.set_value(key, v))
			else:
				# Applied on mouse release: rescaling the UI while dragging
				# would move the slider under the cursor.
				field.slider.gui_input.connect(func(event: InputEvent) -> void:
					var mb := event as InputEventMouseButton
					if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
						Settings.set_value(key, field.slider.value))
				field.value_changed.connect(func(v: float) -> void:
					if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
						Settings.set_value(key, v))
			control = field
		"toggle":
			var toggle := CheckButton.new()
			toggle.button_pressed = Settings.get_value(key)
			toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
			control = toggle
		"option":
			var option := OptionButton.new()
			option.custom_minimum_size.x = 260
			option.fit_to_longest_item = false
			_fill_options(option, def.items)
			option.item_selected.connect(func(index: int) -> void:
				Settings.set_value(key, option.get_item_metadata(index)))
			control = option
	row.set_control(control)
	_controls[key] = { "row": row, "control": control }
	_sync_control(key)
	return row


func _fill_options(option: OptionButton, source: String) -> void:
	option.clear()
	match source:
		"quality":
			for i in Settings.QUALITY_NAMES.size():
				option.add_item(Settings.QUALITY_NAMES[i])
				option.set_item_metadata(i, i)
		"window_mode":
			for i in Settings.WINDOW_MODE_NAMES.size():
				option.add_item(Settings.WINDOW_MODE_NAMES[i])
				option.set_item_metadata(i, i)
		"resolution":
			var list := Settings.available_resolutions()
			var current: Vector2i = Settings.get_value(&"graphics/resolution")
			if not list.has(current):
				list.append(current)
			for i in list.size():
				option.add_item("%d × %d" % [list[i].x, list[i].y])
				option.set_item_metadata(i, list[i])


## Updates a control from the stored value without re-emitting changes.
func _sync_control(key: StringName) -> void:
	if not _controls.has(key):
		return
	var entry: Dictionary = _controls[key]
	var value: Variant = Settings.get_value(key)
	var control: Control = entry.control
	if control is NxSliderField:
		control.value = value
	elif control is CheckButton:
		control.set_pressed_no_signal(value)
	elif control is OptionButton:
		for i in control.item_count:
			if control.get_item_metadata(i) == value:
				control.select(i)
				break
	if key == &"graphics/window_mode" or key == &"graphics/resolution":
		var windowed: bool = Settings.get_value(&"graphics/window_mode") == Settings.WindowMode.WINDOWED
		if _controls.has(&"graphics/resolution"):
			var res_row: NxSettingRow = _controls[&"graphics/resolution"].row
			res_row.set_row_enabled(windowed)


func _show_page(id: String) -> void:
	_current_page = id
	_last_page = id
	for page_id in _pages:
		_pages[page_id].visible = page_id == id
	for button in _nav_group.get_buttons():
		button.set_pressed_no_signal(button.get_meta(&"page") == id)


func _on_setting_changed(key: StringName, _value: Variant) -> void:
	_sync_control(key)


func _on_reset_pressed() -> void:
	UI.confirm("Rétablir les paramètres ?",
		"Tous les réglages audio, graphiques, de contrôle et d'interface reprendront leur valeur par défaut.",
		"Rétablir", func() -> void:
			Settings.reset_to_defaults()
			UI.toast("Paramètres par défaut rétablis.", &"success"),
		false)
