extends Node2D

@export_category("Cubism Model")
@export var cubism_model: GDCubismUserModel

@export_category("Tracking")
@export var x_offset = 0.0
@export var y_offset = 0.0

#region EFFECTS
@onready var eye_blink = %EyeBlink
#endregion

#region OTHER NODES
@onready var anim_timer = $AnimTimer
#endregion 

#region STATE VARIABLES
var item_is_pinned := false 
#endregion

#region TWEENS
var tween: Tween
#endregion 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	intialize_toggles()

	set_expression("end")
	play_random_idle_animation()
	
func connect_signals() -> void:
	Globals.play_animation.connect(play_animation)
	Globals.set_expression.connect(set_expression)
	Globals.set_toggle.connect(set_toggle)
	Globals.nudge_model.connect(nudge_model)
	anim_timer.timeout.connect(_on_animation_finished)
	Globals.pin_item.connect(_on_pin_item)
	Globals.stop_pin_item.connect(_on_stop_pin_item)

func intialize_toggles() -> void:
	var parameters = cubism_model.get_parameters()
	for param in parameters:
		for toggle in Globals.toggles.values():
			if param.get_id() == toggle["id"]:
				toggle.param = param

func _process(_delta: float) -> void:
	for toggle in Globals.toggles.values():
		toggle.param.set_value(toggle.value)
	
	if item_is_pinned: 
		pin_item()

func _on_pin_item() -> void: 
	item_is_pinned = true 
	$AnimatedSprite2D.visible = true 
	$AnimatedSprite2D.play()
	
func _on_stop_pin_item() -> void: 
	item_is_pinned = false 
	$AnimatedSprite2D.visible = false
	$AnimatedSprite2D.stop()

func pin_item() -> void: 
	var dict_mesh = cubism_model.get_meshes()
	var ary_mesh: ArrayMesh = dict_mesh["ArtMesh19"]
	var ary_surface = ary_mesh.surface_get_arrays(0)
	var pos = ary_surface[ArrayMesh.ARRAY_VERTEX][0]
	$AnimatedSprite2D.position = Vector2(pos.x - 950 + x_offset, pos.y - 1000 + y_offset)

func nudge_model() -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(cubism_model, "speed_scale", 2, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(cubism_model, "speed_scale", 1, 1.0).set_ease(Tween.EASE_OUT)

func play_animation(anim_name: String) -> void:
	reset_overrides()
	Globals.last_animation = anim_name
	if anim_name == "end":
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
	if Globals.last_animation != "end":
		play_random_idle_animation()

func play_random_idle_animation() -> void:
	var random_int: int

	if Globals.last_animation == "idle2":
		random_int = randi_range(4, 10)
	else:
		random_int = randi_range(1, 10)

	if random_int <= 3: # 30% chance, 0 % when idle2 was last_animation
		play_animation("idle2")
	elif random_int <= 6: # 30% chance, ~43% when idle2 was last_animation
		play_animation("idle3")
	elif random_int <= 10: # 40% chance, ~57% when idle2 was last_animation
		play_animation("idle1")
