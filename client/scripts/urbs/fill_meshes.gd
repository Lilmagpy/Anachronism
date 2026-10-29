## Urbs (D-289, step U3): procedural meshes for the ordinary buildings of Rome (insula, domus,
## casa, taberna, workshop, horti, trees). Used by fill.gd through MultiMesh, so every mesh is
## built once, in metres, around a footprint centred on the origin with its FRONT facing +z and
## its feet at y = 0 (a 4 m foundation skirt hangs below so buildings sit on sloping ground).
## Instances scale x and z to the lot size; y is never scaled.
##
## Sources for the forms:
##   Vitruvius 2.8.17 (LacusCurtius, Gwilt trans., read): the crowd of Rome obliged people to
##     gain in height what the plan could not hold, by piers of stone, burnt brick or rubble
##     walls tied with timber floors, so that Romans were lodged in many storeys -> insulae of
##     3-5 storeys, party walls, timber balconies (maeniana: # unverified as to the word here).
##   Vitruvius 6.3 (read): the atrium house -- entrance passage, atrium with the opening in the
##     roof (compluvium) over the basin (impluvium), alae, tablinum, then the peristyle: here a
##     blank street wall with one door, an atrium whose roof opens to the sky, a middle range and
##     a colonnaded garden at the back.
##   Strabo 5.3.7 (read): Augustus forbade street frontages above 70 feet: no mesh is taller
##     than five storeys (about 16 m).
##   Livy 5.55.2-5 (read): after the Gauls the rebuilding was hasty and the streets crooked --
##     this is why early lots are irregular (fill.gd).
##   Pliny NH 16.36: Rome was roofed with wooden shingles until the war with Pyrrhus
##     (# unverified): casa meshes before 280 BC use a shingle/thatch roof colour.
##   Livy 21.62.3 (read): an ox climbed to the third storey in the Forum Boarium (218 BC):
##     multi-storey dwellings existed by then.
class_name UrbsFillMeshes
extends RefCounted

const SKIRT := 4.0
const WALL := Color(1, 1, 1)
const FOUND := Color(0.48, 0.46, 0.42)
const DARK := Color(0.13, 0.095, 0.075)
const WOOD := Color(0.5, 0.36, 0.24)
const TILE := Color(0.88, 0.42, 0.30)
const THATCH := Color(0.70, 0.58, 0.34)
const SHINGLE := Color(0.50, 0.38, 0.26)

static var _cache := {}


## Mesh for `key`, e.g. "insula:gable:4", "domus", "taberna:0", "casa:tile", "workshop:0",
## "horti", "tree:cypress". `lod` 2 gives boxes and roofs only (no windows or balconies).
static func get_mesh(key: String, lod := 0) -> ArrayMesh:
	var full := "%s@%d" % [key, 0 if lod < 2 else 1]
	if _cache.has(full):
		return _cache[full]
	var p := key.split(":")
	var detail := lod < 2
	var mb: MB
	match p[0]:
		"insula":
			mb = _insula(p[1], int(p[2]), detail)
		"domus":
			mb = _domus(detail)
		"casa":
			mb = _casa(p[1], detail)
		"taberna":
			mb = _taberna(int(p[1]), detail)
		"workshop":
			mb = _workshop(int(p[1]), detail)
		"horti":
			mb = _horti(detail)
		"tree":
			mb = _tree(p[1])
		_:
			mb = MB.new()
			mb.box(Vector3(-1, 0, -1), Vector3(1, 2, 1), WALL)
	var mesh := mb.to_mesh()
	_cache[full] = mesh
	return mesh


# ---------------------------------------------------------------- mesh builder

