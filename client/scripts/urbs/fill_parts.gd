## Urbs (U8 houses): the parts every ordinary building is made of, and the mesh builder they are
## built with. fill_houses.gd assembles houses from these; fill_props.gd uses the builder alone.
##
## Conventions (shared with fill_meshes.gd): metres; a building's footprint is centred on the
## origin, its FRONT faces +z, its feet are at y = 0, and a `SKIRT` metres deep masonry plinth
## hangs below so a building on a slope stands on a base instead of floating (fill.gd puts the
## feet at the highest of the four corners). Instances scale x and z only.
##
## Surfaces are vertex-colour alphas (id / 20); the shader in fill_meshes.gd paints each one
## from UrbsMaterials.COLOURS. The rgb is only used where it says so (cloth, linen, leaf).
##
## Forms and sources:
##   Roofs: pan and cover tiles (tegulae and imbrices) with a row of ridge tiles and antefixes
##     on the eaves, pitched about 20-25 degrees. Vitruvius 6.3.1-2 (Perseus, Morgan, read) on
##     the roofs of atria sloping to the compluvium; the surviving Pompeian and Etruscan roofs
##     are the evidence for the pitch and the antefixes (no ancient text gives the angle).
##   Windows: small, with wooden shutters or a wooden lattice (transenna), as at Pompeii and
##     Herculaneum (the carbonised shutters of Herculaneum): an opening is never a black hole.
##   Shops: the wide taberna opening with a masonry counter, a timber lintel, the wooden
##     shutter boards and an awning; the wall above carries a painted sign (dipinti of Pompeii).
##   Balconies (maeniana): timber galleries on brackets with a railing (Vitruvius 2.8.17, read:
##     "floor after floor"; the Casa a Graticcio at Herculaneum for the form).
##   External stairs: a flight from the street to the first floor, the upper flats having their
##     own entrance (the Ostian insulae; # unverified for Republican Rome).
##   Smoke: no chimneys; a small tiled hood over a hole in the roof lets the hearth smoke out.
class_name UrbsFillParts
extends RefCounted

const SKIRT := 10.0   ## the masonry base below the floor: up to 9 m shows on a steep downhill side

# surface ids (vertex alpha * 20)
const ID_EARTH := 0
const ID_LEAF := 1
const ID_PLINTH := 2
const ID_STONE := 3
const ID_CLOTH := 4
const ID_SHADE := 5
const ID_WATER := 6
const ID_WOOD := 7
const ID_TERRA := 8
const ID_TILE := 9
const ID_PLASTER := 10
const ID_RIDGE := 11
const ID_SHUTTER := 12
const ID_SIGN := 13
const ID_THATCH := 14
const ID_SHINGLE := 15
const ID_BRONZE := 16
const ID_BRICK := 17
const ID_LINEN := 18
const ID_LATTICE := 19
const ID_DOOR := 20

const EARTH := Color(1, 1, 1, 0.0)
const LEAF := Color(0.30, 0.44, 0.20, 0.05)
const PLINTH := Color(1, 1, 1, 0.10)
const STONE := Color(1, 1, 1, 0.15)
const CLOTH := Color(0.85, 0.80, 0.65, 0.20)
const SHADE := Color(1, 1, 1, 0.25)
const WATER := Color(1, 1, 1, 0.30)
const WOOD := Color(1, 1, 1, 0.35)
const TERRA := Color(1, 1, 1, 0.40)
const TILE := Color(1, 1, 1, 0.45)
const PLASTER := Color(1, 1, 1, 0.50)
const RIDGE := Color(1, 1, 1, 0.55)
const SHUTTER := Color(1, 1, 1, 0.60)
const SIGN := Color(1, 1, 1, 0.65)
const THATCH := Color(1, 1, 1, 0.70)
const SHINGLE := Color(1, 1, 1, 0.75)
const BRONZE := Color(1, 1, 1, 0.80)
const BRICK := Color(1, 1, 1, 0.85)
const LINEN := Color(0.92, 0.90, 0.84, 0.90)
const LATTICE := Color(1, 1, 1, 0.95)
const DOOR := Color(1, 1, 1, 1.0)

## Laundry colours (undyed linen, a few dyed pieces): rgb used by the shader.
const LINENS: Array[Color] = [
	Color(0.92, 0.90, 0.84, 0.90), Color(0.88, 0.84, 0.72, 0.90), Color(0.70, 0.42, 0.34, 0.90),
	Color(0.86, 0.80, 0.60, 0.90), Color(0.56, 0.58, 0.62, 0.90), Color(0.90, 0.88, 0.82, 0.90),
	Color(0.84, 0.78, 0.66, 0.90),
]
## Awning cloths: rgb used by the shader (stripes in the cloth colour on cream).
const AWNINGS: Array[Color] = [
	Color(0.72, 0.28, 0.20, 0.20), Color(0.80, 0.62, 0.26, 0.20), Color(0.34, 0.42, 0.56, 0.20),
	Color(0.86, 0.80, 0.64, 0.20), Color(0.38, 0.50, 0.36, 0.20), Color(0.60, 0.32, 0.42, 0.20),
]

## Roof pitch in degrees (about 20-25 on the surviving Roman roofs; nothing ancient gives it).
const PITCH_DEG := 22.0


## Deterministic value in [0, 1) from two small integers (per-part variation inside one mesh).
static func fr(i: int, k: int) -> float:
	return float(((i * 7919 + k * 104729) ^ (i * 31 + k * 17)) & 1023) / 1024.0


# ---------------------------------------------------------------- mesh builder

