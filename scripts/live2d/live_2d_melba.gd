extends Node2D

@export var cubism_model: GDCubismUserModel

# Effects (For override) 
@onready var eye_blink = %EyeBlink

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	intialize_toggles()

func connect_signals() -> void:
	Globals.speech_done.connect(_on_speech_done)
	Globals.play_animation.connect(play_animation)
	Globals.set_expression.connect(set_expression)
	Globals.set_toggle.connect(set_toggle)
	
	cubism_model.motion_finished.connect(_on_gd_cubism_user_model_motion_finished)
	set_expression("end")

func intialize_toggles() -> void:
	# TODO: Tween values not opacities so that everything can fade in / fade out. 
	var parameters = cubism_model.get_parameters()
	for param in parameters:
		for toggle in Globals.toggles.values(): 
			if param.get_id() == toggle["id"]:
				toggle.param = param

func _process(_delta: float) -> void:
	for toggle in Globals.toggles.values():
		toggle.param.set_value(toggle.value)

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
		var expr_id = Globals.expressions[expression_name].id
		cubism_model.start_expression(expr_id)

func set_toggle(toggle_name: String, enabled: bool) -> void:
	if Globals.toggles.has(toggle_name):
		var value_tween = create_tween() 
		var toggle = Globals.toggles[toggle_name]
		if enabled:
			toggle.enabled = true 
		else: 
			toggle.enabled = false
			value_tween.tween_property(toggle, "value", 0.0, toggle.duration)

func reset_overrides():
	eye_blink.active = true

# DOESN'T run when motion has been forcibly stoped
func _on_gd_cubism_user_model_motion_finished():
	reset_overrides()
	play_animation("idle")

# DOES in run when audio has been forcibly stoped
func _on_speech_done():
	pass
