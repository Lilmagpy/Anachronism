## Urbs (U8): the architectural orders, after Vitruvius, in metres. Columns (base, fluted
## shaft, capital) for the Tuscan, Doric, Ionic and Corinthian orders; the entablature of each
## (architrave with its fasciae, frieze, dentils or triglyphs, corona and sima); pediments with
## their raking cornice, sculpture and acroteria; tiled roofs with ridge tiles and antefixes;
## bronze doors; statues. Everything is built with UrbsMonumentMesh and the UrbsMaterials names.
##
## Sources (read on Perseus, Morgan's translation): Vitruvius 3.3 (intercolumniations and the
## column heights that go with them), 3.4.4 (steps), 3.5 (Ionic base, capital, architrave,
## frieze, dentils, corona, tympanum one ninth of the corona's front, acroteria), 4.1.8 and
## 4.1.11-12 (Doric 7 d, Ionic 9 d; the Corinthian capital as high as the column is thick,
## abacus 1/7, leaves in thirds), 4.3 (Doric: module half a diameter, column 14 modules,
## capital 1, architrave 1, triglyphs 1 x 1.5, square metopes, corona 1/2 projecting 2/3),
## 4.7 (Tuscan: column 1/3 of the width, d = h/7, base d/2, taper 1/4, capital d/2 in three
## parts, mutules projecting 1/4 of the column height, eaves one third of the roof).
## Not re-read this session, marked `# unverified`: the diminution table (3.3.12), 24 Ionic
## flutes (3.5.14), the Attic plinth width (3.5.1), doorway proportions (4.6).
class_name UrbsOrders
extends RefCounted

const MM := preload("res://scripts/urbs/monument_mesh.gd")

## Axial column spacing in lower diameters (clear space + 1): Vitr. 3.3.2-6.
const SPACING := {"pycnostyle": 2.5, "systyle": 3.0, "eustyle": 3.25, "diastyle": 4.0, "araeostyle": 4.5}
## Column height in lower diameters for each spacing: Vitr. 3.3.10 (pycnostyle 10, systyle and
## eustyle 9.5, diastyle 8.5, araeostyle 8).
const HEIGHT := {"pycnostyle": 10.0, "systyle": 9.5, "eustyle": 9.5, "diastyle": 8.5, "araeostyle": 8.0}

static var _column_cache := {}


## Column height in diameters: Tuscan and Doric 7 (4.7.2, 4.1.8), the slender orders by their
## spacing (3.3.10); a Corinthian column has the Ionic proportions but for its capital (4.1.1).
static func height_ratio(order: String, intercol := "eustyle") -> float:
	if order == "tuscan" or order == "doric":
		return 7.0
	return float(HEIGHT.get(intercol, 9.5))


static func spacing_ratio(intercol: String) -> float:
	return float(SPACING.get(intercol, 3.25))


## Top radius / bottom radius of a shaft by its height (Vitr. 3.3.12: under 15 ft 5/6, 15-20 ft
## 11/13, 20-30 ft 6/7, 30-40 ft 13/15, 40-50 ft 7/8).  # unverified: table recalled, not re-read
static func diminution(h: float) -> float:
	if h < 4.44:
		return 5.0 / 6.0
	if h < 5.92:
		return 11.0 / 13.0
	if h < 8.88:
		return 6.0 / 7.0
	if h < 11.84:
		return 13.0 / 15.0
	return 7.0 / 8.0


# --- columns ------------------------------------------------------------------------------------


## The mesh of one column of `order`, `h` metres high and `d` thick at the foot (d = 0 takes the
## order's ratio), in material `mat`, at detail `lod` (0 fluted and moulded, 1 plain, 2 a post).
## Cached: a temple's twenty columns share one mesh, and UrbsMonuments draws them in a MultiMesh.
static func column_mesh(order: String, h: float, mat: String, lod := 0, d := 0.0, intercol := "eustyle") -> ArrayMesh:
	if d <= 0.0:
		d = h / height_ratio(order, intercol)
	var key := "%s|%s|%.2f|%.2f|%d" % [order, mat, h, d, lod]
	if _column_cache.has(key):
		return _column_cache[key]
	var mm := MM.new()
	column(mm, Vector3.ZERO, h, order, mat, lod, d)
	var mesh := mm.finish_mesh()
	_column_cache[key] = mesh
	return mesh


