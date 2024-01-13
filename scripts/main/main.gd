extends Node2D

@export_category("Model")
@export var model_parent_animation: AnimationPlayer
@onready var model := preload("res://scenes/live2d/live_2d_melba.tscn").instantiate()
var model_sprite: Sprite2D
var user_model: GDCubismUserModel
var model_target_point: GDCubismEffectTargetPoint

@export_category("Nodes")
@export var client: WebSocketClient
@export var control_panel: Window
@export var lower_third: Control
@export var mic: AnimatedSprite2D
@export var audio_manager: Node
@export var timer: Timer

# Tweens
@onready var tweens := {}

# Song-related
var current_song: Song
var current_subtitles: Array
var song_playback: AudioStreamPlayback

var pending_speech: Dictionary
var pressed: bool

func _ready() -> void:
	# Makes bg transparent
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)

	# Signals
	_connect_signals()

	# Add model
	_add_model()

	# Waiting for the backend
	await connect_backend()

	# Ready for speech
	timer.wait_time = Globals.time_before_speech
	Globals.ready_for_speech.connect(_on_ready_for_speech)

func _process(_delta: float) -> void:
	if Globals.is_singing and current_song:
		var full_position: Array[float] = audio_manager.get_position()
		var pos: float = full_position[0]

		if Globals.show_beats:
			$BeatsCounter.text = \
				"TIME: %d:%02d (%6.2f) [%.4f] / %d:%02d (%.2f), BPM: %.1f, BEAT: %d / 4" \
				% audio_manager.beats_counter_data(full_position)

		$BeatsCounter.visible = Globals.show_beats

		if current_subtitles:
			if pos > current_subtitles[0][0]:
				var line: Array = current_subtitles.pop_front()

				if line[1].begins_with("&"):
					_match_command(line[1])
				else:
					lower_third.set_subtitles_fast(line[1])
	else:
		$BeatsCounter.visible = false

func _connect_signals() -> void:
	Globals.new_speech.connect(_on_new_speech)
	Globals.cancel_speech.connect(_on_cancel_speech)
	Globals.speech_done.connect(_on_speech_done)
	Globals.start_singing.connect(_on_start_singing)
	Globals.stop_singing.connect(_on_stop_singing)
	Globals.change_position.connect(_on_change_position)

	timer.timeout.connect(_on_timer_before_speech_timeout)

func _add_model() -> void:
	add_child(model, true)
	move_child(model, 0)

	model_sprite = model.get_node("%Sprite2D")
	user_model = model.get_node("%GDCubismUserModel")
	model_target_point = model.get_node("%TargetPoint")

	Globals.change_position.emit(Globals.default_position)

func connect_backend() -> void:
	client.connect_client()
	await client.connection_established
	control_panel.backend_connected()

	if not client.data_received.is_connected(_on_data_received):
		client.data_received.connect(_on_data_received)

	if not client.connection_closed.is_connected(_on_connection_closed):
		client.connection_closed.connect(_on_connection_closed)

func disconnect_backend() -> void:
	client.break_connection("from control panel")
	await client.connection_closed

func _on_connection_closed() -> void:
	Globals.is_paused = true
	control_panel.backend_disconnected()

func _match_command(line: String) -> void:
	var command: Array = line.split(" ")

	match command:
		["&CLEAR"]:
			lower_third.set_subtitles_fast("")

		["&START", var bpm]:
			Globals.start_dancing_motion.emit(bpm as float)

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

		_:
			printerr("SONG: `%s` is not a valid command" % line)

func _input(event: InputEvent) -> void:
	if event as InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
			_mouse_to_prop("position", event.relative)

		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT != 0:
			_move_eyes(event, true)

	if event as InputEventMouseButton:
		if event.is_pressed():
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_mouse_to_scale(Globals.scale_change)

				MOUSE_BUTTON_WHEEL_DOWN:
					_mouse_to_scale(-Globals.scale_change)

				MOUSE_BUTTON_MIDDLE:
					Globals.change_position.emit(Globals.last_position)
		else:
			match event.button_index:
				MOUSE_BUTTON_RIGHT:
					_move_eyes(event, false)

func _mouse_to_scale(change: Vector2) -> void:
	if tweens.has("model_scale"):
		tweens.model_scale.kill()

	tweens.model_scale = create_tween()
	tweens.model_scale.tween_property(model, "scale", model.scale + change, 0.05)

func _mouse_to_prop(prop: String, change: Vector2) -> void:
	model[prop] += change

