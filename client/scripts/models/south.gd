## Warm-climate building styles: Nile (Egypt, Kush), Near East (Mesopotamia, Persia, Levant,
## Islamic cities) and South Asia (Maurya, Indian kingdoms). Built with the model kit.
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")

const MUD := Color(0.72, 0.58, 0.40)
const MUD_LT := Color(0.82, 0.69, 0.50)
const SAND := Color(0.86, 0.76, 0.56)
const LIME := Color(0.93, 0.89, 0.78)
const WHITE := Color(0.96, 0.94, 0.88)
const BLUE := Color(0.10, 0.34, 0.62)
const TURQ := Color(0.12, 0.56, 0.62)
const RED := Color(0.70, 0.22, 0.14)
const OCHRE := Color(0.80, 0.56, 0.22)
const GILD := Color(0.95, 0.76, 0.28)
const WOOD := Color(0.40, 0.26, 0.15)
const WOOD_DK := Color(0.28, 0.18, 0.10)
const PALM_G := Color(0.30, 0.52, 0.22)
const SHADE := Color(0.08, 0.06, 0.05)
const REED := Color(0.78, 0.66, 0.38)
const BRICKR := Color(0.70, 0.40, 0.28)
const STONE_LT := Color(0.80, 0.74, 0.62)
const STONE_GR := Color(0.62, 0.60, 0.55)


static func kinds() -> Array:
	return ["nile_house_1", "nile_house_2", "nile_house_3", "nile_house_4", "nile_palace",
		"pyramid", "obelisk", "sphinx",
		"near_east_house_1", "near_east_house_2", "near_east_house_3", "near_east_house_4",
		"ziggurat", "near_east_palace",
		"south_asian_house_1", "south_asian_house_2", "south_asian_house_3", "south_asian_house_4",
		"south_asian_palace", "stupa", "temple_shikhara"] + _generated()


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	if _build_generated(k, kind):
		return k.finish()
	match kind:
		"nile_house_1": _nile_house_1(k)
		"nile_house_2": _nile_house_2(k)
		"nile_house_3": _nile_house_3(k)
		"nile_house_4": _nile_house_4(k)
		"nile_palace": _nile_palace(k)
		"pyramid": _pyramid(k)
		"obelisk": _obelisk(k)
		"sphinx": _sphinx(k)
		"near_east_house_1": _ne_house_1(k)
		"near_east_house_2": _ne_house_2(k)
		"near_east_house_3": _ne_house_3(k)
		"near_east_house_4": _ne_house_4(k)
		"ziggurat": _ziggurat(k)
		"near_east_palace": _ne_palace(k)
		"south_asian_house_1": _sa_house_1(k)
		"south_asian_house_2": _sa_house_2(k)
		"south_asian_house_3": _sa_house_3(k)
		"south_asian_house_4": _sa_house_4(k)
		"south_asian_palace": _sa_palace(k)
		"stupa": _stupa(k)
		"temple_shikhara": _shikhara(k)
	return k.finish()


# --- helpers -----------------------------------------------------------------------------------


## A palm tree: ribbed trunk and a crown of drooping fronds.
static func _palm(k: Kit, p: Vector3, h: float, fronds := 7, spread := 0.78) -> void:
	k.frustum(p, h * 0.05, h * 0.035, h, Color(0.45, 0.33, 0.20), Kit.TIMBER, 5, false)
	var c := p + Vector3(0, h, 0)
	var below := c + Vector3(0, -3, 0)
	var above := c + Vector3(0, 3, 0)
	for i in fronds:
		var a: float = i * TAU / fronds + p.x * 7.0
		var d := Vector3(cos(a), 0, sin(a))
		var s := Vector3(-d.z, 0, d.x) * h * 0.1 * spread
		var m := c + d * h * 0.28 * spread + Vector3(0, h * 0.13, 0)
		var t := c + d * h * 0.58 * spread + Vector3(0, -h * 0.1, 0)
		k.tri(c, m + s, t, PALM_G, Kit.LEAF, below)
		k.tri(c, t, m - s, PALM_G.darkened(0.08), Kit.LEAF, below)
		k.tri(c, m + s, t, PALM_G, Kit.LEAF, above)
		k.tri(c, t, m - s, PALM_G, Kit.LEAF, above)
	k.frustum(c + Vector3(0, -h * 0.02, 0), h * 0.06, h * 0.03, h * 0.08, Color(0.50, 0.38, 0.22), Kit.THATCH, 5)


## Steps climbing toward local -z from `foot`; `w` wide, `n` steps.
static func _stairs(k: Kit, foot: Vector3, yaw: float, w: float, n: int, rise: float, run: float, col: Color, mat: int) -> void:
	k.push(Kit.at(foot, yaw))
	var hw := w / 2.0
	for i in n:
		var y0 := i * rise
		var y1 := (i + 1) * rise
		var z0 := -i * run
		var z1 := -(i + 1) * run
		k.quad(Vector3(-hw, y0, z0), Vector3(hw, y0, z0), Vector3(hw, y1, z0), Vector3(-hw, y1, z0), col.darkened(0.12), mat, Vector3(0, y0, z0 - 1))
		k.quad(Vector3(-hw, y1, z0), Vector3(hw, y1, z0), Vector3(hw, y1, z1), Vector3(-hw, y1, z1), col, mat, Vector3(0, -1, z0))
		for s in [-1.0, 1.0]:
			var sx: float = s * hw
			k.quad(Vector3(sx, 0, z0), Vector3(sx, 0, z1), Vector3(sx, y1, z1), Vector3(sx, y1, z0), col.darkened(0.2), mat, Vector3(0, y0, z0))
	k.pop()


## A low rim round a flat roof or terrace (four boxes).
static func _parapet(k: Kit, foot: Vector3, w: float, d: float, h: float, t: float, col: Color, mat: int, gap_front := 0.0) -> void:
	if gap_front <= 0.0:
		k.box(foot + Vector3(0, 0, d / 2 - t / 2), Vector3(w, h, t), col, mat)
	else:
		var seg := (w - gap_front) / 2.0
		for s in [-1.0, 1.0]:
			var sx: float = s * (gap_front / 2.0 + seg / 2.0)
			k.box(foot + Vector3(sx, 0, d / 2 - t / 2), Vector3(seg, h, t), col, mat)
	k.box(foot + Vector3(0, 0, -d / 2 + t / 2), Vector3(w, h, t), col, mat)
	for s in [-1.0, 1.0]:
		var sx2: float = s * (w / 2 - t / 2)
		k.box(foot + Vector3(sx2, 0, 0), Vector3(t, h, d - t * 2), col, mat)


## Merlons (stepped or plain battlements) spaced along a rectangle's rim.
static func _merlons(k: Kit, foot: Vector3, w: float, d: float, size: float, h: float, col: Color, mat: int) -> void:
	var nx := maxi(2, int(w / (size * 2.0)))
	var nz := maxi(2, int(d / (size * 2.0)))
	for i in nx:
		var x: float = -w / 2 + size + (w - size * 2) * i / float(nx - 1)
		k.box(foot + Vector3(x, 0, d / 2 - size / 2), Vector3(size, h, size), col, mat)
		k.box(foot + Vector3(x, 0, -d / 2 + size / 2), Vector3(size, h, size), col, mat)
	for i in range(1, nz - 1):
		var z: float = -d / 2 + size + (d - size * 2) * i / float(nz - 1)
		k.box(foot + Vector3(w / 2 - size / 2, 0, z), Vector3(size, h, size), col, mat)
		k.box(foot + Vector3(-w / 2 + size / 2, 0, z), Vector3(size, h, size), col, mat)


## A dark slot/window block on a wall: `p` the foot-middle at the wall face, facing `yaw`.
static func _slot(k: Kit, p: Vector3, yaw: float, w: float, h: float, frame := MUD_LT) -> void:
	k.push(Kit.at(p, yaw))
	k.box(Vector3(0, 0, -0.01), Vector3(w, h, 0.03), SHADE, Kit.DARK)
	k.box(Vector3(0, h, -0.01), Vector3(w * 1.5, h * 0.22, 0.045), frame, Kit.MUDBRICK)
	k.pop()


## A flat arched opening (dark) on a wall face: `p` the foot-middle, facing `yaw`.
static func _arch(k: Kit, p: Vector3, yaw: float, w: float, h: float, col := SHADE, pointed := false, mat := Kit.DARK) -> void:
	k.push(Kit.at(p, yaw))
	var hs := h - w / 2.0
	var pts: Array = [Vector3(-w / 2, 0, 0.008), Vector3(w / 2, 0, 0.008)]
	var seg := 6
	for i in range(0, seg + 1):
		var a := PI * i / seg
		var rx := cos(a) * w / 2.0
		var ry := sin(a) * w / 2.0
		if pointed:
			ry *= 1.35
		pts.append(Vector3(rx, hs + ry, 0.008))
	pts.append(Vector3(-w / 2, hs, 0.008))
	# reorder: the arc goes from +x round to -x, which is counter-clockwise; fine for a fan
	k.polygon(pts, col, mat, Vector3(0, h / 2, -1))
	k.pop()


## A deep arched doorway with jambs, a recessed dark opening and a coloured leaf.
static func _arch_door(k: Kit, p: Vector3, yaw: float, w: float, h: float, frame: Color, leaf: Color, mat := Kit.PLASTER) -> void:
	k.push(Kit.at(p, yaw))
	var j := w * 0.22
	for s in [-1.0, 1.0]:
		var sx: float = s * (w / 2 + j / 2)
		k.box(Vector3(sx, 0, 0.0), Vector3(j, h * 0.82, w * 0.34), frame, mat)
	_arch(k, Vector3(0, 0, 0), 0.0, w, h, SHADE, false)
	# door leaf, half open into the shade
	k.box(Vector3(0, 0, 0.004), Vector3(w * 0.84, h * 0.62, 0.012), leaf, Kit.PAINT)
	k.box(Vector3(0, h * 0.62, 0.004), Vector3(w * 0.84, h * 0.04, 0.014), leaf.darkened(0.3), Kit.PAINT)
	# arch band over the opening
	k.box(Vector3(0, h * 0.82 - j * 0.3, 0.0), Vector3(w + j * 2.0, j, w * 0.34), frame, mat)
	k.pop()


## A slanted wall band on a sloping (battered) face: front face of a plinth at z=zf(y).
static func _band(k: Kit, cx: float, w: float, y0: float, y1: float, zc: float, hd: float, inset: float, hh: float, col: Color, mat := Kit.PAINT) -> void:
	var za := zc + hd - inset * y0 / hh + 0.004
	var zb := zc + hd - inset * y1 / hh + 0.004
	k.quad(Vector3(cx - w / 2, y0, za), Vector3(cx + w / 2, y0, za), Vector3(cx + w / 2, y1, zb), Vector3(cx - w / 2, y1, zb), col, mat, Vector3(cx, (y0 + y1) / 2, zc - 1))


## A beehive granary / small dome with a hatch.
static func _granary(k: Kit, p: Vector3, r: float, col: Color, mat := Kit.MUDBRICK) -> void:
	k.frustum(p, r, r * 0.95, r * 0.5, col, mat, 10, false)
	k.dome(p + Vector3(0, r * 0.5, 0), r * 0.95, col, mat, 1.1, 4, 10)
	k.box(p + Vector3(0, r * 1.3, 0), Vector3(r * 0.5, r * 0.18, r * 0.5), col.darkened(0.15), mat)


## A clay pot.
static func _pot(k: Kit, p: Vector3, r: float, col := Color(0.62, 0.34, 0.22)) -> void:
	k.frustum(p, r * 0.6, r, r * 1.1, col, Kit.EARTH, 7, false)
	k.frustum(p + Vector3(0, r * 1.1, 0), r, r * 0.55, r * 0.5, col, Kit.EARTH, 7, false)


## A papyrus column: slender shaft, banded neck and a closed-bud capital.
static func _papyrus(k: Kit, p: Vector3, h: float, r: float, col: Color, band: Color) -> void:
	k.frustum(p, r * 1.2, r, h * 0.12, col.darkened(0.1), Kit.STONE, 8, false)
	k.frustum(p + Vector3(0, h * 0.12, 0), r, r * 0.8, h * 0.62, col, Kit.PAINT, 8, false)
	k.frustum(p + Vector3(0, h * 0.74, 0), r * 0.95, r * 0.95, h * 0.05, band, Kit.PAINT, 8, false)
	k.frustum(p + Vector3(0, h * 0.79, 0), r * 0.8, r * 1.45, h * 0.12, col.lightened(0.05), Kit.PAINT, 8, false)
	k.frustum(p + Vector3(0, h * 0.91, 0), r * 1.45, r * 0.8, h * 0.09, col, Kit.PAINT, 8, true)


## A shed-roofed wind-catcher (malqaf): open front, sloping lid facing +z.
static func _malqaf(k: Kit, p: Vector3, w: float, d: float, h: float, col: Color, yaw := 0.0) -> void:
	k.push(Kit.at(p, yaw))
	k.box(Vector3(0, 0, 0), Vector3(w, h, d), col, Kit.MUDBRICK)
	# the open mouth with a dark shaft and a sloped lid over it
	k.box(Vector3(0, h * 0.35, d / 2 - 0.002), Vector3(w * 0.7, h * 0.55, 0.012), SHADE, Kit.DARK)
	k.box(Vector3(0, h * 0.35, d / 2 + 0.0), Vector3(w * 0.12, h * 0.55, 0.02), col.darkened(0.1), Kit.MUDBRICK)
	var hd := d / 2.0 + 0.03
	var hw := w / 2.0 + 0.015
	var a := Vector3(-hw, h * 1.0 + 0.03, hd)
	var b := Vector3(hw, h * 1.0 + 0.03, hd)
	var c := Vector3(hw, h * 1.0 + 0.1, -hd)
	var e := Vector3(-hw, h * 1.0 + 0.1, -hd)
	var ctr := Vector3(0, h, 0)
	k.quad(a, b, c, e, col.lightened(0.05), Kit.MUDBRICK, Vector3(0, h - 1, 0))
	k.quad(a, b, Vector3(hw, h, hd), Vector3(-hw, h, hd), col.darkened(0.25), Kit.MUDBRICK, ctr)
	k.quad(c, e, Vector3(-hw, h, -hd), Vector3(hw, h, -hd), col.darkened(0.2), Kit.MUDBRICK, ctr)
	k.tri(a, e, Vector3(-hw, h, -hd), col.darkened(0.1), Kit.MUDBRICK, Vector3(0, h * 0.5, 0))
	k.tri(a, Vector3(-hw, h, hd), Vector3(-hw, h, -hd), col.darkened(0.1), Kit.MUDBRICK, Vector3(0, h * 0.5, 0))
	k.tri(b, c, Vector3(hw, h, -hd), col.darkened(0.1), Kit.MUDBRICK, Vector3(0, h * 0.5, 0))
	k.tri(b, Vector3(hw, h, hd), Vector3(hw, h, -hd), col.darkened(0.1), Kit.MUDBRICK, Vector3(0, h * 0.5, 0))
	k.pop()


## A palm-thatch awning on four posts.
static func _shelter(k: Kit, p: Vector3, w: float, d: float, h: float, rise: float) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var px: float = sx * (w / 2 - 0.02)
			var pz: float = sz * (d / 2 - 0.02)
			k.rod(p + Vector3(px, 0, pz), p + Vector3(px, h, pz), 0.012, WOOD, Kit.TIMBER)
	k.hip_roof(p + Vector3(0, h, 0), w - 0.04, d - 0.04, rise, 0.05, 0.022, REED, Kit.THATCH)


# --- NILE --------------------------------------------------------------------------------------


static func _nile_house_1(k: Kit) -> void:
	# a battered mud-brick house, flat roof with parapet, palm-thatch shelter, outside stair
	k.plinth(Vector3(-0.06, 0, -0.02), 0.78, 0.66, 0.5, 0.045, MUD, Kit.MUDBRICK)
	k.box(Vector3(-0.06, 0.5, -0.02), Vector3(0.70, 0.04, 0.58), MUD_LT, Kit.MUDBRICK)   # roof slab edge
	_parapet(k, Vector3(-0.06, 0.54, -0.02), 0.72, 0.6, 0.07, 0.035, MUD_LT, Kit.MUDBRICK)
	var zf := 0.31
	_arch_door(k, Vector3(-0.2, 0, zf + 0.0), 0.0, 0.15, 0.28, MUD_LT, BLUE, Kit.MUDBRICK)
	for x in [0.06, 0.2]:
		_slot(k, Vector3(x, 0.36, zf - 0.012), 0.0, 0.05, 0.06)
	for z in [-0.12, 0.1]:
		_slot(k, Vector3(0.32, 0.34, z), PI / 2, 0.05, 0.06)
	_slot(k, Vector3(-0.06, 0.38, -0.33 + 0.012), PI, 0.05, 0.06)
	# outside stair up the right side
	_stairs(k, Vector3(0.46, 0, 0.26), 0.0, 0.13, 8, 0.067, 0.07, MUD_LT, Kit.MUDBRICK)
	k.box(Vector3(0.46, 0.5, -0.30), Vector3(0.13, 0.04, 0.12), MUD_LT, Kit.MUDBRICK)
	# roof: thatch shelter, pots
	_shelter(k, Vector3(-0.2, 0.54, -0.04), 0.34, 0.4, 0.2, 0.07)
	_pot(k, Vector3(0.16, 0.54, 0.05), 0.045)
	_pot(k, Vector3(0.24, 0.54, -0.1), 0.035)
	k.box(Vector3(0.14, 0.54, -0.17), Vector3(0.14, 0.03, 0.06), REED, Kit.THATCH)
	_palm(k, Vector3(-0.42, 0, 0.42), 0.55)
	_palm(k, Vector3(0.18, 0, -0.42), 0.42, 6)
	k.box(Vector3(-0.42, 0, 0.0), Vector3(0.04, 0.1, 0.5), MUD_LT, Kit.MUDBRICK)   # yard wall stub


static func _nile_house_2(k: Kit) -> void:
	# a courtyard house with a wind-catcher; walled yard with palms and a granary
	for s in [-1.0, 1.0]:   # yard walls
		var sx: float = s * 0.48
		k.box(Vector3(sx, 0, 0.02), Vector3(0.04, 0.12, 0.96), MUD_LT, Kit.MUDBRICK)
	k.box(Vector3(0, 0, -0.48), Vector3(0.96, 0.12, 0.04), MUD_LT, Kit.MUDBRICK)
	for s in [-1.0, 1.0]:   # gate piers and front wall
		var gx: float = s * 0.34
		k.box(Vector3(gx, 0, 0.48), Vector3(0.28, 0.12, 0.04), MUD_LT, Kit.MUDBRICK)
		var px: float = s * 0.18
		k.box(Vector3(px, 0, 0.48), Vector3(0.06, 0.2, 0.06), MUD, Kit.MUDBRICK)
	k.plinth(Vector3(0, 0, -0.2), 0.84, 0.5, 0.46, 0.04, MUD, Kit.MUDBRICK)
	k.box(Vector3(0, 0.46, -0.2), Vector3(0.78, 0.035, 0.44), MUD_LT, Kit.MUDBRICK)
	_parapet(k, Vector3(0, 0.495, -0.2), 0.78, 0.44, 0.06, 0.03, MUD_LT, Kit.MUDBRICK)
	_arch_door(k, Vector3(0.0, 0, 0.034), 0.0, 0.16, 0.28, MUD_LT, RED, Kit.MUDBRICK)
	for x in [-0.28, 0.28]:
		_slot(k, Vector3(x, 0.28, 0.035), 0.0, 0.06, 0.07)
	_malqaf(k, Vector3(-0.22, 0.495, -0.3), 0.2, 0.15, 0.32, MUD_LT)
	_stairs(k, Vector3(0.4, 0, 0.0), 0.0, 0.1, 6, 0.08, 0.075, MUD_LT, Kit.MUDBRICK)
	_shelter(k, Vector3(0.18, 0.495, -0.24), 0.3, 0.3, 0.15, 0.06)
	_granary(k, Vector3(-0.32, 0, 0.18), 0.1, MUD)
	_granary(k, Vector3(-0.2, 0, 0.3), 0.07, MUD_LT)
	_palm(k, Vector3(0.34, 0, 0.3), 0.6)
	_palm(k, Vector3(-0.38, 0, -0.38), 0.5, 6)
	_pot(k, Vector3(0.12, 0, 0.3), 0.04)
	k.box(Vector3(0.0, 0, 0.32), Vector3(0.1, 0.04, 0.08), WATER_BLUE, Kit.WATER)


const WATER_BLUE := Color(0.25, 0.5, 0.6)


static func _nile_house_3(k: Kit) -> void:
	# a two-level house: a front block, a upper room set back, awning, domed granaries
	k.plinth(Vector3(-0.08, 0, 0.0), 0.8, 0.7, 0.36, 0.035, LIME, Kit.MUDBRICK)
	k.box(Vector3(-0.08, 0.36, 0.0), Vector3(0.74, 0.03, 0.64), MUD_LT, Kit.MUDBRICK)
	_parapet(k, Vector3(-0.08, 0.39, 0.0), 0.74, 0.64, 0.05, 0.03, MUD_LT, Kit.MUDBRICK)
	k.plinth(Vector3(-0.2, 0.39, -0.1), 0.48, 0.42, 0.32, 0.03, WHITE, Kit.MUDBRICK)
	k.box(Vector3(-0.2, 0.71, -0.1), Vector3(0.44, 0.03, 0.38), MUD_LT, Kit.MUDBRICK)
	_parapet(k, Vector3(-0.2, 0.74, -0.1), 0.44, 0.38, 0.05, 0.03, MUD_LT, Kit.MUDBRICK)
	_arch_door(k, Vector3(-0.2, 0, 0.35), 0.0, 0.14, 0.24, WHITE, BLUE, Kit.MUDBRICK)
	_slot(k, Vector3(0.1, 0.22, 0.35), 0.0, 0.06, 0.07)
	_slot(k, Vector3(-0.35, 0.22, 0.35), 0.0, 0.05, 0.07)
	_slot(k, Vector3(-0.2, 0.5, 0.12), 0.0, 0.06, 0.08, WHITE)
	_slot(k, Vector3(-0.42, 0.5, -0.1), -PI / 2, 0.05, 0.07, WHITE)
	# a red painted band under the parapet of the upper room
	k.box(Vector3(-0.2, 0.67, -0.1), Vector3(0.456, 0.025, 0.396), RED, Kit.PAINT)
	_stairs(k, Vector3(0.12, 0, 0.2), PI / 2 * 0.0, 0.12, 5, 0.072, 0.08, MUD_LT, Kit.MUDBRICK)
	_shelter(k, Vector3(0.12, 0.39, -0.12), 0.34, 0.3, 0.17, 0.06)
	_granary(k, Vector3(0.38, 0, -0.3), 0.11, MUD)
	_granary(k, Vector3(0.36, 0, 0.2), 0.08, MUD_LT)
	_palm(k, Vector3(0.44, 0, 0.42), 0.6)
	_pot(k, Vector3(-0.32, 0.39, 0.2), 0.04)
	_pot(k, Vector3(-0.08, 0.39, 0.22), 0.035)


static func _nile_house_4(k: Kit) -> void:
	# a tall dovecote tower house with pigeon holes and a lean-to
	k.plinth(Vector3(-0.14, 0, -0.1), 0.6, 0.56, 0.95, 0.07, WHITE, Kit.MUDBRICK)
	var zc := -0.1
	for y in [0.55, 0.66, 0.77]:
		for i in 4:
			var x: float = -0.14 - 0.18 + i * 0.12
			_slot(k, Vector3(x, y, 0.18 - 0.0), 0.0, 0.035, 0.04, WHITE)
	_arch_door(k, Vector3(-0.14, 0, 0.18), 0.0, 0.13, 0.26, WHITE, OCHRE, Kit.MUDBRICK)
	for s in [-1.0, 1.0]:
		_slot(k, Vector3(-0.14 + s * 0.2, 0.28, 0.18), 0.0, 0.04, 0.06, WHITE)
	# cavetto-style cornice and a band
	k.box(Vector3(-0.14, 0.95, -0.1), Vector3(0.58, 0.04, 0.54), MUD_LT, Kit.MUDBRICK)
	k.box(Vector3(-0.14, 0.99, -0.1), Vector3(0.64, 0.04, 0.6), WHITE, Kit.MUDBRICK)
	_parapet(k, Vector3(-0.14, 1.03, -0.1), 0.62, 0.58, 0.05, 0.03, WHITE, Kit.MUDBRICK)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:   # horned corner pinnacles
			var cx: float = -0.14 + sx * 0.29
			var cz: float = -0.1 + sz * 0.27
			k.plinth(Vector3(cx, 1.03, cz), 0.07, 0.07, 0.08, 0.02, MUD_LT, Kit.MUDBRICK)
	k.box(Vector3(-0.14, 0.62, 0.173), Vector3(0.44, 0.018, 0.02), RED, Kit.PAINT)
	k.box(Vector3(-0.14, 0.43, 0.185), Vector3(0.5, 0.018, 0.02), BLUE, Kit.PAINT)
	# lean-to with a sloping thatch roof
	k.plinth(Vector3(0.36, 0, -0.1), 0.3, 0.44, 0.28, 0.03, MUD, Kit.MUDBRICK)
	_shelter(k, Vector3(0.36, 0.3, -0.1), 0.28, 0.42, 0.1, 0.05)
	_stairs(k, Vector3(0.36, 0, 0.3), 0.0, 0.1, 4, 0.07, 0.07, MUD_LT, Kit.MUDBRICK)
	_palm(k, Vector3(-0.42, 0, 0.38), 0.6)
	_palm(k, Vector3(0.45, 0, 0.3), 0.5, 6)
	_pot(k, Vector3(0.1, 0, 0.3), 0.04)
	_pot(k, Vector3(0.16, 0, 0.36), 0.03)


## A box that flares outward going up (a cavetto cornice): bottom w x d, top grown by `grow`.
static func _flare(k: Kit, foot: Vector3, w: float, d: float, h: float, grow: float, col: Color, mat: int) -> void:
	k.push(Kit.at(foot))
	var a := [Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0, -d / 2), Vector3(w / 2, 0, d / 2), Vector3(-w / 2, 0, d / 2)]
	var b := [Vector3(-w / 2 - grow, h, -d / 2 - grow), Vector3(w / 2 + grow, h, -d / 2 - grow),
		Vector3(w / 2 + grow, h, d / 2 + grow), Vector3(-w / 2 - grow, h, d / 2 + grow)]
	var c := Vector3(0, h * 0.4, 0)
	for i in 4:
		var j := (i + 1) % 4
		k.quad(a[i], a[j], b[j], b[i], col, mat, c)
	k.quad(b[0], b[1], b[2], b[3], col.lightened(0.05), mat, c)
	k.pop()


static func _obelisk_shape(k: Kit, p: Vector3, w: float, h: float, marks := true) -> void:
	var top := w * 0.58
	var inset := (w - top) / 2.0
	k.box(p, Vector3(w * 1.35, 0.035, w * 1.35), STONE_GR, Kit.STONE)
	k.plinth(p + Vector3(0, 0.035, 0), w, w, h, inset, Color(0.78, 0.5, 0.45), Kit.STONE)
	k.plinth(p + Vector3(0, 0.035 + h, 0), top, top, w * 0.6, top / 2.0, GILD, Kit.GOLD)
	if marks:
		for i in 4:
			k.push(Kit.at(p, i * PI / 2.0))
			for dx in [-0.22, 0.0, 0.22]:
				var x: float = dx * w
				var y0 := 0.035 + h * 0.12
				var y1 := 0.035 + h * 0.86
				var z0 := w / 2.0 - inset * (y0 - 0.035) / h + 0.003
				var z1 := w / 2.0 - inset * (y1 - 0.035) / h + 0.003
				k.quad(Vector3(x - w * 0.025, y0, z0), Vector3(x + w * 0.025, y0, z0), Vector3(x + w * 0.025, y1, z1),
					Vector3(x - w * 0.025, y1, z1), Color(0.42, 0.24, 0.2), Kit.PAINT, Vector3(x, (y0 + y1) / 2, 0))
			k.pop()


