extends PanelContainer
class_name EventSummaryPanel

## Bottom-center Game Entry summary and validation strip.
## This panel previews active drafts or selected events and emits requests only.
## It does not commit events, calculate stats, or mutate the event log.

signal confirm_requested()
signal cancel_requested()
signal edit_requested()

const GameEntryStyle = preload("res://modes/game_entry/GameEntryStyle.gd")
const EventValidatorScript = preload("res://app/EventValidator.gd")
const EventSummaryFormatterScript = preload("res://app/EventSummaryFormatter.gd")

const IDLE_TEXT = "No active event. Choose an event button to begin scoring."
const SEVERITY_ERROR = "error"
const SEVERITY_WARNING = "warning"
const SEVERITY_INFO = "info"
const SEVERITY_SUCCESS = "success"

@onready var title_label: Label = %EventSummaryTitleLabel
@onready var preview_label: Label = %PreviewLabel
@onready var validation_list: VBoxContainer = %ValidationList
@onready var confirm_button: Button = %ConfirmButton
@onready var edit_button: Button = %EditButton
@onready var cancel_button: Button = %CancelButton

var _validation_messages: Array = []
var _is_active = false
var _has_blocking_error = false
var _can_confirm = false
var _edit_relevant = false

func _ready() -> void:
	_apply_style()
	confirm_button.pressed.connect(func() -> void: confirm_requested.emit())
	cancel_button.pressed.connect(func() -> void: cancel_requested.emit())
	edit_button.pressed.connect(func() -> void: edit_requested.emit())
	set_idle()

func set_idle() -> void:
	_is_active = false
	_can_confirm = false
	_edit_relevant = false
	_has_blocking_error = false
	title_label.text = "Event Summary / Validation"
	preview_label.text = IDLE_TEXT
	_validation_messages.clear()
	_clear_validation_list()
	_set_buttons_visible(false)
	_update_confirm_state()

func set_preview_text(text: String) -> void:
	_is_active = true
	_edit_relevant = false
	title_label.text = "Active Event Preview"
	preview_label.text = text.strip_edges() if not text.strip_edges().is_empty() else "Preview will appear as event details are entered."
	_set_buttons_visible(true)
	_update_confirm_state()

func set_validation_messages(messages: Array) -> void:
	_validation_messages = messages.duplicate(true)
	_has_blocking_error = _messages_have_errors(_validation_messages)
	_render_validation_messages()
	_update_confirm_state()

func set_active(can_confirm: bool) -> void:
	_is_active = true
	_can_confirm = can_confirm
	_set_buttons_visible(true)
	_update_confirm_state()

func set_selected_event_summary(text: String) -> void:
	_is_active = true
	_can_confirm = false
	_edit_relevant = true
	_has_blocking_error = false
	title_label.text = "Selected Event Summary"
	preview_label.text = text.strip_edges() if not text.strip_edges().is_empty() else "Selected event has no summary yet."
	_validation_messages.clear()
	_clear_validation_list()
	confirm_button.visible = false
	cancel_button.visible = false
	edit_button.visible = true
	_update_confirm_state()

func has_active_event() -> bool:
	return _is_active and cancel_button.visible

func can_confirm_event() -> bool:
	return _is_active and _can_confirm and not _has_blocking_error and confirm_button.visible and not confirm_button.disabled

func show_payload_preview(payload: Dictionary) -> void:
	var preview = EventSummaryFormatterScript.summarize(payload)
	set_preview_text(preview)
	var messages = EventValidatorScript.validate_event_payload(payload)
	set_validation_messages(messages)
	set_active(not EventValidatorScript.has_errors(messages))

func _apply_style() -> void:
	GameEntryStyle.style_content_panel(self)
	GameEntryStyle.style_title_label(title_label)
	GameEntryStyle.style_body_label(preview_label)
	for button in [confirm_button, edit_button, cancel_button]:
		GameEntryStyle.style_button(button)

func _set_buttons_visible(visible: bool) -> void:
	confirm_button.visible = visible
	cancel_button.visible = visible
	edit_button.visible = visible and _edit_relevant

func _update_confirm_state() -> void:
	confirm_button.disabled = (not _is_active) or (not _can_confirm) or _has_blocking_error

func _render_validation_messages() -> void:
	_clear_validation_list()
	if _validation_messages.is_empty():
		validation_list.add_child(_message_label(SEVERITY_INFO, "No validation messages yet."))
		return
	for message in _validation_messages:
		var severity = _message_severity(message)
		validation_list.add_child(_message_label(severity, _message_text(message)))

func _clear_validation_list() -> void:
	for child in validation_list.get_children():
		validation_list.remove_child(child)
		child.queue_free()

func _messages_have_errors(messages: Array) -> bool:
	for message in messages:
		if _message_severity(message) == SEVERITY_ERROR:
			return true
	return false

func _message_severity(message: Variant) -> String:
	if message is Dictionary:
		var severity = str(message.get("severity", SEVERITY_INFO)).strip_edges().to_lower()
		return severity if [SEVERITY_ERROR, SEVERITY_WARNING, SEVERITY_INFO, SEVERITY_SUCCESS].has(severity) else SEVERITY_INFO
	return SEVERITY_INFO

func _message_text(message: Variant) -> String:
	if message is Dictionary:
		return str(message.get("message", message.get("text", "Validation message")))
	return str(message)

func _message_label(severity: String, text: String) -> Label:
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "%s %s" % [_severity_icon(severity), text]
	label.add_theme_color_override("font_color", _severity_color(severity))
	label.add_theme_font_size_override("font_size", 13)
	return label

func _severity_icon(severity: String) -> String:
	match severity:
		SEVERITY_ERROR:
			return "✗"
		SEVERITY_WARNING:
			return "⚠"
		SEVERITY_SUCCESS:
			return "✓"
		_:
			return "ⓘ"

func _severity_color(severity: String) -> Color:
	match severity:
		SEVERITY_ERROR:
			return Color("#ff6b6b")
		SEVERITY_WARNING:
			return Color("#ffd166")
		SEVERITY_SUCCESS:
			return Color("#72d572")
		_:
			return Color("#93c5fd")
