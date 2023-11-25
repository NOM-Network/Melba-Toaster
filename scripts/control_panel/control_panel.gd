extends Window
@onready var main: Node2D = get_parent()

@export_category("General")
@export var obs: ObsWebSocketClient

@export_category("UI")
@export var debug_button: Button
@export var cancel_button: Button
@export var pause_button: Button

@export_category("Timers")
@export var godot_stats_timer: Timer
@export var obs_stats_timer: Timer

var OpCodes := obs.OpCodeEnums.WebSocketOpCode

var anim_menu: Array
var expr_menu: Array

var is_streaming := false

var last_pause_status := not Globals.is_paused
var last_singing_status := not Globals.is_singing
var last_dancing_bpm := 0.1

# region MAIN

func _ready() -> void:
	godot_stats_timer.start()

	# Defaults
	debug_button.button_pressed = Globals.debug_mode
	pause_button.button_pressed = Globals.is_paused

	%BackendStatus.text = "Backend %s" % Globals.config.get_backend("host")
	%TimeBeforeCleanout.value = Globals.time_before_cleanout
	%TimeBeforeReady.value = Globals.time_before_ready
	%TimeBeforeSpeech.value = Globals.time_before_speech
	%ShowBeats.button_pressed = Globals.show_beats

	generate_position_controls()
	generate_model_controls()
	generate_singing_controls()

	connect_signals()
	_start_obs_processing()

func _process(_delta) -> void:
	_update_control_status()

func _update_control_status() -> void:
	if last_pause_status != Globals.is_paused:
		last_pause_status = Globals.is_paused
		CpHelpers.change_toggle_state(
			pause_button,
			Globals.is_paused,
			">>> RESUME (F9) <<<",
			"Pause (F9)"
		)

	if last_singing_status != Globals.is_singing:
		last_singing_status = Globals.is_singing
		CpHelpers.change_toggle_state(
			%SingingToggle,
			Globals.is_singing
		)

	if last_dancing_bpm != Globals.dancing_bpm:
		last_dancing_bpm = Globals.dancing_bpm
		%CurrentDancingBpm.text = str(Globals.dancing_bpm)
		CpHelpers.change_toggle_state(
			%DancingToggle,
			Globals.dancing_bpm
		)

func _start_obs_processing() -> void:
	# OBS Connection
	obs.establish_connection()
	await obs.connection_authenticated
	obs.data_received.connect(_on_data_received)
	CpHelpers.change_status_color(%ObsClientStatus, true)

	# OBS Data init
	obs.send_command_batch([
		"GetSceneList",
		"GetInputList",
		"GetStats"
	])

	# OBS Stats timers
	obs_stats_timer.start()

func _stop_obs_processing():
	obs_stats_timer.stop()
	obs.break_connection()
	CpHelpers.change_status_color(%ObsClientStatus, false)

func connect_signals() -> void:
	Globals.set_toggle.connect(update_toggle_controls)
	Globals.new_speech.connect(_on_new_speech)
	Globals.start_speech.connect(_on_start_speech)

	Globals.start_singing.connect(_on_start_singing)
	Globals.stop_singing.connect(_on_stop_singing)

	Globals.change_position.connect(_on_change_position)
	Globals.change_scene.connect(_on_change_scene)

	print_debug("Control Panel: connected signals")

func generate_position_controls() -> void:
	var positions := %Positions
	for n in positions.get_children():
		if n.get_class() == "Button":
			n.queue_free()

	var button_group = ButtonGroup.new()
	button_group.pressed.connect(_on_position_button_pressed)

	for p in Globals.positions:
		var button = Button.new()
		button.text = p
		button.toggle_mode = true
		button.button_pressed = p == Globals.default_position
		button.name = "Position" + p.to_pascal_case()
		button.button_group = button_group
		button.focus_mode = Control.FOCUS_NONE
		positions.add_child(button)

	var menu := %NextPositionMenu
	menu.add_item("NO OVERRIDE")
	for p in Globals.positions:
		menu.add_item(p)

func _on_position_button_pressed(button: BaseButton) -> void:
	Globals.change_position.emit(button.text)

func generate_singing_controls():
	var menu := %SingingMenu
	menu.clear()

	var songs = Globals.config.songs
	for song in songs:
		menu.add_item(song.name)

func generate_model_controls():
	for type in ["animations", "pinnable_assets", "expressions", "toggles"]:
		var parent_name = type.to_pascal_case()
		var parent = get_node("%%%s" % parent_name)
		for n in parent.get_children():
			n.queue_free()

		var callable
		if type == "toggles":
			callable = _on_toggle_pressed

		CpHelpers.construct_model_control_buttons(
			type,
			parent,
			Globals[type],
			callable
		)

# endregion

# region INCOMING DATA

