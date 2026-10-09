class_name NxThemeBuilder
extends RefCounted
## Builds the NEXUS Theme resource from the design tokens in NxPalette.
##
## The generated theme is saved to res://ui/theme/nexus_theme.tres and set as
## the project theme (gui/theme/custom) so it is visible in the editor too.
## Regenerate it after changing tokens:
##     godot --headless --path . -s res://tools/build_theme.gd
##
## Type variations defined here (use them through `theme_type_variation`):
##   Buttons : PrimaryButton, GhostButton, DangerButton, ToolButton,
##             MenuEntryButton, NavButton, ChipButton
##   Panels  : Card, SidePanel, BarPanel, DialogPanel, ToastPanel, KeyCap, InsetPanel
##   Labels  : Wordmark, Headline, TitleLabel, SectionLabel, MutedLabel,
##             DimLabel, CaptionLabel, ValueLabel, AccentLabel

const P := preload("res://ui/theme/nx_palette.gd")

const FONT_DIR := "res://resources/fonts/"
const UI_DIR := "res://resources/ui/"

var _theme: Theme
var _regular: Font
var _medium: Font
var _semibold: Font
var _display: Font
var _mono: Font


static func build() -> Theme:
	var builder := NxThemeBuilder.new()
	return builder._build()


func _build() -> Theme:
	_theme = Theme.new()
	_load_fonts()
	_theme.default_font = _regular
	_theme.default_font_size = P.FONT_BODY

	_build_buttons()
	_build_panels()
	_build_labels()
	_build_inputs()
	_build_toggles()
	_build_sliders()
	_build_popups()
	_build_scroll()
	_build_tabs()
	_build_lists()
	_build_misc()
	return _theme


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func _load_fonts() -> void:
	_regular = load(FONT_DIR + "Inter-Regular.ttf")
	_medium = load(FONT_DIR + "Inter-Medium.ttf")
	_semibold = load(FONT_DIR + "Inter-SemiBold.ttf")
	_display = load(FONT_DIR + "InterDisplay-Bold.ttf")
	_mono = load(FONT_DIR + "JetBrainsMono-Regular.ttf")


static func flat(bg: Color, radius: int = P.RADIUS_M, border: Color = Color.TRANSPARENT,
		border_width: int = 0, margin_h: int = P.SPACE_M, margin_v: int = P.SPACE_S) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 6
	sb.anti_aliasing = true
	if border_width > 0:
		sb.border_color = border
		sb.set_border_width_all(border_width)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


static func empty(margin_h: int = 0, margin_v: int = 0) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


## Keyboard focus ring: an accent outline drawn around the control.
static func focus_ring(radius: int = P.RADIUS_M) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = P.ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius + 2)
	sb.set_expand_margin_all(2)
	sb.anti_aliasing = true
	return sb


func _tex(file: String) -> Texture2D:
	return load(UI_DIR + file)


func _font_colors(type: String, normal: Color, hover: Color, pressed: Color,
		disabled: Color, focus: Color = Color(-1, 0, 0)) -> void:
	if focus.r < 0.0:
		focus = hover
	for item in ["font_color", "icon_normal_color"]:
		_theme.set_color(item, type, normal)
	for item in ["font_hover_color", "icon_hover_color"]:
		_theme.set_color(item, type, hover)
	for item in ["font_pressed_color", "icon_pressed_color", "font_hover_pressed_color", "icon_hover_pressed_color"]:
		_theme.set_color(item, type, pressed)
	for item in ["font_focus_color", "icon_focus_color"]:
		_theme.set_color(item, type, focus)
	for item in ["font_disabled_color", "icon_disabled_color"]:
		_theme.set_color(item, type, disabled)


