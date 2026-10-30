extends Node

## Autoload "Config" — global constants and runtime configuration (spec §2.4).

const GAME_TITLE: String = "Космо-грузчицы"
const TERMINAL_NAME: String = "Тупик-9"

## Fixed simulation step, seconds (spec §2.3).
const SIM_DT: float = 1.0
## Offline catch-up chunk, seconds (spec §8.7).
const OFFLINE_CHUNK_S: float = 10.0
## Hard numeric ceiling (spec §2.8).
const NUM_CAP: float = 1e60
## Tile size in pixels (spec §2.2).
const TILE: int = 16

## Base shift length in seconds; the first trial shift is shorter (spec §8.1).
const SHIFT_S: float = 300.0
const TRIAL_SHIFT_S: float = 90.0

## Which art pack is active; elements missing from it fall back to placeholder
## (spec §16.6).
var active_pack: String = "placeholder"

var debug_enabled: bool = OS.is_debug_build()