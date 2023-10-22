extends Node
class_name MelbaServer 

signal play_animation 
signal set_expression 
signal play_audio 

@export var model: Node 
@export var server: Node
@export var control_panel: PackedScene

const PORT = 8765 

var id: int 

func _ready() -> void: 
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)
	
	# CP init
	control_panel_init()

	# WebSockets server init
	var err: Error = server.listen(PORT)
	if err != OK:
		print("Error listing on port %s" % PORT)

func control_panel_init():
	get_viewport().set_embedding_subwindows(false)
	var cp: Window = control_panel.instantiate()
	add_child(cp)
	cp.visible = true

func process_string(message: String) -> void: 
	var data = JSON.parse_string(message)
	match data["type"]:
		"PlayAnimation":
			play_animation.emit(data["animationName"])
		"SetExpression":
			set_expression.emit(data["expressionName"])

func process_audio(message: PackedByteArray) -> void: 
	pass 

func _on_web_socket_server_message_received(peer_id, message):
	server.send(id, message)
	
	match typeof(message): 
		TYPE_STRING: 
			process_string(message) 
		TYPE_PACKED_BYTE_ARRAY: 
			process_audio(message)
				
func _on_web_socket_server_client_connected(peer_id) -> void:
	id = peer_id 
	print(peer_id)