class MB:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()

	func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, hint := Vector3.ZERO) -> void:
		var nrm := (b - a).cross(d - a)
		if nrm.length_squared() < 1e-10:
			return
		nrm = nrm.normalized()
		if hint != Vector3.ZERO and nrm.dot(hint) < 0.0:
			var t := b
			b = d
			d = t
			nrm = -nrm
		v.append(a); v.append(b); v.append(d)
		n.append(nrm); n.append(nrm); n.append(nrm)
		c.append(col); c.append(col); c.append(col)

	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color, hint := Vector3.ZERO) -> void:
		tri(a, b, d, col, hint)
		tri(a, d, e, col, hint)

	## Box from min corner to max corner, four sides and top (no bottom).
	func box(lo: Vector3, hi: Vector3, col: Color, top := true) -> void:
		quad(Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), col)
		quad(Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), col)
		quad(Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), col)
		quad(Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z), col)
		if top:
			quad(Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), col)

	## Rectangle on a wall of a W x D block: face 0 front(+z) 1 back(-z) 2 right(+x) 3 left(-x);
	## h = position along the wall (x for front/back, z for sides), y = height, off = standoff.
	func rect_on(face: int, h0: float, h1: float, y0: float, y1: float, w: float, d: float, off: float, col: Color) -> void:
		match face:
			0:
				var z := d * 0.5 + off
				quad(Vector3(h0, y0, z), Vector3(h1, y0, z), Vector3(h1, y1, z), Vector3(h0, y1, z), col)
			1:
				var z := -d * 0.5 - off
				quad(Vector3(h1, y0, z), Vector3(h0, y0, z), Vector3(h0, y1, z), Vector3(h1, y1, z), col)
			2:
				var x := w * 0.5 + off
				quad(Vector3(x, y0, h1), Vector3(x, y0, h0), Vector3(x, y1, h0), Vector3(x, y1, h1), col)
			_:
				var x := -w * 0.5 - off
				quad(Vector3(x, y0, h0), Vector3(x, y0, h1), Vector3(x, y1, h1), Vector3(x, y1, h0), col)

	## Gable roof over [x0,x1] x [z0,z1], ridge along x, eaves at `base`, ridge `rh` higher,
	## with the triangular gable ends in `wall_col`.
	func gable(x0: float, x1: float, z0: float, z1: float, base: float, rh: float, roof: Color, wall_col: Color) -> void:
		var zm := (z0 + z1) * 0.5
		var top := base + rh
		quad(Vector3(x0, base, z1), Vector3(x1, base, z1), Vector3(x1, top, zm), Vector3(x0, top, zm), roof, Vector3(0, 1, 0.3))
		quad(Vector3(x1, base, z0), Vector3(x0, base, z0), Vector3(x0, top, zm), Vector3(x1, top, zm), roof, Vector3(0, 1, -0.3))
		tri(Vector3(x1, base, z1), Vector3(x1, base, z0), Vector3(x1, top, zm), wall_col, Vector3(1, 0, 0))
		tri(Vector3(x0, base, z0), Vector3(x0, base, z1), Vector3(x0, top, zm), wall_col, Vector3(-1, 0, 0))

	## Hip roof (four slopes) over [x0,x1] x [z0,z1].
	func hip(x0: float, x1: float, z0: float, z1: float, base: float, rh: float, roof: Color) -> void:
		var zm := (z0 + z1) * 0.5
		var inset := minf((x1 - x0), (z1 - z0)) * 0.3
		var rx0 := x0 + (x1 - x0) * 0.5 - ((x1 - x0) * 0.5 - inset)
		var rx1 := x1 - inset
		var top := base + rh
		quad(Vector3(x0, base, z1), Vector3(x1, base, z1), Vector3(rx1, top, zm), Vector3(rx0, top, zm), roof, Vector3(0, 1, 0.3))
		quad(Vector3(x1, base, z0), Vector3(x0, base, z0), Vector3(rx0, top, zm), Vector3(rx1, top, zm), roof, Vector3(0, 1, -0.3))
		tri(Vector3(x1, base, z1), Vector3(x1, base, z0), Vector3(rx1, top, zm), roof, Vector3(1, 1, 0))
		tri(Vector3(x0, base, z0), Vector3(x0, base, z1), Vector3(rx0, top, zm), roof, Vector3(-1, 1, 0))

	## Lean-to roof sloping from y_hi at z=z_hi down to y_lo at z=z_lo, x in [x0,x1].
	func shed(x0: float, x1: float, z_hi: float, z_lo: float, y_hi: float, y_lo: float, roof: Color) -> void:
		quad(Vector3(x0, y_hi, z_hi), Vector3(x1, y_hi, z_hi), Vector3(x1, y_lo, z_lo), Vector3(x0, y_lo, z_lo), roof, Vector3(0, 1, 0))

	## Frustum of a cone with `sides` sides: bottom radius r0 at y0, top radius r1 at y1.
	func cone(cx: float, cz: float, y0: float, y1: float, r0: float, r1: float, sides: int, col: Color) -> void:
		for s in sides:
			var a0 := TAU * float(s) / sides
			var a1 := TAU * float(s + 1) / sides
			var p0 := Vector3(cx + cos(a0) * r0, y0, cz + sin(a0) * r0)
			var p1 := Vector3(cx + cos(a1) * r0, y0, cz + sin(a1) * r0)
			var q0 := Vector3(cx + cos(a0) * r1, y1, cz + sin(a0) * r1)
			var q1 := Vector3(cx + cos(a1) * r1, y1, cz + sin(a1) * r1)
			var out := Vector3(cos((a0 + a1) * 0.5), 0.2, sin((a0 + a1) * 0.5))
			quad(p0, p1, q1, q0, col, out)

	func to_mesh() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


