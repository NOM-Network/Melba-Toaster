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

		["goodbyes"]:
			_goodbyes()

		_:
			print("Unknown command ", command)

func _pause() -> void:
	Globals.is_paused = true

func _unpause() -> void:
	Globals.is_paused = false

	if Globals.is_ready():
		Globals.ready_for_speech.emit()

func _sing(song_name: String) -> void:
	Globals.queue_next_song.emit(song_name, 0)

func _goodbyes() -> void:
	Globals.obs_action.emit("toggle_scene_source", "Goodbyes")
