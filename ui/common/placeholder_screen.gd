extends Control

signal navigate_requested(screen_name: StringName)

@export var screen_title := "Placeholder"
@export_multiline var description := "This screen will be implemented in a future task."

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel

func _ready() -> void:
	title_label.text = screen_title
	description_label.text = description

func _on_back_button_pressed() -> void:
	navigate_requested.emit(&"main_menu")
