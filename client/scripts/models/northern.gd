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
	var all: Array = ["house_1", "house_2", "house_3", "house_4", "house_5", "house_6", "palace", "church", "market_hall"]
	var names: Array = _rows().keys()
	names.sort()
	all.append_array(names)
	all.append_array(BIG_KINDS)
	all.append_array(PROP_KINDS)
	return all


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	var row: Dictionary = _rows().get(kind, {})
	if not row.is_empty():
		_from_row(k, row)
		return k.finish()
	if kind.begins_with("big_"):
		_big(k, kind)
		return k.finish()
	if kind.begins_with("prop_"):
		_prop(k, kind)
		return k.finish()
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


# =================================================================================================
# Parametric houses (D-281). One builder per building family; a table of rows gives each kind its
# own proportions, storeys, jetties, roof form and material, wall finish, timber pattern, dormers,
# chimneys and porches, so a city is never the same two houses over and over.
# =================================================================================================

const LOG_C := Color(0.52, 0.36, 0.20)
const PAL_PL := {"cream": Color(0.93, 0.88, 0.75), "white": Color(0.96, 0.95, 0.90), "ochre": Color(0.88, 0.74, 0.46),
	"pink": Color(0.88, 0.70, 0.62), "sage": Color(0.74, 0.79, 0.68), "grey": Color(0.78, 0.78, 0.74),
	"umber": Color(0.72, 0.62, 0.48), "blue": Color(0.68, 0.76, 0.80)}
const PAL_TM := {"brown": Color(0.27, 0.18, 0.11), "black": Color(0.15, 0.11, 0.09), "blood": Color(0.36, 0.14, 0.11),
	"grey": Color(0.42, 0.38, 0.32), "green": Color(0.20, 0.30, 0.24), "oak": Color(0.45, 0.31, 0.18)}
const PAL_ST := {"grey": Color(0.66, 0.63, 0.57), "warm": Color(0.74, 0.66, 0.52), "pale": Color(0.80, 0.77, 0.69),
	"dark": Color(0.55, 0.53, 0.49)}
const TRIM := {"white": Color(0.93, 0.90, 0.80), "blue": Color(0.22, 0.38, 0.62), "red": Color(0.62, 0.20, 0.14),
	"green": Color(0.24, 0.45, 0.30), "ochre": Color(0.82, 0.62, 0.22)}
const FRONT_C := 0.008   ## how far applied strips and openings stand off a wall face

static var _rows_cache := {}


## Roof material by name: [kit material, colour, eave overhang, slab thickness].
static func _rdef(name: String) -> Array:
	match name:
		"tile":
			return [Kit.TILE, Color(0.66, 0.36, 0.26), 0.05, 0.035]
		"tile2":
			return [Kit.TILE, Color(0.78, 0.50, 0.32), 0.05, 0.035]
		"shingle":
			return [Kit.TILE, SHINGLE, 0.06, 0.04]
		"shingle_g":
			return [Kit.TILE, Color(0.50, 0.46, 0.40), 0.06, 0.04]
		"plank":
			return [Kit.TILE, Color(0.55, 0.45, 0.33), 0.07, 0.04]
		"flag":
			return [Kit.TILE, Color(0.52, 0.52, 0.48), 0.05, 0.05]
		"thatch":
			return [Kit.THATCH, Color(0.76, 0.64, 0.34), 0.09, 0.08]
		"thatch_g":
			return [Kit.THATCH, Color(0.62, 0.55, 0.40), 0.09, 0.08]
		"reed":
			return [Kit.THATCH, Color(0.70, 0.62, 0.40), 0.08, 0.07]
		"turf":
			return [Kit.LEAF, Color(0.36, 0.48, 0.23), 0.08, 0.07]
		_:
			return [Kit.OWNER_ROOF, SLATE, 0.05, 0.035]


static func _pal(table: Dictionary, key: Variant, fallback: Color) -> Color:
	return table.get(str(key), fallback)


# --- small flat details ------------------------------------------------------------------------------
# These are drawn in a wall's own frame: x across the face, y up it, z out of it. Flat quads are
# two triangles each, where a box costs ten, which is how the houses afford so much timber work.


## A flat strip from a to b, `wd` wide, standing off the face.
static func _strip(k: Kit, a: Vector2, b: Vector2, wd: float, col: Color, mat := Kit.TIMBER, z := FRONT_C) -> void:
	var dir := b - a
	if dir.length() < 0.002:
		return
	var nrm := Vector2(-dir.y, dir.x).normalized() * wd * 0.5
	var mid := (a + b) * 0.5
	k.quad(Vector3(a.x - nrm.x, a.y - nrm.y, z), Vector3(b.x - nrm.x, b.y - nrm.y, z),
		Vector3(b.x + nrm.x, b.y + nrm.y, z), Vector3(a.x + nrm.x, a.y + nrm.y, z), col, mat, Vector3(mid.x, mid.y, -1.0))


## A flat rectangle (x0,y0)-(x1,y1) at depth z.
static func _plate(k: Kit, x0: float, y0: float, x1: float, y1: float, col: Color, mat: int, z := FRONT_C) -> void:
	k.quad(Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), col, mat,
		Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, -1.0))


## Timber framing across a wall w wide, h high: sill and head beams, posts, and the chosen pattern.
static func _pattern(k: Kit, w: float, h: float, pat: String, col: Color) -> void:
	var hw := w / 2.0
	_strip(k, Vector2(-hw, 0.016), Vector2(hw, 0.016), 0.032, col)
	_strip(k, Vector2(-hw, h - 0.016), Vector2(hw, h - 0.016), 0.032, col)
	var cols := 3
	match pat:
		"close":
			cols = maxi(3, int(w / 0.085))
		"panels":
			cols = maxi(2, int(w / 0.2))
		"braces", "cross":
			cols = maxi(2, int(w / 0.25))
		_:
			cols = 2
	for i in cols + 1:
		var x := -hw + 0.015 + (w - 0.03) * i / cols
		_strip(k, Vector2(x, 0.03), Vector2(x, h - 0.03), 0.028, col)
	if pat == "panels":
		_strip(k, Vector2(-hw, h * 0.55), Vector2(hw, h * 0.55), 0.024, col)
	elif pat == "close":
		_strip(k, Vector2(-hw, h * 0.5), Vector2(hw, h * 0.5), 0.022, col)
	elif pat == "braces":
		for c in cols:
			var x0 := -hw + 0.015 + (w - 0.03) * c / cols
			var x1 := -hw + 0.015 + (w - 0.03) * (c + 1) / cols
			if c % 2 == 0:
				_strip(k, Vector2(x0, 0.035), Vector2(x1, h - 0.035), 0.02, col)
			else:
				_strip(k, Vector2(x1, 0.035), Vector2(x0, h - 0.035), 0.02, col)
	elif pat == "cross":
		for c in cols:
			var x0 := -hw + 0.015 + (w - 0.03) * c / cols
			var x1 := -hw + 0.015 + (w - 0.03) * (c + 1) / cols
			_strip(k, Vector2(x0, 0.035), Vector2(x1, h - 0.035), 0.018, col)
			_strip(k, Vector2(x1, 0.035), Vector2(x0, h - 0.035), 0.018, col)


## Horizontal log courses on a wall face, as dark seams between the logs.
static func _logs(k: Kit, w: float, h: float, col: Color) -> void:
	var n := maxi(3, roundi(h / 0.055))
	for i in range(1, n):
		var y := h * i / n
		_strip(k, Vector2(-w / 2.0, y), Vector2(w / 2.0, y), 0.012, col.darkened(0.35), Kit.DARK, 0.004)


## A window centred at (x, y) on the face. Styles: frame, shutters, lattice, arch, stone.
static func _win2(k: Kit, x: float, y: float, w: float, h: float, frame: Color, style := "shutters") -> void:
	var fm := Kit.STONE if style == "stone" else Kit.TIMBER
	_plate(k, x - w / 2.0 - 0.02, y - h / 2.0 - 0.02, x + w / 2.0 + 0.02, y + h / 2.0 + 0.02, frame, fm, 0.005)
	_plate(k, x - w / 2.0, y - h / 2.0, x + w / 2.0, y + h / 2.0, Color(0.07, 0.05, 0.04), Kit.DARK, 0.009)
	if style == "shutters":
		for s: float in [-1.0, 1.0]:
			_plate(k, x + s * (w / 2.0 + 0.02), y - h / 2.0, x + s * (w / 2.0 + 0.02 + w * 0.42), y + h / 2.0, frame.darkened(0.1), Kit.TIMBER, 0.011)
	elif style == "lattice":
		_strip(k, Vector2(x, y - h / 2.0), Vector2(x, y + h / 2.0), 0.012, frame, Kit.TIMBER, 0.012)
		_strip(k, Vector2(x - w / 2.0, y), Vector2(x + w / 2.0, y), 0.012, frame, Kit.TIMBER, 0.012)
	elif style == "arch":
		k.tri(Vector3(x - w / 2.0, y + h / 2.0, 0.009), Vector3(x + w / 2.0, y + h / 2.0, 0.009), Vector3(x, y + h / 2.0 + w * 0.5, 0.009),
			Color(0.07, 0.05, 0.04), Kit.DARK, Vector3(x, y, -1.0))


## A door with its leaf, frame and step; `arch` caps it with a pointed head.
static func _door2(k: Kit, x: float, w: float, h: float, frame: Color, leaf: Color, arch := false, step := true) -> void:
	_plate(k, x - w / 2.0 - 0.025, 0.0, x + w / 2.0 + 0.025, h + 0.025, frame, Kit.TIMBER, 0.005)
	_plate(k, x - w / 2.0, 0.0, x + w / 2.0, h, leaf, Kit.TIMBER, 0.009)
	if arch:
		k.tri(Vector3(x - w / 2.0 - 0.025, h + 0.025, 0.005), Vector3(x + w / 2.0 + 0.025, h + 0.025, 0.005),
			Vector3(x, h + w * 0.5, 0.005), frame, Kit.STONE, Vector3(x, h, -1.0))
		k.tri(Vector3(x - w / 2.0, h, 0.009), Vector3(x + w / 2.0, h, 0.009), Vector3(x, h + w * 0.42, 0.009), leaf, Kit.TIMBER, Vector3(x, h, -1.0))
	if step:
		k.box(Vector3(x, 0, 0.03), Vector3(w * 1.5, 0.018, 0.06), Color(0.62, 0.60, 0.56), Kit.STONE)


# --- small things standing about -----------------------------------------------------------------------


static func _barrel6(k: Kit, foot: Vector3, r: float, h: float) -> void:
	k.frustum(foot, r, r * 0.9, h, Color(0.5, 0.34, 0.18), Kit.TIMBER, 6)
	k.frustum(foot + Vector3(0, h * 0.4, 0), r * 1.05, r * 1.05, h * 0.06, Color(0.2, 0.18, 0.16), Kit.DARK, 6, false)


static func _shrub(k: Kit, foot: Vector3, r: float) -> void:
	k.dome(foot, r, Color(0.30, 0.46, 0.22), Kit.LEAF, 0.8, 2, 6)


## A little yard object by name, standing at (x, z) in the house frame.
static func _extra(k: Kit, what: String, x: float, z: float) -> void:
	var wood := Color(0.5, 0.36, 0.2)
	match what:
		"barrel":
			_barrel6(k, Vector3(x, 0, z), 0.04, 0.09)
			_barrel6(k, Vector3(x + 0.07, 0, z - 0.02), 0.035, 0.08)
		"bush":
			_shrub(k, Vector3(x, 0, z), 0.08)
			_shrub(k, Vector3(x + 0.09, 0, z + 0.02), 0.06)
		"wood":
			k.box(Vector3(x, 0, z), Vector3(0.16, 0.07, 0.07), wood, Kit.TIMBER)
			k.box(Vector3(x, 0.07, z), Vector3(0.13, 0.05, 0.06), wood.darkened(0.1), Kit.TIMBER)
		"hay":
			k.frustum(Vector3(x, 0, z), 0.09, 0.0, 0.17, Color(0.80, 0.68, 0.34), Kit.THATCH, 6)
		"bench":
			k.box(Vector3(x, 0.05, z), Vector3(0.15, 0.015, 0.05), wood, Kit.TIMBER)
			k.box(Vector3(x - 0.06, 0, z), Vector3(0.015, 0.05, 0.045), wood, Kit.TIMBER)
			k.box(Vector3(x + 0.06, 0, z), Vector3(0.015, 0.05, 0.045), wood, Kit.TIMBER)
		"cart":
			k.box(Vector3(x, 0.05, z), Vector3(0.12, 0.025, 0.2), wood.darkened(0.1), Kit.TIMBER)
			for s: float in [-1.0, 1.0]:
				_wheel(k, Vector3(x + s * 0.07, 0.05, z), 0.05)
			k.rod(Vector3(x, 0.06, z + 0.1), Vector3(x, 0.03, z + 0.2), 0.008, wood, Kit.TIMBER)
		"fence":
			for i in 4:
				k.box(Vector3(x + i * 0.08, 0, z), Vector3(0.02, 0.08, 0.02), wood, Kit.TIMBER)
			k.box(Vector3(x + 0.12, 0.05, z), Vector3(0.26, 0.012, 0.012), wood, Kit.TIMBER)
		"pen":
			for s: float in [-1.0, 1.0]:
				k.box(Vector3(x + s * 0.1, 0.03, z), Vector3(0.012, 0.06, 0.2), wood, Kit.TIMBER)
			k.box(Vector3(x, 0.03, z - 0.1), Vector3(0.2, 0.06, 0.012), wood, Kit.TIMBER)
			k.box(Vector3(x, 0.0, z), Vector3(0.18, 0.012, 0.18), Color(0.72, 0.62, 0.4), Kit.THATCH)
		"ladder":
			for s: float in [-1.0, 1.0]:
				k.rod(Vector3(x + s * 0.025, 0.0, z + 0.04), Vector3(x + s * 0.025, 0.3, z), 0.006, wood, Kit.TIMBER)
		"well":
			k.frustum(Vector3(x, 0, z), 0.06, 0.06, 0.07, STONE_D, Kit.STONE, 6)
			k.frustum(Vector3(x, 0.05, z), 0.04, 0.04, 0.02, Color(0.25, 0.45, 0.6), Kit.WATER, 6)


