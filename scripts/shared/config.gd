extends Node
class_name ToasterConfig

var config: ConfigFile
var songs: Array[Dictionary]

var song_path = 'res://assets/songs/%s/'

func _init() -> void:
	config = _load_config_file("prod")

	var list := _load_config_file("songs")
	for section in list.get_sections():
		var song := {}
		for key in list.get_section_keys(section):
			song[key] = list.get_value(section, key)
			song["path"] = song_path % list.get_value(section, "id") + '%s.mp3'

		if not FileAccess.file_exists(song.path % "song") \
			or not FileAccess.file_exists(song.path % "voice"):
			printerr("No song files found for %s" % song.id)
			continue

		if song.subtitles:
			song.subtitles = _load_subtitles_file(song_path % song.id)

		songs.push_back(song)

	print_debug("Songs loaded: ", songs.size())

func _load_subtitles_file(path: String) -> Variant:
	if not FileAccess.file_exists(path + "subtitles.txt"):
		printerr("No subtitles found in %s" % path)
		return null

	var file := FileAccess.open(path + "subtitles.txt", FileAccess.READ)
	var subtitles := []
	while not file.eof_reached():
		var file_line := file.get_line()
		var line := file_line.split("\t")

		if line[0] == "":
			continue

		subtitles.push_back([
			line[0].to_float(),
			line[2]
		])

	return subtitles

func _load_config_file(filename: String) -> ConfigFile:
	var file := ConfigFile.new()
	var err := file.load("res://config/%s.cfg" % [filename])

	if (err) != OK:
		printerr(err)

	return file

func get_obs(key: String) -> Variant:
	return config.get_value("OBS", key)

func get_backend(key: String) -> Variant:
	return config.get_value("backend", key)
