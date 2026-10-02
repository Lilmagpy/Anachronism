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
signal menu_requested
signal capital_requested
signal spoke                    ## a character has started speaking (for the chime)
signal armies_changed           ## the army selection changed: redraw the armies

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
var court_mode := "offline"
var selected_army := ""        ## the army the player picked (drawn with a gold ring)
var marching_army := ""        ## waiting for the player to click where this army should march
var levy_style := "balanced"   ## the mix of soldiers the next levy will have
var selected_fleet := ""       ## the fleet the player picked (drawn with a gold ring)
var sailing_fleet := ""        ## waiting for the player to click where this fleet should sail
var open_box := ""             ## the unfolded section of the province card: "levy", "fleet", "build" or ""
var _outcome_shown := false
var dev_info: Dictionary = {}   ## filled by main: engine and model details for F3
var _dev := Label.new()     ## "online" when a language model rules, from settings

var _root := Control.new()
var _top := HBoxContainer.new()
var _side_body := VBoxContainer.new()
var _tabs := HBoxContainer.new()
var _dilemma := PanelContainer.new()
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
	_dilemma.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_dilemma.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dilemma.offset_top = 110
	_dilemma.custom_minimum_size = Vector2(620, 0)
	_dilemma.visible = false
	_root.add_child(_dilemma)
	_hover.add_theme_color_override("font_color", UiStyle.CREAM)
	_hover.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03, 0.95))
	_hover.add_theme_constant_override("outline_size", 7)
	_hover.add_theme_font_override("font", UiStyle.font("body", 800))
	_hover.add_theme_font_size_override("font_size", 18)
	_hover.visible = false
	_root.add_child(_hover)
	_dev.position = Vector2(16, 96)
	_dev.add_theme_font_size_override("font_size", 14)
	_dev.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_dev.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_dev.add_theme_constant_override("outline_size", 6)
	_dev.visible = false
	_root.add_child(_dev)


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
	_fill_dilemma()
	var outcome: Variant = view.get("victory", {}).get("outcome")
	if outcome != null and not _outcome_shown:
		_outcome_shown = true
		_show_outcome(outcome)


## A choice put to the ruler (D-104): the situation and a button for each answer, with what
## it will do. Left unanswered, the court takes the first answer when the turn ends.
func _fill_dilemma() -> void:
	for child in _dilemma.get_children():
		child.queue_free()
	var question: Variant = view.get("dilemma")
	var offer: Variant = view.get("offer")
	_dilemma.visible = question != null or offer != null
	if question == null and offer != null:
		_fill_offer(offer)
		return
	if question == null:
		return
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.add_child(UiStyle.label(str(question["title"]), 24, UiStyle.RED, "title", 800))
	var text := _wrapped(str(question["text"]), 16, INK)
	text.custom_minimum_size = Vector2(580, 0)
	body.add_child(text)
	for i in question["choices"].size():
		var choice: Dictionary = question["choices"][i]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var pick := _button(str(choice["label"]), func():
			action_requested.emit({"kind": "dilemma", "dilemma": question["id"], "choice": i}))
		pick.add_theme_font_size_override("font_size", 16)
		row.add_child(pick)
		row.add_child(_label(str(choice["hint"]), 12, DIM))
		body.add_child(row)
	body.add_child(_label("If you do not choose, the court will take the first answer.", 12, DIM))
	_dilemma.add_child(body)


