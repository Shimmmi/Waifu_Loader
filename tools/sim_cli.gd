extends SceneTree

## Headless CLI simulation of a single line (part of M1's DoD: "CLI 8-hour
## simulation"). Builds a line purely from res://data, runs it, and prints the
## totals + a conservation check.
##
## Run:  godot --headless --path <project> -s tools/sim_cli.gd

const HOURS: float = 8.0


func _init() -> void:
	var cargo: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cargo.json"))
	var bal: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	var cat := Catalog.from_dicts(cargo, bal)

	var rank := 3
	var dock := 3
	var store := 1

	var line := LineSim.create(cat)
	line.q0_cap = float(bal.get("q0_cap", 60.0))
	line.b1_cap = float(bal.get("b1_cap_per_level", 100.0)) * dock
	line.b2_cap = float(bal.get("b2_cap_base", 150.0)) * pow(float(bal.get("b2_cap_growth", 1.18)), store - 1)
	line.tariff = cat.tariff(rank)
	line.set_inflow(cat.free_flow_lambda(rank, dock), cat.free_flow_mix(rank))
	# Pretend a modest crew: power 1.0 at each station.
	line.set_rates(
		cat.station_rate("unload", dock, 1.0),
		cat.station_rate("move", dock, 1.0),
		cat.station_rate("store", dock, 1.0))

	var steps := int(HOURS * 3600)
	for i in steps:
		line.step(1.0)

	var rhs: float = line.stored + line.waste + line.missed + line.buffer_total()
	var conserved: bool = absf(line.arrived - rhs) < 1e-2

	print("=== sim_cli: %.0f h @ rank %d, dock L%d ===" % [HOURS, rank, dock])
	print("  arrival  %.1f t/min" % line.lambda)
	print("  arrived  %.1f t" % line.arrived)
	print("  stored   %.1f t" % line.stored)
	print("  waste    %.1f t" % line.waste)
	print("  missed   %.1f t" % line.missed)
	print("  buffers  %.1f t" % line.buffer_total())
	print("  credits  %s (¢)" % Fmt.num(line.credits))
	print("  conservation: %s" % ("OK" if conserved else "BROKEN (%.4f)" % absf(line.arrived - rhs)))
	quit(0 if conserved else 1)