static func _nile_palace(k: Kit) -> void:
	k.box(Vector3.ZERO, Vector3(3.1, 0.03, 3.1), Color(0.84, 0.76, 0.58), Kit.EARTH)
	var zc := 1.2
	var pw := 0.95
	var pd := 0.5
	var ph := 1.1
	var ins := 0.07
	# --- the great pylon: two tapering towers and a gate between
	for s in [-1.0, 1.0]:
		var cx: float = s * 0.84
		k.plinth(Vector3(cx, 0, zc), pw, pd, ph, ins, STONE_LT, Kit.STONE)
		_flare(k, Vector3(cx, ph, zc), pw - ins * 2.0, pd - ins * 2.0, 0.07, 0.03, STONE_LT, Kit.STONE)
		_band(k, cx, pw - ins * 2.5, 0.82, 0.87, zc, pd / 2, ins, ph, BLUE)
		_band(k, cx, pw - ins * 2.5, 0.87, 0.91, zc, pd / 2, ins, ph, GILD, Kit.GOLD)
		_band(k, cx, pw - ins * 2.5, 0.91, 0.96, zc, pd / 2, ins, ph, RED)
		_band(k, cx, pw - ins * 2.5, 0.08, 0.12, zc, pd / 2, ins, ph, BLUE)
		for t in [-1.0, 1.0]:   # flagpole grooves and masts with pennants
			var gx: float = cx + t * 0.27
			_band(k, gx, 0.07, 0.14, 0.8, zc, pd / 2, ins, ph, Color(0.24, 0.17, 0.12), Kit.DARK)
			var zf: float = zc + pd / 2 - ins * 0.2 / ph + 0.03
			k.banner(Vector3(gx, 0.2, zf), 1.25, 0.26, 0.0)
		for t in [-1.0, 1.0]:   # corner rolls
			for u in [-1.0, 1.0]:
				var rx: float = cx + t * (pw / 2 - 0.01)
				var rz: float = zc + u * (pd / 2 - 0.01)
				var tx: float = cx + t * (pw / 2 - ins - 0.01)
				var tz: float = zc + u * (pd / 2 - ins - 0.01)
				k.rod(Vector3(rx, 0.0, rz), Vector3(tx, ph, tz), 0.014, STONE_GR, Kit.STONE)
		# painted relief panel
		_band(k, cx, 0.5, 0.3, 0.62, zc, pd / 2, ins, ph, Color(0.72, 0.6, 0.42), Kit.PAINT)
		_band(k, cx, 0.32, 0.38, 0.54, zc, pd / 2, ins, ph, RED.lightened(0.1), Kit.PAINT)
	k.box(Vector3(0, 0.62, zc), Vector3(0.78, 0.38, 0.42), STONE_LT, Kit.STONE)   # lintel block over the gate
	_flare(k, Vector3(0, ph, zc), 0.78, 0.42, 0.07, 0.03, STONE_LT, Kit.STONE)
	k.box(Vector3(0, 0.0, zc + 0.205), Vector3(0.44, 0.62, 0.03), SHADE, Kit.DARK)   # the gateway
	for s in [-1.0, 1.0]:
		var jx: float = s * 0.26
		k.box(Vector3(jx, 0, zc + 0.2), Vector3(0.07, 0.64, 0.05), GILD, Kit.GOLD)
	k.box(Vector3(0, 0.62, zc + 0.2), Vector3(0.58, 0.05, 0.05), GILD, Kit.GOLD)
	# winged sun disc over the gate
	k.polygon([Vector3(-0.05, 0.81, zc + 0.215), Vector3(0.05, 0.81, zc + 0.215), Vector3(0.07, 0.88, zc + 0.215),
		Vector3(0, 0.94, zc + 0.215), Vector3(-0.07, 0.88, zc + 0.215)], GILD, Kit.GOLD, Vector3(0, 0.85, zc))
	for s in [-1.0, 1.0]:
		var wx: float = s
		k.quad(Vector3(wx * 0.07, 0.86, zc + 0.215), Vector3(wx * 0.3, 0.9, zc + 0.215), Vector3(wx * 0.3, 0.85, zc + 0.215),
			Vector3(wx * 0.07, 0.82, zc + 0.215), BLUE, Kit.PAINT, Vector3(0, 0.85, zc))
		k.quad(Vector3(wx * 0.07, 0.82, zc + 0.215), Vector3(wx * 0.28, 0.85, zc + 0.215), Vector3(wx * 0.25, 0.8, zc + 0.215),
			Vector3(wx * 0.07, 0.78, zc + 0.215), RED, Kit.PAINT, Vector3(0, 0.85, zc))
	# obelisks and palms before the pylon
	for s in [-1.0, 1.0]:
		var ox: float = s * 0.52
		_obelisk_shape(k, Vector3(ox, 0.03, 1.5), 0.1, 0.62, false)
		_palm(k, Vector3(s * 1.42, 0.03, 1.4), 0.6)
		_palm(k, Vector3(s * 1.48, 0.03, 0.95), 0.5, 6)
	# --- the open court: colonnades, a sacred pool and an altar
	for s in [-1.0, 1.0]:
		var wx2: float = s * 1.42
		k.box(Vector3(wx2, 0.03, 0.4), Vector3(0.07, 0.46, 1.1), STONE_LT, Kit.STONE)
		k.box(Vector3(wx2 - s * 0.036, 0.4, 0.4), Vector3(0.01, 0.045, 1.08), BLUE, Kit.PAINT)
		k.box(Vector3(wx2 - s * 0.036, 0.3, 0.4), Vector3(0.01, 0.02, 1.08), RED, Kit.PAINT)
		var rx2: float = s * 1.26
		k.box(Vector3(rx2, 0.49, 0.4), Vector3(0.36, 0.045, 1.1), STONE_LT, Kit.STONE)
		k.box(Vector3(s * 1.09, 0.49, 0.4), Vector3(0.03, 0.045, 1.12), GILD, Kit.GOLD)
		for i in 5:
			var z: float = 0.88 - i * 0.24
			_papyrus(k, Vector3(s * 1.12, 0.03, z), 0.46, 0.04, WHITE, RED)
	k.box(Vector3(0, 0.03, 0.35), Vector3(0.62, 0.05, 0.78), STONE_GR, Kit.STONE)
	k.box(Vector3(0, 0.03, 0.35), Vector3(0.52, 0.056, 0.68), WATER_BLUE, Kit.WATER)
	k.box(Vector3(0, 0.03, -0.0), Vector3(0.2, 0.09, 0.1), STONE_LT, Kit.STONE)   # altar
	k.box(Vector3(0, 0.12, -0.0), Vector3(0.14, 0.03, 0.08), GILD, Kit.GOLD)
	# --- the hypostyle hall
	var hx := 1.0
	var hz0 := -0.9
	var hz1 := -0.05
	k.box(Vector3(0, 0.03, (hz0 + hz1) / 2.0), Vector3(hx * 2.0, 0.6, hz1 - hz0), STONE_LT, Kit.STONE)
	_flare(k, Vector3(0, 0.63, (hz0 + hz1) / 2.0), hx * 2.0 + 0.04, hz1 - hz0 + 0.04, 0.06, 0.04, STONE_LT, Kit.STONE)
	k.box(Vector3(0, 0.69, (hz0 + hz1) / 2.0), Vector3(hx * 2.0 + 0.2, 0.04, hz1 - hz0 + 0.2), STONE_LT.darkened(0.06), Kit.STONE)
	k.box(Vector3(0, 0.73, (hz0 + hz1) / 2.0 - 0.05), Vector3(1.1, 0.14, 0.5), STONE_LT, Kit.STONE)   # raised nave
	k.box(Vector3(0, 0.73, (hz0 + hz1) / 2.0 + 0.2), Vector3(1.1, 0.08, 0.02), SHADE, Kit.DARK)
	for i in 5:
		var wx3: float = -0.4 + i * 0.2
		k.box(Vector3(wx3, 0.78, (hz0 + hz1) / 2.0 + 0.21), Vector3(0.06, 0.05, 0.02), SHADE, Kit.DARK)
	k.box(Vector3(0, 0.87, (hz0 + hz1) / 2.0 - 0.05), Vector3(1.2, 0.04, 0.6), STONE_LT, Kit.STONE)
	k.box(Vector3(0, 0.73, (hz0 + hz1) / 2.0 - 0.05), Vector3(1.12, 0.14, 0.52), STONE_LT, Kit.STONE)
	k.box(Vector3(0, 0.44, hz1 + 0.012), Vector3(2.0, 0.035, 0.012), BLUE, Kit.PAINT)   # painted frieze
	k.box(Vector3(0, 0.4, hz1 + 0.012), Vector3(2.0, 0.025, 0.012), GILD, Kit.GOLD)
	k.box(Vector3(0, 0.03, hz1 + 0.012), Vector3(0.3, 0.42, 0.012), SHADE, Kit.DARK)   # dark doorway
	for i in 6:   # the front colonnade
		var cx2: float = -0.75 + i * 0.3
		_papyrus(k, Vector3(cx2, 0.03, hz1 + 0.1), 0.6, 0.05, WHITE, BLUE)
	k.box(Vector3(0, 0.03, hz1 + 0.1), Vector3(1.7, 0.035, 0.06), STONE_GR, Kit.STONE)
	# --- the sanctuary
	k.box(Vector3(0, 0.03, -1.2), Vector3(1.1, 0.46, 0.58), STONE_LT, Kit.STONE)
	_flare(k, Vector3(0, 0.49, -1.2), 1.1, 0.58, 0.05, 0.035, STONE_LT, Kit.STONE)
	k.box(Vector3(0, 0.3, -0.906), Vector3(0.5, 0.025, 0.012), RED, Kit.PAINT)
	k.box(Vector3(0, 0.34, -0.906), Vector3(0.5, 0.025, 0.012), BLUE, Kit.PAINT)
	k.box(Vector3(0, 0.03, -0.906), Vector3(0.14, 0.24, 0.012), SHADE, Kit.DARK)
	# --- the mud-brick enclosure
	k.box(Vector3(0, 0.03, -1.55), Vector3(3.0, 0.24, 0.06), MUD, Kit.MUDBRICK)
	for s in [-1.0, 1.0]:
		var ex: float = s * 1.55
		k.box(Vector3(ex, 0.03, -0.45), Vector3(0.06, 0.2, 2.2), MUD, Kit.MUDBRICK)
		_palm(k, Vector3(s * 1.2, 0.03, -1.25), 0.6)
		_palm(k, Vector3(s * 1.3, 0.03, -0.9), 0.5, 6)


static func _pyramid(k: Kit) -> void:
	var cx := -0.3
	var cz := -0.35
	k.box(Vector3(cx, 0, cz), Vector3(2.3, 0.04, 2.3), Color(0.82, 0.74, 0.56), Kit.EARTH)
	var half := 1.0
	var ht := 1.45
	var bands := 7
	var y := 0.04
	var layer_h := (ht - 0.25 - 0.04) / bands
	for i in bands:
		var y0 := y + i * layer_h
		var f0 := 1.0 - (y0 - 0.04) / (ht - 0.04)
		var f1 := 1.0 - (y0 + layer_h - 0.04) / (ht - 0.04)
		var w0 := half * 2.0 * f0
		var w1 := half * 2.0 * f1
		var col := Color(0.90, 0.85, 0.70) if i % 2 == 0 else Color(0.86, 0.80, 0.66)
		k.plinth(Vector3(cx, y0, cz), w0, w0, layer_h, (w0 - w1) / 2.0, col, Kit.STONE)
	var ytop := y + bands * layer_h
	var wt := half * 2.0 * (1.0 - (ytop - 0.04) / (ht - 0.04))
	k.plinth(Vector3(cx, ytop, cz), wt, wt, 0.25, wt / 2.0, GILD, Kit.GOLD)
	# entrance on the front face
	var fy := 0.55
	var zf := cz + half * (1.0 - (fy - 0.04) / (ht - 0.04))
	k.box(Vector3(cx, fy, zf - 0.02), Vector3(0.12, 0.1, 0.05), SHADE, Kit.DARK)
	# queens' pyramids
	for q in [0.0, 1.0]:
		var qz: float = -0.85 + q * 0.75
		var qw := 0.6
		k.box(Vector3(1.15, 0, qz), Vector3(0.7, 0.03, 0.7), Color(0.82, 0.74, 0.56), Kit.EARTH)
		k.plinth(Vector3(1.15, 0.03, qz), qw, qw, 0.34, qw / 2.0 * 0.86, Color(0.88, 0.82, 0.68), Kit.STONE)
		k.plinth(Vector3(1.15, 0.37, qz), qw * 0.14, qw * 0.14, 0.05, qw * 0.07, GILD, Kit.GOLD)
	# causeway and mortuary temple
	k.box(Vector3(cx, 0, 1.0), Vector3(0.3, 0.05, 0.7), Color(0.8, 0.74, 0.62), Kit.STONE)
	k.box(Vector3(cx, 0.05, 1.18), Vector3(0.7, 0.16, 0.28), STONE_LT, Kit.STONE)
	k.box(Vector3(cx, 0.21, 1.18), Vector3(0.76, 0.03, 0.34), STONE_GR, Kit.STONE)
	for s in [-1.0, 1.0]:
		k.box(Vector3(cx + s * 0.2, 0.05, 1.325), Vector3(0.06, 0.15, 0.03), SHADE, Kit.DARK)
	k.box(Vector3(cx, 0.05, 1.325), Vector3(0.08, 0.1, 0.03), SHADE, Kit.DARK)
	_palm(k, Vector3(0.45, 0, 1.2), 0.5)
	_palm(k, Vector3(-1.2, 0, 1.25), 0.45, 6)


static func _obelisk(k: Kit) -> void:
	_obelisk_shape(k, Vector3.ZERO, 0.22, 1.25, true)
	k.box(Vector3.ZERO, Vector3(0.4, 0.03, 0.4), STONE_GR.darkened(0.1), Kit.STONE)


static func _sphinx(k: Kit) -> void:
	var sand := Color(0.86, 0.74, 0.52)
	var sand_d := Color(0.80, 0.68, 0.46)
	k.box(Vector3(0, 0, 0), Vector3(1.6, 0.05, 0.78), Color(0.8, 0.72, 0.56), Kit.STONE)
	k.box(Vector3(0.1, 0.05, 0), Vector3(1.3, 0.04, 0.62), Color(0.76, 0.68, 0.52), Kit.STONE)
	# body, lying with its front toward +x
	k.bevel_box(Vector3(-0.42, 0.09, 0), Vector3(0.56, 0.3, 0.44), 0.06, sand, Kit.STONE)   # haunches
	k.bevel_box(Vector3(-0.05, 0.09, 0), Vector3(0.5, 0.26, 0.34), 0.05, sand_d, Kit.STONE)   # back
	k.bevel_box(Vector3(0.24, 0.09, 0), Vector3(0.32, 0.36, 0.36), 0.06, sand, Kit.STONE)   # chest
	for s in [-1.0, 1.0]:
		var lz: float = s * 0.14
		k.box(Vector3(0.5, 0.09, lz), Vector3(0.5, 0.11, 0.1), sand, Kit.STONE)   # forelegs
		k.bevel_box(Vector3(0.72, 0.09, lz), Vector3(0.12, 0.07, 0.12), 0.02, sand_d, Kit.STONE)   # paws
		for t in [-1.0, 1.0]:
			var tz: float = lz + t * 0.03
			k.box(Vector3(0.79, 0.09, tz), Vector3(0.012, 0.05, 0.02), sand_d.darkened(0.2), Kit.STONE)
		k.box(Vector3(-0.58, 0.09, s * 0.24), Vector3(0.2, 0.06, 0.08), sand_d, Kit.STONE)   # hind feet
	k.rod(Vector3(-0.7, 0.2, 0.0), Vector3(-0.78, 0.12, 0.16), 0.02, sand_d, Kit.STONE)   # tail
	# neck and head with nemes headdress
	k.bevel_box(Vector3(0.34, 0.4, 0), Vector3(0.2, 0.2, 0.24), 0.04, sand, Kit.STONE)
	var hx := 0.4
	k.box(Vector3(hx, 0.58, 0), Vector3(0.2, 0.26, 0.26), BLUE, Kit.PAINT)       # headcloth crown
	for i in 4:
		var sx: float = hx - 0.08 + i * 0.054
		k.box(Vector3(sx, 0.58, 0), Vector3(0.02, 0.27, 0.268), GILD, Kit.GOLD)   # gold stripes
	k.box(Vector3(hx + 0.01, 0.84, 0), Vector3(0.18, 0.02, 0.22), GILD, Kit.GOLD)
	for s in [-1.0, 1.0]:   # lappets framing the face
		var lz2: float = s * 0.15
		k.box(Vector3(hx + 0.07, 0.41, lz2), Vector3(0.1, 0.24, 0.05), BLUE, Kit.PAINT)
		k.box(Vector3(hx + 0.121, 0.41, lz2), Vector3(0.012, 0.24, 0.05), GILD, Kit.GOLD)
	k.box(Vector3(hx + 0.115, 0.5, 0), Vector3(0.05, 0.28, 0.2), sand, Kit.STONE)   # face
	k.box(Vector3(hx + 0.145, 0.57, 0), Vector3(0.03, 0.06, 0.05), sand_d, Kit.STONE)   # nose
	for s in [-1.0, 1.0]:
		var ez: float = s * 0.06
		k.box(Vector3(hx + 0.142, 0.62, ez), Vector3(0.012, 0.025, 0.04), SHADE, Kit.DARK)
	k.box(Vector3(hx + 0.142, 0.53, 0), Vector3(0.012, 0.014, 0.08), RED.darkened(0.2), Kit.PAINT)   # mouth
	k.box(Vector3(hx + 0.13, 0.42, 0), Vector3(0.03, 0.1, 0.05), sand_d, Kit.STONE)   # beard
	k.box(Vector3(hx + 0.12, 0.83, 0), Vector3(0.025, 0.07, 0.025), GILD, Kit.GOLD)   # uraeus


# --- NEAR EAST ---------------------------------------------------------------------------------


## A terrace railing: corner and spaced posts with a top rail.
static func _railing(k: Kit, foot: Vector3, w: float, d: float, h: float, col: Color, gap_front := 0.0) -> void:
	var r := 0.011
	var nx := maxi(2, int(w / 0.12))
	var nz := maxi(2, int(d / 0.12))
	for i in nx + 1:
		var x: float = -w / 2 + w * i / float(nx)
		k.rod(foot + Vector3(x, 0, -d / 2), foot + Vector3(x, h, -d / 2), r, col, Kit.TIMBER)
		if absf(x) >= gap_front / 2.0:
			k.rod(foot + Vector3(x, 0, d / 2), foot + Vector3(x, h, d / 2), r, col, Kit.TIMBER)
	for i in range(1, nz):
		var z: float = -d / 2 + d * i / float(nz)
		k.rod(foot + Vector3(-w / 2, 0, z), foot + Vector3(-w / 2, h, z), r, col, Kit.TIMBER)
		k.rod(foot + Vector3(w / 2, 0, z), foot + Vector3(w / 2, h, z), r, col, Kit.TIMBER)
	var top := Vector3(0, h, 0)
	k.rod(foot + top + Vector3(-w / 2, 0, -d / 2), foot + top + Vector3(w / 2, 0, -d / 2), r * 1.2, col, Kit.TIMBER)
	k.rod(foot + top + Vector3(-w / 2, 0, d / 2), foot + top + Vector3(w / 2, 0, d / 2), r * 1.2, col, Kit.TIMBER)
	k.rod(foot + top + Vector3(-w / 2, 0, -d / 2), foot + top + Vector3(-w / 2, 0, d / 2), r * 1.2, col, Kit.TIMBER)
	k.rod(foot + top + Vector3(w / 2, 0, -d / 2), foot + top + Vector3(w / 2, 0, d / 2), r * 1.2, col, Kit.TIMBER)


## A badgir (wind tower): square shaft with slotted openings near the top and a cap.
static func _badgir(k: Kit, p: Vector3, w: float, h: float, col: Color, mat: int) -> void:
	k.box(p, Vector3(w, h, w), col, mat)
	k.box(p + Vector3(0, h, 0), Vector3(w * 1.12, 0.03, w * 1.12), col.lightened(0.04), mat)
	for i in 4:
		k.push(Kit.at(p + Vector3(0, 0, 0), i * PI / 2.0))
		for dx in [-0.25, 0.25]:
			var x: float = dx * w
			k.box(Vector3(x, h * 0.72, w / 2.0 - 0.01), Vector3(w * 0.16, h * 0.24, 0.025), SHADE, Kit.DARK)
		k.box(Vector3(0, h * 0.7, w / 2.0), Vector3(w * 0.9, 0.018, 0.03), col.darkened(0.12), mat)
		k.pop()
	k.plinth(p + Vector3(0, h + 0.03, 0), w * 1.0, w * 1.0, w * 0.35, w * 0.3, col.darkened(0.06), mat)


static func _ne_house_1(k: Kit) -> void:
	# whitewashed cube house crowned by a dome, a terrace beside it
	k.box(Vector3(0, 0, 0.0), Vector3(0.9, 0.06, 0.78), STONE_GR, Kit.STONE)
	k.box(Vector3(-0.1, 0.06, -0.04), Vector3(0.7, 0.5, 0.66), WHITE, Kit.PLASTER)
	k.box(Vector3(-0.1, 0.56, -0.04), Vector3(0.76, 0.04, 0.72), LIME.darkened(0.04), Kit.PLASTER)   # cornice
	k.box(Vector3(0.28, 0.06, -0.1), Vector3(0.28, 0.34, 0.5), WHITE.darkened(0.03), Kit.PLASTER)
	k.box(Vector3(0.28, 0.4, -0.1), Vector3(0.32, 0.035, 0.54), LIME.darkened(0.04), Kit.PLASTER)
	_parapet(k, Vector3(0.28, 0.435, -0.1), 0.32, 0.54, 0.05, 0.03, WHITE, Kit.PLASTER)
	_railing(k, Vector3(0.28, 0.435, -0.1), 0.26, 0.48, 0.1, WOOD)
	# drum and dome on the main block
	k.frustum(Vector3(-0.2, 0.6, -0.1), 0.2, 0.2, 0.1, WHITE, Kit.PLASTER, 12, false)
	k.dome(Vector3(-0.2, 0.7, -0.1), 0.2, WHITE, Kit.PLASTER, 0.95, 5, 14)
	k.cylinder(Vector3(-0.2, 0.89, -0.1), 0.014, 0.1, GILD, Kit.GOLD, 5)
	k.dome(Vector3(-0.2, 0.97, -0.1), 0.03, GILD, Kit.GOLD, 1.0, 2, 6)
	for i in 4:
		var a := PI / 12 + i * PI / 2
		_arch(k, Vector3(-0.2 + cos(a) * 0.194, 0.62, -0.1 + sin(a) * 0.194), PI / 2 - a, 0.05, 0.08)
	# the blue arched door and windows
	_arch_door(k, Vector3(-0.28, 0.06, 0.29), 0.0, 0.17, 0.32, LIME, BLUE)
	for x in [0.0, 0.1]:
		_arch(k, Vector3(x + 0.0, 0.34, 0.29), 0.0, 0.06, 0.12)
	_arch(k, Vector3(0.28, 0.17, 0.155), 0.0, 0.1, 0.17, SHADE)
	k.box(Vector3(0.28, 0.06, 0.16), Vector3(0.2, 0.025, 0.02), BLUE, Kit.PAINT)
	k.box(Vector3(-0.1, 0.5, 0.292), Vector3(0.7, 0.03, 0.02), BLUE, Kit.PAINT)   # glazed band under cornice
	_arch(k, Vector3(-0.451, 0.28, -0.1), -PI / 2, 0.07, 0.15)
	_stairs(k, Vector3(0.28, 0.06, 0.4), 0.0, 0.14, 5, 0.07, 0.06, LIME, Kit.PLASTER)
	_pot(k, Vector3(0.4, 0.44, 0.1), 0.035)


static func _ne_house_2(k: Kit) -> void:
	# mud-brick house with a tall wind tower (badgir)
	k.box(Vector3(0.0, 0, 0.0), Vector3(0.92, 0.04, 0.8), MUD_LT.darkened(0.1), Kit.EARTH)
	k.box(Vector3(0.0, 0.04, 0.04), Vector3(0.86, 0.48, 0.64), MUD, Kit.MUDBRICK)
	k.box(Vector3(0.0, 0.52, 0.04), Vector3(0.9, 0.035, 0.68), MUD_LT, Kit.MUDBRICK)
	_parapet(k, Vector3(0.0, 0.555, 0.04), 0.9, 0.68, 0.07, 0.04, MUD_LT, Kit.MUDBRICK)
	_merlons(k, Vector3(0.0, 0.625, 0.04), 0.9, 0.68, 0.06, 0.04, MUD_LT, Kit.MUDBRICK)
	_badgir(k, Vector3(-0.26, 0.555, -0.14), 0.22, 0.46, MUD, Kit.MUDBRICK)
	_arch_door(k, Vector3(0.12, 0.04, 0.36), 0.0, 0.17, 0.3, MUD_LT, TURQ, Kit.MUDBRICK)
	for x in [-0.28, -0.1, 0.34]:
		_arch(k, Vector3(x, 0.3, 0.362), 0.0, 0.055, 0.12)
	_arch(k, Vector3(0.435, 0.28, 0.1), PI / 2, 0.07, 0.14)
	k.box(Vector3(0.0, 0.46, 0.363), Vector3(0.86, 0.025, 0.018), TURQ, Kit.PAINT)
	k.dome(Vector3(0.24, 0.555, -0.1), 0.15, MUD_LT, Kit.MUDBRICK, 0.9, 4, 10)
	k.box(Vector3(0.24, 0.555, -0.1), Vector3(0.0, 0.0, 0.0), MUD, Kit.MUDBRICK)
	_pot(k, Vector3(-0.38, 0.555, 0.25), 0.035)
	_palm(k, Vector3(0.4, 0, 0.45), 0.55, 6)
	k.box(Vector3(-0.42, 0.04, 0.43), Vector3(0.12, 0.1, 0.08), MUD_LT, Kit.MUDBRICK)


static func _ne_house_3(k: Kit) -> void:
	# courtyard house: walls round a court with a tree and a pool; wings with domes
	var wall := WHITE.darkened(0.04)
	k.box(Vector3(0, 0, 0), Vector3(1.0, 0.03, 1.0), Color(0.76, 0.68, 0.52), Kit.EARTH)
	k.box(Vector3(0, 0.03, -0.38), Vector3(0.98, 0.42, 0.22), wall, Kit.PLASTER)   # rear wing
	k.box(Vector3(0, 0.45, -0.38), Vector3(1.0, 0.035, 0.26), LIME, Kit.PLASTER)
	k.box(Vector3(-0.38, 0.03, 0.0), Vector3(0.22, 0.36, 0.54), wall, Kit.PLASTER)   # left wing
	k.box(Vector3(-0.38, 0.39, 0.0), Vector3(0.26, 0.035, 0.58), LIME, Kit.PLASTER)
	k.box(Vector3(0.38, 0.03, 0.0), Vector3(0.22, 0.3, 0.54), wall, Kit.PLASTER)   # right wing
	k.box(Vector3(0.38, 0.33, 0.0), Vector3(0.26, 0.035, 0.58), LIME, Kit.PLASTER)
	# front wall with a gate arch
	for s in [-1.0, 1.0]:
		var fx: float = s * 0.3
		k.box(Vector3(fx, 0.03, 0.46), Vector3(0.38, 0.3, 0.07), wall, Kit.PLASTER)
		k.box(Vector3(fx, 0.33, 0.46), Vector3(0.42, 0.03, 0.1), LIME, Kit.PLASTER)
	k.box(Vector3(0, 0.3, 0.46), Vector3(0.24, 0.1, 0.07), wall, Kit.PLASTER)
	k.box(Vector3(0, 0.4, 0.46), Vector3(0.32, 0.03, 0.1), LIME, Kit.PLASTER)
	_arch_door(k, Vector3(0, 0.03, 0.5), 0.0, 0.18, 0.28, LIME, BLUE)
	k.box(Vector3(0, 0.32, 0.505), Vector3(0.26, 0.02, 0.02), TURQ, Kit.PAINT)
	# domes over wing rooms
	k.frustum(Vector3(0, 0.48, -0.38), 0.17, 0.17, 0.06, wall, Kit.PLASTER, 10, false)
	k.dome(Vector3(0, 0.54, -0.38), 0.17, TURQ, Kit.PAINT, 0.9, 4, 12)
	k.dome(Vector3(-0.38, 0.425, 0.02), 0.12, WHITE, Kit.PLASTER, 0.9, 4, 10)
	_arch(k, Vector3(0, 0.03, -0.268), 0.0, 0.14, 0.28)
	_arch(k, Vector3(-0.268, 0.03, 0.0), PI / 2, 0.12, 0.22)
	_arch(k, Vector3(0.268, 0.03, 0.0), -PI / 2, 0.12, 0.2)
	k.box(Vector3(0, 0.03, -0.268), Vector3(0.28, 0.02, 0.02), BLUE, Kit.PAINT)
	# court: pool, tree
	k.box(Vector3(0, 0.03, 0.05), Vector3(0.26, 0.04, 0.2), STONE_GR, Kit.STONE)
	k.box(Vector3(0, 0.03, 0.05), Vector3(0.22, 0.045, 0.16), WATER_BLUE, Kit.WATER)
	k.frustum(Vector3(0.2, 0.03, 0.2), 0.02, 0.014, 0.18, WOOD, Kit.TIMBER, 5, false)
	k.dome(Vector3(0.2, 0.17, 0.2), 0.11, Color(0.34, 0.52, 0.24), Kit.LEAF, 0.8, 3, 8)
	k.frustum(Vector3(-0.2, 0.03, 0.22), 0.02, 0.014, 0.15, WOOD, Kit.TIMBER, 5, false)
	k.dome(Vector3(-0.2, 0.15, 0.22), 0.09, Color(0.28, 0.48, 0.22), Kit.LEAF, 0.8, 3, 8)
	_badgir(k, Vector3(0.38, 0.365, -0.3), 0.14, 0.2, wall, Kit.PLASTER)


