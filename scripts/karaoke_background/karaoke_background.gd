extends Node2D

@onready var spectrum := %Spectrum
@onready var spirals := %Spirals
@onready var analyzer: AudioEffectSpectrumAnalyzerInstance = AudioServer.get_bus_effect_instance(0, 0)

const VU_COUNT = 120
const FREQ_MAX = 11050.0
const MIN_DB = 60
const ANIMATION_SPEED = 0.1
const HEIGHT_SCALE = 12.0
const TOTAL_SKIPS: int = 25

var skip_time := 0.0
var min_values := []
var max_values := []

func _ready() -> void:
	min_values.resize(VU_COUNT)
	min_values.fill(0.0)
	max_values.resize(VU_COUNT)
	max_values.fill(0.0)

func _physics_process(delta: float) -> void:
	if not Globals.is_singing:
		return

	var bob_interval: float = 30.0 / Globals.dancing_bpm

	var prev_hz := 0.0
	var data := []
	for i in range(1, VU_COUNT + 1):
		var hz := i * FREQ_MAX / VU_COUNT
		var f: Vector2 = analyzer.get_magnitude_for_frequency_range(prev_hz, hz)
		var energy: float = clamp((MIN_DB + linear_to_db(f.length())) / MIN_DB, 0.0, 1.0)
		data.append(energy * HEIGHT_SCALE)
		prev_hz = hz
	for i in range(VU_COUNT):
		if data[i] > max_values[i]:
			max_values[i] = data[i]
		else:
			max_values[i] = lerp(max_values[i], data[i], ANIMATION_SPEED)
		if data[i] <= 0.0:
			min_values[i] = lerp(min_values[i], 0.0, ANIMATION_SPEED)

	var fft := []
	for i in range(VU_COUNT):
		fft.append(lerp(min_values[i], max_values[i], ANIMATION_SPEED))

		if i == VU_COUNT - 10:
			skip_time = skip_time * 2 + delta
			if skip_time > bob_interval:
				spirals.get_material().set_shader_parameter("speed", lerp(min_values[i], max_values[i], ANIMATION_SPEED) * 1000)
				skip_time = 0.0
	spectrum.get_material().set_shader_parameter("freq_data", fft)

func set_transparency(value: float) -> void:
	if value < 0.0:
		value = 0.0
	$MainViewport.get_material().set_shader_parameter("opacity", value)

func get_transparency() -> float:
	return $MainViewport.get_material().get_shader_parameter("opacity")
