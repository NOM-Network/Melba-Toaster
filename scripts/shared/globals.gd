extends Node

# region EVENT BUS

signal play_animation(anim_name: String)
signal set_expression(expression_name: String, enabled: bool)
signal set_toggle(toggle_name: String, enabled: bool)
signal incoming_speech(stream: PackedByteArray)
signal cancel_speech()

# endregion

# region LIVE2D DATA

var toggles := {
	"toast": {"param": null, "enabled": false},
	"void": {"param": null, "enabled": false}
}

var animations := {
	"sampleAnimation": {"id": "Sample"}
}

var expressions := {
	"sampleExpression": {"id": "Sample", "enabled": false}
}

# endregion

func _ready() -> void:
	# region EVENT BUS DEBUG

	play_animation.connect(func(anim_name): _debug_event("play_animation", {
		"name": anim_name
	}))

	set_expression.connect(func(expression_name, enabled): _debug_event("set_expression", {
		"name": expression_name,
		"enabled": enabled
	}))

	set_toggle.connect(func(toggle_name, enabled): _debug_event("set_toggle", {
		"name": toggle_name,
		"enabled": enabled
	}))

	incoming_speech.connect(func(stream): _debug_event("set_toggle", {
		"stream": stream.size()
	}))

	cancel_speech.connect(_debug_event.bind("cancel_speech"))

	# endregion

func _debug_event(eventName: String, data: Dictionary = {}) -> void:
	if data:
		print_debug("EVENT BUS: '%s' called - " % [eventName], data)
	else:
		print_debug("EVENT BUS: '%s' called" % [eventName])