static func _ne_house_4(k: Kit) -> void:
	# two-storey townhouse: timber-latticed balcony, roof terrace and a small dome
	k.box(Vector3(0, 0, 0), Vector3(0.9, 0.05, 0.8), STONE_GR, Kit.STONE)
	k.box(Vector3(-0.02, 0.05, 0), Vector3(0.82, 0.38, 0.66), WHITE, Kit.PLASTER)
	k.box(Vector3(-0.02, 0.43, 0), Vector3(0.88, 0.04, 0.72), LIME, Kit.PLASTER)
	k.box(Vector3(-0.1, 0.47, -0.06), Vector3(0.58, 0.3, 0.46), WHITE.darkened(0.03), Kit.PLASTER)
	k.box(Vector3(-0.1, 0.77, -0.06), Vector3(0.64, 0.035, 0.52), LIME, Kit.PLASTER)
	_parapet(k, Vector3(-0.1, 0.805, -0.06), 0.64, 0.52, 0.05, 0.03, WHITE, Kit.PLASTER)
	_railing(k, Vector3(0.3, 0.47, 0.18), 0.28, 0.32, 0.09, WOOD)
	k.dome(Vector3(-0.1, 0.8, -0.14), 0.14, TURQ, Kit.PAINT, 1.0, 4, 12)
	k.dome(Vector3(0.0, 0.8, 0.12), 0.08, WHITE, Kit.PLASTER, 1.0, 3, 8)
	_arch_door(k, Vector3(-0.22, 0.05, 0.33), 0.0, 0.15, 0.27, LIME, BLUE)
	# projecting wooden balcony (mashrabiya)
	k.box(Vector3(0.18, 0.3, 0.38), Vector3(0.3, 0.16, 0.1), WOOD, Kit.TIMBER)
	k.box(Vector3(0.18, 0.46, 0.38), Vector3(0.34, 0.025, 0.14), WOOD_DK, Kit.TIMBER)
	k.box(Vector3(0.18, 0.325, 0.432), Vector3(0.24, 0.1, 0.012), SHADE, Kit.DARK)
	for i in 4:
		var lx: float = 0.1 + i * 0.054
		k.box(Vector3(lx, 0.325, 0.44), Vector3(0.01, 0.1, 0.012), WOOD_DK, Kit.TIMBER)
	_arch(k, Vector3(0.0, 0.22, 0.33), 0.0, 0.06, 0.12)
	_arch(k, Vector3(-0.1, 0.56, 0.176), 0.0, 0.07, 0.14)
	_arch(k, Vector3(-0.38, 0.56, -0.06), -PI / 2, 0.07, 0.14)
	k.box(Vector3(-0.1, 0.72, 0.177), Vector3(0.58, 0.02, 0.012), BLUE, Kit.PAINT)
	_stairs(k, Vector3(0.43, 0.05, 0.1), 0.0, 0.1, 5, 0.075, 0.07, LIME, Kit.PLASTER)
	_palm(k, Vector3(-0.42, 0.0, 0.4), 0.5, 6)


static func _ziggurat(k: Kit) -> void:
	var brick := Color(0.74, 0.58, 0.36)
	var dark := Color(0.60, 0.46, 0.30)
	k.box(Vector3(0, 0, 0), Vector3(3.2, 0.05, 2.8), Color(0.78, 0.68, 0.5), Kit.EARTH)
	# tier 1
	k.plinth(Vector3(0, 0.05, 0), 2.7, 2.0, 0.55, 0.06, brick, Kit.MUDBRICK)
	# tier 2
	k.plinth(Vector3(0, 0.6, -0.05), 1.9, 1.4, 0.5, 0.06, brick.lightened(0.04), Kit.MUDBRICK)
	# tier 3
	k.plinth(Vector3(0, 1.1, -0.1), 1.2, 0.9, 0.45, 0.05, brick, Kit.MUDBRICK)
	# glazed blue band at the top of tier 2 and tier 1
	var z1 := 1.0 - 0.06 * 0.9
	k.box(Vector3(0, 0.5, 0), Vector3(2.64, 0.05, 1.92), BLUE, Kit.PAINT)
	k.box(Vector3(0, 0.6, -0.05), Vector3(1.86, 0.035, 1.34), TURQ, Kit.PAINT)
	k.box(Vector3(0, 1.1, -0.1), Vector3(1.14, 0.03, 0.86), BLUE, Kit.PAINT)
	k.box(Vector3(0, 1.43, -0.1), Vector3(1.16, 0.03, 0.88), dark, Kit.MUDBRICK)
	# buttress ribs on each tier front and sides
	for i in 13:
		var x: float = -1.2 + i * 0.2
		if absf(x) > 0.25:
			k.box(Vector3(x, 0.05, z1 + 0.0), Vector3(0.07, 0.43, 0.04), dark, Kit.MUDBRICK)
		k.box(Vector3(x, 0.05, -z1 - 0.0), Vector3(0.07, 0.43, 0.04), dark, Kit.MUDBRICK)
	for i in 9:
		var z: float = -0.8 + i * 0.2
		for s in [-1.0, 1.0]:
			var sx: float = s * 1.3
			k.box(Vector3(sx, 0.05, z), Vector3(0.04, 0.43, 0.07), dark, Kit.MUDBRICK)
	for i in 7:
		var x2: float = -0.8 + i * 0.27
		if absf(x2) > 0.2:
			k.box(Vector3(x2, 0.62, 0.62), Vector3(0.07, 0.4, 0.04), dark, Kit.MUDBRICK)
		for z2 in [-0.55]:
			k.box(Vector3(x2, 0.62, z2 - 0.1), Vector3(0.07, 0.4, 0.04), dark, Kit.MUDBRICK)
	# the long front stair and the two side stairs meeting at the gate tower
	_stairs(k, Vector3(0, 0.05, 1.55), 0.0, 0.34, 10, 0.05, 0.055, Color(0.85, 0.76, 0.58), Kit.STONE)
	k.box(Vector3(0, 0.05, 0.98), Vector3(0.46, 0.5, 0.06), dark, Kit.MUDBRICK)
	k.box(Vector3(0, 0.55, 0.45), Vector3(0.44, 0.05, 0.6), Color(0.85, 0.76, 0.58), Kit.STONE)
	for s in [-1.0, 1.0]:
		var sx2: float = s * 0.52
		_stairs(k, Vector3(sx2, 0.05, 1.4), 0.0, 0.2, 6, 0.08, 0.14, Color(0.85, 0.76, 0.58), Kit.STONE)
		_stairs(k, Vector3(sx2 * 0.55, 0.6, 0.63), 0.0, 0.2, 5, 0.1, 0.09, Color(0.85, 0.76, 0.58), Kit.STONE)
	# upper stair from tier 2 to tier 3
	_stairs(k, Vector3(0, 0.6, 0.75), 0.0, 0.3, 9, 0.055, 0.04, Color(0.85, 0.76, 0.58), Kit.STONE)
	# the shrine
	k.box(Vector3(0, 1.43, -0.12), Vector3(0.7, 0.34, 0.5), BLUE, Kit.PAINT)
	k.box(Vector3(0, 1.43, -0.12), Vector3(0.74, 0.04, 0.54), GILD, Kit.GOLD)
	k.box(Vector3(0, 1.77, -0.12), Vector3(0.78, 0.045, 0.58), GILD, Kit.GOLD)
	k.hip_roof(Vector3(0, 1.82, -0.12), 0.62, 0.42, 0.12, 0.02, 0.025, BLUE, Kit.PAINT)
	_arch(k, Vector3(0, 1.43, 0.14), 0.0, 0.16, 0.24, SHADE)
	k.box(Vector3(0, 1.43, 0.132), Vector3(0.28, 0.03, 0.01), GILD, Kit.GOLD)
	for s in [-1.0, 1.0]:   # gold horns on the corners
		for t in [-1.0, 1.0]:
			var hx: float = s * 0.37
			var hz: float = -0.12 + t * 0.25
			k.plinth(Vector3(hx, 1.82, hz), 0.05, 0.05, 0.08, 0.02, GILD, Kit.GOLD)
	# a few offering braziers on the lower stage
	for s in [-1.0, 1.0]:
		var bx: float = s * 0.95
		_pot(k, Vector3(bx, 0.6, 0.55), 0.04, Color(0.5, 0.3, 0.2))
		_pot(k, Vector3(bx, 1.1, 0.25), 0.04, Color(0.5, 0.3, 0.2))


static func _lamassu(k: Kit, p: Vector3, yaw: float) -> void:
	k.push(Kit.at(p, yaw))
	k.box(Vector3(0, 0, 0), Vector3(0.12, 0.22, 0.24), STONE_LT, Kit.STONE)
	k.box(Vector3(0, 0.22, -0.02), Vector3(0.12, 0.03, 0.2), GILD, Kit.GOLD)
	k.box(Vector3(0, 0.12, 0.13), Vector3(0.1, 0.2, 0.06), STONE_LT, Kit.STONE)
	k.box(Vector3(0, 0.24, 0.135), Vector3(0.095, 0.1, 0.055), BLUE, Kit.PAINT)
	k.box(Vector3(0, 0.34, 0.135), Vector3(0.1, 0.02, 0.06), GILD, Kit.GOLD)
	k.pop()


static func _ne_palace(k: Kit) -> void:
	var brick := Color(0.72, 0.56, 0.38)
	var stone := Color(0.82, 0.76, 0.62)
	k.box(Vector3(0, 0, 0), Vector3(3.2, 0.03, 3.2), Color(0.78, 0.68, 0.5), Kit.EARTH)
	# the great terrace with stepped (crenellated) edge and grand stairs
	k.plinth(Vector3(0, 0.03, -0.1), 3.0, 2.7, 0.34, 0.05, brick, Kit.MUDBRICK)
	k.box(Vector3(0, 0.37, -0.1), Vector3(2.9, 0.03, 2.7), stone, Kit.STONE)
	_stairs(k, Vector3(0, 0.03, 1.62), 0.0, 0.9, 6, 0.057, 0.06, stone, Kit.STONE)
	for s in [-1.0, 1.0]:   # relief panels on the stair walls
		var px: float = s * 0.51
		k.box(Vector3(px, 0.03, 1.4), Vector3(0.12, 0.2, 0.4), stone.darkened(0.08), Kit.STONE)
		for i in 4:
			var rz: float = 1.55 - i * 0.1
			k.box(Vector3(px, 0.23, rz), Vector3(0.08, 0.02, 0.06), BLUE, Kit.PAINT)
	k.box(Vector3(0, 0.4, 1.38), Vector3(1.2, 0.02, 0.1), stone, Kit.STONE)
	# gateway with lamassu
	k.box(Vector3(0, 0.37, 1.1), Vector3(1.1, 0.5, 0.3), brick, Kit.MUDBRICK)
	k.box(Vector3(0, 0.87, 1.1), Vector3(1.2, 0.04, 0.34), stone, Kit.STONE)
	_merlons(k, Vector3(0, 0.91, 1.1), 1.2, 0.34, 0.08, 0.06, brick, Kit.MUDBRICK)
	k.box(Vector3(0, 0.37, 1.255), Vector3(1.1, 0.04, 0.012), BLUE, Kit.PAINT)
	k.box(Vector3(0, 0.78, 1.255), Vector3(1.1, 0.05, 0.012), BLUE, Kit.PAINT)
	k.box(Vector3(0, 0.74, 1.256), Vector3(1.1, 0.02, 0.012), GILD, Kit.GOLD)
	_arch(k, Vector3(0, 0.37, 1.252), 0.0, 0.3, 0.34, SHADE)
	k.box(Vector3(0, 0.37, 1.25), Vector3(0.42, 0.015, 0.008), GILD, Kit.GOLD)
	_lamassu(k, Vector3(-0.28, 0.4, 1.27), 0.0)
	_lamassu(k, Vector3(0.28, 0.4, 1.27), 0.0)
	for s in [-1.0, 1.0]:
		var tx: float = s * 0.62
		k.box(Vector3(tx, 0.37, 1.1), Vector3(0.2, 0.7, 0.34), brick, Kit.MUDBRICK)
		k.box(Vector3(tx, 1.07, 1.1), Vector3(0.26, 0.04, 0.4), stone, Kit.STONE)
		_merlons(k, Vector3(tx, 1.11, 1.1), 0.26, 0.4, 0.07, 0.06, brick, Kit.MUDBRICK)
	# the apadana: a great columned hall
	var hz := -0.1
	k.box(Vector3(0, 0.4, hz - 0.35), Vector3(2.0, 0.5, 0.06), brick, Kit.MUDBRICK)    # rear wall
	for s in [-1.0, 1.0]:
		var wx: float = s * 0.97
		k.box(Vector3(wx, 0.4, hz + 0.0), Vector3(0.06, 0.5, 0.7), brick, Kit.MUDBRICK)
		k.box(Vector3(wx, 0.65, hz + 0.0), Vector3(0.062, 0.02, 0.72), BLUE, Kit.PAINT)
		k.box(Vector3(wx, 0.5, hz + 0.0), Vector3(0.062, 0.015, 0.72), GILD, Kit.GOLD)
	k.box(Vector3(0, 0.4, hz + 0.005), Vector3(2.0, 0.04, 0.7), stone, Kit.STONE)    # floor
	for row in 3:
		for i in 7:
			var cx: float = -0.9 + i * 0.3
			var cz: float = hz + 0.25 - row * 0.2
			var cr := 0.034
			k.frustum(Vector3(cx, 0.4, cz), cr * 1.4, cr, 0.06, stone.darkened(0.1), Kit.STONE, 8, false)
			k.frustum(Vector3(cx, 0.46, cz), cr, cr * 0.85, 0.5, stone, Kit.STONE, 8, false)
			k.frustum(Vector3(cx, 0.96, cz), cr * 0.85, cr * 1.8, 0.07, GILD, Kit.GOLD, 8, true)   # bull capital hint
	k.box(Vector3(0, 1.03, hz - 0.03), Vector3(2.04, 0.05, 0.78), stone, Kit.STONE)   # entablature
	k.box(Vector3(0, 1.0, hz - 0.03), Vector3(2.0, 0.03, 0.74), BLUE, Kit.PAINT)
	k.box(Vector3(0, 1.08, hz - 0.03), Vector3(1.9, 0.07, 0.7), brick, Kit.MUDBRICK)
	_merlons(k, Vector3(0, 1.15, hz - 0.03), 1.9, 0.7, 0.08, 0.07, brick, Kit.MUDBRICK)
	# stepped crenellations (zigzag on the terrace rim)
	_merlons(k, Vector3(0, 0.4, -0.1), 2.88, 2.68, 0.1, 0.06, brick, Kit.MUDBRICK)
	# corner towers
	for s in [-1.0, 1.0]:
		var cx2: float = s * 1.38
		k.box(Vector3(cx2, 0.37, -1.28), Vector3(0.3, 0.66, 0.3), brick, Kit.MUDBRICK)
		k.box(Vector3(cx2, 0.99, -1.28), Vector3(0.36, 0.04, 0.36), stone, Kit.STONE)
		_merlons(k, Vector3(cx2, 1.03, -1.28), 0.36, 0.36, 0.08, 0.07, brick, Kit.MUDBRICK)
		k.box(Vector3(cx2, 0.5, -1.128), Vector3(0.28, 0.04, 0.012), TURQ, Kit.PAINT)
		k.box(Vector3(cx2, 0.8, -1.128), Vector3(0.28, 0.04, 0.012), GILD, Kit.GOLD)
	# side wings with glazed brick bands and a garden
	for s in [-1.0, 1.0]:
		var wx2: float = s * 1.25
		k.box(Vector3(wx2, 0.4, 0.5), Vector3(0.5, 0.3, 0.8), brick, Kit.MUDBRICK)
		k.box(Vector3(wx2, 0.7, 0.5), Vector3(0.56, 0.035, 0.86), stone, Kit.STONE)
		_merlons(k, Vector3(wx2, 0.735, 0.5), 0.56, 0.86, 0.07, 0.05, brick, Kit.MUDBRICK)
		k.box(Vector3(wx2 - s * 0.255, 0.55, 0.5), Vector3(0.012, 0.04, 0.8), BLUE, Kit.PAINT)
		k.box(Vector3(wx2 - s * 0.255, 0.49, 0.5), Vector3(0.012, 0.03, 0.8), GILD, Kit.GOLD)
		k.box(Vector3(wx2, 0.5, 0.905), Vector3(0.5, 0.04, 0.012), BLUE, Kit.PAINT)
		k.dome(Vector3(wx2, 0.735, 0.4), 0.12, TURQ, Kit.PAINT, 0.9, 3, 10)
		_arch(k, Vector3(wx2, 0.4, 0.903), 0.0, 0.12, 0.22)
	k.box(Vector3(0, 0.4, 0.55), Vector3(0.6, 0.03, 0.4), WATER_BLUE, Kit.WATER)
	k.box(Vector3(0, 0.4, 0.55), Vector3(0.66, 0.02, 0.46), stone, Kit.STONE)
	k.box(Vector3(0, 0.4, 0.55), Vector3(0.6, 0.03, 0.4), WATER_BLUE, Kit.WATER)
	for s in [-1.0, 1.0]:
		_palm(k, Vector3(s * 0.55, 0.4, 0.45), 0.5, 6)
		_palm(k, Vector3(s * 0.6, 0.4, 0.15), 0.45)


# --- SOUTH ASIA --------------------------------------------------------------------------------


## A chhatri: four slender posts, a slab and a little dome with a finial.
static func _chhatri(k: Kit, p: Vector3, w: float, h: float, col: Color, dome_col: Color) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var px: float = sx * (w / 2 - 0.012)
			var pz: float = sz * (w / 2 - 0.012)
			k.frustum(p + Vector3(px, 0, pz), 0.012, 0.01, h, col, Kit.PLASTER, 5, false)
	k.box(p + Vector3(0, h, 0), Vector3(w + 0.03, 0.025, w + 0.03), col, Kit.PLASTER)
	k.dome(p + Vector3(0, h + 0.025, 0), w * 0.52, dome_col, Kit.PLASTER if dome_col == col else Kit.PAINT, 0.95, 3, 8)
	k.cylinder(p + Vector3(0, h + 0.025 + w * 0.48, 0), 0.007, 0.05, GILD, Kit.GOLD, 4)


## A curved bangla roof: two stacked hips with upturned eaves and a finial.
static func _bangla(k: Kit, foot: Vector3, w: float, d: float, rise: float, col: Color, mat := Kit.OWNER_ROOF) -> void:
	k.hip_roof(foot, w, d, rise * 0.4, 0.06, 0.025, col, mat, 0.0, 0.035)
	var w2 := w * 0.66
	var d2 := d * 0.66
	k.hip_roof(foot + Vector3(0, rise * 0.4 - 0.005, 0), w2, d2, rise * 0.6, 0.0, 0.022, col.lightened(0.04), mat, 0.0, 0.0)
	k.cylinder(foot + Vector3(0, rise + 0.015, 0), 0.012, 0.06, GILD, Kit.GOLD, 5)
	k.dome(foot + Vector3(0, rise + 0.075, 0), 0.025, GILD, Kit.GOLD, 1.2, 2, 6)


## A carved wooden balcony (jharokha) on brackets, facing +z of the local frame.
static func _jharokha(k: Kit, p: Vector3, yaw: float, w: float, h: float) -> void:
	k.push(Kit.at(p, yaw))
	k.box(Vector3(0, 0, 0.07), Vector3(w, 0.03, 0.14), WOOD, Kit.TIMBER)
	for s in [-1.0, 1.0]:
		var bx: float = s * w * 0.4
		k.rod(Vector3(bx, -0.05, 0.0), Vector3(bx, 0.0, 0.12), 0.012, WOOD_DK, Kit.TIMBER)
	k.box(Vector3(0, 0.03, 0.14 - 0.01), Vector3(w, h * 0.35, 0.02), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.03 + h * 0.35, 0.13), Vector3(w, h * 0.65, 0.02), SHADE, Kit.DARK)
	for s in [-1.0, 0.0, 1.0]:
		var cx: float = s * w * 0.4
		k.rod(Vector3(cx, 0.03 + h * 0.35, 0.145), Vector3(cx, 0.03 + h, 0.145), 0.01, WOOD, Kit.TIMBER)
	for s in [-1.0, 1.0]:
		var sx: float = s * (w / 2 - 0.005)
		k.box(Vector3(sx, 0.03, 0.07), Vector3(0.012, h * 0.4, 0.13), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.03 + h, 0.075), Vector3(w + 0.03, 0.02, 0.17), WOOD_DK, Kit.TIMBER)
	k.dome(Vector3(0, 0.05 + h, 0.075), w * 0.4, WHITE, Kit.PLASTER, 0.9, 3, 8)
	k.pop()


static func _sa_house_1(k: Kit) -> void:
	# a haveli townhouse: red brick below, whitewash above, jharokha balcony, chhatris
	k.box(Vector3(0, 0, 0), Vector3(0.9, 0.04, 0.8), STONE_GR, Kit.STONE)
	k.box(Vector3(0, 0.04, 0), Vector3(0.84, 0.3, 0.66), BRICKR, Kit.BRICK)
	k.box(Vector3(0, 0.34, 0), Vector3(0.88, 0.035, 0.7), STONE_LT, Kit.STONE)
	k.box(Vector3(0, 0.375, 0), Vector3(0.8, 0.3, 0.62), WHITE, Kit.PLASTER)
	k.box(Vector3(0, 0.675, 0), Vector3(0.86, 0.04, 0.68), STONE_LT, Kit.STONE)
	_parapet(k, Vector3(0, 0.715, 0), 0.84, 0.64, 0.05, 0.03, WHITE, Kit.PLASTER)
	_merlons(k, Vector3(0, 0.765, 0), 0.84, 0.64, 0.06, 0.05, WHITE, Kit.PLASTER)
	_arch_door(k, Vector3(-0.2, 0.04, 0.33), 0.0, 0.15, 0.26, STONE_LT, OCHRE, Kit.STONE)
	_arch(k, Vector3(0.1, 0.1, 0.333), 0.0, 0.07, 0.15)
	_arch(k, Vector3(0.3, 0.1, 0.333), 0.0, 0.07, 0.15)
	_jharokha(k, Vector3(0.05, 0.42, 0.31), 0.0, 0.26, 0.2)
	for x in [-0.28, 0.36]:
		_arch(k, Vector3(x, 0.45, 0.313), 0.0, 0.07, 0.15)
		k.box(Vector3(x, 0.43, 0.33), Vector3(0.12, 0.015, 0.05), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.35, 0.357), Vector3(0.84, 0.02, 0.015), OCHRE, Kit.PAINT)
	for x in [-0.34, 0.34]:
		_chhatri(k, Vector3(x, 0.765, 0.12), 0.16, 0.14, WHITE, WHITE)
	_chhatri(k, Vector3(0.0, 0.765, -0.18), 0.2, 0.17, WHITE, TURQ)
	_arch(k, Vector3(0.436, 0.1, 0.0), PI / 2, 0.07, 0.15)
	_palm(k, Vector3(-0.42, 0, 0.4), 0.55, 6)
	_pot(k, Vector3(0.44, 0, 0.36), 0.035)


static func _sa_house_2(k: Kit) -> void:
	# a thatched village hut: round mud wall, conical thatch, little veranda and a granary
	k.cylinder(Vector3(-0.1, 0, -0.05), 0.32, 0.26, Color(0.66, 0.5, 0.34), Kit.EARTH, 12)
	k.frustum(Vector3(-0.1, 0.26, -0.05), 0.46, 0.26, 0.14, REED, Kit.THATCH, 12, false)
	k.frustum(Vector3(-0.1, 0.4, -0.05), 0.26, 0.0, 0.3, REED.lightened(0.04), Kit.THATCH, 12, true)
	k.frustum(Vector3(-0.1, 0.7, -0.05), 0.03, 0.02, 0.07, WOOD, Kit.TIMBER, 5, true)
	k.dome(Vector3(-0.1, 0.77, -0.05), 0.035, Color(0.7, 0.4, 0.25), Kit.EARTH, 1.0, 2, 6)
	# eaves ring of reed bundles
	for i in 12:
		var a := i * TAU / 12.0
		k.rod(Vector3(-0.1 + cos(a) * 0.45, 0.28, -0.05 + sin(a) * 0.45), Vector3(-0.1 + cos(a) * 0.46, 0.2, -0.05 + sin(a) * 0.46), 0.01, REED.darkened(0.2), Kit.THATCH)
	# front doorway and veranda
	var dz := -0.05 + 0.32
	k.box(Vector3(-0.1, 0, dz - 0.01), Vector3(0.13, 0.2, 0.03), SHADE, Kit.DARK)
	k.box(Vector3(-0.1, 0.2, dz - 0.0), Vector3(0.19, 0.03, 0.05), WOOD, Kit.TIMBER)
	k.box(Vector3(-0.1, 0, 0.42), Vector3(0.5, 0.05, 0.12), Color(0.7, 0.55, 0.38), Kit.EARTH)
	for s in [-1.0, 1.0]:
		var vx: float = -0.1 + s * 0.22
		k.rod(Vector3(vx, 0.05, 0.46), Vector3(vx, 0.27, 0.46), 0.014, WOOD, Kit.TIMBER)
	k.rod(Vector3(-0.32, 0.27, 0.46), Vector3(0.12, 0.27, 0.46), 0.014, WOOD, Kit.TIMBER)
	k.rod(Vector3(-0.32, 0.27, 0.46), Vector3(-0.32, 0.25, 0.3), 0.01, WOOD, Kit.TIMBER)
	k.rod(Vector3(0.12, 0.27, 0.46), Vector3(0.12, 0.25, 0.3), 0.01, WOOD, Kit.TIMBER)
	# the second building: a square shed with hipped thatch
	k.box(Vector3(0.34, 0, -0.18), Vector3(0.26, 0.2, 0.3), Color(0.72, 0.58, 0.42), Kit.EARTH)
	k.hip_roof(Vector3(0.34, 0.2, -0.18), 0.26, 0.3, 0.16, 0.06, 0.025, REED, Kit.THATCH)
	k.box(Vector3(0.34, 0, -0.02), Vector3(0.1, 0.14, 0.02), SHADE, Kit.DARK)
	# a small granary basket on stilts
	k.frustum(Vector3(0.38, 0.1, 0.32), 0.08, 0.1, 0.16, Color(0.72, 0.55, 0.3), Kit.THATCH, 8, false)
	k.frustum(Vector3(0.38, 0.26, 0.32), 0.11, 0.0, 0.1, REED, Kit.THATCH, 8, true)
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			k.rod(Vector3(0.38 + s * 0.05, 0, 0.32 + t * 0.05), Vector3(0.38 + s * 0.05, 0.1, 0.32 + t * 0.05), 0.01, WOOD, Kit.TIMBER)
	# fence and tree
	for i in 7:
		var fz: float = -0.4 + i * 0.12
		k.rod(Vector3(-0.47, 0, fz), Vector3(-0.47, 0.1, fz), 0.01, WOOD, Kit.TIMBER)
	k.rod(Vector3(-0.47, 0.08, -0.4), Vector3(-0.47, 0.08, 0.32), 0.008, WOOD, Kit.TIMBER)
	k.frustum(Vector3(0.38, 0, 0.0), 0.025, 0.018, 0.3, WOOD, Kit.TIMBER, 5, false)
	k.dome(Vector3(0.38, 0.28, 0.0), 0.16, Color(0.32, 0.5, 0.22), Kit.LEAF, 0.8, 3, 9)


