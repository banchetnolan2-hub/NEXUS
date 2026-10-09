class_name NxThumbnails
extends Node
## Renders a small 3D preview of every machine type once, off-screen, and
## caches the images for the library. Without a GPU (headless) it does
## nothing and the library keeps showing the type icons.

signal thumbnail_ready(type: StringName, texture: Texture2D)

const SIZE := 160

static var _cache: Dictionary = {}


static func get_thumbnail(type: StringName) -> Texture2D:
	return _cache.get(type)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_render_all.call_deferred()


func _render_all() -> void:
	var todo := NxRegistry.types().filter(func(t: StringName) -> bool: return not _cache.has(t))
	if todo.is_empty():
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("aab8cc")
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.current = true

	for type in todo:
		var model := NxComponentVisual.create(type)
		vp.add_child(model)
		var b := model.local_bounds
		var center := b.get_center()
		var radius := b.size.length() * 0.5
		var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.05
		cam.position = center + Vector3(0.75, 0.6, 1.0).normalized() * dist
		cam.look_at(center, Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_cache[type] = tex
			thumbnail_ready.emit(type, tex)
		model.queue_free()
		await get_tree().process_frame
	vp.queue_free()
