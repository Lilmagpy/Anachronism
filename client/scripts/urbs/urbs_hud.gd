## Urbs (D-289): a thin overlay for the city: the year, the hint for the camera in use, a
## Back-to-map button and the monument card (name in Latin and English, date and builder, the
## form, the sources in small text, and an Enter button). It keeps no state of its own: Urbs
## tells it what to show.
##
## F2 play adds the city as the interface (docs/plans/briefs/f2_play.md):
##   - the card shows the place's actions (UrbsPlaces.action_list: cost, forecast, why not)
##     and the result of the last one; pressing one emits `action_pressed`;
##   - in an interior, the same actions on a panel at the spot (show_spot: the Curia's floor,
##     the altar, the Circus' box, the Rostra), following the spot on the screen;
##   - "Rome this year": the places with actions open this year; a row flies you there;
##   - End year (with a confirm), the busy veil while the years pass, and the idea box a
##     workshop or the harbour opens;
##   - set_watching(true) clears the screen for the moments (moments.gd).
## Keys (all also by mouse): 1-9 pick an action on the card or panel (then Enter does it; Tab
## moves between them), L opens or closes "Rome this year" (1-9 then fly to a place), Enter with
## nothing picked asks to end the year, Esc closes what is open (the camera's Esc steps back).
class_name UrbsHud
extends CanvasLayer

signal back_pressed
signal enter_pressed
signal card_closed
signal action_pressed(place_id: String, entry: Dictionary)   # F2 play
signal end_year_confirmed                                    # F2 play
signal place_chosen(id: String)                              # F2 play: a row of "Rome this year"
signal idea_sent(text: String, context: String)              # F2 play: the idea box of a place

const HINTS := {
	UrbsCamera.Mode.CITY: "Scroll to zoom in · drag to move · right-drag to turn · click a building · L: Rome this year · Enter: end the year",
	UrbsCamera.Mode.STREET: "WASD to walk · shift to run · right-drag to look · scroll to rise or sink · Esc to rise out",
	UrbsCamera.Mode.INSIDE: "WASD to walk · right-drag to look · 1-9 then Enter: act here · Esc to go back out",
}
const CARD_W := 330.0

var camera: Camera3D                 # F2 play: for the interior panel's spot on the screen
var _root := Control.new()
var _year := Label.new()
var _year_text := ""
var _hint := Label.new()
var _hint_box := PanelContainer.new()
var _back := Button.new()
var _end := Button.new()
var _card := PanelContainer.new()
var _card_scroll := ScrollContainer.new()
var _card_body := VBoxContainer.new()
var _title_bar := PanelContainer.new()
var _title := Label.new()
var _mode := UrbsCamera.Mode.CITY
var _rows: Array = []                # the ActionRows on the card or the panel, by number
var _card_place := ""                # the place whose actions the card shows
var _list := PanelContainer.new()
var _list_body := VBoxContainer.new()
var _list_open := true
var _todo: Array = []
var _spot := PanelContainer.new()
var _spot_body := VBoxContainer.new()
var _spot_mark := Label.new()
var _spot_at := Vector3.ZERO
var _confirm: Control
var _busy := Control.new()
var _busy_label := Label.new()
var _idea: Control
var _watching := false
var _inside := false


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
	# F2 play: End year, left of it
	_end = UiStyle.big_button("End year ▸", 18, Color(0.86, 0.36, 0.22))
	_end.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_end.offset_left = -386
	_end.offset_right = -202
	_end.offset_top = 14
	_end.tooltip_text = "End the year here in Rome (Enter): the years pass, then the year's events play where they happen."
	_end.pressed.connect(ask_end_year)
	_end.visible = false
	_root.add_child(_end)
	# the hint, bottom centre
	_hint_box.add_theme_stylebox_override("panel", _small_panel(Color(0.97, 0.93, 0.84, 0.86)))
	_hint_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_box.offset_top = -52
	_hint_box.offset_bottom = -14
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font", UiStyle.font("body", 700))
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", UiStyle.INK_SOFT)
	_hint_box.add_child(_hint)
	_root.add_child(_hint_box)
	# the monument card, right (F2 play: it scrolls when the place's actions make it tall)
	_card.add_theme_stylebox_override("panel", UiStyle.panel())
	_card.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_card.anchor_top = 0.0
	_card.anchor_bottom = 0.0
	_card.offset_left = -400
	_card.offset_right = -16
	_card.offset_top = 70
	_card.visible = false
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_body.add_theme_constant_override("separation", 6)
	_card_scroll.add_child(_card_body)
	_card.add_child(_card_scroll)
	_root.add_child(_card)
	_build_list()
	_build_spot()
	_build_busy()
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
	_year_text = "%d BC" % -year if year < 0 else "AD %d" % year
	_year.text = _year_text


