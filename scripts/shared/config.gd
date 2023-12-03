extends Node
class_name ToasterConfig

var config: ConfigFile
var songs: Array[Song]

func _init(debug_mode: bool) -> void:
	config = _load_config_file("res://config/prod.cfg")
	assert(config is ConfigFile, "No config present!")

	var list = _load_config_file("res://assets/songs/songs.cfg")
	if not list:
		print("No songs were loaded")
		return

	for section in list.get_sections():
		var song := {}
		for key in list.get_section_keys(section):
			song[key] = list.get_value(section, key)

		if song.has("test") and not debug_mode:
			continue

		songs.push_back(Song.new(song))

	print("Songs loaded: ", songs.size())

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
