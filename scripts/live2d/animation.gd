extends Node
class_name Live2DAnimation

var id: int
var duration: float
var override_name: String 
var override = null

func _init(p_id, p_duration, p_override_name := "") -> void:
	self.id = p_id
	self.duration = p_duration
	self.override_name = p_override_name
