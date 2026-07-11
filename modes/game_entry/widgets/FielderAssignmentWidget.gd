extends VBoxContainer
class_name FielderAssignmentWidget

## Reusable fielder assignment widget for expanded Game Entry templates.
##
## This widget only gathers event-specific fielding data. Callers should store
## the returned dictionary in GameEvent.details (for example,
## details["fielders"] or details["fielder_assignment"]) when creating or
## editing canonical game-log events. It intentionally does not calculate stats.

const CONTEXT_GROUNDOUT := "groundout"
const CONTEXT_FLYOUT := "flyout"
const CONTEXT_DOUBLE_PLAY := "double_play"
const CONTEXT_CUSTOM := "custom"

const PRESETS := {
	CONTEXT_GROUNDOUT: ["6-3", "4-3", "5-3", "1-3", "3U", "custom"],
	CONTEXT_FLYOUT: ["F7", "F8", "F9", "F6", "custom"],
	CONTEXT_DOUBLE_PLAY: ["6-4-3", "4-6-3", "5-4-3", "3-6-3", "1-2-3", "custom"],
	CONTEXT_CUSTOM: ["custom"],
}

const POSITION_LABELS := {
	"1": "P",
	"2": "C",
	"3": "1B",
	"4": "2B",
	"5": "3B",
	"6": "SS",
	"7": "LF",
	"8": "CF",
	"9": "RF",
}

const DEFAULT_FIELDER_DATA := {
	"preset": "",
	"putout_fielder_id": "",
	"assist_fielder_ids": [],
	"primary_fielder_id": "",
	"fielding_notes": "",
}

@onready var context_label: Label = %ContextLabel
@onready var preset_option: OptionButton = %PresetOption
@onready var primary_option: OptionButton = %PrimaryFielderOption
@onready var primary_manual_edit: LineEdit = %PrimaryManualEdit
@onready var putout_option: OptionButton = %PutoutFielderOption
@onready var putout_manual_edit: LineEdit = %PutoutManualEdit
@onready var assist_options_container: VBoxContainer = %AssistOptionsContainer
@onready var assist_manual_edit: LineEdit = %AssistManualEdit
@onready var notes_edit: TextEdit = %NotesEdit
@onready var warning_label: Label = %WarningLabel

var _context := CONTEXT_GROUNDOUT
var _defensive_players: Array = []
var _assist_option_buttons: Array[OptionButton] = []
var _pending_data := DEFAULT_FIELDER_DATA.duplicate(true)

func _ready() -> void:
	preset_option.item_selected.connect(_on_preset_selected)
	setup_defense(_defensive_players)
	set_context(_context)
	set_fielder_data(_pending_data)

func setup_defense(defensive_players: Array) -> void:
	_defensive_players = defensive_players.duplicate(true)
	if not is_node_ready():
		return
	_populate_player_option(primary_option)
	_populate_player_option(putout_option)
	_rebuild_assist_options()
	_apply_preset_to_fields(_selected_preset())

func set_context(context: String) -> void:
	_context = _normalize_context(context)
	if not is_node_ready():
		return
	if is_instance_valid(context_label):
		context_label.text = "Context: %s" % _context.capitalize()
	if not is_instance_valid(preset_option):
		return
	var previous_preset := _selected_preset()
	preset_option.clear()
	for preset in PRESETS.get(_context, PRESETS[CONTEXT_CUSTOM]):
		preset_option.add_item(preset)
	_select_option(preset_option, previous_preset)
	if preset_option.selected < 0 and preset_option.item_count > 0:
		preset_option.select(0)
	_apply_preset_to_fields(_selected_preset())

