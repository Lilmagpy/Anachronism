## Northern and Western Europe, AD 800-1500 (England, Normandy, France, the Empire, Scandinavia,
## Rus, Poland, Hungary): half-timbered town houses, thatched cottages, a stone merchant's house
## with a stepped gable, a Scandinavian longhouse, a Rus izba, an inn; a castle, a church and a
## timber market hall. Models face +z, stand on y = 0, centred on x = z = 0 (1.0 = a house lot).
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")

const PLASTER_C := Color(0.93, 0.88, 0.75)
const TIMBER_C := Color(0.27, 0.18, 0.11)
const STONE_C := Color(0.66, 0.63, 0.57)
const STONE_D := Color(0.55, 0.53, 0.49)
const SLATE := Color(0.60, 0.58, 0.62)
## Uniform scale per kind, so each model stays inside its lot.
const FIT := {"house_1": 0.96, "house_2": 0.9, "house_4": 0.85, "house_5": 0.88, "house_6": 0.94,
	"palace": 0.93, "church": 0.93, "market_hall": 0.97}
const SHINGLE := Color(0.46, 0.33, 0.21)


static func kinds() -> Array:
	return ["house_1", "house_2", "house_3", "house_4", "house_5", "house_6", "palace", "church", "market_hall"]


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	var fit: float = FIT.get(kind, 1.0)
	if fit != 1.0:
		k.push(Transform3D(Basis().scaled(Vector3(fit, fit, fit)), Vector3.ZERO))
	match kind:
		"house_1":
			_house_timber(k)
		"house_2":
			_house_thatch(k)
		"house_3":
			_house_merchant(k)
		"house_4":
			_house_longhouse(k)
		"house_5":
			_house_izba(k)
		"house_6":
			_house_inn(k)
		"palace":
			_palace(k)
		"church":
			_church(k)
		"market_hall":
			_market_hall(k)
	return k.finish()


# --- helpers -----------------------------------------------------------------------------------


## Half-timbering on a wall face: `pos` is the bottom middle of the face, `yaw` its outward direction.
static func _frame_face(k: Kit, pos: Vector3, yaw: float, w: float, h: float, nx: int, braces: Array, col: Color) -> void:
	k.push(Kit.at(pos, yaw))
	k.box(Vector3(0, 0, 0), Vector3(w, 0.028, 0.026), col, Kit.TIMBER)
	k.box(Vector3(0, h - 0.028, 0), Vector3(w, 0.028, 0.026), col, Kit.TIMBER)
	for i in nx + 1:
		var x := -w / 2.0 + w * i / nx
		k.box(Vector3(x, 0, 0), Vector3(0.03, h, 0.028), col, Kit.TIMBER)
	for c: int in braces:
		var x0 := -w / 2.0 + w * c / nx
		var x1 := -w / 2.0 + w * (c + 1) / nx
		var up := c % 2 == 0
		k.rod(Vector3(x0 if up else x1, 0.03, 0.007), Vector3(x1 if up else x0, h - 0.03, 0.007), 0.008, col, Kit.TIMBER)
	k.pop()


## A row of merlons along a wall top from a to b (crenellation).
static func _merlons(k: Kit, a: Vector3, b: Vector3, thick: float, h: float, col: Color, spacing := 0.13) -> void:
	var d := b - a
	var n := maxi(2, int(d.length() / spacing))
	var yaw := atan2(-d.z, d.x)
	for i in n:
		var t := (i + 0.5) / n
		k.box(a + d * t, Vector3(d.length() / n * 0.58, h, thick), col, Kit.STONE, yaw)


## A sloped slab (lean-to roof / stair parapet) from the high edge to the low edge, along x.
static func _lean(k: Kit, x0: float, x1: float, z_hi: float, y_hi: float, z_lo: float, y_lo: float,
		thick: float, col: Color, mat: int) -> void:
	var up := Vector3(0, thick, 0)
	var inside := Vector3((x0 + x1) / 2.0, y_lo - 1.0, (z_hi + z_lo) / 2.0)
	var a := Vector3(x0, y_hi, z_hi)
	var b := Vector3(x1, y_hi, z_hi)
	var c := Vector3(x1, y_lo, z_lo)
	var d := Vector3(x0, y_lo, z_lo)
	k.quad(a + up, b + up, c + up, d + up, col, mat, inside)
	k.quad(a, b, c, d, col.darkened(0.35), mat, Vector3(0, 10, 0))
	k.quad(d, c, c + up, d + up, col.darkened(0.2), mat, Vector3((x0 + x1) / 2.0, y_lo, (z_hi + z_lo) / 2.0))
	k.quad(a, d, d + up, a + up, col.darkened(0.2), mat, Vector3(x1 + 1.0, y_hi, z_hi))
	k.quad(b, c, c + up, b + up, col.darkened(0.2), mat, Vector3(x0 - 1.0, y_hi, z_hi))


## A disc (round window, wheel) on a vertical plane facing `yaw`, centre `c`.
static func _disc(k: Kit, c: Vector3, yaw: float, r: float, thick: float, col: Color, mat: int, sides := 12) -> void:
	k.push(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2.0), c))
	k.frustum(Vector3(0, -thick / 2.0, 0), r, r, thick, col, mat, sides)
	k.pop()


## A cheap window: dark opening in a frame board, optional shutters or bars (arch/stone use the kit's).
static func _win(k: Kit, p: Vector3, yaw: float, w: float, h: float, frame: Color, style := "frame") -> void:
	if style == "arch" or style == "stone":
		k.window(p, yaw, w, h, frame, style)
		return
	k.push(Kit.at(p, yaw))
	k.box(Vector3(0, -h / 2.0 - 0.02, 0), Vector3(w + 0.05, h + 0.04, 0.012), frame, Kit.TIMBER)
	k.box(Vector3(0, -h / 2.0, 0.006), Vector3(w, h, 0.01), Color(0.07, 0.05, 0.04), Kit.DARK)
	if style == "shutters":
		for s: float in [-1.0, 1.0]:
			k.box(Vector3(s * (w / 2.0 + 0.035), -h / 2.0, 0.008), Vector3(w * 0.38, h, 0.012), frame.darkened(0.1), Kit.TIMBER)
	elif style == "lattice":
		k.box(Vector3(0, -h / 2.0, 0.012), Vector3(0.012, h, 0.008), frame, Kit.TIMBER)
		k.box(Vector3(0, -h / 2.0, 0.012), Vector3(w, 0.012, 0.008), frame, Kit.TIMBER)
	k.pop()


