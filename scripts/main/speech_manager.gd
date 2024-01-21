extends Node

@export var messages := []
var primed := false
var skip_message_id := 0

var current_speech_id := 0
var current_speech_text := ""

func _ready() -> void:
	Globals.ready_for_speech.connect(_on_ready_for_speech)
	Globals.cancel_speech.connect(_on_cancel_speech)

func _process(_delta: float) -> void:
	if not messages.size() or not Globals.is_ready():
		return

	var message = messages.pop_front()
	if message == null:
		printerr("Message is empty on process")
		return

	if message.id == skip_message_id:
		printerr("Skipping message %s - skipped on process" % message.id)
		return

	print("Message ID: ", message.id)
	current_speech_id = message.id
	match message.type:
		"NewSpeech":
			print("NewSpeech: ", message.id)
			skip_message_id = 0
			Globals.new_speech_v2.emit(message)

		"ContinueSpeech":
			print("ContinueSpeech: ", message.id)
			Globals.continue_speech_v2.emit(message)

		"EndSpeech":
			print("EndSpeech: ", message.id)
			Globals.is_speaking = true
			current_speech_id = 0
			Globals.end_speech_v2.emit(message)

		_:
			printerr("Unknown message type: ", message.type)

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
			skip_message_id = 0
			primed = true
			current_speech_text = message.response

		"ContinueSpeech":
			current_speech_text += "\n" + message.response

		"EndSpeech":
			current_speech_id = 0
			primed = false
			current_speech_text += "\n" + message.response

	messages.append(message)
	Globals.push_speech_from_queue.emit(current_speech_text)

func ready_for_new_message() -> bool:
	return current_speech_id == 0 and messages.size() == 0

func _on_ready_for_speech() -> void:
	current_speech_id = 0
	current_speech_text = ""
	skip_message_id = 0

func _on_cancel_speech() -> void:
	skip_message_id = current_speech_id
	messages = messages.filter(func (d): return d.id != current_speech_id)
	primed = false
