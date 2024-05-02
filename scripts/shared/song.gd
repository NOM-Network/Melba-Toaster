extends Node
class_name Song

var FOLDER_PATH: String

var id: String
var path: String
var song_name: String
var full_name: String
var short_name: String
var wait_time: float
var mute_voice: bool = true
var reverb: bool = false

func _init(
	p_data: Dictionary,
	debug_mode: bool
) -> void:
	FOLDER_PATH = './dist/songs/%s/%s' if debug_mode else './songs/%s/%s'

	self.id = p_data.id
	self.song_name = p_data.name
	self.wait_time = p_data.wait_time

	if p_data.has("mute_voice"):
		self.mute_voice = p_data.mute_voice

	if p_data.has("reverb"):
		self.reverb = p_data.reverb

	if p_data.has("artist"):
		self.full_name = "%s - %s" % [p_data.artist, p_data.name]
	else:
		self.full_name = p_data.name

	if p_data.has("feat"):
		self.full_name += " %s" % p_data.feat

	if p_data.has("short_name"):
		self.short_name = p_data.short_name

	self.path = FOLDER_PATH % [p_data.id, "%s.ogg"]

	assert(
		FileAccess.file_exists(self.path % "song") and FileAccess.file_exists(self.path % "voice"),
		"SONG: Files for %s are not found!" % self.id
	)

func load_subtitles_file() -> Variant:
	var p: String = FOLDER_PATH % [id, "subtitles.txt"]
	if not FileAccess.file_exists(p):
		printerr("No subtitles found in %s" % p)
		return []

	var file := FileAccess.open(p, FileAccess.READ)
	var sub := []
	while not file.eof_reached():
		var file_line := file.get_line()
		var line := file_line.split("\t")

		if line[0] == "":
			continue

		sub.push_back([
			line[0] as float,
			line[2]
		])

	return sub

func load(type: String) -> AudioStreamOggVorbis:
	var p: String = self.path % type
	assert(FileAccess.file_exists(p), "No audio file found in %s" % p)

	var file := FileAccess.open(p, FileAccess.READ)
	return AudioStreamOggVorbis.load_from_buffer(file.get_buffer(file.get_length()))

func get_song_ui_name() -> String:
	return self.short_name if self.short_name else self.song_name