func _button_styles(type: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox,
		disabled: StyleBox, focus: StyleBox) -> void:
	_theme.set_stylebox("normal", type, normal)
	_theme.set_stylebox("hover", type, hover)
	_theme.set_stylebox("pressed", type, pressed)
	_theme.set_stylebox("hover_pressed", type, pressed)
	_theme.set_stylebox("disabled", type, disabled)
	_theme.set_stylebox("focus", type, focus)


func _variation(name: String, base: String) -> void:
	_theme.set_type_variation(name, base)


# -----------------------------------------------------------------------------
# Buttons
# -----------------------------------------------------------------------------

func _build_buttons() -> void:
	# Default button: quiet secondary surface.
	_button_styles("Button",
		flat(P.BG_3, P.RADIUS_M, P.BORDER, 1),
		flat(P.BG_4, P.RADIUS_M, P.BORDER_STRONG, 1),
		flat(P.ACCENT_SOFT, P.RADIUS_M, P.ACCENT_PRESSED, 1),
		flat(P.BG_2, P.RADIUS_M, P.BORDER, 1),
		focus_ring())
	_font_colors("Button", P.TEXT, Color.WHITE, P.ACCENT_HOVER, P.TEXT_DIM)
	_theme.set_font("font", "Button", _medium)
	_theme.set_font_size("font_size", "Button", P.FONT_LABEL)
	_theme.set_constant("h_separation", "Button", P.SPACE_S)
	_theme.set_constant("icon_max_width", "Button", 20)

	# Primary call to action.
	_variation("PrimaryButton", "Button")
	_button_styles("PrimaryButton",
		flat(P.ACCENT, P.RADIUS_M, Color.TRANSPARENT, 0, P.SPACE_L),
		flat(P.ACCENT_HOVER, P.RADIUS_M, Color.TRANSPARENT, 0, P.SPACE_L),
		flat(P.ACCENT_PRESSED, P.RADIUS_M, Color.TRANSPARENT, 0, P.SPACE_L),
		flat(P.BG_3, P.RADIUS_M, Color.TRANSPARENT, 0, P.SPACE_L),
		focus_ring())
	_font_colors("PrimaryButton", P.TEXT_ON_ACCENT, P.TEXT_ON_ACCENT, P.TEXT_ON_ACCENT, P.TEXT_DIM)
	_theme.set_font("font", "PrimaryButton", _semibold)

	# Ghost: no surface until hovered.
	_variation("GhostButton", "Button")
	_button_styles("GhostButton",
		empty(P.SPACE_M, P.SPACE_S),
		flat(P.BG_3),
		flat(P.BG_4),
		empty(P.SPACE_M, P.SPACE_S),
		focus_ring())
	_font_colors("GhostButton", P.TEXT_MUTED, P.TEXT, P.ACCENT, P.TEXT_DIM)

	# Destructive action.
	_variation("DangerButton", "Button")
	_button_styles("DangerButton",
		flat(Color(P.DANGER, 0.12), P.RADIUS_M, Color(P.DANGER, 0.5), 1, P.SPACE_L),
		flat(P.DANGER, P.RADIUS_M, Color.TRANSPARENT, 0, P.SPACE_L),
		flat(P.DANGER_HOVER, P.RADIUS_M, Color.TRANSPARENT, 0, P.SPACE_L),
		flat(P.BG_2, P.RADIUS_M, P.BORDER, 1, P.SPACE_L),
		focus_ring())
	_font_colors("DangerButton", P.DANGER_HOVER, Color.WHITE, Color.WHITE, P.TEXT_DIM)
	_theme.set_font("font", "DangerButton", _semibold)

	# Square icon buttons for toolbars; toggled state uses the accent tint.
	_variation("ToolButton", "Button")
	var tool_pad := 7
	_button_styles("ToolButton",
		empty(tool_pad, tool_pad),
		flat(P.BG_3, P.RADIUS_M, Color.TRANSPARENT, 0, tool_pad, tool_pad),
		flat(P.ACCENT_SOFT, P.RADIUS_M, Color(P.ACCENT, 0.35), 1, tool_pad, tool_pad),
		empty(tool_pad, tool_pad),
		focus_ring())
	_font_colors("ToolButton", P.TEXT_MUTED, P.TEXT, P.ACCENT, Color(P.TEXT_DIM, 0.6))

	# Large main-menu entries: accent bar appears on the left when hovered.
	_variation("MenuEntryButton", "Button")
	var menu_normal := empty(P.SPACE_XL, P.SPACE_M)
	var menu_hover := flat(Color(P.ACCENT, 0.08), P.RADIUS_S, P.ACCENT, 0, P.SPACE_XL, P.SPACE_M)
	menu_hover.border_width_left = 3
	menu_hover.corner_radius_top_left = 0
	menu_hover.corner_radius_bottom_left = 0
	var menu_pressed: StyleBoxFlat = menu_hover.duplicate()
	menu_pressed.bg_color = Color(P.ACCENT, 0.16)
	var menu_focus: StyleBoxFlat = menu_hover.duplicate()
	_button_styles("MenuEntryButton", menu_normal, menu_hover, menu_pressed, menu_normal, menu_focus)
	_font_colors("MenuEntryButton", P.TEXT, Color.WHITE, P.ACCENT_HOVER, P.TEXT_DIM, Color.WHITE)
	_theme.set_font("font", "MenuEntryButton", _medium)
	_theme.set_font_size("font_size", "MenuEntryButton", P.FONT_MENU)
	_theme.set_constant("h_separation", "MenuEntryButton", P.SPACE_L)
	_theme.set_constant("icon_max_width", "MenuEntryButton", 22)

	# Vertical navigation (settings categories). Toggled = selected.
	_variation("NavButton", "Button")
	var nav_sel := flat(P.ACCENT_SOFT, P.RADIUS_M, P.ACCENT, 0, P.SPACE_M, 10)
	_button_styles("NavButton",
		empty(P.SPACE_M, 10),
		flat(P.BG_3, P.RADIUS_M, Color.TRANSPARENT, 0, P.SPACE_M, 10),
		nav_sel,
		empty(P.SPACE_M, 10),
		focus_ring())
	_font_colors("NavButton", P.TEXT_MUTED, P.TEXT, P.ACCENT_HOVER, P.TEXT_DIM)
	_theme.set_constant("h_separation", "NavButton", P.SPACE_M)

	# Small rounded filter chips (category filters).
	_variation("ChipButton", "Button")
	_button_styles("ChipButton",
		flat(P.BG_2, 12, P.BORDER, 1, 10, 4),
		flat(P.BG_3, 12, P.BORDER_STRONG, 1, 10, 4),
		flat(P.ACCENT_SOFT, 12, Color(P.ACCENT, 0.6), 1, 10, 4),
		flat(P.BG_2, 12, P.BORDER, 1, 10, 4),
		focus_ring(10))
	_font_colors("ChipButton", P.TEXT_MUTED, P.TEXT, P.ACCENT_HOVER, P.TEXT_DIM)
	_theme.set_font_size("font_size", "ChipButton", P.FONT_CAPTION)
	_theme.set_constant("icon_max_width", "ChipButton", 14)
	_theme.set_constant("h_separation", "ChipButton", 6)

	# LinkButton (inline text links).
	_font_colors("LinkButton", P.ACCENT, P.ACCENT_HOVER, P.ACCENT_PRESSED, P.TEXT_DIM)
	_theme.set_stylebox("focus", "LinkButton", focus_ring(P.RADIUS_S))


