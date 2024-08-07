extends Node
class_name Toggle

var param: GDCubismParameter
var enabled := false
var default_state := false
var value := 0.0
var id: String
var duration: float

func _init(p_id: String, p_duration: float, p_enabled := false) -> void:
	self.id = p_id
	self.duration = p_duration
	self.enabled = p_enabled
	self.default_state = p_enabled
	self.value = 1.0 if enabled else 0.0