## The hint for the camera now in use.
func set_mode(mode: int) -> void:
	_mode = mode
	_hint.text = HINTS.get(mode, "")
	_back.text = "Back to map" if mode == UrbsCamera.Mode.CITY else "Step back"
	if _inside:
		_back.text = "Go outside"


## Inside a monument: the card gives way to its name.
func set_inside(inside: bool, info: Dictionary) -> void:
	_inside = inside
	if inside:
		hide_card()
		_year.text = _year_text + " · " + str(info.get("english", ""))
	else:
		_year.text = _year_text   # F2 play: the name goes when you leave (it used to stay)
		hide_spot()
	_back.text = "Step back" if not inside else "Go outside"
	_layout_list()


func card_open() -> bool:
	return _card.visible


func hide_card() -> void:
	if _card.visible:
		_card.visible = false
		_rows.clear()
		_card_place = ""
		card_closed.emit()


## The place whose actions the card is showing ("" when none).
func card_place() -> String:
	return _card_place if _card.visible else ""


## The card for a monument, from `UrbsMonuments.info`; F2 play: with its place's actions
## (`place`, from view["places"], with "_id" its monument id) and the result of the last action
## there (`result`: {accepted, message}).
func show_card(info: Dictionary, place: Dictionary = {}, result: Dictionary = {}) -> void:
	if info.is_empty():
		hide_card()
		return
	var place_id := str(place.get("_id", ""))
	var keep_scroll := _card.visible and place_id != "" and place_id == _card_place
	var scrolled := _card_scroll.scroll_vertical
	for child in _card_body.get_children():
		child.queue_free()
	_rows.clear()
	_card_place = place_id
	var latin := str(info.get("latin", ""))
	var title := UiStyle.wrapped(latin if latin != "" else str(info.get("english", "")), 22, UiStyle.INK, CARD_W)
	title.add_theme_font_override("font", UiStyle.font("title", 800))
	_card_body.add_child(title)
	if latin != "":
		var english := UiStyle.wrapped(str(info.get("english", "")), 16, UiStyle.INK_SOFT, CARD_W)
		english.add_theme_font_override("font", UiStyle.font("body", 800))
		_card_body.add_child(english)
	var when := _date_text(int(info.get("year", 0)))
	var by := str(info.get("by", ""))
	var acts: Array = place.get("actions", [])
	if acts.is_empty():
		_card_body.add_child(UiStyle.wrapped("%s%s" % [when, " · " + by if by != "" else ""], 15, UiStyle.GOLD_DARK, CARD_W))
	else:
		# F2 play: the place first, its history after
		_card_body.add_child(_place_section(place, result, CARD_W, true))
		_card_body.add_child(_rule())
		_card_body.add_child(UiStyle.wrapped("%s%s" % [when, " · " + by if by != "" else ""], 13, UiStyle.GOLD_DARK, CARD_W))
	var form := str(info.get("form", ""))
	if form != "":
		_card_body.add_child(UiStyle.wrapped(form, 15 if acts.is_empty() else 13, UiStyle.INK, CARD_W))
	var sources: Array = info.get("sources", [])
	if not sources.is_empty():
		var text := UiStyle.wrapped("Sources: " + "; ".join(PackedStringArray(sources.map(func(s): return str(s)))), 12, UiStyle.INK_SOFT, CARD_W)
		_card_body.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if bool(info.get("enterable", false)):
		var enter := UiStyle.big_button("Enter", 18)
		enter.tooltip_text = "Go inside" + (": the same actions wait for you there" if not acts.is_empty() else "")
		enter.pressed.connect(func() -> void: enter_pressed.emit())
		row.add_child(enter)
	var close := UiStyle.big_button("Close", 14, UiStyle.PARCHMENT)
	close.pressed.connect(hide_card)
	row.add_child(close)
	_card_body.add_child(row)
	var was_open := _card.visible
	_card.visible = not _watching
	if not was_open:
		_card.modulate.a = 0.0
		_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.2)
	_fit_card.call_deferred(scrolled if keep_scroll else 0)


