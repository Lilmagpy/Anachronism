## A commander's sketch of a battle (D-272): your line at the bottom, the enemy's at the top,
## seen from above. Each wing is a block sized by the men standing there, the reserve sits
## behind, and red dashed arrows show the plan: a strong wing curving round the enemy's flank,
## a punch through the centre, a wide line wrapping both ends, a reserve moving up, arrows
## loosed, a feigned flight drawing the enemy on. In a battle report the same sketch shows
## how each wing fared: the winner's block solid, the beaten one hatched, a flank attack's
## arrow where a second army fell on the enemy.

extends Control

const PLAN := Color(0.85, 0.12, 0.10)        ## the red of the plan's arrows
const MINE := Color(0.72, 0.52, 0.16)
const FOE := Color(0.42, 0.40, 0.44)
const INK := Color(0.20, 0.15, 0.10)
const PLACES := ["left", "centre", "right"]

var mine_men := {"left": 0, "centre": 0, "right": 0, "reserve": 0}
var foe_men := {"left": 0, "centre": 0, "right": 0}   ## the enemy's wings by THEIR names
var formation := ""        ## formation id in force (resolved from auto where possible)
var plan := ""             ## battle plan id (line, charge, hold, skirmish, flank, feint, ambush)
var outcomes := {}         ## my wing -> "won" | "lost" | "even" (reports and previews)
var flank := ""            ## "left" | "right": a second army's blow lands on that enemy wing
var foe_label := "Enemy"
var my_label := "Your line"
var plan_note := ""        ## the plan in words, written in red at the top right
var show_plan := true      ## false in a battle report: the blocks and outcomes tell it


func _init() -> void:
	custom_minimum_size = Vector2(300, 190)
	mouse_filter = Control.MOUSE_FILTER_PASS


## Fill from an army as the view describes it (deployment shares by place, men by kind).
func from_army(army: Dictionary) -> void:
	mine_men = {"left": 0, "centre": 0, "right": 0, "reserve": 0}
	var men_of := {}
	for k in army.get("kinds", []):
		men_of[str(k["kind"])] = int(k["men"])
	var deployment: Dictionary = army.get("deployment", {})
	for kind in deployment:
		var shares: Dictionary = deployment[kind].get("shares", {})
		for place in shares:
			if mine_men.has(place):
				mine_men[place] += int(men_of.get(kind, 0)) * int(shares[place]) / 10000
	if mine_men.values().max() == 0:   # no deployment (a rival, an old save): an even line
		var each := int(army.get("men", 0)) / 3
		mine_men = {"left": each, "centre": each, "right": each, "reserve": 0}
	formation = str(army.get("formation", "auto"))
	if formation == "auto":
		formation = _read_formation()
	plan = str(army.get("plan", "auto"))
	if plan == "auto" and army.get("likely") != null:
		plan = str(army["likely"]["id"])
	queue_redraw()


## Fill from a battle report's Clash phase, seen from ``my_side`` ("a" attacked, "d" defended).
func from_clash(phase: Dictionary, my_side: String) -> void:
	mine_men = {"left": 0, "centre": 0, "right": 0, "reserve": 0}
	foe_men = {"left": 0, "centre": 0, "right": 0}
	outcomes = {}
	for w in phase.get("wings", []):
		var mine_a := my_side == "a"
		var my_place := str(w["wing"]) if mine_a else str(w["d_wing"])
		var their_place := str(w["d_wing"]) if mine_a else str(w["wing"])
		mine_men[my_place] = int(w["a_men"]) if mine_a else int(w["d_men"])
		foe_men[their_place] = int(w["d_men"]) if mine_a else int(w["a_men"])
		var winner := str(w.get("winner", ""))
		outcomes[my_place] = "even" if winner == "" else ("won" if winner == my_side else "lost")
	var blow: Dictionary = phase.get("flank", {})
	flank = str(blow.get("against", "")) if str(blow.get("side", "")) == my_side else ""
	show_plan = false
	queue_redraw()


