## Generic settlement props (D-281): the small life that makes a village or city look lived in.
## Barrels and crates, carts, hay, wells, fences, market stalls, washing, boats, nets, statues.
## Models face +z, stand on y = 0, centred on x = z = 0 (1.0 = an ordinary house's width), and
## are drawn a little chunkier than true scale so they read from the high three-quarter camera.
## Fence-like kinds (fence, wattle, stone_wall) are exactly 1.0 long along x so they tile.
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")

const WOOD := Color(0.54, 0.37, 0.22)
const WOOD_D := Color(0.36, 0.25, 0.15)
const WOOD_L := Color(0.72, 0.55, 0.34)
const IRON := Color(0.24, 0.22, 0.21)
const STONE_C := Color(0.64, 0.61, 0.55)
const STONE_D := Color(0.52, 0.50, 0.46)
const HAY := Color(0.88, 0.74, 0.36)
const SACK := Color(0.80, 0.72, 0.54)
const CREAM := Color(0.93, 0.89, 0.78)


static func kinds() -> Array:
	return ["barrel", "barrels", "barrels_2", "crate", "crates", "crates_2", "sacks", "woodpile",
		"haystack", "haystack_2", "cart", "cart_loaded", "handcart", "well", "trough", "bench",
		"fence", "wattle", "stone_wall", "gate_small", "market_stall", "laundry", "pots",
		"cooking_fire", "beehives", "scarecrow", "signpost", "boat", "nets", "statue", "fountain",
		"rocks", "rocks_2", "timber"]


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	match kind:
		"barrel":
			_barrel(k, Vector3.ZERO, 0.065, 0.15, 8, 2)
		"barrels":
			_barrel(k, Vector3(-0.06, 0, 0.03), 0.06, 0.14, 6, 1)
			_barrel(k, Vector3(0.06, 0, 0.0), 0.06, 0.15, 6, 1)
			_barrel(k, Vector3(0.0, 0, -0.07), 0.06, 0.14, 6, 1)
		"barrels_2":
			_barrel(k, Vector3(-0.065, 0, 0.0), 0.06, 0.15, 6, 1)
			_barrel(k, Vector3(0.065, 0, 0.0), 0.06, 0.15, 6, 1)
			# one lying across the two on top (axis along z)
			k.push(Transform3D(Basis(Vector3(1, 0, 0), PI / 2.0), Vector3(0, 0.215, -0.07)))
			_barrel(k, Vector3.ZERO, 0.055, 0.14, 6, 1)
			k.pop()
		"crate":
			_crate(k, Vector3.ZERO, 0.13, 0.0, true)
		"crates":
			_crate(k, Vector3(-0.07, 0, 0.0), 0.12, 0.1, false)
			_crate(k, Vector3(0.075, 0, 0.02), 0.12, -0.15, false)
			_crate(k, Vector3(0.0, 0.12, 0.01), 0.11, 0.5, false)
		"crates_2":
			_crate(k, Vector3(-0.07, 0, 0.0), 0.12, -0.1, false)
			_crate(k, Vector3(0.07, 0, -0.01), 0.1, 0.25, false)
			_barrel(k, Vector3(0.0, 0, 0.1), 0.055, 0.13, 6, 1)
		"sacks":
			_sack(k, Vector3(-0.055, 0, 0.0), 1.0, 0)
			_sack(k, Vector3(0.055, 0, 0.0), 0.95, 1)
			_sack(k, Vector3(0.0, 0.065, -0.005), 0.9, 2)
		"woodpile":
			_woodpile(k)
		"haystack":
			_blob(k, Vector3(0, 0.07, 0), 0.19, 0.21, 0.19, 3, 9, HAY, Kit.THATCH, 0.1, 3, -0.4)
		"haystack_2":
			_rick(k)
		"cart":
			_cart(k, false)
		"cart_loaded":
			_cart(k, true)
		"handcart":
			_handcart(k)
		"well":
			_well(k)
		"trough":
			_trough(k)
		"bench":
			_bench(k)
		"fence":
			_fence(k)
		"wattle":
			_wattle(k)
		"stone_wall":
			_stone_wall(k)
		"gate_small":
			_gate(k)
		"market_stall":
			_stall(k)
		"laundry":
			_laundry(k)
		"pots":
			_pots(k)
		"cooking_fire":
			_fire(k)
		"beehives":
			_beehives(k)
		"scarecrow":
			_scarecrow(k)
		"signpost":
			_signpost(k)
		"boat":
			_boat(k)
		"nets":
			_nets(k)
		"statue":
			_statue(k)
		"fountain":
			_fountain(k)
		"rocks":
			_blob(k, Vector3(-0.02, 0.025, 0.0), 0.11, 0.1, 0.09, 3, 7, STONE_C, Kit.STONE, 0.14, 11, -0.4)
			_blob(k, Vector3(0.1, 0.02, 0.05), 0.07, 0.06, 0.065, 2, 6, STONE_D, Kit.STONE, 0.15, 5, -0.4)
			_blob(k, Vector3(0.03, 0.015, -0.1), 0.055, 0.05, 0.05, 2, 6, STONE_C.darkened(0.08), Kit.STONE, 0.15, 8, -0.4)
		"rocks_2":
			_blob(k, Vector3(0, 0.04, 0.0), 0.12, 0.16, 0.11, 3, 7, STONE_D, Kit.STONE, 0.16, 21, -0.5)
			_blob(k, Vector3(0.11, 0.015, 0.06), 0.06, 0.05, 0.055, 2, 6, STONE_C, Kit.STONE, 0.15, 2, -0.4)
			# a cap of moss on the tall boulder
			_blob(k, Vector3(0.0, 0.14, 0.0), 0.07, 0.05, 0.065, 2, 6, Color(0.40, 0.55, 0.28), Kit.LEAF, 0.12, 9, 0.0)
		"timber":
			_timber(k)
	return k.finish()


