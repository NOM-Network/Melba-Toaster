extends Node2D

@export var cubism_model: GDCubismUserModel

# Effects
@onready var eye_blink = %EyeBlink
@onready var mouth_movement = %MouthMovement
@onready var breath_effect = %GDCubismEffectBreath

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

func intialize_toggles() -> void:
	# TODO: Tween values not opacities so that everything can fade in / fade out. 
	var parameters = cubism_model.get_parameters()
	for param in parameters:
		if param.get_id() == "Param9":
			Globals.toggles["toast"]["param"] = param
		if param.get_id() == "Param14":
			Globals.toggles["void"]["param"] = param
		if param.get_id() == "Param20":
			Globals.toggles["tears"]["param"] = param
	var part_opacities = cubism_model.get_part_opacities()
	for opacity in part_opacities:
		if opacity.get_id() == "Bread":
			Globals.toggles["toast"]["opacity"] = opacity
		if opacity.get_id() == "Tears":
			Globals.toggles["tears"]["opacity"] = opacity

func _process(_delta: float) -> void:
	for toggle in Globals.toggles:
		if Globals.toggles[toggle].has("opacity"):
			Globals.toggles[toggle]["param"].set_value(true)
		else:
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
		var expr_id = Globals.expressions[expression_name].id
		cubism_model.start_expression(expr_id)

func set_toggle(toggle_name: String, enabled: bool) -> void:
	if Globals.toggles.has(toggle_name):
		if Globals.toggles[toggle_name].has("opacity"):
			var opacity_tween = create_tween()
			var toggle_opacity = Globals.toggles[toggle_name]["opacity"]
			if enabled: opacity_tween.tween_property(toggle_opacity, "value", 1.0, 0.5)
			else: opacity_tween.tween_property(toggle_opacity, "value", 0.0, 0.5)
		Globals.toggles[toggle_name]["enabled"] = enabled

func reset_overrides():
	eye_blink.active = true
	mouth_movement.active = true
	breath_effect.active = true

# DOESN'T run when motion has been forcibly stoped
func _on_gd_cubism_user_model_motion_finished():
	reset_overrides()
	play_animation("idle")

# DOES in run when audio has been forcibly stoped
func _on_speech_done():
	if Globals.last_animation == "idle":
		play_animation("idle")