static func _sa_house_3(k: Kit) -> void:
	# courtyard haveli: tile-roofed wings round a court, a veranda on posts
	var wall := WHITE.darkened(0.02)
	k.box(Vector3(0, 0, 0), Vector3(1.0, 0.03, 1.0), Color(0.78, 0.68, 0.5), Kit.EARTH)
	var clay := Color(0.66, 0.36, 0.24)
	# back wing and two side wings
	k.box(Vector3(0, 0.03, -0.34), Vector3(0.96, 0.3, 0.3), wall, Kit.PLASTER)
	k.gable_roof(Vector3(0, 0.33, -0.34), 0.96, 0.3, 0.18, 0.06, 0.03, clay, Kit.OWNER_ROOF, wall, Kit.PLASTER)
	for s in [-1.0, 1.0]:
		var wx: float = s * 0.4
		k.box(Vector3(wx, 0.03, 0.0), Vector3(0.22, 0.26, 0.5), wall, Kit.PLASTER)
		k.gable_roof(Vector3(wx, 0.29, 0.0), 0.5, 0.22, 0.14, 0.05, 0.028, clay, Kit.OWNER_ROOF, wall, Kit.PLASTER, PI / 2)
	# veranda posts along the court faces of the back wing
	for i in 7:
		var px: float = -0.4 + i * 0.133
		k.frustum(Vector3(px, 0.03, -0.14), 0.016, 0.014, 0.26, WOOD, Kit.TIMBER, 5, false)
		k.box(Vector3(px, 0.27, -0.14), Vector3(0.04, 0.02, 0.04), WOOD_DK, Kit.TIMBER)
	k.box(Vector3(0, 0.29, -0.14), Vector3(0.84, 0.025, 0.04), WOOD_DK, Kit.TIMBER)
	k.box(Vector3(0, 0.03, -0.19), Vector3(0.84, 0.05, 0.1), Color(0.76, 0.7, 0.58), Kit.STONE)
	for i in 3:
		var dx: float = -0.28 + i * 0.28
		_arch(k, Vector3(dx, 0.08, -0.188), 0.0, 0.1, 0.18)
	# front wall with gateway and a gate room
	for s in [-1.0, 1.0]:
		var fx: float = s * 0.31
		k.box(Vector3(fx, 0.03, 0.46), Vector3(0.38, 0.22, 0.06), wall, Kit.PLASTER)
		k.box(Vector3(fx, 0.25, 0.46), Vector3(0.42, 0.03, 0.09), STONE_LT, Kit.STONE)
	k.box(Vector3(0, 0.03, 0.46), Vector3(0.3, 0.4, 0.14), wall, Kit.PLASTER)
	k.box(Vector3(0, 0.43, 0.46), Vector3(0.36, 0.03, 0.2), STONE_LT, Kit.STONE)
	_arch_door(k, Vector3(0, 0.03, 0.535), 0.0, 0.14, 0.26, STONE_LT, OCHRE, Kit.STONE)
	_chhatri(k, Vector3(0, 0.46, 0.46), 0.14, 0.1, WHITE, TURQ)
	k.box(Vector3(0, 0.36, 0.536), Vector3(0.3, 0.018, 0.012), OCHRE, Kit.PAINT)
	# court: a raised tulsi platform
	k.box(Vector3(0, 0.03, 0.08), Vector3(0.16, 0.08, 0.16), STONE_LT, Kit.STONE)
	k.dome(Vector3(0, 0.11, 0.08), 0.04, Color(0.28, 0.5, 0.22), Kit.LEAF, 1.0, 2, 6)
	_palm(k, Vector3(0.36, 0.03, 0.32), 0.55, 6)


static func _sa_house_4(k: Kit) -> void:
	# whitewashed house with a curved roof and a veranda on carved posts
	k.box(Vector3(0, 0, 0), Vector3(0.9, 0.05, 0.82), STONE_GR, Kit.STONE)
	k.box(Vector3(0, 0.05, -0.08), Vector3(0.7, 0.34, 0.52), WHITE, Kit.PLASTER)
	k.box(Vector3(0, 0.39, -0.08), Vector3(0.74, 0.035, 0.56), STONE_LT, Kit.STONE)
	_bangla(k, Vector3(0, 0.425, -0.08), 0.74, 0.56, 0.3, Color(0.7, 0.4, 0.28))
	# veranda
	k.box(Vector3(0, 0.05, 0.3), Vector3(0.8, 0.05, 0.22), Color(0.78, 0.7, 0.56), Kit.STONE)
	for i in 5:
		var px: float = -0.34 + i * 0.17
		k.frustum(Vector3(px, 0.1, 0.38), 0.018, 0.015, 0.25, WOOD, Kit.TIMBER, 6, false)
		k.box(Vector3(px, 0.34, 0.38), Vector3(0.05, 0.03, 0.05), WOOD_DK, Kit.TIMBER)
	k.box(Vector3(0, 0.37, 0.38), Vector3(0.78, 0.03, 0.05), WOOD_DK, Kit.TIMBER)
	k.hip_roof(Vector3(0, 0.37, 0.32), 0.78, 0.2, 0.1, 0.05, 0.022, Color(0.7, 0.4, 0.28), Kit.OWNER_ROOF, 0.0, 0.025)
	_arch_door(k, Vector3(0, 0.1, 0.18), 0.0, 0.14, 0.26, STONE_LT, OCHRE, Kit.STONE)
	for s in [-1.0, 1.0]:
		var wx: float = s * 0.27
		_arch(k, Vector3(wx, 0.15, 0.182), 0.0, 0.08, 0.16)
	k.box(Vector3(0, 0.34, 0.182), Vector3(0.7, 0.02, 0.012), TURQ, Kit.PAINT)
	_palm(k, Vector3(-0.42, 0, 0.38), 0.6)
	_pot(k, Vector3(0.38, 0.1, 0.38), 0.03)


static func _sa_palace(k: Kit) -> void:
	var sand := Color(0.88, 0.82, 0.68)
	var clay := Color(0.70, 0.40, 0.28)
	k.box(Vector3(0, 0, 0), Vector3(3.2, 0.03, 3.2), Color(0.8, 0.7, 0.52), Kit.EARTH)
	k.plinth(Vector3(0, 0.03, -0.1), 3.0, 2.8, 0.22, 0.04, sand.darkened(0.06), Kit.STONE)
	k.box(Vector3(0, 0.25, -0.1), Vector3(2.9, 0.025, 2.7), sand, Kit.STONE)
	# --- gateway at the front, with two gate towers and chhatris
	for s in [-1.0, 1.0]:
		var tx: float = s * 0.5
		k.plinth(Vector3(tx, 0.25, 1.2), 0.46, 0.46, 0.6, 0.03, BRICKR, Kit.BRICK)
		k.box(Vector3(tx, 0.85, 1.2), Vector3(0.54, 0.04, 0.54), sand, Kit.STONE)
		_merlons(k, Vector3(tx, 0.89, 1.2), 0.54, 0.54, 0.07, 0.06, BRICKR, Kit.BRICK)
		_chhatri(k, Vector3(tx, 0.89, 1.2), 0.2, 0.15, sand, TURQ)
		_arch(k, Vector3(tx, 0.45, 1.442), 0.0, 0.08, 0.18)
	k.box(Vector3(0, 0.58, 1.2), Vector3(0.6, 0.27, 0.4), BRICKR, Kit.BRICK)
	k.box(Vector3(0, 0.85, 1.2), Vector3(0.62, 0.04, 0.44), sand, Kit.STONE)
	_merlons(k, Vector3(0, 0.89, 1.2), 0.62, 0.44, 0.07, 0.06, BRICKR, Kit.BRICK)
	_arch_door(k, Vector3(0, 0.25, 1.415), 0.0, 0.34, 0.5, sand, OCHRE, Kit.STONE)
	_stairs(k, Vector3(0, 0.03, 1.75), 0.0, 0.7, 4, 0.055, 0.09, sand, Kit.STONE)
	for s in [-1.0, 1.0]:   # curtain walls
		var wx: float = s * 1.18
		k.box(Vector3(wx, 0.25, 1.2), Vector3(0.8, 0.34, 0.12), BRICKR, Kit.BRICK)
		k.box(Vector3(wx, 0.59, 1.2), Vector3(0.84, 0.03, 0.16), sand, Kit.STONE)
		_merlons(k, Vector3(wx, 0.62, 1.2), 0.84, 0.16, 0.06, 0.05, BRICKR, Kit.BRICK)
	# --- the pillared hall (Mauryan style): polished sandstone pillars
	var hz := -0.3
	k.box(Vector3(0, 0.275, hz), Vector3(2.0, 0.07, 1.2), sand, Kit.STONE)
	k.box(Vector3(0, 0.34, hz - 0.54), Vector3(1.9, 0.5, 0.1), BRICKR, Kit.BRICK)
	for s in [-1.0, 1.0]:
		var sx: float = s * 0.95
		k.box(Vector3(sx, 0.34, hz), Vector3(0.1, 0.5, 1.1), BRICKR, Kit.BRICK)
		for t in 3:
			var tz: float = hz - 0.3 + t * 0.3
			_arch(k, Vector3(sx - s * 0.0, 0.5, tz), s * PI / 2 * -1.0 + PI * 0.0, 0.08, 0.2)
	for row in 3:
		for i in 6:
			var cx: float = -0.75 + i * 0.3
			var cz: float = hz + 0.45 - row * 0.3
			k.frustum(Vector3(cx, 0.345, cz), 0.04, 0.034, 0.5, Color(0.9, 0.84, 0.7), Kit.PAINT, 8, false)
			k.frustum(Vector3(cx, 0.845, cz), 0.034, 0.055, 0.05, sand.darkened(0.05), Kit.STONE, 8, true)
			k.box(Vector3(cx, 0.895, cz), Vector3(0.12, 0.03, 0.12), WOOD_DK, Kit.TIMBER)
	# timber gallery above, with a railing and lattice
	k.box(Vector3(0, 0.925, hz), Vector3(2.1, 0.04, 1.3), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.965, hz), Vector3(1.9, 0.26, 1.1), WHITE, Kit.PLASTER)
	for i in 6:
		var gx: float = -0.8 + i * 0.32
		_arch(k, Vector3(gx, 1.0, hz + 0.551), 0.0, 0.1, 0.17)
		k.box(Vector3(gx, 0.965, hz + 0.58), Vector3(0.16, 0.02, 0.06), WOOD, Kit.TIMBER)
	_railing(k, Vector3(0, 0.945, hz + 0.005), 2.04, 1.24, 0.05, WOOD_DK)
	k.box(Vector3(0, 1.22, hz), Vector3(2.0, 0.04, 1.2), sand, Kit.STONE)
	_bangla(k, Vector3(0, 1.26, hz), 1.9, 1.1, 0.55, clay)
	# --- flanking pavilions with their own curved roofs
	for s in [-1.0, 1.0]:
		var px: float = s * 1.18
		k.box(Vector3(px, 0.275, -0.2), Vector3(0.7, 0.35, 0.7), WHITE, Kit.PLASTER)
		k.box(Vector3(px, 0.625, -0.2), Vector3(0.74, 0.035, 0.74), sand, Kit.STONE)
		_bangla(k, Vector3(px, 0.66, -0.2), 0.72, 0.72, 0.28, clay)
		_arch_door(k, Vector3(px, 0.275, 0.16), 0.0, 0.14, 0.26, sand, BLUE, Kit.STONE)
		k.box(Vector3(px, 0.54, 0.162), Vector3(0.7, 0.025, 0.012), OCHRE, Kit.PAINT)
		var qx: float = s * 0.75
		_chhatri(k, Vector3(qx, 0.275, 0.6), 0.18, 0.16, sand, TURQ)
		_chhatri(k, Vector3(px, 0.275, 0.75), 0.2, 0.18, sand, TURQ)
	# --- courtyard: a pool and trees
	k.box(Vector3(0, 0.275, 0.62), Vector3(0.6, 0.04, 0.34), STONE_GR, Kit.STONE)
	k.box(Vector3(0, 0.275, 0.62), Vector3(0.54, 0.046, 0.28), WATER_BLUE, Kit.WATER)
	for s in [-1.0, 1.0]:
		_palm(k, Vector3(s * 0.9, 0.275, 0.75), 0.55)
		_palm(k, Vector3(s * 0.55, 0.275, 0.9), 0.45, 6)
		k.banner(Vector3(s * 0.28, 0.275, 1.0), 0.6, 0.22, 0.0)
	k.rod(Vector3(0, 1.8, hz), Vector3(0, 1.9, hz), 0.01, GILD, Kit.GOLD)


static func _stupa(k: Kit) -> void:
	var white := Color(0.94, 0.91, 0.84)
	var stone := Color(0.80, 0.72, 0.58)
	k.cylinder(Vector3.ZERO, 0.92, 0.05, Color(0.78, 0.7, 0.54), Kit.STONE, 20)
	# lower terrace (medhi) with a circumambulation path and stair
	k.frustum(Vector3(0, 0.05, 0), 0.72, 0.68, 0.18, stone, Kit.STONE, 20, true)
	k.frustum(Vector3(0, 0.23, 0), 0.64, 0.62, 0.05, stone.lightened(0.05), Kit.STONE, 20, true)
	k.frustum(Vector3(0, 0.28, 0), 0.55, 0.52, 0.1, white.darkened(0.04), Kit.PLASTER, 20, false)
	# the dome
	k.dome(Vector3(0, 0.38, 0), 0.5, white, Kit.PLASTER, 0.82, 8, 20)
	# the harmika: a small square railed box on top, the mast and the chattra parasols
	var ytop := 0.38 + 0.5 * 0.82
	k.box(Vector3(0, ytop - 0.01, 0), Vector3(0.24, 0.1, 0.24), stone, Kit.STONE)
	k.box(Vector3(0, ytop + 0.09, 0), Vector3(0.28, 0.025, 0.28), GILD, Kit.GOLD)
	k.cylinder(Vector3(0, ytop + 0.11, 0), 0.012, 0.28, WOOD, Kit.TIMBER, 5)
	for i in 3:
		var r := 0.17 - i * 0.04
		k.frustum(Vector3(0, ytop + 0.12 + i * 0.075, 0), r, r * 0.72, 0.022, GILD, Kit.GOLD, 12, true)
		k.frustum(Vector3(0, ytop + 0.142 + i * 0.075, 0), r * 0.72, 0.008, 0.03, GILD.darkened(0.1), Kit.GOLD, 12, true)
	k.dome(Vector3(0, ytop + 0.37, 0), 0.02, GILD, Kit.GOLD, 1.3, 2, 6)
	# garlands round the dome's base
	k.frustum(Vector3(0, 0.37, 0), 0.51, 0.5, 0.02, OCHRE, Kit.PAINT, 20, false)
	# the vedika railing with four toranas (gates) at the cardinal points
	var rr := 0.84
	var n := 32
	for i in n:
		var a := i * TAU / n
		var skip := false
		for q in 4:
			if absf(angle_difference(a, q * PI / 2.0)) < 0.17:
				skip = true
		if skip:
			continue
		k.rod(Vector3(cos(a) * rr, 0.0, sin(a) * rr), Vector3(cos(a) * rr, 0.26, sin(a) * rr), 0.014, stone, Kit.STONE)
	for r_y in [0.07, 0.15, 0.23]:
		for i in 16:
			var a0 := i * TAU / 16.0
			var a1 := (i + 1) * TAU / 16.0
			var mid := (a0 + a1) / 2.0
			var near := false
			for q in 4:
				if absf(angle_difference(mid, q * PI / 2.0)) < 0.2:
					near = true
			if near:
				continue
			k.rod(Vector3(cos(a0 + 0.06) * rr, r_y, sin(a0 + 0.06) * rr), Vector3(cos(a1 - 0.06) * rr, r_y, sin(a1 - 0.06) * rr), 0.01, stone.darkened(0.04), Kit.STONE)
	for q in 4:
		k.push(Kit.at(Vector3.ZERO, q * PI / 2.0))
		var tz := rr
		for s in [-1.0, 1.0]:
			var tx: float = s * 0.15
			k.box(Vector3(tx, 0, tz), Vector3(0.05, 0.42, 0.05), stone, Kit.STONE)
		for i in 3:   # three curled architraves
			var by := 0.28 + i * 0.07
			var ex := 0.22 - i * 0.015
			k.box(Vector3(0, by, tz), Vector3(0.3 + 0.06 * (i + 1), 0.035, 0.035), RED.lightened(0.05) if i == 1 else stone.darkened(0.08), Kit.STONE)
			for s in [-1.0, 1.0]:
				var cx: float = s * (0.15 + 0.03 * (i + 1) + 0.0)
				k.dome(Vector3(cx, by + 0.02, tz), 0.025, OCHRE, Kit.PAINT, 1.0, 2, 6)
		k.box(Vector3(0, 0.47, tz), Vector3(0.1, 0.05, 0.04), GILD, Kit.GOLD)
		k.pop()
	# the stair up to the terrace (west of the +z gate)
	_stairs(k, Vector3(0, 0.05, 0.79), 0.0, 0.2, 4, 0.045, 0.045, stone, Kit.STONE)


static func _shikhara(k: Kit) -> void:
	var sand := Color(0.84, 0.70, 0.52)
	var stone := Color(0.78, 0.66, 0.5)
	# plinth with steps
	k.plinth(Vector3(0, 0, 0), 1.3, 1.3, 0.1, 0.04, stone.darkened(0.08), Kit.STONE)
	k.box(Vector3(0, 0.1, -0.1), Vector3(1.0, 0.04, 1.0), stone, Kit.STONE)
	_stairs(k, Vector3(0, 0, 0.8), 0.0, 0.34, 3, 0.047, 0.07, stone, Kit.STONE)
	# sanctum body and the curved tower
	k.box(Vector3(0, 0.14, -0.22), Vector3(0.56, 0.3, 0.56), sand, Kit.STONE)
	k.box(Vector3(0, 0.44, -0.22), Vector3(0.62, 0.04, 0.62), stone.darkened(0.05), Kit.STONE)
	var layers := 11
	var y := 0.48
	var base := 0.54
	var lh := 0.082
	for i in layers:
		var t := float(i) / layers
		var w := base * (1.0 - pow(t, 1.45) * 0.78)
		var col := sand.lightened(0.04 * float(i % 2)) 
		k.box(Vector3(0, y, -0.22), Vector3(w, lh, w), col, Kit.STONE)
		k.box(Vector3(0, y + lh, -0.22), Vector3(w * 1.06, 0.014, w * 1.06), stone.darkened(0.1), Kit.STONE)
		# the vertical rib (lata) on the front face and mini-spires
		k.box(Vector3(0, y, -0.22 + w / 2 + 0.006), Vector3(w * 0.22, lh, 0.014), sand.darkened(0.12), Kit.STONE)
		if i % 3 == 1:
			for s in [-1.0, 1.0]:
				var mx: float = s * w * 0.4
				k.box(Vector3(mx, y, -0.22 + w / 2 + 0.01), Vector3(w * 0.12, lh * 0.9, 0.02), sand.darkened(0.08), Kit.STONE)
		y += lh + 0.014
	var tw := base * 0.28
	k.frustum(Vector3(0, y, -0.22), tw * 0.6, tw * 0.72, 0.035, stone, Kit.STONE, 12, true)   # amalaka
	k.frustum(Vector3(0, y + 0.035, -0.22), tw * 0.72, tw * 0.5, 0.03, stone.lightened(0.04), Kit.STONE, 12, true)
	k.cylinder(Vector3(0, y + 0.065, -0.22), 0.012, 0.04, GILD, Kit.GOLD, 5)
	k.dome(Vector3(0, y + 0.1, -0.22), 0.036, GILD, Kit.GOLD, 1.3, 2, 8)
	k.cylinder(Vector3(0, y + 0.16, -0.22), 0.004, 0.08, GILD, Kit.GOLD, 4)
	k.banner(Vector3(0, y + 0.2, -0.22), 0.01, 0.01)
	# the porch (mandapa) in front, with a stepped pyramidal roof
	k.box(Vector3(0, 0.14, 0.28), Vector3(0.6, 0.24, 0.5), sand, Kit.STONE)
	for i in 4:
		var w2 := 0.66 - i * 0.14
		k.box(Vector3(0, 0.38 + i * 0.05, 0.28), Vector3(w2, 0.045, w2 * 0.82), stone.lightened(0.02 * i), Kit.STONE)
	k.frustum(Vector3(0, 0.58, 0.28), 0.06, 0.03, 0.04, stone, Kit.STONE, 8, true)
	k.dome(Vector3(0, 0.62, 0.28), 0.03, GILD, Kit.GOLD, 1.3, 2, 6)
	for s in [-1.0, 1.0]:
		var cx: float = s * 0.24
		k.frustum(Vector3(cx, 0.14, 0.52), 0.032, 0.028, 0.22, Color(0.9, 0.82, 0.66), Kit.PAINT, 8, false)
		k.box(Vector3(cx, 0.36, 0.52), Vector3(0.09, 0.03, 0.09), stone, Kit.STONE)
	k.box(Vector3(0, 0.14, 0.535), Vector3(0.16, 0.22, 0.012), SHADE, Kit.DARK)
	k.box(Vector3(0, 0.36, 0.53), Vector3(0.6, 0.025, 0.03), OCHRE, Kit.PAINT)
	k.banner(Vector3(0.5, 0.1, 0.5), 0.5, 0.16)


# =============================================================================================
# GENERATED HOUSES (D-281): every kind below is an archetype function driven by a parameter
# row in a table (size, storeys, wall and trim colours, roof treatment, extras). The seeded
# rng picks the small details (window spacing, which side a yard feature falls on) so the same
# archetype never gives the same house twice. Houses fit in 1.0 x 1.0; "big_" kinds in 2.0 x 1.0.
# =============================================================================================

const DUST := Color(0.78, 0.64, 0.45)
const OCHRE_WALL := Color(0.80, 0.62, 0.38)
const ROSE := Color(0.76, 0.52, 0.42)
const CLAY := Color(0.66, 0.36, 0.24)
const GREEN := Color(0.30, 0.50, 0.24)
const SAFFRON := Color(0.90, 0.58, 0.16)
const DEEPRED := Color(0.55, 0.16, 0.12)
const PALM_TR := Color(0.46, 0.34, 0.20)
const STONE_DK := Color(0.52, 0.50, 0.46)

const NILE_KINDS := ["house_nile_worker_1", "house_nile_worker_2", "house_nile_worker_3", "house_nile_worker_4",
	"house_nile_town_1", "house_nile_town_2", "house_nile_town_3", "house_nile_town_4",
	"house_nile_villa_1", "house_nile_villa_2", "house_nile_farm_1", "house_nile_farm_2",
	"house_nile_tower_1", "house_nile_tower_2"]
const NE_KINDS := ["house_ne_court_1", "house_ne_court_2", "house_ne_court_3", "house_ne_court_4",
	"house_ne_flat_1", "house_ne_flat_2", "house_ne_flat_3",
	"house_ne_hittite_1", "house_ne_hittite_2", "house_ne_hittite_3",
	"house_ne_berber_1", "house_ne_berber_2", "house_ne_berber_3",
	"house_ne_domed_1", "house_ne_domed_2", "house_ne_domed_3"]
const IND_KINDS := ["house_ind_hut_1", "house_ind_hut_2", "house_ind_hut_3", "house_ind_hut_4",
	"house_ind_tile_1", "house_ind_tile_2", "house_ind_tile_3", "house_ind_tile_4",
	"house_ind_haveli_1", "house_ind_haveli_2", "house_ind_haveli_3", "house_ind_haveli_4",
	"house_ind_merchant_1", "house_ind_merchant_2", "house_ind_merchant_3"]
const BIG_KINDS := ["big_nile_row", "big_nile_villa", "big_nile_farm", "big_nile_court",
	"big_ne_court", "big_ne_row", "big_ne_hall", "big_ne_kasbah", "big_ne_khan",
	"big_ind_haveli", "big_ind_court", "big_ind_row", "big_ind_farm"]
const PROP_KINDS := ["prop_shaduf", "prop_water_jars", "prop_reed_boat", "prop_rugs", "prop_dovecote",
	"prop_shrine_india", "prop_bullock_cart", "prop_tree_platform", "prop_mud_wall"]


## Every kind this module can build (the original hand-made ones first).
static func _generated() -> Array:
	return NILE_KINDS + NE_KINDS + IND_KINDS + BIG_KINDS + PROP_KINDS


## Build a generated kind or prop; false if `kind` is not one of them.
static func _build_generated(k: Kit, kind: String) -> bool:
	if kind.begins_with("prop_"):
		_prop(k, kind)
		return true
	var rows := _rows()
	if not rows.has(kind):
		return false
	var r := RandomNumberGenerator.new()
	r.seed = hash(kind)
	_run(k, r, rows[kind])
	return true


## Run one parameter row: a single archetype, or a "multi" row that places several in a frame.
static func _run(k: Kit, r: RandomNumberGenerator, P: Dictionary) -> void:
	match str(P.get("fn", "flat")):
		"multi":
			for part: Dictionary in P["parts"]:
				var at: Vector2 = part.get("at", Vector2.ZERO)
				k.push(Kit.at(Vector3(at.x, 0, at.y), part.get("yaw", 0.0)))
				_run(k, r, part)
				k.pop()
			for extra: Dictionary in P.get("extras", []):
				_extra(k, r, extra)
		"flat": _flat(k, r, P)
		"court": _court(k, r, P)
		"kasbah": _kasbah(k, r, P)
		"hittite": _hittite(k, r, P)
		"domed": _domed(k, r, P)
		"hut": _hut(k, r, P)
		"tiled": _tiled(k, r, P)
		"haveli": _haveli(k, r, P)
		"merchant": _merchant(k, r, P)


## Loose extras of a multi row: walls, trees, pools and the like, by "t".
static func _extra(k: Kit, r: RandomNumberGenerator, E: Dictionary) -> void:
	var p: Vector2 = E.get("at", Vector2.ZERO)
	var at3 := Vector3(p.x, E.get("y", 0.0), p.y)
	match str(E["t"]):
		"wall":   # a low wall of size (w, h, d)
			var s: Vector3 = E["size"]
			k.box(at3, s, E.get("col", MUD_LT), E.get("mat", Kit.MUDBRICK))
		"palm": _palm(k, at3, E.get("h", 0.5), E.get("fronds", 6))
		"tree": _tree(k, at3, E.get("h", 0.3), E.get("r", 0.12))
		"pond": _pond(k, at3, E.get("w", 0.3), E.get("d", 0.2))
		"granary": _granary(k, at3, E.get("r", 0.09), E.get("col", MUD))
		"pot": _pot(k, at3, E.get("r", 0.035))
		"beds": _beds(k, at3, E.get("w", 0.4), E.get("d", 0.3), E.get("n", 4))
		"pen": _pen(k, at3, E.get("w", 0.4), E.get("d", 0.3))
		"shelter": _roof_shelter(k, at3, E.get("w", 0.3), E.get("d", 0.3), E.get("h", 0.15), E.get("kind", "reed"))
		"gate": _gatepiers(k, at3, E.get("w", 0.2), E.get("h", 0.2), E.get("col", MUD_LT), E.get("mat", Kit.MUDBRICK))


# --- generated-house helpers -------------------------------------------------------------------


## A leafy tree: a short trunk and a squashed crown.
static func _tree(k: Kit, p: Vector3, h: float, r: float, col := GREEN) -> void:
	k.frustum(p, r * 0.14, r * 0.1, h, WOOD, Kit.TIMBER, 5, false)
	k.dome(p + Vector3(0, h * 0.7, 0), r, col, Kit.LEAF, 0.75, 3, 8)


## A shallow pool in a stone kerb.
static func _pond(k: Kit, p: Vector3, w: float, d: float) -> void:
	k.box(p, Vector3(w, 0.03, d), STONE_GR, Kit.STONE)
	k.box(p + Vector3(0, 0.0, 0), Vector3(w - 0.05, 0.036, d - 0.05), WATER_BLUE, Kit.WATER)


## Garden beds: rows of green on dark soil.
static func _beds(k: Kit, p: Vector3, w: float, d: float, n: int) -> void:
	k.box(p, Vector3(w, 0.014, d), Color(0.42, 0.30, 0.20), Kit.EARTH)
	for i in n:
		var z: float = -d / 2.0 + d * (i + 0.5) / n
		k.box(p + Vector3(0, 0.014, z), Vector3(w * 0.9, 0.035, d / n * 0.4), GREEN.lightened(0.05), Kit.LEAF)


## A reed or wattle animal pen: four low fence runs.
static func _pen(k: Kit, p: Vector3, w: float, d: float) -> void:
	for s in [-1.0, 1.0]:
		k.box(p + Vector3(s * w / 2.0, 0, 0), Vector3(0.02, 0.08, d), REED, Kit.THATCH)
		k.box(p + Vector3(0, 0, s * d / 2.0), Vector3(w, 0.08, 0.02), REED, Kit.THATCH)


## Two gate piers with a gap `w` between them.
static func _gatepiers(k: Kit, p: Vector3, w: float, h: float, col: Color, mat: int) -> void:
	for s in [-1.0, 1.0]:
		k.box(p + Vector3(s * (w / 2.0 + 0.03), 0, 0), Vector3(0.06, h, 0.06), col, mat)
		k.box(p + Vector3(s * (w / 2.0 + 0.03), h, 0), Vector3(0.08, 0.025, 0.08), col.lightened(0.05), mat)


## A palm-trunk column (rough shaft, square abacus) for porches and loggias.
static func _pcol(k: Kit, p: Vector3, h: float, r: float, col := PALM_TR, mat := Kit.TIMBER) -> void:
	k.frustum(p, r * 1.1, r, h, col, mat, 6, false)
	k.box(p + Vector3(0, h, 0), Vector3(r * 3.0, r * 0.9, r * 3.0), col.darkened(0.12), mat)