## The card never runs past the hint bar: it scrolls instead.
func _fit_card(scroll_to: int) -> void:
	if not is_instance_valid(_card_body):
		return
	var room := _root.get_viewport_rect().size.y - 70.0 - 66.0 - 36.0
	_card_scroll.custom_minimum_size = Vector2(CARD_W + 14.0, minf(_card_body.get_combined_minimum_size().y + 4.0, room))
	_card.reset_size()
	_card_scroll.scroll_vertical = scroll_to


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(UiStyle.GOLD_DARK, 0.5)
	r.custom_minimum_size = Vector2(CARD_W, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A place's heading, blurb, info, last result and numbered actions (card and panel).
func _place_section(place: Dictionary, result: Dictionary, width: float, numbered: bool, heading := "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var role := str(place.get("role", ""))
	var kicker := heading if heading != "" else UrbsPlaces.role_words(role)
	if kicker != "":
		box.add_child(UiStyle.label(kicker.to_upper(), 13, UiStyle.RED, "body", 900))
	var blurb := str(place.get("blurb", ""))
	if blurb != "":
		box.add_child(UiStyle.wrapped(blurb, 14, UiStyle.INK_SOFT, width))
	var info: Array = place.get("info", [])
	if not info.is_empty():
		box.add_child(UrbsPlaces.info_lines(place, width))
	if not result.is_empty():
		box.add_child(UrbsPlaces.result_line(result, width))
	var id := str(place.get("_id", ""))
	var list := UrbsPlaces.action_list(place, width, func(a: Dictionary) -> void: action_pressed.emit(id, a), _rows.size() + 1 if numbered else 99)
	for r in list.get_children():
		_rows.append(r)
	box.add_child(list)
	return box


static func _date_text(year: int) -> String:
	if year == 0:
		return "date unknown"
	return "built %d BC" % -year if year < 0 else "built AD %d" % year


# --- F2 play: "Rome this year" ----------------------------------------------------------------

func _build_list() -> void:
	var style := _small_panel(Color(0.97, 0.93, 0.84, 0.94))
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	_list.add_theme_stylebox_override("panel", style)
	_list.position = Vector2(16, 66)
	_list.custom_minimum_size.x = 300
	_list_body.add_theme_constant_override("separation", 4)
	_list.add_child(_list_body)
	_list.visible = false
	_root.add_child(_list)


## The places with actions open this year ([{id, title, role, open, total}], UrbsPlaces.todo).
func set_todo(todo: Array) -> void:
	_todo = todo
	_layout_list()


func toggle_list(open := not _list_open) -> void:
	_list_open = open
	_layout_list()


func list_open() -> bool:
	return _list.visible and _list_open


func _layout_list() -> void:
	for child in _list_body.get_children():
		child.queue_free()
	_list.visible = not _todo.is_empty() and not _watching and not _inside
	if not _list.visible:
		return
	var head := Button.new()
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.text = "ROME THIS YEAR · %d %s  %s" % [_todo.size(), "place" if _todo.size() == 1 else "places", "▾" if _list_open else "▸"]
	head.add_theme_font_override("font", UiStyle.font("body", 900))
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", UiStyle.RED)
	head.add_theme_color_override("font_hover_color", UiStyle.RED.lightened(0.2))
	head.tooltip_text = "What you can do in Rome this year, place by place (L). Press a place to fly there."
	head.pressed.connect(func() -> void: toggle_list())
	_list_body.add_child(head)
	if not _list_open:
		_list.reset_size()
		return
	var n := 1
	for item in _todo:
		_list_body.add_child(_list_row(item, n))
		n += 1
	_list.reset_size()


func _list_row(item: Dictionary, n: int) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s  %s" % [str(n) if n <= 9 else "·", str(item.get("title", item.get("id", "")))]
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_override("font", UiStyle.font("body", 800))
	b.add_theme_font_size_override("font_size", 15)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, UiStyle.INK)
	var fills := {"normal": Color(0.99, 0.96, 0.88), "hover": Color(1.0, 0.92, 0.70), "focus": Color(1.0, 0.90, 0.64), "pressed": Color(0.95, 0.82, 0.55)}
	for state in fills:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(7)
		s.content_margin_left = 8
		s.content_margin_right = 44
		s.content_margin_top = 3
		s.content_margin_bottom = 3
		s.bg_color = fills[state]
		s.border_color = UiStyle.RED if state == "focus" else Color(UiStyle.GOLD_DARK, 0.6)
		s.set_border_width_all(2 if state == "focus" else 1)
		b.add_theme_stylebox_override(state, s)
	var open := int(item.get("open", 0))
	var what := UrbsPlaces.role_words(str(item.get("role", "")))
	b.tooltip_text = "%s. %d %s open. Fly there." % [what, open, "action" if open == 1 else "actions"]
	var count := UiStyle.label("%d ▸" % open, 13, UiStyle.GOLD_DARK, "body", 900)
	count.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	count.offset_left = -44
	count.offset_right = -8
	count.offset_top = -10
	count.offset_bottom = 10
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(count)
	b.custom_minimum_size = Vector2(286, 30)
	var id := str(item.get("id", ""))
	b.pressed.connect(func() -> void: place_chosen.emit(id))
	return b


# --- F2 play: the panel at the spot inside a building -------------------------------------------

func _build_spot() -> void:
	var style := UiStyle.panel(Color(0.97, 0.93, 0.84, 0.95), UiStyle.GOLD_DARK, 12)
	style.set_content_margin_all(12)
	_spot.add_theme_stylebox_override("panel", style)
	_spot.visible = false
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_spot_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_spot_body)
	_spot.add_child(scroll)
	_root.add_child(_spot)
	_spot_mark = UiStyle.headline("◆", 30, UiStyle.GOLD)
	_spot_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spot_mark.visible = false
	_root.add_child(_spot_mark)


