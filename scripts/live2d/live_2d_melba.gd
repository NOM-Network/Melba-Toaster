extends Node2D

@onready var cubism_model = $Sprite2D/GDCubismUserModel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cubism_model.motion_finished.connect(_on_gd_cubism_user_model_motion_finished)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func test() -> void: 
	cubism_model.start_motion("", 4, GDCubismUserModel.PRIORITY_FORCE)
	print(cubism_model.get_motions())
	
func _on_gd_cubism_user_model_motion_finished():
		cubism_model.start_motion("Idle", 0, GDCubismUserModel.PRIORITY_FORCE)
