extends Control
## Developer showcase of the NEXUS design system: every reusable control in
## one screen, to review visual consistency. Run this scene with F6 in the
## editor. Escape returns to the main menu.

const P := preload("res://ui/theme/nx_palette.gd")


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = P.BG_0
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	scroll.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", P.SPACE_XL)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Design system NEXUS"
	title.theme_type_variation = &"Headline"
	root.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", P.SPACE_XL)
	root.add_child(columns)
	var left := _column(columns)
	var middle := _column(columns)
	var right := _column(columns)

	# Buttons
	var buttons := _card(left, "Boutons")
	var row := HBoxContainer.new()
	buttons.add_child(row)
	row.add_child(_button("Principal", &"PrimaryButton"))
	row.add_child(_button("Secondaire", &""))
	row.add_child(_button("Discret", &"GhostButton"))
	var row2 := HBoxContainer.new()
	buttons.add_child(row2)
	row2.add_child(_button("Supprimer", &"DangerButton", "trash"))
	var disabled := _button("Désactivé", &"")
	disabled.disabled = true
	row2.add_child(disabled)
	var tools := HBoxContainer.new()
	buttons.add_child(tools)
	for icon in ["cursor", "move", "rotate", "copy", "trash", "link"]:
		var tool := Button.new()
		tool.theme_type_variation = &"ToolButton"
		tool.icon = NxIcons.get_icon(icon)
		tool.toggle_mode = true
		tool.button_pressed = icon == "move"
		tools.add_child(tool)
	var chips := HFlowContainer.new()
	buttons.add_child(chips)
	for c in NxCatalog.CATEGORIES:
		var chip := Button.new()
		chip.text = c.name
		chip.icon = NxIcons.get_icon(c.icon)
		chip.theme_type_variation = &"ChipButton"
		chip.toggle_mode = true
		chip.add_theme_color_override("icon_normal_color", P.domain_color(c.id))
		chips.add_child(chip)

	# Typography
	var type_box := _card(left, "Typographie")
	for v in [["Headline", "Titre principal"], ["TitleLabel", "Titre de section"],
			["", "Texte courant de l'interface"], ["MutedLabel", "Texte secondaire"],
			["CaptionLabel", "Légende et aide contextuelle"], ["ValueLabel", "1 450 tr/min  ·  12,5 kW"],
			["AccentLabel", "Accent"]]:
		var l := Label.new()
		l.theme_type_variation = StringName(v[0])
		l.text = v[1]
		type_box.add_child(l)

	# Inputs
	var inputs := _card(middle, "Champs")
	var edit := LineEdit.new()
	edit.placeholder_text = "Rechercher un composant…"
	edit.right_icon = NxIcons.get_icon("search")
	inputs.add_child(edit)
	var option := OptionButton.new()
	for q in ["Basse", "Moyenne", "Élevée", "Ultra"]:
		option.add_item(q)
	option.select(2)
	inputs.add_child(option)
	var slider := NxSliderField.new()
	slider.value = 0.65
	inputs.add_child(slider)
	var toggle := CheckButton.new()
	toggle.text = "Infobulles"
	toggle.button_pressed = true
	inputs.add_child(toggle)
	var check := CheckBox.new()
	check.text = "Case à cocher"
	check.button_pressed = true
	inputs.add_child(check)
	var progress := ProgressBar.new()
	progress.value = 62
	progress.custom_minimum_size.y = 6
	progress.show_percentage = false
	inputs.add_child(progress)

	# Inspector rows
	var inspector := _card(middle, "Inspecteur")
	inspector.add_child(NxPropertyRow.new("Vitesse cible", "1 200 tr/min"))
	inspector.add_child(NxPropertyRow.new("Consommation", "3,2 kW"))
	var state := NxPropertyRow.new("État", "")
	state.set_value_text("En marche", P.SUCCESS)
	inspector.add_child(state)
	var warn := NxPropertyRow.new("Énergie", "")
	warn.set_value_text("Insuffisante", P.WARNING)
	inspector.add_child(warn)

	# Feedback
	var feedback := _card(right, "Retours")
	for kind in [&"info", &"success", &"warning", &"error"]:
		var b := _button("Notification « %s »" % kind, &"GhostButton")
		b.pressed.connect(UI.toast.bind("Exemple de notification (%s)." % kind, kind))
		feedback.add_child(b)
	var dialog_btn := _button("Ouvrir une confirmation", &"")
	dialog_btn.pressed.connect(func() -> void:
		UI.confirm("Supprimer la machine ?", "Cette action est irréversible.", "Supprimer", func() -> void: pass))
	feedback.add_child(dialog_btn)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", P.SPACE_L)
	keys.add_child(NxKeyHint.new(["Ctrl", "S"], "Enregistrer"))
	keys.add_child(NxKeyHint.new(["R"], "Pivoter"))
	feedback.add_child(keys)

	var palette := _card(right, "Domaines")
	for c in NxCatalog.CATEGORIES:
		var line := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = P.domain_color(c.id)
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(swatch)
		var name_label := Label.new()
		name_label.text = c.name
		line.add_child(name_label)
		palette.add_child(line)

	var icons := _card(root, "Icônes")
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 14)
	icons.add_child(grid)
	for icon_name in NxIcons.list_icons():
		var rect := TextureRect.new()
		rect.texture = NxIcons.get_icon(icon_name)
		rect.custom_minimum_size = Vector2(22, 22)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.modulate = P.TEXT_MUTED
		rect.tooltip_text = icon_name
		grid.add_child(rect)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		UI.change_scene(Game.MENU_SCENE)


func _column(parent: Control) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", P.SPACE_XL)
	parent.add_child(c)
	return c


func _card(parent: Control, heading: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	parent.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", P.SPACE_M)
	card.add_child(box)
	var label := Label.new()
	label.text = heading
	label.uppercase = true
	label.theme_type_variation = &"SectionLabel"
	box.add_child(label)
	return box


func _button(text: String, variation: StringName, icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	if not icon_name.is_empty():
		b.icon = NxIcons.get_icon(icon_name)
	return b
