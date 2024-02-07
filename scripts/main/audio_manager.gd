extends Node

@onready var voice_bus := AudioServer.get_bus_index("Voice")

@onready var cancel_sound: AudioStreamPlayer = $CancelSound
@onready var speech_player: AudioStreamPlayer = $SpeechPlayer
@onready var song_player: AudioStreamPlayer = $SongPlayer

var speech_duration := 0.0
var song_duration := 0.0

func _ready() -> void:
	Globals.start_speech.connect(_on_start_speech)
	Globals.stop_singing.connect(_on_stop_singing)

# region PUBLIC FUNCTIONS

func play_cancel_sound() -> void:
	Globals.is_speaking = true
	cancel_sound.play()
	await cancel_sound.finished
	Globals.is_speaking = false

func prepare_speech(message: PackedByteArray) -> void:
	var stream = AudioStreamOggVorbis.load_from_buffer(message)
	speech_player.stream = stream
	speech_duration = stream.get_length()

func play_speech() -> void:
	assert(speech_player.stream, "There is no stream in speech_player")

	Globals.is_speaking = true
	speech_player.play()

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

# region SIGNALS CALLBACK

func _on_start_speech() -> void:
	play_speech()

func _on_speech_player_finished() -> void:
	Globals.is_speaking = false
	reset_speech_player()

	Globals.speech_done.emit()

func _on_stop_singing() -> void:
	finish_song()

func _on_song_player_finished() -> void:
	Globals.stop_singing.emit()

# endregion

# region PRIVATE FUNCTIONS

func finish_song() -> void:
	Globals.is_singing = false

	reset_speech_player()
	reset_song_player()

	AudioServer.set_bus_mute(voice_bus, false)
	AudioServer.set_bus_effect_enabled(voice_bus, 1, false)


# endregion
