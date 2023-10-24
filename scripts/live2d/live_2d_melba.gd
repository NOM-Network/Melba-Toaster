extends MelbaModel

@onready var cubism_model = $"../Live2DMelba/Sprite2D/GDCubismUserModel"
@onready var mouth_movement = $"../Live2DMelba/Sprite2D/GDCubismUserModel/MouthMovement"
@onready var audio_player = $"../AudioStreamPlayer"

var reading_audio = false 

# Animations 
#enum Animations {
#	IDLE
#}
#var current_animation = Animations.IDLE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	cubism_model.motion_finished.connect(_on_gd_cubism_user_model_motion_finished)
	audio_player.finished.connect(_on_audio_stream_player_finished)
	var parameters = cubism_model.get_parameters()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not reading_audio: 
		if audio_queue.size() > 0: 
			play_audio(audio_queue[0])
			audio_queue.remove_at(0)

func toast_toggle(enabled: bool) -> void:
	if enabled:
		cubism_model.start_expression("Bread")
	else: 
		cubism_model.stop_expression()

func void_toggle(enabled: bool) -> void:
	if enabled:
		cubism_model.start_expression("Void")
	else:
		cubism_model.stop_expression()

func remove_toggle(enabled: bool) -> void:
	cubism_model.stop_expression()

func play_audio(stream: AudioStreamWAV) -> void:
	reading_audio = true 
	
	audio_player.stream = stream
	audio_player.play()

func idle_animation() -> void:
	cubism_model.start_motion("Idle", 0, GDCubismUserModel.PRIORITY_FORCE)

func _on_gd_cubism_user_model_motion_finished():
	idle_animation()

func _on_audio_stream_player_finished():
	reading_audio = false  