## The actions of the places an interior offers, on a panel beside `at` (world) on the screen.
## `sections` is [[place_id, place, heading]]; `result` the last action's (shown under the
## section of `result_for`).
func show_spot(sections: Array, at: Vector3, result: Dictionary = {}, result_for := "") -> void:
	for child in _spot_body.get_children():
		child.queue_free()
	_rows.clear()
	if sections.is_empty():
		hide_spot()
		return
	_spot_at = at
	for s in sections:
		var place: Dictionary = (s[1] as Dictionary).duplicate()
		place["_id"] = s[0]
		var title := UiStyle.label(str(place.get("title", s[0])), 19, UiStyle.INK, "title", 800)
		_spot_body.add_child(title)
		_spot_body.add_child(_place_section(place, result if str(s[0]) == result_for else {}, 300.0, true, str(s[2])))
	_spot.visible = not _watching
	_spot_mark.visible = _spot.visible
	_fit_spot.call_deferred()


func _fit_spot() -> void:
	var room := _root.get_viewport_rect().size.y - 160.0
	var scroll: ScrollContainer = _spot.get_node("Scroll")
	scroll.custom_minimum_size = Vector2(314, minf(_spot_body.get_combined_minimum_size().y + 4.0, room))
	_spot.reset_size()


func hide_spot() -> void:
	_spot.visible = false
	_spot_mark.visible = false


