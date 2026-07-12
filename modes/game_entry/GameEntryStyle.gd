class_name GameEntryStyle
extends RefCounted

const BACKGROUND_COLOR = Color("#101419")
const DOCK_COLOR = Color("#171d24")
const PANEL_COLOR = Color("#202832")
const PANEL_HEADER_COLOR = Color("#2a3440")
const BORDER_COLOR = Color("#3a4654")
const TEXT_COLOR = Color("#d8e0ea")
const MUTED_TEXT_COLOR = Color("#93a0ad")
const ACCENT_COLOR = Color("#4f8cff")
const ACCENT_DARK_COLOR = Color("#244b8f")
const BUTTON_COLOR = Color("#27313d")
const BUTTON_HOVER_COLOR = Color("#344150")
const BUTTON_PRESSED_COLOR = Color("#3f587a")
const BUTTON_DISABLED_COLOR = Color("#1c222a")
const BUTTON_DISABLED_TEXT_COLOR = Color("#65707c")

static func apply_shell_style(root: Control, background: ColorRect, dock_panels: Array, content_panels: Array, title_labels: Array, body_labels: Array, buttons: Array) -> void:
	if is_instance_valid(background):
		background.color = BACKGROUND_COLOR
	if is_instance_valid(root):
		root.add_theme_color_override("font_color", TEXT_COLOR)
	for panel in dock_panels:
		style_dock_panel(panel)
	for panel in content_panels:
		style_content_panel(panel)
	for label in title_labels:
		style_title_label(label)
	for label in body_labels:
		style_body_label(label)
	for button in buttons:
		style_button(button)

static func style_dock_panel(panel: PanelContainer) -> void:
	if not is_instance_valid(panel):
		return
	panel.add_theme_stylebox_override("panel", _panel_box(DOCK_COLOR, BORDER_COLOR, 10, 10))

static func style_content_panel(panel: PanelContainer) -> void:
	if not is_instance_valid(panel):
		return
	panel.add_theme_stylebox_override("panel", _panel_box(PANEL_COLOR, BORDER_COLOR, 8, 8))

static func style_title_label(label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_stylebox_override("normal", _panel_box(PANEL_HEADER_COLOR, Color(0, 0, 0, 0), 6, 6))

static func style_body_label(label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 13)

static func style_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", BUTTON_DISABLED_TEXT_COLOR)
	button.add_theme_stylebox_override("normal", _button_box(BUTTON_COLOR, BORDER_COLOR))
	button.add_theme_stylebox_override("hover", _button_box(BUTTON_HOVER_COLOR, ACCENT_COLOR))
	button.add_theme_stylebox_override("pressed", _button_box(BUTTON_PRESSED_COLOR, ACCENT_COLOR))
	button.add_theme_stylebox_override("disabled", _button_box(BUTTON_DISABLED_COLOR, Color("#2a313a")))
	button.add_theme_stylebox_override("focus", _button_box(BUTTON_HOVER_COLOR, ACCENT_COLOR))

static func set_button_selected(button: Button, selected: bool) -> void:
	if not is_instance_valid(button):
		return
	if selected:
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _button_box(ACCENT_DARK_COLOR, ACCENT_COLOR))
		button.add_theme_stylebox_override("hover", _button_box(ACCENT_DARK_COLOR.lightened(0.12), ACCENT_COLOR))
		button.add_theme_stylebox_override("pressed", _button_box(ACCENT_DARK_COLOR.lightened(0.2), ACCENT_COLOR))
	else:
		style_button(button)

static func _panel_box(color: Color, border_color: Color, corner_radius: int, content_margin: int) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = corner_radius
	box.corner_radius_top_right = corner_radius
	box.corner_radius_bottom_right = corner_radius
	box.corner_radius_bottom_left = corner_radius
	box.content_margin_left = content_margin
	box.content_margin_top = content_margin
	box.content_margin_right = content_margin
	box.content_margin_bottom = content_margin
	return box

static func _button_box(color: Color, border_color: Color) -> StyleBoxFlat:
	var box = _panel_box(color, border_color, 6, 8)
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
