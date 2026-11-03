## Civic buildings for the model kit (D-280): what a player builds inside a city, drawn
## as small, detailed, instantly readable models. Front (main facade) faces +z.
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")

const G := 0.03   ## thickness of the ground pad every building stands on

const STONE_C := Color(0.74, 0.71, 0.64)
const STONE_D := Color(0.56, 0.53, 0.48)
const WOOD := Color(0.45, 0.30, 0.18)
const WOODL := Color(0.68, 0.50, 0.30)
const PLASTER := Color(0.93, 0.88, 0.77)
const BRICK_C := Color(0.70, 0.37, 0.27)
const ROOF := Color(0.80, 0.46, 0.32)
const CREAM := Color(0.93, 0.88, 0.74)
const EARTH_C := Color(0.52, 0.40, 0.27)
const GROUND := Color(0.64, 0.58, 0.46)
const SOOT := Color(0.14, 0.12, 0.11)
const GOLD_C := Color(0.92, 0.74, 0.28)
const WATER_C := Color(0.30, 0.55, 0.72)
const LEAF_C := Color(0.35, 0.54, 0.25)
const IRON := Color(0.25, 0.25, 0.27)
const OWNER_C := Color(0.85, 0.85, 0.85)


static func kinds() -> Array:
	return ["market", "bank", "temple", "granary", "workshop", "factory", "watchtower", "mine",
		"school", "academy", "observatory", "forge", "water_wheel", "windmill", "clock_tower",
		"aqueduct", "hospital", "station", "hall", "harbour"]


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	match kind:
		"market": _market(k)
		"bank": _bank(k)
		"temple": _temple(k)
		"granary": _granary(k)
		"workshop": _workshop(k)
		"factory": _factory(k)
		"watchtower": _barracks(k)
		"mine": _mine(k)
		"school": _school(k)
		"academy": _academy(k)
		"observatory": _observatory(k)
		"forge": _forge(k)
		"water_wheel": _water_wheel(k)
		"windmill": _windmill(k)
		"clock_tower": _clock_tower(k)
		"aqueduct": _aqueduct(k)
		"hospital": _hospital(k)
		"station": _station(k)
		"hall": _hall(k)
		"harbour": _harbour(k)
		_: _hall(k)
	return k.finish()


# =============================================================================================
# helpers
# =============================================================================================


static func _base(k: Kit, w: float, d: float, col := GROUND, mat := Kit.EARTH) -> void:
	k.bevel_box(Vector3.ZERO, Vector3(w, G, d), 0.012, col, mat)


## A disc (short cylinder) whose axis points along z.
static func _disc_z(k: Kit, c: Vector3, r: float, t: float, col: Color, mat: int, sides := 10) -> void:
	k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), c))
	k.frustum(Vector3(0, -t / 2.0, 0), r, r, t, col, mat, sides)
	k.pop()


## A disc whose axis points along x.
static func _disc_x(k: Kit, c: Vector3, r: float, t: float, col: Color, mat: int, sides := 10) -> void:
	k.push(Transform3D(Basis(Vector3(0, 0, 1), -PI / 2.0), c))
	k.frustum(Vector3(0, -t / 2.0, 0), r, r, t, col, mat, sides)
	k.pop()


## A tapering horizontal tube along x (boiler, pipe, log), from x = -len/2 to len/2.
static func _tube_x(k: Kit, c: Vector3, r0: float, r1: float, len: float, col: Color, mat: int, sides := 10) -> void:
	k.push(Transform3D(Basis(Vector3(0, 0, 1), -PI / 2.0), c))
	k.frustum(Vector3(0, -len / 2.0, 0), r0, r1, len, col, mat, sides)
	k.pop()


static func _tube_z(k: Kit, c: Vector3, r0: float, r1: float, len: float, col: Color, mat: int, sides := 10) -> void:
	k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), c))
	k.frustum(Vector3(0, -len / 2.0, 0), r0, r1, len, col, mat, sides)
	k.pop()


static func _sack(k: Kit, p: Vector3, c := CREAM, s := 1.0) -> void:
	k.frustum(p, 0.05 * s, 0.036 * s, 0.065 * s, c, Kit.CLOTH, 5)
	k.frustum(p + Vector3(0, 0.065 * s, 0), 0.036 * s, 0.012 * s, 0.025 * s, c.darkened(0.18), Kit.CLOTH, 5)


static func _crate(k: Kit, p: Vector3, s: float, yaw := 0.0, c := WOODL) -> void:
	k.box(p, Vector3(s, s * 0.8, s), c, Kit.TIMBER, yaw)
	k.box(p + Vector3(0, s * 0.8, 0), Vector3(s * 1.05, s * 0.07, s * 1.05), c.darkened(0.25), Kit.TIMBER, yaw)


static func _barrel(k: Kit, p: Vector3, r := 0.05, h := 0.1) -> void:
	k.frustum(p, r * 0.82, r, h * 0.5, WOOD, Kit.TIMBER, 8, false)
	k.frustum(p + Vector3(0, h * 0.5, 0), r, r * 0.82, h * 0.5, WOOD, Kit.TIMBER, 8)
	k.frustum(p + Vector3(0, h * 0.44, 0), r * 1.03, r * 1.03, h * 0.1, SOOT, Kit.DARK, 8, false)
	k.frustum(p + Vector3(0, h * 0.1, 0), r * 0.9, r * 0.9, h * 0.07, SOOT, Kit.DARK, 8, false)


static func _ladder(k: Kit, a: Vector3, b: Vector3, side: Vector3, n := 5, r := 0.008) -> void:
	k.rod(a + side, b + side, r, WOOD, Kit.TIMBER)
	k.rod(a - side, b - side, r, WOOD, Kit.TIMBER)
	for i in n:
		var m := a.lerp(b, (i + 1.0) / (n + 1.0))
		k.rod(m + side, m - side, r * 0.8, WOODL, Kit.TIMBER)


## A circle of rods in the plane spanned by u and v (unit vectors), centre c, radius r.
static func _ring(k: Kit, c: Vector3, u: Vector3, v: Vector3, r: float, segs: int, rr: float, col: Color, mat: int) -> void:
	var prev := c + u * r
	for i in segs:
		var a := (i + 1) * TAU / segs
		var p := c + u * cos(a) * r + v * sin(a) * r
		k.rod(prev, p, rr, col, mat)
		prev = p


static func _tent(k: Kit, p: Vector3, yaw: float, w: float, d: float, h: float, col: Color, mat := Kit.CLOTH) -> void:
	k.push(Kit.at(p, yaw))
	k.wedge(Vector3.ZERO, w, d, h, col, mat, PI / 2.0)
	k.tri(Vector3(-d * 0.2, 0, w / 2.0 + 0.003), Vector3(d * 0.2, 0, w / 2.0 + 0.003), Vector3(0, h * 0.72, w / 2.0 + 0.003),
		SOOT, Kit.DARK, Vector3(0, h * 0.3, 0))
	k.rod(Vector3(0, h, -w / 2.0 - 0.02), Vector3(0, h, w / 2.0 + 0.02), 0.008, WOOD, Kit.TIMBER)
	k.pop()


## A semicircular arcade between x0 and x1: wall above the arch up to y_top, arch opening
## from y_spring. Piers are separate.
static func _arch_wall(k: Kit, x0: float, x1: float, y_spring: float, y_top: float, z: float, thick: float,
		col: Color, mat: int, segs := 8) -> void:
	var r := (x1 - x0) / 2.0
	var xc := (x0 + x1) / 2.0
	var solid := Vector3(xc, y_top, 0)
	var mid := Vector3(xc, (y_spring + y_top) / 2.0, 0)
	for i in segs:
		var a0 := PI * i / segs
		var a1 := PI * (i + 1) / segs
		var xa := xc - cos(a0) * r
		var ya := y_spring + sin(a0) * r
		var xb := xc - cos(a1) * r
		var yb := y_spring + sin(a1) * r
		for s in [-1.0, 1.0]:
			var zz: float = s * thick / 2.0 + z
			k.quad(Vector3(xa, ya, zz), Vector3(xb, yb, zz), Vector3(xb, y_top, zz), Vector3(xa, y_top, zz),
				col, mat, Vector3(mid.x, mid.y, z))
		k.quad(Vector3(xa, ya, z - thick / 2.0), Vector3(xb, yb, z - thick / 2.0), Vector3(xb, yb, z + thick / 2.0),
			Vector3(xa, ya, z + thick / 2.0), col.darkened(0.12), mat, Vector3(solid.x, y_top, z))


## A run of piers and arches along x, starting at x_start, `bays` arches of `span`.
static func _arcade(k: Kit, x_start: float, base_y: float, bays: int, span: float, pw: float, y_spring: float,
		y_top: float, z: float, thick: float, col: Color, mat: int) -> void:
	var x := x_start
	for i in bays + 1:
		k.box(Vector3(x + pw / 2.0, base_y, z), Vector3(pw, y_top - base_y, thick), col, mat)
		x += pw
		if i < bays:
			_arch_wall(k, x, x + span, base_y + y_spring, base_y + (y_top - base_y), z, thick, col, mat)
			x += span


static func _clock(k: Kit, c: Vector3, yaw: float, r: float) -> void:
	k.push(Kit.at(c, yaw))
	_disc_z(k, Vector3(0, 0, 0), r * 1.15, 0.03, GOLD_C, Kit.GOLD, 14)
	_disc_z(k, Vector3(0, 0, 0.012), r, 0.03, Color(0.96, 0.94, 0.88), Kit.PAINT, 14)
	for i in 4:
		var a := i * PI / 2.0
		k.box(Vector3(sin(a) * r * 0.8 - 0.006, cos(a) * r * 0.8 - 0.006, 0.026), Vector3(0.012, 0.012, 0.006), SOOT, Kit.DARK)
	k.rod(Vector3(0, 0, 0.032), Vector3(r * 0.1, r * 0.72, 0.032), 0.006, SOOT, Kit.DARK)
	k.rod(Vector3(0, 0, 0.034), Vector3(r * 0.55, -r * 0.2, 0.034), 0.006, SOOT, Kit.DARK)
	k.pop()


## A tall brick/stone chimney with a soot-black top.
static func _stack(k: Kit, p: Vector3, r0: float, r1: float, h: float, col: Color, mat: int, sides := 6) -> void:
	k.frustum(p, r0, r1, h, col, mat, sides, false)
	k.frustum(p + Vector3(0, h, 0), r1 * 1.25, r1 * 1.25, h * 0.05, col.darkened(0.1), mat, sides)
	k.frustum(p + Vector3(0, h * 1.05, 0), r1 * 1.0, r1 * 0.95, 0.012, SOOT, Kit.DARK, sides)


static func _tree(k: Kit, p: Vector3, s := 1.0) -> void:
	k.frustum(p, 0.025 * s, 0.018 * s, 0.14 * s, WOOD, Kit.TIMBER, 5, false)
	k.dome(p + Vector3(0, 0.1 * s, 0), 0.12 * s, LEAF_C, Kit.LEAF, 0.9, 3, 7)
	k.dome(p + Vector3(0.05 * s, 0.17 * s, 0.02 * s), 0.08 * s, LEAF_C.lightened(0.1), Kit.LEAF, 0.9, 2, 6)


## A stepped pile of lumber or logs.
static func _logs(k: Kit, p: Vector3, yaw: float, n := 3) -> void:
	k.push(Kit.at(p, yaw))
	for row in n:
		for i in n - row:
			var x := (i - (n - row - 1) / 2.0) * 0.062
			_tube_z(k, Vector3(x, 0.03 + row * 0.052, 0), 0.028, 0.028, 0.22, WOODL, Kit.TIMBER, 6)
			k.tri(Vector3(x - 0.02, 0.03 + row * 0.052, 0.111), Vector3(x + 0.02, 0.03 + row * 0.052, 0.111),
				Vector3(x, 0.05 + row * 0.052, 0.111), Color(0.78, 0.62, 0.38), Kit.PAINT, Vector3(x, 0.03 + row * 0.052, 0))
	k.pop()


static func _stall(k: Kit, p: Vector3, yaw: float, goods: int) -> void:
	k.push(Kit.at(p, yaw))
	k.box(Vector3(0, 0, 0.06), Vector3(0.5, 0.1, 0.14), WOODL, Kit.TIMBER)
	k.box(Vector3(0, 0.1, 0.06), Vector3(0.54, 0.014, 0.18), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0, -0.1), Vector3(0.5, 0.2, 0.03), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.2, -0.1), Vector3(0.5, 0.012, 0.06), WOODL, Kit.TIMBER)
	for sx: float in [-0.25, 0.25]:
		k.box(Vector3(sx, 0, -0.11), Vector3(0.025, 0.36, 0.025), WOOD, Kit.TIMBER)
		k.box(Vector3(sx, 0, 0.15), Vector3(0.025, 0.29, 0.025), WOOD, Kit.TIMBER)
	var n := 6
	for i in n:
		var x0 := -0.29 + i * 0.58 / n
		var x1 := x0 + 0.58 / n
		var m := Kit.OWNER_CLOTH if i % 2 == 0 else Kit.CLOTH
		var c := OWNER_C if i % 2 == 0 else CREAM
		k.quad(Vector3(x0, 0.36, -0.13), Vector3(x1, 0.36, -0.13), Vector3(x1, 0.29, 0.21), Vector3(x0, 0.29, 0.21), c, m, Vector3(0, 0, 0))
		k.quad(Vector3(x0, 0.355, -0.13), Vector3(x1, 0.355, -0.13), Vector3(x1, 0.285, 0.21), Vector3(x0, 0.285, 0.21), c.darkened(0.3), m, Vector3(0, 1, 0))
		k.tri(Vector3(x0, 0.29, 0.21), Vector3(x1, 0.29, 0.21), Vector3((x0 + x1) / 2.0, 0.26, 0.21), c, m, Vector3(0, 0.3, 0))
	match goods:
		0:   # fruit and veg crates
			for i in 3:
				k.box(Vector3(-0.17 + i * 0.17, 0.114, 0.06), Vector3(0.13, 0.04, 0.1), WOODL, Kit.TIMBER)
				var fc := [Color(0.85, 0.25, 0.18), Color(0.95, 0.75, 0.2), Color(0.45, 0.65, 0.25)][i] as Color
				k.dome(Vector3(-0.17 + i * 0.17, 0.152, 0.06), 0.06, fc, Kit.PAINT, 0.5, 2, 6)
		1:   # bolts of cloth
			for i in 4:
				var cc := [Color(0.75, 0.25, 0.25), Color(0.25, 0.4, 0.7), Color(0.9, 0.8, 0.4), Color(0.3, 0.6, 0.4)][i] as Color
				k.box(Vector3(-0.18 + i * 0.12, 0.114, 0.06), Vector3(0.09, 0.05, 0.12), cc, Kit.CLOTH)
			k.box(Vector3(-0.1, 0.164, 0.06), Vector3(0.1, 0.04, 0.1), Color(0.9, 0.9, 0.85), Kit.CLOTH)
		2:   # pots
			for i in 5:
				k.frustum(Vector3(-0.2 + i * 0.1, 0.114, 0.04 + (i % 2) * 0.05), 0.035, 0.025 + (i % 3) * 0.01, 0.06 + (i % 2) * 0.02,
					Color(0.75, 0.42, 0.25), Kit.TILE, 7)
		_:   # sacks of grain and spice
			for i in 4:
				_sack(k, Vector3(-0.18 + i * 0.12, 0.114, 0.05), [CREAM, Color(0.8, 0.65, 0.4)][i % 2] as Color, 0.9)
	k.pop()


# =============================================================================================
# market: a paved square with striped stalls round a well
# =============================================================================================


static func _market(k: Kit) -> void:
	_base(k, 1.56, 1.56, Color(0.68, 0.62, 0.52), Kit.STONE)
	k.box(Vector3(0, G, 0), Vector3(0.2, 0.004, 1.4), Color(0.80, 0.75, 0.66), Kit.STONE)
	k.box(Vector3(0, G, 0), Vector3(1.4, 0.004, 0.2), Color(0.80, 0.75, 0.66), Kit.STONE)
	# the well
	var w := Vector3(0, G, 0.05)
	k.frustum(w, 0.15, 0.14, 0.12, STONE_C, Kit.STONE, 10)
	k.frustum(w + Vector3(0, 0.113, 0), 0.115, 0.115, 0.014, WATER_C, Kit.WATER, 10)
	for sx: float in [-0.12, 0.12]:
		k.box(w + Vector3(sx - 0.011, 0.12, -0.011), Vector3(0.022, 0.24, 0.022), WOOD, Kit.TIMBER)
	k.rod(w + Vector3(-0.12, 0.3, 0), w + Vector3(0.12, 0.3, 0), 0.012, WOOD, Kit.TIMBER)
	k.gable_roof(w + Vector3(0, 0.33, 0), 0.3, 0.24, 0.1, 0.03, 0.02, ROOF, Kit.OWNER_ROOF, WOOD, Kit.TIMBER)
	k.rod(w + Vector3(0, 0.3, 0), w + Vector3(0, 0.2, 0), 0.004, SOOT, Kit.DARK)
	k.frustum(w + Vector3(0, 0.15, 0), 0.025, 0.02, 0.05, WOOD, Kit.TIMBER, 6)
	# stalls
	_stall(k, Vector3(-0.42, G, -0.6), 0.0, 0)
	_stall(k, Vector3(0.42, G, -0.6), 0.0, 1)
	_stall(k, Vector3(-0.64, G, 0.0), PI / 2.0, 2)
	_stall(k, Vector3(0.64, G, 0.0), -PI / 2.0, 3)
	# a handcart with goods
	k.push(Kit.at(Vector3(0.36, G, 0.4), 0.35))
	k.box(Vector3(0, 0.07, 0), Vector3(0.34, 0.03, 0.2), WOODL, Kit.TIMBER)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.15, 0.07, 0.0), Vector3(0.01, 0.07, 0.2), WOOD, Kit.TIMBER)
	_disc_x(k, Vector3(0.0, 0.07, 0.12), 0.07, 0.02, WOOD, Kit.TIMBER, 10)
	_disc_x(k, Vector3(0.0, 0.07, -0.12), 0.07, 0.02, WOOD, Kit.TIMBER, 10)
	k.rod(Vector3(-0.1, 0.075, 0.1), Vector3(-0.2, 0.05, 0.28), 0.01, WOOD, Kit.TIMBER)
	k.rod(Vector3(0.1, 0.075, 0.1), Vector3(0.2, 0.05, 0.28), 0.01, WOOD, Kit.TIMBER)
	_sack(k, Vector3(-0.07, 0.1, 0), CREAM)
	_sack(k, Vector3(0.07, 0.1, 0.02), Color(0.8, 0.65, 0.4))
	_sack(k, Vector3(0.0, 0.1, -0.06), CREAM, 0.9)
	k.pop()
	_barrel(k, Vector3(-0.55, G, 0.58))
	_barrel(k, Vector3(-0.46, G, 0.66))
	_barrel(k, Vector3(-0.5, G, 0.52), 0.045, 0.08)
	_crate(k, Vector3(-0.2, G, 0.64), 0.1, 0.2)
	_crate(k, Vector3(-0.2, G + 0.08, 0.64), 0.08, 0.5)
	_crate(k, Vector3(-0.07, G, 0.68), 0.09, -0.2)
	k.banner(Vector3(-0.72, G, 0.7), 0.6, 0.24)
	k.banner(Vector3(0.72, G, -0.72), 0.5, 0.2, PI)
	# a coin-weighing table
	k.box(Vector3(0.18, G, 0.3), Vector3(0.14, 0.09, 0.09), WOODL, Kit.TIMBER)
	k.box(Vector3(0.16, G + 0.09, 0.3), Vector3(0.04, 0.015, 0.04), GOLD_C, Kit.GOLD)


