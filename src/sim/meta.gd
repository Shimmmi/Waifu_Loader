class_name Meta
extends RefCounted

## Pure meta-game formulas (spec §12).


## Shares earned by a Reorganisation (spec §12.3): floor(4 * (T_run/1e5)^0.45).
static func shares(t_run: float) -> int:
	return int(floor(4.0 * pow(maxf(t_run, 0.0) / 1e5, 0.45)))


## Reputation required for a rank (spec §3.5): round(12 * 1.5^(n-1)).
static func rep_needed(for_rank: int) -> float:
	return round(12.0 * pow(1.5, for_rank - 1))


## Passive income bonus from accumulated shares, capped at +300% (spec §12.3).
static func shares_income_bonus(total_shares: int) -> float:
	return minf(0.01 * float(total_shares), 3.0)