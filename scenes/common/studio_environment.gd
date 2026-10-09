class_name NxStudioEnvironment
extends WorldEnvironment
## Shared lighting environment of NEXUS 3D scenes (menu backdrop, workshop).
##
## Builds its Environment in code so every scene shares the same look, and
## re-applies the graphics quality preset when the player changes it.

const P := preload("res://ui/theme/nx_palette.gd")

## Distance at which the fog fully hides the background.
@export var fog_density := 0.018


func _ready() -> void:
	environment = create_environment(fog_density)
	Settings.apply_environment_quality(environment)
	Settings.setting_changed.connect(_on_setting_changed)


static func create_environment(density: float = 0.018) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = P.BG_0
	# A dark procedural sky is used only for ambient light and reflections,
	# so metals get a sheen while the visible background stays flat.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2a3546")
	sky_mat.sky_horizon_color = Color("4a5568")
	sky_mat.ground_horizon_color = Color("2a3038")
	sky_mat.ground_bottom_color = Color("0b0d10")
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0

	# Glow only on emissive accents: high HDR threshold, screen blending.
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for level in 7:
		env.set_glow_level(level, level >= 1 and level <= 3)

	env.fog_enabled = true
	env.fog_light_color = P.BG_0
	env.fog_density = density
	env.fog_sky_affect = 0.0

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.05
	return env


func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if key == &"graphics/quality":
		Settings.apply_environment_quality(environment)
