## The screens before a game: the title screen and the civilisation picker (step 2.9).
##
## The picker works like Rise of Kingdoms: moments in history across the top, a big
## portrait of the chosen civilisation's ruler, its story and strengths, a gold CONFIRM
## button, and every civilisation of that moment as a badge along the bottom.
class_name Menus
extends CanvasLayer

signal start_requested(scenario_id: String, civ_id: String, difficulty: String, chronicle: bool)
signal quit_requested
signal continue_requested   ## resume the autosaved game

var catalog: Array = []        ## real-map scenarios from the engine's "scenarios" command
var scenario: Dictionary = {}
var civ: Dictionary = {}

var _root := Control.new()


func _ready() -> void:
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
	add_child(_root)


var can_continue := false   ## an autosaved game exists
var difficulty := "normal"  ## chosen in the picker; kept while browsing moments
var chronicle := true   ## follow history in chapters (D-120), where the state has them


func show_title() -> void:
	_clear()
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.03, 0.02, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	var title := UiStyle.headline("MERITUS", 96, UiStyle.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var tagline := UiStyle.headline("Guide a civilisation with ideas ahead of their time", 26, UiStyle.CREAM)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	# which build this is, so old downloads can be told from new ones (written by package.sh)
	var stamp := FileAccess.get_file_as_string("res://engine_src/VERSION").strip_edges()
	var version := UiStyle.headline(stamp if stamp != "" else "Development build", 20, Color(0.85, 0.80, 0.70))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(version)
	var gap := Control.new()
	gap.custom_minimum_size.y = 40
	column.add_child(gap)
	var entries := [["NEW GAME", show_disclaimer, UiStyle.GOLD], ["QUIT", func(): quit_requested.emit(), Color(0.85, 0.80, 0.70)]]
	if can_continue:
		entries.push_front(["CONTINUE", func(): continue_requested.emit(), UiStyle.GOLD])
	for entry in entries:
		var button := UiStyle.big_button(entry[0], 30, entry[2])
		button.custom_minimum_size = Vector2(340, 70)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(entry[1])
		column.add_child(button)
	_root.add_child(column)
	var credit := UiStyle.label("Map: Mapzen Terrain Tiles · NASA Blue Marble · Natural Earth   ·   Models: Kenney (CC0)   ·   Heraldry: game-icons.net by Lorc, Delapouite and others (CC BY 3.0)", 13, Color(1, 1, 1, 0.7))
	credit.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	credit.position = Vector2(16, -30)
	credit.offset_top = -30
	credit.offset_left = 16
	_root.add_child(credit)


## Before play (brief §8): this is a good-faith simulation, not a re-enactment.
func show_disclaimer() -> void:
	_clear()
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.03, 0.02, 0.6)
	_root.add_child(shade)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.add_child(UiStyle.label("A word before you begin", 36, UiStyle.RED, "title", 900))
	for text in [
		"Meritus is a good-faith simulation of history, not an exact re-enactment. Its peoples, places and rulers are real, but borders, populations, dates and temperaments are simplified from general sources, and some are informed guesses.",
		"From the moment you start, history is yours to change. The rival states follow what they really intended - until your ideas reach them. What happens after that is invention.",
		"When a language model helps judge your ideas, its words are fiction written for the game; the game's own rules decide what is possible.",
	]:
		column.add_child(UiStyle.wrapped(text, 20, UiStyle.INK, 760))
	var row := HBoxContainer.new()
	var back := UiStyle.big_button("BACK", 20, Color(0.85, 0.80, 0.70))
	back.pressed.connect(show_title)
	row.add_child(back)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(push)
	var go := UiStyle.big_button("I UNDERSTAND", 26)
	go.custom_minimum_size = Vector2(300, 64)
	go.pressed.connect(func(): show_picker())
	row.add_child(go)
	column.add_child(row)
	card.add_child(column)
	_root.add_child(card)


func show_picker(scenario_id := "", civ_id := "") -> void:
	if catalog.is_empty():
		return
	scenario = catalog[0]
	for s in catalog:
		if s["id"] == scenario_id:
			scenario = s
		elif scenario_id == "" and civ_id != "" and s["civs"].any(func(c): return c["id"] == civ_id):
			scenario = s  # the moment this civilisation belongs to
	var wanted := civ_id if civ_id != "" else str(scenario["default_civ"])
	civ = scenario["civs"][0]
	for c in scenario["civs"]:
		if c["id"] == wanted:
			civ = c
	_draw_picker()