# --- helpers -----------------------------------------------------------------------------------


## A repeatable pseudo-random number 0..1 from an integer (so models never change between runs).
static func _h(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)


## A rough rounded lump (boulder, haystack, bush of straw): a half sphere of `rings` rings whose
## points are jittered by `jit`, starting `p0` radians from the equator (negative = a skirt below).
static func _blob(k: Kit, c: Vector3, rx: float, ry: float, rz: float, rings: int, sides: int,
		col: Color, mat: int, jit := 0.12, seed := 0, p0 := 0.0) -> void:
	var inside := c + Vector3(0, ry * 0.2, 0)
	var rows: Array = []
	for i in rings:
		var p := lerpf(p0, PI / 2.0, float(i) / rings)
		var ring: Array = []
		for s in sides:
			var a := s * TAU / sides
			var j := 1.0 + jit * (_h(seed * 131 + i * 17 + s * 5) - 0.5) * 2.0
			ring.append(c + Vector3(cos(a) * cos(p) * rx * j, maxf(sin(p) * ry * j, -c.y + 0.0), sin(a) * cos(p) * rz * j))
		rows.append(ring)
	var apex := c + Vector3(0, ry * (1.0 + jit * (_h(seed * 131 + 99) - 0.5)), 0)
	for i in rings - 1:
		for s in sides:
			var t := (s + 1) % sides
			var col2 := col.darkened(0.04 * float(i == 0))
			k.quad(rows[i][s], rows[i][t], rows[i + 1][t], rows[i + 1][s], col2, mat, inside)
	for s in sides:
		var t := (s + 1) % sides
		k.tri(rows[rings - 1][s], rows[rings - 1][t], apex, col.lightened(0.05), mat, inside)


## A flat quad drawn from both sides (cloth, nets, leaves of a gate).
static func _flat(k: Kit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, mat: int) -> void:
	k.quad(a, b, c, d, col, mat)
	k.quad(a, d, c, b, col, mat)


## A flat triangle drawn from both sides.
static func _flat_tri(k: Kit, a: Vector3, b: Vector3, c: Vector3, col: Color, mat: int) -> void:
	k.tri(a, b, c, col, mat)
	k.tri(a, c, b, col, mat)


## A flat ring seen from above (the top of a well or basin wall).
static func _annulus(k: Kit, y: float, r_out: float, r_in: float, sides: int, col: Color, mat: int) -> void:
	for s in sides:
		var a0 := s * TAU / sides
		var a1 := (s + 1) * TAU / sides
		k.quad(Vector3(cos(a0) * r_out, y, sin(a0) * r_out), Vector3(cos(a1) * r_out, y, sin(a1) * r_out),
			Vector3(cos(a1) * r_in, y, sin(a1) * r_in), Vector3(cos(a0) * r_in, y, sin(a0) * r_in),
			col, mat, Vector3(0, y - 1.0, 0))


static func _disc(k: Kit, y: float, r: float, sides: int, col: Color, mat: int) -> void:
	var pts: Array = []
	for s in sides:
		var a := s * TAU / sides
		pts.append(Vector3(cos(a) * r, y, sin(a) * r))
	k.polygon(pts, col, mat, Vector3(0, y - 1.0, 0))


## A barrel: bulging belly (two frusta), iron hoops. Footed at `pos`.
static func _barrel(k: Kit, pos: Vector3, r: float, h: float, sides: int, hoops: int) -> void:
	var wood := WOOD.lightened(0.04 * float(int(pos.x * 100.0) % 3))
	k.frustum(pos, r * 0.84, r, h * 0.5, wood, Kit.TIMBER, sides, false)
	k.frustum(pos + Vector3(0, h * 0.5, 0), r, r * 0.84, h * 0.5, wood, Kit.TIMBER, sides, true)
	var ys := [0.17, 0.74] if hoops >= 2 else [0.2]
	for yf in ys:
		var f: float = yf
		var local := (0.84 + 0.16 * (f / 0.5)) if f < 0.5 else (0.84 + 0.16 * ((1.0 - f) / 0.5))
		k.frustum(pos + Vector3(0, h * f, 0), r * local * 1.05, r * local * 1.05, h * 0.07, IRON, Kit.DARK, sides, false)


