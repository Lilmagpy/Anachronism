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


## How many variants each generated family has: kinds are named house_<family>_<n>.
const FAMILIES := {"cn_siheyuan": 3, "cn_shop": 5, "cn_merchant": 4, "cn_farm": 4, "cn_south": 4,
	"jp_machiya": 4, "jp_minka": 4, "jp_samurai": 3, "jp_kura": 3, "kr_hanok": 4, "kr_choga": 3}
## Two-lot buildings, all about 2.0 wide by 1.0 deep.
const BIGS := ["big_cn_shoprow_1", "big_cn_shoprow_2", "big_cn_shoprow_3", "big_cn_courtyard_1", "big_cn_courtyard_2",
	"big_cn_south_row", "big_cn_farmstead", "big_jp_row_1", "big_jp_row_2", "big_jp_samurai", "big_jp_farmstead",
	"big_kr_hanok", "big_kr_farmstead"]
const PROPS := ["prop_stone_lantern", "prop_shrine", "prop_torii", "prop_lantern_post", "prop_water_jars", "prop_drying_rack"]


static func kinds() -> Array:
	var out := ["house_1", "house_2", "house_3", "house_4", "house_5", "house_6", "pagoda", "palace", "castle_keep", "gate"]
	for fam in FAMILIES:
		for n in range(1, int(FAMILIES[fam]) + 1):
			out.append("house_%s_%d" % [fam, n])
	out.append_array(BIGS)
	out.append_array(PROPS)
	return out


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	if kind.begins_with("house_") and kind.count("_") >= 3:
		var parts := kind.split("_")
		_gen(k, parts[1] + "_" + parts[2], int(parts[3]))
		return k.finish()
	if kind.begins_with("big_"):
		_big(k, kind)
		return k.finish()
	if kind.begins_with("prop_"):
		_prop(k, kind)
		return k.finish()
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


# =================================================================================================
# Generated houses (D-281): many kinds from parameter tables instead of hand-made copies.
# A house is a dictionary of parameters read by `_hb`; each family has a `_params_*` table whose
# variant number picks the width, storeys, roof form, front, annex, materials and extras.
# =================================================================================================

const DARKC := Color(0.07, 0.05, 0.04)
const OCHRE := Color(0.80, 0.68, 0.46)
const PINKW := Color(0.84, 0.70, 0.60)
const BRICKG := Color(0.55, 0.56, 0.56)
const BRICKR := Color(0.62, 0.36, 0.28)
const MUD := Color(0.72, 0.62, 0.46)
const BARK := Color(0.22, 0.16, 0.11)
const PINE := Color(0.20, 0.38, 0.22)
const NAMAKO := Color(0.17, 0.17, 0.19)


## Flat panel facing +z (dirn 1) or -z (dirn -1) at depth z: windows, planks, door leaves.
static func _strip_z(k: Kit, x0: float, x1: float, y0: float, y1: float, z: float, col: Color, mat: int, dirn := 1.0) -> void:
	k.quad(Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), col, mat,
		Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, z - dirn))


## A door: leaf and a frame of flat strips (about 8 triangles).
static func _door(k: Kit, x: float, y: float, z: float, w: float, h: float, leaf: Color, frame: Color) -> void:
	_strip_z(k, x - w / 2.0, x + w / 2.0, y, y + h, z + 0.008, leaf, Kit.TIMBER)
	_strip_z(k, x - w / 2.0 - 0.025, x + w / 2.0 + 0.025, y + h, y + h + 0.035, z + 0.012, frame, Kit.TIMBER)
	_strip_z(k, x - w / 2.0 - 0.025, x - w / 2.0, y, y + h, z + 0.012, frame, Kit.TIMBER)
	_strip_z(k, x + w / 2.0, x + w / 2.0 + 0.025, y, y + h, z + 0.012, frame, Kit.TIMBER)


## A window of flat strips facing `yaw`: styles lattice, shutters, plain, round, slit.
static func _wn(k: Kit, pos: Vector3, yaw: float, w: float, h: float, frame: Color, style := "lattice") -> void:
	k.push(Kit.at(pos, yaw))
	var f := 0.018 + w * 0.08
	if style == "round":
		var ring: Array = []
		var core: Array = []
		for i in 8:
			var a := i * TAU / 8.0
			ring.append(Vector3(cos(a) * (w / 2.0 + f), sin(a) * (w / 2.0 + f), 0.006))
			core.append(Vector3(cos(a) * w / 2.0, sin(a) * w / 2.0, 0.01))
		k.polygon(ring, frame, Kit.TIMBER, Vector3(0, 0, -1))
		k.polygon(core, DARKC, Kit.DARK, Vector3(0, 0, -1))
		k.pop()
		return
	_strip_z(k, -w / 2.0 - f, w / 2.0 + f, -h / 2.0 - f, h / 2.0 + f, 0.006, frame, Kit.TIMBER)
	_strip_z(k, -w / 2.0, w / 2.0, -h / 2.0, h / 2.0, 0.01, DARKC, Kit.DARK)
	if style == "lattice":
		for bx in [-w / 6.0, w / 6.0]:
			_strip_z(k, bx - 0.006, bx + 0.006, -h / 2.0, h / 2.0, 0.014, frame, Kit.TIMBER)
		_strip_z(k, -w / 2.0, w / 2.0, -0.006, 0.006, 0.014, frame, Kit.TIMBER)
	elif style == "shutters":
		var sc := frame.darkened(0.12)
		_strip_z(k, -w * 1.5 - f, -w / 2.0 - f, -h / 2.0 - f, h / 2.0 + f, 0.012, sc, Kit.TIMBER)
		_strip_z(k, w / 2.0 + f, w * 1.5 + f, -h / 2.0 - f, h / 2.0 + f, 0.012, sc, Kit.TIMBER)
	k.pop()


## A small upper balcony: deck and a railing on three sides.
static func _balcony(k: Kit, x: float, y: float, z: float, w: float, depth: float, col: Color, mat: int) -> void:
	k.box(Vector3(x, y, z + depth / 2.0), Vector3(w, 0.03, depth), WOOD_L, Kit.TIMBER)
	var zz := z + depth - 0.01
	var h := 0.085
	for px in [-w / 2.0 + 0.012, 0.0, w / 2.0 - 0.012]:
		k.box(Vector3(x + px, y + 0.03, zz), Vector3(0.02, h, 0.02), col, mat)
	k.rod(Vector3(x - w / 2.0 + 0.012, y + 0.03 + h, zz), Vector3(x + w / 2.0 - 0.012, y + 0.03 + h, zz), 0.008, col, mat)
	for s in [-1.0, 1.0]:
		k.rod(Vector3(x + s * (w / 2.0 - 0.012), y + 0.03 + h, zz), Vector3(x + s * (w / 2.0 - 0.012), y + 0.03 + h, z), 0.008, col, mat)


## A small bit of life (barrel, jar, woodpile, haystack, tree, lantern, crates, well, bush, pine...).
static func _bit(k: Kit, what: String, x: float, z: float, s := 1.0) -> void:
	var p := Vector3(x, 0, z)
	match what:
		"barrel":
			k.frustum(p, 0.03 * s, 0.026 * s, 0.07 * s, WOOD, Kit.TIMBER, 6)
		"jar":
			k.frustum(p, 0.035 * s, 0.05 * s, 0.07 * s, Color(0.45, 0.30, 0.18), Kit.PAINT, 7, false)
			k.dome(p + Vector3(0, 0.07 * s, 0), 0.05 * s, Color(0.45, 0.30, 0.18), Kit.PAINT, 0.45, 2, 7)
		"wood":
			for i in 3:
				k.box(p + Vector3(0, i * 0.03 * s, 0), Vector3(0.14 * s, 0.03 * s, 0.05 * s - i * 0.006), WOOD_L, Kit.TIMBER)
		"hay":
			k.frustum(p, 0.1 * s, 0.07 * s, 0.13 * s, STRAW, Kit.THATCH, 7, false)
			k.frustum(p + Vector3(0, 0.13 * s, 0), 0.07 * s, 0.0, 0.09 * s, STRAW.darkened(0.1), Kit.THATCH, 7)
		"tree":
			k.frustum(p, 0.016 * s, 0.012 * s, 0.14 * s, BARK, Kit.TIMBER, 5, false)
			k.dome(p + Vector3(0, 0.12 * s, 0), 0.1 * s, Color(0.30, 0.50, 0.22), Kit.LEAF, 0.8, 3, 7)
			k.dome(p + Vector3(0.05 * s, 0.18 * s, 0.02 * s), 0.062 * s, Color(0.38, 0.56, 0.26), Kit.LEAF, 0.8, 2, 7)
		"pine":
			k.frustum(p, 0.014 * s, 0.012 * s, 0.1 * s, BARK, Kit.TIMBER, 5, false)
			k.frustum(p + Vector3(0, 0.07 * s, 0), 0.1 * s, 0.03 * s, 0.07 * s, PINE, Kit.LEAF, 7)
			k.frustum(p + Vector3(0, 0.13 * s, 0), 0.075 * s, 0.0, 0.08 * s, PINE.lightened(0.08), Kit.LEAF, 7)
		"crates":
			k.box(p, Vector3(0.08 * s, 0.06 * s, 0.07 * s), WOOD_L, Kit.TIMBER, 0.3)
			k.box(p + Vector3(0.01, 0.06 * s, 0), Vector3(0.06 * s, 0.05 * s, 0.06 * s), WOOD, Kit.TIMBER, -0.2)
		"well":
			k.frustum(p, 0.06 * s, 0.055 * s, 0.07 * s, GREY, Kit.STONE, 7)
			k.frustum(p + Vector3(0, 0.06 * s, 0), 0.04 * s, 0.04 * s, 0.002, Color(0.15, 0.25, 0.3), Kit.WATER, 7)
		"bush":
			k.dome(p, 0.07 * s, Color(0.32, 0.50, 0.24), Kit.LEAF, 0.75, 2, 7)
		"lantern":
			k.rod(p, p + Vector3(0, 0.2 * s, 0), 0.008 * s, WOOD, Kit.TIMBER)
			_lantern(k, p + Vector3(0, 0.15 * s, 0.0), 1.1 * s)
		"stool":
			k.frustum(p, 0.035 * s, 0.035 * s, 0.04 * s, WOOD_L, Kit.TIMBER, 6)
		"pen":
			for i in 5:
				var a := i * TAU / 5.0
				k.box(p + Vector3(cos(a) * 0.1 * s, 0, sin(a) * 0.1 * s), Vector3(0.016, 0.07, 0.016), WOOD, Kit.TIMBER)
			k.box(p + Vector3(0, 0, 0), Vector3(0.12 * s, 0.012, 0.12 * s), MUD.darkened(0.15), Kit.EARTH)
		"sign":
			k.rod(p, p + Vector3(0, 0.22 * s, 0), 0.01, WOOD, Kit.TIMBER)
			k.box(p + Vector3(0, 0.12 * s, 0), Vector3(0.1 * s, 0.1 * s, 0.01), Color.WHITE, Kit.OWNER_CLOTH)


# --- roofs ------------------------------------------------------------------------------------


## Height of a curved roof profile at t (0 at the eave, 1 at the ridge): shallow near the eave,
## steeper towards the ridge, the eave tip lifted by `curl`.
static func _prof(t: float, rise: float, g: float, curl: float, drop: float) -> float:
	return -drop + (rise + drop) * pow(t, g) + curl * pow(1.0 - t, 3.0)


## A gabled roof with a curved profile, ridge along x (yaw PI/2 turns it along z). `g` bends the
## slope (1 = straight), `curl` lifts the eaves, `overx` is the overhang at the gable ends.
static func _gable(k: Kit, foot: Vector3, w: float, d: float, rise: float, over: float, thick: float,
		col: Color, mat: int, curl: float, wall: Color, wmat: int, yaw := 0.0, g := 1.5, orn := true,
		overx := -1.0, steps := 3) -> void:
	if overx < 0.0:
		overx = over
	k.push(Kit.at(foot, yaw))
	var hw := w / 2.0 + overx
	var hd := d / 2.0 + over
	var drop := 0.03
	var up := Vector3(0, thick, 0)
	var below := Vector3(0, -1, 0)
	for s in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		for i in steps + 1:
			var t := float(i) / steps
			var cur := Vector3(0, _prof(t, rise, g, curl, drop), s * hd * (1.0 - t))
			if i > 0:
				k.quad(Vector3(-hw, prev.y, prev.z) + up, Vector3(hw, prev.y, prev.z) + up, Vector3(hw, cur.y, cur.z) + up,
					Vector3(-hw, cur.y, cur.z) + up, col, mat, below)
				for x in [-hw, hw]:
					k.quad(Vector3(x, prev.y, prev.z), Vector3(x, cur.y, cur.z), Vector3(x, cur.y, cur.z) + up,
						Vector3(x, prev.y, prev.z) + up, col.darkened(0.2), mat, Vector3(0, rise * 0.4, 0))
			prev = cur
		var e := Vector3(0, _prof(0.0, rise, g, curl, drop), s * hd)
		k.quad(Vector3(-hw, e.y, e.z), Vector3(hw, e.y, e.z), Vector3(hw, e.y, e.z) + up, Vector3(-hw, e.y, e.z) + up,
			col.darkened(0.2), mat, Vector3(0, rise, 0))
		k.quad(Vector3(-hw, e.y, e.z), Vector3(hw, e.y, e.z), Vector3(hw, rise, 0), Vector3(-hw, rise, 0),
			col.darkened(0.35), mat, Vector3(0, 10, 0))
	k.box(Vector3(0, rise + thick * 0.4, 0), Vector3(w + overx * 2.0 + thick, thick * 1.3, thick * 1.8), col.darkened(0.15), mat)
	if wmat >= 0:
		for x in [-w / 2.0, w / 2.0]:
			for j in 4:
				var z0 := -d / 2.0 + d * j / 4.0
				var z1 := -d / 2.0 + d * (j + 1) / 4.0
				var y0 := _prof(1.0 - absf(z0) / hd, rise, g, curl, drop) + thick * 0.4
				var y1 := _prof(1.0 - absf(z1) / hd, rise, g, curl, drop) + thick * 0.4
				k.quad(Vector3(x, 0, z0), Vector3(x, 0, z1), Vector3(x, y1, z1), Vector3(x, y0, z0), wall, wmat, Vector3(0, rise * 0.3, 0))
	if orn:
		for s in [-1.0, 1.0]:
			var b := Vector3(s * (w / 2.0 + overx - 0.01), rise + thick, 0)
			k.rod(b, b + Vector3(s * 0.025, 0.07, 0), 0.014, col.darkened(0.3), mat)
	k.pop()


