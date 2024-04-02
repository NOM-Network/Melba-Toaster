extends GDCubismEffectCustom
class_name SingingMovement

@onready var sprite_2d: Sprite2D = %Sprite2D
@onready var gd_cubism_user_model: GDCubismUserModel = %GDCubismUserModel

var bob_interval: float = 0.5
var motion_range: float = 30.0

# Parameters
## Head
var param_angle_x: GDCubismParameter
var param_angle_y: GDCubismParameter
var param_angle_z: GDCubismParameter
## Body
var param_body_angle_x: GDCubismParameter
var param_body_angle_y: GDCubismParameter
var param_body_angle_z: GDCubismParameter

# Tweens
var tween: Dictionary
var current_motion: Array

# Timer
@onready var beats_timer := Timer.new()

func _ready() -> void:
	self.cubism_init.connect(_on_cubism_init)

	add_child(beats_timer)
	beats_timer.timeout.connect(_on_beats_timer_timeout)

func _on_cubism_init(model: GDCubismUserModel) -> void:
	Globals.start_dancing_motion.connect(_start_motion)
	Globals.end_dancing_motion.connect(_end_motion)

	var param_names: Array = [
		"ParamAngleX",
		"ParamAngleY",
		"ParamAngleZ",
		"ParamBodyAngleX",
		"ParamBodyAngleY",
		"ParamBodyAngleZ"
	]

	for param: GDCubismParameter in model.get_parameters():
		if param_names.has(param.id):
			set(param.id.to_snake_case(), param)

func _start_motion(p_bpm: String) -> void:
	var bpm: float = p_bpm as float
	Globals.dancing_bpm = bpm
	var old_bob_interval: float = bob_interval
	bob_interval = motion_range / bpm

	if old_bob_interval != bob_interval:
		_stop_motion()

	_start_tween()
	_start_timer()

func _end_motion() -> void:
	Globals.dancing_bpm = 0
	Globals.play_animation.emit("idle2")

	_stop_motion()

func _stop_motion() -> void:
	_stop_timer()
	for axis: String in ["x", "y", "z"]:
		_stop(axis)

func _start_tween() -> void:
	current_motion = _random_motion()

	for axis: String in ["x", "y", "z"]:
		_dance(axis) if axis in current_motion else _stop(axis)

func _wait_time() -> float:
	return ((60.0 / Globals.dancing_bpm) * 8.0) + Globals.get_audio_compensation()

func _start_timer() -> void:
	beats_timer.wait_time = _wait_time()
	beats_timer.start()

func _stop_timer() -> void:
	beats_timer.stop()

func _on_beats_timer_timeout() -> void:
	beats_timer.wait_time = _wait_time()

	var chance := 1.0 if Globals.debug_mode else randf_range(0.0, 1.0)
	if randf() < chance:
		current_motion = _random_motion()

	if Globals.debug_mode: print("---\n", current_motion)
	for axis: String in ["x", "y", "z"]:
		_dance(axis) if axis in current_motion else _stop(axis)

func _dance(axis: String, new_tween:=false) -> void:
	if tween.has(axis):
		if not new_tween and tween[axis].is_running():
			if Globals.debug_mode: print("Skipping: ", axis)
			return

		if Globals.debug_mode: print("Running:  ", axis)
		tween[axis].kill()

	var param := "param_angle_" + axis
	var body_param := "param_body_angle_" + axis

	var time: float = bob_interval * _time_modifier(axis)
	tween[axis] = create_tween().set_ease(Tween.EASE_IN_OUT).set_parallel().set_loops()

	var random_swing := 1 if randi_range(0, 1) else - 1
	if Globals.debug_mode: print(axis, ": swing ", random_swing)

	# Swing back
	tween[axis].tween_property(get(param), "value", motion_range * random_swing, time)
	tween[axis].tween_property(get(body_param), "value", motion_range, time)

	# Swing forth
	tween[axis].chain().tween_property(get(param), "value", -motion_range * random_swing, time)
	tween[axis].tween_property(get(body_param), "value", -motion_range, time)

func _stop(axis: String) -> void:
	if tween.has(axis):
		if Globals.debug_mode: print("Stopping: ", axis)
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
