## East Asian buildings (China, Korea, Japan): houses, pagoda, palace, castle keep, gate.
## The star is the roof: curved, upturned eaves with rafter ends, corner rods and ridge ornaments.
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")

const RED := Color(0.66, 0.13, 0.09)
const RED_D := Color(0.48, 0.10, 0.08)
const WOOD := Color(0.30, 0.19, 0.11)
const WOOD_L := Color(0.52, 0.36, 0.21)
const WHITE := Color(0.94, 0.92, 0.85)
const CREAM := Color(0.88, 0.82, 0.68)
const GREY := Color(0.64, 0.63, 0.60)
const GREY_D := Color(0.45, 0.45, 0.44)
const ROOF := Color(0.50, 0.52, 0.56)
const ROOF_D := Color(0.38, 0.40, 0.44)
const SLATE := Color(0.24, 0.26, 0.29)
const GOLDC := Color(0.90, 0.72, 0.24)
const STRAW := Color(0.74, 0.62, 0.34)
const BLUE := Color(0.16, 0.30, 0.48)
const EARTHC := Color(0.70, 0.62, 0.48)
const MARBLE := Color(0.88, 0.86, 0.80)


static func kinds() -> Array:
	return ["house_1", "house_2", "house_3", "house_4", "house_5", "house_6", "pagoda", "palace", "castle_keep", "gate"]


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	var sc := {"house_3": 0.9, "house_5": 0.96, "house_6": 0.9, "palace": 0.96}
	if sc.has(kind):
		var f: float = sc[kind]
		k.push(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * f), Vector3.ZERO))
	match kind:
		"house_1": _house_plaster(k)
		"house_2": _house_shop(k)
		"house_3": _house_courtyard(k)
		"house_4": _house_machiya(k)
		"house_5": _house_hanok(k)
		"house_6": _house_farm(k)
		"pagoda": _pagoda(k)
		"palace": _palace(k)
		"castle_keep": _keep(k)
		"gate": _gate(k)
	return k.finish()


# --- helpers ----------------------------------------------------------------------------------


