extends Control

signal navigate_requested(screen_name: StringName)

func _on_data_entry_button_pressed() -> void:
	navigate_requested.emit(&"data_entry")

func _on_game_entry_button_pressed() -> void:
	navigate_requested.emit(&"game_entry")

func _on_data_viewing_button_pressed() -> void:
	navigate_requested.emit(&"data_viewing")

func _on_import_export_button_pressed() -> void:
	navigate_requested.emit(&"import_export")

func _on_settings_button_pressed() -> void:
	navigate_requested.emit(&"settings")
