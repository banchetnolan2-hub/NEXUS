class_name NxMaterials
extends RefCounted
## Shared 3D materials of the NEXUS industrial style.
##
## Materials are cached so many machines share the same resources.

const P := preload("res://ui/theme/nx_palette.gd")
const GRID_SHADER := preload("res://resources/shaders/grid_floor.gdshader")

static var _cache: Dictionary = {}


## Dark brushed steel used for frames and housings.
static func steel() -> StandardMaterial3D:
	return _cached(&"steel", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("5d6775")
		m.metallic = 0.55
		m.roughness = 0.42
		return m)


## Lighter machined metal for shafts and gears.
static func machined() -> StandardMaterial3D:
	return _cached(&"machined", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("a9b3c1")
		m.metallic = 0.8
		m.roughness = 0.3
		return m)


## Painted surface tinted with a domain colour.
static func painted(color: Color) -> StandardMaterial3D:
	return _cached(StringName("painted_%s" % color.to_html()), func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = color.darkened(0.15)
		m.metallic = 0.2
		m.roughness = 0.5
		return m)


## Emissive accent for status lights and important highlights only.
static func glow(color: Color = P.ACCENT, energy: float = 2.4) -> StandardMaterial3D:
	return _cached(StringName("glow_%s_%.2f" % [color.to_html(), energy]), func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return m)


## Dark machine base plate.
static func base_plate() -> StandardMaterial3D:
	return _cached(&"base_plate", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("232830")
		m.metallic = 0.3
		m.roughness = 0.6
		return m)


## Translucent tank shell.
static func glass() -> StandardMaterial3D:
	return _cached(&"glass", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.72, 0.82, 0.18)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.2
		m.roughness = 0.08
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)


## Liquid inside tanks.
static func fluid() -> StandardMaterial3D:
	return _cached(&"fluid", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(P.FLUID, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = P.FLUID
		m.emission_energy_multiplier = 0.35
		m.roughness = 0.15
		return m)


## Workshop grid floor.
static func grid_floor() -> ShaderMaterial:
	return _cached(&"grid_floor", func() -> Material:
		var m := ShaderMaterial.new()
		m.shader = GRID_SHADER
		return m)


static func _cached(key: StringName, factory: Callable) -> Material:
	if not _cache.has(key):
		_cache[key] = factory.call()
	return _cache[key]