# ---------------------------------------------------------------- shared pieces

## Four walls of a W x D block from y = 0 to `h` plus a darker foundation skirt below.
static func _walls(b: MB, w: float, d: float, h: float, col := WALL) -> void:
	for face in 4:
		var span := (w if face < 2 else d) * 0.5
		b.rect_on(face, -span, span, -SKIRT, 0.0, w, d, 0.0, FOUND)
		b.rect_on(face, -span, span, 0.0, h, w, d, 0.0, col)


## Evenly spaced rectangles along a wall (windows, shop openings).
static func _row(b: MB, face: int, count: int, half_span: float, y0: float, y1: float, wid: float, w: float, d: float, col: Color, off := 0.03) -> void:
	for i in count:
		var h := -half_span + (float(i) + 0.5) * (2.0 * half_span / float(count))
		b.rect_on(face, h - wid * 0.5, h + wid * 0.5, y0, y1, w, d, off, col)


# ---------------------------------------------------------------- insula

## Tenement block, nominal 18 x 18 m: shops on the ground floor, windows above, timber
## balconies on the street face, tile roof. shape: gable | hip | stepped.
static func _insula(shape: String, storeys: int, detail: bool) -> MB:
	var w := 18.0
	var d := 18.0
	var gf := 3.7
	var sh := 3.1
	var h := gf + sh * float(storeys - 1)
	var b := MB.new()
	var main_z0 := -d * 0.5
	if shape == "stepped":
		main_z0 = -d * 0.5 + 6.0
		var annex_h := maxf(gf, h - sh)
		# lower rear annex
		_walls(b, w, 6.0, annex_h)
		for face in 4:
			pass
		b.shed(-w * 0.5 - 0.3, w * 0.5 + 0.3, -d * 0.5 + 6.0, -d * 0.5 - 0.4, annex_h + 1.0, annex_h, TILE)
	# main block
	var md := d * 0.5 - main_z0
	var mz := (d * 0.5 + main_z0) * 0.5
	var mb := MB.new()
	_walls(mb, w, md, h)
	if shape == "stepped":
		_append(b, mb, Vector3(0, 0, mz))
	else:
		b.v.append_array(mb.v)
		b.n.append_array(mb.n)
		b.c.append_array(mb.c)
	var zc := mz
	if detail:
		var tmp := MB.new()
		# ground floor: shop openings on the front, a door and small windows at the back
		_row(tmp, 0, 4, w * 0.5 - 0.6, 0.0, 2.5, 2.7, w, md, DARK)
		_row(tmp, 0, 4, w * 0.5 - 0.6, 2.5, 2.8, 3.0, w, md, WOOD, 0.05)
		_row(tmp, 1, 2, w * 0.5 - 2.0, 1.2, 2.4, 0.9, w, md, DARK)
		for s in range(1, storeys):
			var y0 := gf + sh * float(s - 1)
			_row(tmp, 0, 5, w * 0.5 - 0.5, y0 + 0.9, y0 + 2.3, 1.15, w, md, DARK)
			_row(tmp, 1, 5, w * 0.5 - 0.5, y0 + 0.9, y0 + 2.3, 1.15, w, md, DARK)
			_row(tmp, 2, 3, md * 0.5 - 1.0, y0 + 0.9, y0 + 2.3, 1.1, w, md, DARK)
			_row(tmp, 3, 3, md * 0.5 - 1.0, y0 + 0.9, y0 + 2.3, 1.1, w, md, DARK)
			# timber balcony on the street face (upper floors only)
			if s >= 2 or storeys == 2:
				var zb := md * 0.5
				for bx in [-4.2, 3.6]:
					tmp.box(Vector3(bx - 1.9, y0 + 0.05, zb), Vector3(bx + 1.9, y0 + 0.2, zb + 1.1), WOOD)
					tmp.box(Vector3(bx - 1.9, y0 + 0.2, zb + 1.0), Vector3(bx + 1.9, y0 + 1.05, zb + 1.1), WOOD, false)
		_append(b, tmp, Vector3(0, 0, zc))
	var roof := MB.new()
	if shape == "hip":
		roof.hip(-w * 0.5 - 0.5, w * 0.5 + 0.5, -md * 0.5 - 0.5, md * 0.5 + 0.5, h, 2.6, TILE)
	else:
		roof.gable(-w * 0.5 - 0.5, w * 0.5 + 0.5, -md * 0.5 - 0.5, md * 0.5 + 0.5, h, 2.4, TILE, WALL)
	_append(b, roof, Vector3(0, 0, zc))
	return b