# -----------------------------------------------------------------------------
# Panels
# -----------------------------------------------------------------------------

func _build_panels() -> void:
	_theme.set_stylebox("panel", "Panel", flat(P.BG_1, 0))
	_theme.set_stylebox("panel", "PanelContainer", flat(P.BG_1, 0, P.BORDER, 0, 0, 0))

	_variation("Card", "PanelContainer")
	_theme.set_stylebox("panel", "Card", flat(P.BG_2, P.RADIUS_L, P.BORDER, 1, P.SPACE_L, P.SPACE_L))

	_variation("InsetPanel", "PanelContainer")
	_theme.set_stylebox("panel", "InsetPanel", flat(P.BG_0, P.RADIUS_M, P.BORDER, 1, P.SPACE_M, P.SPACE_M))

	_variation("SidePanel", "PanelContainer")
	var side := flat(Color(P.BG_1, 0.96), P.RADIUS_L, P.BORDER, 1, 0, 0)
	side.shadow_color = Color(0, 0, 0, 0.35)
	side.shadow_size = 12
	_theme.set_stylebox("panel", "SidePanel", side)

	_variation("BarPanel", "PanelContainer")
	var bar := flat(Color(P.BG_1, 0.96), P.RADIUS_L, P.BORDER, 1, P.SPACE_S, 6)
	bar.shadow_color = Color(0, 0, 0, 0.3)
	bar.shadow_size = 10
	_theme.set_stylebox("panel", "BarPanel", bar)

	_variation("DialogPanel", "PanelContainer")
	var dialog := flat(P.BG_1, P.RADIUS_L + 2, P.BORDER_STRONG, 1, 0, 0)
	dialog.shadow_color = Color(0, 0, 0, 0.55)
	dialog.shadow_size = 32
	dialog.shadow_offset = Vector2(0, 8)
	_theme.set_stylebox("panel", "DialogPanel", dialog)

	_variation("ToastPanel", "PanelContainer")
	var toast := flat(P.BG_2, P.RADIUS_L, P.BORDER_STRONG, 1, P.SPACE_L, P.SPACE_M)
	toast.shadow_color = Color(0, 0, 0, 0.45)
	toast.shadow_size = 16
	_theme.set_stylebox("panel", "ToastPanel", toast)

	_variation("KeyCap", "PanelContainer")
	var keycap := flat(P.BG_3, P.RADIUS_S, P.BORDER_STRONG, 1, 6, 1)
	keycap.border_width_bottom = 2
	_theme.set_stylebox("panel", "KeyCap", keycap)


