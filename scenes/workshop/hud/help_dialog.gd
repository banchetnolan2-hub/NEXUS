extends NxDialog
## Controls reference (F1).

const SECTIONS := [
	["Caméra", [
		[["Clic droit", "glisser"], "Orbiter autour de l'atelier"],
		[["Clic molette", "glisser"], "Déplacer la vue"],
		[["Molette"], "Zoomer / dézoomer"],
		[["Z", "Q", "S", "D"], "Se déplacer (W A S D en QWERTY) · Maj : plus vite"],
		[["F"], "Centrer sur la sélection (ou vue initiale)"],
	]],
	["Construction", [
		[["Clic"], "Sélectionner · placer le composant choisi"],
		[["Glisser"], "Déplacer la machine sélectionnée"],
		[["R"], "Pivoter (aperçu ou sélection)"],
		[["Ctrl", "D"], "Dupliquer la sélection"],
		[["Suppr"], "Supprimer la sélection"],
		[["Ctrl", "Z"], "Annuler · Ctrl+Y : rétablir"],
		[["Échap"], "Annuler l'action en cours / désélectionner"],
	]],
	["Connexions", [
		[["C"], "Outil Connexion (V : retour à la sélection)"],
		[["Clic", "Clic"], "Port de départ puis port de même couleur"],
	]],
	["Simulation et général", [
		[["Espace"], "Lancer / mettre en pause"],
		[["Ctrl", "R"], "Réinitialiser la simulation"],
		[["Ctrl", "S"], "Enregistrer"],
		[["Ctrl", "L"], "Bibliothèque · Ctrl+I : inspecteur"],
		[["F1"], "Cette aide · F11 : plein écran"],
	]],
]


func _init() -> void:
	super("Aide et contrôles", 760)
	title_icon = "keyboard"
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", NxPalette.SPACE_XXL)
	add_content(columns)
	var col_a := VBoxContainer.new()
	var col_b := VBoxContainer.new()
	for col in [col_a, col_b]:
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", NxPalette.SPACE_S)
		columns.add_child(col)
	for i in SECTIONS.size():
		var col := col_a if i < 2 else col_b
		if col.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size.y = 8
			col.add_child(gap)
		col.add_child(NxHud.section(SECTIONS[i][0]))
		for entry in SECTIONS[i][1]:
			var row := HBoxContainer.new()
			var keys := NxKeyHint.new(PackedStringArray(entry[0]))
			keys.custom_minimum_size.x = 150
			row.add_child(keys)
			var text := Label.new()
			text.text = entry[1]
			text.theme_type_variation = &"CaptionLabel"
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text)
			col.add_child(row)
	add_button("Compris", NxDialog.PRIMARY)