## Append `src` into `dst`, shifted by `offset`.
static func _append(dst: MB, src: MB, offset: Vector3) -> void:
	for i in src.v.size():
		dst.v.append(src.v[i] + offset)
	dst.n.append_array(src.n)
	dst.c.append_array(src.c)


# ---------------------------------------------------------------- casa

## Small one-storey house, nominal 8 x 9 m. roof: tile | thatch | shingle.
static func _casa(roof_kind: String, detail: bool) -> MB:
	var w := 8.0
	var d := 9.0
	var h := 2.9
	var col := TILE
	if roof_kind == "thatch":
		col = THATCH
	elif roof_kind == "shingle":
		col = SHINGLE
	var b := MB.new()
	_walls(b, w, d, h)
	if detail:
		b.rect_on(0, -0.5, 0.5, 0.0, 2.1, w, d, 0.03, DARK)
		b.rect_on(0, 2.0, 3.0, 1.2, 2.0, w, d, 0.03, DARK)
		b.rect_on(2, -1.0, 0.0, 1.2, 2.0, w, d, 0.03, DARK)
	b.gable(-w * 0.5 - 0.4, w * 0.5 + 0.4, -d * 0.5 - 0.4, d * 0.5 + 0.4, h, 2.0, col, WALL)
	return b


# ---------------------------------------------------------------- taberna

## Shop-front unit, nominal 4.6 x 5.2 m. variant 0: one storey with an awning; 1: two storeys
## with a window; 2: one storey, open front with a plank counter.
static func _taberna(variant: int, detail: bool) -> MB:
	var w := 4.6
	var d := 5.2
	var h := 3.5 if variant != 1 else 6.4
	var b := MB.new()
	_walls(b, w, d, h)
	if detail:
		b.rect_on(0, -w * 0.5 + 0.55, w * 0.5 - 0.55, 0.0, 2.5, w, d, 0.03, DARK)
		b.rect_on(0, -w * 0.5 + 0.4, w * 0.5 - 0.4, 2.5, 2.85, w, d, 0.05, WOOD)
		if variant == 1:
			b.rect_on(0, -0.7, 0.7, 4.3, 5.6, w, d, 0.03, DARK)
		if variant == 0:
			# canvas/plank awning sloping out over the footpath
			b.shed(-w * 0.5 - 0.1, w * 0.5 + 0.1, d * 0.5 + 0.1, d * 0.5 + 1.5, 3.1, 2.45, Color(0.85, 0.7, 0.5))
		if variant == 2:
			b.box(Vector3(-w * 0.5 + 0.7, 0.0, d * 0.5 - 0.1), Vector3(w * 0.5 - 0.7, 1.0, d * 0.5 + 0.5), WOOD)
	b.shed(-w * 0.5 - 0.15, w * 0.5 + 0.15, d * 0.5 + 0.3, -d * 0.5 - 0.3, h + 0.9, h, TILE)
	# side walls rise to the slope: close the two triangles
	b.tri(Vector3(w * 0.5, h, d * 0.5), Vector3(w * 0.5, h, -d * 0.5), Vector3(w * 0.5, h + 0.9, d * 0.5), WALL, Vector3(1, 0, 0))
	b.tri(Vector3(-w * 0.5, h, -d * 0.5), Vector3(-w * 0.5, h, d * 0.5), Vector3(-w * 0.5, h + 0.9, d * 0.5), WALL, Vector3(-1, 0, 0))
	return b


# ---------------------------------------------------------------- workshop

## Craft shop with a yard, nominal 16 x 14 m. variant 0: long hall with wide doors and a stack
## of amphorae; 1: hall with timber stacks.
static func _workshop(variant: int, detail: bool) -> MB:
	var w := 16.0
	var d := 14.0
	var h := 5.0
	var b := MB.new()
	# hall in the rear two thirds, open yard in front behind a low wall
	var hd := 9.0
	var hz := -d * 0.5 + hd * 0.5
	var hall := MB.new()
	_walls(hall, w, hd, h)
	if detail:
		hall.rect_on(0, -4.8, -1.4, 0.0, 3.4, w, hd, 0.03, DARK)
		hall.rect_on(0, 1.4, 4.8, 0.0, 3.4, w, hd, 0.03, DARK)
		_row(hall, 2, 2, 3.0, 2.8, 4.0, 0.9, w, hd, DARK)
	hall.gable(-w * 0.5 - 0.5, w * 0.5 + 0.5, -hd * 0.5 - 0.5, hd * 0.5 + 0.5, h, 2.8, TILE, WALL)
	_append(b, hall, Vector3(0, 0, hz))
	# yard wall (low) on the three open sides of the front yard
	var yz0 := -d * 0.5 + hd
	b.box(Vector3(-w * 0.5, 0.0, d * 0.5 - 0.4), Vector3(w * 0.5, 1.7, d * 0.5), WALL)
	b.box(Vector3(-w * 0.5, 0.0, yz0), Vector3(-w * 0.5 + 0.4, 1.7, d * 0.5), WALL)
	b.box(Vector3(w * 0.5 - 0.4, 0.0, yz0), Vector3(w * 0.5, 1.7, d * 0.5), WALL)
	b.rect_on(0, -1.4, 1.4, 0.0, 1.7, w, d, 0.0, DARK)   # yard gate gap
	# goods in the yard
	if variant == 0:
		for i in 4:
			for j in 2:
				b.box(Vector3(-6.5 + i * 0.9, 0.0, yz0 + 1.0 + j * 0.9), Vector3(-5.8 + i * 0.9, 1.2, yz0 + 1.6 + j * 0.9), Color(0.78, 0.5, 0.32))
	else:
		b.box(Vector3(3.0, 0.0, yz0 + 0.8), Vector3(6.4, 1.6, yz0 + 2.0), WOOD)
		b.box(Vector3(3.4, 1.6, yz0 + 1.0), Vector3(6.0, 2.2, yz0 + 1.8), WOOD)
	return b