# =============================================================================================
# bank: a stone counting-house with a columned portico and a strongroom
# =============================================================================================


static func _bank(k: Kit) -> void:
	_base(k, 1.5, 1.4, Color(0.70, 0.67, 0.60), Kit.STONE)
	var y0 := G
	# podium and steps
	k.box(Vector3(0, y0, 0.0), Vector3(1.2, 0.08, 0.95), STONE_C, Kit.STONE)
	for i in 3:
		k.box(Vector3(0, y0 + 0.01, 0.52 + i * 0.05), Vector3(0.6 - i * 0.04, 0.07 - i * 0.02, 0.1), STONE_C.lightened(0.05 * i), Kit.STONE)
	var y1 := y0 + 0.08
	# main hall
	k.box(Vector3(0, y1, -0.08), Vector3(1.0, 0.48, 0.55), Color(0.80, 0.76, 0.68), Kit.STONE)
	k.box(Vector3(0, y1 + 0.43, -0.08), Vector3(1.05, 0.05, 0.6), STONE_C, Kit.STONE)   # cornice
	k.hip_roof(Vector3(0, y1 + 0.48, -0.08), 1.0, 0.55, 0.2, 0.05, 0.03, ROOF, Kit.OWNER_ROOF)
	# side windows and barred ones
	for sx: float in [-0.38, 0.38]:
		k.window(Vector3(sx, y1 + 0.3, 0.2), 0.0, 0.1, 0.2, STONE_C, "stone")
	for sz: float in [-0.22, 0.06]:
		for s: float in [-1.0, 1.0]:
			k.window(Vector3(s * 0.5, y1 + 0.3, -0.08 + sz), s * PI / 2.0, 0.09, 0.18, STONE_C, "lattice")
	k.door(Vector3(0, y1, 0.195), 0.0, 0.2, 0.34, STONE_C, Color(0.35, 0.22, 0.12))
	# portico
	for sx: float in [-0.36, -0.12, 0.12, 0.36]:
		k.column(Vector3(sx, y1, 0.34), 0.035, 0.46, Color(0.9, 0.87, 0.8), Kit.PAINT)
	k.box(Vector3(0, y1 + 0.46, 0.3), Vector3(0.92, 0.06, 0.24), STONE_C, Kit.STONE)
	k.wedge(Vector3(0, y1 + 0.52, 0.3), 0.24, 0.92, 0.17, STONE_C.lightened(0.04), Kit.STONE, PI / 2.0)
	_disc_z(k, Vector3(0, y1 + 0.6, 0.43), 0.06, 0.02, GOLD_C, Kit.GOLD, 12)
	k.box(Vector3(-0.015, y1 + 0.585, 0.44), Vector3(0.03, 0.05, 0.006), SOOT, Kit.DARK)
	k.box(Vector3(0, y1 + 0.69, 0.3), Vector3(0.05, 0.05, 0.05), GOLD_C, Kit.GOLD)
	# strongroom behind
	k.box(Vector3(0, y1, -0.5), Vector3(0.46, 0.4, 0.34), STONE_D, Kit.STONE)
	k.box(Vector3(0, y1 + 0.4, -0.5), Vector3(0.52, 0.04, 0.4), STONE_C, Kit.STONE)
	for i in 6:
		k.box(Vector3(-0.2 + i * 0.08, y1 + 0.44, -0.5 - 0.18 * (1 if i % 5 == 0 else 0)), Vector3(0.05, 0.04, 0.05), STONE_C, Kit.STONE)
	k.window(Vector3(0, y1 + 0.24, -0.325), PI, 0.07, 0.1, IRON, "lattice")
	k.box(Vector3(0.0, y1, -0.69), Vector3(0.2, 0.22, 0.03), IRON, Kit.PAINT)   # vault door
	_disc_z(k, Vector3(0.0, y1 + 0.11, -0.7), 0.06, 0.02, GOLD_C, Kit.GOLD, 10)
	# treasure chests and guards' posts
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.62, y0, 0.45), Vector3(0.16, 0.09, 0.1), WOOD, Kit.TIMBER)
		k.box(Vector3(sx * 0.62, y0 + 0.09, 0.45), Vector3(0.16, 0.025, 0.1), GOLD_C.darkened(0.2), Kit.GOLD)
		k.box(Vector3(sx * 0.62, y0, 0.45), Vector3(0.025, 0.1, 0.105), IRON, Kit.PAINT)
		k.box(Vector3(sx * 0.66, y0, 0.6), Vector3(0.04, 0.3, 0.04), STONE_C, Kit.STONE)
		k.box(Vector3(sx * 0.66, y0 + 0.3, 0.6), Vector3(0.06, 0.03, 0.06), STONE_D, Kit.STONE)
		k.box(Vector3(sx * 0.66, y0 + 0.33, 0.6), Vector3(0.03, 0.04, 0.03), GOLD_C, Kit.GOLD)
	k.banner(Vector3(-0.55, y1, 0.0), 0.75, 0.22)


# =============================================================================================
# temple: stepped base, peristyle, pediment, incense altar
# =============================================================================================


static func _temple(k: Kit) -> void:
	_base(k, 1.5, 1.5, Color(0.68, 0.64, 0.55), Kit.STONE)
	k.plinth(Vector3(0, G, 0), 1.3, 1.15, 0.06, 0.03, STONE_C, Kit.STONE)
	k.plinth(Vector3(0, G + 0.06, 0), 1.12, 0.97, 0.06, 0.03, STONE_C.lightened(0.04), Kit.STONE)
	k.plinth(Vector3(0, G + 0.12, 0), 0.96, 0.82, 0.05, 0.03, STONE_C.lightened(0.08), Kit.STONE)
	var y := G + 0.17
	for i in 3:   # front steps
		k.box(Vector3(0, G, 0.62 + i * 0.05), Vector3(0.36 - i * 0.04, 0.05 * (3 - i) + 0.01, 0.07), STONE_C, Kit.STONE)
	k.box(Vector3(0, y, -0.02), Vector3(0.5, 0.44, 0.6), Color(0.88, 0.84, 0.74), Kit.PLASTER)
	k.door(Vector3(0, y, 0.285), 0.0, 0.17, 0.3, GOLD_C, Color(0.30, 0.18, 0.10))
	_disc_z(k, Vector3(0, y + 0.37, 0.29), 0.035, 0.012, GOLD_C, Kit.GOLD, 10)
	var cols: Array = []
	for sx: float in [-0.36, -0.12, 0.12, 0.36]:
		cols.append(Vector3(sx, y, 0.38))
	for sz: float in [-0.22, 0.0, 0.22]:
		cols.append(Vector3(-0.38, y, sz))
		cols.append(Vector3(0.38, y, sz))
	cols.append(Vector3(-0.36, y, -0.36))
	cols.append(Vector3(0.36, y, -0.36))
	for c: Vector3 in cols:
		k.column(c, 0.032, 0.44, Color(0.93, 0.9, 0.82), Kit.PAINT)
	k.box(Vector3(0, y + 0.44, 0.0), Vector3(0.9, 0.05, 0.84), STONE_C, Kit.STONE)
	k.gable_roof(Vector3(0, y + 0.49, 0.0), 0.84, 0.9, 0.24, 0.0, 0.035, Color(0.78, 0.44, 0.30), Kit.OWNER_ROOF,
		Color(0.9, 0.86, 0.76), Kit.STONE, PI / 2.0)
	k.box(Vector3(0, y + 0.72, 0.43), Vector3(0.06, 0.05, 0.03), GOLD_C, Kit.GOLD)
	k.dome(Vector3(0, y + 0.55, 0.435), 0.05, GOLD_C, Kit.GOLD, 0.8, 2, 8)
	for sz: float in [-0.43, 0.43]:   # acroteria at the gable ends
		k.box(Vector3(0, y + 0.74, sz), Vector3(0.04, 0.05, 0.04), GOLD_C, Kit.GOLD)
	# incense altar and braziers
	k.box(Vector3(0, G, 0.86 - 0.02), Vector3(0.2, 0.09, 0.14), STONE_C, Kit.STONE)
	k.frustum(Vector3(0, G + 0.09, 0.84), 0.055, 0.08, 0.04, GOLD_C, Kit.GOLD, 8)
	k.frustum(Vector3(0, G + 0.125, 0.84), 0.07, 0.07, 0.01, Color(0.2, 0.08, 0.05), Kit.DARK, 8)
	k.frustum(Vector3(0, G + 0.13, 0.84), 0.012, 0.03, 0.12, Color(0.85, 0.85, 0.85), Kit.CLOTH, 5, false)
	for sx: float in [-0.5, 0.5]:
		k.rod(Vector3(sx - 0.04, G, 0.8), Vector3(sx, G + 0.22, 0.8), 0.008, IRON, Kit.PAINT)
		k.rod(Vector3(sx + 0.04, G, 0.8), Vector3(sx, G + 0.22, 0.8), 0.008, IRON, Kit.PAINT)
		k.rod(Vector3(sx, G, 0.76), Vector3(sx, G + 0.22, 0.8), 0.008, IRON, Kit.PAINT)
		k.frustum(Vector3(sx, G + 0.22, 0.8), 0.04, 0.065, 0.04, GOLD_C, Kit.GOLD, 8)
		k.frustum(Vector3(sx, G + 0.255, 0.8), 0.055, 0.055, 0.01, Color(0.9, 0.35, 0.1), Kit.GOLD, 8)
	k.banner(Vector3(-0.68, G, 0.7), 0.7, 0.2)
	k.banner(Vector3(0.68, G, 0.7), 0.7, 0.2)


# =============================================================================================
# granary: timber bin on stone feet, plus thatched silos, sacks and a ladder
# =============================================================================================


static func _granary(k: Kit) -> void:
	_base(k, 1.5, 1.4, Color(0.62, 0.55, 0.40), Kit.EARTH)
	var feet_y := G
	var bx := -0.25
	for sx: float in [-0.3, 0.0, 0.3]:
		for sz: float in [-0.2, 0.2]:
			k.frustum(Vector3(bx + sx, feet_y, sz), 0.05, 0.035, 0.1, STONE_C, Kit.STONE, 6, false)
			k.frustum(Vector3(bx + sx, feet_y + 0.1, sz), 0.07, 0.07, 0.025, STONE_D, Kit.STONE, 6)
	var fy := feet_y + 0.125
	k.box(Vector3(bx, fy, 0), Vector3(0.78, 0.04, 0.5), WOOD, Kit.TIMBER)
	k.box(Vector3(bx, fy + 0.04, 0), Vector3(0.72, 0.4, 0.44), Color(0.72, 0.55, 0.34), Kit.TIMBER)
	for i in 5:   # corner posts and battens
		k.box(Vector3(bx - 0.36 + i * 0.18, fy + 0.04, 0.225), Vector3(0.03, 0.4, 0.02), WOOD, Kit.TIMBER)
	k.box(Vector3(bx, fy + 0.22, 0.225), Vector3(0.72, 0.025, 0.02), WOOD, Kit.TIMBER)
	k.box(Vector3(bx + 0.1, fy + 0.04, 0.226), Vector3(0.16, 0.22, 0.008), Color(0.35, 0.22, 0.12), Kit.TIMBER)   # hatch door
	k.box(Vector3(bx + 0.1, fy + 0.04, 0.231), Vector3(0.18, 0.02, 0.01), WOOD, Kit.TIMBER)
	for sx: float in [-0.28, 0.28]:   # vent slits
		k.box(Vector3(bx + sx, fy + 0.3, 0.226), Vector3(0.05, 0.04, 0.006), SOOT, Kit.DARK)
	k.gable_roof(Vector3(bx, fy + 0.44, 0), 0.72, 0.44, 0.28, 0.1, 0.035, Color(0.85, 0.62, 0.30), Kit.OWNER_ROOF,
		Color(0.72, 0.55, 0.34), Kit.TIMBER)
	k.box(Vector3(bx - 0.36, fy + 0.72, 0), Vector3(0.03, 0.05, 0.03), WOOD, Kit.TIMBER)
	k.box(Vector3(bx + 0.36, fy + 0.72, 0), Vector3(0.03, 0.05, 0.03), WOOD, Kit.TIMBER)
	_ladder(k, Vector3(bx + 0.28, G, 0.45), Vector3(bx + 0.28, fy + 0.15, 0.25), Vector3(0.04, 0, 0), 6)
	# round silos with thatch cones
	for s in [Vector3(0.42, 0, -0.35), Vector3(0.45, 0, 0.18)]:
		var sp: Vector3 = s
		for i in 6:
			var a := i * TAU / 6.0
			k.frustum(sp + Vector3(cos(a) * 0.17, G, sin(a) * 0.17), 0.03, 0.022, 0.07, STONE_C, Kit.STONE, 5)
		k.frustum(sp + Vector3(0, G + 0.07, 0), 0.2, 0.2, 0.025, WOOD, Kit.TIMBER, 12)
		k.frustum(sp + Vector3(0, G + 0.095, 0), 0.185, 0.17, 0.42, Color(0.86, 0.78, 0.6), Kit.PLASTER, 12, false)
		for i in 3:
			k.frustum(sp + Vector3(0, G + 0.17 + i * 0.12, 0), 0.19 - i * 0.004, 0.19 - i * 0.004, 0.012, WOOD, Kit.TIMBER, 12, false)
		k.frustum(sp + Vector3(0, G + 0.515, 0), 0.25, 0.0, 0.26, Color(0.85, 0.62, 0.30), Kit.OWNER_ROOF, 12)
		k.frustum(sp + Vector3(0, G + 0.77, 0), 0.015, 0.0, 0.05, GOLD_C, Kit.GOLD, 4)
		k.box(sp + Vector3(0, G + 0.14, 0.19), Vector3(0.08, 0.11, 0.02), Color(0.3, 0.2, 0.12), Kit.TIMBER)
	# sacks, barrels, a loaded cart
	for i in 3:
		_sack(k, Vector3(-0.62 + i * 0.09, G, 0.55), CREAM)
	_sack(k, Vector3(-0.58, G + 0.065, 0.55), CREAM, 0.95)
	_sack(k, Vector3(-0.5, G + 0.065, 0.56), Color(0.8, 0.65, 0.4), 0.95)
	_sack(k, Vector3(-0.54, G + 0.13, 0.55), CREAM, 0.9)
	_barrel(k, Vector3(-0.1, G, 0.6))
	k.push(Kit.at(Vector3(0.28, G, 0.6), -0.3))
	k.box(Vector3(0, 0.07, 0), Vector3(0.3, 0.03, 0.18), WOODL, Kit.TIMBER)
	_disc_x(k, Vector3(0.0, 0.07, 0.11), 0.065, 0.02, WOOD, Kit.TIMBER, 10)
	_disc_x(k, Vector3(0.0, 0.07, -0.11), 0.065, 0.02, WOOD, Kit.TIMBER, 10)
	for i in 3:
		_sack(k, Vector3(-0.09 + i * 0.09, 0.1, 0), CREAM)
	k.rod(Vector3(0.14, 0.075, 0), Vector3(0.36, 0.05, 0.02), 0.01, WOOD, Kit.TIMBER)
	k.pop()
	# a heap of loose grain with a shovel
	k.dome(Vector3(0.0, G, -0.62), 0.14, Color(0.9, 0.75, 0.35), Kit.THATCH, 0.6, 3, 8)
	k.rod(Vector3(0.12, G + 0.1, -0.6), Vector3(0.2, G + 0.02, -0.5), 0.007, WOOD, Kit.TIMBER)


# =============================================================================================
# workshop: an open-fronted craftsman's shed with benches and a timber pile
# =============================================================================================


