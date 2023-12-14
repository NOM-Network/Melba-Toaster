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
signal new_speech(prompt: String, text: String, emotions: Array)
signal start_speech()
signal speech_done()
signal cancel_speech()
signal reset_subtitles()

signal update_backend_stats(data: Array)

# endregion

# region SCENE DATA

static var default_position := "default"
static var last_position := "default"
static var default_model_position := [ Vector2(737, 1124), Vector2(1, 1) ]
static var default_lower_third_position := [ Vector2(35, 682), Vector2(1, 1) ]

static var positions := {
	# use Tulpes - [ position, scale ]
	"intro": {}, # placeholder for intro animation

	"intro_start": {
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

	"full": {
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
	"idle3": Live2DAnimation.new(2, 5, "EyeBlink"), # Original: 5.367
	"sleep": Live2DAnimation.new(3, 10.3, "EyeBlink"), # Original: 10.3
	"confused": Live2DAnimation.new(4, 4.0, "EyeBlink")  # Original: 10
}
static var last_animation := ""

static var expressions := {
	"end": {"id": "none"}
}
static var last_expression := ""

# endregion

# region MELBA STATE

static var debug_mode := OS.is_debug_build()
static var config := ToasterConfig.new(debug_mode)

static var is_paused := true
static var is_speaking := false
static var is_singing := false
static var dancing_bpm := 0.0

static var show_beats := debug_mode
static var fixed_scene := false

static var time_before_cleanout := 5.0
static var time_before_speech := 3.0

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

	print_debug(
		"EVENT BUS: `%s` - %s" % [eventName, args]
	)

# endregion
