extends Node3D
## Animated 3D backdrop of the main menu: a small gearbox, a motor and a tank
## on the workshop grid, seen by a slowly drifting camera.
##
## Gear speeds follow their tooth ratios, like the real mechanics will.

const P := preload("res://ui/theme/nx_palette.gd")

## Angular speed of the driving gear (radians per second).
@export var drive_speed := 0.22
## Horizontal framing offset so the machine sits to the right of the menu.
@export var framing_offset := -4.0

var _camera: Camera3D
var _gears: Array[Dictionary] = []  # { node: Node3D, ratio: float }
var _time := 0.0
var _level_ring: MeshInstance3D


func _ready() -> void:
	_build_world()
	_build_machine()
	_build_camera()


func _process(delta: float) -> void:
	_time += delta
	for gear in _gears:
		gear.node.rotation.z += drive_speed * gear.ratio * delta
	# Slow camera drift around the machine.
	var angle := sin(_time * 0.05) * 0.2 - 0.3
	var target := Vector3(1.0, 1.9, 0.0)
	var dist := 19.0
	_camera.position = target + Vector3(sin(angle) * dist, 4.2 + sin(_time * 0.09) * 0.3, cos(angle) * dist)
	_camera.look_at(target)
	# Tank level indicator breathes gently.
	if _level_ring:
		_level_ring.position.y = 1.1 + sin(_time * 0.35) * 0.35


# -----------------------------------------------------------------------------
# Construction
# -----------------------------------------------------------------------------

func _build_world() -> void:
	var env := NxStudioEnvironment.new()
	env.fog_density = 0.035
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.5
	sun.light_color = Color("f1f4fa")
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	var rim := OmniLight3D.new()
	rim.position = Vector3(1.5, 4.5, -3.0)
	rim.light_color = P.ACCENT
	rim.light_energy = 2.2
	rim.omni_range = 9.0
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-6.0, 3.0, 4.0)
	fill.light_color = Color("ffd6a8")
	fill.light_energy = 0.6
	fill.omni_range = 14.0
	add_child(fill)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(120, 120)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = NxMaterials.grid_floor()
	add_child(floor_node)


