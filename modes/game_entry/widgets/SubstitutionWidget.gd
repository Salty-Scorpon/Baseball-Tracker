extends VBoxContainer
class_name SubstitutionWidget

## Collects substitution data for Game Entry Mode.
## This widget only returns event-specific data for GameEvent.details; callers
## are responsible for committing the canonical event and applying lineup state.

const SUBSTITUTION_TYPES: Array[String] = ["pinch_hitter", "pinch_runner", "defensive_substitution", "position_change", "batting_order_replacement"]
const POSITION_CHANGE_TYPES: Array[String] = ["position_change"]
const NO_PLAYER_OUT_TYPES: Array[String] = ["position_change"]
const NO_PLAYER_IN_TYPES: Array[String] = ["position_change"]
const BASE_KEYS: Array[String] = ["1B", "2B", "3B"]

@onready var context_label: Label = %ContextLabel
@onready var team_option: OptionButton = %TeamOption
@onready var substitution_type_option: OptionButton = %SubstitutionTypeOption
@onready var player_out_option: OptionButton = %PlayerOutOption
@onready var player_in_option: OptionButton = %PlayerInOption
@onready var inning_spin: SpinBox = %InningSpin
@onready var half_option: OptionButton = %HalfOption
@onready var batting_order_slot_spin: SpinBox = %BattingOrderSlotSpin
@onready var old_position_edit: LineEdit = %OldPositionEdit
@onready var new_position_edit: LineEdit = %NewPositionEdit
@onready var affects_batting_order_check: CheckBox = %AffectsBattingOrderCheck
@onready var inherited_runner_label: Label = %InheritedRunnerLabel
@onready var notes_edit: TextEdit = %NotesEdit

var _context: Dictionary = {}
var _players_by_team: Dictionary = {}
var _pending_data: Dictionary = {}

func _ready() -> void:
	_populate_static_options()
	reset()
	if not _pending_data.is_empty():
		set_substitution_data(_pending_data)

func setup_context(game_context: Dictionary) -> void:
	_context = game_context.duplicate(true)
	_players_by_team.clear()
	_players_by_team[str(_context.get("offense_team_id", ""))] = _as_array(_context.get("offensive_lineup", []))
	_players_by_team[str(_context.get("defense_team_id", ""))] = _as_array(_context.get("defensive_players", []))
	_populate_team_options()
	inning_spin.value = int(_context.get("inning", 1))
	_select_option_by_meta(half_option, str(_context.get("half", _context.get("half_inning", "top"))))
	_select_default_team_for_type()
	_update_context_label()
	_update_player_options()
	_update_type_defaults()

func get_substitution_data() -> Dictionary:
	var data = {
		"team_id": _selected_meta(team_option),
		"substitution_type": _selected_meta(substitution_type_option),
		"player_out_id": _selected_meta(player_out_option),
		"player_in_id": _selected_meta(player_in_option),
		"inning": int(inning_spin.value),
		"half_inning": _selected_meta(half_option),
		"batting_order_slot": int(batting_order_slot_spin.value),
		"old_position": old_position_edit.text.strip_edges(),
		"new_position": new_position_edit.text.strip_edges(),
		"affects_batting_order": affects_batting_order_check.button_pressed,
		"notes": notes_edit.text.strip_edges(),
	}
	if str(data.get("substitution_type", "")) == "pinch_runner":
		data["runner_state"] = _runner_state_for(str(data.get("player_out_id", "")))
	return data

func set_substitution_data(data: Dictionary) -> void:
	_pending_data = data.duplicate(true)
	if not is_node_ready(): return
	_select_option_by_meta(substitution_type_option, str(data.get("substitution_type", "pinch_hitter")))
	_select_option_by_meta(team_option, str(data.get("team_id", "")))
	_update_player_options()
	_select_option_by_meta(player_out_option, str(data.get("player_out_id", "")))
	_select_option_by_meta(player_in_option, str(data.get("player_in_id", "")))
	inning_spin.value = int(data.get("inning", _context.get("inning", 1)))
	_select_option_by_meta(half_option, str(data.get("half_inning", _context.get("half", "top"))))
	batting_order_slot_spin.value = int(data.get("batting_order_slot", 1))
	old_position_edit.text = str(data.get("old_position", ""))
	new_position_edit.text = str(data.get("new_position", ""))
	affects_batting_order_check.button_pressed = bool(data.get("affects_batting_order", true))
	notes_edit.text = str(data.get("notes", ""))
	_update_type_defaults(false)

func reset() -> void:
	_context.clear()
	_players_by_team.clear()
	if is_node_ready():
		context_label.text = "Select substitution details."
		_populate_team_options()
		_populate_player_options(player_out_option, [])
		_populate_player_options(player_in_option, [])
		inning_spin.value = 1
		_select_option_by_meta(half_option, "top")
		batting_order_slot_spin.value = 1
		old_position_edit.text = ""
		new_position_edit.text = ""
		affects_batting_order_check.button_pressed = true
		notes_edit.text = ""
		_update_inherited_runner_label()

