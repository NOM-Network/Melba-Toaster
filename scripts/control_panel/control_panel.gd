extends Window

const uuid := preload("res://scripts/helpers/uuid.gd")

# OBS Websocket settings
@export_category("OBS Websocket settings")
@export var server = "127.0.0.1"
@export var port = 4455

# WS data
var socket := WebSocketPeer.new()
var connected = false

# Stream info
var streaming = false
var stats = {}
var status = {}

# Scenes
var active_scene = ""
var scenes = []
var sound_inputs = []

const MessageType = {
	Hello = 0,
	Identify = 1,
	Identified = 2,
	Reidentify = 3,
	Event = 5,
	Request = 6,
	RequestResponse = 7,
	RequestBatch = 8,
	RequestBatchResponse = 9,
}

func _ready():
	socket.connect_to_url("ws://%s:%d" % [server, port], TLSOptions.client_unsafe())
	
func _process(_delta):
	start_socket()

func start_socket():
	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_CLOSING:
			socket.poll()

			while socket.get_available_packet_count():
				_on_packet_received(socket.get_packet().get_string_from_utf8())
					
		WebSocketPeer.STATE_CLOSED:
			var code = socket.get_close_code()
			var reason = socket.get_close_reason()
			print("OBS Websocket closed: %d %s" % [code, reason])
			set_process(false)

func init_data():
	if scenes == []:
		send_request("GetSceneList")

	send_request("GetInputList")

	$StatsTimer.start()

func _on_stats_timer_timeout():
	send_request("GetStats")
	send_request("GetStreamStatus")

func _on_packet_received(packet):
	var data = JSON.parse_string(packet)

	var op = int(data.op)
	var d = data.d
	match op:
		MessageType.Hello:
			print("Hello! WS version %s, version %s" % [d.obsWebSocketVersion, d.rpcVersion])
			
			var message = {
				"op": MessageType.Identify, 
				"d": {
					"rpcVersion": d.rpcVersion
				}
			}

			message = JSON.stringify(message)
			socket.send_text(message)
		
		MessageType.Identified:
			connected = true
			init_data()
			print("Successfully connected!")
		
		MessageType.RequestResponse:
			process_request(d)

		MessageType.Event:
			process_event(d)

		_:
			print("op: ", op)
			print("d: ", d)
			print("-------------")	

func process_event(data):
	match data.eventType:
		"CurrentProgramSceneChanged", "SceneListChanged":
			send_request("GetSceneList")	

		"InputMuteStateChanged":
			change_input_state(data.eventData)

		"InputNameChanged":
			change_input_name(data.eventData)

		"SceneNameChanged":
			# Handled by SceneListChanged response
			pass 

		"StreamStateChanged":
			# Handled by GetStreamStatus request
			pass

		"SceneTransitionStarted", "SceneTransitionEnded", "SceneTransitionVideoEnded":
			pass

		"ExitStarted":
			socket.close()

		_:
			print("Unhandled event: ", data.eventType)
			print(data)
			print("-------------")

func process_request(data):
	match data.requestType:
		"GetStats":
			stats = data.responseData
			print_data(stats, %StreamStats)

		"GetStreamStatus":
			status = data.responseData
			print_data(status, %StreamStatus)

			if streaming != status.outputActive:
				streaming = status.outputActive
				update_stream_control_button(status.outputActive)

		"GetSceneList":
			generate_scene_buttons(data.responseData)		

		"GetInputList":
			generate_inputs_buttons(data.responseData.inputs)

		"SetCurrentProgramScene", "ToggleStream":
			# Just a callback, ignore
			pass

		_:
			print("Unhandled request: ", data.requestType)
			print(data)
			print("-------------")

func print_data(data, node):	
	node.clear()
	for i in data:
		node.append_text("[b]%s:[b] %s\n" % [i.lstrip("output").capitalize(), data[i]])

func generate_inputs_buttons(inputs):
	for n in %ObsInputs.get_children():
		n.queue_free()

	for input in inputs:
		var button = Button.new()
		button.visible = false
		button.name = input.inputName.to_camel_case()
		button.text = input.inputName
		button.pressed.connect(_on_input_button_pressed.bind(button))
		%ObsInputs.add_child(button)

		# Sending two times because it is easier to use events
		send_request("ToggleInputMute", {"inputName": button.text})
		send_request("ToggleInputMute", {"inputName": button.text})

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
	send_request("ToggleInputMute", {"inputName": button.text})

func change_input_name(data):
	var button = %ObsInputs.get_node(data.oldInputName.to_camel_case())
	if button:
		button.name = data.inputName.to_camel_case()
		button.text = data.inputName

func generate_scene_buttons(data):
	if data.has("currentProgramSceneName"):
		active_scene = data.currentProgramSceneName
	scenes = data.scenes
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

func _on_scene_button_pressed(button):
	send_request("SetCurrentProgramScene", { "sceneName": button.text })

func _on_close_requested():
	$CloseConfirm.visible = true

func _on_close_confirm_confirmed():
	$StatsTimer.stop()
	socket.close()

	get_tree().quit()

func _on_obs_stream_control_pressed():
	send_request("ToggleStream")

func update_stream_control_button(isStreaming: bool):
	if (isStreaming):
		%ObsStreamControl.text = "Stop Stream"
		for i in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			%ObsStreamControl.add_theme_color_override(i, Color(1, 0, 0))
	else:
		%ObsStreamControl.text = "Start Stream"
		for i in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			%ObsStreamControl.remove_theme_color_override(i)

func send_request(type, data = {}):
	var message = {
		"op": MessageType.Request,
		"d": {
			"requestType": type,
			"requestId": uuid.v4()
		}
	}

	if data != {}:
		message.d.requestData = data

	message = JSON.stringify(message)
	socket.send_text(message)

func _on_reconnect_button_pressed():
	$StatsTimer.stop()
	socket.close()

	get_tree().reload_current_scene()