static func _workshop(k: Kit) -> void:
	_base(k, 1.5, 1.3, GROUND, Kit.EARTH)
	var hx := -0.18
	k.box(Vector3(hx, G, -0.27), Vector3(0.9, 0.4, 0.05), PLASTER, Kit.PLASTER)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(hx + s * 0.44, G, -0.02), Vector3(0.05, 0.4, 0.55), PLASTER, Kit.PLASTER)
	for sx: float in [-0.45, 0.0, 0.45]:   # front posts
		k.box(Vector3(hx + sx, G, 0.26), Vector3(0.04, 0.42, 0.04), WOOD, Kit.TIMBER)
	k.box(Vector3(hx, G + 0.4, 0.26), Vector3(0.95, 0.04, 0.05), WOOD, Kit.TIMBER)
	for i in 3:
		k.box(Vector3(hx - 0.3 + i * 0.3, G + 0.38, 0.26), Vector3(0.03, 0.02, 0.05), WOOD, Kit.TIMBER)
	k.gable_roof(Vector3(hx, G + 0.42, 0), 0.9, 0.58, 0.22, 0.09, 0.035, ROOF, Kit.OWNER_ROOF, PLASTER, Kit.PLASTER)
	k.chimney(Vector3(hx + 0.28, G + 0.5, -0.12), 0.07, 0.3, STONE_D)
	k.box(Vector3(hx + 0.28, G + 0.8, -0.12), Vector3(0.07, 0.015, 0.07), SOOT, Kit.DARK)
	# the bench with a vice, saw and mallet, a second bench with planks
	k.box(Vector3(hx - 0.2, G, -0.16), Vector3(0.38, 0.11, 0.14), WOODL, Kit.TIMBER)
	k.box(Vector3(hx - 0.2, G + 0.11, -0.16), Vector3(0.4, 0.02, 0.16), WOOD, Kit.TIMBER)
	k.box(Vector3(hx - 0.36, G + 0.13, -0.16), Vector3(0.04, 0.04, 0.05), IRON, Kit.PAINT)
	k.box(Vector3(hx - 0.2, G + 0.13, -0.15), Vector3(0.14, 0.01, 0.03), IRON, Kit.PAINT)
	k.rod(Vector3(hx - 0.06, G + 0.135, -0.13), Vector3(hx - 0.03, G + 0.15, -0.13), 0.008, WOOD, Kit.TIMBER)
	k.box(Vector3(hx + 0.12, G, 0.0), Vector3(0.3, 0.1, 0.12), WOODL, Kit.TIMBER)
	k.box(Vector3(hx + 0.12, G + 0.1, 0.0), Vector3(0.32, 0.02, 0.14), WOOD, Kit.TIMBER)
	k.box(Vector3(hx + 0.1, G + 0.12, 0.0), Vector3(0.22, 0.015, 0.06), Color(0.8, 0.66, 0.42), Kit.TIMBER)
	k.box(Vector3(hx + 0.13, G + 0.135, 0.01), Vector3(0.18, 0.015, 0.06), Color(0.74, 0.58, 0.36), Kit.TIMBER)
	# tools on the back wall
	for i in 4:
		k.rod(Vector3(hx - 0.3 + i * 0.17, G + 0.32, -0.24), Vector3(hx - 0.3 + i * 0.17, G + 0.2, -0.24), 0.007, IRON, Kit.PAINT)
		k.box(Vector3(hx - 0.32 + i * 0.17, G + 0.2, -0.245), Vector3(0.04, 0.03, 0.01), IRON, Kit.PAINT)
	k.rod(Vector3(hx - 0.35, G + 0.34, -0.245), Vector3(hx + 0.4, G + 0.34, -0.245), 0.006, WOOD, Kit.TIMBER)
	# a treadle lathe
	k.box(Vector3(hx + 0.32, G, 0.04), Vector3(0.05, 0.12, 0.2), WOOD, Kit.TIMBER)
	_disc_x(k, Vector3(hx + 0.32, G + 0.1, 0.0), 0.04, 0.02, WOOD, Kit.TIMBER, 8)
	# hanging sign with a gear
	k.rod(Vector3(hx + 0.45, G + 0.38, 0.28), Vector3(hx + 0.58, G + 0.38, 0.28), 0.008, WOOD, Kit.TIMBER)
	_disc_z(k, Vector3(hx + 0.56, G + 0.31, 0.28), 0.055, 0.015, GOLD_C, Kit.GOLD, 8)
	_disc_z(k, Vector3(hx + 0.56, G + 0.31, 0.29), 0.02, 0.015, SOOT, Kit.DARK, 6)
	# yard: timber pile, planks, saw horse, logs, barrel, grindstone
	_logs(k, Vector3(0.6, G, -0.2), 0.0, 4)
	_logs(k, Vector3(0.58, G, 0.25), 0.2, 3)
	for i in 5:
		k.rod(Vector3(-0.72 + i * 0.03, G, -0.45), Vector3(-0.68 + i * 0.03, G + 0.36, -0.28), 0.014, Color(0.75, 0.6, 0.38), Kit.TIMBER)
	k.rod(Vector3(-0.55, G + 0.1, 0.5), Vector3(-0.55, G, 0.55), 0.008, WOOD, Kit.TIMBER)
	k.box(Vector3(-0.45, G + 0.09, 0.5), Vector3(0.24, 0.02, 0.03), WOOD, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		k.rod(Vector3(-0.45 + s * 0.1, G + 0.09, 0.5), Vector3(-0.45 + s * 0.13, G, 0.56), 0.01, WOOD, Kit.TIMBER)
		k.rod(Vector3(-0.45 + s * 0.1, G + 0.09, 0.5), Vector3(-0.45 + s * 0.13, G, 0.44), 0.01, WOOD, Kit.TIMBER)
	k.box(Vector3(-0.45, G + 0.1, 0.5), Vector3(0.3, 0.025, 0.07), Color(0.78, 0.62, 0.4), Kit.TIMBER)
	_barrel(k, Vector3(-0.1, G, 0.55))
	_disc_x(k, Vector3(0.18, G + 0.08, 0.5), 0.07, 0.03, Color(0.6, 0.58, 0.54), Kit.STONE, 10)
	k.box(Vector3(0.18 - 0.05, G, 0.5 - 0.02), Vector3(0.02, 0.1, 0.04), WOOD, Kit.TIMBER)
	k.box(Vector3(0.18 + 0.05, G, 0.5 - 0.02), Vector3(0.02, 0.1, 0.04), WOOD, Kit.TIMBER)
	k.box(Vector3(0.32, G, 0.58), Vector3(0.06, 0.09, 0.05), WOOD, Kit.TIMBER)
	k.box(Vector3(0.32, G + 0.09, 0.58), Vector3(0.07, 0.03, 0.06), SOOT, Kit.DARK)


# =============================================================================================
# factory: an early-modern manufactory, brick hall with a sawtooth roof and tall chimneys
# =============================================================================================


static func _factory(k: Kit) -> void:
	_base(k, 1.58, 1.4, Color(0.42, 0.40, 0.37), Kit.EARTH)
	var y := G
	var hx := -0.18
	var hz := -0.12
	var hl := 1.1
	var hd := 0.62
	var zf := hz + hd / 2.0
	var zb := hz - hd / 2.0
	k.box(Vector3(hx, y, hz), Vector3(hl + 0.04, 0.05, hd + 0.04), STONE_D, Kit.STONE)
	k.box(Vector3(hx, y + 0.05, hz), Vector3(hl, 0.36, hd), BRICK_C, Kit.BRICK)
	k.box(Vector3(hx, y + 0.4, hz), Vector3(hl + 0.04, 0.03, hd + 0.04), STONE_C, Kit.STONE)
	var y0 := y + 0.43
	var teeth := 5
	var tw := hl / teeth
	for i in teeth:
		var x0 := hx - hl / 2.0 + i * tw
		var x1 := x0 + tw
		k.quad(Vector3(x0, y0, zb - 0.02), Vector3(x1, y0 + 0.17, zb - 0.02), Vector3(x1, y0 + 0.17, zf + 0.02), Vector3(x0, y0, zf + 0.02),
			Color(0.78, 0.45, 0.32), Kit.OWNER_ROOF, Vector3(x0 + tw / 2.0, y0 - 0.5, hz))
		k.quad(Vector3(x0, y0 - 0.02, zb - 0.02), Vector3(x1, y0 + 0.15, zb - 0.02), Vector3(x1, y0 + 0.15, zf + 0.02), Vector3(x0, y0 - 0.02, zf + 0.02),
			Color(0.4, 0.2, 0.15), Kit.OWNER_ROOF, Vector3(x0 + tw / 2.0, y0 + 2.0, hz))
		k.quad(Vector3(x1, y0, zb), Vector3(x1, y0, zf), Vector3(x1, y0 + 0.17, zf), Vector3(x1, y0 + 0.17, zb),
			Color(0.16, 0.2, 0.24), Kit.DARK, Vector3(x0 + tw / 2.0, y0 + 0.05, hz))
		for m in 4:
			k.box(Vector3(x1, y0, zb + (m + 1) * hd / 5.0 - 0.006), Vector3(0.012, 0.17, 0.012), IRON, Kit.PAINT)
		k.rod(Vector3(x1 + 0.004, y0 + 0.17, zb), Vector3(x1 + 0.004, y0 + 0.17, zf), 0.01, STONE_D, Kit.STONE)
		for z in [zb - 0.02, zf + 0.02]:
			k.tri(Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y0 + 0.17, z), BRICK_C, Kit.BRICK, Vector3(x0 + 0.1, y0 + 0.05, hz))
	# windows and the great door
	for x: float in [-0.62, -0.47, 0.19, 0.34]:
		k.window(Vector3(hx + x + 0.0, y + 0.28, zf), 0.0, 0.08, 0.17, STONE_C, "arch")
	k.door(Vector3(hx + 0.0, y + 0.05, zf), 0.0, 0.2, 0.28, STONE_C, Color(0.30, 0.2, 0.12))
	_disc_z(k, Vector3(hx, y + 0.41, zf + 0.025), 0.045, 0.012, GOLD_C, Kit.GOLD, 10)
	_disc_z(k, Vector3(hx, y + 0.41, zf + 0.032), 0.02, 0.01, SOOT, Kit.DARK, 6)
	for z: float in [-0.3, -0.12]:
		k.window(Vector3(hx + hl / 2.0, y + 0.28, hz + z + 0.12), PI / 2.0, 0.08, 0.17, STONE_C, "arch")
	for i in 5:   # pilasters
		k.box(Vector3(hx - hl / 2.0 + i * hl / 4.0, y + 0.05, zf + 0.005), Vector3(0.035, 0.35, 0.02), STONE_C, Kit.STONE)
	# boiler house, big chimney, water tank
	var bx := 0.56
	k.box(Vector3(bx, y, -0.24), Vector3(0.34, 0.3, 0.4), Color(0.62, 0.32, 0.24), Kit.BRICK)
	k.hip_roof(Vector3(bx, y + 0.3, -0.24), 0.34, 0.4, 0.1, 0.04, 0.025, Color(0.5, 0.3, 0.25), Kit.OWNER_ROOF)
	k.window(Vector3(bx, y + 0.17, -0.04), 0.0, 0.07, 0.12, STONE_C, "arch")
	k.box(Vector3(bx, y, 0.0), Vector3(0.2, 0.04, 0.1), STONE_D, Kit.STONE)
	_stack(k, Vector3(0.62, y, -0.45), 0.09, 0.055, 1.25, BRICK_C, Kit.BRICK, 8)
	for h: float in [0.35, 0.8]:
		k.frustum(Vector3(0.62, y + h, -0.45), 0.09 - h * 0.027 + 0.012, 0.09 - h * 0.027 + 0.012, 0.03, STONE_C, Kit.STONE, 8, false)
	k.frustum(Vector3(0.62, y + 1.29, -0.45), 0.065, 0.06, 0.02, SOOT, Kit.DARK, 8, false)
	_stack(k, Vector3(-0.55, y + 0.43, -0.28), 0.045, 0.035, 0.42, BRICK_C, Kit.BRICK, 6)
	for p in [Vector3(0.62, 1.42, -0.45), Vector3(0.66, 1.52, -0.42), Vector3(0.71, 1.64, -0.4)]:
		var pp: Vector3 = p
		k.dome(pp, 0.07 + (pp.y - 1.42) * 0.25, Color(0.8, 0.8, 0.82), Kit.CLOTH, 1.0, 3, 8)
	# water tank on stilts
	for sx: float in [-0.05, 0.05]:
		for sz: float in [-0.05, 0.05]:
			k.rod(Vector3(0.1 + sx, y, -0.62 + sz), Vector3(0.1 + sx, y + 0.22, -0.62 + sz), 0.008, WOOD, Kit.TIMBER)
	k.frustum(Vector3(0.1, y + 0.22, -0.62), 0.085, 0.085, 0.1, WOOD, Kit.TIMBER, 10)
	k.frustum(Vector3(0.1, y + 0.32, -0.62), 0.095, 0.0, 0.06, Color(0.5, 0.3, 0.25), Kit.TILE, 10)
	# coal heap, rails and a coal wagon
	k.dome(Vector3(0.58, y, 0.12), 0.14, Color(0.12, 0.11, 0.11), Kit.DARK, 0.6, 3, 7)
	for sx in [0.0, 1.0]:
		k.rod(Vector3(-0.78, y + 0.02, 0.5 + sx * 0.08), Vector3(0.78, y + 0.02, 0.5 + sx * 0.08), 0.008, IRON, Kit.PAINT)
	for i in 14:
		k.box(Vector3(-0.74 + i * 0.113, y, 0.54), Vector3(0.03, 0.015, 0.14), WOOD, Kit.TIMBER)
	k.box(Vector3(-0.3, y + 0.04, 0.54), Vector3(0.3, 0.1, 0.12), Color(0.35, 0.22, 0.15), Kit.TIMBER)
	k.dome(Vector3(-0.3, y + 0.14, 0.54), 0.1, Color(0.12, 0.11, 0.11), Kit.DARK, 0.5, 2, 6)
	for sx: float in [-0.1, 0.1]:
		for sz: float in [0.48, 0.6]:
			_disc_z(k, Vector3(-0.3 + sx, y + 0.045, sz), 0.035, 0.012, IRON, Kit.PAINT, 8)
	# bales and barrels at the door
	for i in 3:
		k.box(Vector3(hx + 0.27 + i * 0.09, y, zf + 0.12), Vector3(0.08, 0.06, 0.12), Color(0.85, 0.8, 0.65), Kit.CLOTH)
	k.box(Vector3(hx + 0.31, y + 0.06, zf + 0.12), Vector3(0.08, 0.06, 0.12), Color(0.82, 0.75, 0.6), Kit.CLOTH)
	_barrel(k, Vector3(hx - 0.28, y, zf + 0.12))
	_crate(k, Vector3(hx - 0.4, y, zf + 0.12), 0.08)
	k.banner(Vector3(-0.73, y, 0.1), 0.55, 0.2, 0.0)


# =============================================================================================
# watchtower (barracks): a palisaded training yard with a tower, racks and tents
# =============================================================================================


static func _palisade(k: Kit, a: Vector3, b: Vector3, step := 0.1) -> void:
	var n := int(a.distance_to(b) / step)
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		var h := 0.17 + 0.03 * float((i * 7) % 3)
		k.box(p - Vector3(0.0275, 0, 0.0275), Vector3(0.055, h, 0.055), Color(0.5 + 0.03 * (i % 2), 0.36, 0.22), Kit.TIMBER)
		k.frustum(p + Vector3(0, h, 0), 0.04, 0.0, 0.05, Color(0.5, 0.36, 0.22), Kit.TIMBER, 4)
	k.rod(a + Vector3(0, 0.1, 0), b + Vector3(0, 0.1, 0), 0.012, WOOD, Kit.TIMBER)


static func _barracks(k: Kit) -> void:
	_base(k, 1.56, 1.46, Color(0.60, 0.50, 0.36), Kit.EARTH)
	var y := G
	_palisade(k, Vector3(-0.74, y, -0.68), Vector3(0.74, y, -0.68), 0.115)
	_palisade(k, Vector3(-0.74, y, -0.68), Vector3(-0.74, y, 0.66), 0.115)
	_palisade(k, Vector3(0.74, y, -0.68), Vector3(0.74, y, 0.66), 0.115)
	_palisade(k, Vector3(-0.74, y, 0.66), Vector3(-0.22, y, 0.66), 0.115)
	_palisade(k, Vector3(0.22, y, 0.66), Vector3(0.74, y, 0.66), 0.115)
	# gate posts with crossbeam and banner
	for sx: float in [-0.2, 0.2]:
		k.box(Vector3(sx - 0.03, y, 0.64), Vector3(0.06, 0.46, 0.06), WOOD, Kit.TIMBER)
	k.box(Vector3(0, y + 0.42, 0.64), Vector3(0.5, 0.05, 0.06), WOOD, Kit.TIMBER)
	k.box(Vector3(-0.12, y + 0.28, 0.645), Vector3(0.1, 0.14, 0.01), OWNER_C, Kit.OWNER_CLOTH)
	k.box(Vector3(0.12, y + 0.28, 0.645), Vector3(0.1, 0.14, 0.01), OWNER_C, Kit.OWNER_CLOTH)
	# corner tower
	var tx := -0.5
	var tz := -0.44
	k.box(Vector3(tx, y, tz), Vector3(0.38, 0.38, 0.38), STONE_C, Kit.STONE)
	k.box(Vector3(tx, y + 0.38, tz), Vector3(0.46, 0.05, 0.46), WOOD, Kit.TIMBER)
	k.box(Vector3(tx, y + 0.43, tz), Vector3(0.4, 0.17, 0.4), Color(0.72, 0.56, 0.36), Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(tx + s * 0.19, y + 0.43, tz + 0.19), Vector3(0.025, 0.17, 0.025), WOOD, Kit.TIMBER)
		k.box(Vector3(tx + s * 0.19, y + 0.43, tz - 0.19), Vector3(0.025, 0.17, 0.025), WOOD, Kit.TIMBER)
	k.window(Vector3(tx, y + 0.52, tz + 0.2), 0.0, 0.08, 0.07, WOOD, "frame")
	k.window(Vector3(tx + 0.2, y + 0.52, tz), PI / 2.0, 0.08, 0.07, WOOD, "frame")
	k.hip_roof(Vector3(tx, y + 0.6, tz), 0.4, 0.4, 0.26, 0.07, 0.03, ROOF, Kit.OWNER_ROOF)
	k.window(Vector3(tx, y + 0.25, tz + 0.19), 0.0, 0.025, 0.1, STONE_D, "frame")
	k.window(Vector3(tx + 0.19, y + 0.25, tz), PI / 2.0, 0.025, 0.1, STONE_D, "frame")
	k.door(Vector3(tx + 0.1, y, tz + 0.19), 0.0, 0.1, 0.18, STONE_D)
	k.banner(Vector3(tx, y + 0.8, tz), 0.4, 0.22, 0.4)
	_ladder(k, Vector3(tx + 0.3, y, tz + 0.2), Vector3(tx + 0.3, y + 0.42, tz + 0.2), Vector3(0.0, 0, 0.0) + Vector3(0.03, 0, 0), 6)
	# tents
	_tent(k, Vector3(0.45, y, -0.45), 0.2, 0.4, 0.34, 0.26, Color(0.9, 0.85, 0.7))
	_tent(k, Vector3(0.1, y, -0.5), -0.1, 0.34, 0.3, 0.22, OWNER_C, Kit.OWNER_CLOTH)
	_tent(k, Vector3(0.52, y, -0.02), -0.3, 0.36, 0.3, 0.22, Color(0.9, 0.85, 0.7))
	k.banner(Vector3(0.45, y + 0.26, -0.45), 0.1, 0.1, 0.0)
	# training: dummy, archery butt, racks, fire, hay
	k.push(Kit.at(Vector3(-0.35, y, 0.15), 0.3))
	k.box(Vector3(-0.015, 0, -0.015), Vector3(0.03, 0.26, 0.03), WOOD, Kit.TIMBER)
	k.box(Vector3(-0.07, 0.16, -0.012), Vector3(0.14, 0.02, 0.024), WOOD, Kit.TIMBER)
	k.dome(Vector3(0, 0.26, 0), 0.03, Color(0.85, 0.75, 0.55), Kit.CLOTH, 1.0, 2, 6)
	_disc_z(k, Vector3(0.08, 0.15, 0.01), 0.04, 0.012, OWNER_C, Kit.OWNER_CLOTH, 8)
	k.rod(Vector3(-0.1, 0.17, 0.0), Vector3(-0.13, 0.28, 0.0), 0.007, IRON, Kit.PAINT)
	k.pop()
	_disc_z(k, Vector3(0.15, y + 0.15, 0.15), 0.1, 0.03, Color(0.9, 0.78, 0.4), Kit.THATCH, 10)
	_disc_z(k, Vector3(0.15, y + 0.15, 0.17), 0.065, 0.02, OWNER_C, Kit.OWNER_CLOTH, 10)
	_disc_z(k, Vector3(0.15, y + 0.15, 0.18), 0.03, 0.02, Color(0.9, 0.78, 0.4), Kit.THATCH, 8)
	k.rod(Vector3(0.1, y, 0.1), Vector3(0.15, y + 0.15, 0.14), 0.01, WOOD, Kit.TIMBER)
	k.rod(Vector3(0.2, y, 0.1), Vector3(0.15, y + 0.15, 0.14), 0.01, WOOD, Kit.TIMBER)
	for off: Vector3 in [Vector3(-0.62, 0, -0.1), Vector3(-0.62, 0, 0.4)]:
		k.push(Kit.at(Vector3(off.x, y, off.z), PI / 2.0))
		k.box(Vector3(-0.2, 0, 0), Vector3(0.025, 0.2, 0.025), WOOD, Kit.TIMBER)
		k.box(Vector3(0.2, 0, 0), Vector3(0.025, 0.2, 0.025), WOOD, Kit.TIMBER)
		k.rod(Vector3(-0.2, 0.18, 0), Vector3(0.2, 0.18, 0), 0.01, WOOD, Kit.TIMBER)
		k.rod(Vector3(-0.2, 0.08, 0), Vector3(0.2, 0.08, 0), 0.01, WOOD, Kit.TIMBER)
		for i in 6:
			var x := -0.16 + i * 0.065
			k.rod(Vector3(x, 0.0, 0.05), Vector3(x, 0.34, 0.02), 0.006, WOODL, Kit.TIMBER)
			k.tri(Vector3(x - 0.012, 0.34, 0.02), Vector3(x + 0.012, 0.34, 0.02), Vector3(x, 0.4, 0.02), IRON, Kit.PAINT, Vector3(x, 0.3, 0.0))
		k.pop()
	# campfire and hay
	for i in 6:
		var a := i * TAU / 6.0
		k.box(Vector3(0.38 + cos(a) * 0.06 - 0.015, y, 0.4 + sin(a) * 0.06 - 0.015), Vector3(0.03, 0.025, 0.03), STONE_D, Kit.STONE)
	k.frustum(Vector3(0.38, y, 0.4), 0.04, 0.0, 0.07, Color(1.0, 0.55, 0.15), Kit.GOLD, 5)
	k.frustum(Vector3(0.38, y, 0.4), 0.02, 0.0, 0.1, Color(1.0, 0.8, 0.3), Kit.GOLD, 4)
	for i in 3:
		k.box(Vector3(-0.1 + i * 0.12, y, 0.5), Vector3(0.1, 0.06, 0.07), Color(0.88, 0.76, 0.4), Kit.THATCH, 0.1 * i)
	k.box(Vector3(-0.04, y + 0.06, 0.5), Vector3(0.1, 0.06, 0.07), Color(0.88, 0.76, 0.4), Kit.THATCH)
	_barrel(k, Vector3(0.6, y, 0.45))
	_barrel(k, Vector3(0.52, y, 0.52), 0.045, 0.08)


