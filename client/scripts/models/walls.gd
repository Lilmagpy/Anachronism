## City walls, towers and gatehouses (D-280 model kit), six cultural families:
## east, classical, northern, mud, south_asian, steppe.
##
## wall_F: one straight segment, exactly 1.0 long along x (x = -0.5 .. 0.5), the outer face
##   (the one with the crenellated parapet) toward +z, a walkway behind it. Segments tile end
##   to end; every part stops flush at x = +-0.5.
## tower_F: footprint <= 0.6 x 0.6, stands where the wall turns.
## gate_F: a gatehouse spanning a 1.0 gap along x (road through along z), <= 1.2 x 0.7.
## *_run kinds: test compositions (4 segments in a gentle curve + a tower + a gate).
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")

const FAMILIES := ["east", "classical", "northern", "mud", "south_asian", "steppe"]


static func kinds() -> Array:
	var out: Array = []
	for f in FAMILIES:
		out.append("wall_" + f)
		out.append("tower_" + f)
		out.append("gate_" + f)
	for f in FAMILIES:
		out.append("wall_" + f + "_run")
	return out


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	var parts := kind.split("_", false, 1)
	var what: String = parts[0]
	var fam: String = parts[1] if parts.size() > 1 else "east"
	if fam.ends_with("_run"):
		_run(k, fam.trim_suffix("_run"))
	else:
		match what:
			"wall":
				_wall(k, fam)
			"tower":
				_tower(k, fam)
			"gate":
				_gate(k, fam)
	return k.finish()


# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------

## A box between two corners.
static func _bx(k: Kit, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, col: Color, mat: int) -> void:
	k.box(Vector3((x0 + x1) * 0.5, y0, (z0 + z1) * 0.5), Vector3(x1 - x0, y1 - y0, z1 - z0), col, mat)


## A trapezoid prism along x: half thickness hb at y0, ht at y1 (a battered wall), closed ends.
static func _slab(k: Kit, x0: float, x1: float, y0: float, y1: float, hb: float, ht: float, col: Color, mat: int) -> void:
	var c := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0)
	k.quad(Vector3(x0, y0, hb), Vector3(x1, y0, hb), Vector3(x1, y1, ht), Vector3(x0, y1, ht), col, mat, c)
	k.quad(Vector3(x1, y0, -hb), Vector3(x0, y0, -hb), Vector3(x0, y1, -ht), Vector3(x1, y1, -ht), col, mat, c)
	k.quad(Vector3(x0, y1, ht), Vector3(x1, y1, ht), Vector3(x1, y1, -ht), Vector3(x0, y1, -ht), col, mat, c)
	k.quad(Vector3(x0, y0, -hb), Vector3(x0, y0, hb), Vector3(x0, y1, ht), Vector3(x0, y1, -ht), col, mat, c)
	k.quad(Vector3(x1, y0, hb), Vector3(x1, y0, -hb), Vector3(x1, y1, -ht), Vector3(x1, y1, ht), col, mat, c)


## A row of n merlons across x in [x0, x1] standing on y, centred at depth z.
## style: rect, round, step, peak. `cap` (alpha > 0) puts a coping slab over rect/step merlons.
static func _merlons(k: Kit, n: int, x0: float, x1: float, y: float, z: float, h: float, d: float, frac: float,
		col: Color, mat: int, style := "rect", cap := Color(0, 0, 0, 0), cap_mat := Kit.TILE) -> void:
	var pitch := (x1 - x0) / n
	var w := pitch * frac
	for i in n:
		var cx := x0 + pitch * (i + 0.5)
		match style:
			"round":
				k.box(Vector3(cx, y, z), Vector3(w, h * 0.6, d), col, mat)
				k.push(Transform3D(Basis.from_scale(Vector3(1, 1, d / w)), Vector3(cx, y + h * 0.6, z)))
				k.dome(Vector3.ZERO, w * 0.5, col, mat, 0.9, 2, 6)
				k.pop()
			"step":
				k.box(Vector3(cx, y, z), Vector3(w, h * 0.55, d), col, mat)
				k.box(Vector3(cx, y + h * 0.55, z), Vector3(w * 0.5, h * 0.45, d), col, mat)
			"peak":
				k.box(Vector3(cx, y, z), Vector3(w, h * 0.55, d), col, mat)
				k.wedge(Vector3(cx, y + h * 0.55, z), d, w, h * 0.45, col, mat, PI / 2.0)
			_:
				k.box(Vector3(cx, y, z), Vector3(w, h, d), col, mat)
				if cap.a > 0.0:
					k.box(Vector3(cx, y + h, z), Vector3(w + 0.02, 0.025, d + 0.03), cap, cap_mat)


## The arched mass of a gatehouse: a solid x0..x1 (depth d, base y0, top ytop) with a vaulted
## passage of radius r (x-radius) and height stretch ry, springing at ys, centred at cx.
static func _arch_mass(k: Kit, x0: float, x1: float, y0: float, ytop: float, cx: float, r: float, ys: float,
		d: float, col: Color, mat: int, vault: Color, ry := 1.0, steps := 8) -> void:
	var hd := d * 0.5
	_bx(k, x0, cx - r, y0, ytop, -hd, hd, col, mat)
	_bx(k, cx + r, x1, y0, ytop, -hd, hd, col, mat)
	# the passage sides below the spring
	if ys > y0:
		for s: float in [-1.0, 1.0]:
			var x: float = cx + s * r
			var inside := Vector3(cx + s * (r + 0.1), (y0 + ys) * 0.5, 0)
			k.quad(Vector3(x, y0, -hd), Vector3(x, y0, hd), Vector3(x, ys, hd), Vector3(x, ys, -hd), vault, mat, inside)
	for i in steps:
		var a0 := PI * i / steps
		var a1 := PI * (i + 1) / steps
		var p0 := Vector3(cx + cos(a0) * r, ys + sin(a0) * r * ry, 0)
		var p1 := Vector3(cx + cos(a1) * r, ys + sin(a1) * r * ry, 0)
		var inside := Vector3((p0.x + p1.x) * 0.5, ytop - 0.01, 0)
		var f0 := Vector3(p0.x, p0.y, hd)
		var f1 := Vector3(p1.x, p1.y, hd)
		var b0 := Vector3(p0.x, p0.y, -hd)
		var b1 := Vector3(p1.x, p1.y, -hd)
		# spandrels front and back (from the arch up to the top), and the vault soffit
		k.quad(f1, f0, Vector3(f0.x, ytop, hd), Vector3(f1.x, ytop, hd), col, mat, inside)
		k.quad(b0, b1, Vector3(b1.x, ytop, -hd), Vector3(b0.x, ytop, -hd), col, mat, inside)
		k.quad(f0, f1, b1, b0, vault, mat, inside)
		k.quad(Vector3(f1.x, ytop, hd), Vector3(f0.x, ytop, hd), Vector3(b0.x, ytop, -hd), Vector3(b1.x, ytop, -hd), col, mat,
			Vector3(f0.x, ytop - 0.1, 0))


