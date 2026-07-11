extends VBoxContainer
class_name PitchingChangeWidget

## Collects pitching-change data for Game Entry Mode.
## This widget does not calculate stats or mutate game state; callers store the
## returned dictionary inside GameEvent.details as canonical event-specific data.

const BASE_KEYS: Array[String] = ["1B", "2B", "3B"]
const OUTGOING_ACTIONS: Array[String] = ["leave_game", "move_to_position", "remain_as_dh_if_ruleset_allows", "unknown"]
const INCOMING_SOURCES: Array[String] = ["enter_from_bench", "move_from_existing_position"]

@onready var context_label: Label = %ContextLabel
@onready var defensive_team_value: Label = %DefensiveTeamValue
@onready var outgoing_pitcher_option: OptionButton = %OutgoingPitcherOption
@onready var outgoing_action_option: OptionButton = %OutgoingActionOption
@onready var old_pitcher_new_position_edit: LineEdit = %OldPitcherNewPositionEdit
@onready var incoming_pitcher_option: OptionButton = %IncomingPitcherOption
@onready var incoming_source_option: OptionButton = %IncomingSourceOption
@onready var new_pitcher_position_edit: LineEdit = %NewPitcherPositionEdit
@onready var responsibility_label: Label = %ResponsibilityLabel

var _context: Dictionary = {}
var _defensive_players: Array = []
var _runner_responsibility: Array = []
var _pending_data: Dictionary = {}

func _ready() -> void:
	_populate_static_options()
	reset()
	if not _pending_data.is_empty():
		set_pitching_change_data(_pending_data)

func setup_context(game_context: Dictionary) -> void:
	_context = game_context.duplicate(true)
	_defensive_players = _as_array(_context.get("defensive_players", []))
	defensive_team_value.text = str(_context.get("defense_team_id", _context.get("defensive_team_id", "")))
	context_label.text = "Inning %s %s • Outs: %s • Current pitcher: %s" % [_context.get("inning", "?"), _context.get("half", _context.get("half_inning", "")), _context.get("outs", 0), _context.get("pitcher_id", _context.get("outgoing_pitcher_id", ""))]
	_populate_player_options()
	_select_option_by_meta(outgoing_pitcher_option, str(_context.get("outgoing_pitcher_id", _context.get("pitcher_id", ""))))
	_runner_responsibility = _build_runner_responsibility()
	_update_responsibility_label()

func get_pitching_change_data() -> Dictionary:
	return {
		"defensive_team_id": str(_context.get("defense_team_id", _context.get("defensive_team_id", ""))),
		"outgoing_pitcher_id": _selected_meta(outgoing_pitcher_option),
		"incoming_pitcher_id": _selected_meta(incoming_pitcher_option),
		"inning": _context.get("inning", null),
		"half_inning": str(_context.get("half", _context.get("half_inning", ""))),
		"outs": int(_context.get("outs", 0)),
		"base_state": _as_dictionary(_context.get("base_state", {})).duplicate(true),
		"runners_on_base": _runners_on_base(),
		"runner_responsibility": _runner_responsibility.duplicate(true),
		"new_pitcher_defensive_position": new_pitcher_position_edit.text.strip_edges(),
		"old_pitcher_new_position": old_pitcher_new_position_edit.text.strip_edges(),
		"outgoing_pitcher_action": _selected_meta(outgoing_action_option),
		"incoming_pitcher_source": _selected_meta(incoming_source_option),
	}