static func _barrel(k: Kit, foot: Vector3, r: float, h: float) -> void:
	k.frustum(foot, r * 0.85, r, h * 0.5, Color(0.5, 0.34, 0.18), Kit.TIMBER, 8, false)
	k.frustum(foot + Vector3(0, h * 0.5, 0), r, r * 0.85, h * 0.5, Color(0.5, 0.34, 0.18), Kit.TIMBER, 8)
	k.frustum(foot + Vector3(0, h * 0.3, 0), r * 1.03, r * 1.03, h * 0.04, Color(0.2, 0.18, 0.16), Kit.DARK, 8, false)
	k.frustum(foot + Vector3(0, h * 0.68, 0), r * 1.03, r * 1.03, h * 0.04, Color(0.2, 0.18, 0.16), Kit.DARK, 8, false)


static func _bush(k: Kit, foot: Vector3, r: float) -> void:
	k.dome(foot, r, Color(0.30, 0.46, 0.22), Kit.LEAF, 0.8, 3, 8)


# --- house 1: half-timbered town house with a jettied upper storey -------------------------------


static func _house_timber(k: Kit) -> void:
	var tm := TIMBER_C
	var pl := PLASTER_C
	k.box(Vector3(0, 0, 0), Vector3(0.78, 0.08, 0.78), STONE_C, Kit.STONE)
	k.box(Vector3(0, 0.08, 0), Vector3(0.74, 0.3, 0.74), pl, Kit.PLASTER)
	# jetty beam and joist ends under the overhanging upper floor
	k.box(Vector3(0, 0.37, 0.03), Vector3(0.82, 0.045, 0.82), tm, Kit.TIMBER)
	for i in 5:
		k.box(Vector3(-0.3 + i * 0.15, 0.33, 0.395), Vector3(0.03, 0.045, 0.06), tm, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:   # curved brackets under the jetty corners
		k.rod(Vector3(s * 0.37, 0.28, 0.37), Vector3(s * 0.37, 0.37, 0.44), 0.012, tm, Kit.TIMBER)
	k.box(Vector3(0, 0.415, 0.03), Vector3(0.80, 0.3, 0.80), pl, Kit.PLASTER)
	# ground floor framing and openings
	_frame_face(k, Vector3(0, 0.08, 0.37), 0.0, 0.74, 0.3, 3, [], tm)
	k.door(Vector3(0.25, 0.08, 0.372), 0.0, 0.15, 0.22, tm)
	_win(k, Vector3(-0.25, 0.25, 0.375), 0.0, 0.12, 0.12, tm, "shutters")
	_frame_face(k, Vector3(0.37, 0.08, 0.0), PI / 2.0, 0.74, 0.3, 3, [1], tm)
	# upper floor: framed front, a bay of casement windows, framed sides
	_frame_face(k, Vector3(0, 0.415, 0.43), 0.0, 0.8, 0.3, 3, [], tm)
	for x in [-0.267, 0.0, 0.267]:
		_win(k, Vector3(x, 0.58, 0.435), 0.0, 0.11, 0.13, tm, "shutters" if x != 0.0 else "lattice")
	_frame_face(k, Vector3(0.4, 0.415, 0.03), PI / 2.0, 0.8, 0.3, 4, [0, 2], tm)
	_frame_face(k, Vector3(-0.4, 0.415, 0.03), -PI / 2.0, 0.8, 0.3, 3, [1], tm)
	_win(k, Vector3(0.4, 0.58, 0.18), PI / 2.0, 0.1, 0.12, tm, "shutters")
	# steep slate roof, ridge front to back, with a timbered gable over the street
	k.gable_roof(Vector3(0, 0.715, 0.03), 0.8, 0.82, 0.52, 0.045, 0.035, SLATE, Kit.OWNER_ROOF, pl, Kit.PLASTER, PI / 2.0)
	k.push(Kit.at(Vector3(0, 0.715, 0.433)))
	k.box(Vector3(0, 0, 0), Vector3(0.86, 0.03, 0.03), tm, Kit.TIMBER)
	k.box(Vector3(0, 0.2, 0), Vector3(0.46, 0.026, 0.024), tm, Kit.TIMBER)
	k.box(Vector3(0, 0.2, 0), Vector3(0.03, 0.26, 0.026), tm, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.16, 0, 0), Vector3(0.026, 0.2, 0.024), tm, Kit.TIMBER)
		k.rod(Vector3(s * 0.38, 0.03, 0.01), Vector3(s * 0.16, 0.2, 0.01), 0.008, tm, Kit.TIMBER)
	_win(k, Vector3(0, 0.11, 0.012), 0.0, 0.1, 0.12, tm, "shutters")
	k.pop()
	k.chimney(Vector3(0.2, 0.9, -0.2), 0.1, 0.42, Color(0.62, 0.45, 0.36), Kit.BRICK)


# --- house 2: thatched cottage ---------------------------------------------------------------


static func _house_thatch(k: Kit) -> void:
	var pl := Color(0.94, 0.90, 0.78)
	var tm := Color(0.34, 0.23, 0.14)
	k.box(Vector3(0, 0, 0), Vector3(0.8, 0.06, 0.58), STONE_D, Kit.STONE)
	k.box(Vector3(0, 0.06, 0), Vector3(0.76, 0.22, 0.54), pl, Kit.PLASTER)
	for x in [-0.38, -0.13, 0.13, 0.38]:   # a few visible posts
		k.box(Vector3(x, 0.06, 0.27), Vector3(0.03, 0.22, 0.03), tm, Kit.TIMBER)
	k.door(Vector3(0.2, 0.06, 0.272), 0.0, 0.13, 0.19, tm)
	_win(k, Vector3(-0.2, 0.2, 0.275), 0.0, 0.1, 0.09, tm, "shutters")
	_win(k, Vector3(-0.382, 0.2, 0.05), -PI / 2.0, 0.09, 0.09, tm, "frame")
	k.hip_roof(Vector3(0, 0.25, 0), 0.76, 0.54, 0.44, 0.1, 0.09, Color(0.74, 0.62, 0.32), Kit.THATCH)
	# a thatched eyebrow over the attic window and a bundle of reed on the ridge
	k.push(Kit.at(Vector3(-0.1, 0.52, 0.2)))
	k.dome(Vector3(0, 0, 0), 0.1, Color(0.78, 0.66, 0.36), Kit.THATCH, 0.55, 2, 8)
	k.box(Vector3(0, -0.02, 0.08), Vector3(0.1, 0.08, 0.02), Color(0.12, 0.08, 0.06), Kit.DARK)
	k.pop()
	k.chimney(Vector3(-0.31, 0.3, 0.0), 0.11, 0.5, Color(0.64, 0.6, 0.54), Kit.STONE)
	# little garden: fence, hedges, a haystack
	for i in 7:
		k.box(Vector3(-0.3 + i * 0.1, 0, 0.45), Vector3(0.025, 0.1, 0.025), tm, Kit.TIMBER)
	k.box(Vector3(0, 0.05, 0.45), Vector3(0.62, 0.02, 0.015), tm, Kit.TIMBER)
	_bush(k, Vector3(0.42, 0, 0.35), 0.1)
	_bush(k, Vector3(-0.44, 0, 0.3), 0.08)
	k.frustum(Vector3(0.38, 0, -0.38), 0.1, 0.0, 0.2, Color(0.8, 0.68, 0.34), Kit.THATCH, 8)


