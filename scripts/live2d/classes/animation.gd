extends Node
class_name Live2DAnimation

var id: int
var duration: float
var ignore_blinking: bool
var override_name: String
var override = null

func _init(p_id, p_duration, p_ignore_blinking := false, p_override_name := "") -> void:
	self.id = p_id
	self.duration = p_duration
	self.ignore_blinking = p_ignore_blinking
	self.override_name = p_override_name
