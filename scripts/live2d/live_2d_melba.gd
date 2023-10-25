extends Node2D

@onready var controller: ModelController = get_parent()
@onready var cubism_model = %GDCubismUserModel
@onready var audio_player = $AudioStreamPlayer

var reading_audio = false
var audio_queue := []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	intialize_toggles()

func connect_signals() -> void:
	controller.play_animation.connect(play_animation)
	controller.set_expression.connect(set_expression)
	controller.set_toggle.connect(set_toggle)
	controller.queue_audio.connect(queue_audio)
	cubism_model.motion_finished.connect(_on_gd_cubism_user_model_motion_finished)
	audio_player.finished.connect(_on_audio_stream_player_finished)

func intialize_toggles() -> void: 
	var parameters = cubism_model.get_parameters()
	for param in parameters:
		if param.get_id() == "Param9": 
			Globals.toggles["toast"]["param"] = param
		if param.get_id() == "Param14":
			Globals.toggles["void"]["param"] = param

# Called every frame. 'delta' is the elapsed time since the previous frame.
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
	if Globals.animations.has(anim_name):
		var anim_id = Globals.animations[anim_name]["id"]
		cubism_model.start_motion(anim_id, 0, GDCubismUserModel.PRIORITY_FORCE)

func set_expression(expression_name: String, enabled: bool) -> void:
	if Globals.expressions.has(expression_name):
		var expr_id = Globals.expresions[expression_name]["id"]
		if enabled:
			Globals.expressions[expression_name]["enabled"] = true 
			cubism_model.start_expression(expr_id)
		else:
			Globals.expressions[expression_name]["enabled"] = false
			cubism_model.stop_expression()

func set_toggle(toggle_name: String, enabled: bool) -> void:
	if Globals.toggles.has(toggle_name):
		Globals.toggles[toggle_name]["enabled"] = enabled

func queue_audio(stream: AudioStreamMP3):
	audio_queue.append(stream)

func play_audio(stream: AudioStreamMP3) -> void:
	reading_audio = true

	audio_player.stream = stream
	audio_player.play()

func idle_animation() -> void:
#	cubism_model.start_motion("Idle", 0, GDCubismUserModel.PRIORITY_FORCE)
	pass

func _on_gd_cubism_user_model_motion_finished():
	idle_animation()

func _on_audio_stream_player_finished():
	reading_audio = false
