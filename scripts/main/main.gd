extends Node2D

@export_category("Variables")
@export_range(0.5, 10, 0.01) var time_before_cleanout: float = 3.0
@export_range(0.5, 10, 0.01) var time_before_ready: float = 2.0

@export_category("Nodes")
@export var client: WebSocketClient
@export var control_panel: Window
@export var subtitles: RichTextLabel

var subtitles_cleanout := false
var subtitles_duration := 0.0

func _ready():
	# Makes bg transparent
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)

	# Waiting for the backend
	await client.connection_established
	control_panel.backend_connected()
	client.data_received.connect(_on_data_received)
	client.connection_closed.connect(_on_connection_closed)

	# Signals
	Globals.incoming_speech.connect(_on_incoming_speech)
	Globals.new_speech.connect(_on_new_speech)
	Globals.speech_done.connect(_on_speech_done)
	Globals.cancel_speech.connect(_on_cancel_speech)

	# Ready for speech
	Globals.ready_for_speech.connect(_on_ready_for_speech)
	# Globals.ready_for_speech.emit()

	Globals.is_paused = true

func _on_data_received(data: Dictionary):
	if Globals.is_paused:
		return

	if data.type == "binary":
		if not Globals.is_speaking:
			# Testing for MP3
			var header = data.message.slice(0, 2)
			if not header == PackedByteArray([255, 251]): # Magic number FF FB
				printerr("Binary data is not an MP3 file! Skipping...")
				return

			Globals.incoming_speech.emit(data.message)
		else:
			print_debug("Audio while blabbering")
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
	if Globals.is_speaking:
		if subtitles.visible_ratio <= 1.0:
			subtitles.visible_ratio += ((1.0 / subtitles_duration) + 0.05) * delta
	else:
		if subtitles.visible_ratio > 0.0 && subtitles_cleanout:
			subtitles.visible_ratio -= 0.05

func _on_incoming_speech(message: PackedByteArray):
	var stream = AudioStreamMP3.new()
	stream.data = message
	subtitles_duration = stream.get_length()
	Globals.current_audio = stream

func _on_ready_for_speech():
	if not Globals.is_paused:
		client.send_message({"type": "ReadyForSpeech"})

func _on_new_speech(_prompt, text):
	subtitles_cleanout = false
	subtitles.visible_ratio = 0.0

	if text.length() > 300:
		subtitles.add_theme_font_size_override("normal_font_size", 20)
	else:
		subtitles.remove_theme_font_size_override("normal_font_size")

	subtitles.text = "[center]%s" % text

func _on_speech_done():
	subtitles.remove_theme_font_size_override("normal_font_size")
	await get_tree().create_timer(time_before_cleanout).timeout

	subtitles_cleanout = true

	get_ready_for_next_speech()

func _on_cancel_speech():
	Globals.is_speaking = false
	subtitles_cleanout = false
	subtitles.visible_ratio = 1.0
	subtitles.text = "[center][REDACTED]"
	subtitles.remove_theme_font_size_override("normal_font_size")

	get_ready_for_next_speech()

func get_ready_for_next_speech():
	if not Globals.is_paused:
		await get_tree().create_timer(time_before_ready).timeout
		Globals.ready_for_speech.emit()

func _on_connection_closed():
	control_panel.backend_disconnected()