static func _perim(hw: float, hd: float, n: int, curl: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for i in n:
		var x := -hw + 2.0 * hw * float(i) / n
		pts.append(Vector3(x, curl * pow(absf(x) / hw, 3.0), hd))
	for i in n:
		var z := hd - 2.0 * hd * float(i) / n
		pts.append(Vector3(hw, curl * pow(absf(z) / hd, 3.0), z))
	for i in n:
		var x := hw - 2.0 * hw * float(i) / n
		pts.append(Vector3(x, curl * pow(absf(x) / hw, 3.0), -hd))
	for i in n:
		var z := -hd + 2.0 * hd * float(i) / n
		pts.append(Vector3(-hw, curl * pow(absf(z) / hd, 3.0), z))
	return pts


## A hipped roof with real upturned (concave, curved) eaves. w x d is the wall footprint, `over`
## the overhang. rx/rz: half-size of the top (ridge or flat top); rx < 0 = a plain ridge.
static func _roof(k: Kit, foot: Vector3, w: float, d: float, rise: float, over: float, thick: float,
		curl: float, col: Color, mat: int, rx := -1.0, rz := 0.0, n := 4, yaw := 0.0, raf := true,
		orn := 1.0, finial := true, rafstep := 2, fly := true) -> void:
	if rx < 0.0:
		rx = maxf(0.0, (w - d) / 2.0)
	var hw := w / 2.0 + over
	var hd := d / 2.0 + over
	k.push(Kit.at(foot, yaw))
	var P := _perim(hw, hd, n, curl)
	var cnt := P.size()
	var up := Vector3(0, thick, 0)
	var T: Array[Vector3] = []
	var M: Array[Vector3] = []
	for pv in P:
		var t := Vector3(clampf(pv.x, -rx, rx), rise, clampf(pv.z, -rz, rz))
		T.append(t)
		var m := pv.lerp(t, 0.5)
		m.y = pv.y + (rise - pv.y) * 0.3
		M.append(m)
	var below := Vector3(0, -1, 0)
	var above := Vector3(0, 10, 0)
	for i in cnt:
		var j := (i + 1) % cnt
		k.quad(P[i] + up, P[j] + up, M[j] + up, M[i] + up, col, mat, below)
		k.quad(M[i] + up, M[j] + up, T[j] + up, T[i] + up, col, mat, below)
		k.quad(P[i], P[j], M[j], M[i], col.darkened(0.35), mat, above)
		k.quad(P[i], P[j], P[j] + up, P[i] + up, col.darkened(0.2), mat, Vector3(0, rise, 0))
	if rx > 0.0 and rz > 0.0:
		k.quad(Vector3(-rx, rise + thick, -rz), Vector3(rx, rise + thick, -rz), Vector3(rx, rise + thick, rz),
			Vector3(-rx, rise + thick, rz), col, mat, below)
	var rc := col.darkened(0.14)
	for c in 4:
		var ci := c * n
		k.rod(P[ci] + up, M[ci] + up, thick * 0.7, rc, mat)
		k.rod(M[ci] + up, T[ci] + up, thick * 0.7, rc, mat)
		# flying rafters from the wall corner out to the tip of the eave
		var sx := signf(P[ci].x)
		var sz := signf(P[ci].z)
		if fly:
			k.rod(Vector3(sx * w / 2.0, -0.01, sz * d / 2.0), P[ci] + Vector3(0, -0.02, 0), thick * 0.5, WOOD, Kit.TIMBER)
		if orn > 0.0:
			var tp := P[ci] + up
			var o := Vector3(sx * 0.03, 0.05, sz * 0.03) * orn
			k.quad(tp, tp + Vector3(sx * 0.012, 0, -sz * 0.012) * orn, tp + o, tp + Vector3(-sx * 0.012, 0, sz * 0.012) * orn, GOLDC, Kit.GOLD, tp - Vector3(sx, 1, sz))
	if rz == 0.0 and rx > 0.0:
		k.rod(Vector3(-rx, rise, 0) + up, Vector3(rx, rise, 0) + up, thick * 0.9, col.darkened(0.2), mat)
	if raf and rafstep > 0:
		for i in range(0, cnt, rafstep):
			var pv := P[i]
			k.box(pv + Vector3(0, -0.03, 0), Vector3(0.02, 0.03, 0.02), RED, Kit.PAINT)
	if orn > 0.0 and rz == 0.0:
		if rx > 0.0:
			for s in [-1.0, 1.0]:
				var b := Vector3(s * rx, rise + thick, 0)
				k.rod(b, b + Vector3(s * 0.012, 0.09, 0) * orn, 0.018 * orn, col.darkened(0.25), mat)
				k.rod(b + Vector3(s * 0.012, 0.09, 0) * orn, b + Vector3(-s * 0.02, 0.12, 0) * orn, 0.012 * orn, GOLDC, Kit.GOLD)
		elif finial:
			k.frustum(Vector3(0, rise + thick, 0), 0.035 * orn, 0.0, 0.13 * orn, GOLDC, Kit.GOLD, 6)
			k.frustum(Vector3(0, rise + thick, 0), 0.02 * orn, 0.02 * orn, 0.05 * orn, GOLDC, Kit.GOLD, 6)
	k.pop()


## A beam stack with bracket blocks under the eaves of a body hx x hz (half sizes).
static func _brackets(k: Kit, hx: float, hz: float, y: float, step: float, h: float, col := RED, cz := 0.0) -> void:
	k.push(Kit.at(Vector3(0, 0, cz)))
	k.box(Vector3(0, y, 0), Vector3(hx * 2.0 + 0.04, h * 0.5, hz * 2.0 + 0.04), col, Kit.PAINT)
	var nx := maxi(1, int((hx * 2.0) / step))
	var nz := maxi(1, int((hz * 2.0) / step))
	for i in nx + 1:
		var x := -hx + 2.0 * hx * float(i) / nx
		for s in [-1.0, 1.0]:
			k.box(Vector3(x, y + h * 0.5, s * (hz + 0.025)), Vector3(0.04, h * 0.5, 0.07), WOOD, Kit.TIMBER)
	for i in range(1, nz):
		var z := -hz + 2.0 * hz * float(i) / nz
		for s in [-1.0, 1.0]:
			k.box(Vector3(s * (hx + 0.025), y + h * 0.5, z), Vector3(0.07, h * 0.5, 0.04), WOOD, Kit.TIMBER)
	k.pop()


static func _rail(k: Kit, a: Vector3, b: Vector3, h: float, step: float, post: Color, mat: int) -> void:
	var n := maxi(2, int(round(a.distance_to(b) / step)) + 1)
	for i in n:
		var p := a.lerp(b, float(i) / (n - 1))
		k.box(p, Vector3(0.022, h, 0.022), post, mat)
	k.rod(a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.01, post, mat)
	k.rod(a + Vector3(0, h * 0.45, 0), b + Vector3(0, h * 0.45, 0), 0.007, post, mat)


static func _rail_ring(k: Kit, hx: float, hz: float, y: float, h: float, step: float, post: Color, mat: int, gap := 0.0) -> void:
	var c := [Vector3(-hx, y, hz), Vector3(hx, y, hz), Vector3(hx, y, -hz), Vector3(-hx, y, -hz)]
	for i in 4:
		_rail(k, c[i], c[(i + 1) % 4], h, step, post, mat)


## A cheap window: dark opening, frame, optional lattice bars and a sill (about 20 triangles).
static func _win(k: Kit, p: Vector3, yaw: float, w: float, h: float, frame: Color, style := "lattice") -> void:
	k.push(Kit.at(p, yaw))
	var f := w * 0.14
	var ins := Vector3(0, 0, -1)
	var hw := w / 2.0
	var hh := h / 2.0
	k.quad(Vector3(-hw - f, -hh - f, 0.004), Vector3(hw + f, -hh - f, 0.004), Vector3(hw + f, hh + f, 0.004), Vector3(-hw - f, hh + f, 0.004), frame, Kit.TIMBER, ins)
	k.quad(Vector3(-hw, -hh, 0.008), Vector3(hw, -hh, 0.008), Vector3(hw, hh, 0.008), Vector3(-hw, hh, 0.008), Color(0.07, 0.05, 0.04), Kit.DARK, ins)
	if style == "lattice":
		for bx in [-hw / 3.0, hw / 3.0]:
			k.quad(Vector3(bx - f * 0.2, -hh, 0.012), Vector3(bx + f * 0.2, -hh, 0.012), Vector3(bx + f * 0.2, hh, 0.012), Vector3(bx - f * 0.2, hh, 0.012), frame, Kit.TIMBER, ins)
		k.quad(Vector3(-hw, -f * 0.2, 0.012), Vector3(hw, -f * 0.2, 0.012), Vector3(hw, f * 0.2, 0.012), Vector3(-hw, f * 0.2, 0.012), frame, Kit.TIMBER, ins)
	k.box(Vector3(0, -hh - f * 1.6, 0.0), Vector3(w + f * 3.0, f * 1.2, 0.035), frame, Kit.TIMBER)
	k.pop()


static func _lantern(k: Kit, p: Vector3, s := 1.0) -> void:
	k.box(p, Vector3(0.04, 0.055, 0.04) * s, RED, Kit.PAINT)
	k.box(p + Vector3(0, 0.055 * s, 0), Vector3(0.05, 0.012, 0.05) * s, GOLDC, Kit.GOLD)
	k.box(p + Vector3(0, -0.012 * s, 0), Vector3(0.03, 0.012, 0.03) * s, GOLDC, Kit.GOLD)


## A small tiled lean-to (pent) roof sloping down towards +z.
static func _lean(k: Kit, cx: float, hw: float, y: float, z0: float, z1: float, drop: float, thick: float,
		col: Color, mat: int) -> void:
	var up := Vector3(0, thick, 0)
	var a0 := Vector3(cx - hw, y, z0)
	var a1 := Vector3(cx + hw, y, z0)
	var b1 := Vector3(cx + hw, y - drop, z1)
	var b0 := Vector3(cx - hw, y - drop, z1)
	var mid := Vector3(cx, y - drop * 0.5 + thick * 0.5, (z0 + z1) / 2.0)
	k.quad(a0 + up, a1 + up, b1 + up, b0 + up, col, mat, Vector3(cx, y - 1.0, mid.z))
	k.quad(a0, a1, b1, b0, col.darkened(0.35), mat, Vector3(cx, y + 10.0, mid.z))
	k.quad(b0, b1, b1 + up, b0 + up, col.darkened(0.2), mat, mid)
	k.quad(a0, b0, b0 + up, a0 + up, col.darkened(0.2), mat, mid)
	k.quad(a1, b1, b1 + up, a1 + up, col.darkened(0.2), mat, mid)
	for i in 6:
		var t := (i + 0.5) / 6.0
		k.rod(Vector3(cx - hw + 0.02, y - drop * t, z0 + (z1 - z0) * t - 0.0), Vector3(cx + hw - 0.02, y - drop * t, z0 + (z1 - z0) * t), 0.006, col.darkened(0.3), mat)


# --- houses -----------------------------------------------------------------------------------


static func _house_plaster(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(0.84, 0.07, 0.64), GREY, Kit.STONE)
	k.box(Vector3(0, 0.07, 0), Vector3(0.74, 0.38, 0.54), WHITE, Kit.PLASTER)
	for x in [-0.37, -0.185, 0.185, 0.37]:
		for s in [-1.0, 1.0]:
			k.box(Vector3(x, 0.07, s * 0.27), Vector3(0.045, 0.38, 0.045), RED, Kit.PAINT)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.37, 0.07, 0), Vector3(0.045, 0.38, 0.045), RED, Kit.PAINT)
		k.box(Vector3(s * 0.37, 0.41, 0), Vector3(0.045, 0.04, 0.58), RED_D, Kit.PAINT)
		k.box(Vector3(0, 0.41, s * 0.27), Vector3(0.78, 0.04, 0.045), RED_D, Kit.PAINT)
	k.door(Vector3(0, 0.07, 0.272), 0.0, 0.15, 0.26, WOOD)
	for x in [-0.28, 0.28]:
		_win(k, Vector3(x, 0.28, 0.272), 0.0, 0.11, 0.14, WOOD, "lattice")
	for s in [-1.0, 1.0]:
		_win(k, Vector3(s * 0.372, 0.28, -0.02), s * PI / 2.0, 0.14, 0.14, WOOD, "lattice")
	_win(k, Vector3(0, 0.28, -0.272), PI, 0.14, 0.14, WOOD, "lattice")
	_lantern(k, Vector3(0.12, 0.27, 0.3))
	_lantern(k, Vector3(-0.12, 0.27, 0.3))
	_brackets(k, 0.37, 0.27, 0.45, 0.2, 0.05)
	_roof(k, Vector3(0, 0.5, 0), 0.74, 0.54, 0.27, 0.11, 0.028, 0.08, ROOF, Kit.OWNER_ROOF, -1.0, 0.0, 4)


