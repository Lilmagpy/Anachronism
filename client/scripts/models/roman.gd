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
static func _pseudo(k: Kit, n: int, order: String, mat_kind: String, lod := false) -> void:
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
	var fd := 0 if lod else 1
	for i in n:
		_col(k, Vector3(-xo + i * s, ph, zz), h, order, colc, colm, fd)
	for j in range(1, pb):
		for sx in [-1.0, 1.0]:
			_col(k, Vector3(sx * xo, ph, zz - j * s), h, order, colc, colm, fd)
	# engaged half-columns on the flanks and the back (pseudoperipteral)
	for j in range(pb, bays + 1):
		for sx in [-1.0, 1.0]:
			if not lod or j % 2 == 0:
				_col(k, Vector3(sx * xo, ph, zz - j * s), h, order, colc, colm, 0)
	if not lod:
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
# PUBLIC BUILDINGS
# =============================================================================================


## A row of arches: n bays of width `bay`, piers `pw` wide (n + 1 piers), centred on xc, one storey
## from y0 up to yt with the arches springing at ys, wall thickness z0..z1.
static func _arcade(k: Kit, xc: float, n: int, bay: float, pw: float, y0: float, ys: float, yt: float,
		z0: float, z1: float, c: Color, m: int, segs := 6, back := false, ratio := 1.0, dark := true) -> void:
	var xs := xc - n * bay * 0.5
	for i in n + 1:
		var px := xs + i * bay
		k.box(Vector3(px, y0, (z0 + z1) * 0.5), Vector3(pw, yt - y0, z1 - z0), c, m)
	for i in n:
		var a := xs + i * bay + pw * 0.5
		var b := xs + (i + 1) * bay - pw * 0.5
		_arch(k, a, b, ys, yt, z0, z1, c, m, segs, true, back, ratio)
		if dark:
			_b(k, a, y0, z0 + 0.01, b, ys + (b - a) * 0.5 * ratio * 0.9, z0 + 0.02, DARK_C, Kit.DARK)


## A shop front (taberna) in a wall facing yaw: timber lintel, folded shutters, a stone counter.
static func _shopfront(k: Kit, p: Vector3, yaw: float, w: float, h: float) -> void:
	k.push(Kit.at(p, yaw))
	k.box(Vector3(0, 0, 0.0), Vector3(w, h, 0.012), DARK_C, Kit.DARK)
	k.box(Vector3(0, h, 0.0), Vector3(w * 1.12, h * 0.1, 0.05), DWOOD, Kit.TIMBER)
	k.box(Vector3(-w * 0.5 + w * 0.06, 0, 0.012), Vector3(w * 0.12, h, 0.02), WOOD, Kit.TIMBER)
	k.box(Vector3(w * 0.1, 0, 0.04), Vector3(w * 0.7, h * 0.34, 0.07), PEPERINO, Kit.STONE)
	k.pop()


## Republican basilica with two storeys of arcades and a clerestory (Basilica Aemilia, 179 BC,
## Livy 40.51.5; Basilica Sempronia 169 BC, Livy 44.16.10; Platner-Ashby s.v. Basilica
## Aemilia: about 70 m long). Vitruvius 5.1.4-5: a nave twice an aisle or more, aisles two
## storeys, the nave lit by a clerestory. Tufa or travertine piers; terracotta roof.
static func _basilica(k: Kit, travertine: bool) -> void:
	var L := 5.0
	var W := 2.6
	var c := TRAVERT if travertine else GROTTA
	var wl := STUCCO if not travertine else TRAVERT.darkened(0.04)
	var bay := L / 8.0
	_pad(k, L + 0.3, W + 0.3, Color(0.70, 0.66, 0.58), Kit.STONE, 0.05)
	k.push(Kit.at(Vector3(0, 0.05, 0)))
	_arcade(k, 0.0, 8, bay, 0.17, 0.0, 0.34, 0.62, W / 2.0 - 0.14, W / 2.0, c, Kit.STONE, 6, false, 1.0)
	_b(k, -L / 2 - 0.02, 0.62, W / 2.0 - 0.16, L / 2 + 0.02, 0.67, W / 2.0 + 0.03, c.lightened(0.05), Kit.STONE)
	_arcade(k, 0.0, 8, bay, 0.17, 0.67, 0.95, 1.2, W / 2.0 - 0.14, W / 2.0, c, Kit.STONE, 6, false, 1.0)
	_b(k, -L / 2 - 0.04, 1.2, W / 2.0 - 0.18, L / 2 + 0.04, 1.27, W / 2.0 + 0.05, c.lightened(0.08), Kit.STONE)
	for i in 8:   # tabernae behind the ground-floor arches: a counter in each
		var x := -L / 2 + (i + 0.5) * bay
		k.box(Vector3(x, 0.0, W / 2.0 - 0.06), Vector3(bay * 0.6, 0.12, 0.06), PEPERINO, Kit.STONE)
	# back, end walls and the clerestory
	_b(k, -L / 2, 0.0, -W / 2, L / 2, 1.27, -W / 2 + 0.14, wl, Kit.PLASTER)
	for s in [-1.0, 1.0]:
		_b(k, s * L / 2 - 0.07, 0.0, -W / 2 + 0.14, s * L / 2 + 0.07, 1.27, W / 2 - 0.14, wl, Kit.PLASTER)
	for i in 6:
		var x := -L / 2 + (i + 0.5) * L / 6
		_b(k, x - 0.05, 0.75, -W / 2 - 0.004, x + 0.05, 1.0, -W / 2 + 0.01, DARK_C, Kit.DARK)
	var nw := 0.58
	_b(k, -L / 2, 1.27, -nw - 0.06, L / 2, 1.95, -nw + 0.06, wl, Kit.PLASTER)
	_b(k, -L / 2, 1.27, nw - 0.06, L / 2, 1.95, nw + 0.06, wl, Kit.PLASTER)
	for s in [-1.0, 1.0]:
		_b(k, s * L / 2 - 0.06, 1.27, -nw, s * L / 2 + 0.06, 1.95, nw, wl, Kit.PLASTER)
		for i in 10:
			var x := -L / 2 + (i + 0.5) * L / 10
			_b(k, x - 0.05, 1.5, s * (nw + 0.06) - 0.006, x + 0.05, 1.78, s * (nw + 0.06) + 0.006, DARK_C, Kit.DARK)
	# the aisle roofs, low pitched, and the nave roof
	for s in [-1.0, 1.0]:
		_slab(k, [Vector3(-L / 2 - 0.06, 1.3, s * (W / 2 + 0.1)), Vector3(L / 2 + 0.06, 1.3, s * (W / 2 + 0.1)),
			Vector3(L / 2 + 0.06, 1.55, s * (nw + 0.06)), Vector3(-L / 2 - 0.06, 1.55, s * (nw + 0.06))], 0.04, TERRA, Kit.TILE)
	_gable_x(k, Vector3(0, 1.95, 0), L, nw * 2.0 + 0.1, 0.42, 0.08, TERRA, wl, Kit.PLASTER, 0.04)
	k.pop()


## The Curia Iulia type (Caesar's senate house, begun 44, dedicated 29 BC; the Republican
## Curia Hostilia stood at the same place, Platner-Ashby s.v. Curia Iulia: about 27 x 18 m and
## about 21 m to the eaves in the Diocletianic rebuild): a tall plain hall, brick under stucco with
## a marble-look dado, a low pediment, three tall windows over the portal.
static func _curia(k: Kit) -> void:
	var w := 1.8
	var d := 2.7
	var h := 2.0
	_pad(k, w + 0.5, d + 0.7, Color(0.72, 0.68, 0.60), Kit.STONE, 0.05)
	k.push(Kit.at(Vector3(0, 0.05, 0)))
	_b(k, -w / 2 - 0.06, 0.0, -d / 2 - 0.06, w / 2 + 0.06, 0.2, d / 2 + 0.06, TRAVERT, Kit.STONE)
	_stair(k, 0.0, 0.9, d / 2 + 0.06, 0.2, 3, 0.07, TRAVERT, Kit.STONE)
	_b(k, -w / 2, 0.2, -d / 2, w / 2, 0.75, d / 2, STUCCO_W, Kit.PLASTER)   # the stuccoed dado
	_b(k, -w / 2, 0.75, -d / 2, w / 2, h, d / 2, BRICK_C, Kit.BRICK)
	_b(k, -w / 2 - 0.03, 0.75, -d / 2 - 0.03, w / 2 + 0.03, 0.79, d / 2 + 0.03, TRAVERT, Kit.STONE)
	_b(k, -w / 2 - 0.05, h - 0.06, -d / 2 - 0.05, w / 2 + 0.05, h + 0.02, d / 2 + 0.05, TRAVERT, Kit.STONE)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_b(k, sx * w / 2 - 0.06 - (0.0 if sx > 0 else -0.0), 0.2, sz * d / 2 - 0.06, sx * w / 2 + 0.06, h, sz * d / 2 + 0.06, TRAVERT, Kit.STONE)
	# portal, the great bronze door, and the three windows above (Curia Iulia reconstruction)
	k.door(Vector3(0, 0.2, d / 2 + 0.001), 0.0, 0.5, 0.95, TRAVERT, BRONZE)
	for x in [-0.5, 0.0, 0.5]:
		k.window(Vector3(x, 1.5, d / 2 + 0.001), 0.0, 0.26, 0.5, TRAVERT, "frame")
	for s in [-1.0, 1.0]:
		for z in [-0.9, -0.3, 0.3, 0.9]:
			k.window(Vector3(s * (w / 2 + 0.001), 1.5, z), s * PI / 2.0, 0.2, 0.45, TRAVERT, "frame")
	_gable_z(k, Vector3(0, h + 0.02, 0), d, w, 0.26, 0.07, TERRA, STUCCO, Kit.PLASTER, 0.04)
	k.pop()