## A slatted crate; `strong` adds corner posts.
static func _crate(k: Kit, pos: Vector3, s: float, yaw: float, strong: bool) -> void:
	k.box(pos, Vector3(s, s * 0.82, s), WOOD_L, Kit.TIMBER, yaw)
	k.box(pos + Vector3(0, s * 0.82, 0), Vector3(s * 1.1, s * 0.12, s * 1.1), WOOD, Kit.TIMBER, yaw)
	var posts := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)] if strong else [Vector3(-1, 0, 1), Vector3(1, 0, 1)]
	k.push(Kit.at(pos, yaw))
	for q in posts:
		var o: Vector3 = q
		k.box(Vector3(o.x * s * 0.5, 0, o.z * s * 0.5), Vector3(s * 0.12, s * 0.84, s * 0.12), WOOD_D, Kit.TIMBER)
	k.pop()


## A bulging sack with a tied neck.
static func _sack(k: Kit, pos: Vector3, scale: float, n: int) -> void:
	var col := SACK.darkened(0.06 * n)
	var r := 0.058 * scale
	k.frustum(pos, r * 0.95, r, 0.05 * scale, col, Kit.CLOTH, 5, false)
	k.frustum(pos + Vector3(0, 0.05 * scale, 0), r, r * 0.35, 0.04 * scale, col.lightened(0.04), Kit.CLOTH, 5, true)


## A stack of split logs seen end on, with the cut faces pale.
static func _woodpile(k: Kit) -> void:
	var bark := Color(0.40, 0.28, 0.17)
	var cut := Color(0.80, 0.62, 0.40)
	var widths := [0.34, 0.28, 0.2]
	for row in 3:
		var w: float = widths[row]
		k.box(Vector3(0, 0.05 * row, 0), Vector3(w, 0.05, 0.17), bark.lightened(0.03 * row), Kit.TIMBER)
		var n := 4 - row
		for i in n:
			var x := (i - (n - 1) / 2.0) * (w / n)
			var pts: Array = []
			for s in 6:
				var a := s * TAU / 6.0
				pts.append(Vector3(x + cos(a) * 0.026, 0.025 + 0.05 * row + sin(a) * 0.024, 0.0865))
			k.polygon(pts, cut.darkened(0.05 * ((i + row) % 2)), Kit.TIMBER, Vector3(x, 0.025 + 0.05 * row, 0.0))
	# two stakes hold the pile
	for sx in [-0.17, 0.17]:
		var x2: float = sx
		k.box(Vector3(x2, 0, 0.09), Vector3(0.025, 0.12, 0.025), WOOD_D, Kit.TIMBER)


## A rectangular straw rick under a little thatched hat, with a ladder rung of stakes.
static func _rick(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(0.3, 0.1, 0.2), HAY.darkened(0.06), Kit.THATCH)
	k.gable_roof(Vector3(0, 0.1, 0), 0.3, 0.2, 0.13, 0.025, 0.02, HAY, Kit.THATCH, HAY, Kit.THATCH)
	for sx in [-0.16, 0.16]:
		var x: float = sx
		k.rod(Vector3(x, 0, 0.11), Vector3(x, 0.14, 0.11), 0.01, WOOD_D, Kit.TIMBER)


## A spoked wheel, axle along x, centred on `c`. `spokes` diameters across.
static func _wheel(k: Kit, c: Vector3, radius: float, thick: float, segs: int, spokes: int) -> void:
	var ri := radius * 0.76
	var hx := thick / 2.0
	for s in segs:
		var a0 := s * TAU / segs
		var a1 := (s + 1) * TAU / segs
		var d0 := Vector3(0, sin(a0), cos(a0))
		var d1 := Vector3(0, sin(a1), cos(a1))
		var xm := Vector3(-hx, 0, 0)
		var xp := Vector3(hx, 0, 0)
		k.quad(c + xm + d0 * radius, c + xp + d0 * radius, c + xp + d1 * radius, c + xm + d1 * radius, WOOD_D, Kit.TIMBER, c)
		k.quad(c + xp + d0 * ri, c + xp + d0 * radius, c + xp + d1 * radius, c + xp + d1 * ri, WOOD, Kit.TIMBER, c)
		k.quad(c + xm + d0 * ri, c + xm + d0 * radius, c + xm + d1 * radius, c + xm + d1 * ri, WOOD, Kit.TIMBER, c)
	for j in spokes:
		var a := 0.35 + j * PI / spokes
		var d := Vector3(0, sin(a), cos(a))
		var perp := Vector3(0, -cos(a), sin(a)) * thick * 0.55
		_flat(k, c - d * ri - perp, c + d * ri - perp, c + d * ri + perp, c - d * ri + perp, WOOD_L, Kit.TIMBER)


