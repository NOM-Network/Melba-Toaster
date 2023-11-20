extends Window
@onready var main: Node2D = get_parent()

@export_category("General")
@export var obs: ObsWebSocketClient

@export_category("UI")
@export var current_prompt: Label
@export var current_speech: Label
@export var debug_button: Button
@export var cancel_button: Button
@export var pause_button: Button

@export_category("Timers")
@export var godot_stats_timer: Timer
@export var obs_stats_timer: Timer

var OpCodes := obs.OpCodeEnums.WebSocketOpCode

var anim_menu: Array
var expr_menu: Array

var is_streaming := false

# region MAIN

func _ready() -> void:
	godot_stats_timer.start()

	# Defaults
	debug_button.button_pressed = Globals.debug_mode
	pause_button.button_pressed = Globals.is_paused

	generate_position_controls()
	generate_model_controls()
	generate_singing_controls()

	connect_signals()
	obs_connection()

func obs_connection() -> void:
	# OBS Connection
	obs.establish_connection()
	await obs.connection_authenticated
	obs.data_received.connect(_on_data_received)
	CpHelpers.change_status_color(%ObsClientStatus, true)

	# OBS Data init
	obs.send_command_batch([
		"GetSceneList",
		"GetInputList",
		"GetStats"
	])

	# OBS Stats timers
	obs_stats_timer.start()

func connect_signals() -> void:
	Globals.set_toggle.connect(update_toggle_controls)
	Globals.new_speech.connect(_on_new_speech)

	Globals.start_singing.connect(_on_start_singing)
	Globals.stop_singing.connect(_on_stop_singing)

	Globals.change_position.connect(_on_change_position)
	Globals.change_scene.connect(_on_change_scene)

	print_debug("Control Panel: connected signals")

func generate_position_controls() -> void:
	var positions := %Positions
	for n in positions.get_children():
		if n.get_class() == "Button":
			n.queue_free()

	var button_group = ButtonGroup.new()
	button_group.pressed.connect(_on_position_button_pressed)

	for p in Globals.positions:
		var button = Button.new()
		button.text = p
		button.toggle_mode = true
		button.button_pressed = p == "intro_start"
		button.name = "Position" + p.to_pascal_case()
		button.button_group = button_group
		positions.add_child(button)

	var menu := %NextPositionMenu
	positions.move_child(menu, -1)

	menu.add_item("NO OVERRIDE")
	for p in Globals.positions:
		menu.add_item(p)

	Globals.change_position.emit("intro_start")

func _on_position_button_pressed(button: BaseButton) -> void:
	Globals.change_position.emit(button.text)

func generate_singing_controls():
	var menu := %SingingMenu
	menu.clear()

	var songs = Globals.config.songs
	for song in songs:
		menu.add_item(song.id)

func generate_model_controls():
	for type in ["animations", "expressions", "toggles"]:
		var parent = get_node("%%%s" % type.capitalize())
		for n in parent.get_children():
			n.queue_free()

		var callable
		if type == "toggles":
			callable = _on_toggle_pressed

		CpHelpers.construct_model_control_buttons(
			type,
			parent,
			Globals[type],
			callable
		)

# endregion

# region INCOMING DATA

func _on_data_received(data):
	match data.op:
		OpCodes.Event.IDENTIFIER_VALUE:
			_handle_event(data.d)

		OpCodes.RequestResponse.IDENTIFIER_VALUE:
			_handle_request(data.d)

		OpCodes.RequestBatchResponse.IDENTIFIER_VALUE:
			for i in data.d.results:
				_handle_request(i)

		_:
			print_debug("Unhandled op: ", data.op)
			print_debug(data)
			print_debug("-------------")

