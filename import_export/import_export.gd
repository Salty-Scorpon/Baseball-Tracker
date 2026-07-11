extends Control

signal navigate_requested(screen_name: StringName)

const CsvImporterScript = preload("res://import_export/CsvImporter.gd")
const SaveManagerScript = preload("res://data/saving/save_manager.gd")

@onready var import_text: TextEdit = %ImportText
@onready var result_label: Label = %ResultLabel
@onready var import_button: Button = %ImportButton
@onready var back_button: Button = %BackButton

var repository: DataRepository

func _ready() -> void:
	repository = SaveManagerScript.load_project()
	if repository == null:
		repository = SaveManagerScript.new_project()
	import_button.pressed.connect(_on_import_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	if import_text.text.strip_edges().is_empty():
		import_text.text = "team_name,region,jersey_number,player_name,position,bats,throws,grade\nOsaka Toin,Osaka,1,Taro Yamada,P,R,R,3\nOsaka Toin,Osaka,2,Ken Sato,C,L,R,2"

func _on_import_button_pressed() -> void:
	var importer = CsvImporterScript.new()
	var result = importer.import_text(repository, import_text.text)
	if not result.errors.is_empty():
		result_label.text = "Import failed:\n%s" % "\n".join(result.errors)
		return
	var err = SaveManagerScript.save_project(repository)
	if err != OK:
		result_label.text = "Import created data but save failed: %d" % err
		return
	var lines = PackedStringArray()
	lines.append("Import complete.")
	lines.append("Teams created: %d" % result.teams_created.size())
	lines.append("Teams reused: %d" % result.teams_reused.size())
	lines.append("Players created: %d" % result.players_created.size())
	if not result.warnings.is_empty():
		lines.append("Warnings:")
		lines.append_array(result.warnings)
	result_label.text = "\n".join(lines)

func _on_back_button_pressed() -> void:
	navigate_requested.emit(&"main_menu")
