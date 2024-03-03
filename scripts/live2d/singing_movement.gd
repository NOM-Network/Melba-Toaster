extends GDCubismEffectCustom
class_name SingingMovement

@onready var sprite_2d = %Sprite2D
@onready var gd_cubism_user_model = %GDCubismUserModel

var bob_interval = 0.5
var motion_range: float = 30.0

# Parameters
var param_angle_x: GDCubismParameter
var param_angle_y: GDCubismParameter
var param_angle_z: GDCubismParameter
var param_body_angle_x: GDCubismParameter
var param_body_angle_y: GDCubismParameter
var param_body_angle_z: GDCubismParameter

# Tweens
var tween: Dictionary
var current_motion: Array

# Timer
@onready var beats_timer := Timer.new()

func _ready():
	self.cubism_init.connect(_on_cubism_init)

	add_child(beats_timer)
	beats_timer.timeout.connect(_on_beats_timer_timeout)

func _on_cubism_init(model: GDCubismUserModel):
	Globals.start_dancing_motion.connect(_start_motion)
	Globals.end_dancing_motion.connect(_end_motion)

	var param_names = [
		"ParamAngleX",
		"ParamAngleY",
		"ParamAngleZ",
		"ParamBodyAngleX",
		"ParamBodyAngleY",
		"ParamBodyAngleZ"
	]

	for param in model.get_parameters():
		if param_names.has(param.id):
			set(param.id.to_snake_case(), param)

func _start_motion(bpm: float) -> void:
	Globals.dancing_bpm = bpm
	bob_interval = motion_range / bpm

	_start_tween()
	_start_timer()

func _end_motion() -> void:
	Globals.dancing_bpm = 0
	Globals.play_animation.emit("end")

	_stop_timer()
	for axis in ["x", "y", "z"]:
		if tween.has(axis) and tween[axis].is_running():
			_stop(axis)

	await get_tree().create_timer(1.0).timeout
	Globals.play_animation.emit("random")

func _start_tween() -> void:
	for axis in _random_motion():
		_dance(axis)

func _wait_time() -> float:
	return ((60.0 / Globals.dancing_bpm) * 8.0) + Globals.get_audio_compensation()

func _start_timer() -> void:
	beats_timer.wait_time = _wait_time()
	beats_timer.start()

func _stop_timer() -> void:
	beats_timer.stop()

func _on_beats_timer_timeout() -> void:
	beats_timer.wait_time = _wait_time()

	if randf() < 0.33:
		var new_motion = _random_motion()
		if current_motion == new_motion:
			return

		current_motion = new_motion
		for axis in ["x", "y", "z"]:
			if axis in new_motion:
				if not tween.has(axis) or not tween[axis].is_running():
					_dance(axis)
			else:
				if tween.has(axis) and tween[axis].is_running():
					_stop(axis)

func _dance(axis: String) -> void:
	var param := "param_angle_" + axis
	var body_param := "param_body_angle_" + axis

	var time_modifier := _time_modifier(axis)
	var motion_modifier := 1.0

	if tween.has(axis):
		tween[axis].kill()

	tween[axis] = create_tween().set_parallel().set_loops()

	# Positive
	tween[axis].tween_property(get(param), "value", -motion_range * motion_modifier, bob_interval * time_modifier)
	tween[axis].tween_property(get(body_param), "value", -motion_range * motion_modifier, bob_interval * time_modifier)

	# Negative
	tween[axis].chain().tween_property(get(param), "value", motion_range * motion_modifier, bob_interval * time_modifier)
	tween[axis].tween_property(get(body_param), "value", motion_range * motion_modifier, bob_interval * time_modifier)

func _stop(axis: String) -> void:
	if tween.has(axis):
		tween[axis].kill()

func _time_modifier(axis: String) -> float:
	var time_modifier := 1.0
	match axis:
		"x":
			time_modifier = 2.0
		"z":
			time_modifier = 4.0
		_:
			time_modifier = 1.0

	return time_modifier

func _random_motion() -> Array:
	if Globals.dancing_bpm <= 100.0:
		return [
			["y", "z"],
			["y", "x"],
			["y"],
		].pick_random()
	else:
		return [
			["x", "y", "z"],
			["x", "y"],
			["y", "z"],
		].pick_random()
