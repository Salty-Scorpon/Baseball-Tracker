class_name DateField
extends HBoxContainer

const DateUtils := preload("res://data/date_utils.gd")

signal date_changed(date_text: String)

var selected_date := ""
var display_year := 0
var display_month := 0

var date_edit: LineEdit
var picker_button: Button
var clear_button: Button
var popup: PopupPanel
var month_label: Label
var days_grid: GridContainer

func _ready() -> void:
	_build_control()
	if selected_date.is_empty():
		_set_display_from_today()
	else:
		_set_display_from_date(selected_date)
	_refresh_calendar()

func set_date_text(value: String) -> void:
	selected_date = value.strip_edges()
	if date_edit != null:
		date_edit.text = selected_date
	if DateUtils.is_valid_iso_date(selected_date) and not selected_date.is_empty():
		_set_display_from_date(selected_date)
	elif display_year == 0:
		_set_display_from_today()
	if days_grid != null:
		_refresh_calendar()

func get_date_text() -> String:
	return date_edit.text.strip_edges() if date_edit != null else selected_date

func _build_control() -> void:
	if date_edit != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_edit = LineEdit.new()
	date_edit.placeholder_text = "YYYY-MM-DD"
	date_edit.text = selected_date
	date_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_edit.text_changed.connect(_on_date_text_changed)
	add_child(date_edit)

	picker_button = Button.new()
	picker_button.text = "📅"
	picker_button.tooltip_text = "Select date"
	picker_button.pressed.connect(_show_popup)
	add_child(picker_button)

	clear_button = Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(_clear_date)
	add_child(clear_button)

	popup = PopupPanel.new()
	add_child(popup)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(280, 260)
	popup.add_child(panel)

	var header := HBoxContainer.new()
	panel.add_child(header)
	var previous := Button.new()
	previous.text = "‹"
	previous.pressed.connect(func() -> void: _change_month(-1))
	header.add_child(previous)
	month_label = Label.new()
	month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(month_label)
	var next := Button.new()
	next.text = "›"
	next.pressed.connect(func() -> void: _change_month(1))
	header.add_child(next)

	days_grid = GridContainer.new()
	days_grid.columns = 7
	panel.add_child(days_grid)

func _on_date_text_changed(value: String) -> void:
	selected_date = value.strip_edges()
	if DateUtils.is_valid_iso_date(selected_date) and not selected_date.is_empty():
		_set_display_from_date(selected_date)
		_refresh_calendar()
	date_changed.emit(selected_date)

func _show_popup() -> void:
	if DateUtils.is_valid_iso_date(get_date_text()) and not get_date_text().is_empty():
		_set_display_from_date(get_date_text())
	_refresh_calendar()
	popup.popup(Rect2i(picker_button.global_position, Vector2i(280, 260)))

func _change_month(delta: int) -> void:
	display_month += delta
	while display_month < 1:
		display_month += 12
		display_year -= 1
	while display_month > 12:
		display_month -= 12
		display_year += 1
	_refresh_calendar()

func _refresh_calendar() -> void:
	if days_grid == null:
		return
	for child in days_grid.get_children():
		child.queue_free()
	month_label.text = "%s %d" % [DateUtils.MONTH_NAMES[display_month - 1], display_year]
	for weekday in DateUtils.WEEKDAY_NAMES:
		var label := Label.new()
		label.text = weekday
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		days_grid.add_child(label)
	for i in range(DateUtils.first_weekday_of_month(display_year, display_month)):
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(36, 28)
		days_grid.add_child(spacer)
	for day in range(1, DateUtils.days_in_month(display_year, display_month) + 1):
		var button := Button.new()
		button.text = str(day)
		button.custom_minimum_size = Vector2(36, 28)
		var date_text := DateUtils.format_date(display_year, display_month, day)
		button.disabled = false
		if date_text == selected_date:
			button.text = "[%d]" % day
		button.pressed.connect(_select_date.bind(date_text))
		days_grid.add_child(button)

func _clear_date() -> void:
	set_date_text("")
	date_changed.emit("")

func _select_date(date_text: String) -> void:
	set_date_text(date_text)
	date_changed.emit(date_text)
	popup.hide()

func _set_display_from_today() -> void:
	_set_display_from_date(DateUtils.today_iso())

func _set_display_from_date(date_text: String) -> void:
	var parsed := DateUtils.parse_iso_date(date_text)
	if parsed.is_empty():
		return
	display_year = int(parsed["year"])
	display_month = int(parsed["month"])