# =============================================================================================
# mine: a timber headframe with winding wheels, shed, spoil heap, rails and ore cart
# =============================================================================================


static func _mine(k: Kit) -> void:
	_base(k, 1.56, 1.46, Color(0.45, 0.40, 0.34), Kit.EARTH)
	var y := G
	var hx := -0.15
	var hz := 0.0
	var top := 1.0
	# shaft collar
	k.box(Vector3(hx, y, hz), Vector3(0.3, 0.05, 0.3), WOOD, Kit.TIMBER)
	k.box(Vector3(hx, y + 0.05, hz), Vector3(0.18, 0.004, 0.18), SOOT, Kit.DARK)
	# the four legs of the headframe, braced
	var legs: Array = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var bot := Vector3(hx + sx * 0.22, y, hz + sz * 0.22)
			var tp := Vector3(hx + sx * 0.07, y + top, hz + sz * 0.03)
			k.rod(bot, tp, 0.022, WOOD, Kit.TIMBER)
			legs.append([bot, tp])
	for t: float in [0.25, 0.5, 0.75]:
		for i in 4:
			var j: int = [1, 3, 0, 2][i]
			var a: Array = legs[i]
			var b: Array = legs[j]
			var pa := (a[0] as Vector3).lerp(a[1] as Vector3, t)
			var pb := (b[0] as Vector3).lerp(b[1] as Vector3, t)
			if i < j:
				k.rod(pa, pb, 0.011, WOODL, Kit.TIMBER)
	for t: float in [0.0, 0.25, 0.5]:   # diagonals on the side faces
		var a: Array = legs[0]
		var b: Array = legs[1]
		var pa := (a[0] as Vector3).lerp(a[1] as Vector3, t)
		var pb := (b[0] as Vector3).lerp(b[1] as Vector3, t + 0.25)
		k.rod(pa, pb, 0.009, WOODL, Kit.TIMBER)
		var c: Array = legs[2]
		var d: Array = legs[3]
		k.rod((c[0] as Vector3).lerp(c[1] as Vector3, t), (d[0] as Vector3).lerp(d[1] as Vector3, t + 0.25), 0.009, WOODL, Kit.TIMBER)
	# winding wheels and cable
	k.box(Vector3(hx - 0.14, y + top, hz - 0.02), Vector3(0.28, 0.03, 0.05), WOOD, Kit.TIMBER)
	k.rod(Vector3(hx - 0.14, y + top + 0.04, hz), Vector3(hx + 0.14, y + top + 0.04, hz), 0.012, IRON, Kit.PAINT)
	for sx: float in [-0.08, 0.08]:
		_disc_x(k, Vector3(hx + sx, y + top + 0.04, hz), 0.12, 0.025, Color(0.5, 0.36, 0.2), Kit.TIMBER, 12)
		_disc_x(k, Vector3(hx + sx, y + top + 0.04, hz), 0.035, 0.04, GOLD_C, Kit.GOLD, 8)
		for i in 4:
			var a := i * PI / 4.0
			k.rod(Vector3(hx + sx, y + top + 0.04 + cos(a) * 0.12, hz + sin(a) * 0.12), Vector3(hx + sx, y + top + 0.04 - cos(a) * 0.12, hz - sin(a) * 0.12), 0.006, WOOD, Kit.TIMBER)
	k.rod(Vector3(hx, y + top - 0.07, hz), Vector3(hx, y + 0.05, hz), 0.004, SOOT, Kit.DARK)
	k.box(Vector3(hx - 0.03, y + 0.25, hz - 0.03), Vector3(0.06, 0.04, 0.06), WOODL, Kit.TIMBER)   # the bucket
	k.rod(Vector3(hx + 0.07, y + top + 0.1, hz), Vector3(hx + 0.07, y + top + 0.2, hz), 0.006, WOOD, Kit.TIMBER)
	k.banner(Vector3(hx, y + top + 0.03, hz + 0.03), 0.22, 0.15, 0.0)
	# hoist shed with a soot-stained chimney
	var sx2 := 0.45
	var sz2 := 0.35
	k.box(Vector3(sx2, y, sz2), Vector3(0.42, 0.26, 0.34), Color(0.78, 0.7, 0.58), Kit.TIMBER)
	for i in 4:
		k.box(Vector3(sx2 - 0.2 + i * 0.133, y, sz2 + 0.172), Vector3(0.025, 0.26, 0.015), WOOD, Kit.TIMBER)
	k.door(Vector3(sx2, y, sz2 + 0.17), 0.0, 0.12, 0.2, WOOD)
	k.gable_roof(Vector3(sx2, y + 0.26, sz2), 0.42, 0.34, 0.16, 0.06, 0.03, ROOF, Kit.OWNER_ROOF, Color(0.78, 0.7, 0.58), Kit.TIMBER)
	_stack(k, Vector3(sx2 + 0.12, y + 0.3, sz2 - 0.05), 0.04, 0.032, 0.3, STONE_D, Kit.STONE, 5)
	k.window(Vector3(sx2 - 0.14, y + 0.17, sz2 + 0.172), 0.0, 0.06, 0.07, WOOD, "frame")
	# spoil heap and the dark adit
	k.frustum(Vector3(-0.2, y, -0.55), 0.52, 0.3, 0.2, Color(0.50, 0.44, 0.38), Kit.EARTH, 7)
	k.frustum(Vector3(-0.28, y + 0.19, -0.57), 0.3, 0.12, 0.17, Color(0.42, 0.37, 0.33), Kit.STONE, 6)
	k.frustum(Vector3(0.4, y, -0.55), 0.3, 0.14, 0.14, Color(0.55, 0.48, 0.4), Kit.EARTH, 6)
	for i in 6:
		k.box(Vector3(-0.5 + i * 0.12, y + 0.07 + (i % 3) * 0.05, -0.3), Vector3(0.07, 0.05, 0.06), STONE_D, Kit.STONE, i * 0.8)
	k.box(Vector3(0.26, y + 0.02, -0.55), Vector3(0.015, 0.015, 0.04), GOLD_C, Kit.GOLD, 0.6)
	k.box(Vector3(0.04, y, -0.34), Vector3(0.2, 0.17, 0.05), SOOT, Kit.DARK)
	for sx: float in [-0.11, 0.11]:
		k.box(Vector3(0.04 + sx, y, -0.31), Vector3(0.035, 0.2, 0.04), WOOD, Kit.TIMBER)
	k.box(Vector3(0.04, y + 0.18, -0.31), Vector3(0.28, 0.035, 0.05), WOOD, Kit.TIMBER)
	# rails from adit to the heap and an ore cart
	for s: float in [-0.04, 0.04]:
		k.rod(Vector3(0.04 + s, y + 0.01, -0.3), Vector3(0.04 + s * 1.0 + 0.1, y + 0.01, 0.5), 0.007, IRON, Kit.PAINT)
	for i in 11:
		var t := i / 10.0
		k.box(Vector3(0.04 + 0.1 * t, y, -0.3 + t * 0.9), Vector3(0.14, 0.012, 0.025), WOOD, Kit.TIMBER)
	k.push(Kit.at(Vector3(0.1, y + 0.02, 0.2), 0.1))
	k.box(Vector3(0, 0.03, 0), Vector3(0.14, 0.09, 0.17), Color(0.42, 0.3, 0.2), Kit.TIMBER)
	k.box(Vector3(0, 0.12, 0), Vector3(0.15, 0.015, 0.18), IRON, Kit.PAINT)
	k.dome(Vector3(0, 0.12, 0), 0.075, Color(0.3, 0.28, 0.3), Kit.STONE, 0.7, 2, 6)
	k.box(Vector3(0.02, 0.15, 0.01), Vector3(0.025, 0.02, 0.025), GOLD_C, Kit.GOLD)
	for sx: float in [-0.08, 0.08]:
		for sz: float in [-0.06, 0.06]:
			_disc_x(k, Vector3(sx, 0.025, sz), 0.028, 0.012, IRON, Kit.PAINT, 8)
	k.pop()
	# tools, lantern, barrels, timber props
	k.rod(Vector3(-0.6, y, 0.25), Vector3(-0.5, y + 0.32, 0.25), 0.01, WOOD, Kit.TIMBER)
	k.box(Vector3(-0.56, y + 0.26, 0.24), Vector3(0.12, 0.025, 0.02), IRON, Kit.PAINT)
	k.rod(Vector3(-0.68, y, 0.35), Vector3(-0.6, y + 0.3, 0.3), 0.01, WOOD, Kit.TIMBER)
	k.box(Vector3(-0.66, y + 0.28, 0.285), Vector3(0.1, 0.02, 0.02), IRON, Kit.PAINT)
	k.box(Vector3(-0.35, y, 0.5), Vector3(0.02, 0.18, 0.02), WOOD, Kit.TIMBER)
	k.box(Vector3(-0.375, y + 0.18, 0.5), Vector3(0.07, 0.07, 0.05), GOLD_C, Kit.GOLD)
	_barrel(k, Vector3(0.7, y, -0.1))
	_crate(k, Vector3(-0.55, y, 0.55), 0.09, 0.3)
	_logs(k, Vector3(-0.6, y, -0.0), PI / 2.0, 3)


# =============================================================================================
# school: a schoolhouse with a bell cupola and a fenced courtyard
# =============================================================================================


static func _school(k: Kit) -> void:
	_base(k, 1.52, 1.5, Color(0.66, 0.62, 0.48), Kit.EARTH)
	var y := G
	var hz := -0.32
	k.box(Vector3(0, y, hz), Vector3(0.96, 0.05, 0.54), STONE_D, Kit.STONE)
	k.box(Vector3(0, y + 0.05, hz), Vector3(0.92, 0.36, 0.5), PLASTER, Kit.PLASTER)
	for x: float in [-0.46, -0.15, 0.15, 0.46]:
		k.box(Vector3(x - 0.015, y + 0.05, hz + 0.24), Vector3(0.03, 0.36, 0.03), WOOD, Kit.TIMBER)
	k.box(Vector3(0, y + 0.37, hz + 0.255), Vector3(0.96, 0.03, 0.03), WOOD, Kit.TIMBER)
	for x: float in [-0.32, 0.32]:
		k.window(Vector3(x, y + 0.26, hz + 0.25), 0.0, 0.1, 0.16, WOOD, "arch")
	k.door(Vector3(0, y + 0.05, hz + 0.25), 0.0, 0.14, 0.26, WOOD)
	for s: float in [-1.0, 1.0]:
		k.window(Vector3(s * 0.46, y + 0.26, hz), s * PI / 2.0, 0.1, 0.16, WOOD, "arch")
	k.gable_roof(Vector3(0, y + 0.41, hz), 0.92, 0.5, 0.27, 0.08, 0.035, ROOF, Kit.OWNER_ROOF, PLASTER, Kit.PLASTER)
	# bell cupola
	var by := y + 0.41 + 0.27
	for sx: float in [-0.05, 0.05]:
		for sz: float in [-0.05, 0.05]:
			k.box(Vector3(sx - 0.01, by, hz + sz - 0.01), Vector3(0.02, 0.14, 0.02), WOOD, Kit.TIMBER)
	k.rod(Vector3(-0.05, by + 0.1, hz), Vector3(0.05, by + 0.1, hz), 0.01, WOOD, Kit.TIMBER)
	k.frustum(Vector3(0, by + 0.04, hz), 0.045, 0.02, 0.07, GOLD_C, Kit.GOLD, 8)
	k.hip_roof(Vector3(0, by + 0.14, hz), 0.14, 0.14, 0.12, 0.03, 0.02, ROOF, Kit.OWNER_ROOF)
	k.box(Vector3(0, by + 0.26, hz), Vector3(0.015, 0.06, 0.015), GOLD_C, Kit.GOLD)
	# a library wing
	k.box(Vector3(-0.68, y, hz - 0.02), Vector3(0.34, 0.3, 0.38), PLASTER, Kit.PLASTER)
	k.gable_roof(Vector3(-0.68, y + 0.3, hz - 0.02), 0.38, 0.34, 0.2, 0.06, 0.03, ROOF, Kit.OWNER_ROOF, PLASTER, Kit.PLASTER, PI / 2.0)
	k.window(Vector3(-0.68, y + 0.2, hz + 0.17), 0.0, 0.08, 0.12, WOOD, "arch")
	k.chimney(Vector3(-0.8, y + 0.4, hz - 0.1), 0.05, 0.2, STONE_D)
	# courtyard wall with a gate, tree, benches, globe, flag
	var wz := 0.7
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.45, y, wz), Vector3(0.62, 0.07, 0.04), STONE_C, Kit.STONE)
		k.box(Vector3(s * 0.72, y, 0.2), Vector3(0.04, 0.07, 1.0), STONE_C, Kit.STONE)
		k.box(Vector3(s * 0.16, y, wz), Vector3(0.06, 0.16, 0.06), STONE_C, Kit.STONE)
		k.box(Vector3(s * 0.16, y + 0.16, wz), Vector3(0.08, 0.03, 0.08), STONE_D, Kit.STONE)
	k.box(Vector3(0, y + 0.13, wz), Vector3(0.3, 0.025, 0.025), WOOD, Kit.TIMBER)
	_tree(k, Vector3(-0.5, y, 0.42), 1.3)
	for s: float in [-0.15, 0.15]:   # benches and desks
		k.box(Vector3(s * 2.0 + 0.0, y + 0.05, 0.18), Vector3(0.22, 0.02, 0.07), WOODL, Kit.TIMBER)
		k.box(Vector3(s * 2.0 - 0.09, y, 0.18), Vector3(0.02, 0.05, 0.06), WOOD, Kit.TIMBER)
		k.box(Vector3(s * 2.0 + 0.09, y, 0.18), Vector3(0.02, 0.05, 0.06), WOOD, Kit.TIMBER)
		k.box(Vector3(s * 2.0, y + 0.07, 0.31), Vector3(0.22, 0.02, 0.07), WOODL, Kit.TIMBER)
		k.box(Vector3(s * 2.0 - 0.09, y, 0.31), Vector3(0.02, 0.07, 0.06), WOOD, Kit.TIMBER)
		k.box(Vector3(s * 2.0 + 0.09, y, 0.31), Vector3(0.02, 0.07, 0.06), WOOD, Kit.TIMBER)
	k.box(Vector3(0.4, y, 0.5), Vector3(0.04, 0.12, 0.04), STONE_C, Kit.STONE)
	k.dome(Vector3(0.4, y + 0.12, 0.5), 0.06, Color(0.35, 0.55, 0.7), Kit.PAINT, 1.0, 3, 8)
	_ring(k, Vector3(0.4, y + 0.18, 0.5), Vector3(1, 0, 0), Vector3(0, 1, 0), 0.075, 10, 0.004, GOLD_C, Kit.GOLD)
	k.banner(Vector3(0.56, y, 0.62), 0.6, 0.22, PI)
	k.box(Vector3(-0.1, y, 0.05), Vector3(0.2, 0.004, 0.2), Color(0.55, 0.62, 0.42), Kit.LEAF)   # a patch of grass


# =============================================================================================
# academy: a grand college round a cloister court, domed gate tower
# =============================================================================================


static func _academy(k: Kit) -> void:
	_base(k, 1.6, 1.6, Color(0.70, 0.66, 0.58), Kit.STONE)
	var y := G
	var wall := Color(0.86, 0.82, 0.72)
	var rc := Color(0.70, 0.40, 0.28)
	# back range
	k.box(Vector3(0, y, -0.62), Vector3(1.5, 0.44, 0.32), wall, Kit.PLASTER)
	k.gable_roof(Vector3(0, y + 0.44, -0.62), 1.5, 0.32, 0.22, 0.05, 0.03, rc, Kit.OWNER_ROOF, wall, Kit.PLASTER)
	for x in 6:
		k.window(Vector3(-0.62 + x * 0.248, y + 0.3, -0.455), PI, 0.07, 0.16, STONE_C, "frame")
	# side ranges
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.66, y, -0.04), Vector3(0.28, 0.4, 0.92), wall, Kit.PLASTER)
		k.gable_roof(Vector3(s * 0.66, y + 0.4, -0.04), 0.92, 0.28, 0.18, 0.05, 0.03, rc, Kit.OWNER_ROOF, wall, Kit.PLASTER, PI / 2.0)
		for z in 4:
			k.window(Vector3(s * 0.8, y + 0.27, -0.34 + z * 0.24), s * PI / 2.0, 0.065, 0.14, STONE_C, "frame")
	# front range with the gate tower
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.46, y, 0.58), Vector3(0.54, 0.34, 0.3), wall, Kit.PLASTER)
		k.gable_roof(Vector3(s * 0.46, y + 0.34, 0.58), 0.54, 0.3, 0.15, 0.05, 0.03, rc, Kit.OWNER_ROOF, wall, Kit.PLASTER)
		k.window(Vector3(s * 0.36, y + 0.27, 0.735), 0.0, 0.07, 0.15, STONE_C, "frame")
		k.window(Vector3(s * 0.58, y + 0.27, 0.735), 0.0, 0.07, 0.15, STONE_C, "frame")
	k.box(Vector3(0, y, 0.58), Vector3(0.4, 0.78, 0.36), STONE_C, Kit.STONE)
	k.door(Vector3(0, y, 0.76), 0.0, 0.17, 0.28, STONE_D, Color(0.3, 0.19, 0.11))
	k.window(Vector3(0, y + 0.5, 0.765), 0.0, 0.1, 0.16, STONE_D, "arch")
	_clock(k, Vector3(0, y + 0.66, 0.765), 0.0, 0.055)
	k.box(Vector3(0, y + 0.78, 0.58), Vector3(0.46, 0.04, 0.42), STONE_D, Kit.STONE)
	k.box(Vector3(0, y + 0.82, 0.58), Vector3(0.3, 0.16, 0.3), STONE_C, Kit.STONE)
	for s: float in [-1.0, 1.0]:
		k.window(Vector3(s * 0.1, y + 0.9, 0.735), 0.0, 0.05, 0.1, STONE_D, "arch")
	k.dome(Vector3(0, y + 0.98, 0.58), 0.18, Color(0.78, 0.4, 0.28), Kit.OWNER_ROOF, 0.85, 5, 12)
	k.frustum(Vector3(0, y + 1.13, 0.58), 0.03, 0.03, 0.08, STONE_C, Kit.STONE, 6)
	k.dome(Vector3(0, y + 1.2, 0.58), 0.035, GOLD_C, Kit.GOLD, 1.0, 2, 6)
	k.rod(Vector3(0, y + 1.23, 0.58), Vector3(0, y + 1.34, 0.58), 0.006, GOLD_C, Kit.GOLD)
	# four corner turrets
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(sx * 0.69, y, sz * 0.69)
			k.frustum(p, 0.1, 0.09, 0.62, STONE_C, Kit.STONE, 8, false)
			k.frustum(p + Vector3(0, 0.62, 0), 0.115, 0.115, 0.04, STONE_D, Kit.STONE, 8)
			k.frustum(p + Vector3(0, 0.66, 0), 0.12, 0.0, 0.2, Color(0.78, 0.4, 0.28), Kit.OWNER_ROOF, 8)
			k.window(Vector3(p.x - sx * 0.01 + 0.0, y + 0.46, p.z + sz * 0.09), 0.0 if sz > 0 else PI, 0.025, 0.07, STONE_D, "frame")
	# court: cloister columns, lawn, fountain
	k.box(Vector3(0, y, 0.0), Vector3(0.88, 0.012, 0.78), Color(0.45, 0.62, 0.32), Kit.LEAF)
	k.box(Vector3(0, y + 0.012, 0.0), Vector3(0.12, 0.004, 0.78), Color(0.8, 0.76, 0.68), Kit.STONE)
	k.box(Vector3(0, y + 0.012, 0.0), Vector3(0.88, 0.004, 0.12), Color(0.8, 0.76, 0.68), Kit.STONE)
	for i in 8:
		k.box(Vector3(-0.49 - 0.012, y, -0.34 + i * 0.1 - 0.012), Vector3(0.024, 0.19, 0.024), Color(0.92, 0.9, 0.84), Kit.PAINT)
		k.box(Vector3(0.49 - 0.012, y, -0.34 + i * 0.1 - 0.012), Vector3(0.024, 0.19, 0.024), Color(0.92, 0.9, 0.84), Kit.PAINT)
	k.box(Vector3(-0.49, y + 0.19, 0.0), Vector3(0.03, 0.025, 0.74), STONE_C, Kit.STONE)
	k.box(Vector3(0.49, y + 0.19, 0.0), Vector3(0.03, 0.025, 0.74), STONE_C, Kit.STONE)
	k.frustum(Vector3(0, y, 0), 0.1, 0.1, 0.05, STONE_C, Kit.STONE, 10)
	k.frustum(Vector3(0, y + 0.045, 0), 0.08, 0.08, 0.012, WATER_C, Kit.WATER, 10)
	k.frustum(Vector3(0, y + 0.05, 0), 0.02, 0.012, 0.1, STONE_C, Kit.STONE, 6)
	k.dome(Vector3(0, y + 0.15, 0), 0.04, WATER_C, Kit.WATER, 0.4, 2, 6)
	for s: float in [-1.0, 1.0]:
		_tree(k, Vector3(s * 0.28, y, 0.22), 0.8)
		k.box(Vector3(s * 0.28 - 0.06, y, -0.2), Vector3(0.14, 0.04, 0.05), WOODL, Kit.TIMBER)
	k.banner(Vector3(0.0, y + 0.82, 0.74), 0.2, 0.0)