func _on_data_received(data):
	match data.op:
		OpCodes.Event.IDENTIFIER_VALUE:
			_handle_event(data.d)

		OpCodes.RequestResponse.IDENTIFIER_VALUE:
			_handle_request(data.d)

		OpCodes.RequestBatchResponse.IDENTIFIER_VALUE:
			for i in data.d.results:
				_handle_request(i)

		_:
			print_debug("Unhandled op: ", data.op)
			print_debug(data)
			print_debug("-------------")

func _handle_event(data):
	match data.eventType:
		"CurrentProgramSceneChanged", "SceneListChanged":
			obs.send_command("GetSceneList")

		"InputMuteStateChanged":
			change_input_state(data.eventData)

		"InputNameChanged":
			change_input_name(data.eventData)

		"StreamStateChanged":
			if is_streaming != data.eventData.outputActive:
				is_streaming = data.eventData.outputActive
				update_stream_control_button()

		# "ExitStarted":
		# 	stop_processing()

		# Ignored callbacks
		"SceneNameChanged":
			pass # handled by SceneListChanged

		"SceneTransitionStarted", "SceneTransitionVideoEnded", "SceneTransitionEnded":
			pass # We don't need it

		_:
			pass
			# print_debug("Unhandled event: ", data.eventType)
			# print_debug(data)
			# print_debug("-------------")

func _handle_request(data):
	if not data.requestStatus.result:
		if data.requestStatus.code != 604:
			print_debug("Error in request: ", data)
			return
		return

	match data.requestType:
		"GetStats":
			insert_data(%StreamStats, Templates.format_obs_stats(data.responseData))

		"GetStreamStatus":
			var status = data.responseData
			# insert_data(status, %StreamStatus, "")
			if is_streaming != status.outputActive:
				is_streaming = status.outputActive
				update_stream_control_button()

		"GetSceneList":
			generate_scene_buttons(data.responseData)

		"GetInputList":
			generate_input_request(data.responseData.inputs)

		"GetInputMute":
			var inputData := {
				"inputName": data.requestId,
				"inputMuted": data.responseData.inputMuted
			}
			generate_input_button(inputData)

		# Ignored callbacks
		"ToggleInputMute":
			pass # handled by InputMuteStateChanged event

		"SetCurrentProgramScene", "ToggleStream":
			pass # handled by StreamChateChanged event

		"SetSourceFilterEnabled":
			pass

		_:
			print("Unhandled request: ", data.requestType)
			print(data)
			print("-------------")

# endregion

# region TIMERS

func _on_obs_stats_timer_timeout():
	obs.send_command("GetStats")

func _on_godot_stats_timer_timeout():
	insert_data(%GodotStats, Templates.format_godot_stats())

# endregion

# region UI FUNCTIONS

func _on_start_singing(_song, _seek_time):
	_on_pause_speech_toggled(true, false) # TODO: Use emit events

func _on_stop_singing():
	%SingingToggle.button_pressed = false
	_on_singing_toggle_toggled(false, false)

func _on_singing_toggle_toggled(button_pressed: bool, emit := true) -> void:
	if emit:
		var song: Dictionary = Globals.config.songs[%SingingMenu.selected]
		var seek_time: float = %SingingSeekTime.value

		if button_pressed:
			Globals.start_singing.emit(song, seek_time)
		else:
			Globals.stop_singing.emit()

func _on_dancing_toggle_toggled(button_pressed: bool):
	if button_pressed:
		Globals.start_dancing_motion.emit(%DancingBpm.value)
	else:
		Globals.end_dancing_motion.emit()

func _on_toggle_pressed(toggle: CheckButton):
	Globals.set_toggle.emit(toggle.text, toggle.button_pressed)

func _on_new_speech(prompt: String, text: String, emotions: Array) -> void:
	%CurrentSpeech/Text.add_theme_color_override("font_color", Color.YELLOW)
	%CurrentSpeech/Prompt.text = prompt
	%CurrentSpeech/Emotions.text = array_to_string(emotions)
	%CurrentSpeech/Text.text = text

func array_to_string(arr: Array) -> String:
	var s := ""
	for i in arr:
		s += String(i) + " "
	return s

func _on_start_speech() -> void:
	%CurrentSpeech/Text.remove_theme_color_override("font_color")

func update_toggle_controls(toggle_name: String, enabled: bool):
	var ui_name := "Toggles%s" % [toggle_name.to_pascal_case()]
	var toggle: CheckButton = %Toggles.get_node(ui_name)
	toggle.set_pressed_no_signal(enabled)

func update_stream_control_button():
	CpHelpers.change_toggle_state(
		%ObsStreamControl,
		is_streaming,
		"Stop Stream",
		"Start Stream"
	)

func _on_obs_stream_control_pressed():
	obs.send_command("ToggleStream")