func validate() -> Array[String]:
	var issues: Array[String] = []
	var type = _selected_meta(substitution_type_option)
	if _selected_meta(team_option).is_empty(): issues.append("Substitution requires a team.")
	if type.is_empty(): issues.append("Substitution requires a type.")
	if not NO_PLAYER_OUT_TYPES.has(type) and _selected_meta(player_out_option).is_empty(): issues.append("%s requires a player leaving/replaced." % type)
	if not NO_PLAYER_IN_TYPES.has(type) and _selected_meta(player_in_option).is_empty(): issues.append("%s requires a player entering." % type)
	if type == "pinch_runner" and _runner_state_for(_selected_meta(player_out_option)).is_empty(): issues.append("Pinch runner requires the replaced runner to be on base.")
	if type in ["position_change", "defensive_substitution"] and new_position_edit.text.strip_edges().is_empty(): issues.append("%s requires a new defensive position." % type)
	return issues

func _populate_static_options() -> void:
	substitution_type_option.clear(); half_option.clear()
	for type in SUBSTITUTION_TYPES:
		substitution_type_option.add_item(type.replace("_", " ").capitalize()); substitution_type_option.set_item_metadata(substitution_type_option.item_count - 1, type)
	for half in ["top", "bottom"]:
		half_option.add_item(half.capitalize()); half_option.set_item_metadata(half_option.item_count - 1, half)
	substitution_type_option.item_selected.connect(func(_i: int) -> void: _update_type_defaults())
	team_option.item_selected.connect(func(_i: int) -> void: _update_player_options())
	player_out_option.item_selected.connect(func(_i: int) -> void:
		_update_slot_from_player_out()
		_update_inherited_runner_label()
	)

func _populate_team_options() -> void:
	team_option.clear()
	for team_id in [str(_context.get("offense_team_id", "")), str(_context.get("defense_team_id", ""))]:
		if team_id.is_empty() or _has_meta(team_option, team_id): continue
		team_option.add_item(team_id); team_option.set_item_metadata(team_option.item_count - 1, team_id)

func _update_player_options() -> void:
	var players: Array = _as_array(_players_by_team.get(_selected_meta(team_option), []))
	_populate_player_options(player_out_option, players)
	_populate_player_options(player_in_option, players)
	_update_slot_from_player_out()
	_update_inherited_runner_label()

func _populate_player_options(option: OptionButton, players: Array) -> void:
	option.clear(); option.add_item("(none)"); option.set_item_metadata(0, "")
	for player in players:
		var id = str(player.get("id", player.get("player_id", "")))
		option.add_item(str(player.get("display_name", player.get("name", id)))); option.set_item_metadata(option.item_count - 1, id)

func _update_type_defaults(update_team: bool = true) -> void:
	var type = _selected_meta(substitution_type_option)
	if update_team: _select_default_team_for_type()
	affects_batting_order_check.button_pressed = type in ["pinch_hitter", "pinch_runner", "batting_order_replacement"]
	player_out_option.disabled = NO_PLAYER_OUT_TYPES.has(type)
	player_in_option.disabled = NO_PLAYER_IN_TYPES.has(type)
	batting_order_slot_spin.editable = type != "position_change"
	_update_player_options()
	_update_context_label()

func _select_default_team_for_type() -> void:
	var type = _selected_meta(substitution_type_option)
	var default_team = str(_context.get("defense_team_id", "")) if type in ["defensive_substitution", "position_change"] else str(_context.get("offense_team_id", ""))
	_select_option_by_meta(team_option, default_team)

func _update_slot_from_player_out() -> void:
	var players: Array = _as_array(_players_by_team.get(_selected_meta(team_option), []))
	var player_id = _selected_meta(player_out_option)
	for index in range(players.size()):
		var player: Dictionary = players[index]
		if str(player.get("id", player.get("player_id", ""))) == player_id:
			batting_order_slot_spin.value = index + 1
			return

func _runner_state_for(player_id: String) -> Dictionary:
	if player_id.is_empty(): return {}
	var base_state = _as_dictionary(_context.get("base_state", {}))
	for base in BASE_KEYS:
		if str(base_state.get(base, "")) == player_id:
			return {"runner_id": player_id, "base": base}
	return {}

func _update_inherited_runner_label() -> void:
	if not is_node_ready(): return
	var runner_state = _runner_state_for(_selected_meta(player_out_option))
	inherited_runner_label.text = "Pinch runner base inheritance: %s" % ("none" if runner_state.is_empty() else "%s on %s" % [runner_state.get("runner_id", ""), runner_state.get("base", "")])

func _update_context_label() -> void:
	context_label.text = "Inning %s %s • Type: %s" % [inning_spin.value, _selected_meta(half_option), _selected_meta(substitution_type_option)]

func _selected_meta(option: OptionButton) -> String:
	return str(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""
func _select_option_by_meta(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value:
			option.select(index); return
func _has_meta(option: OptionButton, value: String) -> bool:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value: return true
	return false
func _as_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
func _as_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []
