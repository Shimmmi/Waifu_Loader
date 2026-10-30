class_name Outbox
extends RefCounted

## Outbox queue (spec §13.1): every outgoing mutation is queued with an
## idempotency key so retries are safe. Persisted inside the save file.

var items: Array = []
var _seq_rng: PCG32


func _init(rng_seed: int = 0x7A15) -> void:
	_seq_rng = PCG32.new(rng_seed, 0)


## Add a request; returns its idempotency key. Re-enqueuing the same key is a
## no-op (returns the key unchanged).
func enqueue(path: String, method: String, body: Dictionary, key: String = "") -> String:
	if key == "":
		key = _gen_key()
	for it in items:
		if it["key"] == key:
			return key
	items.append({ "path": path, "method": method, "body": body, "key": key, "attempts": 0 })
	return key


func peek() -> Dictionary:
	return items[0] if not items.is_empty() else {}


func pop() -> Dictionary:
	return items.pop_front() if not items.is_empty() else {}


func size() -> int:
	return items.size()


func contains_key(key: String) -> bool:
	for it in items:
		if it["key"] == key:
			return true
	return false


func to_array() -> Array:
	return items.duplicate(true)


func load_array(arr: Array) -> void:
	items = arr.duplicate(true)


func _gen_key() -> String:
	# Deterministic 16-hex key from the outbox RNG (order-dependent).
	var hi: int = _seq_rng.next_uint32()
	var lo: int = _seq_rng.next_uint32()
	return "%08x%08x" % [hi, lo]