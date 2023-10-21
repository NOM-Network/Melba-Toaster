extends Node

@export var path = "C:/Users/user/Downloads/audio/" 

@onready var model = $PixelMelba
@onready var server = $WebSocketServer

const PORT = 8765 

var control_panel = preload("res://scenes/control_panel/control_panel.tscn")

var id: int 

func _ready() -> void:
    # Get rid of this code when we have a background. 
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

func _on_web_socket_server_message_received(_peer_id, message):
    server.send(id, message)
    print(typeof(message))
    if message == "quit":
        get_tree().quit()
    if message == "toast":
        model.toast_toggle()
    if message.is_valid_int():
        model.play_audio(path + message + ".wav")

func _on_web_socket_server_client_connected(peer_id):
    id = peer_id 
    print(peer_id)
