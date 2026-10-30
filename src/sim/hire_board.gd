class_name HireBoard
extends RefCounted

## The job exchange (spec §7). Generates a candidate pool deterministically from
## the account seed + refresh index, so reloading never rerolls.

var rules: Rules
var generator: Generator
var rng: PCG32

var pool: Array = []              # Array[Worker]
var refresh_index: int = 0
var paid_refreshes_this_hour: int = 0
var last_refresh_time: float = 0.0


func _init(p_rules: Rules, p_generator: Generator, account_seed: int) -> void:
	rules = p_rules
	generator = p_generator
	var mixed: int = account_seed ^ 0x517369  # account ^ "hire"
	rng = PCG32.new(mixed, 0x48495245)        # seq "HIRE"


## Regenerate the pool. `size` = pool size, `agency` = agency level.
func refresh(size: int, agency: int, now_s: float = 0.0) -> void:
	pool.clear()
	for i in maxi(size, 1):
		var tier: int = generator.next_rarity(rng, agency)
		pool.append(generator.create_worker(rng, tier))
	refresh_index += 1
	last_refresh_time = now_s


## Remove a candidate from the pool and return it (or null).
func take(worker_id: String) -> Worker:
	for i in pool.size():
		if pool[i].id == worker_id:
			return pool.pop_at(i)
	return null


## Signing bonus for a worker (spec §7.4).
func hire_cost(w: Worker) -> float:
	return 6.0 * w.wage_base(rules)


func resume_cost(w: Worker) -> float:
	return 5.0 * w.wage


func interview_cost(w: Worker) -> float:
	return 12.0 * w.wage


## Cost to post an instant-refresh advert (spec §7.1).
func posting_cost(rank: int) -> float:
	return 40.0 * (1.0 + 0.3 * rank) * pow(2.0, paid_refreshes_this_hour)