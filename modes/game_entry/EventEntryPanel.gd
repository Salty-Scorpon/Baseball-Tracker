extends VBoxContainer
class_name DynamicEventEntryPanel

## Dynamic event-entry UI for expanded Game Entry Mode.
##
## This panel builds an event-specific data-entry form from EventTemplateRegistry
## metadata. It only collects and validates event-specific data; callers remain
## responsible for creating GameEvent records and storing this payload inside
## GameEvent.details before committing to the canonical event log.

const CountEntryWidgetScene = preload("res://modes/game_entry/widgets/CountEntryWidget.tscn")
const RunnerAdvancementGridScene = preload("res://modes/game_entry/widgets/RunnerAdvancementGrid.tscn")
const FielderAssignmentWidgetScene = preload("res://modes/game_entry/widgets/FielderAssignmentWidget.tscn")
const ManualOverridePanelScene = preload("res://modes/game_entry/widgets/ManualOverridePanel.tscn")
const ErrorAssignmentWidgetScene = preload("res://modes/game_entry/widgets/ErrorAssignmentWidget.tscn")
const PitchingChangeWidgetScene = preload("res://modes/game_entry/widgets/PitchingChangeWidget.tscn")
const SubstitutionWidgetScene = preload("res://modes/game_entry/widgets/SubstitutionWidget.tscn")
const DefensiveChangeWizardScene = preload("res://modes/game_entry/widgets/DefensiveChangeWizard.tscn")

const SUPPORTED_EVENT_TYPES: Array[String] = [
	"single",
	"double",
	"triple",
	"home_run",
	"walk",
	"hit_by_pitch",
	"strikeout",
	"groundout",
	"flyout",
	"reached_on_error",
	"fielders_choice",
	"sacrifice_bunt",
	"sacrifice_fly",
	"stolen_base",
	"caught_stealing",
	"wild_pitch",
	"passed_ball",
	"balk",
	"pitching_change",
	"pinch_hitter",
	"pinch_runner",
	"defensive_substitution",
	"position_change",
	"batting_order_replacement",
	"batch_defensive_change",
	"double_play",
	"triple_play",
	"dropped_third_strike",
	"interference",
	"pickoff",
	"pickoff_error",
	"manual_correction",
	"earned_run_override",
	"win_loss_save_assignment",
	"game_administration_events",
]

@onready var title_label: Label = %TitleLabel
@onready var context_label: Label = %ContextLabel
@onready var sections_container: VBoxContainer = %SectionsContainer
@onready var validation_label: Label = %ValidationLabel

var _event_type = ""
var _template: Dictionary = {}
var _game_context: Dictionary = {}
var _widget_instances = {}
var _detail_controls = {}

func _ready() -> void:
	reset()

func open_for_event(event_type: String, game_context: Dictionary) -> void:
	reset()
	_event_type = _normalize_event_type(event_type)
	_game_context = game_context.duplicate(true)
	if not SUPPORTED_EVENT_TYPES.has(_event_type):
		_show_panel_error("Unsupported event type: %s" % event_type)
		return
	_template = EventTemplateRegistry.get_template(_event_type)
	if _template.is_empty():
		_show_panel_error("No EventTemplateRegistry template found for: %s" % _event_type)
		return
	title_label.text = str(_template.get("display_name", _event_type.capitalize()))
	context_label.text = _format_context_summary()
	for widget_key in _template.get("widgets_needed", []):
		_add_widget_for_key(str(widget_key))
	_update_validation_label()

func get_event_payload() -> Dictionary:
	var manual_overrides := _get_widget_data(EventTemplateRegistry.WIDGET_MANUAL_OVERRIDES)
	var details = {
		"template": _template.duplicate(true),
		"count": _get_widget_data(EventTemplateRegistry.WIDGET_COUNT_ENTRY),
		"runner_advancements": _get_widget_data(EventTemplateRegistry.WIDGET_RUNNER_ADVANCEMENT_GRID),
		"fielder_assignment": _get_widget_data(EventTemplateRegistry.WIDGET_BASIC_FIELDER_ASSIGNMENT),
		"errors": _get_widget_data(EventTemplateRegistry.WIDGET_ERROR_DETAILS),
		"event_details": _collect_detail_data(),
		"manual_overrides": manual_overrides,
		"pitching_change": _get_widget_data(EventTemplateRegistry.WIDGET_PITCHING_CHANGE),
		"substitution": _get_widget_data(EventTemplateRegistry.WIDGET_SUBSTITUTION),
		"defensive_change": _get_widget_data(EventTemplateRegistry.WIDGET_DEFENSIVE_CHANGE_WIZARD),
		"out_assignments": _out_assignments_from_details(),
	}
	return {
		"event_type": _event_type,
		"game_id": _game_context.get("game_id", ""),
		"inning": _game_context.get("inning", null),
		"half": _game_context.get("half", _game_context.get("half_inning", "")),
		"half_inning": _game_context.get("half_inning", _game_context.get("half", "")),
		"offense_team_id": _game_context.get("offense_team_id", ""),
		"defense_team_id": _game_context.get("defense_team_id", ""),
		"batter_id": _game_context.get("batter_id", ""),
		"pitcher_id": _game_context.get("pitcher_id", ""),
		"base_state_before": _as_dictionary(_game_context.get("base_state", {})).duplicate(true),
		"outs_before": _game_context.get("outs", 0),
		"score_before": _as_dictionary(_game_context.get("score", {})).duplicate(true),
		"manual_overrides": manual_overrides,
		"details": details,
	}

