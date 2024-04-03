extends Window
@onready var main: Node2D = get_parent()

@onready var obs := $ObsWebSocketClient

@export_category("UI")
@onready var debug_button := %DebugMode
@onready var cancel_button := %CancelSpeech
@onready var pause_button := %PauseSpeech
@onready var obs_client_status := %ObsClientStatus
@onready var backend_status := %BackendStatus

@onready var godot_stats_timer := $Timers/GodotStatsTimer
@onready var obs_stats_timer := $Timers/ObsStatsTimer
@onready var message_queue_stats_timer := $Timers/MessageQueueStatsTimer
@onready var sound_output := %SoundOutput

# OBS info
var OpCodes: Dictionary = ObsWebSocketClient.OpCodeEnums.WebSocketOpCode
var is_streaming := false

# Last state globals
var last_pause_status := not Globals.is_paused
var last_singing_status := not Globals.is_singing
var last_position := ""
var last_animation := ""
var last_dancing_bpm := 0.1

func _ready() -> void:
	# Remove editor-only nodes
	for i in get_tree().get_nodes_in_group("_editor_only"):
		i.queue_free()

	godot_stats_timer.start()
	message_queue_stats_timer.start()

	_apply_defaults()

	_generate_position_controls()
	_generate_model_controls()
	_generate_singing_controls()
	_generate_sound_controls()

	_connect_signals()
	_start_obs_processing()

func _process(_delta: float) -> void:
	_update_control_status()

func _apply_defaults() -> void:
	debug_button.button_pressed = Globals.debug_mode
	pause_button.button_pressed = Globals.is_paused
	%ShowBeats.button_pressed = Globals.show_beats

	obs_client_status.text = "OBS\n%s:%s" % [Globals.config.get_obs("host"), Globals.config.get_obs("port")]
	backend_status.text = "Backend\n%s:%s" % [Globals.config.get_backend("host"), Globals.config.get_backend("port")]

	%TimeBeforeCleanout.value = Globals.time_before_cleanout
	%TimeBeforeNextResponse.value = Globals.time_before_next_response

	%CurrentSpeech/Prompt.text = "Waiting for prompt..."
	%CurrentSpeech/Emotions.text = "Waiting for emotions..."
	%CurrentSpeech/Text.text = "Waiting for text..."

	%FixedScene.button_pressed = Globals.fixed_scene

func _update_control_status() -> void:
	if last_pause_status != Globals.is_paused:
		last_pause_status = Globals.is_paused
		CpHelpers.change_toggle_state(
			pause_button,
			Globals.is_paused,
			">>> RESUME (F9) <<<",
			"Pause (F9)",
			Color.YELLOW
		)

	if last_singing_status != Globals.is_singing:
		last_singing_status = Globals.is_singing
		CpHelpers.change_toggle_state(
			%SingingToggle,
			Globals.is_singing
		)

	if last_dancing_bpm != Globals.dancing_bpm:
		last_dancing_bpm = Globals.dancing_bpm
		CpHelpers.change_toggle_state(
			%DancingToggle,
			Globals.dancing_bpm,
			"STOP (%s bpm)" % Globals.dancing_bpm
		)

	if last_animation != Globals.last_animation:
		last_animation = Globals.last_animation
		_update_animation_buttons(Globals.last_animation)

	if last_position != Globals.last_position:
		last_position = Globals.last_position
		_update_position_buttons(Globals.last_position)

func _start_obs_processing() -> void:
	obs.establish_connection()
	await obs.connection_authenticated

	if not obs.data_received.is_connected(_on_data_received):
		obs.data_received.connect(_on_data_received)

	CpHelpers.change_status_color(obs_client_status, true)

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
	CpHelpers.change_status_color(obs_client_status, false)

	CpHelpers.clear_nodes([ %ObsScenes, %ObsInputs, %ObsFilters])

