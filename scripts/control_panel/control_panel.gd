extends Window
@onready var main: Node2D = get_parent()

@export_category("General")
@export var obs: ObsWebSocketClient

@export_category("UI")
@export var debug_button: Button
@export var cancel_button: Button
@export var pause_button: Button

@export_category("Timers")
@export var godot_stats_timer: Timer
@export var obs_stats_timer: Timer

# OBS info
var OpCodes := obs.OpCodeEnums.WebSocketOpCode
var is_streaming := false

# Last state globals
var last_pause_status := not Globals.is_paused
var last_singing_status := not Globals.is_singing
var last_dancing_bpm := 0.1

func _ready() -> void:
	# Remove editor-only nodes
	for i in get_tree().get_nodes_in_group("_editor_only"):
		i.queue_free()

	godot_stats_timer.start()

	_apply_defaults()

	_generate_position_controls()
	_generate_model_controls()
	_generate_singing_controls()

	_connect_signals()
	_start_obs_processing()

func _process(_delta) -> void:
	_update_control_status()

func _apply_defaults() -> void:
	debug_button.button_pressed = Globals.debug_mode
	pause_button.button_pressed = Globals.is_paused

	%BackendStatus.text = "Backend %s" % Globals.config.get_backend("host")
	%TimeBeforeCleanout.value = Globals.time_before_cleanout
	%TimeBeforeReady.value = Globals.time_before_ready
	%TimeBeforeSpeech.value = Globals.time_before_speech
	%ShowBeats.button_pressed = Globals.show_beats

func _update_control_status() -> void:
	if last_pause_status != Globals.is_paused:
		last_pause_status = Globals.is_paused
		CpHelpers.change_toggle_state(
			pause_button,
			Globals.is_paused,
			">>> RESUME (F9) <<<",
			"Pause (F9)"
		)

	if last_singing_status != Globals.is_singing:
		last_singing_status = Globals.is_singing
		CpHelpers.change_toggle_state(
			%SingingToggle,
			Globals.is_singing
		)

	if last_dancing_bpm != Globals.dancing_bpm:
		last_dancing_bpm = Globals.dancing_bpm
		%CurrentDancingBpm.text = str(Globals.dancing_bpm)
		CpHelpers.change_toggle_state(
			%DancingToggle,
			Globals.dancing_bpm
		)

func _start_obs_processing() -> void:
	obs.establish_connection()
	await obs.connection_authenticated

	if not obs.data_received.is_connected(_on_data_received):
		obs.data_received.connect(_on_data_received)

	%ObsStreamControl.disabled = false
	CpHelpers.change_status_color(%ObsClientStatus, true)

	# OBS Data init
	obs.send_command_batch([
		"GetSceneList",
		"GetInputList",
		"GetStats"
	])

	# OBS Stats timers
	obs_stats_timer.start()

func _stop_obs_processing() -> void:
	obs_stats_timer.stop()
	obs.break_connection()
	CpHelpers.change_status_color(%ObsClientStatus, false)
	%ObsStreamControl.disabled = true

	CpHelpers.clear_nodes([%ObsScenes, %ObsInputs, %ObsFilters])

func _connect_signals() -> void:
	Globals.set_toggle.connect(_on_set_toggle)
	Globals.new_speech.connect(_on_new_speech)
	Globals.start_speech.connect(_on_start_speech)

	Globals.start_singing.connect(_on_start_singing)

	Globals.change_position.connect(_on_change_position)
	Globals.change_scene.connect(_on_change_scene)

	print_debug("Control Panel: connected signals")

func _generate_position_controls() -> void:
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
		button.button_pressed = p == Globals.default_position
		button.name = "Position" + p.to_pascal_case()
		button.button_group = button_group
		button.focus_mode = Control.FOCUS_NONE
		positions.add_child(button)

	var menu := %NextPositionMenu
	menu.add_item("NO OVERRIDE")
	for p in Globals.positions:
		menu.add_item(p)

func _on_position_button_pressed(button: BaseButton) -> void:
	Globals.change_position.emit(button.text)

