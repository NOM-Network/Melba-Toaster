extends GDCubismEffectCustom
class_name SingingMovement

@onready var sprite_2d = %Sprite2D
@onready var gd_cubism_user_model = %GDCubismUserModel

@export var param_angle_y_name = "ParamAngleY"
@export var param_body_angle_y_name = "ParamBodyAngleY"
@export var bob_interval = 0.5
@export var audio_bus_name := "Control"

# Parameters
var param_angle_y
var param_body_angle_y

# Tweens
var angle_y_tween: Tween
var body_angle_y_tween: Tween

func _ready():
	self.cubism_init.connect(_on_cubism_init)

func _on_cubism_init(model: GDCubismUserModel):
	Globals.start_dancing_motion.connect(_start_motion)
	Globals.end_dancing_motion.connect(_end_motion)

	var any_param = model.get_parameters()

	for param in any_param:
		if param.id == param_angle_y_name:
			param_angle_y = param
		if param.id == param_body_angle_y_name:
			param_body_angle_y = param

func _start_motion(bpm: float) -> void:
	Globals.dancing_bpm = bpm
	bob_interval = 60.0 / bpm
	start_tween()

func _end_motion() -> void:
	Globals.dancing_bpm = 0

func start_tween() -> void:
	if angle_y_tween: angle_y_tween.kill()
	if body_angle_y_tween: body_angle_y_tween.kill()
	angle_y_tween = create_tween()
	body_angle_y_tween = create_tween()

	angle_y_tween.finished.connect(_on_tween_finished)
	angle_y_tween.tween_property(param_angle_y, "value", 30.0, bob_interval / 2.0)
	body_angle_y_tween.tween_property(param_body_angle_y, "value", 30.0, bob_interval / 2.0)

func _on_tween_finished() -> void:
	if angle_y_tween: angle_y_tween.kill()
	if body_angle_y_tween: body_angle_y_tween.kill()
	body_angle_y_tween = create_tween()
	angle_y_tween = create_tween()

	body_angle_y_tween.tween_property(param_body_angle_y, "value", -30.0, bob_interval / 2.0)
	await angle_y_tween.tween_property(param_angle_y, "value", -30.0, bob_interval / 2.0).finished

	if Globals.dancing_bpm:
		start_tween()