func _draw_picker() -> void:
	_clear()
	var colour := Color(civ["colour"])
	var back := ColorRect.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = colour.darkened(0.55)
	_root.add_child(back)
	# moments in history, on a timeline
	var heading := UiStyle.headline("CHOOSE YOUR\nMOMENT", 28, UiStyle.GOLD)
	heading.position = Vector2(36, 8)
	_root.add_child(heading)
	var moments := ScrollContainer.new()
	moments.position = Vector2(300, 2)
	moments.size = Vector2(1290, 120)
	moments.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var timeline := Timeline.new()
	timeline.setup(catalog, str(scenario["id"]))
	timeline.chosen.connect(func(id: String): show_picker(id))
	moments.add_child(timeline)
	_root.add_child(moments)
	# portrait
	var portrait := Portrait.new()
	portrait.position = Vector2(40, 124)
	portrait.size = Vector2(540, 580)
	portrait.setup(civ)
	_root.add_child(portrait)
	# the civilisation's card
	var card := PanelContainer.new()
	card.position = Vector2(620, 124)
	card.custom_minimum_size = Vector2(940, 580)
	card.size = Vector2(940, 580)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	card.add_child(body)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	if str(civ.get("symbol", "")) != "":
		var arms := TextureRect.new()
		arms.texture = Symbols.shield(colour, str(civ["symbol"]), 128)
		arms.custom_minimum_size = Vector2(80, 94)
		arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(arms)
	else:
		var emblem := UiStyle.label(str(civ["emblem"]), 64, colour.darkened(0.3), "emblem")
		head.add_child(emblem)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.add_child(UiStyle.label(str(civ["name"]), 48, UiStyle.INK, "title", 900))
	var ruler := "Ruler: %s" % civ["leader"] if str(civ["leader"]) != "" else "Ruler unrecorded"
	names.add_child(UiStyle.label("%s   ·   Capital: %s" % [ruler, civ["capital"]], 17, UiStyle.INK_SOFT))
	head.add_child(names)
	body.add_child(head)
	var moment := UiStyle.label("%s" % scenario["name"], 20, UiStyle.RED, "title", 800)
	body.add_child(moment)
	body.add_child(UiStyle.wrapped(str(civ["description"]), 16, UiStyle.INK_SOFT, 860))
	if str(civ["pitch"]) != "":
		var pitch_box := PanelContainer.new()
		pitch_box.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PARCHMENT, Color(UiStyle.GOLD_DARK, 0.5), 10))
		var pitch := UiStyle.wrapped(str(civ["pitch"]), 19, UiStyle.INK, 820)
		pitch.add_theme_font_override("font", UiStyle.font("body", 800))
		pitch_box.add_child(pitch)
		body.add_child(pitch_box)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	for entry in [["People", GameHud.people(int(civ["population"]))], ["Provinces", str(int(civ["provinces"]))],
			["Known ideas", str(int(civ["advances"]))], ["Literacy", GameHud.pct(int(civ["literacy_bp"]))]]:
		stats.add_child(_chip(entry[0], entry[1], colour))
	body.add_child(stats)
	var story := UiStyle.wrapped(str(scenario["description"]), 13, UiStyle.INK_SOFT, 860)
	body.add_child(story)
	var chapters := int(civ.get("chronicle", 0))
	if chapters > 0:
		# chronicle mode: live through the real history, chapter by chapter, and try to outdo it
		var ways := HBoxContainer.new()
		ways.add_theme_constant_override("separation", 8)
		for follow in [true, false]:
			var label := ("FOLLOW HISTORY · %d chapters" % chapters) if follow else "FREE PLAY"
			var way := UiStyle.big_button(label, 16, UiStyle.GOLD if chronicle == follow else Color(0.85, 0.80, 0.70))
			way.custom_minimum_size = Vector2(260, 44)
			way.tooltip_text = ("Live through what really happened, chapter by chapter. Your goal is not to win but to outdo history." if follow
				else "The same moment with no chapters: history is only what you and the rivals make it.")
			way.pressed.connect(func():
				chronicle = follow
				_draw_picker())
			ways.add_child(way)
		body.add_child(ways)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(fill)
	var row := HBoxContainer.new()
	var back_button := UiStyle.big_button("BACK", 20, Color(0.85, 0.80, 0.70))
	back_button.pressed.connect(show_title)
	row.add_child(back_button)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(push)
	# difficulty: how bold the rivals are and how forgiving the opening turns
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 6)
	levels.alignment = BoxContainer.ALIGNMENT_CENTER
	var tips := {"easy": "Gentler rivals, slower conquests, five quiet turns to start",
		"normal": "The game as designed", "hard": "Bolder rivals, faster conquests, no grace"}
	for level in ["easy", "normal", "hard"]:
		var chosen: bool = level == difficulty
		var pick := UiStyle.big_button(level.to_upper(), 16, UiStyle.GOLD if chosen else Color(0.85, 0.80, 0.70))
		pick.custom_minimum_size = Vector2(96, 44)
		pick.tooltip_text = tips[level]
		pick.pressed.connect(func():
			difficulty = level
			_draw_picker())
		levels.add_child(pick)
	row.add_child(levels)
	var push2 := Control.new()
	push2.custom_minimum_size.x = 24
	row.add_child(push2)
	var confirm := UiStyle.big_button("CONFIRM", 32)
	confirm.custom_minimum_size = Vector2(300, 72)
	confirm.pressed.connect(func(): start_requested.emit(str(scenario["id"]), str(civ["id"]), difficulty,
		chronicle and int(civ.get("chronicle", 0)) > 0))
	row.add_child(confirm)
	body.add_child(row)
	_root.add_child(card)
	# every civilisation of this moment, as badges
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.08, 0.06, 0.05, 0.85), UiStyle.GOLD_DARK, 12))
	strip.position = Vector2(20, 720)
	strip.size = Vector2(1560, 170)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1520, 150)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 4)
	for c in scenario["civs"]:
		var badge := CivBadge.new()
		badge.setup(c)
		badge.selected = c["id"] == civ["id"]
		badge.chosen.connect(func(id: String): show_picker(str(scenario["id"]), id))
		badges.add_child(badge)
	scroll.add_child(badges)
	strip.add_child(scroll)
	_root.add_child(strip)


func _chip(name: String, value: String, colour: Color) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.panel(colour.lightened(0.55), colour.darkened(0.2), 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -2)
	column.add_child(UiStyle.label(name, 13, UiStyle.INK_SOFT))
	column.add_child(UiStyle.label(value, 24, UiStyle.INK, "body", 900))
	box.add_child(column)
	return box


func _clear() -> void:
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