static func _house_shop(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(0.9, 0.05, 0.7), GREY, Kit.STONE)
	k.box(Vector3(0, 0.05, 0), Vector3(0.78, 0.36, 0.56), WHITE, Kit.PLASTER)
	k.box(Vector3(0, 0.07, 0.275), Vector3(0.56, 0.28, 0.02), Color(0.07, 0.05, 0.04), Kit.DARK)
	for x in [-0.39, -0.29, 0.29, 0.39]:
		k.box(Vector3(x, 0.05, 0.285), Vector3(0.05, 0.36, 0.05), RED, Kit.PAINT)
	k.box(Vector3(0, 0.37, 0.285), Vector3(0.84, 0.05, 0.05), RED_D, Kit.PAINT)
	k.box(Vector3(0, 0.05, 0.33), Vector3(0.5, 0.11, 0.07), WOOD_L, Kit.TIMBER)
	for i in 4:
		var gx := -0.18 + i * 0.12
		var gc := [Color(0.8, 0.3, 0.2), Color(0.9, 0.75, 0.3), Color(0.35, 0.55, 0.3), Color(0.8, 0.6, 0.4)][i] as Color
		k.box(Vector3(gx, 0.16, 0.33), Vector3(0.07, 0.04, 0.05), gc, Kit.CLOTH)
	# striped awning over the shop front
	for i in 8:
		var x0 := -0.42 + i * 0.105
		var x1 := x0 + 0.105
		var c := Color.WHITE if i % 2 == 0 else CREAM
		var m := Kit.OWNER_CLOTH if i % 2 == 0 else Kit.CLOTH
		k.quad(Vector3(x0, 0.40, 0.28), Vector3(x1, 0.40, 0.28), Vector3(x1, 0.31, 0.55), Vector3(x0, 0.31, 0.55), c, m, Vector3(0, 0, 0))
		k.quad(Vector3(x0, 0.31, 0.55), Vector3(x1, 0.31, 0.55), Vector3(x1, 0.28, 0.55), Vector3(x0, 0.28, 0.55), c, m, Vector3(0, 0.2, 0))
	for s in [-1.0, 1.0]:
		k.tri(Vector3(s * 0.42, 0.40, 0.28), Vector3(s * 0.42, 0.31, 0.55), Vector3(s * 0.42, 0.28, 0.55), CREAM, Kit.CLOTH, Vector3(0, 0.2, 0.4))
		k.rod(Vector3(s * 0.41, 0.29, 0.55), Vector3(s * 0.41, 0.05, 0.55), 0.011, WOOD, Kit.TIMBER)
	# upper floor with a balcony
	k.box(Vector3(0, 0.41, 0), Vector3(0.76, 0.3, 0.5), CREAM, Kit.PLASTER)
	k.box(Vector3(0, 0.41, 0.345), Vector3(0.5, 0.03, 0.2), WOOD_L, Kit.TIMBER)
	_rail(k, Vector3(-0.24, 0.44, 0.44), Vector3(0.24, 0.44, 0.44), 0.09, 0.08, RED, Kit.PAINT)
	_rail(k, Vector3(-0.24, 0.44, 0.44), Vector3(-0.24, 0.44, 0.25), 0.09, 0.08, RED, Kit.PAINT)
	_rail(k, Vector3(0.24, 0.44, 0.44), Vector3(0.24, 0.44, 0.25), 0.09, 0.08, RED, Kit.PAINT)
	for s in [-1.0, 1.0]:
		k.rod(Vector3(s * 0.2, 0.40, 0.44), Vector3(s * 0.2, 0.41, 0.26), 0.012, WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.44, 0.252), Vector3(0.2, 0.21, 0.012), Color(0.07, 0.05, 0.04), Kit.DARK)
	k.door(Vector3(0, 0.44, 0.255), 0.0, 0.16, 0.2, RED)
	for x in [-0.28, 0.28]:
		_win(k, Vector3(x, 0.58, 0.252), 0.0, 0.11, 0.13, WOOD, "lattice")
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.38, 0.41, 0.25), Vector3(0.045, 0.3, 0.045), RED, Kit.PAINT)
		k.box(Vector3(s * 0.38, 0.41, -0.25), Vector3(0.045, 0.3, 0.045), RED, Kit.PAINT)
		_win(k, Vector3(s * 0.382, 0.58, 0), s * PI / 2.0, 0.13, 0.13, WOOD, "lattice")
	_brackets(k, 0.38, 0.25, 0.71, 0.2, 0.05)
	_roof(k, Vector3(0, 0.76, 0), 0.76, 0.5, 0.26, 0.1, 0.026, 0.08, ROOF, Kit.OWNER_ROOF, -1.0, 0.0, 4)
	# hanging shop sign
	k.rod(Vector3(0.40, 0.66, 0.26), Vector3(0.40, 0.66, 0.50), 0.01, WOOD, Kit.TIMBER)
	k.box(Vector3(0.40, 0.45, 0.48), Vector3(0.02, 0.21, 0.08), Color.WHITE, Kit.OWNER_CLOTH)


