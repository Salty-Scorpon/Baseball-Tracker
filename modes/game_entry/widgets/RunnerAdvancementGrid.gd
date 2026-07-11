extends VBoxContainer
class_name RunnerAdvancementGrid

## Reusable runner advancement entry widget for expanded Game Entry templates.
##
## The data returned by this widget is event-specific input data. Callers
## should store it in GameEvent.details (for example, details["runner_advancements"])
## when creating or editing the canonical game event log.

const BASE_VALUES: Array[String] = ["HOME", "1B", "2B", "3B", "OUT", "SCORED", "NONE"]
const OCCUPIED_BASE_VALUES: Array[String] = ["1B", "2B", "3B"]
const ADVANCE_REASONS: Array[String] = [
	"batter_result",
	"throw",
	"error",
	"wild_pitch",
	"passed_ball",
	"balk",
	"fielder_choice",
	"defensive_indifference",
	"manual",
]

const BATTER_RUNNER_ID := "__batter__"
const BATTER_LABEL := "Batter"

@onready var rows_grid: GridContainer = %RowsGrid
@onready var empty_label: Label = %EmptyLabel

var _rows: Array[Dictionary] = []
var _batter_id := ""

func _ready() -> void:
	reset()

func setup_from_base_state(batter_id: String, base_state: Dictionary, player_lookup: Callable) -> void:
	reset()
	_batter_id = batter_id
	if not batter_id.strip_edges().is_empty():
		_add_row({
			"runner_id": batter_id,
			"display_name": _lookup_player_name(batter_id, player_lookup, BATTER_LABEL),
			"start_base": "HOME",
			"end_base": "NONE",
			"scored": false,
			"out": false,
			"rbi_credit": false,
			"advance_reason": "batter_result",
			"responsible_pitcher_id": "",
			"is_batter": true,
		})

	for base in ["1B", "2B", "3B"]:
		var runner_id := str(base_state.get(base, ""))
		if runner_id.strip_edges().is_empty():
			continue
		_add_row({
			"runner_id": runner_id,
			"display_name": _lookup_player_name(runner_id, player_lookup, runner_id),
			"start_base": base,
			"end_base": "NONE",
			"scored": false,
			"out": false,
			"rbi_credit": false,
			"advance_reason": "batter_result",
			"responsible_pitcher_id": "",
			"is_batter": false,
		})
	_update_empty_state()

func apply_default_for_event(event_type: String) -> void:
	var normalized := event_type.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	for row in _rows:
		_set_row_value(row, "advance_reason", "batter_result")
		_set_row_value(row, "out", false)
		_set_row_value(row, "scored", false)
		_set_row_value(row, "rbi_credit", false)
		var start_base := str(row["start_base"])
		var is_batter := bool(row.get("is_batter", false))
		match normalized:
			"single":
				_set_row_value(row, "end_base", "1B" if is_batter else _advance_base(start_base, 1))
			"double":
				_set_row_value(row, "end_base", "2B" if is_batter else _advance_base(start_base, 2))
			"triple":
				_set_row_value(row, "end_base", "3B" if is_batter else _advance_base(start_base, 3))
			"home_run":
				_set_row_value(row, "end_base", "SCORED")
				_set_row_value(row, "scored", true)
				_set_row_value(row, "rbi_credit", true)
			"walk", "intentional_walk", "hit_by_pitch":
				_set_row_value(row, "end_base", "1B" if is_batter else start_base)
			"strikeout", "groundout", "flyout", "lineout", "popout":
				if is_batter:
					_set_row_value(row, "end_base", "OUT")
					_set_row_value(row, "out", true)
				else:
					_set_row_value(row, "end_base", start_base)
			_:
				_set_row_value(row, "end_base", "NONE")

func get_advancements() -> Array:
	var advancements: Array = []
	for row in _rows:
		advancements.append({
			"runner_id": str(row["runner_id"]),
			"display_name": str(row["name_label"].text),
			"start_base": str(row["start_base"]),
			"end_base": _selected_option_text(row["end_base_option"]),
			"scored": row["scored_check"].button_pressed,
			"out": row["out_check"].button_pressed,
			"rbi_credit": row["rbi_check"].button_pressed,
			"advance_reason": _selected_option_text(row["reason_option"]),
			"responsible_pitcher_id": str(row["pitcher_edit"].text).strip_edges(),
		})
	return advancements

func set_advancements(data: Array) -> void:
	var rows_by_runner := {}
	for row in _rows:
		rows_by_runner[str(row["runner_id"])] = row
	for item in data:
		if not item is Dictionary:
			continue
		var row: Dictionary = rows_by_runner.get(str(item.get("runner_id", "")), {})
		if row.is_empty():
			continue
		for key in ["end_base", "scored", "out", "rbi_credit", "advance_reason", "responsible_pitcher_id"]:
			if item.has(key):
				_set_row_value(row, key, item[key])

