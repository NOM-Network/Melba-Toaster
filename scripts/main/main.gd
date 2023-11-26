extends Node2D

@export_category("Model")
@export var model_parent_animation: AnimationPlayer
var model: Node2D
var model_sprite: Sprite2D
var user_model: GDCubismUserModel
var model_target_point: GDCubismEffectTargetPoint

@export_category("Nodes")
@export var client: WebSocketClient
@export var control_panel: Window
@export var lower_third: Control
@export var mic: AnimatedSprite2D

@export_group("Sound Bus")
@export var cancel_sound: AudioStreamPlayer
@export var speech_player: AudioStreamPlayer
@export var song_player: AudioStreamPlayer

# Tweens
@onready var tweens := {}

# Cleanout stuff
var subtitles_cleanout := false
var subtitles_duration := 0.0

# Song-related
@onready var voice_bus := AudioServer.get_bus_index("Voice")
var current_song: Dictionary
var current_subtitles: Array
var song_playback: AudioStreamPlayback
var wait_time_triggered := false
var stop_time_triggered := false

# Defaults
@onready var prompt: Label = lower_third.get_node("Prompt")
@onready var subtitles: Label = lower_third.get_node("Subtitles")
var prompt_font_size: int
var subtitles_font_size: int

# For AnimationPlayer
@export_category("Nodes")
@export var target_position: Vector2

var pending_speech: Dictionary
var pressed: bool

func _ready():
	# Makes bg transparent
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)

	# Defaults
	prompt_font_size = prompt.label_settings.font_size
	subtitles_font_size = subtitles.label_settings.font_size

	prompt.text = ""
	subtitles.text = ""

	# Signals
	_connect_signals()

	# Add model
	_add_model()
	Globals.change_position.emit(Globals.default_position)

	# Waiting for the backend
	await connect_backend()

	# Ready for speech
	Globals.ready_for_speech.connect(_on_ready_for_speech)

func _process(_delta) -> void:
	if Globals.is_singing and current_song:
		var pos = song_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency() + (1 / Engine.get_frames_per_second()) * 2

		if Globals.show_beats:
			var beat := int(pos * Globals.dancing_bpm / 60.0)
			var seconds := int(pos)
			var duration := int(current_song.duration)
			$BeatsCounter.text = "BPM: %d, TIME: %d:%s (%f) / %d:%s (%d), BEAT: %d / 4" % [
				Globals.dancing_bpm,
				seconds / 60.0,
				strsec(seconds % 60),
				pos,
				duration / 60.0,
				strsec(duration % 60),
				current_song.duration,
				beat % 4 + 1,
			]

		$BeatsCounter.visible = Globals.show_beats

		if current_subtitles:
			if pos > current_subtitles[0][0]:
				var line: Array = current_subtitles.pop_front()

				if line[1].begins_with("&"):
					_match_command(line[1])
				else:
					subtitles.text = line[1]

	if model_parent_animation.is_playing():
		model_target_point.set_target(target_position)

func _match_command(line: String):
	var command: Array = line.split(" ")

	match command:
		["&CLEAR"]:
			subtitles.text = ""

		["&START", var bpm]:
			Globals.start_dancing_motion.emit(bpm.to_int())

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

func _add_model():
	model = preload("res://scenes/live2d/live_2d_melba.tscn").instantiate()
	add_child(model, true)
	move_child(model, 0)

	model_sprite = model.get_node("%Sprite2D")
	user_model = model.get_node("%GDCubismUserModel")
	model_target_point = model.get_node("%TargetPoint")

func strsec(secs):
	var s = str(secs)
	if (secs < 10):
		s = "0" + s
	return s

func _input(event: InputEvent):
	if event as InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
			_mouse_to_prop("position", event.relative)

		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT != 0:
			_move_eyes(event, true)

	if event as InputEventMouseButton:
		if event.is_pressed():
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_mouse_to_prop("scale", Globals.scale_change)

				MOUSE_BUTTON_WHEEL_DOWN:
					_mouse_to_prop("scale", -Globals.scale_change)

				MOUSE_BUTTON_MIDDLE:
					_reset_model_props()
		else:
			match event.button_index:
				MOUSE_BUTTON_RIGHT:
					_move_eyes(event, false)