# ---------------------------------------------------------------- domus

## Atrium house, nominal 20 x 34 m: blank street wall with a door; front range around the atrium
## (roof sloping in to the opening over the impluvium); the middle range (tablinum and alae);
## the peristyle garden at the back (lawn, pool, colonnade under a lean-to roof).
static func _domus(detail: bool) -> MB:
	var w := 20.0
	var d := 34.0
	var h0 := 4.9
	var b := MB.new()
	_walls(b, w, d, h0)
	if detail:
		b.rect_on(0, -1.5, 1.5, 0.0, 3.3, w, d, 0.02, Color(0.82, 0.8, 0.74))
		b.rect_on(0, -0.9, 0.9, 0.0, 2.8, w, d, 0.04, DARK)
		b.rect_on(0, -7.0, -5.8, 3.4, 4.2, w, d, 0.03, DARK)
		b.rect_on(0, 5.8, 7.0, 3.4, 4.2, w, d, 0.03, DARK)
	var hx := w * 0.5
	var hz := d * 0.5
	# atrium ring roof (front range): outer edge z in [4, 17], opening 6.4 x 5.8
	var ox0 := -hx
	var ox1 := hx
	var oz0 := 4.0
	var oz1 := hz
	var ix0 := -3.2
	var ix1 := 3.2
	var iz0 := 7.6
	var iz1 := 13.4
	var ho := h0
	var hi := h0 - 0.9
	var up := Vector3(0, 1, 0)
	b.quad(Vector3(ox0, ho, oz1), Vector3(ox1, ho, oz1), Vector3(ix1, hi, iz1), Vector3(ix0, hi, iz1), TILE, up)
	b.quad(Vector3(ox1, ho, oz0), Vector3(ox0, ho, oz0), Vector3(ix0, hi, iz0), Vector3(ix1, hi, iz0), TILE, up)
	b.quad(Vector3(ox0, ho, oz0), Vector3(ox0, ho, oz1), Vector3(ix0, hi, iz1), Vector3(ix0, hi, iz0), TILE, up)
	b.quad(Vector3(ox1, ho, oz1), Vector3(ox1, ho, oz0), Vector3(ix1, hi, iz0), Vector3(ix1, hi, iz1), TILE, up)
	# impluvium basin seen through the opening
	b.quad(Vector3(ix0, 1.0, iz1), Vector3(ix1, 1.0, iz1), Vector3(ix1, 1.0, iz0), Vector3(ix0, 1.0, iz0), Color(0.34, 0.45, 0.52), up)
	b.quad(Vector3(ix0 + 0.8, 0.4, iz1 - 0.8), Vector3(ix1 - 0.8, 0.4, iz1 - 0.8), Vector3(ix1 - 0.8, 0.4, iz0 + 0.8), Vector3(ix0 + 0.8, 0.4, iz0 + 0.8), Color(0.3, 0.38, 0.44), up)
	# middle range: tablinum and alae under a gable
	b.gable(-hx, hx, -1.0, oz0, h0, 1.4, TILE, WALL)
	# peristyle: outer z in [-17, -1], inner garden rect 13.6 x 9.6
	var gx0 := -6.8
	var gx1 := 6.8
	var gz0 := -13.8
	var gz1 := -4.2
	var pz0 := -hz
	var pz1 := -1.0
	var hl := 3.6
	b.quad(Vector3(-hx, h0, pz1), Vector3(hx, h0, pz1), Vector3(gx1, hl, gz1), Vector3(gx0, hl, gz1), TILE, up)
	b.quad(Vector3(hx, h0, pz0), Vector3(-hx, h0, pz0), Vector3(gx0, hl, gz0), Vector3(gx1, hl, gz0), TILE, up)
	b.quad(Vector3(-hx, h0, pz0), Vector3(-hx, h0, pz1), Vector3(gx0, hl, gz1), Vector3(gx0, hl, gz0), TILE, up)
	b.quad(Vector3(hx, h0, pz1), Vector3(hx, h0, pz0), Vector3(gx1, hl, gz0), Vector3(gx1, hl, gz1), TILE, up)
	# lawn, pool, shrubs
	b.quad(Vector3(gx0, 0.3, gz1), Vector3(gx1, 0.3, gz1), Vector3(gx1, 0.3, gz0), Vector3(gx0, 0.3, gz0), Color(0.42, 0.52, 0.28), up)
	b.quad(Vector3(-1.8, 0.4, -6.2), Vector3(1.8, 0.4, -6.2), Vector3(1.8, 0.4, -11.8), Vector3(-1.8, 0.4, -11.8), Color(0.34, 0.45, 0.52), up)
	if detail:
		for s in [Vector2(-5.0, -5.4), Vector2(5.0, -5.4), Vector2(-5.0, -12.6), Vector2(5.0, -12.6), Vector2(-5.4, -9.0), Vector2(5.4, -9.0)]:
			b.box(Vector3(s.x - 0.7, 0.3, s.y - 0.7), Vector3(s.x + 0.7, 1.3, s.y + 0.7), Color(0.24, 0.40, 0.18))
		var cols := Color(0.93, 0.9, 0.84)
		var nx := 6
		for i in nx:
			var x := gx0 + (gx1 - gx0) * float(i) / float(nx - 1)
			b.box(Vector3(x - 0.2, 0.0, gz1 - 0.2), Vector3(x + 0.2, hl, gz1 + 0.2), cols, false)
			b.box(Vector3(x - 0.2, 0.0, gz0 - 0.2), Vector3(x + 0.2, hl, gz0 + 0.2), cols, false)
		for j in range(1, 4):
			var z := gz0 + (gz1 - gz0) * float(j) / 4.0
			b.box(Vector3(gx0 - 0.2, 0.0, z - 0.2), Vector3(gx0 + 0.2, hl, z + 0.2), cols, false)
			b.box(Vector3(gx1 - 0.2, 0.0, z - 0.2), Vector3(gx1 + 0.2, hl, z + 0.2), cols, false)
	return b


