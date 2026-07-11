extends VBoxContainer
class_name ErrorAssignmentWidget

## Reusable error assignment widget for expanded Game Entry templates.
##
## This widget only gathers scorer-entered error data. Callers should store the
## returned array in GameEvent.details["errors"] so the canonical event log keeps
## event-specific error data attached to the play where it occurred.

const ERROR_TYPES: Array[String] = [
	"fielding",
	"throwing",
	"catching",
	"dropped_fly",
	"missed_tag",
	"missed_base",
	"interference",
	"unknown",
]

const ERROR_PHASES: Array[String] = [
	"fielding_batted_ball",
	"throwing_after_fielding",
	"catching_throw",
	"dropped_fly",
	"missed_tag",
	"missed_base",
	"relay_error",
	"pickoff_error",
	"other",
]

const EARNED_RUN_EFFECTS: Array[String] = [
	"manual_review",
	"unknown",
	"no_effect",
	"potential_unearned",
	"potential_earned",
]

const DEFAULT_ERROR = {
	"fielder_id": "",
	"error_type": "fielding",
	"error_phase": "fielding_batted_ball",
	"runner_or_batter_benefited": "",
	"extra_base_taken": "",
	"runs_scored_due_to_error": 0,
	"earned_run_effect": "manual_review",
	"notes": "",
}

@onready var rows_container: VBoxContainer = %RowsContainer
@onready var add_button: Button = %AddButton
@onready var empty_label: Label = %EmptyLabel
@onready var warning_label: Label = %WarningLabel

var _defensive_players: Array = []
var _pending_errors: Array = []

func _ready() -> void:
	add_button.pressed.connect(_on_add_pressed)
	_rebuild_rows()
	if not _pending_errors.is_empty():
		set_errors(_pending_errors)

func setup_defense(defensive_players: Array) -> void:
	_defensive_players = defensive_players.duplicate(true)
	if is_node_ready():
		_rebuild_rows_from_current_data()

func get_errors() -> Array:
	if not is_node_ready():
		return _pending_errors.duplicate(true)
	var errors: Array = []
	for row in rows_container.get_children():
		if not row is PanelContainer:
			continue
		var data = DEFAULT_ERROR.duplicate(true)
		data["fielder_id"] = _fielder_value(row.get_node("VBox/Header/FielderOption"), row.get_node("VBox/Header/FielderManualEdit"))
		data["error_type"] = _selected_text(row.get_node("VBox/Details/ErrorTypeOption"))
		data["error_phase"] = _selected_text(row.get_node("VBox/Details/ErrorPhaseOption"))
		data["runner_or_batter_benefited"] = row.get_node("VBox/Details/BenefitedEdit").text.strip_edges()
		data["extra_base_taken"] = row.get_node("VBox/Details/ExtraBaseEdit").text.strip_edges()
		data["runs_scored_due_to_error"] = int(row.get_node("VBox/Details/RunsSpinBox").value)
		data["earned_run_effect"] = _selected_text(row.get_node("VBox/Details/EarnedRunEffectOption"))
		data["notes"] = row.get_node("VBox/NotesEdit").text.strip_edges()
		errors.append(data)
	return errors

func set_errors(errors: Array) -> void:
	_pending_errors = errors.duplicate(true)
	if not is_node_ready():
		return
	_rebuild_rows()
	for error in errors:
		_add_error_row(_as_dictionary(error))
	_update_state()

func reset() -> void:
	_pending_errors.clear()
	if not is_node_ready():
		return
	_rebuild_rows()
	_update_state()

func validate() -> Array[String]:
	var issues: Array[String] = []
	var errors = get_errors()
	for index in range(errors.size()):
		var error = _as_dictionary(errors[index])
		var label = "Error %d" % (index + 1)
		if str(error.get("fielder_id", "")).strip_edges().is_empty():
			issues.append("%s needs a fielder_id or manual unknown ID." % label)
		if not ERROR_TYPES.has(str(error.get("error_type", ""))):
			issues.append("%s has an invalid error_type." % label)
		if not ERROR_PHASES.has(str(error.get("error_phase", ""))):
			issues.append("%s has an invalid error_phase." % label)
		if int(error.get("runs_scored_due_to_error", 0)) < 0:
			issues.append("%s cannot have negative runs_scored_due_to_error." % label)
	return issues

func _on_add_pressed() -> void:
	_add_error_row(DEFAULT_ERROR)
	_update_state()

func _rebuild_rows_from_current_data() -> void:
	var current = get_errors()
	_rebuild_rows()
	for error in current:
		_add_error_row(_as_dictionary(error))
	_update_state()

func _rebuild_rows() -> void:
	for child in rows_container.get_children():
		child.queue_free()

