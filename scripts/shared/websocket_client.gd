extends Node
class_name WebSocketClient

const URL_PATH: String = "%s://%s:%s"
var socket: WebSocketPeer
var last_state: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED

var poll_time: float = 0.5
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
signal data_received(data: Variant, stats: Array)

# Stats
var incoming_messages_count: int = 0
var outgoing_messages_count: int = 0

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	_poll_counter += delta

	if _poll_counter >= poll_time:
		_poll_counter = 0.0
		if socket.get_ready_state() != socket.STATE_CLOSED:
			socket.poll()

		var state: WebSocketPeer.State = socket.get_ready_state()
		if last_state != state:
			last_state = state
			if state == socket.STATE_OPEN:
				connection_established.emit()
			elif state == socket.STATE_CLOSED:
				connection_closed.emit()
				print_debug("Toaster client: Connection closed! ", socket.get_close_reason())

		while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count():
			incoming_messages_count += 1
			data_received.emit(socket.get_packet(), [incoming_messages_count, outgoing_messages_count])

func is_open() -> bool:
	return socket.get_ready_state() == socket.STATE_OPEN

func connect_client() -> void:
	print_debug("Toaster client: Establishing connection!")

	set_process(true)
	if not socket:
		socket = WebSocketPeer.new()

	socket.handshake_headers = handshake_headers
	socket.supported_protocols = supported_protocols
	socket.inbound_buffer_size = 200000000

	var err: Error = socket.connect_to_url(URL_PATH % [secure, host, port], TLSOptions.client())
	if err != OK:
		printerr("Toaster client: Connection error ", err)
		connection_closed.emit()

	last_state = socket.get_ready_state()

func send_message(json: Dictionary) -> void:
	var message: String = JSON.stringify(json)

	outgoing_messages_count += 1
	var err: Error = socket.send_text(message)
	if err != OK:
		printerr("Toaster client: Message sending error ", err)

func break_connection(reason: String="") -> void:
	set_process(true)
	socket.close(1000, reason)
	last_state = socket.get_ready_state()

	incoming_messages_count = 0
	outgoing_messages_count = 0

	socket = WebSocketPeer.new()
