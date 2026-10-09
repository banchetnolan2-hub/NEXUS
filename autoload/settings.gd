extends Node
## Persistent user settings (autoload "Settings").
##
## Values are stored in user://settings.cfg and applied immediately when they
## change. Other systems read values with `Settings.get_value(key)` and react
## to `setting_changed`. Keys use the "section/name" form.

signal setting_changed(key: StringName, value: Variant)

const FILE_PATH := "user://settings.cfg"
const FORMAT_VERSION := 1

enum Quality { LOW, MEDIUM, HIGH, ULTRA }
enum WindowMode { WINDOWED, FULLSCREEN, EXCLUSIVE_FULLSCREEN }

const QUALITY_NAMES := ["Basse", "Moyenne", "Élevée", "Ultra"]
const WINDOW_MODE_NAMES := ["Fenêtré", "Plein écran (fenêtre sans bordure)", "Plein écran exclusif"]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]

const DEFAULTS := {
	&"audio/master": 0.8,
	&"audio/sfx": 1.0,
	&"audio/ui": 0.6,
	&"graphics/quality": Quality.HIGH,
	&"graphics/window_mode": WindowMode.WINDOWED,
	&"graphics/resolution": Vector2i(1600, 900),
	&"graphics/vsync": true,
	&"controls/camera_sensitivity": 1.0,
	&"controls/invert_y": false,
	&"interface/ui_scale": 1.0,
	&"interface/tooltips": true,
	&"interface/reduce_motion": false,
}

## Numeric limits applied when a value is set or loaded.
const RANGES := {
	&"audio/master": Vector2(0.0, 1.0),
	&"audio/sfx": Vector2(0.0, 1.0),
	&"audio/ui": Vector2(0.0, 1.0),
	&"graphics/quality": Vector2(Quality.LOW, Quality.ULTRA),
	&"graphics/window_mode": Vector2(WindowMode.WINDOWED, WindowMode.EXCLUSIVE_FULLSCREEN),
	&"controls/camera_sensitivity": Vector2(0.2, 3.0),
	&"interface/ui_scale": Vector2(0.8, 1.25),
}

const AUDIO_BUSES := {
	&"audio/master": &"Master",
	&"audio/sfx": &"SFX",
	&"audio/ui": &"UI",
}

## Path of the settings file; tests point it elsewhere.
var file_path := FILE_PATH
## When false, changes are only kept in memory (used by tests).
var autosave := true
## When false, values are stored but not pushed to the engine (used by tests).
var apply_changes := true

var _values: Dictionary = DEFAULTS.duplicate(true)
var _save_queued := false


func _ready() -> void:
	load_settings()
	apply_all()


# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

func get_value(key: StringName) -> Variant:
	if _values.has(key):
		return _values[key]
	assert(DEFAULTS.has(key), "Unknown setting: %s" % key)
	return DEFAULTS.get(key)


