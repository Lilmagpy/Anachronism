## Your cities (D-127): every city you hold down the left, how grown it is and whether it has
## room to build; on the right the open city - what it makes each turn, its building plots
## (built, going up, empty, and when the next one opens) and what it could build, each with
## what it would add there in plain numbers, what it costs and what it costs to keep.
class_name CityScreen
extends Control

signal build_requested(province_id: String, building_id: String)
signal unqueue_requested(province_id: String, building_id: String)
signal show_requested(province_id: String)

const INK := UiStyle.INK
const DIM := UiStyle.INK_SOFT
const GOOD := Color(0.16, 0.45, 0.18)
const BAD := Color(0.62, 0.12, 0.08)
const TIER_POINTS := [0, 2, 4, 7, 10]
const TIERS := ["Village", "Town", "City", "Great city", "Metropolis"]

var view: Dictionary = {}
var _selected := ""
var _list: VBoxContainer
var _page: VBoxContainer
var _summary: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.03, 0.02, 0.6)
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var book := PanelContainer.new()
	book.add_theme_stylebox_override("panel", UiStyle.ornate_panel())
	book.custom_minimum_size = Vector2(1360, 790)
	centre.add_child(book)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	book.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var head := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(UiStyle.label("YOUR CITIES", 32, UiStyle.RED, "title", 900))
	_summary = UiStyle.label("", 15, DIM)
	titles.add_child(_summary)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var shut := UiStyle.big_button("✕", 20, Color(0.85, 0.80, 0.70))
	shut.custom_minimum_size = Vector2(48, 44)
	shut.tooltip_text = "Close (Esc)"
	shut.pressed.connect(close)
	head.add_child(shut)
	column.add_child(head)
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 18)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(pages)
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.add_child(left)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_list)
	var spine := ColorRect.new()
	spine.color = Color(0.55, 0.40, 0.20, 0.5)
	spine.custom_minimum_size = Vector2(3, 0)
	pages.add_child(spine)
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.add_child(right)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 12)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_page)


func open(new_view: Dictionary, province_id := "") -> void:
	if province_id != "":
		_selected = province_id
	visible = true
	move_to_front()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	refresh(new_view)


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func refresh(new_view: Dictionary) -> void:
	view = new_view
	if not visible:
		return
	var cities := _cities()
	if cities.is_empty():
		return
	if _selected == "" or not cities.any(func(c: Dictionary) -> bool: return str(c["id"]) == _selected):
		_selected = str(cities[0]["id"])
	var free := 0
	var going := 0
	for city in cities:
		if city.get("works") != null:
			going += 1
		elif _free_plots(city) > 0:
			free += 1
	_summary.text = "%d cities · %d building now · %d with room to build" % [cities.size(), going, free]
	_fill_list(cities)
	_fill_page(_find(_selected))


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _cities() -> Array:
	var out: Array = view.get("provinces", []).filter(func(p: Dictionary) -> bool:
		return p.get("owner") == view.get("player") and not p.get("sea", false) and p.has("output"))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("capital", false)) != bool(b.get("capital", false)):
			return bool(a.get("capital", false))
		return int(a.get("population", 0)) > int(b.get("population", 0)))
	return out


func _find(id: String) -> Dictionary:
	for p in view.get("provinces", []):
		if str(p["id"]) == id:
			return p
	return {}


func _free_plots(city: Dictionary) -> int:
	return int(city.get("slots", 0)) - (city.get("buildings", []) as Array).size() - (1 if city.get("works") != null else 0) \
		- (city.get("queue", []) as Array).size()


func _can_build_now(city: Dictionary) -> bool:
	return (city.get("queue", []) as Array).size() < 3 and (city.get("can_build", []) as Array).any(
		func(o: Dictionary) -> bool: return o.get("why_not") == null)


func _fill_list(cities: Array) -> void:
	for child in _list.get_children():
		child.queue_free()
	for city in cities:
		var id := str(city["id"])
		var row := Button.new()
		row.toggle_mode = true
		row.button_pressed = id == _selected
		row.flat = id != _selected
		row.custom_minimum_size = Vector2(380, 64)
		row.focus_mode = Control.FOCUS_NONE
		row.pressed.connect(func():
			_selected = id
			refresh(view))
		var inside := VBoxContainer.new()
		inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inside.offset_left = 12
		inside.offset_top = 6
		inside.offset_right = -12
		inside.add_theme_constant_override("separation", 0)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name := UiStyle.label(("♛ " if city.get("capital", false) else "") + str(city["name"]).split(" (")[0], 18, INK, "body", 800)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(name)
		var tier := UiStyle.label(str(city.get("tier_name", "")).to_upper(), 13, UiStyle.GOLD_DARK, "body", 900)
		tier.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(tier)
		inside.add_child(top)
		var line := ""
		var colour := DIM
		if city.get("works") != null:
			line = "⚒ building %s · %d turn%s" % [city["works"]["name"], int(city["works"]["turns"]), "" if int(city["works"]["turns"]) == 1 else "s"]
			var waiting := (city.get("queue", []) as Array).size()
			if waiting > 0:
				line += " · %d queued" % waiting
			colour = UiStyle.GOLD_DARK
		elif _can_build_now(city):
			line = "＋ room to build (%d free plot%s)" % [_free_plots(city), "" if _free_plots(city) == 1 else "s"]
			colour = GOOD
		elif _free_plots(city) <= 0:
			line = "every plot built on"
		else:
			line = "nothing to build yet"
		var words := UiStyle.label("%s people · %s" % [GameHud.people(int(city.get("population", 0))), line], 13, colour)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_child(words)
		row.add_child(inside)
		_list.add_child(row)


func _fill_page(city: Dictionary) -> void:
	for child in _page.get_children():
		child.queue_free()
	if city.is_empty():
		return
	var id := str(city["id"])
	# heading: name, how grown it is, and what makes it grow
	var head := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tier := int(city.get("tier", 0))
	titles.add_child(UiStyle.label(str(city.get("tier_name", "")).to_upper(), 15, UiStyle.GOLD_DARK, "body", 900))
	titles.add_child(UiStyle.label(str(city["name"]).split(" (")[0], 40, UiStyle.RED, "title", 900))
	titles.add_child(UiStyle.label("%s people" % GameHud.number(int(city.get("population", 0))), 16, DIM))
	head.add_child(titles)
	var look := UiStyle.big_button("Show on the map  ▸", 15, Color(0.86, 0.81, 0.71))
	look.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	look.pressed.connect(func():
		close()
		show_requested.emit(id))
	head.add_child(look)
	_page.add_child(head)
	if tier < TIERS.size() - 1:
		var points := (city.get("buildings", []) as Array).size() + int(city.get("population", 0)) / 250000
		var need: int = TIER_POINTS[tier + 1] - points
		_page.add_child(UiStyle.wrapped("To grow into a %s: %d more building%s (or %s more people for each)." % [
			TIERS[tier + 1].to_lower(), need, "" if need == 1 else "s", GameHud.number(250000)], 14, DIM, 820))
	# what it makes
	_section("WHAT IT MAKES EACH TURN")
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 12)
	var output: Dictionary = city.get("output", {})
	for key in ["food", "materials", "wealth", "knowledge"]:
		tiles.add_child(_tile(key, GameHud.number(int(output.get(key, 0)))))
	_page.add_child(tiles)
	# what it could build
	var options: Array = city.get("can_build", [])
	_section("BUILD HERE")
	if city.get("works") != null:
		_page.add_child(UiStyle.wrapped("Builders are at work on the %s. What you choose now joins the queue (up to 3) and starts when they are free - paid for then." % str(city["works"]["name"]).to_lower(), 15, UiStyle.GOLD_DARK, 820))
	elif _free_plots(city) <= 0:
		_page.add_child(UiStyle.wrapped("Every plot is built on. The city gains plots as its people grow.", 15, DIM, 820))
	if options.is_empty():
		_page.add_child(UiStyle.wrapped("Nothing can be built here yet: buildings need ideas in use (see your notebook).", 15, DIM, 820))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var queueing := city.get("works") != null
	for option in options:
		grid.add_child(_option(id, option, queueing))
	_page.add_child(grid)
	# the plots
	var built: Array = city.get("buildings", [])
	var total := int(city.get("slots", 0))
	_section("BUILDING PLOTS · %d of %d used" % [built.size() + (1 if city.get("works") != null else 0), total])
	var plots := HFlowContainer.new()
	plots.add_theme_constant_override("h_separation", 10)
	plots.add_theme_constant_override("v_separation", 10)
	for b in built:
		plots.add_child(_plot(str(b["name"]), str(b.get("does", "")), Color(0.86, 0.93, 0.80), "✓"))
	if city.get("works") != null:
		var w: Dictionary = city["works"]
		plots.add_child(_plot(str(w["name"]), "going up · %d turn%s left" % [int(w["turns"]), "" if int(w["turns"]) == 1 else "s"], Color(0.98, 0.88, 0.6), "⚒"))
	for q in city.get("queue", []):
		var tile := _plot(str(q["name"]), "queued: starts when the builders are free", Color(0.93, 0.90, 0.98), "⏳")
		var drop := UiStyle.big_button("✕", 13, Color(0.86, 0.81, 0.71))
		drop.custom_minimum_size = Vector2(30, 28)
		drop.tooltip_text = "Take it off the plans"
		var building := str(q["id"])
		drop.pressed.connect(func(): unqueue_requested.emit(id, building))
		tile.get_child(0).add_child(drop)
		plots.add_child(tile)
	for k in maxi(0, total - built.size() - (1 if city.get("works") != null else 0) - (city.get("queue", []) as Array).size()):
		plots.add_child(_plot("Empty plot", "ready for a building", Color(0.95, 0.92, 0.84), "＋"))
	if city.has("next_slot_at"):
		plots.add_child(_plot("Locked plot", "opens at %s people" % GameHud.number(int(city["next_slot_at"])), Color(0.82, 0.80, 0.76), "🔒"))
	_page.add_child(plots)


