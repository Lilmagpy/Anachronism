## Urbs (D-289, step U5): the insides of Rome's buildings at real scale, built from code.
##
## One builder per kind, parameterised by the footprint, so every real building gets its own
## size: `build(kind, size, opts)` returns a Dictionary:
##   mesh     ArrayMesh   floors, walls, furniture, statues (stays when the roof is cut away)
##   cover    ArrayMesh   roof and ceiling (hide it for a cutaway view); may be null
##   lights   Array       {pos, colour, energy, range, kind} - oil lamps, torches, a sky fill
##   spawn    Transform3D where the camera starts (local frame, eye height)
##   seats    Dictionary  name -> Transform3D viewpoints (see `seat()`)
##   views    Array       [name, Transform3D] for the previews (inside and cutaway)
##   notes    Array       what the builder assumed (sources, what is conjecture)
## Local frame: 1 unit = 1 metre, y = 0 is the ground the building stands on, the origin is
## the middle of the footprint, +z is the front (the door side; for the circus the sphendone
## end, the carceres being at -z). `size` is (L, W) with L the long dimension.
## Kinds: temple (variant "capitoline"), curia, basilica, circus, arena (variant "colosseum"
## or "forum"), domus, insula, theatre.
##
## Sources (read unless marked `# unverified`): Vitruvius 2.8.17, 4.5, 4.7, 4.9, 5.1, 5.2, 5.6, 6.3
## (Thayer's transcription of Gwilt's translation); Dion. Hal. 4.61 (Capitoline); Platner-Ashby
## s.v. Circus Maximus, Curia Hostilia, Curia Iulia, Basilica Aemilia, Theatrum Pompei,
## Amphitheatrum Flavium (LacusCurtius); Livy 1.35.8-9 and 1.56.2 (circus seats); Dio 49.43.2
## (dolphins), 51.22.1-2 (Victory in the Curia Iulia); Plutarch Pompey 42 (theatre of Mytilene).
## Not read, cited through Platner-Ashby only: Livy 41.27.6, Tertullian De spect. 8 and 10,
## Pliny NH 8.20-21 and 36.102, Suetonius Aug. 31.
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")

const RF := 0.2957          ## a Roman foot in metres
const EYE := 1.65           ## eye height of a standing person
const MS := 3.5             ## the meshes are built 1/MS size and drawn MS times larger, so the
							## shader's surface patterns (stone courses, tiles) come out at real scale

# --- palette (sRGB, the shader lifts to linear) --------------------------------------------------
const TUFA := Color(0.62, 0.55, 0.43)
const TRAVERTINE := Color(0.84, 0.79, 0.67)
const MARBLE := Color(0.93, 0.91, 0.86)
const MARBLE_D := Color(0.76, 0.74, 0.70)
const STUCCO := Color(0.90, 0.85, 0.74)
const PLAST_W := Color(0.93, 0.90, 0.82)
const RED := Color(0.62, 0.20, 0.15)       ## Pompeian red
const OCHRE := Color(0.82, 0.62, 0.24)
const BLACK_P := Color(0.12, 0.10, 0.09)
const BLUE_P := Color(0.20, 0.34, 0.50)
const TERRA := Color(0.72, 0.40, 0.26)
const TILE_C := Color(0.66, 0.36, 0.24)
const WOOD := Color(0.52, 0.36, 0.20)
const WOOD_D := Color(0.34, 0.23, 0.13)
const WOOD_L := Color(0.70, 0.52, 0.32)
const BRONZE := Color(0.64, 0.46, 0.20)
const GILT := Color(0.92, 0.74, 0.28)
const IVORY := Color(0.93, 0.89, 0.78)
const SAND := Color(0.80, 0.70, 0.50)
const DUST := Color(0.66, 0.57, 0.42)
const GRASS := Color(0.34, 0.50, 0.22)
const LEAF_C := Color(0.26, 0.42, 0.18)
const TOGA := Color(0.93, 0.92, 0.88)
const PURPLE := Color(0.42, 0.14, 0.30)
const FLAME := Color(1.0, 0.78, 0.35)


static func kinds() -> Array:
	return ["temple", "curia", "basilica", "circus", "arena", "domus", "insula", "theatre"]


## A reasonable (L, W) for a kind with no data of its own.
static func default_size(kind: String, variant := "") -> Vector2:
	match kind:
		"temple":
			return Vector2(60, 55) if variant == "capitoline" else Vector2(30, 25)
		"curia":
			return Vector2(25.2, 17.6)      # Platner-Ashby s.v. Curia Iulia (Diocletian's hall)
		"basilica":
			return Vector2(90, 36)          # Vitruvius 5.1.4: width 1/3 to 1/2 of the length
		"circus":
			return Vector2(600, 85)         # Platner-Ashby: 600 m, arena 75-87 m wide
		"arena":
			return Vector2(83, 48) if variant == "colosseum" else Vector2(110, 55)
		"domus":
			return Vector2(36, 18)
		"insula":
			return Vector2(30, 24)
		"theatre":
			return Vector2(150, 150)
	return Vector2(30, 20)


## Build one interior. `opts`: year (int, default -100), variant (String), seed (int).
static func build(kind: String, size: Vector2, opts := {}) -> Dictionary:
	var year: int = int(opts.get("year", -100))
	var variant: String = str(opts.get("variant", ""))
	var sz := Vector2(maxf(size.x, size.y), minf(size.x, size.y)) if kind != "circus" else size
	match kind:
		"temple":
			return _temple(sz, year, variant)
		"curia":
			return _curia(sz, year, variant)
		"basilica":
			return _basilica(sz, year, variant)
		"circus":
			return _circus(sz, year)
		"arena":
			return _arena(sz, year, variant)
		"domus":
			return _domus(sz, year)
		"insula":
			return _insula(sz, year)
		"theatre":
			return _theatre(sz, year, variant)
	push_warning("RomanInteriors: unknown kind '%s'" % kind)
	return {}


## The viewpoint for a named seat section (circus: carceres, finish, pulvinar, senate, turn,
## sphendone; theatre: ima, media, summa, temple; arena: podium, primum, secundum, summum).
## Builds the interior's geometry only to read its viewpoints, so call it once and keep it.
static func seat(kind: String, size: Vector2, section: String, opts := {}) -> Transform3D:
	var r := build(kind, size, opts)
	var seats: Dictionary = r.get("seats", {})
	if seats.has(section):
		return seats[section]
	return r.get("spawn", Transform3D.IDENTITY)


# --- shared helpers ----------------------------------------------------------------------------


## A Kit whose coordinates are metres (it draws everything 1/MS size; the node scales it up).
static func _kit() -> Kit:
	var k := Kit.new()
	k.push(Transform3D(Basis().scaled(Vector3.ONE / MS), Vector3.ZERO))
	return k


static func _pack(k: Kit, cover: Kit, lights: Array, spawn: Transform3D, seats: Dictionary,
		views: Array, notes: Array, extra := {}) -> Dictionary:
	var d := {
		"mesh": k.finish(), "cover": cover.finish() if cover != null else null,
		"lights": lights, "spawn": spawn, "seats": seats, "views": views, "notes": notes,
		"tris": k.triangles() + (cover.triangles() if cover != null else 0),
	}
	d.merge(extra, true)
	return d


static func look(from: Vector3, to: Vector3) -> Transform3D:
	var dir := to - from
	if dir.length() < 0.001:
		dir = Vector3(0, 0, -1)
	if absf(dir.normalized().dot(Vector3.UP)) > 0.999:
		dir += Vector3(0.001, 0, 0.001)
	return Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), from)


static func _lamp(lights: Array, pos: Vector3, energy := 1.6, range_m := 9.0, kind := "lamp") -> void:
	lights.append({"pos": pos, "colour": Color(1.0, 0.72, 0.38), "energy": energy, "range": range_m, "kind": kind})


