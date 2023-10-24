extends Node2D

@onready var client: WebSocketClient = $WebSocketClient
@onready var control_panel: Window = $ControlPanel
@onready var live2d_server: Node2D = $Live2DMelbaServer

func _ready():
	get_viewport().set_embedding_subwindows(false)

	# Waiting for the backend
	await client.connection_established
	control_panel.backend_connected()
	client.data_received.connect(_on_data_received)
	client.connection_closed.connect(_on_connection_closed)

func _on_data_received(data: Dictionary):
	match data.type:
		"Hello":
			var message: Dictionary = {"type": "Hello"}
			client.send_message(message)

		"PlayAnimation":
			live2d_server.play_anim(data.animationName)

		"SetExpression":
			live2d_server.set_expr(data.expressionName)

		_:
			print("Unhandled data type: ", data)

func _on_connection_closed():
	control_panel.backend_disconnected()