# =============================================================================================
# observatory: a round stone tower with a slitted dome, telescope and armillary sphere
# =============================================================================================


static func _observatory(k: Kit) -> void:
	_base(k, 1.56, 1.5, Color(0.66, 0.62, 0.52), Kit.STONE)
	var y := G
	k.frustum(Vector3(0, y, 0), 0.68, 0.64, 0.06, STONE_C, Kit.STONE, 16)
	y += 0.06
	k.frustum(Vector3(0, y, 0), 0.37, 0.3, 0.85, Color(0.80, 0.76, 0.68), Kit.STONE, 14, false)
	for h: float in [0.28, 0.58]:
		var rr := 0.37 - 0.07 * h / 0.85
		k.frustum(Vector3(0, y + h, 0), rr + 0.012, rr + 0.012, 0.025, STONE_D, Kit.STONE, 14, false)
	for a: float in [-1.0, -0.5, 0.55, 1.05, 2.3, 3.6, 5.0]:   # tall slit windows spiralling up
		var h := 0.18 + fposmod(a * 1.7, 1.0) * 0.5
		var rr := 0.37 - 0.07 * h / 0.85
		k.window(Vector3(sin(a) * (rr - 0.006), y + h, cos(a) * (rr - 0.006)), a, 0.04, 0.12, STONE_D, "arch")
	# porch with door
	k.box(Vector3(0, y, 0.37), Vector3(0.24, 0.24, 0.1), STONE_C, Kit.STONE)
	k.gable_roof(Vector3(0, y + 0.24, 0.37), 0.24, 0.1, 0.07, 0.03, 0.02, ROOF, Kit.OWNER_ROOF, STONE_C, Kit.STONE, PI / 2.0)
	k.door(Vector3(0, y, 0.425), 0.0, 0.1, 0.18, STONE_D)
	# balcony
	k.frustum(Vector3(0, y + 0.85, 0), 0.42, 0.4, 0.04, STONE_D, Kit.STONE, 14)
	for i in 14:
		var a := i * TAU / 14.0
		k.box(Vector3(cos(a) * 0.4 - 0.008, y + 0.89, sin(a) * 0.4 - 0.008), Vector3(0.016, 0.07, 0.016), STONE_C, Kit.STONE)
	_ring(k, Vector3(0, y + 0.95, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), 0.4, 14, 0.008, STONE_C, Kit.STONE)
	# dome with a slit
	k.frustum(Vector3(0, y + 0.89, 0), 0.31, 0.31, 0.06, STONE_C, Kit.STONE, 14)
	var dy := y + 0.95
	var dr := 0.32
	var sq := 0.85
	k.dome(Vector3(0, dy, 0), dr, Color(0.78, 0.42, 0.30), Kit.OWNER_ROOF, sq, 6, 14)
	var seg := 6
	for i in seg:
		var e0 := i * 1.38 / seg
		var e1 := (i + 1) * 1.38 / seg
		var r0 := cos(e0) * dr * 1.012
		var r1 := cos(e1) * dr * 1.012
		var w := 0.034
		var za := sqrt(maxf(r0 * r0 - w * w, 0.0))
		var zb := sqrt(maxf(r1 * r1 - w * w, 0.0))
		k.quad(Vector3(-w, dy + sin(e0) * dr * sq, za), Vector3(w, dy + sin(e0) * dr * sq, za),
			Vector3(w, dy + sin(e1) * dr * sq, zb), Vector3(-w, dy + sin(e1) * dr * sq, zb), SOOT, Kit.DARK, Vector3(0, dy + 0.1, 0))
	k.rod(Vector3(0, dy + 0.12, 0.16), Vector3(0, dy + 0.3, 0.42), 0.02, GOLD_C, Kit.GOLD)
	k.rod(Vector3(0, dy + 0.3, 0.42), Vector3(0, dy + 0.32, 0.46), 0.026, Color(0.5, 0.42, 0.2), Kit.GOLD)
	k.dome(Vector3(0, dy + dr * sq - 0.01, 0), 0.04, GOLD_C, Kit.GOLD, 1.0, 2, 6)
	k.rod(Vector3(0, dy + dr * sq + 0.03, 0), Vector3(0, dy + dr * sq + 0.14, 0), 0.006, GOLD_C, Kit.GOLD)
	# armillary sphere on a pedestal
	var ap := Vector3(0.58, G, 0.5)
	k.box(ap + Vector3(-0.07, 0, -0.07), Vector3(0.14, 0.05, 0.14), STONE_C, Kit.STONE)
	k.frustum(ap + Vector3(0, 0.05, 0), 0.04, 0.03, 0.12, STONE_C, Kit.STONE, 8)
	k.box(ap + Vector3(-0.05, 0.17, -0.05), Vector3(0.1, 0.02, 0.1), STONE_D, Kit.STONE)
	var ac := ap + Vector3(0, 0.32, 0)
	_ring(k, ac, Vector3(1, 0, 0), Vector3(0, 1, 0), 0.12, 14, 0.006, GOLD_C, Kit.GOLD)
	_ring(k, ac, Vector3(0, 0, 1), Vector3(0, 1, 0), 0.12, 14, 0.006, GOLD_C, Kit.GOLD)
	_ring(k, ac, Vector3(1, 0, 0), Vector3(0, 0.34, 0.94).normalized(), 0.12, 14, 0.006, Color(0.8, 0.6, 0.2), Kit.GOLD)
	k.rod(ac + Vector3(0, -0.15, -0.06), ac + Vector3(0, 0.15, 0.06), 0.005, GOLD_C, Kit.GOLD)
	k.dome(ac - Vector3(0, 0.02, 0), 0.03, Color(0.35, 0.5, 0.75), Kit.PAINT, 1.0, 3, 8)
	# sundial
	k.frustum(Vector3(-0.6, G, 0.5), 0.1, 0.1, 0.035, STONE_C, Kit.STONE, 10)
	k.tri(Vector3(-0.6, G + 0.035, 0.5), Vector3(-0.6, G + 0.035, 0.42), Vector3(-0.6, G + 0.11, 0.42), GOLD_C, Kit.GOLD, Vector3(-0.58, G + 0.05, 0.45))
	k.tri(Vector3(-0.6, G + 0.035, 0.5), Vector3(-0.6, G + 0.035, 0.42), Vector3(-0.6, G + 0.11, 0.42), GOLD_C, Kit.GOLD, Vector3(-0.62, G + 0.05, 0.45))
	# an annex and a telescope on a tripod
	k.box(Vector3(-0.58, G, -0.4), Vector3(0.42, 0.28, 0.38), PLASTER, Kit.PLASTER)
	k.hip_roof(Vector3(-0.58, G + 0.28, -0.4), 0.42, 0.38, 0.14, 0.05, 0.03, ROOF, Kit.OWNER_ROOF)
	k.window(Vector3(-0.58, G + 0.18, -0.21), PI, 0.07, 0.1, WOOD, "frame")
	k.door(Vector3(-0.58, G, -0.21 + 0.4), 0.0, 0.1, 0.18, WOOD)
	for s: float in [-1.0, 1.0]:
		k.rod(Vector3(0.45 + s * 0.05, G, -0.5), Vector3(0.45, G + 0.18, -0.5), 0.008, WOOD, Kit.TIMBER)
	k.rod(Vector3(0.45, G, -0.55), Vector3(0.45, G + 0.18, -0.5), 0.008, WOOD, Kit.TIMBER)
	k.rod(Vector3(0.45, G + 0.18, -0.5), Vector3(0.52, G + 0.34, -0.42), 0.014, GOLD_C, Kit.GOLD)
	k.banner(Vector3(0.6, G, -0.6), 0.55, 0.2, PI)


# =============================================================================================
# forge: a smithy with a big hearth and chimney, anvil under an open shed
# =============================================================================================


static func _forge(k: Kit) -> void:
	_base(k, 1.5, 1.35, Color(0.40, 0.37, 0.34), Kit.EARTH)
	var y := G
	var hx := -0.1
	# hearth wall and big chimney
	k.box(Vector3(hx, y, -0.3), Vector3(0.7, 0.34, 0.3), STONE_D, Kit.STONE)
	k.box(Vector3(hx, y + 0.34, -0.3), Vector3(0.32, 0.4, 0.24), STONE_D, Kit.STONE)
	k.box(Vector3(hx, y + 0.74, -0.3), Vector3(0.2, 0.36, 0.17), STONE_C, Kit.STONE)
	k.box(Vector3(hx, y + 1.1, -0.3), Vector3(0.26, 0.05, 0.22), STONE_D, Kit.STONE)
	k.box(Vector3(hx, y + 1.15, -0.3), Vector3(0.2, 0.012, 0.16), SOOT, Kit.DARK)
	for p in [Vector3(hx, y + 1.22, -0.3), Vector3(hx + 0.05, y + 1.36, -0.27)]:
		var pp: Vector3 = p
		k.dome(pp, 0.08, Color(0.55, 0.55, 0.57), Kit.CLOTH, 1.0, 3, 8)
	# the hearth mouth: black opening, glowing coals
	k.box(Vector3(hx, y + 0.06, -0.147), Vector3(0.3, 0.2, 0.012), SOOT, Kit.DARK)
	k.box(Vector3(hx, y + 0.06, -0.139), Vector3(0.26, 0.06, 0.012), Color(1.0, 0.4, 0.08), Kit.GOLD)
	k.box(Vector3(hx - 0.03, y + 0.1, -0.137), Vector3(0.12, 0.05, 0.012), Color(1.0, 0.8, 0.3), Kit.GOLD)
	k.box(Vector3(hx, y + 0.26, -0.15), Vector3(0.36, 0.04, 0.03), STONE_C, Kit.STONE)
	k.wedge(Vector3(hx, y + 0.3, -0.19), 0.34, 0.16, 0.1, STONE_C, Kit.STONE)
	k.box(Vector3(hx, y + 0.06, -0.12), Vector3(0.36, 0.04, 0.05), STONE_C, Kit.STONE)
	# open shed round it
	for sx: float in [-0.42, 0.4]:
		k.box(Vector3(hx + sx, y, 0.25), Vector3(0.045, 0.62, 0.045), WOOD, Kit.TIMBER)
		k.box(Vector3(hx + sx, y, -0.12), Vector3(0.045, 0.62, 0.045), WOOD, Kit.TIMBER)
	k.box(Vector3(hx, y + 0.62, 0.25), Vector3(0.9, 0.04, 0.05), WOOD, Kit.TIMBER)
	k.gable_roof(Vector3(hx, y + 0.66, 0.07), 0.86, 0.5, 0.17, 0.05, 0.035, Color(0.62, 0.34, 0.26), Kit.OWNER_ROOF, Color(0.3, 0.26, 0.24), Kit.TIMBER)
	k.rod(Vector3(hx - 0.42, y + 0.5, 0.25), Vector3(hx - 0.3, y + 0.62, 0.25), 0.014, WOOD, Kit.TIMBER)
	k.rod(Vector3(hx + 0.4, y + 0.5, 0.25), Vector3(hx + 0.3, y + 0.62, 0.25), 0.014, WOOD, Kit.TIMBER)
	# anvil on a stump
	k.frustum(Vector3(hx - 0.02, y, 0.08), 0.065, 0.06, 0.1, WOOD, Kit.TIMBER, 8)
	k.box(Vector3(hx - 0.02, y + 0.1, 0.08), Vector3(0.1, 0.02, 0.07), IRON, Kit.PAINT)
	k.box(Vector3(hx - 0.02, y + 0.12, 0.08), Vector3(0.06, 0.03, 0.045), IRON, Kit.PAINT)
	k.box(Vector3(hx - 0.02, y + 0.15, 0.08), Vector3(0.15, 0.03, 0.055), Color(0.3, 0.3, 0.33), Kit.PAINT)
	k.wedge(Vector3(hx + 0.08, y + 0.15, 0.08), 0.06, 0.05, -0.0001, IRON, Kit.PAINT)
	k.rod(Vector3(hx + 0.01, y + 0.185, 0.09), Vector3(hx + 0.07, y + 0.19, 0.12), 0.008, WOOD, Kit.TIMBER)
	k.box(Vector3(hx + 0.07, y + 0.185, 0.115), Vector3(0.03, 0.025, 0.02), IRON, Kit.PAINT)
	# bellows, quench tub, tongs rack
	k.wedge(Vector3(hx - 0.42, y + 0.1, -0.17), 0.14, 0.12, 0.1, Color(0.5, 0.35, 0.22), Kit.CLOTH, PI / 2.0)
	k.rod(Vector3(hx - 0.37, y + 0.1, -0.17), Vector3(hx - 0.22, y + 0.07, -0.15), 0.012, IRON, Kit.PAINT)
	k.box(Vector3(hx - 0.46, y, -0.2), Vector3(0.05, 0.1, 0.05), WOOD, Kit.TIMBER)
	k.frustum(Vector3(hx + 0.28, y, 0.03), 0.07, 0.065, 0.1, WOOD, Kit.TIMBER, 9)
	k.frustum(Vector3(hx + 0.28, y + 0.09, 0.03), 0.06, 0.06, 0.012, WATER_C, Kit.WATER, 9)
	for i in 4:
		k.rod(Vector3(hx + 0.2 + i * 0.05, y + 0.32, -0.145), Vector3(hx + 0.2 + i * 0.05, y + 0.2, -0.145), 0.006, IRON, Kit.PAINT)
	k.rod(Vector3(hx + 0.17, y + 0.33, -0.145), Vector3(hx + 0.37, y + 0.33, -0.145), 0.006, WOOD, Kit.TIMBER)
	# yard: charcoal, ingots, swords, grindstone, barrels, a horseshoe sign
	k.dome(Vector3(0.58, y, -0.35), 0.17, Color(0.1, 0.09, 0.09), Kit.DARK, 0.6, 3, 8)
	k.dome(Vector3(0.64, y, -0.15), 0.1, Color(0.12, 0.1, 0.1), Kit.DARK, 0.6, 2, 7)
	for i in 3:
		for j in 2 - (i % 2):
			k.box(Vector3(0.45 + j * 0.07 - 0.03, y + i * 0.025, 0.4), Vector3(0.06, 0.025, 0.035), Color(0.55, 0.55, 0.6), Kit.PAINT)
	k.box(Vector3(-0.6, y, 0.35), Vector3(0.18, 0.06, 0.05), WOOD, Kit.TIMBER)
	for i in 3:
		k.rod(Vector3(-0.66 + i * 0.06, y + 0.06, 0.35), Vector3(-0.66 + i * 0.06 - 0.01, y + 0.3, 0.33), 0.007, Color(0.7, 0.72, 0.78), Kit.PAINT)
		k.box(Vector3(-0.675 + i * 0.06, y + 0.12, 0.33), Vector3(0.03, 0.01, 0.01), GOLD_C, Kit.GOLD)
	_disc_x(k, Vector3(-0.64, y + 0.1, -0.1), 0.08, 0.03, Color(0.6, 0.58, 0.54), Kit.STONE, 10)
	k.box(Vector3(-0.66, y, -0.12), Vector3(0.02, 0.1, 0.05), WOOD, Kit.TIMBER)
	k.box(Vector3(-0.62, y, -0.12), Vector3(0.02, 0.1, 0.05), WOOD, Kit.TIMBER)
	_barrel(k, Vector3(0.6, y, 0.12))
	_crate(k, Vector3(0.25, y, 0.5), 0.09, 0.3)
	_ring(k, Vector3(hx - 0.42, y + 0.34, 0.275), Vector3(1, 0, 0), Vector3(0, 1, 0), 0.03, 8, 0.006, IRON, Kit.PAINT)
	k.banner(Vector3(-0.68, y, 0.62), 0.5, 0.2)


# =============================================================================================
# water_wheel: a mill house with a big undershot wheel in a mill race
# =============================================================================================


static func _big_wheel(k: Kit, c: Vector3, r: float, w: float, n := 14) -> void:
	k.push(Kit.at(c))
	var seg_pts: Array = []
	for i in n:
		var a := i * TAU / n
		seg_pts.append(Vector3(0, cos(a) * r, sin(a) * r))
	for s: float in [-1.0, 1.0]:
		var dx := Vector3(s * w / 2.0, 0, 0)
		for i in n:
			var p: Vector3 = seg_pts[i]
			var q: Vector3 = seg_pts[(i + 1) % n]
			k.rod(p + dx, q + dx, 0.013, WOOD, Kit.TIMBER)
			if i % 2 == 0:
				k.rod(dx, p * 0.97 + dx, 0.011, WOODL, Kit.TIMBER)
	for i in n:   # paddles
		var a := i * TAU / n
		var ri := r * 0.9
		var ro := r * 1.07
		var tang := Vector3(0, -sin(a), cos(a)) * 0.012
		var pa := Vector3(-w / 2.0, cos(a) * ri, sin(a) * ri)
		var pb := Vector3(w / 2.0, cos(a) * ri, sin(a) * ri)
		var pc := Vector3(w / 2.0, cos(a) * ro, sin(a) * ro)
		var pd := Vector3(-w / 2.0, cos(a) * ro, sin(a) * ro)
		k.quad(pa, pb, pc, pd, Color(0.58, 0.40, 0.24), Kit.TIMBER, (pa + pc) / 2.0 + tang * 4.0)
		k.quad(pa, pb, pc, pd, Color(0.5, 0.34, 0.2), Kit.TIMBER, (pa + pc) / 2.0 - tang * 4.0)
	k.rod(Vector3(-w / 2.0 - 0.1, 0, 0), Vector3(w / 2.0 + 0.05, 0, 0), 0.02, WOOD, Kit.TIMBER)
	_disc_x(k, Vector3(0, 0, 0), 0.04, w * 0.7, Color(0.5, 0.34, 0.2), Kit.TIMBER, 8)
	k.pop()


