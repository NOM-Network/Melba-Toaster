extends Node

# region EVENT BUS

signal play_animation(anim_name: String)
signal set_expression(expression_name: String, enabled: bool)
signal set_toggle(toggle_name: String, enabled: bool)

signal start_singing(song: Dictionary)
signal stop_singing()

signal start_dancing_motion(bpm: float, wait_time: float, stop_time: float)
signal end_dancing_motion()
signal start_singing_mouth_movement()
signal end_singing_mouth_movement()

signal ready_for_speech()
signal new_speech(prompt: String, text: String)
signal speech_done()
signal cancel_speech()

# endregion

# region LIVE2D DATA

var toggles := {
	"toast": Toggle.new("Param9", 0.5),
	"void": Toggle.new("Param14", 0.5),
	"tears": Toggle.new( "Param20", 0.5),
	"toa": Toggle.new("Param21", 1.0),
	"confused": Toggle.new("Param18", 0.5)
}

var animations := {
	"end": {"id": -1, "override": "none"},
	"idle": {"id": 0, "override": "none"},
	"sleep": {"id": 1, "override": "eye_blink"},
	"confused": {"id": 2, "override": "eye_blink"}
}
var last_animation := ""

var expressions := {
	"end": {"id": "none"}
}
var last_expression := ""

# endregion

# region MELBA STATE

var is_paused := true
var is_speaking := false
var is_singing := false
var debug_mode := true
var config := ToasterConfig.new()

# endregion

func _ready() -> void:
	# region EVENT BUS DEBUG

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

	start_dancing_motion.connect(func(bpm, wait_time, end_time): _debug_event("start_dancing_motion", {
		"bpm": bpm,
		"wait_time": wait_time,
		"end_time": end_time
	}))

	end_dancing_motion.connect(_debug_event.bind("end_dancing_motion"))

	ready_for_speech.connect(_debug_event.bind("ready_for_speech"))

	new_speech.connect(func(prompt, text): _debug_event("new_speech", {
		"prompt": prompt,
		"text": text
	}))

	speech_done.connect(_debug_event.bind("speech_done"))

	cancel_speech.connect(_debug_event.bind("cancel_speech"))

	# endregion

func _debug_event(eventName: String, data: Dictionary = {}) -> void:
	if not debug_mode:
		return

	if data:
		print_debug("EVENT BUS: '%s' called - " % [eventName], data)
	else:
		print_debug("EVENT BUS: '%s' called" % [eventName])

# region HELPERS

func call_delayed(callable: Callable, delay: float):
	get_tree().create_timer(delay).connect("timeout", callable)

# endredion
