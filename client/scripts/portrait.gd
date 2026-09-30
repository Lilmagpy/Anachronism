## A placeholder portrait painted in code (D-060): a cartoon bust in the civilisation's
## colours, with headwear by its portrait style. Real portrait images can replace it later:
## if res://portraits/<civ_id>.png exists it is shown instead.
class_name Portrait
extends Control

const SKIN := Color(0.93, 0.76, 0.60)
const SKIN_SHADE := Color(0.80, 0.60, 0.45)
const HAIR := Color(0.12, 0.09, 0.08)
const BRONZE := Color(0.72, 0.52, 0.24)

var colour := Color(0.5, 0.3, 0.2)
var style := "court"
var civ_id := ""
var _image: Texture2D


func _ready() -> void:
	clip_contents = true  # the backdrop's sun rays stay inside the frame


func setup(civ: Dictionary) -> void:
	colour = Color(civ["colour"])
	style = str(civ.get("portrait", "court"))
	civ_id = str(civ["id"])
	var path := "res://portraits/%s.png" % civ_id
	_image = load(path) if ResourceLoader.exists(path) else null
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if _image != null:
		draw_texture_rect(_image, Rect2(Vector2.ZERO, size), false)
		return
	_backdrop(w, h)
	var cx := w * 0.5
	var head := Vector2(cx, h * 0.42)
	var r := w * 0.15
	_robe(w, h, cx)
	var skin := _skin()
	# neck
	draw_rect(Rect2(cx - r * 0.38, head.y + r * 0.8, r * 0.76, r * 0.9), skin.darkened(0.15))
	if style in ["steppe", "celtic"]:
		_ellipse(head + Vector2(0, r * 0.2 if style == "celtic" else -r * 0.1), Vector2(r * 1.15, r * (1.25 if style == "celtic" else 1.05)), _hair())
	_ellipse(head, Vector2(r * 0.92, r * 1.12), skin)
	_ellipse(head + Vector2(r * 0.25, r * 0.25), Vector2(r * 0.55, r * 0.7), Color(skin.darkened(0.15), 0.35))
	_face(head, r)
	match style:
		"steppe":
			_fur_hat(head, r)
		"southern":
			_topknot(head, r)
		"hills":
			_helmet(head, r)
		"scholar":
			_scholar_cap(head, r)
		"steward":
			_steward_cap(head, r)
		"general":
			_general(head, r, w, h)
		"diviner":
			_diviner(head, r, w, h)
		"roman":
			_laurel(head, r)
		"greek":
			_greek_helmet(head, r)
		"hellenistic":
			_diadem(head, r)
		"punic":
			_punic_cap(head, r)
		"pharaoh":
			_nemes(head, r)
		"berber":
			_headscarf(head, r)
		"celtic":
			_celtic(head, r, w, h)
		"kushite":
			_kushite_cap(head, r)
		"hittite":
			_hittite_cap(head, r)
		"assyrian":
			_assyrian(head, r)
		"medieval_king":
			_medieval_crown(head, r, w, h)
		"viking":
			_viking(head, r)
		"bishop":
			_mitre(head, r)
		"byzantine":
			_byzantine(head, r)
		"turban":
			_turban(head, r)
		"doge":
			_doge(head, r)
		"rus":
			_rus_cap(head, r)
		_:
			_crown(head, r)
	# frame
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.GOLD_DARK, false, 6.0)
	draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), UiStyle.GOLD, false, 3.0)


func _backdrop(w: float, h: float) -> void:
	var top := colour.lightened(0.45)
	var bottom := colour.darkened(0.2)
	draw_polygon([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)], [top, top, bottom, bottom])
	# sun rays behind the head
	var centre := Vector2(w * 0.5, h * 0.38)
	for i in 16:
		var a := TAU * i / 16.0
		var b := a + TAU / 32.0
		var far := w * 1.2
		draw_colored_polygon([centre, centre + Vector2(cos(a), sin(a)) * far, centre + Vector2(cos(b), sin(b)) * far],
			Color(1, 1, 0.9, 0.10))
	draw_circle(centre, w * 0.3, Color(1, 0.97, 0.85, 0.18))


