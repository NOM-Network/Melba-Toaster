extends GDCubismEffectCustom
class_name PinnableAssets

const _90_DEG_IN_RAD = deg_to_rad(90.0)

#region ASSETS
@export var assets: Node2D
var meshes: Dictionary
var assets_to_pin: Dictionary
var tweens: Dictionary
#endregion

#region MAIN
func _ready() -> void:
	assets.get_node("Notes").visible = false

	_connect_signals()

func _connect_signals() -> void:
	cubism_init.connect(_on_cubism_init)
	Globals.pin_asset.connect(_on_pin_asset)
	cubism_prologue.connect(_on_cubism_prologue)
#endregion

#region SIGNALS
func _on_cubism_init(model: GDCubismUserModel) -> void:
	meshes = model.get_meshes()

	for asset: PinnableAsset in Globals.pinnable_assets.values():
		asset.node = assets.find_child(asset.node_name)
		if not asset.node:
			printerr("Cannot found `%s` asset node" % asset.node_name)
			continue

		asset.node.modulate.a = 0

		if not meshes.has(asset.mesh):
			printerr("Cannot found `%s` mesh" % asset.mesh)
			continue

		var ary_mesh: ArrayMesh = meshes[asset.mesh]
		var ary_surface: Array = ary_mesh.surface_get_arrays(0)

		asset.initial_points[0] = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point]
		asset.initial_points[1] = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.second_point]

func _on_pin_asset(node_name: String, enabled: bool) -> void:
	if not Globals.pinnable_assets.has(node_name):
		printerr("Cannot found `%s` asset node" % node_name)
		return

	var asset: PinnableAsset = Globals.pinnable_assets[node_name]
	asset.enabled = enabled

	_tween_pinned_asset(asset, enabled)

func _on_cubism_prologue(model: GDCubismUserModel, _delta: float) -> void:
	for asset: String in assets_to_pin.keys():
		_pin(assets_to_pin[asset], model)
#endregion

#region ASSET FUNCTIONS

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

func _pin(asset: PinnableAsset, model: GDCubismUserModel) -> void:
	var ary_mesh: ArrayMesh = meshes[asset.mesh]
	var ary_surface: Array = ary_mesh.surface_get_arrays(0)
	var pos: Vector2 = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.custom_point]
	var pos2: Vector2 = ary_surface[ArrayMesh.ARRAY_VERTEX][asset.second_point]

	asset.node.position = pos + (model.adjust_scale * asset.position_offset)
	asset.node.scale = Vector2(model.adjust_scale, model.adjust_scale) * asset.scale_offset
	asset.node.rotation = _get_asset_rotation(asset.initial_points, [pos, pos2])

func _get_asset_rotation(initial_points: Array[Vector2], pos: Array[Vector2]) -> float:
	var delta_p: Vector2 = pos[0] - initial_points[0]
	var trans_point_b: Vector2 = delta_p + initial_points[1]

	var angle1: float = pos[0].angle_to_point(trans_point_b)
	var angle2: float = pos[0].angle_to_point(pos[1])

	var angle = angle2 - angle1

	if angle > 0:
		return angle - _90_DEG_IN_RAD
	return angle + _90_DEG_IN_RAD
#endregion