## A ring of dressed stone round an arch (proud of the face by `out`), front and back.
static func _arch_ring(k: Kit, cx: float, ys: float, r: float, t: float, d: float, out: float, col: Color, mat: int,
		ry := 1.0, steps := 8) -> void:
	var hd := d * 0.5 + out
	for zs: float in [-1.0, 1.0]:
		var z: float = zs * hd
		for i in steps:
			var a0 := PI * i / steps
			var a1 := PI * (i + 1) / steps
			var i0 := Vector3(cx + cos(a0) * r, ys + sin(a0) * r * ry, z)
			var i1 := Vector3(cx + cos(a1) * r, ys + sin(a1) * r * ry, z)
			var o0 := Vector3(cx + cos(a0) * (r + t), ys + sin(a0) * (r + t) * ry, z)
			var o1 := Vector3(cx + cos(a1) * (r + t), ys + sin(a1) * (r + t) * ry, z)
			var inside := Vector3(cx, ys, z - zs * 0.2)
			k.quad(i0, o0, o1, i1, col, mat, inside)
		# a keystone block on top
		k.box(Vector3(cx, ys + (r + t) * ry - t * 0.4, z - zs * out * 0.5), Vector3(t * 1.1, t * 1.3, out * 2.0 + 0.01), col.lightened(0.08), mat)
	# the jambs below the spring
	for s: float in [-1.0, 1.0]:
		for zs: float in [-1.0, 1.0]:
			k.box(Vector3(cx + s * (r + t * 0.5), 0, zs * (hd - out * 0.5)), Vector3(t, ys, out + 0.0), col, mat)


## Double doors swung half open against the passage sides, plus the dark depth behind.
static func _gate_doors(k: Kit, cx: float, ys: float, r: float, z: float, wood: Color, ry := 1.0) -> void:
	# dark backdrop filling the opening (half-disc and rectangle)
	var pts: Array = [Vector3(cx - r, 0, z), Vector3(cx + r, 0, z)]
	var steps := 8
	pts.append(Vector3(cx + r, ys, z))
	for i in range(1, steps):
		var a := PI * i / steps
		pts.append(Vector3(cx + cos(a) * r, ys + sin(a) * r * ry, z))
	pts.append(Vector3(cx - r, ys, z))
	k.polygon(pts, Color(0.05, 0.04, 0.04), Kit.DARK, Vector3(cx, ys * 0.5, z - 1.0))
	# the door leaves
	for s: float in [-1.0, 1.0]:
		var hinge := Vector3(cx + s * (r - 0.005), 0, z + 0.07)
		k.push(Kit.at(hinge, s * 1.0))
		k.box(Vector3(-s * r * 0.5, 0, 0), Vector3(r, ys + 0.04, 0.025), wood, Kit.TIMBER)
		k.box(Vector3(-s * r * 0.5, ys * 0.35, 0.018), Vector3(r, 0.02, 0.012), Color(0.15, 0.15, 0.16), Kit.DARK)
		k.box(Vector3(-s * r * 0.5, ys * 0.75, 0.018), Vector3(r, 0.02, 0.012), Color(0.15, 0.15, 0.16), Kit.DARK)
		k.pop()


## A hanging banner (vertical cloth) on a wall face at `foot`, facing +z.
static func _hanging(k: Kit, foot: Vector3, w: float, h: float, yaw := 0.0) -> void:
	k.push(Kit.at(foot, yaw))
	k.box(Vector3(0, h, 0), Vector3(w + 0.03, 0.015, 0.03), Color(0.3, 0.22, 0.12), Kit.TIMBER)
	k.box(Vector3(0, 0, 0.01), Vector3(w, h, 0.012), Color.WHITE, Kit.OWNER_CLOTH)
	k.tri(Vector3(-w / 2, 0, 0.016), Vector3(w / 2, 0, 0.016), Vector3(0, -w * 0.4, 0.016), Color.WHITE, Kit.OWNER_CLOTH,
		Vector3(0, h / 2, 0))
	k.pop()


## A ring of boxes round a round tower (crenellations, corbels).
static func _ring(k: Kit, n: int, radius: float, y: float, size: Vector3, col: Color, mat: int, phase := 0.0) -> void:
	for i in n:
		var a := phase + i * TAU / n
		k.box(Vector3(cos(a) * radius, y, sin(a) * radius), size, col, mat, -a)


## A cheap lattice window: dark opening, frame and two bars (centre at `at`, facing `yaw`).
static func _lat(k: Kit, at: Vector3, yaw: float, w: float, h: float, frame: Color) -> void:
	k.push(Kit.at(at, yaw))
	k.box(Vector3(0, -h / 2 - 0.012, 0), Vector3(w + 0.035, h + 0.035, 0.01), frame, Kit.PAINT)
	k.box(Vector3(0, -h / 2, 0.006), Vector3(w, h, 0.01), Color(0.07, 0.05, 0.04), Kit.DARK)
	k.box(Vector3(0, -h / 2, 0.014), Vector3(0.012, h, 0.01), frame, Kit.PAINT)
	k.box(Vector3(0, -h * 0.5, 0.014), Vector3(w, 0.012, 0.01), frame, Kit.PAINT)
	k.pop()


## An arrow slit on a wall face: a dark vertical slot.
static func _slit(k: Kit, at: Vector3, yaw: float, w: float, h: float) -> void:
	k.push(Kit.at(at, yaw))
	k.box(Vector3(0, -h / 2, 0), Vector3(w, h, 0.012), Color(0.06, 0.05, 0.05), Kit.DARK)
	k.pop()


# ---------------------------------------------------------------------------------------------
# walls: straight segments, x from -0.5 to 0.5, outer face +z
# ---------------------------------------------------------------------------------------------