# --- house 3: stone merchant's house with stepped gable ------------------------------------------


static func _house_merchant(k: Kit) -> void:
	var st := Color(0.72, 0.68, 0.60)
	var quoin := Color(0.82, 0.79, 0.71)
	var tm := Color(0.35, 0.24, 0.15)
	k.box(Vector3(0, 0, 0), Vector3(0.78, 0.07, 0.9), STONE_D, Kit.STONE)
	k.box(Vector3(0, 0.07, 0), Vector3(0.74, 0.57, 0.86), st, Kit.STONE)
	for x in [-0.37, 0.37]:   # corner quoins
		for z in [-0.43, 0.43]:
			k.box(Vector3(x, 0.07, z), Vector3(0.05, 0.57, 0.05), quoin, Kit.STONE)
	k.box(Vector3(0, 0.34, 0), Vector3(0.78, 0.025, 0.9), quoin, Kit.STONE)   # string course
	# stepped gables front and back
	var roof_y := 0.64
	for zs: float in [-1.0, 1.0]:
		for i in 5:
			var wd := 0.78 - 0.15 * i
			k.box(Vector3(0, roof_y + 0.08 * i, zs * 0.395), Vector3(wd, 0.08, 0.07), st, Kit.STONE)
		k.box(Vector3(0, roof_y + 0.4, zs * 0.395), Vector3(0.07, 0.07, 0.07), quoin, Kit.STONE)
	k.gable_roof(Vector3(0, roof_y, 0), 0.78, 0.74, 0.4, 0.04, 0.035, SLATE, Kit.OWNER_ROOF, st, Kit.STONE, PI / 2.0)
	# front: arched door, windows, loading door under the hoist
	k.door(Vector3(0, 0.07, 0.432), 0.0, 0.16, 0.24, quoin, Color(0.38, 0.24, 0.14))
	_win(k, Vector3(0, 0.34, 0.432), 0.0, 0.16, 0.0001, quoin, "arch")
	for x in [-0.24, 0.24]:
		_win(k, Vector3(x, 0.25, 0.432), 0.0, 0.1, 0.15, quoin, "arch")
		_win(k, Vector3(x, 0.52, 0.432), 0.0, 0.09, 0.13, quoin, "stone")
	k.box(Vector3(0, 0.44, 0.432), Vector3(0.11, 0.17, 0.014), Color(0.38, 0.24, 0.14), Kit.TIMBER)
	_win(k, Vector3(0, 0.84, 0.432), 0.0, 0.07, 0.08, quoin, "arch")
	# hoist beam with pulley wheel
	k.box(Vector3(0, 0.95, 0.43), Vector3(0.035, 0.035, 0.13), tm, Kit.TIMBER)
	k.rod(Vector3(0, 0.93, 0.43), Vector3(0, 0.84, 0.52), 0.012, tm, Kit.TIMBER)
	k.box(Vector3(0, 0.84, 0.50), Vector3(0.02, 0.1, 0.02), Color(0.5, 0.4, 0.25), Kit.TIMBER)
	# side windows
	for sx: float in [-1.0, 1.0]:
		for z in [-0.2, 0.2]:
			_win(k, Vector3(sx * 0.372, 0.25, z), sx * PI / 2.0, 0.09, 0.14, quoin, "arch")
	k.chimney(Vector3(0.22, 0.8, -0.15), 0.1, 0.38, Color(0.6, 0.5, 0.42), Kit.BRICK)
	k.box(Vector3(0, 0, 0.455), Vector3(0.3, 0.04, 0.05), quoin, Kit.STONE)
	# a hand cart of goods at the door
	k.box(Vector3(0.45, 0.04, 0.2), Vector3(0.1, 0.03, 0.18), tm, Kit.TIMBER)
	_barrel(k, Vector3(-0.44, 0, 0.42), 0.05, 0.1)


# --- house 4: Scandinavian longhouse ---------------------------------------------------------------


static func _house_longhouse(k: Kit) -> void:
	var wood := Color(0.45, 0.31, 0.19)
	var dark := Color(0.28, 0.18, 0.10)
	var red := Color(0.62, 0.20, 0.14)
	k.box(Vector3(0, 0, 0), Vector3(0.94, 0.05, 0.44), STONE_D, Kit.STONE)
	k.box(Vector3(0, 0.05, 0), Vector3(0.9, 0.2, 0.4), wood, Kit.TIMBER)
	# plank battens and corner stave posts topped with carved heads
	for i in 9:
		k.box(Vector3(-0.4 + i * 0.1, 0.05, 0.2), Vector3(0.02, 0.2, 0.012), dark, Kit.TIMBER)
	for x in [-0.45, 0.45]:
		for z in [-0.2, 0.2]:
			k.box(Vector3(x, 0.05, z), Vector3(0.05, 0.28, 0.05), dark, Kit.TIMBER)
			k.box(Vector3(x, 0.33, z), Vector3(0.045, 0.045, 0.045), red, Kit.PAINT)
	k.door(Vector3(0.18, 0.05, 0.202), 0.0, 0.12, 0.17, red, Color(0.3, 0.19, 0.1))
	for x in [-0.25, -0.05]:   # shuttered smoke-dim windows
		_win(k, Vector3(x, 0.2, 0.202), 0.0, 0.06, 0.05, dark, "frame")
	# the roof: shingles, a turf ridge, gable ends closed in carved boards
	k.gable_roof(Vector3(0, 0.25, 0), 0.9, 0.4, 0.34, 0.1, 0.045, SHINGLE, Kit.TILE, wood, Kit.TIMBER)
	k.box(Vector3(0, 0.59, 0), Vector3(1.0, 0.035, 0.09), Color(0.32, 0.46, 0.22), Kit.LEAF)
	for s: float in [-1.0, 1.0]:   # crossed, carved gable horns and a painted gable board
		var x := s * 0.54
		k.rod(Vector3(x, 0.45, -0.1), Vector3(x + s * 0.03, 0.66, 0.1), 0.014, dark, Kit.TIMBER)
		k.rod(Vector3(x, 0.45, 0.1), Vector3(x + s * 0.03, 0.66, -0.1), 0.014, dark, Kit.TIMBER)
		k.box(Vector3(s * 0.452, 0.27, 0), Vector3(0.012, 0.045, 0.2), red, Kit.PAINT)
		k.box(Vector3(s * 0.452, 0.34, 0), Vector3(0.012, 0.04, 0.12), Color(0.85, 0.72, 0.35), Kit.GOLD)
	# smoke louvre on the ridge
	k.box(Vector3(0.1, 0.6, 0), Vector3(0.14, 0.06, 0.1), dark, Kit.TIMBER)
	k.gable_roof(Vector3(0.1, 0.66, 0), 0.14, 0.1, 0.07, 0.015, 0.015, SHINGLE.darkened(0.2), Kit.TILE, dark, Kit.TIMBER)
	# woodpile and a small stave-built storehouse at the end
	for i in 3:
		for j in 3 - i:
			k.cylinder(Vector3(-0.2 + j * 0.05 + i * 0.025, 0.02 + i * 0.045, 0.34), 0.022, 0.2, Color(0.5, 0.36, 0.2), Kit.TIMBER, 6)
	k.box(Vector3(-0.3, 0, -0.38), Vector3(0.22, 0.14, 0.16), wood, Kit.TIMBER)
	k.gable_roof(Vector3(-0.3, 0.14, -0.38), 0.22, 0.16, 0.12, 0.03, 0.03, Color(0.3, 0.44, 0.2), Kit.LEAF, wood, Kit.TIMBER)


