## Roman Republican buildings for the 3D city of Rome (phase R5 groundwork).
##
## Architecturally grounded model kit: temples by their real forms, public buildings,
## infrastructure and houses. 1.0 = about 10 m. Models stand on y = 0, centred, facing +z.
## Republican Rome was NOT a marble city: tufa (cappellaccio, Grotta Oscura), peperino and
## travertine, concrete faced in stucco; marble only from about 146 BC (Metellus' temple, Vell.
## Pat. 1.11.5; Hercules Victor c. 120 BC). Marble variants are named `_marble`.
##
## Sources used for proportions: Vitruvius, De architectura 2 (materials; 2.8 walls, opus
## incertum/reticulatum), 3.3 (intercolumniation: eustyle 2.25 d), 3.5 (Ionic), 4.1 (Corinthian
## capital height = d), 4.7 (Tuscan temple), 4.8 (round temples), 6.3 and 6.5 (atrium house),
## 8.6 (aqueducts); Livy, Pliny NH 36, Frontinus; Platner-Ashby, Topographical Dictionary
## of Ancient Rome (1929), s.v. entries named above each builder.
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")

# --- palette (tufa and stucco, not marble) ------------------------------------------------------
const CAPPELLACCIO := Color(0.55, 0.49, 0.40)   ## grey-brown archaic tufa (Capitoline, 6th c.)
const GROTTA := Color(0.76, 0.65, 0.42)         ## yellow Grotta Oscura tufa (Veii quarries, after 396)
const PEPERINO := Color(0.60, 0.56, 0.50)       ## grey peperino (Gabii/Alban), 2nd c.
const TRAVERT := Color(0.88, 0.83, 0.72)        ## travertine (Tibur), from the 2nd c.
const MARBLE := Color(0.93, 0.91, 0.86)         ## only from c. 146 BC
const STUCCO := Color(0.93, 0.88, 0.76)
const STUCCO_W := Color(0.95, 0.93, 0.88)
const TERRA := Color(0.72, 0.36, 0.22)          ## terracotta roof tiles and revetments
const TERRA_L := Color(0.84, 0.52, 0.32)
const RED := Color(0.66, 0.20, 0.15)            ## Pompeian red / minium
const OCHRE := Color(0.82, 0.62, 0.30)
const BLUE := Color(0.22, 0.36, 0.56)
const BRICK_C := Color(0.66, 0.38, 0.27)
const WOOD := Color(0.46, 0.31, 0.18)
const DWOOD := Color(0.30, 0.20, 0.12)
const BRONZE := Color(0.62, 0.45, 0.22)
const DARK_C := Color(0.07, 0.05, 0.04)
const GREEN := Color(0.30, 0.46, 0.22)
const EARTH_C := Color(0.50, 0.40, 0.28)
const GRASS_C := Color(0.40, 0.55, 0.28)
const WATER_C := Color(0.55, 0.75, 0.85)


# --- helpers ----------------------------------------------------------------------------------


## A box from corner extents (x0..x1, y0..y1, z0..z1).
static func _b(k: Kit, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, c: Color, m: int) -> void:
	k.box(Vector3((x0 + x1) * 0.5, y0, (z0 + z1) * 0.5), Vector3(absf(x1 - x0), y1 - y0, absf(z1 - z0)), c, m)


## Four boxes forming a rectangular ring (hx, hz half-sizes of the outer edge, wall thickness t).
static func _ring(k: Kit, cx: float, cz: float, hx: float, hz: float, t: float, y0: float, y1: float, c: Color, m: int) -> void:
	_b(k, cx - hx, y0, cz + hz - t, cx + hx, y1, cz + hz, c, m)
	_b(k, cx - hx, y0, cz - hz, cx + hx, y1, cz - hz + t, c, m)
	_b(k, cx - hx, y0, cz - hz + t, cx - hx + t, y1, cz + hz - t, c, m)
	_b(k, cx + hx - t, y0, cz - hz + t, cx + hx, y1, cz + hz - t, c, m)


