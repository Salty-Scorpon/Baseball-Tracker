extends VBoxContainer
class_name DefensiveChangeWizard

## Collects a grouped defensive change for Game Entry Mode.
## The returned dictionary is event-specific data for GameEvent.details.

signal changed

const CHANGE_TYPES: Array[String] = ["position_change", "player_replacement", "player_leaves_game", "bench_player_enters"]
const REQUIRED_POSITIONS: Array[String] = ["P", "C", "1B", "2B", "3B", "SS", "LF", "CF", "RF"]
const POSITION_OPTIONS: Array[String] = ["", "P", "C", "1B", "2B", "3B", "SS", "LF", "CF", "RF", "DH"]

@onready var context_label: Label = %ContextLabel
@onready var team_option: OptionButton = %TeamOption
@onready var rows_container: VBoxContainer = %RowsContainer
@onready var validation_label: Label = %ValidationLabel
@onready var add_position_button: Button = %AddPositionButton
@onready var add_replacement_button: Button = %AddReplacementButton
@onready var add_leave_button: Button = %AddLeaveButton
@onready var add_enter_button: Button = %AddEnterButton

var _context: Dictionary = {}
var _players_by_team: Dictionary = {}
var _rows: Array[Dictionary] = []
var _pending_data: Dictionary = {}

func _ready() -> void:
	add_position_button.pressed.connect(func() -> void: _add_change_row({"change_type": "position_change"}))
	add_replacement_button.pressed.connect(func() -> void: _add_change_row({"change_type": "player_replacement"}))
	add_leave_button.pressed.connect(func() -> void: _add_change_row({"change_type": "player_leaves_game"}))
	add_enter_button.pressed.connect(func() -> void: _add_change_row({"change_type": "bench_player_enters"}))
	_populate_team_options()
	if not _pending_data.is_empty():
		set_defensive_change_data(_pending_data)
	else:
		_add_change_row({"change_type": "player_replacement"})

func setup_context(game_context: Dictionary) -> void:
	_context = game_context.duplicate(true)
	_players_by_team.clear()
	_players_by_team[str(_context.get("defense_team_id", _context.get("defensive_team_id", "")))] = _as_array(_context.get("defensive_players", []))
	_populate_team_options()
	_select_option_by_meta(team_option, str(_context.get("defense_team_id", _context.get("defensive_team_id", ""))))
	context_label.text = "Grouped defensive change • Inning %s %s" % [_context.get("inning", "?"), _context.get("half", _context.get("half_inning", ""))]
	_refresh_player_options()
	_update_validation_label()

func get_defensive_change_data() -> Dictionary:
	return {"team_id": _selected_meta(team_option), "changes": _collect_changes()}

func set_defensive_change_data(data: Dictionary) -> void:
	_pending_data = data.duplicate(true)
	if not is_node_ready(): return
	_select_option_by_meta(team_option, str(data.get("team_id", "")))
	for child in rows_container.get_children(): child.queue_free()
	_rows.clear()
	for change in _as_array(data.get("changes", [])):
		_add_change_row(_as_dictionary(change))
	if _rows.is_empty():
		_add_change_row({"change_type": "player_replacement"})
	_update_validation_label()

func validate() -> Array[String]:
	var issues: Array[String] = []
	for message in validate_alignment():
		issues.append("%s: %s" % [str(message.get("severity", "warning")).capitalize(), str(message.get("message", ""))])
	return issues

