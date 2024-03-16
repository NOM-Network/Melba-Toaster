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

@export var green_screen := false

func is_ready() -> bool:
	return not (is_speaking or is_singing)

# endregion

# region SCENE DATA

static var default_position := "default"
static var last_position := default_position
static var default_model_position := Vector2(740, 1160)
static var default_model_scale := 0.33
static var default_lower_third_position := [Vector2(35, 682), Vector2(1, 1)]

static var positions := {
	# use Tulpes - [ position, scale ]
	"intro": {}, # placeholder for intro animation

	"under": {
		"model": [Vector2(740, 2080), 0.33],
		"lower_third": default_lower_third_position,
	},

	"default": {
		"model": [default_model_position, default_model_scale],
		"lower_third": default_lower_third_position,
	},

	"gaming": {
		"model": [Vector2(1680, 1420), 0.3],
		"lower_third": [Vector2(35, 800), Vector2(0.777, 0.777)],
	},

	"close": {
		"model": [Vector2(740, 1500), 0.5],
		"lower_third": default_lower_third_position,
	},

	"fullscreen": {
		"model": [Vector2(920, 3265), 1.35],
		"lower_third": default_lower_third_position,
	},

	"full_height": {
		"model": [Vector2(740, 520), 0.15],
		"lower_third": default_lower_third_position,
	},

	"collab": {
		"model": [default_model_position - Vector2(300, 0), default_model_scale],
		"lower_third": [Vector2(35, 800), Vector2(0.777, 0.777)],
	}
}

static var scale_change := 0.05
static var rotation_change := 5.0

# region LIVE2D DATA

static var pinnable_assets := {
	"censor": PinnableAsset.new("CensorAnimation", "Nose", Vector2(0, -120), 1.5),
	"glasses": PinnableAsset.new("GlassSprites", "Nose", Vector2(10, -110), 1.1),
	"hat": PinnableAsset.new("Hat", "ArtMesh67", Vector2(150, 100), 1.1),
	"band": PinnableAsset.new("TetoBand", "ArtMesh30", Vector2( - 75, 70), 1.0)
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
	"confused": Live2DAnimation.new(4, 4.0, true) # Original: 10
}
static var last_animation := ""

static var expressions := {
	"end": {"id": "none"}
}
static var last_expression := ""

static var emotions_modifiers := {
    # Negative
	"anger": - 1.0,
		"disappointment": - 0.5,
		"disgust": - 0.5,
		"embarrassment": - 0.3,
		"fear": - 0.3,
		"grief": - 0.3,
		"annoyance": - 0.1,
		"confusion": - 0.1,
		"sadness": - 0.1,

	# Neutral
		"admiration": 0.0,
		"approval": 0.0,
		"caring": 0.0,
		"curiosity": 0.0,
		"desire": 0.0,
		"disapproval": 0.0,
		"gratitude": 0.0,
		"nervousness": 0.0,
		"pride": 0.0,
		"realization": 0.0,
		"relief": 0.0,
		"remorse": 0.0,
		"neutral": 0.0,
	"anticipation": 0.0,

	# Positive
		"amusement": 0.5,
		"excitement": 0.5,
		"joy": 0.5,
		"love": 0.5,
		"surprise": 0.5,
		"optimism": 0.1,
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

func _debug_event(arg1, arg2=null, arg3=null, arg4=null, arg5=null) -> void:
	if not debug_mode:
		return

	var args := [arg1, arg2, arg3, arg4, arg5].filter(func(d): return d != null)

	var eventName = args.pop_back()

	# remove audio buffer from debug
	if args.size() > 0:
		if eventName in ["new_speech", "continue_speech", "end_speech"]:
			args[0] = CpHelpers.remove_audio_buffer(args[0].duplicate())

	print_debug(
		"EVENT BUS: `%s` - %s" % [eventName, args]
	)

# endregion
