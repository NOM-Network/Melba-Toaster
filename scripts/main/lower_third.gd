extends Control

# Controls
@onready var prompt := $Prompt
@onready var subtitles := $Subtitles
@onready var timer := $ClearSubtitlesTimer

# Defaults
@onready var default_font_size := {
	"Prompt": prompt.label_settings.font_size,
	"Subtitles": subtitles.label_settings.font_size,
}

# Tweens
@onready var tweens := {}

func _ready() -> void:
	# Signals
	Globals.reset_subtitles.connect(_on_reset_subtitles)
	Globals.start_speech.connect(_on_start_speech)
	Globals.start_singing.connect(_on_start_singing.unbind(2))
	Globals.cancel_speech.connect(_on_cancel_speech)
	Globals.speech_done.connect(_on_speech_done)

	timer.timeout.connect(_on_clear_subtitles_timer_timeout)

	Globals.reset_subtitles.emit()

# region SIGNAL CALLBACKS

func _on_reset_subtitles() -> void:
	clear_subtitles()

func _on_start_speech() -> void:
	timer.stop()

func _on_start_singing() -> void:
	timer.stop()

func _on_cancel_speech() -> void:
	if not Globals.is_speaking:
		start_clear_subtitles_timer()

func _on_speech_done() -> void:
	start_clear_subtitles_timer()

func _on_clear_subtitles_timer_timeout() -> void:
	clear_subtitles()

# endregion

# region PUBLIC FUNCTIONS

func set_prompt(text: String, duration := 0.0) -> void:
	_print(prompt, text, duration)

func set_subtitles(text: String, duration := 0.0) -> void:
	_print(subtitles, text, duration)

func set_subtitles_fast(text: String) -> void:
	subtitles.text = text
	subtitles.visible_ratio = 1.0

func clear_subtitles() -> void:
	prompt.text = ""
	subtitles.text = ""

	prompt.label_settings.font_size = default_font_size["Prompt"]
	subtitles.label_settings.font_size = default_font_size["Subtitles"]

	prompt.visible_ratio = 1.0
	subtitles.visible_ratio = 1.0

# endregion

# region PRIVATE FUNCTIONS

func start_clear_subtitles_timer() -> void:
	timer.wait_time = Globals.time_before_cleanout
	timer.start()

func _print(node: Label, text := "", duration := 0.0):
	node.text = "%s" % text

	node.label_settings.font_size = default_font_size[node.name]
	while node.get_line_count() > node.get_visible_line_count():
		node.label_settings.font_size -= 1

	_tween_visible_ratio(node, node.name, 0.0, 1.0, duration)

func _tween_visible_ratio(label: Label, tween_name: String, start_val: float, final_val: float, duration: float) -> void:
	if tweens.has(tween_name):
		tweens[tween_name].kill()

	label.visible_ratio = start_val

	tweens[tween_name] = create_tween()
	tweens[tween_name].tween_property(label, "visible_ratio", final_val, duration - duration * 0.01)

# endregion