## An axis-aligned block between two corners.
static func _span(k: Kit, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float,
		col: Color, mat: int, bottom := true) -> void:
	if x1 - x0 < 0.001 or y1 - y0 < 0.001 or z1 - z0 < 0.001:
		return
	k.box(Vector3((x0 + x1) * 0.5, y0, (z0 + z1) * 0.5), Vector3(x1 - x0, y1 - y0, z1 - z0), col, mat, 0.0, bottom)


## A horizontal quad (facing up or down) between corners.
static func _floor(k: Kit, x0: float, z0: float, x1: float, z1: float, y: float, col: Color, mat: int, up := true) -> void:
	var inside := Vector3((x0 + x1) * 0.5, y - 1.0 if up else y + 1.0, (z0 + z1) * 0.5)
	k.quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), col, mat, inside)


## A checkerboard (two colours) floor, cells `cell` metres wide.
static func _checker(k: Kit, x0: float, z0: float, x1: float, z1: float, y: float, cell: float,
		c0: Color, c1: Color, mat := Kit.PAINT) -> void:
	var nx := maxi(1, int(round((x1 - x0) / cell)))
	var nz := maxi(1, int(round((z1 - z0) / cell)))
	var sx := (x1 - x0) / nx
	var sz := (z1 - z0) / nz
	for i in nx:
		for j in nz:
			_floor(k, x0 + i * sx, z0 + j * sz, x0 + (i + 1) * sx, z0 + (j + 1) * sz, y, c0 if (i + j) % 2 == 0 else c1, mat)


## A wall from a to b (plan coordinates x, z), `h` high from `y0`, `th` thick, with openings
## [centre along the wall, width, top height, sill height (optional)] in metres.
static func _wall(k: Kit, a: Vector2, b: Vector2, y0: float, h: float, th: float, col: Color, mat: int,
		holes := []) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.01:
		return
	var dir := d / length
	var yaw := atan2(-dir.y, dir.x)
	var sorted := holes.duplicate()
	sorted.sort_custom(func(p, q): return p[0] < q[0])
	var t := 0.0
	for hole in sorted:
		var t0: float = maxf(hole[0] - hole[1] * 0.5, 0.0)
		var t1: float = minf(hole[0] + hole[1] * 0.5, length)
		_wall_piece(k, a, dir, yaw, t, t0, y0, h, th, col, mat)
		var sill: float = hole[3] if hole.size() > 3 else 0.0
		if sill > 0.0:
			_wall_piece(k, a, dir, yaw, t0, t1, y0, sill, th, col, mat)
		if hole[2] < h:
			_wall_piece(k, a, dir, yaw, t0, t1, y0 + hole[2], h - hole[2], th, col, mat)
		t = t1
	_wall_piece(k, a, dir, yaw, t, length, y0, h, th, col, mat)


static func _wall_piece(k: Kit, a: Vector2, dir: Vector2, yaw: float, t0: float, t1: float, y0: float,
		h: float, th: float, col: Color, mat: int) -> void:
	if t1 - t0 < 0.01 or h < 0.01:
		return
	var c := a + dir * ((t0 + t1) * 0.5)
	k.box(Vector3(c.x, y0, c.y), Vector3(t1 - t0, h, th), col, mat, yaw, true)


## A rectangular room's four walls (x0..x1, z0..z1), openings per side: n, s, w, e (z0 is "n").
static func _room(k: Kit, x0: float, z0: float, x1: float, z1: float, y0: float, h: float, th: float,
		col: Color, mat: int, n := [], s := [], w := [], e := []) -> void:
	_wall(k, Vector2(x0 - th * 0.5, z0), Vector2(x1 + th * 0.5, z0), y0, h, th, col, mat, n)
	_wall(k, Vector2(x0 - th * 0.5, z1), Vector2(x1 + th * 0.5, z1), y0, h, th, col, mat, s)
	_wall(k, Vector2(x0, z0 + th * 0.5), Vector2(x0, z1 - th * 0.5), y0, h, th, col, mat, w)
	_wall(k, Vector2(x1, z0 + th * 0.5), Vector2(x1, z1 - th * 0.5), y0, h, th, col, mat, e)


## A column: plinth, base, tapering shaft, capital. `style` tuscan, ionic or corinthian.
static func _column(k: Kit, foot: Vector3, d: float, h: float, col: Color, mat := Kit.STONE, style := "tuscan") -> void:
	var r := d * 0.5
	var bh := d * 0.5
	var cap := d * (0.6 if style == "tuscan" else 0.95)
	k.box(foot, Vector3(d * 1.4, bh * 0.45, d * 1.4), col, mat)
	k.frustum(foot + Vector3(0, bh * 0.45, 0), r * 1.2, r * 1.04, bh * 0.55, col, mat, 12)
	var sh := h - bh - cap
	k.frustum(foot + Vector3(0, bh, 0), r, r * 0.85, sh, col, mat, 14, false)
	var ty := bh + sh
	if style == "tuscan":
		k.frustum(foot + Vector3(0, ty, 0), r * 0.9, r * 1.35, cap * 0.55, col, mat, 12)
		k.box(foot + Vector3(0, ty + cap * 0.55, 0), Vector3(d * 1.6, cap * 0.45, d * 1.6), col, mat)
	else:
		k.frustum(foot + Vector3(0, ty, 0), r * 0.9, r * 1.35, cap * 0.7, col.lightened(0.04), mat, 12)
		k.box(foot + Vector3(0, ty + cap * 0.7, 0), Vector3(d * 1.7, cap * 0.3, d * 1.7), col, mat)


## A beam between two points on a level (axis-aligned), `w` wide, `hh` deep, hanging from y_top.
static func _beam_x(k: Kit, x0: float, x1: float, y_top: float, z: float, w: float, hh: float, col: Color, mat := Kit.TIMBER) -> void:
	_span(k, x0, y_top - hh, z - w * 0.5, x1, y_top, z + w * 0.5, col, mat)


static func _beam_z(k: Kit, z0: float, z1: float, y_top: float, x: float, w: float, hh: float, col: Color, mat := Kit.TIMBER) -> void:
	_span(k, x - w * 0.5, y_top - hh, z0, x + w * 0.5, y_top, z1, col, mat)


## A flat coffered or beamed ceiling at height y: planking with a grid of beams below it.
static func _ceiling(k: Kit, x0: float, z0: float, x1: float, z1: float, y: float, bays_x: int, bays_z: int,
		beam: float, deep: float, plank: Color, beam_col: Color, coffered := true) -> void:
	_floor(k, x0, z0, x1, z1, y, plank, Kit.TIMBER, false)
	for i in range(bays_x + 1):
		var x := x0 + (x1 - x0) * i / bays_x
		_span(k, x - beam * 0.5, y - deep, z0, x + beam * 0.5, y, z1, beam_col, Kit.TIMBER, true)
	for j in range(bays_z + 1):
		var z := z0 + (z1 - z0) * j / bays_z
		_span(k, x0, y - deep, z - beam * 0.5, x1, y, z + beam * 0.5, beam_col, Kit.TIMBER, true)
	if coffered:   # a little gilded rosette in each coffer
		for i in bays_x:
			for j in bays_z:
				var cx := x0 + (x1 - x0) * (i + 0.5) / bays_x
				var cz := z0 + (z1 - z0) * (j + 0.5) / bays_z
				k.box(Vector3(cx, y - 0.04, cz), Vector3(beam * 1.4, 0.04, beam * 1.4), GILT, Kit.GOLD, 0.0, true)


