## A short guided tour for a first game of Rome (F1 client): a tip card beside each part of
## the screen, with an arrow pointing at it. Who you are (the unseen hand), the consuls of the
## year, the Senate tab, whispering an idea, the city visit and the end of the turn. Shown
## once (remembered in the player's settings), skippable at any step, and available again
## from Settings.
class_name Tutorial
extends CanvasLayer

signal finished

const SETTINGS := "user://settings.cfg"
## title, text, where the arrow points (in 1600x900 layout units; -1,-1 for none), where the card sits
const STEPS := [
	["The unseen hand", "Rome has no king and never will again. It has two consuls a year, a Senate of great families and a people in arms. You are none of them: you are the whisper in their ear, with one advantage over every Roman alive. You know what comes next.", Vector2(-1, -1), Vector2(540, 290)],
	["The consuls of the year", "The Romans named each year by its two consuls, and so does the top bar. They change every year; the Senate stays. Beside them, Rome's people, stores and temper: food, materials, wealth, knowledge, hands to spare, and how the people feel about it all.", Vector2(400, 56), Vector2(300, 120)],
	["Whisper an idea", "Type anything here - \"concrete that sets under water\", \"pay the legions in coin\", \"an aqueduct\". Rome judges it: within reach, in need of groundwork (with the first steps to begin), or beyond this age. What it accepts becomes a project, and one day a building in the city.", Vector2(1320, 178), Vector2(690, 150)],
	["The Senate", "Nothing great happens without the Senate. This tab shows the year's magistrates, the families and where each leans, and what you can put to a vote with the forecast of how it would go. Spend influence to win a family over, back a man for office, or propose a war, a law, a colony or a work.", Vector2(1527, 125), Vector2(820, 180)],
	["Visit Rome", "The city is real and you can walk it: zoom in from the map or press Visit Rome (V). Every temple stands where it stood in this year; click one to go inside. After each turn, This Year in Rome (R) lists the games, votes, dedications and fires, with a Watch button for each.", Vector2(1455, 46), Vector2(880, 110)],
	["Your cities and your notebook", "Cities (C) is where Rome's towns build granaries, markets and schools. The Notebook (N) is your memory of the future: every idea you could bring, how early it would be, and what it needs first.", Vector2(1160, 855), Vector2(620, 600)],
	["The years pass", "End Turn (Enter) lets the years pass: elections are held, men die and are born, the city holds its games, the legions march. The game saves itself every turn. Tab cycles the panels; Esc opens the menu with the chronicle, charts, the tech tree and your saves.", Vector2(1480, 855), Vector2(880, 600)],
]

var _step := 0
var start_at := 0   ## for screenshots: open the tour at a later step
var _root := Control.new()


static func seen() -> bool:
	var config := ConfigFile.new()
	return config.load(SETTINGS) == OK and bool(config.get_value("tutorial", "seen", false))


static func mark_seen(value: bool) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("tutorial", "seen", value)
	config.save(SETTINGS)


func _ready() -> void:
	layer = 8
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiStyle.theme()
	add_child(_root)
	_step = start_at
	_show()


## Layout units are for a 1600x900 window; other sizes scale the positions.
func _scale() -> Vector2:
	var size := get_viewport().get_visible_rect().size
	return Vector2(size.x / 1600.0, size.y / 900.0)


func _show() -> void:
	for child in _root.get_children():
		child.queue_free()
	if _step >= STEPS.size():
		mark_seen(true)
		finished.emit()
		queue_free()
		return
	var step: Array = STEPS[_step]
	var s := _scale()
	var target: Vector2 = step[2]
	if target.x >= 0:
		target *= s
	var card_at: Vector2 = step[3] * s
	var card_width := 440.0
	card_at.x = clampf(card_at.x, 10.0, get_viewport().get_visible_rect().size.x - card_width - 10.0)
	var arrow := _Arrow.new()
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.to = target
	# the arrow leaves the card from the edge nearest its target
	var card_centre := card_at + Vector2(card_width / 2.0, 90.0)
	arrow.from = card_centre
	if target.x >= 0:
		var toward := (target - card_centre)
		if absf(toward.x) > absf(toward.y):
			arrow.from = card_at + Vector2(card_width if toward.x > 0 else 0.0, 90.0)
		else:
			arrow.from = card_at + Vector2(card_width / 2.0, 180.0 if toward.y > 0 else 0.0)
	_root.add_child(arrow)
	var card := PanelContainer.new()
	card.position = card_at
	card.custom_minimum_size = Vector2(card_width, 0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.add_child(UiStyle.label(str(step[0]), 26, UiStyle.RED, "title", 900))
	body.add_child(UiStyle.wrapped(str(step[1]), 17, UiStyle.INK, card_width - 36.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var skip := UiStyle.big_button("Skip tour", 15, Color(0.85, 0.8, 0.7))
	skip.tooltip_text = "Close the tour; it is in Settings whenever you want it again"
	skip.pressed.connect(func():
		_step = STEPS.size()
		_show())
	row.add_child(skip)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(push)
	row.add_child(UiStyle.label("%d / %d" % [_step + 1, STEPS.size()], 14, UiStyle.INK_SOFT))
	if _step > 0:
		var back := UiStyle.big_button("Back", 15, Color(0.85, 0.8, 0.7))
		back.pressed.connect(func():
			_step -= 1
			_show())
		row.add_child(back)
	var next := UiStyle.big_button("Next" if _step < STEPS.size() - 1 else "Play!", 18)
	next.pressed.connect(func():
		_step += 1
		_show())
	row.add_child(next)
	body.add_child(row)
	card.add_child(body)
	_root.add_child(card)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_step = STEPS.size()
			_show()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_SPACE, KEY_RIGHT]:
			_step += 1
			_show()
			get_viewport().set_input_as_handled()


class _Arrow extends Control:
	var from := Vector2.ZERO
	var to := Vector2(-1, -1)

	func _draw() -> void:
		if to.x < 0:
			return
		var dir := (to - from).normalized()
		var tip := to - dir * 12.0
		draw_line(from, tip, Color(0.96, 0.76, 0.26), 6.0, true)
		draw_line(from, tip, Color(0.4, 0.2, 0.05), 2.0, true)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([to, tip - dir * 14.0 + side * 12.0, tip - dir * 14.0 - side * 12.0]), Color(0.96, 0.76, 0.26))
		draw_arc(to, 26.0, 0, TAU, 32, Color(0.96, 0.76, 0.26), 4.0)