func set_value(key: StringName, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("Settings: unknown key '%s' ignored." % key)
		return
	var clean: Variant = _sanitize(key, value)
	if clean == null:
		push_warning("Settings: invalid value for '%s': %s" % [key, value])
		return
	if _values.has(key) and _values[key] == clean:
		return
	_values[key] = clean
	if apply_changes:
		_apply(key)
	setting_changed.emit(key, clean)
	if autosave:
		_queue_save()


func reset_to_defaults() -> void:
	for key in DEFAULTS:
		set_value(key, DEFAULTS[key])


func load_settings() -> Error:
	if not FileAccess.file_exists(file_path):
		return ERR_FILE_NOT_FOUND
	var cfg := ConfigFile.new()
	var err := cfg.load(file_path)
	if err != OK:
		push_warning("Settings: could not read %s (%s); defaults are used." % [file_path, error_string(err)])
		return err
	for key in DEFAULTS:
		var parts := String(key).split("/")
		if cfg.has_section_key(parts[0], parts[1]):
			var clean: Variant = _sanitize(key, cfg.get_value(parts[0], parts[1]))
			if clean != null:
				_values[key] = clean
	return OK


func save_settings() -> Error:
	_save_queued = false
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", FORMAT_VERSION)
	for key in DEFAULTS:
		var parts := String(key).split("/")
		cfg.set_value(parts[0], parts[1], _values.get(key, DEFAULTS[key]))
	var err := cfg.save(file_path)
	if err != OK:
		push_error("Settings: could not write %s (%s)." % [file_path, error_string(err)])
	return err


func apply_all() -> void:
	if not apply_changes:
		return
	for key in DEFAULTS:
		_apply(key)


## Resolutions that fit on the current screen.
func available_resolutions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var screen := DisplayServer.screen_get_size()
	for res in RESOLUTIONS:
		if screen == Vector2i.ZERO or (res.x <= screen.x and res.y <= screen.y):
			result.append(res)
	if result.is_empty():
		result.append(RESOLUTIONS[0])
	return result


## Applies quality-dependent effects to an Environment owned by a scene.
func apply_environment_quality(env: Environment) -> void:
	if env == null:
		return
	var q: int = get_value(&"graphics/quality")
	env.ssao_enabled = q >= Quality.HIGH
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = q >= Quality.ULTRA
	env.glow_enabled = true
	env.volumetric_fog_enabled = false


# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------

func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	# Several sliders can fire many changes per frame; write once at idle time.
	save_settings.call_deferred()


func _sanitize(key: StringName, value: Variant) -> Variant:
	var default: Variant = DEFAULTS[key]
	match typeof(default):
		TYPE_BOOL:
			if typeof(value) == TYPE_BOOL:
				return value
			if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				return value != 0
			return null
		TYPE_INT:
			if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				return null
			var i := int(value)
			if RANGES.has(key):
				i = clampi(i, int(RANGES[key].x), int(RANGES[key].y))
			return i
		TYPE_FLOAT:
			if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				return null
			var f := float(value)
			if is_nan(f) or is_inf(f):
				return null
			if RANGES.has(key):
				f = clampf(f, RANGES[key].x, RANGES[key].y)
			return f
		TYPE_VECTOR2I:
			if typeof(value) in [TYPE_VECTOR2I, TYPE_VECTOR2]:
				var v := Vector2i(value)
				if v.x < 640 or v.y < 360:
					return null
				return v
			return null
	return value


func _apply(key: StringName) -> void:
	var value: Variant = _values.get(key, DEFAULTS[key])
	if AUDIO_BUSES.has(key):
		_apply_bus_volume(AUDIO_BUSES[key], value)
		return
	match key:
		&"graphics/window_mode", &"graphics/resolution":
			_apply_window()
		&"graphics/vsync":
			if _has_window():
				DisplayServer.window_set_vsync_mode(
					DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
		&"graphics/quality":
			_apply_quality(value)
		&"interface/ui_scale":
			get_tree().root.content_scale_factor = value


func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func _has_window() -> bool:
	return DisplayServer.get_name() != "headless"


func _apply_window() -> void:
	if not _has_window():
		return
	var window := get_tree().root
	match int(get_value(&"graphics/window_mode")):
		WindowMode.FULLSCREEN:
			window.mode = Window.MODE_FULLSCREEN
		WindowMode.EXCLUSIVE_FULLSCREEN:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			var was_fullscreen := window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
			if was_fullscreen or window.mode == Window.MODE_MAXIMIZED:
				window.mode = Window.MODE_WINDOWED
			var target: Vector2i = get_value(&"graphics/resolution")
			var usable := DisplayServer.screen_get_usable_rect(window.current_screen).size
			if usable.x > 0 and usable.y > 0:
				target = Vector2i(mini(target.x, usable.x), mini(target.y, usable.y))
			window.size = target
			window.move_to_center()


func _apply_quality(q: int) -> void:
	var vp := get_tree().root
	var msaa := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
	vp.msaa_3d = msaa[q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == Quality.LOW else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_scale = 0.85 if q == Quality.LOW else 1.0
	vp.mesh_lod_threshold = [4.0, 2.0, 1.0, 0.5][q]
	var shadow_sizes := [1024, 2048, 4096, 8192]
	RenderingServer.directional_shadow_atlas_set_size(shadow_sizes[q], true)
	vp.positional_shadow_atlas_size = shadow_sizes[q]
	var filters := [
		RenderingServer.SHADOW_QUALITY_HARD,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
	]
	RenderingServer.directional_soft_shadow_filter_set_quality(filters[q])
	RenderingServer.positional_soft_shadow_filter_set_quality(filters[q])
