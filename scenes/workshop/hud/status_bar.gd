class_name WorkshopStatusBar
extends PanelContainer
## Bottom bar: simulation state, simulated time, energy balance, counts, FPS.

const P := preload("res://ui/theme/nx_palette.gd")

var _runner: SimulationRunner
var _world: SimWorld
var _dot: Label
var _state: Label
var _time: Label
var _energy: Label
var _counts: Label
var _fps: Label
var _timer := 0.0


func _init() -> void:
	theme_type_variation = &"BarPanel"
	add_theme_stylebox_override("panel", NxThemeBuilder.flat(Color(P.BG_1, 0.94), P.RADIUS_M, P.BORDER, 1, P.SPACE_M, 4))


func bind(runner: SimulationRunner, world: SimWorld) -> void:
	_runner = runner
	_world = world
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", P.SPACE_L)
	add_child(row)
	_dot = Label.new()
	_dot.text = "●"
	_dot.add_theme_font_size_override("font_size", 10)
	row.add_child(_dot)
	_state = _text(P.TEXT)
	row.add_child(_state)
	_time = _text(P.TEXT_MUTED)
	_time.theme_type_variation = &"ValueLabel"
	_time.add_theme_font_size_override("font_size", P.FONT_CAPTION)
	row.add_child(_time)
	row.add_child(_sep())
	_energy = _text(P.TEXT_MUTED)
	row.add_child(_energy)
	row.add_child(_sep())
	_counts = _text(P.TEXT_DIM)
	row.add_child(_counts)
	row.add_child(NxHud.spacer())
	_fps = _text(P.TEXT_DIM)
	_fps.custom_minimum_size.x = 52
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_fps)
	runner.state_changed.connect(func(_s: int) -> void: refresh())
	refresh()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 and _runner:
		_timer = 0.2
		refresh()


func refresh() -> void:
	var labels := ["Simulation arrêtée", "Simulation en cours", "Simulation en pause"]
	var colors := [P.TEXT_DIM, P.SUCCESS, P.WARNING]
	var text: String = labels[_runner.state]
	if _runner.state == SimulationRunner.State.RUNNING and _runner.speed > 1.0:
		text += " ×%d" % int(_runner.speed)
	_state.text = text
	_dot.add_theme_color_override("font_color", colors[_runner.state])
	_time.text = "t = " + NxHud.format_time(_world.time)
	var short := _world.total_demand_kw > _world.total_supply_kw + 0.001
	_energy.text = "Énergie : %s / %s kW%s" % [SimBehavior.fmt(_world.total_demand_kw),
		SimBehavior.fmt(_world.total_supply_kw), "  ⚠ insuffisante" if short else ""]
	_energy.add_theme_color_override("font_color", P.WARNING if short else P.TEXT_MUTED)
	_counts.text = "%d machines · %d connexions" % [_world.components.size(), _world.connections.size()]
	_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _text(color: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"CaptionLabel"
	label.add_theme_color_override("font_color", color)
	return label


func _sep() -> Control:
	var s := VSeparator.new()
	s.custom_minimum_size.y = 14
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return s
