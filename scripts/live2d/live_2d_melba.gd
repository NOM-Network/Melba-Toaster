extends Node2D

@onready var controller: ModelController = get_parent()
@onready var cubism_model = %GDCubismUserModel
@onready var audio_player = $AudioStreamPlayer

var reading_audio = false
var audio_queue := []

# Pretty sure there is a more readable way to do this but this works for now.
var toggles := {
	"toast": {"param": null, "status": false},
	"void": {"param": null, "status": false}
}

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
			toggles["toast"]["param"] = param
		if param.get_id() == "Param14":
			toggles["void"]["param"] = param

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not reading_audio:
		if audio_queue.size() > 0:
			play_audio(audio_queue[0])
			audio_queue.remove_at(0)
			
	for toggle in toggles: 
		if toggles[toggle]["status"]:
			toggles[toggle]["param"].set_value(true)
		else:
			toggles[toggle]["param"].set_value(false)
	
func play_animation(animation_name: String) -> void:
	match animation_name:
		"sampleAnimation": pass

func set_expression(expression_name: String, enabled: bool) -> void:
	match expression_name:
		"stopExpression": stop_expression() 

func stop_expression(): 
	cubism_model.stop_expression()

func set_toggle(toggle_name: String, enabled: bool) -> void:
	if toggles.has(toggle_name):
		toggles[toggle_name]["status"] = true

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
