# Base class for all Melba Models
# Needs to be a parent of a MelbaServer
extends Node2D
class_name MelbaModel 

@onready var server: MelbaServer = get_parent() 

func connect_signals() -> void: 
	server.play_animation.connect(play_animation)
	server.set_expression.connect(set_expression)
	server.play_audio.connect(play_audio)  

# Do not override
func play_animation(animation_name: String) -> void:
	match animation_name: 
		"lookAtChat": look_at_chat() 

# Do not override 
func set_expression(expression_name: String) -> void:
	match expression_name: 
		"toastToggle": toast_toggle() 

# Plays audio, override to use. 
func play_audio(stream: AudioStreamWAV): 
	pass 

# Animation, override to use. 
func look_at_chat():
	pass 

# Expression, override to use. 
func toast_toggle():
	pass 

