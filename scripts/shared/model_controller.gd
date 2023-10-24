extends Node
class_name ModelController

signal play_animation
signal set_expression
signal queue_audio

@onready var model := $Live2DMelba

func _ready() -> void:
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)

func play_anim(type):
	play_animation.emit(type)

func set_expr(type, enabled):
	set_expression.emit(type, enabled)

func process_audio(message: PackedByteArray) -> void:
	var stream = AudioStreamMP3.new()
	stream.data = message
	queue_audio.emit(stream)
