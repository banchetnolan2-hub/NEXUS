extends NxDialog
## In-workshop menu opened with Escape.

signal save_requested
signal settings_requested
signal main_menu_requested
signal quit_requested


func _init() -> void:
	super("Menu", 380)
	title_icon = "menu"
	_entry("Reprendre", "play", Callable(), "Échap")
	_entry("Enregistrer", "save", func() -> void: save_requested.emit(), "Ctrl+S")
	_entry("Paramètres", "settings", func() -> void: settings_requested.emit())
	get_body().add_child(HSeparator.new())
	_entry("Menu principal", "home", func() -> void: main_menu_requested.emit())
	_entry("Quitter le jeu", "power", func() -> void: quit_requested.emit())


func _entry(text: String, icon_name: String, action: Callable, shortcut: String = "") -> void:
	var button := Button.new()
	button.text = text
	button.icon = NxIcons.get_icon(icon_name)
	button.theme_type_variation = &"NavButton"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 42
	if not shortcut.is_empty():
		var hint := NxKeyHint.new(PackedStringArray(shortcut.split("+")))
		hint.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		hint.offset_left = -90
		hint.offset_right = -12
		hint.offset_top = -11
		hint.offset_bottom = 11
		hint.alignment = BoxContainer.ALIGNMENT_END
		button.add_child(hint)
	button.pressed.connect(func() -> void:
		# Close first so the next dialog opens on a clean stack.
		close()
		if action.is_valid():
			action.call())
	get_body().add_child(button)