## The Rostra: the speakers' platform in the Forum, faced with the bronze beaks (rostra) of the
## ships of Antium taken in 338 BC (Livy 8.14.12; Plin. NH 34.20; Platner-Ashby s.v. Rostra).
## Here: a tufa platform about 24 x 11 m, 3.5 m high, a flight of steps at the back, eight
## beaks on the front, and the rostral column of C. Duilius (260 BC, Plin. NH 34.20) at the end.
static func _rostra(k: Kit) -> void:
	var w := 2.4
	var d := 1.1
	var h := 0.36
	_pad(k, w + 0.6, d + 0.9, Color(0.72, 0.68, 0.60), Kit.STONE, 0.04)
	k.push(Kit.at(Vector3(0, 0.04, 0)))
	_podium(k, w / 2.0, -d / 2.0, d / 2.0, h, GROTTA, Kit.STONE)
	_b(k, -w / 2 + 0.03, h, -d / 2 + 0.03, w / 2 - 0.03, h + 0.025, d / 2 - 0.03, GROTTA.lightened(0.05), Kit.STONE)
	for i in 8:   # the beaks: bronze rams, each a tapering ram with two ridges
		var x := -w / 2 + (i + 0.5) * w / 8.0
		k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(x, h * 0.55, d / 2.0 + 0.0)))
		k.frustum(Vector3.ZERO, 0.045, 0.02, 0.2, BRONZE, Kit.GOLD, 6)
		k.pop()
		_b(k, x - 0.05, h * 0.55 + 0.02, d / 2.0, x + 0.05, h * 0.55 + 0.05, d / 2.0 + 0.13, BRONZE, Kit.GOLD)
		_b(k, x - 0.05, h * 0.55 - 0.05, d / 2.0, x + 0.05, h * 0.55 - 0.02, d / 2.0 + 0.13, BRONZE, Kit.GOLD)
	for i in 5:   # steps behind
		_b(k, w * 0.3 - 0.35, 0.0, -d / 2.0 - 0.06 * (5 - i), w * 0.3 + 0.35, h * (i + 1) / 6.0, -d / 2.0, GROTTA.lightened(0.04), Kit.STONE)
	for i in 3:   # statue plinths of the honoured
		_b(k, -0.8 + i * 0.7, h + 0.025, -0.1, -0.7 + i * 0.7, h + 0.12, 0.0, GROTTA, Kit.STONE)
		k.frustum(Vector3(-0.75 + i * 0.7, h + 0.12, -0.05), 0.02, 0.012, 0.16, BRONZE, Kit.GOLD, 5)
	# the columna rostrata at the right end: shaft with three pairs of beaks
	var cx := w / 2.0 - 0.15
	k.box(Vector3(cx, h + 0.025, 0.0), Vector3(0.18, 0.1, 0.18), GROTTA, Kit.STONE)
	_shaft(k, Vector3(cx, h + 0.125, 0.0), 0.05, 0.04, 0.8, TRAVERT, Kit.STONE, 0, 8)
	for i in 3:
		for sx in [-1.0, 1.0]:
			k.push(Transform3D(Basis(Vector3(0, 0, 1), -sx * PI / 2.0), Vector3(cx + sx * 0.03, h + 0.3 + i * 0.22, 0.0)))
			k.frustum(Vector3.ZERO, 0.025, 0.01, 0.1, BRONZE, Kit.GOLD, 5)
			k.pop()
	k.frustum(Vector3(cx, h + 0.925, 0), 0.05, 0.03, 0.05, BRONZE, Kit.GOLD, 6)
	k.dome(Vector3(cx, h + 0.975, 0), 0.03, BRONZE, Kit.GOLD, 1.0, 2, 6)
	k.pop()


## A colonnaded portico, one bay segment 1.0 long and tiling along x (Porticus Aemilia 193 BC,
## Livy 35.10.12; Porticus Metelli 146 BC with the first marble temples, Vell. Pat. 1.11.3; Vitruvius
## 5.9 porticoes: columns, an entablature, a lean-to roof against a back wall). Two columns per
## segment, spaced 0.5. `marble`: Metellus' Ionic marble form.
static func _portico(k: Kit, marble: bool) -> void:
	var h := 0.55
	var order := "ionic" if marble else "tuscan"
	var c := MARBLE if marble else STUCCO_W
	var m := Kit.STONE if marble else Kit.PLASTER
	var d := _dia(h, order)
	_b(k, -0.5, 0.0, -0.42, 0.5, 0.05, 0.42, c.darkened(0.08), Kit.STONE)   # stylobate, joined across segments
	for x in [-0.25, 0.25]:
		_col(k, Vector3(x, 0.05, 0.3), h, order, c, m, 1)
	_b(k, -0.5, 0.05 + h, 0.3 - d * 0.6, 0.5, 0.05 + h + 0.6 * d, 0.3 + d * 0.6, c, Kit.STONE)     # architrave
	_b(k, -0.5, 0.05 + h + 0.6 * d, 0.3 - d * 0.6, 0.5, 0.05 + h + 1.2 * d, 0.3 + d * 0.6, RED if not marble else c.darkened(0.06), Kit.PAINT if not marble else Kit.STONE)
	_b(k, -0.5, 0.05 + h + 1.2 * d, 0.3 - d * 0.8, 0.5, 0.05 + h + 1.5 * d, 0.3 + d * 0.8, c.lightened(0.04), Kit.STONE)
	# the back wall, with doors to tabernae, and the lean-to roof
	_b(k, -0.5, 0.05, -0.42, 0.5, 0.05 + h + 0.3, -0.34, STUCCO if not marble else c, Kit.PLASTER if not marble else Kit.STONE)
	_b(k, -0.5, 0.05 + h + 0.3, -0.44, 0.5, 0.05 + h + 0.36, -0.32, c.lightened(0.05), Kit.STONE)
	k.box(Vector3(0.0, 0.05, -0.335), Vector3(0.18, 0.3, 0.012), DARK_C, Kit.DARK)
	var ye := 0.05 + h + 1.5 * d
	_slab(k, [Vector3(-0.5, ye + 0.02, 0.3 + d * 0.8 + 0.04), Vector3(0.5, ye + 0.02, 0.3 + d * 0.8 + 0.04),
		Vector3(0.5, 0.05 + h + 0.4, -0.4), Vector3(-0.5, 0.05 + h + 0.4, -0.4)], 0.03, TERRA, Kit.TILE)


## The Tabularium (78 BC, Q. Lutatius Catulus; the state archive on the Capitoline above the Forum;
## CIL VI 1313; Platner-Ashby s.v. Tabularium): a monumental substructure in peperino blocks, c. 70 m
## long; the Forum front has a blank rusticated base, a gallery of arches framed by engaged Doric
## half-columns (the Forum gallery), and above, a second order (restored as an arcade).
static func _tabularium(k: Kit) -> void:
	var L := 4.5
	var D := 1.2
	var bay := L / 9.0
	_pad(k, L + 0.4, D + 0.4, Color(0.66, 0.62, 0.54), Kit.STONE, 0.05)
	k.push(Kit.at(Vector3(0, 0.05, 0)))
	_b(k, -L / 2 - 0.05, 0.0, -D / 2, L / 2 + 0.05, 0.62, D / 2 - 0.2, PEPERINO.darkened(0.06), Kit.STONE)   # blank base
	for i in 5:   # slit windows and the postern in the base
		_b(k, -L / 2 + (i + 0.5) * L / 5 - 0.03, 0.3, D / 2 - 0.205, -L / 2 + (i + 0.5) * L / 5 + 0.03, 0.5, D / 2 - 0.19, DARK_C, Kit.DARK)
	_b(k, -0.12, 0.0, D / 2 - 0.205, 0.12, 0.3, D / 2 - 0.19, DARK_C, Kit.DARK)
	_b(k, -L / 2 - 0.08, 0.62, -D / 2, L / 2 + 0.08, 0.68, D / 2 - 0.12, PEPERINO.lightened(0.08), Kit.STONE)
	# the gallery of arches with engaged half-columns, z thickness 0.2
	_b(k, -L / 2, 0.68, -D / 2, L / 2, 1.4, D / 2 - 0.35, PEPERINO, Kit.STONE)
	_arcade(k, 0.0, 9, bay, 0.2, 0.68, 1.0, 1.28, D / 2 - 0.35, D / 2 - 0.15, PEPERINO, Kit.STONE, 6, false, 1.0)
	for i in 10:
		_col(k, Vector3(-L / 2 + i * bay, 0.68, D / 2 - 0.12), 0.6, "doric", PEPERINO.lightened(0.05), Kit.STONE, 0)
	_b(k, -L / 2 - 0.1, 1.28, -D / 2, L / 2 + 0.1, 1.4, D / 2 - 0.04, PEPERINO.lightened(0.1), Kit.STONE)   # Doric entablature
	for i in 18:   # triglyph hints
		var x := -L / 2 + (i + 0.5) * L / 18
		k.box(Vector3(x, 1.3, D / 2 - 0.035), Vector3(0.05, 0.08, 0.012), DWOOD, Kit.PAINT)
	# a second order, slightly set back, then the cornice and a flat tiled roof
	_arcade(k, 0.0, 9, bay, 0.2, 1.4, 1.62, 1.82, D / 2 - 0.5, D / 2 - 0.3, PEPERINO, Kit.STONE, 6, false, 1.0)
	_b(k, -L / 2, 1.4, -D / 2, L / 2, 1.9, D / 2 - 0.5, PEPERINO, Kit.STONE)
	_b(k, -L / 2 - 0.06, 1.82, -D / 2, L / 2 + 0.06, 1.9, D / 2 - 0.26, PEPERINO.lightened(0.1), Kit.STONE)
	_gable_x(k, Vector3(0, 1.9, -D / 2 + 0.3), L + 0.1, 0.62, 0.15, 0.04, TERRA, PEPERINO, Kit.STONE, 0.03)
	k.pop()