## A half-hipped roof (xieshan): a hipped skirt with a small gable set on its flat top.
static func _halfhip(k: Kit, foot: Vector3, w: float, d: float, rise: float, over: float, thick: float, curl: float,
		col: Color, mat: int, wall: Color, wmat: int, yaw := 0.0, rn := 3) -> void:
	k.push(Kit.at(foot, yaw))
	var low := rise * 0.55
	var rx := w * 0.30
	var rz := d * 0.2
	_roof(k, Vector3.ZERO, w, d, low, over, thick, curl, col, mat, rx, rz, rn, 0.0, false, 0.8, false, 0, false)
	_gable(k, Vector3(0, low + thick, 0), rx * 2.0, rz * 2.0 + 0.04, rise - low, 0.03, thick * 0.9, col, mat, 0.0, wall, wmat,
		0.0, 1.2, true, 0.07, 2)
	k.pop()


## Roofs of the generated houses, by form: hip, hipz, gable, gablez, halfhip, thatch, thatchz,
## thatch_hip, irimoya (thatch skirt and gable), pent. `zc` shifts the roof to cover a veranda.
static func _roofs(k: Kit, p: Dictionary, y: float, wr: float, dr: float, zc: float) -> void:
	var form: String = p.get("form", "hip")
	var rise: float = p.get("rise", 0.25)
	var over: float = p.get("over", 0.1)
	var thick: float = p.get("thick", 0.028)
	var curl: float = p.get("curl", 0.07)
	var rc: Color = p.get("rc", ROOF)
	var rm: int = p.get("rm", Kit.OWNER_ROOF)
	var gc: Color = p.get("gc", WHITE)
	var gm: int = p.get("gm", Kit.PLASTER)
	var g: float = p.get("g", 1.5)
	var raf: bool = p.get("raf", false)
	var overx: float = p.get("overx", -1.0)
	var rn: int = p.get("rn", 2 if p.get("lite", false) else 3)
	var foot := Vector3(0, y, zc)
	match form:
		"hip":
			_roof(k, foot, wr, dr, rise, over, thick, curl, rc, rm, -1.0, 0.0, rn, 0.0, raf, 0.9 if rm == Kit.OWNER_ROOF else 0.0, rm == Kit.OWNER_ROOF, 3, false)
		"hipz":
			_roof(k, foot, dr, wr, rise, over, thick, curl, rc, rm, -1.0, 0.0, rn, PI / 2.0, raf, 0.9, true, 3, false)
		"gable":
			_gable(k, foot, wr, dr, rise, over, thick, rc, rm, curl, gc, gm, 0.0, g, true, overx)
		"gablez":
			_gable(k, foot, dr, wr, rise, over, thick, rc, rm, curl, gc, gm, PI / 2.0, g, true, overx)
		"halfhip":
			_halfhip(k, foot, wr, dr, rise, over, thick, curl, rc, rm, gc, gm, 0.0, rn)
		"halfhipz":
			_halfhip(k, foot, dr, wr, rise, over, thick, curl, rc, rm, gc, gm, PI / 2.0, rn)
		"thatch":
			k.gable_roof(foot, wr, dr, rise, over, 0.065, STRAW, Kit.THATCH, WOOD_L, Kit.TIMBER, 0.0, 0.0)
		"thatchz":
			k.gable_roof(foot, dr, wr, rise, over, 0.065, STRAW, Kit.THATCH, WOOD_L, Kit.TIMBER, PI / 2.0, 0.0)
		"thatch_hip":
			k.hip_roof(foot, wr, dr, rise, over, 0.06, STRAW, Kit.THATCH, 0.0, 0.0)
			k.frustum(foot + Vector3(0, rise + 0.05, 0), 0.03, 0.0, 0.07, STRAW.darkened(0.2), Kit.THATCH, 5)
		"irimoya":
			_roof(k, foot, wr, dr, rise * 0.55, over, 0.06, 0.0, STRAW, Kit.THATCH, wr * 0.3, dr * 0.12, 3, 0.0, false, 0.0, false, 0, false)
			k.gable_roof(foot + Vector3(0, rise * 0.55 + 0.06, 0), wr * 0.6 + 0.08, dr * 0.24 + 0.1, rise * 0.45, 0.04, 0.05,
				STRAW.darkened(0.06), Kit.THATCH, WOOD_L, Kit.TIMBER, 0.0, 0.0)
		"pent":
			_lean(k, 0.0, wr / 2.0 + over, y + rise, -dr / 2.0 - over, dr / 2.0 + over, rise, 0.026, rc, rm)


# --- the parametric house -------------------------------------------------------------------------
# Keys (all optional): w d (body), st (storeys), h1 h2 (storey heights), pl (plinth), wm wc (wall
# material, colour), um uc (upper wall), pc pmat (post colour, material), trim, win (window style),
# frame (posts | grid | none), front (door | shop | slats | veranda | barn), dx ox (door / opening x),
# vd (veranda depth), jet (upper storey jutting out), pent (lean-to between storeys), balcony,
# nuw (upper windows), nsw (side windows), form rise over curl g thick rc rm gc gm raf overx (roof),
# brk (0 none, 1 eave beam, 2 brackets), an aw ah ad az at am acol arm (annex), chim [x, z],
# ex [[bit, x, z, scale]...], sign (hanging shop sign), lanterns, lite (fewer details).


