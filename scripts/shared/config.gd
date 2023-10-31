extends Node
class_name ToasterConfig

var config: ConfigFile
var songs: Array

func _init() -> void:
	config = _load_config_file("prod")

	var songs_list := _load_config_file("songs")
	for section in songs_list.get_sections():
		var song := {}
		for key in songs_list.get_section_keys(section):
			song[key] = songs_list.get_value(section, key)
		songs.push_back(song)

	print_debug("Songs loaded: ", songs)

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
