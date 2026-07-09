extends Control

const MAIN_MENU_SCENE := preload("res://modes/main_menu/main_menu.tscn")
const SCENES := {
	&"main_menu": preload("res://modes/main_menu/main_menu.tscn"),
	&"data_entry": preload("res://modes/data_entry/data_entry.tscn"),
	&"game_entry": preload("res://modes/game_entry/game_entry.tscn"),
	&"data_viewing": preload("res://modes/data_viewing/data_viewing.tscn"),
	&"import_export": preload("res://import_export/import_export.tscn"),
	&"settings": preload("res://modes/settings/settings.tscn"),
}

@onready var content_root: Control = %ContentRoot

var current_screen: Control

func _ready() -> void:
	show_screen(&"main_menu")

func show_screen(screen_name: StringName) -> void:
	if not SCENES.has(screen_name):
		push_warning("Unknown screen requested: %s" % screen_name)
		return

	if current_screen:
		current_screen.queue_free()

	current_screen = SCENES[screen_name].instantiate()
	content_root.add_child(current_screen)
	AppState.set_mode(screen_name)

	if current_screen.has_signal("navigate_requested"):
		current_screen.navigate_requested.connect(show_screen)