## A cart wheel flat in the x-plane at `c`.
static func _wheel(k: Kit, c: Vector3, r: float) -> void:
	k.push(Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.RIGHT, PI / 2.0), c))
	k.frustum(Vector3(0, -0.01, 0), r, r, 0.02, Color(0.30, 0.20, 0.12), Kit.TIMBER, 7)
	k.pop()


# --- roofs ---------------------------------------------------------------------------------------------


## A half-hipped (jerkin-head) roof: gable ends clipped by a small hip at the top. Ridge along x.
static func _half_roof(k: Kit, foot: Vector3, len: float, span: float, rise: float, over: float, col: Color,
		mat: int, wc: Color, wm: int, yaw: float) -> void:
	k.push(Kit.at(foot, yaw))
	var hw := len / 2.0 + over
	var hd := span / 2.0 + over
	var drop := over * rise / maxf(span / 2.0, 0.001)
	var yh := rise * 0.62
	var zc := hd * (1.0 - (yh + drop) / (rise + drop))
	var lh := minf(span * 0.3, len * 0.3)
	var inner := Vector3(0, -1.0, 0)
	for s: float in [-1.0, 1.0]:
		k.polygon([Vector3(-hw, -drop, s * hd), Vector3(hw, -drop, s * hd), Vector3(hw, yh, s * zc),
			Vector3(hw - lh, rise, 0), Vector3(-hw + lh, rise, 0), Vector3(-hw, yh, s * zc)], col, mat, inner)
		for e: float in [-1.0, 1.0]:
			k.tri(Vector3(e * hw, yh, -zc), Vector3(e * hw, yh, zc), Vector3(e * (hw - lh), rise, 0), col.darkened(0.08), mat, inner)
			if s > 0.0:
				k.quad(Vector3(e * hw, -drop, -hd), Vector3(e * hw, -drop, hd), Vector3(e * hw, yh, zc), Vector3(e * hw, yh, -zc),
					wc, wm, Vector3(e * (hw - 1.0), 0, 0))
	k.rod(Vector3(-hw + lh, rise + 0.01, 0), Vector3(hw - lh, rise + 0.01, 0), 0.016, col.darkened(0.15), mat)
	k.pop()


## A catslide (saltbox) roof: the ridge sits toward the front, the back slope runs long and low.
static func _cat_roof(k: Kit, foot: Vector3, len: float, span: float, rise: float, over: float, col: Color,
		mat: int, wc: Color, wm: int, yaw: float) -> void:
	k.push(Kit.at(foot, yaw))
	var hw := len / 2.0 + over
	var hd := span / 2.0 + over
	var zr := span * 0.12
	var drop := over * rise / maxf(span / 2.0, 0.001) * 0.6
	var inner := Vector3(0, -1.0, 0)
	k.quad(Vector3(-hw, -drop, hd), Vector3(hw, -drop, hd), Vector3(hw, rise, zr), Vector3(-hw, rise, zr), col, mat, inner)
	k.quad(Vector3(-hw, rise, zr), Vector3(hw, rise, zr), Vector3(hw, -drop, -hd), Vector3(-hw, -drop, -hd), col.darkened(0.06), mat, inner)
	k.rod(Vector3(-hw, rise + 0.01, zr), Vector3(hw, rise + 0.01, zr), 0.016, col.darkened(0.15), mat)
	for e: float in [-1.0, 1.0]:
		k.tri(Vector3(e * len / 2.0, 0, span / 2.0), Vector3(e * len / 2.0, 0, -span / 2.0), Vector3(e * len / 2.0, rise - 0.01, zr),
			wc, wm, Vector3(e * (len / 2.0 - 1.0), 0, 0))
	k.pop()


## A shed roof sloping along x between the high edge `xh` and the low edge `xl`, over z0..z1.
static func _shed(k: Kit, xh: float, xl: float, z0: float, z1: float, yh: float, yl: float, col: Color, mat: int) -> void:
	var inner := Vector3((xh + xl) / 2.0, yl - 1.0, (z0 + z1) / 2.0)
	k.quad(Vector3(xh, yh, z0), Vector3(xh, yh, z1), Vector3(xl, yl, z1), Vector3(xl, yl, z0), col, mat, inner)
	k.quad(Vector3(xl, yl, z0), Vector3(xl, yl, z1), Vector3(xl, yl - 0.035, z1), Vector3(xl, yl - 0.035, z0), col.darkened(0.25), mat,
		Vector3(xh, yl, (z0 + z1) / 2.0))


## Any roof form over a body of `len` (along the ridge) by `span`; `ridge_z` turns the ridge to run
## front to back so the gable faces the street.
static func _roof(k: Kit, form: String, foot: Vector3, len: float, span: float, rise: float, over: float,
		thick: float, col: Color, mat: int, wc: Color, wm: int, ridge_z: bool) -> void:
	var yaw := PI / 2.0 if ridge_z else 0.0
	match form:
		"hip":
			k.hip_roof(foot, len, span, rise, over, thick, col, mat, yaw)
		"half":
			_half_roof(k, foot, len, span, rise, over, col, mat, wc, wm, yaw)
		"cat":
			_cat_roof(k, foot, len, span, rise, over, col, mat, wc, wm, yaw)
		_:
			k.gable_roof(foot, len, span, rise, over, thick, col, mat, wc, wm, yaw)


# --- the town house builder -------------------------------------------------------------------------------


static func _slots(fw: float) -> int:
	return clampi(roundi(fw / 0.26), 1, 4)


static func _door_x(p: Dictionary, w: float) -> float:
	var n := _slots(w)
	var j := 0
	match str(p.get("door", "r")):
		"l":
			j = 0
		"c":
			j = n / 2
		_:
			j = n - 1
	return -w / 2.0 + w * (j + 0.5) / n


## A house of one or more storeys: timber frame, plaster, stone, brick, log or wattle walls, jetties,
## any roof form, dormers, chimney, porch, lean-to, side wing. See the rows for the parameters.
static func _town(k: Kit, p: Dictionary) -> float:
	var w: float = p.get("w", 0.7)
	var d: float = p.get("d", 0.66)
	var n: int = p.get("n", 2)
	var sh: float = p.get("sh", 0.26)
	var top_sh: float = p.get("top_sh", 1.0)
	var jet: float = p.get("jet", 0.0)
	var jet_all: bool = p.get("jet_all", false)
	var plh: float = p.get("plinth", 0.06)
	var wall: String = p.get("wall", "frame")
	var pat: String = p.get("pat", "braces")
	var pl: Color = _pal(PAL_PL, p.get("pl", "cream"), PLASTER_C)
	var tm: Color = _pal(PAL_TM, p.get("tm", "brown"), TIMBER_C)
	var stc: Color = _pal(PAL_ST, p.get("st", "grey"), STONE_C)
	var trim: Color = _pal(TRIM, p.get("trim", "white"), TIMBER_C) if wall == "log" else tm
	var gf: bool = p.get("gf", false)
	var form: String = p.get("roof", "gable")
	var rise: float = p.get("rise", 0.4)
	var rd := _rdef(str(p.get("rm", "slate")))
	var rmat: int = rd[0]
	var rcol: Color = rd[1]
	var over: float = p.get("over", rd[2])
	var thick: float = rd[3]
	var winstyle: String = p.get("win", "shutters")
	var front_only: bool = p.get("front_only", false)
	var sides: String = p.get("sides", "lr")
	k.push(Kit.at(Vector3(p.get("ox", 0.0), 0, p.get("oz", 0.0))))
	var wc := pl
	var wm := Kit.PLASTER
	match wall:
		"stone", "mixed":
			wc = stc
			wm = Kit.STONE
		"brick":
			wc = Color(0.62, 0.38, 0.28)
			wm = Kit.BRICK
		"log":
			wc = LOG_C
			wm = Kit.TIMBER
		"wattle":
			wc = pl.darkened(0.14)
	if plh > 0.0:
		k.box(Vector3(0, 0, 0), Vector3(w + 0.04, plh, d + 0.04), STONE_D, Kit.STONE)
	var y := plh
	var wt := w
	var dt := d
	var zt := 0.0
	var door_x := _door_x(p, w)
	for i in n:
		var hi := sh * (top_sh if i == n - 1 and n > 1 else 1.0)
		var wi := w + (jet * 2.0 * i if jet_all else 0.0)
		var di := d + jet * i
		var zi := jet * i * 0.5
		var low_stone := wall == "mixed" and i == 0
		var mat_i := Kit.STONE if low_stone else wm
		var col_i := stc if low_stone else wc
		if i > 0 and jet > 0.0:
			k.box(Vector3(0, y - 0.034, zi), Vector3(wi + 0.012, 0.034, di + 0.012), tm, Kit.TIMBER)
		k.box(Vector3(0, y, zi), Vector3(wi, hi, di), col_i, mat_i)
		if not (wall == "frame" or (wall == "mixed" and i > 0)):
			# quoins, or corner posts on wattle and log walls
			var qc := stc.lightened(0.15) if (wall == "stone" or low_stone) else (tm if wall == "wattle" else wc.darkened(0.2))
			var qm := Kit.STONE if (wall == "stone" or low_stone) else Kit.TIMBER
			for qx: float in [-1.0, 1.0]:
				for qz: float in [-1.0, 1.0]:
					k.box(Vector3(qx * (wi / 2.0 - 0.012), y, zi + qz * (di / 2.0 - 0.012)), Vector3(0.05, hi, 0.05), qc, qm)
		var faces := [[0.0, Vector3(0, y, zi + di / 2.0), wi], [PI, Vector3(0, y, zi - di / 2.0), wi],
			[PI / 2.0, Vector3(wi / 2.0, y, zi), di], [-PI / 2.0, Vector3(-wi / 2.0, y, zi), di]]
		for fi in 4:
			var f: Array = faces[fi]
			var fw: float = f[2]
			if front_only and (fi == 1 or (fi == 2 and not sides.contains("r")) or (fi == 3 and not sides.contains("l"))):
				continue
			k.push(Kit.at(f[1], f[0]))
			var timber_wall := (wall == "frame" or wall == "wattle" or (wall == "mixed" and i > 0)) and pat != "none"
			if timber_wall:
				_pattern(k, fw, hi, pat if fi == 0 else ("panels" if pat == "close" else pat), tm)
			elif wall == "log":
				_logs(k, fw, hi, wc)
			# joist ends under a jetty
			if i > 0 and jet > 0.0 and fi == 0:
				pass
			var slots := _slots(fw) if fi == 0 else (1 if fw > 0.38 else 0)
			if fi == 1:
				slots = 1 if fw > 0.38 else 0
			var ww := clampf(fw / maxf(slots, 1) * 0.4, 0.07, 0.12)
			var wh := hi * 0.42
			for j in slots:
				var sx := -fw / 2.0 + fw * (j + 0.5) / slots
				if fi == 0 and i == 0 and absf(sx - door_x) < 0.001:
					continue
				var style := winstyle
				if winstyle == "mix":
					style = "shutters" if (j + i) % 2 == 0 else "lattice"
				_win2(k, sx, hi * 0.56, ww, wh, trim if wall == "log" else (stc.lightened(0.15) if style == "stone" or style == "arch" else tm), style)
			if fi == 0 and i == 0:
				var arch := winstyle == "arch" or wall == "stone"
				_door2(k, door_x, 0.14, minf(0.21, hi * 0.8), trim if wall == "log" else (stc.lightened(0.18) if wall != "frame" else tm),
					Color(0.38, 0.24, 0.14), arch, plh > 0.0 or wall != "frame")
			k.pop()
		if jet > 0.0 and i > 0:
			# joist ends peeping out below the jetty beam, along the front
			var m := maxi(3, int(wi / 0.1))
			k.push(Kit.at(Vector3(0, y - 0.075, zi + di / 2.0)))
			for j in m:
				var jx := -wi / 2.0 + 0.05 + (wi - 0.1) * j / maxf(m - 1, 1)
				_plate(k, jx - 0.014, 0.0, jx + 0.014, 0.04, tm, Kit.TIMBER, -0.002 - jet * 0.5)
			k.pop()
		y += hi
		wt = wi
		dt = di
		zt = zi
	var y0 := y
	# --- cross wing: a gabled bay thrust out of the front
	var wing: bool = p.get("cross", false)
	if wing:
		var ww2 := wt * 0.42
		var wx: float = (wt * 0.5 - ww2 * 0.5 - 0.02) * (1.0 if str(p.get("wing_side", "l")) == "r" else -1.0)
		var pz := 0.1
		var wd := dt / 2.0 + pz
		var wcz := zt + (dt / 2.0 + pz) / 2.0 - dt / 4.0 * 0.0
		wcz = zt + dt / 4.0 + pz / 2.0
		var yy := plh
		for i in n:
			var hi := sh * (top_sh if i == n - 1 and n > 1 else 1.0)
			k.box(Vector3(wx, yy, wcz), Vector3(ww2, hi, wd), wc, wm)
			k.push(Kit.at(Vector3(wx, yy, wcz + wd / 2.0)))
			if wall == "frame" or wall == "wattle":
				_pattern(k, ww2, hi, pat, tm)
			_win2(k, 0.0, hi * 0.56, 0.09, hi * 0.42, tm, winstyle if winstyle != "mix" else "shutters")
			k.pop()
			yy += hi
		_roof(k, "gable", Vector3(wx, yy, wcz), wd, ww2, rise * 0.7, over, thick, rcol, rmat, wc, wm, true)
	# --- the main roof
	var ridge_z := gf
	if form == "hip":
		ridge_z = dt > wt
	var span := wt if ridge_z else dt
	var rlen := dt if ridge_z else wt
	if form == "cat":
		ridge_z = false
		span = dt
		rlen = wt
	var roof_over := over
	if p.get("step", false):
		roof_over = 0.01
	_roof(k, form, Vector3(0, y0, zt), rlen, span, rise, roof_over, thick, rcol, rmat, wc, wm, ridge_z)
	# --- gable-end work on a street-facing gable
	if ridge_z and form != "hip":
		_gable_work(k, p, y0, zt, wt, dt, rise, roof_over, tm, trim, wc, wm, wall, pat, stc)
	# --- dormers on an eaves-to-street roof
	var dorm: int = p.get("dorm", 0)
	if dorm > 0 and not ridge_z and form != "cat":
		for j in dorm:
			var dx := -wt / 2.0 + wt * (j + 0.5) / dorm
			var zf := zt + dt * 0.18
			var yf := y0 + rise * (1.0 - (dt * 0.18) / (dt / 2.0)) * 1.0 - 0.0
			k.push(Kit.at(Vector3(dx, yf, zf)))
			k.box(Vector3(0, -0.03, 0.0), Vector3(0.14, 0.16, 0.14), wc, wm)
			k.push(Kit.at(Vector3(0, 0, 0.07)))
			_win2(k, 0.0, 0.04, 0.07, 0.09, tm, "shutters")
			k.pop()
			k.wedge(Vector3(0, 0.13, 0.0), 0.16, 0.17, 0.08, rcol, rmat, PI / 2.0)
			k.pop()
	# --- chimney
	var chim: String = p.get("chim", "ridge")
	var brick := Color(0.62, 0.45, 0.36)
	if chim == "ridge" or chim == "two":
		var cx := wt * 0.22
		if ridge_z:
			k.chimney(Vector3(0, y0 + rise * 0.55, zt - dt * 0.2), 0.1, rise * 0.45 + 0.13, brick, Kit.BRICK)
		else:
			k.chimney(Vector3(cx, y0 + rise * (0.55 if form != "cat" else 0.45), zt + (span * 0.12 if form == "cat" else 0.0)), 0.1, rise * 0.45 + 0.13, brick, Kit.BRICK)
			if chim == "two":
				k.chimney(Vector3(-cx, y0 + rise * 0.55, zt), 0.09, rise * 0.45 + 0.1, brick, Kit.BRICK)
	elif chim == "gable":
		var gx := wt / 2.0 + 0.045
		k.box(Vector3(gx, 0, zt), Vector3(0.1, y0 + rise * 0.55, 0.16), stc, Kit.STONE)
		k.box(Vector3(gx, y0 + rise * 0.55, zt), Vector3(0.1, rise * 0.4 + 0.08, 0.1), stc, Kit.STONE)
		k.box(Vector3(gx, y0 + rise * 0.95 + 0.08, zt), Vector3(0.13, 0.03, 0.13), stc.darkened(0.1), Kit.STONE)
	# --- porch over the door
	if p.get("porch", false) and jet == 0.0:
		var pzf := d / 2.0
		for s: float in [-1.0, 1.0]:
			k.box(Vector3(door_x + s * 0.11, 0, pzf + 0.14), Vector3(0.03, 0.24, 0.03), tm, Kit.TIMBER)
		k.wedge(Vector3(door_x, 0.24, pzf + 0.08), 0.32, 0.3, 0.1, rcol, rmat)
	# --- lean-to shed on one side
	var lean := str(p.get("lean", ""))
	if lean != "":
		var s := 1.0 if lean == "r" else -1.0
		var lw := 0.2
		var lh := sh * 0.78
		var ld := dt * 0.82
		k.box(Vector3(s * (w / 2.0 + lw / 2.0), 0, zt), Vector3(lw, lh, ld), wc.darkened(0.06), wm if wall != "frame" else Kit.TIMBER)
		_shed(k, s * (w / 2.0 - 0.01), s * (w / 2.0 + lw + 0.05), zt - ld / 2.0 - 0.03, zt + ld / 2.0 + 0.03, lh + 0.08, lh - 0.02, rcol, rmat)
	k.pop()
	# --- an outbuilding (barn) beside the house
	if p.get("barn", false):
		var bx: float = p.get("barn_x", 0.3)
		var bw := 0.38
		var bd := 0.5
		var bh := 0.2
		k.box(Vector3(bx, 0, -0.05), Vector3(bw, bh, bd), Color(0.5, 0.36, 0.22), Kit.TIMBER)
		k.push(Kit.at(Vector3(bx, 0, -0.05 + bd / 2.0)))
		_plate(k, -0.07, 0.0, 0.07, 0.15, Color(0.25, 0.17, 0.11), Kit.DARK, 0.006)
		k.pop()
		_roof(k, "gable", Vector3(bx, bh, -0.05), bd, bw, 0.2, 0.05, 0.035, rcol, rmat, Color(0.5, 0.36, 0.22), Kit.TIMBER, true)
	# --- a few things in the yard
	var ex: Array = p.get("extras", [])
	var spots := [Vector2(-0.41, 0.4), Vector2(0.38, 0.43), Vector2(-0.38, -0.4), Vector2(0.4, -0.38)]
	for e in ex.size():
		var sp: Vector2 = spots[e % 4]
		_extra(k, str(ex[e]), sp.x, sp.y)
	return y0