## A person-sized figure (statue or carved shape): standing or seated, robed.
static func _figure(k: Kit, foot: Vector3, h: float, robe: Color, skin: Color, yaw := 0.0, seated := false,
		mat := Kit.PAINT, helmet := false) -> void:
	k.push(Kit.at(foot, yaw))
	var u := h / 1.75
	if seated:
		k.box(Vector3(0, 0, 0), Vector3(0.62 * u, 0.5 * u, 0.55 * u), robe, mat)           # seat and thighs
		k.box(Vector3(-0.17 * u, 0, 0.42 * u), Vector3(0.2 * u, 0.5 * u, 0.4 * u), robe, mat)   # legs down
		k.box(Vector3(0.17 * u, 0, 0.42 * u), Vector3(0.2 * u, 0.5 * u, 0.4 * u), robe, mat)
		k.frustum(Vector3(0, 0.5 * u, -0.05 * u), 0.3 * u, 0.24 * u, 0.58 * u, robe, mat, 9)    # torso
		k.box(Vector3(-0.34 * u, 0.62 * u, 0.05 * u), Vector3(0.14 * u, 0.1 * u, 0.5 * u), robe, mat)   # arms
		k.box(Vector3(0.34 * u, 0.62 * u, 0.05 * u), Vector3(0.14 * u, 0.1 * u, 0.5 * u), robe, mat)
		k.dome(Vector3(0, 1.08 * u, -0.05 * u), 0.15 * u, skin, mat, 1.2, 3, 8)
		if helmet:
			k.dome(Vector3(0, 1.2 * u, -0.05 * u), 0.17 * u, GILT, Kit.GOLD, 0.9, 3, 8)
	else:
		k.frustum(Vector3(0, 0, 0), 0.30 * u, 0.2 * u, 1.0 * u, robe, mat, 10)               # long robe
		k.frustum(Vector3(0, 1.0 * u, 0), 0.22 * u, 0.26 * u, 0.4 * u, robe, mat, 9)          # chest
		k.box(Vector3(-0.3 * u, 0.96 * u, 0.0), Vector3(0.1 * u, 0.5 * u, 0.12 * u), robe, mat)   # arms
		k.box(Vector3(0.3 * u, 0.96 * u, 0.0), Vector3(0.1 * u, 0.5 * u, 0.12 * u), robe, mat)
		k.dome(Vector3(0, 1.43 * u, 0), 0.15 * u, skin, mat, 1.2, 3, 8)
		if helmet:
			k.dome(Vector3(0, 1.56 * u, 0), 0.17 * u, GILT, Kit.GOLD, 0.9, 3, 8)
	k.pop()


## A bronze tripod lamp stand with a lit bowl (the light itself goes in `lights`).
static func _lamp_stand(k: Kit, pos: Vector3, h := 1.5) -> void:
	k.rod(pos + Vector3(0.18, 0.0, 0.0), pos + Vector3(0.02, h, 0.0), 0.02, BRONZE, Kit.GOLD)
	k.rod(pos + Vector3(-0.09, 0.0, 0.16), pos + Vector3(-0.01, h, 0.01), 0.02, BRONZE, Kit.GOLD)
	k.rod(pos + Vector3(-0.09, 0.0, -0.16), pos + Vector3(-0.01, h, -0.01), 0.02, BRONZE, Kit.GOLD)
	k.frustum(pos + Vector3(0, h, 0), 0.07, 0.17, 0.12, BRONZE, Kit.GOLD, 10)
	k.frustum(pos + Vector3(0, h + 0.1, 0), 0.08, 0.0, 0.2, FLAME, Kit.GOLD, 6)


## A little wooden or stone tree for gardens.
static func _tree(k: Kit, foot: Vector3, h: float, crown: Color = LEAF_C) -> void:
	k.frustum(foot, h * 0.04, h * 0.025, h * 0.5, WOOD_D, Kit.TIMBER, 6, false)
	k.dome(foot + Vector3(0, h * 0.35, 0), h * 0.33, crown, Kit.LEAF, 1.1, 3, 8)
	k.dome(foot + Vector3(h * 0.12, h * 0.52, h * 0.05), h * 0.23, crown.lightened(0.05), Kit.LEAF, 1.0, 3, 7)


# ====================================================================================================
#  TEMPLE
# ====================================================================================================