class MB:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()    ## only painted signs use UV (panel 0..1, left to right from outside)
	var uv2 := PackedVector2Array()   ## signs: (panel width m, trade category * 100 + a number 0-99)

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
		# Godot treats clockwise triangles as front faces: emit (a, d, b) so the face whose normal
		# points at the viewer is the front one (lighting is right on both sides with cull off)
		v.append(a); v.append(d); v.append(b)
		n.append(nrm); n.append(nrm); n.append(nrm)
		c.append(col); c.append(col); c.append(col)
		uv.append(Vector2.ZERO); uv.append(Vector2.ZERO); uv.append(Vector2.ZERO)
		uv2.append(Vector2.ZERO); uv2.append(Vector2.ZERO); uv2.append(Vector2.ZERO)

	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color, hint := Vector3.ZERO) -> void:
		tri(a, b, d, col, hint)
		tri(a, d, e, col, hint)

	func box(lo: Vector3, hi: Vector3, col: Color, top := true, bottom := false) -> void:
		quad(Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), col)
		quad(Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), col)
		quad(Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), col)
		quad(Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z), col)
		if top:
			quad(Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), col)
		if bottom:
			quad(Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z), col, Vector3.DOWN)

	## Point on wall `face` of a W x D block: face 0 front(+z) 1 back(-z) 2 right(+x) 3 left(-x);
	## `h` runs along the wall (x for faces 0/1, z for 2/3), `off` is outward from the wall plane.
	static func fp(face: int, h: float, y: float, w: float, d: float, off: float) -> Vector3:
		match face:
			0: return Vector3(h, y, d * 0.5 + off)
			1: return Vector3(h, y, -d * 0.5 - off)
			2: return Vector3(w * 0.5 + off, y, h)
			_: return Vector3(-w * 0.5 - off, y, h)

	static func outward(face: int) -> Vector3:
		match face:
			0: return Vector3(0, 0, 1)
			1: return Vector3(0, 0, -1)
			2: return Vector3(1, 0, 0)
			_: return Vector3(-1, 0, 0)

	## Direction of increasing `h` on a face.
	static func along(face: int) -> Vector3:
		return Vector3(1, 0, 0) if face < 2 else Vector3(0, 0, 1)

	## Rectangle on a wall face, `off` proud of (or, negative, recessed into) the wall.
	func rect_on(face: int, h0: float, h1: float, y0: float, y1: float, w: float, d: float, off: float, col: Color) -> void:
		quad(fp(face, h0, y0, w, d, off), fp(face, h1, y0, w, d, off), fp(face, h1, y1, w, d, off), fp(face, h0, y1, w, d, off), col, outward(face))

	## A box standing on a wall face: centre `h` along the wall, bottom `y0`, size (wide, tall,
	## proud), `off` standoff from the wall.
	func on_wall(face: int, h: float, y0: float, wide: float, tall: float, proud: float, w: float, d: float, off: float, col: Color) -> void:
		match face:
			0:
				var z := d * 0.5 + off
				box(Vector3(h - wide * 0.5, y0, z), Vector3(h + wide * 0.5, y0 + tall, z + proud), col, true, true)
			1:
				var z := -d * 0.5 - off
				box(Vector3(h - wide * 0.5, y0, z - proud), Vector3(h + wide * 0.5, y0 + tall, z), col, true, true)
			2:
				var x := w * 0.5 + off
				box(Vector3(x, y0, h - wide * 0.5), Vector3(x + proud, y0 + tall, h + wide * 0.5), col, true, true)
			_:
				var x := -w * 0.5 - off
				box(Vector3(x - proud, y0, h - wide * 0.5), Vector3(x, y0 + tall, h + wide * 0.5), col, true, true)

	## A box in face coordinates: h0..h1 along the wall, y0..y1, and outward offsets off_in..off_out
	## (negative offsets lie inside the building).
	func box_on(face: int, h0: float, h1: float, y0: float, y1: float, off_in: float, off_out: float, w: float, d: float, col: Color) -> void:
		var a := fp(face, h0, y0, w, d, off_in)
		var b := fp(face, h1, y1, w, d, off_out)
		box(Vector3(minf(a.x, b.x), y0, minf(a.z, b.z)), Vector3(maxf(a.x, b.x), y1, maxf(a.z, b.z)), col, true, false)

	## A painted sign panel on a wall face: UV runs 0..1 left to right as read from outside and 0..1
	## upwards; UV2 = (panel width in metres, `trade` = category * 100 + a number 0-99 from the sign's
	## place along the wall, so neighbouring shops of one building differ) picks the words.
	func sign_panel(face: int, h0: float, h1: float, y0: float, y1: float, w: float, d: float, off: float, trade: float) -> void:
		var flip := face == 1 or face == 2      # faces whose +h runs right to left seen from outside
		var pts := [fp(face, h0, y0, w, d, off), fp(face, h1, y0, w, d, off), fp(face, h1, y1, w, d, off), fp(face, h0, y1, w, d, off)]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		if flip:
			uvs = [Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]
		var nrm := outward(face)
		var u2 := Vector2(h1 - h0, trade)
		for t in [[0, 1, 2], [0, 2, 3]]:
			var a: Vector3 = pts[t[0]]
			var b: Vector3 = pts[t[1]]
			var e: Vector3 = pts[t[2]]
			var ua: Vector2 = uvs[t[0]]
			var ub: Vector2 = uvs[t[1]]
			var ue: Vector2 = uvs[t[2]]
			if (b - a).cross(e - a).dot(nrm) < 0.0:
				var tv := b
				b = e
				e = tv
				var tu := ub
				ub = ue
				ue = tu
			# clockwise front faces (see tri)
			v.append(a); v.append(e); v.append(b)
			n.append(nrm); n.append(nrm); n.append(nrm)
			c.append(SIGN); c.append(SIGN); c.append(SIGN)
			uv.append(ua); uv.append(ue); uv.append(ub)
			uv2.append(u2); uv2.append(u2); uv2.append(u2)

	## A wall face with holes: `holes` are Rect2(h0, y0, width, height) in face coordinates.
	## Built as horizontal bands between the holes' edges.
	func face_with_holes(face: int, h0: float, h1: float, y0: float, y1: float, w: float, d: float, holes: Array, col: Color) -> void:
		if holes.is_empty():
			rect_on(face, h0, h1, y0, y1, w, d, 0.0, col)
			return
		var ys: Array[float] = [y0, y1]
		for r in holes:
			var rr := r as Rect2
			ys.append(clampf(rr.position.y, y0, y1))
			ys.append(clampf(rr.end.y, y0, y1))
		ys.sort()
		for i in range(ys.size() - 1):
			var ya: float = ys[i]
			var yb: float = ys[i + 1]
			if yb - ya < 0.005:
				continue
			var ym := (ya + yb) * 0.5
			var cuts: Array[Vector2] = []
			for r in holes:
				var rr := r as Rect2
				if rr.position.y <= ym and rr.end.y >= ym:
					cuts.append(Vector2(maxf(rr.position.x, h0), minf(rr.end.x, h1)))
			cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			var x := h0
			for cut in cuts:
				if cut.x - x > 0.005:
					rect_on(face, x, cut.x, ya, yb, w, d, 0.0, col)
				x = maxf(x, cut.y)
			if h1 - x > 0.005:
				rect_on(face, x, h1, ya, yb, w, d, 0.0, col)

	## The four reveals of an opening recessed `rec` into a wall, and its back plane.
	func reveal(face: int, h0: float, h1: float, y0: float, y1: float, w: float, d: float, rec: float, col: Color, back: Color, back_rec := -1.0) -> void:
		var br := rec if back_rec < 0.0 else back_rec
		var al := along(face)
		var a0 := fp(face, h0, y0, w, d, 0.0)
		var a1 := fp(face, h1, y0, w, d, 0.0)
		var a2 := fp(face, h1, y1, w, d, 0.0)
		var a3 := fp(face, h0, y1, w, d, 0.0)
		var b0 := fp(face, h0, y0, w, d, -rec)
		var b1 := fp(face, h1, y0, w, d, -rec)
		var b2 := fp(face, h1, y1, w, d, -rec)
		var b3 := fp(face, h0, y1, w, d, -rec)
		quad(a0, b0, b3, a3, col, al)          # jamb at h0, faces +h
		quad(a1, b1, b2, a2, col, -al)         # jamb at h1
		quad(a0, a1, b1, b0, col, Vector3.UP)  # sill
		quad(a3, a2, b2, b3, col, Vector3.DOWN)  # head
		rect_on(face, h0, h1, y0, y1, w, d, -br, back)

	## Gable roof over x0..x1, z0..z1 with the ridge along x at the middle of z. Tile faces,
	## plastered gable ends, a ridge of tiles, antefixes on both eaves (lod 0), fascia boards.
	func gable(x0: float, x1: float, z0: float, z1: float, base: float, rh: float, roof: Color, wall_col: Color, lod := 0, ends := true) -> void:
		var zm := (z0 + z1) * 0.5
		var top := base + rh
		quad(Vector3(x0, base, z1), Vector3(x1, base, z1), Vector3(x1, top, zm), Vector3(x0, top, zm), roof, Vector3(0, 1, 0.3))
		quad(Vector3(x1, base, z0), Vector3(x0, base, z0), Vector3(x0, top, zm), Vector3(x1, top, zm), roof, Vector3(0, 1, -0.3))
		if ends:
			tri(Vector3(x1, base, z1), Vector3(x1, base, z0), Vector3(x1, top, zm), wall_col, Vector3(1, 0, 0))
			tri(Vector3(x0, base, z0), Vector3(x0, base, z1), Vector3(x0, top, zm), wall_col, Vector3(-1, 0, 0))
		if lod < 2:
			ridge(Vector3(x0, top, zm), Vector3(x1, top, zm), 0.22)
		if lod == 0:
			fascia(Vector3(x0, base, z1), Vector3(x1, base, z1), Vector3(0, 0, 1))
			fascia(Vector3(x0, base, z0), Vector3(x1, base, z0), Vector3(0, 0, -1))
			antefixes(Vector3(x0, base, z1), Vector3(x1, base, z1), Vector3(0, 0, 1), rh / maxf(zm - z0, 0.1))
			antefixes(Vector3(x0, base, z0), Vector3(x1, base, z0), Vector3(0, 0, -1), rh / maxf(zm - z0, 0.1))

	## Hip roof: a ridge along x, four tile faces, hip ridges, antefixes all round.
	func hip(x0: float, x1: float, z0: float, z1: float, base: float, rh: float, roof: Color, lod := 0) -> void:
		var zm := (z0 + z1) * 0.5
		var inset := (z1 - z0) * 0.5
		var rx0 := minf(x0 + inset, (x0 + x1) * 0.5 - 0.3)
		var rx1 := maxf(x1 - inset, (x0 + x1) * 0.5 + 0.3)
		var top := base + rh
		var r0 := Vector3(rx0, top, zm)
		var r1 := Vector3(rx1, top, zm)
		quad(Vector3(x0, base, z1), Vector3(x1, base, z1), r1, r0, roof, Vector3(0, 1, 0.3))
		quad(Vector3(x1, base, z0), Vector3(x0, base, z0), r0, r1, roof, Vector3(0, 1, -0.3))
		tri(Vector3(x1, base, z1), Vector3(x1, base, z0), r1, roof, Vector3(1, 1, 0))
		tri(Vector3(x0, base, z0), Vector3(x0, base, z1), r0, roof, Vector3(-1, 1, 0))
		if lod < 2:
			ridge(r0, r1, 0.22)
			for corner in [Vector3(x0, base, z0), Vector3(x0, base, z1)]:
				ridge(corner, r0, 0.16)
			for corner in [Vector3(x1, base, z0), Vector3(x1, base, z1)]:
				ridge(corner, r1, 0.16)
		if lod == 0:
			fascia(Vector3(x0, base, z1), Vector3(x1, base, z1), Vector3(0, 0, 1))
			fascia(Vector3(x0, base, z0), Vector3(x1, base, z0), Vector3(0, 0, -1))
			fascia(Vector3(x1, base, z0), Vector3(x1, base, z1), Vector3(1, 0, 0))
			fascia(Vector3(x0, base, z0), Vector3(x0, base, z1), Vector3(-1, 0, 0))
			var slope := rh / maxf(inset, 0.1)
			antefixes(Vector3(x0, base, z1), Vector3(x1, base, z1), Vector3(0, 0, 1), slope)
			antefixes(Vector3(x0, base, z0), Vector3(x1, base, z0), Vector3(0, 0, -1), slope)
			antefixes(Vector3(x1, base, z0), Vector3(x1, base, z1), Vector3(1, 0, 0), slope)
			antefixes(Vector3(x0, base, z0), Vector3(x0, base, z1), Vector3(-1, 0, 0), slope)

	## Single-pitch roof from the high edge (z_hi, y_hi) to the low eave (z_lo, y_lo).
	func shed(x0: float, x1: float, z_hi: float, z_lo: float, y_hi: float, y_lo: float, roof: Color, lod := 0) -> void:
		quad(Vector3(x0, y_hi, z_hi), Vector3(x1, y_hi, z_hi), Vector3(x1, y_lo, z_lo), Vector3(x0, y_lo, z_lo), roof, Vector3(0, 1, 0))
		if lod == 0 and is_equal_approx(roof.a, TILE.a):
			var out := Vector3(0, 0, signf(z_lo - z_hi))
			fascia(Vector3(x0, y_lo, z_lo), Vector3(x1, y_lo, z_lo), out)
			if lod == 0:
				antefixes(Vector3(x0, y_lo, z_lo), Vector3(x1, y_lo, z_lo), out, (y_hi - y_lo) / maxf(absf(z_hi - z_lo), 0.1))

	## Ridge tiles: a half-round run of imbrices along the ridge (a three-sided prism).
	func ridge(a: Vector3, b: Vector3, r: float) -> void:
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.5:
			side = Vector3(0, 0, 1)
		var up := Vector3.UP * r
		var s := side * r
		var a0 := a - s
		var a1 := a + s
		var at := a + up * 0.9
		var b0 := b - s
		var b1 := b + s
		var bt := b + up * 0.9
		quad(a0, b0, bt, at, RIDGE, -side + Vector3.UP)
		quad(a1, at, bt, b1, RIDGE, side + Vector3.UP)
		quad(a0, at, a1, a0 + dir * 0.001, RIDGE, -dir)

	## Fascia board under the eave (gives the roof an edge thickness).
	func fascia(a: Vector3, b: Vector3, out: Vector3) -> void:
		var dn := Vector3(0, -0.16, 0)
		quad(a, b, b + dn, a + dn, WOOD, out)
		var back := -out * 0.4
		quad(a + dn, b + dn, b + dn + back, a + dn + back, WOOD, Vector3.DOWN)

	## Antefixes: a small flat terracotta plaque (palmette or head), about 0.16 m tall and 0.14 m
	## wide, upright on the eave at the end of every cover tile, its face to the street. Only at full
	## detail (callers check lod == 0).
	func antefixes(a: Vector3, b: Vector3, out: Vector3, _slope: float) -> void:
		var len := a.distance_to(b)
		var n_tiles := maxi(int(len / 0.5), 1)
		var dir := (b - a) / float(n_tiles)
		var al := dir.normalized()
		var half := al * 0.07
		var top := half * 0.6
		for i in range(n_tiles + 1):
			var p := a + dir * float(i) + out * 0.01
			if i == 0:
				p += al * 0.1
			elif i == n_tiles:
				p -= al * 0.1
			# a plaque 0.12 high and a rounded (bevelled) head 0.04 high: four triangles, no point
			var y1 := Vector3(0, 0.12, 0)
			var y2 := Vector3(0, 0.16, 0)
			quad(p - half, p + half, p + half + y1, p - half + y1, RIDGE, out)
			quad(p - half + y1, p + half + y1, p + top + y2, p - top + y2, RIDGE, out)

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
		if r1 > 0.05:
			var top := Vector3(cx, y1, cz)
			for s in sides:
				var a0 := TAU * float(s) / sides
				var a1 := TAU * float(s + 1) / sides
				tri(top, Vector3(cx + cos(a0) * r1, y1, cz + sin(a0) * r1), Vector3(cx + cos(a1) * r1, y1, cz + sin(a1) * r1), col, Vector3(0, 1, 0))

	func append(src: MB, offset: Vector3) -> void:
		for i in src.v.size():
			v.append(src.v[i] + offset)
		n.append_array(src.n)
		c.append_array(src.c)
		uv.append_array(src.uv)
		uv2.append_array(src.uv2)

	func triangles() -> int:
		return v.size() / 3

	func to_mesh() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