func _handle_event(data):
	match data.eventType:
		"CurrentProgramSceneChanged", "SceneListChanged":
			obs.send_command("GetSceneList")

		"InputMuteStateChanged":
			change_input_state(data.eventData)

		"InputNameChanged":
			change_input_name(data.eventData)

		"StreamStateChanged":
			if is_streaming != data.eventData.outputActive:
				is_streaming = data.eventData.outputActive
				update_stream_control_button()

		"ExitStarted":
			stop_processing()

		# Ignored callbacks
		"SceneNameChanged":
			pass # handled by SceneListChanged

		"SceneTransitionStarted", "SceneTransitionVideoEnded", "SceneTransitionEnded":
			pass # We don't need it

		_:
			pass
			# print_debug("Unhandled event: ", data.eventType)
			# print_debug(data)
			# print_debug("-------------")

func _handle_request(data):
	if not data.requestStatus.result:
		if data.requestStatus.code != 604:
			print_debug("Error in request: ", data)
			return
		return

	match data.requestType:
		"GetStats":
			insert_data(%StreamStats, Templates.format_obs_stats(data.responseData))

		"GetStreamStatus":
			var status = data.responseData
			# insert_data(status, %StreamStatus, "")
			if is_streaming != status.outputActive:
				is_streaming = status.outputActive
				update_stream_control_button()

		"GetSceneList":
			generate_scene_buttons(data.responseData)

		"GetInputList":
			generate_input_request(data.responseData.inputs)

		"GetInputMute":
			var inputData := {
				"inputName": data.requestId,
				"inputMuted": data.responseData.inputMuted
			}
			generate_input_button(inputData)

		# Ignored callbacks
		"ToggleInputMute":
			pass # handled by InputMuteStateChanged event

		"SetCurrentProgramScene", "ToggleStream":
			pass # handled by StreamChateChanged event

		_:
			print("Unhandled request: ", data.requestType)
			print(data)
			print("-------------")

# endregion

# region TIMERS

func _on_obs_stats_timer_timeout():
	obs.send_command("GetStats")

func _on_godot_stats_timer_timeout():
	insert_data(%GodotStats, Templates.format_godot_stats())

# endregion

# region UI FUNCTIONS

func _on_start_singing(_song: Dictionary):
	_on_pause_speech_toggled(true, false) # TODO: Use emit events

func _on_stop_singing():
	%SingingToggle.button_pressed = false
	_on_singing_toggle_toggled(false, false)

func _on_singing_toggle_toggled(button_pressed: bool, emit = true):
	if button_pressed:
		var song: Dictionary = Globals.config.songs[%SingingMenu.selected]
		if emit: Globals.start_singing.emit(song)
	else:
		if emit: Globals.stop_singing.emit()

	CpHelpers.change_toggle_state(
		%SingingToggle,
		button_pressed,
		">>> STOP <<<",
		"Start"
	)

func _on_dancing_toggle_toggled(button_pressed: bool):
	if button_pressed:
		Globals.start_dancing_motion.emit(%DancingBpm.value as float)
	else:
		Globals.end_dancing_motion.emit()

	CpHelpers.change_toggle_state(
		%DancingToggle,
		button_pressed,
		">> Stop <<",
		"Start"
	)

func _on_toggle_pressed(toggle: CheckButton):
	Globals.set_toggle.emit(toggle.text, toggle.button_pressed)

func _on_new_speech(prompt, text) -> void:
	current_speech.remove_theme_color_override("font_color")
	current_prompt.text = prompt
	current_speech.text = text.response

func update_toggle_controls(toggle_name: String, enabled: bool):
	var ui_name := "Toggles%s" % [toggle_name.to_pascal_case()]
	var toggle: CheckButton = %Toggles.get_node(ui_name)
	if toggle:
		toggle.button_pressed = enabled

func update_stream_control_button():
	CpHelpers.change_toggle_state(
		%ObsStreamControl,
		is_streaming,
		"Stop Stream",
		"Start Stream"
	)

func _on_obs_stream_control_pressed():
	obs.send_command("ToggleStream")

func _on_change_scene(scene_name: String) -> void:
	obs.send_command("SetCurrentProgramScene", { "sceneName": scene_name })

	var next_position: String
	var selected_override: int = %NextPositionMenu.selected - 1
	if selected_override != -1:
		next_position = Globals.positions.keys()[selected_override]

	if not next_position:
		match scene_name:
			"Main", "Song":
				next_position = "default"

			"Debut":
				next_position = "gaming"

	%NextPositionMenu.selected = 0
	if next_position:
		Globals.change_position.emit(next_position)