## Tuscan temple (Vitruvius 4.7): length:width 6:5, the back half the cella, the front half the
## pronaos; the width in ten parts, four for the middle cella and three each side for the
## alae (or smaller cellae); column height a third of the width, thickness a seventh of the
## height. Altar before the temple, lower than the statue (4.5, 4.9). The Capitoline temple
## (Dion. Hal. 4.61): three parallel cellae under one roof, three rows of columns in front, a
## single row on each flank.
static func _temple(sz: Vector2, year: int, variant: String) -> Dictionary:
	var L := sz.x
	var W := sz.y
	var capit := variant == "capitoline"
	var k := _kit()
	var kc := _kit()
	var lights: Array = []
	var ph := clampf(W * 0.1, 1.4, 4.5)                       # podium height
	var stone := TUFA if year < -150 else TRAVERTINE
	var order := Color(0.9, 0.82, 0.68) if year < -78 else MARBLE   # stuccoed tufa, later marble
	var ch := W / 3.0                                          # Vitruvius 4.7.2
	var cd := ch / 7.0
	var ae := ch * 0.2                                         # entablature
	var hc := ch + ae
	var top := ph + hc
	var e := cd * 1.1 + 0.25                                   # column centres in from the edge
	var wt := clampf(W * 0.03, 0.5, 1.4)
	# podium and the steps up its front
	_span(k, -W * 0.5, 0.0, -L * 0.5, W * 0.5, ph, L * 0.5, stone, Kit.STONE, false)
	_span(k, -W * 0.5 - 0.15, ph - 0.25, -L * 0.5 - 0.15, W * 0.5 + 0.15, ph, L * 0.5 + 0.15, stone.lightened(0.08), Kit.STONE, false)
	var nst := maxi(2, int(round(ph / 0.2)))
	var sw := W * (0.62 if capit else 0.5)
	for i in nst:
		_span(k, -sw * 0.5, 0.0, L * 0.5, sw * 0.5, ph * (i + 1) / nst, L * 0.5 + (nst - i) * 0.42, stone, Kit.STONE, false)
	# cellae
	var cellae: Array = []   # [x0, x1, deity]
	if capit:
		var side := cd * 2.6
		var wtot := W - 2.0 * side
		cellae = [[-wtot * 0.5, -wtot * 0.2, "Iuno"], [-wtot * 0.2, wtot * 0.2, "Iuppiter"], [wtot * 0.2, wtot * 0.5, "Minerva"]]
	else:
		var cw := maxf(W * 0.4, minf(W * 0.62, 6.0))
		cellae = [[-cw * 0.5, cw * 0.5, ""]]
	var zb := -L * 0.5 + e + 0.4          # back wall
	var x_lo: float = cellae[0][0]
	var x_hi: float = cellae[cellae.size() - 1][1]
	_wall(k, Vector2(x_lo - wt * 0.5, zb), Vector2(x_hi + wt * 0.5, zb), ph, hc, wt, order, Kit.PLASTER)
	var bounds: Array = [x_lo]
	for c in cellae:
		bounds.append(c[1])
	for xb in bounds:
		_wall(k, Vector2(xb, zb + wt * 0.5), Vector2(xb, 0.0), ph, hc, wt, order, Kit.PLASTER)
	# front wall of the cellae with a door to each
	var anchors := {}
	var spawn_in := Transform3D.IDENTITY
	for c in cellae:
		var x0: float = c[0]
		var x1: float = c[1]
		var cwid := x1 - x0
		var dw := clampf(cwid * 0.34, 1.8, 5.2)
		var dh := minf(dw * 2.1, hc * 0.78)
		_wall(k, Vector2(x0, 0.0), Vector2(x1, 0.0), ph, hc, wt, order, Kit.PLASTER, [[cwid * 0.5, dw, dh]])
		# bronze door leaves swung open into the cella
		var th := deg_to_rad(72.0)
		k.box(Vector3(x0 + cwid * 0.5 - dw * 0.5 + cos(th) * dw * 0.25, ph, -sin(th) * dw * 0.25), Vector3(dw * 0.5, dh, 0.14), BRONZE, Kit.GOLD, th, true)
		k.box(Vector3(x0 + cwid * 0.5 + dw * 0.5 - cos(th) * dw * 0.25, ph, -sin(th) * dw * 0.25), Vector3(dw * 0.5, dh, 0.14), BRONZE, Kit.GOLD, PI - th, true)
		# painted dado, floor, statue base
		var xi0 := x0 + wt * 0.5
		var xi1 := x1 - wt * 0.5
		_span(k, xi0, ph, zb + wt * 0.5, xi0 + 0.04, ph + 1.3, -wt * 0.5, RED, Kit.PLASTER)
		_span(k, xi1 - 0.04, ph, zb + wt * 0.5, xi1, ph + 1.3, -wt * 0.5, RED, Kit.PLASTER)
		_span(k, xi0, ph, zb + wt * 0.5, xi1, ph + 1.3, zb + wt * 0.5 + 0.04, RED, Kit.PLASTER)
		_checker(k, xi0, zb + wt * 0.5, xi1, -wt * 0.5, ph + 0.01, 1.0, Color(0.74, 0.70, 0.62), Color(0.55, 0.30, 0.24))
		var bw := minf(cwid * 0.55, 4.2)
		var bz := zb + wt * 0.5 + 2.0
		var bh := 1.1
		_span(k, (x0 + x1) * 0.5 - bw * 0.5, ph, bz - 1.4, (x0 + x1) * 0.5 + bw * 0.5, ph + bh, bz + 1.4, MARBLE_D, Kit.STONE)
		_span(k, (x0 + x1) * 0.5 - bw * 0.5 - 0.1, ph + bh, bz - 1.5, (x0 + x1) * 0.5 + bw * 0.5 + 0.1, ph + bh + 0.14, bz + 1.5, MARBLE, Kit.STONE)
		var hs := minf(hc * 0.5, 5.6)
		var cx := (x0 + x1) * 0.5
		var deity: String = c[2]
		if deity == "Iuppiter" or deity == "":
			# the seated god, terracotta painted red in the early temple, gilded later
			var robe := TERRA if year < -78 else GILT
			k.box(Vector3(cx, ph + bh + 0.14, bz), Vector3(1.8, 0.2, 1.3), WOOD_L, Kit.TIMBER)
			k.box(Vector3(cx, ph + bh + 0.14, bz - 0.55), Vector3(1.8, hs * 0.55, 0.2), WOOD_L, Kit.TIMBER)
			_figure(k, Vector3(cx, ph + bh + 0.3, bz - 0.1), hs * 0.9, robe, Color(0.74, 0.40, 0.28), 0.0, true, Kit.PAINT)
			k.rod(Vector3(cx + 0.75, ph + bh + 0.5, bz + 0.1), Vector3(cx + 0.75, ph + bh + hs * 0.9, bz + 0.1), 0.05, GILT, Kit.GOLD)   # sceptre
		else:
			_figure(k, Vector3(cx, ph + bh + 0.14, bz), hs, TOGA if deity == "Iuno" else Color(0.78, 0.74, 0.66), Color(0.9, 0.82, 0.72), 0.0, false, Kit.PAINT, deity == "Minerva")
		for s in [-1.0, 1.0]:
			var lp := Vector3(cx + s * (bw * 0.5 + 0.9), ph, bz + 0.6)
			_lamp_stand(k, lp, 1.6)
			_lamp(lights, lp + Vector3(0, 1.9, 0), 1.5, 9.0)
		# beamed (before Sulla) or coffered ceiling over the cella
		_ceiling(kc, xi0, zb + wt * 0.5, xi1, -wt * 0.5, top, maxi(2, int(cwid / 2.4)), maxi(3, int(absf(zb) / 2.4)), 0.34, 0.5, Color(0.5, 0.33, 0.2), WOOD_D, year >= -78)
		if deity == "Iuppiter" or deity == "":
			anchors["statue"] = Vector3(cx, ph + bh, bz)
			anchors["cella_door"] = Vector3(cx, ph, 0.0)
			spawn_in = look(Vector3(cx, ph + EYE, -0.6), Vector3(cx, ph + 2.8, bz))
	# pronaos columns: front rows, flank rows
	var nf := 6 if W >= 18.0 else 4
	var rows := 3 if capit else (2 if W >= 18.0 else 1)
	var rz: Array = []
	var spz := (L * 0.5 - 2.0 * e) / maxf(float(rows) - 0.4, 1.0)
	for r in rows:
		rz.append(L * 0.5 - e - r * spz)
	var xs: Array = []
	for i in nf:
		xs.append(-W * 0.5 + e + (W - 2.0 * e) * i / (nf - 1))
	var colstyle := "tuscan" if year < -78 else "corinthian"
	for z in rz:
		for x in xs:
			_column(k, Vector3(x, ph, z), cd, ch, order, Kit.STONE, colstyle)
	var nside := maxi(3, int(round((L - 2.0 * e) / ((W - 2.0 * e) / (nf - 1)))))
	for i in range(1, nside + 1):
		var z := L * 0.5 - e - (L - 2.0 * e) * i / nside
		if z > rz[rz.size() - 1] - 0.5 and z < rz[0] + 0.1 and rows > 1:
			pass
		for s in [-1.0, 1.0]:
			_column(k, Vector3(s * (W * 0.5 - e), ph, z), cd, ch, order, Kit.STONE, colstyle)
	# entablature: heavy beams over the columns
	var yb := ph + ch
	for z in rz:
		_span(k, -W * 0.5 + e - cd, yb, z - cd * 0.7, W * 0.5 - e + cd, yb + ae, z + cd * 0.7, order, Kit.STONE)
	for s in [-1.0, 1.0]:
		_span(k, s * (W * 0.5 - e) - cd * 0.7, yb, -L * 0.5 + e - cd, s * (W * 0.5 - e) + cd * 0.7, yb + ae, L * 0.5 - e + cd, order, Kit.STONE)
	_span(k, -W * 0.5 + e - cd, yb, -L * 0.5 + e - cd * 0.7, W * 0.5 - e + cd, yb + ae, -L * 0.5 + e + cd * 0.7, order, Kit.STONE)
	# pronaos ceiling and the roof
	_ceiling(kc, -W * 0.5 + e, 0.0, W * 0.5 - e, L * 0.5 - e, top, maxi(3, int(W / 3.0)), maxi(2, int(L / 6.0)), 0.3, 0.45, Color(0.5, 0.33, 0.2), WOOD_D, year >= -78)
	var rise := W * 0.16
	kc.gable_roof(Vector3(0, top, 0), L - 0.4, W - 0.2, rise, 0.7, 0.28, TILE_C, Kit.TILE, Color(0.86, 0.66, 0.5), Kit.PLASTER, PI / 2.0)
	# the altar outside, in front, facing the temple (Vitruvius 4.5, 4.9: lower than the statue)
	var za := L * 0.5 + nst * 0.42 + clampf(W * 0.3, 5.0, 14.0)
	var pave := minf(W * 0.8, 16.0)
	_span(k, -pave * 0.5, 0.0, za - pave * 0.4, pave * 0.5, 0.05, za + pave * 0.4, stone.darkened(0.05), Kit.STONE, false)
	_span(k, -1.6, 0.05, za - 1.2, 1.6, 0.3, za + 1.2, stone, Kit.STONE, false)
	_span(k, -1.3, 0.3, za - 0.9, 1.3, 1.5, za + 0.9, TRAVERTINE, Kit.STONE)
	_span(k, -1.45, 1.5, za - 1.05, 1.45, 1.7, za + 1.05, TRAVERTINE.lightened(0.05), Kit.STONE)
	for sx in [-1.0, 1.0]:      # the horns of the altar
		k.cylinder(Vector3(sx * 1.2, 1.7, za - 0.9), 0.1, 0.22, TRAVERTINE, Kit.STONE, 6)
		k.cylinder(Vector3(sx * 1.2, 1.7, za + 0.9), 0.1, 0.22, TRAVERTINE, Kit.STONE, 6)
	k.frustum(Vector3(0, 1.7, za), 0.7, 0.2, 0.3, Color(0.9, 0.45, 0.15), Kit.GOLD, 8)   # the fire on it
	lights.append({"pos": Vector3(0, 2.4, za), "colour": Color(1.0, 0.6, 0.25), "energy": 3.0, "range": 12.0, "kind": "fire"})
	anchors["altar"] = Vector3(0, 1.7, za)
	anchors["temple_front"] = Vector3(0, ph, L * 0.5)
	var spawn := look(Vector3(0, EYE, za + 7.0), Vector3(0, ph + hc * 0.5, 0.0))
	var views := [
		["front", spawn],
		["altar", look(Vector3(5.0, EYE, za + 3.0), Vector3(0, 1.4, za))],
		["pronaos", look(Vector3(0, ph + EYE, L * 0.5 - 1.0), Vector3(0, ph + 3.0, 0.0))],
		["cella", spawn_in],
		["overview", look(Vector3(W * 0.95, W * 0.8, za + W * 0.45), Vector3(0, 1.0, -L * 0.1))],
	]
	var notes := [
		"Proportions: Vitruvius 4.7 (6:5 length to width, cella the back half, columns a third of the width). Read.",
		"Altar outside before the temple, lower than the statue: Vitruvius 4.5 and 4.9. Read.",
		"Front faces east by default (Vitruvius 4.5); the Capitoline faced south (Dion. Hal. 4.61). Orientation comes from the monument data.",
		"Order: Tuscan before Sulla's rebuilding, Corinthian columns after (Plut. Publ. 15, Olympieion columns; not read here). # unverified",
		"Which of Juno and Minerva stood on which side is not in the passages read. # unverified",
		"Terracotta painted statue of Jupiter in the early temple: Pliny NH 35.157 # unverified.",
	]
	return _pack(k, kc, lights, spawn, {"altar": spawn, "pronaos": views[2][1], "cella": spawn_in}, views, notes,
		{"anchors": anchors, "floor_y": ph})

