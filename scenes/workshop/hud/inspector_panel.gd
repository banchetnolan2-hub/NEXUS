class_name InspectorPanel
extends RefCounted
## Contextual inspector. Without selection it shows the workshop overview
## and a short guide; with a machine selected it shows its status, its real
## settings (generated from the definition), live values and connections.

const P := preload("res://ui/theme/nx_palette.gd")
const LIVE_REFRESH := 0.1

var _content: VBoxContainer
var _controller: BuildController
var _runner: SimulationRunner
var _world: SimWorld
var _shown_id := -2
var _live_rows: Array = []          # [NxPropertyRow]
var _status_pill: PanelContainer
var _param_controls: Dictionary = {}
var _overview_labels: Dictionary = {}
var _timer := 0.0
var _name_edit: LineEdit


func build(content: VBoxContainer, controller: BuildController, runner: SimulationRunner) -> void:
	_content = content
	_controller = controller
	_runner = runner
	_world = controller.world
	controller.selection_changed.connect(func(_id: int) -> void: rebuild())
	_world.params_changed.connect(func(id: int) -> void:
		if id == _controller.selected_id:
			_sync_params())
	runner.state_changed.connect(func(_s: int) -> void: refresh_live())
	rebuild()


## Called every frame by the HUD; live values refresh at 10 Hz.
func process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = LIVE_REFRESH
		refresh_live()


func rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_live_rows.clear()
	_param_controls.clear()
	_overview_labels.clear()
	_status_pill = null
	var c: SimComponent = _world.components.get(_controller.selected_id)
	_shown_id = c.id if c else -1
	if c:
		_build_component(c)
	else:
		_build_overview()
	refresh_live()


# -----------------------------------------------------------------------------
# Overview (nothing selected)
# -----------------------------------------------------------------------------

func _build_overview() -> void:
	_content.add_child(NxHud.section("Atelier"))
	_name_edit = LineEdit.new()
	_name_edit.text = Game.session_name
	_name_edit.max_length = 48
	UI.set_tooltip(_name_edit, "Nom de l'atelier, utilisé pour la sauvegarde.")
	_name_edit.text_submitted.connect(func(_t: String) -> void:
		_commit_name()
		_name_edit.release_focus())
	_name_edit.focus_exited.connect(_commit_name)
	_content.add_child(_name_edit)

	var props := VBoxContainer.new()
	props.add_theme_constant_override("separation", 6)
	_content.add_child(props)
	for key in ["machines", "links", "sim", "time", "energy"]:
		var labels := { "machines": "Machines", "links": "Connexions", "sim": "Simulation",
			"time": "Temps simulé", "energy": "Énergie" }
		var row := NxPropertyRow.new(labels[key], "")
		props.add_child(row)
		_overview_labels[key] = row
		if key == "energy":
			UI.set_tooltip(row, "Puissance demandée / puissance produite par les générateurs.")

	_content.add_child(NxHud.section("Premiers pas"))
	var steps := [
		["layers", "Choisissez un composant dans la bibliothèque, puis cliquez dans l'atelier."],
		["link", "Outil Connexion (C) : cliquez un port puis un port de même couleur."],
		["settings", "Sélectionnez une machine pour la régler ici."],
		["play", "Lancez la simulation (Espace) et observez l'état des machines."],
		["save", "Enregistrez avec Ctrl+S."],
	]
	for i in steps.size():
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var num := Label.new()
		num.text = str(i + 1)
		num.theme_type_variation = &"ValueLabel"
		num.add_theme_color_override("font_color", P.ACCENT)
		num.custom_minimum_size.x = 12
		num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(num)
		var text := Label.new()
		text.text = steps[i][1]
		text.theme_type_variation = &"CaptionLabel"
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size.x = 160
		line.add_child(text)
		_content.add_child(line)

	_content.add_child(NxHud.section("Légende des connexions"))
	var legend := VBoxContainer.new()
	legend.add_theme_constant_override("separation", 4)
	for type in [NxPort.POWER, NxPort.SHAFT, NxPort.FLUID, NxPort.SIGNAL, NxPort.PROBE]:
		var line := HBoxContainer.new()
		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 10)
		dot.add_theme_color_override("font_color", NxPort.color(type))
		line.add_child(dot)
		var l := Label.new()
		l.text = NxPort.type_name(type)
		l.theme_type_variation = &"CaptionLabel"
		line.add_child(l)
		legend.add_child(line)
	_content.add_child(legend)


