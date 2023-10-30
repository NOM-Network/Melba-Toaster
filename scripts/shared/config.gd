extends Node
class_name ToasterConfig

var config := ConfigFile.new()

func _init() -> void:
	var err = config.load("res://config/prod.cfg")
	if (err) != OK:
		printerr(err)
		return

func get_obs(key: String) -> Variant:
	return config.get_value("OBS", key)

func get_backend(key: String) -> Variant:
	return config.get_value("backend", key)