static func _hb(k: Kit, p: Dictionary) -> void:
	var w: float = p.get("w", 0.7)
	var d: float = p.get("d", 0.5)
	var st: int = p.get("st", 1)
	var h1: float = p.get("h1", 0.32)
	var h2: float = p.get("h2", 0.26)
	var pl: float = p.get("pl", 0.06)
	var wm: int = p.get("wm", Kit.PLASTER)
	var wc: Color = p.get("wc", WHITE)
	var um: int = p.get("um", wm)
	var uc: Color = p.get("uc", wc)
	var pc: Color = p.get("pc", RED)
	var pmat: int = p.get("pmat", Kit.PAINT)
	var vd: float = p.get("vd", 0.0) if st == 1 else 0.0
	var an: int = p.get("an", 0)
	var aw: float = p.get("aw", 0.22)
	var jet: float = p.get("jet", 0.0)
	var front: String = p.get("front", "door")
	var frame: String = p.get("frame", "posts")
	var lite: bool = p.get("lite", false)
	var wst: String = p.get("win", "lattice")
	var trim: Color = p.get("trim", WOOD)
	var rc: Color = p.get("rc", ROOF)
	var rm: int = p.get("rm", Kit.OWNER_ROOF)
	var dx: float = p.get("dx", 0.0)
	k.push(Kit.at(Vector3(-float(an) * aw * 0.5, 0, -vd * 0.5)))
	k.box(Vector3(0, 0, vd * 0.5), Vector3(w + 0.08, pl, d + vd + 0.08), p.get("bc", GREY), p.get("bm", Kit.STONE))
	var y1 := pl + h1
	var zf := d * 0.5
	k.box(Vector3(0, pl, 0), Vector3(w, h1, d), wc, wm)
	# --- structure on the front and sides
	if frame == "posts":
		var np := maxi(2, int(round(w / (0.36 if lite else 0.22))) + 1)
		for i in np:
			k.box(Vector3(-w / 2.0 + w * i / (np - 1), pl, zf), Vector3(0.04, h1, 0.04), pc, pmat)
		for s in [-1.0, 1.0]:
			k.box(Vector3(s * w / 2.0, pl, -zf), Vector3(0.04, h1, 0.04), pc, pmat)
		k.box(Vector3(0, y1 - 0.035, zf), Vector3(w + 0.04, 0.035, 0.05), pc.darkened(0.2), pmat)
	elif frame == "grid":
		var n := maxi(3, int(round(w / 0.2)))
		for i in n + 1:
			var x := -w / 2.0 + w * i / n
			_strip_z(k, x - 0.014, x + 0.014, pl, y1, zf + 0.006, trim, Kit.TIMBER)
		_strip_z(k, -w / 2.0, w / 2.0, y1 - 0.04, y1, zf + 0.007, trim, Kit.TIMBER)
		_strip_z(k, -w / 2.0, w / 2.0, pl + h1 * 0.5, pl + h1 * 0.5 + 0.02, zf + 0.007, trim, Kit.TIMBER)
		for s in [-1.0, 1.0]:
			k.box(Vector3(s * w / 2.0, pl, zf), Vector3(0.035, h1, 0.035), trim, Kit.TIMBER)
	# --- the front
	match front:
		"door":
			_door(k, dx, pl, zf, 0.15, minf(0.25, h1 * 0.76), WOOD, trim)
			for x in [-w * 0.33, w * 0.33, -w * 0.12, w * 0.12]:
				if absf(x - dx) > 0.18 and absf(x) > (0.0 if absf(w) > 0.8 else w * 0.2):
					_wn(k, Vector3(x, pl + h1 * 0.6, zf), 0.0, 0.1, minf(0.14, h1 * 0.4), trim, wst)
		"shop":
			var ox: float = p.get("ox", 0.0)
			var ow := w * 0.74
			_strip_z(k, ox - ow / 2.0, ox + ow / 2.0, pl + 0.02, y1 - 0.045, zf + 0.006, DARKC, Kit.DARK)
			for s in [-1.0, 1.0]:
				k.box(Vector3(ox + s * ow / 2.0, pl, zf + 0.02), Vector3(0.05, h1, 0.05), pc, pmat)
			k.box(Vector3(ox, pl, zf + 0.055), Vector3(ow * 0.86, 0.1, 0.06), WOOD_L, Kit.TIMBER)
			var gc2: Array = [Color(0.8, 0.3, 0.2), Color(0.9, 0.75, 0.3), Color(0.35, 0.55, 0.3), Color(0.8, 0.6, 0.4)]
			for i in 3:
				k.box(Vector3(ox - ow * 0.28 + i * ow * 0.28, pl + 0.1, zf + 0.055), Vector3(0.08, 0.04, 0.045), gc2[(i + int(w * 10.0)) % 4], Kit.CLOTH)
			var ns := 4
			for i in ns:
				var x0 := ox - ow / 2.0 - 0.04 + (ow + 0.08) * i / ns
				var x1 := ox - ow / 2.0 - 0.04 + (ow + 0.08) * (i + 1) / ns
				var c := Color.WHITE if i % 2 == 0 else CREAM
				var m := Kit.OWNER_CLOTH if i % 2 == 0 else Kit.CLOTH
				k.quad(Vector3(x0, y1 + 0.02, zf + 0.02), Vector3(x1, y1 + 0.02, zf + 0.02), Vector3(x1, y1 - 0.08, zf + 0.23),
					Vector3(x0, y1 - 0.08, zf + 0.23), c, m, Vector3(0, y1 - 0.2, zf + 0.1))
				k.quad(Vector3(x0, y1 - 0.08, zf + 0.23), Vector3(x1, y1 - 0.08, zf + 0.23), Vector3(x1, y1 - 0.12, zf + 0.23),
					Vector3(x0, y1 - 0.12, zf + 0.23), c, m, Vector3(0, y1 - 0.2, zf))
		"slats":
			var n2 := 12
			for i in n2:
				var x := -w / 2.0 + 0.05 + (w - 0.1) * i / (n2 - 1)
				if absf(x - dx) < 0.085:
					continue
				_strip_z(k, x - 0.011, x + 0.011, pl + 0.03, y1 - 0.04, zf + 0.012, WOOD_L, Kit.TIMBER)
			_strip_z(k, -w / 2.0 + 0.02, w / 2.0 - 0.02, pl + 0.03, pl + 0.06, zf + 0.014, WOOD, Kit.TIMBER)
			_strip_z(k, -w / 2.0 + 0.02, w / 2.0 - 0.02, y1 - 0.08, y1 - 0.05, zf + 0.014, WOOD, Kit.TIMBER)
			_strip_z(k, dx - 0.07, dx + 0.07, pl, y1 - 0.06, zf + 0.008, DARKC, Kit.DARK)
			_strip_z(k, dx - 0.085, dx + 0.085, y1 - 0.2, y1 - 0.06, zf + 0.02, Color.WHITE, Kit.OWNER_CLOTH)   # noren curtain
		"veranda":
			k.box(Vector3(0, pl, zf + vd / 2.0), Vector3(w + 0.03, 0.035, vd), WOOD_L, Kit.TIMBER)
			var nb := maxi(2, int(round(w / 0.19)))
			for i in nb:
				var x0 := -w / 2.0 + w * i / nb
				_wn(k, Vector3(x0 + w / nb / 2.0, pl + h1 * 0.55, zf), 0.0, w / nb * 0.5, h1 * 0.62, trim, "lattice")
			for i in nb + 1:
				k.box(Vector3(-w / 2.0 + w * i / nb, pl + 0.035, zf + vd - 0.025), Vector3(0.04, h1 - 0.035, 0.04), pc, pmat)
			k.box(Vector3(0, y1 - 0.035, zf + vd - 0.025), Vector3(w + 0.04, 0.04, 0.05), pc.darkened(0.2), pmat)
			k.box(Vector3(dx, 0, zf + vd + 0.03), Vector3(0.2, 0.035, 0.07), GREY, Kit.STONE)
		"barn":
			var bw := minf(0.34, w * 0.5)
			_strip_z(k, dx - bw / 2.0, dx + bw / 2.0, pl, pl + h1 * 0.85, zf + 0.008, WOOD, Kit.TIMBER)
			_strip_z(k, dx - 0.012, dx + 0.012, pl, pl + h1 * 0.85, zf + 0.012, DARKC, Kit.DARK)
			k.rod(Vector3(dx - bw / 2.0, pl, zf + 0.014), Vector3(dx, pl + h1 * 0.85, zf + 0.014), 0.008, WOOD_L, Kit.TIMBER)
			k.rod(Vector3(dx + bw / 2.0, pl, zf + 0.014), Vector3(dx, pl + h1 * 0.85, zf + 0.014), 0.008, WOOD_L, Kit.TIMBER)
		"windows":
			var nw := maxi(1, int(round(w / (0.42 if lite else 0.28))))
			for i in nw:
				_wn(k, Vector3(-w / 2.0 + w * (i + 0.5) / nw, pl + h1 * 0.58, zf), 0.0, 0.1, 0.13, trim, wst)
	var nsw: int = p.get("nsw", 1)
	if not lite:
		for s in [-1.0, 1.0]:
			for i in nsw:
				var z := -d * 0.5 + d * (i + 0.5) / nsw if nsw > 1 else -d * 0.05
				_wn(k, Vector3(s * (w / 2.0 + 0.002), pl + h1 * 0.58, z), s * PI / 2.0, 0.12, 0.13, trim, wst)
	# --- upper storey
	var y2 := y1
	var wr := w
	var dr := d + vd
	var zc := vd * 0.5
	if st >= 2:
		var uw := w * float(p.get("upw", 0.94))
		var ud := d - 0.04 + jet
		var zu := ud * 0.5 + jet * 0.0
		zu = d * 0.5 - 0.02 + jet
		var uz := (zu - ud * 0.5)
		k.box(Vector3(0, y1, uz), Vector3(uw, h2, ud), uc, um)
		if jet > 0.0:   # beam ends carrying the jetty
			for i in 5:
				k.box(Vector3(-uw / 2.0 + uw * i / 4.0, y1 - 0.025, zf + jet * 0.4), Vector3(0.025, 0.025, jet + 0.06), WOOD, Kit.TIMBER)
		if frame == "grid":
			var n3 := maxi(3, int(round(uw / 0.2)))
			for i in n3 + 1:
				var x := -uw / 2.0 + uw * i / n3
				_strip_z(k, x - 0.012, x + 0.012, y1, y1 + h2, zu + 0.006, trim, Kit.TIMBER)
			_strip_z(k, -uw / 2.0, uw / 2.0, y1 + h2 - 0.035, y1 + h2, zu + 0.007, trim, Kit.TIMBER)
		elif frame == "posts":
			for s in [-1.0, 1.0]:
				k.box(Vector3(s * uw / 2.0, y1, zu), Vector3(0.04, h2, 0.04), pc, pmat)
			k.box(Vector3(0, y1 + h2 - 0.03, zu), Vector3(uw + 0.03, 0.03, 0.045), pc.darkened(0.2), pmat)
		var nuw: int = p.get("nuw", 3)
		var bal: bool = p.get("balcony", false)
		if bal:
			_balcony(k, 0.0, y1, zu, uw * 0.62, 0.17, pc, pmat)
			_door(k, 0.0, y1 + 0.02, zu, 0.14, minf(0.2, h2 * 0.75), RED_D, trim)
		for i in nuw:
			var x := -uw / 2.0 + uw * (i + 0.5) / nuw
			if bal and absf(x) < 0.12:
				continue
			_wn(k, Vector3(x, y1 + h2 * 0.58, zu), 0.0, 0.1, 0.12, trim, wst)
		if not lite:
			for s in [-1.0, 1.0]:
				_wn(k, Vector3(s * (uw / 2.0 + 0.002), y1 + h2 * 0.58, uz - 0.02), s * PI / 2.0, 0.12, 0.12, trim, wst)
		if bool(p.get("pent", not bal)):
			_lean(k, 0.0, w / 2.0 + 0.04, y1 + 0.015, zu - 0.01 if jet == 0.0 else zu, zf + 0.125 + jet, 0.075, 0.022, rc, rm)
		y2 = y1 + h2
		wr = uw
		dr = ud
		zc = uz
	# --- roof
	var brk: int = p.get("brk", 1)
	if brk >= 1:
		k.box(Vector3(0, y2 - 0.005, zc), Vector3(wr + 0.03, 0.03, dr + 0.03), pc.darkened(0.25), pmat)
	if brk >= 2:
		_brackets(k, wr / 2.0, dr / 2.0, y2 + 0.015, 0.22, 0.04, pc, zc)
	_roofs(k, p, y2 + (0.045 if brk >= 2 else 0.02), wr, dr, zc)
	# --- gable-end firewalls: southern horse-head walls (mtq) and Kyoto udatsu
	if bool(p.get("mtq", false)):
		var rise: float = p.get("rise", 0.25)
		var y0 := y2 + 0.02
		for s in [-1.0, 1.0]:
			var xx: float = s * (wr / 2.0 + 0.01)
			var levels: Array = [[0.0, dr * 0.17, rise + 0.08], [dr * 0.17, dr * 0.33, rise * 0.62 + 0.05], [dr * 0.33, dr * 0.5 + 0.04, rise * 0.28 + 0.03]]
			for lv in levels:
				var za: float = lv[0]
				var zb: float = lv[1]
				var hh: float = lv[2]
				for sz in ([1.0] if za == 0.0 else [-1.0, 1.0]):
					var z0: float = (za * sz) if za != 0.0 else -zb
					var z1: float = (zb * sz) if za != 0.0 else zb
					var zm := (z0 + z1) / 2.0 + zc
					k.box(Vector3(xx, y0 - 0.04, zm), Vector3(0.045, hh + 0.04, absf(z1 - z0)), p.get("gc", WHITE), Kit.PLASTER)
					k.box(Vector3(xx, y0 + hh, zm), Vector3(0.07, 0.022, absf(z1 - z0) + 0.02), SLATE, Kit.TILE)
	if bool(p.get("udatsu", false)):
		var rise2: float = p.get("rise", 0.25)
		k.box(Vector3(wr / 2.0 + 0.01, y1 - 0.02, zc), Vector3(0.05, (y2 - y1) + rise2 + 0.1, dr * 0.9), WHITE, Kit.PLASTER)
		k.box(Vector3(wr / 2.0 + 0.01, y2 + rise2 + 0.08, zc), Vector3(0.085, 0.025, dr * 0.9 + 0.08), SLATE, Kit.TILE)
		k.box(Vector3(wr / 2.0 + 0.01, y2 + rise2 + 0.1, zc), Vector3(0.05, 0.03, dr * 0.5), SLATE, Kit.TILE)
	if p.has("namako"):
		var lc: Color = p.get("namako", Color.WHITE)
		for i in 5:
			var x := -w / 2.0 + w * (i + 0.5) / 5.0
			_strip_z(k, x - 0.006, x + 0.006, pl + 0.01, y1 - 0.01, zf + 0.007, lc, Kit.PLASTER)
		for j in 3:
			var yy := pl + h1 * (j + 1) / 4.0
			_strip_z(k, -w / 2.0, w / 2.0, yy - 0.006, yy + 0.006, zf + 0.007, lc, Kit.PLASTER)
	# --- annex
	if an != 0:
		var ah: float = p.get("ah", 0.2)
		var ad: float = p.get("ad", d * 0.8)
		var az: float = p.get("az", -d * 0.08)
		var ax := float(an) * (w / 2.0 + aw / 2.0 - 0.005)
		var acol: Color = p.get("acol", wc)
		var am: int = p.get("am", wm)
		k.box(Vector3(ax, 0, az), Vector3(aw + 0.04, pl * 0.8, ad + 0.04), GREY_D, Kit.STONE)
		k.box(Vector3(ax, pl * 0.8, az), Vector3(aw, ah, ad), acol, am)
		if bool(p.get("athatch", false)):
			k.gable_roof(Vector3(ax, pl * 0.8 + ah, az), ad, aw, 0.17, 0.05, 0.05, STRAW, Kit.THATCH, WOOD_L, Kit.TIMBER, PI / 2.0, 0.0)
		else:
			_gable(k, Vector3(ax, pl * 0.8 + ah, az), ad, aw, 0.12, 0.05, 0.022, rc.darkened(0.05), rm, 0.03, acol, am, PI / 2.0, 1.3, false, 0.06)
		_door(k, ax, pl * 0.8, az + ad / 2.0, 0.11, ah * 0.78, WOOD, trim)
	# --- details
	var chim: Array = p.get("chim", [])
	if chim.size() == 2:
		var cx: float = chim[0]
		var cz: float = chim[1]
		k.box(Vector3(cx, y2 - 0.05, cz), Vector3(0.07, 0.34, 0.07), Color(0.55, 0.50, 0.45), Kit.BRICK)
		k.box(Vector3(cx, y2 + 0.29, cz), Vector3(0.11, 0.03, 0.11), SLATE, Kit.TILE)
	if bool(p.get("sign", false)):
		k.rod(Vector3(w / 2.0, y1 - 0.02, zf + 0.01), Vector3(w / 2.0, y1 - 0.02, zf + 0.2), 0.01, WOOD, Kit.TIMBER)
		k.box(Vector3(w / 2.0, y1 - 0.2, zf + 0.19), Vector3(0.02, 0.18, 0.07), Color.WHITE, Kit.OWNER_CLOTH)
	if bool(p.get("lanterns", false)):
		for s in [-1.0, 1.0]:
			_lantern(k, Vector3(s * w * 0.36, y1 - 0.14, zf + vd + 0.04))
	var ex: Array = p.get("ex", [])
	for e in ex:
		var ea: Array = e
		_bit(k, str(ea[0]), float(ea[1]), float(ea[2]), float(ea[3]) if ea.size() > 3 else 1.0)
	k.pop()


# --- families ---------------------------------------------------------------------------------------


static func _gen(k: Kit, fam: String, n: int) -> void:
	match fam:
		"cn_siheyuan": _siheyuan(k, n)
		"jp_samurai": _samurai(k, n)
		"kr_hanok": _hanok(k, n)
		_: _hb(k, _params(fam, n))