## Builds one column straight into `mm` (for the few that are not repeated).
static func column(mm: UrbsMonumentMesh, foot: Vector3, h: float, order: String, mat: String, lod := 0, d := 0.0) -> void:
	if d <= 0.0:
		d = h / height_ratio(order)
	var r := d * 0.5
	if lod >= 2:
		mm.frustum(foot, r, r * 0.9, h, mat, 6, true)
		return
	var sides := 16 if lod == 0 else 10
	var top := diminution(h)
	var bh := 0.0
	var cap := 0.0
	match order:
		"tuscan":
			bh = 0.5 * d
			cap = 0.5 * d
		"doric":
			bh = 0.0
			cap = 0.5 * d
		"ionic":
			bh = 0.5 * d
			cap = 0.55 * d
		_:
			bh = 0.5 * d
			cap = d
	# base
	if order == "tuscan":
		# Vitr. 4.7.3: base half a diameter high, its plinth round, as thick as the column
		mm.lathe(foot, PackedVector2Array([Vector2(r * 1.2, 0.0), Vector2(r * 1.2, bh * 0.5), Vector2(r * 1.15, bh * 0.6), Vector2(r * 1.0, bh)]), mat, sides, false)
	elif order != "doric":
		_attic_base(mm, foot, d, mat, sides)
	# shaft
	var sh := h - bh - cap
	var flutes := 0
	if lod == 0:
		flutes = 20 if order == "doric" else (0 if order == "tuscan" else 24)   # 4.3.9; 3.5.14 # unverified
	_shaft(mm, foot + Vector3(0, bh, 0), r, r * top, sh, mat, flutes, sides)
	# capital
	var ty := bh + sh
	var rt := r * top
	match order:
		"tuscan":
			_tuscan_capital(mm, foot + Vector3(0, ty, 0), d, rt, cap, mat, sides)
		"doric":
			_doric_capital(mm, foot + Vector3(0, ty, 0), d, rt, cap, mat, sides)
		"ionic":
			_ionic_capital(mm, foot + Vector3(0, ty, 0), d, rt, cap, mat, sides, lod)
		_:
			_corinthian_capital(mm, foot + Vector3(0, ty, 0), d, rt, cap, mat, sides, lod)


## The Attic base (Vitr. 3.5.2): half a diameter high; its plinth one third of that, square
## (1 3/8 d wide, 3.5.1 # unverified); of the rest, a quarter is the upper torus and three
## quarters the lower torus and the scotia with its fillets.
static func _attic_base(mm: UrbsMonumentMesh, foot: Vector3, d: float, mat: String, sides: int) -> void:
	var bh := 0.5 * d
	var plinth := bh / 3.0
	var rest := bh - plinth
	mm.box(foot, Vector3(d * 1.375, plinth, d * 1.375), mat)
	var r := d * 0.5
	var lt := rest * 0.375   # lower torus
	var sc := rest * 0.375   # scotia and fillets
	var ut := rest * 0.25    # upper torus
	var y := plinth
	var prof := PackedVector2Array()
	prof.append(Vector2(r * 1.36, y))
	prof.append(Vector2(r * 1.42, y + lt * 0.5))
	prof.append(Vector2(r * 1.30, y + lt))
	prof.append(Vector2(r * 1.22, y + lt + sc * 0.15))
	prof.append(Vector2(r * 1.10, y + lt + sc * 0.5))          # the scotia's hollow
	prof.append(Vector2(r * 1.20, y + lt + sc * 0.85))
	prof.append(Vector2(r * 1.24, y + lt + sc))
	prof.append(Vector2(r * 1.28, y + lt + sc + ut * 0.5))
	prof.append(Vector2(r * 1.08, y + lt + sc + ut))
	prof.append(Vector2(r * 1.0, y + lt + sc + ut))
	mm.lathe(foot, prof, mat, sides, false)


## A shaft tapering from r0 to r1 over h. `flutes` > 0 cuts that many flutes (concave channels
## between sharp arrises for Ionic and Corinthian, 24; the Doric 20 meet in arrises too).
static func _shaft(mm: UrbsMonumentMesh, foot: Vector3, r0: float, r1: float, h: float, mat: String, flutes: int, sides: int) -> void:
	if flutes <= 0:
		mm.frustum(foot, r0, r1, h, mat, sides, false)
		return
	mm.push(MM.at(foot))
	var n := flutes * 2
	var depth := 0.88
	var ctr := Vector3(0, h * 0.5, 0)
	# a short plain band at the foot and the head (the fillets of the apophyge), then the flutes
	var band := minf(0.12 * r0, h * 0.04)
	mm.frustum(Vector3.ZERO, r0, r0, band, mat, sides, false)
	mm.frustum(Vector3(0, h - band, 0), r1, r1, band, mat, sides, false)
	var y0 := band
	var y1 := h - band
	var ra := lerpf(r0, r1, y0 / h)
	var rb := lerpf(r0, r1, y1 / h)
	for i in n:
		var a0 := i * TAU / n
		var a1 := (i + 1) * TAU / n
		var f0 := 1.0 if i % 2 == 0 else depth
		var f1 := 1.0 if (i + 1) % 2 == 0 else depth
		var b0 := Vector3(cos(a0) * ra * f0, y0, sin(a0) * ra * f0)
		var b1 := Vector3(cos(a1) * ra * f1, y0, sin(a1) * ra * f1)
		var t0 := Vector3(cos(a0) * rb * f0, y1, sin(a0) * rb * f0)
		var t1 := Vector3(cos(a1) * rb * f1, y1, sin(a1) * rb * f1)
		mm.quad(b0, b1, t1, t0, mat, ctr)
	mm.pop()


## Vitr. 4.7.3: the Tuscan capital half a diameter high in three parts: abacus (as wide as
## the foot of the column), echinus, and the necking with its congé.
static func _tuscan_capital(mm: UrbsMonumentMesh, foot: Vector3, d: float, rt: float, cap: float, mat: String, sides: int) -> void:
	var t := cap / 3.0
	mm.lathe(foot, PackedVector2Array([Vector2(rt, 0.0), Vector2(rt * 1.05, t * 0.85), Vector2(rt * 0.98, t)]), mat, sides, false)
	mm.lathe(foot + Vector3(0, t, 0), PackedVector2Array([Vector2(rt * 0.98, 0.0), Vector2(d * 0.5, t * 0.9), Vector2(d * 0.5, t)]), mat, sides, false)
	mm.box(foot + Vector3(0, 2.0 * t, 0), Vector3(d, t, d), mat)