func _connect_signals() -> void:
	Globals.set_toggle.connect(_on_set_toggle)
	Globals.pin_asset.connect(_on_pin_asset)

	Globals.start_speech.connect(_on_start_speech)

	Globals.start_singing.connect(_on_start_singing.unbind(2))
	Globals.stop_singing.connect(_on_stop_singing)

	Globals.change_position.connect(_on_change_position)
	Globals.change_scene.connect(_on_change_scene)

	Globals.update_backend_stats.connect(_on_update_backend_stats)

	Globals.new_speech.connect(_on_new_speech)
	Globals.end_speech.connect(_on_end_speech)
	Globals.push_speech_from_queue.connect(_on_push_speech_from_queue)

	print_debug("Control Panel: connected signals")

func _generate_position_controls() -> void:
	var positions := %Positions
	for n in positions.get_children():
		if n.get_class() == "Button":
			n.queue_free()

	var button_group := ButtonGroup.new()
	button_group.pressed.connect(_on_position_button_pressed)

	for p: String in Globals.positions:
		var button := Button.new()
		button.text = p.capitalize()
		button.toggle_mode = true
		button.button_pressed = p == Globals.default_position
		button.name = "Position" + p.to_pascal_case()
		button.button_group = button_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.set_meta("position_name", p)
		positions.add_child(button)

	var menu := %NextPositionMenu
	for p: String in Globals.positions:
		menu.add_item(p)

func _on_position_button_pressed(button: BaseButton) -> void:
	Globals.change_position.emit(button.get_meta("position_name"))

func _generate_singing_controls() -> void:
	var menu := %SingingMenu
	menu.clear()

	var songs := Globals.config.songs
	var i := 1
	for song in songs:
		menu.add_item("%s - %s" % [i, song.song_name])
		i += 1

func _generate_model_controls() -> void:
	for type: String in ["animations", "pinnable_assets", "expressions", "toggles"]:
		var parent := get_node("%%%s"% type.to_pascal_case())
		CpHelpers.clear_nodes(parent)

		var callable: Callable
		match type:
			"toggles":
				callable = _on_model_toggle_pressed

			"pinnable_assets":
				callable = _on_asset_toggle_pressed

		CpHelpers.construct_model_control_buttons(type, parent, Globals[type], callable)

func _on_data_received(data: Object) -> void:
	match data.op:
		OpCodes.Event.IDENTIFIER_VALUE:
			_handle_event(data.d)

		OpCodes.RequestResponse.IDENTIFIER_VALUE:
			_handle_request(data.d)

		OpCodes.RequestBatchResponse.IDENTIFIER_VALUE:
			for i: Dictionary in data.d.results:
				_handle_request(i)

		_:
			print_debug("Unhandled op: ", data.op)
			print_debug(data)
			print_debug("-------------")

func _handle_event(data: Dictionary) -> void:
	match data.eventType:
		"CurrentProgramSceneChanged":
			_change_active_scene(data.eventData)

		"SceneListChanged":
			obs.send_command("GetSceneList")

		"InputMuteStateChanged":
			_change_input_state(data.eventData)

		"InputNameChanged":
			_change_input_name(data.eventData)

		"ExitStarted":
			_stop_obs_processing()

		"SourceFilterEnableStateChanged":
			change_filter_state(data.eventData)

		"SourceFilterNameChanged":
			obs.send_command("GetSceneList")

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

func _handle_request(data: Dictionary) -> void:
	if not data.requestStatus.result:
		if data.requestStatus.code == 604:
			# ignore GetInputMute's "The specified input does not support audio" errors
			return

		print_debug("Error in request: ", data)
		return

	match data.requestType:
		"GetStats":
			CpHelpers.insert_data( %StreamStats, Templates.format_obs_stats(data.responseData))

		"GetSceneList":
			_generate_scene_buttons(data.responseData)

			var request := []
			for scene: Dictionary in data.responseData.scenes:
				request.push_front([
					"GetSourceFilterList", {"sourceName": scene.sceneName}, scene.sceneName
				])

			CpHelpers.clear_nodes( %ObsFilters)
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

