extends Node
class_name BakkalAudioManager

const MUSIC_PATH := "res://assets/audio/night_shift_theme.wav"
const SETTINGS_PATH := "user://settings.cfg"
const SOUND_EFFECT_PATHS: Dictionary = {
	&"ui_confirm": "res://assets/audio/ui_confirm.wav",
	&"xp_collect": "res://assets/audio/xp_collect.wav",
	&"level_up": "res://assets/audio/level_up.wav",
	&"player_hurt": "res://assets/audio/player_hurt.wav",
	&"boss_arrival": "res://assets/audio/boss_arrival.wav",
	&"shift_survived": "res://assets/audio/shift_survived.wav",
	&"shift_lost": "res://assets/audio/shift_lost.wav",
}

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}
var _next_sfx_player: int = 0
var music_volume_db: float = -16.0
var sfx_volume_db: float = -7.0


func _ready() -> void:
	_load_settings()
	if DisplayServer.get_name() == "headless":
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	_music_player.volume_db = music_volume_db
	var source_stream := AudioStreamWAV.load_from_file(MUSIC_PATH)
	if source_stream == null:
		push_error("Could not load night-shift music from %s." % MUSIC_PATH)
		return
	var loop_stream := source_stream.duplicate() as AudioStreamWAV
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop_stream.loop_begin = 0
	loop_stream.loop_end = int(loop_stream.mix_rate * loop_stream.get_length())
	_music_player.stream = loop_stream
	add_child(_music_player)
	for sound_id: StringName in SOUND_EFFECT_PATHS:
		var stream := AudioStreamWAV.load_from_file(String(SOUND_EFFECT_PATHS[sound_id]))
		if stream != null:
			_sfx_streams[sound_id] = stream
	for index: int in range(6):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = "Master"
		player.volume_db = sfx_volume_db
		add_child(player)
		_sfx_players.append(player)


func _exit_tree() -> void:
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	for player: AudioStreamPlayer in _sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_sfx_players.clear()
	_sfx_streams.clear()


func play_music() -> void:
	if is_instance_valid(_music_player) and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	if is_instance_valid(_music_player):
		_music_player.stop()


func play_sfx(sound_id: StringName) -> void:
	if _sfx_players.is_empty() or not _sfx_streams.has(sound_id):
		return
	var player := _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	player.stop()
	player.stream = _sfx_streams[sound_id]
	player.volume_db = sfx_volume_db
	player.play()


func set_music_volume(value: float) -> void:
	music_volume_db = clampf(value, -40.0, 0.0)
	if is_instance_valid(_music_player):
		_music_player.volume_db = music_volume_db


func set_sfx_volume(value: float) -> void:
	sfx_volume_db = clampf(value, -40.0, 0.0)
	for player: AudioStreamPlayer in _sfx_players:
		player.volume_db = sfx_volume_db


func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "music_db", music_volume_db)
	config.set_value("audio", "sfx_db", sfx_volume_db)
	config.save(SETTINGS_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		music_volume_db = clampf(float(config.get_value("audio", "music_db", music_volume_db)), -40.0, 0.0)
		sfx_volume_db = clampf(float(config.get_value("audio", "sfx_db", sfx_volume_db)), -40.0, 0.0)