## A sloping cloth or reed awning: back edge at height hb, front edge at hf, centred on p.
## `posts` adds two front poles.
static func _awning(k: Kit, p: Vector3, w: float, d: float, hb: float, hf: float, col: Color, mat: int,
		posts := true) -> void:
	var a := p + Vector3(-w / 2.0, hb, -d / 2.0)
	var b := p + Vector3(w / 2.0, hb, -d / 2.0)
	var c := p + Vector3(w / 2.0, hf, d / 2.0)
	var e := p + Vector3(-w / 2.0, hf, d / 2.0)
	k.quad(a, b, c, e, col, mat, p + Vector3(0, hb - 2.0, 0))
	k.quad(a, b, c, e, col.darkened(0.3), mat, p + Vector3(0, hb + 2.0, 0))
	k.box(p + Vector3(0, hf - 0.035, d / 2.0), Vector3(w, 0.035, 0.012), col.darkened(0.12), mat)
	if posts:
		for s in [-1.0, 1.0]:
			var q := p + Vector3(s * (w / 2.0 - 0.015), 0, d / 2.0 - 0.015)
			k.rod(q, q + Vector3(0, hf, 0), 0.011, WOOD, Kit.TIMBER)


## A rooftop shelter on four posts: "reed" (hipped thatch) or "cloth" (a sloping owner-coloured awning)
## or "mat" (a flat reed mat).
static func _roof_shelter(k: Kit, p: Vector3, w: float, d: float, h: float, kind: String) -> void:
	if kind == "cloth":
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var q := p + Vector3(sx * (w / 2.0 - 0.015), 0, sz * (d / 2.0 - 0.015))
				k.rod(q, q + Vector3(0, h - (0.04 if sz < 0 else 0.0) + (0.05 if sz < 0 else 0.0), 0), 0.011, WOOD, Kit.TIMBER)
		_awning(k, p, w, d, h + 0.05, h, Color.WHITE, Kit.OWNER_CLOTH, false)
	elif kind == "mat":
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var q := p + Vector3(sx * (w / 2.0 - 0.015), 0, sz * (d / 2.0 - 0.015))
				k.rod(q, q + Vector3(0, h, 0), 0.011, WOOD, Kit.TIMBER)
		k.box(p + Vector3(0, h, 0), Vector3(w, 0.02, d), REED, Kit.THATCH)
		k.rod(p + Vector3(-w / 2.0, h + 0.02, 0), p + Vector3(w / 2.0, h + 0.02, 0), 0.01, WOOD, Kit.TIMBER)
	else:
		_shelter(k, p, w, d, h, h * 0.4)


## A drum and dome on a roof: radius r, drum height dh.
static func _roof_dome(k: Kit, p: Vector3, r: float, col: Color, dh := 0.05, mat := Kit.PLASTER, wall := WHITE) -> void:
	if dh > 0.0:
		k.frustum(p, r, r, dh, wall, Kit.PLASTER, 10, false)
	k.dome(p + Vector3(0, dh, 0), r, col, mat, 0.9, 4, 10)


## A row of dark window slots on a wall front: n slots over `span`, skipping near `skip_x` (a door).
static func _front_slots(k: Kit, r: RandomNumberGenerator, x0: float, z: float, y: float, span: float, n: int,
		skip_x: float, sw: float, sh: float, frame: Color, arched := false, yaw := 0.0) -> void:
	for i in n:
		var x: float = x0 - span / 2.0 + span * (i + 0.5) / n + r.randf_range(-0.01, 0.01)
		if absf(x - skip_x) < 0.12:
			continue
		if arched:
			_arch(k, Vector3(x, y, z + 0.004), yaw, sw, sh)
		else:
			_slot(k, Vector3(x, y, z), yaw, sw, sh, frame)


## The yard of a house with walls round it, from z0 (the house's front) to 0.5. `P` may hold:
## yard (1 = walls with a gate, 2 = walls with a gate and a deeper garden), gran, palms, pond, pots,
## trees, beds, pen. Items fall on a side picked by the rng.
static func _yard(k: Kit, r: RandomNumberGenerator, P: Dictionary, z0: float) -> void:
	var zc := (z0 + 0.5) / 2.0
	var ln := 0.5 - z0
	var wcol: Color = P.get("ycol", MUD_LT)
	var wmat: int = P.get("ymat", Kit.MUDBRICK)
	var wh: float = P.get("ywh", 0.12)
	for s in [-1.0, 1.0]:
		var sx: float = s * 0.48
		k.box(Vector3(sx, 0, zc), Vector3(0.04, wh, ln), wcol, wmat)
		k.box(Vector3(s * 0.3, 0, 0.48), Vector3(0.36, wh, 0.04), wcol, wmat)
	_gatepiers(k, Vector3(0, 0, 0.48), 0.2, wh + 0.06, wcol.darkened(0.05), wmat)
	var side: float = 1.0 if r.randf() < 0.5 else -1.0
	var slot := 0
	for i in int(P.get("gran", 0)):
		var gx: float = side * (0.3 - 0.13 * (i % 2)) - side * 0.0
		_granary(k, Vector3(gx, 0, z0 + 0.14 + 0.12 * i), 0.09 - 0.01 * (i % 2), MUD if i % 2 == 0 else MUD_LT)
	for i in int(P.get("palms", 0)):
		var px: float = -side * 0.34 + (0.0 if i % 2 == 0 else side * 0.7)
		_palm(k, Vector3(px, 0, z0 + 0.12 + 0.1 * i), 0.5 + 0.08 * i, 6)
	for i in int(P.get("trees", 0)):
		var tx: float = (-0.3 if i % 2 == 0 else 0.3) + r.randf_range(-0.04, 0.04)
		_tree(k, Vector3(tx, 0, z0 + 0.18 + 0.12 * i), 0.22, 0.12)
	if P.get("pond", false):
		_pond(k, Vector3(-side * 0.0, 0, (z0 + 0.5) / 2.0 + 0.02), 0.28, 0.18)
	if P.get("beds", false):
		_beds(k, Vector3(-side * 0.26, 0, z0 + 0.2), 0.26, 0.22, 4)
	if P.get("pen", false):
		_pen(k, Vector3(side * 0.26, 0, z0 + 0.2), 0.3, 0.22)
	for i in int(P.get("pots", 0)):
		_pot(k, Vector3(-0.1 + i * 0.1, 0, 0.38), 0.035)


# --- ARCHETYPE: flat-roofed block house (Nile town and worker houses, Near East flat houses) ----


## A flat-roofed mud or plaster block: optional battered walls, an upper room set back,
## parapets, an outside stair, a roof shelter or wind-catcher or domes, beam ends, a painted
## band, a porch on palm columns, a walled yard behind a gate.
static func _flat(k: Kit, r: RandomNumberGenerator, P: Dictionary) -> void:
	var w: float = P.get("w", 0.7)
	var d: float = P.get("d", 0.55)
	var h: float = P.get("h", 0.4)
	var wall: Color = P.get("wall", MUD)
	var trim: Color = P.get("trim", MUD_LT)
	var mat: int = P.get("mat", Kit.MUDBRICK)
	var inset: float = 0.04 if P.get("batter", true) else 0.0
	var stair: int = P.get("stair", 0)
	var yard: int = P.get("yard", 0)
	var ox: float = -stair * 0.08 + P.get("ox", 0.0)
	var oz: float = P.get("oz", 0.0)
	if yard > 0:
		oz = -0.5 + d / 2.0 + 0.03
	var base := Vector3(ox, 0, oz)
	var front := oz + d / 2.0
	# body and roof slab
	if inset > 0.0:
		k.plinth(base, w, d, h, inset, wall, mat)
	else:
		k.box(base, Vector3(w, h, d), wall, mat)
	var rw := w - inset * 2.0 + 0.06
	var rd := d - inset * 2.0 + 0.06
	k.box(base + Vector3(0, h, 0), Vector3(rw, 0.035, rd), trim, mat)
	var top := h + 0.035
	_parapet(k, base + Vector3(0, top, 0), rw, rd, P.get("pw", 0.055), 0.03, trim, mat)
	if P.get("merlons", false):
		_merlons(k, base + Vector3(0, top + P.get("pw", 0.055), 0), rw, rd, 0.06, 0.04, trim, mat)
	# upper room, set back
	var uh: float = P.get("uh", 0.0)
	var utop := top
	var ub := base + Vector3(0, top, 0)
	if uh > 0.0:
		var uw: float = P.get("uw", w * 0.62)
		var ud: float = P.get("ud", d * 0.62)
		var uc: Vector2 = P.get("uat", Vector2(-0.1, -0.05))
		ub = base + Vector3(uc.x, top, uc.y)
		var ucol: Color = P.get("ucol", wall.lightened(0.12))
		if inset > 0.0:
			k.plinth(ub, uw, ud, uh, 0.03, ucol, mat)
		else:
			k.box(ub, Vector3(uw, uh, ud), ucol, mat)
		k.box(ub + Vector3(0, uh, 0), Vector3(uw - (0.06 if inset > 0 else 0.0) + 0.06, 0.03, ud + (0.0 if inset > 0 else 0.0)), trim, mat)
		_parapet(k, ub + Vector3(0, uh + 0.03, 0), uw - (0.06 if inset > 0 else 0.0) + 0.06, ud, 0.05, 0.028, trim, mat)
		utop = top + uh + 0.03
		var uf := ub.z + ud / 2.0 - (0.03 * 0.3 if inset > 0 else 0.0)
		_slot(k, Vector3(ub.x - uw * 0.2, top + uh * 0.45, uf), 0.0, 0.05, 0.075, trim)
		_slot(k, Vector3(ub.x + uw * 0.2, top + uh * 0.45, uf), 0.0, 0.05, 0.075, trim)
		if P.has("uband"):
			k.box(Vector3(ub.x, top + uh - 0.05, uf + 0.004), Vector3(uw - 0.04, 0.025, 0.012), P["uband"], Kit.PAINT)
		if P.get("lattice", false):   # a wooden screened balcony on the upper front
			k.box(Vector3(ub.x + uw * 0.1, top + uh * 0.2, uf + 0.06), Vector3(uw * 0.55, uh * 0.55, 0.1), WOOD, Kit.TIMBER)
			k.box(Vector3(ub.x + uw * 0.1, top + uh * 0.2 + uh * 0.55, uf + 0.06), Vector3(uw * 0.62, 0.025, 0.14), WOOD_DK, Kit.TIMBER)
			k.box(Vector3(ub.x + uw * 0.1, top + uh * 0.3, uf + 0.112), Vector3(uw * 0.42, uh * 0.3, 0.012), SHADE, Kit.DARK)
	# the front: door, windows, band, beam ends
	var fz := front - inset * 0.4
	var dx: float = P.get("dx", -w * 0.2)
	var dh := minf(h - 0.1, P.get("dh", 0.27))
	var dcol: Color = P.get("door", BLUE)
	if P.get("porch", 0) > 0:
		var n: int = P["porch"]
		var pd := 0.17
		var ph := minf(h - 0.02, 0.3)
		for i in n:
			var px: float = ox - w / 2.0 + 0.04 + (w - 0.08) * i / maxf(n - 1, 1)
			_pcol(k, Vector3(px, 0, front + pd - 0.02), ph, 0.017, P.get("pcol", PALM_TR), P.get("pmat", Kit.TIMBER))
		k.box(Vector3(ox, ph + 0.03, front + pd / 2.0 - 0.02), Vector3(w - 0.0, 0.03, pd + 0.02), trim, mat)
		k.box(Vector3(ox, 0, front + pd / 2.0 - 0.02), Vector3(w - 0.04, 0.025, pd), Color(0.72, 0.64, 0.5), Kit.STONE)
	_arch_door(k, Vector3(ox + dx, 0, fz), 0.0, 0.14, dh, trim, dcol, mat)
	_front_slots(k, r, ox, fz, h * 0.6, w * 0.8, int(P.get("win", 2)), ox + dx, 0.05, 0.065, trim, P.get("arched", false))
	if P.has("band"):
		var bz := front - inset * (1.0 - 0.07 / h) + 0.006
		k.box(Vector3(ox, h - 0.1, bz), Vector3(w - inset * 2.0, 0.03, 0.012), P["band"], Kit.PAINT)
		if P.has("band2"):
			k.box(Vector3(ox, h * 0.3, front - inset * 0.7 + 0.006), Vector3(w - inset * 1.4, 0.02, 0.012), P["band2"], Kit.PAINT)
	if P.has("holes"):   # pigeon holes in a grid up the front of a tower
		var hc: Vector2i = P["holes"]
		for ry in hc.y:
			for cx in hc.x:
				var hx: float = ox - (w - 0.2) / 2.0 + (w - 0.2) * (cx + 0.5) / hc.x
				var hy: float = h * 0.55 + ry * (h * 0.3 / hc.y)
				k.box(Vector3(hx, hy, front - inset * (hy / h) + 0.002), Vector3(0.035, 0.035, 0.012), SHADE, Kit.DARK)
	if P.get("horns", false):   # horned corner pinnacles
		for sx3 in [-1.0, 1.0]:
			for sz3 in [-1.0, 1.0]:
				k.plinth(base + Vector3(sx3 * (rw / 2.0 - 0.035), top, sz3 * (rd / 2.0 - 0.035)), 0.07, 0.07, 0.08, 0.02, trim, mat)
	if P.get("beams", 0) > 0:   # palm-trunk beam ends poking out under the parapet
		var nb: int = P["beams"]
		for i in nb:
			var bx: float = ox - w / 2.0 + inset + (w - inset * 2.0) * (i + 0.5) / nb
			k.rod(Vector3(bx, h - 0.03, fz - 0.01), Vector3(bx, h - 0.03, fz + 0.06), 0.013, PALM_TR, Kit.TIMBER)
		for s in [-1.0, 1.0]:
			for j in 2:
				var bzz: float = oz - d * 0.2 + j * d * 0.4
				var sx: float = ox + s * (w / 2.0 - inset * 0.6)
				k.rod(Vector3(sx, h - 0.03, bzz), Vector3(sx + s * 0.06, h - 0.03, bzz), 0.013, PALM_TR, Kit.TIMBER)
	# outside stair to the first roof
	if stair != 0:
		var n := clampi(int(round(top / 0.07)), 3, 8)
		var sx2: float = ox + stair * (w / 2.0 - inset * 0.5 + 0.06)
		_stairs(k, Vector3(sx2, 0, front - 0.02), 0.0, 0.11, n, top / n, 0.06, trim, mat)
	# roof furniture
	var fy := utop if P.get("high", false) else top
	var fb := ub if P.get("high", false) else base + Vector3(0, top, 0)
	fb.y = 0.0
	var sh: String = P.get("shelter", "")
	if sh != "":
		var sp: Vector2 = P.get("sat", Vector2(0.15, -0.05))
		var ss: Vector2 = P.get("ssize", Vector2(0.3, 0.3))
		_roof_shelter(k, Vector3(fb.x + sp.x, fy, fb.z + sp.y), ss.x, ss.y, P.get("sh", 0.16), sh)
	if P.get("malqaf", false):
		var mp: Vector2 = P.get("mq", Vector2(-0.18, -0.12))
		_malqaf(k, Vector3(fb.x + mp.x, fy, fb.z + mp.y), 0.2, 0.15, P.get("mh", 0.3), trim)
	if P.get("badgir", false):
		var bp: Vector2 = P.get("bat", Vector2(-0.2, -0.12))
		_badgir(k, Vector3(fb.x + bp.x, fy, fb.z + bp.y), 0.2, P.get("bh", 0.4), wall, mat)
	for dm: Array in P.get("domes", []):
		_roof_dome(k, Vector3(fb.x + dm[0], fy, fb.z + dm[1]), dm[2], dm[3] if dm.size() > 3 else WHITE)
	for i in int(P.get("pots", 1)):
		_pot(k, Vector3(fb.x + 0.12 + i * 0.1, fy, fb.z + 0.12 - i * 0.05), 0.04 - i * 0.005)
	if P.get("mats", false):
		k.box(Vector3(fb.x + 0.1, fy, fb.z - 0.12), Vector3(0.14, 0.03, 0.06), REED, Kit.THATCH)
	# yard and trees
	if yard > 0:
		_yard(k, r, P, oz + d / 2.0)
	else:
		for i in int(P.get("palms", 1)):
			var px2: float = ox + (w / 2.0 + 0.1 if i == 0 else -w / 2.0 - 0.08) * (1.0 if (i + stair) % 2 == 0 else -1.0)
			px2 = clampf(px2, -0.46, 0.46)
			_palm(k, Vector3(px2, 0, front - 0.05 + 0.1 * i), 0.5 - 0.06 * i, 6)


# --- parameter rows ------------------------------------------------------------------------------


static func _rows() -> Dictionary:
	var rows := {}
	rows.merge(_nile_rows())
	rows.merge(_ne_rows())
	rows.merge(_ind_rows())
	rows.merge(_big_rows())
	return rows


static func _nile_rows() -> Dictionary:
	return {
		"house_nile_worker_1": {"fn": "flat", "w": 0.62, "d": 0.5, "h": 0.36, "stair": 1, "shelter": "reed",
			"sat": Vector2(-0.05, 0.0), "ssize": Vector2(0.3, 0.3), "win": 1, "palms": 1, "door": BLUE},
		"house_nile_worker_2": {"fn": "flat", "w": 0.7, "d": 0.4, "h": 0.3, "yard": 1, "gran": 2, "palms": 1,
			"pen": true, "win": 2, "door": RED, "beams": 4, "pots": 2, "sat": Vector2(0.1, 0.0),
			"shelter": "mat", "ssize": Vector2(0.26, 0.26), "sh": 0.13},
		"house_nile_worker_3": {"fn": "flat", "w": 0.5, "d": 0.5, "h": 0.42, "beams": 5, "shelter": "mat",
			"sat": Vector2(0.0, 0.0), "ssize": Vector2(0.32, 0.32), "sh": 0.14, "band": RED, "door": OCHRE,
			"win": 0, "palms": 2, "wall": MUD.darkened(0.06), "pots": 2},
		"house_nile_worker_4": {"fn": "multi", "parts": [
			{"fn": "flat", "w": 0.5, "d": 0.44, "h": 0.34, "at": Vector2(-0.22, 0.06), "stair": 0, "win": 1,
				"palms": 0, "pots": 1, "door": BLUE, "shelter": "reed", "sat": Vector2(0.0, -0.02),
				"ssize": Vector2(0.28, 0.28), "sh": 0.14},
			{"fn": "flat", "w": 0.34, "d": 0.36, "h": 0.24, "at": Vector2(0.27, -0.1), "wall": MUD_LT,
				"win": 1, "palms": 0, "pots": 0, "door": RED, "dh": 0.18, "dx": 0.0}],
			"extras": [{"t": "palm", "at": Vector2(0.3, 0.32), "h": 0.5}, {"t": "granary", "at": Vector2(-0.38, -0.4), "r": 0.08},
				{"t": "pen", "at": Vector2(0.28, 0.2), "w": 0.26, "d": 0.2}]},
		"house_nile_town_1": {"fn": "flat", "w": 0.7, "d": 0.6, "h": 0.34, "uh": 0.3, "uw": 0.46, "ud": 0.4,
			"uat": Vector2(-0.12, -0.08), "stair": 1, "shelter": "reed", "sat": Vector2(0.2, 0.0),
			"ssize": Vector2(0.24, 0.34), "band": RED, "uband": BLUE, "win": 2, "wall": MUD, "ucol": LIME},
		"house_nile_town_2": {"fn": "flat", "w": 0.66, "d": 0.56, "h": 0.42, "uh": 0.34, "uw": 0.42, "ud": 0.36,
			"uat": Vector2(0.1, -0.1), "malqaf": true, "mq": Vector2(-0.18, 0.04), "mh": 0.3,
			"shelter": "cloth", "high": true, "sat": Vector2(0.0, 0.0), "ssize": Vector2(0.3, 0.28), "sh": 0.15,
			"wall": LIME, "trim": WHITE, "ucol": WHITE, "band": BLUE, "uband": RED, "door": TURQ, "win": 2,
			"dx": 0.2, "palms": 1},
		"house_nile_town_3": {"fn": "flat", "w": 0.72, "d": 0.5, "h": 0.32, "uh": 0.26, "uw": 0.5, "ud": 0.34,
			"uat": Vector2(-0.08, -0.06), "porch": 4, "shelter": "reed", "high": true, "sat": Vector2(0.0, 0.0),
			"ssize": Vector2(0.34, 0.26), "sh": 0.14, "wall": OCHRE_WALL, "trim": MUD_LT, "ucol": MUD_LT,
			"band": BLUE, "win": 0, "dx": 0.0, "door": RED, "palms": 1, "lattice": true},
		"house_nile_town_4": {"fn": "flat", "w": 0.68, "d": 0.6, "h": 0.5, "batter": false, "mat": Kit.PLASTER,
			"wall": WHITE, "trim": LIME, "stair": -1, "malqaf": true, "mq": Vector2(0.1, -0.08), "mh": 0.28,
			"domes": [[-0.16, 0.02, 0.1, MUD_LT]], "band": TURQ, "band2": RED, "win": 3, "door": OCHRE, "dx": 0.18,
			"beams": 3, "palms": 1},
		"house_nile_villa_1": {"fn": "flat", "w": 0.84, "d": 0.4, "h": 0.34, "uh": 0.2, "uw": 0.42, "ud": 0.3,
			"uat": Vector2(0.14, -0.02), "yard": 2, "porch": 4, "wall": LIME, "trim": WHITE, "ucol": WHITE,
			"band": RED, "win": 0, "door": BLUE, "dx": 0.0, "dh": 0.22, "pond": true, "trees": 2, "palms": 2,
			"ycol": WHITE, "ymat": Kit.PLASTER, "beams": 0, "pots": 0, "pcol": RED, "pmat": Kit.PAINT, "ywh": 0.14},
		"house_nile_villa_2": {"fn": "flat", "w": 0.76, "d": 0.44, "h": 0.4, "uh": 0.24, "uw": 0.34, "ud": 0.34,
			"uat": Vector2(-0.17, -0.03), "yard": 1, "wall": OCHRE_WALL, "trim": MUD_LT, "ucol": LIME,
			"band": BLUE, "uband": GILD, "win": 2, "door": RED, "beams": 6, "beds": true, "trees": 1, "palms": 2,
			"shelter": "cloth", "high": true, "sat": Vector2(0.0, 0.0), "ssize": Vector2(0.26, 0.26), "sh": 0.13,
			"pots": 0, "ycol": OCHRE_WALL, "stair": 0},
		"house_nile_farm_1": {"fn": "flat", "w": 0.56, "d": 0.38, "h": 0.3, "yard": 1, "gran": 3, "palms": 1,
			"pen": true, "stair": 1, "shelter": "mat", "sat": Vector2(-0.05, 0.0), "ssize": Vector2(0.22, 0.22),
			"sh": 0.12, "win": 1, "door": OCHRE, "pots": 2},
		"house_nile_farm_2": {"fn": "multi", "parts": [
			{"fn": "flat", "w": 0.52, "d": 0.42, "h": 0.38, "at": Vector2(-0.2, -0.16), "stair": 1, "win": 1, "palms": 0,
				"shelter": "reed", "sat": Vector2(-0.04, 0.0), "ssize": Vector2(0.26, 0.26), "sh": 0.14, "wall": MUD_LT.darkened(0.05)}],
			"extras": [{"t": "granary", "at": Vector2(0.3, -0.34), "r": 0.1}, {"t": "granary", "at": Vector2(0.42, -0.16), "r": 0.08, "col": MUD_LT},
				{"t": "granary", "at": Vector2(0.28, -0.14), "r": 0.075}, {"t": "pen", "at": Vector2(-0.18, 0.28), "w": 0.4, "d": 0.28},
				{"t": "palm", "at": Vector2(0.38, 0.16), "h": 0.55}, {"t": "palm", "at": Vector2(0.1, 0.38), "h": 0.45, "fronds": 6},
				{"t": "beds", "at": Vector2(0.22, 0.32), "w": 0.3, "d": 0.24, "n": 3}]},
		"house_nile_tower_1": {"fn": "flat", "w": 0.52, "d": 0.46, "h": 0.8, "wall": WHITE, "trim": MUD_LT,
			"holes": Vector2i(4, 3), "horns": true, "band": RED, "band2": BLUE, "win": 0, "door": OCHRE, "dx": 0.0,
			"stair": 0, "palms": 2, "pots": 0, "mat": Kit.MUDBRICK},
		"house_nile_tower_2": {"fn": "flat", "w": 0.6, "d": 0.5, "h": 0.46, "uh": 0.34, "uw": 0.3, "ud": 0.3,
			"uat": Vector2(-0.14, -0.1), "stair": 1, "wall": MUD, "trim": MUD_LT, "ucol": LIME, "beams": 4,
			"shelter": "mat", "high": true, "sat": Vector2(0.0, 0.0), "ssize": Vector2(0.24, 0.24), "sh": 0.12,
			"win": 1, "door": BLUE, "palms": 1, "pots": 2, "uband": TURQ},
	}


# --- NEAR EAST archetypes ----------------------------------------------------------------------


## One wing of a courtyard house in its own frame: length w along x, depth d, court on the +z side.
## `roof`: "flat" (parapet), "dome", "reed" (thatch gable) or "vault" (flat with a low dome).
static func _wing(k: Kit, w: float, d: float, h: float, wall: Color, trim: Color, mat: int, roof: String,
		dome_col: Color, arches: int, arch_col: Color) -> void:
	k.box(Vector3.ZERO, Vector3(w, h, d), wall, mat)
	k.box(Vector3(0, h, 0), Vector3(w + 0.02, 0.035, d + 0.03), trim, mat)
	match roof:
		"dome", "vault":
			var rr := minf(w, d) * (0.42 if roof == "dome" else 0.3)
			k.frustum(Vector3(0, h + 0.035, 0), rr, rr, 0.05, wall, mat, 10, false)
			k.dome(Vector3(0, h + 0.085, 0), rr, dome_col, Kit.PAINT if dome_col != wall else mat, 0.9, 4, 12)
			if roof == "vault":
				_parapet(k, Vector3(0, h + 0.035, 0), w + 0.02, d + 0.03, 0.05, 0.03, trim, mat)
		"reed":
			k.gable_roof(Vector3(0, h + 0.035, 0), w, d, 0.12, 0.05, 0.025, REED, Kit.THATCH, wall, mat)
		_:
			_parapet(k, Vector3(0, h + 0.035, 0), w + 0.02, d + 0.03, 0.055, 0.03, trim, mat)
	for i in arches:
		var ax: float = -w / 2.0 + w * (i + 0.5) / arches
		_arch(k, Vector3(ax, 0.0, d / 2.0), 0.0, minf(0.13, w / arches * 0.5), minf(h * 0.8, 0.26))
	if arches > 0:
		k.box(Vector3(0, h * 0.8, d / 2.0 + 0.002), Vector3(w * 0.96, 0.02, 0.012), arch_col, Kit.PAINT)


