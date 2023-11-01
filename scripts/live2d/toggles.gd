extends Node
class_name Toggle 

var param: GDCubismParameter
var enabled: bool
var value: float  
var id: String 
var duration: float 

func _init(enabled, value, id, duration):
	self.enabled = enabled 
	self.value = value 
	self.id = id 
	self.duration = duration 
