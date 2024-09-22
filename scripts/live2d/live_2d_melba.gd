extends Node2D

@onready var sprite: Sprite2D = %ModelSprite
@onready var model: GDCubismUserModel = %Model
@onready var target_point: GDCubismEffectTargetPoint = %TargetPoint
@onready var eye_blink: Node = %EyeBlinking
@onready var anim_timer: Timer = $AnimTimer

#region TWEENS
@onready var tweens := {}
#endregion

#region MODEL DATA
@export var model_position: Vector2 = Vector2.ZERO:
	get:
		if model:
			return model.adjust_position + Vector2(model.size) / 2
		else:
			return Vector2(-200, 580)

	set(value):
		if model:
			model.adjust_position = value - Vector2(model.size) / 2

@export var model_scale: float = 1.0:
	get:
		return model.adjust_scale if model else 1.0

	set(value):
		if model:
			model.adjust_scale = value

@export var model_eyes_target: Vector2 = Vector2.ZERO:
	get:
		return target_point.get_target() if target_point else Vector2.ZERO

	set(value):
		if target_point:
			target_point.set_target(value)
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	initialize_animations()
	intialize_toggles()
	set_expression("end")
	play_random_idle_animation()

func connect_signals() -> void:
	Globals.play_animation.connect(play_animation)
	Globals.set_expression.connect(set_expression)
	Globals.set_toggle.connect(set_toggle)
	Globals.nudge_model.connect(nudge_model)
	Globals.change_position.connect(_on_change_position)

	anim_timer.timeout.connect(_on_animation_finished)

func initialize_animations() -> void:
	model.playback_process_mode = GDCubismUserModel.IDLE

	for anim: Object in Globals.animations.values():
		if anim.override_name != "":
			anim.override = model.get_node(anim.override_name)

func intialize_toggles() -> void:
	var parameters: Array = model.get_parameters()
	for param: GDCubismParameter in parameters:
		for toggle: Object in Globals.toggles.values():
			if param.get_id() == toggle["id"]:
				toggle.param = param

func _physics_process(_delta: float) -> void:
	for toggle: Object in Globals.toggles.values():
		if not toggle.param:
			printerr("Cannot found `%s` parameter" % toggle["id"])
			continue

		toggle.param.set_value(toggle.value)

func _input(event: InputEvent) -> void:
	if event as InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
			mouse_to_position(event.relative)

		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT != 0:
			move_eyes(event.position)

	if event as InputEventMouseButton:
		if event.is_pressed():
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					if event.shift_pressed:
						print_model_data()

				MOUSE_BUTTON_WHEEL_UP:
					if event.ctrl_pressed:
						mouse_to_rotation(Globals.rotation_change)
					else:
						mouse_to_scale(Globals.scale_change)

				MOUSE_BUTTON_WHEEL_DOWN:
					if event.ctrl_pressed:
						mouse_to_rotation(-Globals.rotation_change)
					else:
						mouse_to_scale(-Globals.scale_change)

				MOUSE_BUTTON_MIDDLE:
					Globals.change_position.emit(Globals.last_position)
		else:
			match event.button_index:
				MOUSE_BUTTON_RIGHT:
					move_eyes(Vector2.ZERO)

func nudge_model() -> void:
	play_random_idle_animation()

	if tweens.has("nudge"):
		tweens.nudge.kill()

	tweens.nudge = create_tween()
	tweens.nudge.tween_property(model, "speed_scale", 1.7, 1.0).set_ease(Tween.EASE_IN)
	tweens.nudge.tween_property(model, "speed_scale", 1.0, 2.0).set_ease(Tween.EASE_OUT)

func reset_overrides() -> void:
	eye_blink.active = true

func play_animation(anim_name: String) -> void:
	reset_overrides()

	Globals.last_animation = anim_name
	match anim_name:
		"end":
			model.stop_motion()

		"random":
			play_random_idle_animation()

		anim_name:
			if not Globals.animations.has(anim_name):
				printerr("Cannot found `%s` animation" % anim_name)
				return

			var anim: Object = Globals.animations[anim_name]

			anim_timer.wait_time = anim["duration"]
			anim_timer.start()
			var anim_id: int = anim.id
			var override: Node = anim.override

			eye_blink.active = not anim.ignore_blinking

			if override:
				override.active = false
			model.start_motion("", anim_id, GDCubismUserModel.PRIORITY_FORCE)

