class_name SimulationRunner
extends Node
## Runs a SimWorld at a fixed rate, independent of the frame rate.
##
## Start keeps a snapshot of the dynamic state (tank contents, time) so that
## Reset brings the installation back to where it was before running.

signal state_changed(state: int)
signal ticked
signal speed_changed(speed: float)

enum State { STOPPED, RUNNING, PAUSED }

const TICK := 0.05            ## 20 simulation steps per simulated second.
const MAX_STEPS_PER_FRAME := 8
const SPEEDS := [1.0, 2.0, 4.0]

var world: SimWorld
var state: int = State.STOPPED
var speed := 1.0
var _accumulator := 0.0
var _snapshot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if state != State.RUNNING or world == null:
		return
	_accumulator += delta * speed
	var steps := 0
	while _accumulator >= TICK and steps < MAX_STEPS_PER_FRAME:
		world.step(TICK)
		_accumulator -= TICK
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		# Too slow to keep up: drop the backlog rather than spiral.
		_accumulator = 0.0
	if steps > 0:
		ticked.emit()


func start() -> void:
	if state == State.RUNNING:
		return
	if state == State.STOPPED:
		_snapshot = world.capture_dynamic()
	_set_state(State.RUNNING)


func pause() -> void:
	if state == State.RUNNING:
		_set_state(State.PAUSED)


func toggle() -> void:
	if state == State.RUNNING:
		pause()
	else:
		start()


func reset() -> void:
	if state == State.STOPPED:
		return
	world.restore_dynamic(_snapshot)
	_accumulator = 0.0
	_set_state(State.STOPPED)
	# One step without time so statuses reflect the restored state.
	world.step(0.0)
	world.time = _snapshot.get("time", 0.0)
	ticked.emit()


## Runs a number of steps immediately (tests, tools).
func advance(steps: int) -> void:
	for i in steps:
		world.step(TICK)
	ticked.emit()


func set_speed(value: float) -> void:
	speed = value
	speed_changed.emit(speed)


func is_running() -> bool:
	return state == State.RUNNING


func _set_state(value: int) -> void:
	state = value
	world.running = state == State.RUNNING
	state_changed.emit(state)