## A courtyard house: wings round an open court (a cut-out at the middle), a gate in the front
## wall, a court with a pool, trees or a well. P: back/left/right (wing heights, 0 = none), roofs,
## up (an upper storey over the back wing), tree/pool/well, badgir.
static func _court(k: Kit, r: RandomNumberGenerator, P: Dictionary) -> void:
	var wall: Color = P.get("wall", WHITE.darkened(0.04))
	var trim: Color = P.get("trim", LIME)
	var mat: int = P.get("mat", Kit.PLASTER)
	var acol: Color = P.get("acol", BLUE)
	var dcol: Color = P.get("dome", TURQ)
	var cw: float = P.get("w", 1.0)
	var cd: float = P.get("d", 1.0)
	var cx := -cw / 2.0
	var ground: Color = P.get("ground", Color(0.76, 0.68, 0.52))
	k.box(Vector3(0, 0, 0), Vector3(cw, 0.03, cd), ground, Kit.EARTH)
	var hb: float = P.get("back", 0.42)
	var hl: float = P.get("left", 0.36)
	var hr: float = P.get("right", 0.3)
	var wd: float = P.get("wd", 0.22)
	if hb > 0.0:
		k.push(Kit.at(Vector3(0, 0.03, -cd / 2.0 + wd / 2.0 + 0.01), 0.0))
		_wing(k, cw - 0.02, wd, hb, wall, trim, mat, P.get("rback", "flat"), dcol, int(P.get("archb", 2)), acol)
		if P.get("up", 0.0) > 0.0:
			var uh: float = P["up"]
			var uwid: float = P.get("upw", 0.5)
			k.box(Vector3(P.get("upx", 0.0), hb + 0.035, 0), Vector3(uwid, uh, wd * 0.8), wall.lightened(0.04), mat)
			k.box(Vector3(P.get("upx", 0.0), hb + 0.035 + uh, 0), Vector3(uwid + 0.04, 0.03, wd * 0.8 + 0.04), trim, mat)
			var bx: float = P.get("upx", 0.0)
			if P.get("lattice", true):   # a screened balcony over the court
				k.box(Vector3(bx, hb + 0.035 + uh * 0.15, wd * 0.4 + 0.045), Vector3(uwid * 0.7, uh * 0.6, 0.09), WOOD, Kit.TIMBER)
				k.box(Vector3(bx, hb + 0.035 + uh * 0.15 + uh * 0.6, wd * 0.4 + 0.045), Vector3(uwid * 0.76, 0.02, 0.12), WOOD_DK, Kit.TIMBER)
				k.box(Vector3(bx, hb + 0.035 + uh * 0.28, wd * 0.4 + 0.092), Vector3(uwid * 0.5, uh * 0.3, 0.012), SHADE, Kit.DARK)
			else:
				_arch(k, Vector3(bx - 0.1, hb + 0.035 + 0.03, wd * 0.4), 0.0, 0.07, 0.14)
				_arch(k, Vector3(bx + 0.1, hb + 0.035 + 0.03, wd * 0.4), 0.0, 0.07, 0.14)
		k.pop()
	if hl > 0.0:
		k.push(Kit.at(Vector3(cx + wd / 2.0 + 0.01, 0.03, 0.0), PI / 2.0))
		_wing(k, cd * 0.56, wd, hl, wall, trim, mat, P.get("rleft", "dome"), dcol, int(P.get("archl", 1)), acol)
		k.pop()
	if hr > 0.0:
		k.push(Kit.at(Vector3(-cx - wd / 2.0 - 0.01, 0.03, 0.0), -PI / 2.0))
		_wing(k, cd * 0.56, wd, hr, wall, trim, mat, P.get("rright", "flat"), dcol, int(P.get("archr", 1)), acol)
		k.pop()
	# front wall with a gate
	var fz := cd / 2.0 - 0.04
	var fh: float = P.get("front", 0.3)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * (cw / 2.0 - 0.19), 0.03, fz), Vector3(0.38, fh, 0.07), wall, mat)
		k.box(Vector3(s * (cw / 2.0 - 0.19), 0.03 + fh, fz), Vector3(0.4, 0.03, 0.09), trim, mat)
	k.box(Vector3(0, 0.03 + fh * 0.8, fz), Vector3(0.28, fh * 0.45, 0.07), wall, mat)
	k.box(Vector3(0, 0.03 + fh * 0.8 + fh * 0.45, fz), Vector3(0.32, 0.03, 0.09), trim, mat)
	_arch_door(k, Vector3(0, 0.03, fz + 0.035), 0.0, 0.17, fh * 0.9, trim, P.get("door", BLUE), mat)
	if P.get("gate_tower", false):
		k.box(Vector3(0, 0.03 + fh * 1.25, fz), Vector3(0.34, 0.16, 0.12), wall, mat)
		k.box(Vector3(0, 0.03 + fh * 1.25 + 0.16, fz), Vector3(0.38, 0.03, 0.15), trim, mat)
	# the court itself
	var cc: String = P.get("court", "tree")
	var ctr := Vector3(0.0, 0.03, 0.06)
	match cc:
		"pool":
			_pond(k, ctr, 0.3, 0.2)
			_tree(k, Vector3(0.2, 0.03, 0.28), 0.16, 0.1)
			_tree(k, Vector3(-0.22, 0.03, 0.26), 0.14, 0.09, GREEN.darkened(0.1))
		"well":
			k.cylinder(ctr + Vector3(0.0, 0, 0.05), 0.06, 0.07, STONE_GR, Kit.STONE, 8)
			k.box(ctr + Vector3(0, 0.07, 0.05), Vector3(0.1, 0.004, 0.1), SHADE, Kit.DARK)
			_pot(k, Vector3(-0.2, 0.03, 0.26), 0.04)
			_pot(k, Vector3(0.22, 0.03, 0.22), 0.035)
		"beds":
			_beds(k, ctr + Vector3(0.0, 0, 0.0), 0.34, 0.28, 4)
			_tree(k, Vector3(0.25, 0.03, 0.3), 0.18, 0.11)
		_:
			_tree(k, Vector3(0.18, 0.03, 0.1), 0.2, 0.13)
			_tree(k, Vector3(-0.16, 0.03, 0.26), 0.14, 0.09, GREEN.darkened(0.1))
	if P.get("badgir", false):
		_badgir(k, Vector3(P.get("bx", 0.3), 0.03 + hb + 0.035, -cd / 2.0 + wd / 2.0), 0.14, 0.2, wall, mat)


## A kasbah-like tower house: stepped tapering earth storeys, corner towers with merlons and
## zigzag bands, small slit windows, a studded gate. P: n (storeys), towers [[x, z, h, w]],
## wall (a low outer wall with a gate).
static func _kasbah(k: Kit, r: RandomNumberGenerator, P: Dictionary) -> void:
	var col: Color = P.get("col", Color(0.70, 0.50, 0.34))
	var light: Color = P.get("light", Color(0.88, 0.76, 0.58))
	var bw: float = P.get("bw", 0.56)
	var bd: float = P.get("bd", 0.46)
	var n: int = P.get("n", 2)
	var bz: float = P.get("bz", -0.06)
	var sh := 0.2
	var y := 0.0
	for i in n:
		var w := bw - i * 0.07
		var d := bd - i * 0.07
		k.plinth(Vector3(0, y, bz), w, d, sh, 0.02, col.lightened(0.04 * i), Kit.EARTH)
		k.box(Vector3(0, y + sh, bz), Vector3(w - 0.03, 0.025, d - 0.03), light, Kit.EARTH)
		_front_slots(k, r, 0.0, bz + d / 2.0 - 0.008, y + sh * 0.55, w * 0.7, 2 if i == 0 else 3, 99.0, 0.035, 0.06, light)
		y += sh + 0.025
	var tw: float = bw - (n - 1) * 0.07
	var td: float = bd - (n - 1) * 0.07
	_parapet(k, Vector3(0, y, bz), tw - 0.03, td - 0.03, 0.05, 0.03, light, Kit.EARTH)
	_arch_door(k, Vector3(P.get("dx", -0.12), 0, bz + bd / 2.0 - 0.015), 0.0, 0.13, 0.25, light, WOOD_DK, Kit.EARTH)
	for t: Array in P.get("towers", [[-0.3, -0.26, 0.74, 0.2], [0.32, 0.12, 0.5, 0.18]]):
		var tx: float = t[0]
		var tz: float = t[1]
		var th: float = t[2]
		var twd: float = t[3]
		k.plinth(Vector3(tx, 0, tz), twd, twd, th, 0.045, col.darkened(0.04), Kit.EARTH)
		k.box(Vector3(tx, th, tz), Vector3(twd - 0.06, 0.03, twd - 0.06), light, Kit.EARTH)
		_merlons(k, Vector3(tx, th + 0.03, tz), twd - 0.06, twd - 0.06, 0.05, 0.05, light, Kit.EARTH)
		for f in 2:   # zigzag diamonds on two faces
			k.push(Kit.at(Vector3(tx, 0, tz), f * PI / 2.0))
			for i in 3:
				var zx: float = (i - 1) * twd * 0.24
				k.box(Vector3(zx, th * 0.72, twd / 2.0 - 0.045 * 0.72 - 0.005), Vector3(0.04, 0.04, 0.012), light, Kit.PAINT)
				k.box(Vector3(zx, th * 0.62, twd / 2.0 - 0.045 * 0.62 - 0.005), Vector3(0.02, 0.02, 0.012), SHADE, Kit.DARK)
			k.pop()
		_slot(k, Vector3(tx, th * 0.4, tz + twd / 2.0 - 0.045 * 0.4 - 0.004), 0.0, 0.03, 0.07, light)
	if P.get("wall", false):
		for s in [-1.0, 1.0]:
			k.box(Vector3(s * 0.34, 0, 0.44), Vector3(0.3, 0.12, 0.04), col, Kit.EARTH)
			k.box(Vector3(s * 0.34, 0.12, 0.44), Vector3(0.3, 0.02, 0.06), light, Kit.EARTH)
		k.box(Vector3(-0.46, 0, 0.0), Vector3(0.04, 0.1, 0.88), col, Kit.EARTH)
		_gatepiers(k, Vector3(0, 0, 0.44), 0.2, 0.17, light, Kit.EARTH)
		_pot(k, Vector3(-0.3, 0, 0.3), 0.04)
	for i in int(P.get("palms", 1)):
		_palm(k, Vector3(0.36 - 0.72 * i, 0, 0.34), 0.5, 6)


## A stone-and-timber house (Hittite/Anatolian): a rough stone base, a timber-framed upper
## floor with plaster infill and beam ends, a flat earth roof or a steep thatched one.
## P: roof "flat"/"gable"/"hip", bw/bd, sb (base height), uh, corner (a stone tower), stair.
static func _hittite(k: Kit, r: RandomNumberGenerator, P: Dictionary) -> void:
	var bw: float = P.get("bw", 0.7)
	var bd: float = P.get("bd", 0.56)
	var sb: float = P.get("sb", 0.26)
	var uh: float = P.get("uh", 0.26)
	var ox: float = P.get("ox", -0.04 if P.get("stair", false) else 0.0)
	var stone: Color = P.get("stone", STONE_GR)
	var plaster: Color = P.get("plaster", LIME)
	k.box(Vector3(ox, 0, 0), Vector3(bw, sb, bd), stone, Kit.STONE)
	for i in 3:   # a few dark-edged stone courses for texture
		k.box(Vector3(ox, sb * (i + 1) / 4.0, bd / 2.0 + 0.002), Vector3(bw, 0.008, 0.008), stone.darkened(0.25), Kit.STONE)
	k.box(Vector3(ox, sb, 0), Vector3(bw + 0.04, 0.03, bd + 0.04), WOOD_DK, Kit.TIMBER)   # the floor beam
	var y1 := sb + 0.03
	var uw := bw - 0.02
	var ud := bd - 0.02
	if uh > 0.0:
		k.box(Vector3(ox, y1, 0), Vector3(uw, uh, ud), plaster, Kit.PLASTER)
		for i in 5:   # posts and braces on the front
			var px: float = ox - uw / 2.0 + uw * i / 4.0
			k.rod(Vector3(px, y1, ud / 2.0 + 0.004), Vector3(px, y1 + uh, ud / 2.0 + 0.004), 0.011, WOOD_DK, Kit.TIMBER)
		for i in 4:
			var px2: float = ox - uw / 2.0 + uw * (i + 0.5) / 4.0
			if i % 2 == 0:
				k.rod(Vector3(px2 - uw / 8.0, y1, ud / 2.0 + 0.004), Vector3(px2 + uw / 8.0, y1 + uh, ud / 2.0 + 0.004), 0.008, WOOD, Kit.TIMBER)
			else:
				k.rod(Vector3(px2 + uw / 8.0, y1, ud / 2.0 + 0.004), Vector3(px2 - uw / 8.0, y1 + uh, ud / 2.0 + 0.004), 0.008, WOOD, Kit.TIMBER)
		for j in 3:   # beam ends poking out of the side
			var bz: float = -ud / 2.0 + ud * (j + 0.5) / 3.0
			k.rod(Vector3(ox + uw / 2.0, y1 - 0.01, bz), Vector3(ox + uw / 2.0 + 0.07, y1 - 0.01, bz), 0.013, WOOD, Kit.TIMBER)
			k.rod(Vector3(ox - uw / 2.0, y1 - 0.01, bz), Vector3(ox - uw / 2.0 - 0.07, y1 - 0.01, bz), 0.013, WOOD, Kit.TIMBER)
		k.window(Vector3(ox + uw * 0.25, y1 + uh * 0.5, ud / 2.0 + 0.012), 0.0, 0.07, 0.08, WOOD_DK, "shutters")
		k.window(Vector3(ox - uw * 0.25, y1 + uh * 0.5, ud / 2.0 + 0.012), 0.0, 0.07, 0.08, WOOD_DK, "shutters")
	var ytop := y1 + uh
	match str(P.get("roof", "flat")):
		"gable":
			k.gable_roof(Vector3(ox, ytop, 0), uw if uh > 0 else bw, ud if uh > 0 else bd, P.get("rise", 0.24), 0.07, 0.03,
				P.get("rcol", REED), P.get("rmat", Kit.THATCH), plaster, Kit.PLASTER, 0.0)
		"hip":
			k.hip_roof(Vector3(ox, ytop, 0), uw, ud, P.get("rise", 0.2), 0.07, 0.03, P.get("rcol", REED), P.get("rmat", Kit.THATCH))
		_:
			k.box(Vector3(ox, ytop, 0), Vector3(uw + 0.06, 0.04, ud + 0.06), Color(0.62, 0.50, 0.36), Kit.EARTH)
			_parapet(k, Vector3(ox, ytop + 0.04, 0), uw + 0.06, ud + 0.06, 0.05, 0.03, Color(0.62, 0.50, 0.36), Kit.EARTH)
			_pot(k, Vector3(ox + 0.15, ytop + 0.04, 0.0), 0.04)
	k.door(Vector3(ox + P.get("dx", -0.1), 0, bd / 2.0 + 0.006), 0.0, 0.12, 0.2, WOOD_DK)
	k.window(Vector3(ox + 0.18, sb * 0.6, bd / 2.0 + 0.006), 0.0, 0.05, 0.06, WOOD_DK, "frame")
	if P.get("stair", false):
		_stairs(k, Vector3(ox + bw / 2.0 + 0.1, 0, bd / 2.0 - 0.02), 0.0, 0.11, 5, (sb + 0.03) / 5.0, 0.07, stone, Kit.STONE)
	if P.get("corner", false):   # a stone tower at one corner
		var tx: float = ox - bw / 2.0 - 0.02
		k.plinth(Vector3(tx, 0, -bd / 2.0 + 0.04), 0.3, 0.3, 0.6, 0.03, stone.lightened(0.04), Kit.STONE)
		k.box(Vector3(tx, 0.6, -bd / 2.0 + 0.04), Vector3(0.28, 0.03, 0.28), WOOD_DK, Kit.TIMBER)
		_merlons(k, Vector3(tx, 0.63, -bd / 2.0 + 0.04), 0.28, 0.28, 0.05, 0.05, stone, Kit.STONE)
		_slot(k, Vector3(tx, 0.34, -bd / 2.0 + 0.04 + 0.15 - 0.02), 0.0, 0.03, 0.08, stone.lightened(0.2))
	if P.get("wood", true):
		for i in 3:
			k.rod(Vector3(0.38, 0.02 + i * 0.03, 0.34 + 0.0), Vector3(0.38, 0.02 + i * 0.03, 0.46), 0.014, WOOD, Kit.TIMBER)
			k.rod(Vector3(0.42, 0.02 + i * 0.03, 0.34 + 0.0), Vector3(0.42, 0.02 + i * 0.03, 0.46), 0.014, WOOD, Kit.TIMBER)
	_palm_or_tree(k, P, ox, bw)


## A tree beside a house: a leafy tree for upland styles.
static func _palm_or_tree(k: Kit, P: Dictionary, ox: float, bw: float) -> void:
	var t: String = P.get("tree", "tree")
	if t == "palm":
		_palm(k, Vector3(-0.42, 0, 0.4), 0.52, 6)
	elif t == "tree":
		_tree(k, Vector3(-0.4, 0, 0.36), 0.22, 0.13, Color(0.34, 0.5, 0.24))


## A domed house of the Persian/Turkic world: cubic body, a pishtaq (raised arched portal),
## domes of different sizes on drums, a wind-catcher, a slender tower. P: domes [[x, z, r, col]].
static func _domed(k: Kit, r: RandomNumberGenerator, P: Dictionary) -> void:
	var w: float = P.get("w", 0.8)
	var d: float = P.get("d", 0.6)
	var h: float = P.get("h", 0.4)
	var wall: Color = P.get("wall", WHITE)
	var trim: Color = P.get("trim", LIME)
	var mat: int = P.get("mat", Kit.PLASTER)
	var tile: Color = P.get("tile", TURQ)
	k.box(Vector3(0, 0, 0), Vector3(w + 0.06, 0.04, d + 0.06), STONE_GR, Kit.STONE)
	k.box(Vector3(0, 0.04, 0), Vector3(w, h, d), wall, mat)
	k.box(Vector3(0, 0.04 + h, 0), Vector3(w + 0.04, 0.03, d + 0.04), trim, mat)
	var top := 0.04 + h + 0.03
	var pw: float = P.get("pw", 0.3)
	var ph: float = P.get("ph", 0.16)
	var px: float = P.get("px", 0.0)
	k.box(Vector3(px, 0.04, d / 2.0 + 0.02), Vector3(pw, h + ph, 0.06), trim, mat)   # the pishtaq
	k.box(Vector3(px, 0.04 + h + ph, d / 2.0 + 0.02), Vector3(pw + 0.04, 0.03, 0.08), trim.lightened(0.04), mat)
	_arch(k, Vector3(px, 0.04, d / 2.0 + 0.052), 0.0, pw * 0.5, (h + ph) * 0.8, SHADE, true)
	_arch_door(k, Vector3(px, 0.04, d / 2.0 + 0.056), 0.0, pw * 0.34, h * 0.6, trim, P.get("door", BLUE), mat)
	k.box(Vector3(px, 0.04 + h + ph - 0.045, d / 2.0 + 0.056), Vector3(pw * 0.8, 0.03, 0.01), tile, Kit.PAINT)
	for s in [-1.0, 1.0]:   # arched windows either side of the portal
		var ax: float = px + s * (pw / 2.0 + 0.12)
		if absf(ax) < w / 2.0 - 0.06:
			_arch(k, Vector3(ax, 0.04 + h * 0.3, d / 2.0), 0.0, 0.07, 0.15)
	k.box(Vector3(0, 0.04 + h - 0.03, d / 2.0 + 0.004), Vector3(w, 0.022, 0.012), tile, Kit.PAINT)
	_parapet(k, Vector3(0, top, 0), w + 0.04, d + 0.04, 0.045, 0.028, trim, mat)
	for dm: Array in P.get("domes", [[-0.18, -0.04, 0.2, TURQ]]):
		var dc: Color = dm[3]
		k.frustum(Vector3(dm[0], top, dm[1]), dm[2] * 0.95, dm[2] * 0.95, 0.07, wall, mat, 12, false)
		k.dome(Vector3(dm[0], top + 0.07, dm[1]), dm[2], dc, Kit.PAINT if dc != wall else mat, 0.95, 4, 12, P.get("onion", false))
		k.cylinder(Vector3(dm[0], top + 0.07 + dm[2] * 0.92, dm[1]), 0.01, 0.07, GILD, Kit.GOLD, 4)
	if P.get("badgir", false):
		var bp: Vector2 = P.get("bat", Vector2(0.28, -0.14))
		_badgir(k, Vector3(bp.x, top, bp.y), 0.17, 0.36, wall, mat)
	if P.get("tower", false):   # a slender corner tower with a little cap
		var tp: Vector2 = P.get("tat", Vector2(0.4, -0.2))
		k.frustum(Vector3(tp.x, top, tp.y), 0.055, 0.045, 0.34, wall, mat, 8, false)
		k.box(Vector3(tp.x, top + 0.34, tp.y), Vector3(0.14, 0.025, 0.14), trim, mat)
		k.frustum(Vector3(tp.x, top + 0.365, tp.y), 0.06, 0.0, 0.1, tile, Kit.PAINT, 8, true)
	if P.get("pool", false):
		_pond(k, Vector3(0.0, 0, 0.44), 0.3, 0.1)
	_palm(k, Vector3(P.get("palm", -0.44), 0, 0.42), 0.5, 6)


static func _ne_rows() -> Dictionary:
	var rows := {
		"house_ne_court_1": {"fn": "court", "back": 0.42, "left": 0.34, "right": 0.28, "rback": "dome", "rleft": "flat",
			"rright": "flat", "court": "tree", "dome": TURQ},
		"house_ne_court_2": {"fn": "court", "back": 0.36, "left": 0.0, "right": 0.3, "rback": "flat", "rright": "dome",
			"court": "pool", "wall": MUD_LT, "trim": SAND, "mat": Kit.MUDBRICK, "dome": MUD_LT, "acol": TURQ,
			"badgir": true, "bx": -0.3, "door": RED, "ground": Color(0.80, 0.70, 0.52), "gate_tower": true},
		"house_ne_court_3": {"fn": "court", "back": 0.3, "up": 0.26, "upw": 0.54, "upx": 0.12, "left": 0.3, "right": 0.0,
			"rback": "flat", "rleft": "vault", "court": "well", "wall": OCHRE_WALL, "trim": MUD_LT, "mat": Kit.MUDBRICK,
			"acol": RED, "dome": OCHRE_WALL, "door": TURQ, "front": 0.26},
		"house_ne_court_4": {"fn": "court", "back": 0.26, "left": 0.26, "right": 0.26, "rback": "reed", "rleft": "reed",
			"rright": "reed", "court": "beds", "wall": ROSE, "trim": LIME, "mat": Kit.PLASTER, "acol": BLUE,
			"door": OCHRE, "archb": 3},
		"house_ne_flat_1": {"fn": "flat", "w": 0.8, "d": 0.62, "h": 0.46, "merlons": true, "malqaf": false,
			"badgir": true, "bat": Vector2(-0.22, -0.1), "bh": 0.4, "door": TURQ, "win": 3, "arched": true,
			"wall": MUD, "dx": 0.18, "band": TURQ, "stair": 0, "palms": 1, "domes": [[0.22, 0.0, 0.14, MUD_LT]], "pots": 0},
		"house_ne_flat_2": {"fn": "flat", "w": 0.74, "d": 0.62, "h": 0.36, "uh": 0.3, "uw": 0.5, "ud": 0.42,
			"uat": Vector2(0.06, -0.08), "batter": false, "mat": Kit.PLASTER, "wall": WHITE, "trim": LIME,
			"ucol": WHITE, "stair": 1, "domes": [[-0.2, 0.08, 0.1, TURQ]], "door": BLUE, "win": 3, "arched": true,
			"lattice": true, "palms": 1, "band": BLUE, "pots": 0},
		"house_ne_flat_3": {"fn": "flat", "w": 0.84, "d": 0.5, "h": 0.5, "batter": true, "wall": DUST, "trim": SAND,
			"merlons": true, "malqaf": true, "mq": Vector2(0.24, -0.08), "mh": 0.36, "shelter": "cloth",
			"sat": Vector2(-0.14, 0.0), "ssize": Vector2(0.3, 0.3), "sh": 0.15, "door": RED, "win": 2, "dx": -0.26,
			"beams": 5, "palms": 1, "arched": true},
		"house_ne_hittite_1": {"fn": "hittite", "roof": "flat", "stair": true, "bw": 0.68, "bd": 0.56, "sb": 0.26, "uh": 0.26},
		"house_ne_hittite_2": {"fn": "hittite", "roof": "gable", "bw": 0.62, "bd": 0.5, "sb": 0.2, "uh": 0.24, "rise": 0.3,
			"plaster": OCHRE_WALL, "stone": STONE_DK},
		"house_ne_hittite_3": {"fn": "hittite", "roof": "flat", "corner": true, "bw": 0.58, "bd": 0.5, "sb": 0.3, "uh": 0.22,
			"ox": 0.1, "plaster": SAND, "stone": STONE_LT, "stair": false, "tree": "none"},
		"house_ne_berber_1": {"fn": "kasbah", "n": 2, "towers": [[-0.3, -0.28, 0.74, 0.2]]},
		"house_ne_berber_2": {"fn": "kasbah", "n": 1, "bw": 0.5, "bd": 0.4, "bz": -0.14, "wall": true,
			"towers": [[-0.32, -0.3, 0.6, 0.2], [0.32, -0.3, 0.46, 0.18], [0.0, -0.4, 0.36, 0.16]],
			"col": Color(0.62, 0.42, 0.3), "light": Color(0.82, 0.68, 0.52)},
		"house_ne_berber_3": {"fn": "kasbah", "n": 3, "bw": 0.5, "bd": 0.44, "bz": -0.04,
			"towers": [[0.3, -0.22, 0.92, 0.18], [-0.3, 0.1, 0.5, 0.16]], "col": Color(0.74, 0.54, 0.38),
			"light": Color(0.9, 0.8, 0.62), "dx": 0.0, "palms": 2},
		"house_ne_domed_1": {"fn": "domed", "w": 0.8, "d": 0.56, "h": 0.4, "domes": [[-0.18, -0.04, 0.2, TURQ]],
			"badgir": true, "px": 0.18},
		"house_ne_domed_2": {"fn": "domed", "w": 0.88, "d": 0.5, "h": 0.34, "wall": SAND, "trim": WHITE,
			"mat": Kit.PLASTER, "domes": [[-0.28, -0.02, 0.13, SAND], [-0.02, -0.02, 0.15, WHITE], [0.26, -0.02, 0.13, SAND]],
			"pw": 0.26, "ph": 0.1, "px": 0.0, "tower": true, "tat": Vector2(0.38, -0.16), "tile": BLUE, "door": OCHRE},
		"house_ne_domed_3": {"fn": "domed", "w": 0.7, "d": 0.62, "h": 0.5, "wall": ROSE, "trim": LIME, "onion": true,
			"domes": [[0.0, -0.06, 0.24, BLUE]], "pw": 0.32, "ph": 0.12, "px": 0.0, "pool": true, "tile": GILD, "door": TURQ,
			"palm": 0.44},
	}
	return rows


# --- SOUTH ASIA archetypes ---------------------------------------------------------------------


## A round mud-walled hut with a thatched cone, in its own spot. Optional lean-to porch.
static func _round_hut(k: Kit, c: Vector3, rad: float, wh: float, ch: float, wall: Color, thatch: Color,
		porch: bool, band: Color, yaw := 0.0) -> void:
	k.cylinder(c, rad, wh, wall, Kit.EARTH, 12)
	if band.a > 0.0:
		k.cylinder(c + Vector3(0, wh * 0.55, 0), rad + 0.004, 0.035, band, Kit.PAINT, 12)
	k.frustum(c + Vector3(0, wh, 0), rad * 1.45, rad * 0.8, ch * 0.3, thatch, Kit.THATCH, 12, false)
	k.frustum(c + Vector3(0, wh + ch * 0.3, 0), rad * 0.8, 0.0, ch * 0.7, thatch.lightened(0.04), Kit.THATCH, 12, true)
	k.frustum(c + Vector3(0, wh + ch, 0), 0.02, 0.014, 0.06, WOOD, Kit.TIMBER, 5, true)
	k.box(c + Vector3(0, 0, rad - 0.01), Vector3(0.12, wh * 0.78, 0.03), SHADE, Kit.DARK)
	k.box(c + Vector3(0, wh * 0.78, rad - 0.005), Vector3(0.17, 0.03, 0.05), WOOD, Kit.TIMBER)
	if porch:
		_awning(k, c + Vector3(0, 0, rad + 0.12), rad * 1.3, 0.22, wh * 1.05, wh * 0.8, thatch, Kit.THATCH, true)
		k.box(c + Vector3(0, 0, rad + 0.1), Vector3(rad * 1.2, 0.04, 0.2), Color(0.72, 0.58, 0.4), Kit.EARTH)