## Envoys from a rival court (D-105): their proposal, and accept or refuse.
func _fill_offer(offer: Dictionary) -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = civ_colours.get(offer["from"], Color.GRAY)
	swatch.custom_minimum_size = Vector2(18, 18)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(swatch)
	head.add_child(UiStyle.label(str(offer["title"]), 24, UiStyle.RED, "title", 800))
	body.add_child(head)
	var text := _wrapped(str(offer["text"]), 16, INK)
	text.custom_minimum_size = Vector2(580, 0)
	body.add_child(text)
	body.add_child(_wrapped(str(offer["hint"]), 13, DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for answer in [[str(offer["accept"]), true], [str(offer["decline"]), false]]:
		var pick := _button(answer[0], func(): action_requested.emit({"kind": "envoy_answer", "accept": answer[1]}))
		pick.add_theme_font_size_override("font_size", 16)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pick)
	body.add_child(row)
	body.add_child(_label("If you give no answer, the court refuses for you.", 12, DIM))
	_dilemma.add_child(body)


## The end of the game (DESIGN §11): a banner across the screen; play can continue.
func _show_outcome(outcome: Dictionary) -> void:
	var won: bool = outcome["result"] == "victory"
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.45)
	_root.add_child(shade)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	var title := UiStyle.headline("VICTORY" if won else "DEFEAT", 84, UiStyle.GOLD if won else Color(0.8, 0.25, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var how := {"military": "by the sword", "economic": "through trade", "cultural": "by the pen and the word", "collapse": "your state has fallen"}
	var line := "%s dominates the region %s, %s." % [view["status"]["name"], how.get(outcome["path"], ""), year_text(outcome["year"])] if won else "In %s %s." % [year_text(outcome["year"]), how["collapse"]]
	var words := UiStyle.wrapped(line, 22, UiStyle.INK, 620)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(words)
	# the reign in numbers, and its boldest anachronism
	var in_use := 0
	var boldest := ""
	var boldest_ahead := 0
	var started := int(view["year"]) - (int(view["turn"]) - 1) * int(view["years_per_turn"])
	for idea in view["ideas"]:
		if idea["stage"] in ["adopted", "widespread"]:
			in_use += 1
			if int(idea["year"]) - started > boldest_ahead:
				boldest_ahead = int(idea["year"]) - started
				boldest = str(idea["name"])
	var owned := 0
	for p in view["provinces"]:
		if p["owner"] == view["player"]:
			owned += 1
	var summary := "%d years · %d ideas in use · %d provinces · %s people" % [
		int(outcome["year"]) - started, in_use, owned, people(view["status"]["population"])]
	var facts := _label(summary, 16, INK)
	facts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(facts)
	if boldest != "":
		var feat := _label("Boldest anachronism: %s, %d years before its time" % [boldest, boldest_ahead], 15, GOLD)
		feat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(feat)
	if won:
		column.add_child(_label("A regional victory. Greater tiers - a hemisphere, the world - await more regions.", 13, DIM))
	var keep := UiStyle.big_button("KEEP PLAYING", 24)
	keep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	keep.pressed.connect(func():
		shade.queue_free()
		box.queue_free())
	column.add_child(keep)
	box.add_child(column)
	_root.add_child(box)


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
	_chronicle.get_parent().visible = _speech_queue.is_empty() and int(view.get("turn", 1)) > 1
	if _speech_queue.is_empty():
		return
	var voice: Dictionary = _speech_queue.pop_front()
	spoke.emit()
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
		"id": "%s_%s" % [voice["civ"], voice["name"] if voice["speaker"] in ["ruler", "rival"] else voice["speaker"]]})
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
	if not selected.is_empty() and _speech != null:
		# the player wants the map now: let the court fall silent so the card shows
		_speech_queue.clear()
		_show_next_voice()


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
	var panel := UiStyle.ornate_panel().duplicate() as StyleBoxTexture
	panel.set_content_margin_all(16)
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
	var style := UiStyle.ornate_panel().duplicate() as StyleBoxTexture
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
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
	var badge := Button.new()
	badge.flat = true
	badge.focus_mode = Control.FOCUS_NONE
	badge.tooltip_text = "Visit your capital and see what your ideas have built"
	badge.pressed.connect(func(): capital_requested.emit())
	var badge_inner := PanelContainer.new()
	badge_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_inner)
	badge_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.custom_minimum_size = Vector2(maxf(56.0, 30.0 + 19.0 * str(me.get("emblem", "")).length()), 52)
	var badge_style := UiStyle.panel(civ_colours.get(view["player"], UiStyle.GOLD), UiStyle.GOLD_DARK, 22)
	badge_style.set_content_margin_all(4)
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.shadow_size = 0
	badge_inner.add_theme_stylebox_override("panel", badge_style)
	if str(me.get("symbol", "")) != "":
		# the realm's heraldic shield (G1)
		badge.custom_minimum_size = Vector2(52, 60)
		badge_style.bg_color = Color(0, 0, 0, 0)
		badge_style.border_color = Color(0, 0, 0, 0)
		var arms := TextureRect.new()
		arms.texture = Symbols.shield(civ_colours.get(view["player"], UiStyle.GOLD), str(me["symbol"]), 128)
		arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arms.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_inner.add_child(arms)
	else:
		var emblem := UiStyle.headline(str(me.get("emblem", "")), 24, UiStyle.CREAM)
		emblem.add_theme_font_override("font", UiStyle.font("emblem"))
		badge_inner.add_child(emblem)
	_top.add_child(badge)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.add_child(UiStyle.label(str(status["name"]).to_upper(), 22, GOLD, "title", 900))
	var reign := ""
	if str(status.get("ruler", "")) != "":
		reign = " · %s (%d)" % [status["ruler"], int(status["ruler_age"])]
	elif int(status.get("ruler_age", 0)) > 0:
		reign = " · a new ruler (%d)" % int(status["ruler_age"])
	titles.add_child(UiStyle.label("%s · turn %d%s" % [year_text(view["year"]), view["turn"], reign], 15, DIM, "body", 700))
	_top.add_child(titles)
	_top.add_child(VSeparator.new())
	var stores: Dictionary = status["stores"]
	_stat("people", "People: more people means more workers and more taxes", people(status["population"]), trends["population"], true)
	_stat("food", "Food in store: if it runs out, people starve", number(stores["food"]), trends["food"], true)
	_stat("materials", "Materials: stone, timber and metal for building and experiments", number(stores["materials"]), 0, true)
	_stat("wealth", "Wealth: pays for experiments, embassies, missionaries and decrees", number(stores["wealth"]), 0, true)
	_stat("knowledge", "Knowledge: your scholars' learning, spent on every new idea", number(stores["knowledge"]), 0, true)
	_stat("labour", "Labour: your workforce, and in brackets how many are free for experiments", "%s (%s)" % [number(status["workforce"]), number(status["free_labour"])], 0, true)
	_top.add_child(VSeparator.new())
	_stat("literacy", "Literacy: who can read; it speeds learning, and some ideas need it", pct(status["literacy_bp"]), trends["literacy_bp"], true)
	_stat("unrest", "Unrest: when it runs high come riots, then revolts", pct(status["unrest_bp"]), trends["unrest_bp"], false)
	_stat("legitimacy", "Legitimacy: the people's trust in the throne; it holds the realm and its armies together", pct(status["legitimacy_bp"]), trends["legitimacy_bp"], true)
	_stat("suspicion", "Suspicion: how uncanny your progress looks to the world; it draws spies and enemies", pct(status["suspicion_bp"]), trends["suspicion_bp"], false)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top.add_child(push)
	var menu := Button.new()
	menu.tooltip_text = "Menu: save, load, chronicle, tech tree, settings (Esc)"
	menu.focus_mode = Control.FOCUS_NONE
	menu.custom_minimum_size = Vector2(52, 44)
	var picture := GameIcon.make("menu", 24)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 10
	picture.offset_right = -10
	picture.offset_top = 8
	picture.offset_bottom = -8
	menu.add_child(picture)
	menu.pressed.connect(func(): menu_requested.emit())
	_top.add_child(menu)


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
	panel.offset_left = -440
	panel.offset_right = -8
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
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
	var gutter := MarginContainer.new()  # room for the scroll bar
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", 14)
	gutter.add_child(_side_body)
	scroll.add_child(gutter)
	column.add_child(scroll)
	panel.add_child(column)
	_root.add_child(panel)


func _fill_side() -> void:
	_clear(_tabs)
	for entry in [["ideas", "Ideas"], ["projects", "Projects %d" % view["projects"].size()], ["world", "World"]]:
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
		holder.add_child(GameIcon.make(entry[0], 22))
		var name := UiStyle.label(entry[1], 15, INK, "body", 800)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(name)
		button.add_child(holder)
		_tabs.add_child(button)
	_clear(_side_body)
	var exile: Array = view["status"].get("exile", [])
	if not exile.is_empty():   # fallen, but remembered (D-113)
		_side_body.add_child(_wrapped("Your state has fallen. Its people still remember it in %s: while no garrison holds them down they may rise and restore it. Wait, and end the turn." % ", ".join(exile), 14, BAD))
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


## The developer overlay (brief §6.6, §11): engine, seed, turn, the court's model and its
## token use. Toggled with F3.
func toggle_dev() -> void:
	_dev.visible = not _dev.visible


