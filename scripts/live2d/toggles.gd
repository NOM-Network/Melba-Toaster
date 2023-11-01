extends Node
class_name Toggle 

var param: GDCubismParameter
var enabled := false 
var value := 0.0   
var id: String 
var duration: float 

func _init(id, duration):
	self.id = id 
	self.duration = duration 