func _robe(w: float, h: float, cx: float) -> void:
	var robe := colour.darkened(0.2)
	var shade := colour.darkened(0.45)
	var top := h * 0.62
	# shoulders: a rounded mound
	var pts := PackedVector2Array()
	for i in 21:
		var t := i / 20.0
		var x := lerpf(cx - w * 0.46, cx + w * 0.46, t)
		var y := top + h * 0.08 * pow(absf(t - 0.5) * 2.0, 2.0) - h * 0.02
		pts.append(Vector2(x, y))
	pts.append(Vector2(cx + w * 0.48, h))
	pts.append(Vector2(cx - w * 0.48, h))
	draw_colored_polygon(pts, robe)
	# folds
	for side in [-1, 1]:
		draw_line(Vector2(cx + side * w * 0.30, top + h * 0.10), Vector2(cx + side * w * 0.36, h), shade, w * 0.012)
	var neck := Vector2(cx, top - h * 0.01)
	# white under-collar, then the two lapels (right over left, as in Chinese dress)
	draw_colored_polygon([neck + Vector2(-w * 0.09, 0), neck + Vector2(w * 0.09, 0), neck + Vector2(0, h * 0.16)], Color(0.95, 0.93, 0.88))
	var band := w * 0.05
	var trim := UiStyle.GOLD if style != "steppe" else Color(0.62, 0.48, 0.32)
	var left_lapel := PackedVector2Array([neck + Vector2(-w * 0.10, 0), neck + Vector2(-w * 0.10 + band, 0),
		neck + Vector2(w * 0.12, h * 0.30), neck + Vector2(w * 0.12 - band, h * 0.32)])
	var right_lapel := PackedVector2Array([neck + Vector2(w * 0.10, 0), neck + Vector2(w * 0.10 - band, 0),
		neck + Vector2(-w * 0.02, h * 0.17), neck + Vector2(w * 0.02, h * 0.19)])
	draw_colored_polygon(right_lapel, trim.darkened(0.15))
	draw_colored_polygon(left_lapel, trim)
	if style == "steppe":  # fur collar
		for i in 11:
			draw_circle(neck + Vector2(-w * 0.25 + i * w * 0.05, h * 0.0), w * 0.04, Color(0.68, 0.54, 0.38))
	# belt
	draw_rect(Rect2(cx - w * 0.40, h * 0.92, w * 0.80, h * 0.035), shade)
	draw_rect(Rect2(cx - w * 0.03, h * 0.915, w * 0.06, h * 0.045), UiStyle.GOLD)


func _face(head: Vector2, r: float) -> void:
	for side in [-1, 1]:
		var eye: Vector2 = head + Vector2(side * r * 0.36, -r * 0.05)
		_ellipse(eye, Vector2(r * 0.13, r * 0.08), Color.WHITE)
		draw_circle(eye + Vector2(side * r * 0.02, 0), r * 0.06, HAIR)
		draw_line(eye + Vector2(-r * 0.18, -r * 0.2), eye + Vector2(r * 0.18, -r * 0.24 + side * r * 0.03), HAIR, r * 0.07)
	draw_line(head + Vector2(0, r * 0.05), head + Vector2(r * 0.06, r * 0.3), SKIN_SHADE, r * 0.06)
	# moustache and beard (Romans and Hellenistic kings shaved; Celts wore only moustaches)
	if style in ["roman", "hellenistic", "kushite", "hittite"]:
		draw_line(head + Vector2(-r * 0.2, r * 0.52), head + Vector2(r * 0.2, r * 0.52), Color(0.5, 0.2, 0.15), r * 0.06)
	elif style == "celtic":
		draw_polyline([head + Vector2(-r * 0.6, r * 0.85), head + Vector2(-r * 0.25, r * 0.45),
			head + Vector2(r * 0.25, r * 0.45), head + Vector2(r * 0.6, r * 0.85)], Color(0.62, 0.36, 0.16), r * 0.16)
	elif style == "assyrian":
		pass  # the square curled beard is drawn with the crown
	elif style == "pharaoh":
		draw_rect(Rect2(head.x - r * 0.1, head.y + r * 0.75, r * 0.2, r * 0.55), Color(0.2, 0.15, 0.1))
	elif style != "southern":
		draw_polyline([head + Vector2(-r * 0.4, r * 0.55), head + Vector2(-r * 0.1, r * 0.42),
			head + Vector2(r * 0.1, r * 0.42), head + Vector2(r * 0.4, r * 0.55)], HAIR, r * 0.08)
		var beard: float = {"court": 1.35, "scholar": 1.9, "diviner": 1.6, "general": 1.0,
			"viking": 1.8, "byzantine": 1.5, "turban": 1.5, "rus": 1.6, "bishop": 1.2}.get(style, 1.1)
		var beard_colour: Color = Color(0.85, 0.85, 0.82) if style in ["scholar", "diviner", "bishop"] else HAIR
		if style == "viking":
			beard_colour = Color(0.72, 0.45, 0.2)
		draw_colored_polygon([head + Vector2(-r * 0.14, r * 0.7), head + Vector2(r * 0.14, r * 0.7),
			head + Vector2(0, r * beard)], beard_colour)
	else:
		draw_line(head + Vector2(-r * 0.2, r * 0.5), head + Vector2(r * 0.2, r * 0.5), Color(0.55, 0.2, 0.15), r * 0.06)
	# hair at the temples
	if style != "pharaoh":
		for side in [-1, 1]:
			_ellipse(head + Vector2(side * r * 0.85, -r * 0.2), Vector2(r * 0.18, r * 0.5), _hair())


## Mianguan: the flat-topped crown with bead tassels worn by Zhou-world rulers.
func _crown(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.62), Vector2(r * 0.96, r * 0.62), HAIR)
	# the cap (topknot cover) and its hairpin
	var cap := Rect2(head.x - r * 0.42, head.y - r * 1.45, r * 0.84, r * 0.62)
	draw_rect(cap, Color(0.10, 0.08, 0.08))
	draw_line(Vector2(cap.position.x - r * 0.35, cap.position.y + r * 0.35), Vector2(cap.end.x + r * 0.35, cap.position.y + r * 0.35), UiStyle.GOLD, r * 0.07)
	# the board, tilted slightly forward, black above and red beneath
	var board := PackedVector2Array([Vector2(head.x - r * 1.35, head.y - r * 1.52), Vector2(head.x + r * 1.35, head.y - r * 1.52),
		Vector2(head.x + r * 1.45, head.y - r * 1.36), Vector2(head.x - r * 1.45, head.y - r * 1.36)])
	draw_colored_polygon(board, Color(0.08, 0.07, 0.07))
	draw_line(board[3], board[2], Color(0.70, 0.16, 0.12), r * 0.06)
	# bead strings hanging from the front edge
	for i in 7:
		var x := head.x - r * 1.3 + i * r * 2.6 / 6.0
		if absf(x - head.x) < r * 0.5:
			continue  # keep the face clear
		for k in 4:
			draw_circle(Vector2(x, head.y - r * 1.25 + k * r * 0.16), r * 0.05, [UiStyle.GOLD, Color(0.85, 0.25, 0.18), Color(0.25, 0.6, 0.4), Color(0.95, 0.95, 0.9)][k])


func _fur_hat(head: Vector2, r: float) -> void:
	draw_colored_polygon([head + Vector2(-r * 0.95, -r * 0.55), head + Vector2(r * 0.95, -r * 0.55),
		head + Vector2(r * 0.15, -r * 2.1), head + Vector2(-r * 0.25, -r * 1.9)], colour.darkened(0.1))
	for side in [-1, 1]:
		draw_colored_polygon([head + Vector2(side * r * 0.95, -r * 0.6), head + Vector2(side * r * 1.2, r * 0.4),
			head + Vector2(side * r * 0.75, r * 0.3)], Color(0.62, 0.48, 0.32))
	draw_rect(Rect2(head.x - r * 1.05, head.y - r * 0.85, r * 2.1, r * 0.4), Color(0.62, 0.48, 0.32))
	for i in 8:
		draw_circle(Vector2(head.x - r * 0.95 + i * r * 0.27, head.y - r * 0.85), r * 0.13, Color(0.68, 0.54, 0.38))


func _topknot(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.7), Vector2(r * 0.97, r * 0.6), HAIR)
	draw_circle(head + Vector2(r * 0.1, -r * 1.45), r * 0.42, HAIR)
	draw_line(head + Vector2(-r * 0.6, -r * 1.7), head + Vector2(r * 0.9, -r * 1.25), UiStyle.GOLD, r * 0.09)
	draw_rect(Rect2(head.x - r * 0.95, head.y - r * 0.72, r * 1.9, r * 0.18), Color(0.75, 0.15, 0.12))
	# a phoenix feather for Chu and Yue
	draw_colored_polygon([head + Vector2(r * 0.4, -r * 1.6), head + Vector2(r * 1.4, -r * 2.6),
		head + Vector2(r * 0.7, -r * 1.5)], Color(0.2, 0.55, 0.45))


func _helmet(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.55), Vector2(r * 1.05, r * 0.85), BRONZE)
	draw_rect(Rect2(head.x - r * 1.05, head.y - r * 0.6, r * 2.1, r * 0.22), BRONZE.darkened(0.25))
	draw_colored_polygon([head + Vector2(-r * 0.12, -r * 1.35), head + Vector2(r * 0.12, -r * 1.35),
		head + Vector2(0, -r * 2.0)], colour.lightened(0.1))
	for side in [-1, 1]:
		draw_colored_polygon([head + Vector2(side * r * 1.0, -r * 0.45), head + Vector2(side * r * 1.08, r * 0.45),
			head + Vector2(side * r * 0.72, r * 0.3), head + Vector2(side * r * 0.8, -r * 0.4)], BRONZE.darkened(0.1))
	for i in 5:
		draw_circle(Vector2(head.x - r * 0.7 + i * r * 0.35, head.y - r * 0.5), r * 0.06, UiStyle.GOLD)


## A soft black scholar's cap with two ribbons, like the later futou.
func _scholar_cap(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.62), Vector2(r * 0.96, r * 0.62), Color(0.85, 0.85, 0.82))
	_ellipse(head + Vector2(0, -r * 0.95), Vector2(r * 0.85, r * 0.55), Color(0.12, 0.1, 0.1))
	for side in [-1, 1]:
		draw_line(head + Vector2(side * r * 0.6, -r * 0.9), head + Vector2(side * r * 1.5, -r * 0.4), Color(0.12, 0.1, 0.1), r * 0.12)


func _steward_cap(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.62), Vector2(r * 0.96, r * 0.62), HAIR)
	draw_rect(Rect2(head.x - r * 0.75, head.y - r * 1.3, r * 1.5, r * 0.6), Color(0.15, 0.12, 0.1))
	draw_rect(Rect2(head.x - r * 0.75, head.y - r * 0.85, r * 1.5, r * 0.14), Color(0.7, 0.18, 0.12))
	# a scroll of accounts
	var at := head + Vector2(r * 1.2, r * 3.2)
	draw_rect(Rect2(at, Vector2(r * 1.4, r * 0.5)), Color(0.93, 0.87, 0.72))
	draw_circle(at + Vector2(0, r * 0.25), r * 0.28, Color(0.55, 0.35, 0.2))
	draw_circle(at + Vector2(r * 1.4, r * 0.25), r * 0.28, Color(0.55, 0.35, 0.2))


func _general(head: Vector2, r: float, w: float, h: float) -> void:
	_helmet(head, r)
	# red horsehair plume
	for i in 5:
		draw_line(head + Vector2(0, -r * 1.9), head + Vector2(-r * 0.6 + i * r * 0.3, -r * 2.7), Color(0.8, 0.12, 0.1), r * 0.14)
	# lamellar armour on the shoulders
	for side in [-1, 1]:
		for row in 3:
			for k in 4:
				var x: float = w * 0.5 + side * (w * 0.22 + k * w * 0.045)
				var y := h * 0.66 + row * h * 0.035
				draw_rect(Rect2(x - w * 0.02, y, w * 0.04, h * 0.03), BRONZE.darkened(0.1 + row * 0.1))


func _diviner(head: Vector2, r: float, w: float, h: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.62), Vector2(r * 0.96, r * 0.62), Color(0.85, 0.85, 0.82))
	draw_colored_polygon([head + Vector2(-r * 0.7, -r * 0.8), head + Vector2(r * 0.7, -r * 0.8),
		head + Vector2(r * 0.4, -r * 2.2), head + Vector2(-r * 0.4, -r * 2.2)], Color(0.2, 0.18, 0.35))
	draw_circle(head + Vector2(0, -r * 1.5), r * 0.25, Color(0.95, 0.9, 0.6))
	draw_circle(head + Vector2(r * 0.1, -r * 1.55), r * 0.22, Color(0.2, 0.18, 0.35))  # crescent moon
	# oracle-bone beads
	for i in 9:
		var a := PI * (0.15 + i * 0.0875)
		draw_circle(Vector2(w * 0.5, h * 0.64) + Vector2(cos(a) * w * 0.16, sin(a) * h * 0.12), r * 0.09, Color(0.9, 0.85, 0.7))


func _skin() -> Color:
	match style:
		"kushite":
			return Color(0.45, 0.30, 0.20)
		"pharaoh", "berber", "punic":
			return Color(0.80, 0.60, 0.44)
		"celtic":
			return Color(0.96, 0.80, 0.68)
	return SKIN


func _hair() -> Color:
	return Color(0.62, 0.36, 0.16) if style == "celtic" else HAIR


func _short_hair(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.6), Vector2(r * 0.98, r * 0.62), _hair())
	for i in 7:
		draw_circle(head + Vector2(-r * 0.75 + i * r * 0.25, -r * 0.62), r * 0.16, _hair())


func _laurel(head: Vector2, r: float) -> void:
	_short_hair(head, r)
	for side in [-1, 1]:
		for i in 6:
			var a := PI * (1.05 + i * 0.09)
			var at := head + Vector2(side * cos(a) * -r * 1.0, sin(a) * r * 0.75 - r * 0.25)
			_ellipse(at, Vector2(r * 0.18, r * 0.09), Color(0.30, 0.55, 0.22))
	# the toga's purple stripe
	draw_line(Vector2(head.x - r * 1.6, head.y + r * 2.4), Vector2(head.x + r * 0.2, head.y + r * 4.2), Color(0.45, 0.12, 0.35), r * 0.25)


func _greek_helmet(head: Vector2, r: float) -> void:
	var bronze := BRONZE.lightened(0.1)
	_ellipse(head + Vector2(0, -r * 0.45), Vector2(r * 1.05, r * 0.9), bronze)
	for side in [-1, 1]:  # cheek pieces
		draw_colored_polygon([head + Vector2(side * r * 1.0, -r * 0.4), head + Vector2(side * r * 1.0, r * 0.7),
			head + Vector2(side * r * 0.55, r * 0.55), head + Vector2(side * r * 0.5, -r * 0.1)], bronze.darkened(0.1))
	# the crest, front to back
	var crest := PackedVector2Array()
	for i in 13:
		var a := PI * (1.0 + i / 12.0)
		crest.append(head + Vector2(cos(a) * r * 1.2, -r * 1.2 + sin(a) * r * 0.9))
	crest.append(head + Vector2(r * 1.2, -r * 1.15))
	crest.append(head + Vector2(-r * 1.2, -r * 1.15))
	draw_colored_polygon(crest, colour.lightened(0.15))


func _diadem(head: Vector2, r: float) -> void:
	_short_hair(head, r)
	draw_line(head + Vector2(-r * 0.98, -r * 0.55), head + Vector2(r * 0.98, -r * 0.55), Color(0.97, 0.95, 0.9), r * 0.16)
	for i in 2:  # the diadem's ribbon ends
		draw_line(head + Vector2(r * 0.9, -r * 0.5), head + Vector2(r * (1.2 + i * 0.2), r * (0.3 + i * 0.25)), Color(0.97, 0.95, 0.9), r * 0.1)


