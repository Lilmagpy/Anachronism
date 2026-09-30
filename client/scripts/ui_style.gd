## The game's look: fonts, colours and ready-made panels and buttons, in a bright style like
## Rise of Kingdoms (D-059): cream panels with gold trim, bold gold buttons, big titles.
class_name UiStyle
extends RefCounted

const CREAM := Color(0.97, 0.93, 0.84)
const PARCHMENT := Color(0.93, 0.86, 0.71)
const INK := Color(0.17, 0.12, 0.08)
const INK_SOFT := Color(0.38, 0.30, 0.22)
const GOLD := Color(0.96, 0.76, 0.26)
const GOLD_DARK := Color(0.66, 0.44, 0.12)
const RED := Color(0.72, 0.18, 0.14)
const NIGHT := Color(0.09, 0.08, 0.10)

static var _fonts := {}


## A font by role: "title" (Cinzel), "body" (Nunito) or "emblem" (Chinese characters),
## at a weight from 400 (regular) to 900 (black).
static func font(role: String, weight := 400) -> Font:
	var key := "%s:%d" % [role, weight]
	if _fonts.has(key):
		return _fonts[key]
	var path: String = {"title": "res://fonts/Cinzel.ttf", "body": "res://fonts/Nunito.ttf",
		"emblem": "res://fonts/emblems.ttf"}[role]
	var base := FontFile.new()
	base.data = FileAccess.get_file_as_bytes(path)
	var variation := FontVariation.new()
	variation.base_font = base
	if role != "emblem":
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	# Characters missing from a font (e.g. 秦 in Nunito) fall back to the emblem font.
	if role != "emblem":
		var emblem := FontFile.new()
		emblem.data = FileAccess.get_file_as_bytes("res://fonts/emblems.ttf")
		variation.fallbacks = [emblem]
	_fonts[key] = variation
	return variation


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("body", 600)
	t.default_font_size = 17
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", panel())
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", button_box(state))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	t.set_font("font", "Button", font("body", 800))
	return t


static func panel(fill := CREAM, border := GOLD_DARK, radius := 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(18)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	return box


static func button_box(state: String, base := GOLD) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.border_color = GOLD_DARK
	box.set_border_width_all(3)
	box.border_width_bottom = 6  # a chunky lip, like a physical button
	match state:
		"hover":
			box.bg_color = base.lightened(0.15)
		"pressed":
			box.bg_color = base.darkened(0.1)
			box.border_width_bottom = 3
			box.content_margin_top = 11
		"disabled":
			box.bg_color = Color(0.75, 0.72, 0.66)
			box.border_color = Color(0.55, 0.52, 0.48)
		"focus":
			box.draw_center = false
			box.border_color = Color(0, 0, 0, 0)
		_:
			box.bg_color = base
	return box


static func label(text: String, size := 17, colour := INK, role := "body", weight := 600) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(role, weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


static func wrapped(text: String, size := 16, colour := INK_SOFT, width := 360.0) -> Label:
	var l := label(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


## A big title with a dark outline, for use over pictures.
static func headline(text: String, size := 64, colour := CREAM) -> Label:
	var l := label(text, size, colour, "title", 900)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.03))
	l.add_theme_constant_override("outline_size", maxi(6, size / 7))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", size / 14)
	return l


static func big_button(text: String, size := 26, base := GOLD) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font("title", 900))
	b.add_theme_font_size_override("font_size", size)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, button_box(state, base))
	return b
