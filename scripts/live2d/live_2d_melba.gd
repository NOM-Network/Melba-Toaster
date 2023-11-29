extends Node2D

@export_category("Cubism Model")
@export var cubism_model: GDCubismUserModel

#region EFFECTS
@onready var eye_blink = %EyeBlink
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
	intialize_toggles()
	initialize_pinnable_assets()

	for child in $PinnableAssets.get_children():
		child.modulate.a = 0

	set_expression("end")
	play_random_idle_animation()


func connect_signals() -> void:
	Globals.play_animation.connect(play_animation)
	Globals.set_expression.connect(set_expression)
	Globals.set_toggle.connect(set_toggle)
	Globals.nudge_model.connect(nudge_model)
	Globals.pin_asset.connect(pin_asset)

	anim_timer.timeout.connect(_on_animation_finished)

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

		var ary_mesh: ArrayMesh = dict_mesh[asset.mesh]
		var ary_surface = ary_mesh.surface_get_arrays(0)

		asset.initial_points.A = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point]
		asset.initial_points.B = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point + asset.second_point]

func _process(_delta: float) -> void:
	for toggle in Globals.toggles.values():
		toggle.param.set_value(toggle.value)

	for asset in assets_to_pin.values():
		pin(asset)

func nudge_model() -> void:
	play_random_idle_animation()

	if tweens.has("nudge"):
		tweens.nudge.kill()

	tweens.nudge = create_tween()
	tweens.nudge.tween_property(cubism_model, "speed_scale", 1.5, 1.0).set_ease(Tween.EASE_IN)
	tweens.nudge.tween_property(cubism_model, "speed_scale", 1, 1.0).set_ease(Tween.EASE_OUT)

func pin_asset(asset_name: String, enabled: bool) -> void:
	var asset = Globals.pinnable_assets[asset_name]
	asset.enabled = enabled

	if enabled:
		assets_to_pin[asset_name] = asset
		tween_pinned_asset(asset.node, false)
	else:
		assets_to_pin.erase(asset_name)
		tween_pinned_asset(asset.node, true)

func tween_pinned_asset(node, opaque: bool) -> void:
	if tweens.has("pin"):
		tweens.pin.kill()

	tweens.pin = create_tween().set_trans(Tween.TRANS_QUINT)
	tweens.pin.tween_property(node, "modulate:a", 0.0 if opaque else 1.0, 0.5)

func pin(asset: PinnableAsset) -> void:
	var base_offset = cubism_model.size * -0.5

	var dict_mesh = cubism_model.get_meshes()
	var ary_mesh: ArrayMesh = dict_mesh[asset.mesh]
	var ary_surface = ary_mesh.surface_get_arrays(0)
	var pos = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point]
	var pos2 = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point + asset.second_point]

	asset.node.position = pos + base_offset + asset.offset
	asset.node.rotation = get_asset_rotation(
		asset.initial_points.A,
		asset.initial_points.B,
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

			anim_timer.wait_time = Globals.animations[anim_name]["duration"]
			anim_timer.start()
			var anim_id = Globals.animations[anim_name]["id"]
			var override = Globals.animations[anim_name]["override"]
			if override == "eye_blink":
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
		play_animation("idle1")
	elif random_int <= 6: # 30% chance, ~43% when idle2 was last_animation
		play_animation("idle2")
	elif random_int <= 10: # 40% chance, ~57% when idle2 was last_animation
		play_animation("idle3")