## Work on a gable that faces the street: a window and ties in the triangle, stepped parapet,
## barge boards with carved teeth, a horse on the ridge, or crucks.
static func _gable_work(k: Kit, p: Dictionary, y0: float, zt: float, wt: float, dt: float, rise: float,
		over: float, tm: Color, trim: Color, wc: Color, wm: int, wall: String, pat: String, stc: Color) -> void:
	for side: float in [1.0, -1.0]:
		k.push(Kit.at(Vector3(0, y0, zt + side * dt / 2.0), 0.0 if side > 0.0 else PI))
		var half := wt / 2.0
		if (wall == "frame" or wall == "wattle" or wall == "mixed") and pat != "none":
			var yc := rise * 0.32
			var xc := half * (1.0 - yc / rise)
			_strip(k, Vector2(-xc, yc), Vector2(xc, yc), 0.024, tm)
			_strip(k, Vector2(0, yc), Vector2(0, rise - 0.04), 0.024, tm)
			if pat == "close" or pat == "cross":
				for s: float in [-1.0, 1.0]:
					_strip(k, Vector2(s * xc * 0.5, yc), Vector2(s * xc * 0.5, rise * 0.62), 0.02, tm)
			_win2(k, 0.0, rise * 0.14, 0.08, 0.1, tm, "shutters")
		elif wall == "log":
			var rows := 5
			for r in range(1, rows):
				var yy := rise * r / rows
				var xx := half * (1.0 - yy / rise)
				_strip(k, Vector2(-xx, yy), Vector2(xx, yy), 0.012, wc.darkened(0.35), Kit.DARK, 0.004)
			_win2(k, 0.0, rise * 0.2, 0.07, 0.09, trim, "frame")
		else:
			_win2(k, 0.0, rise * 0.15, 0.08, 0.1, stc.lightened(0.15), "arch")
		if p.get("carve", false):
			# carved barge boards along both slopes
			for s: float in [-1.0, 1.0]:
				var drop := over * rise / maxf(half, 0.001)
				var ex := half + over
				_strip(k, Vector2(s * ex, -drop), Vector2(0, rise + 0.03), 0.034, trim, Kit.PAINT, over + 0.012)
				for t in 5:
					var f := 0.1 + t * 0.17
					var bx := s * (ex * (1.0 - f))
					var by := -drop + (rise + 0.03 + drop) * f - 0.05
					_plate(k, bx - 0.012, by, bx + 0.012, by + 0.035, trim.darkened(0.15), Kit.PAINT, over + 0.012)
		if p.get("cruck", false):
			var sh2: float = p.get("sh", 0.17)
			for s: float in [-1.0, 1.0]:
				var pts := [Vector2(s * wt * 0.49, -sh2), Vector2(s * wt * 0.44, 0.0), Vector2(s * wt * 0.34, rise * 0.4),
					Vector2(s * wt * 0.16, rise * 0.78), Vector2(0, rise * 0.97)]
				for q in pts.size() - 1:
					_strip(k, pts[q], pts[q + 1], 0.036, tm, Kit.TIMBER, 0.012)
			_strip(k, Vector2(-wt * 0.36, rise * 0.34), Vector2(wt * 0.36, rise * 0.34), 0.026, tm, Kit.TIMBER, 0.012)
		k.pop()
	if p.get("step", false):
		var steps := 3
		for zs: float in [-1.0, 1.0]:
			for i in steps:
				var wd := wt * (1.0 - float(i) / (steps + 0.4)) * 0.98
				k.box(Vector3(0, y0 + rise * i / (steps + 0.3) * 0.9, zt + zs * (dt / 2.0 - 0.03)), Vector3(wd, rise * 0.9 / (steps + 0.3) + 0.01, 0.07), wc, wm)
	if p.get("hoist", false):
		k.box(Vector3(0, y0 + rise * 0.3, zt + dt / 2.0), Vector3(0.035, 0.035, 0.14), tm, Kit.TIMBER)
		k.rod(Vector3(0, y0 + rise * 0.3, zt + dt / 2.0 + 0.06), Vector3(0, y0 + rise * 0.3 - 0.1, zt + dt / 2.0 + 0.08), 0.008, tm, Kit.TIMBER)
	if p.get("konek", false):
		var kz := zt + dt / 2.0 + over + 0.02
		k.box(Vector3(0, y0 + rise * 0.93, kz - 0.06), Vector3(0.05, 0.07, 0.14), LOG_C.darkened(0.1), Kit.TIMBER)
		k.box(Vector3(0, y0 + rise * 0.93 + 0.06, kz), Vector3(0.045, 0.05, 0.06), LOG_C.darkened(0.1), Kit.TIMBER)


# --- Viking longhouses, pit-houses and storehouses -----------------------------------------------


const PAL_WOOD := {"oak": Color(0.45, 0.31, 0.19), "grey": Color(0.52, 0.46, 0.38), "dark": Color(0.33, 0.22, 0.14),
	"tar": Color(0.24, 0.17, 0.12), "red": Color(0.55, 0.22, 0.15), "pale": Color(0.62, 0.50, 0.34)}