# --- house 5: Rus log house (izba) -------------------------------------------------------------------


static func _house_izba(k: Kit) -> void:
	var log_c := Color(0.55, 0.38, 0.21)
	var log_d := Color(0.46, 0.31, 0.17)
	var trim := Color(0.93, 0.90, 0.80)
	var blue := Color(0.22, 0.38, 0.62)
	# stone/log footing and 8 courses of logs with projecting corners
	k.box(Vector3(0, 0, 0), Vector3(0.6, 0.06, 0.7), STONE_D, Kit.STONE)
	var w := 0.56
	var d := 0.66
	for i in 8:
		var y := 0.06 + i * 0.055
		k.box(Vector3(0, y, d / 2.0 - 0.025), Vector3(w + (0.07 if i % 2 == 0 else 0.0), 0.055, 0.05), log_c if i % 2 == 0 else log_d, Kit.TIMBER)
		k.box(Vector3(0, y, -d / 2.0 + 0.025), Vector3(w + (0.07 if i % 2 == 0 else 0.0), 0.055, 0.05), log_c if i % 2 == 0 else log_d, Kit.TIMBER)
		k.box(Vector3(w / 2.0 - 0.025, y, 0), Vector3(0.05, 0.055, d + (0.07 if i % 2 == 1 else 0.0)), log_c if i % 2 == 1 else log_d, Kit.TIMBER)
		k.box(Vector3(-w / 2.0 + 0.025, y, 0), Vector3(0.05, 0.055, d + (0.07 if i % 2 == 1 else 0.0)), log_c if i % 2 == 1 else log_d, Kit.TIMBER)
	k.box(Vector3(0, 0.06, 0), Vector3(w - 0.06, 0.44, d - 0.06), log_d, Kit.TIMBER)
	# steep shingle roof, gable to the street with a carved, painted barge-board
	k.gable_roof(Vector3(0, 0.5, 0), d, w, 0.42, 0.07, 0.04, Color(0.40, 0.33, 0.26), Kit.TILE, log_c, Kit.TIMBER, PI / 2.0)
	k.push(Kit.at(Vector3(0, 0.5, d / 2.0 + 0.075)))
	for s: float in [-1.0, 1.0]:
		k.rod(Vector3(s * 0.36, -0.045, 0.0), Vector3(s * 0.01, 0.42, 0.0), 0.02, trim, Kit.PAINT)
		for i in 5:   # carved teeth along the barge board
			var t := 0.12 + i * 0.17
			k.box(Vector3(s * (0.36 - 0.35 * t) - 0.01, -0.045 + 0.46 * t - 0.055, 0.0), Vector3(0.02, 0.035, 0.02), blue, Kit.PAINT)
	k.box(Vector3(0, 0.4, 0.0), Vector3(0.05, 0.05, 0.05), blue, Kit.PAINT)
	k.pop()
	# the ridge horse (konek)
	k.box(Vector3(0, 0.88, d / 2.0 + 0.04), Vector3(0.05, 0.07, 0.12), log_d, Kit.TIMBER)
	k.box(Vector3(0, 0.95, d / 2.0 + 0.1), Vector3(0.045, 0.05, 0.05), log_d, Kit.TIMBER)
	# front window with carved frame, pediment and shutters
	k.push(Kit.at(Vector3(-0.08, 0.3, d / 2.0 + 0.01)))
	_win(k, Vector3(0, 0, 0), 0.0, 0.1, 0.12, trim, "shutters")
	k.tri(Vector3(-0.1, 0.08, 0.03), Vector3(0.1, 0.08, 0.03), Vector3(0, 0.16, 0.03), blue, Kit.PAINT, Vector3(0, 0.05, -1.0))
	k.box(Vector3(0, 0.07, 0.02), Vector3(0.2, 0.025, 0.03), trim, Kit.PAINT)
	k.box(Vector3(0, -0.2, 0.02), Vector3(0.18, 0.02, 0.03), trim, Kit.PAINT)
	k.pop()
	_win(k, Vector3(0.24, 0.3, 0.1), PI / 2.0, 0.09, 0.11, trim, "frame")
	_win(k, Vector3(-0.24, 0.3, 0.1), -PI / 2.0, 0.09, 0.11, trim, "frame")
	_win(k, Vector3(0, 0.78, d / 2.0 + 0.01), 0.0, 0.07, 0.09, trim, "arch")
	# the porch (kryltso): raised floor, two carved posts, little roof and steps
	k.box(Vector3(0.2, 0.0, d / 2.0 + 0.12), Vector3(0.22, 0.1, 0.24), log_d, Kit.TIMBER)
	k.door(Vector3(0.2, 0.1, d / 2.0 - 0.02), 0.0, 0.11, 0.2, trim, Color(0.3, 0.2, 0.12))
	for x in [0.1, 0.3]:
		k.box(Vector3(x, 0.1, d / 2.0 + 0.22), Vector3(0.035, 0.28, 0.035), log_c, Kit.TIMBER)
	k.gable_roof(Vector3(0.2, 0.38, d / 2.0 + 0.12), 0.26, 0.2, 0.1, 0.02, 0.025, Color(0.4, 0.33, 0.26), Kit.TILE, log_c, Kit.TIMBER, PI / 2.0)
	for i in 3:
		k.box(Vector3(0.2, 0.0, d / 2.0 + 0.26 + i * 0.05), Vector3(0.14, 0.09 - i * 0.03, 0.05), log_c, Kit.TIMBER)
	k.chimney(Vector3(-0.15, 0.78, -0.12), 0.09, 0.3, Color(0.6, 0.36, 0.3), Kit.BRICK)


# --- house 6: two-storey inn -----------------------------------------------------------------------


