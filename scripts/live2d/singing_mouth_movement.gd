extends GDCubismEffectCustom
class_name SingingMouthMovement

@export var mouth_movement := MouthMovement # MouthMovement node
@export var audio_bus_name := "Voice"
@export var min_db := 60.0
@export var min_voice_freq := 0
@export var max_voice_freq := 3200
# Parameter Names
@export_category("Param Names")
@export var param_mouth_name: String = "ParamMouthOpenY"
@export var param_mouth_form_name: String = "ParamMouthForm"
@export var param_eye_ball_x_name: String = "ParamEyeBallX"
@export var param_eye_ball_y_name: String = "ParamEyeBallY"
# Parameter Values
@export_category("Param Values")
@export var max_mouth_value := 0.7
@export var min_mouth_value := 0.2
@export var mouth_form_value := 0.0
# Parameters
var param_mouth: GDCubismParameter
var param_mouth_form: GDCubismParameter
var param_eye_ball_x: GDCubismParameter
var param_eye_ball_y: GDCubismParameter
# For voice analysis
var spectrum: AudioEffectSpectrumAnalyzerInstance

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

	var bus = AudioServer.get_bus_index(audio_bus_name)
	spectrum = AudioServer.get_bus_effect_instance(bus, 0)


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

var freq_array := [0.0, 0.0, 0.0, 0.0]
func manage_mouth_movement() -> void:
	var magnitude: float = spectrum.get_magnitude_for_frequency_range(
		min_voice_freq,
		max_voice_freq
	).length()
	var energy = clamp((min_db + linear_to_db(magnitude)) / min_db, 0.0, 1.0)

	param_mouth_form.value = mouth_form_value
	param_mouth.value = energy * max_mouth_value

	# Update array
	freq_array.remove_at(0)
	freq_array.append(param_mouth.value)

	# param mouth value is only set to below min mouth value if
	# all three values before it were less than the min mouth value.
	if param_mouth.value < min_mouth_value and not freq_array.all(func(e): return e < min_mouth_value):
		param_mouth.value = min_mouth_value

	if abs(freq_array[-2] - param_mouth.value) > 0.4:
		param_mouth.value = (freq_array[-2] + param_mouth.value) / 2.0