## A fluted shaft by facets: alternate vertices pulled in, so each flute catches its own light.
static func _shaft(k: Kit, foot: Vector3, r0: float, r1: float, h: float, c: Color, m: int, flutes := 8, sides := 8) -> void:
	if flutes <= 0:
		k.frustum(foot, r0, r1, h, c, m, sides, false)
		return
	k.push(Kit.at(foot))
	var n := flutes * 2
	var ctr := Vector3(0, h * 0.5, 0)
	for i in n:
		var a0 := i * TAU / n
		var a1 := (i + 1) * TAU / n
		var f0 := 1.0 if i % 2 == 0 else 0.86
		var f1 := 1.0 if (i + 1) % 2 == 0 else 0.86
		var b0 := Vector3(cos(a0) * r0 * f0, 0, sin(a0) * r0 * f0)
		var b1 := Vector3(cos(a1) * r0 * f1, 0, sin(a1) * r0 * f1)
		var t0 := Vector3(cos(a0) * r1 * f0, h, sin(a0) * r1 * f0)
		var t1 := Vector3(cos(a1) * r1 * f1, h, sin(a1) * r1 * f1)
		k.quad(b0, b1, t1, t0, c, m, ctr)
	k.pop()


## A cylinder lying along z (volutes), centred on `c`.
static func _disc_z(k: Kit, c: Vector3, r: float, len: float, col: Color, m: int, sides := 8) -> void:
	k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), c + Vector3(0, 0, -len * 0.5)))
	k.frustum(Vector3.ZERO, r, r, len, col, m, sides)
	k.pop()


## A cylinder lying along x, centred on `c`.
static func _tube_x(k: Kit, c: Vector3, r: float, len: float, col: Color, m: int, sides := 8) -> void:
	k.push(Transform3D(Basis(Vector3(0, 0, 1), -PI / 2.0), c + Vector3(-len * 0.5, 0, 0)))
	k.frustum(Vector3.ZERO, r, r, len, col, m, sides)
	k.pop()


## Column diameter as a fraction of the height (Vitruvius: Tuscan 1/7, Doric 1/7, Ionic 1/9,
## Corinthian 1/10, capital included).
static func _dia(h: float, order: String) -> float:
	match order:
		"ionic":
			return h / 9.0
		"corinthian":
			return h / 10.0
	return h / 7.0


## A column of total height `h` in an order: "tuscan" (Vitruvius 4.7: base 1/2 d, shaft tapering by
## a quarter, capital 1/2 d with abacus = d), "doric", "ionic" (attic base, volutes, 3.5) or
## "corinthian" (bell capital = d, 4.1). `detail` 0 = cheap (engaged columns), 1 = full.
static func _col(k: Kit, foot: Vector3, h: float, order: String, c: Color, m := Kit.STONE, detail := 1) -> void:
	var d := _dia(h, order)
	var r := d * 0.5
	var f := foot
	var sd := 8 if detail > 0 else 6
	match order:
		"tuscan", "doric":
			var bh := 0.0
			if order == "tuscan":
				bh = 0.5 * d
				k.frustum(f, r * 1.2, r * 1.2, bh * 0.5, c, m, sd, false)
				k.frustum(f + Vector3(0, bh * 0.5, 0), r * 1.1, r * 0.98, bh * 0.5, c, m, sd, false)
			var cap := 0.5 * d
			var sh := h - bh - cap
			var top := 0.75 if order == "tuscan" else 0.8
			_shaft(k, f + Vector3(0, bh, 0), r, r * top, sh, c, m, 0 if (order == "tuscan" or detail == 0) else 6, sd)
			var ty := bh + sh
			k.frustum(f + Vector3(0, ty, 0), r * top, r * top, cap * 0.34, c, m, sd, false)
			k.frustum(f + Vector3(0, ty + cap * 0.34, 0), r * top, r * 1.0, cap * 0.33, c, m, sd, false)
			k.box(f + Vector3(0, ty + cap * 0.67, 0), Vector3(d * 1.02, cap * 0.33, d * 1.02), c, m)
		"ionic":
			var bh := 0.5 * d
			k.box(f, Vector3(d * 1.3, bh * 0.36, d * 1.3), c, m)
			k.frustum(f + Vector3(0, bh * 0.36, 0), r * 1.3, r * 1.1, bh * 0.4, c, m, sd, false)
			k.frustum(f + Vector3(0, bh * 0.76, 0), r * 1.0, r * 1.0, bh * 0.24, c, m, sd, false)
			var cap := 0.36 * d
			var sh := h - bh - cap
			_shaft(k, f + Vector3(0, bh, 0), r, r * 0.86, sh, c, m, 0 if detail == 0 else 6, sd)
			var ty := bh + sh
			k.frustum(f + Vector3(0, ty, 0), r * 0.86, r * 0.95, cap * 0.2, c, m, sd, false)
			k.box(f + Vector3(0, ty + cap * 0.2, 0), Vector3(d * 1.5, cap * 0.5, d * 1.0), c, m)
			if detail > 0:
				for s in [-1.0, 1.0]:
					_disc_z(k, f + Vector3(s * d * 0.62, ty + cap * 0.45, 0), cap * 0.28, d * 1.05, c.darkened(0.06), m, 8)
			k.box(f + Vector3(0, ty + cap * 0.7, 0), Vector3(d * 1.55, cap * 0.3, d * 1.25), c, m)
		_:   # corinthian
			var bh := 0.5 * d
			k.box(f, Vector3(d * 1.3, bh * 0.36, d * 1.3), c, m)
			k.frustum(f + Vector3(0, bh * 0.36, 0), r * 1.3, r * 1.1, bh * 0.4, c, m, sd, false)
			k.frustum(f + Vector3(0, bh * 0.76, 0), r * 1.0, r * 1.0, bh * 0.24, c, m, sd, false)
			var sh := h - bh - d
			_shaft(k, f + Vector3(0, bh, 0), r, r * 0.86, sh, c, m, 0 if detail == 0 else 6, sd)
			var ty := bh + sh
			if detail == 0:
				k.frustum(f + Vector3(0, ty, 0), r * 0.86, r * 1.25, d * 0.86, c, m, sd, false)
			else:
				k.frustum(f + Vector3(0, ty, 0), r * 0.86, r * 1.0, d * 0.34, c.darkened(0.08), m, sd, false)
				k.frustum(f + Vector3(0, ty + d * 0.34, 0), r * 0.95, r * 1.15, d * 0.3, c, m, sd, false)
				k.frustum(f + Vector3(0, ty + d * 0.64, 0), r * 1.1, r * 1.28, d * 0.22, c.darkened(0.05), m, sd, false)
			k.box(f + Vector3(0, ty + d * 0.86, 0), Vector3(d * 1.34, d * 0.14, d * 1.34), c, m)


