extends MelbaModel

@onready var cubism_model = $"../Live2DMelba/Sprite2D/GDCubismUserModel"
@onready var mouth_movement = $"../Live2DMelba/Sprite2D/GDCubismUserModel/MouthMovement"
@onready var audio_player = $"../AudioStreamPlayer"

# Toggles 
var toast_toggled = true 

# Expressions 
enum Expressions {
	SMILE
}
var current_expression = Expressions.SMILE

# Animations 
enum Animations {
	LOOKING_STRAIGHT, 
	LOOKING_AT_CHAT 
}
var current_animation = Animations.LOOKING_AT_CHAT 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	cubism_model.motion_finished.connect(_on_gd_cubism_user_model_motion_finished)
	audio_player.finished.connect(_on_audio_stream_player_finished)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if current_animation == Animations.LOOKING_AT_CHAT: 
		if audio_queue.size() > 0: 
			play_audio(audio_queue[0])
			audio_queue.remove_at(0)

func look_straight() -> void:
	current_animation = Animations.LOOKING_STRAIGHT
#	cubism_model.start_motion("", 4, GDCubismUserModel.PRIORITY_FORCE)

func look_at_chat() -> void: 
	current_animation = Animations.LOOKING_AT_CHAT 

func toast_toggle() -> void:
	if not toast_toggled:
		toast_toggled = true 
		cubism_model.start_expression("exp_04")
	else:
		toast_toggled = false 
		cubism_model.start_expression("exp_01")

func play_audio(stream: AudioStreamWAV) -> void:
	look_straight()
	
	audio_player.stream = stream
	audio_player.play()

func idle_animation() -> void:
	cubism_model.start_motion("Idle", 0, GDCubismUserModel.PRIORITY_FORCE)

func _on_gd_cubism_user_model_motion_finished():
	idle_animation()

func _on_audio_stream_player_finished():
	look_at_chat()  