func _process(delta: float) -> void:
	if _dev.visible:
		var lines := ["DEVELOPER (F3)", "fps %d" % Engine.get_frames_per_second()]
		if not view.is_empty():
			lines.append("%s · seed %d · turn %d" % [view["scenario"], int(view["seed"]), int(view["turn"])])
		for key in dev_info:
			lines.append("%s: %s" % [key, dev_info[key]])
		_dev.text = "\n".join(lines)
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
	var steps: Array = ruling.get("next_steps", [])
	if not steps.is_empty():
		body.add_child(_label("Start on the road there:", 12, DIM))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 4)
		row.add_theme_constant_override("v_separation", 4)
		for step in steps:
			row.add_child(_small_button("Begin " + str(step["name"]), {"kind": "start", "node_id": str(step["id"])}))
		body.add_child(row)
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
	# the game's hook first: ideas ahead of their time, soonest first; then what the wider
	# world already knows, most recent first (old basics would otherwise top every list)
	var now: int = int(view["year"])
	var ahead_ideas: Array = ready.filter(func(i): return int(i["year"]) > now)
	var abroad: Array = ready.filter(func(i): return int(i["year"]) <= now)
	ahead_ideas.sort_custom(func(a, b): return a["year"] < b["year"])
	abroad.sort_custom(func(a, b): return a["year"] > b["year"])
	if not rulings.is_empty():
		_side_body.add_child(_label("The court's ruling", 17, GOLD))
		for ruling in rulings:
			_side_body.add_child(_ruling_card(ruling))
	var advice: Array = view.get("advice", [])
	if not advice.is_empty():
		_side_body.add_child(_label("Your court's counsel", 17, GOLD))
		for item in advice:
			_side_body.add_child(_advice_card(item))
	_side_body.add_child(_label("Ideas ahead of their time", 17, GOLD))
	_side_body.add_child(_wrapped("Each costs labour, materials, knowledge and wealth every turn until it works. The further ahead of its time, the more it costs and the more suspicion it draws."))
	if ahead_ideas.is_empty():
		_side_body.add_child(_wrapped("None within reach yet: whisper your own, or learn what the world already knows.", 13, DIM))
	for idea in ahead_ideas:
		_side_body.add_child(_idea_card(idea))
	if not abroad.is_empty():
		_side_body.add_child(_label("Known abroad: catch up", 17, GOLD))
		for idea in abroad:
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


## One adviser's recommendation: who speaks, their reason, and a button to begin.
func _advice_card(item: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	var who := _label(str(item["name"]), 15, BAD if item["urgent"] else INK)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	var node_id := str(item["node_id"])
	head.add_child(_small_button("Begin", {"kind": "start", "node_id": node_id}))
	card.add_child(head)
	card.add_child(_wrapped("\u201c%s\u201d" % str(item["text"]), 13, DIM))
	return card


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
	# how much of the workforce is still free: the one limit on how much you can try
	var status: Dictionary = view["status"]
	var workforce := int(status.get("workforce", 0))
	var free := int(status.get("free_labour", 0))
	if workforce > 0:
		var share := float(free) / float(workforce)
		var note := "Free hands: %s of %s workers (%d%%)." % [number(free), number(workforce), int(share * 100.0)]
		if share < 0.1:
			note += " Almost everyone is busy: more work now means hunger and unrest."
		else:
			note += " Each experiment takes some of them from the fields."
		_side_body.add_child(_wrapped(note, 13, BAD if share < 0.1 else DIM))
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
				var pick := _button(level.capitalize(), func(): action_requested.emit({"kind": "priority", "node_id": id, "priority": level}))
				pick.tooltip_text = {"high": "Funded first, even if it pulls farmers from the fields",
					"normal": "Funded after high-priority work",
					"low": "Steady work: only spare hands, never farmers. Slower, but it cannot cause\na famine and does not decay while it keeps moving"}[level]
				row.add_child(pick)
		row.add_child(_button("Abandon", func(): action_requested.emit({"kind": "cancel", "node_id": id})))
		box.add_child(row)
		box.add_child(HSeparator.new())
		_side_body.add_child(box)


func _fill_world() -> void:
	var victory: Dictionary = view.get("victory", {})
	var outcome: Variant = victory.get("outcome")
	if outcome != null:
		var won: bool = outcome["result"] == "victory"
		_side_body.add_child(_label(("Victory: " if won else "Defeat: ") + str(outcome["path"]), 18, GOOD if won else BAD))
	_side_body.add_child(_label("Paths to dominance", 17, GOLD))
	var names := {"military": ["army", "By the sword", "Rule over this share of all the people"],
		"economic": ["wealth", "Through trade", "Reach this share of other peoples through trade partners and allies (allies count double), with friendly ties to half the other states, and earn at least half the wealth per turn of the largest economy"],
		"cultural": ["knowledge", "By the pen", "Hold this share of the region's culture (people weighted by literacy and influence)"]}
	var paths: Dictionary = victory.get("paths", {})
	for path in ["military", "economic", "cultural"]:
		if paths.has(path):
			_side_body.add_child(_victory_bar(names[path], paths[path]))
	var wars: Array = view.get("wars", [])
	if not wars.is_empty():
		_side_body.add_child(_label("Wars", 17, GOLD))
		for war in wars:
			_side_body.add_child(_wrapped("⚔ %s and %s are at war" % [_civ_name(war["a"]), _civ_name(war["b"])], 14, BAD))
	var status: Dictionary = view["status"]
	if status.has("festival_cost"):
		_side_body.add_child(_label("Royal decrees", 17, GOLD))
		var decrees := HBoxContainer.new()
		decrees.add_theme_constant_override("separation", 6)
		var rich: int = int(status["stores"]["wealth"])
		var feast := _small_button("Hold a festival (%s)" % number(int(status["festival_cost"])), {"kind": "festival"})
		feast.disabled = rich < int(status["festival_cost"])
		feast.tooltip_text = "Feasts and games: legitimacy up, unrest down"
		decrees.add_child(feast)
		var hire := _small_button("Hire mercenaries (%s)" % number(int(status["mercenary_cost"])), {"kind": "mercenaries"})
		hire.disabled = rich < int(status["mercenary_cost"]) or int(status["mercenaries"]) > 0
		hire.tooltip_text = "More military strength for two turns"
		decrees.add_child(hire)
		_side_body.add_child(decrees)
		if int(status["mercenaries"]) > 0:
			_side_body.add_child(_label("Mercenaries serve for %d more turn(s)" % int(status["mercenaries"]), 12, DIM))
		if status.has("sealed"):
			var secrets := HBoxContainer.new()
			secrets.add_theme_constant_override("separation", 6)
			var seal := _small_button("Seal the borders", {"kind": "seal"})
			seal.disabled = int(status["sealed"]) > 0
			seal.tooltip_text = "For %d turns: no trade with anyone, but news of your inventions travels half as fast" % int(status["seal_turns"])
			secrets.add_child(seal)
			var on_road: int = int(status["news_on_the_road"])
			var rumours := _small_button("Spread false rumours (%s)" % number(int(status["rumour_cost"])), {"kind": "rumours"})
			rumours.disabled = on_road == 0 or rich < int(status["rumour_cost"])
			rumours.tooltip_text = "Storytellers muddle the news of your inventions already on the road: rivals hear nonsense first and the truth much later"
			secrets.add_child(rumours)
			_side_body.add_child(secrets)
			if int(status["sealed"]) > 0:
				_side_body.add_child(_label("Borders sealed for %d more turn(s): no trade" % int(status["sealed"]), 12, DIM))
			if on_road > 0:
				_side_body.add_child(_label("Word of your inventions is on the road to %d court(s)" % on_road, 12, DIM))
		if status.has("explain_costs") and int(status["suspicion_bp"]) > 0:
			var costs: Array = status["explain_costs"]
			var wait: int = int(status["explain_ready_in"])
			var stories := HBoxContainer.new()
			stories.add_theme_constant_override("separation", 6)
			var divine := _small_button("Divine gift (%s)" % number(int(costs[0])), {"kind": "explain", "story": "divine"})
			divine.disabled = wait > 0 or rich < int(costs[0])
			divine.tooltip_text = "Priests proclaim the new arts divine: suspicion down. If the people trust the throne, talk of witchcraft or fraud turns to awe"
			stories.add_child(divine)
			var sages := _small_button("Foreign sages (%s knowledge)" % number(int(costs[1])), {"kind": "explain", "story": "sages"})
			sages.disabled = wait > 0 or int(status["stores"]["knowledge"]) < int(costs[1])
			sages.tooltip_text = "Blame wise strangers from distant lands: suspicion falls further, but rivals hear of your arts at once"
			stories.add_child(sages)
			_side_body.add_child(_label("People ask where the court's new arts come from", 13, INK))
			_side_body.add_child(stories)
			if wait > 0:
				_side_body.add_child(_label("The court's last story is still fresh: wait %d turn(s)" % wait, 12, DIM))
	_side_body.add_child(_label("The powers of the world", 17, GOLD))
	_side_body.add_child(_wrapped("On the map, lines from your capital: gold to trading partners, green to allies, purple to tributaries.", 12, DIM))
	var me: Dictionary = {}
	for civ in view["civs"]:
		if civ["id"] == view["player"]:
			me = civ
	var civs: Array = view["civs"].filter(func(c): return c["id"] != view["player"] and c["alive"])
	civs.sort_custom(func(a, b):
		var ka := 0 if a["relation"] != null else 1
		var kb := 0 if b["relation"] != null else 1
		return a["population"] > b["population"] if ka == kb else ka < kb)
	for civ in civs:
		_side_body.add_child(_rival_card(civ, me))


func _civ_name(civ_id: String) -> String:
	for civ in view["civs"]:
		if civ["id"] == civ_id:
			return str(civ["name"])
	return civ_id


func _victory_bar(info: Array, path: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.tooltip_text = str(info[2])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(GameIcon.make(str(info[0]), 22))
	var title := _label(str(info[1]), 14, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_label("%s of %s" % [pct(int(path["share_bp"])), pct(int(path["target_bp"]))], 12, DIM))
	box.add_child(head)
	var bar := ProgressBar.new()
	bar.max_value = max(1, int(path["target_bp"]))
	bar.value = min(int(path["share_bp"]), int(path["target_bp"]))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.80, 0.55, 0.12)
	fill.set_corner_radius_all(5)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.85, 0.80, 0.70)
	back.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)
	# the other conditions a path needs, ticked off as they are met
	var also: Array = []
	if path.has("partners"):
		also.append([int(path["partners"]) >= int(path["partners_needed"]),
			"Friendly ties: %d of %d states" % [int(path["partners"]), int(path["partners_needed"])]])
	if path.has("income"):
		also.append([bool(path["richest"]),
			"Income %s a turn (need %s)" % [number(int(path["income"])), number(int(path["income_target"]))]])
	if path.has("leading"):
		also.append([bool(path["leading"]), "No rival's culture larger"])
	if path.has("influence_bp"):
		also.append([int(path["influence_bp"]) >= int(path["influence_target_bp"]),
			"Cultural influence %s (need %s)" % [pct(int(path["influence_bp"])), pct(int(path["influence_target_bp"]))]])
	for item in also:
		box.add_child(_label(("✔ " if item[0] else "· ") + str(item[1]), 12, GOOD if item[0] else DIM))
	return box


func _rival_card(civ: Dictionary, me: Dictionary) -> Control:
	var relation: Variant = civ["relation"]
	var colours := {"war": BAD, "hostile": Color(0.75, 0.35, 0.1), "neutral": DIM, "trading": Color(0.1, 0.45, 0.6),
		"allied": GOOD, "tributary": Color(0.45, 0.3, 0.6)}
	var box := PanelContainer.new()
	var edge: Color = civ_colours.get(civ["id"], DIM)
	box.add_theme_stylebox_override("panel", UiStyle.panel(Color(1, 0.98, 0.93), edge.darkened(0.1), 8))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var swatch := ColorRect.new()
	swatch.color = edge
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(swatch)
	var name := _label(str(civ["name"]), 15, INK)
	name.add_theme_font_override("font", UiStyle.font("body", 800))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var standing := "no contact" if relation == null else str(relation)
	head.add_child(_label(standing, 12, colours.get(standing, DIM)))
	body.add_child(head)
	var mine: int = max(1, int(me.get("strength", 1)))
	var ratio: float = float(civ["strength"]) / float(mine)
	var might := "about your match"
	if ratio > 1.6:
		might = "far stronger than you"
	elif ratio > 1.15:
		might = "stronger than you"
	elif ratio < 0.6:
		might = "far weaker than you"
	elif ratio < 0.85:
		might = "weaker than you"
	var ruler_line := str(civ.get("ruler", ""))
	ruler_line = ("%s, %s, age %d" % [ruler_line, civ["disposition"], int(civ["ruler_age"])]) if ruler_line != "" else "%s ruler" % civ["disposition"]
	body.add_child(_label("%s people · %s" % [people(civ["population"]), might], 12, DIM))
	body.add_child(_label(ruler_line, 12, DIM))
	if str(civ.get("faith", "")) != "":
		body.add_child(_label("Faith: %s%s" % [civ["faith"], "  (as yours)" if civ.get("same_faith", false) else ""], 12, GOOD if civ.get("same_faith", false) else DIM))
	var heard: Array = civ.get("heard_of_you", [])
	if not heard.is_empty():
		body.add_child(_wrapped("Has heard of your %s" % ", ".join(heard), 12, Color(0.6, 0.3, 0.1)))
	if int(civ["grievance_bp"]) >= 2000:
		body.add_child(_label("Bears you a grudge", 12, BAD))
	var intel: Variant = civ.get("intel")
	if intel != null:   # what envoys, merchants or spies say of its plans (D-115)
		var trust := int(intel["trust_bp"])
		var sure := "reliable" if trust >= 7000 else ("often wrong" if trust < 5000 else "fairly reliable")
		var said := "%s say (%s):" % [str(intel["source"]).capitalize(), sure]
		body.add_child(_label(said, 12, GOLD))
		for line in intel["lines"]:
			var warn: bool = "on us" in str(line)
			body.add_child(_wrapped("  " + str(line), 12, BAD if warn else INK))
	if int(civ.get("spies", 0)) > 0:
		body.add_child(_label("Our spies are there (%d more turns)" % int(civ["spies"]), 12, DIM))
	if relation != null:
		body.add_child(_diplomacy_buttons(civ))
	box.add_child(body)
	return box


