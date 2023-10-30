extends GDCubismEffectCustom
class_name SingingMouthMovement

@export var live_2d_melba = Node # The node with live2d_melba.gd
@export var mouth_movement := MouthMovement # MouthMovement node 
@export var param_mouth_name: String = "ParamMouthOpenY"
@export var param_mouth_form_name: String = "ParamMouthForm"
@export var param_eye_ball_x_name: String = "ParamEyeBallX"
@export var param_eye_ball_y_name: String = "ParamEyeBallY"

# Parameters
var param_mouth: GDCubismParameter
var param_mouth_form: GDCubismParameter
var param_eye_ball_x: GDCubismParameter
var param_eye_ball_y: GDCubismParameter
# Tween values
var mouth_pos = 0.6
var mouth_form_pos = -0.8
var eye_x_pos = 0.0
var eye_y_pos = 0.0
var previous_volume = 0.0
# Tweens
var tween_mouth: Tween
var tween_mouth_form: Tween
var tween_eye_x: Tween
var tween_eye_y: Tween
# For voice analysis 
var spectrum: AudioEffectSpectrumAnalyzer

func _ready():
	self.cubism_init.connect(_on_cubism_init)
	self.cubism_process.connect(_on_cubism_process)
	Globals.start_singing_mouth_movement.connect(_start_movement)
	Globals.end_singing_mouth_movement.connect(_end_movement)

func _on_cubism_init(model: GDCubismUserModel):
	var any_param = model.get_parameters()

	for param in any_param:
		if param.id == param_mouth_name:
			param_mouth = param
		if param.id == param_mouth_form_name:
			param_mouth_form = param
		if param.id == param_eye_ball_x_name:
			param_eye_ball_x = param
		if param.id == param_eye_ball_y_name:
			param_eye_ball_y = param

func _on_cubism_process(_model: GDCubismUserModel, _delta: float):
	manage_mouth_movement() # For mouth opening and closing

func _start_movement() -> void:
	position_eyes_and_mouth()  
	active = true 
	mouth_movement.active = false 

func _end_movement() -> void: 
	active = false  
	mouth_movement.active = true 

func position_eyes_and_mouth() -> void: 
	pass 
	
func manage_mouth_movement() -> void:
	pass 

