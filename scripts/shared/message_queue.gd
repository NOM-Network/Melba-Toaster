extends Node

@export var messages := []

func remove_by_id(id: int) -> void:
	messages = messages.filter(func (d): return d.id != id)

func add(message: Dictionary) -> void:
	messages.push_back(message)

func get_next() -> Dictionary:
	return messages.pop_front()

func is_empty() -> bool:
	return messages.size() == 0

func clear() -> void:
	messages.clear()

func size() -> int:
	return messages.size()
