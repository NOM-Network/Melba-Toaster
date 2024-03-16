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
var time_per_symbol := 0.0

func _ready() -> void:
	# Signals
	Globals.reset_subtitles.connect(_on_reset_subtitles)
	Globals.start_speech.connect(_on_start_speech)
	Globals.continue_speech.connect(_on_continue_speech)
	Globals.speech_done.connect(_on_speech_done)
	Globals.cancel_speech.connect(_on_cancel_speech)

	Globals.ready_for_speech.connect(_on_ready_for_speech)

	cleanout_timer.timeout.connect(_on_clear_subtitles_timer_timeout)

	Globals.reset_subtitles.emit()

	Globals.change_position.connect(_on_change_position)

	Globals.start_singing.connect(_on_start_singing)
	Globals.stop_singing.connect(_on_stop_singing)

func _process(delta: float) -> void:
	if not print_timer.is_stopped():
		var current_time: float = current_duration + (time_per_symbol * 3) - print_timer.time_left
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

				# Auto toggles
				var search_string := text.strip_edges().to_lower()
				var unwanted_chars := [".", ",", ":", "?", "!", ";", "-"]

				var result := ""
				for c in unwanted_chars:
					result = search_string.replace(c, "")

				if result.begins_with("toachan"):
					if randf() < 0.33:
						Globals.set_toggle.emit("toa", true)

				subtitles.label_settings.font_size = default_font_size[subtitles.name]
				while subtitles.get_line_count() > subtitles.get_visible_line_count():
					subtitles.label_settings.font_size -= 1

# region SIGNAL CALLBACKS

func _on_reset_subtitles() -> void:
	clear_subtitles()

func _on_start_speech() -> void:
	cleanout_timer.stop()

func _on_continue_speech(_data: Dictionary) -> void:
	cleanout_timer.stop()

func _on_speech_done() -> void:
	_start_clear_subtitles_timer()

func _on_start_singing(song: Song, seek_time:=0.0) -> void:
	clear_subtitles()
	cleanout_timer.stop()

	set_prompt(song.full_name, 0.0 if seek_time else song.wait_time)

func _on_cancel_speech() -> void:
	if not Globals.is_speaking:
		_start_clear_subtitles_timer()

func _on_clear_subtitles_timer_timeout() -> void:
	clear_subtitles()

func _on_ready_for_speech() -> void:
	Globals.set_toggle.emit("toa", false)

# endregion

# region PUBLIC FUNCTIONS

func set_prompt(text: String, duration:=0.0) -> void:
	prompt.text = ""
	text = text.strip_edges()
	if not text:
		return

	if text == "random":
		return

	prompt.text = text
	prompt.label_settings.font_size = default_font_size[prompt.name]
	while prompt.get_line_count() > prompt.get_visible_line_count():
		prompt.label_settings.font_size -= 1

	_tween_visible_ratio(prompt, prompt.name, 0.0, 1.0, duration)

func set_subtitles(text: String, duration:=0.0, continue_print:=false) -> void:
	if not continue_print:
		subtitles.text = ""
	print_timer.stop()

	text = text.strip_edges(true)
	if not text:
		return

	time_per_symbol = (duration - 0.5) / text.length()

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

	# Fix last token not appearing at the end
	current_subtitle_text[- 1] = [duration - time_per_symbol, current_subtitle_text[- 1][1]]
	current_subtitle_text.push_back([duration, "STOP"])

	print_timer.start(duration)

func set_subtitles_fast(text: String) -> void:
	subtitles.text = text.strip_edges(false, true)
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

func _start_clear_subtitles_timer() -> void:
	cleanout_timer.wait_time = Globals.time_before_cleanout
	cleanout_timer.start()

func _tween_visible_ratio(label: Label, tween_name: String, start_val: float, final_val: float, duration: float) -> void:
	if tweens.has(tween_name):
		tweens[tween_name].kill()

	label.visible_ratio = start_val

	tweens[tween_name] = create_tween()
	tweens[tween_name].tween_property(label, "visible_ratio", final_val, duration - duration * 0.01)

func _on_change_position(new_position: String) -> void:
	new_position = new_position.to_snake_case()

	if not Globals.positions.has(new_position):
		printerr("Position %s does not exist" % new_position)
		return

	var positions: Dictionary = Globals.positions[new_position]

	# "model" positions are handled in the model script
	match new_position:
		"intro":
			return

		_:
			var pos = positions.lower_third

			if tweens.has("lower_third"):
				tweens.lower_third.kill()

			tweens.lower_third = create_tween().set_trans(Tween.TRANS_QUINT)
			tweens.lower_third.set_parallel()
			tweens.lower_third.tween_property(self, "position", pos[0], 1)
			tweens.lower_third.tween_property(self, "scale", pos[1], 1)

# endregion

func _on_stop_singing() -> void:
	clear_subtitles()
