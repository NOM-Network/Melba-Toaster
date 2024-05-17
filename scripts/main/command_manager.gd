extends Node

func execute(command_string: String) -> void:
	var command: Array = command_string.to_lower().split(" ")

	match command:
		["sing", var song_name]:
			_sing(song_name)

		["pause"]:
			_pause()

		["unpause"]:
			_unpause()

		_:
			print("Unknown command: %s" % command)

func _pause() -> void:
	Globals.is_paused = true

func _unpause() -> void:
	Globals.is_paused = false

	if Globals.is_ready():
		Globals.ready_for_speech.emit()

func _sing(song_name: String) -> void:
	var next_song: Song
	for song in Globals.config.songs:
		if song.id.begins_with(song_name):
			next_song = song
			break

	if not next_song:
		print("Could not find song %s" % song_name)
		return

	print("Waiting for speech to end...")
	Globals.is_paused = true
	await Globals.end_speech

	print("Singing %s..." % song_name)
	await get_tree().create_timer(2.0).timeout

	Globals.start_singing.emit(next_song, 0.0)
