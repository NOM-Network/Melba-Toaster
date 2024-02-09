extends GDCubismEffectCustom
class_name SingingMovement

@onready var sprite_2d = %Sprite2D
@onready var gd_cubism_user_model = %GDCubismUserModel

var bob_interval = 0.5
var motion_range: float = 30.0

# Parameters
var param_angle_y: GDCubismParameter
var param_body_angle_y: GDCubismParameter

# Tweens
var tween: Tween

func _ready():
	self.cubism_init.connect(_on_cubism_init)

func _on_cubism_init(model: GDCubismUserModel):
	Globals.start_dancing_motion.connect(_start_motion)
	Globals.end_dancing_motion.connect(_end_motion)

	for param in model.get_parameters():
		if param.id == "ParamAngleY":
			param_angle_y = param
		if param.id == "ParamBodyAngleY":
			param_body_angle_y = param

		if param_angle_y && param_body_angle_y:
			break

func _start_motion(bpm: float) -> void:
	Globals.dancing_bpm = bpm
	bob_interval = motion_range / bpm

	start_tween()

func _end_motion() -> void:
	Globals.dancing_bpm = 0

	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(param_angle_y, "value", 0, bob_interval)
	tween.set_parallel().tween_property(param_body_angle_y, "value", 0, bob_interval)

func start_tween() -> void:
	if tween:
		tween.kill()

	tween = create_tween().set_loops()

	# Positive
	tween.tween_property(param_angle_y, "value", -motion_range, bob_interval)
	tween.set_parallel().tween_property(param_body_angle_y, "value", -motion_range, bob_interval)

	# Negative
	tween.chain().tween_property(param_angle_y, "value", motion_range, bob_interval)
	tween.set_parallel().tween_property(param_body_angle_y, "value", motion_range, bob_interval)