## Warehouses (horrea) round a courtyard: Platner-Ashby s.v. Horrea (Horrea Sempronia of C. Gracchus,
## Plut. C. Gracchus 6; Livy 29.37.2 on grain storage). Ranges of vaulted rooms on a raised floor
## against damp, facing a court; high blank outer walls with slit windows; one great gate on +z.
static func _horrea(k: Kit) -> void:
	var s := 2.4
	var t := 0.62
	var hw := s / 2.0
	var h := 0.62
	_pad(k, s + 0.3, s + 0.3, Color(0.70, 0.64, 0.52), Kit.EARTH, 0.04)
	k.push(Kit.at(Vector3(0, 0.04, 0)))
	_ring(k, 0.0, 0.0, hw, hw, 0.14, 0.0, h, GROTTA, Kit.STONE)          # outer wall
	_ring(k, 0.0, 0.0, hw - t, hw - t, 0.1, 0.0, h * 0.9, STUCCO, Kit.PLASTER)   # court wall
	_ring(k, 0.0, 0.0, hw + 0.03, hw + 0.03, 0.05, h, h + 0.04, GROTTA.lightened(0.1), Kit.STONE)
	_frame_roof(k, Vector3.ZERO, hw + 0.08, hw + 0.08, hw - t, hw - t, h + 0.02, h * 0.82, 0.04, TERRA)
	for i in 8:   # slit windows in the outer wall
		var x := -hw + 0.3 + i * 0.3
		_b(k, x - 0.03, h * 0.6, hw - 0.005, x + 0.03, h * 0.88, hw + 0.002, DARK_C, Kit.DARK)
		_b(k, x - 0.03, h * 0.6, -hw - 0.002, x + 0.03, h * 0.88, -hw + 0.005, DARK_C, Kit.DARK)
	for i in 8:
		var z := -hw + 0.3 + i * 0.3
		_b(k, hw - 0.005, h * 0.6, z - 0.03, hw + 0.002, h * 0.88, z + 0.03, DARK_C, Kit.DARK)
		_b(k, -hw - 0.002, h * 0.6, z - 0.03, -hw + 0.005, h * 0.88, z + 0.03, DARK_C, Kit.DARK)
	# the great gate (arch) and the court's doors to the store rooms on the raised floor
	_b(k, -0.28, 0.0, hw - 0.01, 0.28, 0.4, hw + 0.01, DARK_C, Kit.DARK)
	_arch(k, -0.28, 0.28, 0.4, 0.62, hw - 0.14, hw + 0.01, TRAVERT, Kit.STONE, 6, true, false)
	for i in 4:
		var x := -0.75 + i * 0.5
		_b(k, x - 0.1, 0.1, hw - t + 0.04, x + 0.1, 0.5, hw - t + 0.06, DARK_C, Kit.DARK)
		_b(k, x - 0.1, 0.1, -hw + t - 0.06, x + 0.1, 0.5, -hw + t - 0.04, DARK_C, Kit.DARK)
		_b(k, hw - t + 0.04, 0.1, x - 0.1, hw - t + 0.06, 0.5, x + 0.1, DARK_C, Kit.DARK)
		_b(k, -hw + t - 0.06, 0.1, x - 0.1, -hw + t - 0.04, 0.5, x + 0.1, DARK_C, Kit.DARK)
	_b(k, -hw + t + 0.0, 0.0, -hw + t, hw - t, 0.04, hw - t, Color(0.62, 0.55, 0.42), Kit.EARTH)
	for i in 6:   # stacked amphorae and sacks in the court
		var p := Vector3(-0.25 + (i % 3) * 0.25, 0.04, -0.2 + (i / 3) * 0.3)
		k.frustum(p, 0.03, 0.08, 0.14, TERRA_L, Kit.PAINT, 6, false)
		k.frustum(p + Vector3(0, 0.14, 0), 0.08, 0.04, 0.1, TERRA_L, Kit.PAINT, 6)
	k.pop()


## The macellum, the provision market (Livy 40.51.5, 179 BC, "macellum" built on the site of Fulvius' house;
## Platner-Ashby s.v. Macellum): a walled square of shops round a colonnaded court, in the centre
## a round pavilion (tholos) of eight columns under a conical roof, the fish-sellers' fountain.
static func _macellum(k: Kit) -> void:
	var s := 1.9
	var hw := s / 2.0
	var h := 0.42
	_pad(k, s + 0.3, s + 0.3, Color(0.70, 0.66, 0.56), Kit.STONE, 0.04)
	k.push(Kit.at(Vector3(0, 0.04, 0)))
	_ring(k, 0.0, 0.0, hw, hw, 0.12, 0.0, h, GROTTA, Kit.STONE)
	_ring(k, 0.0, 0.0, hw + 0.03, hw + 0.03, 0.05, h, h + 0.04, GROTTA.lightened(0.08), Kit.STONE)
	_frame_roof(k, Vector3.ZERO, hw + 0.06, hw + 0.06, hw - 0.42, hw - 0.42, h + 0.04, h * 0.8, 0.035, TERRA)
	for i in 5:   # tabernae on the front, each with a counter and an upper window
		var x := -hw + (i + 0.5) * s / 5.0
		_shopfront(k, Vector3(x, 0.0, hw + 0.001), 0.0, 0.26, 0.3)
	for sg in [-1.0, 1.0]:
		for i in 4:
			var z := -hw + (i + 0.6) * s / 4.4
			_shopfront(k, Vector3(sg * (hw + 0.001), 0.0, z), sg * PI / 2.0, 0.26, 0.3)
	for x in [-0.6, -0.2, 0.2, 0.6]:   # the colonnade round the court (Tuscan, stuccoed)
		for sz in [-1.0, 1.0]:
			_col(k, Vector3(x, 0.0, sz * (hw - 0.45)), 0.28, "tuscan", STUCCO_W, Kit.PLASTER, 0)
	_b(k, -hw + 0.43, 0.0, -hw + 0.43, hw - 0.43, 0.02, hw - 0.43, Color(0.78, 0.72, 0.60), Kit.STONE)
	# central tholos
	var n := 8
	var r := 0.3
	k.frustum(Vector3(0, 0.0, 0), r + 0.08, r + 0.08, 0.05, TRAVERT, Kit.STONE, 8)
	for i in n:
		var a := i * TAU / n
		_col(k, Vector3(cos(a) * r, 0.05, sin(a) * r), 0.4, "tuscan", STUCCO_W, Kit.PLASTER, 0)
	k.frustum(Vector3(0, 0.45, 0), r + 0.05, r + 0.05, 0.06, TRAVERT, Kit.STONE, 8)
	k.frustum(Vector3(0, 0.51, 0), r + 0.08, 0.0, 0.2, TERRA, Kit.TILE, 8)
	k.cylinder(Vector3(0, 0.05, 0), 0.1, 0.1, GROTTA, Kit.STONE, 8)   # the fish-sellers' fountain
	k.cylinder(Vector3(0, 0.15, 0), 0.08, 0.01, Color.WHITE, Kit.WATER, 8)
	k.pop()


# =============================================================================================
# THEATRE AND CIRCUS
# =============================================================================================


static func _pt(r: float, th: float, y: float) -> Vector3:
	return Vector3(r * cos(th), y, r * sin(th))


## The Theatre of Pompey (dedicated 55 BC; the first permanent stone theatre in Rome: Plin. NH
## 36.115, Tac. Ann. 14.20, Dio 39.38; Platner-Ashby s.v. Theatrum Pompei): a semicircular cavea
## about 150 m across, concrete vaults faced in travertine and tufa, an outer facade of three
## arcaded orders, the stage building (scaena) with its columnar front, and at the top of the
## cavea, on the axis, the temple of Venus Victrix (Gell. NA 10.1.7; Plin. NH 8.20). Here: the
## cavea opens to -z (the temple at the far end, facing +z), the stage house on +z.
## 15 units across, using the real 150 m; orchestra radius 2, ima/media/summa cavea.
static func _theatre_pompey(k: Kit) -> void:
	var R := 7.5
	var n := 18
	var dth := PI / n
	var ap := R * cos(dth / 2.0)
	var b := 2.0 * R * sin(dth / 2.0)
	var c := TRAVERT
	_b(k, -R - 0.6, 0.0, -R - 0.5, R + 0.6, 0.04, 3.2, Color(0.66, 0.62, 0.54), Kit.STONE)
	k.push(Kit.at(Vector3(0, 0.04, 0)))
	# the cavea: stepped seating in three zones, with landings (diazomata) between them
	var steps: Array = []
	var zones := [[2.2, 3.4, 0.0, 0.64], [3.7, 4.9, 0.64, 1.4], [5.2, 6.4, 1.4, 2.2]]
	var y_prev := 0.0
	for zi in zones.size():
		var z: Array = zones[zi]
		if zi > 0:
			steps.append([float(zones[zi - 1][1]), float(z[0]), y_prev, y_prev])
		for s in 3:
			var ri: float = float(z[0]) + s * (float(z[1]) - float(z[0])) / 3.0
			var ro: float = float(z[0]) + (s + 1) * (float(z[1]) - float(z[0])) / 3.0
			var yt: float = float(z[2]) + (s + 1) * (float(z[3]) - float(z[2])) / 3.0
			steps.append([ri, ro, y_prev, yt])
			y_prev = yt
	steps.append([6.4, ap - 0.3, y_prev, y_prev])   # the top walkway behind the last seats
	for i in n:
		var ta := PI + i * dth
		var tb := ta + dth
		var tm := (ta + tb) * 0.5
		var col := c.darkened(0.05 if i % 2 == 0 else 0.0)
		for st in steps:
			var ri: float = st[0]
			var ro: float = st[1]
			var y0: float = st[2]
			var y1: float = st[3]
			k.quad(_pt(ri, ta, y1), _pt(ro, ta, y1), _pt(ro, tb, y1), _pt(ri, tb, y1), col, Kit.STONE, Vector3(ri * cos(tm), y1 - 1.0, ri * sin(tm)))
			if y1 > y0:
				k.quad(_pt(ri, ta, y0), _pt(ri, tb, y0), _pt(ri, tb, y1), _pt(ri, ta, y1), col.darkened(0.08), Kit.STONE, _pt(ri * 2.0, tm, (y0 + y1) * 0.5))
	for s in [-1.0, 1.0]:   # the ends of the cavea
		for st in steps:
			var ri: float = st[0]
			var ro: float = st[1]
			var y1: float = st[3]
			if y1 > 0.0:
				k.quad(Vector3(s * ri, 0, 0), Vector3(s * ro, 0, 0), Vector3(s * ro, y1, 0), Vector3(s * ri, y1, 0), c.darkened(0.1), Kit.STONE, Vector3(s * (ri + ro) * 0.5, y1 * 0.5, -1.0))
	# the orchestra: a half disc of paving
	var pts: Array = []
	for i in 11:
		pts.append(_pt(2.2, PI + i * PI / 10.0, 0.004))
	k.polygon(pts, Color(0.80, 0.70, 0.52), Kit.STONE, Vector3(0, -1, 0))
	# the outer facade: three storeys of arches, then an attic
	for i in n:
		var mid := PI + (i + 0.5) * dth
		k.push(Kit.at(Vector3.ZERO, atan2(cos(mid), sin(mid))))
		for sto in 3:
			var y0 := sto * 0.9
			_b(k, -b / 2, y0, ap - 0.3, -b / 2 + 0.15, y0 + 0.9, ap, c, Kit.STONE)
			_b(k, b / 2 - 0.15, y0, ap - 0.3, b / 2, y0 + 0.9, ap, c, Kit.STONE)
			k.quad(Vector3(-b / 2 + 0.15, y0, ap - 0.31), Vector3(b / 2 - 0.15, y0, ap - 0.31), Vector3(b / 2 - 0.15, y0 + 0.7, ap - 0.31), Vector3(-b / 2 + 0.15, y0 + 0.7, ap - 0.31), DARK_C, Kit.DARK, Vector3(0, y0, ap - 1.0))
			_arch(k, -b / 2 + 0.15, b / 2 - 0.15, y0 + 0.4, y0 + 0.86, ap - 0.3, ap, c, Kit.STONE, 4, true, false, 1.0)
			_b(k, -b / 2 - 0.01, y0 + 0.86, ap - 0.34, b / 2 + 0.01, y0 + 0.9, ap + 0.05, c.lightened(0.07), Kit.STONE)
		_b(k, -b / 2, 2.7, ap - 0.25, b / 2, 3.1, ap, c.darkened(0.04), Kit.STONE)
		k.quad(Vector3(-0.12, 2.8, ap + 0.003), Vector3(0.12, 2.8, ap + 0.003), Vector3(0.12, 3.0, ap + 0.003), Vector3(-0.12, 3.0, ap + 0.003), DARK_C, Kit.DARK, Vector3(0, 2.9, ap - 1.0))
		_b(k, -b / 2 - 0.02, 3.1, ap - 0.3, b / 2 + 0.02, 3.16, ap + 0.04, c.lightened(0.1), Kit.STONE)
		k.pop()
	# the temple of Venus Victrix at the top of the cavea, on the axis, facing the stage
	_b(k, -0.95, 0.0, -ap + 0.35, 0.95, 2.2, -5.2, c.darkened(0.06), Kit.STONE)
	k.push(Transform3D(Basis.from_scale(Vector3(0.55, 0.55, 0.55)), Vector3(0, 2.2, -6.15)))
	_pseudo(k, 4, "corinthian", "travertine", true)
	k.pop()
	# the stage house: stage, the columnar front (scaenae frons) in two orders, wings, roofs
	_b(k, -4.4, 0.0, 0.0, 4.4, 0.2, 1.0, Color(0.55, 0.40, 0.25), Kit.TIMBER)   # the timber stage
	_b(k, -4.4, 0.0, 1.0, 4.4, 1.75, 1.45, STUCCO, Kit.PLASTER)
	for x in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		_b(k, x - 0.2, 0.25, 1.0 - 0.01, x + 0.2, 0.8, 1.0 + 0.01, DARK_C, Kit.DARK)
	for i in 5:
		var x := -3.6 + i * 1.8
		_col(k, Vector3(x, 0.2, 1.1), 0.75, "corinthian", MARBLE, Kit.STONE, 0)
		_col(k, Vector3(x, 1.0, 1.1), 0.62, "corinthian", MARBLE, Kit.STONE, 0)
	_b(k, -4.4, 0.95, 0.98, 4.4, 1.0, 1.2, MARBLE.darkened(0.04), Kit.STONE)
	_b(k, -4.45, 1.62, 0.98, 4.45, 1.75, 1.2, MARBLE.darkened(0.04), Kit.STONE)
	for s in [-1.0, 1.0]:   # the wings (versurae)
		_b(k, s * 5.95 - 1.55, 0.0, 0.0, s * 5.95 + 1.55, 2.0, 2.2, STUCCO, Kit.PLASTER)
		_b(k, s * 5.95 - 1.6, 2.0, -0.05, s * 5.95 + 1.6, 2.08, 2.25, c.lightened(0.05), Kit.STONE)
		for x in [-0.8, 0.0, 0.8]:
			_b(k, s * 5.95 + x - 0.18, 0.5, 2.2 - 0.005, s * 5.95 + x + 0.18, 1.5, 2.2 + 0.004, DARK_C, Kit.DARK)
		_gable_x(k, Vector3(s * 5.95, 2.08, 1.1), 3.2, 2.2, 0.4, 0.06, TERRA, STUCCO, Kit.PLASTER, 0.04)
	_gable_x(k, Vector3(0, 1.75, 1.75), 8.8, 1.5, 0.3, 0.05, TERRA, STUCCO, Kit.PLASTER, 0.04)
	k.pop()