func validate_alignment() -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	var data = get_defensive_change_data()
	if str(data.get("team_id", "")).is_empty():
		messages.append(_warning("team_id", "Choose the defensive team for the grouped change."))
	if _as_array(data.get("changes", [])).is_empty():
		messages.append(_warning("changes", "Add at least one defensive change."))
	var change_position_counts = {}
	for change in _as_array(data.get("changes", [])):
		var new_position = str(_as_dictionary(change).get("new_position", ""))
		if new_position.is_empty(): continue
		change_position_counts[new_position] = int(change_position_counts.get(new_position, 0)) + 1
		if int(change_position_counts[new_position]) > 1:
			messages.append(_warning("changes.new_position", "Two players are assigned to %s." % new_position))
	var alignment = _projected_alignment(data)
	var position_to_player = {}
	var player_to_positions = {}
	for position in alignment.keys():
		var player_id = str(alignment[position])
		if player_id.is_empty(): continue
		if position_to_player.has(position):
			messages.append(_warning("alignment.%s" % position, "Two players are assigned to %s." % position))
		position_to_player[position] = player_id
		if not player_to_positions.has(player_id): player_to_positions[player_id] = []
		player_to_positions[player_id].append(position)
	for position in REQUIRED_POSITIONS:
		if str(alignment.get(position, "")).is_empty():
			messages.append(_warning("alignment.%s" % position, "Required position %s is empty." % position))
	for player_id in player_to_positions.keys():
		if _as_array(player_to_positions[player_id]).size() > 1:
			messages.append(_warning("alignment.%s" % player_id, "%s appears in multiple positions: %s." % [_player_label(player_id), ", ".join(player_to_positions[player_id])]))
	var slot_map = {}
	for change in _as_array(data.get("changes", [])):
		var slot = str(_as_dictionary(change).get("batting_order_slot", "")).strip_edges()
		if slot.is_empty() or slot == "0": continue
		if slot_map.has(slot):
			messages.append(_warning("batting_order_slot.%s" % slot, "Batting order slot %s has two active players in this group." % slot))
		slot_map[slot] = true
	return messages

func _add_change_row(data: Dictionary) -> void:
	var panel = PanelContainer.new()
	var grid = GridContainer.new(); grid.columns = 2; panel.add_child(grid)
	var row = {"panel": panel}
	_add_label(grid, "Change type"); var type_option = _option(CHANGE_TYPES, str(data.get("change_type", "player_replacement")), true); grid.add_child(type_option); row["change_type"] = type_option
	_add_label(grid, "Player changed / out"); var out_option = _player_option(str(data.get("player_out_id", data.get("player_id", "")))); grid.add_child(out_option); row["player_out"] = out_option
	_add_label(grid, "Player in"); var in_option = _player_option(str(data.get("player_in_id", ""))); grid.add_child(in_option); row["player_in"] = in_option
	_add_label(grid, "Old position"); var old_option = _option(POSITION_OPTIONS, str(data.get("old_position", ""))); grid.add_child(old_option); row["old_position"] = old_option
	_add_label(grid, "New position"); var new_option = _option(POSITION_OPTIONS, str(data.get("new_position", ""))); grid.add_child(new_option); row["new_position"] = new_option
	_add_label(grid, "Batting order slot"); var slot = SpinBox.new(); slot.min_value = 0; slot.max_value = 99; slot.step = 1; slot.value = int(data.get("batting_order_slot", 0)); grid.add_child(slot); row["slot"] = slot
	_add_label(grid, "Remove"); var remove = Button.new(); remove.text = "Remove change"; grid.add_child(remove)
	remove.pressed.connect(func() -> void: _remove_row(row))
	for control in [type_option, out_option, in_option, old_option, new_option]: control.item_selected.connect(func(_i: int) -> void: _on_row_changed())
	slot.value_changed.connect(func(_v: float) -> void: _on_row_changed())
	_rows.append(row)
	rows_container.add_child(panel)
	_update_validation_label()

func _collect_changes() -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	for row in _rows:
		var type = _selected_meta(row["change_type"])
		var change = {"change_type": type}
		if type == "position_change":
			change["player_id"] = _selected_meta(row["player_out"])
			change["player_name"] = _player_label(str(change["player_id"]))
		else:
			change["player_out_id"] = _selected_meta(row["player_out"])
			change["player_out_name"] = _player_label(str(change["player_out_id"]))
		change["player_in_id"] = _selected_meta(row["player_in"])
		change["player_in_name"] = _player_label(str(change["player_in_id"]))
		change["old_position"] = _selected_meta(row["old_position"])
		change["new_position"] = _selected_meta(row["new_position"])
		change["batting_order_slot"] = int(row["slot"].value)
		changes.append(change)
	return changes