func _punic_cap(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.6), Vector2(r * 0.97, r * 0.62), HAIR)
	draw_colored_polygon([head + Vector2(-r * 0.85, -r * 0.7), head + Vector2(r * 0.85, -r * 0.7),
		head + Vector2(r * 0.45, -r * 1.9), head + Vector2(-r * 0.45, -r * 1.9)], colour.lightened(0.2))
	draw_rect(Rect2(head.x - r * 0.9, head.y - r * 0.85, r * 1.8, r * 0.2), UiStyle.GOLD)
	for i in 6:  # curled beard
		draw_circle(head + Vector2(-r * 0.5 + i * r * 0.2, r * 0.95 + (i % 2) * r * 0.12), r * 0.15, HAIR)


func _nemes(head: Vector2, r: float) -> void:
	var blue := Color(0.15, 0.3, 0.65)
	var gold := UiStyle.GOLD
	draw_colored_polygon([head + Vector2(-r * 0.95, -r * 0.9), head + Vector2(r * 0.95, -r * 0.9),
		head + Vector2(r * 1.6, r * 1.8), head + Vector2(r * 0.85, r * 1.8), head + Vector2(r * 0.9, -r * 0.1),
		head + Vector2(-r * 0.9, -r * 0.1), head + Vector2(-r * 0.85, r * 1.8), head + Vector2(-r * 1.6, r * 1.8)], gold)
	for i in 6:  # stripes
		var y := -r * 0.7 + i * r * 0.42
		draw_line(head + Vector2(-r * 1.0 - i * r * 0.1, y), head + Vector2(-r * 0.9, y), blue, r * 0.14)
		draw_line(head + Vector2(r * 0.9, y), head + Vector2(r * 1.0 + i * r * 0.1, y), blue, r * 0.14)
	_ellipse(head + Vector2(0, -r * 0.85), Vector2(r * 0.97, r * 0.35), gold)
	draw_line(head + Vector2(-r * 0.9, -r * 0.7), head + Vector2(r * 0.9, -r * 0.7), blue, r * 0.12)
	draw_circle(head + Vector2(0, -r * 1.05), r * 0.14, Color(0.85, 0.2, 0.15))  # uraeus


func _headscarf(head: Vector2, r: float) -> void:
	var cloth := colour.lightened(0.45)
	_ellipse(head + Vector2(0, -r * 0.55), Vector2(r * 1.05, r * 0.75), cloth)
	draw_colored_polygon([head + Vector2(-r * 1.05, -r * 0.4), head + Vector2(-r * 0.85, r * 1.2),
		head + Vector2(-r * 1.3, r * 1.4)], cloth.darkened(0.1))
	draw_line(head + Vector2(-r * 1.0, -r * 0.45), head + Vector2(r * 1.0, -r * 0.45), colour.darkened(0.2), r * 0.12)


func _celtic(head: Vector2, r: float, w: float, h: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.65), Vector2(r * 1.0, r * 0.6), _hair())
	# gold torc at the neck
	var neck := Vector2(w * 0.5, h * 0.62)
	draw_arc(neck, w * 0.1, PI * 0.05, PI * 0.95, 16, UiStyle.GOLD, r * 0.18)
	draw_circle(neck + Vector2(-w * 0.1, h * 0.01), r * 0.13, UiStyle.GOLD)
	draw_circle(neck + Vector2(w * 0.1, h * 0.01), r * 0.13, UiStyle.GOLD)


func _kushite_cap(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.55), Vector2(r * 0.98, r * 0.7), Color(0.1, 0.08, 0.08))
	draw_line(head + Vector2(-r * 0.97, -r * 0.35), head + Vector2(r * 0.97, -r * 0.35), UiStyle.GOLD, r * 0.14)
	for side in [-1, 1]:  # the double uraeus of the Kushite kings
		draw_circle(head + Vector2(side * r * 0.15, -r * 0.55), r * 0.12, Color(0.85, 0.2, 0.15))