func _build_machine() -> void:
	var steel := NxMaterials.steel()
	var machined := NxMaterials.machined()

	# Gearbox back plate on two feet.
	_box(Vector3(7.6, 4.4, 0.25), Vector3(0.6, 2.7, -0.55), steel)
	_box(Vector3(0.5, 0.5, 1.6), Vector3(-2.6, 0.25, -0.2), steel)
	_box(Vector3(0.5, 0.5, 1.6), Vector3(3.8, 0.25, -0.2), steel)
	_box(Vector3(0.3, 0.6, 0.3), Vector3(-2.6, 0.75, -0.55), steel)
	_box(Vector3(0.3, 0.6, 0.3), Vector3(3.8, 0.75, -0.55), steel)

	# Gear train: A (32 teeth) drives B (16), which drives C (24).
	var a_pos := Vector3(-1.0, 2.9, 0.0)
	var b_pos := a_pos + Vector3(1.6 + 0.8, 0, 0)
	var c_dir := Vector2.from_angle(deg_to_rad(-48.0))
	var c_pos := b_pos + Vector3(c_dir.x, c_dir.y, 0) * (0.8 + 1.2)
	_gear(32, 1.6, a_pos, 1.0, 0.0, P.MECHANICAL.darkened(0.1))
	_gear(16, 0.8, b_pos, -2.0, PI / 16.0, Color("a9b3c1"))
	_gear(24, 1.2, c_pos, 32.0 / 24.0, 0.0, Color("a9b3c1"))

	# Status ring on the driving hub: the only strong glow in the scene.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.34
	ring.outer_radius = 0.4
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	ring_node.material_override = NxMaterials.glow(P.ACCENT, 3.0)
	ring_node.position = a_pos + Vector3(0, 0, 0.27)
	ring_node.rotation_degrees.x = 90
	add_child(ring_node)

	# Motor driving gear A through a shaft.
	_box(Vector3(1.6, 1.5, 1.4), Vector3(-4.3, 0.75, 0.6), steel)
	_cylinder(0.62, 1.7, Vector3(-4.3, 1.9, 0.6), steel, Vector3(0, 0, 90))
	_cylinder(0.66, 0.16, Vector3(-3.42, 1.9, 0.6), NxMaterials.painted(P.MECHANICAL), Vector3(0, 0, 90))
	_box(Vector3(0.9, 0.06, 0.08), Vector3(-4.3, 1.2, 1.31), NxMaterials.glow(P.SUCCESS, 2.0))

	# Tank with a glowing level band, piped to the gearbox side.
	var tank_pos := Vector3(5.6, 0.0, 1.6)
	_cylinder(1.0, 2.8, tank_pos + Vector3(0, 1.4, 0), steel)
	_cylinder(1.04, 0.12, tank_pos + Vector3(0, 2.86, 0), machined)
	_cylinder(1.04, 0.12, tank_pos + Vector3(0, 0.06, 0), machined)
	var band := CylinderMesh.new()
	band.top_radius = 1.02
	band.bottom_radius = 1.02
	band.height = 0.05
	_level_ring = MeshInstance3D.new()
	_level_ring.mesh = band
	_level_ring.material_override = NxMaterials.glow(P.FLUID, 2.2)
	_level_ring.position = tank_pos + Vector3(0, 1.1, 0)
	add_child(_level_ring)

	var pipe := NxMaterials.painted(P.FLUID)
	_cylinder(0.13, 2.0, Vector3(4.6, 0.45, 1.6), pipe, Vector3(0, 0, 90))
	_sphere(0.17, Vector3(3.6, 0.45, 1.6), pipe)
	_cylinder(0.13, 1.6, Vector3(3.6, 0.45, 0.8), pipe, Vector3(90, 0, 0))
	_sphere(0.17, Vector3(3.6, 0.45, 0.0), pipe)

	# Small pump block at the pipe junction.
	_box(Vector3(0.8, 0.7, 0.7), Vector3(3.6, 0.35, 0.0), steel)
	_box(Vector3(0.36, 0.06, 0.06), Vector3(3.6, 0.55, 0.36), NxMaterials.glow(P.ACCENT, 2.0))


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.h_offset = framing_offset
	_camera.v_offset = 0.3
	_camera.near = 0.1
	_camera.far = 200.0
	add_child(_camera)
	_camera.current = true
	_process(0.0)


func _gear(teeth: int, pitch_radius: float, pos: Vector3, ratio: float, phase: float, color: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.z = phase
	add_child(pivot)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.7
	mat.roughness = 0.34
	var gear := MeshInstance3D.new()
	gear.mesh = NxGearMesh.build(teeth, pitch_radius, 0.32)
	gear.material_override = mat
	gear.rotation_degrees.x = 90
	pivot.add_child(gear)

	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = pitch_radius * 0.28
	hub_mesh.bottom_radius = pitch_radius * 0.28
	hub_mesh.height = 0.5
	hub.mesh = hub_mesh
	hub.material_override = NxMaterials.steel()
	hub.rotation_degrees.x = 90
	pivot.add_child(hub)

	# Spokes cut-outs suggested by darker blocks, so rotation is visible.
	for i in 4:
		var spoke := MeshInstance3D.new()
		var spoke_mesh := BoxMesh.new()
		spoke_mesh.size = Vector3(pitch_radius * 0.9, 0.12, 0.34)
		spoke.mesh = spoke_mesh
		spoke.material_override = NxMaterials.steel()
		spoke.rotation.z = i * PI / 4.0
		pivot.add_child(spoke)

	_gears.append({ "node": pivot, "ratio": ratio })


func _box(box_size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return _add_mesh(mesh, pos, mat)


func _cylinder(radius: float, height: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	var node := _add_mesh(mesh, pos, mat)
	node.rotation_degrees = rot_deg
	return node


func _sphere(radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _add_mesh(mesh, pos, mat)


func _add_mesh(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	add_child(node)
	return node
