## A civilisation's shield badge with its emblem (秦, 楚…), used in the picker's bottom row.
class_name CivBadge
extends Control

signal chosen(civ_id: String)

var civ: Dictionary = {}
var selected := false


func setup(civ_data: Dictionary) -> void:
	civ = civ_data
	custom_minimum_size = Vector2(118, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = str(civ["name"])
	if int(civ.get("chronicle", 0)) > 0:
		tooltip_text += "\nA chronicle: %d chapters of real history to follow" % int(civ["chronicle"])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(str(civ["id"]))


func _draw() -> void:
	var colour := Color(civ["colour"])
	var lift := 0.0
	var w := 100.0
	var h := 112.0
	var o := Vector2((size.x - w) / 2.0, 12 + lift)
	var shield := PackedVector2Array([o + Vector2(0, 8), o + Vector2(8, 0), o + Vector2(w - 8, 0),
		o + Vector2(w, 8), o + Vector2(w, h * 0.62), o + Vector2(w / 2, h), o + Vector2(0, h * 0.62)])
	if selected:
		var glow := PackedVector2Array()
		for p in shield:
			glow.append(o + Vector2(w / 2, h / 2) + (p - o - Vector2(w / 2, h / 2)) * 1.14)
		draw_colored_polygon(glow, Color(1.0, 0.95, 0.6, 0.85))
	var art := Symbols.shield(colour, str(civ.get("symbol", "")), int(h))
	if str(civ.get("symbol", "")) != "":
		draw_texture_rect(art, Rect2(o + Vector2((w - h * 0.86) / 2.0, 0), Vector2(h * 0.86, h)), false)
		_draw_name(selected)
		return
	draw_colored_polygon(shield, colour.darkened(0.15))
	var inner := PackedVector2Array()
	for p in shield:
		inner.append(o + Vector2(w / 2, h / 2) + (p - o - Vector2(w / 2, h / 2)) * 0.86)
	draw_colored_polygon(inner, colour)
	shield.append(shield[0])
	draw_polyline(shield, UiStyle.GOLD if selected else UiStyle.GOLD_DARK, 4.0)
	var emblem := str(civ.get("emblem", "?"))
	var font := UiStyle.font("emblem") if emblem.unicode_at(0) > 127 else UiStyle.font("title", 900)
	var font_size := 50 if emblem.length() == 1 else 32
	var text_size := font.get_string_size(emblem, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := o + Vector2((w - text_size.x) / 2, h * 0.42 + font_size * 0.36)
	draw_string_outline(font, at, emblem, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color(0.1, 0.06, 0.03))
	draw_string(font, at, emblem, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiStyle.CREAM)
	_draw_name(selected)


func _draw_name(is_selected: bool) -> void:
	var name_font := UiStyle.font("body", 800)
	var name := str(civ["name"])
	var name_size := 15 if name.length() < 13 else 12
	var nw := name_font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var name_at := Vector2((size.x - nw) / 2, size.y - 6)
	draw_string_outline(name_font, name_at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, 5, Color(0.1, 0.06, 0.03))
	draw_string(name_font, name_at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, UiStyle.CREAM if not is_selected else UiStyle.GOLD)
	_draw_chronicle_seal()


## A gold seal on the shield's shoulder for a state with a chronicle, showing its chapters.
func _draw_chronicle_seal() -> void:
	var chapters := int(civ.get("chronicle", 0))
	if chapters <= 0:
		return
	var centre := Vector2(size.x / 2.0 + 44, 18)
	draw_circle(centre, 15, Color(0.25, 0.12, 0.05))
	draw_circle(centre, 13, UiStyle.GOLD)
	draw_arc(centre, 10, 0, TAU, 24, UiStyle.GOLD_DARK, 1.5)
	var font := UiStyle.font("body", 900)
	var text := str(chapters)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, centre + Vector2(-tw / 2.0, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.25, 0.12, 0.05))