## The parameter table of each hb-built family (one dictionary per variant).
static func _params(fam: String, n: int) -> Dictionary:
	match fam:
		"cn_shop":
			match n:
				1: return {"w": 0.72, "d": 0.54, "st": 2, "h1": 0.34, "h2": 0.28, "front": "shop", "uc": CREAM, "form": "hip",
					"rise": 0.26, "curl": 0.08, "balcony": true, "brk": 2, "sign": true, "nuw": 3}
				2: return {"w": 0.62, "d": 0.5, "st": 1, "h1": 0.34, "front": "shop", "wc": OCHRE, "form": "gable", "rise": 0.2,
					"over": 0.09, "curl": 0.05, "an": 1, "aw": 0.2, "ah": 0.2, "brk": 1, "rc": ROOF_D,
					"ex": [["barrel", -0.4, 0.42], ["crates", 0.38, 0.4]]}
				3: return {"w": 0.56, "d": 0.76, "st": 2, "h1": 0.32, "h2": 0.26, "wm": Kit.BRICK, "wc": BRICKG, "um": Kit.PLASTER,
					"uc": WHITE, "front": "shop", "form": "gablez", "rise": 0.27, "over": 0.08, "curl": 0.05, "sign": true,
					"nsw": 2, "nuw": 2, "lanterns": true}
				4: return {"w": 0.74, "d": 0.5, "st": 2, "wm": Kit.BRICK, "wc": BRICKG, "um": Kit.PLASTER, "uc": PINKW, "jet": 0.06,
					"front": "shop", "ox": -0.08, "form": "halfhip", "rise": 0.32, "curl": 0.09, "brk": 2, "rc": ROOF_D,
					"lanterns": true, "nuw": 3, "balcony": true}
				_: return {"w": 0.7, "d": 0.5, "st": 1, "h1": 0.3, "wm": Kit.EARTH, "wc": MUD, "pc": WOOD, "pmat": Kit.TIMBER,
					"front": "shop", "form": "hip", "rise": 0.2, "over": 0.12, "curl": 0.06, "rc": SLATE, "rm": Kit.TILE,
					"sign": true, "ex": [["crates", -0.4, 0.4], ["jar", 0.42, 0.36]]}
		"cn_merchant":
			match n:
				1: return {"w": 0.78, "d": 0.56, "st": 2, "h1": 0.3, "h2": 0.28, "front": "door", "form": "halfhip", "rise": 0.32,
					"curl": 0.09, "brk": 2, "balcony": true, "nuw": 4, "ex": [["tree", -0.43, 0.38]]}
				2: return {"w": 0.62, "d": 0.52, "st": 2, "wm": Kit.BRICK, "wc": BRICKG, "um": Kit.PLASTER, "uc": WHITE,
					"front": "door", "dx": 0.12, "an": -1, "aw": 0.22, "ah": 0.2, "form": "hip", "rc": ROOF_D, "rise": 0.24,
					"chim": [-0.22, -0.12], "win": "shutters", "nuw": 2, "pent": true}
				3: return {"w": 0.74, "d": 0.46, "st": 2, "h1": 0.28, "h2": 0.26, "jet": 0.05, "pc": WOOD_L, "pmat": Kit.TIMBER,
					"wc": CREAM, "uc": OCHRE, "front": "windows", "form": "gable", "rise": 0.3, "g": 1.4, "over": 0.1,
					"curl": 0.06, "chim": [0.25, -0.1], "nuw": 3, "ex": [["barrel", 0.4, 0.36]]}
				_: return {"w": 0.8, "d": 0.42, "st": 1, "h1": 0.36, "vd": 0.16, "front": "veranda", "wc": CREAM, "form": "halfhip",
					"rise": 0.3, "over": 0.1, "curl": 0.08, "brk": 2, "an": 1, "aw": 0.18, "ex": [["jar", -0.36, 0.38], ["bush", 0.1, 0.43]]}
		"cn_farm":
			match n:
				1: return {"w": 0.66, "d": 0.46, "st": 1, "h1": 0.28, "pl": 0.04, "wm": Kit.EARTH, "wc": MUD, "pc": WOOD,
					"pmat": Kit.TIMBER, "front": "door", "dx": 0.1, "form": "thatch", "rise": 0.34, "over": 0.1, "brk": 0,
					"an": 1, "aw": 0.2, "ah": 0.18, "athatch": true, "bc": GREY_D,
					"ex": [["hay", -0.4, 0.35], ["wood", 0.32, 0.4], ["pen", -0.36, -0.3]]}
				2: return {"w": 0.5, "d": 0.62, "st": 1, "h1": 0.26, "pl": 0.04, "wm": Kit.EARTH, "wc": MUD.darkened(0.08),
					"pc": WOOD, "pmat": Kit.TIMBER, "front": "door", "form": "thatchz", "rise": 0.32, "over": 0.1, "brk": 0,
					"an": -1, "aw": 0.2, "ah": 0.16, "athatch": true, "ex": [["barrel", 0.34, 0.4], ["bush", 0.42, -0.2]]}
				3: return {"w": 0.6, "d": 0.5, "st": 1, "h1": 0.27, "pl": 0.04, "wc": CREAM, "pc": WOOD, "pmat": Kit.TIMBER,
					"front": "door", "dx": -0.12, "form": "thatch_hip", "rise": 0.3, "over": 0.11, "brk": 0,
					"ex": [["tree", 0.4, 0.3], ["hay", -0.4, -0.2], ["pen", 0.35, -0.3]]}
				_: return {"w": 0.7, "d": 0.42, "st": 1, "h1": 0.28, "pl": 0.04, "wm": Kit.BRICK, "wc": BRICKR, "front": "windows",
					"form": "thatch", "rise": 0.3, "over": 0.1, "brk": 0, "an": 1, "aw": 0.18, "ah": 0.22, "chim": [-0.22, -0.1],
					"ex": [["wood", -0.34, 0.4], ["jar", 0.3, 0.38]]}
		"cn_south":
			match n:
				1: return {"w": 0.66, "d": 0.5, "st": 2, "h1": 0.3, "h2": 0.26, "form": "gable", "rise": 0.2, "over": 0.1, "overx": 0.0,
					"curl": 0.02, "g": 1.3, "rc": SLATE, "rm": Kit.TILE, "mtq": true, "front": "door", "win": "plain", "frame": "none",
					"trim": GREY_D, "nuw": 2, "pent": true, "brk": 1, "pc": GREY_D, "pmat": Kit.STONE}
				2: return {"w": 0.62, "d": 0.5, "st": 2, "form": "gable", "rise": 0.22, "over": 0.1, "overx": 0.0, "curl": 0.03,
					"mtq": true, "front": "door", "dx": -0.1, "win": "round", "frame": "none", "trim": GREY_D, "nuw": 2,
					"an": 1, "aw": 0.2, "ah": 0.2, "rm": Kit.OWNER_ROOF, "brk": 1, "pc": GREY_D, "pmat": Kit.STONE, "pent": true}
				3: return {"w": 0.72, "d": 0.46, "st": 1, "h1": 0.34, "form": "gable", "rise": 0.2, "over": 0.1, "overx": 0.0, "curl": 0.02,
					"rc": SLATE, "rm": Kit.TILE, "mtq": true, "front": "door", "dx": 0.14, "win": "plain", "frame": "none",
					"trim": GREY_D, "vd": 0.1, "ex": [["tree", -0.42, 0.4], ["jar", 0.4, 0.4]]}
				_: return {"w": 0.8, "d": 0.44, "st": 2, "h1": 0.28, "h2": 0.24, "form": "gable", "rise": 0.24, "over": 0.08,
					"overx": 0.0, "curl": 0.03, "rc": SLATE, "rm": Kit.TILE, "mtq": true, "front": "windows", "balcony": true,
					"pc": WOOD_L, "pmat": Kit.TIMBER, "frame": "posts", "uc": CREAM, "nuw": 4, "brk": 1}
		"jp_machiya":
			var dark := Color(0.36, 0.24, 0.15)
			match n:
				1: return {"w": 0.6, "d": 0.7, "st": 2, "h1": 0.3, "h2": 0.26, "wm": Kit.TIMBER, "wc": dark, "um": Kit.PLASTER,
					"uc": WHITE, "front": "slats", "dx": 0.14, "frame": "none", "form": "gable", "rise": 0.2, "g": 1.1, "over": 0.1,
					"curl": 0.0, "rc": ROOF_D, "udatsu": true, "win": "lattice", "nuw": 3, "pent": true, "brk": 0}
				2: return {"w": 0.7, "d": 0.6, "st": 1, "h1": 0.34, "wm": Kit.TIMBER, "wc": dark, "front": "slats", "dx": -0.2,
					"frame": "none", "form": "hip", "rise": 0.2, "over": 0.11, "curl": 0.0, "rc": SLATE, "rm": Kit.TILE, "brk": 0,
					"ex": [["lantern", 0.4, 0.4], ["barrel", -0.42, 0.38]]}
				3: return {"w": 0.66, "d": 0.6, "st": 2, "h1": 0.3, "h2": 0.26, "wm": Kit.TIMBER, "wc": dark.lightened(0.1),
					"um": Kit.PLASTER, "uc": CREAM, "front": "slats", "dx": 0.0, "frame": "grid", "form": "halfhip", "rise": 0.28,
					"over": 0.1, "curl": 0.0, "rc": ROOF_D, "win": "slit", "nuw": 3, "pent": true, "brk": 0, "trim": WOOD}
				_: return {"w": 0.5, "d": 0.78, "st": 2, "h1": 0.28, "h2": 0.24, "wm": Kit.TIMBER, "wc": dark, "um": Kit.PLASTER,
					"uc": WHITE, "front": "slats", "dx": -0.1, "frame": "none", "form": "gablez", "rise": 0.24, "over": 0.09,
					"curl": 0.0, "rc": ROOF_D, "chim": [0.0, -0.2], "win": "lattice", "nuw": 2, "pent": true, "brk": 0,
					"ex": [["stool", 0.34, 0.42], ["sign", -0.36, 0.42]]}
		"jp_minka":
			match n:
				1: return {"w": 0.72, "d": 0.58, "st": 1, "h1": 0.26, "pl": 0.05, "wc": CREAM, "frame": "grid", "trim": WOOD,
					"front": "windows", "form": "irimoya", "rise": 0.56, "over": 0.14, "brk": 0, "bc": GREY_D,
					"ex": [["wood", 0.38, 0.4], ["hay", -0.42, 0.34]]}
				2: return {"w": 0.58, "d": 0.6, "st": 1, "h1": 0.26, "pl": 0.05, "wm": Kit.EARTH, "wc": MUD, "frame": "grid",
					"front": "door", "dx": 0.1, "form": "thatchz", "rise": 0.44, "over": 0.13, "brk": 0, "an": 1, "aw": 0.2,
					"ah": 0.22, "athatch": true, "ex": [["pen", -0.4, 0.3], ["tree", 0.4, -0.3]]}
				3: return {"w": 0.5, "d": 0.5, "st": 1, "h1": 0.24, "pl": 0.05, "wm": Kit.TIMBER, "wc": Color(0.34, 0.24, 0.16),
					"frame": "grid", "trim": WOOD, "front": "veranda", "dx": 0.1, "form": "thatch_hip", "rise": 0.34, "over": 0.12, "brk": 0,
					"nsw": 2, "vd": 0.1, "an": -1, "aw": 0.16, "ah": 0.16, "athatch": true,
					"ex": [["barrel", 0.34, 0.36], ["bush", -0.4, 0.3], ["wood", 0.36, -0.3]]}
				_: return {"w": 0.46, "d": 0.66, "st": 1, "h1": 0.4, "pl": 0.05, "wm": Kit.TIMBER, "wc": Color(0.40, 0.28, 0.18),
					"frame": "grid", "trim": WOOD, "front": "windows", "form": "thatchz", "rise": 0.62, "over": 0.08, "brk": 0,
					"nsw": 3, "an": 1, "aw": 0.16, "ah": 0.16, "athatch": true,
					"ex": [["hay", -0.42, 0.1], ["wood", -0.36, 0.36], ["tree", 0.44, 0.34]]}
		"jp_kura":
			match n:
				1: return {"w": 0.5, "d": 0.6, "st": 2, "h1": 0.3, "h2": 0.26, "frame": "none", "front": "barn", "form": "gable",
					"rise": 0.22, "over": 0.12, "curl": 0.0, "rc": SLATE, "rm": Kit.TILE, "win": "slit", "nuw": 2, "pent": true,
					"brk": 0, "ex": [["crates", 0.4, 0.4]]}
				2: return {"w": 0.56, "d": 0.56, "st": 1, "h1": 0.4, "wc": NAMAKO, "namako": Color(0.92, 0.9, 0.85), "frame": "none",
					"front": "barn", "form": "hip", "rise": 0.24, "over": 0.12, "curl": 0.0, "rc": SLATE, "rm": Kit.TILE, "brk": 0,
					"gc": NAMAKO, "ex": [["barrel", 0.36, 0.38], ["pine", -0.4, 0.3]]}
				_: return {"w": 0.52, "d": 0.5, "st": 2, "h1": 0.28, "h2": 0.24, "wm": Kit.EARTH, "wc": MUD, "um": Kit.PLASTER,
					"uc": WHITE, "frame": "none", "front": "barn", "form": "gablez", "rise": 0.24, "over": 0.1, "curl": 0.0,
					"rc": ROOF_D, "win": "slit", "nuw": 1, "pent": true, "brk": 0, "an": 1, "aw": 0.2, "ah": 0.18,
					"ex": [["wood", -0.4, 0.36]]}
		"kr_choga":
			match n:
				1: return {"w": 0.56, "d": 0.42, "st": 1, "h1": 0.24, "pl": 0.03, "wm": Kit.EARTH, "wc": MUD, "frame": "none",
					"front": "door", "dx": 0.1, "form": "thatch_hip", "rise": 0.3, "over": 0.1, "brk": 0, "bc": GREY_D,
					"ex": [["jar", -0.36, 0.34], ["jar", -0.28, 0.4, 0.8], ["hay", 0.38, -0.2]]}
				2: return {"w": 0.52, "d": 0.4, "st": 1, "h1": 0.24, "pl": 0.03, "wm": Kit.EARTH, "wc": MUD.lightened(0.06),
					"frame": "none", "front": "door", "dx": -0.1, "form": "thatch", "rise": 0.28, "over": 0.1, "brk": 0, "an": 1,
					"aw": 0.24, "ah": 0.18, "athatch": true, "chim": [-0.2, -0.1], "ex": [["pen", 0.1, 0.4], ["wood", -0.4, 0.34]]}
				_: return {"w": 0.64, "d": 0.4, "st": 1, "h1": 0.26, "pl": 0.04, "wc": CREAM, "frame": "none", "front": "veranda",
					"vd": 0.1, "form": "thatch_hip", "rise": 0.34, "over": 0.1, "brk": 0, "pc": WOOD, "pmat": Kit.TIMBER,
					"ex": [["tree", 0.4, 0.35], ["jar", -0.4, 0.3]]}
	return {}


