extends Node
class_name PinnableAsset 

var node: Node = null 
var enabled: bool 
var node_name: String 
var mesh: String 
var offset: Vector2 
var custom_point: int
var second_point: int 

var initial_points := {
	"A": 0,
	"B": 0
}

func _init(p_node_name: String, p_mesh: String, 
		   p_offset: Vector2, p_custom_point: int = 0, 
		   p_second_point: int = 1) -> void:
	self.node_name = p_node_name 
	self.mesh = p_mesh 
	self.offset = p_offset 
	self.custom_point = p_custom_point
	self.second_point = p_second_point 
	