func _generate_singing_controls() -> void:
	var menu := %SingingMenu
	menu.clear()

	var songs = Globals.config.songs
	for song in songs:
		menu.add_item(song.name)

func _generate_model_controls() -> void:
	for type in ["animations", "pinnable_assets", "expressions", "toggles"]:
		var parent = get_node("%%%s" % type.to_pascal_case())
		CpHelpers.clear_nodes(parent)

		var callable: Callable
		match type:
			"toggles":
				callable = _on_model_toggle_pressed

			"pinnable_assets":
				callable = _on_asset_toggle_pressed

		CpHelpers.construct_model_control_buttons(type, parent, Globals[type], callable)

func _on_data_received(data) -> void:
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

func _handle_event(data) -> void:
	match data.eventType:
		"CurrentProgramSceneChanged":
			_change_active_scene(data.eventData)

		"SceneListChanged":
			obs.send_command("GetSceneList")

		"InputMuteStateChanged":
			_change_input_state(data.eventData)

		"InputNameChanged":
			_change_input_name(data.eventData)

		"StreamStateChanged":
			if is_streaming != data.eventData.outputActive:
				is_streaming = data.eventData.outputActive
				_update_stream_control_button()

		"ExitStarted":
			_stop_obs_processing()

		"SourceFilterEnableStateChanged":
			change_filter_state(data.eventData)

		# Ignored callbacks
		"SceneNameChanged":
			pass # handled by SceneListChanged

		"SceneTransitionStarted", "SceneTransitionVideoEnded", "SceneTransitionEnded", \
		"MediaInputActionTriggered":
			pass # We don't need it

		_:
			if Globals.debug_mode:
				print_debug("Unhandled event: ", data.eventType)
				print_debug(data)
				print_debug("-------------")

func _handle_request(data) -> void:
	if not data.requestStatus.result:
		if data.requestStatus.code == 604:
			# ignore GetInputMute's "The specified input does not support audio" errors
			return

		print_debug("Error in request: ", data)
		return

	match data.requestType:
		"GetStats":
			CpHelpers.insert_data(%StreamStats, Templates.format_obs_stats(data.responseData))

		"GetStreamStatus":
			var status = data.responseData
			if is_streaming != status.outputActive:
				is_streaming = status.outputActive
				_update_stream_control_button()

		"GetSceneList":
			_generate_scene_buttons(data.responseData)

			var request := []
			for scene in data.responseData.scenes:
				request.push_front([
					"GetSourceFilterList", {"sourceName": scene.sceneName}, scene.sceneName
				])

			obs.send_command_batch(request)

		"GetInputList":
			_generate_input_request(data.responseData.inputs)

		"GetInputMute":
			var inputData := {
				"inputName": data.requestId,
				"inputMuted": data.responseData.inputMuted
			}
			_generate_input_button(inputData)

		"GetSourceFilterList":
			if data.responseData.filters:
				_generate_filter_buttons(data.requestId, data.responseData.filters)

		# Ignored callbacks
		"ToggleInputMute":
			pass # handled by InputMuteStateChanged event

		"SetCurrentProgramScene", "ToggleStream", "SetSourceFilterEnabled":
			pass # handled by StreamChateChanged event

		_:
			if Globals.debug_mode:
				print("Unhandled request: ", data.requestType)
				print(data)
				print("-------------")

func _on_obs_stats_timer_timeout() -> void:
	obs.send_command("GetStats")

func _on_godot_stats_timer_timeout() -> void:
	CpHelpers.insert_data(%GodotStats, Templates.format_godot_stats())

func _on_start_singing(_song, _seek_time) -> void:
	Globals.is_paused = true

func _on_singing_toggle_toggled(button_pressed: bool) -> void:
	var song: Dictionary = Globals.config.songs[%SingingMenu.selected]
	var seek_time: float = %SingingSeekTime.value

	if button_pressed:
		Globals.start_singing.emit(song, seek_time)
	else:
		Globals.stop_singing.emit()