func get_fielder_data() -> Dictionary:
	var preset := _selected_preset()
	var assist_ids: Array = []
	for option in _assist_option_buttons:
		var fielder_id := _selected_player_id(option)
		if not fielder_id.is_empty() and not assist_ids.has(fielder_id):
			assist_ids.append(fielder_id)
	for manual_id in _split_manual_ids(assist_manual_edit.text):
		if not assist_ids.has(manual_id):
			assist_ids.append(manual_id)
	return {
		"preset": preset,
		"putout_fielder_id": _fielder_value(putout_option, putout_manual_edit),
		"assist_fielder_ids": assist_ids,
		"primary_fielder_id": _fielder_value(primary_option, primary_manual_edit),
		"fielding_notes": notes_edit.text.strip_edges(),
	}

func set_fielder_data(data: Dictionary) -> void:
	_pending_data = DEFAULT_FIELDER_DATA.duplicate(true)
	_pending_data.merge(data, true)
	if not is_node_ready():
		return
	_select_option(preset_option, str(_pending_data["preset"]))
	_apply_preset_to_fields(_selected_preset())
	_set_fielder_value(primary_option, primary_manual_edit, str(_pending_data["primary_fielder_id"]))
	_set_fielder_value(putout_option, putout_manual_edit, str(_pending_data["putout_fielder_id"]))
	var assists: Array = _pending_data.get("assist_fielder_ids", [])
	for index in range(_assist_option_buttons.size()):
		var value := str(assists[index]) if index < assists.size() else ""
		_set_player_option_value(_assist_option_buttons[index], value)
	assist_manual_edit.text = _manual_values_not_in_lineup(assists)
	notes_edit.text = str(_pending_data["fielding_notes"])
	_update_warning()

func reset() -> void:
	set_fielder_data(DEFAULT_FIELDER_DATA)

func validate() -> Array[String]:
	var warnings: Array[String] = []
	var data := get_fielder_data()
	if str(data["preset"]).is_empty():
		warnings.append("No fielding preset selected.")
	var assist_ids: Array = data["assist_fielder_ids"]
	if str(data["primary_fielder_id"]).is_empty() and str(data["putout_fielder_id"]).is_empty() and assist_ids.is_empty():
		warnings.append("No fielder assignment entered; this is allowed as unknown fielder data.")
	if str(data["putout_fielder_id"]).is_empty():
		warnings.append("Putout fielder is unknown.")
	return warnings

func _on_preset_selected(_index: int) -> void:
	_apply_preset_to_fields(_selected_preset())

func _apply_preset_to_fields(preset: String) -> void:
	if not is_node_ready():
		return
	var parsed := _parse_preset(preset)
	_set_fielder_value(primary_option, primary_manual_edit, parsed.get("primary", ""))
	_set_fielder_value(putout_option, putout_manual_edit, parsed.get("putout", ""))
	var assists: Array = parsed.get("assists", [])
	for index in range(_assist_option_buttons.size()):
		_set_player_option_value(_assist_option_buttons[index], str(assists[index]) if index < assists.size() else "")
	assist_manual_edit.text = ""
	_update_warning()

func _parse_preset(preset: String) -> Dictionary:
	if preset == "custom" or preset.is_empty():
		return {"primary": "", "putout": "", "assists": []}
	if preset.begins_with("F"):
		var caught_by := _player_id_for_position(preset.substr(1))
		return {"primary": caught_by, "putout": caught_by, "assists": []}
	if preset.ends_with("U"):
		var unassisted := _player_id_for_position(preset.substr(0, preset.length() - 1))
		return {"primary": unassisted, "putout": unassisted, "assists": []}
	var parts := preset.split("-", false)
	var ids: Array[String] = []
	for part in parts:
		ids.append(_player_id_for_position(part))
	if ids.is_empty():
		return {"primary": "", "putout": "", "assists": []}
	return {"primary": ids[0], "putout": ids[ids.size() - 1], "assists": ids.slice(0, max(0, ids.size() - 1))}

func _normalize_context(context: String) -> String:
	var normalized := context.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if PRESETS.has(normalized):
		return normalized
	return CONTEXT_CUSTOM

