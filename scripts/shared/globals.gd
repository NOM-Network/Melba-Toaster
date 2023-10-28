extends Node

# region EVENT BUS

signal play_animation(anim_name: String)
signal set_expression(expression_name: String, enabled: bool)
signal set_toggle(toggle_name: String, enabled: bool)

signal ready_for_speech()
signal incoming_speech(stream: PackedByteArray)
signal new_speech(prompt: String, text: String)
signal speech_done()
signal cancel_speech()

# endregion

# region LIVE2D DATA

var toggles := {
	"toast": {"param": null, "enabled": false, "opacity": null},
	"void": {"param": null, "enabled": false}
}

var animations := {
	"end": {"id": -1, "override": "none"},
	"idle": {"id": 0, "override": "none"},
	"sleep": {"id": 1, "override": "eye_blink"}
}
var last_animation := ""

var expressions := {
	"sampleExpression": {"id": "Sample"}
}
var last_expression := ""

# endregion

# region MELBA STATE

var is_speaking := false
var is_paused := false
var current_audio: AudioStreamMP3

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

	incoming_speech.connect(func(stream): _debug_event("set_toggle", {
		"stream": stream.size()
	}))

	new_speech.connect(func(prompt, text): _debug_event("new_speech", {
		"prompt": prompt,
		"text": text
	}))

	cancel_speech.connect(_debug_event.bind("cancel_speech"))

	# endregion

func _debug_event(eventName: String, data: Dictionary = {}) -> void:
	if data:
		print_debug("EVENT BUS: '%s' called - " % [eventName], data)
	else:
		print_debug("EVENT BUS: '%s' called" % [eventName])
