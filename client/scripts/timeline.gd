## The timeline of starting moments (brief §8): history as a line from the oldest moment to
## the newest, with a medallion for each moment. The eras are painted behind it. Click a
## medallion to choose that moment; scroll sideways when there are many.
class_name Timeline
extends Control

signal chosen(scenario_id: String)

const ERAS := [
	[-3000, -1200, "Bronze Age", Color(0.80, 0.55, 0.30)],
	[-1200, 500, "Classical", Color(0.55, 0.62, 0.40)],
	[500, 1500, "Medieval", Color(0.45, 0.50, 0.70)],
	[1500, 1800, "Early modern", Color(0.65, 0.45, 0.60)],
]
const MAX_STEP := 250.0
const MIN_STEP := 160.0   ## below this the timeline scrolls sideways

var moments: Array = []
var current := ""
var _hover := -1
var step := MAX_STEP   ## room per moment: as much as fits, so every moment shows at once


func setup(scenarios: Array, selected: String, width := 1290.0) -> void:
	moments = scenarios
	current = selected
	step = clampf(width / maxf(moments.size(), 1.0), MIN_STEP, MAX_STEP)
	custom_minimum_size = Vector2(maxf(width, step * moments.size()), 118)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _point(i: int) -> Vector2:
	return Vector2(step / 2.0 + i * step, 64)


func _draw() -> void:
	var title := UiStyle.font("title", 800)
	var body := UiStyle.font("body", 700)
	# era bands: each moment sits in the era its year belongs to
	for i in moments.size():
		var year := int(moments[i]["start_year"])
		for era in ERAS:
			if year >= era[0] and year < era[1]:
				var band := Rect2(_point(i).x - step / 2.0, 18, step, 88)
				draw_rect(band, Color(era[3], 0.35))
				draw_string(body, Vector2(band.position.x + 6, 13), str(era[2]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, step - 12, 11, Color(1, 1, 1, 0.75))
	if moments.size() > 1:
		draw_line(_point(0), _point(moments.size() - 1), UiStyle.GOLD, 5.0)
	for i in moments.size():
		var at := _point(i)
		var chosen_now: bool = moments[i]["id"] == current
		var radius := 17.0 if chosen_now else 12.0
		draw_circle(at, radius + 4, UiStyle.GOLD_DARK)
		draw_circle(at, radius, UiStyle.GOLD if chosen_now or i == _hover else UiStyle.CREAM)
		var year_text := GameHud.year_text(int(moments[i]["start_year"]))
		draw_string(title, at + Vector2(-step / 2.0, -22), year_text, HORIZONTAL_ALIGNMENT_CENTER, step, 20, UiStyle.GOLD if chosen_now else UiStyle.CREAM)
		var name := str(moments[i]["name"]).split(",")[0]
		var size := 15
		while size > 11 and body.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > step - 10:
			size -= 1
		draw_string(body, at + Vector2(-step / 2.0 + 5, 38), name, HORIZONTAL_ALIGNMENT_CENTER, step - 10, size, UiStyle.CREAM if chosen_now else Color(0.9, 0.85, 0.75))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _hover
		_hover = _at(event.position)
		if was != _hover:
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := _at(event.position)
		if index >= 0:
			chosen.emit(str(moments[index]["id"]))


func _at(position: Vector2) -> int:
	for i in moments.size():
		if position.distance_to(_point(i)) < 60.0:
			return i
	return -1