## An opening in a wall plane (front faces +z), an arch between x0 and x1 springing at ys, wall
## above it up to yt, thickness z0..z1. `ratio` < 1 makes a segmental arch. Piers are separate.
static func _arch(k: Kit, x0: float, x1: float, ys: float, yt: float, z0: float, z1: float, c: Color, m: int,
		segs := 6, front := true, back := true, ratio := 1.0, cin := Color(0, 0, 0, 0)) -> void:
	var rx := (x1 - x0) * 0.5
	var ry := rx * ratio
	var xc := (x0 + x1) * 0.5
	var zm := (z0 + z1) * 0.5
	var o := Vector3(xc, ys + ry * 0.4, zm)
	var intra := c.darkened(0.12) if cin.a == 0.0 else cin
	for i in segs:
		var a0 := PI * i / segs
		var a1 := PI * (i + 1) / segs
		var p0x := xc + rx * cos(a0)
		var p1x := xc + rx * cos(a1)
		var p0y := ys + ry * sin(a0)
		var p1y := ys + ry * sin(a1)
		if front:
			k.quad(Vector3(p0x, p0y, z1), Vector3(p1x, p1y, z1), Vector3(p1x, yt, z1), Vector3(p0x, yt, z1), c, m, Vector3((p0x + p1x) / 2, yt, zm))
		if back:
			k.quad(Vector3(p0x, p0y, z0), Vector3(p1x, p1y, z0), Vector3(p1x, yt, z0), Vector3(p0x, yt, z0), c, m, Vector3((p0x + p1x) / 2, yt, zm))
		var cen := Vector3((p0x + p1x) / 2, (p0y + p1y) / 2, zm)
		k.quad(Vector3(p0x, p0y, z0), Vector3(p1x, p1y, z0), Vector3(p1x, p1y, z1), Vector3(p0x, p0y, z1), intra, m, cen + (cen - o))


