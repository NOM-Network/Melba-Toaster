extends Node
class_name Song

const FOLDER_PATH := 'res://assets/songs/%s/%s'

var id: String
var path: String
var artist: String
var song_name: String
var full_name: String
var wait_time: float
var mute_voice: bool
var reverb: bool
var subtitles: bool

func _init(
	p_data: Dictionary
):
	self.id = p_data.id
	self.artist = p_data.artist
	self.song_name = p_data.name
	self.wait_time = p_data.wait_time
	self.mute_voice = p_data.mute_voice
	self.reverb = p_data.reverb
	self.subtitles = p_data.subtitles

	self.full_name = "%s%s%s" % [p_data.artist, "%s", p_data.name]

	self.path = FOLDER_PATH % [p_data.id, "%s.mp3"]

	assert(
		ResourceLoader.exists(self.path % "song") and ResourceLoader.exists(self.path % "voice"),
		"SONG: Files for %s are not found!" % self.id
	)

func load_subtitles_file() -> Variant:
	if not subtitles:
		return null

	var p = FOLDER_PATH % [id, "subtitles.txt"]
	if not FileAccess.file_exists(p):
		printerr("No subtitles found in %s" % p)
		return null

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

func load(type: String) -> AudioStreamMP3:
	var p: String = self.path % type

	assert(ResourceLoader.exists(p), "No audio file %s" % p)
	return load(p)