## A hut compound: round, rectangular or twin huts with thatch, veranda, granary, fence, tree.
## P: form, x/z of the main hut, R (radius), band colour, granary, fence, tree, pen, cart, haystack.
static func _hut(k: Kit, r: RandomNumberGenerator, P: Dictionary) -> void:
	var wall: Color = P.get("wall", Color(0.66, 0.5, 0.34))
	var thatch: Color = P.get("thatch", REED)
	var band: Color = P.get("band", Color(0, 0, 0, 0))
	match str(P.get("form", "round")):
		"round":
			_round_hut(k, Vector3(P.get("x", -0.12), 0, P.get("z", -0.08)), P.get("R", 0.3), P.get("wh", 0.24),
				P.get("ch", 0.36), wall, thatch, P.get("porch", true), band)
		"twin":
			_round_hut(k, Vector3(-0.2, 0, -0.14), 0.26, 0.22, 0.32, wall, thatch, false, band)
			_round_hut(k, Vector3(0.26, 0, 0.0), 0.19, 0.18, 0.26, wall.lightened(0.06), thatch.darkened(0.06), true, band)
			k.box(Vector3(0.03, 0, -0.08), Vector3(0.12, 0.1, 0.04), wall.darkened(0.05), Kit.EARTH)
		"rect":
			var w: float = P.get("w", 0.6)
			var d: float = P.get("d", 0.44)
			var h: float = P.get("h", 0.24)
			var z: float = P.get("z", -0.12)
			k.box(Vector3(0, 0, z), Vector3(w, h, d), wall, Kit.EARTH)
			if band.a > 0.0:
				k.box(Vector3(0, h * 0.55, z + d / 2.0 + 0.003), Vector3(w, 0.03, 0.01), band, Kit.PAINT)
			k.gable_roof(Vector3(0, z * 0 + h, z), w, d, P.get("rise", 0.24), 0.1, 0.035, thatch, Kit.THATCH, wall, Kit.EARTH)
			k.box(Vector3(P.get("dx", -0.1), 0, z + d / 2.0 - 0.005), Vector3(0.13, h * 0.8, 0.03), SHADE, Kit.DARK)
			k.box(Vector3(0.14, h * 0.5, z + d / 2.0 - 0.005), Vector3(0.07, 0.07, 0.03), SHADE, Kit.DARK)
			if P.get("veranda", true):
				k.box(Vector3(0, 0, z + d / 2.0 + 0.1), Vector3(w * 0.9, 0.04, 0.2), Color(0.72, 0.58, 0.4), Kit.EARTH)
				for i in 4:
					var vx: float = -w * 0.4 + w * 0.8 * i / 3.0
					k.rod(Vector3(vx, 0.04, z + d / 2.0 + 0.18), Vector3(vx, h + 0.02, z + d / 2.0 + 0.18), 0.012, WOOD, Kit.TIMBER)
				k.rod(Vector3(-w * 0.4, h + 0.02, z + d / 2.0 + 0.18), Vector3(w * 0.4, h + 0.02, z + d / 2.0 + 0.18), 0.013, WOOD_DK, Kit.TIMBER)
				k.box(Vector3(0, h + 0.0, z + d / 2.0 + 0.1), Vector3(w * 0.9, 0.025, 0.2), thatch.darkened(0.1), Kit.THATCH)
	if P.get("shed", false):
		k.box(Vector3(0.36, 0, -0.26), Vector3(0.24, 0.18, 0.28), Color(0.72, 0.58, 0.42), Kit.EARTH)
		k.hip_roof(Vector3(0.36, 0.18, -0.26), 0.24, 0.28, 0.14, 0.05, 0.022, thatch, Kit.THATCH)
	if P.get("granary", true):
		var gx: float = P.get("gx", 0.38)
		for s in [-1.0, 1.0]:
			for t in [-1.0, 1.0]:
				k.rod(Vector3(gx + s * 0.05, 0, 0.3 + t * 0.05), Vector3(gx + s * 0.05, 0.1, 0.3 + t * 0.05), 0.01, WOOD, Kit.TIMBER)
		k.frustum(Vector3(gx, 0.1, 0.3), 0.08, 0.1, 0.15, Color(0.72, 0.55, 0.3), Kit.THATCH, 8, false)
		k.frustum(Vector3(gx, 0.25, 0.3), 0.11, 0.0, 0.1, thatch, Kit.THATCH, 8, true)
	if P.get("fence", true):
		for i in 7:
			var fz: float = -0.44 + i * 0.13
			k.rod(Vector3(-0.47, 0, fz), Vector3(-0.47, 0.1, fz), 0.01, WOOD, Kit.TIMBER)
		k.rod(Vector3(-0.47, 0.08, -0.44), Vector3(-0.47, 0.08, 0.34), 0.008, WOOD, Kit.TIMBER)
	if P.get("pen", false):
		_pen(k, Vector3(0.28, 0, 0.3), 0.34, 0.24)
	if P.get("hay", false):
		k.frustum(Vector3(-0.34, 0, 0.36), 0.1, 0.09, 0.1, REED.darkened(0.1), Kit.THATCH, 8, false)
		k.frustum(Vector3(-0.34, 0.1, 0.36), 0.09, 0.0, 0.1, REED, Kit.THATCH, 8, true)
	if P.get("tree", true):
		_tree(k, Vector3(P.get("tx", 0.4), 0, P.get("tz", -0.02)), 0.3, 0.16)
	_pot(k, Vector3(-0.3, 0, 0.3), 0.035)


## A tile-roofed house: gable or hip tiles, an optional second wing, a veranda on carved posts,
## an upper storey with a balcony. P: w/d/h, roof, wing [w, d, h, x, z], veranda, up, well, tree.
static func _tiled(k: Kit, r: RandomNumberGenerator, P: Dictionary) -> void:
	var w: float = P.get("w", 0.64)
	var d: float = P.get("d", 0.4)
	var h: float = P.get("h", 0.28)
	var z: float = P.get("z", -0.12)
	var wall: Color = P.get("wall", WHITE.darkened(0.02))
	var mat: int = P.get("mat", Kit.PLASTER)
	var clay: Color = P.get("clay", CLAY)
	var rise: float = P.get("rise", 0.2)
	k.box(Vector3(0, 0, z), Vector3(w + 0.04, 0.035, d + 0.04), STONE_GR, Kit.STONE)
	k.box(Vector3(0, 0.035, z), Vector3(w, h, d), wall, mat)
	var top := 0.035 + h
	var up: float = P.get("up", 0.0)
	if up > 0.0:
		k.box(Vector3(0, top, z), Vector3(w + 0.03, 0.025, d + 0.03), STONE_LT, Kit.STONE)
		k.box(Vector3(0, top + 0.025, z), Vector3(w * 0.88, up, d * 0.88), wall.lightened(0.03), mat)
		k.box(Vector3(P.get("bx", 0.1), top + 0.025 + up * 0.08, z + d * 0.44 + 0.05), Vector3(0.3, up * 0.5, 0.1), WOOD, Kit.TIMBER)
		k.box(Vector3(P.get("bx", 0.1), top + 0.025 + up * 0.08 + up * 0.5, z + d * 0.44 + 0.05), Vector3(0.34, 0.02, 0.13), WOOD_DK, Kit.TIMBER)
		k.box(Vector3(P.get("bx", 0.1), top + 0.025 + up * 0.2, z + d * 0.44 + 0.101), Vector3(0.22, up * 0.25, 0.012), SHADE, Kit.DARK)
		_arch(k, Vector3(-0.2, top + 0.025 + up * 0.12, z + d * 0.44), 0.0, 0.07, up * 0.55)
		top += 0.025 + up
	var roof: String = P.get("roof", "gable")
	if roof == "hip":
		k.hip_roof(Vector3(0, top, z), w * (0.88 if up > 0 else 1.0), d * (0.88 if up > 0 else 1.0), rise, 0.07, 0.03, clay, Kit.OWNER_ROOF, 0.0, 0.02)
	else:
		k.gable_roof(Vector3(0, top, z), w * (0.88 if up > 0 else 1.0), d * (0.88 if up > 0 else 1.0), rise, 0.07, 0.03, clay, Kit.OWNER_ROOF, wall, mat)
	var fz := z + d / 2.0
	_arch_door(k, Vector3(P.get("dx", -0.12), 0.035, fz), 0.0, 0.13, 0.22, STONE_LT, P.get("door", OCHRE), Kit.STONE)
	for wx in P.get("wins", [0.14, 0.26]):
		_arch(k, Vector3(wx, 0.07, fz + 0.002), 0.0, 0.06, 0.12)
	if P.has("wing"):
		var wg: Array = P["wing"]
		k.box(Vector3(wg[3], 0.035, wg[4]), Vector3(wg[0], wg[2], wg[1]), wall.darkened(0.03), mat)
		k.gable_roof(Vector3(wg[3], 0.035 + wg[2], wg[4]), wg[1], wg[0], rise * 0.8, 0.06, 0.028, clay.darkened(0.05), Kit.OWNER_ROOF, wall, mat, PI / 2.0)
		_arch(k, Vector3(wg[3] - wg[0] / 2.0 * 0.0, 0.07, wg[4] + wg[1] / 2.0 + 0.002), 0.0, 0.06, 0.12)
	if P.get("veranda", 5) > 0:
		var n: int = P.get("veranda", 5)
		var vw := w * 0.9
		k.box(Vector3(0, 0.035, fz + 0.1), Vector3(vw + 0.02, 0.04, 0.2), Color(0.78, 0.7, 0.56), Kit.STONE)
		for i in n:
			var px: float = -vw / 2.0 + vw * i / maxf(n - 1, 1)
			k.frustum(Vector3(px, 0.075, fz + 0.18), 0.016, 0.013, h * 0.84, WOOD, Kit.TIMBER, 5, false)
		k.box(Vector3(0, 0.075 + h * 0.84, fz + 0.18), Vector3(vw, 0.03, 0.045), WOOD_DK, Kit.TIMBER)
		k.hip_roof(Vector3(0, 0.075 + h * 0.84, fz + 0.1), vw, 0.2, 0.07, 0.04, 0.022, clay.lightened(0.05), Kit.OWNER_ROOF, 0.0, 0.02)
	if P.get("well", false):
		k.cylinder(Vector3(0.38, 0, 0.36), 0.06, 0.07, STONE_GR, Kit.STONE, 8)
		k.box(Vector3(0.38, 0.07, 0.36), Vector3(0.09, 0.004, 0.09), SHADE, Kit.DARK)
	for i in int(P.get("trees", 1)):
		_tree(k, Vector3(-0.4 + i * 0.8, 0, 0.36 + 0.04 * i), 0.3, 0.15)
	if P.get("palm", false):
		_palm(k, Vector3(0.42, 0, 0.3), 0.52, 6)


## A haveli: brick and plaster storeys, jharokha balconies, arched window rows, a cornice and a
## crown of chhatris / a bangla roof / a dome. P: floors, w, d, brick (base colour), roof.
static func _haveli(k: Kit, r: RandomNumberGenerator, P: Dictionary) -> void:
	var w: float = P.get("w", 0.78)
	var d: float = P.get("d", 0.6)
	var n: int = P.get("floors", 2)
	var fh: float = P.get("fh", 0.28)
	var base: Color = P.get("brick", BRICKR)
	var plaster: Color = P.get("plaster", WHITE)
	var accent: Color = P.get("accent", OCHRE)
	var bmat: int = P.get("bmat", Kit.BRICK)
	k.box(Vector3(0, 0, 0), Vector3(w + 0.08, 0.04, d + 0.08), STONE_GR, Kit.STONE)
	var y := 0.04
	for i in n:
		var col: Color = base if i == 0 else plaster
		var mat: int = bmat if i == 0 else Kit.PLASTER
		var ww: float = w - i * float(P.get("taper", 0.0))
		k.box(Vector3(0, y, 0), Vector3(ww, fh, d), col, mat)
		k.box(Vector3(0, y + fh, 0), Vector3(ww + 0.04, 0.03, d + 0.04), STONE_LT, Kit.STONE)
		var zf := d / 2.0
		if i == 0:
			_arch_door(k, Vector3(P.get("dx", -0.18), y, zf), 0.0, 0.15, 0.24, STONE_LT, accent, Kit.STONE)
			for ax in [0.08, 0.28]:
				if absf(ax) < ww / 2.0 - 0.06:
					_arch(k, Vector3(ax, y + 0.08, zf + 0.002), 0.0, 0.07, 0.14)
		else:
			for wi in 3:
				var ax2: float = -ww * 0.34 + ww * 0.34 * wi
				if i == 1 and P.get("jharokha", 1) > 0 and wi == 1:
					_jharokha(k, Vector3(ax2 + 0.02, y + 0.03, zf - 0.03), 0.0, 0.26, fh * 0.7)
				else:
					_arch(k, Vector3(ax2, y + 0.08, zf + 0.002), 0.0, 0.07, 0.15)
					k.box(Vector3(ax2, y + 0.06, zf + 0.02), Vector3(0.12, 0.015, 0.05), WOOD, Kit.TIMBER)
		k.box(Vector3(0, y + fh - 0.045, zf + 0.004), Vector3(ww, 0.02, 0.012), accent, Kit.PAINT)
		y += fh + 0.03
	var top := y
	var ww2: float = w - (n - 1) * float(P.get("taper", 0.0))
	_parapet(k, Vector3(0, top, 0), ww2 + 0.04, d + 0.04, 0.05, 0.03, plaster, Kit.PLASTER)
	match str(P.get("roof", "chhatri")):
		"chhatri":
			for sx in [-1.0, 1.0]:
				_chhatri(k, Vector3(sx * (ww2 / 2.0 - 0.1), top, d / 2.0 - 0.1), 0.16, 0.13, plaster, plaster)
			_chhatri(k, Vector3(0, top, -0.12), 0.2, 0.16, plaster, P.get("dome", TURQ))
		"bangla":
			_bangla(k, Vector3(0, top, 0), ww2 * 0.92, d * 0.9, 0.3, P.get("clay", Color(0.7, 0.4, 0.28)))
		"dome":
			k.frustum(Vector3(0, top, 0), 0.2, 0.2, 0.07, plaster, Kit.PLASTER, 12, false)
			k.dome(Vector3(0, top + 0.07, 0), 0.2, P.get("dome", TURQ), Kit.PAINT, 0.95, 4, 12, true)
			_chhatri(k, Vector3(ww2 / 2.0 - 0.1, top, d / 2.0 - 0.1), 0.14, 0.12, plaster, plaster)
			_chhatri(k, Vector3(-ww2 / 2.0 + 0.1, top, d / 2.0 - 0.1), 0.14, 0.12, plaster, plaster)
		"tile":
			k.gable_roof(Vector3(0, top, 0), ww2 * 0.9, d * 0.86, 0.2, 0.06, 0.03, P.get("clay", CLAY), Kit.OWNER_ROOF, plaster, Kit.PLASTER)
	if P.get("court", false):   # a walled yard in front
		for s in [-1.0, 1.0]:
			k.box(Vector3(s * 0.3, 0, 0.48), Vector3(0.34, 0.1, 0.04), plaster, Kit.PLASTER)
		_gatepiers(k, Vector3(0, 0, 0.48), 0.2, 0.16, STONE_LT, Kit.STONE)
	_palm(k, Vector3(-0.44, 0, 0.4), 0.55, 6)
	_pot(k, Vector3(0.42, 0, 0.36), 0.035)


## A merchant house: an arcade of pillars and arches along the shopfront (cloth awning, sacks,
## goods), an upper floor with a balcony, and a tiled or flat roof.
static func _merchant(k: Kit, r: RandomNumberGenerator, P: Dictionary) -> void:
	var w: float = P.get("w", 0.86)
	var d: float = P.get("d", 0.62)
	var h: float = P.get("h", 0.26)
	var uh: float = P.get("uh", 0.26)
	var n: int = P.get("arches", 4)
	var wall: Color = P.get("wall", ROSE)
	var upper: Color = P.get("upper", WHITE)
	var z0: float = P.get("z", -0.1)
	k.box(Vector3(0, 0, z0), Vector3(w + 0.04, 0.035, d + 0.04), STONE_GR, Kit.STONE)
	k.box(Vector3(0, 0.035, z0), Vector3(w, h, d), wall, Kit.PLASTER)
	var front := z0 + d / 2.0
	# the arcade: a recessed dark bay between pillars
	k.box(Vector3(0, 0.035, front - 0.01), Vector3(w * 0.94, h * 0.78, 0.03), SHADE, Kit.DARK)
	for i in n + 1:
		var px: float = -w * 0.47 + w * 0.94 * i / n
		k.box(Vector3(px, 0.035, front + 0.03), Vector3(0.05, h * 0.82, 0.07), STONE_LT, Kit.STONE)
	k.box(Vector3(0, 0.035 + h * 0.8, front + 0.03), Vector3(w * 0.98, h * 0.2, 0.08), wall.lightened(0.04), Kit.PLASTER)
	for i in n:   # little arches between the pillars
		var ax: float = -w * 0.47 + w * 0.94 * (i + 0.5) / n
		k.dome(Vector3(ax, 0.035 + h * 0.62, front + 0.05), w * 0.94 / n * 0.32, SHADE, Kit.DARK, 0.45, 2, 6)
	if P.get("awning", true):
		_awning(k, Vector3(0, 0, front + 0.14), w * 0.7, 0.18, 0.035 + h * 0.8, 0.035 + h * 0.5, Color.WHITE, Kit.OWNER_CLOTH, true)
	for i in int(P.get("sacks", 2)):
		var sx: float = -w * 0.25 + i * 0.3 + r.randf_range(-0.04, 0.04)
		k.dome(Vector3(sx, 0.035, front + 0.1), 0.045, Color(0.8, 0.7, 0.5), Kit.CLOTH, 0.8, 2, 6)
	k.box(Vector3(0, 0.035 + h, z0), Vector3(w + 0.03, 0.03, d + 0.03), STONE_LT, Kit.STONE)
	var y := 0.035 + h + 0.03
	k.box(Vector3(0, y, z0 - 0.04), Vector3(w * 0.94, uh, d * 0.84), upper, Kit.PLASTER)
	var uf := z0 - 0.04 + d * 0.42
	for i in 3:
		var wx: float = -w * 0.3 + w * 0.3 * i
		_arch(k, Vector3(wx, y + 0.05, uf + 0.002), 0.0, 0.07, 0.15)
	if P.get("balcony", true):
		k.box(Vector3(0, y, uf + 0.05), Vector3(w * 0.7, 0.025, 0.1), WOOD, Kit.TIMBER)
		_railing(k, Vector3(0, y + 0.025, uf + 0.05), w * 0.7, 0.1, 0.07, WOOD_DK)
	k.box(Vector3(0, y + uh * 0.85, uf + 0.004), Vector3(w * 0.94, 0.02, 0.012), P.get("accent", TURQ), Kit.PAINT)
	var top := y + uh
	match str(P.get("roof", "tile")):
		"flat":
			k.box(Vector3(0, top, z0 - 0.04), Vector3(w * 0.98, 0.03, d * 0.88), STONE_LT, Kit.STONE)
			_parapet(k, Vector3(0, top + 0.03, z0 - 0.04), w * 0.98, d * 0.88, 0.05, 0.03, upper, Kit.PLASTER)
			_chhatri(k, Vector3(w * 0.28, top + 0.03, z0 - 0.04), 0.18, 0.14, upper, P.get("dome", WHITE))
			_roof_shelter(k, Vector3(-w * 0.2, top + 0.03, z0 - 0.04), 0.26, 0.26, 0.14, "mat")
		"hip":
			k.hip_roof(Vector3(0, top, z0 - 0.04), w * 0.94, d * 0.84, 0.2, 0.07, 0.03, P.get("clay", CLAY), Kit.OWNER_ROOF, 0.0, 0.02)
		_:
			k.gable_roof(Vector3(0, top, z0 - 0.04), w * 0.94, d * 0.84, 0.2, 0.07, 0.03, P.get("clay", CLAY), Kit.OWNER_ROOF, upper, Kit.PLASTER)
	_pot(k, Vector3(w / 2.0 - 0.04, 0, front + 0.14), 0.04)
	if P.get("tree", true):
		_tree(k, Vector3(-0.44, 0, 0.42), 0.26, 0.14)


static func _ind_rows() -> Dictionary:
	return {
		"house_ind_hut_1": {"fn": "hut", "form": "round", "R": 0.3, "porch": true, "shed": true},
		"house_ind_hut_2": {"fn": "hut", "form": "rect", "w": 0.6, "d": 0.4, "band": RED, "wall": Color(0.74, 0.6, 0.42),
			"thatch": REED.darkened(0.08), "pen": true, "granary": false, "tx": -0.34, "tz": 0.3},
		"house_ind_hut_3": {"fn": "hut", "form": "twin", "granary": true, "hay": true, "tree": true, "tx": -0.36, "tz": 0.3,
			"band": SAFFRON, "wall": Color(0.7, 0.54, 0.38)},
		"house_ind_hut_4": {"fn": "hut", "form": "round", "R": 0.24, "wh": 0.2, "ch": 0.4, "x": 0.0, "z": -0.1, "wall": Color(0.76, 0.6, 0.42),
			"thatch": REED.lightened(0.06), "band": TURQ, "porch": false, "granary": false, "hay": true, "fence": false,
			"tx": 0.38, "tz": 0.1},
		"house_ind_tile_1": {"fn": "tiled", "w": 0.66, "d": 0.4, "h": 0.28, "roof": "gable", "veranda": 5, "well": true, "trees": 1},
		"house_ind_tile_2": {"fn": "tiled", "w": 0.5, "d": 0.36, "h": 0.26, "z": -0.18, "roof": "hip", "wing": [0.4, 0.3, 0.24, 0.3, 0.1],
			"veranda": 0, "wall": OCHRE_WALL, "mat": Kit.MUDBRICK, "clay": Color(0.62, 0.34, 0.22), "dx": -0.05, "wins": [0.12],
			"trees": 1, "palm": true},
		"house_ind_tile_3": {"fn": "tiled", "w": 0.6, "d": 0.4, "h": 0.24, "up": 0.24, "z": -0.12, "roof": "gable", "veranda": 4,
			"wall": WHITE, "door": TURQ, "trees": 1, "well": true},
		"house_ind_tile_4": {"fn": "tiled", "w": 0.7, "d": 0.34, "h": 0.22, "z": -0.18, "roof": "gable", "rise": 0.26, "veranda": 6,
			"wall": ROSE, "clay": Color(0.5, 0.3, 0.22), "door": BLUE, "wins": [0.12, 0.24], "trees": 2},
		"house_ind_haveli_1": {"fn": "haveli", "floors": 2, "roof": "chhatri"},
		"house_ind_haveli_2": {"fn": "haveli", "floors": 3, "fh": 0.22, "w": 0.66, "d": 0.54, "roof": "dome", "plaster": SAND,
			"brick": Color(0.62, 0.34, 0.24), "accent": TURQ, "taper": 0.04, "court": true},
		"house_ind_haveli_3": {"fn": "haveli", "floors": 2, "w": 0.7, "d": 0.62, "roof": "bangla", "plaster": ROSE, "accent": BLUE,
			"brick": STONE_LT, "bmat": Kit.STONE, "jharokha": 1, "dx": 0.18},
		"house_ind_haveli_4": {"fn": "haveli", "floors": 3, "fh": 0.2, "w": 0.6, "d": 0.5, "roof": "tile", "plaster": LIME,
			"brick": BRICKR.darkened(0.1), "accent": GREEN.lightened(0.1), "clay": Color(0.56, 0.3, 0.22), "court": true},
		"house_ind_merchant_1": {"fn": "merchant", "roof": "tile", "arches": 4},
		"house_ind_merchant_2": {"fn": "merchant", "w": 0.78, "arches": 3, "wall": OCHRE_WALL, "upper": LIME, "roof": "flat",
			"accent": RED, "dome": TURQ, "uh": 0.3, "sacks": 3},
		"house_ind_merchant_3": {"fn": "merchant", "w": 0.9, "d": 0.52, "arches": 5, "wall": STONE_LT, "upper": ROSE, "roof": "hip",
			"accent": BLUE, "balcony": false, "awning": true, "clay": Color(0.58, 0.32, 0.22), "uh": 0.22, "tree": false},
	}


# --- regional props (low poly, under 200 triangles each; 1.0 = a house width) -------------------