func _on_scene_button_pressed(button):
	Globals.change_scene.emit(button.text)

func _on_change_position(new_position: String) -> void:
	var buttons := %Positions

	for b in buttons.get_children():
		if b.text == new_position:
			b.button_pressed = true
			return

func generate_scene_buttons(data):
	var active_scene = null
	if data.has("currentProgramSceneName"):
		active_scene = data.currentProgramSceneName
	var scenes = data.scenes
	scenes.reverse()

	for n in %ObsScenes.get_children():
		n.queue_free()

	for scene in scenes:
		var button = Button.new()
		button.text = scene.sceneName
		CpHelpers.apply_color_override(button, scene.sceneName == active_scene, Color.GREEN)
		button.pressed.connect(_on_scene_button_pressed.bind(button))
		%ObsScenes.add_child(button)

func generate_input_request(inputs):
	for n in %ObsInputs.get_children():
		n.queue_free()

	var request = []
	for i in inputs:
		request.push_back(["GetInputMute", { "inputName": i.inputName }, i.inputName])

	obs.send_command_batch(request)

func generate_input_button(input):
	var button = Button.new()
	button.visible = false
	button.name = input.inputName.to_pascal_case()
	button.text = input.inputName
	button.pressed.connect(_on_input_button_pressed.bind(button))
	%ObsInputs.add_child(button)
	change_input_state(input)

func change_input_name(data):
	var button = %ObsInputs.get_node(data.oldInputName.to_pascal_case())
	if button:
		button.name = data.inputName.to_pascal_case()
		button.text = data.inputName

func change_input_state(data):
	var button = %ObsInputs.get_node(data.inputName.to_pascal_case())

	if button:
		button.visible = true
		CpHelpers.apply_color_override(button, data.inputMuted, Color.RED, Color.GREEN)

func _on_input_button_pressed(button):
	obs.send_command("ToggleInputMute", { "inputName": button.text }, button.text)

func insert_data(node: Node, text: String) -> void:
	node.clear()
	node.append_text(text)

# endregion

# region WINDOW FUNCTIONS

func _input(event):
	if event.is_action_pressed("cancel_speech"):
		cancel_button.emit_signal("pressed")

	if event.is_action_pressed("pause_resume"):
		pause_button.button_pressed = not pause_button.button_pressed
		pause_button.emit_signal("toggled", pause_button.button_pressed)

func backend_connected():
	CpHelpers.change_status_color(%BackendStatus, true)

func backend_disconnected():
	CpHelpers.change_status_color(%BackendStatus, false)

func _on_pause_speech_toggled(button_pressed: bool, emit := true) -> void:
	Globals.is_paused = button_pressed

	CpHelpers.change_toggle_state(
		pause_button,
		button_pressed,
		">>> RESUME (F9) <<<",
		"Pause (F9)"
	)

	if emit and not button_pressed:
		Globals.ready_for_speech.emit()

func _on_debug_mode_button_toggled(button_pressed: bool) -> void:
	Globals.debug_mode = button_pressed

	CpHelpers.change_toggle_state(
		debug_button,
		button_pressed,
		">>> DEBUG MODE <<<",
		"Debug Mode"
	)

func _on_cancel_speech_pressed():
	Globals.cancel_speech.emit()
	current_speech.add_theme_color_override("font_color", Color.RED)

func stop_processing():
	obs_stats_timer.stop()
	obs.break_connection()
	main.client.break_connection("from control panel")
	CpHelpers.change_status_color(%ObsClientStatus, false)

func _on_reconnect_button_pressed():
	stop_processing()
	get_tree().reload_current_scene()

func _on_close_requested():
	$CloseConfirm.visible = true

func _on_close_confirm_confirmed():
	stop_processing()
	get_tree().quit()

# endregion