static func _water_wheel(k: Kit) -> void:
	_base(k, 1.56, 1.56, Color(0.52, 0.55, 0.38), Kit.EARTH)
	var y := G
	var hx := -0.33
	var hz := -0.05
	# the mill house
	k.box(Vector3(hx, y, hz), Vector3(0.62, 0.3, 0.56), STONE_C, Kit.STONE)
	k.box(Vector3(hx, y + 0.3, hz), Vector3(0.66, 0.03, 0.6), WOOD, Kit.TIMBER)
	k.box(Vector3(hx, y + 0.33, hz), Vector3(0.6, 0.24, 0.54), PLASTER, Kit.PLASTER)
	for i in 5:
		k.box(Vector3(hx - 0.3 + i * 0.15 - 0.012, y + 0.33, hz + 0.265), Vector3(0.024, 0.24, 0.02), WOOD, Kit.TIMBER)
	k.rod(Vector3(hx - 0.3, y + 0.33, hz + 0.275), Vector3(hx + 0.3, y + 0.57, hz + 0.275), 0.01, WOOD, Kit.TIMBER)
	k.rod(Vector3(hx + 0.3, y + 0.33, hz + 0.275), Vector3(hx, y + 0.57, hz + 0.275), 0.01, WOOD, Kit.TIMBER)
	k.gable_roof(Vector3(hx, y + 0.57, hz), 0.6, 0.54, 0.26, 0.08, 0.035, ROOF, Kit.OWNER_ROOF, PLASTER, Kit.PLASTER)
	k.door(Vector3(hx - 0.1, y, hz + 0.28), 0.0, 0.13, 0.2, WOOD)
	k.window(Vector3(hx + 0.12, y + 0.18, hz + 0.28), 0.0, 0.08, 0.1, WOOD, "shutters")
	k.window(Vector3(hx - 0.1, y + 0.46, hz + 0.28), 0.0, 0.09, 0.1, WOOD, "shutters")
	k.door(Vector3(hx + 0.12, y + 0.33, hz + 0.28), 0.0, 0.1, 0.16, WOOD)
	k.chimney(Vector3(hx - 0.2, y + 0.7, hz - 0.1), 0.06, 0.22, STONE_D)
	# hoist beam with a sack
	k.rod(Vector3(hx + 0.12, y + 0.5, hz + 0.28), Vector3(hx + 0.12, y + 0.5, hz + 0.45), 0.012, WOOD, Kit.TIMBER)
	k.rod(Vector3(hx + 0.12, y + 0.5, hz + 0.45), Vector3(hx + 0.12, y + 0.3, hz + 0.45), 0.004, SOOT, Kit.DARK)
	_sack(k, Vector3(hx + 0.12, y + 0.23, hz + 0.45), CREAM, 0.8)
	# mill race: stone-lined channel with water, sluice gate
	var cx := 0.2
	k.box(Vector3(cx - 0.13, y, 0.0), Vector3(0.05, 0.14, 1.54), STONE_D, Kit.STONE)
	k.box(Vector3(cx + 0.13, y, 0.0), Vector3(0.05, 0.14, 1.54), STONE_D, Kit.STONE)
	k.box(Vector3(cx, y, 0.0), Vector3(0.21, 0.09, 1.54), WATER_C.darkened(0.3), Kit.STONE)
	k.box(Vector3(cx, y + 0.09, 0.0), Vector3(0.21, 0.015, 1.54), WATER_C, Kit.WATER)
	var wl := y + 0.105
	var r := 0.34
	_big_wheel(k, Vector3(cx, wl + r - 0.075, -0.05), r, 0.15)
	k.box(Vector3(cx - 0.12, wl + r - 0.08 - 0.005, -0.05), Vector3(0.02, 0.02, 0.02), IRON, Kit.PAINT)
	# axle bearing on the house wall
	k.rod(Vector3(hx + 0.3, wl + r - 0.075, -0.05), Vector3(cx - 0.1, wl + r - 0.075, -0.05), 0.025, WOOD, Kit.TIMBER)
	for sx: float in [-0.095, 0.095]:   # sluice gate at the head of the race
		k.box(Vector3(cx + sx * 1.3, y, -0.62), Vector3(0.025, 0.3, 0.025), WOOD, Kit.TIMBER)
	k.box(Vector3(cx, y + 0.28, -0.62), Vector3(0.3, 0.025, 0.03), WOOD, Kit.TIMBER)
	k.box(Vector3(cx, y + 0.12, -0.62), Vector3(0.2, 0.15, 0.015), Color(0.4, 0.3, 0.2), Kit.TIMBER)
	k.rod(Vector3(cx, y + 0.27, -0.62), Vector3(cx, y + 0.32, -0.62), 0.01, IRON, Kit.PAINT)
	# a footbridge over the race
	k.box(Vector3(cx, y + 0.14, 0.5), Vector3(0.34, 0.025, 0.12), WOODL, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(cx + s * 0.16, y + 0.165, 0.5), Vector3(0.015, 0.06, 0.12), WOOD, Kit.TIMBER)
	# millstone, sacks, barrel, reeds, tree
	_disc_z(k, Vector3(hx - 0.45, y + 0.1, hz + 0.1), 0.1, 0.035, Color(0.62, 0.6, 0.55), Kit.STONE, 12)
	_disc_z(k, Vector3(hx - 0.45, y + 0.1, hz + 0.12), 0.025, 0.035, SOOT, Kit.DARK, 6)
	for i in 3:
		_sack(k, Vector3(hx + 0.22 + i * 0.08, y, hz + 0.4), CREAM)
	_sack(k, Vector3(hx + 0.26, y + 0.065, hz + 0.4), Color(0.8, 0.65, 0.4), 0.95)
	_barrel(k, Vector3(hx - 0.28, y, hz + 0.42))
	for i in 6:
		k.frustum(Vector3(cx + 0.19 + (i % 3) * 0.03, y, 0.15 + i * 0.07), 0.006, 0.0, 0.11 + (i % 2) * 0.04, LEAF_C, Kit.LEAF, 3)
	_tree(k, Vector3(0.62, y, 0.1), 1.3)
	_tree(k, Vector3(0.58, y, -0.4), 1.0)
	_crate(k, Vector3(-0.6, y, 0.55), 0.09)


# =============================================================================================
# windmill: a tower mill with four latticed sails
# =============================================================================================


static func _windmill(k: Kit) -> void:
	_base(k, 1.56, 1.5, Color(0.62, 0.58, 0.40), Kit.EARTH)
	var y := G
	k.frustum(Vector3(0, y, -0.1), 0.36, 0.32, 0.3, STONE_C, Kit.STONE, 12, false)
	k.frustum(Vector3(0, y + 0.3, -0.1), 0.32, 0.22, 0.56, Color(0.93, 0.9, 0.82), Kit.PLASTER, 12, false)
	k.frustum(Vector3(0, y + 0.3, -0.1), 0.43, 0.43, 0.03, WOOD, Kit.TIMBER, 12)
	for i in 14:
		var a := i * TAU / 14.0
		k.box(Vector3(cos(a) * 0.42 - 0.008, y + 0.33, -0.1 + sin(a) * 0.42 - 0.008), Vector3(0.016, 0.07, 0.016), WOOD, Kit.TIMBER)
	_ring(k, Vector3(0, y + 0.4, -0.1), Vector3(1, 0, 0), Vector3(0, 0, 1), 0.42, 14, 0.008, WOOD, Kit.TIMBER)
	k.door(Vector3(0, y, 0.215), 0.0, 0.12, 0.22, WOOD)
	for i in 2:
		k.box(Vector3(0, y + i * 0.025, 0.25 + (1 - i) * 0.03), Vector3(0.2, 0.025, 0.07 - i * 0.02), STONE_C, Kit.STONE)
	for a: float in [0.9, -0.9, PI + 0.5, PI - 0.5]:
		var rr := 0.28
		k.window(Vector3(sin(a) * rr, y + 0.6, -0.1 + cos(a) * rr), a, 0.05, 0.09, WOOD, "arch")
	# cap
	k.frustum(Vector3(0, y + 0.86, -0.1), 0.25, 0.25, 0.04, WOOD, Kit.TIMBER, 12)
	k.dome(Vector3(0, y + 0.9, -0.1), 0.25, Color(0.78, 0.42, 0.30), Kit.OWNER_ROOF, 0.8, 5, 12)
	k.dome(Vector3(0, y + 1.09, -0.1), 0.04, GOLD_C, Kit.GOLD, 1.0, 2, 6)
	# hub and the four sails (stocks with lattice frames)
	var hub := Vector3(0, y + 0.8, 0.17)
	k.rod(Vector3(0, y + 0.8, 0.0), hub + Vector3(0, 0, 0.05), 0.035, WOOD, Kit.TIMBER)
	k.dome(hub + Vector3(0, 0, 0.03), 0.06, GOLD_C, Kit.GOLD, 1.0, 3, 8)
	k.push(Kit.at(hub + Vector3(0, 0, 0.09)))
	for i in 4:
		var a := 0.5 + i * PI / 2.0
		var d := Vector3(cos(a), sin(a), 0)
		var nrm := Vector3(-sin(a), cos(a), 0)
		var r0 := 0.14
		var r1 := 0.78
		k.rod(Vector3.ZERO, d * r1, 0.016, WOOD, Kit.TIMBER)
		var A := d * r0 + nrm * 0.03
		var B := d * r1 + nrm * 0.03
		var C := d * r1 + nrm * 0.2
		var D := d * r0 + nrm * 0.2
		k.rod(A, B, 0.007, WOODL, Kit.TIMBER)
		k.rod(D, C, 0.01, WOODL, Kit.TIMBER)
		k.rod(A, D, 0.007, WOODL, Kit.TIMBER)
		k.rod(B, C, 0.007, WOODL, Kit.TIMBER)
		k.rod((A + D) / 2.0, (B + C) / 2.0, 0.005, WOODL, Kit.TIMBER)
		for j in 8:
			var t := 0.12 + j * 0.085
			k.rod(d * (r0 + (r1 - r0) * t / 0.8) + nrm * 0.03, d * (r0 + (r1 - r0) * t / 0.8) + nrm * 0.2, 0.005, WOODL, Kit.TIMBER)
		if i % 2 == 0:   # a couple of sails carry a cloth panel
			k.quad(d * 0.5 + nrm * 0.035, d * 0.74 + nrm * 0.035, d * 0.74 + nrm * 0.195, d * 0.5 + nrm * 0.195,
				CREAM, Kit.CLOTH, Vector3(0, 0, -1))
	k.pop()
	# tail pole, steps, sacks, cart
	k.rod(Vector3(0, y + 0.55, -0.32), Vector3(0, y + 0.03, -0.75), 0.018, WOOD, Kit.TIMBER)
	k.rod(Vector3(0.0, y + 0.03, -0.75), Vector3(0.0, y + 0.03, -0.72), 0.04, WOOD, Kit.TIMBER)
	_disc_x(k, Vector3(0, y + 0.04, -0.72), 0.04, 0.02, WOOD, Kit.TIMBER, 8)
	_ladder(k, Vector3(0.35, y, 0.35), Vector3(0.3, y + 0.34, 0.2), Vector3(0.03, 0, 0), 5)
	for i in 3:
		_sack(k, Vector3(-0.4 + i * 0.08, y, 0.5), CREAM)
	_sack(k, Vector3(-0.36, y + 0.065, 0.5), Color(0.8, 0.65, 0.4), 0.95)
	k.push(Kit.at(Vector3(0.5, y, 0.5), -0.5))
	k.box(Vector3(0, 0.07, 0), Vector3(0.3, 0.03, 0.18), WOODL, Kit.TIMBER)
	_disc_x(k, Vector3(0.0, 0.07, 0.11), 0.065, 0.02, WOOD, Kit.TIMBER, 10)
	_disc_x(k, Vector3(0.0, 0.07, -0.11), 0.065, 0.02, WOOD, Kit.TIMBER, 10)
	for i in 3:
		_sack(k, Vector3(-0.08 + i * 0.08, 0.1, 0), CREAM, 0.9)
	k.rod(Vector3(0.14, 0.075, 0), Vector3(0.34, 0.05, 0.02), 0.01, WOOD, Kit.TIMBER)
	k.pop()
	k.banner(Vector3(-0.7, y, 0.6), 0.45, 0.18)


# =============================================================================================
# clock_tower (courthouse): a town hall with a portico and a tall clock tower
# =============================================================================================


static func _clock_tower(k: Kit) -> void:
	_base(k, 1.56, 1.4, Color(0.70, 0.67, 0.60), Kit.STONE)
	var y := G
	var wall := Color(0.82, 0.77, 0.66)
	k.box(Vector3(0, y, -0.08), Vector3(1.3, 0.05, 0.62), STONE_D, Kit.STONE)
	k.box(Vector3(0, y + 0.05, -0.08), Vector3(1.26, 0.42, 0.56), wall, Kit.STONE)
	k.box(Vector3(0, y + 0.47, -0.08), Vector3(1.32, 0.04, 0.6), STONE_C, Kit.STONE)
	k.hip_roof(Vector3(0, y + 0.51, -0.08), 1.26, 0.56, 0.18, 0.05, 0.03, ROOF, Kit.OWNER_ROOF)
	for x: float in [-0.5, -0.33, 0.33, 0.5]:
		k.window(Vector3(x, y + 0.3, 0.205), 0.0, 0.08, 0.2, STONE_C, "arch")
		k.window(Vector3(x, y + 0.3, -0.365), PI, 0.08, 0.2, STONE_C, "arch")
	for s: float in [-1.0, 1.0]:
		k.window(Vector3(s * 0.63, y + 0.3, -0.08), s * PI / 2.0, 0.08, 0.2, STONE_C, "arch")
	k.door(Vector3(0, y + 0.05, 0.205), 0.0, 0.16, 0.28, STONE_C, Color(0.3, 0.19, 0.11))
	# portico
	for sx: float in [-0.2, -0.07, 0.07, 0.2]:
		k.column(Vector3(sx, y + 0.05, 0.3), 0.03, 0.42, Color(0.92, 0.89, 0.8), Kit.PAINT)
	k.box(Vector3(0, y + 0.47, 0.26), Vector3(0.52, 0.05, 0.18), STONE_C, Kit.STONE)
	k.wedge(Vector3(0, y + 0.52, 0.26), 0.18, 0.54, 0.13, STONE_C, Kit.STONE, PI / 2.0)
	for i in 3:
		k.box(Vector3(0, y + 0.0 + i * 0.0, 0.42 + i * 0.05), Vector3(0.4 - i * 0.05, 0.05 * (2 - i) + 0.05, 0.08), STONE_C, Kit.STONE)
	# the scales of justice over the pediment
	var sp := Vector3(0, y + 0.7, 0.3)
	k.rod(sp, sp + Vector3(0, 0.1, 0), 0.006, GOLD_C, Kit.GOLD)
	k.rod(sp + Vector3(-0.07, 0.1, 0), sp + Vector3(0.07, 0.1, 0), 0.006, GOLD_C, Kit.GOLD)
	for s: float in [-0.07, 0.07]:
		_disc_z(k, sp + Vector3(s, 0.065, 0), 0.025, 0.006, GOLD_C, Kit.GOLD, 8)
	# the clock tower rising behind the portico
	var tz := -0.1
	k.box(Vector3(0, y + 0.05, tz), Vector3(0.36, 0.95, 0.36), STONE_C, Kit.STONE)
	k.box(Vector3(0, y + 0.6, tz), Vector3(0.4, 0.03, 0.4), STONE_D, Kit.STONE)
	for s: float in [-1.0, 1.0]:
		k.window(Vector3(s * 0.19, y + 0.88, tz), s * PI / 2.0, 0.05, 0.12, STONE_D, "arch")
	k.window(Vector3(0.0, y + 0.88, tz + 0.18), 0.0, 0.05, 0.12, STONE_D, "arch")
	for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
		k.push(Kit.at(Vector3(0, 0, tz), yaw))
		_clock(k, Vector3(0, y + 0.74, 0.19), 0.0, 0.07)
		k.pop()
	k.box(Vector3(0, y + 1.0, tz), Vector3(0.44, 0.04, 0.44), STONE_D, Kit.STONE)
	k.box(Vector3(0, y + 1.04, tz), Vector3(0.32, 0.2, 0.32), wall, Kit.STONE)
	for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
		k.push(Kit.at(Vector3(0, 0, tz), yaw))
		k.window(Vector3(0, y + 1.16, 0.165), 0.0, 0.09, 0.12, STONE_D, "arch")
		k.pop()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.2 - 0.02, y + 1.04, tz + sz * 0.2 - 0.02), Vector3(0.04, 0.25, 0.04), STONE_C, Kit.STONE)
			k.frustum(Vector3(sx * 0.2, y + 1.29, tz + sz * 0.2), 0.022, 0.0, 0.07, GOLD_C, Kit.GOLD, 4)
	k.box(Vector3(0, y + 1.24, tz), Vector3(0.38, 0.04, 0.38), STONE_D, Kit.STONE)
	k.hip_roof(Vector3(0, y + 1.28, tz), 0.34, 0.34, 0.34, 0.05, 0.03, Color(0.74, 0.42, 0.3), Kit.OWNER_ROOF)
	k.rod(Vector3(0, y + 1.6, tz), Vector3(0, y + 1.8, tz), 0.008, GOLD_C, Kit.GOLD)
	k.dome(Vector3(0, y + 1.6, tz), 0.03, GOLD_C, Kit.GOLD, 1.0, 2, 6)
	k.quad(Vector3(0, y + 1.74, tz), Vector3(0.1, y + 1.76 - 0.0, tz), Vector3(0.1, y + 1.7, tz), Vector3(0, y + 1.68, tz), OWNER_C, Kit.OWNER_CLOTH, Vector3(0, 1, 1))
	k.banner(Vector3(-0.58, y, 0.4), 0.6, 0.2)
	k.banner(Vector3(0.58, y, 0.4), 0.6, 0.2)
	for sx: float in [-0.5, 0.5]:   # hitching posts and lamps
		k.box(Vector3(sx - 0.015, y, 0.58), Vector3(0.03, 0.2, 0.03), IRON, Kit.PAINT)
		k.box(Vector3(sx - 0.03, y + 0.2, 0.565), Vector3(0.06, 0.06, 0.06), GOLD_C, Kit.GOLD)


# =============================================================================================
# aqueduct: two tiers of arches carrying a water channel (2.0 long, 0.5 deep)
# =============================================================================================