# --- compounds: courtyard houses, samurai residences, hanok ---------------------------------------


## A compound wall from a to b (x, z pairs) with a tiled cap.
static func _cwall(k: Kit, a: Vector2, b: Vector2, h: float, col: Color, mat: int, cap := SLATE) -> void:
	var mid := (a + b) / 2.0
	var l := a.distance_to(b)
	var yaw := atan2(-(b.y - a.y), b.x - a.x)
	k.box(Vector3(mid.x, 0, mid.y), Vector3(l, h, 0.045), col, mat, yaw)
	k.box(Vector3(mid.x, h, mid.y), Vector3(l + 0.02, 0.024, 0.08), cap, Kit.TILE, yaw)


## A room (a house from `_hb`) placed in a compound: at (x, z), turned `yaw` (0 faces +z).
static func _room(k: Kit, x: float, z: float, yaw: float, p: Dictionary) -> void:
	k.push(Kit.at(Vector3(x, 0, z), yaw))
	p["lite"] = true
	_hb(k, p)
	k.pop()


## A little roofed gate in a compound wall at (x, z): posts, door leaves, a small gable roof.
static func _gatehouse(k: Kit, x: float, z: float, w: float, h: float, col: Color, leaf: Color, rc: Color, yaw := 0.0) -> void:
	k.push(Kit.at(Vector3(x, 0, z), yaw))
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * w / 2.0, 0, 0), Vector3(0.06, h, 0.1), col, Kit.PAINT)
	k.box(Vector3(0, 0, 0), Vector3(w - 0.04, h * 0.88, 0.03), leaf, Kit.TIMBER)
	k.box(Vector3(0, h * 0.88, 0), Vector3(w + 0.04, 0.05, 0.09), col.darkened(0.2), Kit.PAINT)
	_gable(k, Vector3(0, h + 0.03, 0), w + 0.02, 0.14, 0.11, 0.07, 0.022, rc, Kit.OWNER_ROOF, 0.05, WHITE, Kit.PLASTER, 0.0, 1.4, true, 0.07, 2)
	k.pop()


static func _siheyuan(k: Kit, n: int) -> void:
	k.box(Vector3(0, 0, 0), Vector3(0.98, 0.02, 0.98), EARTHC, Kit.EARTH)
	match n:
		1:
			k.box(Vector3(0, 0.02, 0.1), Vector3(0.22, 0.012, 0.7), GREY, Kit.STONE)
			_room(k, 0, -0.28, 0.0, {"w": 0.66, "d": 0.3, "h1": 0.3, "front": "windows", "form": "halfhip", "rise": 0.22, "over": 0.09,
				"curl": 0.08, "brk": 1, "nsw": 0})
			_room(k, -0.37, 0.05, PI / 2.0, {"w": 0.42, "d": 0.17, "h1": 0.26, "front": "windows", "form": "gable", "rise": 0.16,
				"over": 0.07, "curl": 0.06, "brk": 0, "rc": ROOF_D})
			_room(k, 0.37, 0.05, -PI / 2.0, {"w": 0.42, "d": 0.17, "h1": 0.26, "front": "windows", "form": "gable", "rise": 0.16,
				"over": 0.07, "curl": 0.06, "brk": 0, "rc": ROOF_D})
			_cwall(k, Vector2(-0.48, 0.46), Vector2(-0.14, 0.46), 0.17, WHITE, Kit.PLASTER)
			_cwall(k, Vector2(0.14, 0.46), Vector2(0.48, 0.46), 0.17, WHITE, Kit.PLASTER)
			_gatehouse(k, 0, 0.46, 0.26, 0.26, RED, RED_D, ROOF)
			_bit(k, "tree", -0.16, 0.2, 1.1)
		2:
			k.box(Vector3(0, 0.02, 0.1), Vector3(0.7, 0.012, 0.18), GREY, Kit.STONE)
			_room(k, -0.1, -0.26, 0.0, {"w": 0.7, "d": 0.34, "st": 2, "h1": 0.26, "h2": 0.22, "wm": Kit.BRICK, "wc": BRICKG,
				"um": Kit.PLASTER, "uc": WHITE, "front": "windows", "form": "hip", "rise": 0.22, "over": 0.09, "curl": 0.07,
				"rc": ROOF_D, "nuw": 3, "pent": true, "brk": 1, "nsw": 0})
			_room(k, 0.37, 0.12, -PI / 2.0, {"w": 0.5, "d": 0.18, "h1": 0.24, "wm": Kit.BRICK, "wc": BRICKG, "front": "windows",
				"form": "gable", "rise": 0.15, "over": 0.07, "curl": 0.05, "rc": ROOF_D, "brk": 0})
			_cwall(k, Vector2(-0.48, 0.46), Vector2(0.48, 0.46), 0.18, BRICKG, Kit.BRICK)
			_cwall(k, Vector2(-0.48, 0.46), Vector2(-0.48, -0.1), 0.18, BRICKG, Kit.BRICK)
			# a moon gate in the front wall
			k.push(Kit.at(Vector3(-0.2, 0.0, 0.485)))
			var ring: Array = []
			var hole: Array = []
			for i in 10:
				var a := i * TAU / 10.0
				ring.append(Vector3(cos(a) * 0.1, 0.1 + sin(a) * 0.1, 0.0))
				hole.append(Vector3(cos(a) * 0.075, 0.1 + sin(a) * 0.075, 0.01))
			k.polygon(ring, RED, Kit.PAINT, Vector3(0, 0.1, -1))
			k.polygon(hole, Color(0.25, 0.34, 0.18), Kit.LEAF, Vector3(0, 0.1, -1))
			k.pop()
			_bit(k, "well", 0.18, 0.2)
			_bit(k, "bush", -0.3, 0.2, 1.2)
		_:
			_room(k, 0, -0.3, 0.0, {"w": 0.62, "d": 0.28, "st": 2, "h1": 0.26, "h2": 0.22, "front": "windows", "form": "halfhip",
				"rise": 0.26, "over": 0.09, "curl": 0.08, "brk": 1, "balcony": false, "nuw": 3, "nsw": 0})
			_room(k, -0.37, 0.08, PI / 2.0, {"w": 0.5, "d": 0.18, "h1": 0.26, "front": "windows", "form": "gable",
				"rise": 0.16, "over": 0.07, "curl": 0.06, "brk": 0, "rc": ROOF_D})
			_room(k, 0.37, 0.08, -PI / 2.0, {"w": 0.5, "d": 0.18, "h1": 0.26, "front": "windows", "form": "gable",
				"rise": 0.16, "over": 0.07, "curl": 0.06, "brk": 0, "rc": ROOF_D})
			_cwall(k, Vector2(-0.48, 0.46), Vector2(0.14, 0.46), 0.17, WHITE, Kit.PLASTER)
			_cwall(k, Vector2(0.34, 0.46), Vector2(0.48, 0.46), 0.17, WHITE, Kit.PLASTER)
			_gatehouse(k, 0.24, 0.46, 0.2, 0.24, RED, RED_D, ROOF)
			# screen wall (yingbi) behind the gate
			k.box(Vector3(-0.3, 0, 0.28), Vector3(0.2, 0.2, 0.04), RED_D, Kit.PAINT)
			k.box(Vector3(-0.3, 0.2, 0.28), Vector3(0.24, 0.025, 0.07), SLATE, Kit.TILE)
			_bit(k, "tree", 0.0, 0.1, 1.2)
			_bit(k, "jar", 0.2, 0.0)


static func _samurai(k: Kit, n: int) -> void:
	var wallc := Color(0.80, 0.74, 0.60)
	k.box(Vector3(0, 0, 0), Vector3(0.98, 0.02, 0.98), Color(0.62, 0.55, 0.42), Kit.EARTH)
	match n:
		1:
			_room(k, 0.0, -0.14, 0.0, {"w": 0.6, "d": 0.4, "h1": 0.3, "frame": "grid",
				"front": "veranda", "vd": 0.1, "form": "halfhip", "rise": 0.3, "over": 0.12, "curl": 0.0, "rc": SLATE, "rm": Kit.TILE,
				"brk": 0, "wc": WHITE, "g": 1.1})
			_cwall(k, Vector2(-0.48, 0.46), Vector2(-0.12, 0.46), 0.17, wallc, Kit.EARTH)
			_cwall(k, Vector2(0.3, 0.46), Vector2(0.48, 0.46), 0.17, wallc, Kit.EARTH)
			# nagayamon: a gatehouse built into the wall
			k.box(Vector3(0.09, 0, 0.46), Vector3(0.42, 0.2, 0.12), Color(0.9, 0.88, 0.8), Kit.PLASTER)
			k.box(Vector3(0.09, 0, 0.465), Vector3(0.16, 0.16, 0.125), DARKC, Kit.DARK)
			_gable(k, Vector3(0.09, 0.2, 0.46), 0.42, 0.12, 0.13, 0.07, 0.022, SLATE, Kit.TILE, 0.0, WHITE, Kit.PLASTER, 0.0, 1.2, false)
			for s in [-1.0, 1.0]:
				_cwall(k, Vector2(s * 0.48, 0.46), Vector2(s * 0.48, -0.46), 0.17, wallc, Kit.EARTH)
			_bit(k, "pine", -0.34, 0.22, 1.4)
			_bit(k, "bush", 0.3, 0.2)
		2:
			_room(k, -0.08, -0.12, 0.0, {"w": 0.56, "d": 0.38, "st": 1, "h1": 0.3, "wm": Kit.PLASTER, "wc": WHITE, "frame": "grid",
				"front": "windows", "form": "hip", "rise": 0.24, "over": 0.13, "curl": 0.0, "rc": ROOF_D, "brk": 0, "an": 1, "aw": 0.24,
				"ah": 0.22, "ad": 0.3, "az": 0.0, "nsw": 0})
			_cwall(k, Vector2(-0.48, 0.46), Vector2(-0.1, 0.46), 0.17, wallc, Kit.EARTH)
			_cwall(k, Vector2(0.1, 0.46), Vector2(0.48, 0.46), 0.17, wallc, Kit.EARTH)
			# a roofed gate (yakuimon) on two posts
			for s in [-1.0, 1.0]:
				k.box(Vector3(s * 0.1, 0, 0.46), Vector3(0.05, 0.28, 0.05), WOOD, Kit.TIMBER)
			k.box(Vector3(0, 0.2, 0.46), Vector3(0.2, 0.04, 0.05), WOOD, Kit.TIMBER)
			_gable(k, Vector3(0, 0.26, 0.46), 0.2, 0.1, 0.1, 0.07, 0.02, SLATE, Kit.TILE, 0.0, WHITE, Kit.PLASTER, 0.0, 1.2, false, 0.08, 2)
			_cwall(k, Vector2(-0.48, 0.46), Vector2(-0.48, 0.0), 0.17, wallc, Kit.EARTH)
			k.box(Vector3(0.0, 0.02, 0.2), Vector3(0.16, 0.01, 0.5), GREY, Kit.STONE)
			_bit(k, "pine", 0.36, 0.2, 1.3)
			_bit(k, "stool", -0.3, 0.2)
		_:
			_room(k, 0.0, -0.18, 0.0, {"w": 0.5, "d": 0.5, "st": 2, "h1": 0.26, "h2": 0.22, "wm": Kit.PLASTER, "wc": WHITE, "frame": "grid",
				"front": "windows", "form": "halfhip", "rise": 0.28, "over": 0.12, "curl": 0.0, "rc": SLATE, "rm": Kit.TILE, "brk": 0,
				"nuw": 3, "pent": true, "win": "plain", "g": 1.1, "nsw": 0})
			for s in [-1.0, 1.0]:
				_cwall(k, Vector2(s * 0.48, 0.46), Vector2(s * 0.48, -0.46), 0.17, wallc, Kit.EARTH)
			_cwall(k, Vector2(-0.48, 0.46), Vector2(-0.06, 0.46), 0.17, wallc, Kit.EARTH)
			_cwall(k, Vector2(0.14, 0.46), Vector2(0.48, 0.46), 0.17, wallc, Kit.EARTH)
			for s in [-1.0, 1.0]:   # a plain gate
				k.box(Vector3(0.04 + s * 0.1, 0, 0.46), Vector3(0.04, 0.24, 0.05), WOOD, Kit.TIMBER)
			k.box(Vector3(0.04, 0.22, 0.46), Vector3(0.24, 0.035, 0.06), WOOD, Kit.TIMBER)
			# a clipped hedge and a small storehouse in the corner
			k.box(Vector3(-0.3, 0.0, 0.32), Vector3(0.3, 0.09, 0.07), Color(0.28, 0.46, 0.2), Kit.LEAF)
			_room(k, 0.34, 0.24, 0.0, {"w": 0.24, "d": 0.24, "st": 1, "h1": 0.26, "wc": NAMAKO, "namako": Color(0.92, 0.9, 0.85),
				"frame": "none", "front": "barn", "form": "hip", "rise": 0.14, "over": 0.06, "curl": 0.0, "rc": SLATE, "rm": Kit.TILE, "brk": 0})
			_bit(k, "pine", -0.34, -0.2, 1.3)


