extends Node2D

@onready var model := %GDCubismUserModel
@onready var sprite := %Sprite2D
@onready var pinnable_assets := %PinnableAssets
@onready var target_point := %TargetPoint
@onready var eye_blink := %EyeBlinking
@onready var anim_timer := $AnimTimer

#region ASSETS
@onready var dict_mesh: Dictionary = model.get_meshes()
var assets_to_pin := {}
#endregion

#region TWEENS
@onready var tweens := {}
#endregion

#region MODEL DATA
@export var model_position: Vector2 = Vector2.ZERO:
	get:
		if model:
			return model.adjust_position + Vector2(model.size) / 2
		else:
			return Vector2( - 200, 580)

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

#region DEBUG
@export var debug_pins := false
var debug_draw: Array
var default_font := ThemeDB.fallback_font
var default_font_size := 26
var default_color := Color.WEB_PURPLE
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	initialize_animations()
	intialize_toggles()
	initialize_pinnable_assets()
	set_expression("end")
	play_random_idle_animation()

	if debug_pins:
		z_index = -1

func connect_signals() -> void:
	Globals.play_animation.connect(play_animation)
	Globals.set_expression.connect(set_expression)
	Globals.set_toggle.connect(set_toggle)
	Globals.nudge_model.connect(nudge_model)
	Globals.pin_asset.connect(pin_asset)
	Globals.change_position.connect(_on_change_position)

	anim_timer.timeout.connect(_on_animation_finished)

func initialize_animations() -> void:
	for anim: Object in Globals.animations.values():
		if anim.override_name != "":
			anim.override = model.get_node(anim.override_name)

func intialize_toggles() -> void:
	var parameters: Array = model.get_parameters()
	for param: GDCubismParameter in parameters:
		for toggle: Object in Globals.toggles.values():
			if param.get_id() == toggle["id"]:
				toggle.param = param

func initialize_pinnable_assets() -> void:
	pinnable_assets.position = model_pivot()

	for asset: PinnableAsset in Globals.pinnable_assets.values():
		asset.node = pinnable_assets.find_child(asset.node_name)
		if not asset.node:
			printerr("Cannot found `%s` asset node" % asset.node_name)
			continue

		asset.node.modulate.a = 0

		var ary_mesh: ArrayMesh = dict_mesh[asset.mesh]
		var ary_surface: Array = ary_mesh.surface_get_arrays(0)

		asset.initial_points[0] = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point]
		asset.initial_points[1] = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.second_point]

func _physics_process(_delta: float) -> void:
	for toggle: Object in Globals.toggles.values():
		toggle.param.set_value(toggle.value)

	for asset: String in assets_to_pin.keys():
		pin(assets_to_pin[asset])

	if debug_pins:
		queue_redraw()
	elif debug_draw:
		# Cleaning the debug draw array
		debug_draw = []
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event as InputEventMouseMotion:
		if event.button_mask&MOUSE_BUTTON_MASK_LEFT != 0:
			mouse_to_position(event.relative)

		if event.button_mask&MOUSE_BUTTON_MASK_RIGHT != 0:
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
						mouse_to_rotation( - Globals.rotation_change)
					else:
						mouse_to_scale( - Globals.scale_change)

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

func pin_asset(node_name: String, enabled: bool) -> void:
	if not Globals.pinnable_assets.has(node_name):
		printerr("Cannot found `%s` asset node" % node_name)
		return

	var asset: PinnableAsset = Globals.pinnable_assets[node_name]
	asset.enabled = enabled

	_tween_pinned_asset(asset, enabled)

func _tween_pinned_asset(asset: PinnableAsset, enabled: bool) -> void:
	var node_name := asset.node_name

	if enabled:
		assets_to_pin[node_name] = asset

	if tweens.has(node_name):
		tweens[node_name].kill()

	tweens[node_name] = create_tween().set_trans(Tween.TRANS_QUINT)
	tweens[node_name].tween_property(asset.node, "modulate:a", 1.0 if enabled else 0.0, 0.5)

	if not enabled:
		await tweens[node_name].finished
		assets_to_pin.erase(node_name)