## A two-wheeled farm cart facing +z, shafts forward; optionally piled with hay.
static func _cart(k: Kit, loaded: bool) -> void:
	var wz := -0.02
	for sx in [-0.14, 0.14]:
		var x: float = sx
		_wheel(k, Vector3(x, 0.1, wz), 0.1, 0.03, 7, 3)
	k.rod(Vector3(-0.15, 0.1, wz), Vector3(0.15, 0.1, wz), 0.012, WOOD_D, Kit.TIMBER)
	k.box(Vector3(0, 0.1, 0.0), Vector3(0.22, 0.02, 0.3), WOOD, Kit.TIMBER)
	for sx in [-0.1, 0.1]:
		var x2: float = sx
		k.box(Vector3(x2, 0.12, 0.0), Vector3(0.02, 0.07, 0.3), WOOD_L, Kit.TIMBER)
	k.box(Vector3(0, 0.12, -0.14), Vector3(0.2, 0.07, 0.02), WOOD_L, Kit.TIMBER)
	k.box(Vector3(0, 0.12, 0.14), Vector3(0.2, 0.05, 0.02), WOOD_L, Kit.TIMBER)
	for sx in [-0.06, 0.06]:
		var x3: float = sx
		k.rod(Vector3(x3, 0.105, 0.12), Vector3(x3 * 0.8, 0.07, 0.29), 0.011, WOOD_D, Kit.TIMBER)
	if loaded:
		_blob(k, Vector3(0, 0.125, 0.0), 0.12, 0.1, 0.16, 2, 7, HAY, Kit.THATCH, 0.1, 6, -0.2)


## A small two-wheeled handcart with a load of sacks, handles at the back.
static func _handcart(k: Kit) -> void:
	for sx in [-0.1, 0.1]:
		var x: float = sx
		_wheel(k, Vector3(x, 0.07, 0.0), 0.07, 0.025, 6, 1)
	k.rod(Vector3(-0.1, 0.07, 0.0), Vector3(0.1, 0.07, 0.0), 0.01, WOOD_D, Kit.TIMBER)
	k.box(Vector3(0, 0.075, 0.02), Vector3(0.16, 0.02, 0.2), WOOD, Kit.TIMBER)
	for sx in [-0.075, 0.075]:
		var x2: float = sx
		k.box(Vector3(x2, 0.095, 0.02), Vector3(0.015, 0.05, 0.2), WOOD_L, Kit.TIMBER)
		k.rod(Vector3(x2, 0.09, -0.06), Vector3(x2 * 0.8, 0.12, -0.2), 0.01, WOOD_D, Kit.TIMBER)
	k.box(Vector3(0, 0.095, 0.12), Vector3(0.15, 0.05, 0.015), WOOD_L, Kit.TIMBER)
	_blob(k, Vector3(0, 0.1, 0.02), 0.07, 0.07, 0.09, 2, 5, SACK, Kit.CLOTH, 0.12, 12, -0.3)


## A stone well: ring wall, water, two posts with a little thatched roof, windlass and bucket.
static func _well(k: Kit) -> void:
	k.frustum(Vector3.ZERO, 0.135, 0.125, 0.13, STONE_C, Kit.STONE, 9, false)
	_annulus(k, 0.13, 0.125, 0.085, 9, STONE_D, Kit.STONE)
	_disc(k, 0.105, 0.087, 9, Color(0.30, 0.50, 0.65), Kit.WATER)
	for sx in [-0.105, 0.105]:
		var x: float = sx
		k.box(Vector3(x, 0.13, 0.0), Vector3(0.03, 0.2, 0.03), WOOD, Kit.TIMBER)
	k.rod(Vector3(-0.12, 0.27, 0.0), Vector3(0.12, 0.27, 0.0), 0.014, WOOD_D, Kit.TIMBER)
	k.gable_roof(Vector3(0, 0.33, 0), 0.28, 0.2, 0.1, 0.035, 0.02, Color(0.82, 0.68, 0.38), Kit.THATCH,
		Color(0.8, 0.66, 0.4), Kit.THATCH)
	k.rod(Vector3(0.0, 0.27, 0.0), Vector3(0.0, 0.18, 0.0), 0.005, WOOD_D, Kit.TIMBER)
	k.frustum(Vector3(0.0, 0.14, 0.0), 0.028, 0.034, 0.04, WOOD_D, Kit.TIMBER, 6, false)


## A drinking trough of boards with water in it.
static func _trough(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(0.34, 0.03, 0.12), WOOD_D, Kit.TIMBER)
	for sz in [-0.05, 0.05]:
		var z: float = sz
		k.box(Vector3(0, 0.03, z), Vector3(0.34, 0.06, 0.025), WOOD, Kit.TIMBER)
	for sx in [-0.165, 0.165]:
		var x: float = sx
		k.box(Vector3(x, 0, 0), Vector3(0.025, 0.1, 0.13), WOOD_D, Kit.TIMBER)
	var y := 0.075
	k.quad(Vector3(-0.15, y, -0.04), Vector3(0.15, y, -0.04), Vector3(0.15, y, 0.04), Vector3(-0.15, y, 0.04),
		Color(0.30, 0.52, 0.66), Kit.WATER, Vector3(0, 0, 0))


## A plank bench with a backrest.
static func _bench(k: Kit) -> void:
	for sx in [-0.12, 0.12]:
		var x: float = sx
		k.box(Vector3(x, 0, 0), Vector3(0.025, 0.08, 0.1), WOOD_D, Kit.TIMBER)
		k.box(Vector3(x, 0.08, -0.05), Vector3(0.025, 0.09, 0.02), WOOD_D, Kit.TIMBER)
	k.box(Vector3(0, 0.08, 0.0), Vector3(0.32, 0.02, 0.11), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.12, -0.05), Vector3(0.32, 0.05, 0.015), WOOD_L, Kit.TIMBER)


