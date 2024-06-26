extends Node
class_name ToasterConfig

var config: ConfigFile
var songs: Array[Song]
var is_ready: bool = false

var SONG_FOLDER_PATH: String

func _init(debug_mode: bool) -> void:
	SONG_FOLDER_PATH = "./dist/songs" if debug_mode else "./songs"

	var config_file: String = "./dist/config/debug.cfg" if debug_mode else "./config/prod.cfg"
	_init_config(config_file)

	init_songs(debug_mode)

func _init_config(config_file: String) -> void:
	print("Loading config from %s..." % config_file)
	config = _load_config_file(config_file)
	is_ready = true

func init_songs(debug_mode: bool) -> void:
	songs = []

	var dir := DirAccess.open(SONG_FOLDER_PATH)
	assert(dir, "There is  %s folder in the project root" % SONG_FOLDER_PATH)

	var song_folders := dir.get_directories()

	for id in song_folders:
		if id.begins_with("_"):
			continue

		var config_path := "%s/%s/config.cfg" % [SONG_FOLDER_PATH, id]
		assert(FileAccess.file_exists(config_path), "No config file for %s" % id)

		var config_file: ConfigFile = _load_config_file(config_path)
		assert(config_file is ConfigFile, "Config file for %s is corrupted" % id)

		for section in config_file.get_sections():
			var song := {}
			for key in config_file.get_section_keys(section):
				song[key] = config_file.get_value(section, key)

			if song.has("test") and not debug_mode:
				continue

			songs.push_back(Song.new(song, debug_mode))

	print("Songs loaded: ", songs.size())

func _load_config_file(filename: String) -> Variant:
	var file: ConfigFile = ConfigFile.new()

	var err: Error = file.load(filename)
	assert(err != Error.ERR_FILE_NOT_FOUND, "Cannot find the config file %s" % filename)

	if err != OK:
		printerr("Failed to load config file %s, error %d, please check the documentation: https://bit.ly/godot-error" % [filename, err])
		printerr("Close the Toaster.")
		return null

	return file

func get_obs(key: String) -> Variant:
	return config.get_value("OBS", key, "")

func get_backend(key: String) -> Variant:
	return config.get_value("backend", key)