func _commit_name() -> void:
	if _name_edit == null or not is_instance_valid(_name_edit):
		return
	var new_name := _name_edit.text.strip_edges()
	if new_name.is_empty():
		new_name = Game.DEFAULT_NAME
	if new_name != Game.session_name:
		Game.session_name = new_name
		Game.mark_dirty()
		Game.session_changed.emit()


# -----------------------------------------------------------------------------
# Selected machine
# -----------------------------------------------------------------------------

func _build_component(c: SimComponent) -> void:
	var d := c.def()
	var color := P.domain_color(d.category)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.add_child(NxHud.badge(d.icon, color, 22, 8))
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = d.name
	title.theme_type_variation = &"TitleLabel"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(title)
	var sub := Label.new()
	sub.text = "%s · %s" % [NxCatalog.category(d.category).name, d.function]
	sub.theme_type_variation = &"CaptionLabel"
	sub.add_theme_color_override("font_color", color.lerp(P.TEXT, 0.3))
	title_box.add_child(sub)
	header.add_child(title_box)
	_content.add_child(header)

	_status_pill = NxHud.status_pill()
	_content.add_child(_status_pill)

	# Actions
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.add_child(_action("rotate", "Pivoter (R)", func() -> void: _controller.rotate_selected()))
	actions.add_child(_action("copy", "Dupliquer (Ctrl+D)", func() -> void: _controller.duplicate_selected()))
	actions.add_child(_action("link", "Relier (outil Connexion, C)", func() -> void:
		_controller.set_tool(BuildController.Tool.CONNECT)))
	actions.add_child(_action("eye", "Centrer la vue (F)", func() -> void:
		_controller.camera.focus_on(SimWorld.footprint_center(c.type, c.cell, c.rot), 9.0)))
	actions.add_child(NxHud.spacer())
	var del := _action("trash", "Supprimer (Suppr)", func() -> void: _controller.delete_selected())
	del.add_theme_color_override("icon_hover_color", P.DANGER)
	actions.add_child(del)
	_content.add_child(actions)

	# Settings
	_content.add_child(NxHud.section("Réglages"))
	for p in d.params:
		_content.add_child(_param_row(c, p))

	# Live values
	_content.add_child(NxHud.section("État en direct"))
	var live := VBoxContainer.new()
	live.add_theme_constant_override("separation", 6)
	_content.add_child(live)
	for entry in c.behavior.live_values(c):
		var row := NxPropertyRow.new(entry[0], entry[1])
		live.add_child(row)
		_live_rows.append(row)

	# Connections
	_content.add_child(NxHud.section("Connexions"))
	for port in d.ports:
		_content.add_child(_port_row(c, port))


func _action(icon_name: String, tip: String, action: Callable) -> Button:
	var b := NxHud.tool_button(icon_name, tip, action)
	return b


