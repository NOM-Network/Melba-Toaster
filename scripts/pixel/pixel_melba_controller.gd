extends Node

@export var path = "C:/Users/user/Downloads/audio/"

@onready var model = $PixelMelba

func _ready() -> void:
	# Get rid of this code when we have a background.
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)