func _projected_alignment(data: Dictionary) -> Dictionary:
	var alignment = _current_alignment().duplicate(true)
	for change in _as_array(data.get("changes", [])):
		var item = _as_dictionary(change)
		var type = str(item.get("change_type", ""))
		var old_pos = str(item.get("old_position", ""))
		var new_pos = str(item.get("new_position", ""))
		if not old_pos.is_empty() and alignment.get(old_pos, "") in [item.get("player_out_id", ""), item.get("player_id", "")]: alignment[old_pos] = ""
		if type == "position_change" and not new_pos.is_empty(): alignment[new_pos] = str(item.get("player_id", ""))
		elif type in ["player_replacement", "bench_player_enters"] and not new_pos.is_empty(): alignment[new_pos] = str(item.get("player_in_id", ""))
	return alignment

func _current_alignment() -> Dictionary:
	var alignment = _as_dictionary(_context.get("defensive_alignment", {}))
	if not alignment.is_empty(): return alignment
	for player in _as_array(_players_by_team.get(_selected_meta(team_option), [])):
		var id = str(player.get("id", player.get("player_id", "")))
		var positions = player.get("positions", [])
		var pos = ""
		if positions is Array and not positions.is_empty():
			pos = str(positions[0]).strip_edges().to_upper()
		else:
			pos = str(player.get("position", "")).split(",")[0].strip_edges().to_upper()
		if not id.is_empty() and not pos.is_empty() and not alignment.has(pos): alignment[pos] = id
	return alignment

func _remove_row(row: Dictionary) -> void:
	_rows.erase(row)
	row["panel"].queue_free()
	_update_validation_label()

func _on_row_changed() -> void:
	_update_validation_label()
	changed.emit()

func _refresh_player_options() -> void:
	for row in _rows:
		_repopulate_player_option(row["player_out"])
		_repopulate_player_option(row["player_in"])

func _populate_team_options() -> void:
	team_option.clear()
	var team_id = str(_context.get("defense_team_id", _context.get("defensive_team_id", "")))
	team_option.add_item(team_id if not team_id.is_empty() else "(defensive team)"); team_option.set_item_metadata(0, team_id)
	team_option.item_selected.connect(func(_i: int) -> void: _refresh_player_options())

func _player_option(selected_id: String) -> OptionButton:
	var option = OptionButton.new(); _repopulate_player_option(option); _select_option_by_meta(option, selected_id); return option
func _repopulate_player_option(option: OptionButton) -> void:
	var selected = _selected_meta(option); option.clear(); option.add_item("(none)"); option.set_item_metadata(0, "")
	for player in _as_array(_players_by_team.get(_selected_meta(team_option), [])):
		var id = str(player.get("id", player.get("player_id", "")))
		option.add_item(str(player.get("display_name", player.get("name", id)))); option.set_item_metadata(option.item_count - 1, id)
	_select_option_by_meta(option, selected)

func _option(values: Array[String], selected_value: String, humanize: bool = false) -> OptionButton:
	var option = OptionButton.new()
	for value in values:
		option.add_item(value.replace("_", " ").capitalize() if humanize else ("(none)" if value.is_empty() else value)); option.set_item_metadata(option.item_count - 1, value)
	_select_option_by_meta(option, selected_value)
	return option
func _add_label(parent: Control, text: String) -> void:
	var label = Label.new(); label.text = text; parent.add_child(label)
func _update_validation_label() -> void:
	if is_instance_valid(validation_label): validation_label.text = "Alignment looks usable." if validate_alignment().is_empty() else "\n".join(validate())
func _selected_meta(option: OptionButton) -> String: return str(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""
func _select_option_by_meta(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value: option.select(index); return
func _player_label(player_id: String) -> String:
	for player in _as_array(_players_by_team.get(_selected_meta(team_option), [])):
		if str(player.get("id", player.get("player_id", ""))) == player_id: return str(player.get("display_name", player_id))
	return player_id
func _warning(field: String, message: String) -> Dictionary: return {"severity": "warning", "field": field, "message": message}
func _as_dictionary(value: Variant) -> Dictionary: return value.duplicate(true) if value is Dictionary else {}
func _as_array(value: Variant) -> Array: return value.duplicate(true) if value is Array else []
