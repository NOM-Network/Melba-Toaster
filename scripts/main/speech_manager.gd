extends Node

var current_speech_id: int
var current_speech_text: String

var skip_message_id := 0

func _ready() -> void:
	Globals.cancel_speech.connect(_on_cancel_speech)

func _process(_delta: float) -> void:
	if MessageQueue.is_empty() or not Globals.is_ready():
		return

	var message = MessageQueue.get_next()
	if message == null:
		return

	if message.id == skip_message_id:
		print("Skipping message ", message.id)
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
	MessageQueue.add(message)

	match message.type:
		"NewSpeech":
			current_speech_text = message.response

		"ContinueSpeech":
			current_speech_text += "\n" + message.response

		"EndSpeech":
			current_speech_text += "\n" + message.response + " [END]"

	Globals.push_speech_from_queue.emit(current_speech_text)

func is_no_more_chunks() -> bool:
	return current_speech_id == 0

func _on_cancel_speech() -> void:
	MessageQueue.remove_by_id(current_speech_id)
	skip_message_id = current_speech_id
	current_speech_id = 0