func _hittite_cap(head: Vector2, r: float) -> void:
	# long hair falling behind, then the tall conical cap
	draw_colored_polygon([head + Vector2(r * 0.6, -r * 0.4), head + Vector2(r * 1.2, r * 0.2),
		head + Vector2(r * 1.1, r * 2.0), head + Vector2(r * 0.7, r * 1.9)], HAIR)
	_ellipse(head + Vector2(0, -r * 0.62), Vector2(r * 0.97, r * 0.6), HAIR)
	draw_colored_polygon([head + Vector2(-r * 0.9, -r * 0.65), head + Vector2(r * 0.9, -r * 0.65),
		head + Vector2(r * 0.1, -r * 2.5)], colour.lightened(0.4))
	draw_line(head + Vector2(-r * 0.85, -r * 0.75), head + Vector2(r * 0.85, -r * 0.75), UiStyle.GOLD, r * 0.12)


func _assyrian(head: Vector2, r: float) -> void:
	# long hair on the shoulders
	for side in [-1, 1]:
		draw_colored_polygon([head + Vector2(side * r * 0.8, -r * 0.3), head + Vector2(side * r * 1.3, r * 0.3),
			head + Vector2(side * r * 1.25, r * 1.6), head + Vector2(side * r * 0.8, r * 1.5)], HAIR)
	# the square beard in rows of curls
	draw_rect(Rect2(head.x - r * 0.6, head.y + r * 0.45, r * 1.2, r * 1.35), HAIR)
	for row in 4:
		for k in 5:
			draw_circle(Vector2(head.x - r * 0.48 + k * r * 0.24, head.y + r * 0.62 + row * r * 0.32), r * 0.1, Color(0.22, 0.17, 0.14))
	# a tall crown with a small point, banded with gold
	var crown := colour.lightened(0.35)
	draw_colored_polygon([head + Vector2(-r * 0.85, -r * 0.55), head + Vector2(r * 0.85, -r * 0.55),
		head + Vector2(r * 0.72, -r * 1.75), head + Vector2(-r * 0.72, -r * 1.75)], crown)
	draw_colored_polygon([head + Vector2(-r * 0.2, -r * 1.75), head + Vector2(r * 0.2, -r * 1.75), head + Vector2(0, -r * 2.15)], crown)
	for band in 3:
		draw_line(head + Vector2(-r * 0.83, -r * (0.7 + band * 0.4)), head + Vector2(r * 0.83, -r * (0.7 + band * 0.4)), UiStyle.GOLD, r * 0.08)


func _medieval_crown(head: Vector2, r: float, w: float, h: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.6), Vector2(r * 1.0, r * 0.62), _hair())
	var gold := UiStyle.GOLD
	draw_rect(Rect2(head.x - r * 0.95, head.y - r * 1.05, r * 1.9, r * 0.35), gold)
	for i in 5:  # the crown's points
		var x := head.x - r * 0.9 + i * r * 0.45
		draw_colored_polygon([Vector2(x - r * 0.14, head.y - r * 1.02), Vector2(x + r * 0.14, head.y - r * 1.02), Vector2(x, head.y - r * 1.5)], gold)
		draw_circle(Vector2(x, head.y - r * 1.5), r * 0.07, Color(0.8, 0.15, 0.15))
	# ermine-trimmed cloak
	for i in 9:
		draw_circle(Vector2(w * 0.5 - w * 0.32 + i * w * 0.08, h * 0.66), w * 0.035, Color(0.96, 0.95, 0.9))


func _viking(head: Vector2, r: float) -> void:
	var iron := Color(0.55, 0.57, 0.6)
	_ellipse(head + Vector2(0, -r * 0.55), Vector2(r * 1.02, r * 0.85), iron)
	draw_rect(Rect2(head.x - r * 1.02, head.y - r * 0.55, r * 2.04, r * 0.16), iron.darkened(0.25))
	draw_rect(Rect2(head.x - r * 0.08, head.y - r * 0.55, r * 0.16, r * 0.75), iron.darkened(0.2))  # nose guard
	for side in [-1, 1]:  # braids
		draw_line(head + Vector2(side * r * 0.9, -r * 0.2), head + Vector2(side * r * 1.0, r * 1.5), Color(0.72, 0.45, 0.2), r * 0.18)


