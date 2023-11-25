extends Node
class_name WebSocketClient

const URL_PATH: String = "%s://%s:%s"
var socket: WebSocketPeer
var last_state = WebSocketPeer.STATE_CLOSED

@export var poll_time: float = 0.5
var _poll_counter: float = 0.0

var secure: String = "wss" if Globals.config.get_backend("secure") else "ws"
var host: String = Globals.config.get_backend("host")
var port: String = Globals.config.get_backend("port")
var password: String = Globals.config.get_backend("password")

@export var handshake_headers: PackedStringArray
@export var supported_protocols: PackedStringArray
var tls_options: TLSOptions = null

signal connection_established()
signal connection_closed()
signal data_received(data: Variant)

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	_poll_counter += delta

	if _poll_counter >= poll_time:
		_poll_counter = 0.0
		if socket.get_ready_state() != socket.STATE_CLOSED:
			socket.poll()

		var state = socket.get_ready_state()
		if last_state != state:
			last_state = state
			if state == socket.STATE_OPEN:
				connection_established.emit()
			elif state == socket.STATE_CLOSED:
				connection_closed.emit()
				print_debug("Toaster client: Connection closed! ", socket.get_close_reason())

		while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count():
			data_received.emit(message_handler())

func connect_client() -> void:
	print_debug("Toaster client: Establishing connection!")

	if not socket:
		socket = WebSocketPeer.new()

	socket.handshake_headers = handshake_headers
	socket.supported_protocols = supported_protocols
	socket.inbound_buffer_size = 200000000

	var err := socket.connect_to_url(URL_PATH % [secure, host, port], TLSOptions.client())
	if err != OK:
		printerr("Toaster client: Connection error ", err)
		connection_closed.emit()

	last_state = socket.get_ready_state()

func message_handler() -> Variant:
	var packet = socket.get_packet()

	print_debug("Incoming text...")
	if socket.was_string_packet():
		return {
			"type": "text",
			"message": packet.get_string_from_utf8()
		}

	print_debug("Incoming buffer...")
	return packet

func send_message(json: Dictionary) -> void:
	var message := JSON.stringify(json)

	var err := socket.send_text(message)
	if err != OK:
		printerr("Toaster client: Message sending error ", err)

func break_connection(reason: String = "") -> void:
	socket.close(1000, reason)
	last_state = socket.get_ready_state()

	socket = WebSocketPeer.new()
