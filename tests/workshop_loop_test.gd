extends RefCounted
## Gameplay loop driven through the real workshop: place with the mouse,
## rotate, connect by clicking ports, select, configure, run, pause, undo,
## save and reload. Called by tests/run_tests.gd.

var t  # The SceneTree test runner (untyped: helpers live in run_tests.gd).


func run(tree) -> void:
	t = tree
	t._use_save_dir("loop")
	var ui: Node = t.root.get_node("UI")
	var game: Node = t.root.get_node("Game")
	var settings: Node = t.root.get_node("Settings")
	settings.autosave = false
	settings.set_value(&"interface/reduce_motion", true)
	game.new_session("Boucle", &"empty")
	t.change_scene_to_file("res://scenes/workshop/workshop.tscn")
	await t._wait(20)
	var ws: Node = t.current_scene
	var ctrl: BuildController = ws.controller
	var cam: WorkshopCamera = ws.get_node("%Camera")
	await t._wait(30)  # Camera settles.

	# 0. Keyboard camera: the W/Z physical key moves the view forward.
	var before: Vector3 = cam._goal_target
	var hold := InputEventKey.new()
	hold.physical_keycode = KEY_W
	hold.keycode = KEY_W
	hold.pressed = true
	Input.parse_input_event(hold)
	await t._wait(15)
	hold = hold.duplicate()
	hold.pressed = false
	Input.parse_input_event(hold)
	await t._wait(2)
	var toward_camera := Vector3(sin(cam._goal_yaw), 0, cos(cam._goal_yaw))
	t.check((cam._goal_target - before).dot(toward_camera) < -0.1, "W/Z moves the view forward")
	cam.reset_view()
	await t._wait(30)

	# 1. Place a generator with a real mouse click in the 3D view.
	ctrl.begin_place(&"generator")
	await t._click_world(cam, Vector3(0.0, 0, 0.0))
	t.check_eq(ctrl.world.components.size(), 1, "mouse click places the generator")
	var gen: SimComponent = ctrl.world.component_at(Vector2i(0, 0))
	t.check(gen != null and gen.type == &"generator", "generator centred under the cursor")

	# 2. Place a motor (rotated with R) and a fan through the same tool.
	ctrl.begin_place(&"motor")
	t._key(KEY_R)
	await t._wait(2)
	t.check_eq(ctrl.place_rot, 1, "R rotates the preview")
	t._key(KEY_R)
	t._key(KEY_R)
	t._key(KEY_R)
	await t._wait(2)
	var motor := ctrl.place_at(Vector2i(3, 0))
	ctrl.begin_place(&"fan")
	var fan := ctrl.place_at(Vector2i(5, 0))
	t.check(ctrl.place_at(Vector2i(5, 0)) == null, "occupied cell refused")
	t._key(KEY_ESCAPE)
	await t._wait(2)
	t.check_eq(ctrl.tool, BuildController.Tool.SELECT, "Escape leaves the placement tool")

	# 3. Connect with the connection tool (clicks on the ports).
	t._key(KEY_C)
	await t._wait(2)
	t.check_eq(ctrl.tool, BuildController.Tool.CONNECT, "C selects the connection tool")
	await t._click_screen(cam.unproject_position(ctrl.world.port_position(gen, &"power")))
	await t._click_screen(cam.unproject_position(ctrl.world.port_position(motor, &"power")))
	t.check_eq(ctrl.world.connections.size(), 1, "power cable created by clicking two ports")
	t.check(ctrl.connect_ports(motor.id, &"shaft_out", fan.id, &"shaft_in"), "shaft connected")
	t.check(not ctrl.connect_ports(gen.id, &"power", fan.id, &"shaft_in"), "incompatible link refused")
	t._key(KEY_V)

	# 4. Select and configure through the inspector path.
	await t._click_world(cam, SimWorld.footprint_center(motor.type, motor.cell, motor.rot) + Vector3(0, 0.4, 0))
	t.check_eq(ctrl.selected_id, motor.id, "clicking a machine selects it")
	ctrl.set_param(motor.id, "target_rpm", 1200.0)
	t.check_eq(motor.param("target_rpm"), 1200.0, "setting changes the machine")

	# 5. Run, observe, pause.
	t._key(KEY_SPACE)
	await t._wait(40)
	t.check(ws.runner.is_running(), "Space starts the simulation")
	t.check(fan.state.rpm > 1000.0, "fan turns while running (%s)" % fan.state.rpm)
	t.check(ctrl.world.time > 0.0, "time advances")
	t._key(KEY_SPACE)
	await t._wait(2)
	var t_paused: float = ctrl.world.time
	await t._wait(10)
	t.check_eq(ctrl.world.time, t_paused, "paused simulation does not advance")

	# 6. Undo / redo / duplicate / delete.
	var count: int = ctrl.world.components.size()
	ctrl.select(fan.id)
	t._key(KEY_DELETE)
	await t._wait(2)
	t.check_eq(ctrl.world.components.size(), count - 1, "Delete removes the selection")
	t._key(KEY_Z, true)
	await t._wait(2)
	t.check_eq(ctrl.world.components.size(), count, "Ctrl+Z restores it")
	t.check_eq(ctrl.world.connections.size(), 2, "with its connections")

	# 7. Save, reload from disk, compare.
	t._key(KEY_S, true)
	await t._wait(3)
	t.check(not game.dirty, "Ctrl+S saves")
	var saved_world: Dictionary = ctrl.world.serialize()
	var latest: Dictionary = t._saves().latest_save()
	game.new_session()
	var loaded: Dictionary = game.load_session(latest.path)
	t.check(loaded.ok, "save reloads")
	t.change_scene_to_file("res://scenes/workshop/workshop.tscn")
	await t._wait(10)
	var reloaded: BuildController = t.current_scene.controller
	t.check_eq(reloaded.world.components.size(), saved_world.components.size(), "machines reloaded")
	t.check_eq(reloaded.world.connections.size(), saved_world.connections.size(), "connections reloaded")
	var m2: SimComponent = reloaded.world.components.get(motor.id)
	t.check(m2 != null and m2.param("target_rpm") == 1200.0, "settings reloaded")
	ui.close_all_dialogs()
	settings.set_value(&"interface/reduce_motion", false)