## What you can do about a civilisation you are in touch with.
func _diplomacy_buttons(civ: Dictionary) -> Control:
	var relation: Variant = civ["relation"]
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 4)
	buttons.add_theme_constant_override("v_separation", 4)
	var target: String = civ["id"]
	if not relation in ["tributary", "allied"]:
		var demand := _small_button("Demand tribute", {"kind": "tribute", "target": target})
		demand.tooltip_text = "A court far weaker than you (or beaten in war) may submit as your tributary"
		buttons.add_child(demand)
	if relation == "war":
		var white := _small_button("Offer peace", {"kind": "peace", "target": target})
		white.tooltip_text = "Each side keeps what it holds now"
		buttons.add_child(white)
		var cede := _small_button("Demand land", {"kind": "peace", "target": target, "terms": "cede"})
		cede.tooltip_text = "Peace, if they cede every province your armies stand in - only a side that is losing gives up land"
		buttons.add_child(cede)
	else:
		buttons.add_child(_small_button("Send envoy", {"kind": "envoy", "target": target}))
		if relation in ["neutral", "trading"]:
			buttons.add_child(_small_button("Propose alliance", {"kind": "alliance", "target": target}))
		buttons.add_child(_small_button("Declare war", {"kind": "declare_war", "target": target}))
		if not civ.get("same_faith", false) and bool(view["status"].get("faith_spreads", false)):
			buttons.add_child(_small_button("Missionaries", {"kind": "missionaries", "target": target}))
	if int(civ.get("spies", 0)) == 0:
		var cost := int(view["status"].get("spy_cost", 0))
		var spy := _small_button("Send spies (%s)" % number(cost), {"kind": "spies", "target": target})
		spy.disabled = int(view["status"]["stores"]["wealth"]) < cost
		spy.tooltip_text = "For %d turns: true word of its plans, its scholars' work and its armies;\nperhaps the secret of one of its advancements. Spies may be caught." % int(view["status"].get("spy_turns", 5))
		buttons.add_child(spy)
	return buttons


func _small_button(text: String, action: Dictionary) -> Button:
	var button := _button(text, func(): action_requested.emit(action))
	button.add_theme_font_size_override("font_size", 13)
	return button


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
		_fill_sea_card()
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
	if p["coastal"] and str(p["terrain"]) != "coast":
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
	var defence := int(p.get("defence_bp", 10000))
	var why: Array = []
	if p["capital"]:
		why.append("capital walls")
	if str(p["terrain"]) in ["hills", "mountains", "forest", "marsh", "desert"]:
		why.append(str(p["terrain"]))
	if int(p.get("walls", 0)) > 0:
		why.append(["stone walls", "towers and gates", "star bastions"][mini(2, int(p["walls"]) - 1)])
	if str(p.get("people", "")) != "":
		var held := "Its people are %s, conquered %d years ago (theirs again in thought after %d more)." % [
			str(p["people"]), int(p["conquered_years"]), int(p["assimilate_in"])]
		if bool(p["garrisoned"]):
			held += " The garrison holds them down."
		else:
			held += " Without a garrison of %s men they may rise." % number(int(p["garrison_need"]))
		_card_body.add_child(_wrapped(held, 13, INK if bool(p["garrisoned"]) else BAD))
	if int(p.get("ravaged", 0)) > 0:
		_card_body.add_child(_wrapped("Ravaged by war: half its crops and goods are lost until it recovers.", 13, BAD))
	if bool(p.get("blockaded", false)):
		_card_body.add_child(_wrapped("Blockaded: enemy warships close its harbours, and most of its trade is lost. Win the sea to lift it.", 13, BAD))
	var hard := "easy" if defence < 11000 else ("hard" if defence < 25000 else "very hard")
	_card_body.add_child(_wrapped("To take in war: %s (%.1f×%s)" % [hard, defence / 10000.0,
		(", " + ", ".join(why)) if not why.is_empty() else ""], 13, DIM))
	_buildings_lines(p)
	var here: Array = view.get("armies", []).filter(func(a): return a["province"] == p["id"])
	if not here.is_empty():
		_card_body.add_child(_label("Armies here", 15, GOLD))
		for army in here:
			_card_body.add_child(_army_box(army))
	if p["owner"] == view["player"] and p.get("wall_next") != null:
		var next: Dictionary = p["wall_next"]
		if str(next["needs"]) != "":
			_card_body.add_child(_wrapped("Higher walls need %s." % str(next["needs"]), 12, DIM))
		else:
			var stores: Dictionary = view["status"]["stores"]
			var build := _small_button("Build walls (%s materials, %s wealth)" % [number(int(next["materials"])), number(int(next["wealth"]))],
				{"kind": "fortify", "province": p["id"]})
			build.disabled = int(stores["materials"]) < int(next["materials"]) or int(stores["wealth"]) < int(next["wealth"])
			build.tooltip_text = "Each level of walls makes the province much harder to besiege"
			_card_body.add_child(build)
	if p["owner"] == view["player"]:
		# raising troops and building ships fold away so the card fits the screen
		var tools := HBoxContainer.new()
		tools.add_theme_constant_override("separation", 4)
		if view.has("levy"):
			tools.add_child(_button(("▾ " if open_box == "levy" else "▸ ") + "Raise a levy", func():
				open_box = "" if open_box == "levy" else "levy"
				_fill_card()))
		if p.has("can_build"):
			tools.add_child(_button(("▾ " if open_box == "build" else "▸ ") + "Build", func():
				open_box = "" if open_box == "build" else "build"
				_fill_card()))
		if p.get("port") != null and view.has("navy"):
			tools.add_child(_button(("▾ " if open_box == "fleet" else "▸ ") + "Build a fleet", func():
				open_box = "" if open_box == "fleet" else "fleet"
				_fill_card()))
		for b in tools.get_children():
			(b as Button).add_theme_font_size_override("font_size", 13)
		_card_body.add_child(tools)
		if open_box == "levy" and view.has("levy"):
			_card_body.add_child(_levy_box(p))
		if open_box == "fleet" and p.get("port") != null and view.has("navy"):
			_card_body.add_child(_shipyard_box(p))
		if open_box == "build" and p.has("can_build"):
			_card_body.add_child(_builders_box(p))
	# a rival's province: where you stand with its holder, and what you can do
	for civ in view["civs"]:
		if civ["id"] == p["owner"] and civ["id"] != view["player"] and civ.get("relation") != null:
			_card_body.add_child(_label("Relations: %s" % str(civ["relation"]), 13, BAD if civ["relation"] == "war" else INK))
			_card_body.add_child(_diplomacy_buttons(civ))