## Voussoir ring (alternating blocks) on the front plane z, between radii r0 and r1.
static func _voussoirs(k: Kit, xc: float, ys: float, r0: float, r1: float, z: float, n: int, c: Color, m: int, depth := 0.0) -> void:
	for i in n:
		var a0 := PI * i / n
		var a1 := PI * (i + 1) / n
		var col := c if i % 2 == 0 else c.darkened(0.1)
		var p := [Vector3(xc + cos(a0) * r0, ys + sin(a0) * r0, z), Vector3(xc + cos(a1) * r0, ys + sin(a1) * r0, z),
			Vector3(xc + cos(a1) * r1, ys + sin(a1) * r1, z), Vector3(xc + cos(a0) * r1, ys + sin(a0) * r1, z)]
		k.quad(p[0], p[1], p[2], p[3], col, m, Vector3(xc, ys, z - 1.0))
		if depth > 0.0:   # the soffit, so the ring reads as a thick arch
			var q: Array = []
			for v in p:
				q.append(v + Vector3(0, 0, -depth))
			k.quad(p[0], p[1], q[1], q[0], col.darkened(0.2), m, Vector3(xc, ys + r0 * 2.0, z - depth * 0.5))


## A stair across the front (+z) of a platform: steps rising to `top`, `n` of them, tread `t`.
static func _stair(k: Kit, cx: float, w: float, z_edge: float, top: float, n: int, t: float, c: Color, m: int) -> void:
	for j in n:
		var hh := (j + 1) * top / (n + 1)
		_b(k, cx - w / 2, 0.0, z_edge, cx + w / 2, hh, z_edge + (n - j) * t, c, m)


## A gabled roof whose ridge runs along z (front gable faces +z). `len` along the ridge, `span` across.
static func _gable_z(k: Kit, foot: Vector3, len: float, span: float, rise: float, over: float, roof: Color, wall: Color, wmat: int, thick := 0.035) -> void:
	k.gable_roof(foot, len, span, rise, over, thick, roof, Kit.TILE, wall, wmat, PI / 2.0)


## A gabled roof whose ridge runs along x.
static func _gable_x(k: Kit, foot: Vector3, len: float, span: float, rise: float, over: float, roof: Color, wall: Color, wmat: int, thick := 0.03) -> void:
	k.gable_roof(foot, len, span, rise, over, thick, roof, Kit.TILE, wall, wmat, 0.0)


## A tilted slab: `p` = four points of the top surface, thickness `thick` hanging below.
static func _slab(k: Kit, p: Array, thick: float, col: Color, mat: int) -> void:
	var dn := Vector3(0, -thick, 0)
	var c: Vector3 = (p[0] + p[1] + p[2] + p[3]) / 4.0 + dn * 0.5
	k.quad(p[0], p[1], p[2], p[3], col, mat, c)
	var q: Array = [p[0] + dn, p[1] + dn, p[2] + dn, p[3] + dn]
	k.quad(q[0], q[1], q[2], q[3], col.darkened(0.35), mat, c)
	for i in 4:
		var j := (i + 1) % 4
		k.quad(p[i], p[j], q[j], q[i], col.darkened(0.2), mat, c)


## Four sloping slabs round a hole: outer half-sizes (ox, oz) at height yo, inner (ix, iz) at yi.
## yi < yo = compluvium (rain falls inward to the impluvium); yi > yo = a pent roof round a court.
static func _frame_roof(k: Kit, centre: Vector3, ox: float, oz: float, ix: float, iz: float,
		yo: float, yi: float, thick: float, col: Color, mat := Kit.TILE) -> void:
	k.push(Kit.at(centre))
	_slab(k, [Vector3(-ox, yo, oz), Vector3(ox, yo, oz), Vector3(ix, yi, iz), Vector3(-ix, yi, iz)], thick, col, mat)
	_slab(k, [Vector3(ox, yo, -oz), Vector3(-ox, yo, -oz), Vector3(-ix, yi, -iz), Vector3(ix, yi, -iz)], thick, col, mat)
	_slab(k, [Vector3(ox, yo, oz), Vector3(ox, yo, -oz), Vector3(ix, yi, -iz), Vector3(ix, yi, iz)], thick, col, mat)
	_slab(k, [Vector3(-ox, yo, -oz), Vector3(-ox, yo, oz), Vector3(-ix, yi, iz), Vector3(-ix, yi, -iz)], thick, col, mat)
	k.pop()


## A terracotta antefix (one palmette triangle) standing on an eave edge, facing `yaw`.
static func _antefix(k: Kit, p: Vector3, yaw: float, s: float) -> void:
	k.push(Kit.at(p, yaw))
	k.tri(Vector3(-s * 0.5, 0, 0), Vector3(s * 0.5, 0, 0), Vector3(0, s * 1.2, 0), RED, Kit.PAINT, Vector3(0, s * 0.4, -1.0))
	k.pop()


