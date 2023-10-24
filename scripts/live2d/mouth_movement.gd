# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2023 MizunagiKB <mizukb@live.jp>
extends GDCubismEffectCustom


@export var param_mouth_name: String = "ParamMouthOpenY"
@export var param_mouth_form_name: String = "ParamMouthForm"

var param_mouth: GDCubismParameter
var param_mouth_form: GDCubismParameter
var tween: Tween
var blabbering = false

func _ready():
	self.cubism_init.connect(_on_cubism_init)
	self.cubism_process.connect(_on_cubism_process)
	self.cubism_term.connect(_on_cubism_term)

func _on_cubism_init(model: GDCubismUserModel):
	param_mouth = null
	var ary_param = model.get_parameters()

	for param in ary_param:
#		print(param.id)
		if param.id == param_mouth_name:
			param_mouth = param
		if param.id == param_mouth_form_name:
			param_mouth_form = param

	param_mouth_form.value = 1.0
	# print(param_mouth_form.value)

func _on_cubism_term(_model: GDCubismUserModel):
	param_mouth = null
	param_mouth_form = null

func _on_cubism_process(_model: GDCubismUserModel, _delta: float):
	if param_mouth != null:
		var volume = (AudioServer.get_bus_peak_volume_left_db(0,0) + AudioServer.get_bus_peak_volume_right_db(0,0)) / 2.0
		if volume < -60.0: # If she is not speaking
			blabbering = false
		elif not blabbering: # If she just started speaking
			blabbering = true
			start_tween()
		else: # If she has been speaking
			pass

func start_tween() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.finished.connect(_on_tween_finished)
	tween.tween_property(param_mouth, "value", 0.5, 0.15)

func _on_tween_finished() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	await tween.tween_property(param_mouth, "value", 0.0, 0.15).finished
	if blabbering:
		start_tween()
	else:
		param_mouth.value = 0.0
