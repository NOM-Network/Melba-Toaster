extends Node2D

@export var cubism_model: GDCubismUserModel
@export var audio_player: AudioStreamPlayer

# Effects 
@onready var eye_blink = %EyeBlink
@onready var mouth_movement = %MouthMovement
@onready var breath_effect = %GDCubismEffectBreath

var reading_audio := false
var audio_queue := []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	intialize_toggles()

func connect_signals() -> void:
	Globals.incoming_speech.connect(process_audio)
	Globals.play_animation.connect(play_animation)
	Globals.set_expression.connect(set_expression)
	Globals.set_toggle.connect(set_toggle)
	Globals.cancel_speech.connect(stop_audio)

	cubism_model.motion_finished.connect(_on_gd_cubism_user_model_motion_finished)
	audio_player.finished.connect(_on_audio_stream_player_finished)

func intialize_toggles() -> void:
	var parameters = cubism_model.get_parameters()
	for param in parameters:
		if param.get_id() == "Param9":
			Globals.toggles["toast"]["param"] = param
		if param.get_id() == "Param14":
			Globals.toggles["void"]["param"] = param

func _process(_delta: float) -> void:
	if not reading_audio:
		if audio_queue.size() > 0:
			play_audio(audio_queue[0])
			audio_queue.remove_at(0)

	for toggle in Globals.toggles:
		if Globals.toggles[toggle]["enabled"]:
			Globals.toggles[toggle]["param"].set_value(true)
		else:
			Globals.toggles[toggle]["param"].set_value(false)

func play_animation(anim_name: String) -> void:
	Globals.last_animation = anim_name
	if anim_name == "end":
		reset_overrides()
		cubism_model.stop_motion()
	elif Globals.animations.has(anim_name):
		var anim_id = Globals.animations[anim_name]["id"]
		var override = Globals.animations[anim_name]["override"]
		match override: 
			"eye_blink":
				eye_blink.active = false 
		cubism_model.start_motion("", anim_id, GDCubismUserModel.PRIORITY_FORCE)
			
func set_expression(expression_name: String) -> void:
	Globals.last_expression = expression_name 
	if expression_name == "end":
		cubism_model.stop_expression()
	elif Globals.expressions.has(expression_name):
		var expr_id = Globals.expresions[expression_name]["id"]
		cubism_model.start_expression(expr_id)

func set_toggle(toggle_name: String, enabled: bool) -> void:
	if Globals.toggles.has(toggle_name):
		Globals.toggles[toggle_name]["enabled"] = enabled

func process_audio(message: PackedByteArray) -> void:
	var stream = AudioStreamMP3.new()
	stream.data = message
	queue_audio(stream)

func queue_audio(stream: AudioStreamMP3):
	audio_queue.append(stream)

func play_audio(stream: AudioStreamMP3) -> void:
	reading_audio = true
	audio_player.stream = stream
	audio_player.play()

# TODO: Test if we need to remove this audio from the queue
func stop_audio() -> void:
	audio_player.stop()

func reset_overrides():
	eye_blink.active = true
	mouth_movement.active = true 
	breath_effect.active = true 

# DOESN'T run when motion has been forcibly stoped
func _on_gd_cubism_user_model_motion_finished():
	reset_overrides()
	play_animation("idle")

# DOES in run when audio has been forcibly stoped
func _on_audio_stream_player_finished():
	reading_audio = false
	if Globals.last_animation == "idle": 
		play_animation("idle")
	