func spot_open() -> bool:
	return _spot.visible


func _process(_delta: float) -> void:
	if not _spot.visible or camera == null or not is_instance_valid(camera):
		return
	# the panel stands beside its spot, and keeps to the screen when the spot is off it
	var room := _root.get_viewport_rect().size
	var px := Vector2(get_viewport().get_visible_rect().size)
	var behind := camera.is_position_behind(_spot_at)
	var p := camera.unproject_position(_spot_at) * (room / px)
	var size := _spot.size
	var onscreen := not behind and p.x > 0 and p.y > 0 and p.x < room.x and p.y < room.y
	_spot_mark.visible = onscreen
	if onscreen:
		_spot_mark.position = p - _spot_mark.size / 2.0
	var at := p + Vector2(34, -size.y * 0.35) if onscreen else Vector2(room.x - size.x - 16, 80)
	if onscreen and at.x + size.x > room.x - 16:
		at.x = p.x - 34 - size.x
	at.x = clampf(at.x, 16, maxf(16.0, room.x - size.x - 16))
	at.y = clampf(at.y, 70, maxf(70.0, room.y - size.y - 66))
	_spot.position = _spot.position.lerp(at, 0.25) if _spot.position.distance_to(at) < 400 else at


# --- F2 play: End year, the busy veil, the idea box, watching ----------------------------------

## Show the End year button ("End year", or "End N years" when a turn is several).
func set_end_year(shown: bool, years := 1) -> void:
	_end.set_meta("shown", shown)
	_end.visible = shown and not _watching
	_end.text = "End year ▸" if years <= 1 else "End %d years ▸" % years


## What the End year confirm says (the years, and a question waiting on the map).
func set_end_year_text(text: String) -> void:
	_end.set_meta("ask", text)


