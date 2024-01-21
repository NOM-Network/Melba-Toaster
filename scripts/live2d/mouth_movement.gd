extends GDCubismEffectCustom
class_name MouthMovement

@export var mouth_movement := MouthMovement # MouthMovement node
@export var audio_bus_name := "Voice"
@export var min_db := 60.0
@export var min_voice_freq := 450
@export var max_voice_freq := 750
@export var freq_steps := 10
@export var vowel_freqs: Array

# Parameter Names
@export_category("Param Names")
@export var param_mouth_name: String = "ParamMouthOpenY"
@export var param_mouth_form_name: String = "ParamMouthForm"

# Parameter Values
@export_category("Param Values")
@export_range(-1.0, 1.0) var max_mouth_value := 0.8

# Parameters
var param_mouth: GDCubismParameter
var param_mouth_form: GDCubismParameter
var param_eye_ball_x: GDCubismParameter
var param_eye_ball_y: GDCubismParameter

# For voice analysis
var spectrum: AudioEffectSpectrumAnalyzerInstance
var prev_values_amount := 10
var prev_mouth_values := []
var prev_mouth_form_values := []
var test_array := []

func _init() -> void:
	for i in freq_steps:
		vowel_freqs.append([min_voice_freq + i * freq_steps, min_voice_freq + (i + 1) * freq_steps])
	vowel_freqs.reverse()

func _ready():
	cubism_init.connect(_on_cubism_init)
	cubism_process.connect(_on_cubism_process)

func _on_cubism_init(model: GDCubismUserModel):
	var any_param = model.get_parameters()

	for param in any_param:
		if param.id == param_mouth_name:
			param_mouth = param
		if param.id == param_mouth_form_name:
			param_mouth_form = param

	var bus = AudioServer.get_bus_index(audio_bus_name)
	spectrum = AudioServer.get_bus_effect_instance(bus, 0)
	prev_mouth_values.resize(prev_values_amount)
	prev_mouth_values.fill(0.0)

	prev_mouth_form_values.resize(prev_values_amount)
	prev_mouth_form_values.fill(0.0)

	test_array.resize(prev_values_amount - 1)
	test_array.fill(0.0)

func _on_cubism_process(_model: GDCubismUserModel, _delta: float):
	var overall_magnitude: float = spectrum.get_magnitude_for_frequency_range(
		min_voice_freq,
		max_voice_freq
	).length()
	var overall_energy = clamp((min_db + linear_to_db(overall_magnitude)) / min_db, 0.0, 1.0)

	var max_vowel_enegry := 0.0
	var selected_vowel := 0
	if overall_magnitude > 0.0:
		for i in range(0, vowel_freqs.size()):
			var magnitude = spectrum.get_magnitude_for_frequency_range(
				vowel_freqs[i][0],
				vowel_freqs[i][1]
			).length()
			var energy = clamp((min_db + linear_to_db(magnitude)) / min_db, 0.0, 1.0)

			if energy != 0.0 and energy >= max_vowel_enegry:
				max_vowel_enegry = energy
				selected_vowel = i

	var selected_mouth_form = 0.0
	if selected_vowel > 0:
		selected_mouth_form = _map_to_log_range(selected_vowel)

	var unaltered_mouth_value = overall_energy * max_mouth_value
	var unaltered_mouth_form = Globals.current_emotion_modifier + clamp(selected_mouth_form * overall_energy, 0.0, 0.8)

	if Globals.is_singing or Globals.is_speaking:
		manage_speaking()
	else:
		param_mouth.value = 0.0
		param_mouth_form.value = lerp(param_mouth_form.value, Globals.current_emotion_modifier, 0.01)

	prev_mouth_values.remove_at(0)
	prev_mouth_values.append(unaltered_mouth_value)

	prev_mouth_form_values.remove_at(0)
	prev_mouth_form_values.append(unaltered_mouth_form)

func manage_speaking() -> void:
	param_mouth.value = _find_avg(prev_mouth_values.slice(-3))
	param_mouth_form.value = _find_avg(prev_mouth_form_values.slice(-3))

	if prev_mouth_values[prev_values_amount - 1] != 0.0 \
		and prev_mouth_values.slice(0, prev_values_amount - 1) == test_array \
		and not Globals.is_singing:
		Globals.nudge_model.emit()

func _find_avg(numbers: Array) -> float:
	var total := 0.0
	for num in numbers:
		total += num
	var avg: float = total / float(numbers.size())
	return avg

func _map_to_log_range(value: float) -> float:
	var old_max = clamp(freq_steps - 1, 0, freq_steps - 1)
	var new_min = 0.0
	var new_max = 1.0
	var epsilon = 0.001

	var log_max = log(old_max + epsilon)
	var log_min = log(epsilon)

	var log_value = log(value + epsilon)
	var normalized_log_value = (log_max - log_value) / (log_max - log_min)

	return (normalized_log_value * (new_max - new_min)) + new_min
