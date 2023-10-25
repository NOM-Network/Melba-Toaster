extends Window
@onready var main: Node2D = get_parent()
@onready var obs: ObsWebSocketClient = $WebSocketClient
@onready var stats_timer: Timer = $StatsTimer
@onready var status_timer: Timer = $StatusTimer

var OpCodes := ObsWebSocketClient.OpCodeEnums.WebSocketOpCode

# TODO: Formats
var obs_stats_template = "" \
	+ "CPU Usage: [b]{cpuUsage}[/b]\n" \
	+ "Memory Usage: [b]{memoryUsage}[/b]\n" \
	+ "Disk Space: [b]{availableDiskSpace}[/b]\n" \
	+ "Active FPS: [b]{activeFps}[/b]\n" \
	+ "Frame Render Time: [b]{averageFrameRenderTime}[/b]\n" \
	+ "Frames Rendered/Skipped: [b]{renderTotalFrames}[/b]/[b]{renderSkippedFrames}[/b]\n" \
	+ "Total Rendered/Skipped: [b]{outputTotalFrames}[/b]/[b]{outputSkippedFrames}[/b]\n" \
	+ "WS Incoming/Outgoing: [b]{webSocketSessionIncomingMessages}[/b]/[b]{webSocketSessionOutgoingMessages}[/b]\n"

var godot_stats_template = "" \
	+ "Active FPS: [b]{fps}[/b]\n" \
	+ "Frame Time: [b]{frameTime}[/b]\n" \
	+ "Video Memory Used: [b]{videoMemoryUsed}[/b]\n" \
	+ "Audio Latency: [b]{audioLatency}[/b]\n"

var is_streaming = false

# region MAIN

func _ready() -> void:
	obs.establish_connection()
	await obs.connection_authenticated

	obs.data_received.connect(_on_data_received)
	change_status_color(%ObsClientStatus, true)

	# Init
	obs.send_command_batch([
		"GetSceneList",
		"GetInputList",
		"GetStats",
		# "GetStreamStatus"
	])

	stats_timer.start()
	status_timer.start()

func _process(_delta) -> void:
	var render_data = {
		"fps": Performance.get_monitor(Performance.Monitor.TIME_FPS),
		"frameTime": Performance.get_monitor(Performance.Monitor.TIME_PROCESS),
		"videoMemoryUsed": Performance.get_monitor(Performance.Monitor.RENDER_VIDEO_MEM_USED),
		"audioLatency": Performance.get_monitor(Performance.Monitor.AUDIO_OUTPUT_LATENCY),
	}

	insert_data(render_data, %GodotStats, godot_stats_template)

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
			print_debug("Unhandled event: ", data.eventType)
			print_debug(data)
			print_debug("-------------")

func _handle_request(data):
	if not data.requestStatus.result:
		print_debug("Error in request: ", data)
		return

	match data.requestType:
		"GetStats":
			insert_data(data.responseData, %StreamStats, obs_stats_template)

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

func _on_stats_timer_timeout():
	obs.send_command("GetStats")

func _on_status_timer_timeout():
	obs.send_command("GetStreamStatus")

# endregion

# region UI FUNCTIONS

func change_status_color(node: Node, active: bool) -> void:
	node.get_theme_stylebox("panel").bg_color = Color(0, 1, 0) if active else Color(1, 0, 0)

func update_stream_control_button():
	if is_streaming:
		%ObsStreamControl.text = "Stop Stream"
		for i in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			%ObsStreamControl.add_theme_color_override(i, Color(1, 0, 0))
	else:
		%ObsStreamControl.text = "Start Stream"
		for i in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
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
	button.name = input.inputName.to_camel_case()
	button.text = input.inputName
	button.pressed.connect(_on_input_button_pressed.bind(button))
	%ObsInputs.add_child(button)
	change_input_state(input)

func change_input_name(data):
	var button = %ObsInputs.get_node(data.oldInputName.to_camel_case())
	if button:
		button.name = data.inputName.to_camel_case()
		button.text = data.inputName

func change_input_state(data):
	var button = %ObsInputs.get_node(data.inputName.to_camel_case())
	if button:
		button.visible = true
		if (data.inputMuted):
			for i in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
				button.add_theme_color_override(i, Color(1, 0, 0))
		else:
			for i in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
				button.add_theme_color_override(i, Color(0, 1, 0))

func _on_input_button_pressed(button):
	obs.send_command("ToggleInputMute", { "inputName": button.text }, button.text)

func insert_data(data: Dictionary, node: Node, template: String) -> void:
	node.clear()
	node.append_text(template.format(data))

# endregion

# region WINDOW FUNCTIONS

func backend_connected():
	change_status_color(%BackendStatus, true)

func backend_disconnected():
	change_status_color(%BackendStatus, false)

func stop_processing():
	stats_timer.stop()
	status_timer.stop()
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