## Post-and-rail fence, exactly 1.0 along x (end posts are half-width so tiles meet in one post).
static func _fence(k: Kit) -> void:
	k.box(Vector3(-0.49, 0, 0), Vector3(0.02, 0.17, 0.04), WOOD_D, Kit.TIMBER)
	k.box(Vector3(0.49, 0, 0), Vector3(0.02, 0.17, 0.04), WOOD_D, Kit.TIMBER)
	k.box(Vector3(0, 0, 0), Vector3(0.04, 0.18, 0.04), WOOD_D, Kit.TIMBER)
	k.box(Vector3(0, 0.055, 0.03), Vector3(1.0, 0.025, 0.02), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.115, 0.03), Vector3(1.0, 0.025, 0.02), WOOD, Kit.TIMBER)


## Woven hazel fence: stakes with willow bands, 1.0 along x.
static func _wattle(k: Kit) -> void:
	var weave := Color(0.66, 0.50, 0.30)
	for i in 6:
		var x := -0.45 + 0.18 * i
		k.rod(Vector3(x, 0, 0), Vector3(x, 0.2 - 0.02 * (i % 2), 0), 0.012, WOOD_D, Kit.TIMBER)
	for b in 3:
		var big := 0.036 if b % 2 == 0 else 0.028
		k.box(Vector3(0, 0.025 + 0.05 * b, 0), Vector3(1.0, 0.045, big), weave.darkened(0.1 * (b % 2)), Kit.TIMBER)


## Dry-stone wall: a broad base and an uneven course of rounded stones, 1.0 along x.
static func _stone_wall(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(1.0, 0.07, 0.12), STONE_D, Kit.STONE)
	var xs := [-0.5, -0.24, 0.0, 0.25, 0.5]
	for i in 4:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		var hh := 0.06 + 0.04 * _h(i + 40)
		k.bevel_box(Vector3((x0 + x1) / 2.0, 0.07, 0), Vector3(x1 - x0, hh, 0.1 + 0.02 * _h(i + 7)),
			0.02, STONE_C.lightened(0.05 * float(i % 2)).darkened(0.05 * _h(i + 3)), Kit.STONE)


## A yard gate, 0.3 wide, between two posts.
static func _gate(k: Kit) -> void:
	for sx in [-0.16, 0.16]:
		var x: float = sx
		k.box(Vector3(x, 0, 0), Vector3(0.035, 0.2, 0.035), WOOD_D, Kit.TIMBER)
	k.box(Vector3(0, 0.03, 0), Vector3(0.29, 0.03, 0.02), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.15, 0), Vector3(0.29, 0.03, 0.02), WOOD, Kit.TIMBER)
	k.box(Vector3(-0.13, 0.03, 0.0), Vector3(0.025, 0.15, 0.02), WOOD, Kit.TIMBER)
	k.box(Vector3(0.13, 0.03, 0.0), Vector3(0.025, 0.15, 0.02), WOOD, Kit.TIMBER)
	k.rod(Vector3(-0.13, 0.045, 0.012), Vector3(0.13, 0.15, 0.012), 0.009, WOOD_L, Kit.TIMBER)


## A market stall: four posts, a counter with goods, a striped awning in the owner's colour.
static func _stall(k: Kit) -> void:
	for sx in [-0.18, 0.18]:
		var x: float = sx
		k.rod(Vector3(x, 0, 0.12), Vector3(x, 0.24, 0.12), 0.011, WOOD_D, Kit.TIMBER)
		k.rod(Vector3(x, 0, -0.12), Vector3(x, 0.31, -0.12), 0.011, WOOD_D, Kit.TIMBER)
	k.box(Vector3(0, 0, 0.04), Vector3(0.34, 0.09, 0.1), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.09, 0.04), Vector3(0.37, 0.015, 0.13), WOOD_L, Kit.TIMBER)
	# goods on the counter: a basket of apples, a cabbage, a bolt of cloth
	k.frustum(Vector3(-0.1, 0.105, 0.04), 0.035, 0.042, 0.025, WOOD_L, Kit.TIMBER, 6, false)
	_blob(k, Vector3(-0.1, 0.125, 0.04), 0.04, 0.03, 0.04, 2, 5, Color(0.82, 0.22, 0.16), Kit.PAINT, 0.1, 4, -0.2)
	_blob(k, Vector3(0.02, 0.105, 0.05), 0.04, 0.035, 0.04, 2, 5, Color(0.45, 0.65, 0.30), Kit.LEAF, 0.1, 6, 0.0)
	k.box(Vector3(0.12, 0.105, 0.04), Vector3(0.07, 0.04, 0.05), Color(0.32, 0.42, 0.72), Kit.CLOTH, 0.2)
	# awning, sloping down to the front, in alternating stripes with a scalloped edge
	for i in 4:
		var x0 := -0.2 + 0.1 * i
		var x1 := x0 + 0.1
		var owner := i % 2 == 0
		var col := Color(0.96, 0.96, 0.96) if owner else CREAM
		var mat := Kit.OWNER_CLOTH if owner else Kit.CLOTH
		_flat(k, Vector3(x0, 0.315, -0.14), Vector3(x1, 0.315, -0.14), Vector3(x1, 0.245, 0.17), Vector3(x0, 0.245, 0.17), col, mat)
		_flat_tri(k, Vector3(x0, 0.245, 0.17), Vector3(x1, 0.245, 0.17), Vector3((x0 + x1) / 2.0, 0.195, 0.17), col, mat)