static func _wall(k: Kit, fam: String) -> void:
	match fam:
		"east":
			var brick := Color(0.56, 0.57, 0.58)
			var stone := Color(0.66, 0.65, 0.62)
			var tile := Color(0.24, 0.26, 0.29)
			_slab(k, -0.5, 0.5, 0.0, 0.12, 0.17, 0.155, stone, Kit.STONE)
			_slab(k, -0.5, 0.5, 0.12, 0.5, 0.15, 0.125, brick, Kit.BRICK)
			# string course / cornice under the parapet, tiled drip edge
			_bx(k, -0.5, 0.5, 0.46, 0.5, -0.15, 0.155, stone, Kit.STONE)
			_bx(k, -0.5, 0.5, 0.5, 0.505, -0.13, 0.13, Color(0.42, 0.40, 0.37), Kit.EARTH)   # walkway
			# outer parapet: low solid wall with crenel-merlons and tiled coping
			_bx(k, -0.5, 0.5, 0.5, 0.58, 0.085, 0.145, brick, Kit.BRICK)
			_bx(k, -0.5, 0.5, 0.58, 0.6, 0.075, 0.155, tile, Kit.TILE)
			_merlons(k, 5, -0.5, 0.5, 0.6, 0.115, 0.1, 0.06, 0.55, brick, Kit.BRICK, "rect", tile)
			# inner low wall
			_bx(k, -0.5, 0.5, 0.5, 0.54, -0.145, -0.1, brick, Kit.BRICK)
			_bx(k, -0.5, 0.5, 0.54, 0.56, -0.155, -0.09, tile, Kit.TILE)
			# a pilaster with a rain-spout in the middle of the outer face
			_bx(k, -0.03, 0.03, 0.12, 0.46, 0.138, 0.17, stone, Kit.STONE)
			# arrow-slit loops
			for x: float in [-0.28, 0.28]:
				_slit(k, Vector3(x, 0.38, 0.1485), 0.0, 0.025, 0.08)
		"classical":
			var stone := Color(0.78, 0.74, 0.66)
			var dark := Color(0.68, 0.64, 0.57)
			_bx(k, -0.5, 0.5, 0.0, 0.07, -0.165, 0.165, dark, Kit.STONE)   # plinth
			_bx(k, -0.5, 0.5, 0.07, 0.5, -0.145, 0.145, stone, Kit.STONE)
			_bx(k, -0.5, 0.5, 0.2, 0.215, -0.15, 0.15, dark, Kit.STONE)   # string course
			_bx(k, -0.5, 0.5, 0.46, 0.5, -0.16, 0.16, dark, Kit.STONE)   # cornice
			_bx(k, -0.5, 0.5, 0.5, 0.505, -0.12, 0.12, Color(0.55, 0.52, 0.46), Kit.STONE)
			_merlons(k, 4, -0.5, 0.5, 0.505, 0.115, 0.13, 0.065, 0.55, stone, Kit.STONE)
			_bx(k, -0.5, 0.5, 0.5, 0.55, -0.15, -0.12, stone, Kit.STONE)   # inner kerb
			for x: float in [-0.25, 0.25]:   # arched loop windows
				k.window(Vector3(x, 0.33, 0.1455), 0.0, 0.06, 0.12, dark, "arch")
		"northern":
			var stone := Color(0.60, 0.59, 0.56)
			var dark := Color(0.5, 0.49, 0.47)
			_slab(k, -0.5, 0.5, 0.0, 0.5, 0.165, 0.13, stone, Kit.STONE)
			_slab(k, -0.5, 0.5, 0.0, 0.1, 0.175, 0.165, dark, Kit.STONE)   # splayed foot
			# corbel course carrying the wall walk
			_bx(k, -0.5, 0.5, 0.46, 0.5, -0.15, 0.17, dark, Kit.STONE)
			_bx(k, -0.5, 0.5, 0.5, 0.505, -0.14, 0.14, Color(0.45, 0.42, 0.38), Kit.EARTH)
			_merlons(k, 4, -0.5, 0.5, 0.505, 0.135, 0.17, 0.07, 0.56, stone, Kit.STONE, "rect", dark, Kit.STONE)
			_bx(k, -0.5, 0.5, 0.505, 0.57, 0.1, 0.17, stone, Kit.STONE)   # low wall behind crenels
			_bx(k, -0.5, 0.5, 0.505, 0.55, -0.15, -0.12, stone, Kit.STONE)
			for x: float in [-0.3, 0.1]:
				_slit(k, Vector3(x, 0.38, 0.1635), 0.0, 0.025, 0.12)
		"mud":
			var mud := Color(0.78, 0.64, 0.45)
			var lite := Color(0.84, 0.72, 0.54)
			_slab(k, -0.5, 0.5, 0.0, 0.58, 0.165, 0.12, mud, Kit.MUDBRICK)   # strongly battered
			_bx(k, -0.5, 0.5, 0.58, 0.6, -0.125, 0.135, lite, Kit.MUDBRICK)
			_bx(k, -0.5, 0.5, 0.6, 0.64, 0.07, 0.135, mud, Kit.MUDBRICK)
			_merlons(k, 5, -0.5, 0.5, 0.64, 0.1, 0.13, 0.07, 0.6, lite, Kit.MUDBRICK, "round")
			_bx(k, -0.5, 0.5, 0.6, 0.64, -0.135, -0.1, mud, Kit.MUDBRICK)
			# a buttress and a drain hole
			k.plinth(Vector3(0, 0, 0.14), 0.2, 0.08, 0.5, 0.03, lite, Kit.MUDBRICK)
			for x: float in [-0.28, 0.28]:
				_slit(k, Vector3(x, 0.42, 0.1335), 0.0, 0.03, 0.06)
		"south_asian":
			var brick := Color(0.70, 0.40, 0.30)
			var stone := Color(0.84, 0.74, 0.58)
			_slab(k, -0.5, 0.5, 0.0, 0.5, 0.17, 0.14, brick, Kit.BRICK)
			_bx(k, -0.5, 0.5, 0.0, 0.08, -0.175, 0.175, stone, Kit.STONE)
			_bx(k, -0.5, 0.5, 0.45, 0.5, -0.16, 0.165, stone, Kit.STONE)   # cornice band
			_bx(k, -0.5, 0.5, 0.5, 0.505, -0.13, 0.13, Color(0.55, 0.45, 0.35), Kit.EARTH)
			_bx(k, -0.5, 0.5, 0.505, 0.56, 0.1, 0.15, brick, Kit.BRICK)
			_merlons(k, 5, -0.5, 0.5, 0.56, 0.125, 0.12, 0.05, 0.62, stone, Kit.STONE, "peak")
			_bx(k, -0.5, 0.5, 0.505, 0.54, -0.15, -0.115, brick, Kit.BRICK)
			# a row of blind arched niches
			for x: float in [-0.25, 0.25]:
				_slit(k, Vector3(x, 0.34, 0.1395), 0.0, 0.05, 0.14)
		"steppe":
			var log_c := Color(0.52, 0.38, 0.24)
			var log_d := Color(0.44, 0.32, 0.20)
			# a plank walk on the inside, rails, then the palisade
			_bx(k, -0.5, 0.5, 0.26, 0.285, -0.2, -0.04, Color(0.5, 0.38, 0.25), Kit.TIMBER)
			for i in 3:
				var x := -0.5 + (i + 0.5) / 3.0
				k.box(Vector3(x, 0, -0.17), Vector3(0.035, 0.26, 0.035), log_d, Kit.TIMBER)
			_bx(k, -0.5, 0.5, 0.1, 0.13, -0.045, 0.045, log_d, Kit.TIMBER)
			for i in 10:
				var x := -0.45 + i * 0.1
				var tall := 0.58 + (0.07 if i % 2 == 0 else 0.0) + (0.03 if i % 5 == 3 else 0.0)
				var z := 0.03 if i % 2 == 0 else -0.03
				k.frustum(Vector3(x, 0, z), 0.052, 0.048, tall, log_c if i % 2 == 0 else log_d, Kit.TIMBER, 5, false)
				k.frustum(Vector3(x, tall, z), 0.048, 0.0, 0.13, log_c, Kit.TIMBER, 5)
			_bx(k, -0.5, 0.5, 0.4, 0.43, 0.05, 0.085, log_d, Kit.TIMBER)   # lashing rail across the face
			_bx(k, -0.5, 0.5, 0.2, 0.23, 0.05, 0.085, log_d, Kit.TIMBER)