static func _hanok(k: Kit, n: int) -> void:
	var hanok := {"pl": 0.1, "bc": GREY, "wc": WHITE, "pc": WOOD, "pmat": Kit.TIMBER, "front": "veranda", "vd": 0.14, "form": "gable",
		"rise": 0.26, "over": 0.14, "curl": 0.1, "g": 1.7, "rc": ROOF_D, "brk": 1, "frame": "none", "win": "lattice", "gc": WHITE}
	var jars := [["jar", -0.4, 0.42], ["jar", -0.31, 0.46, 0.85], ["jar", -0.46, 0.34, 0.75]]
	match n:
		1:
			var p := hanok.duplicate()
			p.merge({"w": 0.78, "d": 0.34, "h1": 0.3, "form": "halfhip", "rise": 0.3, "chim": [-0.34, -0.26], "ex": jars, "nsw": 0})
			p["ex"] = jars + [["tree", 0.4, 0.42]]
			_hb(k, p)
		2:
			var main := hanok.duplicate()
			main.merge({"w": 0.6, "d": 0.28, "h1": 0.28, "chim": [-0.28, -0.2], "rc": SLATE, "rm": Kit.TILE})
			_room(k, -0.12, -0.24, 0.0, main)
			var wing := {"pl": 0.1, "w": 0.4, "d": 0.24, "h1": 0.28, "wc": WHITE, "front": "door", "dx": 0.08, "form": "gable", "rise": 0.2, "over": 0.12,
				"curl": 0.1, "g": 1.7, "rc": SLATE, "rm": Kit.TILE, "brk": 0, "frame": "none", "win": "lattice"}
			_room(k, 0.3, 0.08, -PI / 2.0, wing)
			for jp in [Vector3(-0.38, 0, 0.1), Vector3(-0.28, 0, 0.18)]:
				_bit(k, "jar", jp.x, jp.z, 0.9)
		3:
			var main3 := hanok.duplicate()
			main3.merge({"w": 0.66, "d": 0.26, "h1": 0.28, "vd": 0.12, "form": "halfhip", "rise": 0.26})
			_room(k, 0.0, -0.3, 0.0, main3)
			for s in [-1.0, 1.0]:
				var wp := hanok.duplicate()
				wp.merge({"w": 0.46, "d": 0.2, "h1": 0.26, "vd": 0.06, "form": "gable", "rise": 0.18, "over": 0.1, "chim": [] if s > 0.0 else [0.2, -0.1]})
				_room(k, s * 0.38, 0.06, PI / 2.0 if s < 0.0 else -PI / 2.0, wp)
			# a low brushwood fence with a gate at the front
			k.box(Vector3(-0.26, 0, 0.46), Vector3(0.4, 0.09, 0.025), WOOD_L, Kit.TIMBER)
			k.box(Vector3(0.27, 0, 0.46), Vector3(0.38, 0.09, 0.025), WOOD_L, Kit.TIMBER)
			for s in [-1.0, 1.0]:
				k.box(Vector3(s * 0.07, 0, 0.46), Vector3(0.03, 0.17, 0.03), WOOD, Kit.TIMBER)
			_bit(k, "jar", -0.1, 0.1, 0.9)
			_bit(k, "tree", 0.0, 0.25, 0.9)
		_:
			var main4 := hanok.duplicate()
			main4.merge({"w": 0.74, "d": 0.28, "h1": 0.28, "vd": 0.1, "form": "halfhip", "rise": 0.3, "chim": [0.32, -0.22], "rc": SLATE, "rm": Kit.TILE})
			_room(k, -0.1, -0.22, 0.0, main4)
			# a raised pavilion (nujeong) on stilts
			k.push(Kit.at(Vector3(0.36, 0.0, 0.3)))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					k.box(Vector3(sx * 0.15, 0, sz * 0.15), Vector3(0.04, 0.2, 0.04), WOOD, Kit.TIMBER)
			k.box(Vector3(0, 0.2, 0), Vector3(0.38, 0.03, 0.38), WOOD_L, Kit.TIMBER)
			_roof(k, Vector3(0, 0.36, 0), 0.3, 0.3, 0.2, 0.09, 0.024, 0.09, ROOF_D, Kit.OWNER_ROOF, -1.0, 0.0, 3, 0.0, false, 1.0, true, 0, false)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					k.box(Vector3(sx * 0.15, 0.23, sz * 0.15), Vector3(0.035, 0.13, 0.035), RED, Kit.PAINT)
			k.pop()
			_bit(k, "jar", -0.36, 0.2, 0.9)
			_bit(k, "tree", -0.3, 0.38, 1.0)


# --- two-lot buildings (each about 2.0 wide by 1.0 deep) -----------------------------------------


## One house of a row, `x` along the row; `over` is kept small so neighbours touch.
static func _unit(k: Kit, x: float, p: Dictionary) -> void:
	k.push(Kit.at(Vector3(x, 0, 0)))
	p["lite"] = true
	if not p.has("over"):
		p["over"] = 0.05
	_hb(k, p)
	k.pop()


static func _big(k: Kit, kind: String) -> void:
	match kind:
		"big_cn_shoprow_1":
			_unit(k, -0.67, {"w": 0.6, "d": 0.62, "st": 2, "front": "shop", "uc": CREAM, "form": "gable", "rise": 0.24, "curl": 0.06, "sign": true, "nuw": 2, "brk": 1})
			_unit(k, 0.0, {"w": 0.68, "d": 0.56, "st": 1, "h1": 0.36, "front": "shop", "wc": OCHRE, "form": "gable", "rise": 0.18, "curl": 0.05, "rc": ROOF_D, "brk": 1})
			_unit(k, 0.67, {"w": 0.6, "d": 0.62, "st": 2, "h1": 0.3, "h2": 0.3, "wm": Kit.BRICK, "wc": BRICKG, "um": Kit.PLASTER, "uc": WHITE, "front": "shop",
				"form": "halfhip", "rise": 0.3, "curl": 0.07, "lanterns": true, "nuw": 2, "brk": 1, "ex": [["barrel", 0.3, 0.46]]})
		"big_cn_shoprow_2":
			_unit(k, -0.5, {"w": 0.92, "d": 0.6, "st": 2, "wm": Kit.BRICK, "wc": BRICKG, "um": Kit.PLASTER, "uc": PINKW, "front": "shop", "ox": -0.1,
				"form": "halfhip", "rise": 0.32, "curl": 0.08, "balcony": true, "brk": 2, "lanterns": true, "nuw": 3, "ex": [["tree", -0.42, 0.4]]})
			_unit(k, 0.5, {"w": 0.92, "d": 0.5, "st": 1, "h1": 0.34, "vd": 0.14, "front": "veranda", "wc": CREAM, "form": "gable", "rise": 0.22, "curl": 0.06,
				"rc": ROOF_D, "brk": 1, "an": 0, "chim": [0.3, -0.1]})
		"big_cn_shoprow_3":
			_unit(k, -0.67, {"w": 0.56, "d": 0.8, "st": 2, "front": "shop", "wc": WHITE, "form": "gablez", "rise": 0.26, "curl": 0.05, "sign": true, "nuw": 2, "brk": 1})
			_unit(k, 0.0, {"w": 0.56, "d": 0.76, "st": 1, "h1": 0.4, "front": "shop", "wm": Kit.BRICK, "wc": BRICKG, "form": "gablez", "rise": 0.22, "curl": 0.05, "rc": SLATE, "rm": Kit.TILE, "brk": 1})
			_unit(k, 0.67, {"w": 0.56, "d": 0.8, "st": 2, "h1": 0.3, "h2": 0.3, "front": "shop", "wc": OCHRE, "uc": WHITE, "form": "gablez", "rise": 0.3, "curl": 0.06, "lanterns": true, "nuw": 2, "brk": 1})
		"big_cn_south_row":
			_unit(k, -0.5, {"w": 0.88, "d": 0.5, "st": 2, "h1": 0.3, "h2": 0.28, "form": "gable", "rise": 0.2, "over": 0.08, "overx": 0.0, "curl": 0.02, "g": 1.3,
				"rc": SLATE, "rm": Kit.TILE, "mtq": true, "front": "door", "dx": -0.2, "win": "plain", "frame": "none", "trim": GREY_D, "nuw": 3, "pent": true, "brk": 1,
				"pc": GREY_D, "pmat": Kit.STONE})
			_unit(k, 0.5, {"w": 0.88, "d": 0.5, "st": 1, "h1": 0.4, "form": "gable", "rise": 0.2, "over": 0.08, "overx": 0.0, "curl": 0.02, "g": 1.3, "rc": SLATE, "rm": Kit.TILE,
				"mtq": true, "front": "door", "dx": 0.2, "win": "round", "frame": "none", "trim": GREY_D, "brk": 1, "pc": GREY_D, "pmat": Kit.STONE,
				"ex": [["tree", 0.0, 0.42], ["jar", -0.44, 0.4]]})
		"big_cn_courtyard_1", "big_cn_courtyard_2":
			_cn_courtyard(k, kind.ends_with("2"))
		"big_cn_farmstead":
			_unit(k, -0.5, {"w": 0.66, "d": 0.46, "st": 1, "h1": 0.28, "pl": 0.04, "wm": Kit.EARTH, "wc": MUD, "pc": WOOD, "pmat": Kit.TIMBER, "front": "door", "dx": 0.1,
				"form": "thatch", "rise": 0.34, "over": 0.1, "brk": 0, "an": 1, "aw": 0.2, "ah": 0.18, "athatch": true, "chim": [-0.2, -0.1]})
			_unit(k, 0.55, {"w": 0.68, "d": 0.46, "st": 1, "h1": 0.34, "pl": 0.04, "wm": Kit.TIMBER, "wc": Color(0.45, 0.34, 0.22), "frame": "none", "front": "barn", "dx": 0.0,
				"form": "gable", "rise": 0.26, "over": 0.1, "curl": 0.0, "rc": SLATE, "rm": Kit.TILE, "brk": 0, "gc": WOOD_L, "gm": Kit.TIMBER})
			_bit(k, "hay", 0.05, 0.38, 1.0)
			_bit(k, "pen", -0.1, -0.34, 1.2)
			_bit(k, "wood", -0.82, 0.38)
			_bit(k, "tree", 0.88, 0.36, 1.0)
			_bit(k, "barrel", 0.28, 0.4)
		"big_jp_row_1":
			var dark := Color(0.36, 0.24, 0.15)
			_unit(k, -0.67, {"w": 0.6, "d": 0.7, "st": 2, "h1": 0.3, "h2": 0.26, "wm": Kit.TIMBER, "wc": dark, "um": Kit.PLASTER, "uc": WHITE, "front": "slats", "dx": 0.14,
				"frame": "none", "form": "gable", "rise": 0.2, "g": 1.1, "curl": 0.0, "rc": ROOF_D, "udatsu": true, "nuw": 3, "brk": 0})
			_unit(k, 0.0, {"w": 0.68, "d": 0.66, "st": 1, "h1": 0.34, "wm": Kit.TIMBER, "wc": dark.lightened(0.08), "front": "slats", "dx": -0.18, "frame": "none", "form": "hip", "rise": 0.18,
				"curl": 0.0, "rc": SLATE, "rm": Kit.TILE, "brk": 0, "ex": [["lantern", 0.3, 0.4]]})
			_unit(k, 0.67, {"w": 0.6, "d": 0.7, "st": 2, "h1": 0.3, "h2": 0.28, "wm": Kit.TIMBER, "wc": dark, "um": Kit.PLASTER, "uc": CREAM, "front": "slats", "dx": 0.0, "frame": "none",
				"form": "halfhip", "rise": 0.28, "curl": 0.0, "rc": ROOF_D, "win": "slit", "nuw": 3, "brk": 0})
		"big_jp_row_2":
			var dark2 := Color(0.34, 0.23, 0.15)
			_unit(k, -0.5, {"w": 0.9, "d": 0.64, "st": 2, "h1": 0.3, "h2": 0.26, "wm": Kit.TIMBER, "wc": dark2, "um": Kit.PLASTER, "uc": WHITE, "front": "slats", "dx": 0.2,
				"frame": "none", "form": "gable", "rise": 0.24, "g": 1.1, "curl": 0.0, "rc": ROOF_D, "nuw": 4, "brk": 0, "win": "lattice", "ex": [["sign", -0.44, 0.44]]})
			_unit(k, 0.55, {"w": 0.74, "d": 0.6, "st": 2, "h1": 0.36, "h2": 0.3, "wc": NAMAKO, "namako": Color(0.92, 0.9, 0.85), "frame": "none", "front": "barn", "um": Kit.PLASTER, "uc": WHITE,
				"form": "gable", "rise": 0.24, "over": 0.1, "curl": 0.0, "rc": SLATE, "rm": Kit.TILE, "win": "slit", "nuw": 2, "pent": true, "brk": 0,
				"ex": [["pine", 0.4, 0.44]]})
		"big_jp_samurai":
			_jp_samurai_big(k)
		"big_jp_farmstead":
			_unit(k, -0.5, {"w": 0.8, "d": 0.6, "st": 1, "h1": 0.26, "pl": 0.05, "wc": CREAM, "frame": "grid", "trim": WOOD, "front": "windows", "form": "irimoya", "rise": 0.58, "over": 0.14, "brk": 0,
				"ex": [["wood", -0.45, 0.46], ["bush", 0.4, 0.46]]})
			_unit(k, 0.5, {"w": 0.46, "d": 0.5, "st": 1, "h1": 0.34, "wc": NAMAKO, "namako": Color(0.92, 0.9, 0.85), "frame": "none", "front": "barn", "form": "hip", "rise": 0.22, "over": 0.1,
				"curl": 0.0, "rc": SLATE, "rm": Kit.TILE, "brk": 0})
			_unit(k, 0.9, {"w": 0.2, "d": 0.36, "st": 1, "h1": 0.18, "pl": 0.03, "wm": Kit.TIMBER, "wc": BARK, "frame": "none", "front": "barn", "form": "thatchz", "rise": 0.16, "over": 0.06, "brk": 0})
			_bit(k, "tree", 0.1, 0.4, 1.2)
			_bit(k, "hay", 0.6, -0.4, 0.9)
		"big_kr_hanok":
			_kr_compound(k)
		"big_kr_farmstead":
			_unit(k, -0.5, {"w": 0.6, "d": 0.44, "st": 1, "h1": 0.24, "pl": 0.03, "wm": Kit.EARTH, "wc": MUD, "frame": "none", "front": "veranda", "vd": 0.08, "dx": 0.0, "form": "thatch_hip",
				"rise": 0.32, "over": 0.1, "brk": 0, "pc": WOOD, "pmat": Kit.TIMBER, "chim": [-0.25, -0.15]})
			_unit(k, 0.5, {"w": 0.72, "d": 0.46, "st": 1, "h1": 0.26, "pl": 0.03, "wm": Kit.EARTH, "wc": MUD.darkened(0.1), "frame": "none", "front": "barn", "form": "thatch", "rise": 0.3,
				"over": 0.1, "brk": 0})
			_bit(k, "jar", -0.1, 0.4, 0.9)
			_bit(k, "jar", -0.02, 0.44, 0.75)
			_bit(k, "hay", 0.0, -0.3, 1.1)
			_bit(k, "pen", 0.9, 0.36, 1.1)


