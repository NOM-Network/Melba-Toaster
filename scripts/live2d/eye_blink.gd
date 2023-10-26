extends GDCubismEffectCustom
class_name EyeBlink 

@export var blink_timer: Timer

var param_eye
var tween: Tween 

func _ready():
	self.cubism_init.connect(_on_cubism_init)

func _on_cubism_init(model: GDCubismUserModel):
	blink_timer.timeout.connect(_on_timer_timeout)
	var any_param = model.get_parameters()
	for param in any_param:
		if param.id == "ParamEyeLOpen":
			param_eye = param

func _on_timer_timeout() -> void:
	if active:
		tween = create_tween()
		tween.finished.connect(_on_tween_finished)
		tween.tween_property(param_eye, "value", 0.0, 0.1)

func _on_tween_finished() -> void:
	if active: 
		tween = create_tween()
		tween.tween_property(param_eye, "value", 1.0, 0.1)