## A washing line between two poles with cloths hanging.
static func _laundry(k: Kit) -> void:
	for sx in [-0.2, 0.2]:
		var x: float = sx
		k.rod(Vector3(x, 0, 0), Vector3(x, 0.24, 0), 0.011, WOOD_D, Kit.TIMBER)
	k.rod(Vector3(-0.2, 0.22, 0), Vector3(0.2, 0.2, 0), 0.004, WOOD_L, Kit.TIMBER)
	var cols := [Color(0.95, 0.93, 0.88), Color(0.80, 0.30, 0.25), Color(0.35, 0.50, 0.75), Color(0.93, 0.85, 0.55)]
	for i in 4:
		var x := -0.15 + 0.1 * i
		var top := 0.22 - 0.01 * (i + 0.5) / 2.0 * 0.5
		var w := 0.07
		var drop := 0.1 + 0.03 * (i % 2)
		var col: Color = cols[i]
		var mat := Kit.OWNER_CLOTH if i == 1 else Kit.CLOTH
		_flat(k, Vector3(x - w / 2, top, 0), Vector3(x + w / 2, top, 0), Vector3(x + w / 2 + 0.01, top - drop, 0.012),
			Vector3(x - w / 2 + 0.01, top - drop, 0.012), col, mat)


## A cluster of clay jars.
static func _pots(k: Kit) -> void:
	var clay := Color(0.74, 0.44, 0.28)
	_jar(k, Vector3(-0.05, 0, 0.0), 1.15, clay)
	_jar(k, Vector3(0.06, 0, 0.02), 0.95, clay.darkened(0.08))
	_jar(k, Vector3(0.0, 0, 0.08), 0.75, clay.lightened(0.06))


static func _jar(k: Kit, pos: Vector3, s: float, col: Color) -> void:
	k.frustum(pos, 0.032 * s, 0.056 * s, 0.05 * s, col, Kit.PAINT, 6, false)
	k.frustum(pos + Vector3(0, 0.05 * s, 0), 0.056 * s, 0.03 * s, 0.05 * s, col, Kit.PAINT, 6, false)
	var pts: Array = []
	for i in 6:
		var a := i * TAU / 6.0
		pts.append(pos + Vector3(cos(a) * 0.026 * s, 0.1005 * s, sin(a) * 0.026 * s))
	k.polygon(pts, Color(0.12, 0.08, 0.06), Kit.DARK, pos + Vector3(0, 0, 0))


## A camp cooking fire: a ring of stones, crossed logs and flames.
static func _fire(k: Kit) -> void:
	for i in 4:
		var a := 0.4 + i * TAU / 4.0
		_blob(k, Vector3(cos(a) * 0.085, 0.01, sin(a) * 0.085), 0.04, 0.035, 0.04, 2, 4, STONE_C.darkened(0.06 * (i % 2)), Kit.STONE, 0.1, i + 30, -0.2)
	k.rod(Vector3(-0.07, 0.03, -0.02), Vector3(0.07, 0.045, 0.03), 0.014, WOOD_D, Kit.TIMBER)
	k.rod(Vector3(0.05, 0.03, -0.05), Vector3(-0.04, 0.045, 0.06), 0.014, WOOD, Kit.TIMBER)
	k.frustum(Vector3(0, 0.04, 0), 0.05, 0.0, 0.15, Color(1.0, 0.45, 0.12), Kit.PAINT, 4)
	k.frustum(Vector3(0, 0.04, 0), 0.03, 0.0, 0.1, Color(1.0, 0.82, 0.25), Kit.PAINT, 3)


## Three straw skeps (beehives) on a low bench.
static func _beehives(k: Kit) -> void:
	for sx in [-0.14, 0.14]:
		var x: float = sx
		k.box(Vector3(x, 0, 0), Vector3(0.025, 0.06, 0.1), WOOD_D, Kit.TIMBER)
	k.box(Vector3(0, 0.06, 0), Vector3(0.34, 0.02, 0.11), WOOD, Kit.TIMBER)
	for i in 3:
		var x2 := -0.1 + 0.1 * i
		_blob(k, Vector3(x2, 0.1, 0.0), 0.05, 0.075, 0.05, 2, 6, HAY.darkened(0.05 * i), Kit.THATCH, 0.04, i + 50, -0.5)
		k.box(Vector3(x2, 0.085, 0.045), Vector3(0.018, 0.016, 0.01), Color(0.1, 0.07, 0.05), Kit.DARK)