func set_pitching_change_data(data: Dictionary) -> void:
	_pending_data = data.duplicate(true)
	if not is_node_ready():
		return
	_select_option_by_meta(outgoing_pitcher_option, str(data.get("outgoing_pitcher_id", "")))
	_select_option_by_meta(incoming_pitcher_option, str(data.get("incoming_pitcher_id", "")))
	_select_option_by_meta(outgoing_action_option, str(data.get("outgoing_pitcher_action", "unknown")))
	_select_option_by_meta(incoming_source_option, str(data.get("incoming_pitcher_source", "enter_from_bench")))
	new_pitcher_position_edit.text = str(data.get("new_pitcher_defensive_position", "P"))
	old_pitcher_new_position_edit.text = str(data.get("old_pitcher_new_position", ""))
	_runner_responsibility = _as_array(data.get("runner_responsibility", _runner_responsibility))
	_update_responsibility_label()

func reset() -> void:
	_context.clear()
	_defensive_players.clear()
	_runner_responsibility.clear()
	if is_node_ready():
		defensive_team_value.text = "—"
		context_label.text = "Select incoming and outgoing pitcher details."
		new_pitcher_position_edit.text = "P"
		old_pitcher_new_position_edit.text = ""
		_populate_player_options()
		_update_responsibility_label()

func validate() -> Array[String]:
	var issues: Array[String] = []
	if _selected_meta(incoming_pitcher_option).is_empty():
		issues.append("Pitching change requires an incoming pitcher.")
	if _selected_meta(outgoing_action_option) == "move_to_position" and old_pitcher_new_position_edit.text.strip_edges().is_empty():
		issues.append("Outgoing pitcher needs a new defensive position when moving positions.")
	return issues

func _populate_static_options() -> void:
	outgoing_action_option.clear(); incoming_source_option.clear()
	for action in OUTGOING_ACTIONS:
		outgoing_action_option.add_item(action.replace("_", " ").capitalize()); outgoing_action_option.set_item_metadata(outgoing_action_option.item_count - 1, action)
	for source in INCOMING_SOURCES:
		incoming_source_option.add_item(source.replace("_", " ").capitalize()); incoming_source_option.set_item_metadata(incoming_source_option.item_count - 1, source)

func _populate_player_options() -> void:
	for option in [outgoing_pitcher_option, incoming_pitcher_option]:
		option.clear(); option.add_item("(none)"); option.set_item_metadata(0, "")
		for player in _defensive_players:
			var id = str(player.get("id", player.get("player_id", "")))
			option.add_item(str(player.get("display_name", player.get("name", id)))); option.set_item_metadata(option.item_count - 1, id)

func _build_runner_responsibility() -> Array:
	var existing = _as_array(_context.get("runner_responsibility", []))
	var by_runner := {}
	for entry in existing:
		if entry is Dictionary:
			by_runner[str(entry.get("runner_id", ""))] = entry
	var output: Array = []
	var base_state = _as_dictionary(_context.get("base_state", {}))
	var default_pitcher = str(_context.get("outgoing_pitcher_id", _context.get("pitcher_id", "")))
	for base in BASE_KEYS:
		var runner_id = str(base_state.get(base, ""))
		if runner_id.is_empty(): continue
		var entry = Dictionary(by_runner.get(runner_id, {}))
		output.append({"runner_id": runner_id, "responsible_pitcher_id": str(entry.get("responsible_pitcher_id", default_pitcher)), "base": base})
	return output

func _runners_on_base() -> Array:
	var runners: Array = []
	for entry in _runner_responsibility:
		runners.append({"runner_id": str(entry.get("runner_id", "")), "base": str(entry.get("base", ""))})
	return runners

func _update_responsibility_label() -> void:
	if not is_node_ready(): return
	if _runner_responsibility.is_empty():
		responsibility_label.text = "Runner responsibility: none."
		return
	var parts: Array[String] = []
	for entry in _runner_responsibility:
		parts.append("%s on %s charged to %s" % [entry.get("runner_id", ""), entry.get("base", ""), entry.get("responsible_pitcher_id", "")])
	responsibility_label.text = "Runner responsibility preserved: %s." % "; ".join(parts)

func _selected_meta(option: OptionButton) -> String:
	return str(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""

func _select_option_by_meta(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value:
			option.select(index); return

func _as_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _as_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []
