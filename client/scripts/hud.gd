## The game's screens drawn over the map: the top bar of the state's condition, the ideas,
## projects and world panel, the selected province's card, the chronicle of last turn's
## events and the End Turn button.
##
## The HUD never keeps game state: `show_view` rebuilds everything from the engine's view,
## and player choices go out as `action_requested` / `end_turn_requested` signals.
class_name GameHud
extends CanvasLayer

signal action_requested(action: Dictionary)
signal end_turn_requested

const GOLD := Color(0.86, 0.72, 0.42)
const INK := Color(0.95, 0.92, 0.84)
const DIM := Color(0.70, 0.67, 0.60)
const BAD := Color(0.93, 0.45, 0.38)
const GOOD := Color(0.55, 0.85, 0.50)
const PANEL := Color(0.08, 0.07, 0.06, 0.95)
const CATEGORY_NAMES := {
	"agriculture": "Farming", "construction": "Building", "craft": "Craft",
	"governance": "Government", "health": "Health", "knowledge": "Learning",
	"maritime": "Seafaring", "metallurgy": "Metals", "military": "War",
}

var view: Dictionary = {}
var tab := "ideas"
var selected: Dictionary = {}   ## the province (or sea) the player clicked, from the view
var civ_colours := {}
var message := ""

var _root := Control.new()
var _top := HBoxContainer.new()
var _side_body := VBoxContainer.new()
var _tabs := HBoxContainer.new()
var _card := PanelContainer.new()
var _card_body := VBoxContainer.new()
var _chronicle := VBoxContainer.new()
var _end_turn := Button.new()
var _hover := Label.new()


func _ready() -> void:
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme()
	add_child(_root)
	_build_top_bar()
	_build_side_panel()
	_build_card()
	_build_chronicle()
	_build_end_turn()
	_hover.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hover.add_theme_constant_override("outline_size", 6)
	_hover.visible = false
	_root.add_child(_hover)


# --- updating --------------------------------------------------------------------------

func show_view(new_view: Dictionary) -> void:
	view = new_view
	for civ in view["civs"]:
		civ_colours[civ["id"]] = Color(civ["colour"])
	if not selected.is_empty():
		selected = _find_place(str(selected["id"]))
	_fill_top_bar()
	_fill_side()
	_fill_card()
	_fill_chronicle()


func select(place_id: String) -> void:
	selected = _find_place(place_id)
	_fill_card()


## Floating name under the mouse; empty text hides it.
func show_hover(text: String, at: Vector2) -> void:
	_hover.visible = text != ""
	_hover.text = text
	_hover.position = at + Vector2(16, 12)


func set_tab(new_tab: String) -> void:
	tab = new_tab
	_fill_side()


func _find_place(place_id: String) -> Dictionary:
	for p in view.get("provinces", []):
		if p["id"] == place_id:
			return p
	for s in view.get("seas", []):
		if s["id"] == place_id:
			return s
	return {}


# --- look and feel ------------------------------------------------------------------------

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.border_color = Color(GOLD, 0.55)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(12)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(4)
		box.set_content_margin_all(6)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.bg_color = {
			"normal": Color(0.30, 0.22, 0.12), "hover": Color(0.42, 0.31, 0.16),
			"pressed": Color(0.22, 0.16, 0.09), "disabled": Color(0.18, 0.17, 0.16),
			"focus": Color(0, 0, 0, 0),
		}[state]
		box.border_color = Color(GOLD, 0.7 if state != "disabled" else 0.2)
		box.set_border_width_all(1)
		if state == "focus":
			box.draw_center = false
		theme.set_stylebox(state, "Button", box)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	theme.set_color("font_disabled_color", "Button", DIM)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.18, 0.15)
	bar_bg.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GOLD
	bar_fill.set_corner_radius_all(3)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	return theme


