extends Window

# OBS Websocket settings
@export_category("OBS Websocket settings")
@export var server = "127.0.0.1"
@export var port = 4455

const uuid = preload("res://scripts/helpers/uuid.gd")

var socket = WebSocketPeer.new()
var connected = false
var stats = {}

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
	socket.poll()

	var state = socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			_on_packet_received(socket.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSING:
		pass # Keep polling
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("OBS Websocket closed: %d %s" % [code, reason])
		set_process(false)

func init_data():
	if scenes == []:
		request_scene_list()

	_on_stats_timer_timeout()
	$StatsTimer.start()

func request_scene_list():
	var message = {
		"op": MessageType.Request,
		"d": {
			"requestType": "GetSceneList",
			"requestId": uuid.v4()
		}
	}

	message = JSON.stringify(message)
	socket.send_text(message)

func _on_stats_timer_timeout():
	var message = {
		"op": MessageType.Request,
		"d": {
			"requestType": "GetStats",
			"requestId": uuid.v4()
		}
	}

	message = JSON.stringify(message)
	socket.send_text(message)

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
		"CurrentProgramSceneChanged":
			request_scene_list()

		_:
			print("Event ", data.eventType)
			print("Data: ", data.eventData)

func process_request(data):
	match data.requestType:
		"GetStats":
			stats = data.responseData
			
			%StreamStats.clear()
			for i in stats:
				%StreamStats.append_text("[b]%s:[b] %s\n" % [i, stats[i]])

		"GetSceneList":
			generate_scene_buttons(data)			

		_:
			print(data)
			print("-------------")

func generate_scene_buttons(data):
	active_scene = data.responseData.currentProgramSceneName
	scenes = data.responseData.scenes
	scenes.reverse()

	for n in %ObsScenes.get_children():
		n.queue_free()

	for scene in scenes:
		var button = Button.new()
		button.text = scene.sceneName
		if (scene.sceneName == active_scene):
			button.add_theme_color_override("font_color", Color(1, 0, 0))
		button.pressed.connect(_on_scene_button_pressed.bind(button))
		%ObsScenes.add_child(button)

func _on_scene_button_pressed(button):
	var message = {
		"op": MessageType.Request,
		"d": {
			"requestType": "SetCurrentProgramScene",
			"requestData": {
				"sceneName": button.text
			},
			"requestId": uuid.v4()
		}
	}

	message = JSON.stringify(message)
	socket.send_text(message)
	pass

func _on_close_requested():
	$CloseConfirm.visible = true
	pass

func _on_close_confirm_confirmed():
	$StatsTimer.stop()
	socket.close()

	get_tree().quit()
	pass
