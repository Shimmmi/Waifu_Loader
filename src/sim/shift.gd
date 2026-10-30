class_name Shift
extends RefCounted

## A single work shift driving one LineSim (spec §8.1, §8.8, §8.9).
##
## The Shift owns timing, the "Rush" burst and the end-of-shift report. It is
## pure logic (RefCounted) so the whole thing runs headless.

enum State { IDLE, RUNNING, REPORT }

const RUSH_DURATION: float = 10.0
const RUSH_COOLDOWN: float = 45.0
const RUSH_MULT: float = 1.5

var line: LineSim
var duration_s: float
var elapsed_s: float = 0.0
var state: State = State.IDLE

var rush_until_s: float = -1.0
var rush_cooldown_s: float = 0.0

var _base_unload: float = 0.0
var _base_move: float = 0.0
var _base_store: float = 0.0

# Snapshots taken at start(), so the report reflects this shift only.
var _base_stored: float = 0.0
var _base_credits: float = 0.0

# Report fields, filled at the end of the shift.
var tonnes: float = 0.0
var credits: float = 0.0
var grade: String = "D"
var rep_gain: float = 0.0
## Current company rank, used to scale reputation gain (set by GameState).
var rank: int = 1


func _init(p_line: LineSim, p_duration: float = 300.0) -> void:
	line = p_line
	duration_s = p_duration


## Set the crew-derived station rates that the shift scales with Rush.
func set_base_rates(unload: float, move: float, store: float) -> void:
	_base_unload = unload
	_base_move = move
	_base_store = store
	line.set_rates(unload, move, store)


func start() -> void:
	state = State.RUNNING
	elapsed_s = 0.0
	rush_until_s = -1.0
	rush_cooldown_s = 0.0
	_base_stored = line.stored
	_base_credits = line.credits
	line.set_rates(_base_unload, _base_move, _base_store)


func is_running() -> bool:
	return state == State.RUNNING


func rush_available() -> bool:
	return is_running() and rush_cooldown_s <= 0.0


func rush() -> bool:
	if not rush_available():
		return false
	rush_until_s = elapsed_s + RUSH_DURATION
	rush_cooldown_s = RUSH_COOLDOWN
	return true


func progress() -> float:
	return clampf(elapsed_s / maxf(duration_s, 1e-6), 0.0, 1.0)


## Advance the shift by dt seconds. No-op unless RUNNING.
func tick(dt: float) -> void:
	if state != State.RUNNING:
		return
	elapsed_s += dt
	var mult: float = RUSH_MULT if elapsed_s <= rush_until_s else 1.0
	line.set_rates(_base_unload * mult, _base_move * mult, _base_store * mult)
	line.step(dt)
	if rush_cooldown_s > 0.0:
		rush_cooldown_s = maxf(0.0, rush_cooldown_s - dt)
	if elapsed_s >= duration_s:
		_finish()


func report() -> Dictionary:
	return {
		"tonnes": tonnes,
		"credits": credits,
		"grade": grade,
		"rep": rep_gain,
		"seconds": duration_s,
	}


func _finish() -> void:
	state = State.REPORT
	tonnes = line.stored - _base_stored
	credits = line.credits - _base_credits
	var expected: float = minf(line.lambda, minf(_base_unload, minf(_base_move, _base_store))) \
		* (duration_s / 60.0) * 0.9
	var ratio: float = (tonnes / expected) if expected > 0.0 else 0.0
	grade = _grade(ratio)
	rep_gain = _rep(grade, rank)


func _grade(ratio: float) -> String:
	if ratio >= 1.25:
		return "S"
	if ratio >= 1.05:
		return "A"
	if ratio >= 0.85:
		return "B"
	if ratio >= 0.60:
		return "C"
	return "D"


func _rep(g: String, at_rank: int) -> float:
	var table := {"S": 14.0, "A": 9.0, "B": 5.0, "C": 2.5, "D": 1.0}
	return float(table.get(g, 1.0)) * (1.0 + 0.1 * (at_rank - 1))