# ====================================================================================================
#  CURIA
# ====================================================================================================

## The Senate house: a hall with the senators' benches in tiers along the long sides, the
## presiding magistrates' tribunal at the far end, the doors to the Comitium. Height to the
## coffered ceiling is half the sum of length and width, a cornice runs round the walls at
## half height to hold the voices (Vitruvius 5.2.1-2). The Curia Iulia has Augustus's statue
## of Victory (Dio 51.22.1-2); the Curia Hostilia the painting of Messala's victory on a side
## wall (Pliny NH 35.22, through Platner-Ashby). The tiers follow the Diocletianic hall that
## survives (three broad steps each side, Platner-Ashby s.v. Curia Iulia): earlier benches
## are not described. # unverified
static func _curia(sz: Vector2, year: int, variant: String) -> Dictionary:
	var L := sz.x
	var W := sz.y
	var k := _kit()
	var kc := _kit()
	var lights: Array = []
	var wt := 1.4
	var H := (L + W) * 0.5                                    # Vitruvius 5.2.1
	var fl := 0.9                                             # floor above the Comitium
	var julia := variant == "julia"
	var wallc := PLAST_W if year < -50 else Color(0.90, 0.88, 0.82)
	var hw := (W - wt) * 0.5
	var zt := -L * 0.5 + wt * 0.5                              # inner back face
	var zf := L * 0.5 - wt * 0.5                               # inner front face
	# shell: the walls, with the door and the high windows
	var dw := minf(3.6, W * 0.22)
	var dh := minf(dw * 1.9, H * 0.4)
	var wy := H * 0.62
	var wh := H * 0.26
	var side_holes: Array = []
	var nwin := maxi(2, int(L / 5.0))
	for i in nwin:
		side_holes.append([L * (i + 0.5) / nwin, 2.2, wy + wh, wy])
	var fx := W * 0.5 + wt * 0.5
	var front_holes: Array = [[fx, dw, dh]]
	for s in [-1.0, 0.0, 1.0]:
		front_holes.append([fx + s * W * 0.27, 2.0, wy + wh, wy])
	_wall(k, Vector2(-W * 0.5 - wt * 0.5, L * 0.5), Vector2(W * 0.5 + wt * 0.5, L * 0.5), fl, H, wt, wallc, Kit.PLASTER, front_holes)
	_wall(k, Vector2(-W * 0.5 - wt * 0.5, -L * 0.5), Vector2(W * 0.5 + wt * 0.5, -L * 0.5), fl, H, wt, wallc, Kit.PLASTER)
	for s in [-1.0, 1.0]:
		_wall(k, Vector2(s * W * 0.5, -L * 0.5 + wt * 0.5), Vector2(s * W * 0.5, L * 0.5 - wt * 0.5), fl, H, wt, wallc, Kit.PLASTER, side_holes)
	# foundation, steps up from the Comitium, floor
	_span(k, -W * 0.5 - wt, 0.0, -L * 0.5 - wt, W * 0.5 + wt, fl, L * 0.5 + wt * 0.5, TRAVERTINE, Kit.STONE, false)
	for i in 3:
		_span(k, -dw * 0.8, 0.0, L * 0.5 + wt * 0.5, dw * 0.8, fl * (i + 1) / 3.0, L * 0.5 + wt * 0.5 + (3 - i) * 0.5, TRAVERTINE, Kit.STONE, false)
	_floor(k, -hw, zt, hw, zf, fl, MARBLE_D, Kit.PAINT)
	_checker(k, -hw * 0.45, zt + 5.0, hw * 0.45, zf - 4.0, fl + 0.005, 1.8, Color(0.82, 0.78, 0.70), Color(0.45, 0.28, 0.24))
	# painted lower walls (red dado), marble above it in the later hall; the cornice at half height
	for s in [-1.0, 1.0]:
		_span(k, s * hw - (0.0 if s < 0 else 0.05), fl, zt, s * hw + (0.05 if s < 0 else 0.0), fl + 1.6, zf, RED if year < 100 else MARBLE_D, Kit.PLASTER)
		_span(k, s * (hw - 0.18) - 0.18, fl + H * 0.5, zt, s * (hw - 0.18) + 0.18, fl + H * 0.5 + 0.5, zf, wallc.darkened(0.12), Kit.PLASTER)
	_span(k, -hw, fl + H * 0.5, zt, hw, fl + H * 0.5 + 0.5, zt + 0.36, wallc.darkened(0.12), Kit.PLASTER)
	_span(k, -hw, fl + H * 0.5, zf - 0.36, hw, fl + H * 0.5 + 0.5, zf, wallc.darkened(0.12), Kit.PLASTER)
	# tiers of benches along both long sides
	var td := 1.1
	var rs := 0.38
	var zs0 := zt + 3.9 + 0.5
	var zs1 := zf - 4.0
	for s in [-1.0, 1.0]:
		for j in 3:
			var xa: float = s * (hw - j * td)
			var xb: float = s * (hw - (j + 1) * td)
			var top := fl + (3 - j) * rs
			_span(k, minf(xa, xb), fl, zs0, maxf(xa, xb), top, zs1, TRAVERTINE, Kit.STONE, false)
			# the bench: a plank on little trestles at the aisle side of the tread
			var bx: float = xb + s * 0.42
			_span(k, bx - 0.22, top + 0.4, zs0 + 0.2, bx + 0.22, top + 0.47, zs1 - 0.2, WOOD_L, Kit.TIMBER)
			var nz := int((zs1 - zs0) / 2.2)
			for q in range(nz + 1):
				var zq := zs0 + 0.4 + (zs1 - zs0 - 0.8) * q / maxf(float(nz), 1.0)
				_span(k, bx - 0.18, top, zq - 0.05, bx + 0.18, top + 0.4, zq + 0.05, WOOD_D, Kit.TIMBER)
	# the tribunal at the far end, with the curule chairs; Victory (Curia Iulia) or an altar
	var tz1 := zt + 3.6
	_span(k, -hw, fl, zt, hw, fl + 1.0, tz1, TRAVERTINE, Kit.STONE, false)
	_span(k, -hw * 0.5, fl, tz1, hw * 0.5, fl + 0.34, tz1 + 0.5, TRAVERTINE, Kit.STONE, false)
	_span(k, -hw * 0.5, fl + 0.34, tz1, hw * 0.5, fl + 0.68, tz1 + 0.25, TRAVERTINE, Kit.STONE, false)
	_span(k, -hw + 0.2, fl + 1.0, zt, hw - 0.2, fl + 1.04, tz1 - 0.2, Color(0.5, 0.2, 0.18), Kit.CLOTH)   # a cloth over the dais
	for cx in [-1.4, 0.0, 1.4]:
		_curule(k, Vector3(cx, fl + 1.04, zt + 2.2), 0.0)
	var vz := zt + 1.0
	if julia:
		var gx := 0.0
		k.cylinder(Vector3(gx, fl + 1.04, vz), 0.9, 1.3, MARBLE, Kit.STONE, 8)
		k.dome(Vector3(gx, fl + 2.34, vz), 0.65, GILT, Kit.GOLD, 1.0, 4, 10)       # the globe
		_figure(k, Vector3(gx, fl + 3.1, vz), 3.2, GILT, GILT, 0.0, false, Kit.GOLD)   # Victory
		for sx in [-1.0, 1.0]:
			k.box(Vector3(gx + sx * 1.55, fl + 1.04, vz + 0.4), Vector3(0.1, 0.6, 1.8), GILT, Kit.GOLD, 0.0, true)   # her wings' stand-in
	else:
		k.cylinder(Vector3(0, fl + 1.04, zt + 1.2), 0.55, 1.2, TRAVERTINE, Kit.STONE, 8)
	# the altar before the tribunal, where each senator offered incense and wine (Suet. Aug. 35 # unverified)
	var az := tz1 + 1.6
	_span(k, -0.6, fl, az - 0.5, 0.6, fl + 1.0, az + 0.5, TRAVERTINE, Kit.STONE, false)
	_span(k, -0.7, fl + 1.0, az - 0.6, 0.7, fl + 1.12, az + 0.6, TRAVERTINE.lightened(0.05), Kit.STONE, false)
	k.frustum(Vector3(0, fl + 1.12, az), 0.35, 0.12, 0.2, Color(0.9, 0.45, 0.15), Kit.GOLD, 7)
	lights.append({"pos": Vector3(0, fl + 1.7, az), "colour": Color(1.0, 0.62, 0.28), "energy": 1.8, "range": 9.0, "kind": "fire"})
	if variant == "hostilia":
		# the painting of the victory over Hiero and the Carthaginians (263 BC) on the side wall
		_span(k, -hw + 0.0, fl + 2.4, -2.4, -hw + 0.07, fl + 5.1, 2.4, Color(0.55, 0.40, 0.24), Kit.TIMBER)
		_span(k, -hw + 0.07, fl + 2.6, -2.2, -hw + 0.1, fl + 4.9, 2.2, Color(0.70, 0.60, 0.38), Kit.PLASTER)
		for q in 5:
			_span(k, -hw + 0.1, fl + 3.0, -1.8 + q * 0.8, -hw + 0.12, fl + 4.1 + (q % 2) * 0.3, -1.5 + q * 0.8, [RED, BLUE_P, OCHRE, TOGA, RED][q], Kit.PAINT)
	# the doors, swung open into the hall
	var th := deg_to_rad(84.0)
	k.box(Vector3(-dw * 0.5 + cos(th) * dw * 0.25, fl, L * 0.5 - wt - sin(th) * dw * 0.25), Vector3(dw * 0.5, dh, 0.14), BRONZE, Kit.GOLD, th, true)
	k.box(Vector3(dw * 0.5 - cos(th) * dw * 0.25, fl, L * 0.5 - wt - sin(th) * dw * 0.25), Vector3(dw * 0.5, dh, 0.14), BRONZE, Kit.GOLD, PI - th, true)
	# hanging lamps and braziers (the real light comes through the windows and the door)
	for q in 3:
		for sx in [-1.0, 1.0]:
			var lp := Vector3(sx * hw * 0.55, fl + H * 0.72, zt + 5.0 + q * (L - 10.0) / 2.0)
			k.rod(lp, lp + Vector3(0, 2.4, 0), 0.015, BRONZE, Kit.GOLD)
			k.frustum(lp - Vector3(0, 0.25, 0), 0.07, 0.2, 0.22, BRONZE, Kit.GOLD, 8)
			_lamp(lights, lp - Vector3(0, 0.1, 0), 2.2, 13.0)
	# ceiling: lacunaria (coffers) at height H, then the roof
	_ceiling(kc, -hw, zt, hw, zf, fl + H, maxi(4, int(W / 2.2)), maxi(5, int(L / 2.2)), 0.4, 0.55, Color(0.55, 0.38, 0.22), WOOD_D, true)
	kc.gable_roof(Vector3(0, fl + H, 0), L + 1.0, W + 1.0, W * 0.2, 0.8, 0.3, TILE_C, Kit.TILE, wallc, Kit.PLASTER, PI / 2.0)
	var spawn := look(Vector3(0, EYE + 0.3, zf + 3.2), Vector3(0, fl + 2.2, zt))
	var views := [
		["door", spawn],
		["bench_left", look(Vector3(-hw + 1.3, fl + 3 * rs + 1.1, zs0 + 3.0), Vector3(hw - 1.0, fl + 1.4, zs0 + 6.0))],
		["tribunal", look(Vector3(0, fl + 1.0 + EYE, zt + 2.0), Vector3(0, fl + 3.0, zf))],
		["overview", look(Vector3(W * 0.55, H * 2.0, L * 0.62), Vector3(0, fl, -L * 0.12))],
	]
	var seats := {
		"bench_left": views[1][1], "tribunal": views[2][1], "door": spawn,
		"bench_right": look(Vector3(hw - 1.3, fl + 3 * rs + 1.1, zs0 + 3.0), Vector3(-hw + 1.0, fl + 1.4, zs0 + 6.0)),
	}
	var notes := [
		"Hall height, coffered ceiling and the cornice at half height: Vitruvius 5.2.1-2. Read.",
		"Size defaults to the Diocletianic hall, 25.20 x 17.61 m (Platner-Ashby s.v. Curia Iulia). Read; the Republican halls' dimensions are not recorded.",
		"Statue of Victory from Tarentum set up in the Curia Iulia by Augustus: Dio 51.22.1-2. Read.",
		"Painting of Messala's victory on a side wall of the Curia Hostilia: Pliny NH 35.22 via Platner-Ashby s.v. Curia Hostilia. Read (secondary).",
		"Tiers of benches (3 each side) copy the surviving Diocletianic hall; earlier subsellia unknown. # unverified",
		"High windows: needed for light, not attested for the Republican hall. # unverified",
		"Altar before the tribunal, incense and wine before each meeting: Suet. Aug. 35. # unverified",
	]
	return _pack(k, kc, lights, spawn, seats, views, notes, {
		"anchors": {"tribunal": Vector3(0, fl + 1.04, zt + 2.0), "door": Vector3(0, fl, zf), "victory": Vector3(0, fl + 1.04, vz),
			"altar": Vector3(0, fl + 1.12, az), "bench_left": Vector3(-hw + 1.5, fl + 1.2, 0.0), "bench_right": Vector3(hw - 1.5, fl + 1.2, 0.0)},
		"floor_y": fl})