## The Circus Maximus (Livy 1.35.8-9 the first seats of Tarquin; 8.20.2 carceres 329 BC; 41.27.5-6
## the seven eggs, 174 BC; Plin. NH 36.102 Caesar's stone rebuild; Platner-Ashby s.v. Circus
## Maximus: about 621 x 118 m, track about 79 m wide). A tiling segment of the long flank, 1.0
## long along x: a low podium wall on the track side (+z), rows of seats (stone below, timber above,
## as in the Republican circus), and an arcaded outer wall of two storeys at the back (-z).
static func _circus_segment(k: Kit) -> void:
	var c := GROTTA
	_b(k, -0.5, 0.0, -1.15, 0.5, 0.03, 1.35, Color(0.72, 0.62, 0.45), Kit.EARTH)   # the sand edge
	_b(k, -0.5, 0.03, 0.95, 0.5, 0.2, 1.05, c.lightened(0.05), Kit.STONE)           # the podium wall
	for i in 10:
		var z0 := 0.95 - i * 0.14
		var y1 := 0.2 + (i + 1) * 0.085
		var stone := i < 4
		_b(k, -0.5, 0.0, z0 - 0.14, 0.5, y1, z0, c if stone else Color(0.55, 0.40, 0.25), Kit.STONE if stone else Kit.TIMBER)
	_b(k, -0.5, 0.0, -0.6, 0.5, 1.05, -0.45, c, Kit.STONE)
	_b(k, -0.5, 1.05, -1.1, 0.5, 1.1, -0.35, c.lightened(0.08), Kit.STONE)
	_b(k, -0.5, 0.0, -1.1, -0.3, 1.05, -0.6, c, Kit.STONE)   # the arcaded back: two storeys
	_b(k, 0.3, 0.0, -1.1, 0.5, 1.05, -0.6, c, Kit.STONE)
	_b(k, -0.3, 0.0, -1.1, 0.3, 0.4, -0.95, c, Kit.STONE)
	_arch(k, -0.3, 0.3, 0.35, 0.52, -1.1, -0.9, c, Kit.STONE, 6, true, true)
	_arch(k, -0.3, 0.3, 0.8, 1.0, -1.1, -0.9, c, Kit.STONE, 6, true, true)
	_b(k, -0.3, 0.0, -1.1, 0.3, 0.3, -1.08, DARK_C, Kit.DARK)
	_b(k, -0.5, 0.52, -1.14, 0.5, 0.57, -0.85, c.lightened(0.07), Kit.STONE)


## The end of the circus with the starting gates (Livy 8.20.2: carceres 329 BC; Dion. Hal. 3.68)
## and the beginning of the spina. Faces +z: twelve arched stalls (the carceres) closed by
## timber gates, a tower (oppidum) at each end, the spina down the middle with the seven
## eggs that counted laps (Livy 41.27.6, 174 BC) on two pillars and the turning post (meta).
## 7.9 wide as the track.
static func _circus_end(k: Kit) -> void:
	var c := GROTTA
	var bay := 0.62
	_b(k, -4.0, 0.0, -0.6, 4.0, 0.03, 2.8, Color(0.72, 0.62, 0.45), Kit.EARTH)
	_b(k, -3.0, 0.03, -0.9, 3.0, 0.8, -0.1, c, Kit.STONE)
	_arcade(k, 0.0, 12, 0.5, 0.1, 0.03, 0.3, 0.5, -0.1, 0.0, c, Kit.STONE, 4, false, 1.0, true)
	_b(k, -3.05, 0.5, -0.1, 3.05, 0.8, 0.0, c, Kit.STONE)
	for i in 12:   # the timber gates
		var x0 := -3.0 + i * 0.5
		_b(k, x0 + 0.06, 0.03, -0.085, x0 + 0.44, 0.34, -0.075, DWOOD, Kit.TIMBER)
	_b(k, -3.05, 0.8, -0.95, 3.05, 0.86, 0.04, c.lightened(0.08), Kit.STONE)
	for s in [-1.0, 1.0]:   # the oppida
		_b(k, s * 3.5 - 0.5, 0.03, -0.9, s * 3.5 + 0.5, 1.2, 0.1, c, Kit.STONE)
		_b(k, s * 3.5 - 0.55, 1.2, -0.95, s * 3.5 + 0.55, 1.26, 0.15, c.lightened(0.08), Kit.STONE)
		_b(k, s * 3.5 - 0.1, 0.5, 0.1 - 0.0, s * 3.5 + 0.1, 0.9, 0.1 + 0.004, DARK_C, Kit.DARK)
		_gable_x(k, Vector3(s * 3.5, 1.26, -0.4), 1.1, 1.0, 0.25, 0.04, TERRA, STUCCO, Kit.PLASTER, 0.03)
	_b(k, -3.0, 0.8, -0.9, 3.0, 0.88, -0.1, DWOOD, Kit.TIMBER)   # the roof of the stalls
	# the spina: a low basin with its water channel (euripus), turning posts, eggs
	_b(k, -0.14, 0.03, 0.9, 0.14, 0.2, 2.6, c.lightened(0.05), Kit.STONE)
	_b(k, -0.1, 0.2, 0.95, 0.1, 0.22, 2.55, Color(0.55, 0.75, 0.85), Kit.WATER)
	for s in [-1.0, 1.0]:
		k.frustum(Vector3(s * 0.08, 0.22, 0.95), 0.025, 0.02, 0.45, TRAVERT, Kit.STONE, 6)
	_b(k, -0.1, 0.65, 0.93, 0.1, 0.69, 0.97, WOOD, Kit.TIMBER)
	for i in 7:   # the seven eggs
		k.dome(Vector3(-0.09 + i * 0.03, 0.69, 0.95), 0.014, TERRA_L, Kit.PAINT, 1.4, 2, 5)
	for i in 3:   # the meta prima: three cones on a base
		k.frustum(Vector3(-0.1 + i * 0.1, 0.22, 2.6), 0.04, 0.012, 0.28, TRAVERT, Kit.STONE, 6)
	_b(k, -0.25, 0.03, 2.55, 0.25, 0.1, 2.75, c, Kit.STONE)
	_b(k, -0.12, 0.2, 0.7, 0.12, 0.3, 0.9, c, Kit.STONE)


# =============================================================================================
# THE REST OF THE LIST (U3): forms drawn in metres. `_metres` scales them to kit units (10 m).
# =============================================================================================


## Enter a frame in which 1.0 = one metre (the mesh ends up in kit units). Pair with k.pop().
static func _metres(k: Kit) -> void:
	k.push(Transform3D(Basis.from_scale(Vector3(0.1, 0.1, 0.1)), Vector3.ZERO))


## A wall of thickness t between two ground points a and b (x, z), from y0 to y1.
static func _wall_seg(k: Kit, a: Vector2, b: Vector2, y0: float, y1: float, t: float, c: Color, m: int) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	k.box(Vector3(mid.x, y0, mid.y), Vector3(d.length(), y1 - y0, t), c, m, atan2(-d.y, d.x))