# ---------------------------------------------------------------- walls

## Rise of a roof of PITCH_DEG over a half-span.
static func rise(half_span: float, pitch_deg := PITCH_DEG) -> float:
	return half_span * tan(deg_to_rad(pitch_deg))


## Four walls of a W x D block, `h` high, each face with the holes listed for it (`holes[face]`
## is an Array of Rect2 in face coordinates), over a masonry plinth SKIRT deep. Above LOD 0 the
## walls are solid: the openings are painted on them by the callers.
static func walls(b: MB, w: float, d: float, h: float, holes: Array = [], col := PLASTER, lod := 0) -> void:
	if lod > 0:
		holes = []
	for face in 4:
		var span := (w if face < 2 else d) * 0.5
		b.rect_on(face, -span, span, -SKIRT, 0.0, w, d, 0.0, PLINTH)
		var fh: Array = holes[face] if face < holes.size() else []
		b.face_with_holes(face, -span, span, 0.0, h, w, d, fh, col)


## A thin plaster string course between floors on `face`.
static func string_course(b: MB, face: int, y: float, w: float, d: float) -> void:
	var span := (w if face < 2 else d) * 0.5
	b.on_wall(face, 0.0, y - 0.1, span * 2.0, 0.16, 0.08, w, d, 0.0, STONE)