func set_expression(expression_name: String) -> void:
	Globals.last_expression = expression_name
	if expression_name == "end":
		model.stop_expression()
	elif Globals.expressions.has(expression_name):
		var expr_id: int = Globals.expressions[expression_name].id
		model.start_expression("%s" % expr_id)

func set_toggle(toggle_name: String, enabled: bool) -> void:
	if Globals.toggles.has(toggle_name):
		var value_tween: Tween = create_tween()
		var toggle: Toggle = Globals.toggles[toggle_name]

		if enabled:
			toggle.enabled = true
			value_tween.tween_property(toggle, "value", 1.0, toggle.duration)
		else:
			toggle.enabled = false
			value_tween.tween_property(toggle, "value", 0.0, toggle.duration)

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
		play_animation("idle1")
	elif random_int <= 10: # 40% chance, ~57% when idle2 was last_animation
		play_animation("idle3")

func get_model_pivot() -> Vector2:
	return Vector2(model.size) / 2.0 + model.adjust_position

func mouse_to_scale(change: float) -> void:
	var new_scale: float = model_scale + change
	if new_scale < 0.01:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var pivot := get_model_pivot()

	var new_pos := model_position - Vector2(-(mouse_pos.x - pivot.x) * change, (mouse_pos.y - pivot.y) * change) / new_scale

	if tweens.has("scale"):
		tweens.scale.kill()

	tweens.scale = create_tween()
	tweens.scale.set_parallel()
	tweens.scale.tween_property(self, "model_scale", new_scale, 0.05)
	tweens.scale.tween_property(self, "model_position", new_pos, 0.05)

func mouse_to_rotation(change: float) -> void:
	var pivot: Vector2 = get_model_pivot()
	sprite.offset = -pivot
	sprite.position = pivot

	var rot: float = sprite.rotation_degrees + change

	if tweens.has("rotation"):
		tweens.rotation.kill()

	tweens.rotation = create_tween()
	tweens.rotation.tween_property(sprite, "rotation_degrees", rot, 0.1)
	await tweens.rotation.finished

	if rot >= 360.0:
		rot -= 360.0
		sprite.rotation_degrees = rot
	elif rot <= -360.0:
		rot += 360.0 + change
		sprite.rotation_degrees = rot

func mouse_to_position(change: Vector2) -> void:
	var pivot: Vector2 = get_model_pivot()
	sprite.offset = -pivot
	sprite.position = pivot
	model.adjust_position += change

func move_eyes(mouse_position: Vector2) -> void:
	if mouse_position == Vector2.ZERO:
		model_eyes_target = Vector2.ZERO
		return

	var viewport_size := get_viewport_rect().size
	var relative_x: float = (mouse_position.x / viewport_size.x) * 2.0 - 1.0
	var relative_y: float = (mouse_position.y / viewport_size.y) * 2.0 - 1.0
	model_eyes_target = Vector2(relative_x, -relative_y)

func _on_change_position(new_position: String) -> void:
	new_position = new_position.to_snake_case()

	if not Globals.positions.has(new_position):
		return

	var positions: Dictionary = Globals.positions[new_position]
	match new_position:
		"intro":
			_play_emerge_animation()

		_:
			if tweens.has("trans"):
				tweens.trans.kill()

			var pos: Array = positions.model
			var pivot: Vector2 = get_model_pivot()

			tweens.trans = create_tween().set_trans(Tween.TRANS_QUINT)
			tweens.trans.set_parallel()
			tweens.trans.tween_property(self, "model_position", pos[0], 1)
			tweens.trans.tween_property(self, "model_scale", pos[1], 1)
			tweens.trans.tween_property(sprite, "rotation", 0, 1)
			tweens.trans.tween_property(sprite, "offset", -pivot, 1)
			tweens.trans.tween_property(sprite, "position", pivot, 1)

func _play_emerge_animation() -> void:
	$AnimationPlayer.play("emerge")
	await $AnimationPlayer.animation_finished
	Globals.change_position.emit("default")
	Globals.is_paused = false
	Globals.ready_for_speech.emit()

func print_model_data() -> void:
	print("Model data: %s, %.2f" % [
		model.adjust_position + Vector2(model.size) / 2,
		model.adjust_scale
	])
