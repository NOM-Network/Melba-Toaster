# Base class for all Melba Models
# Needs to be a parent of a MelbaServer
extends Node2D
class_name MelbaModel

@onready var server: ModelController = get_parent()

var audio_queue := []

# Make sure to run this function within the _ready() function
func connect_signals() -> void:
	server.play_animation.connect(play_animation)
	server.set_expression.connect(set_expression)
	server.queue_audio.connect(queue_audio)

# Do not override
func play_animation(animation_name: String) -> void:
	match animation_name:
		"lookAtChat": look_at_chat()

# Do not override
func set_expression(expression_name: String, enabled: bool) -> void:
	match expression_name:
		"toastToggle": toast_toggle(enabled)
		"voidToggle": void_toggle(enabled)
		"removeToggle": remove_toggle(enabled)

# Do not override.
func queue_audio(stream: AudioStreamMP3):
	audio_queue.append(stream)

# Override to use.
func play_audio(_stream: AudioStreamMP3) -> void:
	pass

# An animation, override to use.
func look_at_chat() -> void:
	pass

# An expression, override to use.
func toast_toggle(enabled: bool) -> void:
	pass

# An exprssion, override to use.
func void_toggle(enabled: bool) -> void:
	pass

# An expression, override to use.
func remove_toggle(enabled: bool) -> void:
	pass