# ---------------------------------------------------------------- openings

## Window centred at `h` on `face`, bottom `y0`, size wid x tall. lod 0: recessed with reveals and
## a visible leaf (closed shutters, one shutter open on a lattice, or a lattice) and a stone sill;
## lod 1: a flat shutter plane; lod 2: nothing (the caller leaves the wall blank).
## Call `window_hole` first so the wall has the hole. `k` varies the leaf.
static func window(b: MB, face: int, h: float, y0: float, wid: float, tall: float, w: float, d: float, lod: int, k: int) -> void:
	var h0 := h - wid * 0.5
	var h1 := h + wid * 0.5
	var r := fr(k, 3)
	if lod >= 2:
		return
	if lod == 1:
		b.rect_on(face, h0, h1, y0, y0 + tall, w, d, 0.02, SHUTTER if r < 0.6 else LATTICE)
		return
	if r < 0.5:
		# closed shutters: two leaves with a thin gap, set back a little
		b.reveal(face, h0, h1, y0, y0 + tall, w, d, 0.32, PLASTER, SHADE, 0.34)
		b.rect_on(face, h0 + 0.02, h - 0.02, y0 + 0.02, y0 + tall - 0.02, w, d, -0.24, SHUTTER)
		b.rect_on(face, h + 0.02, h1 - 0.02, y0 + 0.02, y0 + tall - 0.02, w, d, -0.24, SHUTTER)
	elif r < 0.75:
		# one shutter open against the wall, a lattice behind
		b.reveal(face, h0, h1, y0, y0 + tall, w, d, 0.32, PLASTER, LATTICE, 0.30)
		var hs := h1 + 0.02 + wid * 0.25 if fr(k, 4) < 0.5 else h0 - 0.02 - wid * 0.25
		b.on_wall(face, hs, y0 + 0.02, wid * 0.5, tall - 0.04, 0.05, w, d, 0.03, SHUTTER)
	else:
		# wooden lattice (transenna) in the opening
		b.reveal(face, h0, h1, y0, y0 + tall, w, d, 0.32, PLASTER, LATTICE, 0.26)
	# sill
	b.on_wall(face, h, y0 - 0.1, wid + 0.26, 0.10, 0.10, w, d, 0.0, STONE)