static func _house_courtyard(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(0.98, 0.03, 0.98), EARTHC, Kit.EARTH)
	k.box(Vector3(0, 0.03, 0.19), Vector3(0.46, 0.01, 0.52), GREY, Kit.STONE)
	# back wing
	k.box(Vector3(0, 0.03, -0.27), Vector3(0.94, 0.3, 0.34), WHITE, Kit.PLASTER)
	for x in [-0.47, -0.235, 0.0, 0.235, 0.47]:
		k.box(Vector3(x, 0.03, -0.095), Vector3(0.045, 0.3, 0.045), RED, Kit.PAINT)
	k.box(Vector3(0, 0.29, -0.095), Vector3(0.96, 0.04, 0.05), RED_D, Kit.PAINT)
	k.door(Vector3(0, 0.03, -0.098), 0.0, 0.16, 0.24, WOOD)
	for x in [-0.35, 0.35, -0.12, 0.12]:
		_win(k, Vector3(x, 0.19, -0.098), 0.0, 0.1, 0.12, WOOD, "lattice")
	_brackets(k, 0.47, 0.17, 0.33, 0.24, 0.04, RED, -0.27)
	_roof(k, Vector3(0, 0.37, -0.27), 0.92, 0.34, 0.22, 0.08, 0.024, 0.07, ROOF, Kit.OWNER_ROOF, -1.0, 0.0, 4, 0.0, true, 0.9, true, 3, false)
	# side wings
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.38, 0.03, 0.14), Vector3(0.18, 0.26, 0.42), WHITE, Kit.PLASTER)
		for z in [-0.07, 0.35]:
			k.box(Vector3(s * 0.29, 0.03, z), Vector3(0.04, 0.26, 0.04), RED, Kit.PAINT)
		k.box(Vector3(s * 0.29, 0.25, 0.14), Vector3(0.04, 0.035, 0.46), RED_D, Kit.PAINT)
		_win(k, Vector3(s * 0.291, 0.17, 0.08), -s * PI / 2.0, 0.1, 0.12, WOOD, "lattice")
		_win(k, Vector3(s * 0.291, 0.17, 0.24), -s * PI / 2.0, 0.1, 0.12, WOOD, "lattice")
		_roof(k, Vector3(s * 0.38, 0.30, 0.14), 0.42, 0.18, 0.13, 0.035, 0.022, 0.05, ROOF, Kit.OWNER_ROOF, -1.0, 0.0, 3, PI / 2.0, false, 0.7, true, 0, false)
		k.box(Vector3(s * 0.47, 0.03, 0.40), Vector3(0.04, 0.17, 0.12), WHITE, Kit.PLASTER)
	# front wall and gate
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.31, 0.03, 0.45), Vector3(0.33, 0.17, 0.04), WHITE, Kit.PLASTER)
		k.box(Vector3(s * 0.31, 0.2, 0.45), Vector3(0.36, 0.025, 0.075), SLATE, Kit.TILE)
		k.box(Vector3(s * 0.12, 0.03, 0.45), Vector3(0.045, 0.26, 0.05), RED, Kit.PAINT)
	k.box(Vector3(0, 0.03, 0.452), Vector3(0.2, 0.2, 0.025), RED, Kit.PAINT)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.04, 0.12, 0.466), Vector3(0.025, 0.025, 0.012), GOLDC, Kit.GOLD)
	k.box(Vector3(0, 0.29, 0.45), Vector3(0.3, 0.03, 0.06), RED_D, Kit.PAINT)
	_roof(k, Vector3(0, 0.32, 0.45), 0.28, 0.1, 0.1, 0.06, 0.02, 0.05, ROOF, Kit.OWNER_ROOF, -1.0, 0.0, 3, 0.0, false, 0.6, true, 0, false)
	# little tree
	k.cylinder(Vector3(-0.1, 0.03, 0.2), 0.014, 0.14, WOOD, Kit.TIMBER, 5)
	k.dome(Vector3(-0.1, 0.14, 0.2), 0.1, Color(0.30, 0.50, 0.22), Kit.LEAF, 0.8, 3, 8)
	k.dome(Vector3(-0.04, 0.2, 0.17), 0.065, Color(0.36, 0.55, 0.25), Kit.LEAF, 0.8, 3, 8)


static func _house_machiya(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(0.84, 0.05, 0.68), GREY, Kit.STONE)
	k.box(Vector3(0, 0.05, 0), Vector3(0.76, 0.34, 0.56), Color(0.40, 0.27, 0.17), Kit.TIMBER)
	# slatted front
	for i in 14:
		var x := -0.34 + i * 0.052
		if absf(x - 0.18) < 0.09:
			continue
		k.box(Vector3(x, 0.07, 0.285), Vector3(0.018, 0.3, 0.02), WOOD_L, Kit.TIMBER)
	k.box(Vector3(0, 0.07, 0.287), Vector3(0.7, 0.025, 0.02), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.22, 0.287), Vector3(0.7, 0.02, 0.02), WOOD, Kit.TIMBER)
	k.box(Vector3(0.18, 0.06, 0.29), Vector3(0.13, 0.3, 0.012), Color(0.07, 0.05, 0.04), Kit.DARK)
	k.box(Vector3(0.18, 0.2, 0.30), Vector3(0.17, 0.15, 0.012), Color.WHITE, Kit.OWNER_CLOTH)   # noren curtain
	_lean(k, 0.0, 0.43, 0.41, 0.28, 0.5, 0.07, 0.025, SLATE, Kit.TILE)
	# upper floor
	k.box(Vector3(0, 0.39, 0), Vector3(0.7, 0.3, 0.5), WHITE, Kit.PLASTER)
	for x in [-0.35, -0.12, 0.12, 0.35]:
		k.box(Vector3(x, 0.39, 0.25), Vector3(0.035, 0.3, 0.035), WOOD, Kit.TIMBER)
	for x in [-0.23, 0.0, 0.23]:
		_win(k, Vector3(x, 0.55, 0.252), 0.0, 0.14, 0.07, WOOD, "lattice")
	k.box(Vector3(0, 0.66, 0.25), Vector3(0.74, 0.03, 0.035), WOOD, Kit.TIMBER)
	# firewall (udatsu) at one side and the roof
	k.gable_roof(Vector3(0, 0.69, 0), 0.7, 0.5, 0.2, 0.1, 0.03, ROOF_D, Kit.OWNER_ROOF, WHITE, Kit.PLASTER)
	k.box(Vector3(0.38, 0.39, 0), Vector3(0.05, 0.45, 0.46), WHITE, Kit.PLASTER)
	k.box(Vector3(0.38, 0.84, 0), Vector3(0.08, 0.025, 0.52), SLATE, Kit.TILE)
	k.box(Vector3(0.38, 0.865, 0), Vector3(0.05, 0.03, 0.4), SLATE, Kit.TILE)
	for i in 8:   # hanging rafter ends along the front eave
		k.box(Vector3(-0.35 + i * 0.1, 0.62, 0.34), Vector3(0.02, 0.025, 0.02), WOOD, Kit.TIMBER)
	k.gable_roof(Vector3(-0.1, 0.89, 0), 0.2, 0.16, 0.1, 0.04, 0.02, ROOF_D, Kit.OWNER_ROOF, WHITE, Kit.PLASTER)
	k.cylinder(Vector3(-0.38, 0.05, 0.25), 0.03, 0.08, WOOD, Kit.TIMBER, 8)   # barrel