## Vitr. 4.3.4: the Doric capital one module (d/2) high in three: abacus with its cymatium,
## echinus with its annulets, the necking; abacus 2 1/6 modules wide.
static func _doric_capital(mm: UrbsMonumentMesh, foot: Vector3, d: float, rt: float, cap: float, mat: String, sides: int) -> void:
	var t := cap / 3.0
	var aw := d * 1.083
	mm.frustum(foot, rt, rt * 1.02, t, mat, sides, false)
	mm.lathe(foot + Vector3(0, t, 0), PackedVector2Array([Vector2(rt * 1.02, 0.0), Vector2(rt * 1.1, t * 0.15), Vector2(rt * 1.12, t * 0.3), Vector2(aw * 0.48, t * 0.9), Vector2(aw * 0.49, t)]), mat, sides, false)
	mm.box(foot + Vector3(0, 2.0 * t, 0), Vector3(aw, t * 0.8, aw), mat)
	mm.box(foot + Vector3(0, 2.8 * t, 0), Vector3(aw * 1.03, t * 0.2, aw * 1.03), mat)


## Vitr. 3.5.5-7: the Ionic capital: abacus as wide as the foot of the column plus one
## eighteenth; the volutes hang either side of it over an echinus; the capital's height half
## the abacus. The volute rolls (pulvini) run front to back.
static func _ionic_capital(mm: UrbsMonumentMesh, foot: Vector3, d: float, rt: float, cap: float, mat: String, sides: int, lod: int) -> void:
	var aw := d * (1.0 + 1.0 / 18.0)
	var ech := cap * 0.4
	mm.lathe(foot, PackedVector2Array([Vector2(rt, 0.0), Vector2(rt * 1.04, ech * 0.3), Vector2(rt * 1.16, ech * 0.75), Vector2(rt * 1.2, ech)]), mat, sides, false)
	var vol_r := cap * 0.36
	var vy := ech + vol_r * 0.95
	if lod == 0:
		for s: float in [-1.0, 1.0]:
			# the volute: a drum lying along z, a smaller eye in its face
			mm.disc_z(foot + Vector3(s * (aw * 0.5 + vol_r * 0.1), vy, 0), vol_r, d * 0.78, mat, 12)
			mm.disc_z(foot + Vector3(s * (aw * 0.5 + vol_r * 0.1), vy, 0), vol_r * 0.42, d * 0.84, mat, 8)
		# the cushion between the volutes, seen from the sides
		mm.box(foot + Vector3(0, ech, 0), Vector3(aw * 1.0, vol_r * 1.6, d * 0.7), mat)
	else:
		mm.box(foot + Vector3(0, ech, 0), Vector3(aw * 1.0 + vol_r * 2.0, vol_r * 1.9, d * 0.78), mat)
	mm.box(foot + Vector3(0, ech + vol_r * 1.9, 0), Vector3(aw, cap - ech - vol_r * 1.9, aw), mat)


## Vitr. 4.1.11-12: the Corinthian capital as high as the column is thick; the abacus one
## seventh of that, its diagonals twice the capital's height; the rest in three: two rows of
## acanthus leaves and, above them, the stalks and volutes that run out to the abacus corners.
static func _corinthian_capital(mm: UrbsMonumentMesh, foot: Vector3, d: float, rt: float, cap: float, mat: String, sides: int, lod: int) -> void:
	var ab := cap / 7.0
	var body := cap - ab
	var third := body / 3.0
	var half_diag := cap            # diagonal = 2 cap
	var aw := half_diag * sqrt(2.0)     # a square abacus of that diagonal
	if lod > 0:
		mm.frustum(foot, rt, aw * 0.42, body, mat, sides, false)
		mm.box(foot + Vector3(0, body, 0), Vector3(aw * 0.9, ab, aw * 0.9), mat)
		return
	# the bell
	mm.lathe(foot, PackedVector2Array([Vector2(rt, 0.0), Vector2(rt * 0.98, third * 0.9), Vector2(rt * 1.08, third * 2.0), Vector2(aw * 0.36, body)]), mat, sides, false)
	# two rows of leaves: eight leaves each, the tips curling out
	for row in 2:
		var y := row * third
		var rr := rt * (1.12 if row == 0 else 1.22)
		var tip := third * 1.05
		for i in 8:
			var a := (i + 0.5 * row) * TAU / 8.0
			var dir := Vector3(cos(a), 0, sin(a))
			var side := Vector3(-sin(a), 0, cos(a)) * (rr * 0.36)
			var base_in := foot + Vector3(0, y, 0) + dir * (rr * 0.9)
			var p0 := base_in - side
			var p1 := base_in + side
			var p2 := foot + Vector3(0, y + tip, 0) + dir * (rr * 1.25) + side * 0.9
			var p3 := foot + Vector3(0, y + tip, 0) + dir * (rr * 1.25) - side * 0.9
			var p4 := foot + Vector3(0, y + tip * 0.9, 0) + dir * (rr * 1.45)   # the curled tip
			mm.quad(p0, p1, p2, p3, mat, foot + Vector3(0, y + tip * 0.5, 0))
			mm.tri(p2, p3, p4, mat, foot + Vector3(0, y + tip * 0.5, 0))
	# the volutes at the four corners under the abacus
	var vy := 2.0 * third + third * 0.45
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mm.frustum(foot + Vector3(sx * aw * 0.36, vy, sz * aw * 0.36), rt * 0.22, rt * 0.3, third * 0.55, mat, 6, true)
	# the abacus, its four sides hollowed: drawn as four bevelled arms
	mm.box(foot + Vector3(0, body, 0), Vector3(aw * 0.74, ab, aw * 0.74), mat)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mm.box(foot + Vector3(sx * aw * 0.37, body, sz * aw * 0.37), Vector3(aw * 0.26, ab, aw * 0.26), mat)


