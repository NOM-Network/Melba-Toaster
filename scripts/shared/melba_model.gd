# Base class for all Melba Models
extends Node2D
class_name MelbaModel 

# Do not override this function 
func play_animation(animation_name: String) -> void:
	match animation_name: 
		"lookAtChat": look_at_chat() 

# Do not override this function 
func set_expression(expression_name: String) -> void:
	match expression_name: 
		"toast_toggle": toast_toggle() 

# Plays audio, override to use. 
func play_audio(stream: AudioStreamWAV): 
	pass 

# Animation, override to use. 
func look_at_chat():
	pass 

# Expression, override to use. 
func toast_toggle():
	pass 

