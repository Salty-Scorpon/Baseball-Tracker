extends PanelContainer
class_name WorkspacePanel

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")

signal event_payload_changed(payload: Dictionary)
signal event_edit_requested(event_id: String)
signal event_selected(event_id: String)
signal event_creation_cancel_requested()

const MODE_REVIEW := "review"
const MODE_CREATING_EVENT := "creating_event"
const MODE_EDITING_EVENT := "editing_event"

@onready var workspace_title_label: Label = %WorkspaceTitleLabel
@onready var workspace_context_label: Label = %WorkspaceContextLabel
@onready var event_log_view: EventLogView = %EventLogView
@onready var event_creation_workspace: Control = %EventCreationWorkspace
@onready var event_creation_body_label: Label = %EventCreationBodyLabel
@onready var payload_preview_label: Label = %PayloadPreviewLabel
@onready var event_notes_field: TextEdit = %EventNotesField
@onready var cancel_event_button: Button = %CancelEventButton

var _current_mode := MODE_REVIEW
var _current_event_type := ""
var _current_event_id := ""
var _game_context: Dictionary = {}
var _event_data: Dictionary = {}

func _ready() -> void:
	_apply_style()
	cancel_event_button.pressed.connect(_on_cancel_event_pressed)
	event_log_view.event_selected.connect(_on_event_log_selected)
	event_log_view.event_edit_requested.connect(_on_event_log_edit_requested)
	event_notes_field.text_changed.connect(_on_payload_input_changed)
	show_review_mode()

func _apply_style() -> void:
	GameEntryStyle.style_title_label(workspace_title_label)
	for label in [workspace_context_label, event_creation_body_label, payload_preview_label]:
		GameEntryStyle.style_body_label(label)
	for button in [cancel_event_button]:
		GameEntryStyle.style_button(button)

func show_review_mode() -> void:
	_current_mode = MODE_REVIEW
	_current_event_type = ""
	_current_event_id = ""
	_game_context.clear()
	_event_data.clear()
	workspace_title_label.text = "Event Review"
	workspace_context_label.text = "Review the canonical event log. Event editing is requested from here and coordinated by GameEntryMode."
	event_log_view.show()
	event_creation_workspace.hide()
	event_notes_field.text = ""
	payload_preview_label.text = ""

func show_create_event_mode(event_type: String, game_context: Dictionary) -> void:
	_current_mode = MODE_CREATING_EVENT
	_current_event_type = event_type
	_current_event_id = ""
	_game_context = game_context.duplicate(true)
	_event_data.clear()
	workspace_title_label.text = "Creating Event: %s" % _format_event_name(event_type)
	workspace_context_label.text = _format_context_summary(_game_context)
	event_creation_body_label.text = "Event creation controls will collect scoring details here. This workspace only builds a payload; it does not commit, calculate stats, or replay game state."
	event_log_view.hide()
	event_creation_workspace.show()
	event_notes_field.text = ""
	_emit_payload_changed()

func show_edit_event_mode(event_id: String, event_data: Dictionary, game_context: Dictionary) -> void:
	_current_mode = MODE_EDITING_EVENT
	_current_event_id = event_id
	_event_data = event_data.duplicate(true)
	_current_event_type = str(_event_data.get("event_type", ""))
	_game_context = game_context.duplicate(true)
	workspace_title_label.text = "Editing Event #%s: %s" % [event_id, _format_event_name(_current_event_type)]
	workspace_context_label.text = _format_context_summary(_game_context)
	event_creation_body_label.text = "Event editing controls will load existing event details here. This workspace only edits a payload draft; confirmation remains in GameEntryMode."
	event_log_view.hide()
	event_creation_workspace.show()
	event_notes_field.text = str(_event_data.get("notes", ""))
	_emit_payload_changed()

func get_current_mode() -> String:
	return _current_mode

func _on_cancel_event_pressed() -> void:
	event_creation_cancel_requested.emit()
	show_review_mode()

func _on_event_log_selected(event_id: String) -> void:
	event_selected.emit(event_id)

func _on_event_log_edit_requested(event_id: String) -> void:
	event_edit_requested.emit(event_id)

func set_events(events: Array, context: Dictionary = {}) -> void:
	event_log_view.set_events(events, context)

func select_event(event_id: String) -> void:
	event_log_view.select_event(event_id)

func scroll_to_event(event_id: String) -> void:
	event_log_view.scroll_to_event(event_id)

func clear_events() -> void:
	event_log_view.clear()

func _on_payload_input_changed() -> void:
	if _current_mode == MODE_CREATING_EVENT or _current_mode == MODE_EDITING_EVENT:
		_emit_payload_changed()

func _emit_payload_changed() -> void:
	var payload := _build_payload()
	payload_preview_label.text = JSON.stringify(payload, "  ")
	event_payload_changed.emit(payload)

func _build_payload() -> Dictionary:
	return {
		"mode": _current_mode,
		"event_id": _current_event_id,
		"event_type": _current_event_type,
		"game_context": _game_context.duplicate(true),
		"event_data": _event_data.duplicate(true),
		"notes": event_notes_field.text,
	}

func _format_event_name(event_type: String) -> String:
	if event_type.strip_edges().is_empty():
		return "Unknown"
	return event_type.replace("_", " ").capitalize()

func _format_context_summary(game_context: Dictionary) -> String:
	if game_context.is_empty():
		return "No active game context has been provided yet."
	var parts: Array[String] = []
	for key in ["game_id", "inning", "half", "outs", "batter_id", "pitcher_id"]:
		if game_context.has(key):
			parts.append("%s: %s" % [str(key).replace("_", " ").capitalize(), str(game_context[key])])
	return " | ".join(parts) if not parts.is_empty() else "Game context provided."
