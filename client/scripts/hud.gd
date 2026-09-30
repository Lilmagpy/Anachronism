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
signal idea_submitted(text: String, answer: String)

const GOLD := Color(0.62, 0.20, 0.12)     ## headings: deep red on cream (UiStyle, D-059)
const INK := UiStyle.INK
const DIM := UiStyle.INK_SOFT
const BAD := Color(0.72, 0.16, 0.12)
const GOOD := Color(0.16, 0.48, 0.14)
const PANEL := UiStyle.CREAM
const CATEGORY_NAMES := {
	"agriculture": "Farming", "construction": "Building", "craft": "Craft",
	"governance": "Government", "health": "Health", "knowledge": "Learning",
	"maritime": "Seafaring", "metallurgy": "Metals", "military": "War", "trade": "Trade",
}

var view: Dictionary = {}
var tab := "ideas"
var selected: Dictionary = {}   ## the province (or sea) the player clicked, from the view
var civ_colours := {}
var message := ""
var deliberating := false       ## waiting for the court's ruling on the player's idea
var question := ""              ## the court's clarifying question, if it asked one
var rulings: Array = []         ## the latest rulings, shown at the top of the Ideas tab
var court_mode := "offline"     ## "online" when a language model rules, from settings

var _root := Control.new()
var _top := HBoxContainer.new()
var _side_body := VBoxContainer.new()
var _tabs := HBoxContainer.new()
var _card := PanelContainer.new()
var _card_body := VBoxContainer.new()
var _chronicle := VBoxContainer.new()
var _end_turn := Button.new()
var _hover := Label.new()
var _idea_box := VBoxContainer.new()
var _idea_input := LineEdit.new()
var _idea_send := Button.new()
var _idea_status := Label.new()
var _asked := ""                ## the words the question was about
var _dots := 0.0
var _speech_queue: Array = []
var _speech: Control


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
	_hover.add_theme_color_override("font_color", UiStyle.CREAM)
	_hover.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03, 0.95))
	_hover.add_theme_constant_override("outline_size", 7)
	_hover.add_theme_font_override("font", UiStyle.font("body", 800))
	_hover.add_theme_font_size_override("font_size", 18)
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


## Characters take turns to speak: portrait, name ribbon and speech bubble, bottom left.
## Click the bubble to hear the next one.
func speak(voices: Array, replace := false) -> void:
	if replace:  # a new turn: lines nobody clicked through are old news
		_speech_queue.clear()
		if _speech != null:
			_speech.queue_free()
			_speech = null
	_speech_queue.append_array(voices)
	if _speech == null and not _speech_queue.is_empty():
		_show_next_voice()


func _show_next_voice() -> void:
	if _speech != null:
		_speech.queue_free()
		_speech = null
	_card.visible = _speech_queue.is_empty()
	if _speech_queue.is_empty():
		return
	var voice: Dictionary = _speech_queue.pop_front()
	var colour := Color(voice["colour"])
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 12
	box.offset_top = -262
	box.offset_right = 780
	box.offset_bottom = -12
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_show_next_voice())
	var bubble := PanelContainer.new()
	var bubble_style := UiStyle.panel(UiStyle.CREAM, colour.darkened(0.3), 16)
	bubble_style.content_margin_left = 44
	bubble.add_theme_stylebox_override("panel", bubble_style)
	bubble.position = Vector2(170, 40)
	bubble.custom_minimum_size = Vector2(590, 180)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	column.add_child(spacer)
	var text := UiStyle.wrapped(str(voice["text"]), 19, UiStyle.INK, 520)
	text.add_theme_font_override("font", UiStyle.font("body", 700))
	column.add_child(text)
	var more := "▸ click to continue" + (" (%d more)" % _speech_queue.size() if not _speech_queue.is_empty() else "")
	var hint := UiStyle.label(more, 13, UiStyle.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(hint)
	bubble.add_child(column)
	box.add_child(bubble)
	# name ribbon across the top of the bubble
	var ribbon := PanelContainer.new()
	var ribbon_style := UiStyle.panel(colour, colour.darkened(0.4), 8)
	ribbon_style.content_margin_top = 4
	ribbon_style.content_margin_bottom = 4
	ribbon.add_theme_stylebox_override("panel", ribbon_style)
	ribbon.position = Vector2(200, 18)
	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 12)
	var name := UiStyle.headline(str(voice["name"]), 24, UiStyle.CREAM)
	names.add_child(name)
	names.add_child(UiStyle.label(str(voice["title"]), 15, colour.lightened(0.75)))
	ribbon.add_child(names)
	box.add_child(ribbon)
	var portrait := Portrait.new()
	portrait.position = Vector2(0, 0)
	portrait.size = Vector2(190, 240)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.setup({"colour": voice["colour"], "portrait": voice["portrait"], "culture": voice.get("culture", ""),
		"id": "%s_%s" % [voice["civ"], voice["speaker"]]})
	box.add_child(portrait)
	_root.add_child(box)
	_speech = box
	# slide in from the left
	box.modulate.a = 0.0
	var start := box.position
	box.position.x -= 60
	var tween := create_tween().set_parallel()
	tween.tween_property(box, "position", start, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "modulate:a", 1.0, 0.2)


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
	_update_idea_box()
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
	var theme := UiStyle.theme()
	theme.default_font_size = 15
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := UiStyle.button_box(state)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		box.border_width_bottom = 4 if state != "pressed" else 2
		theme.set_stylebox(state, "Button", box)
	var panel := UiStyle.panel()
	panel.set_content_margin_all(12)
	theme.set_stylebox("panel", "PanelContainer", panel)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.82, 0.76, 0.64)
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = UiStyle.GOLD
	bar_fill.set_corner_radius_all(4)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	return theme


## Text sizes below are a design size; small text is enlarged so nothing is hard to read.
static func readable(size: int) -> int:
	return size + 3 if size <= 13 else size + 2


func _label(text: String, size := 15, colour := INK) -> Label:
	size = readable(size)
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
	var style := UiStyle.panel()
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", style)
	_top.add_theme_constant_override("separation", 16)
	bar.add_child(_top)
	_root.add_child(bar)


func _fill_top_bar() -> void:
	_clear(_top)
	var status: Dictionary = view["status"]
	var trends: Dictionary = status["trends"]
	var me: Dictionary = {}
	for civ in view["civs"]:
		if civ["id"] == view["player"]:
			me = civ
	var badge := PanelContainer.new()
	var badge_style := UiStyle.panel(civ_colours.get(view["player"], UiStyle.GOLD), UiStyle.GOLD_DARK, 22)
	badge_style.set_content_margin_all(4)
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.shadow_size = 0
	badge.add_theme_stylebox_override("panel", badge_style)
	var emblem := UiStyle.headline(str(me.get("emblem", "")), 24, UiStyle.CREAM)
	emblem.add_theme_font_override("font", UiStyle.font("emblem"))
	badge.add_child(emblem)
	_top.add_child(badge)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.add_child(UiStyle.label(str(status["name"]).to_upper(), 22, GOLD, "title", 900))
	titles.add_child(UiStyle.label("%s · turn %d" % [year_text(view["year"]), view["turn"]], 15, DIM, "body", 700))
	_top.add_child(titles)
	_top.add_child(VSeparator.new())
	var stores: Dictionary = status["stores"]
	_stat("people", "People", people(status["population"]), trends["population"], true)
	_stat("food", "Food in store", number(stores["food"]), trends["food"], true)
	_stat("materials", "Materials", number(stores["materials"]), 0, true)
	_stat("wealth", "Wealth", number(stores["wealth"]), 0, true)
	_stat("knowledge", "Knowledge", number(stores["knowledge"]), 0, true)
	_stat("labour", "Labour: workforce (free for projects)", "%s (%s)" % [number(status["workforce"]), number(status["free_labour"])], 0, true)
	_top.add_child(VSeparator.new())
	_stat("literacy", "Literacy", pct(status["literacy_bp"]), trends["literacy_bp"], true)
	_stat("unrest", "Unrest", pct(status["unrest_bp"]), trends["unrest_bp"], false)
	_stat("legitimacy", "Legitimacy", pct(status["legitimacy_bp"]), trends["legitimacy_bp"], true)
	_stat("suspicion", "Suspicion: how uncanny your progress looks", pct(status["suspicion_bp"]), trends["suspicion_bp"], false)


