extends Node
class_name ToasterConfig

var config: ConfigFile
var songs: Array[Song]

var SONG_FOLDER_PATH: String

func _init(debug_mode: bool) -> void:
	SONG_FOLDER_PATH = "./dist/songs/" if debug_mode else "./songs/"

	_init_config()

	init_songs(debug_mode)

func _init_config():
	config = _load_config_file("./config/prod.cfg")
	assert(config is ConfigFile, "No config present!")

func init_songs(debug_mode: bool):
	songs = []

	var dir := DirAccess.open(SONG_FOLDER_PATH)
	assert(dir, "There is no %s folder in the project root" % SONG_FOLDER_PATH)

	var song_folders := dir.get_directories()

	for id in song_folders:
		if id.begins_with("_"):
			continue

		var config_path := "%s/%s/config.cfg" % [SONG_FOLDER_PATH, id]
		assert(FileAccess.file_exists(config_path), "No config file for %s" % id)
		var config_file = _load_config_file(config_path)

		for section in config_file.get_sections():
			var song := {}
			for key in config_file.get_section_keys(section):
				song[key] = config_file.get_value(section, key)

			if song.has("test") and not debug_mode:
				continue

			songs.push_back(Song.new(song, debug_mode))

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
