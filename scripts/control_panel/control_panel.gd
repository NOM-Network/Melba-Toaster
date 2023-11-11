extends Window
@onready var main: Node2D = get_parent()

@export_category("General")
@export var obs: ObsWebSocketClient

@export_category("UI")
@export var current_prompt: Label
@export var current_speech: Label
@export var debug_button: Button
@export var cancel_button: Button
@export var pause_button: Button

@export_category("Timers")
@export var godot_stats_timer: Timer
@export var obs_stats_timer: Timer

var OpCodes := ObsWebSocketClient.OpCodeEnums.WebSocketOpCode

var anim_menu: Array
var expr_menu: Array

var is_streaming := false

# region MAIN

func _ready() -> void:
	godot_stats_timer.start()

	# Defaults
	debug_button.button_pressed = Globals.debug_mode
	pause_button.button_pressed = Globals.is_paused

	generate_model_controls()
	generate_singing_controls()

	connect_signals()
	obs_connection()

func _process(_delta) -> void:
	pass

func perf_mon(monitor: String) -> Variant:
	return Performance.get_monitor(Performance[monitor])

func obs_connection() -> void:
	# OBS Connection
	obs.establish_connection()
	await obs.connection_authenticated
	obs.data_received.connect(_on_data_received)
	change_status_color(%ObsClientStatus, true)

	# OBS Data init
	obs.send_command_batch([
		"GetSceneList",
		"GetInputList",
		"GetStats"
	])

	# OBS Stats timers
	obs_stats_timer.start()

func connect_signals() -> void:
	Globals.set_toggle.connect(update_toggle_controls)
	Globals.new_speech.connect(_on_new_speech)

	Globals.start_singing.connect(_on_start_singing)
	Globals.stop_singing.connect(_on_stop_singing)

	print_debug("Control Panel: connected signals")

func generate_singing_controls():
	var menu := %SingingMenu
	menu.clear()

	var songs = Globals.config.songs
	for song in songs:
		menu.add_item(song.id)

func generate_model_controls():
	for type in ["animations", "expressions", "toggles"]:
		var parent = get_node("%%%s" % type.capitalize())
		for n in parent.get_children():
			n.queue_free()

		_construct_model_control_buttons(type, parent, Globals[type])

func _construct_model_control_buttons(type: String, parent: Node, controls: Dictionary):
	var label = Label.new()
	label.text = type.capitalize()
	parent.add_child(label)

	var callback: Signal
	var button_type := Button
	match type:
		"animations":
			callback = Globals.play_animation

		"expressions":
			callback = Globals.set_expression

		"toggles":
			callback = Globals.play_animation
			button_type = CheckButton

	for control in controls:
		var button = button_type.new()
		button.text = control
		button.name = type.capitalize() + control.to_pascal_case()

		if type == "toggles":
			button.button_pressed = controls[control].enabled
			button.pressed.connect(_on_toggle_pressed.bind(button))
		else:
			button.pressed.connect(func (): callback.emit(control))

		parent.add_child(button)

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

		"ExitStarted":
			stop_processing()

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
			var res: Dictionary = data.responseData
			var stats := {
				"activeFps": snapped(res.activeFps, 0),
				"cpuUsage": snapped(res.cpuUsage, 0.001),
				"memoryUsage": snapped(res.memoryUsage, 0.1),
				"availableDiskSpace": snapped(res.availableDiskSpace / 1024, 0.1),
				"averageFrameRenderTime": snapped(res.averageFrameRenderTime, 0.1),
				"renderTotalFrames": res.renderTotalFrames,
				"renderSkippedFrames": res.renderSkippedFrames,
				"outputTotalFrames": res.outputTotalFrames,
				"outputSkippedFrames": res.outputSkippedFrames,
				"webSocketSessionIncomingMessages": res.webSocketSessionIncomingMessages,
				"webSocketSessionOutgoingMessages": res.webSocketSessionOutgoingMessages,
			}
			insert_data(stats, %StreamStats, Templates.obs_stats_template)

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

		_:
			print("Unhandled request: ", data.requestType)
			print(data)
			print("-------------")

# endregion

# region TIMERS

func _on_obs_stats_timer_timeout():
	obs.send_command("GetStats")

func _on_godot_stats_timer_timeout():
	var render_data = {
		"fps": perf_mon("TIME_FPS"),
		"frameTime": snapped(perf_mon("TIME_PROCESS"), 0.01),
		"videoMemoryUsed": snapped(perf_mon("RENDER_VIDEO_MEM_USED") / 1024 / 1000, 0.01),
		"audioLatency": snapped(perf_mon("AUDIO_OUTPUT_LATENCY"), 0.01),
	}

	insert_data(render_data, %GodotStats, Templates.godot_stats_template)


# endregion

# region UI FUNCTIONS

func _on_start_singing(_song: Dictionary):
	_on_pause_speech_toggled(true, false) # TODO: Use emit events

	var button := %SingingToggle
	button.button_pressed = true
	button.text = ">>> STOP <<<"