func _on_godot_stats_timer_timeout() -> void:
	CpHelpers.insert_data( %GodotStats, Templates.format_godot_stats())

func _on_obs_stats_timer_timeout() -> void:
	obs.send_command("GetStats")

func _on_message_queue_stats_timer_timeout() -> void:
	CpHelpers.insert_data( %MessageQueueStats, Templates.format_message_queue_stats())

func _on_start_singing() -> void:
	Globals.is_paused = true
	%SingingMenu.disabled = true
	%ReloadSongList.disabled = true
	%DancingToggle.disabled = true
	%DancingBpm.editable = false
	gui_release_focus()

func _on_stop_singing() -> void:
	%SingingMenu.disabled = false
	%ReloadSongList.disabled = false
	%DancingToggle.disabled = false
	%DancingBpm.editable = true

func _on_singing_toggle_toggled(button_pressed: bool) -> void:
	var song: Song = Globals.config.songs[%SingingMenu.selected]
	var seek_time: float = %SingingSeekTime.value

	if button_pressed:
		var old_text: String = %SingingMenu.get_popup().get_item_text( %SingingMenu.selected)
		%SingingMenu.get_popup().set_item_text( %SingingMenu.selected, "♫ %s" % old_text)
		Globals.start_singing.emit(song, seek_time)
	else:
		Globals.stop_singing.emit()

func _on_dancing_toggle_toggled(button_pressed: bool) -> void:
	if button_pressed:
		Globals.start_dancing_motion.emit( %DancingBpm.value)
	else:
		Globals.end_dancing_motion.emit()
	gui_release_focus()

func _on_model_toggle_pressed(toggle: CheckButton) -> void:
	Globals.set_toggle.emit(toggle.text, toggle.button_pressed)

func _on_asset_toggle_pressed(toggle: CheckButton) -> void:
	Globals.pin_asset.emit(toggle.text, toggle.button_pressed)

func _on_new_speech(data: Dictionary) -> void:
	%CurrentSpeech/Text.remove_theme_color_override("font_color")
	%CurrentSpeech/Prompt.text = "%s (%s)" % [data.prompt, data.id]
	%CurrentSpeech/Emotions.text = CpHelpers.array_to_string(data.emotions)

func _on_end_speech() -> void:
	%CurrentSpeech/Text.add_theme_color_override("font_color", Color.YELLOW)

func _on_push_speech_from_queue(response: String, emotions: Array[String]) -> void:
	%CurrentSpeech/Text.text = response
	%CurrentSpeech/Emotions.text = CpHelpers.array_to_string(emotions)

func _on_start_speech() -> void:
	%CurrentSpeech/Text.remove_theme_color_override("font_color")

func _on_set_toggle(toggle_name: String, enabled: bool) -> void:
	var ui_name := "Toggles_%s" % toggle_name.to_pascal_case()
	_change_checkbutton_state( %Toggles, ui_name, enabled)

func _on_pin_asset(asset_name: String, enabled: bool) -> void:
	var ui_name := "PinnableAssets_%s" % asset_name.to_pascal_case()
	_change_checkbutton_state( %PinnableAssets, ui_name, enabled)

func _change_checkbutton_state(node: Node, ui_name: String, enabled: bool) -> void:
	var asset: CheckButton = node.get_node(ui_name)
	assert(asset is CheckButton, "CheckButton `%s` was not found, returned %s" % [ui_name, asset])

	asset.set_pressed_no_signal(enabled)

func _on_obs_stream_control_pressed() -> void:
	obs.send_command("ToggleStream")

func _on_change_scene(scene_name: String) -> void:
	obs.send_command("SetCurrentProgramScene", {"sceneName": scene_name})

	var next_position: String
	var selected_override: int = %NextPositionMenu.selected - 1
	if selected_override != - 1:
		next_position = Globals.positions.keys()[selected_override]

	if not next_position:
		match scene_name:
			"Main", "Song":
				next_position = "default"

			"Collab":
				next_position = "collab"

			"Gaming":
				next_position = "gaming"

	%NextPositionMenu.selected = 0
	if next_position:
		Globals.change_position.emit(next_position)

