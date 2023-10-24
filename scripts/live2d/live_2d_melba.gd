extends Node2D

@onready var server: ModelController = get_parent()
@onready var cubism_model = $"../Live2DMelba/Sprite2D/GDCubismUserModel"
@onready var mouth_movement = $"../Live2DMelba/Sprite2D/GDCubismUserModel/MouthMovement"
@onready var audio_player = $"../AudioStreamPlayer"

var reading_audio = false
var audio_queue := []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()

	audio_player.play()

func connect_signals() -> void:
	server.play_animation.connect(play_animation)
	server.set_expression.connect(set_expression)
	server.queue_audio.connect(queue_audio)
	cubism_model.motion_finished.connect(_on_gd_cubism_user_model_motion_finished)
	audio_player.finished.connect(_on_audio_stream_player_finished)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not reading_audio:
		if audio_queue.size() > 0:
			play_audio(audio_queue[0])
			audio_queue.remove_at(0)

func play_animation(animation_name: String) -> void:
	match animation_name:
		"sameAnimation": pass

func set_expression(expression_name: String, enabled: bool) -> void:
	match expression_name:
		"toastToggle": toast_toggle(enabled)
		"voidToggle": void_toggle(enabled)
		"removeToggle": remove_toggle(enabled)

# Expression
func toast_toggle(enabled: bool) -> void:
	if enabled:
		cubism_model.start_expression("Bread")
	else:
		cubism_model.stop_expression()

# Expression
func void_toggle(enabled: bool) -> void:
	if enabled:
		cubism_model.start_expression("Void")
	else:
		cubism_model.stop_expression()

# Expression
func remove_toggle(_enabled: bool) -> void:
	cubism_model.stop_expression()

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
