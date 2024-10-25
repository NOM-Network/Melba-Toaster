extends Node
class_name WebSocketClient

const URL_PATH: String = "%s://%s:%s"
var socket: WebSocketPeer
var last_state: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED

var secure: String = "wss" if Globals.config.get_backend("secure") else "ws"
var host: String = Globals.config.get_backend("host")
var port: String = Globals.config.get_backend("port")
var password: String = Globals.config.get_backend("password")

var handshake_headers: PackedStringArray = PackedStringArray([
	"Authentication: Bearer %s" % password
])
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

func _process(_delta: float) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.poll()

	var state: WebSocketPeer.State = socket.get_ready_state()
	if last_state != state:
		last_state = state

		match state:
			WebSocketPeer.STATE_OPEN:
				connection_established.emit()

			WebSocketPeer.STATE_CLOSED:
				var code = socket.get_close_code()
				var reason = socket.get_close_reason()
				printerr("Toaster client: Connection closed with code %d, reason %s. Clean: %s" % [code, reason, code != -1])

				connection_closed.emit()
				set_process(false)

	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			incoming_messages_count += 1
			data_received.emit(socket.get_packet(), [incoming_messages_count, outgoing_messages_count])

func is_open() -> bool:
	return socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func connect_client() -> void:
	print("Toaster client: Establishing connection...")

	socket = WebSocketPeer.new()

	socket.handshake_headers = handshake_headers
	socket.supported_protocols = supported_protocols
	socket.inbound_buffer_size = 200000000

	var err: Error = socket.connect_to_url(URL_PATH % [secure, host, port], TLSOptions.client())
	if err != OK:
		printerr("Toaster client: Connection error ", err)
		connection_closed.emit()

	last_state = socket.get_ready_state()
	print("Toaster client: Connecting...")
	set_process(true)

func send_message(json: Dictionary) -> void:
	var message: String = JSON.stringify(json)

	outgoing_messages_count += 1

	if not socket or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		printerr("Toaster client: Socket connection is not established")

	var err: Error = socket.send_text(message)
	if err != OK:
		printerr("Toaster client: Message sending error ", err)

func break_connection(reason: String = "") -> void:
	socket.close(1000, reason)
	last_state = socket.get_ready_state()

	incoming_messages_count = 0
	outgoing_messages_count = 0