func reset() -> void:
	_event_type = ""
	_template.clear()
	_game_context.clear()
	_widget_instances.clear()
	_detail_controls.clear()
	if is_instance_valid(title_label):
		title_label.text = "Select an event"
	if is_instance_valid(context_label):
		context_label.text = "Open this panel with open_for_event(event_type, game_context)."
	if is_instance_valid(validation_label):
		validation_label.text = ""
	if is_instance_valid(sections_container):
		for child in sections_container.get_children():
			child.queue_free()

func validate() -> Array[String]:
	var issues: Array[String] = []
	for message in validate_payload():
		issues.append("%s: %s" % [str(message.get("severity", "warning")).capitalize(), str(message.get("message", ""))])
	for widget in _widget_instances.values():
		if widget.has_method("validate"):
			issues.append_array(widget.validate())
	return issues

func validate_payload() -> Array[Dictionary]:
	if _event_type.is_empty():
		return [{"severity": "error", "field": "event_type", "message": "No event type selected."}]
	return EventValidator.validate_event_payload(get_event_payload())

func _add_widget_for_key(widget_key: String) -> void:
	match widget_key:
		EventTemplateRegistry.WIDGET_COUNT_ENTRY:
			_add_widget(widget_key, CountEntryWidgetScene.instantiate())
		EventTemplateRegistry.WIDGET_PITCHING_CHANGE:
			var pitching_widget = PitchingChangeWidgetScene.instantiate()
			_add_widget(widget_key, pitching_widget)
			pitching_widget.setup_context(_game_context)
		EventTemplateRegistry.WIDGET_DEFENSIVE_CHANGE_WIZARD:
			var defensive_change_widget = DefensiveChangeWizardScene.instantiate()
			_add_widget(widget_key, defensive_change_widget)
			defensive_change_widget.setup_context(_game_context)
		EventTemplateRegistry.WIDGET_SUBSTITUTION:
			var substitution_widget = SubstitutionWidgetScene.instantiate()
			_add_widget(widget_key, substitution_widget)
			substitution_widget.setup_context(_game_context)
		EventTemplateRegistry.WIDGET_RUNNER_ADVANCEMENT_GRID:
			var runner_grid = RunnerAdvancementGridScene.instantiate()
			_add_widget(widget_key, runner_grid)
			var runner_batter_id = "" if _is_runner_only_event(_event_type) else str(_game_context.get("batter_id", ""))
			runner_grid.setup_from_base_state(runner_batter_id, _as_dictionary(_game_context.get("base_state", {})), Callable(self, "_lookup_offensive_player_name"))
			runner_grid.apply_default_for_event(_event_type)
		EventTemplateRegistry.WIDGET_BASIC_FIELDER_ASSIGNMENT:
			var fielder_widget = FielderAssignmentWidgetScene.instantiate()
			_add_widget(widget_key, fielder_widget)
			fielder_widget.setup_defense(_as_array(_game_context.get("defensive_players", [])))
			fielder_widget.set_context(_event_type)
		EventTemplateRegistry.WIDGET_ERROR_DETAILS:
			var error_widget = ErrorAssignmentWidgetScene.instantiate()
			_add_widget(widget_key, error_widget)
			error_widget.setup_defense(_as_array(_game_context.get("defensive_players", [])))
		EventTemplateRegistry.WIDGET_MANUAL_OVERRIDES:
			_add_widget(widget_key, ManualOverridePanelScene.instantiate())
		EventTemplateRegistry.WIDGET_EVENT_SUMMARY:
			_add_summary_section(widget_key)
		EventTemplateRegistry.WIDGET_OUT_ASSIGNMENTS:
			_add_detail_section(widget_key)
		EventTemplateRegistry.WIDGET_ADVANCED_PLAY_DETAILS:
			_add_detail_section(widget_key)
		EventTemplateRegistry.WIDGET_MANUAL_CORRECTION_DETAILS:
			_add_detail_section(widget_key)
		EventTemplateRegistry.WIDGET_GAME_ADMINISTRATION_DETAILS:
			_add_detail_section(widget_key)
		_:
			_add_detail_section(widget_key)