## A ground pad (earth or paving) so a model never floats.
static func _pad(k: Kit, w: float, d: float, c := Color(0.62, 0.57, 0.46), m := Kit.EARTH, h := 0.02) -> void:
	k.bevel_box(Vector3.ZERO, Vector3(w, h, d), 0.008, c, m)


static func _tree(k: Kit, foot: Vector3, s: float) -> void:
	k.cylinder(foot, 0.018 * s, 0.14 * s, DWOOD, Kit.TIMBER, 5)
	k.dome(foot + Vector3(0, 0.1 * s, 0), 0.12 * s, GREEN, Kit.LEAF, 0.85, 3, 8)


static func _door(k: Kit, p: Vector3, yaw: float, w: float, h: float, frame: Color, leaf := Color(0.30, 0.20, 0.12)) -> void:
	k.door(p, yaw, w, h, frame, leaf)


# =============================================================================================
# TEMPLES
# =============================================================================================


## A moulded podium: a plinth, the body and a projecting cornice (Vitruvius 3.4.4-5: the podium
## is built up with plinth, die and cap). Spans x ±hx, z z0..z1, height ph.
static func _podium(k: Kit, hx: float, z0: float, z1: float, ph: float, c: Color, m: int) -> void:
	_b(k, -hx - 0.02, 0.0, z0 - 0.02, hx + 0.02, ph * 0.16, z1 + 0.02, c.darkened(0.08), m)
	_b(k, -hx, ph * 0.16, z0, hx, ph * 0.86, z1, c, m)
	_b(k, -hx - 0.03, ph * 0.86, z0 - 0.03, hx + 0.03, ph, z1 + 0.03, c.lightened(0.06), m)


