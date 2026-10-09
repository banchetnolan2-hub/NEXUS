class_name BuildController
extends Node
## Player construction tools on top of a SimWorld and its WorldView.
##
## Tools: SELECT (click, drag to move), PLACE (ghost preview + click),
## CONNECT (click a port, then a compatible port). Every edit goes through
## this class so it is recorded in the undo stack and marks the game dirty.

signal tool_changed(tool: int, place_type: StringName)
signal selection_changed(id: int)
signal hint_changed(text: String)
signal edited

enum Tool { SELECT, PLACE, CONNECT }

const DRAG_THRESHOLD := 6.0

var world: SimWorld
var view: WorldView
var camera: WorkshopCamera
var undo_stack := NxUndoStack.new()

var tool: int = Tool.SELECT
var place_type: StringName
var place_rot := 0
var place_params: Dictionary = {}
var selected_id := -1
## Set to false while the mouse is over an interface panel.
var pointer_in_view := true

var _place_cell := Vector2i.ZERO
var _press_pos := Vector2.ZERO
var _press_id := -1
var _dragging := false
var _drag_cell := Vector2i.ZERO
var _drag_offset := Vector2i.ZERO
var _pending_port: Dictionary = {}
var _hover_port: Dictionary = {}
var _base_hint := ""
var _mouse := Vector2.ZERO


func setup(w: SimWorld, v: WorldView, cam: WorkshopCamera) -> void:
	world = w
	view = v
	camera = cam
	world.structure_changed.connect(_on_structure_changed)
	_update_hint()


# -----------------------------------------------------------------------------
# Tools
# -----------------------------------------------------------------------------

func set_tool(value: int) -> void:
	if value == Tool.PLACE and place_type == &"":
		value = Tool.SELECT
	tool = value
	_pending_port = {}
	_hover_port = {}
	_dragging = false
	view.hide_pending_link()
	view.set_hover_port({})
	if tool != Tool.PLACE:
		view.hide_ghost()
	view.set_ports_mode(WorldView.PortsMode.ALL if tool == Tool.CONNECT else WorldView.PortsMode.SELECTED)
	tool_changed.emit(tool, place_type if tool == Tool.PLACE else &"")
	_update_hint()


func begin_place(type: StringName, params: Dictionary = {}, rot: int = -1) -> void:
	if not NxRegistry.has_type(type):
		return
	place_type = type
	place_params = params.duplicate()
	if rot >= 0:
		place_rot = rot
	select(-1)
	set_tool(Tool.PLACE)
	_refresh_pointer()


## Escape / right click: leaves the current action. Returns false if there
## was nothing to cancel (the caller may then open the menu).
func cancel() -> bool:
	if tool == Tool.CONNECT and not _pending_port.is_empty():
		_pending_port = {}
		view.hide_pending_link()
		_update_hint()
		return true
	if tool != Tool.SELECT:
		set_tool(Tool.SELECT)
		return true
	if _dragging:
		_dragging = false
		view.hide_ghost()
		return true
	if selected_id != -1:
		select(-1)
		return true
	return false


func select(id: int) -> void:
	if id != -1 and not world.components.has(id):
		id = -1
	selected_id = id
	view.set_selected(id)
	selection_changed.emit(id)
	_update_hint()


# -----------------------------------------------------------------------------
# Edits (all undoable)
# -----------------------------------------------------------------------------

func place_at(cell: Vector2i) -> SimComponent:
	var check := world.can_place(place_type, cell, place_rot)
	if not check.ok:
		UI.toast(check.reason, &"warning")
		return null
	undo_stack.record(world, "Placer %s" % NxRegistry.definition(place_type).name)
	var c := world.add_component(place_type, cell, place_rot, place_params)
	UI.play_sound(&"click")
	edited.emit()
	return c


func move_component(id: int, cell: Vector2i, rot: int) -> bool:
	var c: SimComponent = world.components.get(id)
	if c == null:
		return false
	var check := world.can_place(c.type, cell, rot, id)
	if not check.ok:
		UI.toast(check.reason, &"warning")
		return false
	undo_stack.record(world, "Déplacer %s" % c.display_name())
	world.move_component(id, cell, rot)
	edited.emit()
	return true


func rotate_selected() -> void:
	var c: SimComponent = world.components.get(selected_id)
	if c == null:
		return
	# Keep the footprint centred while rotating non-square machines.
	var new_rot := (c.rot + 1) % 4
	var old_size := SimWorld.footprint_size(c.type, c.rot)
	var new_size := SimWorld.footprint_size(c.type, new_rot)
	var cell := c.cell + (old_size - new_size) / 2
	move_component(c.id, cell, new_rot)