func _add_widget(widget_key: String, widget: Control) -> void:
	_widget_instances[widget_key] = widget
	sections_container.add_child(widget)

func _add_detail_section(widget_key: String) -> void:
	var panel = PanelContainer.new()
	var box = VBoxContainer.new()
	panel.add_child(box)
	var label = Label.new()
	label.text = _title_for_widget_key(widget_key)
	box.add_child(label)
	var fields: Array = _fields_for_detail_widget(widget_key)
	var controls = {}
	for field in fields:
		var edit = LineEdit.new()
		edit.placeholder_text = str(field).replace("_", " ").capitalize()
		edit.text = _default_detail_value(str(field))
		box.add_child(edit)
		controls[str(field)] = edit
	_detail_controls[widget_key] = controls
	sections_container.add_child(panel)

func _add_summary_section(widget_key: String) -> void:
	var label = Label.new()
	label.text = "Event summary is generated by the caller from the returned payload before commit."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_widget_instances[widget_key] = label
	sections_container.add_child(label)

func _get_widget_data(widget_key: String) -> Variant:
	var widget: Variant = _widget_instances.get(widget_key)
	if widget == null:
		return [] if widget_key in [EventTemplateRegistry.WIDGET_RUNNER_ADVANCEMENT_GRID, EventTemplateRegistry.WIDGET_ERROR_DETAILS] else {}
	match widget_key:
		EventTemplateRegistry.WIDGET_COUNT_ENTRY:
			return widget.get_count_data()
		EventTemplateRegistry.WIDGET_RUNNER_ADVANCEMENT_GRID:
			return widget.get_advancements()
		EventTemplateRegistry.WIDGET_BASIC_FIELDER_ASSIGNMENT:
			return widget.get_fielder_data()
		EventTemplateRegistry.WIDGET_ERROR_DETAILS:
			return widget.get_errors()
		EventTemplateRegistry.WIDGET_MANUAL_OVERRIDES:
			return widget.get_overrides()
		EventTemplateRegistry.WIDGET_PITCHING_CHANGE:
			return widget.get_pitching_change_data()
		EventTemplateRegistry.WIDGET_SUBSTITUTION:
			return widget.get_substitution_data()
		EventTemplateRegistry.WIDGET_DEFENSIVE_CHANGE_WIZARD:
			return widget.get_defensive_change_data()
	return {}

func _collect_detail_data() -> Dictionary:
	var output = {}
	for widget_key in _detail_controls.keys():
		var section = {}
		for field in _detail_controls[widget_key].keys():
			section[field] = _detail_controls[widget_key][field].text.strip_edges()
		output[widget_key] = section
	return output

func _fields_for_detail_widget(widget_key: String) -> Array[String]:
	match widget_key:
		EventTemplateRegistry.WIDGET_HIT_DETAILS:
			return ["hit_location", "batted_ball_type"]
		EventTemplateRegistry.WIDGET_FREE_BASE_DETAILS:
			return ["walk_type", "intentional", "body_area"]
		EventTemplateRegistry.WIDGET_STRIKEOUT_DETAILS:
			return ["strikeout_type", "outs_added"]
		EventTemplateRegistry.WIDGET_BATTED_BALL_OUT_DETAILS:
			if _event_type == "fielders_choice":
				return ["out_type", "outs_added", "runner_out_id", "throw_to_base"]
			return ["out_type", "outs_added"]
		EventTemplateRegistry.WIDGET_SACRIFICE_DETAILS:
			return ["sacrifice_bunt", "sacrifice_fly", "outs_added", "rbi"]
		EventTemplateRegistry.WIDGET_BASERUNNING_DETAILS:
			return ["runner_id", "start_base", "end_base", "attempted_base", "outs_added"]
		EventTemplateRegistry.WIDGET_MISC_ADVANCEMENT_DETAILS:
			return ["pitcher_id", "catcher_id", "runs_scored"]
		EventTemplateRegistry.WIDGET_OUT_ASSIGNMENTS:
			return _out_assignment_fields()
		EventTemplateRegistry.WIDGET_ADVANCED_PLAY_DETAILS:
			return _advanced_play_fields()
		EventTemplateRegistry.WIDGET_MANUAL_CORRECTION_DETAILS:
			return ["correction_type", "affected_team_id", "affected_player_id", "old_value", "new_value", "reason"]
		EventTemplateRegistry.WIDGET_GAME_ADMINISTRATION_DETAILS:
			return ["admin_event_type", "score", "reason", "notes", "manual_override"]
	return []

