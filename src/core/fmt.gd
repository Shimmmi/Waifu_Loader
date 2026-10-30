class_name Fmt
extends RefCounted

## Number and text formatting helpers (spec §2.8).
##
## Numbers below 1000 are shown whole; larger values use the K/M/B/T suffix
## ladder and fall back to scientific notation past the ladder's reach.

const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


## Format a value for display. `scientific` forces scientific notation.
static func num(value: float, scientific: bool = false) -> String:
	if is_nan(value):
		return "NaN"
	if is_inf(value):
		return "∞" if value > 0.0 else "-∞"

	var sign_str: String = ""
	var v: float = value
	if v < 0.0:
		sign_str = "-"
		v = -v

	if v == 0.0:
		return "0"

	if scientific or v >= 1e36:
		return sign_str + _sci(v)

	if v < 1000.0:
		if absf(v - roundf(v)) < 0.05:
			return sign_str + str(int(roundf(v)))
		return sign_str + String.num(v, 1)

	var idx: int = int(floor(log(v) / log(1000.0)))
	idx = clampi(idx, 1, SUFFIXES.size() - 1)
	var scaled: float = v / pow(1000.0, idx)
	# Roll over if rounding pushed us to the next suffix (e.g. 999 999 -> 1M).
	if roundf(_trim_value(scaled)) >= 1000.0 and idx < SUFFIXES.size() - 1:
		idx += 1
		scaled = v / pow(1000.0, idx)
	return sign_str + _trim(scaled) + SUFFIXES[idx]


## Format a whole number of seconds as mm:ss or h:mm:ss.
static func time(seconds: float) -> String:
	var total: int = int(max(0.0, floor(seconds)))
	var h: int = int(total / 3600.0)
	var m: int = int((total % 3600) / 60.0)
	var s: int = total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]


static func _trim_value(v: float) -> float:
	return roundf(v) if v >= 100.0 else v


static func _trim(v: float) -> String:
	if v >= 100.0 or absf(v - roundf(v)) < 0.05:
		return str(int(roundf(v)))
	return String.num(v, 1)


static func _sci(v: float) -> String:
	var e: int = int(floor(log(v) / log(10.0)))
	var m: float = v / pow(10.0, e)
	return "%se%d" % [String.num(m, 2), e]