## The hole a window needs in the wall (face coordinates).
static func window_hole(h: float, y0: float, wid: float, tall: float) -> Rect2:
	return Rect2(h - wid * 0.5, y0, wid, tall)


## A plain small opening (side and back faces, upper floors): a shallow recess with a shutter
## plane, cheap. Needs no hole in the wall (it is painted proud of it).
static func window_flat(b: MB, face: int, h: float, y0: float, wid: float, tall: float, w: float, d: float, k: int, lod := 0) -> void:
	var leaf := SHUTTER if fr(k, 5) < 0.6 else LATTICE
	b.rect_on(face, h - wid * 0.5, h + wid * 0.5, y0, y0 + tall, w, d, 0.02, leaf)
	if lod == 0:
		b.rect_on(face, h - wid * 0.5 - 0.1, h + wid * 0.5 + 0.1, y0 - 0.1, y0, w, d, 0.035, STONE)


## House door centred at `h`: stone jambs and lintel, a threshold step, the leaves recessed.
static func door(b: MB, face: int, h: float, wid: float, tall: float, w: float, d: float, lod: int, k: int, grand := false) -> void:
	var h0 := h - wid * 0.5
	var h1 := h + wid * 0.5
	if lod >= 1:
		b.rect_on(face, h0, h1, 0.0, tall, w, d, 0.02, DOOR)
		return
	var jw := 0.32 if grand else 0.18
	var jcol := STONE if grand else PLASTER
	b.reveal(face, h0, h1, 0.0, tall, w, d, 0.4, jcol, DOOR, 0.36)
	if fr(k, 6) < 0.3:
		# one leaf ajar: the passage behind in shade
		b.rect_on(face, h0 + 0.02, h, 0.02, tall - 0.02, w, d, -0.35, SHADE)
		b.rect_on(face, h + 0.0, h1 - 0.02, 0.02, tall - 0.02, w, d, -0.30, DOOR)
	# jambs and lintel
	b.on_wall(face, h0 - jw * 0.5, 0.0, jw, tall + 0.3, 0.07 if grand else 0.04, w, d, 0.0, jcol)
	b.on_wall(face, h1 + jw * 0.5, 0.0, jw, tall + 0.3, 0.07 if grand else 0.04, w, d, 0.0, jcol)
	b.on_wall(face, h, tall, wid + jw * 2.0 + (0.3 if grand else 0.0), 0.3 if grand else 0.2, 0.08 if grand else 0.05, w, d, 0.0, jcol)
	# threshold
	b.on_wall(face, h, 0.0, wid + jw * 2.0, 0.12, 0.45, w, d, 0.0, STONE)