## One figure with its icon and a trend arrow; `up_is_good` decides green or red.
## Hover it for its name.
func _stat(icon: String, name: String, value: String, trend: int, up_is_good: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.tooltip_text = name
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var picture := GameIcon.make(icon, 30)
	row.add_child(picture)
	var figure := UiStyle.label(value, 19, INK, "body", 800)
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(figure)
	if trend != 0:
		var good := (trend > 0) == up_is_good
		var arrow := UiStyle.label("▲" if trend > 0 else "▼", 14, GOOD if good else BAD)
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(arrow)
	_top.add_child(row)


# --- side panel: ideas, projects, world -------------------------------------------------

func _build_side_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -420
	panel.offset_right = -8
	panel.offset_top = 86
	panel.offset_bottom = -92
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.add_child(_tabs)
	_build_idea_box()
	column.add_child(_idea_box)
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
		var button := _button("", set_tab.bind(entry[0]))
		button.toggle_mode = true
		button.button_pressed = tab == entry[0]
		button.custom_minimum_size.y = 46
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# icon + name, centred inside the button
		var holder := HBoxContainer.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		holder.add_theme_constant_override("separation", 6)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(GameIcon.make(entry[0], 26))
		var name := UiStyle.label(entry[1], 17, INK, "body", 800)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(name)
		button.add_child(holder)
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


# --- the idea box: the player's own words for the court (DESIGN §8) ----------------------

func _build_idea_box() -> void:
	_idea_box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_idea_input.placeholder_text = "Whisper an idea to your court…"
	_idea_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_idea_input.custom_minimum_size.y = 44
	_idea_input.max_length = 600
	_idea_input.add_theme_font_override("font", UiStyle.font("body", 700))
	_idea_input.add_theme_font_size_override("font_size", 17)
	_idea_input.add_theme_color_override("font_color", INK)
	_idea_input.add_theme_color_override("font_placeholder_color", Color(DIM, 0.7))
	var field := UiStyle.panel(Color(1, 0.99, 0.95), UiStyle.GOLD_DARK, 10)
	field.set_content_margin_all(8)
	_idea_input.add_theme_stylebox_override("normal", field)
	_idea_input.add_theme_stylebox_override("focus", field)
	_idea_input.text_submitted.connect(func(_t: String): _submit_idea())
	row.add_child(_idea_input)
	_idea_send.text = "Propose"
	_idea_send.custom_minimum_size = Vector2(104, 44)
	_idea_send.focus_mode = Control.FOCUS_NONE
	_idea_send.add_theme_font_size_override("font_size", 17)
	_idea_send.pressed.connect(_submit_idea)
	row.add_child(_idea_send)
	_idea_box.add_child(row)
	_idea_status.add_theme_font_size_override("font_size", readable(12))
	_idea_status.add_theme_color_override("font_color", DIM)
	_idea_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_idea_box.add_child(_idea_status)
	_update_idea_box()


func _submit_idea() -> void:
	var text := _idea_input.text.strip_edges()
	if deliberating or text == "":
		return
	if question != "":
		idea_submitted.emit(_asked, text)  # the answer to the court's question
	else:
		_asked = text
		idea_submitted.emit(text, "")
	_idea_input.text = ""


## The court starts or stops thinking about the player's idea.
func set_deliberating(on: bool) -> void:
	deliberating = on
	_update_idea_box()


## Show what the court made of the idea: a question, or one ruling per idea.
func show_rulings(result: Dictionary) -> void:
	question = str(result.get("question", ""))
	rulings = result.get("rulings", [])
	if question == "":
		_asked = ""
	tab = "ideas"
	_update_idea_box()
	if not view.is_empty():
		_fill_side()


func _update_idea_box() -> void:
	_idea_input.editable = not deliberating
	_idea_send.disabled = deliberating
	_idea_box.visible = tab == "ideas"
	if deliberating:
		_idea_status.text = "The court deliberates"
		_idea_status.add_theme_color_override("font_color", GOLD)
	elif question != "":
		_idea_status.text = "The court asks: %s" % question
		_idea_status.add_theme_color_override("font_color", GOLD)
		_idea_input.placeholder_text = "Your answer…"
	else:
		_idea_status.text = "Anything at all: \"make the river work for us\", \"a printing press\"… (%s)" % court_mode
		_idea_status.add_theme_color_override("font_color", DIM)
		_idea_input.placeholder_text = "Whisper an idea to your court…"


func _process(delta: float) -> void:
	if deliberating:
		_dots += delta * 2.5
		_idea_status.text = "The court deliberates" + ".".repeat(int(_dots) % 4)


func _ruling_card(ruling: Dictionary) -> Control:
	var verdict := str(ruling["verdict"])
	var colours := {"feasible": GOOD, "blocked": Color(0.70, 0.45, 0.08), "implausible_for_era": BAD}
	var words := {"feasible": "Within reach", "blocked": "Needs groundwork", "implausible_for_era": "Beyond this age"}
	var box := PanelContainer.new()
	var tint: Color = colours.get(verdict, DIM)
	box.add_theme_stylebox_override("panel", UiStyle.panel(Color(tint.lightened(0.82), 1.0), tint, 10))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	var name := _label(str(ruling["name"]), 16, INK)
	name.add_theme_font_override("font", UiStyle.font("body", 800))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(name)
	head.add_child(_label(words.get(verdict, verdict), 12, tint))
	body.add_child(head)
	if ruling.get("new", false):
		body.add_child(_label("A new idea, added to your ideas", 12, GOLD))
	for line in [str(ruling.get("message", "")), str(ruling.get("reason", "")), str(ruling.get("hint", ""))]:
		if line != "":
			body.add_child(_wrapped(line, 13, INK))
	box.add_child(body)
	return box


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
	if not rulings.is_empty():
		_side_body.add_child(_label("The court's ruling", 17, GOLD))
		for ruling in rulings:
			_side_body.add_child(_ruling_card(ruling))
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
	elif idea.get("stub", false):
		var ask := _button("Ask the court", func(): idea_submitted.emit(str(idea["name"]), ""))
		ask.disabled = deliberating
		head.add_child(ask)
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
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 792
	panel.offset_right = 1352
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
		line.custom_minimum_size.x = 520
		_chronicle.add_child(line)
	if events.size() > 6:
		_chronicle.add_child(_label("… and %d more" % (events.size() - 6), 12, DIM))


func _build_end_turn() -> void:
	_end_turn = UiStyle.big_button("END TURN  ▸", 24)
	_end_turn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_end_turn.offset_left = -236
	_end_turn.offset_top = -80
	_end_turn.offset_right = -8
	_end_turn.offset_bottom = -8
	_end_turn.pressed.connect(func(): end_turn_requested.emit())
	_root.add_child(_end_turn)