static func _house_hanok(k: Kit) -> void:
	k.push(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.93), Vector3.ZERO))
	k.box(Vector3(-0.05, 0, -0.1), Vector3(1.0, 0.1, 0.6), GREY, Kit.STONE)
	k.box(Vector3(0.29, 0, 0.25), Vector3(0.4, 0.1, 0.3), GREY, Kit.STONE)
	# main wing: room + open veranda (maru)
	k.box(Vector3(-0.12, 0.1, -0.26), Vector3(0.66, 0.3, 0.28), WHITE, Kit.PLASTER)
	k.box(Vector3(-0.12, 0.1, -0.02), Vector3(0.66, 0.02, 0.2), WOOD_L, Kit.TIMBER)
	for i in 5:
		var x := -0.37 + i * 0.125
		_win(k, Vector3(x, 0.27, -0.118), 0.0, 0.09, 0.15, WOOD, "lattice")
		k.box(Vector3(x - 0.06, 0.1, -0.12), Vector3(0.025, 0.3, 0.025), WOOD, Kit.TIMBER)
	for i in 4:
		k.cylinder(Vector3(-0.42 + i * 0.22, 0.12, 0.07), 0.022, 0.28, RED, Kit.PAINT, 8)
	k.box(Vector3(-0.12, 0.4, 0.07), Vector3(0.7, 0.04, 0.045), WOOD, Kit.TIMBER)
	_roof(k, Vector3(-0.12, 0.45, -0.13), 0.66, 0.46, 0.28, 0.1, 0.03, 0.1, ROOF_D, Kit.OWNER_ROOF, -1.0, 0.0, 5, 0.0, true, 0.9, true, 2)
	# wing towards the front
	k.box(Vector3(0.29, 0.1, 0.2), Vector3(0.3, 0.28, 0.42), WHITE, Kit.PLASTER)
	_win(k, Vector3(0.1, 0.26, 0.2), -PI / 2.0, 0.12, 0.14, WOOD, "lattice")
	_win(k, Vector3(0.29, 0.26, 0.412), 0.0, 0.12, 0.14, WOOD, "lattice")
	k.door(Vector3(0.45, 0.1, 0.12), PI / 2.0, 0.1, 0.2, WOOD)
	for z in [-0.0, 0.4]:
		k.box(Vector3(0.14, 0.1, z), Vector3(0.03, 0.28, 0.03), WOOD, Kit.TIMBER)
		k.box(Vector3(0.44, 0.1, z), Vector3(0.03, 0.28, 0.03), WOOD, Kit.TIMBER)
	_roof(k, Vector3(0.29, 0.43, 0.2), 0.44, 0.3, 0.2, 0.08, 0.027, 0.08, ROOF_D, Kit.OWNER_ROOF, -1.0, 0.0, 4, PI / 2.0, true, 0.8, true, 2)
	# ondol chimney and jars
	k.box(Vector3(-0.35, 0.1, -0.45), Vector3(0.07, 0.46, 0.07), Color(0.55, 0.50, 0.45), Kit.BRICK)
	k.box(Vector3(-0.35, 0.56, -0.45), Vector3(0.11, 0.03, 0.11), SLATE, Kit.TILE)
	k.box(Vector3(-0.35, 0.59, -0.45), Vector3(0.06, 0.04, 0.06), SLATE, Kit.TILE)
	for p in [Vector3(-0.38, 0, 0.2), Vector3(-0.28, 0, 0.3), Vector3(-0.18, 0, 0.18)]:
		k.frustum(p, 0.045, 0.06, 0.08, Color(0.45, 0.30, 0.18), Kit.PAINT, 8)
		k.dome(p + Vector3(0, 0.08, 0), 0.06, Color(0.45, 0.30, 0.18), Kit.PAINT, 0.4, 2, 8)
	k.pop()


static func _house_farm(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(0.84, 0.04, 0.62), GREY_D, Kit.STONE)
	k.box(Vector3(0, 0.04, 0), Vector3(0.7, 0.3, 0.5), Color(0.74, 0.66, 0.52), Kit.EARTH)
	for x in [-0.35, 0.0, 0.35]:
		k.box(Vector3(x, 0.04, 0.25), Vector3(0.04, 0.3, 0.04), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.32, 0.25), Vector3(0.74, 0.03, 0.04), WOOD, Kit.TIMBER)
	k.door(Vector3(0.0, 0.04, 0.252), 0.0, 0.15, 0.22, WOOD)
	_win(k, Vector3(-0.2, 0.2, 0.252), 0.0, 0.1, 0.1, WOOD, "shutters")
	_win(k, Vector3(0.2, 0.2, 0.252), 0.0, 0.1, 0.1, WOOD, "lattice")
	# steep thatched roof
	k.gable_roof(Vector3(0, 0.36, 0), 0.7, 0.5, 0.42, 0.12, 0.07, STRAW, Kit.THATCH, WOOD_L, Kit.TIMBER)
	k.gable_roof(Vector3(0, 0.78, 0), 0.28, 0.12, 0.1, 0.04, 0.04, STRAW.darkened(0.1), Kit.THATCH, WOOD_L, Kit.TIMBER, PI / 2.0)
	for s in [-1.0, 1.0]:   # crossed gable finials (chigi)
		var b := Vector3(s * 0.4, 0.78, 0)
		k.rod(b + Vector3(0, 0.0, -0.05), b + Vector3(s * 0.02, 0.1, 0.05), 0.01, WOOD, Kit.TIMBER)
		k.rod(b + Vector3(0, 0.0, 0.05), b + Vector3(s * 0.02, 0.1, -0.05), 0.01, WOOD, Kit.TIMBER)
	# lean-to shed, haystack, fence
	k.box(Vector3(0.46, 0.04, -0.1), Vector3(0.2, 0.2, 0.3), Color(0.74, 0.66, 0.52), Kit.EARTH)
	k.gable_roof(Vector3(0.47, 0.24, -0.1), 0.3, 0.2, 0.14, 0.05, 0.05, STRAW, Kit.THATCH, WOOD_L, Kit.TIMBER, PI / 2.0)
	k.frustum(Vector3(-0.38, 0.0, 0.38), 0.11, 0.07, 0.15, STRAW, Kit.THATCH, 8)
	k.frustum(Vector3(-0.38, 0.15, 0.38), 0.07, 0.0, 0.1, STRAW.darkened(0.1), Kit.THATCH, 8)
	for i in 7:
		var x := -0.12 + i * 0.075
		k.box(Vector3(x, 0, 0.4), Vector3(0.016, 0.1, 0.016), WOOD, Kit.TIMBER)
	k.rod(Vector3(-0.12, 0.07, 0.4), Vector3(0.33, 0.07, 0.4), 0.006, WOOD, Kit.TIMBER)


# --- pagoda -----------------------------------------------------------------------------------