## A scarecrow on a pole: tunic, sack head, wide-brimmed straw hat, arms out.
static func _scarecrow(k: Kit) -> void:
	k.rod(Vector3(0, 0, 0), Vector3(0, 0.3, 0), 0.012, WOOD_D, Kit.TIMBER)
	k.rod(Vector3(-0.13, 0.2, 0), Vector3(0.13, 0.2, 0), 0.01, WOOD_D, Kit.TIMBER)
	k.frustum(Vector3(0, 0.1, 0), 0.05, 0.035, 0.12, Color(0.45, 0.55, 0.70), Kit.CLOTH, 6, false)
	for sx in [-0.12, 0.12]:
		var x: float = sx
		k.box(Vector3(x, 0.14, 0.0), Vector3(0.04, 0.07, 0.03), Color(0.62, 0.40, 0.30), Kit.CLOTH)
	k.frustum(Vector3(0, 0.22, 0), 0.032, 0.038, 0.06, SACK, Kit.CLOTH, 6, true)
	k.frustum(Vector3(0, 0.275, 0), 0.085, 0.05, 0.012, HAY, Kit.THATCH, 8, false)
	k.frustum(Vector3(0, 0.287, 0), 0.04, 0.03, 0.04, HAY.darkened(0.06), Kit.THATCH, 6, true)


## A signpost with two pointing boards and a cairn at its foot.
static func _signpost(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(0.13, 0.03, 0.13), STONE_C, Kit.STONE, 0.3)
	k.box(Vector3(0, 0.03, 0), Vector3(0.04, 0.28, 0.04), WOOD_D, Kit.TIMBER)
	k.frustum(Vector3(0, 0.31, 0), 0.034, 0.0, 0.04, WOOD_D, Kit.TIMBER, 4)
	k.box(Vector3(0.06, 0.24, 0.03), Vector3(0.16, 0.05, 0.015), WOOD_L, Kit.TIMBER, -0.35)
	k.box(Vector3(-0.045, 0.16, 0.03), Vector3(0.14, 0.05, 0.015), WOOD, Kit.TIMBER, 0.3)
	# arrow points
	k.push(Kit.at(Vector3(0.06, 0.24, 0.03), -0.35))
	_flat_tri(k, Vector3(0.08, 0.0, 0.0), Vector3(0.08, 0.05, 0.0), Vector3(0.115, 0.025, 0.0), WOOD_L, Kit.TIMBER)
	k.pop()
	k.push(Kit.at(Vector3(-0.045, 0.16, 0.03), 0.3))
	_flat_tri(k, Vector3(-0.07, 0.0, 0.0), Vector3(-0.07, 0.05, 0.0), Vector3(-0.105, 0.025, 0.0), WOOD, Kit.TIMBER)
	k.pop()


## A small rowing boat, bow toward +z, waterline at y = 0, with thwarts and two oars.
static func _boat(k: Kit) -> void:
	var hull := Color(0.42, 0.30, 0.20)
	var rim := Color(0.74, 0.58, 0.36)
	var stations := [[-0.19, 0.055, 0.045], [-0.1, 0.08, 0.05], [0.02, 0.085, 0.05], [0.12, 0.062, 0.058], [0.21, 0.0, 0.085]]
	var secs: Array = []
	for st in stations:
		var z: float = st[0]
		var w: float = st[1]
		var gy: float = st[2]
		secs.append([Vector3(-w, gy, z), Vector3(-0.6 * w, -0.025, z), Vector3(0, -0.045, z), Vector3(0.6 * w, -0.025, z), Vector3(w, gy, z)])
	for i in 4:
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		var zm: float = (a[0].z + b[0].z) / 2.0
		for e in 4:
			k.quad(a[e], a[e + 1], b[e + 1], b[e], hull, Kit.TIMBER, Vector3(0, 0.02, zm))
		# inner lining of the two sides, facing the middle of the boat
		k.quad(a[0], a[1], b[1], b[0], hull.darkened(0.2), Kit.TIMBER, Vector3(-1, 0.03, zm))
		k.quad(a[4], a[3], b[3], b[4], hull.darkened(0.2), Kit.TIMBER, Vector3(1, 0.03, zm))
		# the floor boards and the gunwale rim
		var wa: float = 0.7 * a[4].x
		var wb: float = 0.7 * b[4].x
		k.quad(Vector3(-wa, 0.01, a[0].z), Vector3(wa, 0.01, a[0].z), Vector3(wb, 0.01, b[0].z), Vector3(-wb, 0.01, b[0].z),
			hull.darkened(0.3), Kit.TIMBER, Vector3(0, -1, 0))
		for sgn in [-1.0, 1.0]:
			var sg: float = sgn
			var ya: float = a[4].y + 0.004
			var yb: float = b[4].y + 0.004
			k.quad(Vector3(sg * a[4].x, ya, a[0].z), Vector3(sg * (a[4].x - 0.014), ya, a[0].z),
				Vector3(sg * (b[4].x - 0.014), yb, b[0].z), Vector3(sg * b[4].x, yb, b[0].z), rim, Kit.TIMBER, Vector3(0, -1, 0))
	var s0: Array = secs[0]
	k.polygon(s0, hull.darkened(0.1), Kit.TIMBER, Vector3(0, 0.0, 0.0))
	k.box(Vector3(0, 0.03, -0.06), Vector3(0.14, 0.012, 0.03), rim, Kit.TIMBER)
	k.box(Vector3(0, 0.03, 0.07), Vector3(0.12, 0.012, 0.03), rim, Kit.TIMBER)
	for sg2 in [-1.0, 1.0]:
		var s: float = sg2
		k.rod(Vector3(s * 0.04, 0.045, 0.0), Vector3(s * 0.2, 0.0, 0.03), 0.008, WOOD_L, Kit.TIMBER)