## An x-fold curule chair (sella curulis): ivory legs crossed, a seat.
static func _curule(k: Kit, foot: Vector3, yaw: float) -> void:
	k.push(Kit.at(foot, yaw))
	for s in [-1.0, 1.0]:
		k.rod(Vector3(s * 0.28, 0.0, 0.2), Vector3(-s * 0.28, 0.46, -0.2), 0.025, IVORY, Kit.PAINT)
		k.rod(Vector3(s * 0.28, 0.0, -0.2), Vector3(-s * 0.28, 0.46, 0.2), 0.025, IVORY, Kit.PAINT)
	k.box(Vector3(0, 0.45, 0), Vector3(0.62, 0.05, 0.5), PURPLE, Kit.CLOTH)
	k.pop()



## A flight of steps rising from (x, z) along (dx, dz) (unit), n steps of `rise` x `run`.
static func _stairs(k: Kit, x: float, z: float, dx: float, dz: float, n: int, rise: float, run: float,
		width: float, col: Color, mat: int) -> void:
	var yaw := atan2(-dz, dx)
	for i in n:
		var cx := x + dx * run * (i + 0.5)
		var cz := z + dz * run * (i + 0.5)
		k.box(Vector3(cx, 0.0, cz), Vector3(run, rise * (i + 1), width), col, mat, yaw, false)


