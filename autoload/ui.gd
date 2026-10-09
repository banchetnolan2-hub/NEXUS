extends Node
## Interface services shared by every screen (autoload "UI").
##
## - Dialog stack (NxDialog) and confirmations
## - Toast notifications
## - Scene transitions with a short fade
## - Tooltip on/off setting, applied to every Control automatically
## - Short procedural interface sounds
## - Global shortcuts (F11: full screen)

const P := preload("res://ui/theme/nx_palette.gd")

const OVERLAY_LAYER := 50
const FADE_LAYER := 100
const TOAST_DURATION := 3.2
const MAX_TOASTS := 4

var _overlay: CanvasLayer
var _dialog_root: Control
var _toast_box: VBoxContainer
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _dialogs: Array[NxDialog] = []
var _transitioning := false
var _tooltips_enabled := true
var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_layers()
	_build_sounds()
	_tooltips_enabled = Settings.get_value(&"interface/tooltips")
	Settings.setting_changed.connect(_on_setting_changed)
	get_tree().node_added.connect(_on_node_added)


# -----------------------------------------------------------------------------
# Dialogs
# -----------------------------------------------------------------------------

func open_dialog(dialog: NxDialog) -> NxDialog:
	_dialogs.append(dialog)
	dialog.tree_exited.connect(func() -> void: _dialogs.erase(dialog))
	_dialog_root.add_child(dialog)
	play_sound(&"open")
	return dialog


func is_top_dialog(dialog: NxDialog) -> bool:
	for i in range(_dialogs.size() - 1, -1, -1):
		if not _dialogs[i].is_closing():
			return _dialogs[i] == dialog
	return false


func has_open_dialog() -> bool:
	for dialog in _dialogs:
		if not dialog.is_closing():
			return true
	return false


func close_all_dialogs() -> void:
	for dialog in _dialogs.duplicate():
		dialog.close()


## Confirmation for destructive actions only. `on_confirm` runs when accepted.
func confirm(title: String, message: String, confirm_label: String, on_confirm: Callable,
		destructive: bool = true, cancel_label: String = "Annuler") -> NxDialog:
	var dialog := NxDialog.new(title, 460)
	dialog.title_icon = "warning" if destructive else "info"
	dialog.add_text(message)
	dialog.add_button(cancel_label, NxDialog.GHOST)
	dialog.add_button(confirm_label, NxDialog.DANGER if destructive else NxDialog.PRIMARY, on_confirm)
	return open_dialog(dialog)


## Error message with an explanation the player can act on.
func show_error(title: String, message: String) -> NxDialog:
	var dialog := NxDialog.new(title, 460)
	dialog.title_icon = "error"
	dialog.add_text(message)
	dialog.add_button("Compris", NxDialog.PRIMARY)
	play_sound(&"error")
	return open_dialog(dialog)


# -----------------------------------------------------------------------------
# Toasts
# -----------------------------------------------------------------------------

## Shows a short notification. kind: info, success, warning, error.
func toast(message: String, kind: StringName = &"info", duration: float = TOAST_DURATION) -> void:
	while _toast_box.get_child_count() >= MAX_TOASTS:
		var oldest := _toast_box.get_child(0)
		_toast_box.remove_child(oldest)
		oldest.queue_free()

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", P.SPACE_M)
	panel.add_child(row)

	var accent := ColorRect.new()
	accent.color = P.feedback_color(kind)
	accent.custom_minimum_size = Vector2(3, 0)
	row.add_child(accent)

	var icon := TextureRect.new()
	var icon_names := { &"success": "check_circle", &"warning": "warning", &"error": "error" }
	icon.texture = NxIcons.get_icon(icon_names.get(kind, "info"))
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = P.feedback_color(kind)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 240
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	_toast_box.add_child(panel)
	panel.modulate.a = 0.0
	var t := panel.create_tween()
	t.tween_property(panel, "modulate:a", 1.0, anim_time(P.ANIM_NORMAL))
	t.tween_interval(duration)
	t.tween_property(panel, "modulate:a", 0.0, anim_time(P.ANIM_SLOW))
	t.tween_callback(panel.queue_free)
	if kind == &"error":
		play_sound(&"error")


# -----------------------------------------------------------------------------
# Scene transitions
# -----------------------------------------------------------------------------

func change_scene(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	close_all_dialogs()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, anim_time(P.ANIM_NORMAL))
	await t.finished
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("UI: cannot open scene %s (%s)" % [path, error_string(err)])
	# Wait for the new scene to be in the tree before revealing it.
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, anim_time(P.ANIM_SLOW))
	await t2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
	if err != OK:
		show_error("Écran indisponible", "L'écran demandé n'a pas pu être chargé.")


