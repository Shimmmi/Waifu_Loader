extends Node

## Autoload "Audio" — SFX/music plumbing (spec §16.4). Bus setup, a small player
## pool and a name→stream registry. With no audio files present every call is a
## silent no-op, so nothing breaks while assets are missing.

const SFX_BUS: String = "SFX"
const MUSIC_BUS: String = "Music"
const POOL: int = 8

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _registry: Dictionary = {}


func _ready() -> void:
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	add_child(_music)
	register_defaults()


## Map a logical sound name to a file. Missing files are simply skipped.
func register_defaults() -> void:
	var names := ["ui", "rush", "hire", "coin", "shift_end", "contract", "fail"]
	for n in names:
		_registry[n] = "res://assets/audio/%s.ogg" % n


func play_sfx(sound_name: String) -> void:
	if GameState != null and GameState.muted:
		return
	var path: String = String(_registry.get(sound_name, ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return


func play_music(path: String) -> void:
	if GameState != null and GameState.muted:
		return
	if not ResourceLoader.exists(path):
		return
	_music.stream = load(path)
	_music.play()


func stop_music() -> void:
	_music.stop()


func _ensure_bus(bus_name: String) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)