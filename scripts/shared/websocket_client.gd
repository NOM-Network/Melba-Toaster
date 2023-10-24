extends Node
class_name WebSocketClient

signal connection_established()
signal connection_closed()
signal data_received(data)

@export_group("Connection data (DO NOT EXPOSE!)")
@export var host: String = "127.0.0.1"
@export_range(1, 65535, 1) var port: int = 9876

const URL_PATH: String = "ws://%s:%d"
var client := WebSocketPeer.new()

var connected = false
var current_state = 0

func _ready() -> void:
	print_debug("Toaster client: Establishing connection!")
	set_process(true)

	var err := client.connect_to_url(URL_PATH % [host, port], TLSOptions.client())
	if err != OK:
		printerr(err)
		connection_closed.emit()
		set_process(false)

func _process(_delta: float) -> void:
	if current_state != client.get_ready_state():
		print_debug("State %s -> %s" % [current_state, client.get_ready_state()])
		current_state = client.get_ready_state()

	match client.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			client.poll()
			print_debug("Toaster client: Connecting...")

		WebSocketPeer.STATE_OPEN:
			client.poll()

			while client.get_available_packet_count():
				_poll_handler(client.get_packet().get_string_from_utf8())

		WebSocketPeer.STATE_CLOSING:
			client.poll()

			print_debug("Toaster client: Closing...")

		WebSocketPeer.STATE_CLOSED:
			print_debug("Toaster client: Connection closed! ", client.get_close_reason())

			connected = false
			connection_closed.emit()
			set_process(false)

func _poll_handler(data):
	print_debug("Incoming data: ", data)

	if data && not connected:
		connected = true
		connection_established.emit()

	var json: Variant = JSON.parse_string(data)
	if not json is Dictionary:
		printerr("Unexpected data from backend: ", str(data))
	else:
		data_received.emit(json)

func send_message(json: Dictionary) -> void:
	var message := JSON.stringify(json)

	var err := client.send_text(message)
	if err != OK:
		printerr(err)

func break_connection(reason: String = "") -> void:
	client.close(1000, reason)