static func door_hole(h: float, wid: float, tall: float) -> Rect2:
	return Rect2(h - wid * 0.5, 0.0, wid, tall)


## Taberna front: a wide opening 2.6 m tall with a timber lintel, a threshold, inside it the shop
## in shade with its back wall, a masonry counter (L-shaped, with dolia set in it) or the shutter
## boards half closed, goods, and a cloth awning on two poles. `sign` paints the shop's name on
## the wall above the lintel.
static func shop_front(b: MB, face: int, h: float, wid: float, w: float, d: float, lod: int, k: int, awning := -1, sign := true) -> void:
	var tall := 2.6
	var h0 := h - wid * 0.5
	var h1 := h + wid * 0.5
	if lod >= 2:
		b.rect_on(face, h0, h1, 0.0, tall, w, d, 0.02, SHADE)
		return
	if lod == 1:
		b.rect_on(face, h0, h1, 0.0, tall, w, d, 0.02, SHADE)
		b.rect_on(face, h0 - 0.25, h1 + 0.25, tall, tall + 0.3, w, d, 0.03, WOOD)
		if awning >= 0 and face == 0:
			var ca: Color = AWNINGS[awning % AWNINGS.size()]
			b.shed(h0 - 0.3, h1 + 0.3, d * 0.5 + 0.05, d * 0.5 + 1.7, 3.2, 2.5, ca, 2)
		return
	var r := fr(k, 5)
	var deep := 1.2    # how far inside the opening we model
	# reveals and back wall (the shop interior, dim, with shelves implied by the shader)
	b.reveal(face, h0, h1, 0.0, tall, w, d, deep, PLASTER, SHADE, deep)
	# timber lintel over the opening, resting on stone pilasters
	b.on_wall(face, h, tall, wid + 0.5, 0.3, 0.12, w, d, 0.0, WOOD)
	b.rect_on(face, h0 - 0.28, h0, 0.0, tall, w, d, 0.06, STONE)
	b.rect_on(face, h1, h1 + 0.28, 0.0, tall, w, d, 0.06, STONE)
	# threshold with the groove for the shutter boards
	b.on_wall(face, h, 0.0, wid + 0.6, 0.14, 0.36, w, d, 0.0, STONE)
	if r < 0.45:
		# masonry counter: a slab along the front, set back 0.3 m, and a return into the shop
		b.box_on(face, h0 + 0.15, h1 - 0.15, 0.0, 0.95, -0.85, -0.3, w, d, STONE)
		b.box_on(face, h0 + 0.15, h0 + 0.7, 0.0, 0.95, -deep + 0.1, -0.85, w, d, STONE)
		# dolia mouths set in the counter top, an amphora on it
		for i in 2:
			var cm := MB.fp(face, h0 + 0.75 + 0.65 * float(i), 0.0, w, d, -0.57)
			b.cone(cm.x, cm.z, 0.95, 0.99, 0.30, 0.24, 6, TERRA)
			b.cone(cm.x, cm.z, 0.99, 1.0, 0.24, 0.0, 6, SHADE)
		var am := MB.fp(face, h1 - 0.7, 0.0, w, d, -0.57)
		amphora(b, am.x, 0.95, am.z, 0.7)
	elif r < 0.8:
		# shutter boards: two of the vertical boards left in place on one side
		var hs := h0 + 0.2 if fr(k, 7) < 0.5 else h1 - 0.9
		b.rect_on(face, hs, hs + 0.7, 0.14, tall - 0.02, w, d, -0.12, SHUTTER)
		# a table of goods just inside
		var tb := MB.fp(face, h + (0.4 if fr(k, 7) < 0.5 else -0.4), 0.0, w, d, -0.7)
		b.box(tb + Vector3(-0.6, 0.7, -0.4), tb + Vector3(0.6, 0.78, 0.4), WOOD)
		amphora(b, tb.x - 0.2, 0.78, tb.z, 0.5)
		amphora(b, tb.x + 0.25, 0.78, tb.z + 0.1, 0.45)
	else:
		# open workshop: a bench across the back and sacks
		var bk := MB.fp(face, h, 0.0, w, d, -deep + 0.3)
		b.box(bk + Vector3(-wid * 0.4, 0.0, -0.25), bk + Vector3(wid * 0.4, 0.8, 0.25), WOOD)
		var sk := MB.fp(face, h - wid * 0.3, 0.0, w, d, -0.6)
		b.cone(sk.x, sk.z, 0.0, 0.5, 0.3, 0.26, 7, CLOTH)
	# painted sign above the lintel
	if sign and fr(k, 9) < 0.7:
		# the trade the sign names follows what the shop shows: 0 counter with dolia (wine, oil, an
		# inn), 1 a table of goods, 2 a workbench
		var trade := 0.0 if r < 0.45 else (1.0 if r < 0.8 else 2.0)
		b.sign_panel(face, h0 - 0.1, h1 + 0.1, tall + 0.4, tall + 0.95, w, d, 0.012, trade * 100.0 + float(int((h + 20.0) * 2.0 + 0.5) % 100))
	# awning: a cloth from a timber bar over the opening down to two poles at the kerb
	if awning >= 0 and face == 0:
		var ca: Color = AWNINGS[awning % AWNINGS.size()]
		var z0 := d * 0.5 + 0.08
		var z1 := d * 0.5 + 1.8
		b.shed(h0 - 0.3, h1 + 0.3, z0, z1, 3.15, 2.45, ca, 0)
		b.box(Vector3(h0 - 0.35, 3.1, z0 - 0.04), Vector3(h1 + 0.35, 3.2, z0 + 0.06), WOOD)
		for sx in [h0 - 0.25, h1 + 0.25]:
			b.box(Vector3(sx - 0.04, 0.0, z1 - 0.08), Vector3(sx + 0.04, 2.5, z1), WOOD, false)
		# a scalloped edge: a hanging flap
		b.quad(Vector3(h0 - 0.3, 2.45, z1), Vector3(h1 + 0.3, 2.45, z1), Vector3(h1 + 0.3, 2.2, z1 + 0.02), Vector3(h0 - 0.3, 2.2, z1 + 0.02), ca, Vector3(0, 0, 1))