static func _pagoda(k: Kit) -> void:
	k.bevel_box(Vector3(0, 0, 0), Vector3(1.5, 0.1, 1.5), 0.02, GREY, Kit.STONE)
	k.bevel_box(Vector3(0, 0.1, 0), Vector3(1.3, 0.1, 1.3), 0.02, MARBLE, Kit.STONE)
	for i in 2:
		k.box(Vector3(0, i * 0.05, 0.7 + 0.04 * (1 - i)), Vector3(0.3, 0.05, 0.1), GREY, Kit.STONE)
	var W := [0.8, 0.7, 0.61, 0.53, 0.46]
	var BH := [0.42, 0.38, 0.35, 0.32, 0.30]
	var OV := [0.3, 0.27, 0.25, 0.22, 0.2]
	var RS := [0.2, 0.2, 0.2, 0.2, 0.27]
	var y := 0.2
	var tip := Vector3.ZERO
	for i in 5:
		var w: float = W[i]
		var bh: float = BH[i]
		var hb := (w + 0.12) / 2.0
		k.box(Vector3(0, y, 0), Vector3(w + 0.12, 0.03, w + 0.12), WOOD_L, Kit.TIMBER)
		y += 0.03
		_rail_ring(k, hb - 0.01, hb - 0.01, y, 0.07, 0.19, RED, Kit.PAINT)
		k.box(Vector3(0, y, 0), Vector3(w - 0.08, bh, w - 0.08), WHITE if i % 2 == 0 else CREAM, Kit.PLASTER)
		var hp := (w - 0.08) / 2.0 + 0.012
		for cx in [-hp, hp]:
			for cz in [-hp, hp]:
				k.box(Vector3(cx, y, cz), Vector3(0.045, bh, 0.045), RED, Kit.PAINT)
		for m in [-w / 6.0, w / 6.0]:
			for s in [-1.0, 1.0]:
				k.box(Vector3(m, y, s * hp), Vector3(0.035, bh, 0.035), RED, Kit.PAINT)
				k.box(Vector3(s * hp, y, m), Vector3(0.035, bh, 0.035), RED, Kit.PAINT)
		k.box(Vector3(0, y + bh - 0.03, 0), Vector3(w - 0.02, 0.035, w - 0.02), RED_D, Kit.PAINT)
		if i == 0:
			k.door(Vector3(0, y, hp + 0.004), 0.0, 0.16, 0.28, WOOD)
		else:
			_win(k, Vector3(0, y + bh * 0.5, hp + 0.004), 0.0, 0.14, 0.17, WOOD, "frame")
		for a in [PI / 2.0, PI, -PI / 2.0]:
			_win(k, Vector3(sin(a) * (hp + 0.004), y + bh * 0.5, cos(a) * (hp + 0.004)), a, 0.12, 0.16, WOOD, "frame")
		_brackets(k, w / 2.0 - 0.03, w / 2.0 - 0.03, y + bh, 0.4, 0.045)
		var rf: float = RS[i]
		var rxn := (float(W[i + 1]) / 2.0 + 0.06) if i < 4 else 0.0
		_roof(k, Vector3(0, y + bh + 0.045, 0), w - 0.06, w - 0.06, rf, OV[i], 0.028, 0.11, ROOF, Kit.OWNER_ROOF,
			rxn, rxn, 4, 0.0, true, 0.0 if i == 4 else 0.8, false, 2)
		var ytop := y + bh + 0.045
		if i == 4:
			tip = Vector3(0, ytop + rf + 0.028, 0)
			for cx in [-1.0, 1.0]:
				for cz in [-1.0, 1.0]:
					var c := Vector3(cx * ((w - 0.06) / 2.0 + float(OV[i])), ytop + 0.11 + 0.03, cz * ((w - 0.06) / 2.0 + float(OV[i])))
					k.rod(c, tip + Vector3(0, 0.38, 0), 0.004, GOLDC, Kit.GOLD)
		y = ytop + rf + 0.028
	# the spire (sorin)
	k.box(Vector3(0, y - 0.03, 0), Vector3(0.16, 0.07, 0.16), GREY, Kit.STONE)
	k.dome(Vector3(0, y + 0.04, 0), 0.085, GOLDC, Kit.GOLD, 0.8, 2, 8)
	k.cylinder(Vector3(0, y + 0.04, 0), 0.016, 0.6, GOLDC, Kit.GOLD, 6)
	for i in 8:
		var r := 0.07 - 0.0055 * i
		k.frustum(Vector3(0, y + 0.14 + i * 0.05, 0), r, r * 0.45, 0.028, GOLDC, Kit.GOLD, 8)
	k.frustum(Vector3(0, y + 0.55, 0), 0.04, 0.0, 0.16, GOLDC, Kit.GOLD, 6)


# --- palace -----------------------------------------------------------------------------------


