extends Node

## Autoload "Rng" — named, independent PCG32 streams (spec §2.4).
##
## Each domain of the game draws from its own seed stream so that, for example,
## spending a hire reroll does not perturb event randomness.

const STREAM_NAMES: Array[String] = ["hire", "event", "expand", "contract", "combat"]

var account_seed: int = 0

var _streams: Dictionary = {}


func _ready() -> void:
	reset(account_seed)


## Re-seed every stream from an account seed.
func reset(seed_value: int) -> void:
	account_seed = seed_value
	_streams.clear()
	for stream_name in STREAM_NAMES:
		_streams[stream_name] = PCG32.new(_mix(seed_value, stream_name), _seq_for(stream_name))


## Get (creating on demand) the PCG32 stream with the given name.
func stream(stream_name: String) -> PCG32:
	if not _streams.has(stream_name):
		_streams[stream_name] = PCG32.new(_mix(account_seed, stream_name), _seq_for(stream_name))
	return _streams[stream_name]


## 64-bit golden-ratio odd constant (0x9E3779B97F4A7C15 as signed).
const GOLDEN64: int = -7046029254386353131


## Deterministic one-shot value derived from the account seed and a key.
## Useful for "hash(account_seed, key, ...)" style derivation (spec §5.3, §7.4).
## Overflow wraps modulo 2^64, which is the intended mixing behaviour.
func derive(seed_value: int, parts: Array = []) -> int:
	var h: int = seed_value
	for part in parts:
		h = h * 6364136223846793005 + _hash64(part)
	return h


func _mix(seed_value: int, stream_name: String) -> int:
	return seed_value ^ (stream_name.hash() * GOLDEN64)


func _seq_for(stream_name: String) -> int:
	# Keep sequences distinct and positive; the low bit is forced by PCG32.
	return absi(stream_name.hash()) % 0x7FFFFFFF


func _hash64(v: Variant) -> int:
	if v is int:
		return int(v)
	if v is String:
		return v.hash()
	return str(v).hash()