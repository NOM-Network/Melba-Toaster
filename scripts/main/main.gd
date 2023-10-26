extends Node2D

@export var client: WebSocketClient
@export var control_panel: Window
@export var controller: Node2D

func _ready():
	# Makes bg transparent
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)

	# Waiting for the backend
	await client.connection_established
	control_panel.backend_connected()
	client.data_received.connect(_on_data_received)
	client.connection_closed.connect(_on_connection_closed)

	# Testing data
	client.send_message({"type": "RequestAudio"})
	await get_tree().create_timer(1.0).timeout
	client.send_message({"type": "PlayAnimation"})
	await get_tree().create_timer(1.0).timeout
	client.send_message({"type": "SetToggle"})
	await get_tree().create_timer(1.0).timeout
	client.send_message({"type": "SetExpression"})

func _on_data_received(data: Dictionary):
	# TODO: Send audio and text in subsequent frames
	if data.type == "binary":
		# Testing for MP3
		var header = data.message.slice(0, 2)
		if not header == PackedByteArray([255, 251]): # Magic number FF FB
			printerr("Binary data is not an MP3 file! Skipping...")
			return

		Globals.incoming_speech.emit(data.message)
	else:
		var message = JSON.parse_string(data.message)
		print_debug(message)
		match message.type:
			"PlayAnimation":
				Globals.play_animation.emit(message.animationName)

			"SetExpression":
				Globals.set_expression.emit(message.expressionName)

			"SetToggle":
				Globals.set_toggle.emit(message.toggleName, message.enabled)
				print("Setting Toggle")
			_:
				print("Unhandled data type: ", message)

func _on_connection_closed():
	control_panel.backend_disconnected()
