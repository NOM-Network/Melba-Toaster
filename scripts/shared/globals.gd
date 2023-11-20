extends Node

# region EVENT BUS

signal play_animation(anim_name: String)
signal set_expression(expression_name: String, enabled: bool)
signal set_toggle(toggle_name: String, enabled: bool)

signal start_singing(song: Dictionary)
signal stop_singing()

signal start_dancing_motion(bpm: float)
signal end_dancing_motion()
signal start_singing_mouth_movement()
signal end_singing_mouth_movement()
signal nudge_model()

signal change_position(name: String)
signal change_scene(scene: String)

signal ready_for_speech()
signal new_speech(prompt: String, text: String)
signal speech_done()
signal cancel_speech()

# endregion

# region SCENE DATA

static var positions := {
	# use Tulpes - [ position, scale ]
	"default": {
		"model": [ Vector2(737, 1124), Vector2(1, 1) ],
		"lower_third": [ Vector2(34, 722), Vector2(1, 1) ],
	},
	"gaming": {
		"model": [ Vector2(240, 1307), Vector2(0.74, 0.74) ],
		"lower_third": [ Vector2(457, 794), Vector2(0.777, 0.777) ],
	},
}

# region LIVE2D DATA

static var toggles := {
	"toast": Toggle.new("Param9", 0.5),
	"void": Toggle.new("Param14", 0.5),
	"tears": Toggle.new("Param20", 0.5),
	"toa": Toggle.new("Param21", 1.0),
	"confused": Toggle.new("Param18", 0.5),
	"gymbag": Toggle.new("Param28", 0.5)
}

static var animations := {
	"end": {"id": -1, "override": "none"},
	"idle1": {"id": 0, "override": "none", "duration": 7}, # Original: 8.067
	"idle2": {"id": 1, "override": "none", "duration": 4}, # Original: 4.267
	"idle3": {"id": 2, "override": "none", "duration": 5}, # Original: 5.367
	"sleep": {"id": 3, "override": "eye_blink", "duration": 10.3}, # Original: 10.3
	"confused": {"id": 4, "override": "eye_blink", "duration": 4.0} # Original: 10
}
static var last_animation := ""

static var expressions := {
	"end": {"id": "none"}
}
static var last_expression := ""

# endregion

# region MELBA STATE

static var is_paused := true
static var is_speaking := false
static var is_singing := false
static var debug_mode := false
static var config := ToasterConfig.new()

# endregion

# region EVENT BUS DEBUG

func _ready() -> void:
	play_animation.connect(func(anim_name): _debug_event("play_animation", {
		"name": anim_name,
	}))
	set_expression.connect(func(expression_name): _debug_event("set_expression", {
		"name": expression_name,
	}))
	set_toggle.connect(func(toggle_name, enabled): _debug_event("set_toggle", {
		"name": toggle_name,
		"enabled": enabled
	}))

	start_singing.connect(func(song): _debug_event("start_singing", {
		"song": song
	}))
	stop_singing.connect(_debug_event.bind("stop_singing"))

	start_dancing_motion.connect(func(bpm): _debug_event("start_dancing_motion", {
		"bpm": bpm
	}))
	end_dancing_motion.connect(_debug_event.bind("end_dancing_motion"))

	start_singing_mouth_movement.connect(_debug_event.bind("start_singing_mouth_movement"))
	end_singing_mouth_movement.connect(_debug_event.bind("end_singing_mouth_movement"))
	nudge_model.connect(_debug_event.bind("nudge_model"))

	change_position.connect(func(position): _debug_event("change_position", {
		"position": position
	}))
	change_scene.connect(func(scene): _debug_event("change_scene", {
		"scene": scene
	}))

	ready_for_speech.connect(_debug_event.bind("ready_for_speech"))
	new_speech.connect(func(prompt, text): _debug_event("new_speech", {
		"prompt": prompt,
		"text": text
	}))
	speech_done.connect(_debug_event.bind("speech_done"))
	cancel_speech.connect(_debug_event.bind("cancel_speech"))

func _debug_event(eventName: String, data: Dictionary = {}) -> void:
	if not debug_mode:
		return

	if data:
		print_debug("EVENT BUS: '%s' called - " % [eventName], data)
	else:
		print_debug("EVENT BUS: '%s' called" % [eventName])

# endregion