static func shop_hole(h: float, wid: float) -> Rect2:
	return Rect2(h - wid * 0.5, 0.0, wid, 2.6)


# ---------------------------------------------------------------- balconies, stairs, roof furniture

## Timber balcony (maenianum) on the front face: floor on brackets, posts, a rail, and on some a
## washing line with linen hung on it. `h` centre, `hw` half width, `y` the floor level.
static func balcony(b: MB, face: int, h: float, hw: float, y: float, w: float, d: float, k: int, laundry := false, roof := false) -> void:
	var out := MB.outward(face)
	var al := MB.along(face)
	var depth := 1.2
	var p0 := MB.fp(face, h - hw, y, w, d, 0.0)
	var p1 := MB.fp(face, h + hw, y, w, d, 0.0)
	# floor
	var f_lo := Vector3(minf(p0.x, p1.x), y, minf(p0.z, p1.z))
	var f_hi := Vector3(maxf(p0.x, p1.x), y + 0.14, maxf(p0.z, p1.z))
	var ext := out * depth
	b.box(Vector3(minf(f_lo.x, f_lo.x + ext.x), y, minf(f_lo.z, f_lo.z + ext.z)), Vector3(maxf(f_hi.x, f_hi.x + ext.x), y + 0.14, maxf(f_hi.z, f_hi.z + ext.z)), WOOD, true, true)
	# brackets
	var n_br := maxi(2, int(hw * 2.0 / 1.6) + 1)
	for i in n_br:
		var t := float(i) / float(n_br - 1)
		var bp := p0.lerp(p1, t) + al * (0.08 if i == 0 else (-0.08 if i == n_br - 1 else 0.0))
		var q0 := bp + Vector3(0, -0.7, 0)
		var q1 := bp + out * (depth - 0.15)
		b.tri(q0, q1, bp, WOOD, al)
		b.tri(q0, bp, q1, WOOD, -al)
	# posts and rail
	var rail_y := y + 1.05
	var outer0 := p0 + out * (depth - 0.08)
	var outer1 := p1 + out * (depth - 0.08)
	var n_post := maxi(2, int(hw * 2.0 / 1.2) + 1)
	for i in n_post:
		var t := float(i) / float(n_post - 1)
		var pp := outer0.lerp(outer1, t) + al * (0.05 if i == 0 else (-0.05 if i == n_post - 1 else 0.0))
		b.box(pp + Vector3(-0.04, 0.14, -0.04), pp + Vector3(0.04, 1.1, 0.04), WOOD, true, false)
	var r_lo := Vector3(minf(outer0.x, outer1.x) - 0.05, rail_y, minf(outer0.z, outer1.z) - 0.05)
	var r_hi := Vector3(maxf(outer0.x, outer1.x) + 0.05, rail_y + 0.08, maxf(outer0.z, outer1.z) + 0.05)
	b.box(r_lo, r_hi, WOOD, true, true)
	# a mid rail
	b.box(Vector3(r_lo.x, y + 0.6, r_lo.z), Vector3(r_hi.x, y + 0.65, r_hi.z), WOOD, true, true)
	# balusters: thin boards
	var n_bal := int(hw * 2.0 / 0.45)
	for i in n_bal:
		var t := (float(i) + 0.5) / float(n_bal)
		var bp := outer0.lerp(outer1, t)
		b.box(bp + Vector3(-0.025, 0.14, -0.025), bp + Vector3(0.025, 1.05, 0.025), WOOD, false, false)
	# laundry on a line between two posts, hanging over the rail
	if laundry:
		var n_cl := mini(int(hw * 2.0 / 0.8), 5)
		for i in n_cl:
			if fr(k, 20 + i) > 0.7:
				continue
			var t := (float(i) + 0.5) / float(n_cl)
			var cp := outer0.lerp(outer1, t) + out * 0.08 + Vector3(0, 1.13, 0)
			var cw := 0.28 + fr(k, 30 + i) * 0.1
			var ch := 0.6 + fr(k, 40 + i) * 0.5
			var cl: Color = LINENS[(k + i) % LINENS.size()]
			var sway := out * 0.06 * (1.0 if i % 2 == 0 else -1.0)
			b.quad(cp - al * cw, cp + al * cw, cp + al * cw + Vector3(0, -ch, 0) + sway, cp - al * cw + Vector3(0, -ch, 0) + sway, cl, out)
	# a lean-to tile roof over the balcony on some
	if roof:
		var zz0 := MB.fp(face, h - hw - 0.2, y + 2.6, w, d, 0.0)
		var zz1 := MB.fp(face, h + hw + 0.2, y + 2.6, w, d, 0.0)
		var o0 := zz0 + out * (depth + 0.3) + Vector3(0, -0.55, 0)
		var o1 := zz1 + out * (depth + 0.3) + Vector3(0, -0.55, 0)
		b.quad(zz0, zz1, o1, o0, TILE, Vector3.UP + out * 0.3)
		b.fascia(o0, o1, out)