func _mitre(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.6), Vector2(r * 0.97, r * 0.6), Color(0.85, 0.85, 0.82))
	var cloth := Color(0.97, 0.95, 0.9)
	draw_colored_polygon([head + Vector2(-r * 0.8, -r * 0.7), head + Vector2(r * 0.8, -r * 0.7),
		head + Vector2(r * 0.55, -r * 2.2), head + Vector2(0, -r * 2.5), head + Vector2(-r * 0.55, -r * 2.2)], cloth)
	draw_line(head + Vector2(0, -r * 0.7), head + Vector2(0, -r * 2.45), UiStyle.GOLD, r * 0.12)
	draw_line(head + Vector2(-r * 0.8, -r * 0.8), head + Vector2(r * 0.8, -r * 0.8), UiStyle.GOLD, r * 0.12)


func _byzantine(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.6), Vector2(r * 0.97, r * 0.62), HAIR)
	var gold := UiStyle.GOLD
	_ellipse(head + Vector2(0, -r * 1.0), Vector2(r * 0.95, r * 0.45), gold)
	draw_rect(Rect2(head.x - r * 0.95, head.y - r * 1.0, r * 1.9, r * 0.35), gold)
	for i in 5:
		draw_circle(Vector2(head.x - r * 0.7 + i * r * 0.35, head.y - r * 0.85), r * 0.08, [Color(0.8, 0.15, 0.15), Color(0.2, 0.5, 0.8)][i % 2])
	draw_line(head + Vector2(0, -r * 1.45), head + Vector2(0, -r * 1.85), gold, r * 0.1)  # small cross
	draw_line(head + Vector2(-r * 0.15, -r * 1.7), head + Vector2(r * 0.15, -r * 1.7), gold, r * 0.1)
	for side in [-1, 1]:  # pendilia: strings of pearls
		for k in 5:
			draw_circle(head + Vector2(side * r * 0.95, -r * 0.6 + k * r * 0.22), r * 0.07, Color(0.97, 0.95, 0.9))


func _turban(head: Vector2, r: float) -> void:
	var cloth := Color(0.97, 0.95, 0.9) if colour.v < 0.6 else colour.lightened(0.5)
	_ellipse(head + Vector2(0, -r * 0.75), Vector2(r * 1.15, r * 0.75), cloth)
	for band in 3:
		draw_arc(head + Vector2(0, -r * 0.3), r * (0.95 + band * 0.12), PI * 1.15, PI * 1.85, 16, cloth.darkened(0.12), r * 0.08)
	draw_circle(head + Vector2(0, -r * 1.05), r * 0.13, colour.darkened(0.1))
	draw_colored_polygon([head + Vector2(0, -r * 1.2), head + Vector2(r * 0.12, -r * 1.7), head + Vector2(-r * 0.05, -r * 1.3)], colour)


func _doge(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.6), Vector2(r * 0.97, r * 0.6), Color(0.85, 0.85, 0.82))
	var cap := colour.lightened(0.15)
	draw_colored_polygon([head + Vector2(-r * 0.95, -r * 0.6), head + Vector2(r * 0.95, -r * 0.6),
		head + Vector2(r * 0.8, -r * 1.3), head + Vector2(r * 0.3, -r * 2.0), head + Vector2(-r * 0.8, -r * 1.3)], cap)
	draw_line(head + Vector2(-r * 0.95, -r * 0.65), head + Vector2(r * 0.95, -r * 0.65), UiStyle.GOLD, r * 0.12)


func _rus_cap(head: Vector2, r: float) -> void:
	_ellipse(head + Vector2(0, -r * 0.6), Vector2(r * 0.97, r * 0.6), HAIR)
	_ellipse(head + Vector2(0, -r * 1.05), Vector2(r * 0.8, r * 0.6), colour.lightened(0.1))
	draw_rect(Rect2(head.x - r * 1.0, head.y - r * 0.9, r * 2.0, r * 0.35), Color(0.45, 0.32, 0.2))  # fur trim
	for i in 8:
		draw_circle(Vector2(head.x - r * 0.9 + i * r * 0.26, head.y - r * 0.9), r * 0.12, Color(0.5, 0.36, 0.22))
	draw_circle(head + Vector2(0, -r * 1.6), r * 0.1, UiStyle.GOLD)


func _ellipse(centre: Vector2, radius: Vector2, fill: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, fill)