# ---------------------------------------------------------------------------------------------
# towers (footprint <= 0.6 x 0.6)
# ---------------------------------------------------------------------------------------------

static func _tower(k: Kit, fam: String) -> void:
	match fam:
		"east":
			var brick := Color(0.56, 0.57, 0.58)
			var stone := Color(0.66, 0.65, 0.62)
			var red := Color(0.62, 0.14, 0.10)
			var roof := Color(0.42, 0.45, 0.48)
			var cream := Color(0.90, 0.85, 0.72)
			var wood := Color(0.36, 0.24, 0.15)
			k.plinth(Vector3.ZERO, 0.58, 0.58, 0.1, 0.02, stone, Kit.STONE)
			k.plinth(Vector3(0, 0.1, 0), 0.54, 0.54, 0.46, 0.05, brick, Kit.BRICK)
			k.box(Vector3(0, 0.56, 0), Vector3(0.52, 0.04, 0.52), stone, Kit.STONE)   # cornice
			for s: float in [-1.0, 1.0]:   # parapet merlons on the terrace
				_merlons(k, 3, -0.25, 0.25, 0.6, s * 0.245, 0.07, 0.04, 0.6, brick, Kit.BRICK)
				k.push(Kit.at(Vector3.ZERO, PI / 2.0))
				_merlons(k, 3, -0.25, 0.25, 0.6, s * 0.245, 0.07, 0.04, 0.6, brick, Kit.BRICK)
				k.pop()
			# gate arch loop windows
			k.window(Vector3(0, 0.36, 0.2285), 0.0, 0.07, 0.14, stone, "arch")
			# pavilion storey: red pillars, cream walls, lattice windows
			k.box(Vector3(0, 0.6, 0), Vector3(0.4, 0.3, 0.4), cream, Kit.PLASTER)
			for x: float in [-0.2, 0.2]:
				for z: float in [-0.2, 0.2]:
					k.box(Vector3(x, 0.6, z), Vector3(0.05, 0.3, 0.05), red, Kit.PAINT)
			for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
				k.window(Vector3.ZERO + Vector3(sin(yaw), 0, cos(yaw)) * 0.2 + Vector3(0, 0.76, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 0.003,
					yaw, 0.1, 0.12, red, "lattice")
			k.hip_roof(Vector3(0, 0.88, 0), 0.4, 0.4, 0.14, 0.09, 0.03, roof, Kit.OWNER_ROOF, 0.0, 0.05)
			# upper storey
			k.box(Vector3(0, 0.95, 0), Vector3(0.26, 0.2, 0.26), cream, Kit.PLASTER)
			for x: float in [-0.13, 0.13]:
				for z: float in [-0.13, 0.13]:
					k.box(Vector3(x, 0.95, z), Vector3(0.035, 0.2, 0.035), red, Kit.PAINT)
			for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
				_lat(k, Vector3(sin(yaw), 0, cos(yaw)) * 0.1325 + Vector3(0, 1.06, 0), yaw, 0.07, 0.09, red)
			k.hip_roof(Vector3(0, 1.15, 0), 0.26, 0.26, 0.14, 0.09, 0.03, roof, Kit.OWNER_ROOF, 0.0, 0.05)
			k.frustum(Vector3(0, 1.29, 0), 0.02, 0.0, 0.1, Color(0.9, 0.75, 0.25), Kit.GOLD, 6)
		"classical":
			var stone := Color(0.78, 0.74, 0.66)
			var dark := Color(0.66, 0.62, 0.55)
			var roof := Color(0.80, 0.42, 0.30)
			k.box(Vector3.ZERO, Vector3(0.56, 0.08, 0.56), dark, Kit.STONE)
			k.box(Vector3(0, 0.08, 0), Vector3(0.5, 0.9, 0.5), stone, Kit.STONE)

			for y: float in [0.4, 0.62]:
				k.box(Vector3(0, y, 0), Vector3(0.53, 0.025, 0.53), dark, Kit.STONE)
			for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
				var d := Vector3(sin(yaw), 0, cos(yaw))
				k.window(d * 0.2515 + Vector3(0, 0.27, 0), yaw, 0.07, 0.14, dark, "arch")
				k.window(d * 0.2515 + Vector3(0, 0.78, 0), yaw, 0.08, 0.14, dark, "arch")
			# cornice with a corbel table, then an open crenellated top under the roof
			k.box(Vector3(0, 0.98, 0), Vector3(0.56, 0.05, 0.56), dark, Kit.STONE)
			k.box(Vector3(0, 1.03, 0), Vector3(0.5, 0.1, 0.5), stone, Kit.STONE)
			k.hip_roof(Vector3(0, 1.13, 0), 0.5, 0.5, 0.26, 0.04, 0.03, roof, Kit.OWNER_ROOF)
			k.frustum(Vector3(0, 1.43, 0), 0.025, 0.0, 0.1, Color(0.9, 0.75, 0.25), Kit.GOLD, 6)
			k.banner(Vector3(0.15, 1.1, 0.15), 0.3, 0.18)
		"northern":
			var stone := Color(0.60, 0.59, 0.56)
			var dark := Color(0.50, 0.49, 0.47)
			k.frustum(Vector3.ZERO, 0.3, 0.27, 0.16, dark, Kit.STONE, 14, false)
			k.frustum(Vector3(0, 0.16, 0), 0.27, 0.24, 0.74, stone, Kit.STONE, 14, false)
			k.frustum(Vector3(0, 0.9, 0), 0.24, 0.31, 0.1, dark, Kit.STONE, 14, false)   # corbel flare
			k.frustum(Vector3(0, 1.0, 0), 0.31, 0.31, 0.04, dark, Kit.STONE, 14)
			_ring(k, 12, 0.285, 1.04, Vector3(0.06, 0.11, 0.1), stone, Kit.STONE)
			_ring(k, 12, 0.28, 1.04, Vector3(0.05, 0.03, 0.18), dark, Kit.STONE, TAU / 24.0)
			k.frustum(Vector3(0, 1.0, 0), 0.265, 0.265, 0.05, stone, Kit.STONE, 14, false)
			k.frustum(Vector3(0, 1.04, 0), 0.25, 0.0, 0.5, Color(0.80, 0.42, 0.30), Kit.OWNER_ROOF, 14)
			for a: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
				_slit(k, Vector3(sin(a), 0, cos(a)) * 0.259 + Vector3(0, 0.55, 0), a, 0.03, 0.14)
				_slit(k, Vector3(sin(a + 0.785), 0, cos(a + 0.785)) * 0.254 + Vector3(0, 0.82, 0), a + 0.785, 0.025, 0.1)
			k.door(Vector3(0, 0.1, 0.285), 0.0, 0.1, 0.18, Color(0.45, 0.43, 0.4))
			k.banner(Vector3(0, 1.5, 0), 0.3, 0.22)
		"mud":
			var mud := Color(0.78, 0.64, 0.45)
			var lite := Color(0.86, 0.74, 0.56)
			k.plinth(Vector3.ZERO, 0.6, 0.6, 0.75, 0.07, mud, Kit.MUDBRICK)
			k.box(Vector3(0, 0.75, 0), Vector3(0.5, 0.05, 0.5), lite, Kit.MUDBRICK)
			for s: float in [-1.0, 1.0]:
				_merlons(k, 3, -0.25, 0.25, 0.8, s * 0.22, 0.14, 0.06, 0.6, lite, Kit.MUDBRICK, "round")
				k.push(Kit.at(Vector3.ZERO, PI / 2.0))
				_merlons(k, 2, -0.16, 0.16, 0.8, s * 0.22, 0.14, 0.06, 0.6, lite, Kit.MUDBRICK, "round")
				k.pop()
			k.plinth(Vector3(0, 0.75, 0), 0.34, 0.34, 0.3, 0.03, mud, Kit.MUDBRICK)   # upper room
			k.box(Vector3(0, 1.05, 0), Vector3(0.36, 0.04, 0.36), lite, Kit.MUDBRICK)
			for i in 4:
				var a := i * PI / 2.0
				k.push(Kit.at(Vector3.ZERO, a))
				_merlons(k, 2, -0.16, 0.16, 1.09, 0.16, 0.1, 0.05, 0.55, lite, Kit.MUDBRICK, "step")
				k.pop()
			for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
				k.window(Vector3(sin(yaw), 0, cos(yaw)) * 0.169 + Vector3(0, 0.92, 0), yaw, 0.05, 0.1, lite, "arch")
			k.door(Vector3(0, 0, 0.29), 0.0, 0.12, 0.2, Color(0.6, 0.5, 0.36), Color(0.3, 0.2, 0.12))
			# projecting roof-beam ends, the mark of mud-brick building
			for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
				k.push(Kit.at(Vector3.ZERO, yaw))
				for bx: float in [-0.1, 0.1]:
					for by: float in [0.42]:
						var inset := 0.3 - by * 0.0933 - 0.0
						k.box(Vector3(bx, by, inset), Vector3(0.03, 0.03, 0.05), Color(0.4, 0.28, 0.17), Kit.TIMBER)
				k.pop()
			k.banner(Vector3(0.1, 1.09, 0.1), 0.35, 0.2)
		"south_asian":
			var brick := Color(0.70, 0.40, 0.30)
			var stone := Color(0.86, 0.76, 0.60)
			var white := Color(0.94, 0.91, 0.84)
			k.frustum(Vector3.ZERO, 0.3, 0.3, 0.07, stone, Kit.STONE, 12, false)
			k.frustum(Vector3(0, 0.07, 0), 0.28, 0.25, 0.7, brick, Kit.BRICK, 12, false)
			k.frustum(Vector3(0, 0.45, 0), 0.265, 0.265, 0.03, stone, Kit.STONE, 12, false)
			k.frustum(Vector3(0, 0.77, 0), 0.25, 0.3, 0.07, stone, Kit.STONE, 12, false)
			k.frustum(Vector3(0, 0.84, 0), 0.3, 0.3, 0.03, stone, Kit.STONE, 12)
			_ring(k, 12, 0.275, 0.87, Vector3(0.05, 0.05, 0.08), brick, Kit.BRICK)
			for i in 12:
				var a := i * TAU / 12.0
				k.push(Kit.at(Vector3(cos(a), 0.92, sin(a)) * 0.275, -a))
				k.wedge(Vector3.ZERO, 0.08, 0.05, 0.08, brick, Kit.BRICK, PI / 2.0)
				k.pop()
			# the chhatri: six slim columns, a slab roof and a white dome with a gold finial
			for i in 6:
				var a := i * TAU / 6.0
				k.column(Vector3(cos(a) * 0.17, 0.87, sin(a) * 0.17), 0.017, 0.27, stone)
			k.frustum(Vector3(0, 1.14, 0), 0.22, 0.2, 0.04, stone, Kit.STONE, 6)
			k.dome(Vector3(0, 1.18, 0), 0.18, white, Kit.PLASTER, 1.0, 4, 12, true)
			k.frustum(Vector3(0, 1.33, 0), 0.015, 0.0, 0.12, Color(0.9, 0.75, 0.25), Kit.GOLD, 6)
			_slit(k, Vector3(0, 0.55, 0.2525), 0.0, 0.035, 0.16)
		"steppe":
			var wood := Color(0.50, 0.37, 0.24)
			var dk := Color(0.40, 0.29, 0.19)
			for x: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]:
					k.rod(Vector3(x * 0.25, 0, z * 0.25), Vector3(x * 0.17, 0.92, z * 0.17), 0.03, wood, Kit.TIMBER)
			for y: float in [0.25, 0.55]:
				var s := 0.25 - (0.08 * y / 0.92)
				for sgn: float in [-1.0, 1.0]:
					k.rod(Vector3(-s, y, sgn * s), Vector3(s, y, sgn * s), 0.015, dk, Kit.TIMBER)
					k.rod(Vector3(sgn * s, y, -s), Vector3(sgn * s, y, s), 0.015, dk, Kit.TIMBER)
			k.rod(Vector3(-0.22, 0.05, 0.22), Vector3(0.14, 0.58, 0.14), 0.012, dk, Kit.TIMBER)
			k.rod(Vector3(0.22, 0.05, 0.22), Vector3(-0.14, 0.58, 0.14), 0.012, dk, Kit.TIMBER)
			k.box(Vector3(0, 0.92, 0), Vector3(0.44, 0.04, 0.44), dk, Kit.TIMBER)
			for i in 6:   # railing
				var t := -0.2 + i * 0.08
				for sgn: float in [-1.0, 1.0]:
					k.box(Vector3(t, 0.96, sgn * 0.2), Vector3(0.025, 0.12, 0.025), wood, Kit.TIMBER)
					k.box(Vector3(sgn * 0.2, 0.96, t), Vector3(0.025, 0.12, 0.025), wood, Kit.TIMBER)
			for sgn: float in [-1.0, 1.0]:
				_bx(k, -0.21, 0.21, 1.04, 1.07, sgn * 0.21 - 0.012, sgn * 0.21 + 0.012, wood, Kit.TIMBER)
				_bx(k, sgn * 0.21 - 0.012, sgn * 0.21 + 0.012, 1.04, 1.07, -0.21, 0.21, wood, Kit.TIMBER)
			for x: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]:
					k.box(Vector3(x * 0.16, 0.96, z * 0.16), Vector3(0.03, 0.34, 0.03), wood, Kit.TIMBER)
			k.hip_roof(Vector3(0, 1.28, 0), 0.34, 0.34, 0.22, 0.1, 0.025, Color(0.74, 0.50, 0.30), Kit.OWNER_ROOF)
			k.banner(Vector3(0, 1.47, 0), 0.3, 0.22)