## A longhouse: straight-walled with a gable roof, or boat-shaped (bowed ends) under a hipped one.
static func _long(k: Kit, p: Dictionary) -> void:
	var len: float = p.get("L", 0.9)
	var wid: float = p.get("W", 0.4)
	var wh: float = p.get("wh", 0.2)
	var bow: float = p.get("bow", 0.0)
	var rise: float = p.get("rise", 0.32)
	var wood: Color = _pal(PAL_WOOD, p.get("wood", "oak"), Color(0.45, 0.31, 0.19))
	var dark := wood.darkened(0.35)
	var red := Color(0.62, 0.20, 0.14)
	var rd := _rdef(str(p.get("rm", "shingle")))
	var rmat: int = rd[0]
	var rcol: Color = rd[1]
	var over: float = p.get("over", rd[2] + 0.02)
	var thick: float = rd[3]
	var plank: bool = p.get("plank", true)
	var h2 := wid / 2.0
	var l2 := len / 2.0
	k.box(Vector3(0, 0, 0), Vector3(len + 0.03, 0.045, wid + 0.03), STONE_D, Kit.STONE)
	if bow > 0.0:
		var pts := [Vector2(-l2, 0), Vector2(-l2 + bow, -h2), Vector2(l2 - bow, -h2), Vector2(l2, 0), Vector2(l2 - bow, h2), Vector2(-l2 + bow, h2)]
		for i in 6:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % 6]
			k.quad(Vector3(a.x, 0.04, a.y), Vector3(b.x, 0.04, b.y), Vector3(b.x, 0.04 + wh, b.y), Vector3(a.x, 0.04 + wh, a.y), wood, Kit.TIMBER,
				Vector3(0, wh * 0.5, 0))
	else:
		k.box(Vector3(0, 0.04, 0), Vector3(len, wh, wid), wood, Kit.TIMBER)
	# plank battens and a door on the long front
	var flen := len - 2.0 * bow
	k.push(Kit.at(Vector3(0, 0.04, h2)))
	if plank:
		var n := maxi(4, int(flen / 0.09))
		for i in n + 1:
			var x := -flen / 2.0 + flen * i / n
			_strip(k, Vector2(x, 0.0), Vector2(x, wh), 0.016, dark, Kit.TIMBER, 0.004)
	var dx: float = p.get("door", 0.0) * flen / 2.0
	_door2(k, dx, 0.12, wh * 0.82, red if p.get("paint", true) else dark, wood.darkened(0.25), false, false)
	var nw := int(p.get("win", 2))
	for j in nw:
		var wx := -flen / 2.0 + flen * (j + 0.5) / nw - 0.0
		if absf(wx - dx) < 0.14:
			continue
		_win2(k, wx, wh * 0.62, 0.07, 0.05, dark, "frame")
	k.pop()
	if p.get("posts", true):
		var m := maxi(3, int(flen / 0.2))
		for s: float in [-1.0, 1.0]:
			for i in m + 1:
				var x := -flen / 2.0 + flen * i / m
				k.rod(Vector3(x, 0.04, s * (h2 + 0.075)), Vector3(x, 0.04 + wh * 1.05, s * (h2 + 0.01)), 0.016, dark, Kit.TIMBER)
	var form := "hip" if bow > 0.0 else "gable"
	var ry := 0.04 + wh
	if form == "hip":
		k.hip_roof(Vector3(0, ry, 0), len, wid, rise, over, thick, rcol, rmat)
	else:
		k.gable_roof(Vector3(0, ry, 0), len, wid, rise, over, thick, rcol, rmat, wood, Kit.TIMBER)
	if rmat != Kit.LEAF and p.get("turf_ridge", true):
		k.box(Vector3(0, ry + rise + thick * 0.6, 0), Vector3(len * 0.9, 0.035, 0.07), Color(0.32, 0.46, 0.22), Kit.LEAF)
	if p.get("horns", true):
		for s: float in [-1.0, 1.0]:
			var x := s * (len / 2.0 + over * 0.8)
			k.rod(Vector3(x, ry + rise * 0.55, -0.08), Vector3(x + s * 0.03, ry + rise + 0.07, 0.07), 0.013, dark, Kit.TIMBER)
			k.rod(Vector3(x, ry + rise * 0.55, 0.08), Vector3(x + s * 0.03, ry + rise + 0.07, -0.07), 0.013, dark, Kit.TIMBER)
	if p.get("louvre", true):
		var lx: float = p.get("louvre_x", 0.1)
		k.box(Vector3(lx, ry + rise * 0.85, 0), Vector3(0.13, 0.07, 0.1), dark, Kit.TIMBER)
		k.gable_roof(Vector3(lx, ry + rise * 0.85 + 0.07, 0), 0.13, 0.1, 0.06, 0.015, 0.015, rcol.darkened(0.2), rmat, dark, Kit.TIMBER)
	var annex: float = p.get("annex", 99.0)
	if annex < 50.0:
		var aw := 0.24
		k.box(Vector3(annex, 0.0, -h2 - 0.09), Vector3(aw, wh * 0.85, 0.2), wood.darkened(0.1), Kit.TIMBER)
		k.gable_roof(Vector3(annex, wh * 0.85, -h2 - 0.09), aw, 0.2, 0.12, 0.03, 0.03, rcol, rmat, wood, Kit.TIMBER)
	for e in (p.get("extras", []) as Array).size():
		var ex: Array = p.get("extras", [])
		var sp: Vector2 = [Vector2(-0.4, 0.38), Vector2(0.38, 0.4), Vector2(-0.4, -0.36), Vector2(0.4, -0.36)][e % 4]
		_extra(k, str(ex[e]), sp.x, sp.y)


## A turf-roofed pit-house: the roof comes nearly to the ground, the door in the gable.
static func _pit(k: Kit, p: Dictionary) -> void:
	var len: float = p.get("L", 0.78)
	var wid: float = p.get("W", 0.6)
	var rise: float = p.get("rise", 0.32)
	var wood: Color = _pal(PAL_WOOD, p.get("wood", "oak"), Color(0.45, 0.31, 0.19))
	var rd := _rdef(str(p.get("rm", "turf")))
	var rmat: int = rd[0]
	var rcol: Color = rd[1]
	k.box(Vector3(0, 0, 0), Vector3(wid + 0.06, 0.05, len + 0.06), Color(0.50, 0.42, 0.30), Kit.EARTH)
	k.box(Vector3(0, 0.05, 0), Vector3(wid, 0.07, len), wood, Kit.TIMBER)
	k.gable_roof(Vector3(0, 0.12, 0), len, wid, rise, 0.05, 0.06, rcol, rmat, wood, Kit.TIMBER, PI / 2.0)
	# gable end: boards, a low door and a smoke-hole chimney
	k.push(Kit.at(Vector3(0, 0.12, len / 2.0)))
	for i in 7:
		var x := -wid / 2.0 + wid * (i + 0.5) / 7.0
		var hgt := rise * (1.0 - absf(x) / (wid / 2.0)) * 0.9
		_strip(k, Vector2(x, 0.0), Vector2(x, hgt), 0.014, wood.darkened(0.3), Kit.TIMBER, 0.004)
	_door2(k, 0.0, 0.14, 0.2, wood.darkened(0.45), Color(0.18, 0.12, 0.08), false, false)
	k.pop()
	k.box(Vector3(0, 0.12 + rise * 0.78, -0.12), Vector3(0.11, 0.1, 0.11), wood.darkened(0.3), Kit.TIMBER)
	k.box(Vector3(0, 0.12 + rise * 0.78 + 0.1, -0.12), Vector3(0.14, 0.02, 0.14), wood.darkened(0.45), Kit.TIMBER)
	for s: float in [-1.0, 1.0]:   # turf banks and stones along the eaves
		k.box(Vector3(s * (wid / 2.0 + 0.04), 0.0, 0.0), Vector3(0.08, 0.07, len - 0.1), Color(0.34, 0.44, 0.22), Kit.LEAF)
	for i in 3:
		k.box(Vector3(0, 0.0, len / 2.0 + 0.07 + i * 0.07), Vector3(0.14, 0.03 - i * 0.008, 0.06), Color(0.58, 0.56, 0.52), Kit.STONE)
	for e in (p.get("extras", []) as Array).size():
		var ex: Array = p.get("extras", [])
		var sp: Vector2 = [Vector2(-0.38, 0.4), Vector2(0.38, 0.38)][e % 2]
		_extra(k, str(ex[e]), sp.x, sp.y)