static func _house_inn(k: Kit) -> void:
	var pl := Color(0.94, 0.90, 0.78)
	var tm := Color(0.30, 0.20, 0.12)
	var cx := 0.06   # the main block sits right of centre; a stable lean-to takes the left
	k.box(Vector3(cx, 0, 0), Vector3(0.78, 0.07, 0.66), STONE_C, Kit.STONE)
	k.box(Vector3(cx, 0.07, 0), Vector3(0.74, 0.3, 0.6), STONE_C.lightened(0.1), Kit.STONE)
	k.box(Vector3(cx, 0.37, 0.025), Vector3(0.76, 0.04, 0.66), tm, Kit.TIMBER)
	k.box(Vector3(cx, 0.41, 0.025), Vector3(0.74, 0.3, 0.64), pl, Kit.PLASTER)
	_frame_face(k, Vector3(cx, 0.41, 0.345), 0.0, 0.74, 0.3, 4, [0, 3], tm)
	_frame_face(k, Vector3(cx + 0.37, 0.41, 0.025), PI / 2.0, 0.64, 0.3, 3, [1], tm)
	_frame_face(k, Vector3(cx - 0.37, 0.41, 0.025), -PI / 2.0, 0.64, 0.3, 3, [], tm)
	_frame_face(k, Vector3(cx, 0.41, -0.295), PI, 0.74, 0.3, 4, [1, 2], tm)
	# ground floor: wide arched door under a cloth awning, windows, barrels
	k.door(Vector3(cx, 0.07, 0.302), 0.0, 0.17, 0.23, tm, Color(0.36, 0.22, 0.12))
	_win(k, Vector3(cx, 0.31, 0.302), 0.0, 0.17, 0.0001, STONE_C.lightened(0.2), "arch")
	for x in [-0.22, 0.22]:
		_win(k, Vector3(cx + x, 0.24, 0.305), 0.0, 0.11, 0.11, tm, "shutters")
	for x in [-0.25, 0.0, 0.25]:   # upper windows (the middle one a glazed bay)
		_win(k, Vector3(cx + x, 0.58, 0.37), 0.0, 0.1, 0.13, tm, "shutters" if x != 0.0 else "lattice")
	k.push(Kit.at(Vector3(cx, 0.34, 0.31)))   # the awning
	k.quad(Vector3(-0.1, 0.0, 0.02), Vector3(0.1, 0.0, 0.02), Vector3(0.1, -0.07, 0.12), Vector3(-0.1, -0.07, 0.12),
		Color(0.8, 0.8, 0.8), Kit.OWNER_CLOTH, Vector3(0, -0.5, -0.5))
	k.pop()
	_barrel(k, Vector3(cx + 0.3, 0.0, 0.4), 0.05, 0.11)
	_barrel(k, Vector3(cx + 0.18, 0.0, 0.43), 0.045, 0.1)
	# roof: ridge along the street, two dormers, big chimneys
	k.gable_roof(Vector3(cx, 0.71, 0.025), 0.74, 0.64, 0.42, 0.05, 0.035, SLATE.darkened(0.1), Kit.OWNER_ROOF, pl, Kit.PLASTER)
	for x in [-0.2, 0.2]:
		var y_front := 0.71 + 0.42 * (1.0 - 0.27 / 0.32) - 0.03   # the roof height at the dormer face
		k.push(Kit.at(Vector3(cx + x, y_front, 0.0)))
		k.box(Vector3(0, 0, 0.14), Vector3(0.15, 0.19, 0.14), pl, Kit.PLASTER)
		_win(k, Vector3(0, 0.1, 0.212), 0.0, 0.08, 0.1, tm, "shutters")
		k.gable_roof(Vector3(0, 0.19, 0.14), 0.16, 0.15, 0.1, 0.025, 0.02, Color(0.42, 0.28, 0.20), Kit.TILE, pl, Kit.PLASTER, PI / 2.0)
		k.pop()
	k.chimney(Vector3(cx - 0.3, 0.88, -0.1), 0.1, 0.4, Color(0.62, 0.45, 0.36), Kit.BRICK)
	k.chimney(Vector3(cx + 0.28, 0.88, 0.0), 0.09, 0.34, Color(0.62, 0.45, 0.36), Kit.BRICK)
	# hanging sign on an iron bracket at the corner
	k.box(Vector3(cx + 0.33, 0.5, 0.37), Vector3(0.02, 0.02, 0.14), Color(0.15, 0.15, 0.16), Kit.DARK)
	k.rod(Vector3(cx + 0.33, 0.55, 0.37), Vector3(cx + 0.33, 0.5, 0.46), 0.008, Color(0.15, 0.15, 0.16), Kit.DARK)
	k.box(Vector3(cx + 0.33, 0.37, 0.485), Vector3(0.02, 0.13, 0.13), Color(0.55, 0.15, 0.12), Kit.PAINT)
	k.box(Vector3(cx + 0.345, 0.405, 0.485), Vector3(0.012, 0.05, 0.06), Color(0.9, 0.75, 0.3), Kit.GOLD)
	# stable lean-to on the left
	k.box(Vector3(-0.45, 0, -0.02), Vector3(0.14, 0.25, 0.5), tm, Kit.TIMBER)
	_lean(k, -0.56, -0.34, -0.31, 0.38, 0.27, 0.24, 0.03, Color(0.42, 0.28, 0.2), Kit.TILE)
	k.box(Vector3(-0.375, 0.02, 0.15), Vector3(0.01, 0.2, 0.2), Color(0.1, 0.07, 0.05), Kit.DARK)


# --- palace: a castle with keep, forebuilding stair, hall, curtain wall and gatehouse ----------------