# --- buildings (D-111) ------------------------------------------------------------------


## What stands in a province and what is going up.
func _buildings_lines(p: Dictionary) -> void:
	var standing: Array = p.get("buildings", [])
	var names: Array = standing.map(func(b): return str(b["name"]))
	var head := "Buildings (%d of %d): " % [standing.size(), int(p.get("slots", 0))]
	_card_body.add_child(_wrapped(head + (", ".join(names) if not names.is_empty() else "none yet"), 13, INK))
	var works: Variant = p.get("works")
	if works != null:
		var turns := int(works["turns"])
		_card_body.add_child(_wrapped("Builders at work: %s (%d turn%s left)" % [str(works["name"]), turns, "" if turns == 1 else "s"], 13, GOLD))


## The builders' list (two columns, so the card fits): what can go up here now - hover for
## its cost and what it does - then a few of what is nearly in reach and why not yet.
func _builders_box(p: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 3)
	box.add_child(grid)
	var stores: Dictionary = view["status"]["stores"]
	var blocked: Array = []
	for option in p["can_build"]:
		var reason: Variant = option["why_not"]
		if reason != null:
			if not str(reason).begins_with("builders"):
				blocked.append("%s: %s" % [str(option["name"]), str(reason)])
			continue
		var turns := int(option["turns"])
		var button := _small_button("%s  %s/%s" % [str(option["name"]), _short(int(option["materials"])), _short(int(option["wealth"]))],
			{"kind": "build", "province": p["id"], "building": option["id"]})
		button.custom_minimum_size.x = 172
		button.disabled = int(stores["materials"]) < int(option["materials"]) or int(stores["wealth"]) < int(option["wealth"])
		button.tooltip_text = "%s\n%s\nCosts %s materials and %s wealth; ready in %d turn%s." % [str(option["note"]),
			str(option["does"]), number(int(option["materials"])), number(int(option["wealth"])), turns, "" if turns == 1 else "s"]
		grid.add_child(button)
	if grid.get_child_count() == 0:
		box.add_child(_wrapped("Nothing more can be built here yet.", 12, DIM))
	else:
		box.add_child(_wrapped("Costs are materials/wealth; hover for what each does.", 11, DIM))
	for line in blocked.slice(0, 3):
		box.add_child(_wrapped(line, 12, DIM))
	return box


## A number in a few characters (1,500 -> 1.5k).
func _short(n: int) -> String:
	return str(n) if n < 1000 else ("%.1fk" % (n / 1000.0)).replace(".0k", "k")


# --- armies ------------------------------------------------------------------------------

const STYLE_NAMES := {"balanced": "A balanced host", "infantry": "Mostly foot", "missile": "Mostly archers",
	"mounted": "Mostly horse", "siege": "A siege train"}