## Guess the shape from where the men stand, for a general left to choose.
func _read_formation() -> String:
	var total := float(mine_men["left"] + mine_men["centre"] + mine_men["right"] + mine_men["reserve"])
	if total <= 0.0:
		return "balanced"
	if mine_men["reserve"] / total > 0.15:
		return "deep_reserve"
	var l: float = mine_men["left"] / total
	var c: float = mine_men["centre"] / total
	var r: float = mine_men["right"] / total
	if l > r + 0.12 and l > c:
		return "strong_left"
	if r > l + 0.12 and r > c:
		return "strong_right"
	if c > 0.45:
		return "strong_centre"
	return "balanced"


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.96, 0.92, 0.82))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.50, 0.30), false, 2.0)
	var font := get_theme_default_font()
	draw_string(font, Vector2(8, 16), foe_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, FOE.darkened(0.3))
	draw_string(font, Vector2(8, h - 6), my_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MINE.darkened(0.3))
	var foe_y := h * 0.24
	var my_y := h * 0.62
	var lane := w / 3.0
	# the enemy line: their right faces my left, so it is drawn on my left
	var foe_total := maxf(1.0, foe_men["left"] + foe_men["centre"] + foe_men["right"])
	var my_total := maxf(1.0, mine_men["left"] + mine_men["centre"] + mine_men["right"] + mine_men["reserve"])
	for i in 3:
		var mine_place: String = PLACES[i]
		var their_place: String = PLACES[2 - i]
		var foe_share: float = foe_men[their_place] / foe_total if foe_total > 1.0 else 1.0 / 3.0
		var my_share: float = mine_men[mine_place] / my_total
		var x := lane * i + lane / 2.0
		var result := str(outcomes.get(mine_place, ""))
		_block(Vector2(x, foe_y), foe_share, FOE, result == "won")
		_block(Vector2(x, my_y), my_share, MINE, result == "lost")
		if result != "":
			_mark(Vector2(x + lane * 0.36, (foe_y + my_y) / 2.0), result)
	if mine_men["reserve"] > 0:
		_block(Vector2(w / 2.0, h * 0.84), mine_men["reserve"] / my_total, MINE.lightened(0.25), false)
		draw_string(font, Vector2(w / 2.0 + 30, h * 0.86), "reserve", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	if show_plan:
		_plan_arrows(lane, foe_y, my_y)
	if plan_note != "":
		var width := font.get_string_size(plan_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(w - width - 8, 16), plan_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PLAN)
	if flank != "":
		var fx := 8.0 if flank == "right" else w - 8.0   # their right wing is on my left
		_arrow(Vector2(fx, h * 0.95), Vector2(lane * (0.5 if flank == "right" else 2.5), foe_y + 8), Color(0.15, 0.45, 0.75), true)
		draw_string(font, Vector2(fx - (0.0 if flank == "right" else 90.0), h * 0.92), "second army", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.45, 0.75))


## A wing's outlook or fate, drawn (fonts may lack tick glyphs): green tick, red cross, grey bars.
func _mark(at: Vector2, result: String) -> void:
	var tint := Color(0.18, 0.55, 0.20) if result == "won" else (PLAN if result == "lost" else Color(0.45, 0.42, 0.38))
	draw_circle(at, 9.0, tint)
	var white := Color(1, 1, 1)
	if result == "won":
		draw_polyline(PackedVector2Array([at + Vector2(-4, 0), at + Vector2(-1, 4), at + Vector2(5, -4)]), white, 2.5)
	elif result == "lost":
		draw_line(at + Vector2(-4, -4), at + Vector2(4, 4), white, 2.5)
		draw_line(at + Vector2(-4, 4), at + Vector2(4, -4), white, 2.5)
	else:
		draw_line(at + Vector2(-4, -2), at + Vector2(4, -2), white, 2.0)
		draw_line(at + Vector2(-4, 2), at + Vector2(4, 2), white, 2.0)


## A block of men: wider for more men; hatched when that wing was beaten.
func _block(centre: Vector2, share: float, colour: Color, beaten: bool) -> void:
	var bw := clampf(30.0 + share * 170.0, 26.0, size.x / 3.0 - 8.0)
	var rect := Rect2(centre - Vector2(bw / 2.0, 9), Vector2(bw, 18))
	draw_rect(rect, colour)
	draw_rect(rect, colour.darkened(0.4), false, 1.5)
	if beaten:
		var step := 7.0
		var x := rect.position.x
		while x < rect.end.x:
			draw_line(Vector2(x, rect.end.y), Vector2(minf(x + 10.0, rect.end.x), rect.position.y), Color(0.85, 0.12, 0.10, 0.75), 2.0)
			x += step