func delete_selected() -> void:
	var c: SimComponent = world.components.get(selected_id)
	if c == null:
		return
	var label_name := c.display_name()
	undo_stack.record(world, "Supprimer %s" % label_name)
	world.remove_component(c.id)
	select(-1)
	edited.emit()
	UI.toast("%s supprimé. Ctrl+Z pour annuler." % label_name)


func duplicate_selected() -> void:
	var c: SimComponent = world.components.get(selected_id)
	if c == null:
		return
	var params := c.params.duplicate(true)
	begin_place(c.type, params, c.rot)


func connect_ports(a_id: int, a_port: StringName, b_id: int, b_port: StringName) -> bool:
	var check := world.check_connection(a_id, a_port, b_id, b_port)
	if not check.ok:
		UI.toast(check.reason, &"warning")
		UI.play_sound(&"error")
		return false
	undo_stack.record(world, "Relier")
	world.connect_ports(a_id, a_port, b_id, b_port)
	edited.emit()
	return true


func disconnect_link(link_id: int) -> void:
	undo_stack.record(world, "Supprimer une connexion")
	world.disconnect_link(link_id)
	edited.emit()


func set_param(id: int, key: String, value: Variant) -> void:
	var c: SimComponent = world.components.get(id)
	if c == null or c.params.get(key) == value:
		return
	undo_stack.record(world, "Régler %s" % c.display_name(), "param:%d:%s" % [id, key])
	world.set_param(c, key, value)
	edited.emit()


func undo() -> void:
	var label := undo_stack.undo(world)
	if not label.is_empty():
		UI.toast("Annulé : %s" % label)
		edited.emit()


func redo() -> void:
	var label := undo_stack.redo(world)
	if not label.is_empty():
		UI.toast("Rétabli : %s" % label)
		edited.emit()


# -----------------------------------------------------------------------------
# Input
# -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if world == null or UI.has_open_dialog():
		return
	if event is InputEventMouse:
		_mouse = (event as InputEventMouse).position
	if event is InputEventMouseMotion:
		pointer_in_view = true
		_refresh_pointer()
		return
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_on_left_press(mb)
		else:
			_on_left_release()
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
		if camera.right_drag_distance < 5.0:
			cancel()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or world == null or UI.has_open_dialog():
		return
	var handled := true
	var code := key.keycode
	if code == KEY_ESCAPE:
		handled = cancel()
	elif key.ctrl_pressed and (code == KEY_Y or (code == KEY_Z and key.shift_pressed)):
		redo()
	elif key.ctrl_pressed and code == KEY_Z:
		undo()
	elif key.ctrl_pressed and code == KEY_D:
		duplicate_selected()
	elif key.ctrl_pressed or key.alt_pressed or key.echo:
		handled = false
	elif code == KEY_R:
		if tool == Tool.PLACE:
			place_rot = (place_rot + 1) % 4
			_refresh_pointer()
		else:
			rotate_selected()
	elif code == KEY_DELETE or code == KEY_BACKSPACE:
		delete_selected()
	elif code == KEY_V:
		set_tool(Tool.SELECT)
	elif code == KEY_C:
		set_tool(Tool.SELECT if tool == Tool.CONNECT else Tool.CONNECT)
	elif code == KEY_F:
		var c: SimComponent = world.components.get(selected_id)
		if c:
			camera.focus_on(SimWorld.footprint_center(c.type, c.cell, c.rot), 9.0)
		else:
			camera.reset_view()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _on_left_press(mb: InputEventMouseButton) -> void:
	_press_pos = mb.position
	match tool:
		Tool.PLACE:
			var cell = _mouse_anchor(place_type, place_rot)
			if cell != null:
				place_at(cell)
				_refresh_pointer()
		Tool.CONNECT:
			var port := view.pick_port(camera, _mouse_pos())
			if port.is_empty():
				return
			if _pending_port.is_empty():
				_pending_port = port
				UI.play_sound(&"click")
			elif port.c == _pending_port.c and port.p == _pending_port.p:
				_pending_port = {}
			else:
				if connect_ports(_pending_port.c, _pending_port.p, port.c, port.p):
					_pending_port = {}
			view.hide_pending_link()
			_update_hint()
		Tool.SELECT:
			_press_id = _pick_component()
			_dragging = false
			if _press_id != -1:
				var c: SimComponent = world.components[_press_id]
				var hit = _ground_hit()
				if hit != null:
					var anchor := _anchor_for(c.type, c.rot, hit)
					_drag_offset = c.cell - anchor


func _on_left_release() -> void:
	if tool != Tool.SELECT:
		return
	if _dragging:
		_dragging = false
		view.hide_ghost()
		var c: SimComponent = world.components.get(_press_id)
		if c and _drag_cell != c.cell:
			move_component(c.id, _drag_cell, c.rot)
		select(_press_id)
	else:
		select(_press_id)
	_press_id = -1


