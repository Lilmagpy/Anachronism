## Charts over time (brief §5.1: "show trends, not just values"): line charts of the
## player's numbers turn by turn, and every state's population side by side.
class_name Charts
extends Control

var series: Array = []     ## [[name, colour, values: Array]]
var years: Array = []
var title := ""
var percent := false


func setup(chart_title: String, turn_years: Array, lines: Array, as_percent := false) -> void:
	title = chart_title
	years = turn_years
	series = lines
	percent = as_percent
	custom_minimum_size = Vector2(620, 250)
	queue_redraw()


func _draw() -> void:
	var font := UiStyle.font("body", 700)
	var box := Rect2(Vector2(56, 34), size - Vector2(76, 70))
	draw_string(UiStyle.font("title", 800), Vector2(8, 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiStyle.RED)
	draw_rect(box, Color(1, 1, 1, 0.5))
	draw_rect(box, Color(0.5, 0.4, 0.3, 0.5), false, 1.0)
	var top := 1.0
	for line in series:
		for v in line[2]:
			top = maxf(top, float(v))
	top *= 1.1
	for k in 5:
		var y := box.end.y - box.size.y * k / 4.0
		draw_line(Vector2(box.position.x, y), Vector2(box.end.x, y), Color(0.5, 0.4, 0.3, 0.2), 1.0)
		var value := top * k / 4.0
		var text := ("%.0f%%" % (value / 100.0)) if percent else GameHud.people(int(value))
		draw_string(font, Vector2(4, y + 5), text, HORIZONTAL_ALIGNMENT_RIGHT, 48, 11, UiStyle.INK_SOFT)
	var count := years.size()
	if count > 0:
		draw_string(font, Vector2(box.position.x, box.end.y + 18), GameHud.year_text(int(years[0])), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiStyle.INK_SOFT)
		draw_string(font, Vector2(box.end.x - 80, box.end.y + 18), GameHud.year_text(int(years[count - 1])), HORIZONTAL_ALIGNMENT_RIGHT, 80, 12, UiStyle.INK_SOFT)
	var legend_x := 24.0 + UiStyle.font("title", 800).get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	for line in series:
		var values: Array = line[2]
		var points := PackedVector2Array()
		for i in values.size():
			var x := box.position.x + (box.size.x * i / maxf(1.0, values.size() - 1.0))
			var y := box.end.y - box.size.y * float(values[i]) / top
			points.append(Vector2(x, y))
		if points.size() == 1:
			draw_circle(points[0], 4, line[1])
		elif points.size() > 1:
			draw_polyline(points, line[1], 3.0, true)
		draw_rect(Rect2(legend_x, 12, 12, 12), line[1])
		draw_string(font, Vector2(legend_x + 16, 23), str(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.INK)
		legend_x += 26 + font.get_string_size(str(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14
