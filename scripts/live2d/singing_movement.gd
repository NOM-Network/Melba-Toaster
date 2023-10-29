extends GDCubismEffectCustom
class_name SingingMovement 

@onready var sprite_2d = %Sprite2D
@onready var gd_cubism_user_model = %GDCubismUserModel

@export var param_angle_y_name = "ParamAngleY"
@export var param_body_angle_y_name = "ParamBodyAngleY"

# Parameters 
var param_angle_y
var param_body_angle_y
# Tweens  
var angle_y_tween: Tween
var body_angle_y_tween: Tween 

func _ready():
	self.cubism_init.connect(_on_cubism_init)
	self.cubism_process.connect(_on_cubism_process)

func _on_cubism_init(model: GDCubismUserModel):
	var any_param = model.get_parameters()

	for param in any_param:
		if param.id == param_angle_y_name: 
			param_angle_y = param
		if param.id == param_body_angle_y_name:
			param_body_angle_y = param
	
	start_tween()

func _on_cubism_process(_model: GDCubismUserModel, _delta: float):
	pass
	
var bob_interval = 0.25
func start_tween() -> void:
	if angle_y_tween: angle_y_tween.kill()
	if body_angle_y_tween: body_angle_y_tween.kill() 
	angle_y_tween = create_tween()
	body_angle_y_tween = create_tween() 
	
	angle_y_tween.finished.connect(_on_tween_finished)
	angle_y_tween.tween_property(param_angle_y, "value", 30.0, bob_interval)
	body_angle_y_tween.tween_property(param_body_angle_y, "value", 30.0, bob_interval)

func _on_tween_finished() -> void:
	if angle_y_tween: angle_y_tween.kill()
	if body_angle_y_tween: body_angle_y_tween.kill() 
	body_angle_y_tween = create_tween() 
	angle_y_tween = create_tween()
	
	body_angle_y_tween.tween_property(param_body_angle_y, "value", -30.0, bob_interval)
	await angle_y_tween.tween_property(param_angle_y, "value", -30.0, bob_interval).finished
	
	start_tween()
