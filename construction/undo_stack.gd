class_name NxUndoStack
extends RefCounted
## Snapshot-based undo/redo for workshop edits.
##
## Call record() *before* changing the world. Consecutive edits with the same
## merge key (e.g. dragging one slider) within MERGE_WINDOW count as one step.

signal changed

const LIMIT := 100
const MERGE_WINDOW := 1.2

var _undo: Array[Dictionary] = []   # { data, label }
var _redo: Array[Dictionary] = []
var _last_key := ""
var _last_time := 0.0


func record(world: SimWorld, label: String, merge_key: String = "") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not merge_key.is_empty() and merge_key == _last_key and now - _last_time < MERGE_WINDOW:
		_last_time = now
		return
	_last_key = merge_key
	_last_time = now
	_undo.append({ "data": world.serialize(), "label": label })
	if _undo.size() > LIMIT:
		_undo.pop_front()
	_redo.clear()
	changed.emit()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo_label() -> String:
	return _undo.back().label if can_undo() else ""


func redo_label() -> String:
	return _redo.back().label if can_redo() else ""


## Restores the previous state. Returns the label of the undone action.
func undo(world: SimWorld) -> String:
	if not can_undo():
		return ""
	var entry: Dictionary = _undo.pop_back()
	_redo.append({ "data": world.serialize(), "label": entry.label })
	world.replace_with(SimWorld.deserialize(entry.data))
	_last_key = ""
	changed.emit()
	return entry.label


func redo(world: SimWorld) -> String:
	if not can_redo():
		return ""
	var entry: Dictionary = _redo.pop_back()
	_undo.append({ "data": world.serialize(), "label": entry.label })
	world.replace_with(SimWorld.deserialize(entry.data))
	_last_key = ""
	changed.emit()
	return entry.label


func clear() -> void:
	_undo.clear()
	_redo.clear()
	changed.emit()
