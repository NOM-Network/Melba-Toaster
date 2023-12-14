extends Control

# Controls
@onready var prompt := $Prompt
@onready var subtitles := $Subtitles
@onready var cleanout_timer := $ClearSubtitlesTimer
@onready var print_timer := $PrintTimer

# Defaults
@onready var default_font_size := {
	"Prompt": prompt.label_settings.font_size,
	"Subtitles": subtitles.label_settings.font_size,
}

# Tweens
@onready var tweens := {}

# Current prompt data
var current_subtitle_text := []
var current_duration := 0.0

func _ready() -> void:
	# Signals
	Globals.reset_subtitles.connect(_on_reset_subtitles)
	Globals.start_speech.connect(_on_start_speech)
	Globals.start_singing.connect(_on_start_singing.unbind(2))
	Globals.cancel_speech.connect(_on_cancel_speech)
	Globals.speech_done.connect(_on_speech_done)

	cleanout_timer.timeout.connect(_on_clear_subtitles_timer_timeout)
	print_timer.one_shot = true

	Globals.reset_subtitles.emit()


func _process(delta: float) -> void:
	if not print_timer.is_stopped():
		var current_time: float = current_duration - print_timer.time_left
		for token in current_subtitle_text:
			var time_check := current_time + delta
			if current_subtitle_text[0][1] == "STOP":
				print_timer.stop()
				return

			if time_check >= current_subtitle_text[0][0]:
				var text: String = current_subtitle_text.pop_front()[1]
				if not text.length():
					return

				subtitles.text += text

				subtitles.label_settings.font_size = default_font_size[subtitles.name]
				while subtitles.get_line_count() > subtitles.get_visible_line_count():
					subtitles.label_settings.font_size -= 1

# region SIGNAL CALLBACKS

func _on_reset_subtitles() -> void:
	clear_subtitles()

func _on_start_speech() -> void:
	cleanout_timer.stop()

func _on_start_singing() -> void:
	clear_subtitles()
	cleanout_timer.stop()

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
	text = text.strip_edges()
	if not text:
		return

	prompt.text = text
	prompt.label_settings.font_size = default_font_size[prompt.name]
	while prompt.get_line_count() > prompt.get_visible_line_count():
		prompt.label_settings.font_size -= 1

	_tween_visible_ratio(prompt, prompt.name, 0.0, 1.0, duration)

func set_subtitles(text: String, duration := 0.0) -> void:
	subtitles.text = ""
	print_timer.stop()

	text = text.strip_edges()
	if not text:
		return

	var time_per_symbol = duration / text.length()

	current_duration = duration
	current_subtitle_text = []

	var tokenized_text = text.split(" ")
	var time := 0.0
	for i in tokenized_text.size():
		time += time_per_symbol * tokenized_text[i].length()
		current_subtitle_text.push_back([time, tokenized_text[i] + " "])
		if i != tokenized_text.size():
			time += time_per_symbol
			current_subtitle_text.push_back([time, ""])
	current_subtitle_text.push_back([duration, "STOP"])

	print_timer.start(duration)

func set_subtitles_fast(text: String) -> void:
	subtitles.text = text
	subtitles.label_settings.font_size = default_font_size["Subtitles"]

func clear_subtitles() -> void:
	prompt.text = ""
	subtitles.text = ""

	prompt.label_settings.font_size = default_font_size["Prompt"]
	subtitles.label_settings.font_size = default_font_size["Subtitles"]

	prompt.visible_ratio = 1.0

	current_subtitle_text = []
	current_duration = 0.0
	print_timer.stop()

# endregion

# region PRIVATE FUNCTIONS

func start_clear_subtitles_timer() -> void:
	cleanout_timer.wait_time = Globals.time_before_cleanout
	cleanout_timer.start()


func _tween_visible_ratio(label: Label, tween_name: String, start_val: float, final_val: float, duration: float) -> void:
	if tweens.has(tween_name):
		tweens[tween_name].kill()

	label.visible_ratio = start_val

	tweens[tween_name] = create_tween()
	tweens[tween_name].tween_property(label, "visible_ratio", final_val, duration - duration * 0.01)

# endregion
