extends Node
class_name ModelController

@onready var model := $Live2DMelba

# TODO: Remove controller altogether or make it useful
func _ready() -> void:
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)

	Globals.incoming_speech.connect(process_audio)

# TODO: move to the model itself
func process_audio(message: PackedByteArray) -> void:
	var stream = AudioStreamMP3.new()
	stream.data = message
	model.queue_audio(stream)