# ---------------------------------------------------------------------------------------------
# gatehouses: span a 1.0 gap along x; the road runs through along z
# ---------------------------------------------------------------------------------------------

static func _gate(k: Kit, fam: String) -> void:
	match fam:
		"east":
			var brick := Color(0.56, 0.57, 0.58)
			var stone := Color(0.68, 0.66, 0.62)
			var red := Color(0.62, 0.14, 0.10)
			var roof := Color(0.42, 0.45, 0.48)
			var cream := Color(0.90, 0.85, 0.72)
			var tile := Color(0.24, 0.26, 0.29)
			var wood := Color(0.36, 0.24, 0.15)
			_bx(k, -0.6, 0.6, 0.0, 0.08, -0.33, 0.33, stone, Kit.STONE)
			_arch_mass(k, -0.58, 0.58, 0.08, 0.52, 0.0, 0.17, 0.26, 0.56, brick, Kit.BRICK, Color(0.38, 0.38, 0.4))
			_arch_ring(k, 0.0, 0.26, 0.17, 0.045, 0.56, 0.012, stone, Kit.STONE)
			_gate_doors(k, 0.0, 0.26, 0.17, 0.0, wood)
			_bx(k, -0.6, 0.6, 0.5, 0.56, -0.31, 0.31, stone, Kit.STONE)   # cornice
			for s: float in [-1.0, 1.0]:
				_merlons(k, 7, -0.58, 0.58, 0.56, s * 0.275, 0.08, 0.045, 0.55, brick, Kit.BRICK, "rect", tile)
			for x: float in [-0.4, 0.4]:
				_hanging(k, Vector3(x, 0.44, 0.292), 0.1, 0.22)
			# the gate tower: red pillars, cream walls, lattice, two hipped roofs
			k.box(Vector3(0, 0.56, 0), Vector3(0.9, 0.04, 0.46), stone, Kit.STONE)
			k.box(Vector3(0, 0.6, 0), Vector3(0.84, 0.32, 0.38), cream, Kit.PLASTER)
			for x: float in [-0.42, -0.14, 0.14, 0.42]:
				for z: float in [-0.19, 0.19]:
					k.box(Vector3(x, 0.6, z), Vector3(0.05, 0.32, 0.05), red, Kit.PAINT)
			for x: float in [-0.28, 0.0, 0.28]:
				_lat(k, Vector3(x, 0.78, 0.1915), 0.0, 0.1, 0.12, red)
				_lat(k, Vector3(x, 0.78, -0.1915), PI, 0.1, 0.12, red)
			k.box(Vector3(0, 0.92, 0), Vector3(0.9, 0.03, 0.44), red, Kit.PAINT)
			k.hip_roof(Vector3(0, 0.95, 0), 0.86, 0.38, 0.2, 0.14, 0.03, roof, Kit.OWNER_ROOF, 0.0, 0.06)
			k.box(Vector3(0, 1.0, 0), Vector3(0.5, 0.26, 0.26), cream, Kit.PLASTER)
			for x: float in [-0.25, 0.25]:
				for z: float in [-0.13, 0.13]:
					k.box(Vector3(x, 1.0, z), Vector3(0.04, 0.26, 0.04), red, Kit.PAINT)
			for x: float in [-0.12, 0.12]:
				_lat(k, Vector3(x, 1.14, 0.1315), 0.0, 0.08, 0.1, red)
			k.hip_roof(Vector3(0, 1.26, 0), 0.5, 0.26, 0.2, 0.13, 0.03, roof, Kit.OWNER_ROOF, 0.0, 0.06)
			k.frustum(Vector3(0, 1.46, 0), 0.02, 0.0, 0.1, Color(0.9, 0.75, 0.25), Kit.GOLD, 6)
			for x: float in [-0.46, 0.46]:
				k.banner(Vector3(x, 0.56, 0.2), 0.36, 0.2)
		"classical":
			var stone := Color(0.78, 0.74, 0.66)
			var dark := Color(0.66, 0.62, 0.55)
			var roof := Color(0.80, 0.42, 0.30)
			var wood := Color(0.40, 0.27, 0.16)
			_arch_mass(k, -0.6, 0.6, 0.0, 0.72, 0.0, 0.18, 0.3, 0.5, stone, Kit.STONE, dark)
			_arch_ring(k, 0.0, 0.3, 0.18, 0.05, 0.5, 0.012, dark, Kit.STONE)
			_gate_doors(k, 0.0, 0.3, 0.18, 0.0, wood)
			_bx(k, -0.6, 0.6, 0.0, 0.07, -0.26, 0.26, dark, Kit.STONE)
			# inscription band and a pediment-like attic
			_bx(k, -0.2, 0.2, 0.62, 0.7, 0.252, 0.262, Color(0.9, 0.78, 0.4), Kit.GOLD)
			_bx(k, -0.24, 0.24, 0.72, 0.78, -0.26, 0.26, dark, Kit.STONE)
			for s: float in [-1.0, 1.0]:
				_merlons(k, 3, -0.22, 0.22, 0.78, s * 0.22, 0.1, 0.05, 0.55, stone, Kit.STONE, "rect", dark, Kit.STONE)
			for x: float in [-0.42, 0.42]:   # flanking towers
				k.box(Vector3(x, 0, 0), Vector3(0.36, 1.08, 0.6), stone, Kit.STONE)
				k.box(Vector3(x, 0.55, 0), Vector3(0.38, 0.025, 0.62), dark, Kit.STONE)
				k.box(Vector3(x, 1.08, 0), Vector3(0.4, 0.05, 0.64), dark, Kit.STONE)
				k.window(Vector3(x, 0.85, 0.3015), 0.0, 0.08, 0.16, dark, "arch")
				k.window(Vector3(x, 0.3, 0.3015), 0.0, 0.07, 0.14, dark, "arch")
				k.window(Vector3(x + (0.1 if x > 0 else -0.1) * 0 + (0.1925 if x > 0 else -0.1925), 0.8, 0.0), PI / 2.0 if x > 0 else -PI / 2.0, 0.07, 0.14, dark, "arch")
				k.hip_roof(Vector3(x, 1.13, 0), 0.38, 0.6, 0.3, 0.03, 0.03, roof, Kit.OWNER_ROOF)
				k.banner(Vector3(x, 1.38, 0), 0.34, 0.2)
		"northern":
			var stone := Color(0.60, 0.59, 0.56)
			var dark := Color(0.50, 0.49, 0.47)
			var iron := Color(0.18, 0.18, 0.2)
			var wood := Color(0.40, 0.27, 0.16)
			_arch_mass(k, -0.45, 0.45, 0.0, 0.88, 0.0, 0.15, 0.3, 0.46, stone, Kit.STONE, dark)
			_arch_ring(k, 0.0, 0.3, 0.15, 0.04, 0.46, 0.012, dark, Kit.STONE)
			_gate_doors(k, 0.0, 0.3, 0.15, -0.05, wood)
			# portcullis, raised most of the way
			for i in 5:
				var x := -0.12 + i * 0.06
				var top := 0.3 + sqrt(maxf(0.0, 0.15 * 0.15 - x * x)) - 0.01
				k.box(Vector3(x, 0.3, 0.17), Vector3(0.016, top - 0.3, 0.016), iron, Kit.DARK)
			for y: float in [0.34, 0.41]:
				k.box(Vector3(0, y, 0.17), Vector3(0.25, 0.016, 0.016), iron, Kit.DARK)
			_bx(k, -0.45, 0.45, 0.76, 0.84, -0.25, 0.27, dark, Kit.STONE)   # machicolation course
			for s: float in [-1.0, 1.0]:
				_merlons(k, 4, -0.4, 0.4, 0.88, s * 0.215, 0.14, 0.06, 0.55, stone, Kit.STONE, "rect", dark, Kit.STONE)
			k.box(Vector3(0, 0.84, 0), Vector3(0.8, 0.04, 0.4), Color(0.45, 0.42, 0.38), Kit.EARTH)
			k.window(Vector3(0, 0.62, 0.2315), 0.0, 0.06, 0.12, dark, "arch")
			_hanging(k, Vector3(0, 0.56, 0.2325), 0.1, 0.2)
			for x: float in [-0.4, 0.4]:   # round flanking towers
				k.frustum(Vector3(x, 0, 0), 0.23, 0.205, 1.0, stone, Kit.STONE, 14, false)
				k.frustum(Vector3(x, 0, 0), 0.25, 0.23, 0.1, dark, Kit.STONE, 14, false)
				k.frustum(Vector3(x, 1.0, 0), 0.205, 0.255, 0.08, dark, Kit.STONE, 14, false)
				k.frustum(Vector3(x, 1.08, 0), 0.255, 0.255, 0.03, dark, Kit.STONE, 14)
				for i in 10:
					var a := i * TAU / 10.0
					k.box(Vector3(x + cos(a) * 0.23, 1.1, sin(a) * 0.23), Vector3(0.05, 0.1, 0.1), stone, Kit.STONE, -a)
				k.frustum(Vector3(x, 1.1, 0), 0.215, 0.0, 0.46, Color(0.80, 0.42, 0.30), Kit.OWNER_ROOF, 14)
				for a: float in [0.0, PI / 2.0, -PI / 2.0]:
					_slit(k, Vector3(x + sin(a) * 0.2, 0.7, cos(a) * 0.2) + Vector3(sin(a), 0, cos(a)) * 0.0, a, 0.028, 0.14)
				k.banner(Vector3(x, 1.5, 0), 0.26, 0.2)
		"mud":
			var blue := Color(0.10, 0.27, 0.58)
			var deep := Color(0.07, 0.19, 0.44)
			var gold := Color(0.90, 0.74, 0.30)
			var mud := Color(0.78, 0.64, 0.45)
			var lite := Color(0.86, 0.74, 0.56)
			var wood := Color(0.40, 0.27, 0.16)
			# brick base, blue glazed upper works (the Ishtar gate)
			_arch_mass(k, -0.6, 0.6, 0.0, 0.34, 0.0, 0.18, 0.28, 0.6, mud, Kit.MUDBRICK, mud.darkened(0.2))
			_bx(k, -0.6, -0.18, 0.34, 0.9, -0.3, 0.3, blue, Kit.PAINT)
			_bx(k, 0.18, 0.6, 0.34, 0.9, -0.3, 0.3, blue, Kit.PAINT)
			for i in 8:
				var a0 := PI * i / 8.0
				var a1 := PI * (i + 1) / 8.0
				var x0 := cos(a0) * 0.18
				var x1 := cos(a1) * 0.18
				var y0 := 0.28 + sin(a0) * 0.18
				var y1 := 0.28 + sin(a1) * 0.18
				for z: float in [-0.3, 0.3]:
					k.quad(Vector3(x1, y1, z), Vector3(x0, y0, z), Vector3(x0, 0.9, z), Vector3(x1, 0.9, z), blue, Kit.PAINT,
						Vector3(0, 0.8, 0.0))
			_arch_ring(k, 0.0, 0.28, 0.18, 0.04, 0.6, 0.012, gold, Kit.PAINT)
			_gate_doors(k, 0.0, 0.28, 0.18, 0.0, wood)
			# bands of gold and rows of relief animals
			for y: float in [0.4, 0.6, 0.82]:
				for s: float in [-1.0, 1.0]:
					for z: float in [-1.0, 1.0]:
						_bx(k, s * 0.18 if s > 0 else -0.6, 0.6 if s > 0 else -0.18, y, y + 0.025, z * 0.3 - 0.006, z * 0.3 + 0.006, gold, Kit.PAINT)
			for row: float in [0.47, 0.67]:
				for i in 6:
					var x := 0.22 + i * 0.065
					for s: float in [-1.0, 1.0]:
						k.box(Vector3(s * x, row, 0.301), Vector3(0.035, 0.07, 0.012), Color(0.93, 0.85, 0.6), Kit.PAINT)
						k.box(Vector3(s * x, row + 0.05, 0.301), Vector3(0.015, 0.03, 0.012), Color(0.93, 0.85, 0.6), Kit.PAINT)
			# stepped central crown and tower tops
			_bx(k, -0.18, 0.18, 0.9, 0.96, -0.3, 0.3, deep, Kit.PAINT)
			for x: float in [-0.4, 0.4]:
				k.box(Vector3(x, 0.9, 0), Vector3(0.42, 0.06, 0.62), gold, Kit.PAINT)
				k.box(Vector3(x, 0.96, 0), Vector3(0.36, 0.3, 0.56), blue, Kit.PAINT)
				for y: float in [0.0]:
					k.box(Vector3(x, 1.26, 0), Vector3(0.4, 0.04, 0.6), gold, Kit.PAINT)
				for i in 3:
					for s: float in [-1.0, 1.0]:
						var cx := x + (i - 1) * 0.12
						k.box(Vector3(cx, 1.3, s * 0.26), Vector3(0.08, 0.07, 0.06), deep, Kit.PAINT)
						k.box(Vector3(cx, 1.37, s * 0.26), Vector3(0.04, 0.05, 0.06), gold, Kit.PAINT)
				k.window(Vector3(x, 1.12, 0.2815), 0.0, 0.07, 0.14, gold, "arch")
				k.banner(Vector3(x, 1.3, 0), 0.34, 0.22)
			for i in 5:
				k.box(Vector3(-0.15 + i * 0.075, 0.96, 0.27), Vector3(0.05, 0.06, 0.06), deep, Kit.PAINT)
		"south_asian":
			var brick := Color(0.70, 0.40, 0.30)
			var stone := Color(0.86, 0.76, 0.60)
			var white := Color(0.94, 0.91, 0.84)
			var wood := Color(0.40, 0.27, 0.16)
			var gold := Color(0.9, 0.75, 0.25)
			_arch_mass(k, -0.42, 0.42, 0.0, 0.8, 0.0, 0.19, 0.26, 0.5, brick, Kit.BRICK, brick.darkened(0.25), 1.5, 10)
			_arch_ring(k, 0.0, 0.26, 0.19, 0.05, 0.5, 0.012, stone, Kit.STONE, 1.5, 10)
			_gate_doors(k, 0.0, 0.26, 0.19, 0.0, wood, 1.5)
			_bx(k, -0.42, 0.42, 0.0, 0.07, -0.27, 0.27, stone, Kit.STONE)
			_bx(k, -0.42, 0.42, 0.8, 0.87, -0.27, 0.27, stone, Kit.STONE)   # cornice
			for s: float in [-1.0, 1.0]:
				for i in 6:
					var x := -0.3 + i * 0.12
					k.wedge(Vector3(x, 0.87, s * 0.22), 0.05, 0.08, 0.09, stone, Kit.STONE, PI / 2.0)
			# jharokha balcony over the arch and little jali windows
			k.box(Vector3(0, 0.6, 0.25), Vector3(0.26, 0.04, 0.1), stone, Kit.STONE)
			_lat(k, Vector3(0, 0.72, 0.252), 0.0, 0.1, 0.1, stone)
			k.box(Vector3(0, 0.74, 0.25), Vector3(0.18, 0.025, 0.08), stone, Kit.STONE)
			for x: float in [-0.4, 0.4]:   # octagonal bastions carrying chhatris
				k.frustum(Vector3(x, 0, 0), 0.22, 0.2, 1.0, brick, Kit.BRICK, 8, false)
				k.frustum(Vector3(x, 0, 0), 0.24, 0.22, 0.08, stone, Kit.STONE, 8, false)
				k.frustum(Vector3(x, 1.0, 0), 0.2, 0.24, 0.06, stone, Kit.STONE, 8, false)
				k.frustum(Vector3(x, 1.06, 0), 0.24, 0.24, 0.03, stone, Kit.STONE, 8)
				for i in 4:
					var a := PI / 4.0 + i * PI / 2.0
					k.column(Vector3(x + cos(a) * 0.13, 1.09, sin(a) * 0.13), 0.02, 0.26, stone)
				k.frustum(Vector3(x, 1.35, 0), 0.19, 0.17, 0.035, stone, Kit.STONE, 8)
				k.dome(Vector3(x, 1.385, 0), 0.15, white, Kit.PLASTER, 1.0, 4, 12, true)
				k.frustum(Vector3(x, 1.53, 0), 0.012, 0.0, 0.1, gold, Kit.GOLD, 6)
				_slit(k, Vector3(x, 0.62, 0.2), 0.0, 0.035, 0.16)
				k.banner(Vector3(x, 1.06, 0.12), 0.3, 0.18)
			k.banner(Vector3(0, 0.87, 0), 0.3, 0.18)
		"steppe":
			var wood := Color(0.50, 0.37, 0.24)
			var dk := Color(0.40, 0.29, 0.19)
			var door := Color(0.46, 0.32, 0.2)
			for s: float in [-1.0, 1.0]:   # palisade stubs either side
				for i in 4:
					var x := s * (0.34 + i * 0.09)
					var tall := 0.62 + (0.08 if i % 2 == 0 else 0.0)
					var z := 0.03 if i % 2 == 0 else -0.03
					k.frustum(Vector3(x, 0, z), 0.052, 0.048, tall, wood, Kit.TIMBER, 6, false)
					k.frustum(Vector3(x, tall, z), 0.048, 0.0, 0.12, wood, Kit.TIMBER, 6)
				# the great gate posts, carved caps
				var px := s * 0.27
				k.frustum(Vector3(px, 0, 0), 0.075, 0.07, 1.05, dk, Kit.TIMBER, 8, false)
				k.frustum(Vector3(px, 1.05, 0), 0.09, 0.0, 0.16, Color(0.78, 0.60, 0.25), Kit.GOLD, 8)
				k.box(Vector3(px, 0.4, 0.075), Vector3(0.1, 0.03, 0.02), Color(0.6, 0.15, 0.1), Kit.PAINT)
				k.box(Vector3(px, 0.7, 0.075), Vector3(0.1, 0.03, 0.02), Color(0.6, 0.15, 0.1), Kit.PAINT)
				# door leaves swung open
				k.push(Kit.at(Vector3(s * 0.2, 0, 0.08), s * 1.1))
				k.box(Vector3(-s * 0.1, 0, 0), Vector3(0.2, 0.7, 0.035), door, Kit.TIMBER)
				k.box(Vector3(-s * 0.1, 0.3, 0.02), Vector3(0.2, 0.025, 0.015), dk, Kit.TIMBER)
				k.pop()
			k.box(Vector3(0, 0.72, 0), Vector3(0.7, 0.08, 0.14), dk, Kit.TIMBER)   # lintel beam
			k.box(Vector3(0, 0.62, 0), Vector3(0.45, 0.1, 0.1), Color(0.05, 0.04, 0.04), Kit.DARK)
			# watch platform and a little peaked roof on top
			k.box(Vector3(0, 0.8, 0), Vector3(0.64, 0.04, 0.34), wood, Kit.TIMBER)
			for i in 6:
				var x := -0.28 + i * 0.112
				k.box(Vector3(x, 0.84, 0.16), Vector3(0.03, 0.14, 0.03), wood, Kit.TIMBER)
				k.box(Vector3(x, 0.84, -0.16), Vector3(0.03, 0.14, 0.03), wood, Kit.TIMBER)
			_bx(k, -0.3, 0.3, 0.96, 0.99, 0.15, 0.17, dk, Kit.TIMBER)
			for x: float in [-0.22, 0.22]:
				k.box(Vector3(x, 0.84, 0), Vector3(0.035, 0.35, 0.035), wood, Kit.TIMBER)
			k.gable_roof(Vector3(0, 1.17, 0), 0.5, 0.26, 0.2, 0.1, 0.03, Color(0.74, 0.50, 0.30), Kit.OWNER_ROOF,
				dk, Kit.TIMBER, 0.0, 0.03)
			for x: float in [-0.55, 0.55]:
				k.banner(Vector3(x, 0, 0.1), 0.95, 0.24)


# ---------------------------------------------------------------------------------------------
# test runs: four segments in a gentle curve with a tower at a joint and a gate in the line
# ---------------------------------------------------------------------------------------------

static func _run(k: Kit, fam: String) -> void:
	var pos := Vector3(-2.2, 0, 0.8)
	var yaw := 0.0
	var items: Array = ["wall", "wall", "tower", "wall", "gate", "wall", "wall", "tower", "wall"]
	var turns := {1: 0.18, 2: 0.0, 3: 0.3, 4: 0.0, 5: -0.2, 6: -0.3}
	var idx := 0
	for it in items:
		var dir := Vector3(cos(yaw), 0, -sin(yaw))
		match it:
			"wall":
				k.push(Kit.at(pos + dir * 0.5, yaw))
				_wall(k, fam)
				k.pop()
				pos += dir
				yaw += float(turns.get(idx, 0.0))
			"gate":
				k.push(Kit.at(pos + dir * 0.5, yaw))
				_gate(k, fam)
				k.pop()
				pos += dir
			"tower":
				k.push(Kit.at(pos, yaw))
				_tower(k, fam)
				k.pop()
		idx += 1
