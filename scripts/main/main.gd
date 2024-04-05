extends Node2D

@onready var model := preload ("res://scenes/live2d/live_2d_melba.tscn").instantiate()
var model_sprite: Sprite2D
var user_model: GDCubismUserModel
var model_target_point: GDCubismEffectTargetPoint

@onready var client := $WebSocketClient
@onready var control_panel := $ControlPanel
@onready var lower_third := $LowerThird
@onready var mic := $Microphone
@onready var audio_manager := $AudioManager

@onready var greenscreen_window := $GreenScreenWindow
@onready var greenscreen_texture := $GreenScreenWindow/TextureRect

# region PROCESS
func _ready() -> void:
	# Timers
	%BeforeNextResponseTimer.wait_time = Globals.time_before_next_response

	_connect_signals()
	_add_model()

	greenscreen_texture.texture = get_viewport().get_texture()

	await connect_backend()

func _process(_delta: float) -> void:
	if Globals.is_singing:
		var full_position: Array[float] = audio_manager.get_position()

		if Globals.show_beats:
			$BeatsCounter.text = \
				"TIME: %d:%02d (%6.2f) [%.4f] / %d:%02d (%.2f), BPM: %.1f, BEAT: %d / 4" \
				% audio_manager.beats_counter_data(full_position)

		$BeatsCounter.visible = Globals.show_beats
	else:
		$BeatsCounter.visible = false

func _add_model() -> void:
	add_child(model, true)

	model_sprite = model.get_node("%Sprite2D")
	user_model = model.get_node("%GDCubismUserModel")
	model_target_point = model.get_node("%TargetPoint")

	Globals.change_position.emit(Globals.default_position)

# endregion

# region SIGNALS

func _connect_signals() -> void:
	Globals.new_speech.connect(_on_new_speech)
	Globals.continue_speech.connect(_on_continue_speech)
	Globals.cancel_speech.connect(_on_cancel_speech)
	Globals.end_speech.connect(_on_end_speech)

	Globals.start_singing.connect(_on_start_singing)
	Globals.stop_singing.connect(_on_stop_singing)

func _on_ready_for_speech() -> void:
	client.send_message({"type": "DoneSpeaking"})
	if not Globals.is_paused:
		client.send_message({"type": "ReadyForSpeech"})

func _on_data_received(message: PackedByteArray, stats: Array) -> void:
	Globals.update_backend_stats.emit(stats)

	var data: Dictionary = MessagePack.decode(message)
	if data.error != OK:
		printerr("MessagePack decode error: ", data.error)
		return

	match data.result.type:
		"NewSpeech", "ContinueSpeech", "EndSpeech":
			if Globals.is_singing:
				printerr("New speech while singing, skipping")
				return

			data.result.id = hash(data.result.prompt if data.result.prompt else "MelBuh")
			SpeechManager.push_message(data.result)

		"PlayAnimation":
			Globals.play_animation.emit(data.animationName)

		"SetExpression":
			Globals.set_expression.emit(data.expressionName)

		"SetToggle":
			Globals.set_toggle.emit(data.toggleName, data.enabled)

		_:
			print("Unhandled data type: ", data)

func _on_new_speech(data: Dictionary) -> void:
	%BeforeNextResponseTimer.stop()
	Globals.play_animation.emit("random")

	audio_manager.prepare_speech(data.audio)

	lower_third.set_prompt(data.prompt, 1.0)
	lower_third.set_subtitles(data.response, audio_manager.speech_duration)

	audio_manager.play_speech()

func _on_continue_speech(data: Dictionary) -> void:
	%BeforeNextResponseTimer.stop()

	Globals.play_animation.emit("random")
	audio_manager.prepare_speech(data.audio)
	lower_third.set_subtitles(data.response, audio_manager.speech_duration, true)
	audio_manager.play_speech()
	await Globals.speech_done

func _on_cancel_speech() -> void:
	%BeforeNextResponseTimer.stop()

	if Globals.is_singing:
		return

	lower_third.clear_subtitles()

	audio_manager.reset_speech_player()
	lower_third.set_subtitles_fast("[TOASTED]")

	Globals.set_toggle.emit("void", true)
	await audio_manager.play_cancel_sound()
	Globals.set_toggle.emit("void", false)

	_get_ready_for_next_speech()

func _on_end_speech() -> void:
	_get_ready_for_next_speech()

func _on_start_singing(song: Song, _seek_time:=0.0) -> void:
	Globals.current_emotion_modifier = 0.0

	# Reset toggles
	for toggle: String in Globals.toggles:
		Globals.set_toggle.emit(toggle, Globals.toggles[toggle].default_state)

	Globals.is_paused = true

	mic.animation = "in"
	mic.play()

	var command := {
		"sourceName": "Song",
		"filterName": "hiyori",
		"filterEnabled": false
	}
	if song.id == "hiyori":
		command["filterEnabled"] = true
	control_panel.obs.send_command("SetSourceFilterEnabled", command)

	if not Globals.fixed_scene:

func _on_stop_singing() -> void:
	mic.animation = "out"
	mic.play()

	$BeatsCounter.visible = false

	Globals.end_dancing_motion.emit()
	Globals.end_singing_mouth_movement.emit()

	if not Globals.fixed_scene:
		Globals.change_scene.emit("Main")

func _on_connection_closed() -> void:
	Globals.is_paused = true
	control_panel.backend_disconnected()

# endregion

# region PUBLIC FUNCTIONS

func connect_backend() -> void:
	client.connect_client()
	await client.connection_established
	control_panel.backend_connected()

	if not client.data_received.is_connected(_on_data_received):
		client.data_received.connect(_on_data_received)

	if not client.connection_closed.is_connected(_on_connection_closed):
		client.connection_closed.connect(_on_connection_closed)

	if not Globals.ready_for_speech.is_connected(_on_ready_for_speech):
		Globals.ready_for_speech.connect(_on_ready_for_speech)

func disconnect_backend() -> void:
	client.break_connection("from control panel")
	await client.connection_closed

# endregion

# region PRIVATE FUNCTIONS

func _get_ready_for_next_speech() -> void:
	%BeforeNextResponseTimer.stop()
	%BeforeNextResponseTimer.wait_time = Globals.time_before_next_response
	%BeforeNextResponseTimer.start()

func _on_before_next_response_timer_timeout() -> void:
	%BeforeNextResponseTimer.stop()

	# Starting the timer again if there are still chunks to skip
	if not SpeechManager.ready_for_new_message():
		%BeforeNextResponseTimer.wait_time = Globals.time_before_next_response
		%BeforeNextResponseTimer.start()
		return

	if not Globals.is_paused:
		Globals.ready_for_speech.emit()

# endregion
