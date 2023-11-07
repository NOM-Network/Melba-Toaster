extends GDCubismEffectCustom
class_name MouthMovementDepricated

@export var live_2d_melba = Node # The node with live2d_melba.gd
@export var audio_bus_name := "Voice"
# Parameter Names
@export_category("Param Names")
@export var param_mouth_name := "ParamMouthOpenY"
@export var param_mouth_form_name := "ParamMouthForm"
@export var param_eye_ball_x_name := "ParamEyeBallX"
@export var param_eye_ball_y_name := "ParamEyeBallY"
# Parameter Values
@export_category("Param Values")
@export var mouth_pos = 0.6
@export var mouth_form_pos = -0.8
@export var eye_x_pos = 0.0
@export var eye_y_pos = 0.0
# Parameters
var param_mouth: GDCubismParameter
var param_mouth_form: GDCubismParameter
var param_eye_ball_x: GDCubismParameter
var param_eye_ball_y: GDCubismParameter
# Tweens
var tween_mouth: Tween
var tween_mouth_form: Tween
var tween_eye_x: Tween
var tween_eye_y: Tween
# State for volume analysis
var blabbering = false
# States for transitioning between reading and not reading audio
var just_started = true
var transition_fin = false
var just_ended = false
# Sound analysis
var previous_volume = 0.0

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
		if param.id == param_eye_ball_x_name:
			param_eye_ball_x = param
		if param.id == param_eye_ball_y_name:
			param_eye_ball_y = param

func _on_cubism_process(_model: GDCubismUserModel, _delta: float):
	manage_transitions() # For start and end of speech transitions
	manage_mouth_movement() # For mouth opening and closing

func manage_transitions() -> void:
	if Globals.is_speaking:
		# Reset states for not reading audio
		just_ended = true

		param_mouth_form.value = mouth_form_pos
		if just_started:
			just_started = false
			tween_eye_x = create_tween()
			tween_eye_y = create_tween()
			tween_eye_x.tween_property(param_eye_ball_x, "value", eye_x_pos, 1.5)
			tween_eye_y.tween_property(param_eye_ball_y, "value", eye_y_pos, 1.5)
			await tween_eye_x.finished
			transition_fin = true
		if transition_fin:
			param_eye_ball_x.value = eye_x_pos
			param_eye_ball_y.value = eye_y_pos

	else:
		# Reset states for reading audio
		transition_fin = false
		just_started = true

		if just_ended:
			just_ended = false
			param_mouth_form.value = mouth_form_pos
			tween_mouth_form = create_tween()
			tween_mouth_form.tween_property(param_mouth_form, "value", 0.0, 2)

func manage_mouth_movement() -> void:
	var audio_bus = AudioServer.get_bus_index(audio_bus_name)
	var volume = (AudioServer.get_bus_peak_volume_left_db(audio_bus, 0) +
	AudioServer.get_bus_peak_volume_right_db(audio_bus, 0)) / 2.0
	# print(volume)
	if volume < -54.0 and previous_volume < -54.0: # If she is not speaking
		blabbering = false
		if Globals.is_speaking:
			param_mouth.value = 0.05
		else:
			param_mouth.value = 0.0
	elif not blabbering: # If she just started speaking
		blabbering = true
		start_tween()
	else: # If she has been speaking
		pass
	previous_volume = volume

func start_tween() -> void:
	if tween_mouth: tween_mouth.kill()
	tween_mouth = create_tween()
	tween_mouth.finished.connect(_on_tween_finished)
	tween_mouth.tween_property(param_mouth, "value", mouth_pos, 0.15)

func _on_tween_finished() -> void:
	if tween_mouth: tween_mouth.kill()
	tween_mouth = create_tween()
	await tween_mouth.tween_property(param_mouth, "value", 0.1, 0.15).finished
	if blabbering:
		start_tween()
	else:
		param_mouth.value = 0.0
