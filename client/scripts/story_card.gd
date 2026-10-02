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

const INK := UiStyle.INK
const DIM := UiStyle.INK_SOFT

var _shown_result := ""   ## the aftermath already read (so it is not shown twice)
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Show whatever the chronicle has for the player now (or nothing).
func show_chronicle(block: Variant) -> void:
	for child in get_children():
		child.queue_free()
	visible = false
	if block == null:
		return
	if block.get("chapter") != null:
		_chapter(block["chapter"], block)
	elif block.get("result") != null and _key(block["result"]) != _shown_result:
		_aftermath(block["result"])


func is_open() -> bool:
	return visible


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
	column.add_child(UiStyle.label("What will you do?", 16, UiStyle.GOLD_DARK, "body", 800))
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
		pick.pressed.connect(func(): chosen.emit(id, i))
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
		mouse_filter = Control.MOUSE_FILTER_IGNORE)
	column.add_child(go)