## A barrel vault along x: centre (cx, cz), length len, span, springing at y, crown `rise` above.
static func _barrel(k: Kit, cx: float, cz: float, len: float, span: float, y: float, rise: float, c: Color, m: int, segs := 8) -> void:
	var inside := Vector3(cx, y, cz)
	for i in segs:
		var a0 := PI * i / segs
		var a1 := PI * (i + 1) / segs
		var z0 := cz + cos(a0) * span * 0.5
		var z1 := cz + cos(a1) * span * 0.5
		var y0 := y + sin(a0) * rise
		var y1 := y + sin(a1) * rise
		k.quad(Vector3(cx - len / 2, y0, z0), Vector3(cx + len / 2, y0, z0), Vector3(cx + len / 2, y1, z1), Vector3(cx - len / 2, y1, z1), c, m, inside)
	for sx in [-1.0, 1.0]:   # the two ends: a half disc
		var pts: Array = []
		for i in segs + 1:
			var a := PI * i / segs
			pts.append(Vector3(cx + sx * len / 2, y + sin(a) * rise, cz + cos(a) * span * 0.5))
		k.polygon(pts, c.darkened(0.08), m, inside)


## Ellipse arcs: points about `step` metres apart on p = c + (rx cos a, rz sin a), a0..a1:
## [{pos, normal (outward), tangent, len}] (2D x, z).
static func arc_walk(cx: float, cz: float, rx: float, rz: float, a0: float, a1: float, step: float) -> Array:
	var res := []
	var circ := 0.0
	var prev := Vector2(rx * cos(a0), rz * sin(a0))
	for i in range(1, 65):
		var a := a0 + (a1 - a0) * i / 64.0
		var p := Vector2(rx * cos(a), rz * sin(a))
		circ += p.distance_to(prev)
		prev = p
	var n := maxi(1, int(round(circ / step)))
	for i in n:
		var a := a0 + (a1 - a0) * (i + 0.5) / n
		res.append({"pos": Vector2(cx + rx * cos(a), cz + rz * sin(a)), "normal": Vector2(cos(a) / rx, sin(a) / rz).normalized(),
			"tangent": Vector2(-rx * sin(a), rz * cos(a)).normalized(), "len": circ / n})
	return res


## Yaw turning local +x along the 2D direction t, and local +z along n.
static func yaw_x(t: Vector2) -> float:
	return atan2(-t.y, t.x)


static func yaw_z(n: Vector2) -> float:
	return atan2(n.x, n.y)


## Rows of seats on an elliptical arc, rising from radius (rx, rz): `rows` steps of width row_w.
static func seat_rings(k: Kit, cx: float, cz: float, rx: float, rz: float, a0: float, a1: float,
		rows: int, row_w: float, step_h: float, c0: Color, c1: Color, m0: int, m1: int, first := 0.5) -> void:
	for j in rows:
		var hh := first + (j + 1) * step_h
		var col := c0 if j < rows / 3 else c1
		var mat := m0 if j < rows / 3 else m1
		for e in arc_walk(cx, cz, rx + j * row_w + row_w * 0.5, rz + j * row_w + row_w * 0.5, a0, a1, 6.0):
			var p: Vector2 = e.pos
			k.box(Vector3(p.x, 0, p.y), Vector3(float(e.len) * 1.06, hh, row_w * 1.02), col, mat, yaw_x(e.tangent))


## An arcaded facade along an arc, `storeys` storeys of sh metres, facing outward.
static func arc_facade(k: Kit, cx: float, cz: float, rx: float, rz: float, a0: float, a1: float,
		storeys: int, sh: float, c: Color, m: int, bay := 6.0) -> void:
	for e in arc_walk(cx, cz, rx, rz, a0, a1, bay):
		var p: Vector2 = e.pos
		k.push(Kit.at(Vector3(p.x, 0, p.y), yaw_z(e.normal)))
		var bw: float = e.len
		for s in storeys:
			var y0 := s * sh
			_arcade(k, 0.0, 1, bw, bw * 0.34, y0, y0 + sh * 0.56, y0 + sh * 0.9, -0.6, 0.6, c, m, 5, true)
			k.box(Vector3(0, y0 + sh * 0.9, 0), Vector3(bw * 1.02, sh * 0.1, 1.4), c.lightened(0.06), m)
		k.pop()


# --- temples ----------------------------------------------------------------------------------


## An octastyle Corinthian temple on a high podium, 8 columns across the front. peripteral: free columns
## all round, `nside` along each flank, a cella set inside them with a two-bay porch (the temple of
## Castor, Augustan form: octastyle peripteral, 11 columns on each side, columns 12.5 m high and
## 1.45 m thick, c. 50 x 30 m, floor c. 7 m above the Sacra Via, a flight of eleven steps down from
## the pronaos to a speakers' platform; Platner-Ashby s.v. Castor, Aedes). Otherwise pseudoperipteral
## and pycnostyle (the temple of Venus Genetrix in the Forum of Caesar, octastyle Corinthian on a
## high podium, marble, columns 1.5 d apart: Vitr. 3.3.2).
static func _octastyle(k: Kit, peripteral: bool, nside: int, h: float, sp: float, marble: bool) -> void:
	var d := h / 10.0
	var s := d * sp
	var n := 8
	var xo := (n - 1) * 0.5 * s
	var zz := (nside - 1) * 0.5 * s
	var ph := 0.5 * h if peripteral else 0.42 * h
	var colc := MARBLE if marble else TRAVERT.lightened(0.04)
	var pod := MARBLE.darkened(0.04) if marble else TRAVERT
	var wall := MARBLE if marble else STUCCO_W
	var m := Kit.STONE
	var nst := maxi(5, int(ph / 0.6))
	var sl := nst * 0.7
	k.push(Kit.at(Vector3(0, 0, -sl * 0.5)))
	_podium(k, xo + 2.5 * d, -(zz + 2.0 * d), zz + 2.5 * d, ph, pod, m)
	_stair(k, 0.0, xo * 2.0 + d * 2.0, zz + 2.5 * d + 0.3, ph, nst, 0.7, pod.lightened(0.05), m)
	var pb := 2
	var zc := zz - pb * s
	if peripteral:
		_b(k, -(xo - s), ph, -(zz - s), xo - s, ph + h, zc, wall, m)
		k.door(Vector3(0, ph, zc + 0.02), 0.0, s * 0.6, h * 0.55, colc, BRONZE)
		for i in n:
			_col(k, Vector3(-xo + i * s, ph, zz), h, "corinthian", colc, m, 1)
			_col(k, Vector3(-xo + i * s, ph, -zz), h, "corinthian", colc, m, 1)
		for j in range(1, nside - 1):
			for sx in [-1.0, 1.0]:
				_col(k, Vector3(sx * xo, ph, zz - j * s), h, "corinthian", colc, m, 1)
		for sx in [-1.0, 1.0]:   # the double row of the pronaos
			_col(k, Vector3(sx * (xo - s), ph, zz - s), h, "corinthian", colc, m, 1)
	else:
		var wx := xo - 0.1 * d
		_b(k, -wx, ph, -zz, wx, ph + h, zc, wall, m)
		k.door(Vector3(0, ph, zc + 0.02), 0.0, s * 0.6, h * 0.55, colc, BRONZE)
		for i in n:
			_col(k, Vector3(-xo + i * s, ph, zz), h, "corinthian", colc, m, 1)
		for j in range(1, pb):
			for sx in [-1.0, 1.0]:
				_col(k, Vector3(sx * xo, ph, zz - j * s), h, "corinthian", colc, m, 1)
		for j in range(pb, nside):
			for sx in [-1.0, 1.0]:
				_col(k, Vector3(sx * xo, ph, zz - j * s), h, "corinthian", colc, m, 0)
	var ex := xo + 0.75 * d
	var ez := zz + 0.75 * d
	var ya := ph + h
	_ring(k, 0.0, 0.0, ex, ez, d, ya, ya + 0.6 * d, colc, m)
	_ring(k, 0.0, 0.0, ex + 0.01, ez + 0.01, d * 0.9, ya + 0.6 * d, ya + 1.3 * d, wall.darkened(0.04), m)
	_ring(k, 0.0, 0.0, ex + 0.35 * d, ez + 0.35 * d, d * 1.3, ya + 1.3 * d, ya + 1.8 * d, colc.darkened(0.04), m)
	var span := ex * 2.0 + 0.5 * d
	var rise := span / 7.0
	var ry := ya + 1.8 * d
	_gable_z(k, Vector3(0, ry, 0), (ez + 0.35 * d) * 2.0, span, rise, 0.1 * d, TERRA, wall.darkened(0.04), m, 0.3)
	for sz in [-1.0, 1.0]:
		var zf: float = sz * (ez + 0.35 * d)
		_b(k, -0.7 * d, ry + rise, zf - 0.4 * d, 0.7 * d, ry + rise + 0.9 * d, zf + 0.4 * d, TERRA_L, Kit.PAINT)
		for sx in [-1.0, 1.0]:
			_b(k, sx * span * 0.5 - 0.4 * d, ry, zf - 0.3 * d, sx * span * 0.5 + 0.4 * d, ry + 0.5 * d, zf + 0.3 * d, TERRA_L, Kit.PAINT)
	k.pop()


## The temple of Concord in the Forum (Augustan/Tiberian form on the concrete podium of 121 BC): a
## cella much wider than deep, 45 x 24 m, and a pronaos 34 m wide and 14 deep that does not reach
## the cella's corners (Platner-Ashby s.v. Concordia). The order, the six columns and the heights are
## assumed.
static func _concord(k: Kit) -> void:
	var cw := 45.0
	var cd := 24.0
	var pw := 34.0
	var pd := 14.0
	var ph := 5.0
	var h := 14.0
	var c := MARBLE
	var m := Kit.STONE
	var nst := 9
	k.push(Kit.at(Vector3(0, 0, -3.0)))
	_podium(k, cw / 2 + 1.5, -cd - 1.5, pd + 1.5, ph, TRAVERT, m)
	_stair(k, 0.0, 17.0, pd + 1.5 + 0.2, ph, nst, 0.7, TRAVERT.lightened(0.05), m)
	_ring(k, 0.0, -cd / 2, cw / 2, cd / 2, 1.2, ph, ph + h, STUCCO_W, Kit.PLASTER)
	_b(k, -pw / 2, ph, 0.0, pw / 2, ph + h, 1.0, STUCCO_W, Kit.PLASTER)   # the cella front wall behind the porch
	k.door(Vector3(0, ph, 1.02), 0.0, 5.0, 8.0, c, BRONZE)
	var n := 6
	var s := pw / (n - 1)
	for i in n:
		_col(k, Vector3(-pw / 2 + i * s, ph, pd), h, "corinthian", c, m, 1)
	for j in [1, 2]:
		for sx in [-1.0, 1.0]:
			_col(k, Vector3(sx * pw / 2, ph, pd - j * (pd / 3.0)), h, "corinthian", c, m, 1)
	_ring(k, 0.0, pd / 2, pw / 2 + 0.8, pd / 2 + 0.8, 1.2, ph + h, ph + h + 1.6, c, m)
	_ring(k, 0.0, pd / 2, pw / 2 + 1.4, pd / 2 + 1.4, 1.6, ph + h + 1.6, ph + h + 2.4, c.darkened(0.04), m)
	_gable_z(k, Vector3(0, ph + h + 2.4, pd / 2), pd + 3.0, pw + 3.0, 4.2, 0.6, TERRA, STUCCO_W, Kit.PLASTER, 0.3)
	_gable_x(k, Vector3(0, ph + h, -cd / 2), cw + 1.0, cd + 1.0, 4.0, 0.8, TERRA, STUCCO_W, Kit.PLASTER, 0.3)
	k.pop()