## The Etrusco-Italic (Tuscan) temple, the form of Jupiter Capitolinus (dedicated 509 BC; Livy 1.55-56,
## Dion. Hal. 4.61; Platner-Ashby s.v. Aedes Iovis Optimi Maximi Capitolini: 53 x 62 m, six
## columns across the front, three ranks deep, triple cella). Proportions after Vitruvius 4.7:
## length : width = 6 : 5; the front half is the deep porch, the back half the cella, divided in
## ten parts: 3 + 4 + 3 (the central cella and two alae); columns one third of the width high,
## base diameter 1/7 of the height, taper by a quarter, base and capital 1/2 d; mutuli
## projecting a quarter of the column height; a low, wide-eaved timber roof. `archaic`:
## cappellaccio tufa, mud-brick and timber columns, painted terracotta (Plin. NH 35.157, the
## terracotta of Vulca); restored: Grotta Oscura tufa under white stucco (Capitolium after the
## fire of 83 BC was re-columned in marble, Plin. NH 36.45; that is the `_marble` form not modelled).
static func _tuscan(k: Kit, w: float, archaic: bool, nfront: int) -> void:
	var l := w * 1.2
	var h := w / 3.0
	var d := h / 7.0
	var ph := maxf(0.2, w * 0.085)
	var pod := CAPPELLACCIO if archaic else GROTTA
	var colc := Color(0.50, 0.36, 0.22) if archaic else STUCCO_W
	var colm := Kit.TIMBER if archaic else Kit.PLASTER
	var wallc := Color(0.80, 0.68, 0.52) if archaic else STUCCO_W
	var wallm := Kit.MUDBRICK if archaic else Kit.PLASTER
	var hx := w * 0.46
	k.push(Kit.at(Vector3(0, 0, -0.06 * w)))
	_podium(k, w / 2.0, -l / 2.0, l / 2.0, ph, pod, Kit.STONE)
	var nst := maxi(3, int(ph / 0.05))
	_stair(k, 0.0, w * 0.46, l / 2.0 + 0.03, ph, nst, 0.07, pod.lightened(0.05), Kit.STONE)
	# the cella: three chambers in the back half, 3:4:3 (Vitruvius 4.7.1); we see the facade
	_b(k, -hx, ph, -l / 2.0 + 0.12, hx, ph + h, 0.0, wallc, wallm)
	var drs := [[0.0, 0.14 * w], [-0.3 * w, 0.085 * w], [0.3 * w, 0.085 * w]]
	for dr in drs:
		_door(k, Vector3(dr[0], ph, 0.002), 0.0, dr[1], h * 0.52, colc, DWOOD)
	# columns: front row of 4 (aligned with the antae and the walls between the cellae) or 6
	var xs: Array = [-0.46, -0.2, 0.2, 0.46] if nfront == 4 else [-0.46, -0.31, -0.155, 0.155, 0.31, 0.46]
	var zf := l / 2.0 - 1.6 * d
	var rows: Array = [zf, zf * 0.55]
	for ri in rows.size():
		for xf in xs:
			_col(k, Vector3(float(xf) * w, ph, float(rows[ri])), h, "tuscan", colc, colm, 1)
	for s in [-1.0, 1.0]:   # a third rank on the flanks (the Capitolium had three ranks on the front)
		if nfront == 6:
			_col(k, Vector3(s * 0.46 * w, ph, zf * 0.1), h, "tuscan", colc, colm, 1)
	# entablature: paired timber beams, a painted terracotta frieze and the projecting mutuli
	var ex := hx + d * 0.6
	var ez := l / 2.0 - 0.02
	var ya := ph + h
	_ring(k, 0.0, 0.0, ex, ez, d * 1.1, ya, ya + 0.9 * d, DWOOD, Kit.TIMBER)
	_ring(k, 0.0, 0.0, ex + 0.015, ez + 0.015, d * 1.1, ya + 0.9 * d, ya + 1.7 * d, TERRA_L if archaic else RED, Kit.PAINT)
	var over := 0.25 * h
	var nm := int(ex * 2.0 / (2.2 * d))
	for i in nm + 1:
		var x := -ex + 2.0 * ex * i / nm
		for sz in [-1.0, 1.0]:
			k.box(Vector3(x, ya + 1.2 * d, sz * (ez + over * 0.5)), Vector3(0.5 * d, 0.5 * d, over), DWOOD, Kit.TIMBER)
	# the wide, low roof, and its terracotta antefixes and acroterion
	var span := ex * 2.0
	var rise := 0.17 * (span + 2.0 * over)
	var ry := ya + 1.7 * d
	_gable_z(k, Vector3(0, ry, 0), ez * 2.0, span, rise, over, TERRA, Color(0.74, 0.45, 0.28) if archaic else STUCCO_W, Kit.PAINT, 0.05)
	var drop := over * rise / (span * 0.5)
	var n_af := int(ez * 2.0 / (2.5 * d))
	for i in n_af + 1:
		var z := -ez + 2.0 * ez * i / n_af
		_antefix(k, Vector3(span * 0.5 + over, ry - drop + 0.05, z), PI / 2.0, d * 0.8)
		_antefix(k, Vector3(-span * 0.5 - over, ry - drop + 0.05, z), -PI / 2.0, d * 0.8)
	var rz := ez + over * 0.6   # ridge end: the terracotta quadriga of Jupiter (Plin. NH 28.16)
	_b(k, -d, ry + rise, rz - 2.2 * d, d, ry + rise + 0.6 * d, rz, TERRA_L, Kit.PAINT)
	k.frustum(Vector3(0, ry + rise + 0.6 * d, rz - d), d * 0.35, d * 0.15, 2.2 * d, TERRA_L, Kit.PAINT, 6)
	for i in 4:
		_b(k, -1.0 * d + i * 0.5 * d, ry + rise + 0.6 * d, rz - 0.4 * d, -0.6 * d + i * 0.5 * d, ry + rise + 1.4 * d, rz, TERRA_L, Kit.PAINT)
	k.pop()


