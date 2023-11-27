extends Control

# Controls
@onready var prompt := $Prompt
@onready var subtitles := $Subtitles

# Defaults
var prompt_font_size: int
var subtitles_font_size: int

# Tweens
@onready var tweens := {}

func _ready() -> void:
	# Defaults
	prompt_font_size = prompt.label_settings.font_size
	subtitles_font_size = subtitles.label_settings.font_size

	# Signals
	Globals.reset_subtitles.connect(_on_reset_subtitles)
	Globals.reset_subtitles.emit()

# region SIGNAL CALLBACKS

func _on_reset_subtitles() -> void:
	clear_subtitles()
	prompt.visible_ratio = 1.0
	subtitles.visible_ratio = 1.0

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
	prompt.label_settings.font_size = prompt_font_size
	subtitles.label_settings.font_size = subtitles_font_size

# endregion

# region PRIVATE FUNCTIONS

func _print(node: Label, text := "", duration := 0.0):
	node.text = "%s" % text

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