static func _palace(k: Kit) -> void:
	var zt := -0.72
	# courtyard
	k.box(Vector3(0, 0, 0.7), Vector3(2.2, 0.03, 1.5), Color(0.78, 0.74, 0.64), Kit.STONE)
	k.box(Vector3(0, 0.03, 0.62), Vector3(0.34, 0.012, 1.4), GREY_D, Kit.STONE)
	# stepped terrace
	k.bevel_box(Vector3(0, 0, zt), Vector3(2.3, 0.08, 1.5), 0.015, GREY, Kit.STONE)
	k.bevel_box(Vector3(0, 0.08, zt), Vector3(2.1, 0.08, 1.3), 0.015, MARBLE, Kit.STONE)
	k.bevel_box(Vector3(0, 0.16, zt), Vector3(1.9, 0.08, 1.1), 0.015, MARBLE, Kit.STONE)
	var ty := 0.24
	var zf := zt + 0.55   # front edge of the top terrace
	_rail(k, Vector3(-0.93, ty, zf - 0.02), Vector3(-0.3, ty, zf - 0.02), 0.08, 0.1, MARBLE, Kit.STONE)
	_rail(k, Vector3(0.3, ty, zf - 0.02), Vector3(0.93, ty, zf - 0.02), 0.08, 0.1, MARBLE, Kit.STONE)
	_rail(k, Vector3(-0.93, ty, zf - 0.02), Vector3(-0.93, ty, zt - 0.53), 0.08, 0.1, MARBLE, Kit.STONE)
	_rail(k, Vector3(0.93, ty, zf - 0.02), Vector3(0.93, ty, zt - 0.53), 0.08, 0.1, MARBLE, Kit.STONE)
	_rail(k, Vector3(-0.93, ty, zt - 0.53), Vector3(0.93, ty, zt - 0.53), 0.08, 0.1, MARBLE, Kit.STONE)
	# stairs with a carved central ramp
	for s in [-1.0, 1.0]:
		for st in 4:
			var front := 0.12 - st * 0.07
			var top := 0.06 * (st + 1)
			k.box(Vector3(s * 0.25, 0, (front + zf) / 2.0), Vector3(0.17, top, front - zf), MARBLE, Kit.STONE)
		_rail(k, Vector3(s * 0.34, 0.0, 0.12), Vector3(s * 0.34, ty, zf), 0.07, 0.1, MARBLE, Kit.STONE)
	var ra := Vector3(-0.1, 0.0, 0.12)
	var rb := Vector3(0.1, 0.0, 0.12)
	var rc := Vector3(0.1, ty + 0.004, zf)
	var rd := Vector3(-0.1, ty + 0.004, zf)
	k.quad(ra, rb, rc, rd, Color(0.80, 0.76, 0.66), Kit.STONE, Vector3(0, -1, 0.5))
	k.quad(Vector3(-0.1, 0, 0.12), Vector3(-0.1, ty, zf), Vector3(-0.1, 0, zf), Vector3(-0.1, 0, zf), GREY, Kit.STONE, Vector3(0, 0.1, 0.0))
	k.tri(Vector3(-0.1, 0, 0.12), Vector3(-0.1, ty, zf), Vector3(-0.1, 0, zf), GREY, Kit.STONE, Vector3(0, 0.05, 0.0))
	k.tri(Vector3(0.1, 0, 0.12), Vector3(0.1, ty, zf), Vector3(0.1, 0, zf), GREY, Kit.STONE, Vector3(0, 0.05, 0.0))
	# great hall
	var hz := zt - 0.04
	k.box(Vector3(0, ty, hz), Vector3(1.5, 0.5, 0.72), RED_D, Kit.PAINT)
	var fz := hz + 0.36 + 0.02   # front face of the wall
	k.box(Vector3(0, ty, fz + 0.12), Vector3(1.56, 0.02, 0.28), MARBLE, Kit.STONE)   # veranda floor
	for i in 8:
		var x := -0.68 + i * (1.36 / 7.0)
		k.cylinder(Vector3(x, ty + 0.02, fz + 0.2), 0.026, 0.46, RED, Kit.PAINT, 6)
		k.box(Vector3(x, ty + 0.02, fz + 0.2), Vector3(0.07, 0.025, 0.07), GREY, Kit.STONE)
	for i in 7:
		var x := -0.68 + (i + 0.5) * (1.36 / 7.0)
		_win(k, Vector3(x, ty + 0.3, fz + 0.01), 0.0, 0.12, 0.3, WOOD, "lattice")
	k.box(Vector3(0, ty + 0.48, fz + 0.2), Vector3(1.56, 0.04, 0.06), BLUE, Kit.PAINT)
	k.box(Vector3(0, ty + 0.44, fz + 0.2), Vector3(1.56, 0.03, 0.05), GOLDC, Kit.GOLD)
	_brackets(k, 0.76, 0.4, ty + 0.5, 0.17, 0.05, RED, hz)
	k.box(Vector3(0, ty + 0.5, fz + 0.2), Vector3(1.6, 0.04, 0.05), RED_D, Kit.PAINT)
	var y1 := ty + 0.58
	_roof(k, Vector3(0, y1, hz), 1.5, 0.72, 0.2, 0.3, 0.03, 0.09, ROOF, Kit.OWNER_ROOF, 0.62, 0.2, 6, 0.0, true, 1.0, true, 1)
	# upper storey of the double eave
	var y2 := y1 + 0.2 + 0.03
	k.box(Vector3(0, y2, hz), Vector3(1.24, 0.22, 0.4), RED_D, Kit.PAINT)
	for i in 5:
		_win(k, Vector3(-0.44 + i * 0.22, y2 + 0.13, hz + 0.202), 0.0, 0.12, 0.12, WOOD, "lattice")
	for x in [-0.62, -0.31, 0.0, 0.31, 0.62]:
		k.box(Vector3(x, y2, hz + 0.205), Vector3(0.035, 0.22, 0.035), RED, Kit.PAINT)
	_brackets(k, 0.62, 0.2, y2 + 0.22, 0.2, 0.05, RED, hz)
	_roof(k, Vector3(0, y2 + 0.29, hz), 1.24, 0.4, 0.38, 0.26, 0.032, 0.12, ROOF, Kit.OWNER_ROOF, -1.0, 0.0, 6, 0.0, true, 1.4, true, 1)
	# side galleries
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 1.28, 0, 0.72), Vector3(0.36, 0.05, 1.4), GREY, Kit.STONE)
		k.box(Vector3(s * 1.31, 0.05, 0.72), Vector3(0.2, 0.3, 1.3), WHITE, Kit.PLASTER)
		for i in 6:
			var z := 0.12 + i * (1.2 / 5.0)
			k.cylinder(Vector3(s * 1.17, 0.05, z), 0.02, 0.3, RED, Kit.PAINT, 6)
			if i < 5:
				_win(k, Vector3(s * 1.211, 0.2, z + 0.12), -s * PI / 2.0, 0.1, 0.12, WOOD, "lattice")
		k.box(Vector3(s * 1.17, 0.33, 0.72), Vector3(0.045, 0.03, 1.28), RED_D, Kit.PAINT)
		_roof(k, Vector3(s * 1.28, 0.38, 0.72), 1.3, 0.24, 0.2, 0.13, 0.026, 0.07, ROOF, Kit.OWNER_ROOF, -1.0, 0.0, 4, PI / 2.0, true, 0.9, true, 2)
	# gate house and walls
	k.box(Vector3(0, 0, 1.45), Vector3(0.96, 0.05, 0.4), GREY, Kit.STONE)
	k.box(Vector3(0, 0.05, 1.45), Vector3(0.84, 0.34, 0.32), RED_D, Kit.PAINT)
	k.box(Vector3(0, 0.05, 1.45 - 0.0), Vector3(0.22, 0.26, 0.34), Color(0.07, 0.05, 0.04), Kit.DARK)
	k.box(Vector3(0, 0.05, 1.6), Vector3(0.2, 0.24, 0.015), RED, Kit.PAINT)
	for x in [-0.42, -0.21, 0.21, 0.42]:
		k.cylinder(Vector3(x, 0.05, 1.62), 0.022, 0.34, RED, Kit.PAINT, 6)
	_brackets(k, 0.42, 0.16, 0.39, 0.18, 0.05, RED, 1.45)
	_roof(k, Vector3(0, 0.45, 1.45), 0.84, 0.32, 0.26, 0.2, 0.028, 0.1, ROOF, Kit.OWNER_ROOF, -1.0, 0.0, 5, 0.0, true, 1.1, true, 1)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.8, 0, 1.45), Vector3(0.68, 0.2, 0.06), WHITE, Kit.PLASTER)
		k.box(Vector3(s * 0.8, 0.2, 1.45), Vector3(0.72, 0.025, 0.1), SLATE, Kit.TILE)
		# bronze incense burners before the hall
		k.frustum(Vector3(s * 0.55, 0.03, 0.4), 0.05, 0.07, 0.09, Color(0.6, 0.45, 0.2), Kit.GOLD, 6)
		k.box(Vector3(s * 0.55, 0.03, 0.4), Vector3(0.12, 0.02, 0.12), GREY, Kit.STONE)


# --- castle keep ------------------------------------------------------------------------------


static func _tier(k: Kit, w: float, d: float, y: float, bh: float, over: float, rise: float, rx: float, rz: float, curl: float) -> void:
	# plaster storey with a black timber band and lattice windows, then a hipped roof
	k.box(Vector3(0, y, 0), Vector3(w, bh, d), WHITE, Kit.PLASTER)
	k.box(Vector3(0, y, 0), Vector3(w + 0.025, bh * 0.28, d + 0.025), Color(0.18, 0.14, 0.12), Kit.TIMBER)
	k.box(Vector3(0, y + bh - 0.03, 0), Vector3(w + 0.02, 0.03, d + 0.02), Color(0.2, 0.15, 0.12), Kit.TIMBER)
	var nwin := maxi(2, int(w / 0.3))
	for i in nwin:
		var x := -w / 2.0 + (i + 0.5) * w / nwin
		_win(k, Vector3(x, y + bh * 0.62, d / 2.0 + 0.014), 0.0, 0.09, 0.12, Color(0.2, 0.15, 0.12), "lattice")
		_win(k, Vector3(x, y + bh * 0.62, -d / 2.0 - 0.014), PI, 0.09, 0.12, Color(0.2, 0.15, 0.12), "lattice")
	for s in [-1.0, 1.0]:
		_win(k, Vector3(s * (w / 2.0 + 0.014), y + bh * 0.62, 0), s * PI / 2.0, 0.09, 0.12, Color(0.2, 0.15, 0.12), "lattice")
	_roof(k, Vector3(0, y + bh, 0), w, d, rise, over, 0.03, curl, ROOF_D, Kit.OWNER_ROOF, rx, rz, 5, 0.0, true, 0.0, false, 1)