func _param_row(c: SimComponent, p: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var key: String = p.id
	var control: Control
	match p.kind:
		"bool":
			var toggle := CheckButton.new()
			toggle.text = p.label
			toggle.button_pressed = bool(c.param(key))
			toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
			toggle.toggled.connect(func(on: bool) -> void: _controller.set_param(c.id, key, on))
			control = toggle
			box.add_child(toggle)
		"enum":
			var label := Label.new()
			label.text = p.label
			label.theme_type_variation = &"MutedLabel"
			box.add_child(label)
			var option := OptionButton.new()
			option.fit_to_longest_item = false
			option.clip_text = true
			for i in p.options.size():
				option.add_item(p.options[i], i)
			option.select(int(c.param(key)))
			option.item_selected.connect(func(i: int) -> void: _controller.set_param(c.id, key, i))
			control = option
			box.add_child(option)
		_:
			var label := Label.new()
			label.text = p.label
			label.theme_type_variation = &"MutedLabel"
			box.add_child(label)
			var field := NxSliderField.new(p.min, p.max, p.get("step", 0.01))
			var unit: String = p.get("unit", "")
			var decimals := 0 if float(p.get("step", 1.0)) >= 1.0 else (1 if float(p.get("step", 1.0)) >= 0.1 else 2)
			field.formatter = func(v: float) -> String:
				return ("%s %s" % [SimBehavior.fmt(v, decimals), unit]).strip_edges()
			field.value_label.custom_minimum_size.x = 92
			field.slider.custom_minimum_size.x = 110
			field.value = float(c.param(key))
			field.value_changed.connect(func(v: float) -> void: _controller.set_param(c.id, key, v))
			control = field
			box.add_child(field)
	if not str(p.get("desc", "")).is_empty():
		UI.set_tooltip(control, p.desc)
	_param_controls[key] = control
	return box


## Puts controls back in sync after undo or external changes.
func _sync_params() -> void:
	var c: SimComponent = _world.components.get(_shown_id)
	if c == null:
		return
	for key in _param_controls:
		var control: Control = _param_controls[key]
		var value: Variant = c.param(key)
		if control is NxSliderField:
			if not is_equal_approx(control.value, float(value)):
				control.value = float(value)
		elif control is CheckButton:
			control.set_pressed_no_signal(bool(value))
		elif control is OptionButton:
			control.select(int(value))


func _port_row(c: SimComponent, port: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 10)
	dot.add_theme_color_override("font_color", NxPort.color(port.type))
	head.add_child(dot)
	var name_label := Label.new()
	name_label.text = port.label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var type_label := Label.new()
	type_label.text = NxPort.type_name(port.type)
	type_label.theme_type_variation = &"CaptionLabel"
	type_label.add_theme_color_override("font_color", P.TEXT_DIM)
	head.add_child(type_label)
	box.add_child(head)
	var links := _world.links_of(c.id, port.id)
	if links.is_empty():
		var free := Label.new()
		free.text = "Libre"
		free.theme_type_variation = &"CaptionLabel"
		free.add_theme_color_override("font_color", P.TEXT_DIM)
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 16)
		pad.add_child(free)
		box.add_child(pad)
	for link in links:
		var other: SimComponent = link.c
		var line := HBoxContainer.new()
		var pad := Control.new()
		pad.custom_minimum_size.x = 16
		line.add_child(pad)
		var target := Button.new()
		target.theme_type_variation = &"GhostButton"
		target.text = "→ %s · %s" % [other.display_name(), other.port_def(link.p).label]
		target.alignment = HORIZONTAL_ALIGNMENT_LEFT
		target.add_theme_font_size_override("font_size", P.FONT_CAPTION)
		target.add_theme_color_override("font_color", P.ACCENT)
		target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target.clip_text = true
		target.focus_mode = Control.FOCUS_NONE
		var other_id := other.id
		target.pressed.connect(func() -> void: _controller.select(other_id))
		UI.set_tooltip(target, "Sélectionner %s" % other.display_name())
		line.add_child(target)
		var link_id: int = link.link.id
		var remove := NxHud.tool_button("close", "Supprimer cette connexion",
			func() -> void: _controller.disconnect_link(link_id))
		remove.custom_minimum_size = Vector2(26, 26)
		line.add_child(remove)
		box.add_child(line)
	return box


# -----------------------------------------------------------------------------
# Live refresh
# -----------------------------------------------------------------------------

func refresh_live() -> void:
	var c: SimComponent = _world.components.get(_shown_id)
	if c:
		var values: Array = c.behavior.live_values(c)
		for i in mini(values.size(), _live_rows.size()):
			_live_rows[i].set_value_text(values[i][1])
		if _status_pill:
			var status: StringName = c.state.get("status", &"idle")
			var text: String = c.state.get("status_text", "")
			if _runner.state == SimulationRunner.State.STOPPED and status != &"disabled" \
					and is_equal_approx(_world.time, 0.0):
				text = "Simulation arrêtée — lancez-la pour voir la machine fonctionner"
				status = &"idle"
			NxHud.set_pill(_status_pill, status, text)
		return
	if _overview_labels.is_empty():
		return
	_overview_labels.machines.set_value_text(str(_world.components.size()))
	_overview_labels.links.set_value_text(str(_world.connections.size()))
	var states := ["Arrêtée", "En cours", "En pause"]
	var sim_colors := [P.TEXT_MUTED, P.SUCCESS, P.WARNING]
	_overview_labels.sim.set_value_text(states[_runner.state], sim_colors[_runner.state])
	_overview_labels.time.set_value_text(NxHud.format_time(_world.time))
	var short := _world.total_demand_kw > _world.total_supply_kw + 0.001
	_overview_labels.energy.set_value_text("%s / %s kW" % [SimBehavior.fmt(_world.total_demand_kw),
		SimBehavior.fmt(_world.total_supply_kw)], P.WARNING if short else P.TEXT)