func reset() -> void:
	_rows.clear()
	_batter_id = ""
	if is_instance_valid(rows_grid):
		for child in rows_grid.get_children():
			if child.has_meta("runner_advancement_dynamic"):
				child.queue_free()
	_update_empty_state()

func validate() -> Array[String]:
	var warnings: Array[String] = []
	var occupied_after := {}
	for advancement in get_advancements():
		var name := str(advancement.get("display_name", advancement.get("runner_id", "Runner")))
		var end_base := str(advancement.get("end_base", "NONE"))
		var is_out := bool(advancement.get("out", false))
		var scored := bool(advancement.get("scored", false))
		if end_base == "NONE":
			warnings.append("%s has no end state." % name)
		if scored and is_out:
			warnings.append("%s cannot be marked scored and out on the same advancement." % name)
		if OCCUPIED_BASE_VALUES.has(end_base) and not is_out and not scored:
			if occupied_after.has(end_base):
				warnings.append("Two active runners end on %s: %s and %s." % [end_base, occupied_after[end_base], name])
			else:
				occupied_after[end_base] = name
		if str(advancement.get("runner_id", "")) == _batter_id and not _batter_id.is_empty():
			if not is_out and not scored and not OCCUPIED_BASE_VALUES.has(end_base):
				warnings.append("The batter must end out, on base, or scored.")
	return warnings

func _add_row(data: Dictionary) -> void:
	var name_label := Label.new()
	name_label.text = str(data["display_name"])
	_mark_dynamic(name_label)
	rows_grid.add_child(name_label)

	var start_label := Label.new()
	start_label.text = str(data["start_base"])
	_mark_dynamic(start_label)
	rows_grid.add_child(start_label)

	var end_base_option := _build_option_button(BASE_VALUES)
	_mark_dynamic(end_base_option)
	rows_grid.add_child(end_base_option)

	var scored_check := CheckBox.new()
	_mark_dynamic(scored_check)
	rows_grid.add_child(scored_check)
	var out_check := CheckBox.new()
	_mark_dynamic(out_check)
	rows_grid.add_child(out_check)
	var rbi_check := CheckBox.new()
	_mark_dynamic(rbi_check)
	rows_grid.add_child(rbi_check)

	var reason_option := _build_option_button(ADVANCE_REASONS)
	_mark_dynamic(reason_option)
	rows_grid.add_child(reason_option)

	var pitcher_edit := LineEdit.new()
	pitcher_edit.placeholder_text = "Pitcher ID"
	_mark_dynamic(pitcher_edit)
	rows_grid.add_child(pitcher_edit)

	var row := data.duplicate(true)
	row.merge({"name_label": name_label, "end_base_option": end_base_option, "scored_check": scored_check, "out_check": out_check, "rbi_check": rbi_check, "reason_option": reason_option, "pitcher_edit": pitcher_edit}, true)
	_rows.append(row)
	_set_row_value(row, "end_base", data.get("end_base", "NONE"))
	_set_row_value(row, "advance_reason", data.get("advance_reason", "batter_result"))

func _mark_dynamic(control: Control) -> void:
	control.set_meta("runner_advancement_dynamic", true)

func _build_option_button(values: Array[String]) -> OptionButton:
	var option := OptionButton.new()
	for value in values:
		option.add_item(value)
	return option

func _set_row_value(row: Dictionary, key: String, value: Variant) -> void:
	match key:
		"end_base":
			_select_option(row["end_base_option"], str(value))
		"scored":
			row["scored_check"].button_pressed = bool(value)
		"out":
			row["out_check"].button_pressed = bool(value)
		"rbi_credit":
			row["rbi_check"].button_pressed = bool(value)
		"advance_reason":
			_select_option(row["reason_option"], str(value))
		"responsible_pitcher_id":
			row["pitcher_edit"].text = str(value)

func _select_option(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if option.get_item_text(index) == value:
			option.select(index)
			return
	option.select(0)

func _selected_option_text(option: OptionButton) -> String:
	return option.get_item_text(option.selected)

func _advance_base(start_base: String, base_count: int) -> String:
	var base_index := {"HOME": 0, "1B": 1, "2B": 2, "3B": 3}.get(start_base, 0)
	var end_index: int = int(base_index) + base_count
	if end_index >= 4:
		return "SCORED"
	return ["HOME", "1B", "2B", "3B"][end_index]

func _lookup_player_name(player_id: String, player_lookup: Callable, fallback: String) -> String:
	if player_lookup.is_valid():
		var result: Variant = player_lookup.call(player_id)
		if result is String and not str(result).strip_edges().is_empty():
			return str(result)
		if result is Dictionary:
			return str(result.get("display_name", result.get("name", fallback)))
	return fallback

func _update_empty_state() -> void:
	if is_instance_valid(empty_label):
		empty_label.visible = _rows.is_empty()
