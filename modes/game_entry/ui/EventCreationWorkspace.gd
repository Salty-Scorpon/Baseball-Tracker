extends PanelContainer
class_name EventCreationWorkspace

## Photoshop-style center workspace for drafting one Game Entry event.
## This panel only collects event payload data. It does not commit GameEvents,
## calculate stats, or replay the game.

signal payload_changed(payload: Dictionary)
signal cancel_requested()

const DynamicEventEntryPanelScene = preload("res://modes/game_entry/EventEntryPanel.tscn")

const BATTER_PITCHER_EVENTS := {
	"single": true, "double": true, "triple": true, "home_run": true,
	"walk": true, "hit_by_pitch": true, "strikeout": true,
	"groundout": true, "flyout": true, "reached_on_error": true,
	"fielders_choice": true, "sacrifice_bunt": true, "sacrifice_fly": true,
	"double_play": true, "triple_play": true, "dropped_third_strike": true,
	"interference": true,
}

@onready var header_label: Label = %HeaderLabel
@onready var mode_label: Label = %ModeLabel
@onready var selected_event_label: Label = %SelectedEventLabel
@onready var context_label: Label = %ContextLabel
@onready var batter_pitcher_section: VBoxContainer = %BatterPitcherSection
@onready var batter_value_label: Label = %BatterValueLabel
@onready var pitcher_value_label: Label = %PitcherValueLabel
@onready var form_sections_box: VBoxContainer = %FormSectionsBox
@onready var notes_edit: TextEdit = %NotesEdit
@onready var validation_label: Label = %ValidationLabel
@onready var cancel_button: Button = %CancelButton

var _mode := "idle"
var _event_type := ""
var _event_id := ""
var _game_context: Dictionary = {}
var _existing_event_data: Dictionary = {}
var _entry_panel: DynamicEventEntryPanel
var _is_setting_payload := false

func _ready() -> void:
	cancel_button.pressed.connect(func() -> void: cancel_requested.emit())
	notes_edit.text_changed.connect(_emit_payload_changed)
	reset()

func open_for_event(event_type: String, game_context: Dictionary) -> void:
	reset()
	_mode = "creating_event"
	_event_type = _normalize_event_type(event_type)
	_game_context = game_context.duplicate(true)
	_build_workspace()
	_emit_payload_changed_deferred()

func open_for_existing_event(event_data: Dictionary, game_context: Dictionary) -> void:
	reset()
	_mode = "editing_event"
	_existing_event_data = event_data.duplicate(true)
	_event_id = str(event_data.get("event_id", event_data.get("id", "")))
	_event_type = _normalize_event_type(str(event_data.get("event_type", "")))
	_game_context = game_context.duplicate(true)
	_build_workspace()
	set_event_payload(event_data)
	_emit_payload_changed_deferred()

func get_event_payload() -> Dictionary:
	var child_payload: Dictionary = _base_payload()
	if is_instance_valid(_entry_panel):
		child_payload.merge(_entry_panel.get_event_payload(), true)
	var payload := _normalize_payload_shape(child_payload)
	payload["mode"] = _mode
	payload["event_id"] = _event_id
	payload["event_type"] = _event_type
	payload["game_context"] = _game_context.duplicate(true)
	payload["notes"] = notes_edit.text.strip_edges()
	payload["details"]["notes"] = notes_edit.text.strip_edges()
	return payload

func set_event_payload(payload: Dictionary) -> void:
	_is_setting_payload = true
	if payload.has("notes"):
		notes_edit.text = str(payload.get("notes", ""))
	elif payload.has("details") and payload["details"] is Dictionary:
		notes_edit.text = str(payload["details"].get("notes", ""))
	# Existing widgets currently expose focused set_* methods rather than one shared
	# set_event_payload API. Preserve the incoming draft for callers and let future
	# widget work hydrate each subsection without committing logic here.
	_existing_event_data = payload.duplicate(true)
	_is_setting_payload = false
	_emit_payload_changed()

func reset() -> void:
	_mode = "idle"
	_event_type = ""
	_event_id = ""
	_game_context.clear()
	_existing_event_data.clear()
	if is_instance_valid(header_label):
		header_label.text = "Event Creation Workspace"
		mode_label.text = "Idle"
		selected_event_label.text = "Selected event type: none"
		context_label.text = "Choose an event key to start a draft."
		batter_pitcher_section.visible = false
		notes_edit.text = ""
		validation_label.text = ""
		_clear_form_sections()

