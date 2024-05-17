extends Node

func execute(command_string: String) -> void:
	var command: Array = command_string.split(" ")

	match command:
		["sing", var song_name]:
			_sing(song_name.to_lower())

		["pause"]:
			_pause()

		["unpause"]:
			_unpause()

		["scene", ..]:
			var scene_name: String = command.reduce(
				func(acc: String, word: String) -> String: return acc + " " + word, ""
			)
			scene_name = scene_name.strip_edges().trim_prefix("scene ")
			Globals.change_scene.emit(scene_name)

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

	print("Singing %s..." % song_name)
	if not Globals.is_ready():
		await Globals.end_speech
		await get_tree().create_timer(2.0).timeout

	Globals.start_singing.emit(next_song, 0.0)