## Ask before the years pass (Enter confirms, Esc goes back).
func ask_end_year() -> void:
	if (_confirm != null and is_instance_valid(_confirm)) or not bool(_end.get_meta("shown", false)):
		return
	var text := str(_end.get_meta("ask", "The year ends here in Rome. Its events play where they happen; then you are back where you stand."))
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.03, 0.02, 0.45)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(centre)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.panel())
	centre.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	box.add_child(col)
	col.add_child(UiStyle.label(_end.text.trim_suffix(" ▸") + "?", 28, UiStyle.RED, "title", 900))
	col.add_child(UiStyle.wrapped(text, 16, UiStyle.INK, 480.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var yes := UiStyle.big_button("End it (Enter)", 18, Color(0.86, 0.36, 0.22))
	yes.pressed.connect(func() -> void:
		_close_confirm()
		end_year_confirmed.emit())
	row.add_child(yes)
	var no := UiStyle.big_button("Not yet (Esc)", 16, UiStyle.PARCHMENT)
	no.pressed.connect(_close_confirm)
	row.add_child(no)
	col.add_child(row)
	_root.add_child(shade)
	_confirm = shade


func _close_confirm() -> void:
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
	_confirm = null


func _build_busy() -> void:
	_busy.set_anchors_preset(Control.PRESET_FULL_RECT)
	_busy.mouse_filter = Control.MOUSE_FILTER_STOP
	_busy.visible = false
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.03, 0.02, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy.add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy.add_child(centre)
	_busy_label = UiStyle.headline("", 40)
	centre.add_child(_busy_label)
	_root.add_child(_busy)


## A veil with a line while the engine works ("" lifts it).
func set_busy(text: String) -> void:
	_busy_label.text = text
	_busy.visible = text != ""


## The idea box of a place: a line to whisper, sent with the place as context.
func ask_idea(heading: String, context: String) -> void:
	if _idea != null and is_instance_valid(_idea):
		_idea.queue_free()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.03, 0.02, 0.45)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(centre)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.panel())
	centre.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	box.add_child(col)
	col.add_child(UiStyle.label(heading, 24, UiStyle.RED, "title", 900))
	col.add_child(UiStyle.wrapped("Say it in your own words: what they could make, and how. The court of ideas judges it as it would on the map.", 15, UiStyle.INK_SOFT, 480.0))
	var line := LineEdit.new()
	line.placeholder_text = "e.g. a boarding bridge that drops onto the enemy's deck"
	line.custom_minimum_size = Vector2(480, 40)
	line.add_theme_font_size_override("font_size", 16)
	col.add_child(line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var send := UiStyle.big_button("Whisper it (Enter)", 17)
	var close := func() -> void:
		if is_instance_valid(shade):
			shade.queue_free()
		_idea = null
	var go := func(_t := "") -> void:
		var text := line.text.strip_edges()
		if text == "":
			return
		close.call()
		idea_sent.emit(text, context)
	send.pressed.connect(go)
	line.text_submitted.connect(go)
	row.add_child(send)
	var no := UiStyle.big_button("Not now (Esc)", 15, UiStyle.PARCHMENT)
	no.pressed.connect(close)
	row.add_child(no)
	col.add_child(row)
	line.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close.call()
			line.accept_event())
	_root.add_child(shade)
	_idea = shade
	line.grab_focus.call_deferred()


## While the moments play: only the year stays (moments.gd draws its own title card).
func set_watching(on: bool) -> void:
	_watching = on
	if on:
		_card.visible = false
		_spot.visible = false
		_spot_mark.visible = false
		_close_confirm()
	_hint_box.visible = not on
	_back.visible = not on
	_end.visible = not on and bool(_end.get_meta("shown", false))
	_layout_list()


func watching() -> bool:
	return _watching


## A dialog of the HUD's is open (the End year confirm, the idea box, the busy veil).
func dialog_open() -> bool:
	return (_confirm != null and is_instance_valid(_confirm)) or (_idea != null and is_instance_valid(_idea)) or _busy.visible


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _watching or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if _busy.visible:
		get_viewport().set_input_as_handled()
		return
	if _idea != null and is_instance_valid(_idea):
		return
	if _confirm != null and is_instance_valid(_confirm):
		if key in [KEY_ENTER, KEY_KP_ENTER]:
			_close_confirm()
			end_year_confirmed.emit()
		elif key == KEY_ESCAPE:
			_close_confirm()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_L and not _inside:
		toggle_list()
		get_viewport().set_input_as_handled()
		return
	var digit := -1
	if key >= KEY_1 and key <= KEY_9:
		digit = key - KEY_1
	elif key >= KEY_KP_1 and key <= KEY_KP_9:
		digit = key - KEY_KP_1
	if digit >= 0:
		if (_card.visible or _spot.visible) and digit < _rows.size():
			var row: Control = _rows[digit]
			if is_instance_valid(row):
				row.grab_focus()
				if _card.visible:
					_card_scroll.ensure_control_visible(row)
				else:
					(_spot.get_node("Scroll") as ScrollContainer).ensure_control_visible(row)
			get_viewport().set_input_as_handled()
		elif list_open() and not _card.visible and digit < _todo.size():
			place_chosen.emit(str(_todo[digit]["id"]))
			get_viewport().set_input_as_handled()
		return
	if key in [KEY_ENTER, KEY_KP_ENTER] and _end.visible:
		ask_end_year()
		get_viewport().set_input_as_handled()
