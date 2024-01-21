extends GDCubismEffectCustom

@onready var blink_timer := $BlinkTimer
@export var chance_to_squint := 3.0

var param_eye: GDCubismParameter
var param_smile: GDCubismParameter
var squint_value := 0.0
var tween: Tween

func _ready():
	cubism_init.connect(_on_cubism_init)

func _on_cubism_init(model: GDCubismUserModel):
	blink_timer.timeout.connect(_on_timer_timeout)

	var any_param = model.get_parameters()

	for param in any_param:
		if param.id == "ParamEyeLOpen":
			param_eye = param
			break

func _process(_delta: float) -> void:
	if squint_value != 0.0:
		param_eye.value = squint_value

func _on_timer_timeout() -> void:
	if active:
		if randf_range(0, chance_to_squint) > 1.0:
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

	squint_value = 0.0
	tween = create_tween()
	tween.tween_property(param_eye, "value", 0.0, 0.05)
	tween.tween_property(param_eye, "value", 0.0, randf_range(0.01, 0.1))
	tween.tween_property(param_eye, "value", 1.0, 0.05)
	await tween.finished

func _squint_tween() -> void:
	if tween:
		tween.kill()

	squint_value = randf_range(0.7, 1.0)
	tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(param_eye, "value", squint_value, randf_range(0.1, 0.5))
	await tween.finished