# ====================================================================================================
#  BASILICA
# ====================================================================================================

## A basilica on the Forum (Vitruvius 5.1.4-10): width a third to a half of the length, the
## nave three times the width of each aisle, columns as high as the aisle is wide, the upper
## columns a quarter smaller, a parapet between them, the tribunal for the magistrates, light
## through the open gaps over the upper order; shops (tabernae) along the Forum side
## (Platner-Ashby s.v. Basilica Aemilia: the tabernae novae, the two-storey colonnade,
## the Phrygian marble columns). Long axis along x, the Forum side +z, the tribunal at -x.
static func _basilica(sz: Vector2, year: int, variant := "") -> Dictionary:
	var L := sz.x
	var W := sz.y
	var k := _kit()
	var kc := _kit()
	var lights: Array = []
	var a := W / 5.0                               # aisle: a third of the nave (5.1.5)
	var m := W - 2.0 * a
	var ch := a                                    # columns as high as the aisle is wide
	var cd := ch / 9.0
	var ae := ch * 0.18                            # entablature
	var yg := ch + ae                              # gallery floor
	var uh := ch * 0.75                            # upper columns a quarter less
	var ud := cd * 0.75
	var yu := yg + uh + ae * 0.75                  # top of the upper entablature
	var par := uh * 0.75                           # parapet, a quarter less than the upper columns
	var wt := 1.2
	var col := MARBLE if year > -150 else Color(0.82, 0.76, 0.64)
	var wallc := Color(0.88, 0.80, 0.66)
	var zfront := W * 0.5
	# floor and the outer walls (the Forum side has the entrances and the shops' backs)
	_span(k, -L * 0.5 - wt, -0.3, -W * 0.5 - wt, L * 0.5 + wt, 0.0, W * 0.5 + 6.0, TRAVERTINE, Kit.STONE, false)
	_checker(k, -L * 0.5, -W * 0.5, L * 0.5, W * 0.5, 0.005, 2.4, Color(0.80, 0.76, 0.68), Color(0.58, 0.40, 0.36))
	var door_w := 3.6
	var nd := maxi(2, int(L / 22.0))
	var front_holes: Array = []
	for i in nd:
		front_holes.append([L * (i + 0.5) / nd, door_w, 6.4])
	_wall(k, Vector2(-L * 0.5, zfront), Vector2(L * 0.5, zfront), 0.0, yu, wt, wallc, Kit.PLASTER, front_holes)
	_wall(k, Vector2(-L * 0.5, -zfront), Vector2(L * 0.5, -zfront), 0.0, yu, wt, wallc, Kit.PLASTER, [[L * 0.3, 1.6, 3.0], [L * 0.7, 1.6, 3.0]])
	for s in [-1.0, 1.0]:
		_wall(k, Vector2(s * L * 0.5, -zfront), Vector2(s * L * 0.5, zfront), 0.0, yu, wt, wallc, Kit.PLASTER, [[W * 0.5, 2.4, 4.0]])
	# the two orders of columns round the nave
	var nx := maxi(4, int(round(L / (ch * 0.55))))
	var sx := L / nx
	for i in range(nx + 1):
		var x := -L * 0.5 + wt + (L - 2.0 * wt) * i / nx
		for s in [-1.0, 1.0]:
			_column(k, Vector3(x, 0.0, s * m * 0.5), cd, ch, col, Kit.PAINT, "corinthian")
			_column(k, Vector3(x, yg, s * m * 0.5), ud, uh, col, Kit.PAINT, "corinthian")
	for s in [-1.0, 1.0]:
		_span(k, -L * 0.5 + wt - cd, ch, s * m * 0.5 - cd * 0.7, L * 0.5 - wt + cd, yg, s * m * 0.5 + cd * 0.7, col, Kit.STONE)
		_span(k, -L * 0.5 + wt - cd, yg + uh, s * m * 0.5 - cd * 0.7, L * 0.5 - wt + cd, yu, s * m * 0.5 + cd * 0.7, col, Kit.STONE)
		# gallery floor over the aisle, and the parapet between the upper columns
		_floor(k, -L * 0.5 + wt * 0.5, s * m * 0.5 if s > 0 else -zfront + wt * 0.5, L * 0.5 - wt * 0.5, zfront - wt * 0.5 if s > 0 else s * m * 0.5, yg, WOOD_L, Kit.TIMBER)
		_span(k, -L * 0.5 + wt - cd, yg, s * m * 0.5 - 0.2, L * 0.5 - wt + cd, yg + par, s * m * 0.5 + 0.2, col.darkened(0.04), Kit.STONE)
	# the open gap over the upper order: piers carrying the roof, light between them (5.1.7-9)
	var yr := yu + 2.8
	for i in range(nx + 1):
		var x := -L * 0.5 + wt + (L - 2.0 * wt) * i / nx
		for s in [-1.0, 1.0]:
			_span(k, x - 0.5, yu, s * m * 0.5 - 0.5, x + 0.5, yr, s * m * 0.5 + 0.5, col, Kit.STONE)
	for s in [-1.0, 1.0]:
		_span(kc, -L * 0.5 + wt - cd, yr, s * m * 0.5 - 0.6, L * 0.5 - wt + cd, yr + 0.9, s * m * 0.5 + 0.6, WOOD_D, Kit.TIMBER)
	# roofs: the nave gable, the aisles' sloping roofs, a plank ceiling over the aisle galleries
	kc.gable_roof(Vector3(0, yr + 0.9, 0), L + 1.0, m + 3.0, m * 0.22, 0.6, 0.3, TILE_C, Kit.TILE, wallc, Kit.PLASTER)
	for s in [-1.0, 1.0]:
		var z0: float = s * (m * 0.5 + 0.6)
		var z1: float = s * (W * 0.5 + 0.6)
		var pts: Array = [Vector3(-L * 0.5 - 0.5, yu, z0), Vector3(L * 0.5 + 0.5, yu, z0), Vector3(L * 0.5 + 0.5, yu - 1.4, z1), Vector3(-L * 0.5 - 0.5, yu - 1.4, z1)]
		if s < 0:
			pts = [pts[3], pts[2], pts[1], pts[0]]
		kc.quad(pts[0], pts[1], pts[2], pts[3], TILE_C, Kit.TILE, Vector3(0, yu - 4.0, z0 * 0.5))
		kc.quad(pts[0] - Vector3(0, 0.3, 0), pts[3] - Vector3(0, 0.3, 0), pts[2] - Vector3(0, 0.3, 0), pts[1] - Vector3(0, 0.3, 0), WOOD_D, Kit.TIMBER, Vector3(0, yu + 4.0, z0 * 0.5))
	# tie beams across the nave
	var nb := maxi(5, int(L / 4.5))
	for i in range(1, nb):
		var x := -L * 0.5 + L * i / nb
		_span(kc, x - 0.25, yr + 0.9 - 0.7, -m * 0.5, x + 0.25, yr + 0.9, m * 0.5, WOOD_D, Kit.TIMBER)
	# the tribunal: a segmental platform with the magistrates' chairs (5.1.8)
	var tr := minf(m * 0.36, 8.0)
	var tx := -L * 0.5 + wt * 0.5
	var seg := 10
	for i in seg:
		var a0 := -PI * 0.5 + PI * i / seg
		var a1 := -PI * 0.5 + PI * (i + 1) / seg
		var p0 := Vector2(tx + cos(a0) * tr, sin(a0) * tr * 1.15)
		var p1 := Vector2(tx + cos(a1) * tr, sin(a1) * tr * 1.15)
		var c := Vector3(tx, 0.4, 0.0)
		k.quad(Vector3(tx, 1.1, 0), Vector3(p0.x, 1.1, p0.y), Vector3(p1.x, 1.1, p1.y), Vector3(tx, 1.1, 0), wallc, Kit.STONE, c)
		k.tri(Vector3(tx, 1.1, 0), Vector3(p0.x, 1.1, p0.y), Vector3(p1.x, 1.1, p1.y), TRAVERTINE, Kit.STONE, Vector3(tx, 0.5, 0.0))
		k.quad(Vector3(p0.x, 0, p0.y), Vector3(p1.x, 0, p1.y), Vector3(p1.x, 1.1, p1.y), Vector3(p0.x, 1.1, p0.y), TRAVERTINE, Kit.STONE, c)
	for i in range(-2, 3):
		_curule(k, Vector3(tx + 1.6, 1.1, i * 1.5), -PI * 0.5)
	for s in [-1.0, 1.0]:
		_lamp_stand(k, Vector3(tx + tr * 0.9, 1.1, s * tr * 0.6), 1.7)
		_lamp(lights, Vector3(tx + tr * 0.9, 3.0, s * tr * 0.6), 1.6, 11.0)
	# the judges' benches before it
	for q in 3:
		_span(k, tx + tr + 1.5 + q * 1.4, 0.0, -m * 0.3, tx + tr + 1.9 + q * 1.4, 0.45 + q * 0.0, m * 0.3, WOOD_L, Kit.TIMBER)
	# the water clock of Scipio Nasica (159 BC), under cover in the basilica (Pliny NH 7.215)
	if variant == "aemilia" and year >= -159:
		k.cylinder(Vector3(L * 0.5 - 6.0, 0.0, -m * 0.5 + 1.2), 0.5, 1.8, BRONZE, Kit.GOLD, 10)
	# stairs to the gallery at the east end of the north aisle
	_stairs(k, L * 0.5 - wt - 0.4, -W * 0.5 + wt + 1.0, -1.0, 0.0, int(yg / 0.2), 0.2, 0.3, 1.6, WOOD, Kit.TIMBER)
	# hanging lamps along both aisles
	for i in range(1, nx, 2):
		var x := -L * 0.5 + (L) * i / nx
		for s in [-1.0, 1.0]:
			_lamp(lights, Vector3(x, 4.2, s * (m * 0.5 + a * 0.5)), 1.4, 9.0)
	# the shops along the Forum side
	var nshop := maxi(3, int(L / 4.6))
	var sw := L / nshop
	var sd := 5.0
	for i in range(nshop + 1):
		var sxp := -L * 0.5 + sw * i
		var gap := (i % 5 == 2)    # every fifth bay is an entrance passage
		_span(k, sxp - 0.2, 0.0, zfront + 0.6, sxp + 0.2, 4.6, zfront + sd, wallc.darkened(0.06), Kit.PLASTER)
	for i in nshop:
		var cx := -L * 0.5 + sw * (i + 0.5)
		if i % 5 == 2:
			continue
		_span(k, cx - sw * 0.5 + 0.3, 0.0, zfront + sd - 0.5, cx + sw * 0.5 - 0.3, 1.0, zfront + sd - 0.1, WOOD, Kit.TIMBER)   # counter
		_span(k, cx - 0.6, 0.0, zfront + 1.2, cx + 0.6, 0.8, zfront + 2.0, WOOD_L, Kit.TIMBER)   # table
		k.cylinder(Vector3(cx - sw * 0.3, 0.0, zfront + 1.2), 0.3, 0.9, TERRA, Kit.PAINT, 8)  # a jar
		_lamp(lights, Vector3(cx, 3.0, zfront + 2.6), 0.8, 5.0)
	_span(kc, -L * 0.5, 4.6, zfront + 0.6, L * 0.5, 4.9, zfront + sd + 0.3, TILE_C, Kit.TILE)
	var spawn := look(Vector3(L * 0.2, EYE, zfront + 1.5), Vector3(-L * 0.5 + 4.0, 3.0, 0.0))
	var views := [
		["door", spawn],
		["nave", look(Vector3(L * 0.5 - 7.0, EYE, 0.0), Vector3(-L * 0.5 + 4.0, 3.0, 0.0))],
		["gallery", look(Vector3(L * 0.15, yg + EYE, -(m * 0.5 + a * 0.5)), Vector3(-L * 0.2, yg + 1.5, m * 0.3))],
		["tribunal", look(Vector3(tx + 3.0, 1.1 + EYE, 0.0), Vector3(L * 0.3, 4.0, 0.0))],
		["shops", look(Vector3(-L * 0.25, EYE, zfront + sd - 1.0), Vector3(-L * 0.25, 2.0, zfront - 1.0))],
		["overview", look(Vector3(L * 0.1, W * 1.55, W * 1.1), Vector3(-L * 0.1, 3.0, 0.0))],
	]
	var seats := {"door": spawn, "nave": views[1][1], "gallery": views[2][1], "tribunal": views[3][1]}
	var notes := [
		"Proportions: Vitruvius 5.1.4-5 (width 1/3 to 1/2 of length, aisle a third of the nave, column height = aisle width, upper columns 3/4, parapet 3/4 of them). Read.",
		"Tribunal as a segment of a circle for the magistrates, apart from the merchants: Vitruvius 5.1.8 (his Fano basilica puts it mid-side; here at the end). Read; the placement is conjecture.",
		"Light through open spaces over the upper order: Vitruvius 5.1.7, 5.1.9. Read.",
		"Shops (tabernae novae) on the Forum side, two-storey colonnade, water clock of Nasica 159 BC: Platner-Ashby s.v. Basilica Aemilia (Liv. 40.51; Plin. NH 7.215). Read (secondary).",
		"The Basilica Iulia had five aisles (monuments.json); this interior builds the Vitruvian three-aisle plan. # unverified for Iulia",
		"Shop interiors, the stairs, the floor pattern, lamps: conjecture.",
	]
	return _pack(k, kc, lights, spawn, seats, views, notes, {"anchors": {"tribunal": Vector3(tx + 1.6, 1.1, 0.0), "door": Vector3(0, 0, zfront)}, "floor_y": 0.0})


# --- STUBS ---
static func _circus(_sz: Vector2, _y: int) -> Dictionary:
	return {}
static func _arena(_sz: Vector2, _y: int, _v: String) -> Dictionary:
	return {}
static func _domus(_sz: Vector2, _y: int) -> Dictionary:
	return {}
static func _insula(_sz: Vector2, _y: int) -> Dictionary:
	return {}
static func _theatre(_sz: Vector2, _y: int, _v: String) -> Dictionary:
	return {}