static func _cn_courtyard(k: Kit, tall: bool) -> void:
	k.box(Vector3(0, 0, 0), Vector3(1.98, 0.02, 0.98), EARTHC, Kit.EARTH)
	var hall := {"w": 0.86, "d": 0.3, "h1": 0.3, "front": "windows", "form": "halfhip", "rise": 0.24, "over": 0.09, "curl": 0.08, "brk": 1, "nsw": 0}
	var wing := {"w": 0.4, "d": 0.16, "h1": 0.24, "front": "windows", "form": "gable", "rise": 0.15, "over": 0.06, "curl": 0.05, "rc": ROOF_D, "brk": 0}
	if tall:
		# a long two-storey rear range, two small wings and a gate house on the street
		_room(k, 0.0, -0.3, 0.0, {"w": 1.7, "d": 0.3, "st": 2, "h1": 0.26, "h2": 0.22, "front": "windows", "form": "halfhip", "rise": 0.28, "over": 0.09, "curl": 0.08,
			"brk": 1, "nuw": 7, "nsw": 0, "balcony": false, "pent": true})
		for s in [-1.0, 1.0]:
			_room(k, s * 0.88, 0.1, -s * PI / 2.0, wing.duplicate())
		_cwall(k, Vector2(-0.98, 0.46), Vector2(-0.12, 0.46), 0.17, WHITE, Kit.PLASTER)
		_cwall(k, Vector2(0.12, 0.46), Vector2(0.98, 0.46), 0.17, WHITE, Kit.PLASTER)
		_gatehouse(k, 0, 0.46, 0.24, 0.26, RED, RED_D, ROOF)
		_bit(k, "tree", -0.4, 0.15, 1.3)
		_bit(k, "tree", 0.45, 0.2, 1.1)
		_bit(k, "well", 0.0, 0.0)
		return
	# two linked yards: a main court and a side court with a moon gate between
	var h1d := hall.duplicate()
	h1d["w"] = 0.84
	_room(k, -0.5, -0.3, 0.0, h1d)
	var h2d := hall.duplicate()
	h2d.merge({"st": 2, "h2": 0.22, "w": 0.7, "uc": CREAM, "nuw": 3, "wm": Kit.BRICK, "wc": BRICKG, "um": Kit.PLASTER, "rc": ROOF_D})
	_room(k, 0.52, -0.3, 0.0, h2d)
	_room(k, -0.9, 0.08, PI / 2.0, wing.duplicate())
	_room(k, -0.1, 0.08, -PI / 2.0, wing.duplicate())
	_cwall(k, Vector2(-0.98, 0.46), Vector2(-0.64, 0.46), 0.17, WHITE, Kit.PLASTER)
	_cwall(k, Vector2(-0.36, 0.46), Vector2(0.98, 0.46), 0.17, WHITE, Kit.PLASTER)
	_gatehouse(k, -0.5, 0.46, 0.26, 0.26, RED, RED_D, ROOF)
	_cwall(k, Vector2(0.14, 0.46), Vector2(0.14, -0.1), 0.17, WHITE, Kit.PLASTER)
	_cwall(k, Vector2(0.14, 0.15), Vector2(0.98, 0.15), 0.12, BRICKG, Kit.BRICK)
	_bit(k, "tree", -0.5, 0.12, 1.2)
	_bit(k, "bush", 0.6, 0.3, 1.2)
	_bit(k, "jar", 0.8, 0.3)


static func _jp_samurai_big(k: Kit) -> void:
	var wallc := Color(0.80, 0.74, 0.60)
	k.box(Vector3(0, 0, 0), Vector3(1.98, 0.02, 0.98), Color(0.62, 0.55, 0.42), Kit.EARTH)
	_room(k, -0.4, -0.14, 0.0, {"w": 0.8, "d": 0.44, "h1": 0.3, "wc": WHITE, "frame": "grid", "front": "veranda", "vd": 0.1, "form": "halfhip", "rise": 0.32, "over": 0.13, "curl": 0.0,
		"rc": SLATE, "rm": Kit.TILE, "brk": 0, "g": 1.1})
	_room(k, 0.62, -0.2, 0.0, {"w": 0.4, "d": 0.4, "st": 2, "h1": 0.26, "h2": 0.22, "wc": NAMAKO, "namako": Color(0.92, 0.9, 0.85), "um": Kit.PLASTER, "uc": WHITE, "frame": "none", "front": "barn",
		"form": "gable", "rise": 0.2, "over": 0.08, "curl": 0.0, "rc": SLATE, "rm": Kit.TILE, "win": "slit", "nuw": 1, "pent": true, "brk": 0})
	_cwall(k, Vector2(-0.98, 0.46), Vector2(-0.3, 0.46), 0.17, wallc, Kit.EARTH)
	_cwall(k, Vector2(0.4, 0.46), Vector2(0.98, 0.46), 0.17, wallc, Kit.EARTH)
	k.box(Vector3(0.05, 0, 0.46), Vector3(0.7, 0.2, 0.12), Color(0.9, 0.88, 0.8), Kit.PLASTER)
	k.box(Vector3(0.05, 0, 0.465), Vector3(0.18, 0.17, 0.125), DARKC, Kit.DARK)
	_gable(k, Vector3(0.05, 0.2, 0.46), 0.7, 0.12, 0.13, 0.07, 0.022, SLATE, Kit.TILE, 0.0, WHITE, Kit.PLASTER, 0.0, 1.2, false)
	for s in [-1.0, 1.0]:
		_cwall(k, Vector2(s * 0.98, 0.46), Vector2(s * 0.98, -0.46), 0.17, wallc, Kit.EARTH)
	k.box(Vector3(0.0, 0.02, 0.1), Vector3(0.16, 0.01, 0.5), GREY, Kit.STONE)
	_bit(k, "pine", -0.85, 0.25, 1.4)
	_bit(k, "pine", 0.3, 0.2, 1.2)
	_bit(k, "bush", 0.8, 0.2)


static func _kr_compound(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(1.98, 0.02, 0.98), EARTHC, Kit.EARTH)
	var hk := {"pl": 0.1, "bc": GREY, "wc": WHITE, "pc": WOOD, "pmat": Kit.TIMBER, "front": "veranda", "vd": 0.12, "form": "gable", "rise": 0.24, "over": 0.14,
		"curl": 0.1, "g": 1.7, "rc": ROOF_D, "brk": 1, "frame": "none"}
	var main := hk.duplicate()
	main.merge({"w": 1.0, "d": 0.28, "h1": 0.28, "form": "halfhip", "rise": 0.28, "chim": [-0.44, -0.2]})
	_room(k, 0.0, -0.3, 0.0, main)
	for s in [-1.0, 1.0]:
		var w := hk.duplicate()
		w.merge({"w": 0.52, "d": 0.22, "h1": 0.26, "vd": 0.08, "rise": 0.18, "over": 0.1})
		_room(k, s * 0.76, 0.06, -s * PI / 2.0, w)
	# the outer building (sarangchae) across the front with a gate bay
	var front := hk.duplicate()
	front.merge({"w": 0.5, "d": 0.2, "h1": 0.26, "vd": 0.0, "front": "door", "rise": 0.16, "over": 0.1, "dx": 0.0})
	_room(k, -0.5, 0.4, PI, front)
	_room(k, 0.5, 0.4, PI, front.duplicate())
	k.box(Vector3(0, 0, 0.46), Vector3(0.3, 0.2, 0.04), WOOD, Kit.TIMBER)
	_bit(k, "jar", -0.5, 0.0, 1.0)
	_bit(k, "jar", -0.42, 0.06, 0.8)
	_bit(k, "tree", 0.1, 0.1, 1.1)


# --- regional props ---------------------------------------------------------------------------------