func _reset_model_props():
	_mouse_to_prop("scale", Vector2(1.0, 1.0), true)
	_mouse_to_prop("position", Globals.positions.default.model[0], true)

func _mouse_to_prop(prop: String, change: Vector2, absolute := false) -> void:
	model[prop] = change if absolute else model[prop] + change

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

func _connect_signals() -> void:
	Globals.new_speech.connect(_on_new_speech)
	Globals.cancel_speech.connect(_on_cancel_speech)
	Globals.reset_subtitles.connect(_on_reset_subtitles)
	Globals.start_singing.connect(_on_start_singing)
	Globals.stop_singing.connect(_on_stop_singing)
	Globals.change_position.connect(_on_change_position)

	cancel_sound.finished.connect(func (): Globals.is_speaking = false)

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

func _on_data_received(data: Variant):
	if Globals.is_paused:
		return

	if typeof(data) == TYPE_PACKED_BYTE_ARRAY:
		if Globals.is_speaking:
			printerr("Audio while blabbering")
			return

		# Testing for MP3
		var header = data.slice(0, 2)
		if not (header == PackedByteArray([255, 251]) or header == PackedByteArray([73, 68])):
			printerr("%s is not an MP3 file! Skipping..." % [header])
			return

		# Preparing for speaking
		prepare_speech(data)
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
					Globals.new_speech.emit(message.prompt, message.text.response, message.text.emotions)
				else:
					print_debug("NewSpeech while blabbering")

			_:
				print("Unhandled data type: ", message)

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

func _play_audio() -> void:
	if speech_player.stream:
		Globals.is_speaking = true
		speech_player.play()
	else:
		printerr("NO AUDIO FOR THE MESSAGE!")

func _on_ready_for_speech():
	if not Globals.is_paused:
		client.send_message({"type": "ReadyForSpeech"})

func _on_new_speech(p_prompt: String, p_text: String, p_emotions: Array) -> void:
	pending_speech = {
		"prompt": p_prompt,
		"response": p_text,
		"emotions": p_emotions,
	}

	await get_tree().create_timer(Globals.time_before_speech).timeout

	if pending_speech != {}:
		_speak()

func _speak():
	Globals.start_speech.emit()
	_print_prompt(pending_speech.prompt)
	_print_subtitles(pending_speech.response)
	_play_audio()
	pending_speech = {}

func _print_prompt(text: String, duration := 0.0) -> void:
	if text:
		prompt.text = "%s" % text
	else:
		prompt.text = ""

	while prompt.get_line_count() > prompt.get_visible_line_count():
		prompt.label_settings.font_size -= 1

	_tween_text(prompt, "prompt", 0.0, 1.0, duration if duration != 0.0 else 1.0)

func _print_subtitles(text: String, duration := 0.0) -> void:
	if text:
		subtitles.text = "%s" % text
	else:
		subtitles.text = "tsh mebla"

	while subtitles.get_line_count() > subtitles.get_visible_line_count():
		subtitles.label_settings.font_size -= 1

	_tween_text(subtitles, "subtitles", 0.0, 1.0, duration if duration != 0.0 else subtitles_duration)

func _on_cancel_speech() -> void:
	var silent := false
	if pending_speech:
		silent = true

	pending_speech = {}

	speech_player.stop()
	speech_player.stream = null

	prompt.text = ""
	prompt.label_settings.font_size = prompt_font_size

	subtitles.text = ""
	subtitles.label_settings.font_size = subtitles_font_size

	if not silent:
		Globals.set_toggle.emit("void", true)
		subtitles.text = "[TOASTED]"
		_tween_text(subtitles, "subtitles", 0.0, 1.0, 0.2)
		cancel_sound.play()

	await trigger_cleanout(not silent)
	Globals.set_toggle.emit("void", false)