static func _aqueduct(k: Kit) -> void:
	k.bevel_box(Vector3.ZERO, Vector3(2.02, G, 0.62), 0.012, Color(0.58, 0.55, 0.42), Kit.EARTH)
	var y := G
	var stone := Color(0.78, 0.74, 0.66)
	_arcade(k, -1.0, y, 3, 0.48, 0.14, 0.2, y + 0.5, 0.0, 0.4, stone, Kit.STONE)
	k.box(Vector3(0, y + 0.5, 0), Vector3(2.0, 0.035, 0.44), STONE_C, Kit.STONE)
	var y2 := y + 0.535
	_arcade(k, -0.96, y2, 6, 0.2367, 0.07, 0.13, y2 + 0.3, 0.0, 0.34, stone, Kit.STONE)
	k.box(Vector3(0, y2 + 0.3, 0), Vector3(1.98, 0.035, 0.4), STONE_C, Kit.STONE)
	var yc := y2 + 0.335
	k.box(Vector3(0, yc, 0), Vector3(1.96, 0.035, 0.34), STONE_D, Kit.STONE)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(0, yc + 0.035, s * 0.145), Vector3(1.96, 0.1, 0.05), STONE_C, Kit.STONE)
		k.box(Vector3(0, yc + 0.135, s * 0.145), Vector3(1.98, 0.02, 0.07), STONE_C.lightened(0.05), Kit.STONE)
	k.box(Vector3(0, yc + 0.035, 0), Vector3(1.9, 0.07, 0.24), WATER_C.darkened(0.2), Kit.STONE)
	k.box(Vector3(0, yc + 0.07, 0), Vector3(1.9, 0.02, 0.24), WATER_C, Kit.WATER)
	# buttresses on the piers and ornamental roundels in the spandrels
	for i in 4:
		var px := -1.0 + 0.07 + i * 0.62
		for s: float in [-1.0, 1.0]:
			k.box(Vector3(px, y, s * 0.215), Vector3(0.08, 0.5, 0.03), STONE_C, Kit.STONE)
			k.box(Vector3(px, y + 0.5, s * 0.215), Vector3(0.1, 0.02, 0.04), STONE_D, Kit.STONE)
	for i in 3:
		var cx := -0.5 + i * 0.5
		for s: float in [-1.0, 1.0]:
			_disc_z(k, Vector3(cx, y + 0.455, s * 0.205), 0.03, 0.01, STONE_D, Kit.STONE, 8)
	# end towers with steps up to the channel
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.99, yc + 0.035, 0), Vector3(0.04, 0.2, 0.36), STONE_D, Kit.STONE)
	# a spout into a stone trough, plus reeds and bushes
	k.box(Vector3(0.45, y2 + 0.2, 0.2), Vector3(0.04, 0.03, 0.1), STONE_C, Kit.STONE)
	k.box(Vector3(0.45, y + 0.46, 0.27), Vector3(0.012, 0.3, 0.012), WATER_C, Kit.WATER)
	k.box(Vector3(0.45, y, 0.27), Vector3(0.26, 0.09, 0.12), STONE_C, Kit.STONE)
	k.box(Vector3(0.45, y + 0.09, 0.27), Vector3(0.22, 0.012, 0.08), WATER_C, Kit.WATER)
	for i in 6:
		k.frustum(Vector3(0.7 + (i % 3) * 0.04, y, 0.24 + i * 0.015), 0.006, 0.0, 0.12 + (i % 2) * 0.05, LEAF_C, Kit.LEAF, 3)
	k.dome(Vector3(-0.78, y, -0.27), 0.08, LEAF_C, Kit.LEAF, 0.9, 3, 7)
	k.dome(Vector3(0.82, y, -0.26), 0.07, LEAF_C.lightened(0.1), Kit.LEAF, 0.9, 3, 7)
	_barrel(k, Vector3(-0.2, y, 0.28))
	_crate(k, Vector3(0.1, y, 0.3), 0.08, 0.2)


# =============================================================================================
# hospital: wards round a garden court, a chapel with a bell
# =============================================================================================


static func _hospital(k: Kit) -> void:
	_base(k, 1.56, 1.5, Color(0.60, 0.60, 0.46), Kit.EARTH)
	var y := G
	var wallc := Color(0.95, 0.92, 0.84)
	var rc := Color(0.74, 0.44, 0.34)
	# back wing, side wings
	k.box(Vector3(0, y, -0.55), Vector3(1.5, 0.34, 0.4), wallc, Kit.PLASTER)
	k.gable_roof(Vector3(0, y + 0.34, -0.55), 1.5, 0.4, 0.2, 0.06, 0.03, rc, Kit.OWNER_ROOF, wallc, Kit.PLASTER)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.55, y, 0.1), Vector3(0.4, 0.34, 0.9), wallc, Kit.PLASTER)
		k.gable_roof(Vector3(s * 0.55, y + 0.34, 0.1), 0.9, 0.4, 0.2, 0.06, 0.03, rc, Kit.OWNER_ROOF, wallc, Kit.PLASTER, PI / 2.0)
		for z in 4:
			k.window(Vector3(s * 0.75, y + 0.22, -0.2 + z * 0.22), s * PI / 2.0, 0.07, 0.12, STONE_C, "frame")
		k.window(Vector3(s * 0.65, y + 0.22, 0.555), 0.0, 0.07, 0.12, STONE_C, "frame")
		k.window(Vector3(s * 0.45, y + 0.22, 0.555), 0.0, 0.07, 0.12, STONE_C, "frame")
		k.chimney(Vector3(s * 0.55 + 0.05, y + 0.46, 0.0), 0.06, 0.22, STONE_D)
	for x in 5:
		k.window(Vector3(-0.64 + x * 0.32, y + 0.22, -0.745), PI, 0.07, 0.12, STONE_C, "frame")
	# the chapel with a bell tower
	k.box(Vector3(0, y, -0.46), Vector3(0.38, 0.6, 0.4), Color(0.88, 0.84, 0.74), Kit.STONE)
	k.box(Vector3(0, y + 0.6, -0.46), Vector3(0.44, 0.03, 0.46), STONE_D, Kit.STONE)
	k.box(Vector3(0, y + 0.63, -0.46), Vector3(0.3, 0.14, 0.3), Color(0.88, 0.84, 0.74), Kit.STONE)
	for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
		k.push(Kit.at(Vector3(0, 0, -0.46), yaw))
		k.window(Vector3(0, y + 0.7, 0.155), 0.0, 0.07, 0.1, STONE_D, "arch")
		k.pop()
	k.frustum(Vector3(0, y + 0.64, -0.46), 0.035, 0.02, 0.09, GOLD_C, Kit.GOLD, 8)
	k.hip_roof(Vector3(0, y + 0.77, -0.46), 0.32, 0.32, 0.24, 0.04, 0.025, rc, Kit.OWNER_ROOF)
	k.rod(Vector3(0, y + 1.0, -0.46), Vector3(0, y + 1.12, -0.46), 0.006, GOLD_C, Kit.GOLD)
	k.rod(Vector3(-0.03, y + 1.08, -0.46), Vector3(0.03, y + 1.08, -0.46), 0.006, GOLD_C, Kit.GOLD)
	k.door(Vector3(0, y, -0.26), 0.0, 0.1, 0.2, STONE_C, Color(0.3, 0.2, 0.12))
	k.window(Vector3(0, y + 0.36, -0.26), 0.0, 0.06, 0.1, STONE_C, "frame")
	var rd := Color(0.8, 0.16, 0.14)
	k.box(Vector3(0, y + 0.42, -0.255), Vector3(0.14, 0.14, 0.008), Color(0.97, 0.97, 0.95), Kit.PAINT)
	k.box(Vector3(-0.045, y + 0.465, -0.249), Vector3(0.09, 0.03, 0.006), rd, Kit.PAINT)
	k.box(Vector3(-0.015, y + 0.435, -0.249), Vector3(0.03, 0.09, 0.006), rd, Kit.PAINT)
	k.box(Vector3(-0.015, y + 0.42, -0.248), Vector3(0.03, 0.14, 0.004), rd, Kit.PAINT)
	# covered walk with slim posts round the court
	for s: float in [-1.0, 1.0]:
		for z in 6:
			k.box(Vector3(s * 0.3 - 0.01, y, -0.15 + z * 0.14), Vector3(0.02, 0.16, 0.02), WOOD, Kit.TIMBER)
		k.box(Vector3(s * 0.31, y + 0.16, 0.2), Vector3(0.1, 0.02, 0.8), rc, Kit.OWNER_ROOF)
	# garden: beds, paths, fountain, trees, a well-ish cart
	k.box(Vector3(0, y, 0.15), Vector3(0.6, 0.01, 0.8), Color(0.47, 0.62, 0.34), Kit.LEAF)
	k.box(Vector3(0, y + 0.01, 0.15), Vector3(0.07, 0.004, 0.8), Color(0.82, 0.76, 0.64), Kit.STONE)
	for s: float in [-1.0, 1.0]:
		for i in 3:
			k.box(Vector3(s * 0.15 - 0.045, y + 0.01, 0.12 + i * 0.16 - 0.0), Vector3(0.09, 0.028, 0.1), Color(0.35, 0.5, 0.2), Kit.LEAF)
			k.dome(Vector3(s * 0.15, y + 0.036, 0.17 + i * 0.16), 0.03, [Color(0.9, 0.35, 0.4), Color(0.95, 0.85, 0.3), Color(0.7, 0.5, 0.85)][i] as Color, Kit.PAINT, 0.5, 2, 6)
	k.frustum(Vector3(0, y + 0.01, 0.33), 0.07, 0.07, 0.04, STONE_C, Kit.STONE, 10)
	k.frustum(Vector3(0, y + 0.045, 0.33), 0.055, 0.055, 0.01, WATER_C, Kit.WATER, 10)
	k.frustum(Vector3(0, y + 0.05, 0.33), 0.012, 0.008, 0.08, STONE_C, Kit.STONE, 6)
	_tree(k, Vector3(-0.2, y, -0.1), 0.9)
	_tree(k, Vector3(0.2, y, -0.12), 0.9)
	# gate wall in front of the court
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.2, y, 0.62), Vector3(0.22, 0.14, 0.04), STONE_C, Kit.STONE)
		k.box(Vector3(s * 0.1, y, 0.62), Vector3(0.05, 0.22, 0.06), STONE_C, Kit.STONE)
		k.box(Vector3(s * 0.1, y + 0.22, 0.62), Vector3(0.07, 0.025, 0.08), STONE_D, Kit.STONE)
		k.box(Vector3(s * 0.1 - 0.012, y + 0.245, 0.608), Vector3(0.024, 0.04, 0.024), GOLD_C, Kit.GOLD)
	k.box(Vector3(0, y + 0.18, 0.62), Vector3(0.16, 0.025, 0.04), WOOD, Kit.TIMBER)
	k.banner(Vector3(-0.72, y, 0.68), 0.5, 0.18)
	k.box(Vector3(0.58, y, 0.68), Vector3(0.16, 0.05, 0.07), WOODL, Kit.TIMBER)   # a bench
	for i in 2:   # stretcher cart
		_disc_x(k, Vector3(-0.1 + i * 0.2, y + 0.04, 0.5), 0.035, 0.012, WOOD, Kit.TIMBER, 8)


# =============================================================================================
# station: an early railway station: platform, canopy, building and a little locomotive
# =============================================================================================


static func _station(k: Kit) -> void:
	_base(k, 1.58, 1.5, Color(0.55, 0.52, 0.45), Kit.EARTH)
	var y := G
	var green := Color(0.2, 0.36, 0.3)
	# station building
	k.box(Vector3(-0.15, y, -0.52), Vector3(1.1, 0.06, 0.4), STONE_D, Kit.STONE)
	k.box(Vector3(-0.15, y + 0.06, -0.52), Vector3(1.06, 0.3, 0.36), BRICK_C, Kit.BRICK)
	k.gable_roof(Vector3(-0.15, y + 0.36, -0.52), 1.06, 0.36, 0.2, 0.07, 0.03, Color(0.45, 0.4, 0.4), Kit.OWNER_ROOF, BRICK_C, Kit.BRICK)
	# cross gable with the clock
	k.box(Vector3(-0.15, y + 0.06, -0.3), Vector3(0.3, 0.3, 0.1), BRICK_C, Kit.BRICK)
	k.gable_roof(Vector3(-0.15, y + 0.36, -0.3), 0.1, 0.3, 0.17, 0.04, 0.025, Color(0.45, 0.4, 0.4), Kit.OWNER_ROOF, BRICK_C, Kit.BRICK, PI / 2.0)
	_clock(k, Vector3(-0.15, y + 0.43, -0.242), 0.0, 0.045)
	for x: float in [-0.55, -0.4, 0.1, 0.25]:
		k.window(Vector3(x, y + 0.25, -0.34), 0.0, 0.07, 0.16, STONE_C, "arch")
	k.door(Vector3(-0.15, y + 0.06, -0.249), 0.0, 0.14, 0.22, STONE_C)
	k.window(Vector3(-0.15, y + 0.3, -0.249), 0.0, 0.06, 0.06, STONE_C, "frame")
	k.chimney(Vector3(-0.6, y + 0.4, -0.55), 0.06, 0.2, BRICK_C.darkened(0.2), Kit.BRICK)
	k.chimney(Vector3(0.25, y + 0.4, -0.55), 0.06, 0.2, BRICK_C.darkened(0.2), Kit.BRICK)
	k.box(Vector3(0.33, y + 0.06, -0.33), Vector3(0.18, 0.1, 0.03), WOOD, Kit.TIMBER)   # sign board
	k.box(Vector3(0.33, y + 0.07, -0.31), Vector3(0.14, 0.02, 0.01), GOLD_C, Kit.GOLD)
	# platform and canopy
	k.box(Vector3(0, y, -0.0), Vector3(1.5, 0.07, 0.36), Color(0.7, 0.67, 0.6), Kit.STONE)
	k.box(Vector3(0, y + 0.07, 0.17), Vector3(1.5, 0.012, 0.03), Color(0.95, 0.92, 0.8), Kit.PAINT)
	for i in 5:
		k.column(Vector3(-0.55 + i * 0.28, y + 0.07, 0.1), 0.014, 0.3, green, Kit.PAINT)
		k.box(Vector3(-0.55 + i * 0.28 - 0.012, y + 0.31, 0.06), Vector3(0.024, 0.06, 0.07), green, Kit.PAINT)
	k.gable_roof(Vector3(-0.1, y + 0.4, -0.05), 1.3, 0.46, 0.08, 0.04, 0.025, Color(0.72, 0.42, 0.32), Kit.OWNER_ROOF, green, Kit.PAINT)
	for i in 14:
		k.tri(Vector3(-0.72 + i * 0.1, y + 0.4, 0.2 + 0.015), Vector3(-0.64 + i * 0.1, y + 0.4, 0.215), Vector3(-0.68 + i * 0.1, y + 0.36, 0.215),
			green, Kit.PAINT, Vector3(-0.68 + i * 0.1, y + 0.4, 0.0))
	# platform dressing: bench, lamp, trunks, milk churns, a bell
	k.box(Vector3(-0.5, y + 0.07, -0.03), Vector3(0.22, 0.04, 0.06), WOODL, Kit.TIMBER)
	k.box(Vector3(-0.5, y + 0.11, -0.055), Vector3(0.22, 0.05, 0.015), WOODL, Kit.TIMBER)
	k.box(Vector3(0.45, y + 0.07, -0.02), Vector3(0.1, 0.06, 0.07), WOOD, Kit.TIMBER)
	k.box(Vector3(0.45, y + 0.13, -0.02), Vector3(0.11, 0.015, 0.075), GOLD_C.darkened(0.3), Kit.GOLD)
	k.box(Vector3(0.55, y + 0.07, 0.02), Vector3(0.08, 0.05, 0.06), WOODL, Kit.TIMBER)
	for i in 3:
		k.frustum(Vector3(0.22 + i * 0.06, y + 0.07, 0.0), 0.022, 0.016, 0.07, Color(0.78, 0.78, 0.8), Kit.PAINT, 8)
	k.box(Vector3(0.0 - 0.006, y + 0.07, 0.0), Vector3(0.012, 0.18, 0.012), IRON, Kit.PAINT)
	k.box(Vector3(-0.02, y + 0.25, -0.02), Vector3(0.04, 0.05, 0.04), GOLD_C, Kit.GOLD)
	# the track
	k.box(Vector3(0, y, 0.38), Vector3(1.56, 0.02, 0.22), STONE_D, Kit.STONE)
	for i in 16:
		k.box(Vector3(-0.75 + i * 0.1, y + 0.02, 0.38), Vector3(0.035, 0.012, 0.18), WOOD, Kit.TIMBER)
	for s: float in [-0.065, 0.065]:
		k.rod(Vector3(-0.78, y + 0.04, 0.38 + s), Vector3(0.78, y + 0.04, 0.38 + s), 0.008, IRON, Kit.PAINT)
	k.box(Vector3(-0.72, y + 0.02, 0.38), Vector3(0.03, 0.06, 0.2), WOOD, Kit.TIMBER)   # buffer stop
	# the locomotive, facing +x
	var lx := 0.18
	var ly := y + 0.04
	var lz := 0.38
	var blk := Color(0.16, 0.16, 0.18)
	k.box(Vector3(lx + 0.0, ly + 0.05, lz), Vector3(0.7, 0.03, 0.12), blk, Kit.PAINT)
	_tube_x(k, Vector3(lx + 0.18, ly + 0.17, lz), 0.065, 0.065, 0.34, blk, Kit.PAINT, 10)
	_tube_x(k, Vector3(lx + 0.18, ly + 0.17, lz), 0.068, 0.068, 0.012, GOLD_C, Kit.GOLD, 10)
	_tube_x(k, Vector3(lx + 0.07, ly + 0.17, lz), 0.068, 0.068, 0.012, GOLD_C, Kit.GOLD, 10)
	_tube_x(k, Vector3(lx + 0.29, ly + 0.17, lz), 0.068, 0.068, 0.012, GOLD_C, Kit.GOLD, 10)
	k.frustum(Vector3(lx + 0.3, ly + 0.23, lz), 0.026, 0.04, 0.1, blk, Kit.PAINT, 8)
	k.frustum(Vector3(lx + 0.3, ly + 0.33, lz), 0.044, 0.044, 0.012, SOOT, Kit.DARK, 8)
	k.dome(Vector3(lx + 0.14, ly + 0.225, lz), 0.035, GOLD_C, Kit.GOLD, 1.0, 3, 8)
	k.dome(Vector3(lx + 0.2, ly + 0.23, lz), 0.02, GOLD_C, Kit.GOLD, 1.2, 2, 6)
	k.box(Vector3(lx - 0.06, ly + 0.05, lz), Vector3(0.18, 0.2, 0.14), Color(0.55, 0.15, 0.12), Kit.PAINT)
	k.box(Vector3(lx - 0.06, ly + 0.25, lz), Vector3(0.2, 0.025, 0.16), Color(0.6, 0.35, 0.28), Kit.OWNER_ROOF)
	k.window(Vector3(lx - 0.06, ly + 0.16, lz + 0.071), 0.0, 0.05, 0.06, GOLD_C, "frame")
	k.wedge(Vector3(lx + 0.4, ly + 0.07, lz), 0.06, 0.13, 0.05, blk, Kit.PAINT, PI / 2.0)
	k.box(Vector3(lx + 0.355, ly + 0.2, lz - 0.015), Vector3(0.02, 0.03, 0.03), GOLD_C, Kit.GOLD)
	for wx: float in [-0.1, 0.05, 0.2, 0.3]:
		var wr := 0.05 if wx < 0.25 else 0.03
		for s: float in [-0.075, 0.075]:
			_disc_z(k, Vector3(lx + wx, ly + wr + 0.0, lz + s), wr, 0.015, blk, Kit.PAINT, 10)
			_disc_z(k, Vector3(lx + wx, ly + wr, lz + s * 1.1), wr * 0.35, 0.012, GOLD_C, Kit.GOLD, 6)
	k.rod(Vector3(lx - 0.1, ly + 0.05, lz + 0.085), Vector3(lx + 0.2, ly + 0.05, lz + 0.085), 0.006, GOLD_C, Kit.GOLD)
	# tender with coal
	k.box(Vector3(lx - 0.31, ly + 0.05, lz), Vector3(0.2, 0.1, 0.12), Color(0.2, 0.2, 0.22), Kit.PAINT)
	k.dome(Vector3(lx - 0.31, ly + 0.15, lz), 0.07, Color(0.1, 0.09, 0.09), Kit.DARK, 0.5, 2, 6)
	for wx: float in [-0.37, -0.25]:
		for s: float in [-0.065, 0.065]:
			_disc_z(k, Vector3(lx + wx, ly + 0.03, lz + s), 0.03, 0.012, blk, Kit.PAINT, 8)
	for p in [Vector3(lx + 0.3, ly + 0.4, lz), Vector3(lx + 0.22, ly + 0.5, lz), Vector3(lx + 0.12, ly + 0.62, lz)]:
		var pp: Vector3 = p
		k.dome(pp, 0.03 + (pp.y - ly - 0.4) * 0.12, Color(0.92, 0.92, 0.94), Kit.CLOTH, 0.7, 2, 7)
	k.banner(Vector3(-0.72, y, 0.65), 0.5, 0.18)