static func _palace(k: Kit) -> void:
	var st := Color(0.67, 0.64, 0.58)
	var stl := Color(0.78, 0.75, 0.68)
	var roof := Color(0.58, 0.52, 0.5)
	k.box(Vector3(0, 0, 0), Vector3(3.0, 0.025, 3.0), Color(0.55, 0.48, 0.35), Kit.EARTH)
	# curtain wall with merlons, round corner towers, gatehouse
	var e := 1.42
	k.box(Vector3(0, 0, -e), Vector3(2.84, 0.5, 0.12), st, Kit.STONE)
	k.box(Vector3(-e, 0, 0), Vector3(0.12, 0.5, 2.84), st, Kit.STONE)
	k.box(Vector3(e, 0, 0), Vector3(0.12, 0.5, 2.84), st, Kit.STONE)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.96, 0, e), Vector3(0.96, 0.5, 0.12), st, Kit.STONE)
		_merlons(k, Vector3(s * 0.48, 0.5, e + 0.045), Vector3(s * 1.42, 0.5, e + 0.045), 0.03, 0.07, stl)
		_merlons(k, Vector3(s * e + 0.045 * s, 0.5, -e), Vector3(s * e + 0.045 * s, 0.5, e), 0.03, 0.07, stl)
		for z: float in [-1.0, 1.0]:
			k.frustum(Vector3(s * e, 0, z * e), 0.2, 0.18, 0.75, st, Kit.STONE, 10)
			k.frustum(Vector3(s * e, 0.75, z * e), 0.18, 0.0, 0.32, roof, Kit.OWNER_ROOF, 10)
			k.window(Vector3(s * e * 0.985, 0.55, z * e * 0.985 + z * 0.0), 0.0, 0.03, 0.1, stl, "frame")
	_merlons(k, Vector3(-1.42, 0.5, -e - 0.045), Vector3(1.42, 0.5, -e - 0.045), 0.03, 0.07, stl)
	# gatehouse
	k.box(Vector3(0, 0, e), Vector3(0.8, 0.8, 0.4), st, Kit.STONE)
	k.box(Vector3(0, 0, e + 0.2), Vector3(0.26, 0.38, 0.02), Color(0.08, 0.06, 0.05), Kit.DARK)
	k.dome(Vector3(0, 0.38, e + 0.2), 0.13, Color(0.08, 0.06, 0.05), Kit.DARK, 0.9, 3, 8)
	for i in 5:
		k.box(Vector3(-0.1 + i * 0.05, 0.05, e + 0.215), Vector3(0.012, 0.36, 0.012), Color(0.2, 0.2, 0.22), Kit.DARK)
	for s: float in [-1.0, 1.0]:
		k.frustum(Vector3(s * 0.4, 0, e + 0.12), 0.14, 0.14, 0.95, st, Kit.STONE, 8)
		k.frustum(Vector3(s * 0.4, 0.95, e + 0.12), 0.17, 0.17, 0.05, stl, Kit.STONE, 8)
		k.frustum(Vector3(s * 0.4, 1.0, e + 0.12), 0.15, 0.0, 0.25, roof, Kit.OWNER_ROOF, 8)
	_merlons(k, Vector3(-0.26, 0.8, e + 0.2), Vector3(0.26, 0.8, e + 0.2), 0.05, 0.08, stl)
	k.banner(Vector3(0, 0.8, e - 0.05), 0.5, 0.3)
	# paved path from the gate
	k.box(Vector3(0, 0.025, 1.0), Vector3(0.3, 0.012, 0.85), Color(0.62, 0.6, 0.55), Kit.STONE)
	# the keep
	var kx := -0.55
	var kz := -0.72
	k.plinth(Vector3(kx, 0, kz), 1.3, 1.1, 0.16, 0.06, STONE_D, Kit.STONE)
	k.box(Vector3(kx, 0.16, kz), Vector3(1.18, 1.5, 0.98), st, Kit.STONE)
	k.box(Vector3(kx, 1.66, kz), Vector3(1.26, 0.07, 1.06), stl, Kit.STONE)   # corbel course
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			k.frustum(Vector3(kx + x * 0.59, 0.1, kz + z * 0.49), 0.15, 0.15, 1.72, st, Kit.STONE, 10)
			k.frustum(Vector3(kx + x * 0.59, 1.82, kz + z * 0.49), 0.17, 0.17, 0.05, stl, Kit.STONE, 10)
			k.frustum(Vector3(kx + x * 0.59, 1.87, kz + z * 0.49), 0.16, 0.0, 0.36, roof, Kit.OWNER_ROOF, 10)
	# flat buttresses with sloped tops, arrow slits, windows
	for x in [-0.2, 0.2]:
		k.box(Vector3(kx + x, 0.0, kz + 0.52), Vector3(0.09, 1.1, 0.07), stl, Kit.STONE)
		k.wedge(Vector3(kx + x, 1.1, kz + 0.52), 0.09, 0.07, 0.12, stl, Kit.STONE, PI / 2.0)
		k.box(Vector3(kx + x, 0.0, kz - 0.52), Vector3(0.09, 1.1, 0.07), stl, Kit.STONE)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(kx + s * 0.6, 0.0, kz + 0.0), Vector3(0.07, 1.1, 0.09), stl, Kit.STONE)
	for i in 4:
		for lvl in [0.5, 1.2]:
			k.box(Vector3(kx - 0.45 + i * 0.3, lvl, kz + 0.495), Vector3(0.03, 0.15, 0.012), Color(0.06, 0.05, 0.05), Kit.DARK)
	k.window(Vector3(kx + 0.1, 1.2, kz + 0.495), 0.0, 0.1, 0.16, stl, "arch")
	k.window(Vector3(kx + 0.595 * 1.0, 1.2, kz), PI / 2.0, 0.1, 0.16, stl, "arch")
	k.window(Vector3(kx - 0.595, 1.2, kz), -PI / 2.0, 0.1, 0.16, stl, "arch")
	# roof tops: parapet merlons, pitched roof inside, flagpole
	var ty := 1.73
	var hx := 0.63
	var hz := 0.53
	_merlons(k, Vector3(kx - hx, ty, kz + hz), Vector3(kx + hx, ty, kz + hz), 0.06, 0.1, stl, 0.15)
	_merlons(k, Vector3(kx - hx, ty, kz - hz), Vector3(kx + hx, ty, kz - hz), 0.06, 0.1, stl, 0.15)
	_merlons(k, Vector3(kx - hx, ty, kz - hz), Vector3(kx - hx, ty, kz + hz), 0.06, 0.1, stl, 0.15)
	_merlons(k, Vector3(kx + hx, ty, kz - hz), Vector3(kx + hx, ty, kz + hz), 0.06, 0.1, stl, 0.15)
	k.hip_roof(Vector3(kx, ty, kz), 0.8, 0.56, 0.3, 0.0, 0.04, roof, Kit.OWNER_ROOF)
	k.banner(Vector3(kx, ty + 0.22, kz), 0.55, 0.38)
	# forebuilding with a long stair up to its door
	var fx := kx - 0.1
	k.box(Vector3(fx, 0, kz + 0.49 + 0.2), Vector3(0.46, 0.95, 0.4), st, Kit.STONE)
	k.box(Vector3(fx, 0.95, kz + 0.69), Vector3(0.5, 0.05, 0.44), stl, Kit.STONE)
	k.gable_roof(Vector3(fx, 1.0, kz + 0.69), 0.46, 0.42, 0.24, 0.03, 0.03, roof, Kit.OWNER_ROOF, st, Kit.STONE, PI / 2.0)
	var fz := kz + 0.89
	k.door(Vector3(fx, 0.62, fz + 0.002), 0.0, 0.14, 0.24, stl, Color(0.35, 0.22, 0.12))
	for i in 9:
		k.box(Vector3(fx, 0, fz + 0.5 - i * 0.045 - 0.0), Vector3(0.22, 0.07 * (i + 1) - 0.0, 0.05), stl, Kit.STONE)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(fx + s * 0.125, 0.0, fz + 0.28), Vector3(0.03, 0.2, 0.55), st, Kit.STONE)
	_lean(k, fx - 0.14, fx - 0.11, fz + 0.5, 0.2, fz, 0.7, 0.02, st, Kit.STONE)
	_lean(k, fx + 0.11, fx + 0.14, fz + 0.5, 0.2, fz, 0.7, 0.02, st, Kit.STONE)
	# the great hall, attached to the keep
	var hx0 := 0.7
	var hzc := -0.78
	k.box(Vector3(hx0, 0, hzc), Vector3(1.4, 0.62, 0.72), st, Kit.STONE)
	k.box(Vector3(hx0, 0, hzc), Vector3(1.46, 0.05, 0.78), STONE_D, Kit.STONE)
	k.gable_roof(Vector3(hx0, 0.62, hzc), 1.4, 0.72, 0.42, 0.06, 0.04, Color(0.6, 0.54, 0.52), Kit.OWNER_ROOF, st, Kit.STONE)
	for i in 4:
		k.window(Vector3(hx0 - 0.5 + i * 0.33, 0.38, hzc + 0.362), 0.0, 0.1, 0.2, stl, "arch")
		k.box(Vector3(hx0 - 0.33 + i * 0.33, 0.0, hzc + 0.37), Vector3(0.06, 0.5, 0.06), stl, Kit.STONE)
	k.box(Vector3(hx0 - 0.5 - 0.165, 0.0, hzc + 0.37), Vector3(0.06, 0.5, 0.06), stl, Kit.STONE)
	k.door(Vector3(hx0 + 0.62, 0.0, hzc + 0.362), 0.0, 0.16, 0.28, stl, Color(0.35, 0.22, 0.12))
	k.window(Vector3(hx0 + 0.71, 0.45, hzc), PI / 2.0, 0.1, 0.2, stl, "arch")
	k.chimney(Vector3(hx0 + 0.3, 0.85, hzc - 0.18), 0.12, 0.35, st, Kit.STONE)
	# well, tent-stall and stacked barrels in the bailey
	k.cylinder(Vector3(0.55, 0, 0.35), 0.1, 0.1, stl, Kit.STONE, 8)
	k.cylinder(Vector3(0.55, 0.1, 0.35), 0.075, 0.01, Color(0.2, 0.4, 0.55), Kit.WATER, 8)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(0.55 + s * 0.09, 0.1, 0.35), Vector3(0.02, 0.2, 0.02), TIMBER_C, Kit.TIMBER)
	k.gable_roof(Vector3(0.55, 0.3, 0.35), 0.24, 0.12, 0.08, 0.02, 0.015, Color(0.45, 0.3, 0.2), Kit.TILE, TIMBER_C, Kit.TIMBER)
	_barrel(k, Vector3(1.15, 0, 0.3), 0.07, 0.14)
	_barrel(k, Vector3(1.0, 0, 0.4), 0.06, 0.12)