func is_transitioning() -> bool:
	return _transitioning


# -----------------------------------------------------------------------------
# Tooltips
# -----------------------------------------------------------------------------

## Sets a tooltip that follows the "show tooltips" setting.
func set_tooltip(control: Control, text: String) -> void:
	control.set_meta(&"nx_tooltip", text)
	if not control.is_in_group(&"nx_tooltip"):
		control.add_to_group(&"nx_tooltip")
	control.tooltip_text = text if _tooltips_enabled else ""


func tooltips_enabled() -> bool:
	return _tooltips_enabled


func _on_node_added(node: Node) -> void:
	# Register tooltips authored in scenes (tooltip_text set in the editor).
	if node is Control and not node.has_meta(&"nx_tooltip") and node.tooltip_text != "":
		set_tooltip(node, node.tooltip_text)
	if node is BaseButton:
		_hook_button_sounds(node)


func _apply_tooltips() -> void:
	for node in get_tree().get_nodes_in_group(&"nx_tooltip"):
		if node is Control:
			node.tooltip_text = node.get_meta(&"nx_tooltip", "") if _tooltips_enabled else ""


# -----------------------------------------------------------------------------
# Motion
# -----------------------------------------------------------------------------

## Animation duration honouring the "reduce motion" setting.
func anim_time(seconds: float) -> float:
	if Settings.get_value(&"interface/reduce_motion"):
		return 0.01
	return seconds


# -----------------------------------------------------------------------------
# Sounds
# -----------------------------------------------------------------------------

func play_sound(sound: StringName) -> void:
	if not _sounds.has(sound):
		return
	for player in _players:
		if not player.playing:
			player.stream = _sounds[sound]
			player.play()
			return


func _hook_button_sounds(button: BaseButton) -> void:
	if button.has_meta(&"nx_silent"):
		return
	button.pressed.connect(func() -> void: play_sound(&"click"))
	var variation := button.theme_type_variation
	if variation == &"MenuEntryButton" or variation == &"NavButton":
		button.mouse_entered.connect(func() -> void:
			if not button.disabled:
				play_sound(&"hover"))


func _build_sounds() -> void:
	_sounds[&"hover"] = _tone([2400.0], 0.025, 0.06)
	_sounds[&"click"] = _tone([1500.0], 0.045, 0.16)
	_sounds[&"open"] = _tone([880.0, 1320.0], 0.09, 0.1)
	_sounds[&"error"] = _tone([330.0, 247.0], 0.16, 0.14)
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.bus = &"UI"
		add_child(player)
		_players.append(player)


## Small synthetic sound: a sequence of soft sine blips with exponential decay.
func _tone(freqs: Array, length: float, volume: float) -> AudioStreamWAV:
	var rate := 44100
	var blip := length / freqs.size()
	var per := int(rate * blip)
	var data := PackedByteArray()
	data.resize(per * freqs.size() * 2)
	var idx := 0
	for f in freqs:
		for i in per:
			var t := float(i) / rate
			# Exponential decay with a 1 ms attack to avoid clicks.
			var env := exp(-t / (blip * 0.3)) * minf(1.0, t / 0.001)
			var s := sin(TAU * f * t) * env * volume
			data.encode_s16(idx, int(clampf(s, -1.0, 1.0) * 32767.0))
			idx += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


# -----------------------------------------------------------------------------
# Global input & settings
# -----------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F11:
		var mode: int = Settings.get_value(&"graphics/window_mode")
		var windowed := mode == Settings.WindowMode.WINDOWED
		Settings.set_value(&"graphics/window_mode",
			Settings.WindowMode.FULLSCREEN if windowed else Settings.WindowMode.WINDOWED)
		get_viewport().set_input_as_handled()


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"interface/tooltips":
		_tooltips_enabled = value
		_apply_tooltips()


func _build_layers() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = OVERLAY_LAYER
	add_child(_overlay)

	_dialog_root = Control.new()
	_dialog_root.name = "Dialogs"
	_dialog_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_dialog_root)

	var toast_margin := MarginContainer.new()
	toast_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_margin.add_theme_constant_override("margin_right", P.SPACE_XL)
	toast_margin.add_theme_constant_override("margin_bottom", 56)
	_overlay.add_child(toast_margin)
	_toast_box = VBoxContainer.new()
	_toast_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	_toast_box.size_flags_vertical = Control.SIZE_SHRINK_END
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.custom_minimum_size.x = 320
	_toast_box.add_theme_constant_override("separation", P.SPACE_S)
	toast_margin.add_child(_toast_box)

	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = FADE_LAYER
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(P.BG_0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)
