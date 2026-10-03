## Music and sound effects. The sounds are synthesised by scripts/make_sounds.py (our own,
## no licences). Music and effects can each be switched off in Settings; the choice is
## remembered in the player's settings file. Each game plays its era's track from music/
## (named by the scenario or the civilisation, D-208); the title screen keeps the theme.
class_name GameAudio
extends Node

const SETTINGS := "user://settings.cfg"
const SOUNDS := ["click", "end_turn", "speak", "idea", "war", "victory", "march", "clash", "horn", "defeat"]

var music_on := true
var effects_on := true
var _music := AudioStreamPlayer.new()
var _players := {}
var _theme: AudioStream
var _track := ""


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS) == OK:
		music_on = bool(config.get_value("audio", "music", true))
		effects_on = bool(config.get_value("audio", "effects", true))
	var theme: AudioStreamWAV = load("res://sounds/theme.wav")
	theme.loop_mode = AudioStreamWAV.LOOP_FORWARD
	theme.loop_begin = 0
	theme.loop_end = theme.data.size() / 2  # 16-bit mono: two bytes a sample
	_theme = theme
	_music.stream = theme
	_music.volume_db = -8.0
	add_child(_music)
	for name in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://sounds/%s.wav" % name)
		player.volume_db = -4.0
		add_child(player)
		_players[name] = player
	if music_on:
		_music.play()


## Switch to an era's track ("roman", "asian", ...); "" or an unknown name plays the theme.
func set_era(track: String) -> void:
	if track == _track:
		return
	_track = track
	var path := "res://music/%s.mp3" % track
	var stream: AudioStream = _theme
	if track != "" and ResourceLoader.exists(path):
		var mp3: AudioStreamMP3 = load(path)
		mp3.loop = true
		stream = mp3
	_music.stream = stream
	if music_on:
		_music.play()


## Play one effect by name (see SOUNDS).
func play(name: String) -> void:
	if effects_on and _players.has(name):
		(_players[name] as AudioStreamPlayer).play()


func set_music(on: bool) -> void:
	music_on = on
	if on and not _music.playing:
		_music.play()
	elif not on:
		_music.stop()
	_save()


func set_effects(on: bool) -> void:
	effects_on = on
	_save()


func _save() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("audio", "music", music_on)
	config.set_value("audio", "effects", effects_on)
	config.save(SETTINGS)
