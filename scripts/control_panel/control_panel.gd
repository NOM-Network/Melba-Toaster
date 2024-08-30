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

@export var obs_sources: Array
@export var active_scene: String

# OBS info
var OpCodes: Dictionary = ObsWebSocketClient.OpCodeEnums.WebSocketOpCode
var is_streaming := false

var music_inputs: Array = ["MUSIC", "MUSIC2"]
var music_volume: float = -10.0

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

	%SceneOverride.button_pressed = Globals.scene_override

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
		"GetStats",
		"GetStreamStatus"
	])

	# OBS Stats timers
	obs_stats_timer.start()

func _stop_obs_processing() -> void:
	obs_stats_timer.stop()
	obs.break_connection()
	CpHelpers.change_status_color(obs_client_status, false)

	CpHelpers.clear_nodes([%ObsScenes, %ObsInputs, %ObsFilters])

func _connect_signals() -> void:
	Globals.set_toggle.connect(_on_set_toggle)
	Globals.pin_asset.connect(_on_pin_asset)

	Globals.start_speech.connect(_on_start_speech)

	Globals.start_singing.connect(_on_start_singing.unbind(1))
	Globals.stop_singing.connect(_on_stop_singing)

	Globals.change_position.connect(_on_change_position)
	Globals.change_scene.connect(_on_change_scene)

	Globals.update_backend_stats.connect(_on_update_backend_stats)

	Globals.new_speech.connect(_on_new_speech)
	Globals.end_speech.connect(_on_end_speech)
	Globals.push_speech_from_queue.connect(_on_push_speech_from_queue)

	Globals.obs_action.connect(_on_obs_action)

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
	var i := 0
	for song in songs:
		menu.add_item("%s - %s" % [i + 1, song.get_song_ui_name()], i)
		menu.set_item_metadata(i, song.id)
		i += 1

func _generate_model_controls() -> void:
	for type: String in ["animations", "pinnable_assets", "expressions", "toggles"]:
		var parent := get_node("%%%s" % type.to_pascal_case())
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
			active_scene = data.eventData.sceneName
			obs.send_command("GetSceneItemList", {"sceneName": active_scene})

		"SceneListChanged":
			obs.send_command("GetSceneList")

		"InputMuteStateChanged":
			_change_input_state(data.eventData)

		"InputNameChanged":
			_change_input_name(data.eventData)

		"InputSettingsChanged":
			_change_input_settings(data.eventData)

		"ExitStarted":
			_stop_obs_processing()

		"SourceFilterEnableStateChanged":
			change_filter_state(data.eventData)

		"SourceFilterNameChanged":
			obs.send_command("GetSceneList")

		"StreamStateChanged":
			_change_stream_state(data.eventData)

		"SceneItemEnableStateChanged":
			obs.send_command("GetSceneItemList", {"sceneName": active_scene})

		# Ignored callbacks
		"SceneNameChanged":
			pass # handled by SceneListChanged

		"SceneTransitionStarted", "SceneTransitionVideoEnded", "SceneTransitionEnded", \
		"MediaInputActionTriggered", "InputVolumeChanged", "MediaInputPlaybackEnded", \
		"MediaInputPlaybackStarted":
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
			CpHelpers.insert_data(%StreamStats, Templates.format_obs_stats(data.responseData))

		"GetStreamStatus":
			_update_stream_status(data.responseData)

		"GetSceneList":
			obs.send_command("GetSceneItemList", {"sceneName": data.responseData.currentProgramSceneName})
			_generate_scene_buttons(data.responseData)

			var request := []
			for scene: Dictionary in data.responseData.scenes:
				request.push_front([
					"GetSourceFilterList", {"sourceName": scene.sceneName}, scene.sceneName
				])

			CpHelpers.clear_nodes(%ObsFilters)
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

		"GetSceneItemList":
			var sources: Array = data.responseData.sceneItems
			obs_sources = sources.map(func(item: Dictionary) -> Array: return [
				item.sourceName, item.sceneItemId, item.sceneItemEnabled
			])

		# Ignored callbacks
		"ToggleInputMute":
			pass # handled by InputMuteStateChanged event

		"SetCurrentProgramScene", "ToggleStream", "SetSourceFilterEnabled":
			pass # handled by StreamStateChanged event

		"SetInputVolume", "Sleep":
			pass # handled by InputVolumeChanged event

		_:
			if Globals.debug_mode:
				print("Unhandled request: ", data.requestType)
				print(data)
				print("-------------")

func _on_godot_stats_timer_timeout() -> void:
	CpHelpers.insert_data(%GodotStats, Templates.format_godot_stats())