func _on_reset_subtitles() -> void:
	prompt.visible_ratio = 1.0
	subtitles.visible_ratio = 1.0
	prompt.text = ""
	subtitles.text = ""

func trigger_cleanout(timeout := true):
	if timeout:
		await get_tree().create_timer(Globals.time_before_cleanout).timeout

	await get_ready_for_next_speech()
	prompt.text = ""
	subtitles.text = ""
	subtitles.label_settings.font_size = subtitles_font_size

func get_ready_for_next_speech():
	if not Globals.is_paused:
		await get_tree().create_timer(Globals.time_before_ready).timeout
		Globals.ready_for_speech.emit()

func _on_connection_closed():
	control_panel.backend_disconnected()

func _tween_text(label: Label, tween_name: String, start_val: float, final_val: float, duration: float) -> void:
	if tweens.has(tween_name):
		tweens[tween_name].kill()

	label.visible_ratio = start_val

	tweens[tween_name] = create_tween()
	tweens[tween_name].tween_property(label, "visible_ratio", final_val, duration - duration * 0.01)

func _on_start_singing(song: Dictionary, seek_time := 0.0):
	current_song = song

	Globals.is_paused = true
	Globals.is_singing = true

	mic.animation = "in"
	mic.play()

	subtitles_duration = song.wait_time if song.wait_time != 0.0 else 3.0

	if song.subtitles:
		current_subtitles = song.subtitles.duplicate()
		_print_prompt("{artist} - \"{name}\"".format(song), 0.0 if seek_time else song.wait_time)
		subtitles.text = " "
		subtitles.visible_ratio = 1.0
	else:
		_print_prompt(" ")
		_print_subtitles("{artist}\n\"{name}\"".format(song), 0.0 if seek_time else song.wait_time)

	AudioServer.set_bus_mute(voice_bus, song.mute_voice)
	AudioServer.set_bus_effect_enabled(voice_bus, 1, song.reverb)

	var song_track := _load_mp3(song, "song")
	song_player.stream = song_track
	current_song.duration = song_track.get_length()

	var voice_track := _load_mp3(song, "voice")
	speech_player.stream = voice_track

	var command := {
		"sourceName": "Song",
		"filterName": "hiyori",
		"filterEnabled": false
	}
	if song.id == "hiyori":
		command["filterEnabled"] = true
	# TODO: decouple
	control_panel.obs.send_command("SetSourceFilterEnabled", command)

	Globals.change_scene.emit("Song")

	wait_time_triggered = false
	stop_time_triggered = false

	song_player.play(seek_time)
	speech_player.play(seek_time)

func _on_stop_singing():
	Globals.is_singing = false

	song_player.stop()
	speech_player.stop()

	mic.animation = "out"
	mic.play()

	current_song = {}
	current_subtitles = []
	$BeatsCounter.visible = false

	AudioServer.set_bus_mute(voice_bus, false)
	AudioServer.set_bus_effect_enabled(voice_bus, 1, false)

	Globals.end_dancing_motion.emit()
	Globals.end_singing_mouth_movement.emit()

	trigger_cleanout(false)
	Globals.change_scene.emit("Main")

func _load_mp3(song: Dictionary, type: String) -> AudioStreamMP3:
	var path: String = song.path % type

	assert(ResourceLoader.exists(path), "No audio file %s" % path)
	return ResourceLoader.load(path)

func _on_change_position(new_position: String) -> void:
	if Globals.positions.has(new_position):
		var positions: Dictionary = Globals.positions[new_position]

		match new_position:
			"intro":
				assert(model_parent_animation.has_animation(new_position))

				model_parent_animation.play("intro")
				model_parent_animation.animation_finished.emit(_on_change_position.bind("default"))

			_:
				for p in positions:
					var node = get(p)

					if tweens.has(p):
						tweens[p].kill()

					tweens[p] = create_tween().set_trans(Tween.TRANS_QUINT)
					tweens[p].set_parallel()
					tweens[p].tween_property(node, "position", positions[p][0], 1)
					tweens[p].tween_property(node, "scale", positions[p][1], 1)