# -----------------------------------------------------------------------------
# Labels
# -----------------------------------------------------------------------------

func _label_variation(name: String, font: Font, size: int, color: Color) -> void:
	_variation(name, "Label")
	_theme.set_font("font", name, font)
	_theme.set_font_size("font_size", name, size)
	_theme.set_color("font_color", name, color)


func _build_labels() -> void:
	_theme.set_color("font_color", "Label", P.TEXT)
	_theme.set_constant("line_spacing", "Label", 3)

	var wordmark := FontVariation.new()
	wordmark.base_font = _display
	wordmark.spacing_glyph = 14
	_label_variation("Wordmark", wordmark, P.FONT_DISPLAY, P.TEXT)

	_label_variation("Headline", _display, P.FONT_HEADLINE, P.TEXT)
	_label_variation("TitleLabel", _semibold, P.FONT_TITLE, P.TEXT)

	var section := FontVariation.new()
	section.base_font = _semibold
	section.spacing_glyph = 1
	_label_variation("SectionLabel", section, P.FONT_CAPTION, P.TEXT_DIM)

	_label_variation("MutedLabel", _regular, P.FONT_LABEL, P.TEXT_MUTED)
	_label_variation("DimLabel", _regular, P.FONT_LABEL, P.TEXT_DIM)
	_label_variation("CaptionLabel", _regular, P.FONT_CAPTION, P.TEXT_MUTED)
	_label_variation("ValueLabel", _mono, P.FONT_LABEL - 1, P.TEXT)
	_label_variation("AccentLabel", _semibold, P.FONT_LABEL, P.ACCENT)

	_theme.set_font("normal_font", "RichTextLabel", _regular)
	_theme.set_font("bold_font", "RichTextLabel", _semibold)
	_theme.set_font("mono_font", "RichTextLabel", _mono)
	_theme.set_color("default_color", "RichTextLabel", P.TEXT_MUTED)
	_theme.set_font_size("normal_font_size", "RichTextLabel", P.FONT_LABEL)
	_theme.set_font_size("bold_font_size", "RichTextLabel", P.FONT_LABEL)
	_theme.set_font_size("mono_font_size", "RichTextLabel", P.FONT_LABEL - 1)
	_theme.set_stylebox("focus", "RichTextLabel", empty())
	_theme.set_stylebox("normal", "RichTextLabel", empty())