static func _prop(k: Kit, kind: String) -> void:
	match kind:
		"prop_mud_wall":
			# a low mudbrick yard wall exactly 1.0 long, plastered coping, tiles end to end
			k.box(Vector3.ZERO, Vector3(1.0, 0.13, 0.055), MUD, Kit.MUDBRICK)
			k.box(Vector3(0, 0.13, 0), Vector3(1.0, 0.025, 0.07), MUD_LT, Kit.PLASTER)
			for x in [-0.5, 0.5]:   # a slight buttress at the joins reads as brick courses
				k.box(Vector3(x * 0.96, 0, 0), Vector3(0.02, 0.15, 0.065), MUD.darkened(0.08), Kit.MUDBRICK)
			k.box(Vector3(0, 0.05, 0.029), Vector3(1.0, 0.012, 0.004), MUD.darkened(0.18), Kit.MUDBRICK)
		"prop_shaduf":
			# well-sweep: two mud pillars, a pole with a bucket and a clay counterweight, a basin
			for s in [-1.0, 1.0]:
				k.plinth(Vector3(s * 0.05, 0, 0), 0.06, 0.06, 0.26, 0.012, MUD, Kit.MUDBRICK)
			k.rod(Vector3(-0.05, 0.25, 0), Vector3(0.05, 0.25, 0), 0.01, WOOD_DK, Kit.TIMBER)
			k.rod(Vector3(0, 0.25, -0.2), Vector3(0, 0.3, 0.16), 0.012, WOOD, Kit.TIMBER)
			k.dome(Vector3(0, 0.29, -0.2), 0.04, MUD_LT, Kit.MUDBRICK, 1.0, 3, 8)
			k.rod(Vector3(0, 0.3, 0.16), Vector3(0, 0.15, 0.16), 0.004, WOOD_DK, Kit.TIMBER)
			k.frustum(Vector3(0, 0.08, 0.16), 0.03, 0.04, 0.07, Color(0.5, 0.32, 0.2), Kit.EARTH, 6, false)
			k.box(Vector3(0, 0, 0.12), Vector3(0.22, 0.04, 0.16), MUD, Kit.MUDBRICK)
			k.box(Vector3(0, 0.03, 0.12), Vector3(0.18, 0.015, 0.12), WATER_BLUE, Kit.WATER)
		"prop_water_jars":
			# big clay jars: three in a ring stand, one tilted rack jar with a lid
			for i in 3:
				var a := i * TAU / 3.0 + 0.4
				var p := Vector3(cos(a) * 0.065, 0, sin(a) * 0.065)
				k.frustum(p, 0.035, 0.06, 0.1, Color(0.62, 0.36, 0.22), Kit.EARTH, 7, false)
				k.frustum(p + Vector3(0, 0.1, 0), 0.06, 0.03, 0.06, Color(0.58, 0.32, 0.2), Kit.EARTH, 7, false)
				k.frustum(p + Vector3(0, 0.16, 0), 0.033, 0.036, 0.015, Color(0.5, 0.28, 0.18), Kit.EARTH, 7, true)
			k.box(Vector3(0, 0, 0), Vector3(0.2, 0.012, 0.2), MUD_LT, Kit.MUDBRICK)
			_pot(k, Vector3(0.17, 0, 0.0), 0.04)
		"prop_reed_boat":
			# a papyrus skiff: bundled reeds that curve up fore and aft, a cross-thwart and a pole
			var secs := 7
			for i in secs:
				var t0 := float(i) / secs * 2.0 - 1.0
				var t1 := float(i + 1) / secs * 2.0 - 1.0
				var y0 := 0.02 + 0.07 * t0 * t0 * t0 * t0 * 2.0
				var y1 := 0.02 + 0.07 * t1 * t1 * t1 * t1 * 2.0
				var w0 := 0.07 * (1.0 - 0.7 * absf(t0) * absf(t0))
				var w1 := 0.07 * (1.0 - 0.7 * absf(t1) * absf(t1))
				var z0 := t0 * 0.22
				var z1 := t1 * 0.22
				var c := Vector3(0, 0.05, (z0 + z1) / 2.0)
				for s in [-1.0, 1.0]:
					k.quad(Vector3(s * w0, y0 + 0.035, z0), Vector3(s * w1, y1 + 0.035, z1), Vector3(s * w1 * 0.6, y1, z1), Vector3(s * w0 * 0.6, y0, z0), REED, Kit.THATCH, c)
				k.quad(Vector3(-w0 * 0.6, y0, z0), Vector3(w0 * 0.6, y0, z0), Vector3(w1 * 0.6, y1, z1), Vector3(-w1 * 0.6, y1, z1), REED.darkened(0.2), Kit.THATCH, c)
				k.quad(Vector3(-w0, y0 + 0.035, z0), Vector3(w0, y0 + 0.035, z0), Vector3(w1, y1 + 0.035, z1), Vector3(-w1, y1 + 0.035, z1), REED.lightened(0.05), Kit.THATCH, Vector3(0, -1, (z0 + z1) / 2.0))
			k.box(Vector3(0, 0.05, 0.0), Vector3(0.13, 0.015, 0.025), WOOD, Kit.TIMBER)
			k.rod(Vector3(0.04, 0.05, -0.1), Vector3(0.1, 0.22, 0.1), 0.006, WOOD_DK, Kit.TIMBER)
		"prop_rugs":
			# a market carpet spread: layered woven rugs, a folded stack and a hanging rug on a pole
			k.box(Vector3(-0.04, 0, 0.0), Vector3(0.3, 0.008, 0.2), RED, Kit.CLOTH)
			k.box(Vector3(-0.04, 0.008, 0.0), Vector3(0.24, 0.004, 0.14), OCHRE, Kit.CLOTH)
			k.box(Vector3(-0.04, 0.012, 0.0), Vector3(0.14, 0.004, 0.08), BLUE, Kit.CLOTH)
			k.box(Vector3(0.1, 0.008, 0.14), Vector3(0.2, 0.008, 0.12), TURQ, Kit.CLOTH)
			k.box(Vector3(0.1, 0.016, 0.14), Vector3(0.14, 0.004, 0.08), SAFFRON, Kit.CLOTH)
			for i in 4:
				k.box(Vector3(-0.18, i * 0.014, -0.14), Vector3(0.14 - i * 0.008, 0.014, 0.1), [RED, BLUE, OCHRE, DEEPRED][i], Kit.CLOTH)
			for s in [-1.0, 1.0]:
				k.rod(Vector3(0.18 + s * 0.09, 0, -0.12), Vector3(0.18 + s * 0.09, 0.2, -0.12), 0.007, WOOD, Kit.TIMBER)
			k.rod(Vector3(0.09, 0.2, -0.12), Vector3(0.27, 0.2, -0.12), 0.007, WOOD, Kit.TIMBER)
			k.box(Vector3(0.18, 0.05, -0.12), Vector3(0.15, 0.15, 0.008), TEAL_RUG, Kit.CLOTH)
			k.box(Vector3(0.18, 0.09, -0.115), Vector3(0.1, 0.05, 0.004), SAFFRON, Kit.CLOTH)
		"prop_dovecote":
			# a round mud dovecote tower: pigeon holes in rings, a conical cap, perch ledges
			k.frustum(Vector3.ZERO, 0.11, 0.085, 0.34, WHITE, Kit.MUDBRICK, 10, false)
			for row in 2:
				for i in 5:
					var a := i * TAU / 5.0 + row * 0.6
					var rr := 0.11 - (0.34 * (0.1 + row * 0.1) / 0.34) * 0.075 - 0.0
					var yy := 0.17 + row * 0.07
					var rad := lerpf(0.11, 0.085, yy / 0.34)
					k.box(Vector3(cos(a) * rad, yy, sin(a) * rad), Vector3(0.022, 0.022, 0.022), SHADE, Kit.DARK, -a + PI / 2.0)
			k.cylinder(Vector3(0, 0.34, 0), 0.105, 0.03, MUD_LT, Kit.MUDBRICK, 10)
			k.frustum(Vector3(0, 0.37, 0), 0.1, 0.0, 0.14, MUD, Kit.MUDBRICK, 10, true)
			k.box(Vector3(0.0, 0, 0.1), Vector3(0.05, 0.08, 0.012), SHADE, Kit.DARK)
		"prop_shrine_india":
			# a small stone shrine: stepped platform, a shikhara-topped cella, a lamp and a flag
			k.plinth(Vector3.ZERO, 0.3, 0.3, 0.05, 0.02, STONE_LT, Kit.STONE)
			k.box(Vector3(0, 0.05, 0), Vector3(0.18, 0.12, 0.18), SAFFRON.darkened(0.1), Kit.PLASTER)
			k.box(Vector3(0, 0.05, 0.09), Vector3(0.06, 0.09, 0.012), SHADE, Kit.DARK)
			k.plinth(Vector3(0, 0.17, 0), 0.2, 0.2, 0.09, 0.04, STONE_LT, Kit.STONE)
			k.plinth(Vector3(0, 0.26, 0), 0.12, 0.12, 0.09, 0.03, STONE_LT.lightened(0.04), Kit.STONE)
			k.dome(Vector3(0, 0.35, 0), 0.04, GILD, Kit.GOLD, 0.8, 2, 8)
			k.rod(Vector3(0, 0.38, 0), Vector3(0, 0.46, 0), 0.004, GILD, Kit.GOLD)
			k.banner(Vector3(0.12, 0.05, 0.1), 0.26, 0.09)
			k.box(Vector3(-0.1, 0.05, 0.12), Vector3(0.04, 0.025, 0.04), STONE_GR, Kit.STONE)
			k.dome(Vector3(-0.1, 0.075, 0.12), 0.015, SAFFRON, Kit.OWNER_CLOTH if false else Kit.PAINT, 1.0, 2, 6)
		"prop_bullock_cart":
			# a two-wheeled village cart with a thatched hood and a yoke ending in a pair of oxen
			for s in [-1.0, 1.0]:
				k.push(Kit.at(Vector3(s * 0.14, 0.09, 0.0), PI / 2.0))
				k.cylinder(Vector3(0, -0.013, 0), 0.09, 0.026, WOOD_DK, Kit.TIMBER, 6)
				k.pop()
			k.box(Vector3(0, 0.1, 0.0), Vector3(0.26, 0.025, 0.4), WOOD, Kit.TIMBER)
			k.gable_roof(Vector3(0, 0.2, -0.06), 0.26, 0.26, 0.08, 0.03, 0.02, REED, Kit.THATCH, REED, Kit.THATCH, PI / 2.0)
			for s in [-1.0, 1.0]:
				k.rod(Vector3(s * 0.12, 0.125, -0.17), Vector3(s * 0.12, 0.2, -0.17), 0.007, WOOD, Kit.TIMBER)
			k.rod(Vector3(0, 0.11, 0.2), Vector3(0, 0.1, 0.46), 0.01, WOOD, Kit.TIMBER)
			for s in [-1.0, 1.0]:
				var ox: float = s * 0.07
				k.box(Vector3(ox, 0.07, 0.5), Vector3(0.08, 0.1, 0.22), Color(0.9, 0.86, 0.78), Kit.CLOTH)
				k.box(Vector3(ox, 0.1, 0.4), Vector3(0.05, 0.05, 0.04), Color(0.82, 0.78, 0.68), Kit.CLOTH)
				k.box(Vector3(ox, 0, 0.5), Vector3(0.06, 0.07, 0.18), Color(0.7, 0.66, 0.58), Kit.CLOTH)
			k.rod(Vector3(-0.07, 0.17, 0.5), Vector3(0.07, 0.17, 0.5), 0.007, WOOD_DK, Kit.TIMBER)
		"prop_tree_platform":
			# a sacred fig on a round stone platform, with votive stones and a cloth tied round it
			k.frustum(Vector3.ZERO, 0.24, 0.22, 0.05, STONE_LT, Kit.STONE, 12, false)
			k.frustum(Vector3(0, 0.05, 0), 0.19, 0.18, 0.04, STONE_LT.lightened(0.04), Kit.STONE, 12, true)
			k.frustum(Vector3(0, 0.09, 0), 0.03, 0.022, 0.3, WOOD, Kit.TIMBER, 6, false)
			k.frustum(Vector3(0, 0.2, 0), 0.034, 0.034, 0.025, SAFFRON, Kit.CLOTH, 6, false)
			k.dome(Vector3(0.0, 0.34, 0.0), 0.24, GREEN, Kit.LEAF, 0.6, 3, 9)
			k.dome(Vector3(-0.1, 0.3, 0.06), 0.14, GREEN.darkened(0.1), Kit.LEAF, 0.7, 2, 8)
			for i in 2:
				var a := 0.6 + i * 1.1
				k.box(Vector3(cos(a) * 0.12, 0.09, sin(a) * 0.12), Vector3(0.03, 0.04 + 0.01 * i, 0.02), STONE_GR, Kit.STONE, a)
			k.box(Vector3(0.0, 0.09, 0.14), Vector3(0.04, 0.012, 0.02), SAFFRON, Kit.PAINT)


const TEAL_RUG := Color(0.1, 0.4, 0.45)


## Two-lot kinds, all 2.0 wide by 1.0 deep (x -1..1, z -0.5..0.5): rows, compounds, havelis, farms.
static func _big_rows() -> Dictionary:
	var wall_r := {"t": "wall", "size": Vector3(0.04, 0.12, 1.0), "at": Vector2(0.98, 0.0)}
	return {
		"big_nile_row": {"fn": "multi", "parts": [
			{"fn": "flat", "at": Vector2(-0.67, 0.0), "w": 0.62, "d": 0.8, "h": 0.34, "win": 1, "palms": 0, "pots": 1,
				"shelter": "reed", "sat": Vector2(0.0, 0.0), "ssize": Vector2(0.3, 0.3), "sh": 0.14, "door": BLUE, "dx": 0.0},
			{"fn": "flat", "at": Vector2(0.0, 0.0), "w": 0.72, "d": 0.8, "h": 0.4, "uh": 0.26, "uw": 0.44, "ud": 0.44,
				"uat": Vector2(0.0, -0.1), "win": 1, "palms": 0, "pots": 0, "band": RED, "uband": BLUE, "wall": LIME, "trim": WHITE,
				"ucol": WHITE, "door": RED, "dx": 0.0, "malqaf": true, "mq": Vector2(0.2, 0.1), "high": false, "beams": 4},
			{"fn": "flat", "at": Vector2(0.67, 0.0), "w": 0.62, "d": 0.8, "h": 0.28, "win": 1, "palms": 0, "pots": 1,
				"shelter": "mat", "sat": Vector2(0.0, 0.0), "ssize": Vector2(0.28, 0.3), "sh": 0.12, "door": OCHRE, "dx": 0.0, "beams": 3,
				"wall": MUD.darkened(0.06)}],
			"extras": [{"t": "palm", "at": Vector2(0.9, 0.46), "h": 0.5}]},
		"big_nile_villa": {"fn": "multi", "parts": [
			{"fn": "flat", "at": Vector2(-0.5, 0.0), "w": 0.8, "d": 0.4, "h": 0.36, "uh": 0.22, "uw": 0.4, "ud": 0.3,
				"uat": Vector2(0.14, -0.02), "yard": 1, "porch": 4, "wall": LIME, "trim": WHITE, "ucol": WHITE, "band": RED,
				"win": 0, "door": BLUE, "dx": 0.0, "dh": 0.22, "pond": false, "trees": 1, "palms": 1, "ycol": WHITE,
				"ymat": Kit.PLASTER, "pots": 0, "pcol": RED, "pmat": Kit.PAINT, "ywh": 0.14}],
			"extras": [wall_r,
				{"t": "wall", "size": Vector3(1.0, 0.14, 0.04), "at": Vector2(0.5, -0.48), "col": WHITE, "mat": Kit.PLASTER},
				{"t": "wall", "size": Vector3(0.36, 0.14, 0.04), "at": Vector2(0.82, 0.48), "col": WHITE, "mat": Kit.PLASTER},
				{"t": "wall", "size": Vector3(0.3, 0.14, 0.04), "at": Vector2(0.15, 0.48), "col": WHITE, "mat": Kit.PLASTER},
				{"t": "pond", "at": Vector2(0.5, 0.0), "w": 0.4, "d": 0.26},
				{"t": "palm", "at": Vector2(0.2, -0.3), "h": 0.6}, {"t": "palm", "at": Vector2(0.8, -0.3), "h": 0.55, "fronds": 6},
				{"t": "tree", "at": Vector2(0.78, 0.26), "h": 0.22, "r": 0.12}, {"t": "tree", "at": Vector2(0.25, 0.28), "h": 0.2, "r": 0.11},
				{"t": "beds", "at": Vector2(0.5, 0.3), "w": 0.2, "d": 0.2, "n": 3}]},
		"big_nile_farm": {"fn": "multi", "parts": [
			{"fn": "flat", "at": Vector2(-0.5, 0.0), "w": 0.56, "d": 0.38, "h": 0.32, "yard": 1, "gran": 2, "palms": 1, "pen": false,
				"stair": 1, "shelter": "reed", "sat": Vector2(-0.05, 0.0), "ssize": Vector2(0.24, 0.24), "sh": 0.13, "win": 1,
				"door": OCHRE, "pots": 1}],
			"extras": [wall_r, {"t": "wall", "size": Vector3(1.0, 0.12, 0.04), "at": Vector2(0.5, -0.48)},
				{"t": "granary", "at": Vector2(0.2, -0.3), "r": 0.11}, {"t": "granary", "at": Vector2(0.45, -0.32), "r": 0.09, "col": MUD_LT},
				{"t": "granary", "at": Vector2(0.72, -0.3), "r": 0.1}, {"t": "granary", "at": Vector2(0.34, -0.1), "r": 0.075},
				{"t": "pen", "at": Vector2(0.62, 0.16), "w": 0.5, "d": 0.34},
				{"t": "palm", "at": Vector2(0.88, -0.1), "h": 0.55}, {"t": "beds", "at": Vector2(0.28, 0.24), "w": 0.26, "d": 0.2, "n": 3},
				{"t": "wall", "size": Vector3(0.3, 0.12, 0.04), "at": Vector2(0.18, 0.48)},
				{"t": "wall", "size": Vector3(0.34, 0.12, 0.04), "at": Vector2(0.82, 0.48)}]},
		"big_nile_court": {"fn": "multi", "parts": [
			{"fn": "court", "at": Vector2(-0.5, 0.0), "back": 0.4, "left": 0.3, "right": 0.3, "rback": "flat", "rleft": "flat",
				"rright": "flat", "court": "tree", "wall": MUD_LT, "trim": SAND, "mat": Kit.MUDBRICK, "acol": BLUE, "door": RED,
				"ground": DUST},
			{"fn": "court", "at": Vector2(0.5, 0.0), "back": 0.3, "left": 0.0, "right": 0.34, "up": 0.22, "upw": 0.5, "upx": -0.15,
				"rback": "flat", "rright": "dome", "court": "well", "wall": OCHRE_WALL, "trim": MUD_LT, "mat": Kit.MUDBRICK,
				"acol": TURQ, "dome": MUD_LT, "door": BLUE, "ground": DUST, "front": 0.26}]},
		"big_ne_court": {"fn": "multi", "parts": [
			{"fn": "court", "at": Vector2(-0.5, 0.0), "back": 0.42, "left": 0.34, "right": 0.3, "rback": "dome", "rleft": "flat",
				"rright": "flat", "court": "pool", "dome": TURQ, "badgir": true, "bx": 0.3},
			{"fn": "court", "at": Vector2(0.5, 0.0), "back": 0.34, "left": 0.0, "right": 0.3, "up": 0.24, "upw": 0.5, "upx": 0.12,
				"rback": "flat", "rright": "vault", "court": "tree", "wall": SAND, "trim": WHITE, "dome": SAND, "acol": RED,
				"door": TURQ, "gate_tower": true}]},
		"big_ne_row": {"fn": "multi", "parts": [
			{"fn": "flat", "at": Vector2(-0.67, 0.0), "w": 0.64, "d": 0.8, "h": 0.32, "batter": false, "mat": Kit.PLASTER,
				"wall": WHITE, "trim": LIME, "domes": [[0.0, 0.0, 0.16, TURQ]], "door": BLUE, "dx": 0.0, "win": 1, "arched": true,
				"palms": 0, "pots": 0},
			{"fn": "flat", "at": Vector2(0.0, 0.0), "w": 0.7, "d": 0.8, "h": 0.5, "batter": false, "mat": Kit.PLASTER,
				"wall": SAND, "trim": WHITE, "badgir": true, "bat": Vector2(-0.15, -0.15), "bh": 0.36, "door": TURQ, "dx": 0.0,
				"win": 2, "arched": true, "palms": 0, "pots": 0, "merlons": true, "band": BLUE},
			{"fn": "flat", "at": Vector2(0.67, 0.0), "w": 0.64, "d": 0.8, "h": 0.4, "uh": 0.22, "uw": 0.4, "ud": 0.4, "uat": Vector2(0, -0.1),
				"batter": false, "mat": Kit.PLASTER, "wall": LIME, "trim": WHITE, "ucol": WHITE, "lattice": true, "door": OCHRE,
				"dx": 0.0, "win": 1, "arched": true, "palms": 0, "pots": 0}]},
		"big_ne_hall": {"fn": "hittite", "bw": 1.8, "bd": 0.72, "sb": 0.26, "uh": 0.24, "roof": "gable", "rise": 0.34, "dx": -0.5,
			"wood": false, "tree": "none", "plaster": OCHRE_WALL, "stone": STONE_DK},
		"big_ne_kasbah": {"fn": "kasbah", "bw": 1.1, "bd": 0.5, "n": 2, "bz": -0.08, "dx": 0.0,
			"towers": [[-0.86, -0.34, 0.8, 0.22], [0.86, -0.34, 0.66, 0.2], [0.86, 0.3, 0.46, 0.18], [-0.86, 0.3, 0.52, 0.18]],
			"palms": 0, "col": Color(0.68, 0.48, 0.34)},
		"big_ne_khan": {"fn": "multi", "parts": [
			{"fn": "flat", "at": Vector2(0.0, -0.28), "w": 1.8, "d": 0.4, "h": 0.36, "wall": MUD, "merlons": true,
				"domes": [[-0.5, 0.0, 0.14, MUD_LT], [0.0, 0.0, 0.16, TURQ], [0.5, 0.0, 0.14, MUD_LT]], "door": RED, "dx": 0.0,
				"win": 6, "arched": true, "palms": 0, "pots": 0, "band": TURQ}],
			"extras": [{"t": "wall", "size": Vector3(0.7, 0.14, 0.05), "at": Vector2(-0.6, 0.48)},
				{"t": "wall", "size": Vector3(0.7, 0.14, 0.05), "at": Vector2(0.6, 0.48)},
				{"t": "gate", "at": Vector2(0.0, 0.48), "w": 0.3, "h": 0.2},
				{"t": "wall", "size": Vector3(0.05, 0.14, 0.7), "at": Vector2(-0.97, 0.12)},
				{"t": "wall", "size": Vector3(0.05, 0.14, 0.7), "at": Vector2(0.97, 0.12)},
				{"t": "pond", "at": Vector2(0.0, 0.16), "w": 0.3, "d": 0.2},
				{"t": "palm", "at": Vector2(-0.45, 0.2), "h": 0.5}, {"t": "palm", "at": Vector2(0.5, 0.22), "h": 0.55, "fronds": 6},
				{"t": "pot", "at": Vector2(-0.2, 0.34)}, {"t": "pot", "at": Vector2(0.24, 0.36)}]},
		"big_ind_haveli": {"fn": "haveli", "w": 1.7, "d": 0.66, "floors": 3, "fh": 0.24, "roof": "chhatri", "taper": 0.1,
			"dx": -0.5, "plaster": WHITE, "accent": OCHRE, "court": false},
		"big_ind_court": {"fn": "multi", "parts": [
			{"fn": "tiled", "at": Vector2(-0.5, 0.0), "w": 0.78, "d": 0.36, "h": 0.26, "z": -0.2, "roof": "gable", "veranda": 5,
				"trees": 0, "wall": WHITE, "wins": [0.12, 0.26]},
			{"fn": "tiled", "at": Vector2(0.5, 0.0), "w": 0.7, "d": 0.34, "h": 0.22, "z": -0.2, "roof": "hip", "veranda": 4, "trees": 0,
				"wall": ROSE, "clay": Color(0.56, 0.3, 0.22), "door": BLUE, "wins": [0.14]}],
			"extras": [{"t": "tree", "at": Vector2(0.0, 0.3), "h": 0.3, "r": 0.17},
				{"t": "wall", "size": Vector3(0.7, 0.1, 0.04), "at": Vector2(-0.6, 0.48)}, {"t": "wall", "size": Vector3(0.7, 0.1, 0.04), "at": Vector2(0.6, 0.48)},
				{"t": "gate", "at": Vector2(0.0, 0.48), "w": 0.26, "h": 0.17, "col": STONE_LT, "mat": Kit.STONE},
				{"t": "pond", "at": Vector2(0.55, 0.28), "w": 0.2, "d": 0.14}, {"t": "pot", "at": Vector2(-0.5, 0.3)}, {"t": "pot", "at": Vector2(0.28, 0.32)}]},
		"big_ind_row": {"fn": "multi", "parts": [
			{"fn": "merchant", "at": Vector2(-0.5, 0.0), "w": 0.92, "d": 0.62, "arches": 3, "roof": "tile", "tree": false},
			{"fn": "merchant", "at": Vector2(0.5, 0.0), "w": 0.92, "d": 0.62, "arches": 3, "wall": OCHRE_WALL, "upper": LIME,
				"roof": "flat", "accent": RED, "tree": false, "balcony": false, "sacks": 3}]},
		"big_ind_farm": {"fn": "multi", "parts": [
			{"fn": "hut", "at": Vector2(-0.62, 0.0), "form": "round", "R": 0.28, "porch": true, "granary": false, "fence": false, "tree": false},
			{"fn": "hut", "at": Vector2(0.5, 0.0), "form": "rect", "w": 0.6, "d": 0.4, "z": -0.15, "granary": false, "fence": false,
				"tree": false, "band": RED, "thatch": REED.darkened(0.08)}],
			"extras": [{"t": "pen", "at": Vector2(-0.1, 0.1), "w": 0.4, "d": 0.3}, {"t": "tree", "at": Vector2(-0.1, -0.35), "h": 0.32, "r": 0.18},
				{"t": "granary", "at": Vector2(0.12, -0.3), "r": 0.08}, {"t": "pot", "at": Vector2(-0.1, 0.38)},
				{"t": "beds", "at": Vector2(0.4, 0.32), "w": 0.4, "d": 0.2, "n": 4}]},
	}


# --- house sets: what each settlement rank draws from (D-281) -------------------------------------


## Which of the three styles a culture builds in: "nile" (pharaoh, kushite and other Nile cultures),
## "near_east" (berber, hittite, assyrian, turban and anything unknown) or "south_asian" (indian).
static func _style_of(culture: String) -> String:
	if culture in ["pharaoh", "kushite", "egyptian", "nubian", "nile", "meroitic"]:
		return "nile"
	if culture in ["indian", "maurya", "gupta", "south_asian", "hindu"]:
		return "south_asian"
	return "near_east"


## The ranks, folded to the groups that share a list.
static func _rank_group(rank: String) -> String:
	match rank:
		"core", "city", "edge", "suburb", "town", "village", "farm", "camp":
			return rank
	return "city"


## House kinds for a rank, weighted by repetition (a kind listed twice is twice as common).
static func house_set(culture: String, rank: String) -> Array:
	var rk := _rank_group(rank)
	match _style_of(culture):
		"nile":
			return _nile_set(culture, rk)
		"south_asian":
			return _ind_set(rk)
	return _ne_set(culture, rk)


static func _nile_set(culture: String, rk: String) -> Array:
	var kush := culture == "kushite"
	match rk:
		"core":
			return ["house_nile_villa_1", "house_nile_villa_2", "house_nile_town_3", "house_nile_town_4", "house_nile_town_2",
				"house_nile_tower_1", "house_nile_villa_1", "house_nile_town_1"]
		"city":
			return ["house_nile_town_1", "house_nile_town_2", "house_nile_town_3", "house_nile_town_4", "house_nile_villa_2",
				"house_nile_worker_1", "house_nile_tower_1", "house_nile_tower_2", "house_nile_town_1"]
		"edge":
			return ["house_nile_worker_1", "house_nile_worker_2", "house_nile_worker_3", "house_nile_worker_4", "house_nile_town_1",
				"house_nile_tower_2", "house_nile_worker_3"]
		"suburb":
			return ["house_nile_worker_2", "house_nile_worker_3", "house_nile_farm_1", "house_nile_worker_1", "house_nile_town_1",
				"house_nile_worker_4", "house_nile_farm_2"]
		"town":
			return ["house_nile_worker_1", "house_nile_worker_2", "house_nile_worker_3", "house_nile_worker_4", "house_nile_town_1",
				"house_nile_town_2", "house_nile_farm_1", "house_nile_tower_2"]
		"village":
			return ["house_nile_worker_1", "house_nile_worker_2", "house_nile_worker_3", "house_nile_worker_4", "house_nile_farm_1",
				"house_nile_farm_2", "house_nile_worker_3"] + (["house_nile_worker_4", "house_nile_worker_2"] if kush else [])
		"farm":
			return ["house_nile_farm_1", "house_nile_farm_2", "house_nile_farm_1", "house_nile_worker_2"]
	return ["house_nile_worker_3", "house_nile_worker_4", "house_nile_worker_1"]


static func _ne_set(culture: String, rk: String) -> Array:
	# a culture leans toward its own look: berber kasbahs, hittite stone-and-timber, turban domes
	var own: Array = []
	match culture:
		"berber": own = ["house_ne_berber_1", "house_ne_berber_2", "house_ne_berber_3"]
		"hittite": own = ["house_ne_hittite_1", "house_ne_hittite_2", "house_ne_hittite_3"]
		"turban": own = ["house_ne_domed_1", "house_ne_domed_2", "house_ne_domed_3"]
		"assyrian": own = ["house_ne_court_1", "house_ne_court_2", "house_ne_court_3"]
		_: own = ["house_ne_court_1", "house_ne_flat_1", "house_ne_domed_1"]
	match rk:
		"core":
			return own + ["house_ne_court_3", "house_ne_court_1", "house_ne_domed_2", "house_ne_domed_3", "house_ne_flat_2", "house_ne_court_2"]
		"city":
			return own + ["house_ne_court_1", "house_ne_court_2", "house_ne_court_3", "house_ne_flat_1", "house_ne_flat_2", "house_ne_domed_1",
				"house_ne_flat_3"]
		"edge":
			return own + ["house_ne_flat_1", "house_ne_flat_3", "house_ne_court_4", "house_ne_flat_2", "house_ne_flat_3"]
		"suburb":
			return own + ["house_ne_flat_3", "house_ne_court_4", "house_ne_flat_1", "house_ne_hittite_2"]
		"town":
			return own + ["house_ne_flat_1", "house_ne_flat_2", "house_ne_flat_3", "house_ne_court_4", "house_ne_court_1", "house_ne_hittite_2"]
		"village":
			return own + ["house_ne_flat_3", "house_ne_court_4", "house_ne_hittite_2", "house_ne_flat_1", "house_ne_flat_3"]
		"farm":
			return ["house_ne_court_4", "house_ne_hittite_2", "house_ne_flat_3", "house_ne_court_4", "house_ne_berber_2"]
	return ["house_ne_flat_3", "house_ne_hittite_2", "house_ne_court_4"]


static func _ind_set(rk: String) -> Array:
	match rk:
		"core":
			return ["house_ind_haveli_1", "house_ind_haveli_2", "house_ind_haveli_3", "house_ind_haveli_4", "house_ind_merchant_1",
				"house_ind_merchant_2", "house_ind_haveli_2"]
		"city":
			return ["house_ind_haveli_1", "house_ind_haveli_3", "house_ind_haveli_4", "house_ind_merchant_1", "house_ind_merchant_2",
				"house_ind_merchant_3", "house_ind_tile_3", "house_ind_tile_1"]
		"edge":
			return ["house_ind_tile_1", "house_ind_tile_2", "house_ind_tile_3", "house_ind_tile_4", "house_ind_merchant_3", "house_ind_hut_2",
				"house_ind_tile_2"]
		"suburb":
			return ["house_ind_tile_1", "house_ind_tile_2", "house_ind_tile_4", "house_ind_hut_2", "house_ind_hut_1", "house_ind_hut_3"]
		"town":
			return ["house_ind_tile_1", "house_ind_tile_2", "house_ind_tile_3", "house_ind_tile_4", "house_ind_merchant_3",
				"house_ind_hut_2", "house_ind_haveli_4", "house_ind_merchant_1"]
		"village":
			return ["house_ind_hut_1", "house_ind_hut_2", "house_ind_hut_3", "house_ind_hut_4", "house_ind_tile_1", "house_ind_tile_2",
				"house_ind_hut_1", "house_ind_hut_4"]
		"farm":
			return ["house_ind_hut_1", "house_ind_hut_3", "house_ind_hut_2", "house_ind_tile_2"]
	return ["house_ind_hut_1", "house_ind_hut_4", "house_ind_hut_2"]


## Two-lot kinds (2.0 wide by 1.0 deep) for a rank, or [] where a rank has none (camps).
static func big_house_set(culture: String, rank: String) -> Array:
	var rk := _rank_group(rank)
	match _style_of(culture):
		"nile":
			match rk:
				"core": return ["big_nile_villa", "big_nile_court", "big_nile_row"]
				"city": return ["big_nile_row", "big_nile_court", "big_nile_villa", "big_nile_row"]
				"edge": return ["big_nile_row", "big_nile_row", "big_nile_court"]
				"suburb", "town": return ["big_nile_row", "big_nile_farm", "big_nile_court"]
				"village": return ["big_nile_row", "big_nile_farm"]
				"farm": return ["big_nile_farm"]
			return []
		"south_asian":
			match rk:
				"core": return ["big_ind_haveli", "big_ind_row", "big_ind_court"]
				"city": return ["big_ind_row", "big_ind_haveli", "big_ind_court", "big_ind_row"]
				"edge": return ["big_ind_court", "big_ind_row"]
				"suburb", "town": return ["big_ind_court", "big_ind_row", "big_ind_farm"]
				"village": return ["big_ind_farm", "big_ind_court"]
				"farm": return ["big_ind_farm"]
			return []
	var own: String = {"berber": "big_ne_kasbah", "hittite": "big_ne_hall", "turban": "big_ne_khan"}.get(culture, "big_ne_court")
	match rk:
		"core": return [own, "big_ne_court", "big_ne_khan", "big_ne_row"]
		"city": return [own, "big_ne_row", "big_ne_court", "big_ne_row"]
		"edge": return ["big_ne_row", "big_ne_row", own]
		"suburb", "town": return ["big_ne_row", own, "big_ne_hall"]
		"village": return ["big_ne_hall", own]
		"farm": return ["big_ne_hall"]
	return []
