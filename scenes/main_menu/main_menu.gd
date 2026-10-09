extends Node
## Main menu: start, continue or load a workshop, open settings, quit.

const P := preload("res://ui/theme/nx_palette.gd")
const SettingsScreen := preload("res://ui/screens/settings_screen.gd")
const LoadDialog := preload("res://ui/screens/load_dialog.gd")

@onready var _brand: Control = %Brand
@onready var _menu: VBoxContainer = %Menu
@onready var _new_game: Button = %NewGame
@onready var _continue: Button = %Continue
@onready var _continue_detail: Label = %ContinueDetail
@onready var _load: Button = %Load
@onready var _settings: Button = %Settings
@onready var _quit: Button = %Quit
@onready var _version: Label = %Version
@onready var _hints: HBoxContainer = %Hints


func _ready() -> void:
	_version.text = "NEXUS v%s  ·  Étape 1 — interface et identité visuelle" % \
		ProjectSettings.get_setting("application/config/version", "0.0.0")
	_hints.add_child(NxKeyHint.new(["↑", "↓"], "Naviguer"))
	_hints.add_child(NxKeyHint.new(["Entrée"], "Valider"))
	_hints.add_child(NxKeyHint.new(["F11"], "Plein écran"))

	_new_game.pressed.connect(_on_new_game)
	_continue.pressed.connect(_on_continue)
	_load.pressed.connect(_on_load)
	_settings.pressed.connect(_on_settings)
	_quit.pressed.connect(_on_quit)
	UI.set_tooltip(_quit, "Fermer NEXUS.")
	SaveManager.saves_changed.connect(_refresh_continue)

	_refresh_continue()
	_play_intro()
	(_continue if not _continue.disabled else _new_game).grab_focus()


func _refresh_continue() -> void:
	var latest := SaveManager.latest_save()
	_continue.disabled = latest.is_empty()
	_continue.focus_mode = Control.FOCUS_NONE if _continue.disabled else Control.FOCUS_ALL
	if latest.is_empty():
		_continue_detail.text = ""
		UI.set_tooltip(_continue, "Aucune sauvegarde disponible pour le moment.")
	else:
		_continue_detail.text = "%s  ·  %s" % [latest.name, NxFormat.relative_time(latest.modified)]
		UI.set_tooltip(_continue, "Reprendre « %s »." % latest.name)


func _play_intro() -> void:
	# Short staggered entrance; buttons are usable immediately.
	var items: Array[Control] = [_brand]
	for child in _menu.get_children():
		items.append(child)
	var delay := 0.0
	for item in items:
		item.modulate.a = 0.0
		var t := item.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_interval(UI.anim_time(delay))
		t.tween_property(item, "modulate:a", 1.0, UI.anim_time(P.ANIM_SLOW))
		delay += 0.04


func _on_new_game() -> void:
	Game.new_session()
	UI.change_scene(Game.WORKSHOP_SCENE)


func _on_continue() -> void:
	var latest := SaveManager.latest_save()
	if latest.is_empty():
		_refresh_continue()
		return
	_open_save(latest.path)


func _on_load() -> void:
	var dialog := LoadDialog.new()
	dialog.save_chosen.connect(_open_save)
	UI.open_dialog(dialog)


func _open_save(path: String) -> void:
	var result := Game.load_session(path)
	if not result.ok:
		UI.show_error("Chargement impossible",
			result.error + "\n\nLe fichier n'a pas été modifié.")
		_refresh_continue()
		return
	UI.change_scene(Game.WORKSHOP_SCENE)


func _on_settings() -> void:
	UI.open_dialog(SettingsScreen.new())


func _on_quit() -> void:
	get_tree().quit()
