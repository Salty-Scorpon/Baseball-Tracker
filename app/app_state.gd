extends Node

signal mode_changed(mode_name: String)

var current_mode: StringName = &"main_menu"

func set_mode(mode_name: StringName) -> void:
	current_mode = mode_name
	mode_changed.emit(String(mode_name))
