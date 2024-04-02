extends GDCubismEffectCustom
class_name MouthMovement

@export var mouth_movement := MouthMovement # MouthMovement node
@export var audio_bus_name := "Voice"
@export var min_db := 60.0
@export var min_voice_freq := 450
@export var max_voice_freq := 750
@export var freq_steps := 10
@export var vowel_freqs: Array

# Parameter Values
@export_category("Param Values")
@export_range(-1.0, 1.0) var max_mouth_value := 0.8

# Parameters
var param_mouth_open_y: GDCubismParameter
var param_mouth_form: GDCubismParameter

# For voice analysis
@onready var bus := AudioServer.get_bus_index(audio_bus_name)
@onready var spectrum := AudioServer.get_bus_effect_instance(bus, 0)
var prev_values_amount := 10
var prev_mouth_values := []
var prev_mouth_form_values := []
var test_array := []
var allow_nudge := true

func _init() -> void:
	for i in freq_steps:
		vowel_freqs.append([min_voice_freq + i * freq_steps, min_voice_freq + (i + 1) * freq_steps])

	_reset_values()

func _ready() -> void:
	cubism_init.connect(_on_cubism_init)
	cubism_process.connect(_on_cubism_process)

	Globals.reset_subtitles.connect(_on_reset_subtitles)

func _on_cubism_init(model: GDCubismUserModel) -> void:
	var param_names: Array = [
		"ParamMouthOpenY",
		"ParamMouthForm",
	]

	for param: GDCubismParameter in model.get_parameters():
		if param_names.has(param.id):
			set(param.id.to_snake_case(), param)

func _on_reset_subtitles() -> void:
	_reset_values()

func _reset_values() -> void:
	prev_mouth_values.resize(prev_values_amount)
	prev_mouth_values.fill(0.0)

	prev_mouth_form_values.resize(prev_values_amount)
	prev_mouth_form_values.fill(0.0)

	test_array.resize(prev_values_amount - 1)
	test_array.fill(0.0)

func _on_cubism_process(_model: GDCubismUserModel, _delta: float) -> void:
	var overall_magnitude: float = 0.0
	var unaltered_mouth_value: float = 0.0
	var unaltered_mouth_form: float = 0.0

	if Globals.is_singing or Globals.is_speaking:
		overall_magnitude = spectrum.get_magnitude_for_frequency_range(
			min_voice_freq,
			max_voice_freq
		).length()
		var overall_energy: float = clamp((min_db + linear_to_db(overall_magnitude)) / min_db, 0.0, 1.0)

		var selected_mouth_form: float = 0.0
		if overall_energy and overall_magnitude:
			var max_vowel_enegry := 0.0
			var selected_vowel := 0
			for i in range(0, vowel_freqs.size()):
				var magnitude: float = spectrum.get_magnitude_for_frequency_range(
					vowel_freqs[i][0],
					vowel_freqs[i][1]
				).length()
				var energy: float = clamp((min_db + linear_to_db(magnitude)) / min_db, 0.0, 1.0)

				if energy != 0.0 and energy >= max_vowel_enegry:
					max_vowel_enegry = energy
					selected_vowel = i

			if selected_vowel > 0:
				selected_mouth_form = _map_to_log_range(selected_vowel)

		unaltered_mouth_value = overall_energy * max_mouth_value
		unaltered_mouth_form = Globals.current_emotion_modifier + clamp(selected_mouth_form * overall_energy, 0.0, 1.0)

		manage_speaking()
	else:
		param_mouth_open_y.value = 0.0
		param_mouth_form.value = lerp(param_mouth_form.value, Globals.current_emotion_modifier, 0.01)

	prev_mouth_values.remove_at(0)
	prev_mouth_values.append(unaltered_mouth_value)

	prev_mouth_form_values.remove_at(0)
	prev_mouth_form_values.append(unaltered_mouth_form)

func manage_speaking() -> void:
	# Mouth amplitude
	param_mouth_open_y.value = _find_avg(prev_mouth_values.slice( - 4))

	# Mouth form
	var mouth_form: float = _find_avg(prev_mouth_form_values.slice( - 3))
	param_mouth_form.value = _clamp_to_log_scale(mouth_form)

	if prev_mouth_values[prev_values_amount - 1] != 0.0 \
		and prev_mouth_values.slice(0, prev_values_amount - 1) == test_array \
		and not Globals.is_singing:
		Globals.nudge_model.emit()

func _find_avg(numbers: Array) -> float:
	var total := 0.0
	for num: float in numbers:
		total += num
	var avg: float = total / float(numbers.size())
	return avg

func _clamp_to_log_scale(value: float) -> float:
	return 1.0 - (log(1.0 - value + 1.0) / log(1.0 + 1.0))

func _map_to_log_range(value: float) -> float:
	var old_max: float = clamp(freq_steps - 1, 0, freq_steps - 1)
	var new_min: float = 0.0
	var new_max: float = 1.0
	var epsilon: float = 0.001

	var log_max: float = log(old_max + epsilon)
	var log_min: float = log(epsilon)

	var log_value: float = log(value + epsilon)
	var normalized_log_value: float = (log_max - log_value) / (log_max - log_min)

	return (normalized_log_value * (new_max - new_min)) + new_min
