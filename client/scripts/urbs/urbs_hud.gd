## Urbs (D-289): a thin overlay for the city: the year, the hint for the camera in use, a
## Back-to-map button and the monument card (name in Latin and English, date and builder, the
## form, the sources in small text, and an Enter button). It keeps no state of its own: Urbs
## tells it what to show.
class_name UrbsHud
extends CanvasLayer

signal back_pressed
signal enter_pressed
signal card_closed

const HINTS := {
	UrbsCamera.Mode.CITY: "Scroll to zoom in · drag to move · right-drag to turn · click a building",
	UrbsCamera.Mode.STREET: "WASD to walk · shift to run · right-drag to look · scroll to rise or sink · Esc to rise out",
	UrbsCamera.Mode.INSIDE: "WASD to walk · right-drag to look · Esc to go back out",
}

var _root := Control.new()
var _year := Label.new()
var _hint := Label.new()
var _back := Button.new()
var _card := PanelContainer.new()
var _card_body := VBoxContainer.new()
var _title_bar := PanelContainer.new()
var _title := Label.new()
var _mode := UrbsCamera.Mode.CITY


func _ready() -> void:
	layer = 20
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiStyle.theme()
	add_child(_root)
	# the year, top left
	var year_box := PanelContainer.new()
	year_box.add_theme_stylebox_override("panel", _small_panel())
	year_box.position = Vector2(16, 14)
	_year.add_theme_font_override("font", UiStyle.font("title", 800))
	_year.add_theme_font_size_override("font_size", 24)
	_year.add_theme_color_override("font_color", UiStyle.INK)
	year_box.add_child(_year)
	year_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(year_box)
	# back to the map, top right
	_back = UiStyle.big_button("Back to map", 18)
	_back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_back.offset_left = -190
	_back.offset_right = -16
	_back.offset_top = 14
	_back.pressed.connect(func() -> void: back_pressed.emit())
	_root.add_child(_back)
	# the hint, bottom centre
	var hint_box := PanelContainer.new()
	hint_box.add_theme_stylebox_override("panel", _small_panel(Color(0.97, 0.93, 0.84, 0.86)))
	hint_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_box.offset_top = -52
	hint_box.offset_bottom = -14
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font", UiStyle.font("body", 700))
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", UiStyle.INK_SOFT)
	hint_box.add_child(_hint)
	_root.add_child(hint_box)
	# the monument card, right
	_card.add_theme_stylebox_override("panel", UiStyle.panel())
	_card.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_card.anchor_top = 0.0
	_card.anchor_bottom = 0.0
	_card.offset_left = -400
	_card.offset_right = -16
	_card.offset_top = 70
	_card.visible = false
	_card_body.add_theme_constant_override("separation", 6)
	_card.add_child(_card_body)
	_root.add_child(_card)
	set_mode(UrbsCamera.Mode.CITY)


func _small_panel(fill := UiStyle.CREAM) -> StyleBoxFlat:
	var box := UiStyle.panel(fill, UiStyle.GOLD_DARK, 12)
	box.set_content_margin_all(8)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.shadow_size = 6
	return box


## Show the year (BC negative).
func set_year(year: int) -> void:
	_year.text = "%d BC" % -year if year < 0 else "AD %d" % year


## The hint for the camera now in use.
func set_mode(mode: int) -> void:
	_mode = mode
	_hint.text = HINTS.get(mode, "")
	_back.text = "Back to map" if mode == UrbsCamera.Mode.CITY else "Step back"


## Inside a monument: the card gives way to its name.
func set_inside(inside: bool, info: Dictionary) -> void:
	if inside:
		hide_card()
		_year.text += " · " + str(info.get("english", ""))
	_back.text = "Step back" if not inside else "Go outside"


func card_open() -> bool:
	return _card.visible


func hide_card() -> void:
	if _card.visible:
		_card.visible = false
		card_closed.emit()


## The card for a monument, from `UrbsMonuments.info`.
func show_card(info: Dictionary) -> void:
	if info.is_empty():
		hide_card()
		return
	for child in _card_body.get_children():
		child.queue_free()
	var latin := str(info.get("latin", ""))
	var title := UiStyle.wrapped(latin if latin != "" else str(info.get("english", "")), 22, UiStyle.INK, 340.0)
	title.add_theme_font_override("font", UiStyle.font("title", 800))
	_card_body.add_child(title)
	if latin != "":
		var english := UiStyle.wrapped(str(info.get("english", "")), 16, UiStyle.INK_SOFT, 340.0)
		english.add_theme_font_override("font", UiStyle.font("body", 800))
		_card_body.add_child(english)
	var when := _date_text(int(info.get("year", 0)))
	var by := str(info.get("by", ""))
	_card_body.add_child(UiStyle.wrapped("%s%s" % [when, " · " + by if by != "" else ""], 15, UiStyle.GOLD_DARK, 340.0))
	var form := str(info.get("form", ""))
	if form != "":
		_card_body.add_child(UiStyle.wrapped(form, 15, UiStyle.INK, 340.0))
	var sources: Array = info.get("sources", [])
	if not sources.is_empty():
		var text := UiStyle.wrapped("Sources: " + "; ".join(PackedStringArray(sources.map(func(s): return str(s)))), 12, UiStyle.INK_SOFT, 340.0)
		_card_body.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if bool(info.get("enterable", false)):
		var enter := UiStyle.big_button("Enter", 18)
		enter.pressed.connect(func() -> void: enter_pressed.emit())
		row.add_child(enter)
	var close := UiStyle.big_button("Close", 14, UiStyle.PARCHMENT)
	close.pressed.connect(hide_card)
	row.add_child(close)
	_card_body.add_child(row)
	_card.visible = true
	_card.modulate.a = 0.0
	_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.2)


static func _date_text(year: int) -> String:
	if year == 0:
		return "date unknown"
	return "built %d BC" % -year if year < 0 else "built AD %d" % year
