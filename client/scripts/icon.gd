## Small painted icons for the game's screens (food, wealth, knowledge…), drawn in code so
## they scale crisply at any window size. `kind` picks the picture.
class_name GameIcon
extends Control

var kind := "food"
var tint := Color(0, 0, 0, 0)  ## optional override of the main colour


static func make(icon_kind: String, pixels := 26.0) -> GameIcon:
	var icon := GameIcon.new()
	icon.kind = icon_kind
	icon.custom_minimum_size = Vector2(pixels, pixels)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var ink := Color(0.25, 0.16, 0.08)
	match kind:
		"people":
			for i in 3:
				var x := c.x + (i - 1) * s * 0.26
				var col: Color = [Color(0.35, 0.55, 0.85), Color(0.85, 0.45, 0.3), Color(0.45, 0.7, 0.4)][i]
				draw_circle(Vector2(x, c.y - s * 0.12), s * 0.13, Color(0.93, 0.76, 0.6))
				draw_rect(Rect2(x - s * 0.13, c.y + s * 0.04, s * 0.26, s * 0.32), col)
		"food":
			draw_line(Vector2(c.x, c.y + s * 0.42), Vector2(c.x, c.y - s * 0.3), Color(0.6, 0.45, 0.15), s * 0.07)
			for i in 4:
				for side in [-1, 1]:
					var at: Vector2 = Vector2(c.x + side * s * 0.1, c.y - s * 0.28 + i * s * 0.15)
					_ellipse(at, Vector2(s * 0.08, s * 0.12), Color(0.95, 0.75, 0.25))
			_ellipse(Vector2(c.x, c.y - s * 0.4), Vector2(s * 0.06, s * 0.1), Color(0.95, 0.75, 0.25))
		"materials":
			for b in [[-0.3, 0.05], [0.02, 0.05], [-0.15, -0.25]]:
				draw_rect(Rect2(c.x + b[0] * s, c.y + b[1] * s, s * 0.3, s * 0.28), Color(0.62, 0.58, 0.54))
				draw_rect(Rect2(c.x + b[0] * s, c.y + b[1] * s, s * 0.3, s * 0.28), ink, false, 1.5)
			draw_rect(Rect2(c.x + s * 0.12, c.y - s * 0.32, s * 0.28, s * 0.12), Color(0.55, 0.35, 0.2))
		"wealth":
			draw_circle(c + Vector2(s * 0.08, s * 0.08), s * 0.34, Color(0.75, 0.55, 0.1))
			draw_circle(c - Vector2(s * 0.06, s * 0.06), s * 0.34, Color(0.98, 0.8, 0.25))
			draw_arc(c - Vector2(s * 0.06, s * 0.06), s * 0.24, 0, TAU, 20, Color(0.8, 0.6, 0.15), 1.5)
			draw_rect(Rect2(c.x - s * 0.12, c.y - s * 0.18, s * 0.12, s * 0.12), Color(0.8, 0.6, 0.15), false, 1.5)
		"knowledge":
			draw_rect(Rect2(c.x - s * 0.32, c.y - s * 0.22, s * 0.64, s * 0.46), Color(0.96, 0.9, 0.72))
			draw_circle(Vector2(c.x - s * 0.32, c.y), s * 0.12, Color(0.6, 0.4, 0.2))
			draw_circle(Vector2(c.x + s * 0.32, c.y), s * 0.12, Color(0.6, 0.4, 0.2))
			for i in 3:
				draw_line(Vector2(c.x - s * 0.2, c.y - s * 0.1 + i * s * 0.1), Vector2(c.x + s * 0.2, c.y - s * 0.1 + i * s * 0.1), ink, 1.2)
		"labour":
			draw_line(c + Vector2(-s * 0.3, s * 0.35), c + Vector2(s * 0.15, -s * 0.1), Color(0.55, 0.35, 0.2), s * 0.1)
			draw_rect(Rect2(c.x + s * 0.02, c.y - s * 0.38, s * 0.34, s * 0.2), Color(0.55, 0.57, 0.6))
		"literacy":
			draw_colored_polygon([c + Vector2(s * 0.3, -s * 0.4), c + Vector2(s * 0.1, s * 0.05), c + Vector2(-s * 0.25, s * 0.38), c + Vector2(-s * 0.05, s * 0.0)], Color(0.95, 0.95, 0.9))
			draw_line(c + Vector2(-s * 0.25, s * 0.38), c + Vector2(s * 0.3, -s * 0.4), ink, 1.5)
		"unrest":
			draw_colored_polygon([c + Vector2(0, -s * 0.42), c + Vector2(s * 0.3, s * 0.1), c + Vector2(s * 0.12, s * 0.4), c + Vector2(-s * 0.12, s * 0.4), c + Vector2(-s * 0.3, s * 0.1)], Color(0.9, 0.35, 0.15))
			draw_colored_polygon([c + Vector2(0, -s * 0.1), c + Vector2(s * 0.14, s * 0.2), c + Vector2(0, s * 0.38), c + Vector2(-s * 0.14, s * 0.2)], Color(0.98, 0.8, 0.3))
		"legitimacy":
			var gold := Color(0.98, 0.78, 0.25)
			draw_rect(Rect2(c.x - s * 0.34, c.y, s * 0.68, s * 0.22), gold)
			for i in 3:
				var x := c.x - s * 0.3 + i * s * 0.3
				draw_colored_polygon([Vector2(x - s * 0.1, c.y), Vector2(x + s * 0.1, c.y), Vector2(x, c.y - s * 0.34)], gold)
			draw_circle(Vector2(c.x, c.y + s * 0.11), s * 0.06, Color(0.8, 0.15, 0.15))
		"suspicion":
			_ellipse(c, Vector2(s * 0.42, s * 0.24), Color(0.97, 0.95, 0.9))
			draw_circle(c, s * 0.17, Color(0.3, 0.5, 0.75))
			draw_circle(c, s * 0.08, ink)
		"strain":
			draw_arc(c, s * 0.36, PI * 0.8, PI * 2.2, 20, Color(0.8, 0.3, 0.2), s * 0.12)
		"ideas":
			draw_circle(c + Vector2(0, -s * 0.08), s * 0.3, Color(1.0, 0.88, 0.35))
			draw_rect(Rect2(c.x - s * 0.13, c.y + s * 0.18, s * 0.26, s * 0.18), Color(0.55, 0.55, 0.6))
		"projects":
			draw_rect(Rect2(c.x - s * 0.35, c.y - s * 0.1, s * 0.7, s * 0.2), Color(0.82, 0.76, 0.64))
			draw_rect(Rect2(c.x - s * 0.35, c.y - s * 0.1, s * 0.45, s * 0.2), Color(0.98, 0.78, 0.25))
			draw_rect(Rect2(c.x - s * 0.35, c.y - s * 0.1, s * 0.7, s * 0.2), ink, false, 1.5)
		"world":
			draw_circle(c, s * 0.38, Color(0.3, 0.55, 0.85))
			_ellipse(c + Vector2(-s * 0.1, -s * 0.05), Vector2(s * 0.14, s * 0.2), Color(0.45, 0.72, 0.35))
			_ellipse(c + Vector2(s * 0.16, s * 0.12), Vector2(s * 0.1, s * 0.12), Color(0.45, 0.72, 0.35))
		"tree":
			for p in [[0, -0.3], [-0.25, 0.05], [0.25, 0.05], [0, 0.35]]:
				draw_line(c + Vector2(0, -s * 0.3), c + Vector2(p[0] * s, p[1] * s), ink, 1.5)
			for p in [[0, -0.3], [-0.25, 0.05], [0.25, 0.05], [0, 0.35]]:
				draw_circle(c + Vector2(p[0] * s, p[1] * s), s * 0.11, Color(0.45, 0.65, 0.35))
		"chronicle":
			draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.38, s * 0.6, s * 0.76), Color(0.7, 0.3, 0.2))
			draw_rect(Rect2(c.x - s * 0.22, c.y - s * 0.3, s * 0.44, s * 0.6), Color(0.96, 0.9, 0.72))
		"army":
			draw_line(c + Vector2(-s * 0.3, s * 0.35), c + Vector2(s * 0.3, -s * 0.35), Color(0.7, 0.72, 0.75), s * 0.09)
			draw_line(c + Vector2(s * 0.3, s * 0.35), c + Vector2(-s * 0.3, -s * 0.35), Color(0.7, 0.72, 0.75), s * 0.09)
			draw_line(c + Vector2(-s * 0.18, s * 0.1), c + Vector2(-s * 0.05, s * 0.23), Color(0.55, 0.35, 0.2), s * 0.12)
		"menu":
			for i in 3:
				draw_rect(Rect2(c.x - s * 0.32, c.y - s * 0.28 + i * s * 0.24, s * 0.64, s * 0.1), ink)
		_:
			draw_circle(c, s * 0.3, Color(0.7, 0.7, 0.7))


func _ellipse(centre: Vector2, radius: Vector2, fill: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, fill)
