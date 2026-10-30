class_name LineSim
extends RefCounted

## One cargo line: arrival queue Q0 -> buffer B1 (dock) -> buffer B2 (storage)
## -> placed (income). This is the heart of the game (spec §8.4).
##
## Pure RefCounted logic: no nodes, no timers, no autoloads — so it runs
## identically in headless tests and on the server validator.
##
## Conservation invariant after any sequence of steps:
##     arrived == stored + waste + missed + sum_of_buffers - initial_sum

var catalog: Catalog

# Buffers, tons per cargo type.
var q0 := PackedFloat32Array()
var b1 := PackedFloat32Array()
var b2 := PackedFloat32Array()

var q0_cap: float = 60.0
var b1_cap: float = 100.0
var b2_cap: float = 150.0

# Station throughput, t/min (already includes crew and modifiers).
var rate_unload: float = 0.0
var rate_move: float = 0.0
var rate_store: float = 0.0

# Arrival.
var lambda: float = 0.0
var inflow := PackedFloat32Array()

# Income.
var tariff: float = 1.0
var income_mult: float = 1.0

# Perishable handling (spec §8.3): cargo sitting in B1+B2 longer than the limit
# loses value. Approximated by tracking the age-weighted perishable mass.
var perishable_limit_s: float = 120.0
var perishable_loss_per_min: float = 0.05

# Accumulators.
var arrived: float = 0.0
var stored: float = 0.0
var waste: float = 0.0
var missed: float = 0.0
var credits: float = 0.0
var time_s: float = 0.0

var _perishable_index: int = -1


## Build a line for a catalog. Buffers sized to the cargo type count.
static func create(p_catalog: Catalog) -> LineSim:
	var s := LineSim.new()
	s.catalog = p_catalog
	var k: int = p_catalog.size()
	s.q0.resize(k)
	s.b1.resize(k)
	s.b2.resize(k)
	s.inflow.resize(k)
	s._perishable_index = p_catalog.index.get("perishable", -1)
	return s


func set_inflow(rate_tpm: float, mix: PackedFloat32Array) -> void:
	lambda = rate_tpm
	inflow = mix.duplicate()
	if inflow.size() != catalog.size():
		inflow.resize(catalog.size())


func set_rates(unload: float, move: float, store: float) -> void:
	rate_unload = unload
	rate_move = move
	rate_store = store


## Advance the simulation by `dt` seconds. Order is fixed (spec §8.4).
func step(dt: float) -> void:
	var scale: float = dt / 60.0
	time_s += dt

	# 1. Arrival into Q0, overflow -> missed.
	if lambda > 0.0:
		var want: float = lambda * scale
		var space: float = maxf(0.0, q0_cap - _sum(q0))
		var added: float = minf(want, space)
		arrived += want
		missed += want - added
		if added > 0.0:
			for k in catalog.size():
				q0[k] += added * inflow[k]

	# 2. Q0 -> B1 (unload).
	_transfer(q0, b1, rate_unload, catalog.phi_unload, scale, b1_cap)

	# 3. B1 -> B2 (move).
	_transfer(b1, b2, rate_move, catalog.phi_move, scale, b2_cap)

	# 4. B2 -> placed (store): income + defect waste.
	_store(scale)

	# 5. Perishable spoilage.
	_spoil(dt)


## Move cargo from src into dst, limited by effective rate and dst free space.
func _transfer(src: PackedFloat32Array, dst: PackedFloat32Array, rate: float, phi: PackedFloat32Array, scale: float, dst_cap: float) -> float:
	var src_total: float = _sum(src)
	if src_total <= 0.0 or rate <= 0.0:
		return 0.0
	var rate_eff: float = _effective_rate(rate, src, phi)
	var space: float = maxf(0.0, dst_cap - _sum(dst))
	var amount: float = minf(minf(src_total, rate_eff * scale), space)
	if amount <= 0.0:
		return 0.0
	for k in src.size():
		var moved: float = amount * (src[k] / src_total)
		src[k] -= moved
		dst[k] += moved
	return amount


## Harmonic-mean effective rate for a mixed flow (spec §8.3):
##   R_eff = R / sum_k(f_k / phi_k)
func _effective_rate(rate: float, flow: PackedFloat32Array, phi: PackedFloat32Array) -> float:
	var total: float = _sum(flow)
	if total <= 0.0:
		return rate
	var denom: float = 0.0
	for k in flow.size():
		if flow[k] > 0.0:
			denom += (flow[k] / total) / maxf(phi[k], 1e-6)
	if denom <= 0.0:
		return rate
	return rate / denom


func _store(scale: float) -> void:
	var total: float = _sum(b2)
	if total <= 0.0 or rate_store <= 0.0:
		return
	var rate_eff: float = _effective_rate(rate_store, b2, catalog.phi_store)
	var amount: float = minf(total, rate_eff * scale)
	if amount <= 0.0:
		return
	# Capture per-type shares before mutating.
	var defect_mass: float = 0.0
	var income: float = 0.0
	for k in b2.size():
		if b2[k] <= 0.0:
			continue
		var moved: float = amount * (b2[k] / total)
		b2[k] -= moved
		defect_mass += moved * catalog.defect[k]
		income += moved * (1.0 - catalog.defect[k]) * catalog.price[k]
	stored += amount - defect_mass
	waste += defect_mass
	credits += income * tariff * income_mult


func _spoil(_dt: float) -> void:
	# Perishable decay needs real per-ton age tracking (how long each batch has
	# sat in the buffers); deferred to the perishable/contract milestone so that
	# M1's conservation invariant stays exact. Placeholder for now.
	if _perishable_index < 0:
		return


func buffer_total() -> float:
	return _sum(q0) + _sum(b1) + _sum(b2)


func _sum(arr: PackedFloat32Array) -> float:
	var s: float = 0.0
	for v in arr:
		s += v
	return s