## A stave-built storehouse raised on posts, its upper gallery overhanging, a horned turf roof.
static func _stabbur(k: Kit, p: Dictionary) -> void:
	var w: float = p.get("w", 0.5)
	var d: float = p.get("d", 0.46)
	var ph: float = p.get("post", 0.12)
	var wood: Color = _pal(PAL_WOOD, p.get("wood", "dark"), Color(0.33, 0.22, 0.14))
	var rd := _rdef(str(p.get("rm", "turf")))
	var rmat: int = rd[0]
	var rcol: Color = rd[1]
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 0.0, 1.0]:
			if z == 0.0 and w < 0.55:
				continue
			k.rod(Vector3(x * w * 0.46, 0.0, z * d * 0.44), Vector3(x * w * 0.46, ph + 0.02, z * d * 0.44), 0.022, wood.darkened(0.2), Kit.TIMBER)
			k.box(Vector3(x * w * 0.46, 0, z * d * 0.44), Vector3(0.06, 0.02, 0.06), STONE_D, Kit.STONE)
	var h1 := 0.18
	k.box(Vector3(0, ph, 0), Vector3(w, h1, d), wood, Kit.TIMBER)
	var ov := 0.05
	k.box(Vector3(0, ph + h1, 0), Vector3(w + ov * 2.0, 0.025, d + ov * 2.0), wood.darkened(0.3), Kit.TIMBER)
	var h2 := 0.17
	k.box(Vector3(0, ph + h1 + 0.025, 0), Vector3(w + ov * 2.0 - 0.03, h2, d + ov * 2.0 - 0.03), wood.lightened(0.05), Kit.TIMBER)
	# plank seams on the front, both storeys, a door up a ladder and a carved lintel
	k.push(Kit.at(Vector3(0, ph, d / 2.0)))
	for i in 7:
		var x := -w / 2.0 + w * (i + 0.5) / 7.0
		_strip(k, Vector2(x, 0.0), Vector2(x, h1), 0.012, wood.darkened(0.4), Kit.TIMBER, 0.004)
	_door2(k, 0.0, 0.11, 0.14, Color(0.62, 0.20, 0.14), wood.darkened(0.5), false, false)
	k.pop()
	k.push(Kit.at(Vector3(0, ph + h1 + 0.025, d / 2.0 + ov - 0.015)))
	for i in 8:
		var x := -w / 2.0 - ov + (w + 2.0 * ov) * (i + 0.5) / 8.0
		_strip(k, Vector2(x, 0.0), Vector2(x, h2), 0.012, wood.darkened(0.4), Kit.TIMBER, 0.004)
	_win2(k, 0.0, h2 * 0.5, 0.06, 0.06, Color(0.62, 0.20, 0.14), "frame")
	k.pop()
	var ry := ph + h1 + 0.025 + h2
	k.gable_roof(Vector3(0, ry, 0), w + ov * 2.0, d + ov * 2.0 - 0.04, p.get("rise", 0.24), 0.05, 0.05, rcol, rmat, wood, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		var x := s * (w / 2.0 + ov + 0.04)
		k.rod(Vector3(x, ry + 0.05, -0.07), Vector3(x + s * 0.025, ry + 0.24, 0.06), 0.012, wood.darkened(0.3), Kit.TIMBER)
		k.rod(Vector3(x, ry + 0.05, 0.07), Vector3(x + s * 0.025, ry + 0.24, -0.06), 0.012, wood.darkened(0.3), Kit.TIMBER)
	# the ladder
	for s: float in [-1.0, 1.0]:
		k.rod(Vector3(0.12 + s * 0.025, 0.0, d / 2.0 + 0.1), Vector3(0.12 + s * 0.025, ph + 0.1, d / 2.0 + 0.02), 0.006, wood, Kit.TIMBER)
	for e in (p.get("extras", []) as Array).size():
		var ex: Array = p.get("extras", [])
		var sp: Vector2 = [Vector2(-0.38, 0.38), Vector2(0.38, 0.38)][e % 2]
		_extra(k, str(ex[e]), sp.x, sp.y)


# --- roundhouses --------------------------------------------------------------------------------------


## A Celtic roundhouse: low wall of wattle, stone or posts under a tall conical thatch.
static func _round(k: Kit, p: Dictionary) -> void:
	var r: float = p.get("r", 0.34)
	var wh: float = p.get("wh", 0.18)
	var ch: float = p.get("ch", 0.42)
	var wall: String = p.get("wall", "wattle")
	var rd := _rdef(str(p.get("rm", "thatch")))
	var rmat: int = rd[0]
	var rcol: Color = rd[1]
	var over: float = p.get("over", 0.1)
	var pl: Color = _pal(PAL_PL, p.get("pl", "umber"), Color(0.72, 0.62, 0.48))
	var sides := 12
	var wc := pl
	var wm := Kit.PLASTER
	if wall == "stone":
		wc = _pal(PAL_ST, p.get("st", "grey"), STONE_C)
		wm = Kit.STONE
	elif wall == "post":
		wc = Color(0.45, 0.31, 0.19)
		wm = Kit.TIMBER
	k.push(Kit.at(Vector3.ZERO, -PI / sides))
	k.frustum(Vector3.ZERO, r + 0.03, r + 0.03, 0.04, STONE_D, Kit.STONE, sides, false)
	k.frustum(Vector3(0, 0.04, 0), r, r, wh, wc, wm, sides, false)
	if wall == "wattle":
		for t: float in [0.35, 0.7]:
			k.frustum(Vector3(0, 0.04 + wh * t, 0), r * 1.01, r * 1.01, 0.014, pl.darkened(0.35), Kit.TIMBER, sides, false)
	k.frustum(Vector3(0, 0.04 + wh - 0.02, 0), r + over * 0.85, r + over * 0.8, 0.05, rcol.darkened(0.1), rmat, sides, false)
	var ry := 0.04 + wh
	if p.get("double", false):
		k.frustum(Vector3(0, ry, 0), r + over, r * 0.45, ch * 0.62, rcol, rmat, sides)
		k.frustum(Vector3(0, ry + ch * 0.6, 0), r * 0.5, 0.02, ch * 0.48, rcol.lightened(0.04), rmat, 8)
	else:
		k.frustum(Vector3(0, ry, 0), r + over, 0.02, ch, rcol, rmat, sides)
	# ridge rings: bands of thatch binding
	for t: float in [0.35, 0.65]:
		var rr := lerpf(r + over, 0.02, t)
		k.frustum(Vector3(0, ry + ch * t - 0.01, 0), rr + 0.012, rr, 0.02, rcol.darkened(0.25), Kit.THATCH, sides, false)
	k.rod(Vector3(0, ry + ch - 0.02, 0), Vector3(0, ry + ch + 0.09, 0), 0.01, Color(0.25, 0.18, 0.12), Kit.TIMBER)
	k.pop()
	# the door, in a flat patch on the front, under a thatched porch
	var ap := r * cos(PI / sides)
	k.push(Kit.at(Vector3(0, 0.04, ap)))
	_door2(k, 0.0, 0.13, wh * 0.9, Color(0.30, 0.20, 0.12), Color(0.2, 0.13, 0.08), false, false)
	k.pop()
	if p.get("porch", true):
		for s: float in [-1.0, 1.0]:
			k.rod(Vector3(s * 0.1, 0.04, ap + 0.11), Vector3(s * 0.1, 0.04 + wh * 1.0, ap + 0.11), 0.014, Color(0.4, 0.28, 0.16), Kit.TIMBER)
		k.wedge(Vector3(0, 0.04 + wh * 0.95, ap + 0.07), 0.3, 0.26, 0.09, rcol, rmat)
	if p.get("fence", false):
		var fr := r + 0.12
		k.push(Kit.at(Vector3.ZERO, -PI / 12.0))
		k.frustum(Vector3.ZERO, fr, fr, 0.06, Color(0.5, 0.42, 0.28), Kit.THATCH, 12, false)
		k.pop()
	for e in (p.get("extras", []) as Array).size():
		var ex: Array = p.get("extras", [])
		var sp: Vector2 = [Vector2(-0.41, 0.36), Vector2(0.4, 0.38), Vector2(-0.4, -0.38), Vector2(0.4, -0.4)][e % 4]
		_extra(k, str(ex[e]), sp.x, sp.y)


# --- Rus: terem and granary ----------------------------------------------------------------------------


## A terem: a log house with a gallery, and on its roof a small tower room under a tall tent roof.
static func _terem(k: Kit, p: Dictionary) -> void:
	var base: Dictionary = p.get("base", {})
	var y0 := _town(k, base)
	var rise: float = base.get("rise", 0.3)
	var trim: Color = _pal(TRIM, base.get("trim", "red"), Color(0.62, 0.2, 0.14))
	var tw: float = p.get("tw", 0.3)
	var th: float = p.get("th", 0.22)
	var ty := y0 + rise * 0.35
	var top := y0 + rise + th * 0.5
	var rd := _rdef(str(p.get("rm", "plank")))
	var rcol: Color = rd[1]
	k.box(Vector3(0, ty, base.get("tz", 0.0)), Vector3(tw, top - ty, tw), LOG_C.darkened(0.05), Kit.TIMBER)
	for fi in 4:
		var yaw := fi * PI / 2.0
		k.push(Kit.at(Vector3(0, ty, base.get("tz", 0.0)) + Vector3(sin(yaw), 0, cos(yaw)) * tw / 2.0, yaw))
		_logs(k, tw, top - ty, LOG_C)
		_win2(k, 0.0, top - ty - th * 0.45, 0.07, 0.09, trim, "arch")
		k.pop()
	var rr: float = p.get("trise", 0.48)
	k.hip_roof(Vector3(0, top, base.get("tz", 0.0)), tw, tw, rr, 0.06, 0.035, rcol, rd[0])
	k.frustum(Vector3(0, top + rr, base.get("tz", 0.0)), 0.035, 0.0, 0.08, Color(0.9, 0.75, 0.3), Kit.GOLD, 6)
	k.rod(Vector3(0, top + rr + 0.06, base.get("tz", 0.0)), Vector3(0, top + rr + 0.16, base.get("tz", 0.0)), 0.008, Color(0.9, 0.75, 0.3), Kit.GOLD)
	# a gallery across the front at the upper floor, on carved posts
	if p.get("gallery", true):
		var bd: float = base.get("d", 0.6)
		var bw: float = base.get("w", 0.6)
		var gy: float = base.get("plinth", 0.06) + base.get("sh", 0.26)
		k.box(Vector3(0, gy - 0.02, bd / 2.0 + 0.07), Vector3(bw + 0.06, 0.025, 0.14), LOG_C.darkened(0.1), Kit.TIMBER)
		for i in 5:
			var x := -bw / 2.0 + bw * i / 4.0
			k.rod(Vector3(x, gy, bd / 2.0 + 0.13), Vector3(x, gy + 0.1, bd / 2.0 + 0.13), 0.011, trim, Kit.PAINT)
		k.box(Vector3(0, gy + 0.1, bd / 2.0 + 0.13), Vector3(bw + 0.04, 0.018, 0.025), trim, Kit.PAINT)
		for s: float in [-1.0, 1.0]:
			k.rod(Vector3(s * (bw / 2.0 + 0.02), 0.0, bd / 2.0 + 0.13), Vector3(s * (bw / 2.0 + 0.02), gy - 0.02, bd / 2.0 + 0.13), 0.016, trim, Kit.PAINT)


## A log granary on stone feet, its roof of boards.
static func _granary(k: Kit, p: Dictionary) -> void:
	var w: float = p.get("w", 0.5)
	var d: float = p.get("d", 0.42)
	var ph: float = p.get("post", 0.1)
	var rd := _rdef(str(p.get("rm", "plank")))
	var trim: Color = _pal(TRIM, p.get("trim", "red"), Color(0.62, 0.2, 0.14))
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			k.frustum(Vector3(x * w * 0.4, 0, z * d * 0.4), 0.035, 0.03, ph, Color(0.58, 0.55, 0.5), Kit.STONE, 6, false)
			k.box(Vector3(x * w * 0.4, ph, z * d * 0.4), Vector3(0.1, 0.015, 0.1), Color(0.5, 0.48, 0.44), Kit.STONE)
	var h := 0.26
	k.box(Vector3(0, ph + 0.015, 0), Vector3(w, h, d), LOG_C, Kit.TIMBER)
	for fi in 4:
		var yaw := fi * PI / 2.0
		var half := (d if fi % 2 == 0 else w) / 2.0
		k.push(Kit.at(Vector3(sin(yaw), 0, cos(yaw)) * half + Vector3(0, ph + 0.015, 0), yaw))
		_logs(k, w if fi % 2 == 0 else d, h, LOG_C)
		if fi == 0:
			_door2(k, 0.0, 0.12, 0.18, trim, Color(0.25, 0.17, 0.1), false, false)
		k.pop()
	k.gable_roof(Vector3(0, ph + 0.015 + h, 0), w, d, p.get("rise", 0.24), 0.07, 0.04, rd[1], rd[0], LOG_C, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		k.rod(Vector3(0.12 + s * 0.03, 0.0, d / 2.0 + 0.12), Vector3(0.12 + s * 0.03, ph + 0.12, d / 2.0 + 0.01), 0.007, LOG_C, Kit.TIMBER)
	for e in (p.get("extras", []) as Array).size():
		var ex: Array = p.get("extras", [])
		var sp: Vector2 = [Vector2(-0.38, 0.38), Vector2(0.38, 0.4)][e % 2]
		_extra(k, str(ex[e]), sp.x, sp.y)


# --- the rows: every kind and what it is made of --------------------------------------------------------


static func _rows() -> Dictionary:
	if not _rows_cache.is_empty():
		return _rows_cache
	var t := {}
	# medieval timber-framed town houses
	t["house_med_timber_1"] = {"fam": "town", "w": 0.62, "d": 0.62, "n": 2, "jet": 0.07, "pat": "close", "gf": true,
		"rise": 0.5, "rm": "slate", "pl": "cream", "tm": "brown", "door": "l"}
	t["house_med_timber_2"] = {"fam": "town", "w": 0.84, "d": 0.54, "n": 2, "jet": 0.05, "pat": "braces", "rise": 0.36,
		"rm": "tile", "pl": "ochre", "tm": "black", "dorm": 2, "chim": "two", "door": "c", "extras": ["barrel"]}
	t["house_med_timber_3"] = {"fam": "town", "w": 0.52, "d": 0.62, "n": 3, "sh": 0.24, "jet": 0.05, "pat": "cross", "gf": true,
		"rise": 0.5, "rm": "slate", "pl": "white", "tm": "blood", "door": "r"}
	t["house_med_timber_4"] = {"fam": "town", "w": 0.8, "d": 0.58, "n": 2, "pat": "braces", "rise": 0.38, "rm": "tile2",
		"pl": "pink", "tm": "brown", "cross": true, "wing_side": "l", "door": "r", "extras": ["bush"]}
	t["house_med_timber_5"] = {"fam": "town", "w": 0.82, "d": 0.56, "n": 2, "plinth": 0.1, "pat": "panels", "roof": "half",
		"rise": 0.42, "rm": "thatch", "pl": "sage", "tm": "oak", "chim": "gable", "porch": true, "door": "c", "extras": ["hay"]}
	t["house_med_timber_6"] = {"fam": "town", "w": 0.9, "d": 0.5, "n": 2, "jet": 0.06, "pat": "close", "rise": 0.34, "rm": "slate",
		"pl": "grey", "tm": "black", "dorm": 3, "chim": "two", "door": "l", "win": "mix"}
	t["house_med_timber_7"] = {"fam": "town", "w": 0.74, "d": 0.7, "n": 2, "sh": 0.22, "pat": "braces", "roof": "cat", "rise": 0.44,
		"rm": "thatch_g", "pl": "umber", "tm": "brown", "lean": "r", "extras": ["wood"]}
	t["house_med_timber_8"] = {"fam": "town", "w": 0.64, "d": 0.7, "n": 3, "sh": 0.24, "jet": 0.06, "wall": "mixed", "pat": "braces",
		"gf": true, "rise": 0.46, "rm": "shingle", "pl": "cream", "tm": "oak", "door": "c", "hoist": true}
	# stone and brick merchants
	t["house_med_stone_1"] = {"fam": "town", "w": 0.68, "d": 0.84, "n": 2, "sh": 0.3, "plinth": 0.07, "wall": "stone", "gf": true,
		"step": true, "hoist": true, "rise": 0.4, "rm": "slate", "st": "warm", "win": "arch", "door": "c"}
	t["house_med_stone_2"] = {"fam": "town", "w": 0.8, "d": 0.66, "n": 3, "sh": 0.24, "wall": "stone", "roof": "hip", "rise": 0.3,
		"rm": "slate", "st": "pale", "win": "arch", "chim": "gable", "door": "c"}
	t["house_med_stone_3"] = {"fam": "town", "w": 0.66, "d": 0.62, "n": 2, "sh": 0.27, "wall": "stone", "rise": 0.36, "rm": "shingle_g",
		"st": "grey", "porch": true, "door": "c", "lean": "l", "win": "stone", "extras": ["barrel"]}
	t["house_med_stone_4"] = {"fam": "town", "w": 0.5, "d": 0.5, "n": 3, "sh": 0.3, "wall": "stone", "roof": "hip", "rise": 0.5,
		"rm": "slate", "st": "dark", "win": "stone", "door": "c", "chim": "none"}
	t["house_med_brick_1"] = {"fam": "town", "w": 0.82, "d": 0.6, "n": 2, "wall": "brick", "rise": 0.38, "rm": "tile", "pl": "cream",
		"tm": "brown", "dorm": 2, "chim": "two", "door": "l", "win": "stone", "st": "pale", "extras": ["bush"]}
	# cruck cottages, cottages and hovels
	t["house_med_cruck_1"] = {"fam": "town", "w": 0.5, "d": 0.8, "n": 1, "sh": 0.17, "plinth": 0.04, "wall": "wattle", "pat": "panels",
		"gf": true, "cruck": true, "rise": 0.46, "rm": "thatch", "pl": "umber", "tm": "brown", "door": "c", "chim": "none", "extras": ["hay"]}
	t["house_med_cruck_2"] = {"fam": "town", "w": 0.52, "d": 0.72, "n": 1, "sh": 0.18, "plinth": 0.04, "wall": "wattle", "pat": "none",
		"gf": true, "cruck": true, "roof": "half", "rise": 0.4, "rm": "reed", "pl": "cream", "tm": "oak", "door": "c", "chim": "none", "extras": ["wood"]}
	t["house_med_cruck_3"] = {"fam": "town", "w": 0.58, "d": 0.62, "n": 1, "sh": 0.2, "plinth": 0.04, "wall": "wattle", "pat": "braces",
		"gf": true, "cruck": true, "rise": 0.44, "rm": "thatch_g", "pl": "sage", "tm": "black", "door": "r", "chim": "gable", "lean": "r"}
	t["house_med_cottage_1"] = {"fam": "town", "w": 0.72, "d": 0.5, "n": 2, "sh": 0.22, "top_sh": 0.6, "wall": "stone", "rise": 0.34,
		"rm": "shingle_g", "st": "warm", "chim": "gable", "lean": "l", "win": "stone", "door": "c", "extras": ["bush"]}
	t["house_med_cottage_2"] = {"fam": "town", "w": 0.68, "d": 0.52, "n": 1, "sh": 0.3, "wall": "stone", "st": "pale", "roof": "hip",
		"rise": 0.38, "rm": "thatch", "porch": true, "door": "c", "chim": "ridge", "win": "shutters", "extras": ["bench"]}
	t["house_med_hovel_1"] = {"fam": "town", "w": 0.5, "d": 0.44, "n": 1, "sh": 0.16, "plinth": 0.0, "wall": "wattle", "pat": "none",
		"pl": "umber", "rise": 0.22, "rm": "turf", "over": 0.06, "door": "c", "chim": "none", "extras": ["wood"]}
	t["house_med_hovel_2"] = {"fam": "town", "w": 0.46, "d": 0.5, "n": 1, "sh": 0.15, "plinth": 0.0, "wall": "wattle", "pat": "panels",
		"pl": "grey", "roof": "half", "rise": 0.26, "rm": "thatch_g", "lean": "r", "door": "l", "chim": "none", "extras": ["hay"]}
	t["house_med_hovel_3"] = {"fam": "town", "w": 0.56, "d": 0.42, "n": 1, "sh": 0.14, "plinth": 0.0, "wall": "wattle", "pat": "none",
		"pl": "cream", "roof": "cat", "rise": 0.2, "rm": "reed", "lean": "l", "door": "c", "chim": "none", "extras": ["barrel"]}
	t["house_med_farm_1"] = {"fam": "town", "w": 0.46, "d": 0.48, "n": 2, "sh": 0.22, "pat": "panels", "rise": 0.34, "rm": "tile",
		"pl": "cream", "tm": "brown", "ox": -0.26, "barn": true, "barn_x": 0.28, "door": "c", "extras": ["pen"]}
	t["house_med_farm_2"] = {"fam": "town", "w": 0.58, "d": 0.42, "n": 1, "sh": 0.26, "wall": "stone", "st": "warm", "rise": 0.36,
		"rm": "thatch", "ox": -0.22, "barn": true, "barn_x": 0.32, "door": "c", "chim": "gable", "extras": ["hay", "cart"]}
	t["house_med_farm_3"] = {"fam": "town", "w": 0.5, "d": 0.5, "n": 2, "sh": 0.2, "top_sh": 0.7, "pat": "braces", "roof": "half",
		"rise": 0.36, "rm": "shingle_g", "pl": "umber", "tm": "black", "ox": -0.2, "barn": true, "barn_x": 0.33, "door": "c", "extras": ["hay", "well"]}
	# Viking longhouses, pit-houses and storehouses
	t["house_vik_long_1"] = {"fam": "long", "L": 0.96, "W": 0.4, "wh": 0.2, "rm": "shingle", "wood": "oak", "door": 0.3, "louvre_x": 0.1}
	t["house_vik_long_2"] = {"fam": "long", "L": 0.92, "W": 0.46, "wh": 0.2, "bow": 0.14, "rise": 0.3, "rm": "turf", "wood": "grey",
		"door": -0.2, "annex": -0.15, "turf_ridge": false}
	t["house_vik_long_3"] = {"fam": "long", "L": 0.74, "W": 0.36, "wh": 0.18, "rise": 0.3, "rm": "thatch", "wood": "dark", "door": -0.3,
		"posts": false, "paint": false, "win": 1, "louvre_x": -0.05}
	t["house_vik_long_4"] = {"fam": "long", "L": 1.0, "W": 0.38, "wh": 0.2, "bow": 0.1, "rise": 0.32, "rm": "shingle_g", "wood": "tar",
		"door": 0.4, "annex": 0.2, "win": 3}
	t["house_vik_long_5"] = {"fam": "long", "L": 0.8, "W": 0.48, "wh": 0.22, "rise": 0.34, "rm": "turf", "wood": "pale", "door": 0.0,
		"win": 3, "louvre_x": 0.0, "extras": ["wood", "barrel"]}
	t["house_vik_pit_1"] = {"fam": "pit", "L": 0.78, "W": 0.6, "rise": 0.32, "rm": "turf", "wood": "oak", "extras": ["wood"]}
	t["house_vik_pit_2"] = {"fam": "pit", "L": 0.66, "W": 0.54, "rise": 0.28, "rm": "thatch_g", "wood": "dark", "extras": ["hay", "barrel"]}
	t["house_vik_store_1"] = {"fam": "stabbur", "w": 0.5, "d": 0.46, "rm": "turf", "wood": "dark"}
	t["house_vik_store_2"] = {"fam": "stabbur", "w": 0.42, "d": 0.42, "post": 0.1, "rm": "shingle", "wood": "tar", "rise": 0.28}
	t["house_vik_store_3"] = {"fam": "stabbur", "w": 0.6, "d": 0.4, "post": 0.16, "rm": "thatch", "wood": "oak", "rise": 0.22, "extras": ["barrel"]}
	# Rus izbas, terems and granaries
	t["house_rus_izba_1"] = {"fam": "town", "w": 0.5, "d": 0.62, "n": 1, "sh": 0.34, "plinth": 0.07, "wall": "log", "gf": true,
		"rise": 0.42, "rm": "plank", "carve": true, "konek": true, "trim": "blue", "porch": true, "door": "c", "chim": "none"}
	t["house_rus_izba_2"] = {"fam": "town", "w": 0.62, "d": 0.56, "n": 2, "sh": 0.26, "plinth": 0.07, "wall": "log", "gf": true,
		"rise": 0.4, "rm": "shingle", "carve": true, "konek": true, "trim": "red", "door": "l", "chim": "ridge"}
	t["house_rus_izba_3"] = {"fam": "town", "w": 0.46, "d": 0.5, "n": 1, "sh": 0.28, "plinth": 0.05, "wall": "log", "rise": 0.3,
		"rm": "thatch_g", "trim": "green", "door": "l", "chim": "ridge", "extras": ["wood"]}
	t["house_rus_izba_4"] = {"fam": "town", "w": 0.72, "d": 0.5, "n": 1, "sh": 0.3, "plinth": 0.06, "wall": "log", "roof": "half",
		"rise": 0.34, "rm": "plank", "trim": "ochre", "door": "c", "porch": true, "chim": "ridge", "extras": ["bench"]}
	t["house_rus_izba_5"] = {"fam": "town", "w": 0.56, "d": 0.72, "n": 2, "sh": 0.3, "top_sh": 0.6, "plinth": 0.06, "wall": "log",
		"gf": true, "rise": 0.4, "rm": "plank", "carve": true, "konek": true, "trim": "blue", "lean": "r", "door": "c", "chim": "none", "extras": ["barrel"]}
	t["house_rus_farm_1"] = {"fam": "town", "w": 0.44, "d": 0.5, "n": 1, "sh": 0.28, "plinth": 0.05, "wall": "log", "rise": 0.3,
		"rm": "thatch_g", "trim": "green", "ox": -0.26, "barn": true, "barn_x": 0.28, "door": "c", "chim": "ridge", "extras": ["hay", "well"]}
	t["house_rus_terem_1"] = {"fam": "terem", "base": {"w": 0.6, "d": 0.56, "n": 2, "sh": 0.24, "plinth": 0.07, "wall": "log", "gf": true,
		"rise": 0.28, "rm": "plank", "carve": true, "trim": "red", "door": "c", "chim": "none"}, "tw": 0.3, "th": 0.2, "trise": 0.5, "rm": "shingle"}
	t["house_rus_terem_2"] = {"fam": "terem", "base": {"w": 0.74, "d": 0.5, "n": 2, "sh": 0.22, "plinth": 0.07, "wall": "log",
		"rise": 0.3, "rm": "plank", "trim": "blue", "door": "c", "chim": "none", "win": "shutters"}, "tw": 0.26, "th": 0.24, "trise": 0.56, "rm": "plank"}
	t["house_rus_granary_1"] = {"fam": "granary", "w": 0.5, "d": 0.42, "rm": "plank", "trim": "red"}
	t["house_rus_granary_2"] = {"fam": "granary", "w": 0.42, "d": 0.5, "rm": "shingle", "trim": "blue", "rise": 0.28, "post": 0.13, "extras": ["barrel"]}
	# Celtic roundhouses
	t["house_celt_round_1"] = {"fam": "round", "r": 0.34, "wh": 0.18, "ch": 0.42, "wall": "wattle", "rm": "thatch", "pl": "umber", "extras": ["wood"]}
	t["house_celt_round_2"] = {"fam": "round", "r": 0.4, "wh": 0.2, "ch": 0.5, "wall": "stone", "rm": "thatch_g", "st": "warm", "double": false}
	t["house_celt_round_3"] = {"fam": "round", "r": 0.3, "wh": 0.18, "ch": 0.5, "wall": "post", "rm": "reed", "double": true, "fence": true}
	t["house_celt_round_4"] = {"fam": "round", "r": 0.36, "wh": 0.17, "ch": 0.4, "wall": "wattle", "pl": "cream", "rm": "thatch", "fence": true,
		"extras": ["hay", "barrel"]}
	t["house_celt_round_5"] = {"fam": "round", "r": 0.32, "wh": 0.2, "ch": 0.44, "wall": "stone", "st": "dark", "rm": "turf", "porch": false,
		"extras": ["bush"]}
	var yard := ["bush", "wood", "barrel", "hay", "bench", "fence", "cart", "pen"]
	for name: String in t.keys():
		var row: Dictionary = t[name]
		if str(row.get("fam", "town")) != "terem" and not row.has("extras"):
			var h := absi(name.hash())
			row["extras"] = [yard[h % yard.size()], yard[(h / 8) % yard.size()]]
	_rows_cache = t
	return t


## Builds one table row into `k`.
static func _from_row(k: Kit, p: Dictionary) -> void:
	match str(p.get("fam", "town")):
		"long":
			_long(k, p)
		"pit":
			_pit(k, p)
		"stabbur":
			_stabbur(k, p)
		"round":
			_round(k, p)
		"terem":
			_terem(k, p)
		"granary":
			_granary(k, p)
		_:
			_town(k, p)



# --- two-lot buildings (about 2.0 wide by 1.0 deep) ---------------------------------------------------------


const BIG_KINDS := ["big_med_row_1", "big_med_row_2", "big_med_row_3", "big_med_guildhall", "big_med_manor",
	"big_med_farmstead", "big_med_inn", "big_vik_hall_1", "big_vik_hall_2", "big_vik_farm", "big_rus_yard", "big_rus_terem",
	"big_celt_ring", "big_celt_hall"]


## A sub-building at (x, z) in the big model's frame.
static func _at(k: Kit, x: float, z: float, yaw := 0.0) -> void:
	k.push(Kit.at(Vector3(x, 0, z), yaw))


static func _big(k: Kit, kind: String) -> void:
	match kind:
		"big_med_row_1":
			# three joined town houses of differing height, each gable to the street
			var a := {"fam": "town", "w": 0.66, "d": 0.8, "n": 3, "sh": 0.24, "jet": 0.06, "pat": "close", "gf": true, "rise": 0.5,
				"rm": "slate", "pl": "cream", "tm": "brown", "door": "l", "sides": "l", "chim": "ridge", "plinth": 0.05}
			var b := {"fam": "town", "w": 0.7, "d": 0.8, "n": 2, "sh": 0.26, "jet": 0.06, "pat": "braces", "gf": true, "rise": 0.44,
				"rm": "tile", "pl": "ochre", "tm": "black", "door": "r", "sides": "", "chim": "ridge", "plinth": 0.05}
			var c := {"fam": "town", "w": 0.64, "d": 0.8, "n": 3, "sh": 0.23, "jet": 0.05, "pat": "cross", "gf": true, "rise": 0.46,
				"rm": "slate", "pl": "white", "tm": "blood", "door": "c", "sides": "r", "chim": "ridge", "plinth": 0.05}
			a["ox"] = -0.68
			b["ox"] = 0.0
			c["ox"] = 0.67
			for r: Dictionary in [a, b, c]:
				r["front_only"] = true
				_town(k, r)
		"big_med_row_2":
			var specs := [[0.5, 3, "close", "tile2", "pink", "brown"], [0.62, 2, "braces", "slate", "grey", "black"],
				[0.46, 2, "panels", "tile", "sage", "oak"], [0.42, 3, "cross", "slate", "cream", "blood"]]
			var x := -1.0
			for i in specs.size():
				var s: Array = specs[i]
				var wd: float = s[0]
				var r := {"fam": "town", "w": wd, "d": 0.7 - (i % 2) * 0.06, "n": s[1], "sh": 0.23, "jet": 0.05, "pat": s[2], "gf": true,
					"rise": 0.34 + (i % 3) * 0.06, "rm": s[3], "pl": s[4], "tm": s[5], "door": "l" if i % 2 == 0 else "r",
					"sides": ("l" if i == 0 else ("r" if i == specs.size() - 1 else "")), "front_only": true, "ox": x + wd / 2.0, "plinth": 0.05,
					"chim": "ridge" if i % 2 == 0 else "none"}
				_town(k, r)
				x += wd
		"big_med_row_3":
			# a terrace of stone and brick fronted houses, eaves to the street, stepped in height
			var specs := [[0.68, 3, "stone", "slate", "warm"], [0.66, 2, "brick", "tile", "grey"], [0.66, 2, "stone", "slate", "pale"]]
			var x := -1.0
			for i in specs.size():
				var s: Array = specs[i]
				var wd: float = s[0]
				var r := {"fam": "town", "w": wd, "d": 0.62, "n": s[1], "sh": 0.24, "wall": s[2], "rise": 0.3 + 0.04 * i, "rm": s[3],
					"st": s[4], "door": "l" if i != 1 else "r", "win": "stone", "sides": ("l" if i == 0 else ("r" if i == 2 else "")),
					"front_only": true, "ox": x + wd / 2.0, "chim": "ridge", "dorm": 1 if i == 1 else 0, "plinth": 0.05}
				_town(k, r)
				x += wd
		"big_med_guildhall":
			var y0 := _town(k, {"w": 1.9, "d": 0.8, "n": 2, "sh": 0.3, "wall": "mixed", "jet": 0.07, "pat": "cross", "pl": "cream", "tm": "blood",
				"st": "pale", "rise": 0.5, "rm": "slate", "cross": true, "wing_side": "r", "chim": "two", "door": "c", "plinth": 0.07, "win": "mix"})
			# a bell turret on the ridge
			k.box(Vector3(-0.3, y0 + 0.28, 0.0), Vector3(0.16, 0.16, 0.16), LOG_C.darkened(0.2), Kit.TIMBER)
			k.hip_roof(Vector3(-0.3, y0 + 0.44, 0.0), 0.16, 0.16, 0.2, 0.03, 0.025, SLATE, Kit.OWNER_ROOF)
			k.frustum(Vector3(-0.3, y0 + 0.34, 0.0), 0.035, 0.05, 0.06, Color(0.85, 0.7, 0.3), Kit.GOLD, 6)
		"big_med_manor":
			# great hall with a tall roof, solar wing across one end, a porch between
			_town(k, {"w": 1.2, "d": 0.66, "n": 1, "sh": 0.4, "wall": "stone", "st": "warm", "roof": "half", "rise": 0.52, "rm": "slate",
				"ox": -0.4, "chim": "gable", "door": "l", "win": "arch", "porch": true, "plinth": 0.07, "front_only": false})
			_town(k, {"w": 0.74, "d": 0.92, "n": 2, "sh": 0.27, "jet": 0.05, "pat": "braces", "pl": "cream", "tm": "brown", "gf": true,
				"rise": 0.46, "rm": "slate", "ox": 0.63, "chim": "ridge", "door": "r", "front_only": false, "plinth": 0.06})
			_extra(k, "bush", -0.85, 0.42)
			_extra(k, "bench", -0.3, 0.45)
		"big_med_farmstead":
			_town(k, {"w": 0.6, "d": 0.5, "n": 2, "sh": 0.23, "pat": "panels", "pl": "cream", "tm": "brown", "rise": 0.36, "rm": "tile",
				"ox": -0.65, "chim": "ridge", "door": "c", "porch": true})
			# a long barn with a cart door
			var bx := 0.4
			k.box(Vector3(bx, 0, -0.1), Vector3(1.0, 0.24, 0.5), Color(0.5, 0.36, 0.22), Kit.TIMBER)
			k.push(Kit.at(Vector3(bx, 0, 0.15)))
			for i in 11:
				var x := -0.5 + i * 0.1
				_strip(k, Vector2(x, 0.0), Vector2(x, 0.24), 0.014, Color(0.32, 0.22, 0.14), Kit.TIMBER, 0.004)
			_door2(k, 0.0, 0.26, 0.2, Color(0.3, 0.2, 0.12), Color(0.22, 0.15, 0.1), false, false)
			k.pop()
			k.gable_roof(Vector3(bx, 0.24, -0.1), 1.0, 0.5, 0.26, 0.06, 0.04, Color(0.76, 0.64, 0.34), Kit.THATCH, Color(0.5, 0.36, 0.22), Kit.TIMBER)
			_extra(k, "hay", -0.1, -0.38)
			_extra(k, "pen", -0.25, 0.38)
			_extra(k, "cart", 0.2, 0.42)
			_extra(k, "fence", -0.95, 0.4)
			_extra(k, "well", 0.9, 0.42)
		"big_med_inn":
			# a coaching inn: a long front range, a gate arch and a stable wing behind
			var y0 := _town(k, {"w": 1.5, "d": 0.5, "n": 2, "sh": 0.26, "jet": 0.05, "pat": "braces", "pl": "cream", "tm": "black", "rise": 0.38,
				"rm": "tile", "ox": 0.0, "dorm": 3, "chim": "two", "door": "c", "win": "mix", "oz": 0.2})
			k.push(Kit.at(Vector3(0, 0, -0.5)))
			k.box(Vector3(0, 0, 0), Vector3(1.4, 0.2, 0.28), Color(0.5, 0.36, 0.22), Kit.TIMBER)
			k.gable_roof(Vector3(0, 0.2, 0), 1.4, 0.28, 0.16, 0.05, 0.035, Color(0.46, 0.33, 0.21), Kit.TILE, Color(0.5, 0.36, 0.22), Kit.TIMBER)
			k.pop()
			k.chimney(Vector3(0.7, y0, 0.0), 0.1, 0.1, Color(0.62, 0.45, 0.36), Kit.BRICK)
			_extra(k, "barrel", 0.55, 0.45)
			_extra(k, "cart", -0.6, 0.42)
		"big_vik_hall_1":
			_long(k, {"L": 1.86, "W": 0.66, "wh": 0.28, "bow": 0.22, "rise": 0.46, "rm": "shingle", "wood": "oak", "door": 0.3, "louvre_x": 0.2,
				"win": 4, "annex": -0.7})
		"big_vik_hall_2":
			_at(k, 0.0, 0.1)
			_long(k, {"L": 1.5, "W": 0.56, "wh": 0.26, "rise": 0.4, "rm": "turf", "wood": "grey", "door": -0.2, "louvre_x": 0.0, "win": 3})
			k.pop()
			_at(k, -0.55, -0.35)
			_stabbur(k, {"w": 0.4, "d": 0.34, "rm": "turf", "wood": "dark", "rise": 0.22})
			k.pop()
			_at(k, 0.6, -0.34)
			_pit(k, {"L": 0.5, "W": 0.4, "rise": 0.24, "rm": "turf"})
			k.pop()
		"big_vik_farm":
			_at(k, -0.45, 0.0)
			_long(k, {"L": 0.96, "W": 0.4, "wh": 0.2, "rm": "shingle", "wood": "oak", "door": 0.3})
			k.pop()
			_at(k, 0.65, 0.0)
			_stabbur(k, {"w": 0.5, "d": 0.46, "rm": "turf", "wood": "dark"})
			k.pop()
			_extra(k, "hay", 0.2, 0.38)
			_extra(k, "pen", 0.12, -0.36)
			_extra(k, "fence", 0.62, 0.4)
		"big_rus_yard":
			# two izbas linked by a covered passage, a well in the yard
			_town(k, {"w": 0.56, "d": 0.62, "n": 2, "sh": 0.27, "plinth": 0.07, "wall": "log", "gf": true, "rise": 0.4, "rm": "plank", "carve": true,
				"konek": true, "trim": "blue", "door": "c", "chim": "ridge", "ox": -0.65})
			_town(k, {"w": 0.5, "d": 0.54, "n": 1, "sh": 0.3, "plinth": 0.06, "wall": "log", "gf": true, "rise": 0.36, "rm": "shingle", "carve": true,
				"trim": "red", "door": "c", "chim": "none", "ox": 0.65})
			k.box(Vector3(0, 0, -0.08), Vector3(0.82, 0.22, 0.32), LOG_C, Kit.TIMBER)
			k.gable_roof(Vector3(0, 0.22, -0.08), 0.82, 0.32, 0.16, 0.05, 0.035, Color(0.55, 0.45, 0.33), Kit.TILE, LOG_C, Kit.TIMBER)
			k.push(Kit.at(Vector3(0, 0, 0.08)))
			for i in 5:
				_strip(k, Vector2(-0.41, 0.04 * (i + 1)), Vector2(0.41, 0.04 * (i + 1)), 0.01, LOG_C.darkened(0.35), Kit.DARK, 0.004)
			_door2(k, 0.0, 0.14, 0.17, Color(0.62, 0.2, 0.14), Color(0.25, 0.17, 0.1), false, false)
			k.pop()
			_extra(k, "well", 0.0, 0.42)
			_extra(k, "wood", -0.2, -0.42)
		"big_rus_terem":
			_at(k, -0.45, 0.0)
			_terem(k, _rows()["house_rus_terem_1"])
			k.pop()
			_town(k, {"w": 0.7, "d": 0.5, "n": 1, "sh": 0.3, "plinth": 0.06, "wall": "log", "roof": "half", "rise": 0.34, "rm": "plank", "trim": "ochre",
				"door": "c", "chim": "ridge", "ox": 0.62, "porch": true})
			_extra(k, "barrel", 0.2, 0.42)
		"big_celt_ring":
			_at(k, -0.5, 0.0)
			_round(k, {"r": 0.34, "wh": 0.18, "ch": 0.44, "wall": "wattle", "rm": "thatch", "pl": "umber"})
			k.pop()
			_at(k, 0.5, 0.0)
			_round(k, {"r": 0.38, "wh": 0.2, "ch": 0.5, "wall": "stone", "rm": "thatch_g", "st": "warm", "double": true})
			k.pop()
			_fence_run(k, -0.95, -0.46, 0.95, -0.46)
			_fence_run(k, -0.95, -0.46, -0.95, 0.46)
			_fence_run(k, 0.95, -0.46, 0.95, 0.46)
			_extra(k, "hay", 0.0, 0.1)
			_extra(k, "pen", 0.0, -0.3)
		"big_celt_hall":
			_at(k, -0.35, 0.0)
			_round(k, {"r": 0.46, "wh": 0.22, "ch": 0.56, "wall": "wattle", "rm": "reed", "pl": "cream", "double": true, "over": 0.12})
			k.pop()
			_at(k, 0.72, 0.1)
			_round(k, {"r": 0.28, "wh": 0.16, "ch": 0.36, "wall": "post", "rm": "thatch", "porch": false})
			k.pop()
			_at(k, 0.72, -0.35)
			_granary(k, {"w": 0.34, "d": 0.28, "post": 0.1, "rise": 0.18, "rm": "thatch"})
			k.pop()
			_extra(k, "barrel", -0.3, 0.45)
			_extra(k, "bush", 0.2, 0.42)


## A fence of posts and rails from (x0, z0) to (x1, z1).
static func _fence_run(k: Kit, x0: float, z0: float, x1: float, z1: float) -> void:
	var wood := Color(0.5, 0.36, 0.2)
	var a := Vector3(x0, 0, z0)
	var b := Vector3(x1, 0, z1)
	var n := maxi(2, int((b - a).length() / 0.25))
	for i in n + 1:
		var q := a.lerp(b, float(i) / n)
		k.rod(q, q + Vector3(0, 0.1, 0), 0.012, wood, Kit.TIMBER)
	k.rod(a + Vector3(0, 0.075, 0), b + Vector3(0, 0.075, 0), 0.008, wood, Kit.TIMBER)
	k.rod(a + Vector3(0, 0.04, 0), b + Vector3(0, 0.04, 0), 0.008, wood, Kit.TIMBER)


# --- regional props (each under 200 triangles) -----------------------------------------------------------------


const PROP_KINDS := ["prop_market_cross", "prop_well_roofed", "prop_runestone", "prop_longboat", "prop_stocks", "prop_maypole"]


static func _prop(k: Kit, kind: String) -> void:
	match kind:
		"prop_market_cross":
			# a stepped base, a tapering shaft and a carved cross head
			var st := Color(0.70, 0.67, 0.60)
			for i in 3:
				var s := 0.30 - i * 0.07
				k.box(Vector3(0, i * 0.035, 0), Vector3(s, 0.035, s), st.darkened(0.05 * (2 - i)), Kit.STONE)
			k.frustum(Vector3(0, 0.105, 0), 0.04, 0.025, 0.3, st, Kit.STONE, 6)
			k.box(Vector3(0, 0.4, 0), Vector3(0.07, 0.03, 0.07), st.lightened(0.05), Kit.STONE)
			k.box(Vector3(0, 0.43, 0), Vector3(0.035, 0.14, 0.03), st, Kit.STONE)
			k.box(Vector3(0, 0.5, 0), Vector3(0.12, 0.035, 0.03), st, Kit.STONE)
			k.box(Vector3(0, 0.57, 0), Vector3(0.045, 0.045, 0.04), st.lightened(0.05), Kit.STONE)
		"prop_well_roofed":
			var st := Color(0.62, 0.60, 0.55)
			var wood := Color(0.40, 0.28, 0.17)
			k.frustum(Vector3(0, 0, 0), 0.1, 0.1, 0.09, st, Kit.STONE, 8, false)
			k.frustum(Vector3(0, 0.07, 0), 0.085, 0.085, 0.01, Color(0.22, 0.42, 0.58), Kit.WATER, 8)
			for s: float in [-1.0, 1.0]:
				k.box(Vector3(s * 0.1, 0.0, 0), Vector3(0.025, 0.28, 0.025), wood, Kit.TIMBER)
			k.rod(Vector3(-0.1, 0.22, 0), Vector3(0.1, 0.22, 0), 0.009, wood, Kit.TIMBER)
			k.gable_roof(Vector3(0, 0.27, 0), 0.26, 0.2, 0.1, 0.03, 0.025, Color(0.46, 0.33, 0.21), Kit.TILE, wood, Kit.TIMBER)
			k.rod(Vector3(0, 0.22, 0), Vector3(0, 0.1, 0), 0.004, Color(0.3, 0.22, 0.16), Kit.CLOTH)
			_barrel6(k, Vector3(0, 0.085, 0), 0.02, 0.035)
			k.box(Vector3(0.1, 0.19, 0.0), Vector3(0.05, 0.02, 0.02), wood, Kit.TIMBER)
		"prop_runestone":
			var st := Color(0.58, 0.57, 0.54)
			k.frustum(Vector3(0, 0, 0), 0.07, 0.04, 0.36, st, Kit.STONE, 5, false)
			k.tri(Vector3(0.0, 0.34, 0.0), Vector3(0.04, 0.36, 0.0), Vector3(-0.04, 0.36, 0.0), st, Kit.STONE, Vector3(0, 0.2, 0))
			k.frustum(Vector3(0, 0.35, 0), 0.04, 0.0, 0.07, st.lightened(0.05), Kit.STONE, 5)
			var red := Color(0.62, 0.18, 0.12)
			k.push(Kit.at(Vector3(0, 0, 0.0)))
			for i in 4:   # painted runes in a column and a serpent loop
				var y := 0.07 + i * 0.065
				k.quad(Vector3(-0.014, y, 0.068 - i * 0.006), Vector3(0.014, y, 0.068 - i * 0.006), Vector3(0.014, y + 0.045, 0.066 - i * 0.006),
					Vector3(-0.014, y + 0.045, 0.066 - i * 0.006), red, Kit.PAINT, Vector3(0, y, -1))
				k.rod(Vector3(-0.025, y + 0.01, 0.07 - i * 0.006), Vector3(0.02, y + 0.04, 0.07 - i * 0.006), 0.006, red, Kit.PAINT)
			k.pop()
			for i in 4:
				k.box(Vector3(cos(i * PI / 2.0 + 0.4) * 0.09, 0, sin(i * PI / 2.0 + 0.4) * 0.09), Vector3(0.05, 0.03, 0.05), st.darkened(0.15), Kit.STONE)
		"prop_longboat":
			_longboat(k)
		"prop_stocks":
			var wood := Color(0.40, 0.28, 0.17)
			for s: float in [-1.0, 1.0]:
				k.box(Vector3(s * 0.11, 0, 0), Vector3(0.025, 0.16, 0.04), wood, Kit.TIMBER)
			k.box(Vector3(0, 0.06, 0.0), Vector3(0.2, 0.024, 0.026), wood.lightened(0.05), Kit.TIMBER)
			k.box(Vector3(0, 0.084, 0.0), Vector3(0.2, 0.024, 0.026), wood.lightened(0.05), Kit.TIMBER)
			for s: float in [-1.0, 1.0]:
				k.box(Vector3(s * 0.04, 0.07, 0.002), Vector3(0.026, 0.02, 0.03), Color(0.1, 0.07, 0.05), Kit.DARK)
				k.box(Vector3(s * 0.1, 0, 0.1), Vector3(0.02, 0.02, 0.08), wood, Kit.TIMBER)
			k.box(Vector3(0, 0, 0.1), Vector3(0.18, 0.025, 0.07), wood.darkened(0.1), Kit.TIMBER)
			k.box(Vector3(0, 0.17, 0), Vector3(0.28, 0.02, 0.05), wood.darkened(0.1), Kit.TIMBER)
		"prop_maypole":
			var wood := Color(0.62, 0.50, 0.34)
			k.frustum(Vector3(0, 0, 0), 0.12, 0.1, 0.03, Color(0.45, 0.62, 0.30), Kit.LEAF, 8)
			k.frustum(Vector3(0, 0, 0), 0.02, 0.014, 0.78, wood, Kit.TIMBER, 6)
			var cols := [Color(0.78, 0.15, 0.12), Color(0.95, 0.9, 0.7), Color(0.2, 0.4, 0.7), Color(0.9, 0.7, 0.15),
				Color(0.2, 0.55, 0.3), Color(0.8, 0.4, 0.6)]
			for i in 6:
				var a := i * TAU / 6.0
				k.rod(Vector3(0, 0.74, 0), Vector3(cos(a) * 0.17, 0.02, sin(a) * 0.17), 0.005, cols[i], Kit.CLOTH)
			k.frustum(Vector3(0, 0.72, 0), 0.07, 0.07, 0.014, Color(0.3, 0.5, 0.25), Kit.LEAF, 8, false)
			k.frustum(Vector3(0, 0.78, 0), 0.03, 0.0, 0.07, Color(0.9, 0.75, 0.3), Kit.GOLD, 5)


## A Viking longboat drawn up on the beach: lofted clinker hull, dragon prow, oars and shields.
static func _longboat(k: Kit) -> void:
	var wood := Color(0.50, 0.36, 0.22)
	var dark := Color(0.30, 0.20, 0.13)
	var stations := 7
	var half := 0.5
	var prev: Array = []
	for i in stations:
		var t := -1.0 + 2.0 * i / (stations - 1)
		var u := absf(t)
		var beam := 0.11 * (1.0 - pow(u, 2.4)) + 0.008
		var top := 0.095 + 0.09 * pow(u, 3.0)
		var keel := 0.03 + 0.07 * pow(u, 3.0)
		var x := t * half
		var pts := [Vector3(x, keel, -0.0), Vector3(x, keel + (top - keel) * 0.35, beam * 0.7), Vector3(x, top, beam),
			Vector3(x, keel + (top - keel) * 0.35, -beam * 0.7), Vector3(x, top, -beam)]
		if not prev.is_empty():
			var inside := Vector3(x, 0.05, 0)
			k.quad(prev[0], pts[0], pts[1], prev[1], wood, Kit.TIMBER, inside)
			k.quad(prev[1], pts[1], pts[2], prev[2], wood.lightened(0.06), Kit.TIMBER, inside)
			k.quad(pts[0], prev[0], prev[3], pts[3], wood, Kit.TIMBER, inside)
			k.quad(pts[3], prev[3], prev[4], pts[4], wood.lightened(0.06), Kit.TIMBER, inside)
			# the deck seen between the gunwales
			k.quad(prev[2], pts[2], pts[4], prev[4], dark.lightened(0.1), Kit.TIMBER, Vector3(x, -1, 0))
		prev = pts
	# stem and stern posts curling up, the prow a carved head
	for s: float in [-1.0, 1.0]:
		var base := Vector3(s * half, 0.185, 0)
		k.rod(base, base + Vector3(s * 0.025, 0.1, 0), 0.012, dark, Kit.TIMBER)
		k.rod(base + Vector3(s * 0.025, 0.1, 0), base + Vector3(s * 0.01, 0.17, 0), 0.01, dark, Kit.TIMBER)
	k.box(Vector3(half - 0.02, 0.33, 0), Vector3(0.05, 0.03, 0.025), Color(0.62, 0.2, 0.14), Kit.PAINT)
	# a lowered mast with the furled sail, thwarts and oars
	k.rod(Vector3(-0.3, 0.12, 0), Vector3(0.25, 0.14, 0), 0.01, wood.lightened(0.1), Kit.TIMBER)
	k.rod(Vector3(-0.25, 0.135, 0.012), Vector3(0.2, 0.15, 0.012), 0.018, Color(0.88, 0.84, 0.72), Kit.CLOTH)
	for i in 2:
		k.box(Vector3(-0.15 + i * 0.3, 0.1, 0), Vector3(0.025, 0.014, 0.17), wood, Kit.TIMBER)
	for i in 2:
		var x := -0.2 + i * 0.3
		k.rod(Vector3(x, 0.15, 0.1), Vector3(x + 0.02, 0.05, 0.25), 0.006, wood.lightened(0.15), Kit.TIMBER)
	var sc := [Color(0.62, 0.2, 0.14), Color(0.85, 0.75, 0.4), Color(0.2, 0.35, 0.6)]
	for i in 3:
		k.box(Vector3(-0.2 + i * 0.16, 0.14 + 0.0, 0.088 - 0.0), Vector3(0.05, 0.05, 0.008), sc[i % 3], Kit.PAINT)
	# cradle logs under the keel
	for x: float in [-0.3, 0.3]:
		k.box(Vector3(x, 0.0, 0.0), Vector3(0.05, 0.03, 0.26), dark, Kit.TIMBER)


# --- what a settlement draws -----------------------------------------------------------------------------------------


## The people a culture belongs to: "viking", "rus", "celtic", or the medieval western default.
static func _people(culture: String) -> String:
	if culture == "viking" or culture == "rus" or culture == "celtic":
		return culture
	return "medieval"


## House kinds for a place of `rank` ("core", "city", "edge", "suburb", "town", "village", "farm",
## "camp"). A kind listed twice is drawn twice as often. Unknown cultures build medieval houses.
static func house_set(culture: String, rank: String) -> Array:
	var m := "house_med_"
	match _people(culture):
		"viking":
			match rank:
				"core":
					return ["house_vik_long_4", "house_vik_long_1", "house_vik_long_2", "house_vik_long_5", "house_vik_long_4", "house_vik_store_1", "house_4"]
				"city":
					return ["house_vik_long_1", "house_vik_long_2", "house_vik_long_5", "house_vik_long_3", "house_vik_store_1", "house_vik_store_2", "house_vik_long_4"]
				"edge", "suburb":
					return ["house_vik_long_3", "house_vik_pit_1", "house_vik_pit_2", "house_vik_store_2", "house_vik_long_3", "house_vik_store_3"]
				"town":
					return ["house_vik_long_1", "house_vik_long_3", "house_vik_long_5", "house_vik_pit_1", "house_vik_store_1", "house_vik_store_3", "house_vik_long_2"]
				"village":
					return ["house_vik_long_3", "house_vik_long_1", "house_vik_pit_1", "house_vik_pit_2", "house_vik_store_3", "house_vik_pit_1", "house_vik_long_5"]
				"farm":
					return ["house_vik_long_1", "house_vik_long_3", "house_vik_store_1", "house_vik_pit_2", "house_vik_store_3"]
				_:
					return ["house_vik_pit_1", "house_vik_pit_2", "house_vik_store_2", "house_vik_long_3", "house_vik_pit_1"]
		"rus":
			match rank:
				"core":
					return ["house_rus_terem_1", "house_rus_terem_2", "house_rus_izba_2", "house_rus_izba_5", "house_rus_terem_1", "house_rus_izba_2", "house_rus_granary_2"]
				"city":
					return ["house_rus_izba_1", "house_rus_izba_2", "house_rus_izba_4", "house_rus_izba_5", "house_rus_izba_2", "house_rus_terem_2", "house_rus_granary_1"]
				"edge", "suburb":
					return ["house_rus_izba_3", "house_rus_izba_4", "house_rus_izba_1", "house_rus_izba_3", "house_rus_granary_1", "house_5"]
				"town":
					return ["house_rus_izba_1", "house_rus_izba_3", "house_rus_izba_4", "house_rus_izba_5", "house_rus_izba_2", "house_rus_granary_1", "house_rus_granary_2"]
				"village":
					return ["house_rus_izba_3", "house_rus_izba_4", "house_rus_izba_1", "house_rus_izba_3", "house_rus_granary_1", "house_rus_izba_5"]
				"farm":
					return ["house_rus_farm_1", "house_rus_farm_1", "house_rus_izba_3", "house_rus_granary_2", "house_rus_granary_1"]
				_:
					return ["house_rus_izba_3", "house_rus_izba_3", "house_rus_granary_1", "house_rus_izba_4"]
		"celtic":
			match rank:
				"core":
					return ["house_celt_round_2", "house_celt_round_3", "house_celt_round_4", "house_celt_round_2", "house_celt_round_1", "house_vik_long_1", "house_med_cruck_1"]
				"city":
					return ["house_celt_round_1", "house_celt_round_2", "house_celt_round_3", "house_celt_round_4", "house_celt_round_5", "house_med_cruck_1", "house_vik_store_2"]
				"edge", "suburb":
					return ["house_celt_round_1", "house_celt_round_5", "house_celt_round_5", "house_med_hovel_1", "house_med_cruck_3", "house_celt_round_3"]
				"town":
					return ["house_celt_round_1", "house_celt_round_3", "house_celt_round_4", "house_celt_round_5", "house_celt_round_2", "house_med_cruck_2"]
				"village":
					return ["house_celt_round_1", "house_celt_round_5", "house_celt_round_4", "house_celt_round_1", "house_celt_round_3", "house_med_hovel_2"]
				"farm":
					return ["house_celt_round_4", "house_celt_round_1", "house_med_farm_2", "house_celt_round_5"]
				_:
					return ["house_celt_round_5", "house_celt_round_1", "house_med_hovel_1", "house_celt_round_5"]
		_:
			match rank:
				"core":   # the tall merchant and guild houses at the heart of a great town
					return [m + "timber_3", m + "stone_1", m + "timber_8", m + "stone_2", m + "timber_1", m + "stone_4", m + "brick_1", m + "timber_3",
						m + "stone_2", "house_3", "house_6", m + "timber_6"]
				"city":
					return [m + "timber_1", m + "timber_2", m + "timber_3", m + "timber_4", m + "timber_6", m + "stone_1", m + "stone_3", m + "brick_1",
						m + "timber_8", m + "stone_3", "house_1", "house_6", m + "timber_2"]
				"edge":
					return [m + "timber_5", m + "timber_7", m + "cottage_1", m + "cottage_2", m + "timber_2", m + "hovel_3", m + "cruck_3", "house_2",
						m + "timber_4", m + "hovel_2"]
				"suburb":
					return [m + "timber_5", m + "timber_7", m + "timber_4", m + "cottage_1", m + "cottage_2", m + "cruck_2", m + "hovel_1", m + "timber_2"]
				"town":
					return [m + "timber_1", m + "timber_2", m + "timber_4", m + "timber_5", m + "timber_6", m + "timber_7", m + "stone_3", m + "cottage_1",
						m + "cottage_2", "house_1", "house_2", m + "brick_1"]
				"village":
					return [m + "cruck_1", m + "cruck_2", m + "cruck_3", m + "cottage_1", m + "cottage_2", m + "hovel_1", m + "hovel_2", m + "hovel_3",
						m + "timber_5", m + "timber_7", "house_2", m + "cruck_1"]
				"farm":
					return [m + "farm_1", m + "farm_2", m + "farm_3", m + "farm_1", m + "farm_2"]
				_:
					return [m + "hovel_1", m + "hovel_2", m + "hovel_3", m + "cruck_2", m + "hovel_1"]


## Two-lot buildings (about 2.0 wide by 1.0 deep) for a place of `rank`, or [] if none suit it.
static func big_house_set(culture: String, rank: String) -> Array:
	match _people(culture):
		"viking":
			match rank:
				"core", "city", "town":
					return ["big_vik_hall_1", "big_vik_hall_2", "big_vik_farm"]
				"village", "edge", "suburb":
					return ["big_vik_farm", "big_vik_hall_2"]
				"farm":
					return ["big_vik_farm", "big_vik_farm", "big_vik_hall_2"]
				_:
					return []
		"rus":
			match rank:
				"core", "city", "town":
					return ["big_rus_terem", "big_rus_yard", "big_rus_yard"]
				"village", "edge", "suburb", "farm":
					return ["big_rus_yard"]
				_:
					return []
		"celtic":
			match rank:
				"core", "city", "town":
					return ["big_celt_hall", "big_celt_ring", "big_celt_hall"]
				"village", "edge", "suburb", "farm":
					return ["big_celt_ring", "big_celt_hall"]
				_:
					return []
		_:
			match rank:
				"core":
					return ["big_med_guildhall", "big_med_row_1", "big_med_row_2", "big_med_row_3", "big_med_manor", "big_med_guildhall", "big_med_inn"]
				"city":
					return ["big_med_row_1", "big_med_row_2", "big_med_row_3", "big_med_inn", "big_med_guildhall"]
				"edge", "suburb":
					return ["big_med_row_2", "big_med_row_3", "big_med_inn"]
				"town":
					return ["big_med_row_2", "big_med_row_3", "big_med_inn", "big_med_manor", "big_med_row_1"]
				"village":
					return ["big_med_farmstead", "big_med_manor", "big_med_inn"]
				"farm":
					return ["big_med_farmstead", "big_med_farmstead", "big_med_manor"]
				_:
					return []