static func _prop(k: Kit, kind: String) -> void:
	match kind:
		"prop_stone_lantern":   # a toro: base, pillar, fire box, hat
			var st := Color(0.62, 0.62, 0.58)
			k.frustum(Vector3.ZERO, 0.075, 0.06, 0.04, st, Kit.STONE, 6)
			k.frustum(Vector3(0, 0.04, 0), 0.028, 0.026, 0.14, st, Kit.STONE, 6, false)
			k.frustum(Vector3(0, 0.18, 0), 0.07, 0.075, 0.025, st, Kit.STONE, 6)
			k.box(Vector3(0, 0.205, 0), Vector3(0.09, 0.08, 0.09), st, Kit.STONE)
			for a in [0.0, PI / 2.0, PI, -PI / 2.0]:
				k.push(Kit.at(Vector3(0, 0.245, 0), a))
				_strip_z(k, -0.02, 0.02, -0.025, 0.025, 0.0455, DARKC, Kit.DARK)
				k.pop()
			k.frustum(Vector3(0, 0.285, 0), 0.115, 0.03, 0.06, st.darkened(0.08), Kit.STONE, 4)
			k.frustum(Vector3(0, 0.345, 0), 0.02, 0.0, 0.04, st, Kit.STONE, 6)
		"prop_shrine":   # a wayside shrine: stone step, small timber hall, gable roof, offerings
			k.box(Vector3(0, 0, 0), Vector3(0.3, 0.04, 0.26), GREY, Kit.STONE)
			k.box(Vector3(0, 0.04, 0.0), Vector3(0.18, 0.12, 0.14), RED, Kit.PAINT)
			k.box(Vector3(0, 0.04, 0.0), Vector3(0.2, 0.012, 0.16), WOOD, Kit.TIMBER)
			_strip_z(k, -0.04, 0.04, 0.05, 0.13, 0.072, DARKC, Kit.DARK)
			k.gable_roof(Vector3(0, 0.16, 0), 0.2, 0.16, 0.1, 0.05, 0.02, ROOF_D, Kit.OWNER_ROOF, WOOD, Kit.TIMBER, 0.0, 0.01)
			k.box(Vector3(0, 0.04, 0.13), Vector3(0.1, 0.03, 0.06), GREY, Kit.STONE)
			k.box(Vector3(-0.1, 0.04, 0.13), Vector3(0.025, 0.05, 0.025), GREY, Kit.STONE)
			k.box(Vector3(0.1, 0.04, 0.13), Vector3(0.03, 0.04, 0.03), Color(0.9, 0.85, 0.7), Kit.CLOTH)
			k.box(Vector3(0, 0.15, 0.078), Vector3(0.16, 0.012, 0.01), Color.WHITE, Kit.CLOTH)
		"prop_torii":   # a Japanese gate: two posts, tie beam, lintel with upturned ends
			for s in [-1.0, 1.0]:
				k.frustum(Vector3(s * 0.22, 0, 0), 0.032, 0.026, 0.46, RED, Kit.PAINT, 6, false)
				k.box(Vector3(s * 0.22, 0, 0), Vector3(0.09, 0.03, 0.09), Color(0.2, 0.2, 0.22), Kit.STONE)
			k.box(Vector3(0, 0.34, 0), Vector3(0.5, 0.035, 0.035), RED, Kit.PAINT)
			k.box(Vector3(0, 0.455, 0), Vector3(0.44, 0.04, 0.04), RED_D, Kit.PAINT)
			k.box(Vector3(0, 0.48, 0), Vector3(0.62, 0.035, 0.06), Color(0.14, 0.12, 0.12), Kit.PAINT)
			for s in [-1.0, 1.0]:
				k.rod(Vector3(s * 0.28, 0.485, 0), Vector3(s * 0.335, 0.52, 0), 0.026, Color(0.14, 0.12, 0.12), Kit.PAINT)
			k.box(Vector3(0, 0.375, 0.0), Vector3(0.06, 0.08, 0.02), Color(0.14, 0.12, 0.12), Kit.PAINT)
		"prop_lantern_post":   # a red paper lantern hung from a pole
			k.box(Vector3(0, 0, 0), Vector3(0.07, 0.03, 0.07), GREY, Kit.STONE)
			k.box(Vector3(0, 0.03, 0), Vector3(0.026, 0.42, 0.026), WOOD, Kit.TIMBER)
			k.rod(Vector3(0, 0.44, 0), Vector3(0.1, 0.44, 0), 0.01, WOOD, Kit.TIMBER)
			k.rod(Vector3(0.0, 0.4, 0), Vector3(0.07, 0.44, 0), 0.008, WOOD, Kit.TIMBER)
			var lc := Vector3(0.1, 0.3, 0)
			k.box(lc + Vector3(0, 0.135, 0), Vector3(0.05, 0.012, 0.05), Color(0.14, 0.12, 0.12), Kit.PAINT)
			k.frustum(lc + Vector3(0, 0.07, 0), 0.04, 0.056, 0.012, RED, Kit.PAINT, 8, false)
			k.frustum(lc + Vector3(0, 0.0, 0), 0.056, 0.04, 0.07, RED, Kit.PAINT, 8, false)
			k.frustum(lc + Vector3(0, -0.02, 0), 0.02, 0.04, 0.02, Color(0.14, 0.12, 0.12), Kit.PAINT, 6)
		"prop_water_jars":   # big glazed storage jars with lids
			var jc := [Color(0.46, 0.31, 0.19), Color(0.40, 0.28, 0.18), Color(0.52, 0.36, 0.22)]
			var spots := [[Vector3(-0.07, 0, 0.0), 1.0], [Vector3(0.08, 0, 0.02), 0.85], [Vector3(0.0, 0, -0.09), 0.9]]
			for i in 3:
				var sp: Array = spots[i]
				var at: Vector3 = sp[0]
				var s: float = sp[1]
				k.frustum(at, 0.04 * s, 0.062 * s, 0.07 * s, jc[i], Kit.PAINT, 6, false)
				k.frustum(at + Vector3(0, 0.07 * s, 0), 0.062 * s, 0.04 * s, 0.07 * s, jc[i], Kit.PAINT, 6, false)
				k.frustum(at + Vector3(0, 0.14 * s, 0), 0.042 * s, 0.03 * s, 0.025 * s, Color(0.25, 0.17, 0.11), Kit.TIMBER, 6)
			k.box(Vector3(0.12, 0, -0.1), Vector3(0.09, 0.03, 0.07), WOOD_L, Kit.TIMBER, 0.4)
		"prop_drying_rack":   # a timber frame hung with persimmons, cloth and fish
			for s in [-1.0, 1.0]:
				k.box(Vector3(s * 0.2, 0, 0), Vector3(0.026, 0.34, 0.026), WOOD, Kit.TIMBER)
				k.box(Vector3(s * 0.2, 0, 0.0), Vector3(0.05, 0.02, 0.12), WOOD, Kit.TIMBER)
			for y in [0.2, 0.31]:
				k.rod(Vector3(-0.22, y, 0), Vector3(0.22, y, 0), 0.008, WOOD_L, Kit.TIMBER)
			var items := [Color(0.9, 0.5, 0.15), Color(0.85, 0.42, 0.12), Color.WHITE, Color(0.78, 0.74, 0.62), Color(0.9, 0.5, 0.15)]
			for i in 5:
				var x := -0.15 + i * 0.075
				if i == 2:
					k.box(Vector3(x, 0.14, 0), Vector3(0.05, 0.17, 0.008), items[i], Kit.OWNER_CLOTH)
				elif i == 3:
					k.box(Vector3(x, 0.17, 0), Vector3(0.026, 0.14, 0.012), items[i], Kit.CLOTH)
				else:
					k.box(Vector3(x, 0.18, 0), Vector3(0.036, 0.13, 0.036), items[i], Kit.CLOTH)
					k.box(Vector3(x, 0.255, 0), Vector3(0.05, 0.03, 0.05), items[i].darkened(0.1), Kit.CLOTH)


# --- house sets (which kinds a settlement draws from) ---------------------------------------------
# The culture picks the tradition: "samurai" is Japanese, "joseon" Korean, anything else Chinese
# (with "court" favouring courtyard houses, "southern" whitewashed horse-head-wall houses and
# "hills" rural houses). A kind listed twice is twice as common.


static func _tradition(culture: String) -> String:
	if culture == "samurai":
		return "jp"
	if culture == "joseon":
		return "kr"
	return "cn"


static func _names(prefix: String, numbers: Array) -> Array:
	var out: Array = []
	for n in numbers:
		out.append("house_%s_%d" % [prefix, int(n)])
	return out


## The house kinds for `culture` at `rank` (core, city, edge, suburb, town, village, farm, camp).
static func house_set(culture: String, rank: String) -> Array:
	var out: Array = []
	match _tradition(culture):
		"jp":
			match rank:
				"core":
					out = _names("jp_samurai", [1, 2, 3, 1, 2]) + _names("jp_machiya", [1, 3, 4]) + _names("jp_kura", [2, 3])
				"city":
					out = _names("jp_machiya", [1, 2, 3, 4, 1, 3]) + _names("jp_samurai", [1, 2, 3]) + _names("jp_kura", [1, 2]) + _names("jp_minka", [3])
				"edge":
					out = _names("jp_machiya", [2, 4, 2, 1]) + _names("jp_minka", [3, 3]) + _names("jp_kura", [1])
				"suburb":
					out = _names("jp_machiya", [2, 4]) + _names("jp_minka", [1, 3, 3]) + _names("jp_kura", [1, 3])
				"town":
					out = _names("jp_machiya", [1, 2, 3, 4]) + _names("jp_minka", [1, 2, 3]) + _names("jp_kura", [1, 3])
				"village":
					out = _names("jp_minka", [1, 2, 3, 4, 3, 2]) + _names("jp_kura", [3])
				"farm":
					out = _names("jp_minka", [1, 2, 4, 2]) + _names("jp_kura", [2, 3])
				"camp":
					out = _names("jp_minka", [3, 3, 2])
		"kr":
			match rank:
				"core":
					out = _names("kr_hanok", [1, 2, 3, 4, 3, 4]) + ["house_cn_merchant_1"]
				"city":
					out = _names("kr_hanok", [1, 2, 3, 4, 1, 2]) + _names("kr_choga", [1]) + ["house_cn_shop_2"]
				"edge":
					out = _names("kr_hanok", [1, 2]) + _names("kr_choga", [1, 2, 1, 3])
				"suburb":
					out = _names("kr_choga", [1, 2, 3, 1]) + _names("kr_hanok", [1, 2])
				"town":
					out = _names("kr_hanok", [1, 2, 3, 1]) + _names("kr_choga", [1, 2, 3])
				"village":
					out = _names("kr_choga", [1, 2, 3, 1, 2, 3]) + _names("kr_hanok", [1])
				"farm":
					out = _names("kr_choga", [1, 2, 3, 2]) + _names("kr_hanok", [2])
				"camp":
					out = _names("kr_choga", [1, 1, 2])
		_:
			match rank:
				"core":
					match culture:
						"southern": out = _names("cn_merchant", [1, 4, 2, 1]) + _names("cn_south", [2, 4, 4, 2]) + _names("cn_siheyuan", [3])
						"hills": out = _names("cn_merchant", [1, 4, 3]) + _names("cn_siheyuan", [1, 3]) + _names("cn_shop", [1])
						_: out = _names("cn_siheyuan", [1, 2, 3, 1, 3]) + _names("cn_merchant", [1, 2, 4, 1])
				"city":
					match culture:
						"court": out = _names("cn_siheyuan", [1, 2, 3, 1]) + _names("cn_merchant", [2, 3]) + _names("cn_shop", [1, 2, 4]) + ["house_1"]
						"southern": out = _names("cn_south", [1, 2, 3, 4, 1, 2]) + _names("cn_shop", [1, 3]) + _names("cn_merchant", [3])
						"hills": out = _names("cn_shop", [2, 5, 3]) + _names("cn_merchant", [3, 2]) + _names("cn_farm", [3]) + _names("cn_south", [3])
						_: out = _names("cn_shop", [1, 2, 3, 4, 5]) + _names("cn_merchant", [1, 2, 3, 4]) + _names("cn_siheyuan", [1, 2]) + _names("cn_south", [1]) + ["house_1", "house_2"]
				"edge":
					match culture:
						"southern": out = _names("cn_south", [3, 1, 3]) + _names("cn_shop", [5, 2]) + _names("cn_farm", [3])
						_: out = _names("cn_shop", [2, 3, 5, 2, 5]) + _names("cn_merchant", [3]) + _names("cn_farm", [3, 4]) + ["house_1"]
				"suburb":
					out = _names("cn_shop", [5, 2]) + _names("cn_farm", [1, 3, 4]) + _names("cn_merchant", [3])
					if culture == "southern":
						out += _names("cn_south", [3, 1])
				"town":
					out = _names("cn_shop", [2, 3, 5, 1]) + _names("cn_merchant", [3, 2]) + _names("cn_farm", [3, 4]) + _names("cn_south" if culture == "southern" else "cn_shop", [3, 1])
				"village":
					out = _names("cn_farm", [1, 2, 3, 4, 3, 1]) + _names("cn_shop", [5])
					if culture == "southern":
						out += _names("cn_south", [3, 3])
				"farm":
					out = _names("cn_farm", [1, 2, 3, 4, 1])
				"camp":
					out = _names("cn_farm", [2, 3, 2])
	return out


## Two-lot buildings (all about 2.0 wide by 1.0 deep) for `culture` at `rank`, or [] for none.
static func big_house_set(culture: String, rank: String) -> Array:
	var out: Array = []
	match _tradition(culture):
		"jp":
			match rank:
				"core": out = ["big_jp_samurai", "big_jp_row_1", "big_jp_row_2", "big_jp_samurai"]
				"city": out = ["big_jp_row_1", "big_jp_row_2", "big_jp_samurai", "big_jp_row_1"]
				"edge": out = ["big_jp_row_1", "big_jp_row_2"]
				"suburb": out = ["big_jp_row_2", "big_jp_farmstead"]
				"town": out = ["big_jp_row_1", "big_jp_row_2", "big_jp_farmstead"]
				"village", "farm": out = ["big_jp_farmstead"]
		"kr":
			match rank:
				"core", "city": out = ["big_kr_hanok", "big_cn_shoprow_2"]
				"edge": out = ["big_cn_shoprow_3"]
				"suburb", "town": out = ["big_kr_farmstead", "big_kr_hanok"]
				"village", "farm": out = ["big_kr_farmstead"]
		_:
			match rank:
				"core":
					out = ["big_cn_courtyard_1", "big_cn_courtyard_2", "big_cn_shoprow_1", "big_cn_shoprow_2"]
					if culture == "southern":
						out = ["big_cn_south_row", "big_cn_courtyard_2", "big_cn_shoprow_2", "big_cn_south_row"]
				"city":
					out = ["big_cn_shoprow_1", "big_cn_shoprow_2", "big_cn_shoprow_3", "big_cn_courtyard_1"]
					if culture == "southern":
						out = ["big_cn_south_row", "big_cn_south_row", "big_cn_shoprow_1", "big_cn_shoprow_3"]
				"edge": out = ["big_cn_shoprow_3", "big_cn_shoprow_1", "big_cn_south_row" if culture == "southern" else "big_cn_shoprow_3"]
				"suburb": out = ["big_cn_shoprow_3", "big_cn_farmstead"]
				"town": out = ["big_cn_shoprow_1", "big_cn_shoprow_3", "big_cn_farmstead"]
				"village", "farm": out = ["big_cn_farmstead"]
	return out
