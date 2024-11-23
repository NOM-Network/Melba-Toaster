extends Node

@onready var voice_bus := AudioServer.get_bus_index("Voice")

@export var cancel_sound: AudioStreamPlayer
@export var speech_player: AudioStreamPlayer
@export var song_player: AudioStreamPlayer

var subtitles: Array

var speech_duration := 0.0
var song_duration := 0.0

# region PROCESS

func _ready() -> void:
	_connect_signals()

func _process(_delta: float) -> void:
	var full_position: Array[float] = get_position()
	var pos: float = full_position[0]

	if subtitles and pos > subtitles[0][0]:
		_match_command(subtitles.pop_front())

# endregion

# region SIGNALS

func _connect_signals() -> void:
	Globals.start_speech.connect(_on_start_speech)

	Globals.start_singing.connect(_on_start_singing)
	Globals.stop_singing.connect(_on_stop_singing)

func _on_start_speech() -> void:
	if not speech_player.stream:
		printerr("No speech stream")
		return

	Globals.is_speaking = true
	speech_player.play()

func _on_start_singing(song: Song, seek_time := 0.0) -> void:
	prepare_song(song)
	subtitles = song.load_subtitles_file()

	play_song(seek_time)

func _on_stop_singing() -> void:
	Globals.is_singing = false

	reset_speech_player()
	reset_song_player()

	AudioServer.set_bus_mute(voice_bus, false)
	AudioServer.set_bus_effect_enabled(voice_bus, 1, false)

func _on_speech_player_finished() -> void:
	var random_wait := randf_range(0.05, 0.69)
	print("-- Waiting for %f seconds" % random_wait)
	await get_tree().create_timer(random_wait).timeout

	Globals.is_speaking = false
	reset_speech_player()

	Globals.speech_done.emit()

func _on_song_player_finished() -> void:
	subtitles = []

	Globals.stop_singing.emit()

# endregion

func _match_command(line: Array) -> void:
	var text: String = line[1]

	if not text.begins_with("&"):
		Globals.set_subtitles_fast.emit(text.c_unescape())
		return

	var command: Array = text.split(" ")
	match command:
		["&CLEAR"]:
			Globals.set_subtitles_fast.emit("")

		["&START", var bpm]:
			Globals.start_dancing_motion.emit(bpm)

		["&STOP"]:
			Globals.end_dancing_motion.emit()

		["&PIN", var asset_name, var enabled]:
			Globals.pin_asset.emit(asset_name, enabled == "1")

		["&POSITION", var model_position]:
			Globals.change_position.emit(model_position)

		["&TOGGLE", var toggle_name, var enabled]:
			Globals.set_toggle.emit(toggle_name, enabled == "1")

		["&ANIM", var anim_name]:
			Globals.play_animation.emit(anim_name)

		["&FILTER", var source_name, var filter_name, var enabled]:
			Globals.toggle_filter.emit(source_name, filter_name, enabled == "1")

		["&SOURCE", var source_name, var enabled]:
			Globals.obs_action.emit("toggle_scene_source", [source_name, enabled == "1"])

		_:
			printerr("SONG: `%s` is not a valid command, ignoring..." % command)

# region PUBLIC FUNCTIONS

func play_speech() -> void:
	if not speech_player.stream:
		printerr("No speech stream")
		return

	Globals.is_speaking = true
	speech_player.play()

func play_cancel_sound() -> void:
	Globals.is_speaking = true
	cancel_sound.play()
	await cancel_sound.finished
	Globals.is_speaking = false

func prepare_speech(message: PackedByteArray) -> void:
	speech_player.stream = AudioStreamOggVorbis.load_from_buffer(message)

	if not speech_player.stream:
		return

	speech_duration = speech_player.stream.get_length()

func reset_speech_player() -> void:
	speech_player.stop()
	speech_player.stream = null
	speech_duration = 0.0

func prepare_song(song: Song) -> void:
	AudioServer.set_bus_mute(voice_bus, song.mute_voice)
	AudioServer.set_bus_effect_enabled(voice_bus, 1, song.reverb)

	song_player.stream = song.load("song")
	speech_player.stream = song.load("voice")

	song_duration = song_player.stream.get_length()

func play_song(seek_time := 0.0) -> void:
	Globals.is_singing = true
	song_player.play(seek_time)
	speech_player.play(seek_time)

func reset_song_player() -> void:
	song_player.stop()
	song_player.stream = null
	song_duration = 0.0

func get_position() -> Array[float]:
	var comp := Globals.get_audio_compensation()
	return [song_player.get_playback_position() + comp, comp]

func beats_counter_data(full_position: Array[float]) -> Array:
	var position := full_position[0]
	var beat := position * Globals.dancing_bpm / 60.0
	var seconds := position as int

	return [
		seconds / 60.0,
		seconds % 60,
		position,
		full_position[1],
		song_duration / 60.0,
		song_duration as int % 60,
		song_duration,
		Globals.dancing_bpm,
		beat as int % 4 + 1,
	]

# endregion
