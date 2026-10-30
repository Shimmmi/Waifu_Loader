class_name PCG32
extends RefCounted

## PCG32 pseudo-random generator (Melissa O'Neill, PCG family).
##
## Deliberately NOT Godot's RandomNumberGenerator: this implementation is
## deterministic and identical on every platform, which is required so the
## client Sim and the headless server validator produce identical results
## (spec §2.4, §14.6).
##
## State is a signed 64-bit int holding an unsigned wraparound value; all
## right-shifts go through _lsr() to emulate a logical (zero-filling) shift.

const MUL: int = 6364136223846793005  # 6364136223846793005

var _state: int = 0
var _inc: int = 1


func _init(seed_value: int = 0, seq: int = 0) -> void:
	seed_with(seed_value, seq)


## Seed the generator. `seed_value` is the entropy, `seq` selects the stream
## (two different seq values never produce the same sequence).
func seed_with(seed_value: int, seq: int = 0) -> void:
	_state = 0
	_inc = (seq << 1) | 1
	next_uint32()
	_state = _state + seed_value
	next_uint32()


## Return the next 32-bit value as a non-negative int in [0, 2^32).
func next_uint32() -> int:
	var old: int = _state
	_state = old * MUL + _inc
	var xorshifted: int = _lsr(_lsr(old, 18) ^ old, 27) & 0xFFFFFFFF
	var rot: int = _lsr(old, 59) & 31
	return ((xorshifted >> rot) | (xorshifted << ((-rot) & 31))) & 0xFFFFFFFF


## Return an unbiased integer in [0, bound) via rejection sampling.
func next_bounded(bound: int) -> int:
	if bound <= 0:
		push_error("PCG32.next_bounded: bound must be > 0 (got %d)" % bound)
		return 0
	if bound == 1:
		return 0
	var threshold: int = (4294967296 - bound) % bound
	while true:
		var r: int = next_uint32()
		if r >= threshold:
			return r % bound
	return 0  # unreachable


## Return an integer in [from, to] (inclusive).
func next_range(from: int, to: int) -> int:
	if to < from:
		var t: int = from
		from = to
		to = t
	return from + next_bounded(to - from + 1)


## Return a float in [0.0, 1.0).
func next_float() -> float:
	return next_uint32() / 4294967296.0


## Return a float in [from, to).
func next_float_range(from: float, to: float) -> float:
	return from + next_float() * (to - from)


## Logical (zero-filling) right shift on a 64-bit value stored in a signed int.
static func _lsr(v: int, n: int) -> int:
	if n <= 0:
		return v
	if n >= 64:
		return 0
	return (v >> n) & ((1 << (64 - n)) - 1)