func _on_obs_stats_timer_timeout() -> void:
	obs.send_command_batch([
		"GetStats",
		"GetStreamStatus"
	])

func _on_message_queue_stats_timer_timeout() -> void:
	CpHelpers.insert_data(%MessageQueueStats, Templates.format_message_queue_stats())

func _on_start_singing(song: Song) -> void:
	_set_input_volume(-10.0, -100.0, 10.0)
	_mpv_pause()

	Globals.current_emotion_modifier = 0.0

	for i: int in %SingingMenu.get_popup().get_item_count():
		if %SingingMenu.get_popup().get_item_text(i).ends_with(song.get_song_ui_name()):
			%SingingMenu.select(i)
			break

	var old_text: String = %SingingMenu.get_popup().get_item_text(%SingingMenu.selected)
	if not old_text.begins_with("♫"):
		%SingingMenu.get_popup().set_item_text(%SingingMenu.selected, "♫ %s" % old_text)

	Globals.is_paused = true
	_disable_singing_dancing_controls(true)
	gui_release_focus()

func _on_stop_singing() -> void:
	_mpv_pause()
	_set_input_volume(-100.0, -10.0, 10.0)

	_disable_singing_dancing_controls(false)
	gui_release_focus()

func _on_singing_toggle_toggled(button_pressed: bool) -> void:
	if button_pressed:
		var song_name: String = %SingingMenu.get_selected_metadata()
		var seek_time: float = %SingingSeekTime.value
		Globals.queue_next_song.emit(song_name, seek_time)

		%SingingToggle.text = "Queued"
		_disable_singing_dancing_controls(true)
	else:
		if Globals.is_singing:
			Globals.stop_singing.emit()
		else:
			print("Song removed from the queue")
			Globals.is_paused = false
			Globals.queued_song = null
			Globals.queued_song_seek_time = 0.0

		_disable_singing_dancing_controls(false)
		%SingingToggle.text = "Start"
	gui_release_focus()

func _on_dancing_toggle_toggled(button_pressed: bool) -> void:
	if button_pressed:
		var bpm: float = %DancingBpm.value
		Globals.start_dancing_motion.emit("%s" % bpm)
	else:
		Globals.end_dancing_motion.emit()
	gui_release_focus()

func _disable_singing_dancing_controls(disabled: bool) -> void:
	for control: Control in [%DancingBpm, %DancingToggle, %SingingMenu, %ReloadSongList, %SingingSeekTime]:
		if control is SpinBox:
			control.editable = not disabled
		else:
			control.disabled = disabled

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
	_change_checkbutton_state(%Toggles, ui_name, enabled)

func _on_pin_asset(asset_name: String, enabled: bool) -> void:
	var ui_name := "PinnableAssets_%s" % asset_name.to_pascal_case()
	_change_checkbutton_state(%PinnableAssets, ui_name, enabled)

func _change_checkbutton_state(node: Node, ui_name: String, enabled: bool) -> void:
	var asset: CheckButton = node.get_node(ui_name)
	assert(asset is CheckButton, "CheckButton `%s` was not found, returned %s" % [ui_name, asset])

	asset.set_pressed_no_signal(enabled)

func _on_obs_stream_control_pressed() -> void:
	obs.send_command("ToggleStream")

func _on_change_scene(scene_name: String) -> void:
	var next_scene := scene_name
	if Globals.scene_override and Globals.scene_override_to:
		next_scene = Globals.scene_override_to
	obs.send_command("SetCurrentProgramScene", {"sceneName": next_scene})

	var next_position: String
	if Globals.position_override and Globals.position_override_to:
		next_position = Globals.position_override_to
	else:
		match next_scene:
			"Main", "Song":
				next_position = "default"

			"Collab":
				next_position = "collab"

			"Collab Song":
				next_position = "collab_song"

			"Gaming":
				next_position = "gaming"

			_:
				next_position = "default"

	if next_position:
		Globals.position_override = false
		%NextPositionMenu.selected = 0
		Globals.change_position.emit(next_position)

func _on_next_posision_menu_item_selected(index: int) -> void:
	Globals.position_override = true
	Globals.position_override_to = %NextPositionMenu.get_item_text(index)

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
	if data.has("currentProgramSceneName"):
		active_scene = data.currentProgramSceneName
	var scenes: Array = data.scenes
	scenes.reverse()

	CpHelpers.clear_nodes(%ObsScenes)

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

	# Generate scene override list
	var menu := %SceneOverrideList
	menu.clear()

	menu.add_item("Stay", 0)
	menu.set_item_metadata(0, "Stay")

	var i := 1
	for scene: Dictionary in scenes:
		menu.add_item("%s" % scene.sceneName, i)
		menu.set_item_metadata(i, scene.sceneName)
		i += 1

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
	CpHelpers.clear_nodes(%ObsInputs)

	var request := []
	for i: Dictionary in inputs:
		request.push_back([
			"GetInputMute", {"inputName": i.inputName}, i.inputName
		])

	obs.send_command_batch(request)