func _add_error_row(error_data: Dictionary) -> void:
	var data = DEFAULT_ERROR.duplicate(true)
	data.merge(error_data, true)
	var panel = PanelContainer.new()
	var box = VBoxContainer.new()
	box.name = "VBox"
	panel.add_child(box)
	var header = HBoxContainer.new()
	header.name = "Header"
	box.add_child(header)
	var fielder_option = OptionButton.new()
	fielder_option.name = "FielderOption"
	fielder_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_player_option(fielder_option)
	header.add_child(fielder_option)
	var manual = LineEdit.new()
	manual.name = "FielderManualEdit"
	manual.placeholder_text = "Manual/unknown fielder_id"
	header.add_child(manual)
	var remove = Button.new()
	remove.text = "Remove"
	remove.pressed.connect(_remove_error_row.bind(panel))
	header.add_child(remove)
	var details = GridContainer.new()
	details.name = "Details"
	details.columns = 2
	box.add_child(details)
	_add_labeled_option(details, "Error type", "ErrorTypeOption", ERROR_TYPES, str(data["error_type"]))
	_add_labeled_option(details, "Error phase", "ErrorPhaseOption", ERROR_PHASES, str(data["error_phase"]))
	_add_labeled_line_edit(details, "Benefited", "BenefitedEdit", str(data["runner_or_batter_benefited"]), "runner_id or batter_id")
	_add_labeled_line_edit(details, "Extra base", "ExtraBaseEdit", str(data["extra_base_taken"]), "2B, 3B, HOME, etc.")
	var runs_label = Label.new(); runs_label.text = "Runs due to error"; details.add_child(runs_label)
	var runs = SpinBox.new(); runs.name = "RunsSpinBox"; runs.min_value = 0; runs.max_value = 4; runs.step = 1; runs.value = int(data["runs_scored_due_to_error"]); details.add_child(runs)
	_add_labeled_option(details, "Earned run effect", "EarnedRunEffectOption", EARNED_RUN_EFFECTS, str(data["earned_run_effect"]))
	var notes = TextEdit.new()
	notes.name = "NotesEdit"
	notes.custom_minimum_size = Vector2(0, 56)
	notes.placeholder_text = "Optional scorer notes"
	notes.text = str(data["notes"])
	box.add_child(notes)
	rows_container.add_child(panel)
	_set_fielder_value(fielder_option, manual, str(data["fielder_id"]))

func _remove_error_row(panel: PanelContainer) -> void:
	panel.queue_free()
	call_deferred("_update_state")

func _add_labeled_option(parent: GridContainer, label_text: String, option_name: String, values: Array[String], selected: String) -> void:
	var label = Label.new(); label.text = label_text; parent.add_child(label)
	var option = OptionButton.new(); option.name = option_name; option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for value in values:
		option.add_item(value)
		option.set_item_metadata(option.item_count - 1, value)
	_select_option(option, selected)
	parent.add_child(option)

func _add_labeled_line_edit(parent: GridContainer, label_text: String, edit_name: String, text: String, placeholder: String) -> void:
	var label = Label.new(); label.text = label_text; parent.add_child(label)
	var edit = LineEdit.new(); edit.name = edit_name; edit.text = text; edit.placeholder_text = placeholder; parent.add_child(edit)

func _update_state() -> void:
	if is_instance_valid(empty_label):
		empty_label.visible = rows_container.get_child_count() == 0
	if is_instance_valid(warning_label):
		warning_label.text = "\n".join(validate())

func _populate_player_option(option: OptionButton) -> void:
	option.clear()
	option.add_item("Unknown / manual")
	option.set_item_metadata(0, "")
	for player in _defensive_players:
		if not player is Dictionary:
			continue
		var player_id = str(player.get("id", player.get("player_id", ""))).strip_edges()
		if player_id.is_empty():
			continue
		option.add_item(_player_label(player))
		option.set_item_metadata(option.item_count - 1, player_id)

func _player_label(player: Dictionary) -> String:
	var player_id = str(player.get("id", player.get("player_id", "")))
	var name = str(player.get("display_name", player.get("name", player_id)))
	var number = str(player.get("jersey_number", ""))
	var position = str(player.get("position", ""))
	return "#%s %s %s" % [number, name, position] if not number.is_empty() else "%s %s" % [name, position]

func _fielder_value(option: OptionButton, manual: LineEdit) -> String:
	var manual_value = manual.text.strip_edges()
	return manual_value if not manual_value.is_empty() else str(option.get_selected_metadata()).strip_edges()

func _set_fielder_value(option: OptionButton, manual: LineEdit, value: String) -> void:
	manual.text = ""
	if not _select_option_by_metadata(option, value):
		manual.text = value

func _selected_text(option: OptionButton) -> String:
	return str(option.get_selected_metadata()) if option.selected >= 0 else ""

func _select_option(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	if option.item_count > 0:
		option.select(0)

func _select_option_by_metadata(option: OptionButton, value: String) -> bool:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return true
	if option.item_count > 0:
		option.select(0)
	return value.strip_edges().is_empty()

func _as_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