func _out_assignment_fields() -> Array[String]:
	var fields: Array[String] = []
	var count = 3 if _event_type == "triple_play" else 2
	for out_number in range(1, count + 1):
		for suffix in ["runner_or_batter_id", "out_base", "out_type", "putout_fielder_id", "assist_fielder_ids"]:
			fields.append("out_%d_%s" % [out_number, suffix])
	return fields

func _advanced_play_fields() -> Array[String]:
	match _event_type:
		"dropped_third_strike":
			return ["batter_reached_or_out", "wild_pitch", "passed_ball", "catcher_throwing_error", "advance_after_error"]
		"interference":
			return ["interference_type", "interfering_player_id", "benefited_runner_or_batter_id", "ruling", "batter_awarded_base"]
		"pickoff", "pickoff_error":
			return ["runner_id", "base", "pitcher_id", "receiving_fielder_id", "safe_or_out", "error_on_play", "advance_after_error"]
	return []

func _out_assignments_from_details() -> Array[Dictionary]:
	var section = _as_dictionary(_collect_detail_data().get(EventTemplateRegistry.WIDGET_OUT_ASSIGNMENTS, {}))
	var assignments: Array[Dictionary] = []
	var count = 3 if _event_type == "triple_play" else 2 if _event_type == "double_play" else 0
	for out_number in range(1, count + 1):
		assignments.append({
			"out_number": out_number,
			"runner_or_batter_id": str(section.get("out_%d_runner_or_batter_id" % out_number, "")),
			"out_base": str(section.get("out_%d_out_base" % out_number, "")),
			"out_type": str(section.get("out_%d_out_type" % out_number, "")),
			"putout_fielder_id": str(section.get("out_%d_putout_fielder_id" % out_number, "")),
			"assist_fielder_ids": _split_csv(str(section.get("out_%d_assist_fielder_ids" % out_number, ""))),
		})
	return assignments

func _split_csv(value: String) -> Array[String]:
	var output: Array[String] = []
	for part in value.split(",", false):
		var clean = part.strip_edges()
		if not clean.is_empty():
			output.append(clean)
	return output

func _default_detail_value(field: String) -> String:
	if field == "sacrifice_bunt" and _event_type == "sacrifice_bunt":
		return "true"
	if field == "sacrifice_fly" and _event_type == "sacrifice_fly":
		return "true"
	if field == "outs_added" and _event_type in ["sacrifice_bunt", "sacrifice_fly", "caught_stealing"]:
		return "1"
	if field == "outs_added" and _event_type == "double_play":
		return "2"
	if field == "outs_added" and _event_type == "triple_play":
		return "3"
	if field == "pitcher_id" and _event_type in ["wild_pitch", "balk"]:
		return str(_game_context.get("pitcher_id", ""))
	return ""


func _lookup_offensive_player_name(player_id: String) -> String:
	for player in _as_array(_game_context.get("offensive_lineup", [])):
		if player is Dictionary and str(player.get("id", player.get("player_id", ""))) == player_id:
			return str(player.get("display_name", player.get("name", player_id)))
	return player_id

func _format_context_summary() -> String:
	return "Inning %s %s • Outs: %s • Batter: %s • Pitcher: %s" % [_game_context.get("inning", "?"), _game_context.get("half", ""), _game_context.get("outs", 0), _game_context.get("batter_id", ""), _game_context.get("pitcher_id", "")]

func _show_panel_error(message: String) -> void:
	title_label.text = "Event Entry"
	context_label.text = message
	validation_label.text = message

func _update_validation_label() -> void:
	var issues = validate()
	validation_label.text = "Ready to collect event details." if issues.is_empty() else "\n".join(issues)

func _normalize_event_type(event_type: String) -> String:
	return event_type.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

func _title_for_widget_key(widget_key: String) -> String:
	return widget_key.replace("_", " ").capitalize()

func _as_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _as_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []

func _is_runner_only_event(event_type: String) -> bool:
	return event_type in ["stolen_base", "caught_stealing", "wild_pitch", "passed_ball", "balk", "pickoff", "pickoff_error"]