# --- entablature ----------------------------------------------------------------------------------


## The height of an architrave for a column of `h` metres (Vitr. 3.5.8: half a diameter under
## 15 ft; 1/13 of the column from 15 to 20 ft; 1/12.5 to 25 ft; 1/12 to 30 ft; beyond that
## 1/12 # unverified extrapolation).
static func architrave_height(h: float, d: float) -> float:
	if h < 4.44:
		return 0.5 * d
	if h < 5.92:
		return h / 13.0
	if h < 7.4:
		return h / 12.5
	return h / 12.0


## Total entablature height for an order on columns `h` high and `d` thick.
static func entablature_height(order: String, h: float, d: float, sculpted := false) -> float:
	match order:
		"doric":
			return 3.0 * d * 0.5   # architrave 1, frieze 1.5, corona 0.5 modules (4.3.4-6)
		"tuscan":
			return 1.1 * d
	var a := architrave_height(h, d)
	var f := a * (1.25 if sculpted else 0.75)
	var mid := a * (6.0 / 7.0) * (4.0 / 12.0)
	return a + f + mid + mid + mid * 0.5


## The entablature all round the rectangle x0..x1, z0..z1 (the outer faces of the columns'
## axes plus half a diameter), standing on y. `frieze_mat` is the frieze's own surface (painted
## stucco on Republican temples, marble later). Returns the top height.
static func entablature(mm: UrbsMonumentMesh, order: String, h: float, d: float, x0: float, x1: float, z0: float, z1: float,
		y: float, mat: String, frieze_mat: String, lod := 0, sculpted := false, col_xs := PackedFloat32Array(), total_h := 0.0) -> float:
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var hx := (x1 - x0) * 0.5
	var hz := (z1 - z0) * 0.5
	match order:
		"doric":
			return _doric_entablature(mm, d, cx, cz, hx, hz, y, mat, frieze_mat, lod, col_xs)
		"tuscan":
			return _tuscan_entablature(mm, h, d, cx, cz, hx, hz, y, mat, frieze_mat, lod)
	var a := architrave_height(h, d)
	if total_h > 0.0:   # a measured entablature: keep Vitruvius' ratios, scale to the height
		a = total_h / (1.0 + (1.25 if sculpted else 0.75) + 2.5 * (6.0 / 7.0) * (4.0 / 12.0))
	var cym := a / 7.0
	var rest := a - cym
	var f1 := rest * 3.0 / 12.0
	var f2 := rest * 4.0 / 12.0
	var f3 := rest * 5.0 / 12.0
	var t := d * 0.9   # the depth of the beam
	var yy := y
	if lod >= 1:
		mm.ring(cx, cz, hx + 0.02 * d, hz + 0.02 * d, t, yy, yy + a, mat)
	else:
		# the three fasciae, each stepping out, then the crowning cymatium (3.5.10)
		mm.ring(cx, cz, hx, hz, t, yy, yy + f1, mat)
		mm.ring(cx, cz, hx + 0.03 * d, hz + 0.03 * d, t, yy + f1, yy + f1 + f2, mat)
		mm.ring(cx, cz, hx + 0.06 * d, hz + 0.06 * d, t, yy + f1 + f2, yy + rest, mat)
		mm.ring(cx, cz, hx + 0.12 * d, hz + 0.12 * d, t, yy + rest, yy + a, mat)
	yy += a
	var f := a * (1.25 if sculpted else 0.75)
	mm.ring(cx, cz, hx + 0.02 * d, hz + 0.02 * d, t, yy, yy + f, frieze_mat)
	var fc := f / 7.0
	mm.ring(cx, cz, hx + 0.1 * d, hz + 0.1 * d, t, yy + f - fc, yy + f, mat)
	yy += f
	# the dentil band (3.5.11): as high as the middle fascia, projecting as much as it is high;
	# each dentil half as wide as it is high, the gaps two thirds of a dentil
	var dh := f2
	if lod == 0:
		var dw := dh * 0.5
		var gap := dw * 2.0 / 3.0
		var step := dw + gap
		mm.ring(cx, cz, hx + 0.1 * d, hz + 0.1 * d, t, yy, yy + dh, mat)   # the band behind the dentils
		var out := 0.1 * d + dh
		for side in 4:
			var len := (hx if side < 2 else hz) * 2.0
			var n := int(len / step)
			for i in n:
				var s := -len * 0.5 + (i + 0.5) * step
				var p: Vector3
				match side:
					0: p = Vector3(cx + s, yy, cz + hz + out - dh * 0.5)
					1: p = Vector3(cx + s, yy, cz - hz - out + dh * 0.5)
					2: p = Vector3(cx + hx + out - dh * 0.5, yy, cz + s)
					_: p = Vector3(cx - hx - out + dh * 0.5, yy, cz + s)
				var sz := Vector3(dw, dh, dh) if side < 2 else Vector3(dh, dh, dw)
				mm.box(p, sz, mat)
	else:
		mm.ring(cx, cz, hx + 0.1 * d + dh, hz + 0.1 * d + dh, t, yy, yy + dh, mat)
	yy += dh
	# corona as high as the middle fascia, projecting with the dentils as much as their height
	var out2 := 0.1 * d + dh * 2.0
	mm.ring(cx, cz, hx + out2, hz + out2, t + out2, yy, yy + f2, mat)
	yy += f2
	# the sima (cymatium) above the corona, an eighth higher at the pediment: a cavetto
	mm.ring(cx, cz, hx + out2 + 0.02 * d, hz + out2 + 0.02 * d, 0.3 * d, yy, yy + f2 * 0.5, mat)
	yy += f2 * 0.5
	return yy


