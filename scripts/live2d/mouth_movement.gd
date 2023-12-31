extends GDCubismEffectCustom
class_name MouthMovement

@export var mouth_movement := MouthMovement # MouthMovement node
@export var audio_bus_name := "Voice"
@export var min_db := 60.0
@export var min_voice_freq := 200
@export var max_voice_freq := 800

# Parameter Names
@export_category("Param Names")
@export var param_mouth_name: String = "ParamMouthOpenY"
@export var param_mouth_form_name: String = "ParamMouthForm"

# Parameter Values
@export_category("Param Values")
@export var max_mouth_value := 0.6
@export var mouth_form_value := 0.0

# Parameters
var param_mouth: GDCubismParameter
var param_mouth_form: GDCubismParameter
var param_eye_ball_x: GDCubismParameter
var param_eye_ball_y: GDCubismParameter

# For voice analysis
var spectrum: AudioEffectSpectrumAnalyzerInstance
var prev_value := 0.0
var prev_values_amount := 10
var prev_unaltered_values := []
var test_array := []

func _ready():
	self.cubism_init.connect(_on_cubism_init)
	self.cubism_process.connect(_on_cubism_process)

func _on_cubism_init(model: GDCubismUserModel):
	var any_param = model.get_parameters()

	for param in any_param:
		if param.id == param_mouth_name:
			param_mouth = param
		if param.id == param_mouth_form_name:
			param_mouth_form = param

	var bus = AudioServer.get_bus_index(audio_bus_name)
	spectrum = AudioServer.get_bus_effect_instance(bus, 0)
	prev_unaltered_values.resize(prev_values_amount)
	prev_unaltered_values.fill(0.0)

	test_array.resize(prev_values_amount - 1)
	test_array.fill(0.0)

func _on_cubism_process(_model: GDCubismUserModel, _delta: float):
	var magnitude: float = spectrum.get_magnitude_for_frequency_range(
		min_voice_freq,
		max_voice_freq
	).length()
	var energy = clamp((min_db + linear_to_db(magnitude)) / min_db, 0.0, 1.0)

	param_mouth_form.value = mouth_form_value
	var unaltered_value = energy * max_mouth_value
	param_mouth.value = energy * max_mouth_value

	if Globals.is_singing:
		manage_singing()
	elif Globals.is_speaking:
		manage_speaking()
	else:
		param_mouth.value = 0.0

	prev_unaltered_values.remove_at(0)
	prev_unaltered_values.append(unaltered_value)

func manage_singing() -> void:
	if abs(prev_value - param_mouth.value) > 0.07:
		if prev_value > param_mouth.value:
			param_mouth.value = prev_value - 0.07
		else:
			param_mouth.value = prev_value + 0.07

	prev_value = param_mouth.value

func manage_speaking() -> void:
	param_mouth.value = find_avg(prev_unaltered_values.slice(-4))
	
	if param_mouth.value < 0.1:
		var force_value := false
		for i in prev_unaltered_values:
			if i != 0.0:
				force_value = true
		if force_value:
			param_mouth.value = 0.1

	#if abs(prev_value - param_mouth.value) > 0.06:
		#if prev_value > param_mouth.value:
			#param_mouth.value = prev_value - 0.06
		#else:
			#param_mouth.value = prev_value + 0.06

	if prev_unaltered_values[prev_values_amount - 1] != 0.0 \
		and prev_unaltered_values.slice(0, prev_values_amount - 1) == test_array:
		Globals.nudge_model.emit()

	prev_value = param_mouth.value


func find_avg(numbers: Array) -> float: 
	var total := 0.0
	for num in numbers: 
		total += num
	var avg: float = total / float(numbers.size())
	return avg