## The Regia (Platner-Ashby s.v. Regia): a principal building of white marble blocks, trapezoidal in plan,
## mean length about 22 m and width 8 m, in three rooms, the largest holding the circular tufa base of the
## sacrarium of Mars (2.53 m across, shown as a low stone ring on the floor line of the court side); in front
## an open court, the whole area about 27 x 12 m, the front on the Sacra Via. Faces +z.
static func _regia(k: Kit) -> void:
	var c := MARBLE
	var m := Kit.STONE
	var a := Vector2(-11.0, -4.0)    # back left
	var b := Vector2(11.0, -4.0)
	var f1 := Vector2(8.6, 4.0)      # front right (the plan narrows towards the Sacra Via)
	var f0 := Vector2(-8.6, 4.0)
	var h := 6.5
	_b(k, -13.5, 0.0, -6.0, 13.5, 0.3, 14.0, TRAVERT.darkened(0.08), m)   # pavement of the area
	for seg in [[a, b], [b, f1], [f1, f0], [f0, a]]:
		_wall_seg(k, seg[0], seg[1], 0.3, 0.3 + h, 0.7, c, m)
	_wall_seg(k, Vector2(-3.2, -4.0), Vector2(-3.2, 4.0), 0.3, 0.3 + h, 0.5, c, m)   # the two cross walls: three rooms
	_wall_seg(k, Vector2(3.2, -4.0), Vector2(3.2, 4.0), 0.3, 0.3 + h, 0.5, c, m)
	k.door(Vector3(0, 0.3, 4.05), 0.0, 1.8, 3.6, c.darkened(0.06), DWOOD)
	k.door(Vector3(-6.0, 0.3, 4.0), 0.0, 1.5, 3.2, c.darkened(0.06), DWOOD)
	k.door(Vector3(6.0, 0.3, 4.0), 0.0, 1.5, 3.2, c.darkened(0.06), DWOOD)
	k.cylinder(Vector3(0, 0.3, 0), 1.27, 0.15, GROTTA, m, 12)   # the sacrarium base inside
	_gable_x(k, Vector3(0, 0.3 + h, 0), 23.5, 9.4, 2.4, 0.5, TERRA, c, m, 0.25)
	_ring(k, 0.0, 9.0, 4.5, 4.0, 0.4, 0.3, 1.3, GROTTA, m)   # the court's low wall, open towards the street
	k.box(Vector3(0, 0.3, 11.8), Vector3(6.0, 0.4, 0.5), c, m)


## A raised platform with a lean-to portico of columns across the front (the Graecostasis, where
## foreign envoys waited: Varro LL 5.155; the Senaculum; Platner-Ashby s.v. Graecostasis). Size
## assumed: 12 x 9 m, 2.6 m high. Faces +z.
static func _platform_portico(k: Kit) -> void:
	var w := 12.0
	var d := 9.0
	var ph := 2.6
	var c := GROTTA
	var m := Kit.STONE
	_podium(k, w / 2, -d / 2, d / 2, ph, c, m)
	_stair(k, 0.0, 5.0, d / 2 + 0.1, ph, 4, 0.6, c.lightened(0.05), m)
	_b(k, -w / 2 + 0.3, ph, -d / 2 + 0.2, w / 2 - 0.3, ph + 4.6, -d / 2 + 1.0, STUCCO_W, Kit.PLASTER)   # the back wall
	for i in 5:
		_col(k, Vector3(-w / 2 + 1.2 + i * (w - 2.4) / 4.0, ph, d / 2 - 1.0), 4.4, "tuscan", STUCCO_W, Kit.PLASTER, 0)
	_b(k, -w / 2 + 0.2, ph + 4.4, -d / 2 + 0.2, w / 2 - 0.2, ph + 4.9, d / 2 - 0.3, DWOOD, Kit.TIMBER)
	_slab(k, [Vector3(-w / 2, ph + 5.2, d / 2), Vector3(w / 2, ph + 5.2, d / 2), Vector3(w / 2, ph + 6.4, -d / 2 + 0.4), Vector3(-w / 2, ph + 6.4, -d / 2 + 0.4)], 0.3, TERRA, Kit.TILE)


## The Atrium Libertatis (the censors' archive, Livy 43.16.13; Platner-Ashby s.v. Atrium Libertatis; plan
## unknown, assumed from the Tabularium type): a stone base, a hall with a colonnade of Tuscan columns
## before it, a court behind. 30 x 40 m. Faces +z.
static func _archive_hall(k: Kit) -> void:
	var w := 30.0
	var d := 40.0
	var c := PEPERINO
	var m := Kit.STONE
	_b(k, -w / 2, 0.0, -d / 2, w / 2, 3.0, d / 2, c.darkened(0.04), m)
	_stair(k, 0.0, 8.0, d / 2 + 0.1, 3.0, 5, 0.6, c.lightened(0.05), m)
	_ring(k, 0.0, -4.0, w / 2 - 2.0, d / 2 - 8.0, 1.0, 3.0, 11.0, STUCCO_W, Kit.PLASTER)
	for i in 6:
		_col(k, Vector3(-w / 2 + 4.0 + i * (w - 8.0) / 5.0, 3.0, d / 2 - 2.5), 7.0, "tuscan", STUCCO_W, Kit.PLASTER, 0)
	_b(k, -w / 2 + 3.0, 10.0, d / 2 - 4.0, w / 2 - 3.0, 10.9, d / 2 - 1.5, c, m)
	k.door(Vector3(0, 3.0, d / 2 - 7.9), 0.0, 3.2, 5.0, c, DWOOD)
	_gable_x(k, Vector3(0, 11.0, -4.0), w - 2.0, d - 10.0, 3.2, 0.6, TERRA, STUCCO_W, Kit.PLASTER, 0.25)


# --- baths, houses ----------------------------------------------------------------------------


## The Baths of Agrippa (25 BC, Dio 53.27.1; Platner-Ashby s.v. Thermae Agrippae: oriented N-S on the
## axis of the Pantheon, covering about 100-120 m north-south and 80-100 east-west, with a
## rectangular vaulted hall 45 x 19 m and an apse 9 m across in its north wall): the hall, a row
## of vaulted rooms either side, a long pool (the Stagnum) on the west and a portico to the
## Pantheon side. Brick-faced concrete under stucco. Faces +z (south).
static func _baths(k: Kit) -> void:
	var c := STUCCO_W
	var m := Kit.PLASTER
	var W := 90.0
	var D := 110.0
	_b(k, -W / 2, 0.0, -D / 2, W / 2, 0.4, D / 2, TRAVERT.darkened(0.1), Kit.STONE)
	# the central hall, 45 x 19 (long axis along z), with its apse in the north wall
	_b(k, -9.5, 0.4, -34.0, 9.5, 20.0, 11.0, c, m)
	k.cylinder(Vector3(0, 0.4, -34.0), 9.0, 20.0, c, m, 14)
	# barrel vault over the hall: axis along z, so build along x and turn it
	k.push(Kit.at(Vector3(0, 20.0, -11.5), PI / 2.0))
	_barrel(k, 0.0, 0.0, 45.0, 19.0, 0.0, 6.0, TERRA, Kit.TILE, 8)
	k.pop()
	# flanking vaulted rooms and the courtyards between them
	for sx in [-1.0, 1.0]:
		for j in 3:
			var z := -36.0 + j * 24.0
			_b(k, sx * 22.0 - 8.0, 0.4, z - 9.0, sx * 22.0 + 8.0, 12.0, z + 9.0, c, m)
			_barrel(k, sx * 22.0, z, 18.0, 16.0, 12.0, 4.0, TERRA, Kit.TILE, 6)
	# the pool on the west side, 60 x 22 m
	_b(k, -W / 2 + 2.0, 0.4, -30.0, -W / 2 + 24.0, 1.0, 30.0, WATER_C, Kit.WATER)
	# the portico on the south front (the Pantheon side)
	for i in 14:
		_col(k, Vector3(-W / 2 + 6.0 + i * (W - 12.0) / 13.0, 0.4, D / 2 - 3.0), 7.0, "tuscan", STUCCO_W, Kit.PLASTER, 0)
	_b(k, -W / 2 + 4.0, 7.4, D / 2 - 4.5, W / 2 - 4.0, 8.2, D / 2 - 1.5, c, Kit.STONE)
	_slab(k, [Vector3(-W / 2 + 3.0, 8.4, D / 2 - 0.5), Vector3(W / 2 - 3.0, 8.4, D / 2 - 0.5), Vector3(W / 2 - 3.0, 10.0, D / 2 - 7.0), Vector3(-W / 2 + 3.0, 10.0, D / 2 - 7.0)], 0.3, TERRA, Kit.TILE)