func _on_change_scene(scene_name: String) -> void:
	obs.send_command("SetCurrentProgramScene", { "sceneName": scene_name })

	var next_position: String
	var selected_override: int = %NextPositionMenu.selected - 1
	if selected_override != -1:
		next_position = Globals.positions.keys()[selected_override]

	if not next_position:
		match scene_name:
			"Main", "Song":
				next_position = "default"

			"Gaming":
				next_position = "gaming"

	%NextPositionMenu.selected = 0
	if next_position:
		Globals.change_position.emit(next_position)

func _on_scene_button_pressed(button):
	Globals.change_scene.emit(button.text)

func _on_change_position(new_position: String) -> void:
	var buttons := %Positions

	for b in buttons.get_children():
		if b.text == new_position:
			b.button_pressed = true
			return

func generate_scene_buttons(data):
	var active_scene = null
	if data.has("currentProgramSceneName"):
		active_scene = data.currentProgramSceneName
	var scenes = data.scenes
	scenes.reverse()

	for n in %ObsScenes.get_children():
		n.queue_free()

	for scene in scenes:
		var button = Button.new()
		button.text = scene.sceneName
		CpHelpers.apply_color_override(button, scene.sceneName == active_scene, Color.GREEN)
		button.pressed.connect(_on_scene_button_pressed.bind(button))
		%ObsScenes.add_child(button)

func generate_input_request(inputs):
	for n in %ObsInputs.get_children():
		n.queue_free()

	var request = []
	for i in inputs:
		request.push_back(["GetInputMute", { "inputName": i.inputName }, i.inputName])

	obs.send_command_batch(request)

func generate_input_button(input):
	var button = Button.new()
	button.visible = false
	button.name = input.inputName.to_pascal_case()
	button.text = input.inputName
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_input_button_pressed.bind(button))
	%ObsInputs.add_child(button)
	change_input_state(input)

func change_input_name(data):
	var button = %ObsInputs.get_node(data.oldInputName.to_pascal_case())
	if button:
		button.name = data.inputName.to_pascal_case()
		button.text = data.inputName

func change_input_state(data):
	var button = %ObsInputs.get_node(data.inputName.to_pascal_case())

	if button:
		button.visible = true
		CpHelpers.apply_color_override(button, data.inputMuted, Color.RED, Color.GREEN)

func _on_input_button_pressed(button):
	obs.send_command("ToggleInputMute", { "inputName": button.text }, button.text)

func _on_time_before_cleanout_value_changed(value: float) -> void:
	Globals.time_before_cleanout = value

func _on_time_before_ready_value_changed(value: float) -> void:
	Globals.time_before_ready = value

func _on_time_before_speech_value_changed(value: float) -> void:
	Globals.time_before_speech = value

func insert_data(node: Node, text: String) -> void:
	node.clear()
	node.append_text(text)

# endregion

# region WINDOW FUNCTIONS

func _input(event):
	if event.is_action_pressed("cancel_speech"):
		cancel_button.emit_signal("pressed")

	if event.is_action_pressed("pause_resume"):
		pause_button.button_pressed = not pause_button.button_pressed
		pause_button.emit_signal("toggled", pause_button.button_pressed)

func backend_connected():
	CpHelpers.change_status_color(%BackendStatus, true)

func backend_disconnected():
	CpHelpers.change_status_color(%BackendStatus, false)

func _on_pause_speech_toggled(button_pressed: bool, emit := true) -> void:
	Globals.is_paused = button_pressed

	if emit and not button_pressed:
		Globals.ready_for_speech.emit()

func _on_debug_mode_button_toggled(button_pressed: bool) -> void:
	Globals.debug_mode = button_pressed

	CpHelpers.change_toggle_state(
		debug_button,
		button_pressed,
		">>> DEBUG MODE <<<",
		"Debug Mode"
	)

func _on_cancel_speech_pressed():
	Globals.cancel_speech.emit()
	%CurrentSpeech/Text.add_theme_color_override("font_color", Color.RED)

func _on_reset_subtitles_pressed() -> void:
	Globals.reset_subtitles.emit()

func _on_show_beats_toggled(toggled_on: bool) -> void:
	Globals.show_beats = toggled_on

func _on_obs_client_status_pressed() -> void:
	_stop_obs_processing()
	await get_tree().create_timer(1.0).timeout
	_start_obs_processing()

func _on_backend_status_pressed() -> void:
	Globals.is_paused = true
	main.disconnect_backend()
	await get_tree().create_timer(1.0).timeout
	main.connect_backend()

func _on_close_requested():
	$CloseConfirm.visible = true

func _on_close_confirm_confirmed():
	_stop_obs_processing()
	main.disconnect_backend()
	get_tree().quit()

# endregion
