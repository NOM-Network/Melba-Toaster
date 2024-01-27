extends Node2D

@onready var cubism_model := %GDCubismUserModel

#region MODEL EXPORTS

@export_category("Cubism Model")
@export var model_position: Vector2 = Vector2.ZERO:
	get:
		return cubism_model.adjust_position
	set(value):
		if cubism_model:
			cubism_model.adjust_position = value

@export var model_scale: float = 0.15:
	get:
		return cubism_model.adjust_scale
	set(value):
		if cubism_model:
			cubism_model.adjust_scale = value

#endregion

#region EFFECTS FOR OVERRIDE
# re activate these nodes on function reset_overrides
@onready var eye_blink = %EyeBlinking
#endregion

#region OTHER NODES
@onready var anim_timer = $AnimTimer
#endregion

#region ASSETS
var assets_to_pin := {}
#endregion

#region TWEENS
@onready var tweens := {}
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	initialize_animations()
	intialize_toggles()
	initialize_pinnable_assets()
	set_expression("end")
	play_random_idle_animation()

func connect_signals() -> void:
	Globals.play_animation.connect(play_animation)
	Globals.set_expression.connect(set_expression)
	Globals.set_toggle.connect(set_toggle)
	Globals.nudge_model.connect(nudge_model)
	Globals.pin_asset.connect(pin_asset)

	anim_timer.timeout.connect(_on_animation_finished)

func initialize_animations() -> void:
	for anim in Globals.animations.values():
		if anim.override_name != "":
			anim.override = cubism_model.get_node(anim.override_name)

func intialize_toggles() -> void:
	var parameters = cubism_model.get_parameters()
	for param in parameters:
		for toggle in Globals.toggles.values():
			if param.get_id() == toggle["id"]:
				toggle.param = param

func initialize_pinnable_assets() -> void:
	var dict_mesh = cubism_model.get_meshes()

	for asset in Globals.pinnable_assets.values():
		asset.node = $PinnableAssets.find_child(asset.node_name)
		if not asset.node:
			printerr("Cannot found `%s` asset node" % asset.node_name)
			continue

		asset.node.modulate.a = 0

		var ary_mesh: ArrayMesh = dict_mesh[asset.mesh]
		var ary_surface = ary_mesh.surface_get_arrays(0)

		asset.initial_points[0] = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point]
		asset.initial_points[1] = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point + asset.second_point]

func _process(_delta: float) -> void:
	for toggle in Globals.toggles.values():
		toggle.param.set_value(toggle.value)

	for asset in assets_to_pin.keys():
		pin(assets_to_pin[asset])

func nudge_model() -> void:
	play_random_idle_animation()

	if tweens.has("nudge"):
		tweens.nudge.kill()

	tweens.nudge = create_tween()
	tweens.nudge.tween_property(cubism_model, "speed_scale", 1.7, 1.0).set_ease(Tween.EASE_IN)
	tweens.nudge.tween_property(cubism_model, "speed_scale", 1.0, 2.0).set_ease(Tween.EASE_OUT)

func pin_asset(node_name: String, enabled: bool) -> void:
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
		tweens[node_name].tween_callback(func (): assets_to_pin.erase(node_name))

func pin(asset: PinnableAsset) -> void:
	var dict_mesh = cubism_model.get_meshes()
	var ary_mesh: ArrayMesh = dict_mesh[asset.mesh]
	var ary_surface = ary_mesh.surface_get_arrays(0)
	var pos = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point]
	var pos2 = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point + asset.second_point]

	asset.node.position = pos + (model_scale * asset.position_offset)
	asset.node.scale = Vector2(model_scale, model_scale) * asset.scale_offset
	asset.node.rotation = get_asset_rotation(
		asset.initial_points[0],
		asset.initial_points[1],
		pos,
		pos2
	)

func get_asset_rotation(point_a: Vector2, point_b: Vector2, point_a_new: Vector2, point_b_new: Vector2) -> float:
	var delta_p: Vector2 = point_a_new - point_a
	var trans_point_b: Vector2 = delta_p + point_b

	var angle1 = point_a_new.angle_to_point(trans_point_b)
	var angle2 = point_a_new.angle_to_point(point_b_new)
	var delta_angle = angle2 - angle1

	return delta_angle

func reset_overrides():
	eye_blink.active = true

func play_animation(anim_name: String) -> void:
	reset_overrides()

	Globals.last_animation = anim_name
	match anim_name:
		"end":
			cubism_model.stop_motion()

		"random":
			play_random_idle_animation()

		anim_name:
			if not Globals.animations.has(anim_name):
				printerr("Cannot found `%s` animation" % anim_name)
				return

			var anim = Globals.animations[anim_name]

			anim_timer.wait_time = anim["duration"]
			anim_timer.start()
			var anim_id = anim.id
			var override = anim.override

			eye_blink.active = not anim.ignore_blinking

			if override:
				override.active = false
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

func play_emerge_animation() -> void:
	$AnimationPlayer.play("emerge")
	await $AnimationPlayer.animation_finished
	Globals.change_position.emit("default")