## Doric entablature (Vitr. 4.3.4-6): architrave one module with the taenia and guttae, frieze
## of triglyphs (one module wide, one and a half high) and square metopes, corona half a module
## projecting two thirds. `col_xs` are the column axes across the front, a triglyph over each.
static func _doric_entablature(mm: UrbsMonumentMesh, d: float, cx: float, cz: float, hx: float, hz: float, y: float,
		mat: String, frieze_mat: String, lod: int, col_xs: PackedFloat32Array) -> float:
	var m := d * 0.5
	var t := d * 0.9
	mm.ring(cx, cz, hx, hz, t, y, y + m, mat)
	mm.ring(cx, cz, hx + 0.04 * m, hz + 0.04 * m, t, y + m - m / 7.0, y + m, mat)   # the taenia
	var yf := y + m
	var fh := 1.5 * m
	mm.ring(cx, cz, hx + 0.02 * m, hz + 0.02 * m, t, yf, yf + fh, frieze_mat)
	if lod == 0:
		var step := 2.5 * m   # a triglyph and a metope
		for side in 4:
			var len := (hx if side < 2 else hz) * 2.0
			var n := maxi(1, int(round(len / step)))
			var st := len / n
			for i in n + 1:
				var s := -len * 0.5 + i * st
				if i == n:
					s = len * 0.5 - m * 0.5
				if i == 0:
					s = -len * 0.5 + m * 0.5
				var p: Vector3
				var sz: Vector3
				match side:
					0:
						p = Vector3(cx + s, yf, cz + hz + 0.06 * m)
						sz = Vector3(m, fh, 0.1 * m)
					1:
						p = Vector3(cx + s, yf, cz - hz - 0.06 * m)
						sz = Vector3(m, fh, 0.1 * m)
					2:
						p = Vector3(cx + hx + 0.06 * m, yf, cz + s)
						sz = Vector3(0.1 * m, fh, m)
					_:
						p = Vector3(cx - hx - 0.06 * m, yf, cz + s)
						sz = Vector3(0.1 * m, fh, m)
				mm.box(p, sz, mat)
				# the two channels of the triglyph, cut as darker slots
				for k: float in [-1.0, 1.0]:
					var q := p + (Vector3(k * m * 0.28, fh * 0.1, 0.1 * m) if side < 2 else Vector3(0.1 * m, fh * 0.1, k * m * 0.28))
					if side == 1:
						q = p + Vector3(k * m * 0.28, fh * 0.1, -0.1 * m)
					if side == 3:
						q = p + Vector3(-0.1 * m, fh * 0.1, k * m * 0.28)
					mm.box(q, Vector3(m * 0.14, fh * 0.75, 0.04 * m) if side < 2 else Vector3(0.04 * m, fh * 0.75, m * 0.14), frieze_mat)
	var yc := yf + fh
	mm.ring(cx, cz, hx + 2.0 * m / 3.0, hz + 2.0 * m / 3.0, t + 2.0 * m / 3.0, yc, yc + 0.5 * m, mat)
	return yc + 0.5 * m


## Tuscan (Etrusco-Italic) entablature (Vitr. 4.7.4-5): compound timber beams on the columns,
## a frieze of painted terracotta plaques nailed to them, and the mutules (the rafter ends) that
## carry the roof out a quarter of the column height. Returns the top of the beams; the roof's
## wide eaves are drawn by `roof`.
static func _tuscan_entablature(mm: UrbsMonumentMesh, h: float, d: float, cx: float, cz: float, hx: float, hz: float, y: float,
		mat: String, frieze_mat: String, lod: int) -> float:
	var t := d * 1.1
	mm.ring(cx, cz, hx, hz, t, y, y + 0.5 * d, "timber_oak")
	mm.ring(cx, cz, hx + 0.03 * d, hz + 0.03 * d, t, y + 0.5 * d, y + 1.1 * d, frieze_mat)
	if lod == 0:
		var over := 0.25 * h
		var step := 2.2 * d
		var n := int(hx * 2.0 / step)
		for i in n + 1:
			var x := cx - hx + (hx * 2.0) * i / maxf(n, 1)
			for sz: float in [-1.0, 1.0]:
				mm.box(Vector3(x, y + 0.6 * d, cz + sz * (hz + over * 0.5)), Vector3(0.4 * d, 0.4 * d, over), "timber_oak")
	return y + 1.1 * d


# --- pediment and roof ----------------------------------------------------------------------------