func _move_eyes(event: InputEvent, is_pressed: bool) -> void:
	if is_pressed:
		var local_pos: Vector2 = model.to_local(event.position)
		var render_size: Vector2 = Vector2(
			float(user_model.size.x) * model.scale.x,
			float(user_model.size.y) * model.scale.y * -1.0
		) * 0.5
		local_pos /= render_size
		model_target_point.set_target(local_pos)
	else:
		model_target_point.set_target(Vector2.ZERO)

func _on_data_received(data: Variant, stats: Array) -> void:
	Globals.update_backend_stats.emit(stats)

	if Globals.is_paused:
		printerr("Data when paused")
		return

	if typeof(data) == TYPE_PACKED_BYTE_ARRAY:
		if Globals.is_speaking:
			printerr("Audio while blabbering")
			return

		assert(audio_manager.is_valid_mp3(data), "Backend sent a faulty MP3 file!")
		audio_manager.prepare_speech(data)
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
				if Globals.is_speaking:
					print_debug("NewSpeech while blabbering")
					return

				Globals.new_speech.emit(message.prompt, message.text.response, message.text.emotions)

			_:
				print("Unhandled data type: ", message)

func _on_speech_done() -> void:
	get_ready_for_next_speech()

func _on_ready_for_speech() -> void:
	if not Globals.is_paused:
		client.send_message({"type": "ReadyForSpeech"})

func _on_new_speech(p_prompt: String, p_text: String, p_emotions: Array) -> void:
	# This variable might be cleared from control panel
	pending_speech = {
		"prompt": p_prompt,
		"response": p_text,
		"emotions": p_emotions,
	}

	timer.wait_time = Globals.time_before_speech
	timer.start()

func _on_timer_before_speech_timeout() -> void:
	if pending_speech != {}:
		timer.stop()
		_speak()

func _speak() -> void:
	Globals.play_animation.emit("random")

	lower_third.set_prompt(pending_speech.prompt, 1.0)
	lower_third.set_subtitles(pending_speech.response, audio_manager.speech_duration)

	Globals.start_speech.emit()
	pending_speech = {}

func _on_cancel_speech() -> void:
	var silent := not Globals.is_speaking

	pending_speech = {}
	lower_third.clear_subtitles()

	audio_manager.reset_speech_player()
	if not silent:
		Globals.set_toggle.emit("void", true)
		lower_third.set_subtitles("[TOASTED]", 1.0)
		await audio_manager.play_cancel_sound()
		Globals.set_toggle.emit("void", false)

	get_ready_for_next_speech()

func get_ready_for_next_speech() -> void:
	if not Globals.is_paused:
		Globals.ready_for_speech.emit()

func _on_start_singing(song: Song, seek_time := 0.0) -> void:
	_reset_toggles()
	Globals.is_paused = true

	mic.animation = "in"
	mic.play()

	current_song = song
	current_subtitles = song.load_subtitles_file()
	lower_third.set_prompt(song.full_name, 0.0 if seek_time else song.wait_time)

	audio_manager.prepare_song(current_song)

	var command := {
		"sourceName": "Song",
		"filterName": "hiyori",
		"filterEnabled": false
	}
	if song.id == "hiyori":
		command["filterEnabled"] = true
	# TODO: decouple
	control_panel.obs.send_command("SetSourceFilterEnabled", command)

	if not Globals.fixed_scene:
		Globals.change_scene.emit("Song")

	audio_manager.play_song(seek_time)

func _on_stop_singing() -> void:
	mic.animation = "out"
	mic.play()

	current_song = null
	current_subtitles = []
	$BeatsCounter.visible = false

	Globals.end_dancing_motion.emit()
	Globals.end_singing_mouth_movement.emit()

	lower_third.clear_subtitles()

	if not Globals.fixed_scene:
		Globals.change_scene.emit("Main")

func _on_change_position(new_position: String) -> void:
	assert(Globals.positions.has(new_position), "Position %s does not exist" % new_position)

	var positions: Dictionary = Globals.positions[new_position]
	match new_position:
		"Intro":
			assert(model_parent_animation.has_animation("intro"))

			model_parent_animation.play("intro")
			model_parent_animation.animation_finished.emit(_on_change_position.bind("Default"))

		_:
			for p in positions:
				var node = get(p)

				if tweens.has(p):
					tweens[p].kill()

				tweens[p] = create_tween().set_trans(Tween.TRANS_QUINT)
				tweens[p].set_parallel()
				tweens[p].tween_property(node, "position", positions[p][0], 1)
				tweens[p].tween_property(node, "scale", positions[p][1], 1)


func _reset_toggles() -> void:
	for toggle in Globals.toggles:
		Globals.set_toggle.emit(toggle, Globals.toggles[toggle].enabled)