func _on_scene_button_pressed(button: Button) -> void:
	CpHelpers.apply_color_override(button, true, Color.YELLOW)
	Globals.change_scene.emit(button.text)

func _on_change_position(new_position: String) -> void:
	for p in %Positions.get_children():
		if p is Button:
			p.set_pressed_no_signal(p.text == new_position)

func _update_animation_buttons(new_animation: String) -> void:
	for p in %Animations.get_children():
		p.set_pressed_no_signal(p.text == new_animation)

func _update_position_buttons(new_position: String) -> void:
	for p in %Positions.get_children():
		p.set_pressed_no_signal(p.get_meta("position_name") == new_position)

func _generate_scene_buttons(data: Dictionary) -> void:
	var active_scene: String
	if data.has("currentProgramSceneName"):
		active_scene = data.currentProgramSceneName
	var scenes: Array = data.scenes
	scenes.reverse()

	CpHelpers.clear_nodes( %ObsScenes)

	for scene: Dictionary in scenes:
		var button := Button.new()
		button.text = scene.sceneName
		button.toggle_mode = true
		button.name = Templates.scene_node_name % scene.sceneName.to_pascal_case()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.button_pressed = scene.sceneName == active_scene
		button.custom_minimum_size = Vector2(100, 80)
		CpHelpers.apply_color_override(button, scene.sceneName == active_scene, Color.GREEN)
		button.pressed.connect(_on_scene_button_pressed.bind(button))
		%ObsScenes.add_child(button)

func _change_active_scene(data: Dictionary) -> void:
	for button in %ObsScenes.get_children():
		var scene_name: String = Templates.scene_node_name % data.sceneName.to_pascal_case()
		button.button_pressed = button.text == data.sceneName
		CpHelpers.apply_color_override(button, button.name == scene_name, Color.GREEN)

func _generate_filter_buttons(scene_name: String, filters: Array) -> void:
	for filter: Dictionary in filters:
		var button := Button.new()
		button.text = "%s: %s" % [scene_name, filter.filterName]
		button.name = Templates.filter_node_name % [scene_name, filter.filterName]
		button.toggle_mode = true
		button.button_pressed = filter.filterEnabled
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.button_pressed = filter.filterEnabled
		CpHelpers.apply_color_override(button, filter.filterEnabled, Color.GREEN, Color.GRAY)
		button.toggled.connect(_on_filter_button_toggled.bind(button))
		%ObsFilters.add_child(button)

func change_filter_state(data: Dictionary) -> void:
	var filter_name: String = Templates.filter_node_name % [data.sourceName, data.filterName]
	var button := %ObsFilters.get_node(filter_name)
	if not button is Button:
		printerr("Filter button `%s` was not found, returned %s" % [filter_name, button])
		return

	button.button_pressed = data.filterEnabled
	CpHelpers.apply_color_override(button, data.filterEnabled, Color.GREEN, Color.GRAY)

func _generate_input_request(inputs: Array) -> void:
	CpHelpers.clear_nodes( %ObsInputs)

	var request := []
	for i: Dictionary in inputs:
		request.push_back([
			"GetInputMute", {"inputName": i.inputName}, i.inputName
		])

	obs.send_command_batch(request)

func _generate_input_button(data: Dictionary) -> void:
	# Only inputs we need
	if data.inputName not in ["Mebla Capture", "MUSIC"]:
		return

	var button := Button.new()
	button.name = data.inputName.to_pascal_case()
	button.text = data.inputName
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(60, 60)
	button.pressed.connect(_on_input_button_pressed.bind(button))
	%ObsInputs.add_child(button)
	_change_input_state(data)

func _change_input_name(data: Dictionary) -> void:
	var button := %ObsInputs.get_node(data.oldInputName.to_pascal_case())

	if button:
		button.name = data.inputName.to_pascal_case()
		button.text = data.inputName

