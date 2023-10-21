extends Node

@onready var server = $WebSocketServer
@onready var model = $Live2DMelba


const PORT = 8765 

var id: int 

func _ready() -> void:
    # Get rid of this code when we have a background. 
    get_tree().get_root().set_transparent_background(true)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)

    var err: Error = server.listen(PORT)
    if err != OK:
        print("Error listing on port %s" % PORT)
    
func _on_web_socket_server_message_received(peer_id, message):
    server.send(id, message)
    if typeof(message) == 4: 
        var data = JSON.parse_string(message)
        if data["type"] == "PlayAnimation":
            if data["animationName"] == "wink1":
                model.test()
                
func _on_web_socket_server_client_connected(peer_id):
    id = peer_id 
    print(peer_id)
