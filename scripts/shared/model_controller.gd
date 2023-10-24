extends Node
class_name ModelController

signal play_animation
signal set_expression
signal queue_audio

@onready var model := $Live2DMelba

func _ready() -> void:
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)

func _process(_delta: float) -> void:
	var memory_usage = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024 / 1024
	if memory_usage > 200:
		print("Error excessive memory usage")
		get_tree().quit()

func play_anim(type):
	play_animation.emit(type)

func set_expr(type):
	set_expression.emit(type)

func process_audio(message: PackedByteArray) -> void:
	var stream = AudioStreamWAV.new()
	stream.data = message
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	queue_audio.emit(stream)
