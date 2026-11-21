## Chronicle mode (D-120): the storybook card for a chapter of history, and its aftermath.
##
## A chapter: the year and place, who brings the moment (with a portrait), the scene in a
## few paragraphs, and the choices - each with what it will do; choices that need an idea
## the player has not brought in are shown locked, marked as anachronisms. Once chosen, the
## aftermath: what followed, what really happened, whether history chose the same, and how
## the player's state stands against the real one. The game waits while a chapter is open.
class_name StoryCard
extends Control

signal chosen(chapter_id: String, index: int)
signal _reopen   ## redraw from the last chronicle block (after folding or unfolding)

const INK := UiStyle.INK
const DIM := UiStyle.INK_SOFT

var _shown_result := ""   ## the aftermath already read (so it is not shown twice)
var _folded := ""   ## a chapter folded away while the player looks at the map first
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Show whatever the chronicle has for the player now (or nothing).
var _last_block: Variant = null


func _ready_reopen() -> void:
	if not _reopen.is_connected(_redraw):
		_reopen.connect(_redraw)


func _redraw() -> void:
	show_chronicle(_last_block)


func show_chronicle(block: Variant) -> void:
	_ready_reopen()
	_last_block = block
	for child in get_children():
		child.queue_free()
	visible = false
	if block == null:
		return
	# what followed the last choice comes first; a chapter of the same year waits behind it
	if block.get("result") != null and _key(block["result"]) != _shown_result:
		_aftermath(block["result"])
	elif block.get("chapter") != null:
		if str(block["chapter"]["id"]) == _folded:
			_banner(block["chapter"])
		else:
			_chapter(block["chapter"], block)


func is_open() -> bool:
	return visible and _folded == ""


## The chapter waits as a banner at the top while the player looks around the map, reads
## the panels and checks their armies; one click brings the decision back.
func _banner(chapter: Dictionary) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # the map and panels stay usable
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	holder.offset_top = 92
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.ornate_panel())
	holder.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.add_child(UiStyle.label("A DECISION AWAITS  ·  %s" % str(chapter["year"]), 13, UiStyle.GOLD_DARK, "body", 800))
	words.add_child(UiStyle.label(str(chapter["title"]), 22, UiStyle.RED, "title", 900))
	row.add_child(words)
	var back := UiStyle.big_button("DECIDE  ▸", 18)
	back.custom_minimum_size = Vector2(150, 44)
	back.pressed.connect(func():
		_folded = ""
		_reopen.emit())
	row.add_child(back)


## Fold the chapter away to look at the map first.
func _fold(chapter_id: String) -> void:
	_folded = chapter_id
	_reopen.emit()


func _key(result: Dictionary) -> String:
	return "%s|%s" % [result["title"], result["chose"]]


func _frame(width: float) -> VBoxContainer:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.03, 0.02, 0.62)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.ornate_panel())
	_panel.custom_minimum_size = Vector2(width, 0)
	centre.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	# fade in
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	return column


func _chapter(chapter: Dictionary, block: Dictionary) -> void:
	var column := _frame(1040)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	# who brings the moment
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 4)
	var speaker: Dictionary = chapter["speaker"]
	var portrait := Portrait.new()
	portrait.custom_minimum_size = Vector2(200, 250)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.setup({"colour": speaker["colour"], "portrait": speaker["portrait"],
		"culture": speaker.get("culture", ""), "id": "%s_%s" % [speaker["civ"], speaker["name"]]})
	who.add_child(portrait)
	var name := UiStyle.label(str(speaker["name"]), 16, INK, "body", 800)
	name.custom_minimum_size.x = 200
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.add_child(name)
	who.add_child(UiStyle.label(str(speaker["title"]), 13, DIM))
	row.add_child(who)
	# the scene
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 8)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var where := "CHAPTER %d OF %d  ·  %s%s" % [int(block["done"]) + int(block["passed"]) + 1, int(block["total"]),
		str(chapter["year"]), ("  ·  " + str(chapter["place"])) if str(chapter["place"]) != "" else ""]
	text.add_child(UiStyle.label(where, 14, UiStyle.GOLD_DARK, "body", 800))
	text.add_child(UiStyle.label(str(chapter["title"]), 38, UiStyle.RED, "title", 900))
	for paragraph in chapter["story"]:
		text.add_child(UiStyle.wrapped(str(paragraph), 17, INK, 760))
	column.add_child(HSeparator.new())
	var ask := HBoxContainer.new()
	ask.add_child(UiStyle.label("What will you do?", 16, UiStyle.GOLD_DARK, "body", 800))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ask.add_child(gap)
	var look := UiStyle.big_button("Look at the map first  ▾", 15, Color(0.85, 0.80, 0.70))
	look.tooltip_text = "Fold this away to study the map, your armies and your rivals; it waits at the top of the screen"
	var chapter_id := str(chapter["id"])
	look.pressed.connect(func(): _fold(chapter_id))
	ask.add_child(look)
	column.add_child(ask)
	for i in chapter["choices"].size():
		var choice: Dictionary = chapter["choices"][i]
		var locked := str(choice["locked"]) != ""
		var option := VBoxContainer.new()
		option.add_theme_constant_override("separation", 1)
		var label := str(choice["label"])
		if bool(choice["anachronism"]):
			label = "✦ " + label
		var pick := UiStyle.big_button(label, 18, UiStyle.GOLD if not locked else Color(0.82, 0.78, 0.70))
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.disabled = locked
		var id := str(chapter["id"])
		var index := int(choice.get("index", i))  # listed shuffled (D-265); act on the real one
		pick.pressed.connect(func(): chosen.emit(id, index))
		option.add_child(pick)
		var hint := str(choice["hint"])
		if locked:
			hint = "An idea ahead of its time - " + str(choice["locked"]) + " in use. " + hint
		elif bool(choice["anachronism"]):
			hint = "Possible only because of an idea you brought in. " + hint
		option.add_child(UiStyle.wrapped("   " + hint, 13, DIM, 980))
		column.add_child(option)


func _aftermath(result: Dictionary) -> void:
	var column := _frame(900)
	column.add_child(UiStyle.label("%s  ·  %s" % [str(result["year"]), str(result["title"])], 15, UiStyle.GOLD_DARK, "body", 800))
	column.add_child(UiStyle.label("You chose: " + str(result["chose"]), 22, UiStyle.RED, "title", 800))
	column.add_child(UiStyle.wrapped(str(result["outcome"]), 17, INK, 860))
	column.add_child(HSeparator.new())
	column.add_child(UiStyle.label("WHAT REALLY HAPPENED", 18, UiStyle.GOLD_DARK, "title", 900))
	if str(result["history"]) != "":
		column.add_child(UiStyle.wrapped(str(result["history"]), 16, INK, 860))
	var same := "You chose as history did." if bool(result["historical"]) else "History chose otherwise: %s." % str(result["history_chose"])
	column.add_child(UiStyle.label(same, 15, DIM, "body", 700))
	if str(result["benchmark"]) != "":
		var mark := str(result["benchmark"])
		var colour := Color(0.2, 0.5, 0.2) if "ahead" in mark else (UiStyle.RED if "behind" in mark else INK)
		column.add_child(UiStyle.wrapped(mark, 17, colour, 860))
	var go := UiStyle.big_button("CONTINUE", 22)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size = Vector2(240, 54)
	var key := _key(result)
	go.pressed.connect(func():
		_shown_result = key
		for child in get_children():
			child.queue_free()
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reopen.emit())   # the next chapter of the year, if one is waiting
	column.add_child(go)
