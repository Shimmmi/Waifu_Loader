extends Node

## Autoload "Clock" — server-synced time with clock-tamper protection (spec §2.4).
##
## The game must reason in wall-clock time (not frame counts), because browsers
## throttle timers in background tabs. This clock keeps an offset to the
## authoritative server time and detects wild local clock changes.

const TAMPER_TOLERANCE_S: float = 300.0  # 5 minutes

## Offset added to local wall-clock time to approximate server time.
var server_offset_s: float = 0.0
var synced: bool = false

var _monotonic_ref_s: float = 0.0
var _local_ref_s: float = 0.0


func _ready() -> void:
	_monotonic_ref_s = _monotonic()
	_local_ref_s = _local()


## Apply the server's unix timestamp; subsequent now() calls track it.
func apply_server_time(server_unix_s: float) -> void:
	server_offset_s = server_unix_s - _local()
	synced = true


## Current best estimate of server unix time (seconds).
func now() -> float:
	return _local() + server_offset_s


## True when the local wall clock has drifted from the monotonic clock by more
## than the tolerance, which suggests the user manually changed the system time.
func is_tampered() -> bool:
	var wall_elapsed: float = _local() - _local_ref_s
	var monotonic_elapsed: float = _monotonic() - _monotonic_ref_s
	return absf(wall_elapsed - monotonic_elapsed) > TAMPER_TOLERANCE_S


## Elapsed seconds since _ready, using the monotonic clock (tamper-proof).
func uptime() -> float:
	return _monotonic() - _monotonic_ref_s


func _monotonic() -> float:
	return Time.get_ticks_msec() / 1000.0


func _local() -> float:
	return float(Time.get_unix_time_from_system())