# -----------------------------------------------------------------------------
# Text inputs
# -----------------------------------------------------------------------------

func _build_inputs() -> void:
	var normal := flat(P.BG_0, P.RADIUS_M, P.BORDER_STRONG, 1, 10, 7)
	var focus := flat(P.BG_0, P.RADIUS_M, P.ACCENT, 1, 10, 7)
	var read_only := flat(P.BG_2, P.RADIUS_M, P.BORDER, 1, 10, 7)
	for type in ["LineEdit", "TextEdit"]:
		_theme.set_stylebox("normal", type, normal)
		_theme.set_stylebox("focus", type, focus)
		_theme.set_stylebox("read_only", type, read_only)
		_theme.set_color("font_color", type, P.TEXT)
		_theme.set_color("font_placeholder_color", type, P.TEXT_DIM)
		_theme.set_color("font_readonly_color", type, P.TEXT_MUTED)
		_theme.set_color("caret_color", type, P.ACCENT)
		_theme.set_color("selection_color", type, Color(P.ACCENT, 0.3))
		_theme.set_color("font_selected_color", type, Color.WHITE)
		_theme.set_font_size("font_size", type, P.FONT_LABEL)
	_theme.set_constant("caret_width", "LineEdit", 2)
	_theme.set_icon("clear", "LineEdit", _tex("clear.svg"))
	_theme.set_color("clear_button_color", "LineEdit", P.TEXT_MUTED)
	_theme.set_color("clear_button_color_pressed", "LineEdit", P.ACCENT)
	_theme.set_icon("updown", "SpinBox", _tex("updown.svg"))


# -----------------------------------------------------------------------------
# Toggles: CheckBox, CheckButton
# -----------------------------------------------------------------------------

func _build_toggles() -> void:
	for type in ["CheckBox", "CheckButton"]:
		var pad := empty(2, 4)
		_button_styles(type, pad, pad, pad, pad, focus_ring(P.RADIUS_S))
		_font_colors(type, P.TEXT, Color.WHITE, P.TEXT, P.TEXT_DIM)
		_theme.set_constant("h_separation", type, P.SPACE_M)
		_theme.set_font_size("font_size", type, P.FONT_LABEL)

	_theme.set_icon("checked", "CheckBox", _tex("checkbox_on.svg"))
	_theme.set_icon("unchecked", "CheckBox", _tex("checkbox_off.svg"))
	_theme.set_icon("checked_disabled", "CheckBox", _tex("checkbox_on.svg"))
	_theme.set_icon("unchecked_disabled", "CheckBox", _tex("checkbox_off.svg"))
	_theme.set_icon("radio_checked", "CheckBox", _tex("radio_on.svg"))
	_theme.set_icon("radio_unchecked", "CheckBox", _tex("radio_off.svg"))
	_theme.set_icon("radio_checked_disabled", "CheckBox", _tex("radio_on.svg"))
	_theme.set_icon("radio_unchecked_disabled", "CheckBox", _tex("radio_off.svg"))

	for suffix in ["", "_mirrored"]:
		_theme.set_icon("checked" + suffix, "CheckButton", _tex("toggle_on.svg"))
		_theme.set_icon("unchecked" + suffix, "CheckButton", _tex("toggle_off.svg"))
		_theme.set_icon("checked_disabled" + suffix, "CheckButton", _tex("toggle_on_disabled.svg"))
		_theme.set_icon("unchecked_disabled" + suffix, "CheckButton", _tex("toggle_off_disabled.svg"))