func _refresh_pointer() -> void:
	if world == null or camera == null:
		return
	match tool:
		Tool.PLACE:
			var cell = _mouse_anchor(place_type, place_rot)
			if cell == null or not pointer_in_view:
				view.hide_ghost()
				return
			_place_cell = cell
			var check := world.can_place(place_type, cell, place_rot)
			view.show_ghost(place_type, cell, place_rot, check.ok)
			var label_name: String = NxRegistry.definition(place_type).name
			if check.ok:
				_set_hint("Clic : placer %s · R : pivoter · Clic droit ou Échap : terminer" % label_name)
			else:
				_set_hint("Placement impossible : %s" % check.reason)
		Tool.CONNECT:
			var port := view.pick_port(camera, _mouse_pos())
			_hover_port = port
			view.set_hover_port(port)
			if not _pending_port.is_empty():
				var a: SimComponent = world.components.get(_pending_port.c)
				if a == null:
					_pending_port = {}
					return
				var from := world.port_position(a, _pending_port.p)
				var type: StringName = a.port_def(_pending_port.p).type
				if not port.is_empty():
					var b: SimComponent = world.components[port.c]
					var check := world.check_connection(_pending_port.c, _pending_port.p, port.c, port.p)
					view.show_pending_link(from, world.port_position(b, port.p), type, check.ok)
					_set_hint(("Relier à %s · %s" % [b.display_name(), b.port_def(port.p).label]) if check.ok \
						else check.reason)
				else:
					var hit = _ground_hit()
					if hit != null:
						view.show_pending_link(from, hit + Vector3(0, 0.3, 0), type, true)
					_update_hint()
			elif not port.is_empty():
				var c: SimComponent = world.components[port.c]
				var pd := c.port_def(port.p)
				_set_hint("%s · %s (%s)" % [c.display_name(), pd.label, NxPort.type_name(pd.type)])
			else:
				_update_hint()
		Tool.SELECT:
			if _press_id != -1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
					and _mouse_pos().distance_to(_press_pos) > DRAG_THRESHOLD:
				var c: SimComponent = world.components.get(_press_id)
				var hit = _ground_hit()
				if c and hit != null:
					_dragging = true
					_drag_cell = _anchor_for(c.type, c.rot, hit) + _drag_offset
					var check := world.can_place(c.type, _drag_cell, c.rot, c.id)
					view.show_ghost(c.type, _drag_cell, c.rot, check.ok)
					_set_hint("Relâchez pour déplacer" if check.ok else "Déplacement impossible : " + check.reason)
				return
			view.set_hovered(_pick_component() if pointer_in_view else -1)


func _update_hint() -> void:
	match tool:
		Tool.PLACE:
			_set_hint("Clic : placer · R : pivoter · Clic droit ou Échap : terminer")
		Tool.CONNECT:
			if _pending_port.is_empty():
				_set_hint("Connexion : cliquez sur un port (sphère colorée) · C ou Échap : quitter")
			else:
				_set_hint("Cliquez sur un port de même couleur · Échap : annuler")
		_:
			if selected_id != -1:
				_set_hint("Glisser : déplacer · R : pivoter · Ctrl+D : dupliquer · Suppr : supprimer · F : centrer")
			else:
				_set_hint("Clic : sélectionner · Clic droit glissé : orbiter · Molette : zoom · ZQSD : se déplacer")


func current_hint() -> String:
	return _base_hint


func _set_hint(text: String) -> void:
	if text != _base_hint:
		_base_hint = text
		hint_changed.emit(text)


func _on_structure_changed() -> void:
	if selected_id != -1 and not world.components.has(selected_id):
		select(-1)
	else:
		selection_changed.emit(selected_id)


# -----------------------------------------------------------------------------
# Geometry helpers
# -----------------------------------------------------------------------------

## Last pointer position seen by the 3D view (viewport coordinates).
func _mouse_pos() -> Vector2:
	return _mouse


func _ground_hit() -> Variant:
	var pos := _mouse_pos()
	var origin := camera.project_ray_origin(pos)
	var dir := camera.project_ray_normal(pos)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)


func _pick_component() -> int:
	var pos := _mouse_pos()
	return view.pick_component(camera.project_ray_origin(pos), camera.project_ray_normal(pos))


## Anchor cell so that the footprint is centred under the mouse.
func _mouse_anchor(type: StringName, rot: int) -> Variant:
	var hit = _ground_hit()
	if hit == null:
		return null
	return _anchor_for(type, rot, hit)


func _anchor_for(type: StringName, rot: int, hit: Vector3) -> Vector2i:
	var size := SimWorld.footprint_size(type, rot)
	return Vector2i(floori(hit.x - size.x * 0.5 + 0.5), floori(hit.z - size.y * 0.5 + 0.5))
