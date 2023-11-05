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
# States
var singing := false

func _ready():
	self.cubism_init.connect(_on_cubism_init)
#	self.cubism_process.connect(_on_cubism_process)
	Globals.start_dancing_motion.connect(_start_motion)
	Globals.end_dancing_motion.connect(_end_motion)

func _on_cubism_init(model: GDCubismUserModel):
	var any_param = model.get_parameters()

	for param in any_param:
		if param.id == param_angle_y_name:
			param_angle_y = param
		if param.id == param_body_angle_y_name:
			param_body_angle_y = param

func _start_motion(bpm: float, wait_time: float, stop_time: float) -> void:
	singing = true
	bob_interval = 60.0 / bpm
	await get_tree().create_timer(wait_time).timeout
	start_tween()

	if stop_time != 0.0:
		await get_tree().create_timer(stop_time - wait_time).timeout
		_end_motion()

func _end_motion() -> void:
	singing = false

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

	if singing:
		start_tween()