# -----------------------------------------------------------------------------
# Sliders and progress
# -----------------------------------------------------------------------------

func _build_sliders() -> void:
	for type in ["HSlider", "VSlider"]:
		var track := flat(P.BG_4, 3, Color.TRANSPARENT, 0, 0, 2)
		var fill := flat(P.ACCENT, 3, Color.TRANSPARENT, 0, 0, 2)
		var fill_hl := flat(P.ACCENT_HOVER, 3, Color.TRANSPARENT, 0, 0, 2)
		_theme.set_stylebox("slider", type, track)
		_theme.set_stylebox("grabber_area", type, fill)
		_theme.set_stylebox("grabber_area_highlight", type, fill_hl)
		_theme.set_icon("grabber", type, _tex("grabber.svg"))
		_theme.set_icon("grabber_highlight", type, _tex("grabber_highlight.svg"))
		_theme.set_icon("grabber_disabled", type, _tex("grabber_disabled.svg"))
		_theme.set_constant("center_grabber", type, 1)

	_theme.set_stylebox("background", "ProgressBar", flat(P.BG_3, 3, Color.TRANSPARENT, 0, 0, 0))
	_theme.set_stylebox("fill", "ProgressBar", flat(P.ACCENT, 3, Color.TRANSPARENT, 0, 0, 0))
	_theme.set_color("font_color", "ProgressBar", P.TEXT)
	_theme.set_font_size("font_size", "ProgressBar", P.FONT_CAPTION)


# -----------------------------------------------------------------------------
# Popups, option buttons, tooltips, windows
# -----------------------------------------------------------------------------

