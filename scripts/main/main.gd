extends Node2D

@export_category("Variables")
@export_range(0.5, 10, 0.01) var time_before_cleanout: float = 3.0
@export_range(0.5, 10, 0.01) var time_before_ready: float = 2.0

@export_category("Nodes")
@export var client: WebSocketClient
@export var control_panel: Window
@export var subtitles: RichTextLabel
@export var mic: AnimatedSprite2D

@export_group("Sound Bus")
@export var cancel_sound: AudioStreamPlayer
@export var speech_player: AudioStreamPlayer
@export var song_player: AudioStreamPlayer

var voice_bus := AudioServer.get_bus_index("Voice")

# Cleanout stuff
var subtitles_cleanout := false
var subtitles_duration := 0.0

func _ready():
	# Makes bg transparent
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)

	# Defaults
	subtitles.text = ""
	Globals.is_paused = true

	# Signals
	Globals.new_speech.connect(_on_new_speech)
	Globals.cancel_speech.connect(_on_cancel_speech)
	Globals.start_singing.connect(_on_start_singing)
	Globals.stop_singing.connect(_on_stop_singing)

	# Waiting for the backend
	await client.connection_established
	control_panel.backend_connected()
	client.data_received.connect(_on_data_received)
	client.connection_closed.connect(_on_connection_closed)

	# Ready for speech
	Globals.ready_for_speech.connect(_on_ready_for_speech)

func _on_data_received(data: Dictionary):
	if Globals.is_paused:
		return

	if data.type == "binary":
		if Globals.is_speaking:
			printerr("Audio while blabbering")
			return

		# Testing for MP3
		var header = data.message.slice(0, 2)
		if not (header == PackedByteArray([255, 251]) or header == PackedByteArray([73, 68])):
			printerr("%s is not an MP3 file! Skipping..." % [header])
			return

		# Preparing for speaking
		prepare_speech(data.message)
		Globals.incoming_speech.emit(data.message)
	else:
		var message = JSON.parse_string(data.message)

		match message.type:
			"PlayAnimation":
				Globals.play_animation.emit(message.animationName)

			"SetExpression":
				Globals.set_expression.emit(message.expressionName)

			"SetToggle":
				Globals.set_toggle.emit(message.toggleName, message.enabled)

			"NewSpeech":
				if not Globals.is_speaking:
					Globals.new_speech.emit(message.prompt, message.text)
				else:
					print_debug("NewSpeech while blabbering")

			_:
				print("Unhandled data type: ", message)

func _process(delta):
	if Globals.is_speaking or Globals.is_singing:
		if subtitles.visible_ratio <= 1.0:
			subtitles.visible_ratio += ((1.0 / subtitles_duration) + 0.01) * delta
	else:
		if subtitles.visible_ratio > 0.0 && subtitles_cleanout:
			subtitles.visible_ratio -= 0.05

func _on_speech_player_finished():
	Globals.is_speaking = false
	speech_player.stream = null

	if (Globals.is_singing):
		Globals.stop_singing.emit()

	trigger_cleanout()
	Globals.speech_done.emit()

func prepare_speech(message: PackedByteArray):
	var stream = AudioStreamMP3.new()
	stream.data = message
	subtitles_duration = stream.get_length()
	speech_player.stream = stream

func play_audio() -> void:
	if speech_player.stream:
		Globals.is_speaking = true
		speech_player.play()
	else:
		printerr("NO AUDIO FOR THE MESSAGE!")

func _on_ready_for_speech():
	if not Globals.is_paused:
		client.send_message({"type": "ReadyForSpeech"})

func _on_new_speech(_prompt, text):
	_print_subtitles(text)

	play_audio()

func _print_subtitles(text):
	subtitles_cleanout = false
	subtitles.visible_ratio = 0.0

	if text.length() > 300:
		subtitles.add_theme_font_size_override("normal_font_size", 20)
	else:
		subtitles.remove_theme_font_size_override("normal_font_size")

	if text:
		subtitles.text = "[center]%s" % text
	else:
		subtitles.text = "[center]tsh mebla"

func _on_cancel_speech():
	Globals.set_toggle.emit("void", true)

	speech_player.stop()
	speech_player.stream = null
	cancel_sound.play()

	Globals.is_speaking = false
	subtitles_cleanout = false
	subtitles.visible_ratio = 1.0
	subtitles.text = "[center][TOASTED]"
	subtitles.remove_theme_font_size_override("normal_font_size")

	await trigger_cleanout()
	Globals.set_toggle.emit("void", false)

func trigger_cleanout():
	await get_tree().create_timer(time_before_cleanout).timeout
	subtitles_cleanout = true

	await get_ready_for_next_speech()
	subtitles.remove_theme_font_size_override("normal_font_size")

func get_ready_for_next_speech():
	if not Globals.is_paused:
		await get_tree().create_timer(time_before_ready).timeout
		Globals.ready_for_speech.emit()

func _on_connection_closed():
	control_panel.backend_disconnected()

func _on_start_singing(song: Dictionary):
	Globals.is_paused = true
	Globals.is_singing = true

	mic.play()

	subtitles_duration = 3.0
	_print_subtitles("{artist}\n\"{name}\"".format(song))

	AudioServer.set_bus_mute(voice_bus, song.mute_voice)
	AudioServer.set_bus_effect_enabled(voice_bus, 1, song.reverb)

	var song_track := _load_mp3(song, "song")
	song_player.stream = song_track

	var voice_track := _load_mp3(song, "voice")
	speech_player.stream = voice_track

	song_player.play()
	speech_player.play()

	Globals.start_dancing_motion.emit(song.bpm, song.wait_time, song.stop_time)
	Globals.start_singing_mouth_movement.emit()

func _on_stop_singing():
	Globals.is_singing = false

	song_player.stop()
	speech_player.stop()

	mic.play_backwards()

	AudioServer.set_bus_mute(voice_bus, false)
	AudioServer.set_bus_effect_enabled(voice_bus, 1, false)

	Globals.end_dancing_motion.emit()
	Globals.end_singing_mouth_movement.emit()

func _load_mp3(song: Dictionary, type: String) -> AudioStreamMP3:
	var path: String = song.path % type

	if not FileAccess.file_exists(path):
		printerr("No audio file %s" % path)

	var file = FileAccess.open(path, FileAccess.READ)
	var stream = AudioStreamMP3.new()
	stream.data = file.get_buffer(file.get_length())
	stream.bpm = song.bpm
	return stream
