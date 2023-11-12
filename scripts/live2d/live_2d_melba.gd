extends Node2D

@export var cubism_model: GDCubismUserModel

# reagion Effects

@onready var eye_blink = %EyeBlink

# endregion

@onready var anim_timer = $AnimTimer

var tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	intialize_toggles()

func connect_signals() -> void:
	Globals.speech_done.connect(_on_speech_done)
	Globals.play_animation.connect(play_animation)
	Globals.set_expression.connect(set_expression)
	Globals.set_toggle.connect(set_toggle)
	Globals.nudge_model.connect(nudge_model)

	anim_timer.timeout.connect(_on_animation_finished)
	set_expression("end")
	play_animation("idle")

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

func nudge_model() -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(cubism_model, "speed_scale", 2, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(cubism_model, "speed_scale", 1, 1.0).set_ease(Tween.EASE_OUT)

func play_animation(anim_name: String) -> void:
	Globals.last_animation = anim_name
	if anim_name == "end":
		reset_overrides()
		cubism_model.stop_motion()
	elif Globals.animations.has(anim_name):
		anim_timer.wait_time = Globals.animations[anim_name]["duration"]
		anim_timer.start()
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
			value_tween.tween_property(toggle, "value", 1.0, toggle.duration)
		else:
			toggle.enabled = false
			value_tween.tween_property(toggle, "value", 0.0, toggle.duration)

func reset_overrides():
	eye_blink.active = true

func _on_animation_finished() -> void:
	reset_overrides()
	if Globals.last_animation != "end":
		play_animation("idle")

func _on_speech_done() -> void:
	pass