## The red dashed arrows of the formation and plan.
func _plan_arrows(lane: float, foe_y: float, my_y: float) -> void:
	var left := lane * 0.5
	var mid := lane * 1.5
	var right := lane * 2.5
	var front := my_y - 12.0
	match formation:
		"strong_left":
			_curve([Vector2(left, front), Vector2(left - lane * 0.35, (foe_y + my_y) / 2.0), Vector2(left - 6, foe_y - 14), Vector2(left + lane * 0.45, foe_y - 4)])
		"strong_right":
			_curve([Vector2(right, front), Vector2(right + lane * 0.35, (foe_y + my_y) / 2.0), Vector2(right + 6, foe_y - 14), Vector2(right - lane * 0.45, foe_y - 4)])
		"strong_centre":
			_arrow(Vector2(mid, front), Vector2(mid, foe_y + 12), PLAN, true, 4.0)
		"deep_reserve":
			_arrow(Vector2(mid, size.y * 0.80), Vector2(mid, front + 2), PLAN, true)
		"wide_line":
			_curve([Vector2(left, front), Vector2(8, (foe_y + my_y) / 2.0), Vector2(left - 4, foe_y - 14)])
			_curve([Vector2(right, front), Vector2(size.x - 8, (foe_y + my_y) / 2.0), Vector2(right + 4, foe_y - 14)])
		_:
			for x in [left, mid, right]:
				_arrow(Vector2(x, front), Vector2(x, foe_y + 14), PLAN.lightened(0.3), true, 1.5)
	match plan:
		"charge":
			for x in [left, mid, right]:
				_arrow(Vector2(x + 14, front), Vector2(x + 14, foe_y + 12), PLAN, false, 2.5)
		"skirmish":
			for x in [left, mid, right]:
				for k in 3:
					_arrow(Vector2(x - 10 + k * 10, front - 4), Vector2(x - 10 + k * 10, foe_y + 22), Color(0.25, 0.25, 0.25, 0.7), true, 1.0)
		"hold":
			draw_line(Vector2(lane * 0.15, my_y - 14), Vector2(lane * 2.85, my_y - 14), PLAN, 4.0)
		"flank":
			_curve([Vector2(left, my_y), Vector2(4, foe_y), Vector2(mid, foe_y - 22)])
			_curve([Vector2(right, my_y), Vector2(size.x - 4, foe_y), Vector2(mid, foe_y - 22)])
		"feint":
			_arrow(Vector2(mid, front), Vector2(mid, size.y * 0.80), PLAN, true)
			_curve([Vector2(left, size.y * 0.80), Vector2(4, my_y), Vector2(left, foe_y + 16)])
			_curve([Vector2(right, size.y * 0.80), Vector2(size.x - 4, my_y), Vector2(right, foe_y + 16)])
		"ambush":
			_curve([Vector2(size.x - 6, size.y * 0.5), Vector2(right + 10, foe_y + 26), Vector2(right - 10, foe_y + 4)])
			draw_string(get_theme_default_font(), Vector2(size.x - 70, size.y * 0.5 + 16), "hidden", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, PLAN)


## A dashed curve through the points, with an arrow head at the end.
func _curve(points: Array) -> void:
	var curve := Curve2D.new()
	for i in points.size():
		var p: Vector2 = points[i]
		var handle := Vector2.ZERO
		if i > 0 and i < points.size() - 1:
			handle = ((points[i + 1] as Vector2) - (points[i - 1] as Vector2)) * 0.25
		curve.add_point(p, -handle, handle)
	var baked := curve.get_baked_points()
	_dashes(baked, PLAN, 3.0)
	if baked.size() >= 2:
		_head(baked[baked.size() - 2], baked[baked.size() - 1], PLAN)


func _arrow(from: Vector2, to: Vector2, colour: Color, dashed: bool, width := 3.0) -> void:
	if dashed:
		_dashes(PackedVector2Array([from, to]), colour, width)
	else:
		draw_line(from, to, colour, width)
	_head(from, to, colour)


func _dashes(points: PackedVector2Array, colour: Color, width: float) -> void:
	var on := true
	var run := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var t := 0.0
		while t < length:
			var piece := minf(length - t, (7.0 if on else 5.0) - run)
			if on:
				draw_line(a.lerp(b, t / length), a.lerp(b, (t + piece) / length), colour, width)
			t += piece
			run += piece
			if run >= (7.0 if on else 5.0):
				run = 0.0
				on = not on


func _head(from: Vector2, to: Vector2, colour: Color) -> void:
	var d := (to - from).normalized()
	if d == Vector2.ZERO:
		return
	var side := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([to + d * 2.0, to - d * 10.0 + side * 6.0, to - d * 10.0 - side * 6.0]), colour)
