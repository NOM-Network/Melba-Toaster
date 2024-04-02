extends Node

@export var messages: Array[Dictionary] = []
var primed := false
var skip_message_id := 0

var current_speech_id := 0
var current_speech_text := ""
var emotions_array: Array[String] = []

func _ready() -> void:
	Globals.ready_for_speech.connect(_on_ready_for_speech)
	Globals.cancel_speech.connect(_on_cancel_speech)

func _process(_delta: float) -> void:
	if not messages.size() or not Globals.is_ready():
		return

	var message: Dictionary = messages.pop_front()
	if not message:
		printerr("Message is empty on process")
		return

	if message.id == skip_message_id:
		printerr("Skipping message %s - skipped on process" % message.id)
		return

	print("Message ID: ", message.id)
	current_speech_id = message.id

	if message.has("emotions"):
		_process_emotions(message.emotions)
		message.emotions = emotions_array

	match message.type:
		"NewSpeech":
			print("NewSpeech: ", message.id)
			skip_message_id = 0

			if message.response == '<filtered>':
				Globals.end_speech.emit()
			else:
				Globals.new_speech.emit(message)

		"ContinueSpeech":
			print("ContinueSpeech: ", message.id)
			Globals.continue_speech.emit(message)

		"EndSpeech":
			print("EndSpeech: ", message.id)
			current_speech_id = 0
			Globals.end_speech.emit()

		_:
			printerr("Unknown message type: ", message.type)
			return

func push_message(message: Dictionary) -> void:
	if not primed:
		if message.type == "EndSpeech":
			skip_message_id = 0
			current_speech_id = 0
			return
		elif message.type != "NewSpeech":
			printerr("Skipping %s message %s - not primed on push" % [message.type, message.id])
			return

	if message.id == skip_message_id:
		printerr("Skipping %s message %s - skipped on push" % [message.type, message.id])
		return

	match message.type:
		"NewSpeech":
			messages = []
			skip_message_id = 0
			primed = true
			current_speech_text = message.response

		"ContinueSpeech":
			current_speech_text += "\n" + message.response

		"EndSpeech":
			current_speech_id = 0
			primed = false
			current_speech_text += " [END]"

	messages.append(message)
	Globals.push_speech_from_queue.emit(current_speech_text, emotions_array)

func ready_for_new_message() -> bool:
	return current_speech_id == 0 and messages.size() == 0

func _on_ready_for_speech() -> void:
	reset_speech()

func reset_speech() -> void:
	current_speech_id = 0
	current_speech_text = ""
	emotions_array = []
	skip_message_id = 0

func _on_cancel_speech() -> void:
	skip_message_id = current_speech_id
	messages = []
	primed = false

func _process_emotions(emotions: Array) -> void:
	if not emotions:
		return

	var max_emotion: Array = ["anger", - 1.0]

	for emotion: String in emotions:
		if not Globals.emotions_modifiers.has(emotion):
			printerr("Unknown emotion: %s" % emotion)
			return

		if Globals.emotions_modifiers[emotion] > max_emotion[1]:
			max_emotion = [emotion, Globals.emotions_modifiers[emotion]]

	Globals.current_emotion_modifier = max_emotion[1]
	emotions_array.push_back(max_emotion[0])

	for toggle: String in ["tears", "void"]:
		Globals.set_toggle.emit(toggle, Globals.toggles[toggle].default_state)

	match max_emotion[0]:
		"disappointment", "fear", "grief", "sadness":
			Globals.set_toggle.emit("tears", true)

		"anger", "disgust", "grief":
			Globals.set_toggle.emit("void", true)