func _change_input_state(data: Dictionary) -> void:
	var button := %ObsInputs.get_node(data.inputName.to_pascal_case())

	if button:
		button.button_pressed = data.inputMuted
		CpHelpers.apply_color_override(button, data.inputMuted, Color.RED, Color.GREEN)

func _on_input_button_pressed(button: Button) -> void:
	obs.send_command("ToggleInputMute", {"inputName": button.text}, button.text)

func _on_filter_button_toggled(button_pressed: bool, button: Button) -> void:
	var data := button.name.split("_")

	obs.send_command("SetSourceFilterEnabled", {
		"sourceName": data[1],
		"filterName": data[2],
		"filterEnabled": button_pressed
	}, button.name)

	CpHelpers.apply_color_override(button, button_pressed, Color.RED, Color.GREEN)

func _on_time_before_cleanout_value_changed(value: float) -> void:
	Globals.time_before_cleanout = value

func _on_time_before_next_response_value_changed(value: float) -> void:
	Globals.time_before_next_response = value

func _on_update_backend_stats(data: Array) -> void:
	CpHelpers.insert_data( %BackendStats, Templates.format_backend_stats(data))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_speech"):
		cancel_button.pressed.emit()

	if event.is_action_pressed("pause_resume"):
		if not pause_button.disabled:
			pause_button.button_pressed = not pause_button.button_pressed

	if event.is_action_pressed("toggle_mute"):
		obs.send_command("ToggleInputMute", {"inputName": "Mebla Capture"}, "Mebla Capture")

func backend_connected() -> void:
	pause_button.disabled = false
	CpHelpers.change_status_color(backend_status, true)

func backend_disconnected() -> void:
	pause_button.disabled = true
	CpHelpers.change_status_color(backend_status, false)

func _on_pause_speech_toggled(button_pressed: bool) -> void:
	Globals.is_paused = button_pressed

	if not button_pressed and Globals.is_ready():
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

func _on_reset_state_pressed() -> void:
	Globals.reset_subtitles.emit()
	SpeechManager.reset_speech()

func _on_show_beats_toggled(toggled_on: bool) -> void:
	Globals.show_beats = toggled_on

func _on_fixed_scene_toggled(toggled_on: bool) -> void:
	Globals.fixed_scene = toggled_on

func _on_reload_song_list_pressed() -> void:
	if not Globals.is_paused or Globals.is_singing:
		$ReloadSongListWarning.show()
		return

	Globals.config.init_songs(Globals.debug_mode)
	_generate_singing_controls()

func _on_obs_client_status_pressed() -> void:
	_stop_obs_processing()
	await get_tree().create_timer(1.0).timeout
	_start_obs_processing()

func _on_backend_status_pressed() -> void:
	Globals.is_paused = true
	Globals.play_animation.emit("sleep")
	main.disconnect_backend()
	CpHelpers.insert_data( %BackendStats, Templates.format_backend_stats([0, 0]))
	await get_tree().create_timer(1.0).timeout
	main.connect_backend()

func _on_speech_text_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				%CurrentSpeech/TextCopied.show()

				var text: String = %CurrentSpeech/Prompt.text
				text += "\n\n" + %CurrentSpeech/Text.text \
					.replace("\n", " ") \
					.replace(" [END]", "")

				DisplayServer.clipboard_set(text)
				await get_tree().create_timer(2.0).timeout
				%CurrentSpeech/TextCopied.hide()

func _on_close_requested() -> void:
	$CloseConfirm.show()

func _on_close_confirm_confirmed() -> void:
	_stop_obs_processing()
	main.disconnect_backend()
	get_tree().quit()

func _on_green_screen_toggle_toggled(enabled: bool) -> void:
	Globals.green_screen = enabled
	main.greenscreen_window.visible = enabled

func _generate_sound_controls() -> void:
	var outputs := AudioServer.get_output_device_list()

	for output in outputs:
		sound_output.add_item(output)

func _on_sound_output_item_selected(index: int) -> void:
	AudioServer.set_output_device(sound_output.get_popup().get_item_text(index))