## A gabled, tiled roof whose ridge runs along z from z0 to z1 over a span x0..x1, the eaves at
## height y, the ridge `rise` above: tegulae as a slab, ridge tiles, and antefixes along both
## eaves. `over` is the eaves' projection beyond the span. Tympana at the ends are separate.
static func roof(mm: UrbsMonumentMesh, x0: float, x1: float, z0: float, z1: float, y: float, rise: float, over: float,
		lod := 0, tile_mat := "tegulae", thick := 0.25) -> void:
	var cx := (x0 + x1) * 0.5
	var half := (x1 - x0) * 0.5
	var slope := rise / half
	var ex := half + over
	var drop := over * slope
	var zz0 := z0 - over * 0.5
	var zz1 := z1 + over * 0.5
	for s: float in [-1.0, 1.0]:
		var e0 := Vector3(cx + s * ex, y - drop, zz0)
		var e1 := Vector3(cx + s * ex, y - drop, zz1)
		var r1 := Vector3(cx, y + rise, zz1)
		var r0 := Vector3(cx, y + rise, zz0)
		if s > 0.0:
			mm.slab([e0, e1, r1, r0], thick, tile_mat, "timber_oak")
		else:
			mm.slab([r0, r1, e1, e0], thick, tile_mat, "timber_oak")
	# the cover tiles (imbrices): a raised roll down the slope over every joint of the pan tiles,
	# about 0.6 m apart (a Roman tegula is about 2 ft wide, # unverified); every second one at lod 1
	if lod <= 1:
		var pitch := 0.62 * (1.0 if lod == 0 else 2.0)
		var nrow := int((zz1 - zz0) / pitch)
		for s: float in [-1.0, 1.0]:
			for i in range(1, nrow):
				var z := zz0 + (zz1 - zz0) * i / nrow
				var top := Vector3(cx + s * 0.15, y + rise + thick - 0.15 * slope + 0.05, z)
				var low := Vector3(cx + s * ex, y - drop + thick + 0.05, z)
				mm.rod(top, low, 0.075, "ridge_terracotta")
	# ridge tiles
	mm.rod(Vector3(cx, y + rise + thick * 0.6, zz0 - 0.1), Vector3(cx, y + rise + thick * 0.6, zz1 + 0.1), thick * 0.7, "ridge_terracotta")
	if lod == 0:
		# antefixes every 0.6 m along both eaves (the cover tiles' ends), palmette-shaped
		var n := int((zz1 - zz0) / 0.62)
		for s: float in [-1.0, 1.0]:
			for i in n + 1:
				var z := zz0 + (zz1 - zz0) * i / maxf(n, 1)
				var p := Vector3(cx + s * ex, y - drop + thick, z)
				mm.push(MM.at(p, s * PI / 2.0))
				mm.tri(Vector3(-0.17, 0, 0), Vector3(0.17, 0, 0), Vector3(0, 0.34, 0), "antefix_terracotta", Vector3(0, 0.1, -1.0))
				mm.tri(Vector3(-0.17, 0, -0.03), Vector3(0.17, 0, -0.03), Vector3(0, 0.34, -0.03), "antefix_terracotta", Vector3(0, 0.1, 1.0))
				mm.pop()
	elif lod == 1:
		for s: float in [-1.0, 1.0]:
			mm.box(Vector3(cx + s * ex, y - drop + thick, (zz0 + zz1) * 0.5), Vector3(0.06, 0.3, zz1 - zz0), "antefix_terracotta")


## A pediment on the front (+z side when `front` is true) at the top of the entablature `y`:
## the tympanum wall between the corona's front x0..x1, its height one ninth of that length
## (Vitr. 3.5.12), the raking cornice, the sculpture in the tympanum and three acroteria (the
## corner ones as high as the tympanum's centre, the middle one an eighth more). `z` is the
## face plane; `depth` how far back the tympanum wall and cornice go. Returns the rise.
static func pediment(mm: UrbsMonumentMesh, x0: float, x1: float, z: float, y: float, front: bool, depth: float,
		mat: String, tymp_mat: String, sculpt_mat: String, lod := 0, sculpture := true, rise_override := 0.0, acro_scale := 1.0) -> float:
	var cx := (x0 + x1) * 0.5
	var span := x1 - x0
	var rise := rise_override if rise_override > 0.0 else span / 9.0
	var dir := 1.0 if front else -1.0
	var zf := z
	var zb := z - dir * depth
	var ch := span * 0.025   # the raking corona's height
	# tympanum wall, recessed behind the cornice
	var inset := ch * 0.9
	var tz0 := zf - dir * inset
	var inside := Vector3(cx, y + rise * 0.3, (tz0 + zb) * 0.5)
	mm.polygon([Vector3(x0 + inset, y, tz0), Vector3(x1 - inset, y, tz0), Vector3(cx, y + rise - inset * 0.3, tz0)], tymp_mat, inside)
	mm.polygon([Vector3(x0 + inset, y, zb), Vector3(x1 - inset, y, zb), Vector3(cx, y + rise - inset * 0.3, zb)], tymp_mat, inside)
	# the raking cornice: two sloping slabs meeting at the apex, with the sima on top
	for s: float in [-1.0, 1.0]:
		var a := Vector3(cx + s * (span * 0.5 + ch * 0.4), y - ch * 0.1, zf)
		var b := Vector3(cx, y + rise + ch * 0.5, zf)
		var up := Vector3(0, ch, 0)
		var back := Vector3(0, 0, -dir * depth)
		var c := Vector3(cx, y + rise * 0.3, zf - dir * depth * 0.5)
		mm.quad(a, b, b + up, a + up, mat, c)                         # face
		mm.quad(a + up, b + up, b + up + back, a + up + back, mat, c)  # top (the sima)
		mm.quad(a, b, b + back, a + back, mat, c)                      # soffit
		mm.quad(a + back, b + back, b + up + back, a + up + back, mat, c)
	if sculpture and lod == 0:
		_tympanum_sculpture(mm, cx, span, zf - dir * inset * 0.5, y, rise, sculpt_mat, dir)
	# acroteria: a plinth and a figure at each corner and the apex (3.5.12)
	var ah := minf((rise - inset * 0.3) * acro_scale, 4.5)   # a figure over 4.5 m would dwarf the temple
	if lod <= 1:
		for s: float in [-1.0, 0.0, 1.0]:
			var hgt := ah * (1.125 if s == 0.0 else 1.0)
			var px := cx + s * (span * 0.5 - ch * 0.2)
			var py := (y + rise + ch * 1.5) if s == 0.0 else (y + ch * 0.9)
			var p := Vector3(px, py, zf - dir * depth * 0.5)
			var pl := hgt * 0.22
			mm.box(p, Vector3(pl * 1.6, pl, minf(depth, pl * 1.6)), mat)
			if lod == 0:
				statue(mm, p + Vector3(0, pl, 0), hgt - pl, sculpt_mat if s != 0.0 else "gilt", dir)
			else:
				mm.frustum(p + Vector3(0, pl, 0), pl * 0.5, pl * 0.3, hgt - pl, sculpt_mat, 6)
	return rise


