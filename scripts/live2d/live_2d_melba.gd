extends Node2D

@onready var cubism_model = $Sprite2D/GDCubismUserModel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    act()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass

func act() -> void: 
    cubism_model.anim_motion = 5
    
