# Base class for all Melba Models
# Needs to be a parent of a MelbaServer
extends Node2D
class_name MelbaModel

@onready var server: MelbaServer = get_parent()

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
func set_expression(expression_name: String) -> void:
	match expression_name:
		"toastToggle": toast_toggle()

# Do not override.
func queue_audio(stream: AudioStreamWAV):
	audio_queue.append(stream)

# Override to use.
func play_audio(_stream: AudioStreamWAV) -> void:
	pass

# An animation, override to use.
func look_at_chat() -> void:
	pass

# An expression, override to use.
func toast_toggle() -> void:
	pass