## External stair against `face`: a straight flight from the ground to `y_top` (the first floor),
## rising along +h, with a landing and a door at its head; a masonry parapet below the treads.
static func stair(b: MB, face: int, h_start: float, y_top: float, w: float, d: float, lod: int, k: int) -> void:
	var out := MB.outward(face)
	var al := MB.along(face)
	var run := y_top * 1.15
	var width := 1.0
	var p_lo := MB.fp(face, h_start, 0.0, w, d, 0.0)
	var p_hi := MB.fp(face, h_start + run, y_top, w, d, 0.0)
	# a solid sloping block under the steps (masonry), the treads in stone, a timber rail
	var a0 := p_lo
	var a1 := p_lo + out * width
	var b0 := p_hi
	var b1 := p_hi + out * width
	b.quad(a0, a1, b1, b0, STONE, Vector3.UP)       # the slope (treads read via the shader)
	b.quad(a1, b1, Vector3(b1.x, 0.0, b1.z), Vector3(a1.x, 0.0, a1.z), PLINTH, out)
	b.quad(b0, b1, Vector3(b1.x, 0.0, b1.z), Vector3(b0.x, 0.0, b0.z), PLINTH, al)
	if lod == 0:
		var n_steps := int(y_top / 0.26)
		for i in n_steps:
			var t0 := float(i) / float(n_steps)
			var t1 := float(i + 1) / float(n_steps)
			var s0 := p_lo.lerp(p_hi, t0)
			var s1 := p_lo.lerp(p_hi, t1)
			var yy := s1.y
			var tread0 := Vector3(s0.x, yy + 0.02, s0.z)
			var tread1 := Vector3(s1.x, yy + 0.02, s1.z)
			b.quad(tread0, tread0 + out * width, tread1 + out * width, tread1, STONE, Vector3.UP)
			var riser0 := Vector3(s0.x, s0.y + 0.02, s0.z)
			b.quad(riser0, riser0 + out * width, tread0 + out * width, tread0, STONE, -al)
		# handrail on posts
		for i in 3:
			var t := float(i) / 2.0
			var pp := p_lo.lerp(p_hi, t) + out * (width - 0.05)
			b.box(pp + Vector3(-0.04, 0.0, -0.04), pp + Vector3(0.04, 0.95, 0.04), WOOD, true, false)
		var r0 := p_lo + out * (width - 0.05) + Vector3(0, 0.9, 0)
		var r1 := p_hi + out * (width - 0.05) + Vector3(0, 0.9, 0)
		var rs := out * 0.04
		b.quad(r0 - rs, r1 - rs, r1 + rs, r0 + rs, WOOD, Vector3.UP)
		b.quad(r0 - rs, r1 - rs, r1 - rs + Vector3(0, -0.08, 0), r0 - rs + Vector3(0, -0.08, 0), WOOD, -out)
		b.quad(r0 + rs, r1 + rs, r1 + rs + Vector3(0, -0.08, 0), r0 + rs + Vector3(0, -0.08, 0), WOOD, out)
	# the door at the head of the stair
	var hd := h_start + run + 0.6
	b.rect_on(face, hd - 0.45, hd + 0.45, y_top, y_top + 2.0, w, d, -0.08, DOOR)
	b.on_wall(face, hd, y_top + 2.0, 1.2, 0.16, 0.06, w, d, 0.0, WOOD)


## Smoke hood on a roof slope: a small tiled cover on four stubs over the kitchen's smoke hole.
static func smoke_hood(b: MB, x: float, y: float, z: float, lod: int) -> void:
	if lod > 0:
		return
	for sx in [-0.3, 0.3]:
		for sz in [-0.3, 0.3]:
			b.box(Vector3(x + sx - 0.05, y - 0.2, z + sz - 0.05), Vector3(x + sx + 0.05, y + 0.5, z + sz + 0.05), TERRA, false)
	b.gable(x - 0.5, x + 0.5, z - 0.5, z + 0.5, y + 0.5, 0.3, TILE, SHADE, 1, true)


## Amphora standing at (x, y, z): foot, belly, neck, mouth ring.
static func amphora(b: MB, x: float, y: float, z: float, s := 1.0, col := TERRA) -> void:
	b.cone(x, z, y, y + 0.26 * s, 0.05 * s, 0.19 * s, 5, col)
	b.cone(x, z, y + 0.26 * s, y + 0.58 * s, 0.19 * s, 0.11 * s, 5, col)
	b.cone(x, z, y + 0.58 * s, y + 0.84 * s, 0.11 * s, 0.065 * s, 5, col)