func _generate_input_button(data: Dictionary) -> void:
	# Only inputs we need
	if data.inputName not in ["Mebla Capture", "Melba Sound", "MUSIC", "MUSIC2"]:
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
	CpHelpers.insert_data(%BackendStats, Templates.format_backend_stats(data))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_speech"):
		cancel_button.pressed.emit()

	if event.is_action_pressed("pause_resume"):
		if not pause_button.disabled:
			pause_button.button_pressed = not pause_button.button_pressed

	if event.is_action_pressed("toggle_mute"):
		obs.send_command("ToggleInputMute", {"inputName": "Mebla Capture"}, "Mebla Capture")
		obs.send_command("ToggleInputMute", {"inputName": "Melba Sound"}, "Melba Sound")

func backend_connected() -> void:
	pause_button.disabled = false
	CpHelpers.change_status_color(backend_status, true)

func backend_disconnected() -> void:
	pause_button.disabled = true
	Globals.play_animation.emit("sleep")
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
	gui_release_focus()

func _on_scene_override_toggled(toggled_on: bool) -> void:
	Globals.scene_override = toggled_on
	gui_release_focus()

func _on_scene_override_list_item_selected(_index: int) -> void:
	Globals.scene_override_to = %SceneOverrideList.get_selected_metadata()

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
	CpHelpers.insert_data(%BackendStats, Templates.format_backend_stats([0, 0]))
	main.disconnect_backend()

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

func _generate_sound_controls() -> void:
	var outputs := AudioServer.get_output_device_list()

	for output in outputs:
		sound_output.add_item(output)

func _on_sound_output_item_selected(index: int) -> void:
	AudioServer.set_output_device(sound_output.get_popup().get_item_text(index))

func _change_input_settings(data: Dictionary) -> void:
	if data.inputName != "Countdown":
		return

	if data.inputSettings.text == "0:05":
		_set_input_volume(0.0, -10.0, 0.05)

	if data.inputSettings.text == "0:00":
		await get_tree().create_timer(1.0).timeout

		var next_scene := "Collab" if Globals.config.get_obs("collab") else "Main"
		Globals.change_scene.emit(next_scene)

func _set_input_volume(start: float, end: float, step: float, sleep: int = 10) -> void:
	if end < start:
		step *= -1.0

	var requests: Array = []
	for i: float in Vector3(start, end, step):
		for source in music_inputs:
			requests.push_back(["SetInputVolume", {"inputName": source, "inputVolumeDb": i}])
			requests.push_back(["Sleep", {"sleepMillis": sleep}])

	for source in music_inputs:
		requests.push_back(["SetInputVolume", {"inputName": source, "inputVolumeDb": end}])

	print(requests)
	obs.send_command_batch(requests)

func _update_stream_status(data: Dictionary) -> void:
	if data.outputDuration > 2 * 60 * 60 * 1000:
		if not %StreamTimecode.has_theme_color_override("font_color"):
			%StreamTimecode.add_theme_color_override("font_color", Color.RED)

	%StreamTimecode.text = data.outputTimecode.substr(0, 8)

func _change_stream_state(data: Dictionary) -> void:
	if data.outputState == "OBS_WEBSOCKET_OUTPUT_STOPPED":
		%StreamTimecode.remove_theme_color_override("font_color")

func _mpv_pause() -> void:
	var output := []
	var command := "echo cycle pause >\\\\\\\\.\\pipe\\mpv-pipe" # plz forgib ;(
	print_debug(command.c_unescape())
	var exit_code := OS.execute("cmd.exe", ["/C", command.c_unescape()], output, true, false)
	print_debug("mpv exit code: ", exit_code, " ", output)

func _on_obs_action(action: String, args := "") -> void:
	match action:
		"toggle_scene_source":
			var sceneItem: Array = obs_sources.filter(func(item: Array) -> bool: return item[0] == args)
			if sceneItem.is_empty():
				print("Could not find scene item: ", args)
				return

			sceneItem = sceneItem[0]
			obs.send_command("SetSceneItemEnabled", {
				"sceneName": active_scene,
				"sceneItemId": sceneItem[1],
				"sceneItemEnabled": not sceneItem[2]
			})
