extends Node

# region EVENT BUS

signal play_animation(anim_name: String)
signal set_expression(expression_name: String, enabled: bool)
signal set_toggle(toggle_name: String, enabled: bool)
signal pin_asset(asset_name: String, enabled: bool)

signal start_singing(song: Song, seek_time: float)
signal stop_singing()

signal start_dancing_motion(bpm: float)
signal end_dancing_motion()
signal start_singing_mouth_movement()
signal end_singing_mouth_movement()
signal nudge_model()

signal change_position(name: String)
signal change_scene(scene: String)

signal ready_for_speech()
signal new_speech()
signal continue_speech()
signal start_speech()
signal speech_done()
signal cancel_speech()
signal reset_subtitles()

# Speech Manager
signal ready_for_speech_v2()
signal new_speech_v2(data: Dictionary)
signal speech_player_free_v2()
signal continue_speech_v2(data: Dictionary)
signal end_speech_v2(data: Dictionary)
signal push_speech_from_queue(response: String)
signal stop_speech_v2()
signal cancel_speech_v2()

signal update_backend_stats(data: Array)

# endregion

# region MELBA STATE

@export var debug_mode := OS.is_debug_build()
@export var config := ToasterConfig.new(debug_mode)

@export var is_paused := true
@export var is_speaking := false
@export var is_singing := false
@export var dancing_bpm := 0.0

@export var show_beats := debug_mode
@export var fixed_scene := false

@export var time_before_cleanout := 20.0
@export var time_before_next_response := 1.0

func is_ready() -> bool:
	return not (is_speaking or is_singing)

# endregion

# region SCENE DATA

static var default_position := "default"
static var last_position := default_position
static var default_model_position := [ Vector2(737, 1124), Vector2(1, 1) ]
static var default_lower_third_position := [ Vector2(35, 682), Vector2(1, 1) ]

static var positions := {
	# use Tulpes - [ position, scale ]
	"intro": {}, # placeholder for intro animation

	"under": {
		"model": [ Vector2(737, 2036), Vector2(1, 1) ],
		"lower_third": default_lower_third_position,
	},

	"default": {
		"model": default_model_position,
		"lower_third": default_lower_third_position,
	},

	"gaming": {
		"model": [ Vector2(1700, 1300), Vector2(0.74, 0.74) ],
		"lower_third": [ Vector2(35, 800), Vector2(0.777, 0.777) ],
	},

	"close": {
		"model": [ Vector2(812, 1537), Vector2(1.6, 1.6) ],
		"lower_third": default_lower_third_position,
	},

	"fullsreen": {
		"model": [ Vector2(950, 2988), Vector2(3.6, 3.6) ],
		"lower_third": default_lower_third_position,
	},

	"full_height": {
		"model": [ Vector2(829, 544), Vector2(0.55, 0.55) ],
		"lower_third": default_lower_third_position,
	}
}

static var scale_change := Vector2(0.05, 0.05)

# region LIVE2D DATA

static var pinnable_assets := {
	"censor": PinnableAsset.new("censor", "CensorAnimation", "Nose", Vector2(0, -40), 0, 4),
	"glasses": PinnableAsset.new("glasses", "GlassSprites", "Nose", Vector2(5, -40), 0, 4)
}

static var toggles := {
	"toast": Toggle.new("Param9", 0.5),
	"void": Toggle.new("Param14", 0.5),
	"tears": Toggle.new("Param20", 0.5),
	"toa": Toggle.new("Param21", 1.0),
	"confused": Toggle.new("Param18", 0.5),
	"gymbag": Toggle.new("Param28", 0.5, true)
}

static var animations := {
	"idle1": Live2DAnimation.new(0, 7), # Original: 8.067
	"idle2": Live2DAnimation.new(1, 4), # Original: 4.267
	"idle3": Live2DAnimation.new(2, 5), # Original: 5.367
	"sleep": Live2DAnimation.new(3, 10.3, true), # Original: 10.3
	"confused": Live2DAnimation.new(4, 4.0, true)  # Original: 10
}
static var last_animation := ""

static var expressions := {
	"end": {"id": "none"}
}
static var last_expression := ""

static var emotions_modifiers := {
	"fear": -0.3,
	"anger": -0.5,
	"anticipation": 0.0,
	"trust": 0.0,
	"surprise": 0.5,
	"positive": 0.5,
	"negative": -0.5,
	"sadness": -0.1,
	"disgust": -0.5,
	"joy": 0.0
}
static var current_emotion_modifier = 0.0

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

func _on_change_position(position: String):
	self.last_position = position

func _debug_event(arg1, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> void:
	if not debug_mode:
		return

	var args := [arg1, arg2, arg3, arg4, arg5].filter(func (d): return d != null)

	var eventName = args.pop_back()

	# remove audio buffer from debug
	if args.size() > 0:
		if eventName in ["new_speech_v2", "continue_speech_v2", "end_speech_v2"]:
			args[0] = CpHelpers.remove_audio_buffer(args[0].duplicate())

	print_debug(
		"EVENT BUS: `%s` - %s" % [eventName, args]
	)

# endregion
