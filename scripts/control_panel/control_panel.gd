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

		"SceneNameChanged":
			# Handled by SceneListChanged response
			pass 

		"StreamStateChanged":
			# Handled by GetStreamStatus request
			pass

		"SceneTransitionStarted", "SceneTransitionEnded", "SceneTransitionVideoEnded":
			pass

		_:
			print("Event ", data.eventType)
			print("Data: ", data.eventData)

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

		"SetCurrentProgramScene", "ToggleStream":
			# Just a callback, ignore
			pass

		_:
			print("Unhandled request:", data)
			print("-------------")

func print_data(data, node):	
	node.clear()
	for i in data:
		node.append_text("[b]%s:[b] %s\n" % [i.lstrip("output").capitalize(), data[i]])

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
			button.add_theme_color_override("font_color", Color(1, 0, 0))
			button.add_theme_color_override("font_hover_color", Color(1, 0, 0))
			button.add_theme_color_override("font_focus_color", Color(1, 0, 0))
			button.add_theme_color_override("font_pressed_color", Color(1, 0, 0))
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
		%ObsStreamControl.add_theme_color_override("font_color", Color(1, 0, 0))
		%ObsStreamControl.add_theme_color_override("font_hover_color", Color(1, 0, 0))
		%ObsStreamControl.add_theme_color_override("font_focus_color", Color(1, 0, 0))
		%ObsStreamControl.add_theme_color_override("font_pressed_color", Color(1, 0, 0))
	else:
		%ObsStreamControl.text = "Start Stream"
		%ObsStreamControl.remove_theme_color_override("font_color")
		%ObsStreamControl.remove_theme_color_override("font_hover_color")
		%ObsStreamControl.remove_theme_color_override("font_focus_color")
		%ObsStreamControl.remove_theme_color_override("font_pressed_color")

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