func _label(text: String, size := 15, colour := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _wrapped(text: String, size := 14, colour := DIM) -> Label:
	var label := _label(text, size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 300
	return label


func _button(text: String, action: Callable, enabled := true) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func year_text(year: int) -> String:
	return "%d BC" % -year if year < 0 else "AD %d" % year


static func number(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	while text.length() > 3:
		out = "," + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + out


static func people(value: int) -> String:
	if value >= 1_000_000:
		return "%.2fM" % (value / 1_000_000.0)
	if value >= 10_000:
		return "%dk" % (value / 1000)
	return number(value)


static func pct(bp: int) -> String:
	return "%.1f%%" % (bp / 100.0)


# --- top bar ------------------------------------------------------------------------------

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 8
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color(GOLD, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", style)
	_top.add_theme_constant_override("separation", 22)
	bar.add_child(_top)
	_root.add_child(bar)


func _fill_top_bar() -> void:
	_clear(_top)
	var status: Dictionary = view["status"]
	var trends: Dictionary = status["trends"]
	var title := _label("%s   %s · turn %d" % [str(status["name"]).to_upper(), year_text(view["year"]), view["turn"]], 18, GOLD)
	_top.add_child(title)
	var stores: Dictionary = status["stores"]
	_stat("People", people(status["population"]), trends["population"], true)
	_stat("Food", number(stores["food"]), trends["food"], true)
	_stat("Materials", number(stores["materials"]), 0, true)
	_stat("Wealth", number(stores["wealth"]), 0, true)
	_stat("Knowledge", number(stores["knowledge"]), 0, true)
	_stat("Labour", "%s (%s free)" % [number(status["workforce"]), number(status["free_labour"])], 0, true)
	_stat("Literacy", pct(status["literacy_bp"]), trends["literacy_bp"], true)
	_stat("Unrest", pct(status["unrest_bp"]), trends["unrest_bp"], false)
	_stat("Legitimacy", pct(status["legitimacy_bp"]), trends["legitimacy_bp"], true)
	_stat("Suspicion", pct(status["suspicion_bp"]), trends["suspicion_bp"], false)


## One figure with an arrow; `up_is_good` decides whether a rise shows green or red.
func _stat(name: String, value: String, trend: int, up_is_good: bool) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	box.add_child(_label(name, 12, DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_label(value, 16))
	if trend != 0:
		var good := (trend > 0) == up_is_good
		row.add_child(_label("▲" if trend > 0 else "▼", 12, GOOD if good else BAD))
	box.add_child(row)
	_top.add_child(box)


# --- side panel: ideas, projects, world -------------------------------------------------

func _build_side_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -420
	panel.offset_right = -8
	panel.offset_top = 72
	panel.offset_bottom = -92
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_side_body)
	column.add_child(scroll)
	panel.add_child(column)
	_root.add_child(panel)


func _fill_side() -> void:
	_clear(_tabs)
	for entry in [["ideas", "Ideas"], ["projects", "Projects (%d)" % view["projects"].size()], ["world", "World"]]:
		var button := _button(entry[1], set_tab.bind(entry[0]))
		button.toggle_mode = true
		button.button_pressed = tab == entry[0]
		_tabs.add_child(button)
	_clear(_side_body)
	if message != "":
		_side_body.add_child(_wrapped(message, 14, GOLD))
	match tab:
		"ideas":
			_fill_ideas()
		"projects":
			_fill_projects()
		"world":
			_fill_world()


func _fill_ideas() -> void:
	var ready: Array = []
	var blocked: Array = []
	var known: Array = []
	for idea in view["ideas"]:
		if idea["stage"] in ["adopted", "widespread"]:
			known.append(idea)
		elif idea["stage"] == "experimenting":
			continue
		elif idea["ready"]:
			ready.append(idea)
		else:
			blocked.append(idea)
	ready.sort_custom(func(a, b): return a["year"] < b["year"])
	_side_body.add_child(_label("Ideas your scholars could try", 17, GOLD))
	_side_body.add_child(_wrapped("Each costs labour, materials, knowledge and wealth every turn until it works. Ideas far ahead of their time cost more and draw suspicion."))
	for idea in ready:
		_side_body.add_child(_idea_card(idea))
	if not blocked.is_empty():
		_side_body.add_child(_label("Out of reach for now", 17, GOLD))
		for idea in blocked:
			_side_body.add_child(_idea_card(idea))
	if not known.is_empty():
		_side_body.add_child(_label("Already known", 17, GOLD))
		var names: Array = []
		for idea in known:
			names.append(str(idea["name"]))
		_side_body.add_child(_wrapped(", ".join(names)))


func _idea_card(idea: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	var name := _label(str(idea["name"]), 16)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	if idea["ready"]:
		head.add_child(_button("Begin", func(): action_requested.emit({"kind": "start", "node_id": idea["id"]})))
	card.add_child(head)
	var ahead: int = int(idea["year"]) - int(view["year"])
	var when := "known elsewhere since %s" % year_text(idea["year"]) if ahead <= 0 else "%d years ahead of its time" % ahead
	card.add_child(_label("%s · %s" % [CATEGORY_NAMES.get(idea["category"], idea["category"]), when], 12, BAD if ahead > 150 else DIM))
	if idea["flavour"] != "":
		card.add_child(_wrapped(str(idea["flavour"]), 13, DIM))
	var effects: Array = []
	for e in idea["effects"]:
		effects.append(str(e["text"]))
	if not effects.is_empty():
		card.add_child(_wrapped("Brings: " + ", ".join(effects), 13, GOOD))
	if idea["ready"]:
		var c: Dictionary = idea["cost"]
		card.add_child(_wrapped("Per turn: %s labour · %s materials · %s knowledge · %s wealth · about %d turns" % [
			number(c["labour"]), number(c["materials"]), number(c["knowledge"]), number(c["wealth"]), idea["turns"]], 13, INK))
	elif idea["blockers"] != "":
		card.add_child(_wrapped("Needs: " + str(idea["blockers"]), 13, BAD))
	card.add_child(HSeparator.new())
	return card


func _fill_projects() -> void:
	_side_body.add_child(_label("Experiments under way", 17, GOLD))
	if view["projects"].is_empty():
		_side_body.add_child(_wrapped("None yet. Choose an idea in the Ideas tab and press Begin."))
	for project in view["projects"]:
		var box := VBoxContainer.new()
		box.add_child(_label(str(project["name"]), 16))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.show_percentage = false
		bar.value = project["progress_bp"] / 100.0
		box.add_child(bar)
		var state := "paused" if project["paused"] else "funded %s last turn" % pct(project["funding_bp"])
		box.add_child(_wrapped("%s done · %s · about %d turns left · %s priority" % [
			pct(project["progress_bp"]), state, project["turns"], project["priority"]], 12, DIM))
		var row := HBoxContainer.new()
		var id: String = project["id"]
		if project["paused"]:
			row.add_child(_button("Resume", func(): action_requested.emit({"kind": "resume", "node_id": id})))
		else:
			row.add_child(_button("Pause", func(): action_requested.emit({"kind": "pause", "node_id": id})))
		for level in ["high", "normal", "low"]:
			if level != project["priority"]:
				row.add_child(_button(level.capitalize(), func(): action_requested.emit({"kind": "priority", "node_id": id, "priority": level})))
		row.add_child(_button("Abandon", func(): action_requested.emit({"kind": "cancel", "node_id": id})))
		box.add_child(row)
		box.add_child(HSeparator.new())
		_side_body.add_child(box)


func _fill_world() -> void:
	_side_body.add_child(_label("The states under Heaven", 17, GOLD))
	var civs: Array = view["civs"].duplicate()
	civs.sort_custom(func(a, b): return a["population"] > b["population"])
	for civ in civs:
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = Color(civ["colour"])
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var name := _label(str(civ["name"]) + ("  (you)" if civ["id"] == view["player"] else ""), 15)
		name.custom_minimum_size.x = 150
		row.add_child(name)
		row.add_child(_label("%s people · %d prov. · %d advances" % [people(civ["population"]), civ["provinces"], civ["advances"]], 12, DIM))
		_side_body.add_child(row)


# --- province card ------------------------------------------------------------------------

func _build_card() -> void:
	_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_card.offset_left = 8
	_card.offset_bottom = -8
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.custom_minimum_size = Vector2(360, 0)
	_card_body.add_theme_constant_override("separation", 3)
	_card.add_child(_card_body)
	_root.add_child(_card)


func _fill_card() -> void:
	_clear(_card_body)
	if selected.is_empty():
		_card_body.add_child(_wrapped("Click a province to see who holds it and what it has. Drag to move, scroll to zoom.", 13))
		return
	if not selected.has("owner"):
		_card_body.add_child(_label(str(selected["name"]), 20, GOLD))
		_card_body.add_child(_label("Sea", 13, DIM))
		return
	var p := selected
	_card_body.add_child(_label(("♛ " if p["capital"] else "") + str(p["name"]), 20, GOLD))
	var owner_name := "No state: tribes and villages"
	for civ in view["civs"]:
		if civ["id"] == p["owner"]:
			owner_name = str(civ["name"]) + (" (you)" if civ["id"] == view["player"] else "")
	var owner_row := HBoxContainer.new()
	if p["owner"] != null:
		var swatch := ColorRect.new()
		swatch.color = civ_colours[p["owner"]]
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		owner_row.add_child(swatch)
	owner_row.add_child(_label(owner_name, 15))
	_card_body.add_child(owner_row)
	var land: Array = [str(p["terrain"]).replace("_", " ").capitalize()]
	if p["river"]:
		land.append("river")
	if p["coastal"]:
		land.append("coast")
	_card_body.add_child(_label("%s people · %s" % [number(p["population"]), ", ".join(land)], 14))
	var found: Array = []
	for res in p["resources"]:
		var access: String = p["resources"][res]
		found.append(res.capitalize() + ("" if access == "accessible" else " (%s)" % access))
	if not found.is_empty():
		_card_body.add_child(_wrapped("Resources: " + ", ".join(found), 13, DIM))
	var names: Array = []
	for n in p["neighbours"]:
		names.append(str(_find_place(n).get("name", n)))
	if not names.is_empty():
		_card_body.add_child(_wrapped("Borders: " + ", ".join(names), 13, DIM))


# --- chronicle and end turn -------------------------------------------------------------

func _build_chronicle() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_bottom = -8
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chronicle.add_theme_constant_override("separation", 2)
	panel.add_child(_chronicle)
	panel.name = "Chronicle"
	_root.add_child(panel)


func _fill_chronicle() -> void:
	_clear(_chronicle)
	var events: Array = view["events"]
	_chronicle.get_parent().visible = int(view["turn"]) > 1
	_chronicle.add_child(_label("The last %d years" % int(view["years_per_turn"]), 14, GOLD))
	if events.is_empty():
		_chronicle.add_child(_label("Quiet years: nothing of note happened.", 13, DIM))
		return
	for e in events.slice(0, 6):
		var colour := BAD if e["kind"] in ["riot", "revolt", "famine", "collapse", "setback", "stalled"] else INK
		var line := _wrapped("• " + str(e["message"]), 13, colour)
		line.custom_minimum_size.x = 620
		_chronicle.add_child(line)
	if events.size() > 6:
		_chronicle.add_child(_label("… and %d more" % (events.size() - 6), 12, DIM))


func _build_end_turn() -> void:
	_end_turn.text = "End turn  ▸"
	_end_turn.focus_mode = Control.FOCUS_NONE
	_end_turn.add_theme_font_size_override("font_size", 20)
	_end_turn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_end_turn.offset_left = -228
	_end_turn.offset_top = -74
	_end_turn.offset_right = -8
	_end_turn.offset_bottom = -8
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.36, 0.12)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_end_turn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.68, 0.45, 0.16)
	_end_turn.add_theme_stylebox_override("hover", hover)
	_end_turn.pressed.connect(func(): end_turn_requested.emit())
	_root.add_child(_end_turn)