# ---------------------------------------------------------------- horti

## Walled garden estate with a villa, nominal 70 x 70 m (trees are separate instances).
static func _horti(detail: bool) -> MB:
	var w := 70.0
	var d := 70.0
	var b := MB.new()
	var up := Vector3(0, 1, 0)
	var wall := Color(0.9, 0.86, 0.76)
	b.quad(Vector3(-w * 0.5, 0.15, d * 0.5), Vector3(w * 0.5, 0.15, d * 0.5), Vector3(w * 0.5, 0.15, -d * 0.5), Vector3(-w * 0.5, 0.15, -d * 0.5), Color(0.40, 0.52, 0.27), up)
	# perimeter wall with a gate in the front
	var t := 0.5
	var wh := 2.6
	b.box(Vector3(-w * 0.5, -SKIRT, -d * 0.5), Vector3(w * 0.5, wh, -d * 0.5 + t), wall)
	b.box(Vector3(-w * 0.5, -SKIRT, -d * 0.5), Vector3(-w * 0.5 + t, wh, d * 0.5), wall)
	b.box(Vector3(w * 0.5 - t, -SKIRT, -d * 0.5), Vector3(w * 0.5, wh, d * 0.5), wall)
	b.box(Vector3(-w * 0.5, -SKIRT, d * 0.5 - t), Vector3(-2.5, wh, d * 0.5), wall)
	b.box(Vector3(2.5, -SKIRT, d * 0.5 - t), Vector3(w * 0.5, wh, d * 0.5), wall)
	b.rect_on(0, -2.5, 2.5, 0.0, 2.2, w, d, 0.02, DARK)
	# gravel path from the gate to the villa
	b.quad(Vector3(-1.6, 0.25, d * 0.5), Vector3(1.6, 0.25, d * 0.5), Vector3(1.6, 0.25, 4.0), Vector3(-1.6, 0.25, 4.0), Color(0.75, 0.68, 0.5), up)
	# villa: a long portico block with a hip roof, and two pavilions
	var vz := -2.0
	var villa := MB.new()
	_walls(villa, 26.0, 13.0, 7.0)
	if detail:
		_row(villa, 0, 6, 11.0, 1.2, 3.4, 1.4, 26.0, 13.0, DARK)
		_row(villa, 0, 6, 11.0, 4.2, 5.6, 1.1, 26.0, 13.0, DARK)
	villa.hip(-13.6, 13.6, -7.0, 7.0, 7.0, 3.6, TILE)
	_append(b, villa, Vector3(0, 0, vz))
	for sx in [-22.0, 22.0]:
		var pav := MB.new()
		_walls(pav, 8.0, 8.0, 4.6)
		pav.hip(-4.6, 4.6, -4.6, 4.6, 4.6, 2.6, TILE)
		_append(b, pav, Vector3(sx, 0, 8.0))
	# a colonnaded walk in front of the villa
	if detail:
		for i in 9:
			var x := -12.0 + float(i) * 3.0
			b.box(Vector3(x - 0.25, 0.0, vz + 7.6), Vector3(x + 0.25, 3.6, vz + 8.1), Color(0.95, 0.92, 0.86), false)
		b.shed(-12.5, 12.5, vz + 7.0, vz + 8.4, 3.9, 3.6, TILE)
		# formal pool
		b.quad(Vector3(-8.0, 0.3, 22.0), Vector3(8.0, 0.3, 22.0), Vector3(8.0, 0.3, 14.0), Vector3(-8.0, 0.3, 14.0), Color(0.34, 0.45, 0.52), up)
	return b