## One army: its colours, strength, soldiers, morale, general and doings; orders if yours.
func _army_box(army: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var mine: bool = army["owner"] == view["player"]
	var head := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = civ_colours.get(army["owner"], Color.GRAY)
	swatch.custom_minimum_size = Vector2(12, 12)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(swatch)
	var title := "%s · %s men" % [str(army["name"]), number(int(army["men"]))]
	if not mine:
		title = "%s %s" % [_civ_adjective(str(army["owner"])), title]
	var name := _label(title, 14, GOLD if army["id"] == selected_army else INK)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	box.add_child(head)
	var parts: Array = []
	for t in army["troops"].slice(0, 4):
		parts.append("%s %s" % [str(t["name"]), number(int(t["men"]))])
	box.add_child(_wrapped(", ".join(parts), 12, DIM))
	var notes: Array = ["morale %d%%" % (int(army["morale_bp"]) / 100)]
	var vet := int(army.get("veterancy_bp", 0))
	if vet >= 2000:
		notes.append("hardened veterans")
	elif vet >= 800:
		notes.append("veterans")
	elif vet == 0:
		notes.append("raw recruits")
	if str(army["general"]) != "":
		var gift := {"horse": "master of horse", "siege": "a siege master", "shield": "a stubborn defender",
			"bold": "a bold attacker", "quartermaster": "a careful quartermaster", "beloved": "beloved by the men"}
		var who := "led by %s %s" % [str(army["general"]), "★".repeat(int(army["skill"]))]
		if gift.has(str(army.get("trait", ""))):
			who += ", " + str(gift[str(army["trait"])])
		notes.append(who)
	if army.get("mercenary", false):
		notes.append("hired swords")
	if int(army.get("siege_needed", 0)) > 0:
		notes.append("besieging: %d%% of the walls down" % mini(99, int(army["siege_bp"]) * 100 / int(army["siege_needed"])))
	elif army["target"] != null:
		notes.append("marching on %s" % str(_find_place(str(army["target"])).get("name", army["target"])))
	elif army["stance"] == "pillage":
		notes.append("pillaging the land")
	elif mine:
		notes.append("defending our land" if army["stance"] == "defend" else "holding")
	box.add_child(_wrapped(" · ".join(notes), 12, DIM))
	if not mine and army.get("likely") != null:
		var plan := _wrapped("Likely battle plan: %s%s" % [str(army["likely"]["name"]).to_lower(),
			" - and its general reads his enemy's plan" if army.get("reads", false) else ""], 12, INK)
		plan.tooltip_text = _plan_tip(str(army["likely"]["id"]))
		plan.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(plan)
	if mine:
		box.add_child(_plan_picker(army))
		var orders := HBoxContainer.new()
		orders.add_theme_constant_override("separation", 4)
		var go := _button("March…", func():
			selected_army = str(army["id"])
			marching_army = str(army["id"])
			message = "Click the province the %s should march to." % str(army["name"])
			armies_changed.emit()
			show_view(view))
		go.add_theme_font_size_override("font_size", 13)
		go.tooltip_text = "Then click a province: it marches there (two or three provinces a turn), fighting any enemy it meets and besieging enemy cities"
		orders.add_child(go)
		var hold := _small_button("Hold", {"kind": "stance", "army": army["id"], "stance": "hold"})
		hold.tooltip_text = "Stop and stay here"
		orders.add_child(hold)
		var guard := _small_button("Defend", {"kind": "stance", "army": army["id"], "stance": "defend"})
		guard.tooltip_text = "Stop, and march on any invader of our land"
		orders.add_child(guard)
		var place: Dictionary = _find_place(str(army["province"]))
		var foe_land: bool = place.get("owner") != null and place.get("owner") != view["player"] and _relation_of(str(place["owner"])) == "war"
		if foe_land:
			var ravage := _small_button("Pillage", {"kind": "stance", "army": army["id"], "stance": "pillage"})
			ravage.tooltip_text = "Instead of besieging: burn, loot and drive off the people. The army lives off the land; the enemy tires faster - and never forgets"
			orders.add_child(ravage)
		var home := _small_button("Disband", {"kind": "disband", "army": army["id"]})
		home.tooltip_text = "Send the men home to their fields (they work again, and cost nothing)"
		orders.add_child(home)
		box.add_child(orders)
	return box


## The battle plan an army of yours fights with (D-108): the general's own choice, or yours.
func _plan_picker(army: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var caption := _label("Battle plan", 12, DIM)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var pick := OptionButton.new()
	pick.add_theme_font_size_override("font_size", 12)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array = ["auto"]
	var likely: Variant = army.get("likely")
	pick.add_item("The general decides" + (" (%s)" % str(likely["name"]).to_lower() if likely != null else ""))
	pick.set_item_tooltip(0, "He picks the plan that suits his soldiers and the ground" + (
		"; a great general also reads the enemy's plan and answers it" if army.get("reads", false) else ""))
	var lacking: Dictionary = army.get("lacking", {})
	for t in view.get("tactics", []):
		ids.append(t["id"])
		pick.add_item(str(t["name"]))
		var i := pick.item_count - 1
		var tip := _plan_tip(str(t["id"]))
		if lacking.has(t["id"]):
			pick.set_item_disabled(i, true)
			tip += "\nThis army cannot: it " + str(lacking[t["id"]]) + "."
		pick.set_item_tooltip(i, tip)
		if army["plan"] == t["id"]:
			pick.select(i)
	if army["plan"] == "auto":
		pick.select(0)
	pick.item_selected.connect(func(i): action_requested.emit({"kind": "plan", "army": army["id"], "plan": ids[i]}))
	pick.tooltip_text = "How the army means to fight. Each plan beats some plans and loses to others."
	row.add_child(pick)
	return row


static func _list_or_none(items: Array) -> String:
	return "nothing" if items.is_empty() else ", ".join(items).to_lower()


## A battle plan explained: what it is, what it beats, what beats it, what it needs.
func _plan_tip(plan_id: String) -> String:
	for t in view.get("tactics", []):
		if t["id"] == plan_id:
			var tip := "%s\nBeats: %s. Beaten by: %s." % [str(t["note"]), _list_or_none(t["beats"]), _list_or_none(t["beaten_by"])]
			if str(t["needs"]) != "":
				tip += "\nNeeds: " + str(t["needs"]) + "."
			return tip
	return ""


## Raising a levy in one of your provinces: size, mix, and what it costs.
func _levy_box(p: Dictionary) -> Control:
	var levy: Dictionary = view["levy"]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label("Raise a levy here", 15, GOLD))
	box.add_child(_wrapped("Every levy takes sons from their fields: the people grumble (unrest rises), less among warlike peoples.", 12, DIM))
	box.add_child(_wrapped("Under arms: %s of at most %s. Can raise: %s." % [number(int(levy["under_arms"])),
		number(int(levy["cap"])), ", ".join(levy["kinds"])], 12, DIM))
	var mix := OptionButton.new()
	var keys := STYLE_NAMES.keys()
	for i in keys.size():
		mix.add_item(STYLE_NAMES[keys[i]], i)
		if keys[i] == levy_style:
			mix.select(i)
	mix.add_theme_font_size_override("font_size", 13)
	mix.item_selected.connect(func(i):
		levy_style = keys[i]
		show_view(view))
	box.add_child(mix)
	var style: Dictionary = levy["styles"].get(levy_style, {})
	box.add_child(_wrapped(", ".join(style.get("units", [])), 12, DIM))
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 4)
	var stores: Dictionary = view["status"]["stores"]
	for size in ["small", "medium", "large"]:
		var men := int(p["population"]) * int(levy["sizes"][size]) / 10000 * int(levy["martial_bp"]) / 10000
		var food := int(style.get("food", 0)) * men / 10000
		var wealth := int(style.get("wealth", 0)) * men / 10000
		var materials := int(style.get("materials", 0)) * men / 10000
		var button := _small_button("%s %s" % [size.capitalize(), number(men)],
			{"kind": "raise", "province": p["id"], "size": size, "style": levy_style})
		button.tooltip_text = "%s men from %s: costs %d food, %d materials, %d wealth, and their labour in the fields" % [number(men), str(p["name"]), food, materials, wealth]
		button.disabled = men < 200 or int(stores["food"]) < food or int(stores["wealth"]) < wealth or int(stores["materials"]) < materials
		sizes.add_child(button)
	box.add_child(sizes)
	return box


