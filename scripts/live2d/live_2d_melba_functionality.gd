extends MelbaModel

@onready var cubism_model = $"../Live2DMelba/Sprite2D/GDCubismUserModel"

var toast_toggled = true 

enum Expressions {
	TOAST,
	NO_TOAST
}

var current_expression = Expressions.NO_TOAST

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	cubism_model.motion_finished.connect(_on_gd_cubism_user_model_motion_finished)

# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(_delta: float) -> void:
# 	pass

func look_at_chat() -> void:
	cubism_model.start_motion("", 4, GDCubismUserModel.PRIORITY_FORCE)

func toast_toggle() -> void:
	if not toast_toggled:
		toast_toggled = true 
		cubism_model.start_expression("exp_04")
	else:
		toast_toggled = false 
		cubism_model.start_expression("exp_01")

func idle_animation() -> void:
	cubism_model.start_motion("Idle", 0, GDCubismUserModel.PRIORITY_FORCE)

func _on_gd_cubism_user_model_motion_finished():
	idle_animation()