func _on_dancing_toggle_toggled(button_pressed: bool) -> void:
	if button_pressed:
		Globals.start_dancing_motion.emit(%DancingBpm.value)
	else:
		Globals.end_dancing_motion.emit()

func _on_model_toggle_pressed(toggle: CheckButton) -> void:
	Globals.set_toggle.emit(toggle.text, toggle.button_pressed)

func _on_asset_toggle_pressed(toggle: CheckButton) -> void:
	Globals.pin_asset.emit(toggle.text, toggle.button_pressed)

func _on_new_speech(prompt: String, text: String, emotions: Array) -> void:
	%CurrentSpeech/Text.add_theme_color_override("font_color", Color.YELLOW)
	%CurrentSpeech/Prompt.text = prompt
	%CurrentSpeech/Emotions.text = CpHelpers.array_to_string(emotions)
	%CurrentSpeech/Text.text = text

func _on_start_speech() -> void:
	%CurrentSpeech/Text.remove_theme_color_override("font_color")

func _on_set_toggle(toggle_name: String, enabled: bool) -> void:
	var ui_name := "Toggles_%s" % toggle_name.to_pascal_case()
	var toggle: CheckButton = %Toggles.get_node(ui_name)
	assert(toggle is CheckButton, "CheckButton `%s` was not found, returned %s" % [ui_name, toggle])

	toggle.set_pressed_no_signal(enabled)

func _update_stream_control_button() -> void:
	CpHelpers.change_toggle_state(
		%ObsStreamControl,
		is_streaming,
		"Stop Stream",
		"Start Stream"
	)

func _on_obs_stream_control_pressed() -> void:
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

			"Gaming":
				next_position = "gaming"

	%NextPositionMenu.selected = 0
	if next_position:
		Globals.change_position.emit(next_position)

func _on_scene_button_pressed(button) -> void:
	Globals.change_scene.emit(button.text)

func _on_change_position(new_position: String) -> void:
	var buttons := %Positions

	for b in buttons.get_children():
		if b.text == new_position:
			b.set_pressed_no_signal(true)
			return

func _generate_scene_buttons(data: Dictionary) -> void:
	var active_scene = null
	if data.has("currentProgramSceneName"):
		active_scene = data.currentProgramSceneName
	var scenes = data.scenes
	scenes.reverse()

	CpHelpers.clear_nodes(%ObsScenes)

	for scene in scenes:
		var button = Button.new()
		button.text = scene.sceneName
		button.name = Templates.scene_node_name % scene.sceneName.to_pascal_case()
		CpHelpers.apply_color_override(button, scene.sceneName == active_scene, Color.GREEN)
		button.pressed.connect(_on_scene_button_pressed.bind(button))
		%ObsScenes.add_child(button)

func _change_active_scene(data: Dictionary) -> void:
	for button in %ObsScenes.get_children():
		var scene_name = Templates.scene_node_name % data.sceneName.to_pascal_case()
		CpHelpers.apply_color_override(button, button.name == scene_name, Color.GREEN)

func _generate_filter_buttons(scene_name: String, filters: Array) -> void:
	CpHelpers.clear_nodes(%ObsFilters)

	for filter in filters:
		var button = Button.new()
		button.text = "%s: %s" % [scene_name, filter.filterName]
		button.name = Templates.filter_node_name % [scene_name, filter.filterName]
		button.toggle_mode = true
		button.button_pressed = filter.filterEnabled
		button.focus_mode = Control.FOCUS_NONE
		CpHelpers.apply_color_override(button, filter.filterEnabled, Color.GREEN, Color.RED)
		button.toggled.connect(_on_filter_button_toggled.bind(button))
		%ObsFilters.add_child(button)

func change_filter_state(data: Dictionary) -> void:
	var filter_name: String = Templates.filter_node_name % [data.sourceName, data.filterName]
	var button := %ObsFilters.get_node(filter_name)
	assert(button is Button, "Filter button `%s` was not found, returned %s" % [filter_name, button])

	button.button_pressed = data.filterEnabled
	CpHelpers.apply_color_override(button, data.filterEnabled, Color.GREEN, Color.RED)