func validate_local() -> Array:
	var issues: Array = []
	if _event_type.is_empty():
		issues.append("Select an event type.")
	if is_instance_valid(_entry_panel) and _entry_panel.has_method("validate"):
		issues.append_array(_entry_panel.validate())
	validation_label.text = "No local validation issues." if issues.is_empty() else "\n".join(issues)
	return issues

func _build_workspace() -> void:
	header_label.text = "Create Event" if _mode == "creating_event" else "Edit Event"
	mode_label.text = _mode.replace("_", " ").capitalize()
	selected_event_label.text = "Selected event type: %s" % _format_event_name(_event_type)
	context_label.text = _format_context_summary(_game_context)
	batter_pitcher_section.visible = BATTER_PITCHER_EVENTS.has(_event_type)
	batter_value_label.text = _player_label(str(_game_context.get("batter_id", "")), "Current batter")
	pitcher_value_label.text = _player_label(str(_game_context.get("pitcher_id", "")), "Current pitcher")
	_clear_form_sections()
	form_sections_box.add_child(_section_label("Event template sections below use existing widgets when available. Unimplemented advanced fields are clearly labeled placeholders."))
	_entry_panel = DynamicEventEntryPanelScene.instantiate()
	form_sections_box.add_child(_entry_panel)
	_entry_panel.open_for_event(_event_type, _game_context)
	call_deferred("_connect_payload_signals", _entry_panel)
	validate_local()

func _clear_form_sections() -> void:
	_entry_panel = null
	for child in form_sections_box.get_children():
		child.queue_free()

func _connect_payload_signals(root: Node) -> void:
	if not is_instance_valid(root): return
	for node in root.find_children("*", "", true, false):
		if node is BaseButton:
			node.pressed.connect(_emit_payload_changed)
			node.toggled.connect(func(_pressed: bool) -> void: _emit_payload_changed())
		elif node is LineEdit:
			node.text_changed.connect(func(_text: String) -> void: _emit_payload_changed())
		elif node is TextEdit:
			node.text_changed.connect(_emit_payload_changed)
		elif node is SpinBox:
			node.value_changed.connect(func(_value: float) -> void: _emit_payload_changed())
		elif node is OptionButton:
			node.item_selected.connect(func(_index: int) -> void: _emit_payload_changed())

func _emit_payload_changed_deferred() -> void:
	call_deferred("_emit_payload_changed")

func _emit_payload_changed() -> void:
	if _is_setting_payload: return
	validate_local()
	payload_changed.emit(get_event_payload())

func _base_payload() -> Dictionary:
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
		"base_state_before": _game_context.get("base_state", {}).duplicate(true) if _game_context.get("base_state", {}) is Dictionary else {},
		"outs_before": _game_context.get("outs", 0),
		"score_before": _game_context.get("score", {}).duplicate(true) if _game_context.get("score", {}) is Dictionary else {},
	}

func _normalize_payload_shape(payload: Dictionary) -> Dictionary:
	var normalized := _base_payload()
	normalized.merge(payload, true)
	var details := _as_dictionary(normalized.get("details", {}))
	details["template"] = _as_dictionary(details.get("template", EventTemplateRegistry.get_template(_event_type)))
	var overrides := _as_dictionary(normalized.get("manual_overrides", details.get("manual_overrides", {})))
	details["manual_overrides"] = overrides.duplicate(true)
	normalized["details"] = details
	normalized["manual_overrides"] = overrides.duplicate(true)
	normalized["base_state_before"] = _as_dictionary(normalized.get("base_state_before", _game_context.get("base_state", {}))).duplicate(true)
	normalized["score_before"] = _as_dictionary(normalized.get("score_before", _game_context.get("score", {}))).duplicate(true)
	if not normalized.has("half_inning"):
		normalized["half_inning"] = normalized.get("half", "")
	if not normalized.has("outs_after"):
		normalized["outs_after"] = normalized.get("outs_before", 0)
	return normalized

func _as_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _normalize_event_type(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

func _format_event_name(value: String) -> String:
	return "Unknown" if value.is_empty() else value.replace("_", " ").capitalize()

func _format_context_summary(context: Dictionary) -> String:
	if context.is_empty(): return "No game context provided."
	var parts: Array[String] = []
	for key in ["game_id", "inning", "half", "half_inning", "outs", "offense_team_id", "defense_team_id"]:
		if context.has(key): parts.append("%s: %s" % [str(key).replace("_", " ").capitalize(), str(context[key])])
	return " | ".join(parts)

func _player_label(player_id: String, fallback: String) -> String:
	return "%s: —" % fallback if player_id.is_empty() else "%s: %s" % [fallback, player_id]
