class_name WorkshopCamera
extends Camera3D
## Orbit camera of the workshop.
##
##   Right button drag ........ orbit around the target
##   Middle button drag ....... pan
##   Wheel .................... zoom
##   W A S D / Z Q S D ........ pan (physical keys, works on AZERTY)
##   F ........................ frame a point (see focus_on)
## Sensitivity and vertical inversion come from the player settings.

signal view_changed

const MIN_DISTANCE := 3.0
const MAX_DISTANCE := 45.0
const MIN_PITCH := deg_to_rad(12.0)
const MAX_PITCH := deg_to_rad(85.0)
const PAN_SPEED := 9.0          ## Metres per second at distance 12.
const SMOOTHING := 14.0

var target := Vector3.ZERO
var yaw := deg_to_rad(38.0)
var pitch := deg_to_rad(42.0)
var distance := 16.0
## Horizontal framing shift so the build area is centred between the panels.
var screen_offset := 0.0

var _goal_target := target
var _goal_yaw := yaw
var _goal_pitch := pitch
var _goal_distance := distance
var _orbiting := false
var _panning := false
## Mouse travel during the current right-button press (to tell clicks from drags).
var right_drag_distance := 0.0


func _ready() -> void:
	fov = 50.0
	near = 0.05
	far = 400.0
	_apply()


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if not _keyboard_blocked():
		if Input.is_physical_key_pressed(KEY_W):
			move.y -= 1
		if Input.is_physical_key_pressed(KEY_S):
			move.y += 1
		if Input.is_physical_key_pressed(KEY_A):
			move.x -= 1
		if Input.is_physical_key_pressed(KEY_D):
			move.x += 1
	if move != Vector2.ZERO:
		var speed := PAN_SPEED * (_goal_distance / 12.0) * delta
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= 2.5
		var forward := Vector3(sin(_goal_yaw), 0, cos(_goal_yaw))
		var right := Vector3(forward.z, 0, -forward.x)
		_goal_target += (right * move.x + forward * move.y).normalized() * speed
		_clamp_target()

	var t := 1.0 - exp(-SMOOTHING * delta)
	var before := global_transform
	target = target.lerp(_goal_target, t)
	yaw = lerp_angle(yaw, _goal_yaw, t)
	pitch = lerpf(pitch, _goal_pitch, t)
	distance = lerpf(distance, _goal_distance, t)
	_apply()
	if not global_transform.is_equal_approx(before):
		view_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb:
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_orbiting = mb.pressed
				if mb.pressed:
					right_drag_distance = 0.0
			MOUSE_BUTTON_MIDDLE:
				_panning = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					zoom(1.0 / 1.15)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					zoom(1.15)
		return
	var mm := event as InputEventMouseMotion
	if mm == null:
		return
	if _orbiting:
		right_drag_distance += mm.relative.length()
		var sens: float = Settings.get_value(&"controls/camera_sensitivity") * 0.006
		var invert := -1.0 if Settings.get_value(&"controls/invert_y") else 1.0
		_goal_yaw -= mm.relative.x * sens
		_goal_pitch = clampf(_goal_pitch + mm.relative.y * sens * invert, MIN_PITCH, MAX_PITCH)
	elif _panning:
		var scale := _goal_distance * 0.0016
		var forward := Vector3(sin(_goal_yaw), 0, cos(_goal_yaw))
		var right := Vector3(forward.z, 0, -forward.x)
		_goal_target += (-right * mm.relative.x - forward * mm.relative.y) * scale
		_clamp_target()


func zoom(factor: float) -> void:
	_goal_distance = clampf(_goal_distance * factor, MIN_DISTANCE, MAX_DISTANCE)


func focus_on(point: Vector3, dist: float = -1.0) -> void:
	_goal_target = Vector3(point.x, 0, point.z)
	if dist > 0:
		_goal_distance = clampf(dist, MIN_DISTANCE, MAX_DISTANCE)
	_clamp_target()


func reset_view() -> void:
	_goal_target = Vector3.ZERO
	_goal_yaw = deg_to_rad(38.0)
	_goal_pitch = deg_to_rad(42.0)
	_goal_distance = 16.0


func is_dragging() -> bool:
	return _orbiting or _panning


func serialize() -> Dictionary:
	return { "target": [_goal_target.x, _goal_target.z], "yaw": _goal_yaw,
		"pitch": _goal_pitch, "distance": _goal_distance }


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	var t: Array = data.get("target", [0, 0])
	_goal_target = Vector3(float(t[0]), 0, float(t[1]))
	_goal_yaw = float(data.get("yaw", _goal_yaw))
	_goal_pitch = clampf(float(data.get("pitch", _goal_pitch)), MIN_PITCH, MAX_PITCH)
	_goal_distance = clampf(float(data.get("distance", _goal_distance)), MIN_DISTANCE, MAX_DISTANCE)
	_clamp_target()
	target = _goal_target
	yaw = _goal_yaw
	pitch = _goal_pitch
	distance = _goal_distance
	_apply()


func _apply() -> void:
	var offset := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)) * distance
	position = target + offset
	look_at(target, Vector3.UP)
	h_offset = screen_offset * distance * 0.05


func _clamp_target() -> void:
	var limit := float(SimWorld.GRID_HALF) + 4.0
	_goal_target.x = clampf(_goal_target.x, -limit, limit)
	_goal_target.z = clampf(_goal_target.z, -limit, limit)


func _keyboard_blocked() -> bool:
	if UI.has_open_dialog():
		return true
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit
