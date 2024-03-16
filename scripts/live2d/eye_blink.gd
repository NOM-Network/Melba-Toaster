extends GDCubismEffectCustom

@onready var blink_timer := $BlinkTimer
@export var chance_to_squint := 3.0

var param_eye_l_open: GDCubismParameter
var param_eye_ball_y: GDCubismParameter

var squint_value := 0.0
var tween: Tween

func _ready():
	cubism_init.connect(_on_cubism_init)

func _on_cubism_init(model: GDCubismUserModel):
	blink_timer.timeout.connect(_on_timer_timeout)

	var param_names = [
		"ParamEyeLOpen",
		"ParamEyeBallY",
	]

	for param in model.get_parameters():
		if param_names.has(param.id):
			set(param.id.to_snake_case(), param)

func _process(_delta: float) -> void:
	if Globals.last_animation == "sleep":
		return

	if Globals.is_singing or not active:
		param_eye_l_open.value = 1.0
		param_eye_ball_y.value = 0.0
	else:
		param_eye_l_open.value = squint_value if squint_value > 0.0 else 1.0
		param_eye_ball_y.value = -squint_value if squint_value < 0.8 else 0.0

func _on_timer_timeout() -> void:
	if active and Globals.last_animation != "sleep":
		if randf_range(0, chance_to_squint) > 1.0 and not Globals.is_singing:
			await _squint_tween()
		else:
			await _blink_tween()
			if randi_range(0, 5) == 0: # blink twice
				await _blink_tween()

	blink_timer.wait_time = randf_range(1.0, 5.0)
	blink_timer.start()

func _blink_tween() -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(self, "squint_value", 0.0, 0.05)
	tween.tween_property(param_eye_l_open, "value", 0.0, 0.05)
	tween.tween_property(param_eye_l_open, "value", 0.0, randf_range(0.01, 0.1))
	tween.tween_property(param_eye_l_open, "value", 1.0, 0.05)
	await tween.finished

func _squint_tween() -> void:
	if tween:
		tween.kill()

	squint_value = randf_range(0.5, 1.0)
	var time := randf_range(0.1, 0.5)
	tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(param_eye_l_open, "value", squint_value, time)
	tween.tween_property(param_eye_ball_y, "value", -squint_value if squint_value < 0.8 else 0.0, time)
	await tween.finished