## An atrium house (Vitruvius 6.3, 6.5): a street front with two shops (tabernae) and the narrow
## entrance passage (fauces), the atrium with its compluvium and impluvium and the rooms (cubicula,
## alae) round it, the tablinum at its back, and behind that a peristyle garden. About 24 x 42 m.
## Faces +z (the street).
static func _domus(k: Kit) -> void:
	var W := 24.0
	var L := 42.0
	var wh := 4.6
	var wc := STUCCO
	var m := Kit.PLASTER
	_pad(k, W + 2.0, L + 2.0, Color(0.62, 0.57, 0.46), Kit.EARTH, 0.3)
	k.push(Kit.at(Vector3(0, 0.3, 0)))
	# street front block with shops at both ends and the door in the middle
	var z0 := L / 2 - 5.0
	_b(k, -W / 2, 0.0, z0, W / 2, wh, L / 2, wc, m)
	k.door(Vector3(0, 0.0, L / 2 + 0.02), 0.0, 2.2, 3.4, BRICK_C, DWOOD)
	for sx in [-1.0, 1.0]:
		_shopfront(k, Vector3(sx * 7.5, 0.0, L / 2 + 0.02), 0.0, 4.2, 3.0)
	_gable_x(k, Vector3(0, wh, (z0 + L / 2) / 2), W, 5.0, 1.6, 0.5, TERRA, wc, m, 0.2)
	# the atrium range: side rooms and the open atrium (impluvium basin in the centre)
	var za := z0 - 12.0
	_b(k, -W / 2, 0.0, za, -W / 2 + 6.0, wh, z0, wc, m)
	_b(k, W / 2 - 6.0, 0.0, za, W / 2, wh, z0, wc, m)
	_frame_roof(k, Vector3(0, wh, (za + z0) / 2), W / 2 + 0.4, (z0 - za) / 2 + 0.4, 4.0, 4.0, 0.0, 1.4, 0.2, TERRA)
	_b(k, -2.6, 0.0, (za + z0) / 2 - 2.6, 2.6, 0.5, (za + z0) / 2 + 2.6, WATER_C, Kit.WATER)   # the impluvium
	# the tablinum across the back of the atrium and the wings
	var zt := za - 7.0
	_b(k, -W / 2, 0.0, zt, W / 2, wh, za, wc, m)
	_gable_x(k, Vector3(0, wh, (zt + za) / 2), W, 7.0, 1.8, 0.5, TERRA, wc, m, 0.2)
	# the peristyle garden: a colonnade round a court with a pent roof, trees in it
	var pz := zt - 14.0
	for i in 5:
		for sz in [zt - 1.5, pz + 1.5]:
			_col(k, Vector3(-W / 2 + 2.5 + i * (W - 5.0) / 4.0, 0.0, sz), 3.6, "tuscan", STUCCO_W, m, 0)
	for j in range(1, 4):
		for sx in [-W / 2 + 2.5, W / 2 - 2.5]:
			_col(k, Vector3(sx, 0.0, zt - 1.5 - j * (zt - pz - 3.0) / 4.0), 3.6, "tuscan", STUCCO_W, m, 0)
	_frame_roof(k, Vector3(0, 3.8, (zt + pz) / 2), W / 2 - 1.0, (zt - pz) / 2 - 0.5, W / 2 - 4.5, (zt - pz) / 2 - 3.5, 0.0, 0.8, 0.15, TERRA)
	_tree(k, Vector3(0, 0, (zt + pz) / 2), 25.0)
	_b(k, -W / 2, 0.0, pz - 0.6, W / 2, wh * 0.8, pz, wc, m)
	k.pop()


# --- theatres and the amphitheatre ------------------------------------------------------------


## A stone theatre without a temple on the cavea (the Theatre of Marcellus; Platner-Ashby s.v. Theatrum
## Marcelli: diameter about 150 m, scaena 80-90 m long and 20 deep, an apsidal hall about 25 x 15 m
## at each end of the scaena, three open arcades one above the other, Doric below and Ionic above,
## the stage toward the river). The cavea opens to +z (the stage), centre of the semicircle at the
## origin. 150 m across. `timber`: a temporary frame instead (the theatre of Scaurus, 58 BC, Plin. NH 36.113).
static func _theatre(k: Kit, R: float, h: float, timber: bool) -> void:
	var rows := 14
	var orch := R * 0.24
	var row_w := (R - orch) / rows
	var c := TRAVERT.darkened(0.05)
	var c2 := WOOD if timber else c
	var m2 := Kit.TIMBER if timber else Kit.STONE
	seat_rings(k, 0.0, 0.0, orch, orch, PI, TAU, rows, row_w, h * 0.5 / rows, c2, c2, m2, m2, 0.4)
	k.cylinder(Vector3.ZERO, orch, 0.2, Color(0.78, 0.68, 0.48), Kit.EARTH, 24)
	if timber:
		for e in arc_walk(0.0, 0.0, R, R, PI, TAU, 5.0):
			var p: Vector2 = e.pos
			k.box(Vector3(p.x, 0, p.y), Vector3(0.7, h, 0.7), DWOOD, Kit.TIMBER)
		for lv in 3:
			for e in arc_walk(0.0, 0.0, R, R, PI, TAU, 20.0):
				var p: Vector2 = e.pos
				k.box(Vector3(p.x, h * (lv + 1) / 3.5, p.y), Vector3(20.0, 0.4, 0.5), DWOOD, Kit.TIMBER, yaw_x(e.tangent))
	else:
		arc_facade(k, 0.0, 0.0, R, R, PI, TAU, 2, h * 0.4, c, Kit.STONE, 7.0)
		for e in arc_walk(0.0, 0.0, R + 0.3, R + 0.3, PI, TAU, 7.0):
			var p: Vector2 = e.pos
			k.box(Vector3(p.x, h * 0.8, p.y), Vector3(float(e.len) * 1.03, h * 0.2, 1.2), c.lightened(0.04), Kit.STONE, yaw_x(e.tangent))
	var sw := minf(R * 1.2, 90.0)
	k.box(Vector3(0, 0, 8.0), Vector3(sw, 1.4, 16.0), c2, m2)
	k.box(Vector3(0, 1.4, 17.0), Vector3(sw, h * 0.8, 4.0), c if not timber else WOOD, Kit.STONE if not timber else Kit.TIMBER)
	for i in int(sw / 4.5):
		_col(k, Vector3(-sw / 2.0 + 2.0 + i * 4.5, 1.4, 14.5), h * 0.55, "corinthian", MARBLE, Kit.STONE, 0)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * (sw / 2.0 + 6.0), 0, 14.0), Vector3(12.0, h * 0.7, 20.0), c, Kit.STONE)
		k.cylinder(Vector3(sx * (sw / 2.0 + 6.0), h * 0.7, 14.0), 6.0, 0.3, TERRA, Kit.TILE, 10)


## An amphitheatre: an elliptical bowl, `storeys` arcaded storeys, an attic. big = the Flavian
## Amphitheatre (Platner-Ashby s.v. Amphitheatrum Flavium): axes 188 x 156 m, outer wall 48.5 m, three
## arcades with 80 arches each (arches 7.05 x 4.20 m, piers 2.40 wide, 2.70 deep) with engaged Doric,
## Ionic and Corinthian columns, an entablature and attic over each, a top wall with Corinthian pilasters
## and small windows over every second arch, brackets for the velarium masts; arena 86 x 54 m, a
## podium 4 m above it. Not the Republican city, but built for the Colosseum; the small form (2 storeys,
## no masts) stands for the amphitheatre of Statilius Taurus (29 BC; plan unknown).
static func _amphitheatre(k: Kit, big: bool) -> void:
	var a := 94.0 if big else 48.0
	var b := 78.0 if big else 36.0
	var c := TRAVERT.darkened(0.04)
	var m := Kit.STONE
	var arena_a := 43.0 if big else 20.0
	var arena_b := 27.0 if big else 12.0
	var rows := 12 if big else 7
	var rw := (b - arena_b - 6.0) / rows
	var step := (30.0 if big else 14.0) / rows
	# arena floor and podium wall
	for e in arc_walk(0.0, 0.0, arena_a, arena_b, 0.0, TAU, 6.0):
		var p: Vector2 = e.pos
		k.box(Vector3(p.x, 0, p.y), Vector3(float(e.len) * 1.1, 4.0, 1.0), c.lightened(0.05), m, yaw_x(e.tangent))
	k.box(Vector3(0, 0, 0), Vector3(arena_a * 1.8, 0.2, arena_b * 1.8), Color(0.78, 0.68, 0.48), Kit.EARTH)
	# the cavea: rings of seats (the ratio of the ellipse kept)
	for j in rows:
		var hh := 4.0 + (j + 1) * step
		var rx := arena_a + 3.0 + j * rw * (a / b)
		var rz := arena_b + 3.0 + j * rw
		for e in arc_walk(0.0, 0.0, rx + rw * 0.5 * (a / b), rz + rw * 0.5, 0.0, TAU, 6.0):
			var p: Vector2 = e.pos
			k.box(Vector3(p.x, 0, p.y), Vector3(float(e.len) * 1.06, hh, rw * 1.1), c if j < rows * 0.6 else c.darkened(0.1), m, yaw_x(e.tangent))
	# the outer wall: arcaded storeys with their attics
	var bay := 6.6 if big else 6.0
	var heights: Array = [10.4, 10.5, 11.0] if big else [8.5, 8.0]
	var y0 := 1.0
	for st in heights.size():
		var sh: float = heights[st]
		for e in arc_walk(0.0, 0.0, a, b, 0.0, TAU, bay):
			var p: Vector2 = e.pos
			k.push(Kit.at(Vector3(p.x, y0, p.y), yaw_z(e.normal)))
			var bw: float = e.len
			_arcade(k, 0.0, 1, bw, 2.4, 0.0, sh * 0.5, sh * 0.78, -1.4, 1.4, c, m, 5, true)
			_col(k, Vector3(-bw * 0.5 + 1.2, 0.0, 1.5), sh * 0.78, "doric" if st == 0 else ("ionic" if st == 1 else "corinthian"), c.lightened(0.04), m, 0)
			k.box(Vector3(0, sh * 0.78, 0), Vector3(bw * 1.01, sh * 0.22, 3.2), c.lightened(0.05), m)
			k.pop()
		y0 += sh
	if big:   # the top wall with pilasters and windows, and the mast brackets
		for e in arc_walk(0.0, 0.0, a, b, 0.0, TAU, bay):
			var p: Vector2 = e.pos
			k.push(Kit.at(Vector3(p.x, y0, p.y), yaw_z(e.normal)))
			var bw: float = e.len
			k.box(Vector3(0, 0, 0), Vector3(bw * 1.01, 48.5 - y0, 2.8), c, m)
			k.box(Vector3(bw * 0.5, 0, 1.4), Vector3(0.8, 48.5 - y0, 0.5), c.lightened(0.08), m)
			k.box(Vector3(0, (48.5 - y0) * 0.45, 1.41), Vector3(1.2, 2.2, 0.1), DARK_C, Kit.DARK)
			k.box(Vector3(0, 48.5 - y0, 0), Vector3(bw * 1.05, 0.8, 3.4), c.lightened(0.1), m)
			k.box(Vector3(0, 48.5 - y0 + 0.8, 1.7), Vector3(0.5, 1.2, 0.5), c.darkened(0.1), m)
			k.rod(Vector3(0, 48.5 - y0 + 1.0, 1.7), Vector3(0, 48.5 - y0 + 5.0, 2.7), 0.12, DWOOD, Kit.TIMBER)   # a velarium mast
			k.pop()


# --- the Servian wall, its gates, the aqueducts -----------------------------------------------