## Late-Republican pseudoperipteral temple on a high podium with a frontal stair (the Temple of
## Portunus, tetrastyle Ionic, c. 120-80 BC, travertine and tufa under stucco; the Temple of
## Hercules Musarum, the temple of Venus Genetrix style hexastyle Corinthian in the Forum;
## Platner-Ashby s.v. Aedes Portuni, Aedes Fortunae Virilis). Free columns in the porch, the
## cella walls with engaged half-columns on the sides and back, entablature all round.
## Eustyle spacing (Vitruvius 3.3.6: clear gap 2 1/4 d), column heights 9 d (Ionic, 3.5) and
## 10 d (Corinthian, 4.1), pediment rise = span / 9 (3.5.12; here a touch steeper).
static func _pseudo(k: Kit, n: int, order: String, mat_kind: String) -> void:
	var tetra := n == 4
	var d := 0.113 if tetra else 0.125
	var h := d * (9.0 if order == "ionic" else 10.0)
	var s := d * 3.25
	var bays := 5 if tetra else 6
	var pb := 2 if tetra else 3
	var zz := bays * 0.5 * s
	var xo := (n - 1) * 0.5 * s
	var ph := 0.3 * h
	var pod: Color
	var colc: Color
	var colm := Kit.PLASTER
	var wallc: Color
	var frc: Color
	match mat_kind:
		"marble":
			pod = MARBLE.darkened(0.04)
			colc = MARBLE
			colm = Kit.STONE
			wallc = MARBLE
			frc = MARBLE.darkened(0.06)
		"travertine":
			pod = TRAVERT
			colc = TRAVERT.lightened(0.04)
			colm = Kit.STONE
			wallc = STUCCO_W
			frc = STUCCO
		_:   # tufa under stucco
			pod = GROTTA
			colc = STUCCO_W
			wallc = STUCCO_W
			frc = RED
	var nst := maxi(4, int(ph / 0.05))
	var sl := nst * 0.07
	k.push(Kit.at(Vector3(0, 0, -(0.8 * d + sl) * 0.5)))
	_podium(k, xo + 2.4 * d, -(zz + 1.8 * d), zz + 2.6 * d, ph, pod, Kit.STONE)
	_stair(k, 0.0, xo * 2.0 + d * 1.5, zz + 2.6 * d + 0.03, ph, nst, 0.07, pod.lightened(0.05), Kit.STONE)
	# cella with its front wall at the porch depth
	var zc := zz - pb * s
	var wx := xo - 0.1 * d
	_b(k, -wx, ph, -zz, wx, ph + h, zc, wallc, Kit.PLASTER if mat_kind != "marble" else Kit.STONE)
	_door(k, Vector3(0, ph, zc + 0.002), 0.0, s * 0.62, h * 0.55, colc, DWOOD)
	# free columns of the porch: the full front row, and the flank columns of the second ranks
	for i in n:
		_col(k, Vector3(-xo + i * s, ph, zz), h, order, colc, colm, 1)
	for j in range(1, pb):
		for sx in [-1.0, 1.0]:
			_col(k, Vector3(sx * xo, ph, zz - j * s), h, order, colc, colm, 1)
	# engaged half-columns on the flanks and the back (pseudoperipteral)
	for j in range(pb, bays + 1):
		for sx in [-1.0, 1.0]:
			_col(k, Vector3(sx * xo, ph, zz - j * s), h, order, colc, colm, 0)
	for i in n:
		_col(k, Vector3(-xo + i * s, ph, -zz), h, order, colc, colm, 0)
	# entablature: architrave, frieze, cornice
	var ex := xo + 0.75 * d
	var ez := zz + 0.75 * d
	var ya := ph + h
	_ring(k, 0.0, 0.0, ex, ez, d * 1.0, ya, ya + 0.6 * d, colc, Kit.STONE)
	_ring(k, 0.0, 0.0, ex + 0.01, ez + 0.01, d * 0.9, ya + 0.6 * d, ya + 1.3 * d, frc, Kit.PAINT if mat_kind == "stucco" else Kit.STONE)
	_ring(k, 0.0, 0.0, ex + 0.35 * d, ez + 0.35 * d, d * 1.3, ya + 1.3 * d, ya + 1.8 * d, colc.darkened(0.04), Kit.STONE)
	# roof and pediments with acroteria
	var span := ex * 2.0 + 0.5 * d
	var rise := span / 6.5
	var ry := ya + 1.8 * d
	_gable_z(k, Vector3(0, ry, 0), (ez + 0.35 * d) * 2.0, span, rise, 0.1 * d, TERRA, wallc.darkened(0.04), Kit.PLASTER if mat_kind != "marble" else Kit.STONE, 0.03)
	for sz in [-1.0, 1.0]:
		var zf: float = sz * (ez + 0.35 * d)
		_b(k, -0.7 * d, ry + rise, zf - 0.4 * d, 0.7 * d, ry + rise + 0.9 * d, zf + 0.4 * d, TERRA_L, Kit.PAINT)
		for sx in [-1.0, 1.0]:
			_b(k, sx * span * 0.5 - 0.4 * d, ry, zf - 0.3 * d, sx * span * 0.5 + 0.4 * d, ry + 0.5 * d, zf + 0.3 * d, TERRA_L, Kit.PAINT)
	k.pop()