func _build_popups() -> void:
	# OptionButton looks like an input with a chevron.
	var ob_normal := flat(P.BG_3, P.RADIUS_M, P.BORDER, 1, P.SPACE_M, 7)
	var ob_hover := flat(P.BG_4, P.RADIUS_M, P.BORDER_STRONG, 1, P.SPACE_M, 7)
	var ob_pressed := flat(P.BG_4, P.RADIUS_M, P.ACCENT, 1, P.SPACE_M, 7)
	_button_styles("OptionButton", ob_normal, ob_hover, ob_pressed,
		flat(P.BG_2, P.RADIUS_M, P.BORDER, 1, P.SPACE_M, 7), focus_ring())
	_font_colors("OptionButton", P.TEXT, Color.WHITE, P.TEXT, P.TEXT_DIM)
	_theme.set_icon("arrow", "OptionButton", _tex("arrow_down.svg"))
	_theme.set_constant("arrow_margin", "OptionButton", P.SPACE_M)
	_theme.set_font_size("font_size", "OptionButton", P.FONT_LABEL)

	var popup := flat(P.BG_2, P.RADIUS_M, P.BORDER_STRONG, 1, 4, 4)
	popup.shadow_color = Color(0, 0, 0, 0.45)
	popup.shadow_size = 14
	_theme.set_stylebox("panel", "PopupMenu", popup)
	_theme.set_stylebox("hover", "PopupMenu", flat(P.ACCENT_SOFT, P.RADIUS_S, Color.TRANSPARENT, 0, 8, 4))
	var sep := StyleBoxLine.new()
	sep.color = P.BORDER
	sep.thickness = 1
	sep.grow_begin = -6
	sep.grow_end = -6
	_theme.set_stylebox("separator", "PopupMenu", sep)
	_theme.set_stylebox("labeled_separator_left", "PopupMenu", sep)
	_theme.set_stylebox("labeled_separator_right", "PopupMenu", sep)
	_theme.set_color("font_color", "PopupMenu", P.TEXT)
	_theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	_theme.set_color("font_disabled_color", "PopupMenu", P.TEXT_DIM)
	_theme.set_color("font_accelerator_color", "PopupMenu", P.TEXT_DIM)
	_theme.set_color("font_separator_color", "PopupMenu", P.TEXT_DIM)
	_theme.set_constant("v_separation", "PopupMenu", 8)
	_theme.set_constant("h_separation", "PopupMenu", 10)
	_theme.set_constant("item_start_padding", "PopupMenu", 10)
	_theme.set_constant("item_end_padding", "PopupMenu", 14)
	_theme.set_font_size("font_size", "PopupMenu", P.FONT_LABEL)
	_theme.set_icon("checked", "PopupMenu", _tex("checkbox_on.svg"))
	_theme.set_icon("unchecked", "PopupMenu", _tex("checkbox_off.svg"))
	_theme.set_icon("radio_checked", "PopupMenu", _tex("radio_on.svg"))
	_theme.set_icon("radio_unchecked", "PopupMenu", _tex("radio_off.svg"))
	_theme.set_icon("submenu", "PopupMenu", _tex("submenu.svg"))
	_theme.set_stylebox("panel", "PopupPanel", popup)

	var tip := flat(P.BG_3, P.RADIUS_M, P.BORDER_STRONG, 1, 10, 6)
	_theme.set_stylebox("panel", "TooltipPanel", tip)
	_theme.set_color("font_color", "TooltipLabel", P.TEXT)
	_theme.set_font_size("font_size", "TooltipLabel", P.FONT_CAPTION + 1)
	_theme.set_font("font", "TooltipLabel", _regular)

	# Native windows are rarely used (NxDialog is preferred) but stay on-brand.
	var win := flat(P.BG_1, P.RADIUS_L, P.BORDER_STRONG, 1, 0, 0)
	win.expand_margin_top = 32
	win.expand_margin_left = 1
	win.expand_margin_right = 1
	win.expand_margin_bottom = 1
	_theme.set_stylebox("embedded_border", "Window", win)
	_theme.set_stylebox("embedded_unfocused_border", "Window", win)
	_theme.set_color("title_color", "Window", P.TEXT)
	_theme.set_font("title_font", "Window", _semibold)
	_theme.set_font_size("title_font_size", "Window", P.FONT_LABEL)
	_theme.set_constant("title_height", "Window", 32)
	_theme.set_stylebox("panel", "AcceptDialog", flat(P.BG_1, 0, Color.TRANSPARENT, 0, P.SPACE_L, P.SPACE_L))


# -----------------------------------------------------------------------------
# Scrolling
# -----------------------------------------------------------------------------

func _build_scroll() -> void:
	for type in ["VScrollBar", "HScrollBar"]:
		var thin := empty(4, 4)
		_theme.set_stylebox("scroll", type, thin)
		_theme.set_stylebox("scroll_focus", type, thin)
		_theme.set_stylebox("grabber", type, flat(P.BG_4, 4, Color.TRANSPARENT, 0, 3, 3))
		_theme.set_stylebox("grabber_highlight", type, flat(P.BORDER_STRONG, 4, Color.TRANSPARENT, 0, 3, 3))
		_theme.set_stylebox("grabber_pressed", type, flat(P.TEXT_DIM, 4, Color.TRANSPARENT, 0, 3, 3))
	_theme.set_stylebox("panel", "ScrollContainer", empty())


# -----------------------------------------------------------------------------
# Tabs
# -----------------------------------------------------------------------------