## Figures in the tympanum: a tall central figure, two standing beside it, reclining ones in
## the corners (the Saturn gable had Tritons with horses, Macrob. Sat. 1.8.4, as read in
## Platner-Ashby s.v. Saturnus; the figures here are generic masses, not portraits).
static func _tympanum_sculpture(mm: UrbsMonumentMesh, cx: float, span: float, z: float, y: float, rise: float, mat: String, dir: float) -> void:
	var usable := rise * 0.78
	statue(mm, Vector3(cx, y + 0.02, z), usable, mat, dir)
	for s: float in [-1.0, 1.0]:
		var x := cx + s * span * 0.16
		statue(mm, Vector3(x, y + 0.02, z), usable * 0.72, mat, dir)
		var x2 := cx + s * span * 0.3
		statue(mm, Vector3(x2, y + 0.02, z), usable * 0.45, mat, dir, true)
		# a reclining figure towards the corner
		var x3 := cx + s * span * 0.4
		mm.box(Vector3(x3, y + 0.02, z), Vector3(span * 0.1, usable * 0.16, usable * 0.14), mat)
		mm.frustum(Vector3(x3 - s * span * 0.03, y + 0.02 + usable * 0.16, z), usable * 0.05, usable * 0.045, usable * 0.09, mat, 6)


## A standing figure about `h` tall facing +z (dir = 1) or -z: plinth-less, a body tapering to
## the shoulders, a head, raised arm. `seated` makes a shorter, broader mass.
static func statue(mm: UrbsMonumentMesh, foot: Vector3, h: float, mat: String, dir := 1.0, seated := false) -> void:
	if seated:
		mm.box(foot, Vector3(h * 0.5, h * 0.45, h * 0.45), mat)
		mm.frustum(foot + Vector3(0, h * 0.45, 0), h * 0.2, h * 0.16, h * 0.38, mat, 7)
		mm.lathe(foot + Vector3(0, h * 0.83, 0), PackedVector2Array([Vector2(0.001, 0.0), Vector2(h * 0.08, h * 0.06), Vector2(h * 0.075, h * 0.13), Vector2(0.001, h * 0.17)]), mat, 7)
		return
	var w := h * 0.17
	mm.frustum(foot, w * 0.8, w * 1.0, h * 0.52, mat, 8, false)       # the robe
	mm.frustum(foot + Vector3(0, h * 0.52, 0), w * 1.0, w * 0.75, h * 0.3, mat, 8, true)   # the torso
	mm.lathe(foot + Vector3(0, h * 0.82, 0), PackedVector2Array([Vector2(w * 0.3, 0.0), Vector2(w * 0.5, h * 0.05), Vector2(w * 0.48, h * 0.13), Vector2(0.001, h * 0.18)]), mat, 8)
	# an arm raised forward
	mm.rod(foot + Vector3(w * 0.9, h * 0.72, 0), foot + Vector3(w * 1.3, h * 0.9, dir * h * 0.12), w * 0.14, mat)


# --- doors and openings -------------------------------------------------------------------------