# --- church: Romanesque / Gothic parish church ---------------------------------------------------------


static func _church(k: Kit) -> void:
	var st := Color(0.74, 0.71, 0.64)
	var stl := Color(0.84, 0.81, 0.74)
	var slate := Color(0.5, 0.5, 0.56)
	var roof := Color(0.6, 0.56, 0.54)
	var dk := Color(0.07, 0.05, 0.04)
	# nave (x -0.5 .. 0.3), aisles to the sides
	k.box(Vector3(-0.1, 0, 0), Vector3(0.8, 0.06, 0.8), STONE_D, Kit.STONE)
	k.box(Vector3(-0.1, 0.06, 0), Vector3(0.8, 0.52, 0.44), st, Kit.STONE)
	k.gable_roof(Vector3(-0.1, 0.58, 0), 0.8, 0.44, 0.32, 0.03, 0.03, roof, Kit.OWNER_ROOF, st, Kit.STONE)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(-0.1, 0.06, s * 0.32), Vector3(0.8, 0.26, 0.2), st, Kit.STONE)
		if s > 0:
			_lean(k, -0.5, 0.3, 0.22, 0.46, 0.45, 0.31, 0.03, slate, Kit.TILE)
		else:
			_lean(k, -0.5, 0.3, -0.22, 0.46, -0.45, 0.31, 0.03, slate, Kit.TILE)
	for i in 4:   # windows: aisle and clerestory, with buttresses between
		var x := -0.4 + i * 0.2
		k.window(Vector3(x, 0.26, 0.422), 0.0, 0.07, 0.14, stl, "arch")
		k.window(Vector3(x, 0.48, 0.221), 0.0, 0.06, 0.12, stl, "arch")
		k.box(Vector3(x + 0.1, 0.06, 0.42), Vector3(0.045, 0.3, 0.06), stl, Kit.STONE)
		k.wedge(Vector3(x + 0.1, 0.36, 0.42), 0.045, 0.06, 0.07, stl, Kit.STONE, PI / 2.0)
		k.window(Vector3(x, 0.26, -0.422), PI, 0.07, 0.14, stl, "arch")
	# transept with a rose window in its gable
	k.box(Vector3(0.45, 0.0, 0), Vector3(0.3, 0.5, 1.2), st, Kit.STONE)
	k.gable_roof(Vector3(0.45, 0.5, 0), 1.2, 0.3, 0.26, 0.03, 0.03, roof, Kit.OWNER_ROOF, st, Kit.STONE, PI / 2.0)
	_disc(k, Vector3(0.45, 0.45, 0.603), 0.0, 0.065, 0.01, dk, Kit.DARK)
	_disc(k, Vector3(0.45, 0.45, 0.606), 0.0, 0.035, 0.012, stl, Kit.STONE, 8)
	k.window(Vector3(0.45, 0.28, 0.603), 0.0, 0.07, 0.14, stl, "arch")
	# chancel and apse
	k.box(Vector3(0.72, 0.0, 0), Vector3(0.18, 0.4, 0.34), st, Kit.STONE)
	k.gable_roof(Vector3(0.72, 0.4, 0), 0.18, 0.34, 0.2, 0.02, 0.025, roof, Kit.OWNER_ROOF, st, Kit.STONE)
	k.frustum(Vector3(0.8, 0.0, 0), 0.17, 0.17, 0.4, st, Kit.STONE, 8)
	k.frustum(Vector3(0.8, 0.4, 0), 0.19, 0.0, 0.2, roof, Kit.OWNER_ROOF, 8)
	k.window(Vector3(0.96, 0.24, 0), PI / 2.0, 0.06, 0.12, stl, "arch")
	# west tower with belfry openings and a broach spire
	k.box(Vector3(-0.7, 0, 0), Vector3(0.4, 1.0, 0.4), st, Kit.STONE)
	k.box(Vector3(-0.7, 1.0, 0), Vector3(0.44, 0.05, 0.44), stl, Kit.STONE)
	for i in 4:
		var a := i * PI / 2.0
		var d := Vector3(sin(a), 0, cos(a))
		k.window(Vector3(-0.7, 0.8, 0) + d * 0.202, a, 0.07, 0.14, stl, "arch")
		k.box(Vector3(-0.7, 0.05, 0) + d * 0.21 + Vector3(sin(a + PI / 2) * 0.17, 0, cos(a + PI / 2) * 0.17), Vector3(0.05, 0.4, 0.05), stl, Kit.STONE, a)
		k.box(Vector3(-0.7, 0.0, 0) + Vector3(sin(a + PI / 4) * 0.265, 0, cos(a + PI / 4) * 0.265), Vector3(0.05, 0.05, 0.05), stl, Kit.STONE)
	for sx: float in [-1.0, 1.0]:   # corner pinnacles
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(-0.7 + sx * 0.2, 1.05, sz * 0.2), Vector3(0.05, 0.1, 0.05), stl, Kit.STONE)
			k.frustum(Vector3(-0.7 + sx * 0.2, 1.15, sz * 0.2), 0.04, 0.0, 0.07, slate, Kit.TILE, 4)
	k.push(Kit.at(Vector3(-0.7, 1.05, 0), 0.0))
	k.frustum(Vector3.ZERO, 0.17, 0.0, 0.6, slate, Kit.TILE, 8)
	k.pop()
	k.cylinder(Vector3(-0.7, 1.64, 0), 0.008, 0.1, Color(0.9, 0.75, 0.3), Kit.GOLD, 4)
	k.box(Vector3(-0.7, 1.7, 0), Vector3(0.05, 0.012, 0.012), Color(0.9, 0.75, 0.3), Kit.GOLD)
	k.box(Vector3(-0.7, 1.665, 0), Vector3(0.012, 0.012, 0.05), Color(0.9, 0.75, 0.3), Kit.GOLD)
	# south porch
	k.box(Vector3(-0.3, 0.0, 0.53), Vector3(0.2, 0.28, 0.16), stl, Kit.STONE)
	k.gable_roof(Vector3(-0.3, 0.28, 0.53), 0.16, 0.2, 0.14, 0.02, 0.02, roof, Kit.OWNER_ROOF, stl, Kit.STONE, PI / 2.0)
	k.door(Vector3(-0.3, 0.0, 0.612), 0.0, 0.1, 0.2, stl, Color(0.35, 0.22, 0.12))
	k.window(Vector3(-0.3, 0.2, 0.612), 0.0, 0.1, 0.0001, stl, "arch")