## Round temple (tholos): Vitruvius 4.8: a peripteral ring on a two-step stylobate, the cella
## wall set back a fifth of the diameter, the roof half the diameter high. `marble`: the
## Temple of Hercules Victor in the Forum Boarium (c. 120 BC, Pentelic marble, 20 Corinthian
## columns, c. 14.8 m across; Platner-Ashby s.v. Aedes Herculis Victoris); otherwise the
## Temple of Vesta in the Forum (Ovid, Fasti 6.265-282: round; Platner-Ashby s.v. Aedes Vestae):
## stuccoed tufa, Tuscan-style columns, a tiled conical roof.
static func _tholos(k: Kit, marble: bool) -> void:
	var rr := 0.75
	var rc := 0.63
	var rw := 0.45
	var n := 20
	var order := "corinthian" if marble else "tuscan"
	var d := 0.068
	var h := d * (10.0 if marble else 7.0)
	if not marble:
		d = 0.09
		h = d * 7.0
	var colc := MARBLE if marble else STUCCO_W
	var m := Kit.STONE if marble else Kit.PLASTER
	var pod := MARBLE.darkened(0.04) if marble else GROTTA
	k.frustum(Vector3.ZERO, rr, rr, 0.06, pod.darkened(0.06), Kit.STONE, 24)
	k.frustum(Vector3(0, 0.06, 0), rr - 0.07, rr - 0.07, 0.06, pod, Kit.STONE, 24)
	var y0 := 0.12
	k.frustum(Vector3(0, y0, 0), rw, rw, h, colc if marble else STUCCO, m, n, false)
	for i in n:
		var a := i * TAU / n
		_col(k, Vector3(cos(a) * rc, y0, sin(a) * rc), h, order, colc, m, 1 if (not marble or sin(a) > -0.3) else 0)
	var ya := y0 + h
	k.frustum(Vector3(0, ya, 0), rc + 0.6 * d, rc + 0.6 * d, 0.6 * d, colc, Kit.STONE, n)
	k.frustum(Vector3(0, ya + 0.6 * d, 0), rc + 0.62 * d, rc + 0.62 * d, 0.7 * d, RED if not marble else colc.darkened(0.06), Kit.PAINT if not marble else Kit.STONE, n)
	k.frustum(Vector3(0, ya + 1.3 * d, 0), rc + 0.95 * d, rc + 0.95 * d, 0.45 * d, colc, Kit.STONE, n)
	var roof_h := 0.5 * rr
	k.frustum(Vector3(0, ya + 1.75 * d, 0), rc + 1.0 * d, 0.0, roof_h, TERRA, Kit.TILE, n)
	k.dome(Vector3(0, ya + 1.75 * d + roof_h, 0), 0.05, BRONZE, Kit.GOLD, 0.9, 2, 8)
	_door(k, Vector3(0, y0, rw + 0.001), 0.0, 0.2, h * 0.55, colc, DWOOD)
	_stair(k, 0.0, 0.5, rr + 0.0, y0, 3, 0.05, pod.lightened(0.05), Kit.STONE)


# =============================================================================================
# DISPATCH
# =============================================================================================

const KINDS := [
	"temple_tuscan_archaic", "temple_tuscan_restored", "temple_tuscan_small",
	"temple_tetrastyle_ionic", "temple_tetrastyle_ionic_travertine", "temple_tetrastyle_ionic_marble",
	"temple_hexastyle_corinthian", "temple_hexastyle_corinthian_marble",
	"temple_round", "temple_round_marble",
]


static func kinds() -> Array:
	return KINDS.duplicate()


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	match kind:
		"temple_tuscan_archaic":
			_tuscan(k, 5.3, true, 6)
		"temple_tuscan_restored":
			_tuscan(k, 5.3, false, 6)
		"temple_tuscan_small":
			_tuscan(k, 2.2, false, 4)
		"temple_tetrastyle_ionic":
			_pseudo(k, 4, "ionic", "stucco")
		"temple_tetrastyle_ionic_travertine":
			_pseudo(k, 4, "ionic", "travertine")
		"temple_tetrastyle_ionic_marble":
			_pseudo(k, 4, "ionic", "marble")
		"temple_hexastyle_corinthian":
			_pseudo(k, 6, "corinthian", "travertine")
		"temple_hexastyle_corinthian_marble":
			_pseudo(k, 6, "corinthian", "marble")
		"temple_round":
			_tholos(k, false)
		"temple_round_marble":
			_tholos(k, true)
		_:
			_pad(k, 1.0, 1.0)
	return k.finish()