func _generate_input_request(inputs: Array) -> void:
	CpHelpers.clear_nodes(%ObsInputs)

	var request = []
	for i in inputs:
		request.push_back([
			"GetInputMute", { "inputName": i.inputName }, i.inputName
		])

	obs.send_command_batch(request)

func _generate_input_button(data: Dictionary) -> void:
	var button = Button.new()
	button.visible = false
	button.name = data.inputName.to_pascal_case()
	button.text = data.inputName
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_input_button_pressed.bind(button))
	%ObsInputs.add_child(button)
	_change_input_state(data)

func _change_input_name(data: Dictionary) -> void:
	var button = %ObsInputs.get_node(data.oldInputName.to_pascal_case())

	if button:
		button.name = data.inputName.to_pascal_case()
		button.text = data.inputName

func _change_input_state(data) -> void:
	var button = %ObsInputs.get_node(data.inputName.to_pascal_case())

	if button:
		button.visible = true
		CpHelpers.apply_color_override(button, data.inputMuted, Color.RED, Color.GREEN)

func _on_input_button_pressed(button: Button) -> void:
	obs.send_command("ToggleInputMute", { "inputName": button.text }, button.text)

func _on_filter_button_toggled(button_pressed: bool, button: Button) -> void:
	var data = button.name.split("_")

	obs.send_command("SetSourceFilterEnabled", {
		"sourceName": data[1],
		"filterName": data[2],
		"filterEnabled": button_pressed
	}, button.name)

	CpHelpers.apply_color_override(button, button_pressed, Color.RED, Color.GREEN)

func _on_time_before_cleanout_value_changed(value: float) -> void:
	Globals.time_before_cleanout = value

func _on_time_before_ready_value_changed(value: float) -> void:
	Globals.time_before_ready = value

func _on_time_before_speech_value_changed(value: float) -> void:
	Globals.time_before_speech = value

func _input(event) -> void:
	if event.is_action_pressed("cancel_speech"):
		cancel_button.pressed.emit()

	if event.is_action_pressed("pause_resume"):
		pause_button.button_pressed = not pause_button.button_pressed

	if event.is_action_pressed("toggle_mute"):
		var input = "Melba Speaking"
		obs.send_command("ToggleInputMute", { "inputName": input }, input)

func backend_connected() -> void:
	CpHelpers.change_status_color(%BackendStatus, true)

func backend_disconnected() -> void:
	CpHelpers.change_status_color(%BackendStatus, false)

func _on_pause_speech_toggled(button_pressed: bool) -> void:
	Globals.is_paused = button_pressed

	if not button_pressed:
		Globals.ready_for_speech.emit()

func _on_debug_mode_button_toggled(button_pressed: bool) -> void:
	Globals.debug_mode = button_pressed

	CpHelpers.change_toggle_state(
		debug_button,
		button_pressed,
		">>> DEBUG MODE <<<",
		"Debug Mode"
	)

func _on_cancel_speech_pressed() -> void:
	Globals.cancel_speech.emit()
	%CurrentSpeech/Text.add_theme_color_override("font_color", Color.RED)

func _on_reset_subtitles_pressed() -> void:
	Globals.reset_subtitles.emit()

func _on_show_beats_toggled(toggled_on: bool) -> void:
	Globals.show_beats = toggled_on

func _on_obs_client_status_pressed() -> void:
	_stop_obs_processing()
	await get_tree().create_timer(1.0).timeout
	_start_obs_processing()

func _on_backend_status_pressed() -> void:
	Globals.is_paused = true
	main.disconnect_backend()
	await get_tree().create_timer(1.0).timeout
	main.connect_backend()

func _on_close_requested() -> void:
	$CloseConfirm.visible = true

func _on_close_confirm_confirmed() -> void:
	_stop_obs_processing()
	main.disconnect_backend()
	get_tree().quit()