func _section(title: String) -> void:
	_page.add_child(UiStyle.label(title, 14, UiStyle.GOLD_DARK, "body", 900))


func _tile(key: String, value: String) -> Control:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.98, 0.95, 0.88), UiStyle.GOLD_DARK, 10))
	tile.custom_minimum_size = Vector2(190, 70)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(GameIcon.make(key, 40))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.add_child(UiStyle.label(value, 24, INK, "body", 900))
	words.add_child(UiStyle.label(key, 13, DIM))
	row.add_child(words)
	tile.add_child(row)
	return tile


func _plot(name: String, note: String, colour: Color, mark: String) -> Control:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", UiStyle.panel(colour, UiStyle.GOLD_DARK, 10))
	tile.custom_minimum_size = Vector2(200, 72)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiStyle.label(mark, 22, INK, "body", 900))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.add_child(UiStyle.label(name, 16, INK, "body", 800))
	words.add_child(UiStyle.wrapped(note, 12, DIM, 150))
	row.add_child(words)
	tile.add_child(row)
	return tile


func _option(province_id: String, option: Dictionary, queueing: bool) -> Control:
	var card := PanelContainer.new()
	var recommended := bool(option.get("recommended", false))
	card.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.99, 0.96, 0.88) if option.get("why_not") == null else Color(0.92, 0.89, 0.83),
		UiStyle.GOLD if recommended else UiStyle.GOLD_DARK, 10))
	card.custom_minimum_size = Vector2(430, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	var name := UiStyle.label(str(option["name"]), 20, UiStyle.RED, "title", 900)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	if recommended:
		top.add_child(UiStyle.label("★ BEST VALUE", 13, UiStyle.GOLD_DARK, "body", 900))
	column.add_child(top)
	for gain in option.get("gains", []):
		column.add_child(UiStyle.label("▸ " + str(gain), 15, GOOD, "body", 700))
	if str(option.get("replaces", "")) != "":
		column.add_child(UiStyle.label("replaces the %s" % str(option["replaces"]).to_lower(), 13, DIM))
	var costs := "%s materials · %s wealth · %d turn%s · keep: %s wealth a turn" % [
		GameHud.number(int(option["materials"])), GameHud.number(int(option["wealth"])), int(option["turns"]),
		"" if int(option["turns"]) == 1 else "s", GameHud.number(int(option.get("upkeep", 0)))]
	column.add_child(UiStyle.wrapped(costs, 13, INK, 400))
	var why = option.get("why_not")
	if why != null:
		column.add_child(UiStyle.wrapped(str(why).substr(0, 1).to_upper() + str(why).substr(1) + ".", 13, BAD, 400))
	else:
		var go := UiStyle.big_button("QUEUE" if queueing else "BUILD", 17)
		go.custom_minimum_size = Vector2(140, 40)
		go.size_flags_horizontal = Control.SIZE_SHRINK_END
		if queueing:
			go.tooltip_text = "Starts when the builders are free (paid for then)"
		var building := str(option["id"])
		go.pressed.connect(func(): build_requested.emit(province_id, building))
		column.add_child(go)
	card.add_child(column)
	return card
