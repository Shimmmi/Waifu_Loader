class_name ChainRuntime
extends RefCounted

## Event-chain progression (spec §11.4). Each chain is a short state machine;
## step N surfaces as an event whose choices may jump steps or end the chain.

var steps: Dictionary = {}       # chain id -> number of steps
var step_keys: Dictionary = {}   # chain id -> [key, ...]
var choices: Dictionary = {}     # chain id -> [choice, ...]
var progress: Dictionary = {}    # chain id -> current step (0 = not started)


static func from_data(d: Dictionary) -> ChainRuntime:
	var c := ChainRuntime.new()
	for row in d.get("chains", []):
		var id: String = String(row["id"])
		c.steps[id] = int(row.get("steps", 0))
		c.step_keys[id] = row.get("step_keys", [])
		c.choices[id] = row.get("choices", [])
	return c


func ids() -> Array:
	return steps.keys()


func step_of(id: String) -> int:
	return int(progress.get(id, 0))


func is_active(id: String) -> bool:
	var s: int = step_of(id)
	return s >= 1 and s <= int(steps.get(id, 0))


func is_finished(id: String) -> bool:
	return step_of(id) > int(steps.get(id, 0))


func start(id: String) -> void:
	if step_of(id) == 0:
		progress[id] = 1


func current_key(id: String) -> String:
	var s: int = step_of(id)
	var keys: Array = step_keys.get(id, [])
	if s >= 1 and s <= keys.size():
		return String(keys[s - 1])
	return ""


func current_choices(id: String) -> Array:
	return choices.get(id, [])


## Advance after `choice_index`; honors an explicit "next" jump. Returns true
## when the chain is finished.
func advance(id: String, choice_index: int = -1) -> bool:
	var s: int = step_of(id)
	if s < 1:
		return false
	var jump: int = 0
	var ch: Array = choices.get(id, [])
	if choice_index >= 0 and choice_index < ch.size():
		jump = int((ch[choice_index] as Dictionary).get("next", 0))
	progress[id] = jump if jump > 0 else s + 1
	return is_finished(id)


func active_ids() -> Array:
	var out: Array = []
	for id in ids():
		if is_active(id):
			out.append(id)
	return out


func finished_count() -> int:
	var n: int = 0
	for id in ids():
		if is_finished(id):
			n += 1
	return n


func to_dict() -> Dictionary:
	return progress.duplicate()


func load_dict(d: Dictionary) -> void:
	progress = d.duplicate()