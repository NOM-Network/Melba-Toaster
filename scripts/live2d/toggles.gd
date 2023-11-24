extends Node
class_name Toggle

var param: GDCubismParameter
var enabled := false
var value := 0.0
var id: String
var duration: float

func _init(p_id, p_duration, p_enabled := false) -> void:
	self.id = p_id
	self.duration = p_duration
	self.enabled = p_enabled
