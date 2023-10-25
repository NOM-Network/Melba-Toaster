extends GDCubismEffectCustom
class_name MouthMovement

@export var live_2d_melba = Node # The node with live2d_melba.gd 
@export var param_mouth_name: String = "ParamMouthOpenY"
@export var param_mouth_form_name: String = "ParamMouthForm"

var param_mouth: GDCubismParameter
var param_mouth_form: GDCubismParameter
var tween: Tween
var blabbering = false

func _ready():
	self.cubism_init.connect(_on_cubism_init)
	self.cubism_process.connect(_on_cubism_process)
	self.cubism_term.connect(_on_cubism_term)

func _on_cubism_init(model: GDCubismUserModel):
	param_mouth = null
	var any_param = model.get_parameters()

	for param in any_param:
		if param.id == param_mouth_name:
			param_mouth = param
		if param.id == param_mouth_form_name:
			param_mouth_form = param

func _on_cubism_term(_model: GDCubismUserModel):
	param_mouth = null
	param_mouth_form = null

func _on_cubism_process(_model: GDCubismUserModel, _delta: float):
	if param_mouth != null:
		var volume = (AudioServer.get_bus_peak_volume_left_db(0,0) + AudioServer.get_bus_peak_volume_right_db(0,0)) / 2.0
		if volume < -60.0: # If she is not speaking
			blabbering = false
		elif not blabbering: # If she just started speaking
			blabbering = true
			start_tween()
		else: # If she has been speaking
			pass
			
	if live_2d_melba.reading_audio:
		param_mouth_form.value = -0.8
	else: 
		if tween: tween.kill()

func start_tween() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.finished.connect(_on_tween_finished)
	tween.tween_property(param_mouth, "value", 0.6, 0.15)

func _on_tween_finished() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	await tween.tween_property(param_mouth, "value", 0.0, 0.15).finished
	if blabbering:
		start_tween()
	else:
		param_mouth.value = 0.0