# --- fleets ------------------------------------------------------------------------------

## A sea: who commands it, its shores, and the fleets on it (D-107).
func _fill_sea_card() -> void:
	_card_body.add_child(_label(str(selected["name"]), 20, GOLD))
	var command: Variant = selected.get("command")
	var who := "No warships sail here."
	if command != null:
		who = "The %s fleet commands it%s." % [_civ_adjective(str(command)), " (yours)" if command == view["player"] else ""]
	_card_body.add_child(_label("Sea · " + who, 13, DIM))
	var shores: Array = []
	for pid in selected.get("shores", []):
		shores.append(str(_find_place(pid).get("name", pid)))
	if shores.size() > 8:
		shores = shores.slice(0, 8) + ["%d more" % (shores.size() - 8)]
	if not shores.is_empty():
		_card_body.add_child(_wrapped("Shores: " + ", ".join(shores), 12, DIM))
	_card_body.add_child(_wrapped("Armies cross a sea only where no stronger enemy fleet holds it.", 12, DIM))
	var here: Array = view.get("fleets", []).filter(func(f): return f["sea"] == selected["id"])
	if not here.is_empty():
		_card_body.add_child(_label("Fleets here", 15, GOLD))
		for fleet in here:
			_card_body.add_child(_fleet_box(fleet))


## One fleet: its colours, ships and doings; orders if yours.
func _fleet_box(fleet: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var mine: bool = fleet["owner"] == view["player"]
	var head := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = civ_colours.get(fleet["owner"], Color.GRAY)
	swatch.custom_minimum_size = Vector2(12, 12)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(swatch)
	var title := "%s · %d %s" % [str(fleet["name"]), int(fleet["ships"]), str(fleet["ship_name"]).to_lower()]
	if not mine:
		title = "%s %s" % [_civ_adjective(str(fleet["owner"])), title]
	var name := _label(title, 14, GOLD if fleet["id"] == selected_fleet else INK)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	box.add_child(head)
	var notes: Array = ["strength %s" % number(int(fleet["power"]))]
	if mine:
		notes.append("costs %d wealth a turn" % int(fleet["upkeep"]))
	if fleet["target"] != null:
		notes.append("sailing for the %s" % str(_find_place(str(fleet["target"])).get("name", fleet["target"])))
	box.add_child(_wrapped(" · ".join(notes), 12, DIM))
	if mine:
		var orders := HBoxContainer.new()
		orders.add_theme_constant_override("separation", 4)
		var go := _button("Sail…", func():
			selected_fleet = str(fleet["id"])
			sailing_fleet = str(fleet["id"])
			message = "Click the sea (or a coastal province) the %s should sail to." % str(fleet["name"])
			armies_changed.emit()
			show_view(view))
		go.add_theme_font_size_override("font_size", 13)
		go.tooltip_text = "Then click a sea: the fleet sails there (two seas a turn) and fights any enemy fleet it meets"
		orders.add_child(go)
		var scrap := _small_button("Lay up", {"kind": "scuttle", "fleet": fleet["id"]})
		scrap.tooltip_text = "Break up the ships: they cost nothing more - but the sea is open to your enemies"
		orders.add_child(scrap)
		box.add_child(orders)
	return box


## Building warships in one of your coastal provinces.
func _shipyard_box(p: Dictionary) -> Control:
	var navy: Dictionary = view["navy"]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label("Build a fleet here", 15, GOLD))
	if navy.get("ship") == null:
		box.add_child(_wrapped("Warships need %s." % str(navy.get("needs", "Sailing")), 12, DIM))
		return box
	var sea := str(_find_place(str(p["port"])).get("name", p["port"]))
	box.add_child(_wrapped("%s: %s They put to sea in the %s." % [str(navy["ship"]), str(navy["note"]), sea], 12, DIM))
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 4)
	var stores: Dictionary = view["status"]["stores"]
	for size in ["small", "medium", "large"]:
		var cost: Dictionary = navy["sizes"][size]
		var button := _small_button("%s %d" % [size.capitalize(), int(cost["ships"])],
			{"kind": "build_fleet", "province": p["id"], "size": size})
		button.tooltip_text = "%d %s: %d materials and %d wealth, then %d wealth a turn" % [int(cost["ships"]),
			str(navy["ship"]).to_lower(), int(cost["materials"]), int(cost["wealth"]), int(cost["upkeep"])]
		button.disabled = int(stores["materials"]) < int(cost["materials"]) or int(stores["wealth"]) < int(cost["wealth"])
		sizes.add_child(button)
	box.add_child(sizes)
	return box


## The sea a coastal province launches into (for a click while choosing where to sail).
func port_of(place_id: String) -> String:
	var port: Variant = _find_place(place_id).get("port")
	return str(port) if port != null else ""


func _relation_of(civ_id: String) -> String:
	for civ in view["civs"]:
		if civ["id"] == civ_id:
			return str(civ.get("relation", ""))
	return ""


func _civ_adjective(civ_id: String) -> String:
	for civ in view["civs"]:
		if civ["id"] == civ_id:
			return str(civ.get("adjective", civ["name"]))
	return civ_id.capitalize()


# --- chronicle and end turn -------------------------------------------------------------

func _build_chronicle() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 380   # beside the province card (speeches hide it while they show)
	panel.offset_right = -470  # clear of the side panel at any window width
	panel.offset_bottom = -8
	panel.offset_top = -8
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chronicle.add_theme_constant_override("separation", 2)
	panel.add_child(_chronicle)
	panel.name = "Chronicle"
	_root.add_child(panel)


func _fill_chronicle() -> void:
	_clear(_chronicle)
	var events: Array = view["events"]
	_chronicle.get_parent().visible = int(view["turn"]) > 1 and _speech == null
	_chronicle.add_child(_label("The last %d years" % int(view["years_per_turn"]), 14, GOLD))
	if events.is_empty():
		_chronicle.add_child(_label("Quiet years: nothing of note happened.", 13, DIM))
		return
	for e in events.slice(0, 6):
		var colour := BAD if e["kind"] in ["riot", "revolt", "famine", "collapse", "setback", "stalled"] else INK
		var line := _wrapped("• " + str(e["message"]), 13, colour)
		line.custom_minimum_size.x = 0  # wrap to the space between card and side panel
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
	_end_turn.tooltip_text = "Let ten years pass (Enter). Tabs: 1 Ideas, 2 Projects, 3 World"
	_root.add_child(_end_turn)
