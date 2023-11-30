extends Node
class_name ToasterConfig

var config: ConfigFile
var songs: Array[Dictionary]

var song_folder_path = 'res://assets/songs/%s/'

func _init(debug_mode: bool) -> void:
	config = _load_config_file("res://config/prod.cfg")

	var list = _load_config_file("res://assets/songs/songs.cfg")
	if not list:
		print("Songs loaded: ", songs.size())
		return

	for section in list.get_sections():
		var song := {}
		for key in list.get_section_keys(section):
			song[key] = list.get_value(section, key)
			song["path"] = song_folder_path % list.get_value(section, "id") + '%s.mp3'

		if not ResourceLoader.exists(song.path % "song") \
			or not ResourceLoader.exists(song.path % "voice"):
			printerr("No song files found for %s" % song.id)
			continue

		if song.has("test") and not debug_mode:
			continue

		songs.push_back(song)

	print("Songs loaded: ", songs.size())

func load_subtitles_file(id: String) -> Variant:
	var path = song_folder_path % id
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
			line[0] as float,
			line[2]
		])

	return subtitles

func _load_config_file(filename: String) -> Variant:
	var file := ConfigFile.new()

	var err := file.load(filename)
	if (err) != OK:
		printerr("Config file %s is corrupted, error %d" % [filename, err])
		return null

	return file

func get_obs(key: String) -> Variant:
	return config.get_value("OBS", key)

func get_backend(key: String) -> Variant:
	return config.get_value("backend", key)