## A net-drying frame: an A-frame with a net draped over the ridge pole, and a heap of net.
static func _nets(k: Kit) -> void:
	for sx in [-0.2, 0.2]:
		var x: float = sx
		for sz in [-0.09, 0.09]:
			var z: float = sz
			k.rod(Vector3(x, 0, z), Vector3(x, 0.26, 0), 0.011, WOOD_D, Kit.TIMBER)
	k.rod(Vector3(-0.23, 0.26, 0), Vector3(0.23, 0.26, 0), 0.012, WOOD, Kit.TIMBER)
	var net := Color(0.60, 0.56, 0.44)
	for sz in [-1.0, 1.0]:
		var z2: float = sz
		_flat(k, Vector3(-0.2, 0.265, 0.0), Vector3(0.2, 0.265, 0.0), Vector3(0.19, 0.06, z2 * 0.095), Vector3(-0.19, 0.06, z2 * 0.095), net, Kit.CLOTH)
	_blob(k, Vector3(0.12, 0.015, 0.17), 0.08, 0.04, 0.05, 2, 6, net.darkened(0.1), Kit.CLOTH, 0.18, 14, -0.2)
	for i in 3:
		k.box(Vector3(-0.14 + 0.14 * i, 0.04, 0.1 * (1 if i % 2 == 0 else -1)), Vector3(0.025, 0.03, 0.025), WOOD_L, Kit.TIMBER)


## A marble figure on a stepped pedestal, one arm raised.
static func _statue(k: Kit) -> void:
	var marble := Color(0.84, 0.82, 0.77)
	k.box(Vector3(0, 0, 0), Vector3(0.2, 0.03, 0.2), STONE_D, Kit.STONE)
	k.bevel_box(Vector3(0, 0.03, 0), Vector3(0.13, 0.12, 0.13), 0.02, STONE_C, Kit.STONE)
	k.frustum(Vector3(0, 0.15, 0), 0.045, 0.03, 0.15, marble, Kit.PLASTER, 6, false)
	k.box(Vector3(0, 0.27, 0), Vector3(0.1, 0.03, 0.045), marble, Kit.PLASTER)
	k.frustum(Vector3(0, 0.3, 0), 0.026, 0.022, 0.05, marble.lightened(0.04), Kit.PLASTER, 6, true)
	k.rod(Vector3(0.05, 0.285, 0.0), Vector3(0.085, 0.38, 0.0), 0.012, marble, Kit.PLASTER)


## A round fountain: a stone basin of water, a pillar and an upper bowl with a jet.
static func _fountain(k: Kit) -> void:
	k.frustum(Vector3.ZERO, 0.23, 0.21, 0.07, STONE_C, Kit.STONE, 10, false)
	_annulus(k, 0.07, 0.21, 0.17, 10, STONE_D, Kit.STONE)
	_disc(k, 0.06, 0.172, 10, Color(0.30, 0.52, 0.68), Kit.WATER)
	k.frustum(Vector3(0, 0.06, 0), 0.04, 0.025, 0.12, STONE_C, Kit.STONE, 6, false)
	k.frustum(Vector3(0, 0.17, 0), 0.025, 0.1, 0.035, STONE_C, Kit.STONE, 8, false)
	_annulus(k, 0.205, 0.1, 0.08, 8, STONE_D, Kit.STONE)
	_disc(k, 0.196, 0.082, 8, Color(0.35, 0.58, 0.72), Kit.WATER)
	k.frustum(Vector3(0, 0.2, 0), 0.02, 0.0, 0.1, Color(0.65, 0.85, 0.95), Kit.WATER, 4)


## A stack of sawn beams, three high, on two sleepers.
static func _timber(k: Kit) -> void:
	var beam := Color(0.78, 0.60, 0.38)
	for sz in [-0.1, 0.1]:
		var z: float = sz
		k.box(Vector3(0, 0, z), Vector3(0.05, 0.02, 0.05), WOOD_D, Kit.TIMBER)
	var rows := [3, 2, 1]
	for r in 3:
		var n: int = rows[r]
		for i in n:
			var z2 := (i - (n - 1) / 2.0) * 0.055
			var len := 0.36 + 0.06 * _h(r * 7 + i) - 0.03 * r
			var off := 0.04 * (_h(r * 5 + i + 20) - 0.5)
			k.box(Vector3(off, 0.02 + 0.05 * r, z2), Vector3(len, 0.05, 0.052), beam.darkened(0.06 * ((r + i) % 3)), Kit.TIMBER)
