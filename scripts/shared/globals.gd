extends Node

# region EVENT BUS

signal play_animation(anim_name: String)
signal set_expression(expression_name: String, enabled: bool)
signal set_toggle(toggle_name: String, enabled: bool)
signal pin_asset(asset_name: String, enabled: bool)

signal queue_next_song(song_name: String, seek_time: float)
signal start_singing(song: Song, seek_time: float)
signal stop_singing()

signal start_dancing_motion(bpm: String)
signal end_dancing_motion()
signal start_singing_mouth_movement()
signal end_singing_mouth_movement()
signal nudge_model()

signal change_position(name: String)
signal change_scene(scene: String)

# Speech Manager
signal ready_for_speech()
signal new_speech(data: Dictionary)
signal start_speech()
signal push_speech_from_queue(response: String, emotions: Array[String])
signal continue_speech(data: Dictionary)
signal end_speech(data: Dictionary)
signal speech_done()
signal cancel_speech()
signal reset_subtitles()
signal set_subtitles(text: String, duration: float, continue_print: bool)
signal set_subtitles_fast(text: String)

signal update_backend_stats(data: Array)

# OBS Websocket
signal obs_action(action: String, args: String)

# endregion

# region MELBA STATE

@export var debug_mode := OS.is_debug_build()
@export var config := ToasterConfig.new(debug_mode)

@export var is_paused := true
@export var is_speaking := false
@export var is_singing := false
@export var dancing_bpm := 0.0

@export var show_beats := debug_mode

@export var scene_override := false
@export var scene_override_to := "Stay"

@export var position_override := false
@export var position_override_to := default_position

@export var queued_song: Song
@export var queued_song_seek_time := 0.0

@export var time_before_cleanout := 10.0
@export var time_before_next_response := 0.1

func is_ready() -> bool:
	return not (is_speaking or is_singing)

# endregion

# region SCENE DATA

static var default_position := "default"
static var last_position := default_position
static var positions := Variables.positions
static var scale_change := 0.05
static var rotation_change := 5.0

# region LIVE2D DATA

static var pinnable_assets := Variables.pinnable_assets
static var toggles := Variables.toggles
static var animations := Variables.animations
static var last_animation := ""

static var expressions := {
	"end": {"id": "none"}
}
static var last_expression := ""

static var emotions_modifiers := Variables.emotions_modifiers
static var current_emotion_modifier := 0.0

# endregion

# region HELPERS

func get_audio_compensation() -> float:
	return AudioServer.get_time_since_last_mix() \
		- AudioServer.get_output_latency() \
		+ (1 / Engine.get_frames_per_second()) * 2

# endregion

# region EVENT BUS DEBUG

func _ready() -> void:
	for s in get_signal_list():
		self.connect(s.name, _debug_event.bind(s.name))

	self.change_position.connect(_on_change_position)

func _on_change_position(position: String) -> void:
	self.last_position = position

func _debug_event(arg1: Variant, arg2: Variant=null, arg3: Variant=null, arg4: Variant=null, arg5: Variant=null) -> void:
	if not debug_mode:
		return

	var args := [arg1, arg2, arg3, arg4, arg5].filter(func(d: Variant) -> bool: return d != null)

	var eventName: String = args.pop_back()

	# remove audio buffer from debug
	if args.size() > 0:
		if eventName in ["new_speech", "continue_speech", "end_speech"]:
			args[0] = CpHelpers.remove_audio_buffer(args[0].duplicate())

	print_debug(
		"EVENT BUS: `%s` - %s" % [eventName, args]
	)

# endregion