func _rebuild_assist_options() -> void:
	for child in assist_options_container.get_children():
		child.queue_free()
	_assist_option_buttons.clear()
	for index in range(3):
		var option := OptionButton.new()
		option.name = "AssistFielderOption%d" % (index + 1)
		_populate_player_option(option)
		assist_options_container.add_child(option)
		_assist_option_buttons.append(option)

func _populate_player_option(option: OptionButton) -> void:
	if not is_instance_valid(option):
		return
	option.clear()
	option.add_item("Unknown / manual", -1)
	for player in _defensive_players:
		if not player is Dictionary:
			continue
		var player_id := str(player.get("id", player.get("player_id", ""))).strip_edges()
		if player_id.is_empty():
			continue
		option.add_item(_player_label(player), option.item_count)
		option.set_item_metadata(option.item_count - 1, player_id)

func _player_id_for_position(position_number: String) -> String:
	var position_label := POSITION_LABELS.get(position_number, position_number)
	for player in _defensive_players:
		if not player is Dictionary:
			continue
		var positions: Array = _as_string_array(player.get("positions", []))
		positions.append(str(player.get("position", "")))
		if positions.has(position_label) or positions.has(position_number):
			return str(player.get("id", player.get("player_id", "")))
	return ""

func _player_label(player: Dictionary) -> String:
	var player_id := str(player.get("id", player.get("player_id", "")))
	var name := str(player.get("display_name", player.get("name", player_id)))
	var number := str(player.get("jersey_number", ""))
	var position := str(player.get("position", ""))
	if position.is_empty() and player.get("positions", []) is Array and not Array(player["positions"]).is_empty():
		position = str(Array(player["positions"])[0])
	var suffix := ""
	if not number.is_empty():
		suffix += " #%s" % number
	if not position.is_empty():
		suffix += " (%s)" % position
	return "%s%s" % [name, suffix]

func _as_string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(str(item))
	elif not str(value).is_empty():
		result.append(str(value))
	return result

func _fielder_value(option: OptionButton, manual_edit: LineEdit) -> String:
	var manual := manual_edit.text.strip_edges()
	if not manual.is_empty():
		return manual
	return _selected_player_id(option)

func _selected_player_id(option: OptionButton) -> String:
	if option.selected < 0:
		return ""
	var metadata: Variant = option.get_item_metadata(option.selected)
	return str(metadata).strip_edges() if metadata != null else ""

func _set_fielder_value(option: OptionButton, manual_edit: LineEdit, value: String) -> void:
	manual_edit.text = ""
	if not _set_player_option_value(option, value) and not value.strip_edges().is_empty():
		manual_edit.text = value.strip_edges()

func _set_player_option_value(option: OptionButton, value: String) -> bool:
	var normalized := value.strip_edges()
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == normalized:
			option.select(index)
			return true
	option.select(0)
	return normalized.is_empty()

func _selected_preset() -> String:
	if not is_instance_valid(preset_option) or preset_option.selected < 0:
		return ""
	return preset_option.get_item_text(preset_option.selected)

func _select_option(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if option.get_item_text(index) == value:
			option.select(index)
			return
	if option.item_count > 0:
		option.select(0)

func _split_manual_ids(text: String) -> Array[String]:
	var ids: Array[String] = []
	for raw_part in text.replace(";", ",").split(",", false):
		var value := raw_part.strip_edges()
		if not value.is_empty():
			ids.append(value)
	return ids

func _manual_values_not_in_lineup(values: Array) -> String:
	var manual_values: Array[String] = []
	for value in values:
		var fielder_id := str(value).strip_edges()
		if fielder_id.is_empty():
			continue
		var found := false
		for player in _defensive_players:
			if player is Dictionary and str(player.get("id", player.get("player_id", ""))) == fielder_id:
				found = true
				break
		if not found:
			manual_values.append(fielder_id)
	return ", ".join(manual_values)

func _update_warning() -> void:
	if is_instance_valid(warning_label):
		warning_label.text = "\n".join(validate())