## The Servian wall, one tile 10 m long along x, 3.6 m thick, 10 m high, front (+z) = the outer face.
## Ashlar of Grotta Oscura tufa in courses 2 Roman feet (0.59 m) high (Platner-Ashby s.v. Murus
## Servii Tullii: blocks 58-61 cm high, wall 3.6 m thick, 10 m high as in the dataset), with a
## walkway and a parapet with merlons on the outer edge (the merlons are assumed). `agger`: the
## wall as the retaining wall of the great earth rampart behind it, 50 ft thick (Dion. Hal. 9.68),
## with the ditch 100 ft wide and 30 ft deep in front (Cic. Rep. 2.11; Strabo 5.3.7): on level ground
## the ditch is shown as a dark strip and its far bank.
static func _servian_wall(k: Kit, agger: bool) -> void:
	var c := GROTTA
	var m := Kit.STONE
	_b(k, -5.1, -1.0, -1.8, 5.1, 10.0, 1.8, c, m)
	_b(k, -5.1, 10.0, 0.9, 5.1, 10.9, 1.8, c.lightened(0.06), m)   # parapet, outer
	for i in 4:
		_b(k, -4.6 + i * 2.5, 10.9, 0.9, -3.4 + i * 2.5, 12.1, 1.8, c.lightened(0.08), m)   # merlons
	_b(k, -5.1, 10.0, -1.8, 5.1, 10.4, -1.3, c.lightened(0.06), m)   # the low inner kerb
	if agger:
		var prof := [Vector2(-1.8, -1.0), Vector2(-1.8, 9.6), Vector2(-5.0, 9.6), Vector2(-16.8, -1.0)]
		var inside := Vector3(0, 4.0, -6.0)
		for i in prof.size():
			var p0: Vector2 = prof[i]
			var p1: Vector2 = prof[(i + 1) % prof.size()]
			k.quad(Vector3(-5.1, p0.y, p0.x), Vector3(5.1, p0.y, p0.x), Vector3(5.1, p1.y, p1.x), Vector3(-5.1, p1.y, p1.x), EARTH_C, Kit.EARTH, inside)
		_b(k, -5.1, -1.0, 5.0, 5.1, 0.1, 35.0, Color(0.30, 0.24, 0.16), Kit.EARTH)   # the ditch
		_b(k, -5.1, -1.0, 35.0, 5.1, 1.2, 38.0, EARTH_C, Kit.EARTH)                  # its far bank


## A tower of the wall, 8 x 8 m and 14 m high, with arrow slits and merlons. Front +z.
static func _servian_tower(k: Kit) -> void:
	var c := GROTTA
	var m := Kit.STONE
	_b(k, -4.0, -1.0, -4.0, 4.0, 14.0, 4.0, c, m)
	_b(k, -4.4, 14.0, -4.4, 4.4, 14.9, 4.4, c.lightened(0.06), m)
	for i in 4:
		for sz in [-4.4, 4.0]:
			_b(k, -4.0 + i * 2.2, 14.9, sz, -3.0 + i * 2.2, 16.0, sz + 0.4, c.lightened(0.08), m)
	for y in [5.0, 9.0]:
		k.box(Vector3(0, y, 4.01), Vector3(0.3, 1.6, 0.05), DARK_C, Kit.DARK)
	k.door(Vector3(0, 0.0, -4.02), PI, 1.6, 2.8, c, DWOOD)


## A gate of the wall with two openings and an inner court (the Porta Carmentalis had two openings,
## Livy 2.49, Ovid Fasti 2.201: Platner-Ashby s.v. Porta Carmentalis; the arch of 3.30 m found south of
## S. Maria in Cosmedin, s.v. Porta Trigemina; the court and the towers are assumed). Outer gatehouse of two
## arches with a middle pier between two towers, a court 14 m deep behind it closed by an inner gate of
## one arch. The wall (3.6 m thick) runs off at both ends. 34 x 26 m, front +z = outside.
static func _servian_gate(k: Kit) -> void:
	var c := GROTTA
	var m := Kit.STONE
	var pw := 3.3
	var yt := 8.0
	# the outer gatehouse z 6..13 (seven metres deep)
	var z0 := 6.0
	var z1 := 13.0
	_b(k, -17.0, -1.0, z0, -9.0, 14.0, z1, c, m)
	_b(k, 9.0, -1.0, z0, 17.0, 14.0, z1, c, m)
	_b(k, -9.0, -1.0, z0, -pw - 0.6, 10.0, z1, c, m)
	_b(k, pw + 0.6, -1.0, z0, 9.0, 10.0, z1, c, m)
	_b(k, -0.6, -1.0, z0, 0.6, 10.0, z1, c, m)            # the middle pier
	_b(k, -(pw + 0.6), yt, z0, -0.6, 10.0, z1, c, m)       # above the two arches
	_b(k, 0.6, yt, z0, pw + 0.6, 10.0, z1, c, m)
	_arch(k, -pw - 0.6, -0.6, 4.2, yt, z0, z1, c, m, 8)
	_arch(k, 0.6, pw + 0.6, 4.2, yt, z0, z1, c, m, 8)
	for sx in [-1.0, 1.0]:
		_b(k, sx * 9.0 - 4.4, 14.0, z0 - 0.4, sx * 9.0 + 4.4, 14.9, z1 + 0.4, c.lightened(0.06), m)
		for i in 4:
			_b(k, sx * 9.0 - 4.0 + i * 2.2, 14.9, z1 - 0.2, sx * 9.0 - 3.0 + i * 2.2, 16.0, z1 + 0.4, c.lightened(0.08), m)
	_b(k, -9.0, 10.0, z0, 9.0, 10.9, z1, c.lightened(0.06), m)
	# the court: side walls and the inner gate
	_b(k, -9.0, -1.0, -2.0, -8.2, 8.0, z0, c, m)
	_b(k, 8.2, -1.0, -2.0, 9.0, 8.0, z0, c, m)
	_b(k, -9.0, -1.0, -3.0, -pw / 2 - 0.5, 9.0, -2.0, c, m)
	_b(k, pw / 2 + 0.5, -1.0, -3.0, 9.0, 9.0, -2.0, c, m)
	_arch(k, -pw / 2, pw / 2, 4.0, 8.0, -3.0, -2.0, c, m, 8)
	_b(k, -pw / 2 - 0.5, 8.0, -3.0, pw / 2 + 0.5, 9.0, -2.0, c, m)


## An aqueduct arcade, one tile 10 m long along x: two bays of arches on piers, the vaulted channel
## (specus) on top. Frontinus Aq. 6-10; Vitruvius 8.6. 12 m high, 2.4 m thick, the specus 1.2 m wide.
## The line of the aqueduct runs along x; front +z.
static func _aqueduct(k: Kit, tall: bool) -> void:
	var H := 20.0 if tall else 10.0
	var c := PEPERINO.lightened(0.08)
	var m := Kit.STONE
	var bay := 5.0
	var pw := 1.8
	_arcade(k, 0.0, 2, bay, pw, -0.5, H * 0.62, H, -1.2, 1.2, c, m, 6, true)
	_b(k, -5.0, H, -1.4, 5.0, H + 0.8, 1.4, c.lightened(0.05), m)
	_b(k, -5.0, H + 0.8, -1.2, 5.0, H + 2.4, -0.5, c.lightened(0.04), m)       # the side walls of the specus
	_b(k, -5.0, H + 0.8, 0.5, 5.0, H + 2.4, 1.2, c.lightened(0.04), m)
	_b(k, -5.0, H + 2.4, -1.3, 5.0, H + 2.8, 1.3, c.lightened(0.08), m)         # the covering slabs
	k.box(Vector3(0, H + 2.8, 0), Vector3(10.0, 0.25, 2.2), c.lightened(0.1), m)


# =============================================================================================
# DISPATCH
# =============================================================================================

const KINDS := [
	"temple_tuscan_archaic", "temple_tuscan_restored", "temple_tuscan_small",
	"temple_tetrastyle_ionic", "temple_tetrastyle_ionic_travertine", "temple_tetrastyle_ionic_marble",
	"temple_hexastyle_corinthian", "temple_hexastyle_corinthian_marble",
	"temple_round", "temple_round_marble",
	"basilica", "basilica_travertine", "curia", "rostra", "portico", "portico_marble", "tabularium", "horrea", "macellum",
	"theatre_pompey", "circus_segment", "circus_end",
	"temple_hexastyle_ionic", "temple_hexastyle_ionic_marble", "temple_octastyle_peripteral",
	"temple_octastyle_pycnostyle", "temple_concord", "regia", "platform_portico", "archive_hall",
	"baths", "domus", "theatre_stone", "theatre_timber", "amphitheatre_flavian", "amphitheatre_small",
	"servian_wall", "servian_wall_agger", "servian_tower", "servian_gate", "aqueduct_arcade", "aqueduct_arcade_tall",
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
		"basilica":
			_basilica(k, false)
		"basilica_travertine":
			_basilica(k, true)
		"curia":
			_curia(k)
		"rostra":
			_rostra(k)
		"portico":
			_portico(k, false)
		"portico_marble":
			_portico(k, true)
		"tabularium":
			_tabularium(k)
		"horrea":
			_horrea(k)
		"macellum":
			_macellum(k)
		"theatre_pompey":
			_theatre_pompey(k)
		"circus_segment":
			_circus_segment(k)
		"circus_end":
			_circus_end(k)
		"temple_hexastyle_ionic":
			_pseudo(k, 6, "ionic", "travertine")
		"temple_hexastyle_ionic_marble":
			_pseudo(k, 6, "ionic", "marble")
		"temple_octastyle_peripteral":
			_metres(k)
			_octastyle(k, true, 11, 12.5, 2.8, true)
			k.pop()
		"temple_octastyle_pycnostyle":
			_metres(k)
			_octastyle(k, false, 9, 11.0, 2.5, true)
			k.pop()
		"temple_concord":
			_metres(k)
			_concord(k)
			k.pop()
		"regia":
			_metres(k)
			_regia(k)
			k.pop()
		"platform_portico":
			_metres(k)
			_platform_portico(k)
			k.pop()
		"archive_hall":
			_metres(k)
			_archive_hall(k)
			k.pop()
		"baths":
			_metres(k)
			_baths(k)
			k.pop()
		"domus":
			_metres(k)
			_domus(k)
			k.pop()
		"theatre_stone":
			_metres(k)
			_theatre(k, 75.0, 32.6, false)
			k.pop()
		"theatre_timber":
			_metres(k)
			_theatre(k, 60.0, 25.0, true)
			k.pop()
		"amphitheatre_flavian":
			_metres(k)
			_amphitheatre(k, true)
			k.pop()
		"amphitheatre_small":
			_metres(k)
			_amphitheatre(k, false)
			k.pop()
		"servian_wall":
			_metres(k)
			_servian_wall(k, false)
			k.pop()
		"servian_wall_agger":
			_metres(k)
			_servian_wall(k, true)
			k.pop()
		"servian_tower":
			_metres(k)
			_servian_tower(k)
			k.pop()
		"servian_gate":
			_metres(k)
			_servian_gate(k)
			k.pop()
		"aqueduct_arcade":
			_metres(k)
			_aqueduct(k, false)
			k.pop()
		"aqueduct_arcade_tall":
			_metres(k)
			_aqueduct(k, true)
			k.pop()
		_:
			_pad(k, 1.0, 1.0)
	return k.finish()