func _on_stop_singing():
	_on_pause_speech_toggled(false, false) # TODO: Use emit events

	var button := %SingingToggle
	button.button_pressed = false
	button.text = "Start"

func _on_singing_toggle_toggled(button_pressed: bool):
	var menu := %SingingMenu

	if button_pressed:
		var song: Dictionary = Globals.config.songs[menu.selected]
		Globals.start_singing.emit(song)
	else:
		Globals.stop_singing.emit()

func _on_dancing_toggle_toggled(button_pressed: bool):
	var bpm = %DancingBpm.value as float
	var wait_time = %DancingWaitTime.value as float
	var stop_time = %DancingStopTime.value as float

	if button_pressed:
		Globals.start_dancing_motion.emit(bpm, wait_time, stop_time)
		%DancingToggle.text = ">> Stop <<"
	else:
		Globals.end_dancing_motion.emit()
		%DancingToggle.text = "Start"

func _on_toggle_pressed(toggle: CheckButton):
	Globals.set_toggle.emit(toggle.text, toggle.button_pressed)

func _on_new_speech(prompt, text) -> void:
	current_speech.remove_theme_color_override("font_color")
	current_prompt.text = prompt
	current_speech.text = text.response

func update_toggle_controls(toggle_name: String, enabled: bool):
	var ui_name := "Toggles%s" % [toggle_name.to_pascal_case()]
	var toggle: CheckButton = %Toggles.get_node(ui_name)
	if toggle:
		toggle.button_pressed = enabled

func change_status_color(node: Node, active: bool) -> void:
	node.get_theme_stylebox("panel").bg_color = Color(0, 1, 0) if active else Color(1, 0, 0)

func update_stream_control_button():
	var overrides := ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]

	if is_streaming:
		%ObsStreamControl.text = "Stop Stream"
		for i in overrides:
			%ObsStreamControl.add_theme_color_override(i, Color(1, 0, 0))
	else:
		%ObsStreamControl.text = "Start Stream"
		for i in overrides:
			%ObsStreamControl.remove_theme_color_override(i)

func _on_obs_stream_control_pressed():
	obs.send_command("ToggleStream")

func _on_scene_button_pressed(button):
	obs.send_command("SetCurrentProgramScene", { "sceneName": button.text })

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
		if (scene.sceneName == active_scene):
			for i in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
				button.add_theme_color_override(i, Color(0, 1, 0))
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
	var overrides = ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]

	if button:
		button.visible = true
		if (data.inputMuted):
			for i in overrides:
				button.add_theme_color_override(i, Color(1, 0, 0))
		else:
			for i in overrides:
				button.add_theme_color_override(i, Color(0, 1, 0))

func _on_input_button_pressed(button):
	obs.send_command("ToggleInputMute", { "inputName": button.text }, button.text)

func insert_data(data: Dictionary, node: Node, template: String) -> void:
	node.clear()
	node.append_text(template.format(data))

# endregion

# region WINDOW FUNCTIONS

func _input(event):
	if event.is_action_pressed("cancel_speech"):
		cancel_button.emit_signal("pressed")

	if event.is_action_pressed("pause_resume"):
		pause_button.button_pressed = not pause_button.button_pressed
		pause_button.emit_signal("toggled", pause_button.button_pressed)

func backend_connected():
	change_status_color(%BackendStatus, true)

func backend_disconnected():
	change_status_color(%BackendStatus, false)

func _on_pause_speech_toggled(button_pressed: bool, emit := true) -> void:
	Globals.is_paused = button_pressed

	var overrides = ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]

	if (button_pressed):
		pause_button.text = ">>> RESUME (F9) <<<"
		for i in overrides:
			pause_button.add_theme_color_override(i, Color(1, 0, 0))
	else:
		if emit:
			Globals.ready_for_speech.emit()

		pause_button.text = "Pause (F9)"
		for i in overrides:
			pause_button.remove_theme_color_override(i)

func _on_debug_mode_button_toggled(button_pressed: bool) -> void:
	Globals.debug_mode = button_pressed

	var overrides = ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]

	if (button_pressed):
		debug_button.text = ">>> DEBUG MODE <<<"
		for i in overrides:
			debug_button.add_theme_color_override(i, Color(1, 0, 0))
	else:
		debug_button.text = "Debug Mode"
		for i in overrides:
			debug_button.remove_theme_color_override(i)

func _on_cancel_speech_pressed():
	Globals.cancel_speech.emit()
	current_speech.add_theme_color_override("font_color", Color(1, 0, 0))

func stop_processing():
	obs_stats_timer.stop()
	obs.break_connection()
	main.client.break_connection("from control panel")
	change_status_color(%ObsClientStatus, false)

func _on_reconnect_button_pressed():
	stop_processing()
	get_tree().reload_current_scene()

func _on_close_requested():
	$CloseConfirm.visible = true

func _on_close_confirm_confirmed():
	stop_processing()
	get_tree().quit()

# endregion