# =============================================================================================
# hall: a guildhall with a jettied timber-framed upper floor and a front gable bay
# =============================================================================================


static func _hall(k: Kit) -> void:
	_base(k, 1.52, 1.4, Color(0.64, 0.60, 0.48), Kit.STONE)
	var y := G
	var beam := Color(0.36, 0.24, 0.14)
	k.box(Vector3(0, y, -0.15), Vector3(1.12, 0.07, 0.52), STONE_D, Kit.STONE)
	k.box(Vector3(0, y + 0.07, -0.15), Vector3(1.08, 0.25, 0.5), PLASTER, Kit.PLASTER)
	for i in 9:   # ground-floor studs
		k.box(Vector3(-0.5 + i * 0.125 - 0.012, y + 0.07, 0.105), Vector3(0.025, 0.25, 0.02), beam, Kit.TIMBER)
	# jettied upper floor, half-timbered
	k.box(Vector3(0, y + 0.32, -0.15), Vector3(1.18, 0.04, 0.6), beam, Kit.TIMBER)
	k.box(Vector3(0, y + 0.36, -0.15), Vector3(1.14, 0.26, 0.56), PLASTER, Kit.PLASTER)
	for i in 10:
		k.box(Vector3(-0.54 + i * 0.12 - 0.012, y + 0.36, 0.13), Vector3(0.024, 0.26, 0.02), beam, Kit.TIMBER)
	for i in 4:
		k.rod(Vector3(-0.54 + i * 0.28, y + 0.37, 0.14), Vector3(-0.42 + i * 0.28, y + 0.61, 0.14), 0.008, beam, Kit.TIMBER)
	k.box(Vector3(0, y + 0.48, 0.13), Vector3(1.14, 0.02, 0.02), beam, Kit.TIMBER)
	k.box(Vector3(0, y + 0.6, 0.13), Vector3(1.14, 0.025, 0.02), beam, Kit.TIMBER)
	for x: float in [-0.44, -0.3, 0.3, 0.44]:
		k.window(Vector3(x, y + 0.47, 0.145), 0.0, 0.06, 0.1, beam, "lattice")
		k.window(Vector3(x, y + 0.17, 0.105 + 0.005), 0.0, 0.05, 0.1, beam, "shutters")
	k.gable_roof(Vector3(0, y + 0.62, -0.15), 1.14, 0.56, 0.3, 0.08, 0.035, ROOF, Kit.OWNER_ROOF, PLASTER, Kit.PLASTER)
	# gable bay in front with the great door
	k.box(Vector3(0, y, 0.22), Vector3(0.46, 0.07, 0.32), STONE_D, Kit.STONE)
	k.box(Vector3(0, y + 0.07, 0.22), Vector3(0.42, 0.25, 0.28), PLASTER, Kit.PLASTER)
	k.box(Vector3(0, y + 0.32, 0.22), Vector3(0.5, 0.04, 0.36), beam, Kit.TIMBER)
	k.box(Vector3(0, y + 0.36, 0.22), Vector3(0.46, 0.26, 0.32), PLASTER, Kit.PLASTER)
	for i in 4:
		k.box(Vector3(-0.19 + i * 0.127 - 0.012, y + 0.36, 0.385), Vector3(0.024, 0.26, 0.02), beam, Kit.TIMBER)
	k.box(Vector3(0, y + 0.48, 0.385), Vector3(0.46, 0.02, 0.02), beam, Kit.TIMBER)
	k.window(Vector3(0, y + 0.5, 0.395), 0.0, 0.1, 0.08, beam, "lattice")
	k.gable_roof(Vector3(0, y + 0.62, 0.22), 0.34, 0.5, 0.26, 0.05, 0.035, ROOF, Kit.OWNER_ROOF, PLASTER, Kit.PLASTER, PI / 2.0)
	k.door(Vector3(0, y + 0.07, 0.365), 0.0, 0.17, 0.2, beam, Color(0.32, 0.2, 0.12))
	k.dome(Vector3(0, y + 0.27, 0.368), 0.085, Color(0.07, 0.05, 0.04), Kit.DARK, 0.5, 2, 8)
	for i in 3:
		k.box(Vector3(0, y, 0.42 + i * 0.06), Vector3(0.36 - i * 0.06, 0.07 - i * 0.02, 0.07), STONE_C, Kit.STONE)
	# guild emblems and banners
	_disc_z(k, Vector3(0, y + 0.36, 0.385), 0.0001, 0.001, GOLD_C, Kit.GOLD, 3)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.36 - 0.06, y + 0.37, 0.148), Vector3(0.12, 0.2, 0.01), OWNER_C, Kit.OWNER_CLOTH)
		k.tri(Vector3(s * 0.36 - 0.06, y + 0.37, 0.15), Vector3(s * 0.36 + 0.06, y + 0.37, 0.15), Vector3(s * 0.36, y + 0.33, 0.15),
			OWNER_C, Kit.OWNER_CLOTH, Vector3(s * 0.36, y + 0.45, 0.0))
		_disc_z(k, Vector3(s * 0.36, y + 0.48, 0.16), 0.03, 0.01, GOLD_C, Kit.GOLD, 8)
	# bell turret, chimney, lanterns
	var by := y + 0.62 + 0.3
	for sx: float in [-0.04, 0.04]:
		for sz: float in [-0.04, 0.04]:
			k.box(Vector3(sx - 0.008, by, -0.15 + sz - 0.008), Vector3(0.016, 0.12, 0.016), beam, Kit.TIMBER)
	k.frustum(Vector3(0, by + 0.03, -0.15), 0.035, 0.016, 0.06, GOLD_C, Kit.GOLD, 8)
	k.hip_roof(Vector3(0, by + 0.12, -0.15), 0.12, 0.12, 0.12, 0.03, 0.02, ROOF, Kit.OWNER_ROOF)
	k.chimney(Vector3(0.38, y + 0.7, -0.25), 0.08, 0.3, STONE_D)
	k.box(Vector3(0.38, y + 1.0, -0.25), Vector3(0.08, 0.012, 0.08), SOOT, Kit.DARK)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.26 - 0.012, y, 0.5), Vector3(0.024, 0.16, 0.024), WOOD, Kit.TIMBER)
		k.box(Vector3(s * 0.26 - 0.02, y + 0.16, 0.5 - 0.02), Vector3(0.04, 0.05, 0.04), GOLD_C, Kit.GOLD)
	# benches, barrels, a notice board, banner pole
	k.box(Vector3(-0.58, y + 0.04, 0.5), Vector3(0.26, 0.025, 0.07), WOODL, Kit.TIMBER)
	k.box(Vector3(-0.68, y, 0.5), Vector3(0.02, 0.04, 0.06), WOOD, Kit.TIMBER)
	k.box(Vector3(-0.48, y, 0.5), Vector3(0.02, 0.04, 0.06), WOOD, Kit.TIMBER)
	_barrel(k, Vector3(0.58, y, 0.5))
	_barrel(k, Vector3(0.68, y, 0.45), 0.045, 0.08)
	_crate(k, Vector3(0.52, y, 0.35), 0.08, 0.3)
	k.box(Vector3(-0.62, y, 0.15), Vector3(0.025, 0.22, 0.025), WOOD, Kit.TIMBER)
	k.box(Vector3(-0.7, y + 0.14, 0.14), Vector3(0.14, 0.12, 0.012), Color(0.9, 0.85, 0.7), Kit.CLOTH)
	k.banner(Vector3(0.7, y, 0.7), 0.65, 0.22)
	k.banner(Vector3(-0.7, y, 0.7), 0.65, 0.22)


# =============================================================================================
# harbour: a timber quay with a treadwheel crane, bollards, cargo and a moored boat
# =============================================================================================


static func _boat(k: Kit, c: Vector3, len: float, wid: float) -> void:
	k.push(Kit.at(c))
	var n := 8
	var secs: Array = []
	for i in n + 1:
		var t := -1.0 + 2.0 * i / n
		var w := wid / 2.0 * (1.0 - pow(absf(t), 2.4)) + 0.004
		var h := 0.085 + 0.07 * t * t
		var x := t * len / 2.0
		secs.append([Vector3(x, h, -w), Vector3(x, h * 0.35, -w * 0.82), Vector3(x, 0.0, 0.0),
			Vector3(x, h * 0.35, w * 0.82), Vector3(x, h, w)])
	var hull := Color(0.52, 0.34, 0.2)
	for i in n:
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		var cx := (a[2] as Vector3).x * 0.5 + (b[2] as Vector3).x * 0.5
		for q in 4:
			var p0: Vector3 = a[q]
			var p1: Vector3 = a[q + 1]
			var p2: Vector3 = b[q + 1]
			var p3: Vector3 = b[q]
			var col := hull if (i + q) % 2 == 0 else hull.lightened(0.08)
			k.quad(p0, p1, p2, p3, col, Kit.TIMBER, Vector3(cx, 0.1, 0.0))
			var side := -2.0 if q < 2 else 2.0
			var inner := hull.lightened(0.18)
			var lift := Vector3(0, 0.01, 0)
			var shrink := Vector3(0, 0, 0.012 * (1.0 if q < 2 else -1.0))
			k.quad(p0 + shrink + lift, p1 + shrink + lift, p2 + shrink + lift, p3 + shrink + lift, inner, Kit.TIMBER, Vector3(cx, 0.06, side))
	# gunwale rail in dark timber
	for i in n:
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		k.rod((a[0] as Vector3) + Vector3(0, 0.004, 0), (b[0] as Vector3) + Vector3(0, 0.004, 0), 0.007, WOOD, Kit.TIMBER)
		k.rod((a[4] as Vector3) + Vector3(0, 0.004, 0), (b[4] as Vector3) + Vector3(0, 0.004, 0), 0.007, WOOD, Kit.TIMBER)
	# thwarts, mast, sail, cargo
	for x: float in [-0.2, 0.0, 0.2]:
		k.box(Vector3(x, 0.06, -0.1), Vector3(0.04, 0.012, 0.2), WOODL, Kit.TIMBER)
	k.rod(Vector3(0.08, 0.02, 0), Vector3(0.08, 0.62, 0), 0.01, WOOD, Kit.TIMBER)
	var sail := OWNER_C
	k.tri(Vector3(0.08, 0.6, 0.0), Vector3(0.08, 0.2, 0.0), Vector3(-0.3, 0.2, 0.0), sail, Kit.OWNER_CLOTH, Vector3(0, 0.3, 1.0))
	k.tri(Vector3(0.08, 0.6, 0.0), Vector3(0.08, 0.2, 0.0), Vector3(-0.3, 0.2, 0.0), sail.darkened(0.15), Kit.OWNER_CLOTH, Vector3(0, 0.3, -1.0))
	k.tri(Vector3(0.08, 0.5, 0.0), Vector3(0.08, 0.2, 0.0), Vector3(0.34, 0.2, 0.0), CREAM, Kit.CLOTH, Vector3(0, 0.3, 1.0))
	k.tri(Vector3(0.08, 0.5, 0.0), Vector3(0.08, 0.2, 0.0), Vector3(0.34, 0.2, 0.0), CREAM.darkened(0.1), Kit.CLOTH, Vector3(0, 0.3, -1.0))
	k.rod(Vector3(-0.3, 0.2, 0.0), Vector3(0.34, 0.2, 0.0), 0.008, WOOD, Kit.TIMBER)
	k.box(Vector3(-0.28, 0.0, 0.0), Vector3(0.08, 0.08, 0.1), WOODL, Kit.TIMBER)
	k.box(Vector3(-0.2, 0.0, 0.04), Vector3(0.06, 0.06, 0.07), WOOD, Kit.TIMBER)
	_barrel(k, Vector3(0.22, 0.01, 0.04), 0.04, 0.07)
	k.frustum(Vector3(len / 2.0 - 0.01, 0.15, 0), 0.012, 0.0, 0.05, GOLD_C, Kit.GOLD, 4)
	k.pop()


static func _harbour(k: Kit) -> void:
	k.bevel_box(Vector3(0, 0, -0.3), Vector3(1.56, G, 1.0), 0.012, Color(0.60, 0.55, 0.44), Kit.EARTH)
	k.box(Vector3(0, 0.0, 0.58), Vector3(1.56, 0.02, 0.45), WATER_C, Kit.WATER)
	var y := G
	var dy := y + 0.07
	# the quay: stone foot, plank deck, piles, rope rail
	k.box(Vector3(0, y, 0.05), Vector3(1.54, 0.07, 0.4), Color(0.55, 0.4, 0.26), Kit.TIMBER)
	for i in 8:
		k.box(Vector3(-0.7 + i * 0.2, dy, 0.05), Vector3(0.18, 0.01, 0.4), WOODL.lightened(0.04 * (i % 2)), Kit.TIMBER)
	for i in 7:
		k.frustum(Vector3(-0.72 + i * 0.24, 0.0, 0.26), 0.035, 0.032, 0.16, WOOD, Kit.TIMBER, 6)
		k.frustum(Vector3(-0.72 + i * 0.24, 0.16, 0.26), 0.032, 0.0, 0.025, WOOD, Kit.TIMBER, 6)
	for i in 4:   # bollards
		var bx := -0.6 + i * 0.38
		k.frustum(Vector3(bx, dy + 0.01, 0.2), 0.022, 0.017, 0.055, IRON, Kit.PAINT, 6)
		k.frustum(Vector3(bx, dy + 0.065, 0.2), 0.03, 0.03, 0.012, IRON, Kit.PAINT, 6)
	# warehouse at the back
	k.box(Vector3(0.22, y, -0.5), Vector3(0.95, 0.06, 0.4), STONE_D, Kit.STONE)
	k.box(Vector3(0.22, y + 0.06, -0.5), Vector3(0.9, 0.3, 0.36), Color(0.76, 0.6, 0.4), Kit.TIMBER)
	for i in 8:
		k.box(Vector3(-0.2 + i * 0.125, y + 0.06, -0.318), Vector3(0.02, 0.3, 0.02), WOOD, Kit.TIMBER)
	k.gable_roof(Vector3(0.22, y + 0.36, -0.5), 0.9, 0.36, 0.24, 0.07, 0.035, ROOF, Kit.OWNER_ROOF, Color(0.76, 0.6, 0.4), Kit.TIMBER)
	k.door(Vector3(0.22, y + 0.06, -0.318), 0.0, 0.22, 0.24, WOOD, Color(0.3, 0.2, 0.12))
	k.window(Vector3(0.0, y + 0.3, -0.318), 0.0, 0.07, 0.07, WOOD, "frame")
	k.window(Vector3(0.45, y + 0.3, -0.318), 0.0, 0.07, 0.07, WOOD, "frame")
	k.rod(Vector3(0.22, y + 0.5, -0.32), Vector3(0.22, y + 0.5, -0.12), 0.012, WOOD, Kit.TIMBER)   # hoist beam
	k.rod(Vector3(0.22, y + 0.5, -0.12), Vector3(0.22, y + 0.3, -0.12), 0.004, SOOT, Kit.DARK)
	_sack(k, Vector3(0.22, y + 0.23, -0.12), CREAM, 0.8)
	# the treadwheel crane
	var cx := -0.52
	k.box(Vector3(cx, dy, 0.0), Vector3(0.1, 0.03, 0.1), WOOD, Kit.TIMBER)
	k.box(Vector3(cx - 0.025, dy + 0.03, -0.025), Vector3(0.05, 0.55, 0.05), WOOD, Kit.TIMBER)
	k.rod(Vector3(cx, dy + 0.5, 0.0), Vector3(cx, dy + 0.46, 0.34), 0.022, WOOD, Kit.TIMBER)
	k.rod(Vector3(cx, dy + 0.25, 0.0), Vector3(cx, dy + 0.47, 0.22), 0.012, WOOD, Kit.TIMBER)
	k.rod(Vector3(cx, dy + 0.5, 0.0), Vector3(cx, dy + 0.5, -0.14), 0.016, WOOD, Kit.TIMBER)
	k.box(Vector3(cx - 0.03, dy + 0.62, -0.03), Vector3(0.06, 0.04, 0.06), WOOD, Kit.TIMBER)
	k.rod(Vector3(cx, dy + 0.46, 0.34), Vector3(cx, dy + 0.3, 0.34), 0.004, SOOT, Kit.DARK)
	k.box(Vector3(cx - 0.025, dy + 0.15, 0.32), Vector3(0.05, 0.02, 0.05), GOLD_C, Kit.GOLD)
	_crate(k, Vector3(cx, dy + 0.0 + 0.13, 0.325), 0.06, 0.0)
	_ring(k, Vector3(cx + 0.09, dy + 0.14, 0.0), Vector3(0, 1, 0), Vector3(0, 0, 1), 0.12, 12, 0.008, WOOD, Kit.TIMBER)
	_ring(k, Vector3(cx - 0.09, dy + 0.14, 0.0), Vector3(0, 1, 0), Vector3(0, 0, 1), 0.12, 12, 0.008, WOOD, Kit.TIMBER)
	for i in 6:
		var a := i * PI / 6.0
		k.rod(Vector3(cx + 0.09, dy + 0.14 + cos(a) * 0.12, sin(a) * 0.12), Vector3(cx + 0.09, dy + 0.14 - cos(a) * 0.12, -sin(a) * 0.12), 0.006, WOODL, Kit.TIMBER)
		k.box(Vector3(cx - 0.09, dy + 0.14 + cos(a) * 0.12 - 0.006, sin(a) * 0.12 - 0.006), Vector3(0.18, 0.012, 0.012), WOODL, Kit.TIMBER)
	# cargo on the quay
	for i in 3:
		_crate(k, Vector3(0.0 + i * 0.1, dy, 0.08), 0.09, 0.1 * i)
	_crate(k, Vector3(0.05, dy + 0.075, 0.08), 0.08, 0.4)
	_barrel(k, Vector3(0.45, dy, 0.1))
	_barrel(k, Vector3(0.55, dy, 0.05))
	_barrel(k, Vector3(0.5, dy, -0.04), 0.045, 0.08)
	for i in 3:
		_sack(k, Vector3(0.7, dy + 0.0, -0.05 + i * 0.08), CREAM)
	k.dome(Vector3(-0.2, dy, 0.0), 0.1, Color(0.5, 0.55, 0.5), Kit.CLOTH, 0.4, 2, 7)   # coiled net
	k.box(Vector3(0.7, y, 0.4), Vector3(0.0, 0.0, 0.0), WOOD, Kit.TIMBER)
	# a lamp post and a banner
	k.box(Vector3(0.74 - 0.012, dy, 0.18), Vector3(0.024, 0.28, 0.024), IRON, Kit.PAINT)
	k.box(Vector3(0.74 - 0.025, dy + 0.28, 0.165), Vector3(0.05, 0.05, 0.05), GOLD_C, Kit.GOLD)
	k.banner(Vector3(-0.72, y, -0.1), 0.6, 0.2)
	# a moored boat with ropes to the bollards
	_boat(k, Vector3(0.2, 0.01, 0.58), 0.85, 0.26)
	k.rod(Vector3(-0.2, 0.1, 0.55), Vector3(-0.22, dy + 0.04, 0.22), 0.004, Color(0.7, 0.6, 0.4), Kit.CLOTH)
	k.rod(Vector3(0.62, 0.12, 0.58), Vector3(0.55, dy + 0.04, 0.22), 0.004, Color(0.7, 0.6, 0.4), Kit.CLOTH)

