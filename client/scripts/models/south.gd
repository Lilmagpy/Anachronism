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
		"south_asian_palace", "stupa", "temple_shikhara"]


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
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