func _build_tabs() -> void:
	var sel := flat(P.BG_1, 0, P.ACCENT, 0, P.SPACE_L, P.SPACE_S)
	sel.border_width_bottom = 2
	var unsel := empty(P.SPACE_L, P.SPACE_S)
	var hov := flat(P.BG_2, 0, Color.TRANSPARENT, 0, P.SPACE_L, P.SPACE_S)
	for type in ["TabBar", "TabContainer"]:
		_theme.set_stylebox("tab_selected", type, sel)
		_theme.set_stylebox("tab_unselected", type, unsel)
		_theme.set_stylebox("tab_hovered", type, hov)
		_theme.set_stylebox("tab_disabled", type, unsel)
		_theme.set_stylebox("tab_focus", type, focus_ring(0))
		_theme.set_color("font_selected_color", type, P.TEXT)
		_theme.set_color("font_unselected_color", type, P.TEXT_MUTED)
		_theme.set_color("font_hovered_color", type, P.TEXT)
		_theme.set_color("font_disabled_color", type, P.TEXT_DIM)
		_theme.set_font("font", type, _medium)
		_theme.set_font_size("font_size", type, P.FONT_LABEL)
	_theme.set_stylebox("panel", "TabContainer", flat(P.BG_1, 0, Color.TRANSPARENT, 0, P.SPACE_L, P.SPACE_L))
	var tab_bg := flat(P.BG_0, 0, P.BORDER, 0, 0, 0)
	tab_bg.border_width_bottom = 1
	_theme.set_stylebox("tabbar_background", "TabContainer", tab_bg)


# -----------------------------------------------------------------------------
# Lists and trees
# -----------------------------------------------------------------------------

func _build_lists() -> void:
	for type in ["ItemList", "Tree"]:
		_theme.set_stylebox("panel", type, flat(P.BG_0, P.RADIUS_M, P.BORDER, 1, 4, 4))
		_theme.set_stylebox("focus", type, empty())
		var selected := flat(P.ACCENT_SOFT, P.RADIUS_S, Color.TRANSPARENT, 0, 6, 4)
		_theme.set_stylebox("selected", type, selected)
		_theme.set_stylebox("selected_focus", type, selected)
		_theme.set_stylebox("hovered", type, flat(P.BG_3, P.RADIUS_S, Color.TRANSPARENT, 0, 6, 4))
		_theme.set_stylebox("cursor", type, empty())
		_theme.set_stylebox("cursor_unfocused", type, empty())
		_theme.set_color("font_color", type, P.TEXT)
		_theme.set_color("font_selected_color", type, Color.WHITE)
		_theme.set_color("font_hovered_color", type, Color.WHITE)
		_theme.set_color("guide_color", type, Color.TRANSPARENT)
		_theme.set_font_size("font_size", type, P.FONT_LABEL)
	_theme.set_constant("v_separation", "ItemList", 6)
	_theme.set_constant("h_separation", "ItemList", 8)


# -----------------------------------------------------------------------------
# Separators and containers
# -----------------------------------------------------------------------------

func _build_misc() -> void:
	var hsep := StyleBoxLine.new()
	hsep.color = P.BORDER
	hsep.thickness = 1
	_theme.set_stylebox("separator", "HSeparator", hsep)
	_theme.set_constant("separation", "HSeparator", 1)
	var vsep := StyleBoxLine.new()
	vsep.color = P.BORDER
	vsep.thickness = 1
	vsep.vertical = true
	_theme.set_stylebox("separator", "VSeparator", vsep)
	_theme.set_constant("separation", "VSeparator", 1)

	_theme.set_constant("separation", "BoxContainer", P.SPACE_S)
	_theme.set_constant("separation", "HBoxContainer", P.SPACE_S)
	_theme.set_constant("separation", "VBoxContainer", P.SPACE_S)
	_theme.set_constant("h_separation", "GridContainer", P.SPACE_M)
	_theme.set_constant("v_separation", "GridContainer", P.SPACE_M)
	_theme.set_constant("h_separation", "FlowContainer", 6)
	_theme.set_constant("v_separation", "FlowContainer", 6)
	_theme.set_constant("h_separation", "HFlowContainer", 6)
	_theme.set_constant("v_separation", "HFlowContainer", 6)
