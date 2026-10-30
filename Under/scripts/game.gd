extends Node

signal dialogue(text: String, duration: float)

var has_key := false
var door_open := false
var flashlight_on := true
var game_over := false
var escaped := false
var chasing := false
var atmosphere := 100.0
var shake_power := 0.0
var shake_time := 0.0
var intro_seen := false

var _music: AudioStreamPlayer
var _music_name := ""
var _cache := {}
var _said := {}


func _ready() -> void:
	_setup_input()
	_music = AudioStreamPlayer.new()
	add_child(_music)


func _process(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta


func reset() -> void:
	has_key = false
	door_open = false
	flashlight_on = true
	game_over = false
	escaped = false
	chasing = false
	atmosphere = 100.0
	shake_power = 0.0
	shake_time = 0.0
	_said.clear()


func say(text: String, duration: float = 3.4) -> void:
	dialogue.emit(text, duration)


func say_once(id: String, text: String, duration: float = 3.4) -> void:
	if _said.has(id):
		return
	_said[id] = true
	dialogue.emit(text, duration)


func shake(power: float, time: float) -> void:
	shake_power = power
	shake_time = time


func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"sprint": [KEY_SHIFT],
		"flashlight": [KEY_F],
		"confirm": [KEY_ENTER, KEY_SPACE],
		"restart": [KEY_R],
		"menu": [KEY_ESCAPE],
		"mission": [KEY_TAB],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func sfx(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream = _find_audio(sound_name)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_music(music_name: String, loop: bool = true, volume_db: float = -4.0) -> void:
	if music_name == _music_name and _music.playing:
		return
	var stream = _find_audio(music_name)
	if stream == null:
		return
	_music_name = music_name
	if stream is AudioStreamOggVorbis:
		stream.loop = loop
	_music.stream = stream
	_music.volume_db = volume_db
	_music.play()


func stop_music() -> void:
	_music.stop()
	_music_name = ""


func _find_audio(audio_name: String):
	if _cache.has(audio_name):
		return _cache[audio_name]
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://audio/%s.%s" % [audio_name, ext]
		if ResourceLoader.exists(path):
			_cache[audio_name] = load(path)
			return _cache[audio_name]
	_cache[audio_name] = null
	return null
