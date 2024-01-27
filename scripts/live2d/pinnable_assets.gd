extends Node
class_name PinnableAsset

var node_name: String
var enabled: bool
var mesh: String
var position_offset: Vector2
var scale_offset: float
var custom_point: int
var second_point: int

var node: Node
var initial_points := [0.0, 0.0]

func _init(
	p_node_name: String,
	p_mesh: String,
	p_position_offset: Vector2 = Vector2.ZERO,
	p_scale_offset: float = 0.0,
	p_custom_point: int = 0,
	p_second_point: int = 4
) -> void:
	self.node_name = p_node_name
	self.mesh = p_mesh
	self.position_offset = p_position_offset
	self.scale_offset = p_scale_offset
	self.custom_point = p_custom_point
	self.second_point = p_second_point