# ---------------------------------------------------------------- trees

static func _tree(kind: String) -> MB:
	var b := MB.new()
	match kind:
		"cypress":
			b.cone(0, 0, 0.0, 0.6, 0.18, 0.18, 5, Color(0.35, 0.25, 0.16))
			b.cone(0, 0, 0.4, 3.2, 1.0, 0.75, 7, Color(0.16, 0.30, 0.15))
			b.cone(0, 0, 3.2, 7.4, 0.75, 0.05, 7, Color(0.18, 0.33, 0.16))
		"pine":
			b.cone(0, 0, 0.0, 4.5, 0.3, 0.22, 5, Color(0.40, 0.28, 0.18))
			b.cone(0, 0, 4.2, 5.8, 1.0, 3.6, 8, Color(0.20, 0.34, 0.17))
			b.cone(0, 0, 5.8, 6.8, 3.6, 3.0, 8, Color(0.24, 0.38, 0.19))
			b.cone(0, 0, 6.8, 7.4, 3.0, 0.3, 8, Color(0.22, 0.36, 0.18))
		_:
			b.cone(0, 0, 0.0, 2.0, 0.25, 0.2, 5, Color(0.42, 0.30, 0.20))
			b.cone(0, 0, 1.6, 3.3, 0.6, 2.2, 8, Color(0.32, 0.47, 0.20))
			b.cone(0, 0, 3.3, 4.6, 2.2, 0.4, 8, Color(0.36, 0.50, 0.22))
	return b