## A bronze double door in a wall whose face is the plane z = `z` facing +z (turn the frame to
## face elsewhere): the leaves set back into the wall, studded in rows, a moulded stone frame
## (the door's architrave) with a cornice on consoles (Vitr. 4.6, proportions # unverified:
## opening height 2 of 3.5 parts of the room height, width about half the height). `w` and `h`
## are the clear opening.
static func door(mm: UrbsMonumentMesh, foot: Vector3, w: float, h: float, frame_mat: String, leaf_mat := "door_bronze_studded",
		lod := 0, recess := 0.35) -> void:
	var f := maxf(0.12, w * 0.12)   # the frame's width
	var zr := -recess
	# the reveal (the sides of the opening into the wall)
	mm.ext(-w / 2 - 0.02, 0.0, zr, -w / 2 + 0.0, h, 0.0, frame_mat)
	mm.ext(w / 2 - 0.0, 0.0, zr, w / 2 + 0.02, h, 0.0, frame_mat)
	mm.ext(-w / 2, h - 0.02, zr, w / 2, h + 0.0, 0.0, frame_mat)
	# the two leaves, each slightly proud at its stiles, with studs
	for s: float in [-1.0, 1.0]:
		var lx := s * w * 0.25
		mm.box(Vector3(lx, 0.0, zr + 0.04), Vector3(w * 0.5 - 0.01, h, 0.08), leaf_mat)
		if lod == 0:
			var rows := maxi(3, int(h / 0.7))
			var cols := maxi(2, int(w * 0.5 / 0.5))
			for i in rows:
				for j in cols:
					var px := lx - w * 0.25 + (j + 0.5) * (w * 0.5) / cols
					var py := (i + 0.5) * h / rows
					mm.box(Vector3(px, py - 0.04, zr + 0.08), Vector3(0.08, 0.08, 0.04), "bronze")
	# the frame: jambs and lintel with two fasciae, then the cornice on consoles
	for s: float in [-1.0, 1.0]:
		mm.ext(s * (w / 2) + (0.0 if s < 0 else 0.0) - (f if s < 0 else 0.0), 0.0, 0.0, s * (w / 2) + (f if s > 0 else 0.0), h + f, 0.08, frame_mat)
		mm.ext(s * (w / 2) + (0.0 if s < 0 else 0.0) - (f * 0.6 if s < 0 else 0.0), 0.0, 0.08, s * (w / 2) + (f * 0.6 if s > 0 else 0.0), h + f * 0.6, 0.13, frame_mat)
	mm.ext(-w / 2 - f, h, 0.0, w / 2 + f, h + f, 0.08, frame_mat)
	mm.ext(-w / 2 - f * 0.6, h, 0.08, w / 2 + f * 0.6, h + f * 0.6, 0.13, frame_mat)
	if lod == 0:
		# the hyperthyrum: a frieze band and a cornice carried on two consoles
		mm.ext(-w / 2 - f, h + f, 0.0, w / 2 + f, h + f * 1.6, 0.1, frame_mat)
		mm.ext(-w / 2 - f * 1.5, h + f * 1.6, 0.0, w / 2 + f * 1.5, h + f * 2.0, 0.3, frame_mat)
		for s: float in [-1.0, 1.0]:
			mm.box(Vector3(s * (w / 2 + f * 0.5), h + f * 0.2, 0.15), Vector3(f * 0.5, f * 1.4, 0.3), frame_mat)
	# a threshold step
	mm.ext(-w / 2 - f, -0.0, 0.0, w / 2 + f, 0.12, 0.45, frame_mat)


## A window with a wooden lattice or shutters (never a black hole). `style` is "grille" (iron
## bars), "shutters" or "lattice".
static func window(mm: UrbsMonumentMesh, foot: Vector3, w: float, h: float, frame_mat: String, style := "grille", lod := 0) -> void:
	var f := maxf(0.1, w * 0.1)
	var zr := -0.3
	mm.ext(-w / 2 - 0.02, 0.0, zr, -w / 2, h, 0.0, frame_mat)
	mm.ext(w / 2, 0.0, zr, w / 2 + 0.02, h, 0.0, frame_mat)
	mm.ext(-w / 2, h - 0.02, zr, w / 2, h, 0.0, frame_mat)
	mm.ext(-w / 2, -0.02, zr, w / 2, 0.0, 0.0, frame_mat)
	match style:
		"shutters":
			for s: float in [-1.0, 1.0]:
				mm.box(Vector3(s * w * 0.25, 0.0, zr + 0.04), Vector3(w * 0.5 - 0.01, h, 0.06), "shutter_wood")
		"lattice":
			mm.box(Vector3(0, 0, zr + 0.04), Vector3(w, h, 0.03), "shutter_wood")
			if lod == 0:
				for i in 3:
					mm.box(Vector3(-w / 2 + w * (i + 1) / 4.0, 0, zr + 0.06), Vector3(0.04, h, 0.04), "timber_oak")
				mm.box(Vector3(0, h * 0.5 - 0.02, zr + 0.06), Vector3(w, 0.04, 0.04), "timber_oak")
		_:
			# a dim interior plane behind iron bars
			mm.box(Vector3(0, 0, zr + 0.02), Vector3(w, h, 0.02), "stucco_worn")
			if lod == 0:
				var n := maxi(2, int(w / 0.3))
				for i in n:
					mm.box(Vector3(-w / 2 + w * (i + 0.5) / n, 0, zr + 0.1), Vector3(0.04, h, 0.04), "iron")
				mm.box(Vector3(0, h * 0.5 - 0.02, zr + 0.1), Vector3(w, 0.04, 0.04), "iron")
	# a sill and lintel
	mm.ext(-w / 2 - f, -f, 0.0, w / 2 + f, 0.0, 0.1, frame_mat)
	mm.ext(-w / 2 - f, h, 0.0, w / 2 + f, h + f, 0.08, frame_mat)