# --- market hall: a timber hall raised on posts ---------------------------------------------------------------


static func _market_hall(k: Kit) -> void:
	var tm := Color(0.33, 0.22, 0.13)
	var pl := PLASTER_C
	k.box(Vector3(0, 0, 0), Vector3(1.5, 0.05, 0.92), Color(0.62, 0.6, 0.55), Kit.STONE)
	# two rows of posts with stone bases and curved braces
	for i in 6:
		var x := -0.65 + i * 0.26
		for z: float in [-1.0, 1.0]:
			k.box(Vector3(x, 0.05, z * 0.36), Vector3(0.08, 0.05, 0.08), STONE_D, Kit.STONE)
			k.box(Vector3(x, 0.1, z * 0.36), Vector3(0.05, 0.3, 0.05), tm, Kit.TIMBER)
			if i < 5:
				k.rod(Vector3(x + 0.03, 0.3, z * 0.36), Vector3(x + 0.12, 0.4, z * 0.36), 0.01, tm, Kit.TIMBER)
	k.box(Vector3(0, 0.38, 0.36), Vector3(1.4, 0.05, 0.06), tm, Kit.TIMBER)
	k.box(Vector3(0, 0.38, -0.36), Vector3(1.4, 0.05, 0.06), tm, Kit.TIMBER)
	k.box(Vector3(0, 0.4, 0), Vector3(1.5, 0.04, 0.84), tm.lightened(0.1), Kit.TIMBER)   # the floor above
	# the hall above, timber-framed with windows
	k.box(Vector3(0, 0.44, 0), Vector3(1.4, 0.3, 0.74), pl, Kit.PLASTER)
	_frame_face(k, Vector3(0, 0.44, 0.37), 0.0, 1.4, 0.3, 7, [0, 2, 4, 6], tm)
	_frame_face(k, Vector3(0, 0.44, -0.37), PI, 1.4, 0.3, 7, [1, 3, 5], tm)
	_frame_face(k, Vector3(0.7, 0.44, 0), PI / 2.0, 0.74, 0.3, 3, [0, 2], tm)
	_frame_face(k, Vector3(-0.7, 0.44, 0), -PI / 2.0, 0.74, 0.3, 3, [1], tm)
	for i in 3:
		_win(k, Vector3(-0.4 + i * 0.4, 0.6, 0.375), 0.0, 0.09, 0.1, tm, "shutters")
	k.gable_roof(Vector3(0, 0.74, 0), 1.4, 0.74, 0.34, 0.05, 0.035, Color(0.62, 0.38, 0.3), Kit.TILE, pl, Kit.PLASTER)
	# bell cupola
	k.box(Vector3(0, 1.08, 0), Vector3(0.12, 0.08, 0.12), tm, Kit.TIMBER)
	k.frustum(Vector3(0, 1.16, 0), 0.1, 0.0, 0.12, Color(0.45, 0.35, 0.3), Kit.TILE, 4)
	# external stair at the end, stalls with cloth awnings below, goods
	for i in 5:
		k.box(Vector3(0.82, 0.05, -0.1 + i * 0.0), Vector3(0.1 + (0 if i < 0 else 0), 0.06 + i * 0.07, 0.3 - i * 0.04), STONE_C, Kit.STONE)
	for x in [-0.45, 0.05, 0.5]:
		k.quad(Vector3(x - 0.14, 0.34, 0.33), Vector3(x + 0.14, 0.34, 0.33), Vector3(x + 0.14, 0.2, 0.46), Vector3(x - 0.14, 0.2, 0.46),
			Color(0.8, 0.8, 0.8), Kit.OWNER_CLOTH, Vector3(x, 0.0, 0.2))
		k.box(Vector3(x, 0.05, 0.4), Vector3(0.22, 0.1, 0.08), tm, Kit.TIMBER)
		k.box(Vector3(x - 0.05, 0.15, 0.4), Vector3(0.06, 0.04, 0.05), Color(0.7, 0.4, 0.2), Kit.CLOTH)
	_barrel(k, Vector3(-0.62, 0.05, 0.42), 0.05, 0.1)