static func _keep(k: Kit) -> void:
	# sloped stone base with a flared foot
	k.plinth(Vector3(0, 0, 0), 2.3, 1.9, 0.6, 0.3, Color(0.58, 0.57, 0.54), Kit.STONE)
	k.box(Vector3(0, 0, 0), Vector3(2.34, 0.05, 1.94), Color(0.5, 0.49, 0.46), Kit.STONE)
	k.box(Vector3(0, 0.6, 0), Vector3(1.7, 0.04, 1.3), Color(0.45, 0.44, 0.42), Kit.STONE)
	var y := 0.64
	# entrance annex at the front
	k.box(Vector3(0, y, 0.78), Vector3(0.56, 0.34, 0.5), WHITE, Kit.PLASTER)
	k.box(Vector3(0, y, 0.78), Vector3(0.585, 0.1, 0.525), Color(0.18, 0.14, 0.12), Kit.TIMBER)
	k.door(Vector3(0, y, 1.032), 0.0, 0.18, 0.24, Color(0.2, 0.15, 0.12))
	k.gable_roof(Vector3(0, y + 0.34, 0.78), 0.5, 0.56, 0.24, 0.12, 0.03, ROOF_D, Kit.OWNER_ROOF, WHITE, Kit.PLASTER, PI / 2.0, 0.0)
	# the main storeys
	var dims := [[1.5, 1.2, 0.46, 0.22, 0.2], [1.15, 0.9, 0.4, 0.2, 0.18], [0.85, 0.65, 0.34, 0.18, 0.17], [0.55, 0.42, 0.28, 0.16, 0.15]]
	for i in 3:
		var dd: Array = dims[i]
		var nx: Array = dims[i + 1]
		var nw: float = nx[0]
		var nd: float = nx[1]
		_tier(k, dd[0], dd[1], y, dd[2], dd[3], dd[4], nw / 2.0 + 0.04, nd / 2.0 + 0.04, 0.09)
		# chidori-hafu gable on the front slope
		var w: float = dd[0]
		var d: float = dd[1]
		var gz: float = d / 2.0 + float(dd[3]) * 0.5
		var gy: float = y + float(dd[2]) + 0.02
		k.box(Vector3(0, gy, gz), Vector3(0.36, 0.1, 0.2), WHITE, Kit.PLASTER)
		k.gable_roof(Vector3(0, gy + 0.1, gz - 0.04), 0.32, 0.46, 0.17, 0.05, 0.025, ROOF_D, Kit.OWNER_ROOF, WHITE, Kit.PLASTER, PI / 2.0, 0.02)
		if i == 1:   # curved karahafu on the second tier, back side gable
			k.gable_roof(Vector3(0, gy + 0.1, -gz + 0.04), 0.32, 0.46, 0.17, 0.05, 0.025, ROOF_D, Kit.OWNER_ROOF, WHITE, Kit.PLASTER, PI / 2.0, 0.02)
		y += float(dd[2]) + float(dd[4]) + 0.03
	# the top storey with an irimoya roof and golden shachi
	var top: Array = dims[3]
	k.box(Vector3(0, y, 0), Vector3(top[0], top[2], top[1]), WHITE, Kit.PLASTER)
	k.box(Vector3(0, y, 0), Vector3(float(top[0]) + 0.025, 0.08, float(top[1]) + 0.025), Color(0.18, 0.14, 0.12), Kit.TIMBER)
	for x in [-0.17, 0.0, 0.17]:
		_win(k, Vector3(x, y + 0.18, float(top[1]) / 2.0 + 0.014), 0.0, 0.1, 0.12, Color(0.2, 0.15, 0.12), "lattice")
	for s in [-1.0, 1.0]:
		_win(k, Vector3(s * (float(top[0]) / 2.0 + 0.014), y + 0.18, 0), s * PI / 2.0, 0.1, 0.12, Color(0.2, 0.15, 0.12), "lattice")
	var yt := y + float(top[2])
	_roof(k, Vector3(0, yt, 0), float(top[0]), float(top[1]), 0.3, 0.2, 0.035, 0.1, ROOF_D, Kit.OWNER_ROOF, -1.0, 0.0, 5, 0.0, true, 1.2, true, 1)
	for s in [-1.0, 1.0]:
		var b := Vector3(s * 0.12, yt + 0.3 + 0.035, 0)
		k.frustum(b, 0.035, 0.012, 0.15, GOLDC, Kit.GOLD, 6)
		k.rod(b + Vector3(0, 0.14, 0), b + Vector3(-s * 0.03, 0.2, 0), 0.012, GOLDC, Kit.GOLD)
	for s in [-1.0, 1.0]:   # corner turrets on the base
		k.box(Vector3(s * 0.95, 0.6, 0.62), Vector3(0.05, 0.05, 0.05), Color(0.4, 0.39, 0.37), Kit.STONE)


# --- gate -------------------------------------------------------------------------------------


static func _gate(k: Kit) -> void:
	var cols := [-0.46, -0.16, 0.16, 0.46]
	var hs := [0.7, 0.95, 0.95, 0.7]
	for i in 4:
		var x: float = cols[i]
		var h: float = hs[i]
		k.box(Vector3(x, 0, 0), Vector3(0.12, 0.09, 0.12), GREY, Kit.STONE)
		k.cylinder(Vector3(x, 0.09, 0), 0.03, h - 0.09, RED, Kit.PAINT, 8)
		# back props
		k.rod(Vector3(x, 0.4, -0.01), Vector3(x, 0.02, -0.15), 0.01, WOOD, Kit.TIMBER)
		k.box(Vector3(x, 0, -0.17), Vector3(0.06, 0.04, 0.06), GREY, Kit.STONE)
	# lintels
	k.box(Vector3(0, 0.64, 0), Vector3(0.38, 0.05, 0.08), RED_D, Kit.PAINT)
	k.box(Vector3(0, 0.76, 0), Vector3(0.38, 0.1, 0.08), BLUE, Kit.PAINT)
	k.box(Vector3(0, 0.87, 0), Vector3(0.36, 0.04, 0.07), GOLDC, Kit.GOLD)
	k.box(Vector3(0, 0.66, 0.045), Vector3(0.2, 0.12, 0.012), Color(0.08, 0.1, 0.2), Kit.PAINT)
	k.box(Vector3(0, 0.66, 0.052), Vector3(0.14, 0.06, 0.006), GOLDC, Kit.GOLD)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.31, 0.5, 0), Vector3(0.28, 0.05, 0.07), RED_D, Kit.PAINT)
		k.box(Vector3(s * 0.31, 0.58, 0), Vector3(0.28, 0.07, 0.07), BLUE, Kit.PAINT)
		_roof(k, Vector3(s * 0.46, 0.7, 0), 0.14, 0.1, 0.12, 0.08, 0.02, 0.06, ROOF, Kit.OWNER_ROOF, -1.0, 0.0, 3, 0.0, true, 0.7, true, 1)
	# bracket sets under the big roof
	for x in [-0.16, -0.05, 0.05, 0.16]:
		k.box(Vector3(x, 0.95, 0), Vector3(0.05, 0.05, 0.1), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.95, 0), Vector3(0.4, 0.025, 0.12), RED_D, Kit.PAINT)
	_roof(k, Vector3(0, 1.0, 0), 0.36, 0.1, 0.17, 0.1, 0.024, 0.09, ROOF, Kit.OWNER_ROOF, -1.0, 0.0, 4, 0.0, true, 1.0, true, 1)