func pin(asset: PinnableAsset) -> void:
	var ary_mesh: ArrayMesh = dict_mesh[asset.mesh]
	var ary_surface: Array = ary_mesh.surface_get_arrays(0)
	var pos: Vector2 = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point]
	var pos2: Vector2 = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.second_point]

	asset.node.position = pos + (model.adjust_scale * asset.position_offset)
	asset.node.scale = Vector2(model.adjust_scale, model.adjust_scale) * asset.scale_offset
	asset.node.rotation = get_asset_rotation(asset.initial_points, [pos, pos2])

	if Globals.debug_mode:
		debug_draw.append([pos, pos2, asset.mesh])
		debug_draw.append([asset.node.position, asset.node_name])

func _draw() -> void:
	if not debug_pins:
		return

	# Model center
	var pivot: Vector2 = model_pivot()
	draw_circle(pivot, 10, Color.RED)
	draw_string(default_font, pivot, "model_pivot", HORIZONTAL_ALIGNMENT_LEFT, -1, default_font_size, default_color)

	if debug_draw:
		while debug_draw.size() > 0:
			var d: Array = debug_draw.pop_front()

			if d.size() == 3:
				draw_line(d[0], d[1], Color.RED, 10)
				draw_string(default_font, d[1], d[2], HORIZONTAL_ALIGNMENT_LEFT, -1, default_font_size, default_color)
			else:
				draw_circle(d[0], 10, Color.RED)
				draw_string(default_font, d[0], d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, default_font_size, default_color)
			d.pop_front()

func get_asset_rotation(initial_points: Array[Vector2], pos: Array[Vector2]) -> float:
	var delta_p: Vector2 = pos[0] - initial_points[0]
	var trans_point_b: Vector2 = delta_p + initial_points[1]

	var angle1: float = pos[0].angle_to_point(trans_point_b)
	var angle2: float = pos[0].angle_to_point(pos[1])

	return angle2 - angle1

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
		model.start_expression(expr_id)

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

func model_pivot() -> Vector2:
	return Vector2(model.size) / 2.0 + model.adjust_position

func mouse_to_scale(change: float) -> void:
	var new_scale: float = model_scale + change
	if new_scale < 0.01:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var pivot := model_pivot()

	var new_pos := model_position - Vector2(
		- (mouse_pos.x - pivot.x) * change,
		(mouse_pos.y - pivot.y) * change
	) / new_scale

	if tweens.has("scale"):
		tweens.scale.kill()

	tweens.scale = create_tween()
	tweens.scale.set_parallel()
	tweens.scale.tween_property(self, "model_scale", new_scale, 0.05)
	tweens.scale.tween_property(self, "model_position", new_pos, 0.05)

func mouse_to_rotation(change: float) -> void:
	var pivot: Vector2 = model_pivot()
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
	elif rot <= - 360.0:
		rot += 360.0 + change
		sprite.rotation_degrees = rot

func mouse_to_position(change: Vector2) -> void:
	var pivot: Vector2 = model_pivot()
	sprite.offset = -pivot
	sprite.position = pivot
	pinnable_assets.position = -pivot
	model.adjust_position += change

func move_eyes(mouse_position: Vector2) -> void:
	if mouse_position == Vector2.ZERO:
		model_eyes_target = Vector2.ZERO
		return

	var viewport_size := get_viewport_rect().size
	var relative_x: float = (mouse_position.x / viewport_size.x) * 2.0 - 1.0
	var relative_y: float = (mouse_position.y / viewport_size.y) * 2.0 - 1.0
	model_eyes_target = Vector2(relative_x, -relative_y)

	if debug_pins:
		debug_draw.append([mouse_position, "mouse"])

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
			var pivot: Vector2 = model_pivot()

			tweens.trans = create_tween().set_trans(Tween.TRANS_QUINT)
			tweens.trans.set_parallel()
			tweens.trans.tween_property(self, "model_position", pos[0], 1)
			tweens.trans.tween_property(self, "model_scale", pos[1], 1)
			tweens.trans.tween_property(sprite, "rotation", 0, 1)
			tweens.trans.tween_property(sprite, "offset", -pivot, 1)
			tweens.trans.tween_property(sprite, "position", pivot, 1)
			tweens.trans.tween_property(pinnable_assets, "position", -pivot, 1)

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
