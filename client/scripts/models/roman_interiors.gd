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
	d["ground"] = not d.get("no_ground", false)
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
		for s: float in [-1.0, 1.0]:
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
		for s: float in [-1.0, 1.0]:
			_column(k, Vector3(s * (W * 0.5 - e), ph, z), cd, ch, order, Kit.STONE, colstyle)
	# entablature: heavy beams over the columns
	var yb := ph + ch
	for z in rz:
		_span(k, -W * 0.5 + e - cd, yb, z - cd * 0.7, W * 0.5 - e + cd, yb + ae, z + cd * 0.7, order, Kit.STONE)
	for s: float in [-1.0, 1.0]:
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
	for sx: float in [-1.0, 1.0]:      # the horns of the altar
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
	for s: float in [-1.0, 0.0, 1.0]:
		front_holes.append([fx + s * W * 0.27, 2.0, wy + wh, wy])
	_wall(k, Vector2(-W * 0.5 - wt * 0.5, L * 0.5), Vector2(W * 0.5 + wt * 0.5, L * 0.5), fl, H, wt, wallc, Kit.PLASTER, front_holes)
	_wall(k, Vector2(-W * 0.5 - wt * 0.5, -L * 0.5), Vector2(W * 0.5 + wt * 0.5, -L * 0.5), fl, H, wt, wallc, Kit.PLASTER)
	for s: float in [-1.0, 1.0]:
		_wall(k, Vector2(s * W * 0.5, -L * 0.5 + wt * 0.5), Vector2(s * W * 0.5, L * 0.5 - wt * 0.5), fl, H, wt, wallc, Kit.PLASTER, side_holes)
	# foundation, steps up from the Comitium, floor
	_span(k, -W * 0.5 - wt, 0.0, -L * 0.5 - wt, W * 0.5 + wt, fl, L * 0.5 + wt * 0.5, TRAVERTINE, Kit.STONE, false)
	for i in 3:
		_span(k, -dw * 0.8, 0.0, L * 0.5 + wt * 0.5, dw * 0.8, fl * (i + 1) / 3.0, L * 0.5 + wt * 0.5 + (3 - i) * 0.5, TRAVERTINE, Kit.STONE, false)
	_floor(k, -hw, zt, hw, zf, fl, MARBLE_D, Kit.PAINT)
	_checker(k, -hw * 0.45, zt + 5.0, hw * 0.45, zf - 4.0, fl + 0.005, 1.8, Color(0.82, 0.78, 0.70), Color(0.45, 0.28, 0.24))
	# painted lower walls (red dado), marble above it in the later hall; the cornice at half height
	for s: float in [-1.0, 1.0]:
		_span(k, s * hw - (0.0 if s < 0 else 0.05), fl, zt, s * hw + (0.05 if s < 0 else 0.0), fl + 1.6, zf, RED if year < 100 else MARBLE_D, Kit.PLASTER)
		_span(k, s * (hw - 0.18) - 0.18, fl + H * 0.5, zt, s * (hw - 0.18) + 0.18, fl + H * 0.5 + 0.5, zf, wallc.darkened(0.12), Kit.PLASTER)
	_span(k, -hw, fl + H * 0.5, zt, hw, fl + H * 0.5 + 0.5, zt + 0.36, wallc.darkened(0.12), Kit.PLASTER)
	_span(k, -hw, fl + H * 0.5, zf - 0.36, hw, fl + H * 0.5 + 0.5, zf, wallc.darkened(0.12), Kit.PLASTER)
	# tiers of benches along both long sides
	var td := 1.1
	var rs := 0.38
	var zs0 := zt + 3.9 + 0.5
	var zs1 := zf - 4.0
	for s: float in [-1.0, 1.0]:
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
	for cx: float in [-1.4, 0.0, 1.4]:
		_curule(k, Vector3(cx, fl + 1.04, zt + 2.2), 0.0)
	var vz := zt + 1.0
	if julia:
		var gx := 0.0
		k.cylinder(Vector3(gx, fl + 1.04, vz), 0.9, 1.3, MARBLE, Kit.STONE, 8)
		k.dome(Vector3(gx, fl + 2.34, vz), 0.65, GILT, Kit.GOLD, 1.0, 4, 10)       # the globe
		_figure(k, Vector3(gx, fl + 3.1, vz), 3.2, GILT, GILT, 0.0, false, Kit.GOLD)   # Victory
		for sx: float in [-1.0, 1.0]:
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
		for sx: float in [-1.0, 1.0]:
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
	for s: float in [-1.0, 1.0]:
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
	for s: float in [-1.0, 1.0]:
		_wall(k, Vector2(s * L * 0.5, -zfront), Vector2(s * L * 0.5, zfront), 0.0, yu, wt, wallc, Kit.PLASTER, [[W * 0.5, 2.4, 4.0]])
	# the two orders of columns round the nave
	var nx := maxi(4, int(round(L / (ch * 0.55))))
	var sx := L / nx
	for i in range(nx + 1):
		var x := -L * 0.5 + wt + (L - 2.0 * wt) * i / nx
		for s: float in [-1.0, 1.0]:
			_column(k, Vector3(x, 0.0, s * m * 0.5), cd, ch, col, Kit.PAINT, "corinthian")
			_column(k, Vector3(x, yg, s * m * 0.5), ud, uh, col, Kit.PAINT, "corinthian")
	for s: float in [-1.0, 1.0]:
		_span(k, -L * 0.5 + wt - cd, ch, s * m * 0.5 - cd * 0.7, L * 0.5 - wt + cd, yg, s * m * 0.5 + cd * 0.7, col, Kit.STONE)
		_span(k, -L * 0.5 + wt - cd, yg + uh, s * m * 0.5 - cd * 0.7, L * 0.5 - wt + cd, yu, s * m * 0.5 + cd * 0.7, col, Kit.STONE)
		# gallery floor over the aisle, and the parapet between the upper columns
		_floor(k, -L * 0.5 + wt * 0.5, s * m * 0.5 if s > 0 else -zfront + wt * 0.5, L * 0.5 - wt * 0.5, zfront - wt * 0.5 if s > 0 else s * m * 0.5, yg, WOOD_L, Kit.TIMBER)
		_span(k, -L * 0.5 + wt - cd, yg, s * m * 0.5 - 0.2, L * 0.5 - wt + cd, yg + par, s * m * 0.5 + 0.2, col.darkened(0.04), Kit.STONE)
	# the open gap over the upper order: piers carrying the roof, light between them (5.1.7-9)
	var yr := yu + 2.8
	for i in range(nx + 1):
		var x := -L * 0.5 + wt + (L - 2.0 * wt) * i / nx
		for s: float in [-1.0, 1.0]:
			_span(k, x - 0.5, yu, s * m * 0.5 - 0.5, x + 0.5, yr, s * m * 0.5 + 0.5, col, Kit.STONE)
	for s: float in [-1.0, 1.0]:
		_span(kc, -L * 0.5 + wt - cd, yr, s * m * 0.5 - 0.6, L * 0.5 - wt + cd, yr + 0.9, s * m * 0.5 + 0.6, WOOD_D, Kit.TIMBER)
	# roofs: the nave gable, the aisles' sloping roofs, a plank ceiling over the aisle galleries
	kc.gable_roof(Vector3(0, yr + 0.9, 0), L + 1.0, m + 3.0, m * 0.22, 0.6, 0.3, TILE_C, Kit.TILE, wallc, Kit.PLASTER)
	for s: float in [-1.0, 1.0]:
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
	for s: float in [-1.0, 1.0]:
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
		for s: float in [-1.0, 1.0]:
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



# ====================================================================================================
#  CIRCUS MAXIMUS
# ====================================================================================================

## One row of a stepped bank: radial start, radial end and top height of row `r` (rows in
## groups of `per`, a walkway of `walk` and an extra `lift` between groups).
static func _row(r: int, per: int, tread: float, rise: float, walk: float, lift: float, h0: float) -> Array:
	var g := r / per
	var d0 := r * tread + g * walk
	return [d0, d0 + tread, h0 + (r + 1) * rise + g * lift]


## The Circus Maximus from inside. Long axis z: the twelve carceres at -z (the Forum Boarium end),
## the curved end (sphendone) at +z, the spina along the middle, the Palatine (and the pulvinar,
## Mon. Anc. 4.4) on the +x side. Sizes: the arena 568 m long and 75-87 m wide, the spina 344 m
## (Platner-Ashby, the final plan); Dionysius 3.68 in 7 BC gives 3.5 stadia by 4 plethra with a
## euripus 10 ft wide and 10 ft deep, three tiers of seats, the lowest of stone, the upper two of
## wood, the carceres roofless. In the Republic all the seats were wooden (Livy 1.35.8, 1.56.2),
## the carceres first built in 329 BC (Livy 8.20.1), the eggs set up in 174 BC (Livy 41.27.6),
## the dolphins in 33 BC (Dio 49.43.2), the euripus made by Caesar in 46 BC (Pliny NH 8.21).
static func _circus(sz: Vector2, year: int) -> Dictionary:
	var L := sz.x
	var W := sz.y
	var k := _kit()
	var lights: Array = []
	var cz := L * 0.0267                       # depth of the carceres building
	var za := -L * 0.5 + cz                    # where the arena begins (the starting line)
	var A := L * 0.5 - za                      # arena length (568 for 600)
	var euripus := year >= -46
	var ew := 3.0                              # 10 Roman feet
	var stone_low := year >= -46               # the lowest tier of stone from Caesar's rebuilding
	var R0 := W * 0.5 + (ew + 0.8 if euripus else 1.5)
	var zc := L * 0.5 - R0                     # centre of the curved end
	# the track
	_floor(k, -W * 0.5, za, W * 0.5, L * 0.5 - R0 + W * 0.5 + 0.0, 0.0, SAND, Kit.EARTH)
	k.polygon(_arc_pts(0.0, zc, W * 0.5, 0.0, PI, 12, 0.0), SAND, Kit.EARTH, Vector3(0, -1, zc))
	if euripus:
		_floor(k, W * 0.5, za, W * 0.5 + ew, zc, -0.25, Color(0.35, 0.55, 0.65), Kit.WATER)
		_floor(k, -W * 0.5 - ew, za, -W * 0.5, zc, -0.25, Color(0.35, 0.55, 0.65), Kit.WATER)
		for i in 12:
			var a0 := PI * i / 12.0
			var a1 := PI * (i + 1) / 12.0
			var q: Array = []
			for aa in [a0, a1]:
				q.append([Vector3(cos(aa) * W * 0.5, -0.25, zc + sin(aa) * W * 0.5), Vector3(cos(aa) * (W * 0.5 + ew), -0.25, zc + sin(aa) * (W * 0.5 + ew))])
			k.quad(q[0][0], q[0][1], q[1][1], q[1][0], Color(0.35, 0.55, 0.65), Kit.WATER, Vector3(0, -3, zc))
	# the stepped banks: 3 groups of 12 rows; a podium wall in front
	var per := 12
	var nrow := 36
	var tread := 0.75
	var rise := 0.42
	var walk := 3.0
	var lift := 1.3
	var h0 := 2.2 if euripus else 1.4
	var seat_c := TRAVERTINE if stone_low else WOOD_L
	var wall_c := TRAVERTINE
	var rows: Array = []
	for r in nrow:
		rows.append(_row(r, per, tread, rise, walk, lift, h0))
	var last_d: float = rows[nrow - 1][1]
	var top_h: float = rows[nrow - 1][2]
	for s: float in [-1.0, 1.0]:
		var prev_h := 0.0
		_span(k, minf(s * (R0 - 0.7), s * R0), -0.3, za, maxf(s * (R0 - 0.7), s * R0), h0, zc, wall_c, Kit.STONE, false)   # podium wall
		prev_h = h0
		for r in nrow:
			var d0: float = rows[r][0]
			var d1: float = rows[r][1]
			var hh: float = rows[r][2]
			var mat_r := Kit.STONE if (stone_low and r < per) else Kit.TIMBER
			var col_r := TRAVERTINE if (stone_low and r < per) else (WOOD_L if (r / 3) % 2 == 0 else WOOD)
			var xi: float = s * (R0 + d0)
			var xo: float = s * (R0 + d1)
			if r > 0 and r % per == 0:   # the walkway between the tiers
				var pd: float = rows[r - 1][1]
				var py: float = rows[r - 1][2]
				k.quad(Vector3(s * (R0 + pd), py, za), Vector3(s * (R0 + d0), py, za), Vector3(s * (R0 + d0), py, zc), Vector3(s * (R0 + pd), py, zc), DUST, Kit.EARTH, Vector3(s * (R0 + d0), py - 1, zc))
				prev_h = py
			k.quad(Vector3(xi, prev_h, za), Vector3(xi, prev_h, zc), Vector3(xi, hh, zc), Vector3(xi, hh, za), col_r.darkened(0.08), mat_r, Vector3(s * (R0 + d1 + 4.0), prev_h, (za + zc) * 0.5))
			k.quad(Vector3(xi, hh, za), Vector3(xo, hh, za), Vector3(xo, hh, zc), Vector3(xi, hh, zc), col_r, mat_r, Vector3(xi, hh - 1, (za + zc) * 0.5))
			prev_h = hh
		# aisles (stairs) every 40 m on the straight side
		var na := int((zc - za) / 40.0)
		for i in range(1, na + 1):
			var zs := za + (zc - za) * i / (na + 1)
			for r in nrow:
				var d0: float = rows[r][0]
				var d1: float = rows[r][1]
				var hh: float = rows[r][2]
				_floor(k, minf(s * (R0 + d0), s * (R0 + d1)), zs - 0.7, maxf(s * (R0 + d0), s * (R0 + d1)), zs + 0.7, hh + 0.01, DUST.darkened(0.2), Kit.EARTH)
		# the back wall behind the top row
		var xb: float = s * (R0 + last_d + 0.3)
		k.quad(Vector3(xb, top_h, za), Vector3(xb, top_h, zc), Vector3(xb, top_h + 2.8, zc), Vector3(xb, top_h + 2.8, za), wall_c, Kit.PLASTER, Vector3(s * (R0 + last_d - 5), top_h, (za + zc) * 0.5))
	# the curved end
	var segs := 28
	for r in nrow:
		var d0: float = rows[r][0]
		var d1: float = rows[r][1]
		var hh: float = rows[r][2]
		var prev: float = h0 if r == 0 else rows[r - 1][2]
		var col_r2 := TRAVERTINE if (stone_low and r < per) else (WOOD_L if (r / 3) % 2 == 0 else WOOD)
		var mat2 := Kit.STONE if (stone_low and r < per) else Kit.TIMBER
		if r > 0 and r % per == 0:
			var pd2: float = rows[r - 1][1]
			for i in segs:
				var t0 := PI * i / segs
				var t1 := PI * (i + 1) / segs
				k.quad(_pol(R0 + pd2, t0, zc, prev), _pol(R0 + pd2, t1, zc, prev), _pol(R0 + d0, t1, zc, prev), _pol(R0 + d0, t0, zc, prev), DUST, Kit.EARTH, Vector3(0, prev - 1, zc))
		for i in segs:
			var t0 := PI * i / segs
			var t1 := PI * (i + 1) / segs
			var tm := (t0 + t1) * 0.5
			var far := _pol(R0 + d1 + 4.0, tm, zc, prev)
			k.quad(_pol(R0 + d0, t0, zc, prev), _pol(R0 + d0, t1, zc, prev), _pol(R0 + d0, t1, zc, hh), _pol(R0 + d0, t0, zc, hh), col_r2.darkened(0.08), mat2, far)
			k.quad(_pol(R0 + d0, t0, zc, hh), _pol(R0 + d1, t0, zc, hh), _pol(R0 + d1, t1, zc, hh), _pol(R0 + d0, t1, zc, hh), col_r2, mat2, _pol(R0 + d0, tm, zc, hh - 1.0))
	for i in segs:
		var t0 := PI * i / segs
		var t1 := PI * (i + 1) / segs
		k.quad(_pol(R0 - 0.7, t0, zc, -0.3), _pol(R0 - 0.7, t1, zc, -0.3), _pol(R0 - 0.7, t1, zc, h0), _pol(R0 - 0.7, t0, zc, h0), wall_c, Kit.STONE, _pol(R0 + 3.0, (t0 + t1) * 0.5, zc, 0.5))
		var rb := R0 + last_d + 0.3
		k.quad(_pol(rb, t0, zc, top_h), _pol(rb, t1, zc, top_h), _pol(rb, t1, zc, top_h + 2.8), _pol(rb, t0, zc, top_h + 2.8), wall_c, Kit.PLASTER, _pol(rb - 5.0, (t0 + t1) * 0.5, zc, top_h))
	# the spina: a low platform down the middle, 344 m of it
	var Ls := A * 0.605
	var zs0 := za + (A - Ls) * 0.5
	var zs1 := zs0 + Ls
	var sw := 8.0
	_span(k, -sw * 0.5, 0.0, zs0, sw * 0.5, 1.2, zs1, TRAVERTINE, Kit.STONE, false)
	_span(k, -sw * 0.5 - 0.3, 1.2, zs0 - 0.3, sw * 0.5 + 0.3, 1.45, zs1 + 0.3, TRAVERTINE.lightened(0.05), Kit.STONE, false)
	if euripus and year >= -30:   # basins with dolphins spouting water appear later on; a channel for now
		_floor(k, -sw * 0.25, zs0 + 6.0, sw * 0.25, zs1 - 6.0, 1.47, Color(0.35, 0.55, 0.65), Kit.WATER)
	# the metae: three cones on a base at each end (wood before Claudius, Platner-Ashby)
	for ze in [zs0 - 3.5, zs1 + 3.5]:
		_span(k, -sw * 0.5 - 0.5, 0.0, ze - 3.0, sw * 0.5 + 0.5, 1.0, ze + 3.0, TRAVERTINE, Kit.STONE, false)
		for cx: float in [-2.6, 0.0, 2.6]:
			k.frustum(Vector3(cx, 1.0, ze), 1.15, 0.3, 4.6, Color(0.50, 0.36, 0.2), Kit.TIMBER, 10)
	# the eggs (174 BC) near the carceres end, the dolphins (33 BC) near the other
	if year >= -174:
		var ze2 := zs0 + 8.0
		_span(k, -3.0, 1.45, ze2 - 0.2, 3.0, 3.6, ze2 + 0.2, WOOD_D, Kit.TIMBER)
		for q in 7:
			var ex := -2.7 + q * 0.9
			k.dome(Vector3(ex, 3.6, ze2), 0.38, IVORY, Kit.PAINT, 1.45, 3, 8)
	if year >= -33:
		var zd := zs1 - 8.0
		for q in 7:
			var dx := -2.7 + q * 0.9
			k.rod(Vector3(dx, 1.45, zd), Vector3(dx, 3.2, zd), 0.05, BRONZE, Kit.GOLD)
			k.dome(Vector3(dx, 3.2, zd), 0.34, BRONZE, Kit.GOLD, 0.7, 3, 7)
			k.rod(Vector3(dx, 3.4, zd - 0.45), Vector3(dx, 3.0, zd + 0.45), 0.08, BRONZE, Kit.GOLD)
	# statues on columns (Livy 39.7.8, 40.2.1), a shrine in the middle, the obelisk once Augustus set it up
	if year >= -189:
		for q in 3:
			var zz := zs0 + Ls * (0.3 + 0.2 * q)
			k.frustum(Vector3(-2.0, 1.45, zz), 0.45, 0.4, 5.5, TRAVERTINE, Kit.STONE, 10)
			_figure(k, Vector3(-2.0, 6.95, zz), 2.4, BRONZE, BRONZE, 0.0, false, Kit.GOLD)
	var zm := (zs0 + zs1) * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz2: float in [-1.0, 1.0]:
			_column(k, Vector3(2.2 + sx * 0.7, 1.45, zm + sz2 * 0.9), 0.4, 3.6, TRAVERTINE, Kit.STONE, "tuscan")
	_span(k, 1.3, 5.05, zm - 1.5, 3.1, 5.4, zm + 1.5, TRAVERTINE, Kit.STONE)
	k.wedge(Vector3(2.2, 5.4, zm), 3.2, 1.8, 0.9, TERRA, Kit.PLASTER, PI / 2.0)
	if year >= -10:
		k.push(Kit.at(Vector3(0, 1.45, zm), PI / 4.0))
		k.frustum(Vector3.ZERO, 1.2, 0.8, 21.5, Color(0.82, 0.55, 0.50), Kit.STONE, 4)
		k.frustum(Vector3(0, 21.5, 0), 0.8, 0.0, 1.4, GILT, Kit.GOLD, 4)
		k.pop()
	# the finish line (position unverified) and the pulvinar on the Palatine side
	var zf := za + A * 0.27
	_floor(k, -W * 0.5, zf - 0.25, W * 0.5, zf + 0.25, 0.02, Color(0.95, 0.94, 0.9), Kit.PAINT)
	var pr := 9
	var px0: float = R0 + rows[pr][0]
	var py0: float = rows[pr][2]
	_span(k, px0 - 0.4, py0, zf - 7.0, px0 + 9.0, py0 + 0.5, zf + 7.0, TRAVERTINE, Kit.STONE, false)
	for cx in [px0 + 0.2, px0 + 8.4]:
		for cz2 in [zf - 6.4, zf + 6.4]:
			k.rod(Vector3(cx, py0 + 0.5, cz2), Vector3(cx, py0 + 5.0, cz2), 0.12, WOOD_D, Kit.TIMBER)
	_span(k, px0 - 0.2, py0 + 5.0, zf - 7.0, px0 + 9.2, py0 + 5.25, zf + 7.0, PURPLE, Kit.CLOTH)
	for q in 4:
		_span(k, px0 + 3.0, py0 + 0.5, zf - 5.5 + q * 3.0, px0 + 5.6, py0 + 1.0, zf - 4.2 + q * 3.0, Color(0.6, 0.2, 0.2), Kit.CLOTH)
	# the carceres: twelve stalls, roofless, closed by gates (Dionysius 3.68; first built 329 BC)
	var zcb := za - cz
	var pitch := (W + 2.0 * (R0 - W * 0.5)) / 12.0
	var xs0 := -pitch * 6.0
	_span(k, xs0 - 1.0, 0.0, zcb - 0.8, -xs0 + 1.0, 7.5, zcb + 0.1, TRAVERTINE if year > -200 else TUFA, Kit.STONE, false)
	for i in range(13):
		var xp := xs0 + pitch * i
		_span(k, xp - pitch * 0.14, 0.0, zcb, xp + pitch * 0.14, 6.2, za, TRAVERTINE if year > -200 else TUFA, Kit.STONE, false)
	for i in 12:
		var xc := xs0 + pitch * (i + 0.5)
		var gw := pitch * 0.72
		k.box(Vector3(xc - gw * 0.25, 0.0, za - 0.1), Vector3(gw * 0.5, 4.2, 0.12), WOOD, Kit.TIMBER, 0.0, true)
		k.box(Vector3(xc + gw * 0.25, 0.0, za - 0.1), Vector3(gw * 0.5, 4.2, 0.12), WOOD, Kit.TIMBER, 0.0, true)
		_span(k, xc - gw * 0.5, 4.2, za - 0.2, xc + gw * 0.5, 4.5, za + 0.05, WOOD_D, Kit.TIMBER)
	_span(k, -pitch * 0.5 - 0.2, 6.2, zcb, pitch * 0.5 + 0.2, 8.2, za, TRAVERTINE, Kit.STONE)   # the stand above the middle gate
	var spawn := look(Vector3(-W * 0.27, EYE, za + 6.0), Vector3(-W * 0.1, 3.0, za + 230.0))
	var seats := {}
	var zk := zc
	# seat viewpoints: row index into the banks, side, position along z, and what the eyes meet
	var rr := func(side: float, row: int, z: float, target: Vector3) -> Transform3D:
		var xx: float = side * (R0 + (rows[row][0] + rows[row][1]) * 0.5)
		return look(Vector3(xx, rows[row][2] + 1.15, z), target)
	seats["carceres"] = rr.call(1.0, 14, za + 30.0, Vector3(0, 3.0, zcb))
	seats["finish"] = rr.call(1.0, 3, zf, Vector3(-W * 0.5, 0.5, zf))
	seats["senate"] = rr.call(-1.0, 2, za + A * 0.32, Vector3(0, 2.0, za + A * 0.4))
	var pxv := px0 + 4.5
	seats["pulvinar"] = look(Vector3(pxv, py0 + 2.2, zf), Vector3(0, 1.5, zf + 60.0))
	seats["turn"] = look(Vector3(_pol(R0 + (rows[8][0] + rows[8][1]) * 0.5, PI * 0.35, zc, 0.0).x, rows[8][2] + 1.15, _pol(R0 + (rows[8][0] + rows[8][1]) * 0.5, PI * 0.35, zc, 0.0).z), Vector3(0, 3.0, zs1 + 3.5))
	var top := _pol(R0 + rows[nrow - 1][1] - 1.0, PI * 0.5, zc, 0.0)
	seats["sphendone"] = look(Vector3(top.x, top_h + 1.3, top.z), Vector3(0, 0.0, -L * 0.2))
	var views := [
		["carceres", seats["carceres"]], ["finish", seats["finish"]], ["pulvinar", seats["pulvinar"]],
		["senate", seats["senate"]], ["turn", seats["turn"]], ["sphendone", seats["sphendone"]],
		["gates", look(Vector3(0, EYE, za + 22.0), Vector3(0, 3.0, zcb))],
		["overview", look(Vector3(W * 2.2, 260.0, L * 0.05), Vector3(0, 0.0, -L * 0.02))],
	]
	var notes := [
		"Dimensions: arena 568 m, width 75 to 87 m, spina 344 m, whole 600 m (Platner-Ashby s.v. Circus Maximus). Read.",
		"Dionysius 3.68 (7 BC) via Platner-Ashby: 621 x 118 m, euripus 10 ft wide and deep, three tiers (lowest stone, two of wood), carceres roofless, rope barrier. Read through P-A, not the original.",
		"Wooden seats and 'fori' in the Republic: Livy 1.35.8-9 and 1.56.2 (the first read, the second read in part).",
		"Carceres first built 329 BC (Livy 8.20.1 via P-A); eggs 174 BC (Livy 41.27.6 via P-A; the primary text could not be fetched) # unverified at source; dolphins 33 BC (Dio 49.43.2, read).",
		"Euripus by Caesar 46 BC (Pliny NH 8.21 via P-A); the pulvinar by Augustus (Mon. Anc. 4.4 via P-A).",
		"The width of the spina (8 m), the position of the finish line and of the pulvinar, the deities of the spina's shrines, the straight line of the carceres: conjecture. # unverified",
		"Orientation: carceres NW, curved end SE, Palatine on the +x side (Platner-Ashby: the Vallis Murcia between Palatine and Aventine).",
	]
	return _pack(k, null, lights, spawn, seats, views, notes, {
		"anchors": {"carceres_line": Vector3(0, 0, za), "finish_line": Vector3(0, 0, zf), "spina_start": Vector3(0, 1.45, zs0), "spina_end": Vector3(0, 1.45, zs1),
			"meta_a": Vector3(0, 1.0, zs0 - 3.5), "meta_b": Vector3(0, 1.0, zs1 + 3.5), "pulvinar": Vector3(px0 + 4.5, py0 + 0.5, zf), "sphendone_centre": Vector3(0, 0, zc)},
		"floor_y": 0.0, "lane_width": pitch, "track_width": W, "arena_length": A})


## A point on a circle of radius r about (0, zc) at angle t (0 = +x, PI/2 = +z), at height y.
static func _pol(r: float, t: float, zc: float, y: float) -> Vector3:
	return Vector3(cos(t) * r, y, zc + sin(t) * r)


static func _arc_pts(cx: float, cz: float, r: float, t0: float, t1: float, n: int, y: float) -> Array:
	var pts: Array = []
	for i in range(n + 1):
		var t := t0 + (t1 - t0) * i / n
		pts.append(Vector3(cx + cos(t) * r, y, cz + sin(t) * r))
	return pts



# ====================================================================================================
#  ARENA: the Forum with wooden stands (Republic), the Colosseum (after AD 80)
# ====================================================================================================

static func _ell(a: float, b: float, t: float, y: float) -> Vector3:
	return Vector3(cos(t) * a, y, sin(t) * b)


## An open two-storey colonnade with wide spacing (Vitruvius 5.1.1-3: wide intercolumniations
## for the shows, bankers' shops below, balconies above, upper columns a quarter smaller),
## along a line from (x0, z) to (x1, z), the shops behind it at `back` metres.
static func _stoa(k: Kit, kc: Kit, x0: float, x1: float, z: float, back: float, col: Color) -> void:
	var ch := 4.8
	var cd := 0.62
	var n := maxi(2, int(round((x1 - x0) / 4.6)))
	var dirz := signf(back)
	for i in range(n + 1):
		var x := x0 + (x1 - x0) * i / n
		_column(k, Vector3(x, 0.0, z), cd, ch, col, Kit.STONE, "tuscan")
		_column(k, Vector3(x, ch + 0.5, z), cd * 0.75, ch * 0.72, col, Kit.STONE, "tuscan")
	_span(k, x0 - cd, ch, z - 0.4, x1 + cd, ch + 0.5, z + 0.4, col, Kit.STONE)
	_span(k, x0 - cd, ch + 0.5 + ch * 0.72, z - 0.4, x1 + cd, ch + 1.2 + ch * 0.72, z + 0.4, col, Kit.STONE)
	# the gallery (maenianum) floor, its balustrade, the shops behind
	_span(k, x0 - cd, ch + 0.2, minf(z, z + back), x1 + cd, ch + 0.5, maxf(z, z + back), WOOD_L, Kit.TIMBER)
	_span(k, x0 - cd, ch + 0.5, z - 0.05, x1 + cd, ch + 1.3, z + 0.05, col.darkened(0.05), Kit.STONE)
	var wz := z + back
	_wall(k, Vector2(x0 - cd, wz), Vector2(x1 + cd, wz), 0.0, ch + 0.5 + ch * 0.72 + 1.2, 0.8, Color(0.88, 0.78, 0.62), Kit.PLASTER,
		_shop_doors(x1 - x0 + 2.0 * cd, 4.6))
	kc.quad(Vector3(x0 - cd, ch + 1.2 + ch * 0.72, z), Vector3(x1 + cd, ch + 1.2 + ch * 0.72, z), Vector3(x1 + cd, ch + 2.6 + ch * 0.72, wz), Vector3(x0 - cd, ch + 2.6 + ch * 0.72, wz), TILE_C, Kit.TILE, Vector3(0, 0, z))
	if dirz != 0.0:
		pass


static func _shop_doors(length: float, pitch: float) -> Array:
	var holes: Array = []
	var n := maxi(1, int(length / pitch))
	for i in n:
		holes.append([length * (i + 0.5) / n, 2.4, 3.0])           # a shop door
		holes.append([length * (i + 0.5) / n, 1.2, 6.8, 5.0])      # an upper window
	return holes


static func _arena(sz: Vector2, year: int, variant: String) -> Dictionary:
	if variant == "colosseum":
		return _colosseum(sz, year)
	return _forum_games(sz, year)


## The Forum Romanum as the place of the gladiator games: the open space sized for them
## (Vitruvius 5.1.1-2: oblong, width two thirds of the length, wide intercolumniations, shops
## and balconies in the porticoes), temporary wooden stands round the sand, the Rostra at
## the west end. The first munus in Rome was at the Forum Boarium in 264 BC (Livy Per. 16,
## # unverified: not read); the games moved to the Forum (Cicero; Festus on the maeniana,
## # unverified: not read).
static func _forum_games(sz: Vector2, year: int) -> Dictionary:
	var L := sz.x
	var W := sz.y
	var k := _kit()
	var kc := _kit()
	var lights: Array = []
	var paving := TUFA.lightened(0.25) if year < -40 else TRAVERTINE
	_span(k, -L * 0.5 - 6.0, -0.5, -W * 0.5 - 8.0, L * 0.5 + 8.0, 0.0, W * 0.5 + 8.0, paving, Kit.STONE, false)
	var rows := 9
	var tread := 0.8
	var rise := 0.46
	var D := rows * tread
	var h0 := 0.7
	var x_w := -L * 0.5 + 16.0          # west end left open (the Rostra, the Comitium)
	var x_e := L * 0.5 - D
	var z_n := -W * 0.5 + D
	var z_s := W * 0.5 - D
	# the sand of the arena
	_floor(k, x_w, z_n, x_e, z_s, 0.04, SAND, Kit.EARTH)
	# stands along the north and south sides and the east end (timber on trestles)
	for s: float in [-1.0, 1.0]:
		var prev := h0
		for r in rows:
			var zi: float = s * (W * 0.5 - D + r * tread) - 0.0
			var zo: float = s * (W * 0.5 - D + (r + 1) * tread)
			var hh := h0 + (r + 1) * rise
			var col := WOOD_L if r % 2 == 0 else WOOD
			var xe := x_e
			k.quad(Vector3(x_w, prev, zi), Vector3(xe, prev, zi), Vector3(xe, hh, zi), Vector3(x_w, hh, zi), col.darkened(0.1), Kit.TIMBER, Vector3((x_w + xe) * 0.5, prev, zi + s * 4.0))
			k.quad(Vector3(x_w, hh, zi), Vector3(xe, hh, zi), Vector3(xe, hh, zo), Vector3(x_w, hh, zo), col, Kit.TIMBER, Vector3((x_w + xe) * 0.5, hh - 1.0, zi))
			prev = hh
		# trestles behind the rows
		var np := int((x_e - x_w) / 5.0)
		for i in range(np + 1):
			var xp := x_w + (x_e - x_w) * i / np
			k.rod(Vector3(xp, 0.0, s * (W * 0.5 - D + 0.3)), Vector3(xp, h0 + 2.0, s * (W * 0.5 - D + 0.3)), 0.1, WOOD_D, Kit.TIMBER)
			k.rod(Vector3(xp, 0.0, s * (W * 0.5 - 0.5)), Vector3(xp, h0 + rows * rise, s * (W * 0.5 - 0.5)), 0.1, WOOD_D, Kit.TIMBER)
		# the fence round the sand: posts and rails
		for i in range(np * 2 + 1):
			var xp := x_w + (x_e - x_w) * i / (np * 2)
			k.rod(Vector3(xp, 0.0, s * (W * 0.5 - D - 0.2)), Vector3(xp, 1.5, s * (W * 0.5 - D - 0.2)), 0.07, WOOD_D, Kit.TIMBER)
		_span(k, x_w, 1.0, s * (W * 0.5 - D - 0.2) - 0.05, x_e, 1.12, s * (W * 0.5 - D - 0.2) + 0.05, WOOD_D, Kit.TIMBER)
	var prev2 := h0
	for r in rows:
		var xi := x_e + r * tread
		var xo := x_e + (r + 1) * tread
		var hh := h0 + (r + 1) * rise
		var col2 := WOOD_L if r % 2 == 0 else WOOD
		k.quad(Vector3(xi, prev2, z_n), Vector3(xi, prev2, z_s), Vector3(xi, hh, z_s), Vector3(xi, hh, z_n), col2.darkened(0.1), Kit.TIMBER, Vector3(xi + 4.0, prev2, 0))
		k.quad(Vector3(xi, hh, z_n), Vector3(xo, hh, z_n), Vector3(xo, hh, z_s), Vector3(xi, hh, z_s), col2, Kit.TIMBER, Vector3(xi, hh - 1.0, 0))
		prev2 = hh
	for i in range(0, 9):
		var zp := z_n + (z_s - z_n) * i / 8.0
		k.rod(Vector3(x_e, 0.0, zp), Vector3(x_e, h0 + 2.0, zp), 0.1, WOOD_D, Kit.TIMBER)
	# the porticoes: shops below, balconies above (north, south, east)
	var col_s := Color(0.9, 0.84, 0.72)
	_stoa(k, kc, -L * 0.5 + 18.0, L * 0.5, -W * 0.5, -7.0, col_s)
	_stoa(k, kc, -L * 0.5 + 18.0, L * 0.5, W * 0.5, 7.0, col_s)
	# the Rostra at the west end: a platform with the beaks of ships
	var rx := -L * 0.5 + 6.0
	_span(k, rx - 2.0, 0.0, -7.0, rx + 2.0, 3.4, 7.0, TUFA, Kit.STONE, false)
	_span(k, rx - 2.3, 3.4, -7.3, rx + 2.3, 3.7, 7.3, TUFA.lightened(0.1), Kit.STONE, false)
	for i in range(6):
		var zz := -5.5 + i * 2.2
		k.rod(Vector3(rx + 2.0, 2.2, zz), Vector3(rx + 3.6, 2.9, zz), 0.16, BRONZE, Kit.GOLD)
	var spawn := look(Vector3(rx + 9.0, EYE, 0.0), Vector3(x_e, 3.0, 0.0))
	var seat_row := func(side: float, row: int, x: float, target: Vector3) -> Transform3D:
		return look(Vector3(x, h0 + (row + 1) * rise + 1.1, side * (W * 0.5 - D + (row + 0.5) * tread)), target)
	var seats := {
		"stand_north": seat_row.call(-1.0, 4, 0.0, Vector3(0, 0.5, 0.0)),
		"stand_south": seat_row.call(1.0, 4, 0.0, Vector3(0, 0.5, 0.0)),
		"front": seat_row.call(1.0, 0, L * 0.1, Vector3(0, 0.5, -W * 0.2)),
		"top": seat_row.call(-1.0, 8, -L * 0.1, Vector3(0, 0.5, W * 0.1)),
		"balcony": look(Vector3(0, 5.2 + 1.5, -W * 0.5 - 2.0), Vector3(0, 0.5, W * 0.15)),
	}
	var views := [
		["stand", seats["stand_south"]], ["balcony", seats["balcony"]], ["front", seats["front"]],
		["overview", look(Vector3(L * 0.15, W * 1.15, W * 1.0), Vector3(-L * 0.05, 0.0, 0.0))],
	]
	var notes := [
		"The Forum sized for the shows: oblong, width two thirds of the length, wide intercolumniations, shops with upper rooms in the porticoes: Vitruvius 5.1.1-3. Read.",
		"Gladiator shows in the Forum, 'the ancient custom of Italian cities': Vitruvius 5.1.1. Read. The first munus, 264 BC at the Forum Boarium: Livy Per. 16 # unverified (not read).",
		"Temporary timber stands, the maeniana (balconies) of the porticoes: Festus s.v. maeniana, Cicero # unverified (not read); the shape (rows, trestles, fence) is conjecture.",
		"The Rostra at the west end (Platner-Ashby s.v. Rostra, not read) # unverified; its size here is a guess.",
		"Size defaults 110 x 55 m: conjecture; give the real Forum floor in the monument record.",
	]
	return _pack(k, kc, lights, spawn, seats, views, notes, {"anchors": {"sand_centre": Vector3((x_w + x_e) * 0.5, 0.04, 0.0), "rostra": Vector3(rx, 3.7, 0.0), "entrance": Vector3(x_w, 0, 0)}, "floor_y": 0.0, "arena_size": Vector2(x_e - x_w, z_s - z_n)})


## The Flavian amphitheatre from inside (Platner-Ashby s.v. Amphitheatrum Flavium): the arena an
## ellipse (83 x 48 m by the modern survey, P-A gives 86 x 54), its wooden floor on lofty
## substructures, a fence and a narrow marble passage, then the podium about 4 m above the arena
## with the marble chairs and the bronze balustrade, the cavea in the maenianum primum (about
## 20 rows) and the maenianum secundum (about 16) divided by a praecinctio, a wall 5 m high with a
## Corinthian colonnade and a flat roof above the last rows, wooden seats for women behind it,
## the awning (velarium) on masts. The imperial box on the podium at the north end of the minor
## axis, the prefect's opposite; entrances into the arena at the ends of the major axis.
## The hypogeum with its walls parallel to the major axis (5.5-6 m high) is built from AD 81
## (it is Domitian's, P-A: "additions on the inside"); before that, a plain wooden floor.
static func _colosseum(sz: Vector2, year: int) -> Dictionary:
	var a := sz.x * 0.5
	var b := sz.y * 0.5
	var k := _kit()
	var kc := _kit()
	var lights: Array = []
	var N := 96
	var per := 20
	var nrow := 36
	var tread := 0.78
	var rise := 0.43
	var walk := 3.2
	var lift := 2.2
	var h0 := 4.0
	var d0 := 4.4        # podium platform depth beyond the arena edge
	var col := TRAVERTINE
	var marble := MARBLE
	# the arena floor (in the cover mesh: a cutaway shows what is under it) and the ring wall
	var sand := SAND
	for i in N:
		var t0 := TAU * i / N
		var t1 := TAU * (i + 1) / N
		kc.tri(Vector3(0, 0.02, 0), _ell(a + 0.6, b + 0.6, t0, 0.02), _ell(a + 0.6, b + 0.6, t1, 0.02), sand, Kit.EARTH, Vector3(0, -2, 0))
		# the podium wall: its face towards the arena, then the platform behind
		k.quad(_ell(a, b, t0, -6.0 if year >= 81 else 0.0), _ell(a, b, t1, -6.0 if year >= 81 else 0.0), _ell(a, b, t1, h0), _ell(a, b, t0, h0), col, Kit.STONE, _ell(a + 6.0, b + 6.0, (t0 + t1) * 0.5, 1.0))
		k.quad(_ell(a, b, t0, h0), _ell(a + d0, b + d0, t0, h0), _ell(a + d0, b + d0, t1, h0), _ell(a, b, t1, h0), marble, Kit.PAINT, _ell(a, b, (t0 + t1) * 0.5, h0 - 1.0))
		# the bronze balustrade along the edge
		k.quad(_ell(a + 0.1, b + 0.1, t0, h0), _ell(a + 0.1, b + 0.1, t1, h0), _ell(a + 0.1, b + 0.1, t1, h0 + 0.9), _ell(a + 0.1, b + 0.1, t0, h0 + 0.9), BRONZE, Kit.GOLD, _ell(a + 6.0, b + 6.0, (t0 + t1) * 0.5, 1.0))
	# the stepped cavea
	var rows: Array = []
	for r in nrow:
		rows.append(_row(r, per, tread, rise, walk, lift, h0))
	for r in nrow:
		var dd0: float = d0 + rows[r][0]
		var dd1: float = d0 + rows[r][1]
		var hh: float = rows[r][2]
		var prev: float = h0 if r == 0 else rows[r - 1][2]
		var tint := (r / 4) % 2
		var cr := marble if tint == 0 else marble.darkened(0.08)
		if r > 0 and r % per == 0:
			var pd: float = d0 + rows[r - 1][1]
			var py: float = rows[r - 1][2]
			for i in N:
				var t0 := TAU * i / N
				var t1 := TAU * (i + 1) / N
				k.quad(_ell(a + pd, b + pd, t0, py), _ell(a + dd0, b + dd0, t0, py), _ell(a + dd0, b + dd0, t1, py), _ell(a + pd, b + pd, t1, py), TRAVERTINE.darkened(0.05), Kit.STONE, _ell(a + pd, b + pd, (t0 + t1) * 0.5, py - 1.0))
		for i in N:
			var t0 := TAU * i / N
			var t1 := TAU * (i + 1) / N
			var tm := (t0 + t1) * 0.5
			var far := _ell(a + dd1 + 6.0, b + dd1 + 6.0, tm, prev)
			k.quad(_ell(a + dd0, b + dd0, t0, prev), _ell(a + dd0, b + dd0, t1, prev), _ell(a + dd0, b + dd0, t1, hh), _ell(a + dd0, b + dd0, t0, hh), cr.darkened(0.12), Kit.STONE, far)
			k.quad(_ell(a + dd0, b + dd0, t0, hh), _ell(a + dd1, b + dd1, t0, hh), _ell(a + dd1, b + dd1, t1, hh), _ell(a + dd0, b + dd0, t1, hh), cr, Kit.STONE, _ell(a + dd0, b + dd0, tm, hh - 1.0))
	# aisles between the wedges (cunei): darker steps every 8 segments, vomitoria at their feet
	for i in range(0, N, 8):
		var t0 := TAU * i / N
		var t1 := TAU * (i + 0.6) / N
		for r in nrow:
			var dd0: float = d0 + rows[r][0]
			var dd1: float = d0 + rows[r][1]
			var hh: float = rows[r][2]
			k.quad(_ell(a + dd0, b + dd0, t0, hh + 0.01), _ell(a + dd1, b + dd1, t0, hh + 0.01), _ell(a + dd1, b + dd1, t1, hh + 0.01), _ell(a + dd0, b + dd0, t1, hh + 0.01), Color(0.62, 0.58, 0.52), Kit.STONE, _ell(a + dd0, b + dd0, t0, hh - 1.0))
	# the wall above the secundum with the colonnade and its flat roof
	var last_d: float = d0 + rows[nrow - 1][1]
	var top_h: float = rows[nrow - 1][2]
	var wh := 5.0
	for i in N:
		var t0 := TAU * i / N
		var t1 := TAU * (i + 1) / N
		var rb := last_d + 0.4
		k.quad(_ell(a + rb, b + rb, t0, top_h), _ell(a + rb, b + rb, t1, top_h), _ell(a + rb, b + rb, t1, top_h + wh), _ell(a + rb, b + rb, t0, top_h + wh), Color(0.84, 0.78, 0.66), Kit.PLASTER, _ell(a + rb + 6.0, b + rb + 6.0, (t0 + t1) * 0.5, top_h))
		# roof slab over the colonnade walk
		var r0 := rb - 3.6
		kc.quad(_ell(a + r0, b + r0, t0, top_h + wh + 0.4), _ell(a + r0, b + r0, t1, top_h + wh + 0.4), _ell(a + rb + 0.4, b + rb + 0.4, t1, top_h + wh + 0.4), _ell(a + rb + 0.4, b + rb + 0.4, t0, top_h + wh + 0.4), TILE_C, Kit.TILE, _ell(a + r0, b + r0, (t0 + t1) * 0.5, top_h))
	var ncol := 72
	for i in ncol:
		var t := TAU * (i + 0.5) / ncol
		var rc := last_d - 2.8
		var p := _ell(a + rc, b + rc, t, top_h)
		k.cylinder(p, 0.32, wh + 0.2, Color(0.62, 0.52, 0.48), Kit.PAINT, 8)     # cipollino and granite columns
		k.box(p + Vector3(0, wh + 0.2, 0), Vector3(0.9, 0.35, 0.9), marble, Kit.STONE)
	# awning (velarium): cloth panels from the colonnade roof inwards, on masts
	for i in N:
		var t0 := TAU * i / N
		var t1 := TAU * (i + 1) / N
		var c := Color(0.92, 0.88, 0.76) if (i / 3) % 2 == 0 else Color(0.74, 0.26, 0.2)
		var rin := last_d - 3.6 - 0.45 * (last_d - 3.6)
		kc.quad(_ell(a + rin, b + rin, t0, top_h + wh + 2.0), _ell(a + rin, b + rin, t1, top_h + wh + 2.0), _ell(a + last_d - 3.6, b + last_d - 3.6, t1, top_h + wh + 4.2), _ell(a + last_d - 3.6, b + last_d - 3.6, t0, top_h + wh + 4.2), c, Kit.CLOTH, Vector3(0, top_h - 5.0, 0))
	for i in range(0, ncol, 2):
		var t := TAU * (i + 0.5) / ncol
		var rc2 := last_d + 0.3
		var p2 := _ell(a + rc2, b + rc2, t, top_h + wh + 0.4)
		kc.rod(p2, p2 + Vector3(0, 6.0, 0), 0.12, WOOD_D, Kit.TIMBER)
	# the imperial box (north end of the minor axis, +z here) and the prefect's opposite
	for s: float in [-1.0, 1.0]:
		var zc := s * (b + 1.6)
		_span(k, -5.0, h0, zc - 1.6, 5.0, h0 + 0.3, zc + 1.6, TRAVERTINE, Kit.STONE, false)
		for cx in [-5.0, 5.0]:
			k.rod(Vector3(cx, h0 + 0.3, zc), Vector3(cx, h0 + 4.5, zc), 0.14, WOOD_D, Kit.TIMBER)
		_span(kc, -5.4, h0 + 4.5, zc - 2.0, 5.4, h0 + 4.7, zc + 2.0, PURPLE if s > 0 else Color(0.5, 0.2, 0.2), Kit.CLOTH)
		k.box(Vector3(0, h0 + 0.3, zc), Vector3(1.2, 0.8, 1.0), GILT, Kit.GOLD, 0.0, true)   # the emperor's chair
	# the marble chairs of the podium, here as a row of blocks
	var nchair := 54
	for i in nchair:
		var t := TAU * (i + 0.5) / nchair
		if absf(sin(t)) > 0.97 and absf(cos(t)) < 0.2:
			continue
		var p := _ell(a + 2.4, b + 2.4, t, h0)
		k.box(p, Vector3(0.7, 0.9, 0.7), marble, Kit.STONE, -t, true)
	# the doors at the ends of the major axis, into the arena
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * (a - 0.1), 0.0, 0.0), Vector3(0.4, 3.6, 4.2), Color(0.08, 0.06, 0.05), Kit.DARK, 0.0, true)
	# the hypogeum under the floor (from AD 81)
	if year >= 81:
		_span(k, -a * 0.97, -6.0, -b * 0.95, a * 0.97, -5.9, b * 0.95, Color(0.30, 0.24, 0.20), Kit.EARTH, false)
		var brick := Color(0.82, 0.55, 0.40)
		for zz in [-10.0, -5.0, 0.0, 5.0, 10.0]:
			var half: float = a * sqrt(maxf(0.0, 1.0 - (zz / b) * (zz / b))) * 0.94
			for seg in 3:
				var xa: float = -half + (2.0 * half) * seg / 3.0 + 3.0
				var xb: float = -half + (2.0 * half) * (seg + 1) / 3.0 - 3.0
				_span(k, xa, -6.0, zz - 0.5, xb, -0.3, zz + 0.5, brick, Kit.BRICK)
		for i in 24:
			var t0 := TAU * i / 24.0
			var t1 := TAU * (i + 1) / 24.0
			k.quad(_ell(a - 2.0, b - 2.0, t0, -6.0), _ell(a - 2.0, b - 2.0, t1, -6.0), _ell(a - 2.0, b - 2.0, t1, -0.3), _ell(a - 2.0, b - 2.0, t0, -0.3), brick, Kit.BRICK, Vector3(0, -3.0, 0))
		for xx in [-12.0, 12.0, -26.0, 26.0]:
			_span(k, xx - 0.5, -6.0, -b * 0.9, xx + 0.5, -0.3, -b * 0.3, brick, Kit.BRICK)
			_span(k, xx - 0.5, -6.0, b * 0.3, xx + 0.5, -0.3, b * 0.9, brick, Kit.BRICK)
			k.box(Vector3(xx + 3.0, -6.0, 2.0), Vector3(1.8, 2.2, 1.8), WOOD, Kit.TIMBER, 0.0, true)   # a lift cage
			lights.append({"pos": Vector3(xx, -3.5, 0.0), "colour": Color(1.0, 0.62, 0.3), "energy": 1.6, "range": 9.0, "kind": "torch"})
	var spawn := look(Vector3(-a + 4.0, EYE, 0.0), Vector3(a, 8.0, 0.0))
	var seat_at := func(row: int, t: float, tgt: Vector3) -> Transform3D:
		var dd: float = d0 + (rows[row][0] + rows[row][1]) * 0.5
		var hh: float = rows[row][2] + 1.15
		var p := _ell(a + dd, b + dd, t, hh)
		return look(p, tgt)
	var seats := {
		"podium": look(Vector3(0, h0 + 1.7, b + 1.6), Vector3(0, 0.0, -b * 0.3)),
		"primum": seat_at.call(8, PI * 0.25, Vector3(0, 0, 0)),
		"secundum": seat_at.call(28, PI * 0.9, Vector3(0, 0, 0)),
		"summum": look(Vector3(_ell(a + last_d - 2.0, b + last_d - 2.0, PI * 1.5, top_h + wh - 1.5)), Vector3(0, 0, 0)),
	}
	var views := [
		["podium", seats["podium"]], ["primum", seats["primum"]], ["secundum", seats["secundum"]],
		["summum", seats["summum"]],
		["overview", look(Vector3(a * 1.1, a * 1.5, b * 2.0), Vector3(0, 6.0, 0))],
		["cutaway_hypogeum", look(Vector3(a * 0.5, 28.0, b * 1.1), Vector3(0, -3.0, 0))],
	]
	var notes := [
		"Arena 83 x 48 m (modern survey; Platner-Ashby gives 86 x 54), podium about 4 m above it with a bronze balustrade and marble chairs, maenianum primum about 20 rows and secundum about 16 divided by a praecinctio, wall 5 m high with a Corinthian colonnade of cipollino and granite, flat roof, wooden seats of the maenianum summum behind, awning on masts, imperial box at the north end of the minor axis: Platner-Ashby s.v. Amphitheatrum Flavium. Read.",
		"Substructures 5.5 to 6.08 m high, walls parallel to the major axis, passages on the axes: P-A. Read. The hypogeum is dated from Domitian (AD 81) here; the P-A text says only 'additions on the inside'. # unverified",
		"Row depth and height, the velarium's shape, the chairs' spacing, the lift cages: conjecture.",
		"Built from AD 80 (Suet. Titus 7; Dio 66.25 via P-A); exists in the campaign only if the Empire data (monuments_empire) has it.",
	]
	return _pack(k, kc, lights, spawn, seats, views, notes, {
		"anchors": {"arena_centre": Vector3(0, 0, 0), "imperial_box": Vector3(0, h0 + 0.3, b + 1.6), "door_west": Vector3(-a, 0, 0), "door_east": Vector3(a, 0, 0)},
		"floor_y": 0.0, "arena_size": Vector2(sz.x, sz.y), "no_ground": true})



# ====================================================================================================
#  THEATRE (Pompey's, 55 BC)
# ====================================================================================================

## A Roman theatre by Vitruvius 5.6: the orchestra a circle with four triangles inscribed, seven
## stairways on the cavea, the scene twice the diameter of the orchestra, the stage no higher
## than five feet, seats 20-22 digits high and 2 to 2.5 feet deep, columns of the scaenae frons a
## quarter of the orchestra diameter, three doors (the regia and the two hospitalia). Pompey's
## had the temple of Venus Victrix at the top of the cavea, the seats its steps (Tertullian De
## spect. 10, Gellius 10.1.7, Pliny NH 8.20, via Platner-Ashby s.v. Theatrum Pompei), shrines
## of Honos, Virtus and Felicitas (Fasti Allifani, ib.), the plan taken from Mytilene (Plut.
## Pompey 42, read). Stage at -z, cavea rising toward +z; `size.x` is the outer diameter.
static func _theatre(sz: Vector2, year: int, variant: String) -> Dictionary:
	var R := sz.x * 0.5
	var k := _kit()
	var kc := _kit()
	var lights: Array = []
	var pompey := variant == "pompey"
	var ro := R * 0.27                         # orchestra radius
	var tread := 0.65
	var rise := 0.40
	var walk := 2.5
	var lift := 1.2
	var nrow := int((R - 3.0 - ro - 2.0 * walk) / tread)
	var per := int(ceil(nrow / 3.0))
	var marble := TRAVERTINE
	var N := 72
	var rows: Array = []
	for r in nrow:
		rows.append(_row(r, per, tread, rise, walk, lift, 0.0))
	# orchestra floor, senators' seats
	for i in 18:
		var t0 := PI * i / 18.0
		var t1 := PI * (i + 1) / 18.0
		k.tri(Vector3(0, 0, 0), _pol(ro, t0, 0.0, 0.0), _pol(ro, t1, 0.0, 0.0), Color(0.78, 0.72, 0.62), Kit.PAINT, Vector3(0, -2, 0))
	for q in 3:
		var rq := ro * (0.9 - q * 0.1)
		var nq := int(PI * rq / 1.0)
		for i in range(1, nq):
			var t := PI * i / nq
			var p := _pol(rq, t, 0.0, 0.0)
			k.box(p, Vector3(0.5, 0.42, 0.45), WOOD_L, Kit.TIMBER, -t - PI * 0.5, true)
	# the cavea
	for r in nrow:
		var d0: float = ro + rows[r][0]
		var d1: float = ro + rows[r][1]
		var hh: float = rows[r][2]
		var prev: float = 0.0 if r == 0 else rows[r - 1][2]
		var cr := marble if (r / 3) % 2 == 0 else marble.darkened(0.07)
		if r > 0 and r % per == 0:
			var pd: float = ro + rows[r - 1][1]
			var py: float = rows[r - 1][2]
			for i in N:
				var t0 := PI * i / N
				var t1 := PI * (i + 1) / N
				k.quad(_pol(pd, t0, 0.0, py), _pol(d0, t0, 0.0, py), _pol(d0, t1, 0.0, py), _pol(pd, t1, 0.0, py), TRAVERTINE.darkened(0.06), Kit.STONE, _pol(pd, (t0 + t1) * 0.5, 0.0, py - 1.0))
		for i in N:
			var t0 := PI * i / N
			var t1 := PI * (i + 1) / N
			var tm := (t0 + t1) * 0.5
			k.quad(_pol(d0, t0, 0.0, prev), _pol(d0, t1, 0.0, prev), _pol(d0, t1, 0.0, hh), _pol(d0, t0, 0.0, hh), cr.darkened(0.1), Kit.STONE, _pol(d1 + 6.0, tm, 0.0, prev))
			k.quad(_pol(d0, t0, 0.0, hh), _pol(d1, t0, 0.0, hh), _pol(d1, t1, 0.0, hh), _pol(d0, t1, 0.0, hh), cr, Kit.STONE, _pol(d0, tm, 0.0, hh - 1.0))
		# the ends of the rows, against the side passages
		for sgn: float in [0.0, PI]:
			var sx := 1.0 if sgn == 0.0 else -1.0
			k.quad(Vector3(sx * d0, 0, 0), Vector3(sx * d1, 0, 0), Vector3(sx * d1, hh, 0), Vector3(sx * d0, hh, 0), TRAVERTINE.darkened(0.12), Kit.STONE, Vector3(sx * (d0 + d1) * 0.5, hh * 0.5, 5.0))
	# stairways: seven in the lowest tier, alternating above (Vitruvius 5.6.1-3)
	for g in 3:
		var angles: Array = []
		for j in 7:
			if g % 2 == 0:
				angles.append(PI * j / 6.0)
			else:
				if j < 6:
					angles.append(PI * (j + 0.5) / 6.0)
		for ang: float in angles:
			if ang < 0.02 or ang > PI - 0.02:
				continue
			for r in range(g * per, mini((g + 1) * per, nrow)):
				var dd0: float = ro + rows[r][0]
				var dd1: float = ro + rows[r][1]
				var hh: float = rows[r][2]
				var hw := 0.9 / (dd0 + 0.1)
				k.quad(_pol(dd0, ang - hw, 0.0, hh + 0.01), _pol(dd1, ang - hw, 0.0, hh + 0.01), _pol(dd1, ang + hw, 0.0, hh + 0.01), _pol(dd0, ang + hw, 0.0, hh + 0.01), Color(0.58, 0.54, 0.48), Kit.STONE, _pol(dd0, ang, 0.0, hh - 1.0))
	var r_top: float = ro + rows[nrow - 1][1]
	var top_h: float = rows[nrow - 1][2]
	# back wall and the colonnade of the top, its roof level with the top of the scene (5.6.4)
	for i in N:
		var t0 := PI * i / N
		var t1 := PI * (i + 1) / N
		var rb := r_top + 0.5
		if pompey and absf((t0 + t1) * 0.5 - PI * 0.5) < 0.22:
			continue    # the way up to the temple
		k.quad(_pol(rb, t0, 0.0, top_h), _pol(rb, t1, 0.0, top_h), _pol(rb, t1, 0.0, top_h + 7.0), _pol(rb, t0, 0.0, top_h + 7.0), Color(0.88, 0.80, 0.66), Kit.PLASTER, _pol(rb - 6.0, (t0 + t1) * 0.5, 0.0, top_h))
		kc.quad(_pol(rb - 3.5, t0, 0.0, top_h + 7.4), _pol(rb - 3.5, t1, 0.0, top_h + 7.4), _pol(rb + 0.6, t1, 0.0, top_h + 7.4), _pol(rb + 0.6, t0, 0.0, top_h + 7.4), TILE_C, Kit.TILE, _pol(rb - 3.5, (t0 + t1) * 0.5, 0.0, top_h))
	var ncol := int(PI * r_top / 5.0)
	for i in range(1, ncol):
		var t := PI * i / ncol
		if pompey and absf(t - PI * 0.5) < 0.2:
			continue
		_column(k, _pol(r_top - 3.2, t, 0.0, top_h), 0.8, 7.0, marble, Kit.STONE, "corinthian")
	# the stage (no higher than 5 ft), its front with niches, the scaenae frons
	var sh := 1.4
	var zf0 := -ro * 0.5                       # the face of the scene
	var half := ro * 2.0                       # the scene is twice the orchestra's diameter long
	_span(k, -half, 0.0, zf0 - 2.0, half, sh, 0.0, WOOD, Kit.TIMBER, false)
	_floor(k, -half, zf0 - 2.0, half, 0.0, sh + 0.005, WOOD_L, Kit.TIMBER)
	for i in range(-8, 9):
		var nx := i * half / 8.5
		k.box(Vector3(nx, 0.0, 0.02), Vector3(half / 8.5 * 0.55, sh * 0.8, 0.3), BLACK_P, Kit.DARK, 0.0, true)   # the niches of the pulpitum front
	var pod := ro * 2.0 / 12.0                 # the podium: a twelfth of the orchestra's diameter
	var c1 := ro * 2.0 / 4.0                   # columns: a quarter of the diameter
	var a1 := c1 * 0.2
	var pod2 := pod * 0.5
	var c2 := c1 * 0.75
	var a2 := c2 * 0.2
	var pod3 := pod2 * 0.5
	var c3 := c2 * 0.75
	var zw := zf0 - 4.5                        # the back wall of the scene
	var y1 := sh
	var y2 := y1 + pod + c1 + a1
	var y3 := y2 + pod2 + c2 + a2
	var ytop := y3 + pod3 + c3 + 1.0
	var wallc := Color(0.84, 0.66, 0.52)
	_span(k, -half, 0.0, zw - 1.0, half, ytop, zw + 0.5, wallc, Kit.PLASTER, false)
	var nbay := 17
	var bw := 2.0 * half / nbay
	for tier in 3:
		var yb: float = [y1, y2, y3][tier]
		var podh: float = [pod, pod2, pod3][tier]
		var ch: float = [c1, c2, c3][tier]
		var ah: float = [a1, a2, a2 * 0.8][tier]
		var zc := zf0 - 1.0 - tier * 0.4
		_span(k, -half - 0.5, yb, zc - 0.8, half + 0.5, yb + podh, zc + 0.8, marble, Kit.STONE, tier > 0)
		for i in range(nbay + 1):
			var x := -half + bw * i
			var colr := marble if tier != 1 else Color(0.78, 0.55, 0.45)
			_column(k, Vector3(x, yb + podh, zc), ch * 0.1, ch, colr, Kit.PAINT, "corinthian")
		_span(k, -half - 0.5, yb + podh + ch, zc - 0.7, half + 0.5, yb + podh + ch + ah, zc + 0.7, marble, Kit.STONE)
		# statues between the columns
		for i in range(nbay):
			var x := -half + bw * (i + 0.5)
			_figure(k, Vector3(x, yb + podh, zc + 0.1 - 0.0), minf(ch * 0.45, 3.2), marble.darkened(0.04), marble, 0.0, false, Kit.STONE)
	# the three doors: regia in the middle, the hospitalia on either side (5.6.3, 5.6.8)
	var door_z := zw + 0.55
	k.box(Vector3(0, y1, door_z), Vector3(5.0, 6.0, 0.15), Color(0.10, 0.07, 0.05), Kit.DARK, 0.0, true)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * ro * 0.5, y1, door_z), Vector3(3.2, 4.4, 0.15), Color(0.10, 0.07, 0.05), Kit.DARK, 0.0, true)
	if year >= -32:
		k.cylinder(Vector3(0, y1, zf0 - 0.5), 0.9, 1.4, marble, Kit.STONE, 8)
		_figure(k, Vector3(0, y1 + 1.4, zf0 - 0.5), 2.8, marble, marble, PI, false, Kit.STONE)    # Pompey's statue
	# the stage roof, sloping down toward the audience
	kc.quad(Vector3(-half - 1.0, ytop + 1.5, zw - 1.0), Vector3(half + 1.0, ytop + 1.5, zw - 1.0), Vector3(half + 1.0, y2 + pod2 + c2 * 0.6, zf0 + 1.0), Vector3(-half - 1.0, y2 + pod2 + c2 * 0.6, zf0 + 1.0), TILE_C, Kit.TILE, Vector3(0, -3, zw))
	# the temple of Venus Victrix at the top of the cavea, facing the stage, and the shrines
	var views: Array = []
	var seats := {}
	var tp := 1.6
	if pompey:
		var tz0 := r_top + 0.8
		var tw := 20.0
		var td := 15.0
		_span(k, -tw * 0.5, top_h, tz0, tw * 0.5, top_h + tp, tz0 + td, marble, Kit.STONE, false)
		for i in 8:
			_span(k, -tw * 0.3, top_h + tp * (7 - i) / 8.0, tz0 - (i + 1) * 0.4, tw * 0.3, top_h + tp * (8 - i) / 8.0, tz0 + 0.01, marble, Kit.STONE, false)
		for i in 7:
			var cx := -tw * 0.5 + 1.2 + (tw - 2.4) * i / 6.0
			_column(k, Vector3(cx, top_h + tp, tz0 + 2.0), 1.0, 8.4, marble, Kit.STONE, "corinthian")
		_span(k, -tw * 0.5, top_h + tp + 8.4, tz0 + 1.2, tw * 0.5, top_h + tp + 9.6, tz0 + 2.8, marble, Kit.STONE)
		_wall(k, Vector2(-tw * 0.5 + 1.0, tz0 + 6.0), Vector2(tw * 0.5 - 1.0, tz0 + 6.0), top_h + tp, 8.4, 0.8, Color(0.9, 0.82, 0.68), Kit.PLASTER, [[tw * 0.5 - 1.0, 3.2, 6.0]])
		_wall(k, Vector2(-tw * 0.5 + 1.0, tz0 + td - 1.0), Vector2(tw * 0.5 - 1.0, tz0 + td - 1.0), top_h + tp, 8.4, 0.8, Color(0.9, 0.82, 0.68), Kit.PLASTER)
		for sx: float in [-1.0, 1.0]:
			_wall(k, Vector2(sx * (tw * 0.5 - 1.0), tz0 + 6.0), Vector2(sx * (tw * 0.5 - 1.0), tz0 + td - 1.0), top_h + tp, 8.4, 0.8, Color(0.9, 0.82, 0.68), Kit.PLASTER)
		_figure(k, Vector3(0, top_h + tp, tz0 + 10.0), 4.2, GILT, Color(0.9, 0.82, 0.72), PI, false, Kit.GOLD)   # Venus Victrix
		kc.gable_roof(Vector3(0, top_h + tp + 9.6, tz0 + td * 0.5 + 0.8), td + 0.6, tw, 3.4, 0.5, 0.3, TILE_C, Kit.TILE, Color(0.86, 0.66, 0.5), Kit.PLASTER, PI / 2.0)
		for q in 3:   # the shrines of Honos, Virtus, Felicitas: places unknown
			var t: float = PI * [0.28, 0.72, 0.84][q]
			var p := _pol(r_top - 1.4, t, 0.0, top_h)
			k.box(p, Vector3(2.6, 3.2, 2.2), Color(0.9, 0.82, 0.68), Kit.PLASTER, -t - PI * 0.5, true)
			k.box(p + Vector3(0, 3.2, 0), Vector3(3.0, 0.3, 2.6), TILE_C, Kit.TILE, -t - PI * 0.5, true)
		seats["temple"] = look(Vector3(0, top_h + tp + EYE, tz0 + 1.0), Vector3(0, y1 + 3.0, zf0))
	var rr := func(row: int, t: float) -> Transform3D:
		var d: float = ro + (rows[row][0] + rows[row][1]) * 0.5
		var p := _pol(d, t, 0.0, rows[row][2] + 1.15)
		return look(p, Vector3(0, sh + 2.5, zf0 - 1.0))
	seats["ima"] = rr.call(4, PI * 0.5)
	seats["media"] = rr.call(per + 8, PI * 0.5)
	seats["summa"] = rr.call(nrow - 6, PI * 0.5)
	seats["side"] = rr.call(per - 2, PI * 0.12)
	seats["orchestra"] = look(Vector3(0, EYE, ro * 0.55), Vector3(0, sh + 3.0, zf0))
	var spawn: Transform3D = seats["orchestra"]
	views = [["ima", seats["ima"]], ["media", seats["media"]], ["summa", seats["summa"]], ["side", seats["side"]],
		["stage", look(Vector3(0, sh + EYE, zf0 + 1.0), Vector3(0, top_h * 0.6, ro * 2.0))],
		["overview", look(Vector3(R * 0.25, R * 1.15, R * 1.55), Vector3(0, top_h * 0.2, -R * 0.05))]]
	if pompey:
		views.append(["temple", seats["temple"]])
	var notes := [
		"Layout: Vitruvius 5.6.1-8 (four triangles in the orchestra circle, seven stairways, stage <= 5 ft, scene twice the orchestra's diameter, order heights 1/4 of the diameter and 3/4 above, doors regia and hospitalia, seats 20-22 digits high). Read.",
		"Temple of Venus Victrix at the top of the cavea as a pretext for permanent seating (Tertullian De spect. 10, Gellius 10.1.7, Pliny NH 8.20); shrines of Honos, Virtus, Felicitas (Fasti Allifani); plan from Mytilene (Plutarch Pompey 42). Platner-Ashby read; Tertullian, Gellius not read. The temple's size and order, and the places of the three shrines, are conjecture. # unverified",
		"Pompey's statue opposite the regia, put there by Augustus (Suet. Aug. 31 via P-A). Read through P-A. Date gate -32 is loose.",
		"The statues of the fourteen nations (Pliny NH 36.41) stood in the portico, not the scene; the statues between the scene's columns here are generic.",
		"Orchestra radius is a guess (27 percent of the cavea radius); Pompey's theatre is given as about 150 m across in monuments.json.",
	]
	return _pack(k, kc, lights, spawn, seats, views, notes, {
		"anchors": {"orchestra": Vector3(0, 0, 0), "stage": Vector3(0, sh, zf0 * 0.5), "regia": Vector3(0, y1, door_z), "temple": Vector3(0, top_h + tp, r_top + 10.0)},
		"floor_y": 0.0, "stage_height": sh})



# ====================================================================================================
#  DOMUS (atrium house, Vitruvius 6.3)
# ====================================================================================================

## A wall decoration along the inner face of a wall from a to b (plan), inward normal n, from y0 up
## `h`: the First style (blocks of coloured stucco in relief, imitating masonry; before about 80 BC),
## the Second style (painted architecture: a dado, panels between painted pilasters, a cornice and a
## vista; about 80 to 15 BC), later a plainer panelled style. The dating of the styles is the modern
## (Mau) convention, not an ancient source. # unverified
static func _paint_wall(k: Kit, a: Vector2, b: Vector2, n: Vector2, y0: float, h: float, year: int, tint := 0) -> void:
	var d := b - a
	var length := d.length()
	if length < 1.0:
		return
	var dir := d / length
	var yaw := atan2(-dir.y, dir.x)
	var base := a + n * 0.275
	if year < -80:
		var cols: Array = [OCHRE, RED, Color(0.55, 0.30, 0.45), Color(0.88, 0.82, 0.62)]
		var zones: Array = [[0.0, 0.8, 1], [0.8, h * 0.42, 2], [h * 0.42, h * 0.58, 3], [h * 0.58, h - 0.35, 4]]
		var zi := 0
		for zone in zones:
			var yb: float = zone[0]
			var yt: float = zone[1]
			var bw: float = [1.1, 1.6, 0.8, 0.9][zi] if zi < 4 else 1.0
			if zi == 0:
				bw = length
			var nb := maxi(1, int(round(length / bw)))
			var sw := length / nb
			for i in nb:
				var c := base + dir * (sw * (i + 0.5))
				var col: Color = cols[(i + zi + tint) % 4] if zi != 0 else Color(0.36, 0.22, 0.2)
				k.box(Vector3(c.x, y0 + yb + 0.03, c.y), Vector3(sw - 0.05, yt - yb - 0.06, 0.05), col, Kit.PLASTER, yaw, true)
			zi += 1
		k.box(Vector3((a + b).x * 0.5 + n.x * 0.31, y0 + h - 0.35, (a + b).y * 0.5 + n.y * 0.31), Vector3(length, 0.3, 0.14), Color(0.92, 0.88, 0.78), Kit.PLASTER, yaw, true)   # cornice
	else:
		var np := maxi(2, int(round(length / 2.2)))
		var sw2 := length / np
		var zone_top := y0 + h * 0.66
		k.box(Vector3((a + b).x * 0.5 + n.x * 0.28, y0, (a + b).y * 0.5 + n.y * 0.28), Vector3(length, 0.95, 0.05), Color(0.30, 0.14, 0.12), Kit.PLASTER, yaw, true)   # dado
		for i in np:
			var c := base + dir * (sw2 * (i + 0.5))
			var red := (i + tint) % 2 == 0
			var panel := RED if red else Color(0.13, 0.11, 0.10)
			if year > -15:
				panel = Color(0.93, 0.90, 0.82) if red else Color(0.14, 0.12, 0.11)
			k.box(Vector3(c.x, y0 + 0.95, c.y), Vector3(sw2 - 0.5, zone_top - y0 - 0.95, 0.04), panel, Kit.PLASTER, yaw, true)
			var pc := base + dir * (sw2 * i)
			k.box(Vector3(pc.x + n.x * 0.04, y0 + 0.95, pc.y + n.y * 0.04), Vector3(0.34, zone_top - y0 - 0.95, 0.14), Color(0.92, 0.86, 0.72), Kit.PLASTER, yaw, true)   # painted pilaster
		var pc2 := base + dir * length
		k.box(Vector3(pc2.x + n.x * 0.04, y0 + 0.95, pc2.y + n.y * 0.04), Vector3(0.34, zone_top - y0 - 0.95, 0.14), Color(0.92, 0.86, 0.72), Kit.PLASTER, yaw, true)
		k.box(Vector3((a + b).x * 0.5 + n.x * 0.31, zone_top, (a + b).y * 0.5 + n.y * 0.31), Vector3(length, 0.3, 0.2), Color(0.92, 0.84, 0.62), Kit.PLASTER, yaw, true)   # cornice
		# above it, painted architecture: a vista through columns, in blue and ochre
		var uc := base + dir * (length * 0.5)
		k.box(Vector3(uc.x, zone_top + 0.3, uc.y), Vector3(length * 0.8, y0 + h - zone_top - 0.5, 0.03), Color(0.72, 0.62, 0.38), Kit.PLASTER, yaw, true)
		for q in 3:
			var vc := base + dir * (length * (0.3 + 0.2 * q))
			k.box(Vector3(vc.x, zone_top + 0.5, vc.y), Vector3(length * 0.12, y0 + h - zone_top - 0.9, 0.06), Color(0.30, 0.42, 0.55), Kit.PLASTER, yaw, true)


## A tilted roof slab: top quad TILE, underside timber, four corners given in order.
static func _roof_quad(kc: Kit, p: Array, col := TILE_C) -> void:
	var c: Vector3 = (p[0] + p[1] + p[2] + p[3]) * 0.25
	kc.quad(p[0], p[1], p[2], p[3], col, Kit.TILE, c - Vector3(0, 2.0, 0))
	kc.quad(p[0] - Vector3(0, 0.25, 0), p[3] - Vector3(0, 0.25, 0), p[2] - Vector3(0, 0.25, 0), p[1] - Vector3(0, 0.25, 0), Color(0.5, 0.33, 0.2), Kit.TIMBER, c + Vector3(0, 2.0, 0))


## A couch (kline) for the dining room with a cushion.
static func _couch(k: Kit, foot: Vector3, w: float, d: float, yaw: float) -> void:
	k.push(Kit.at(foot, yaw))
	k.box(Vector3(0, 0, 0), Vector3(w, 0.45, d), WOOD, Kit.TIMBER, 0.0, true)
	k.box(Vector3(0, 0.45, 0), Vector3(w - 0.1, 0.14, d - 0.1), Color(0.55, 0.22, 0.2), Kit.CLOTH, 0.0, true)
	k.box(Vector3(0, 0.45, -d * 0.4), Vector3(w - 0.1, 0.4, 0.15), Color(0.55, 0.22, 0.2), Kit.CLOTH, 0.0, true)
	k.pop()


## The atrium house. The footprint is W (frontage, x) by L (depth, z), the street at +z. Plan
## from the street: the fauces (flanked by two shops on a wide house), the atrium with its
## compluvium and impluvium, cubicula on both sides, alae and the tablinum at the back, then the
## peristyle garden with the triclinium and the kitchen. Proportions after Vitruvius 6.3: the atrium
## length to width 5:3, its height to the beams three quarters of its length, the opening a
## quarter to a third of its width, the alae by the table of 6.3.4, the tablinum by 6.3.5-6
## (a half to two fifths of the atrium's width, height an eighth more than the width), the fauces
## two thirds or half the tablinum, the peristyle a third longer across than deep with columns as
## high as the portico is wide, the triclinium twice as long as wide (6.3.7-8).
static func _domus(sz: Vector2, year: int) -> Dictionary:
	var L := sz.x
	var W := sz.y
	var k := _kit()
	var kc := _kit()
	var lights: Array = []
	var zf := L * 0.5
	var wt := 0.5
	var ww := Color(0.90, 0.84, 0.70)
	var xl := -W * 0.5
	var xr := W * 0.5
	var shops := W >= 15.0
	# the atrium by Vitruvius' first proportion (5:3), shrunk if the plot is short
	var wa := clampf(W * 0.38, 5.4, 12.0)
	if (W - wa) * 0.5 < 3.6:
		wa = W - 7.2
	var la := wa * 5.0 / 3.0
	var tw := wa * (2.0 / 3.0 if wa < 6.5 else (0.5 if wa < 12.2 else 0.4))   # 6.3.5
	var fw := tw * (2.0 / 3.0 if wa < 9.0 else 0.5)                           # 6.3.6
	var df := 3.8                                                              # fauces length
	var td := maxf(5.0, tw * 0.9)
	var gar := 14.0                                                            # least depth for the peristyle
	var avail := L - df - td - gar - wt * 2.0
	if la > avail:
		la = maxf(avail, wa * 1.25)
	var he := 0.75 * la                                                        # to the beams, 6.3.4
	var hf := 4.4                                                              # side rooms and fauces
	var z_a0 := zf - df                  # atrium front edge
	var z_a1 := z_a0 - la                # atrium back edge
	var z_t1 := z_a1 - td                # tablinum back
	var ala_ft := la / RF
	var alw := la / (3.0 if ala_ft < 40.0 else (3.5 if ala_ft < 50.0 else (4.0 if ala_ft < 60.0 else (4.5 if ala_ft < 80.0 else 5.0))))   # 6.3.4
	var side := (W - wa) * 0.5
	var pave := Color(0.42, 0.30, 0.27)
	# ground: street frontage, threshold mosaic, atrium floor
	_span(k, xl - 1.0, -0.4, -L * 0.5 - 1.0, xr + 1.0, 0.0, zf + 4.0, Color(0.55, 0.50, 0.44), Kit.STONE, false)
	_floor(k, xl, -L * 0.5, xr, zf, 0.01, pave, Kit.PAINT)
	_checker(k, -fw * 0.5, zf - df, fw * 0.5, zf - 0.3, 0.02, 0.45, Color(0.9, 0.88, 0.82), Color(0.12, 0.1, 0.09))
	_checker(k, -tw * 0.5 + 0.2, z_a1 - td + 0.4, tw * 0.5 - 0.2, z_a1 - 0.2, 0.02, 0.4, Color(0.92, 0.9, 0.84), Color(0.16, 0.14, 0.12))
	# the street wall with the door of the fauces and the two shops
	var fx := W * 0.5
	var front_holes: Array = [[fx, fw, 3.4]]
	if shops:
		var sx := (W - fw) * 0.25 - 0.3
		front_holes.append([W * 0.5 - fw * 0.5 - sx * 0.5 - 0.15, minf(sx, 3.0), 2.7])
		front_holes.append([W * 0.5 + fw * 0.5 + sx * 0.5 + 0.15, minf(sx, 3.0), 2.7])
	_wall(k, Vector2(xl - wt * 0.5, zf), Vector2(xr + wt * 0.5, zf), 0.0, hf + 1.6, wt, ww, Kit.PLASTER, _front_offset(front_holes, wt * 0.5))
	# door leaves of the fauces, open
	var th := deg_to_rad(80.0)
	k.box(Vector3(-fw * 0.5 + cos(th) * fw * 0.25, 0.0, zf - sin(th) * fw * 0.25), Vector3(fw * 0.5, 3.0, 0.1), WOOD, Kit.TIMBER, th, true)
	k.box(Vector3(fw * 0.5 - cos(th) * fw * 0.25, 0.0, zf - sin(th) * fw * 0.25), Vector3(fw * 0.5, 3.0, 0.1), WOOD, Kit.TIMBER, PI - th, true)
	# fauces walls (+ the shops beside them)
	var sx0 := -fw * 0.5
	var sx1 := fw * 0.5
	_wall(k, Vector2(sx0, zf), Vector2(sx0, z_a0), 0.0, hf + 1.6, wt, ww, Kit.PLASTER)
	_wall(k, Vector2(sx1, zf), Vector2(sx1, z_a0), 0.0, hf + 1.6, wt, ww, Kit.PLASTER)
	if shops:
		for s: float in [-1.0, 1.0]:
			var xo := s * (W * 0.5)
			_wall(k, Vector2(xo, zf), Vector2(xo, z_a0), 0.0, hf + 1.6, wt, ww, Kit.PLASTER)
			var xin := s * (fw * 0.5)
			# the shop's counter and shelf
			var cxm := s * (W * 0.25 + fw * 0.25)
			_span(k, cxm - 1.0, 0.0, zf - 1.1, cxm + 1.0, 0.95, zf - 0.5, Color(0.7, 0.55, 0.4), Kit.STONE)
			k.cylinder(Vector3(cxm - 0.5, 0.0, zf - 1.8), 0.4, 0.9, TERRA, Kit.PAINT, 8)
			_lamp(lights, Vector3(cxm, 2.6, zf - 2.0), 0.7, 5.0)
	# the atrium: four tall walls, doors to the rooms, painted
	var holes_side: Array = []
	var ncub := 2
	var cub_len := (la - alw) / ncub
	for i in ncub:
		holes_side.append([(z_a0 - z_a1) - (alw + cub_len * (i + 0.5)) + 0.0, 1.2, 2.6])
	holes_side.append([la - alw * 0.5, minf(alw * 0.8, 3.6), 3.4])    # the ala, wide open
	_wall(k, Vector2(-wa * 0.5, z_a0), Vector2(-wa * 0.5, z_a1), 0.0, he, wt, ww, Kit.PLASTER, holes_side)
	_wall(k, Vector2(wa * 0.5, z_a0), Vector2(wa * 0.5, z_a1), 0.0, he, wt, ww, Kit.PLASTER, holes_side)
	_wall(k, Vector2(-wa * 0.5, z_a0), Vector2(-fw * 0.5, z_a0), 0.0, he, wt, ww, Kit.PLASTER)
	_wall(k, Vector2(fw * 0.5, z_a0), Vector2(wa * 0.5, z_a0), 0.0, he, wt, ww, Kit.PLASTER)
	_wall(k, Vector2(-fw * 0.5, z_a0), Vector2(fw * 0.5, z_a0), hf + 1.6, he - hf - 1.6, wt, ww, Kit.PLASTER)
	# back of the atrium: tablinum opening in the middle
	_wall(k, Vector2(-wa * 0.5, z_a1), Vector2(wa * 0.5, z_a1), 0.0, he, wt, ww, Kit.PLASTER, [[wa * 0.5, tw, tw * 1.125]])
	for s: float in [-1.0, 1.0]:
		_paint_wall(k, Vector2(s * wa * 0.5, z_a0 - 0.3), Vector2(s * wa * 0.5, z_a1 + 0.3), Vector2(-s, 0.0), 0.0, minf(he, 6.0), year, 0)
	_paint_wall(k, Vector2(-wa * 0.5 + 0.3, z_a1), Vector2(-tw * 0.5 - 0.2, z_a1), Vector2(0.0, 1.0), 0.0, minf(he, 6.0), year, 1)
	_paint_wall(k, Vector2(tw * 0.5 + 0.2, z_a1), Vector2(wa * 0.5 - 0.3, z_a1), Vector2(0.0, 1.0), 0.0, minf(he, 6.0), year, 1)
	# impluvium: a basin under the compluvium, water, a rim
	var cw := wa * 0.3                                      # 6.3.6: a quarter to a third
	var cl := cw * la / wa
	var zc := (z_a0 + z_a1) * 0.5
	_span(k, -cw * 0.5 - 0.3, 0.0, zc - cl * 0.5 - 0.3, cw * 0.5 + 0.3, 0.2, zc + cl * 0.5 + 0.3, MARBLE, Kit.STONE)
	_floor(k, -cw * 0.5, zc - cl * 0.5, cw * 0.5, zc + cl * 0.5, 0.16, Color(0.35, 0.55, 0.65), Kit.WATER)
	# the compluvium roof, sloping inward to the opening (Tuscan atrium, 6.3.1)
	var ex := wa * 0.5 + 0.8
	var ey := he
	var iy := he - 1.5
	_roof_quad(kc, [Vector3(-ex, ey, z_a0 + 0.8), Vector3(ex, ey, z_a0 + 0.8), Vector3(cw * 0.5, iy, zc + cl * 0.5), Vector3(-cw * 0.5, iy, zc + cl * 0.5)])
	_roof_quad(kc, [Vector3(ex, ey, z_a1 - 0.8), Vector3(-ex, ey, z_a1 - 0.8), Vector3(-cw * 0.5, iy, zc - cl * 0.5), Vector3(cw * 0.5, iy, zc - cl * 0.5)])
	_roof_quad(kc, [Vector3(-ex, ey, z_a1 - 0.8), Vector3(-ex, ey, z_a0 + 0.8), Vector3(-cw * 0.5, iy, zc + cl * 0.5), Vector3(-cw * 0.5, iy, zc - cl * 0.5)])
	_roof_quad(kc, [Vector3(ex, ey, z_a0 + 0.8), Vector3(ex, ey, z_a1 - 0.8), Vector3(cw * 0.5, iy, zc - cl * 0.5), Vector3(cw * 0.5, iy, zc + cl * 0.5)])
	for i in range(1, 6):   # beams and trimmers showing underneath
		var zz := z_a0 - la * i / 6.0
		kc.box(Vector3(0, he - 0.45, zz), Vector3(wa + 1.0, 0.3, 0.3), WOOD_D, Kit.TIMBER, 0.0, true)
	lights.append({"pos": Vector3(0, he - 0.8, zc), "colour": Color(0.80, 0.88, 1.0), "energy": 1.4, "range": 12.0, "kind": "sky"})
	# side rooms: cubicula and the alae with the masks of the ancestors
	for s: float in [-1.0, 1.0]:
		var xo := s * (W * 0.5)
		var xi := s * (wa * 0.5)
		_wall(k, Vector2(xo, z_a0), Vector2(xo, z_a1), 0.0, hf + 1.6, wt, ww, Kit.PLASTER)
		for i in ncub:
			var za0 := z_a0 - cub_len * i
			var za1 := z_a0 - cub_len * (i + 1)
			_wall(k, Vector2(xi, za1), Vector2(xo, za1), 0.0, hf + 1.0, wt * 0.8, ww, Kit.PLASTER)
			# the bed and a lamp
			var bz := (za0 + za1) * 0.5
			k.box(Vector3(s * (W * 0.5 - 1.3), 0.0, bz), Vector3(1.0, 0.45, 1.9), WOOD, Kit.TIMBER, 0.0, true)
			k.box(Vector3(s * (W * 0.5 - 1.3), 0.45, bz), Vector3(0.95, 0.12, 1.85), Color(0.78, 0.74, 0.62), Kit.CLOTH, 0.0, true)
			_lamp(lights, Vector3(s * (W * 0.5 - 1.0), 1.4, bz + 0.6), 0.6, 4.0)
			_paint_wall(k, Vector2(xo, za0 - 0.3), Vector2(xo, za1 + 0.3), Vector2(-s, 0.0), 0.0, hf, year, i)
		# the ala: open to the atrium, with the wax masks of the ancestors in cupboards (Pliny NH 35.6, # unverified)
		var zal := z_a1 + alw * 0.5
		_wall(k, Vector2(xi, z_a1), Vector2(xo, z_a1), 0.0, hf + 1.0, wt * 0.8, ww, Kit.PLASTER)
		for q in 3:
			var mx := xo - s * 0.6
			k.box(Vector3(mx, 1.2, z_a1 + 0.9 + q * 1.0), Vector3(0.5, 0.7, 0.6), WOOD, Kit.TIMBER, 0.0, true)
			k.dome(Vector3(mx - s * 0.02, 1.9, z_a1 + 0.9 + q * 1.0), 0.14, Color(0.85, 0.75, 0.6), Kit.PAINT, 1.2, 3, 7)
	# flat roofs over the side rooms
	for s: float in [-1.0, 1.0]:
		kc.box(Vector3(s * (wa * 0.5 + side * 0.5), hf + 1.0, (z_a0 + z_a1) * 0.5), Vector3(side + 0.6, 0.3, la + 1.0), TILE_C, Kit.TILE, 0.0, true)
	# the tablinum: a room open to the atrium and the garden, with a coffered ceiling
	var tz0 := z_a1
	var tz1 := z_a1 - td
	var tx0 := -tw * 0.5
	var tx1 := tw * 0.5
	var th_t := tw * 1.125 + tw / 3.0
	_wall(k, Vector2(tx0, tz0), Vector2(tx0, tz1), 0.0, th_t, wt, ww, Kit.PLASTER)
	_wall(k, Vector2(tx1, tz0), Vector2(tx1, tz1), 0.0, th_t, wt, ww, Kit.PLASTER)
	_wall(k, Vector2(tx0, tz1), Vector2(tx1, tz1), th_t * 0.0 + tw * 1.125, th_t - tw * 1.125, wt, ww, Kit.PLASTER)
	_wall(k, Vector2(-wa * 0.5, tz0), Vector2(tx0, tz0), he, 0.0001, wt, ww, Kit.PLASTER)
	_ceiling(kc, tx0, tz1, tx1, tz0, th_t, maxi(2, int(tw / 1.8)), maxi(2, int(td / 1.8)), 0.25, 0.3, Color(0.55, 0.38, 0.22), WOOD_D, true)
	for s: float in [-1.0, 1.0]:
		_paint_wall(k, Vector2(s * tw * 0.5, tz0 - 0.3), Vector2(s * tw * 0.5, tz1 + 0.3), Vector2(-s, 0.0), 0.0, tw * 1.125, year, 2)
	k.box(Vector3(0, 0, tz1 + 1.0), Vector3(1.8, 0.8, 0.8), WOOD_L, Kit.TIMBER, 0.0, true)    # the master's table
	_lamp(lights, Vector3(0, 2.2, tz1 + 1.2), 0.9, 6.0)
	# the rest of the plan behind: walls between the atrium side rooms and the garden, the peristyle
	var gz0 := z_t1
	var gz1 := -L * 0.5 + wt
	var pw := W - 2.0 * wt
	var ph := minf(gz0 - gz1, pw * 0.75)           # 6.3.7: a third longer across than deep
	gz1 = gz0 - ph
	for s: float in [-1.0, 1.0]:
		_wall(k, Vector2(s * W * 0.5, z_a1), Vector2(s * W * 0.5, -L * 0.5), 0.0, hf + 1.6, wt, ww, Kit.PLASTER)
		_wall(k, Vector2(s * tw * 0.5, z_a1), Vector2(s * W * 0.5, z_a1), 0.0, hf + 1.0, wt, ww, Kit.PLASTER)
	_wall(k, Vector2(xl, -L * 0.5), Vector2(xr, -L * 0.5), 0.0, hf + 1.6, wt, ww, Kit.PLASTER)
	var pcw := minf(3.4, pw * 0.14)           # the portico's width = the columns' height (6.3.7)
	var cd := pcw / 8.0
	var gx0 := xl + 0.4
	var gx1 := xr - 0.4
	var zt := gz0 - 0.3
	var zb := gz1 + 0.3
	_floor(k, gx0, zb, gx1, zt, 0.01, Color(0.72, 0.66, 0.56), Kit.STONE)
	# the garden inside the portico
	_floor(k, gx0 + pcw, zb + pcw, gx1 - pcw, zt - pcw, 0.03, GRASS, Kit.LEAF)
	var icd := cd * 3.5
	var nxc := maxi(3, int((gx1 - gx0) / (icd * 3.2)))
	var nzc := maxi(2, int((zt - zb) / (icd * 3.2)))
	var cols_x: Array = []
	for i in range(nxc + 1):
		cols_x.append(gx0 + (gx1 - gx0) * i / nxc)
	for i in range(nxc + 1):
		_column(k, Vector3(cols_x[i], 0.0, zt - 0.5), cd * 2.0, pcw, MARBLE if year > -80 else TRAVERTINE, Kit.STONE, "tuscan")
		_column(k, Vector3(cols_x[i], 0.0, zb + 0.5), cd * 2.0, pcw, MARBLE if year > -80 else TRAVERTINE, Kit.STONE, "tuscan")
	for j in range(1, nzc):
		var zz2 := zb + 0.5 + (zt - zb - 1.0) * j / nzc
		_column(k, Vector3(gx0, 0.0, zz2), cd * 2.0, pcw, MARBLE if year > -80 else TRAVERTINE, Kit.STONE, "tuscan")
		_column(k, Vector3(gx1, 0.0, zz2), cd * 2.0, pcw, MARBLE if year > -80 else TRAVERTINE, Kit.STONE, "tuscan")
	_span(k, gx0 - 0.4, pcw, zb + 0.1, gx1 + 0.4, pcw + 0.4, zb + 0.9, ww, Kit.PLASTER)
	_span(k, gx0 - 0.4, pcw, zt - 0.9, gx1 + 0.4, pcw + 0.4, zt - 0.1, ww, Kit.PLASTER)
	# a sloping portico roof along the edges
	var yr0 := pcw + 0.4
	var gcx := (gx0 + gx1) * 0.5
	var gcz := (zt + zb) * 0.5
	_roof_quad(kc, [Vector3(gx0 - 0.6, yr0 + 0.9, zt - 0.1), Vector3(gx1 + 0.6, yr0 + 0.9, zt - 0.1), Vector3(gx1 + 0.6, yr0 - 0.2, zt - pcw), Vector3(gx0 - 0.6, yr0 - 0.2, zt - pcw)])
	_roof_quad(kc, [Vector3(gx1 + 0.6, yr0 + 0.9, zb + 0.1), Vector3(gx0 - 0.6, yr0 + 0.9, zb + 0.1), Vector3(gx0 - 0.6, yr0 - 0.2, zb + pcw), Vector3(gx1 + 0.6, yr0 - 0.2, zb + pcw)])
	# a long pool, trees, a herm, a fountain
	var pwid := minf(2.0, (gx1 - gx0) * 0.12)
	_span(k, gcx - (gx1 - gx0) * 0.3, 0.0, gcz - pwid, gcx + (gx1 - gx0) * 0.3, 0.35, gcz + pwid, MARBLE, Kit.STONE)
	_floor(k, gcx - (gx1 - gx0) * 0.3 + 0.2, gcz - pwid + 0.2, gcx + (gx1 - gx0) * 0.3 - 0.2, gcz + pwid - 0.2, 0.3, Color(0.35, 0.55, 0.65), Kit.WATER)
	for q in 4:
		var tx := gx0 + pcw + 1.5 + (gx1 - gx0 - 2.0 * pcw - 3.0) * (q % 2)
		var tzp := zb + pcw + 1.2 + (zt - zb - 2.0 * pcw - 2.4) * (q / 2)
		_tree(k, Vector3(tx, 0.03, tzp), 3.6 + q * 0.3)
	for q in 5:
		k.box(Vector3(gx0 + pcw + 0.8 + q * 1.1, 0.03, zb + pcw + 0.5), Vector3(0.7, 0.5, 0.5), LEAF_C, Kit.LEAF, 0.0, true)
	k.box(Vector3(gcx, 0.35, gcz + pwid + 1.2), Vector3(0.4, 1.4, 0.4), MARBLE, Kit.STONE, 0.0, true)    # a herm
	k.dome(Vector3(gcx, 1.75, gcz + pwid + 1.2), 0.22, MARBLE, Kit.STONE, 1.1, 3, 7)
	# the triclinium: twice as long as wide (6.3.8), on one side, three couches round a table
	var trw := minf(4.4, (gx1 - gx0) * 0.2)
	var trl := trw * 2.0
	var trx := xr - 0.2 - trw * 0.5
	var trz := gz0 - 0.6 - trl * 0.5
	# kitchen and a small room on the other side, at the front of the garden
	var kx := xl + 0.2 + 2.0
	var kz := gz0 - 0.6 - 1.6
	var rx0 := xl + 0.2
	var rx1 := xl + 4.4
	var rz0 := gz0 - 0.2
	var rz1 := gz0 - 3.8
	_wall(k, Vector2(rx1, rz0), Vector2(rx1, rz1), 0.0, hf, wt, Color(0.50, 0.44, 0.38), Kit.PLASTER, [[1.8, 1.2, 2.4]])
	_wall(k, Vector2(rx0, rz1), Vector2(rx1, rz1), 0.0, hf, wt, Color(0.50, 0.44, 0.38), Kit.PLASTER)
	_span(k, rx0 + 0.1, 0.0, rz0 - 1.4, rx0 + 2.5, 0.9, rz0 - 0.5, TRAVERTINE.darkened(0.1), Kit.STONE)     # the hearth with its arches
	for q in 3:
		k.box(Vector3(rx0 + 0.55 + q * 0.7, 0.0, rz0 - 0.52), Vector3(0.5, 0.55, 0.06), BLACK_P, Kit.DARK, 0.0, true)
	k.cylinder(Vector3(rx0 + 1.2, 0.9, rz0 - 0.95), 0.28, 0.3, BRONZE, Kit.GOLD, 8)    # a pot on the fire
	lights.append({"pos": Vector3(rx0 + 1.2, 1.3, rz0 - 0.95), "colour": Color(1.0, 0.55, 0.22), "energy": 1.8, "range": 6.0, "kind": "fire"})
	_span(k, rx0 + 0.1, 1.7, rz0 - 0.9, rx0 + 0.9, 2.3, rz0 - 0.5, Color(0.9, 0.82, 0.68), Kit.PLASTER)    # the lararium niche above (Pompeian evidence, # unverified)
	_span(k, rx0 + 0.05, 2.3, rz0 - 1.0, rx0 + 1.0, 2.45, rz0 - 0.45, TILE_C, Kit.TILE)
	# the triclinium walls, couches, table
	_wall(k, Vector2(xr - trw - 0.2, trz + trl * 0.5), Vector2(xr - trw - 0.2, trz - trl * 0.5), 0.0, hf + 0.4, wt, ww, Kit.PLASTER, [[trl * 0.5, 2.0, 2.6]])
	_wall(k, Vector2(xr - trw - 0.2, trz - trl * 0.5), Vector2(xr, trz - trl * 0.5), 0.0, hf + 0.4, wt, ww, Kit.PLASTER)
	_paint_wall(k, Vector2(xr, trz + trl * 0.5 - 0.3), Vector2(xr, trz - trl * 0.5 + 0.3), Vector2(-1.0, 0.0), 0.0, hf + 0.4, year, 1)
	_couch(k, Vector3(trx, 0.0, trz - trl * 0.5 + 0.8), trw * 0.7, 0.9, 0.0)
	_couch(k, Vector3(trx - trw * 0.5 + 0.8, 0.0, trz), trl * 0.4, 0.9, PI * 0.5)
	_couch(k, Vector3(trx + trw * 0.5 - 0.8, 0.0, trz), trl * 0.4, 0.9, PI * 0.5)
	k.cylinder(Vector3(trx, 0.0, trz), 0.5, 0.55, WOOD_L, Kit.TIMBER, 10)
	_lamp(lights, Vector3(trx, 2.4, trz), 1.0, 6.0)
	kc.box(Vector3(trx, hf + 0.4, trz), Vector3(trw + 0.6, 0.3, trl + 0.6), TILE_C, Kit.TILE, 0.0, true)
	kc.box(Vector3((rx0 + rx1) * 0.5, hf, (rz0 + rz1) * 0.5), Vector3(rx1 - rx0 + 0.6, 0.3, rz0 - rz1 + 0.6), TILE_C, Kit.TILE, 0.0, true)
	# the fauces and shops under flat roofs
	kc.box(Vector3(0, hf + 1.6, zf - df * 0.5), Vector3(W + 0.8, 0.3, df + 0.6), TILE_C, Kit.TILE, 0.0, true)
	var spawn := look(Vector3(0, EYE, zf + 3.0), Vector3(0, 2.2, z_a1 - 3.0))
	var views := [
		["street", spawn],
		["atrium", look(Vector3(0, EYE, z_a0 - 0.8), Vector3(0, 2.4, z_a1 - td))],
		["tablinum", look(Vector3(0, EYE, tz0 - 0.8), Vector3(0, 1.8, gz1))],
		["peristyle", look(Vector3(gcx - 7.0, EYE, zt - pcw - 0.3), Vector3(gcx + 6.0, 1.2, zb + pcw + 1.0))],
		["triclinium", look(Vector3(trx - trw * 0.3, EYE, trz + trl * 0.4), Vector3(trx, 0.8, trz - trl * 0.3))],
		["overview", look(Vector3(W * 0.6, L * 0.9, L * 0.75), Vector3(0, 0.0, -L * 0.1))],
	]
	var seats := {"atrium": views[1][1], "tablinum": views[2][1], "peristyle": views[3][1]}
	var notes := [
		"Atrium 5:3, height to the beams 3/4 of its length, impluvium 1/4 to 1/3 of its width, alae by the table of 6.3.4, tablinum and fauces by 6.3.5-6, peristyle a third longer across than deep with columns as high as the portico is wide, triclinium twice as long as wide: Vitruvius 6.3.1-8. Read.",
		"The alae's table in Vitruvius starts at 30 ft; shorter atria use a third (assumption). The tablinum's height rule is applied as written (an eighth more than its width, the ceiling a third of the width higher).",
		"Wall painting: the First style (block imitation) before about 80 BC, the Second (painted architecture) after, a plainer style after about 15 BC: the Mau convention of Pompeian scholarship, not an ancient source. # unverified",
		"Masks of the ancestors in the alae: Pliny NH 35.6-7. # unverified (not read). Lararium, kitchen hearth and the shops beside the fauces follow Pompeian houses. # unverified",
		"Dimensions of rooms, positions of cubicula, the kitchen and the furniture: conjecture. The compluvium and its roof slope (Tuscan atrium) follow 6.3.1.",
	]
	return _pack(k, kc, lights, spawn, seats, views, notes, {"anchors": {"door": Vector3(0, 0, zf), "impluvium": Vector3(0, 0.2, zc), "tablinum": Vector3(0, 0, tz0 - td * 0.5), "garden": Vector3(gcx, 0, gcz), "hearth": Vector3(rx0 + 1.2, 0.9, rz0 - 0.95)}, "floor_y": 0.0})


## Opening centres measured from the wall's left end, when the wall starts `by` metres left of x = -W/2.
static func _front_offset(holes: Array, by: float) -> Array:
	var out: Array = []
	for h in holes:
		var c: Array = (h as Array).duplicate()
		c[0] = c[0] + by
		out.append(c)
	return out


# ====================================================================================================
#  INSULA (Vitruvius 2.8.17)
# ====================================================================================================

## A floor slab over `rect` (x0, z0, x1, z1) with rectangular holes cut out (x0, z0, x1, z1 each).
static func _slab_holes(k: Kit, rect: Array, holes: Array, y: float, thick: float, col: Color, under := WOOD_D) -> void:
	var xs: Array = [rect[0], rect[2]]
	for h in holes:
		for x in [h[0], h[2]]:
			if x > rect[0] and x < rect[2]:
				xs.append(x)
	xs.sort()
	for i in range(xs.size() - 1):
		var xa: float = xs[i]
		var xb: float = xs[i + 1]
		if xb - xa < 0.01:
			continue
		var cuts: Array = []
		for h in holes:
			if h[0] <= xa + 0.001 and h[2] >= xb - 0.001:
				cuts.append([maxf(h[1], rect[1]), minf(h[3], rect[3])])
		cuts.sort_custom(func(p, q): return p[0] < q[0])
		var z := float(rect[1])
		for c in cuts:
			if c[0] > z:
				_slab_piece(k, xa, z, xb, c[0], y, thick, col, under)
			z = maxf(z, c[1])
		if z < rect[3]:
			_slab_piece(k, xa, z, xb, rect[3], y, thick, col, under)


static func _slab_piece(k: Kit, xa: float, za: float, xb: float, zb: float, y: float, thick: float, col: Color, under: Color) -> void:
	_span(k, xa, y - thick, za, xb, y, zb, col, Kit.TIMBER, false)
	_floor(k, xa, za, xb, zb, y - thick, under, Kit.TIMBER, false)


## A tenement block (insula): tabernae with mezzanines on the street, a stair, a courtyard, flats
## above that grow poorer with every flight. Outer walls 1.5 Roman feet thick, the legal limit on a
## public way (Vitruvius 2.8.17), the upper storeys won by height because the plan could not hold
## the people (ib.). `sz` is (frontage x, depth z); the street at +z.
static func _insula(sz: Vector2, year: int) -> Dictionary:
	var X := sz.x
	var Z := sz.y
	var k := _kit()
	var kc := _kit()
	var lights: Array = []
	var wt := 1.5 * RF                           # 0.44 m
	var zf := Z * 0.5
	var sd := 6.4                                # depth of the front block (shops, stair)
	var zb := zf - sd
	var hs := [4.4, 3.4, 3.2, 3.0]               # storey heights
	var ys: Array = [0.0]
	for h in hs:
		ys.append(ys[-1] + h)
	var ytop: float = ys[4]
	var xl := -X * 0.5
	var xr := X * 0.5
	var cx0 := xl + 3.0
	var cx1 := xr - 3.0
	var cz1 := zb
	var cz0 := -Z * 0.5 + 5.2
	var wall_cols: Array = [Color(0.90, 0.84, 0.70), Color(0.92, 0.84, 0.70), Color(0.88, 0.84, 0.76), Color(0.66, 0.52, 0.38)]
	var wall_mats: Array = [Kit.PLASTER, Kit.PLASTER, Kit.PLASTER, Kit.MUDBRICK]
	# street, courtyard pavement
	_span(k, xl - 1.5, -0.4, -Z * 0.5 - 1.5, xr + 1.5, 0.0, zf + 5.0, Color(0.50, 0.47, 0.42), Kit.STONE, false)
	_floor(k, xl, -Z * 0.5, xr, zf, 0.01, Color(0.58, 0.52, 0.44), Kit.STONE)
	# the stair shaft in the front block (right of the street door), the entrance, the shops
	var xe := xr - 9.0                            # the entrance corridor
	var sx0 := xe + 0.95
	var shaft := [sx0, zb, sx0 + 2.4, zf - 0.4]
	var bays: Array = []                          # shop partition x positions
	var nshop := 5
	var span_l := (xe - 0.75) - xl
	var bw := span_l / nshop
	for i in range(nshop + 1):
		bays.append(xl + bw * i)
	# outer wall, storey by storey, with the shop fronts and windows
	for f in 4:
		var y0: float = ys[f]
		var h: float = hs[f]
		var col: Color = wall_cols[f]
		var mat: int = wall_mats[f]
		var fh: Array = []
		var rh: Array = []
		if f == 0:
			for i in nshop:
				fh.append([(bays[i] + bays[i + 1]) * 0.5 - xl + wt * 0.5, 3.0, 2.9])
			fh.append([xe - xl + wt * 0.5, 1.6, 2.6])
		else:
			for i in range(nshop):
				fh.append([(bays[i] + bays[i + 1]) * 0.5 - xl + wt * 0.5, 1.3, 2.7, 1.0])
			fh.append([xe - xl + wt * 0.5, 1.0, 2.5, 1.1])
			fh.append([sx0 + 1.2 - xl + wt * 0.5, 0.8, 2.4, 1.2])
		var side_h: Array = []
		var back_h: Array = []
		if f > 0:
			for q in 3:
				side_h.append([Z * 0.2 + q * Z * 0.3, 0.9, 2.4, 1.1])
			for q in 5:
				back_h.append([X * (q + 0.5) / 5.0, 0.9, 2.4, 1.1])
		else:
			back_h.append([X * 0.5, 1.0, 2.2])
		_wall(k, Vector2(xl - wt * 0.5, zf), Vector2(xr + wt * 0.5, zf), y0, h, wt, col, mat, fh)
		_wall(k, Vector2(xl - wt * 0.5, -Z * 0.5), Vector2(xr + wt * 0.5, -Z * 0.5), y0, h, wt, col, mat, back_h)
		_wall(k, Vector2(xl, -Z * 0.5 + wt * 0.5), Vector2(xl, zf - wt * 0.5), y0, h, wt, col, mat, side_h)
		_wall(k, Vector2(xr, -Z * 0.5 + wt * 0.5), Vector2(xr, zf - wt * 0.5), y0, h, wt, col, mat, side_h)
		# the walls round the courtyard, with doors from every room
		var doors_f: Array = []
		for i in nshop:
			doors_f.append([(bays[i] + bays[i + 1]) * 0.5 - xl + wt * 0.5, 1.0, 2.2])
		var doors_c: Array = []
		if f == 0:
			doors_f = [[xe - xl + wt * 0.5, 1.6, 2.6], [sx0 + 1.2 - xl + wt * 0.5, 1.0, 2.2]]
		_wall(k, Vector2(xl, zb), Vector2(xr, zb), y0, h, wt * 0.9, col, mat, doors_f)
		var nr := int((cz1 - cz0) / 4.2)
		var dside: Array = []
		for q in nr:
			dside.append([(cz1 - cz0) * (q + 0.5) / nr, 1.0, 2.2])
		_wall(k, Vector2(cx0, cz1), Vector2(cx0, cz0), y0, h, wt * 0.9, col, mat, dside)
		_wall(k, Vector2(cx1, cz1), Vector2(cx1, cz0), y0, h, wt * 0.9, col, mat, dside)
		var nrr := int(X / 4.6)
		var drear: Array = []
		for q in nrr:
			drear.append([X * (q + 0.5) / nrr, 1.0, 2.2])
		_wall(k, Vector2(xl, cz0), Vector2(xr, cz0), y0, h, wt * 0.9, col, mat, drear)
		# partitions: between the shops and front rooms, side rooms, rear rooms
		for i in range(1, nshop):
			_wall(k, Vector2(bays[i], zb), Vector2(bays[i], zf), y0, h, wt * 0.8, col, mat)
		_wall(k, Vector2(xe - 0.75, zb), Vector2(xe - 0.75, zf), y0, h, wt * 0.8, col, mat)
		_wall(k, Vector2(sx0, zb), Vector2(sx0, zf), y0, h, wt * 0.8, col, mat)
		_wall(k, Vector2(sx0 + 2.4, zb), Vector2(sx0 + 2.4, zf), y0, h, wt * 0.8, col, mat)
		_wall(k, Vector2(sx0 + 1.15, zb + 0.5), Vector2(sx0 + 1.15, zf - 0.5), y0, h, wt * 0.5, WOOD, Kit.TIMBER)   # the stair's spine wall
		for q in range(1, nr):
			var zq := cz0 + (cz1 - cz0) * q / nr
			_wall(k, Vector2(xl, zq), Vector2(cx0, zq), y0, h, wt * 0.8, col, mat)
			_wall(k, Vector2(cx1, zq), Vector2(xr, zq), y0, h, wt * 0.8, col, mat)
		for q in range(1, nrr):
			var xq := xl + X * q / nrr
			_wall(k, Vector2(xq, -Z * 0.5), Vector2(xq, cz0), y0, h, wt * 0.8, col, mat)
		# furnishings: the higher, the poorer
		if f >= 1:
			var kind_rooms: Array = []
			for i in nshop:
				kind_rooms.append(Vector3((bays[i] + bays[i + 1]) * 0.5, y0, zf - 1.2))
			for r in kind_rooms:
				if f <= 2:
					k.box(Vector3(r.x - 1.0, y0 + 0.0, r.z - 1.2), Vector3(1.0, 0.45, 1.9), WOOD, Kit.TIMBER, 0.0, true)
					k.box(Vector3(r.x - 1.0, y0 + 0.45, r.z - 1.2), Vector3(0.95, 0.1, 1.85), Color(0.72, 0.68, 0.58), Kit.CLOTH, 0.0, true)
				else:
					k.box(Vector3(r.x - 1.0, y0, r.z - 1.2), Vector3(0.9, 0.2, 1.8), Color(0.62, 0.52, 0.30), Kit.THATCH, 0.0, true)    # a straw pallet
				k.cylinder(Vector3(r.x + 0.9, y0, r.z - 2.4), 0.28, 0.5, BRONZE, Kit.GOLD, 8)    # a brazier
				if f == 1:
					k.box(Vector3(r.x + 0.4, y0, r.z - 0.6), Vector3(0.9, 0.7, 0.6), WOOD_L, Kit.TIMBER, 0.0, true)
					_lamp(lights, Vector3(r.x, y0 + 1.5, r.z - 1.8), 0.5, 4.0)
				elif f == 2 and int(r.x) % 2 == 0:
					_lamp(lights, Vector3(r.x, y0 + 1.5, r.z - 1.8), 0.35, 3.5)
	# floors: slabs with the courtyard void (a balcony ring round it above the ground floor) and the stair holes
	var balc := 1.3
	for f in range(1, 4):
		var y: float = ys[f]
		var holes: Array = [[cx0 + balc, cz0 + balc, cx1 - balc, cz1 - 0.0]]
		if f <= 3:
			var hole_x0: float = sx0 if f % 2 == 1 else sx0 + 1.25
			holes.append([hole_x0, zb, hole_x0 + 1.15, zf - 0.4])
		_slab_holes(k, [xl, -Z * 0.5, xr, zf], holes, y, 0.3, Color(0.62, 0.46, 0.30))
	# the balcony rail round the courtyard void
	for f in range(1, 4):
		var y2: float = ys[f]
		for i in range(0, int((cx1 - cx0) / 1.6) + 1):
			var xp := cx0 + balc + (cx1 - cx0 - 2.0 * balc) * i / maxf(1.0, floorf((cx1 - cx0) / 1.6))
			k.rod(Vector3(xp, y2, cz0 + balc), Vector3(xp, y2 + 1.0, cz0 + balc), 0.04, WOOD_D, Kit.TIMBER)
		_span(k, cx0 + balc, y2 + 0.95, cz0 + balc - 0.04, cx1 - balc, y2 + 1.03, cz0 + balc + 0.04, WOOD_D, Kit.TIMBER)
		_span(k, cx0 + balc - 0.04, y2 + 0.95, cz0 + balc, cx0 + balc + 0.04, y2 + 1.03, cz1, WOOD_D, Kit.TIMBER)
		_span(k, cx1 - balc - 0.04, y2 + 0.95, cz0 + balc, cx1 - balc + 0.04, y2 + 1.03, cz1, WOOD_D, Kit.TIMBER)
	# the stairs: flights alternate between two lanes, steps 0.19 x 0.27
	for f in 3:
		var y0: float = ys[f]
		var n := int(round(hs[f] / 0.19))
		var rise: float = hs[f] / n
		var run := (zf - 0.4 - zb - 0.4) / n
		if f % 2 == 0:
			for i in n:
				k.box(Vector3(sx0 + 0.6, y0, zb + 0.2 + run * (i + 0.5)), Vector3(1.15, rise * (i + 1) * 0.0 + 0.12, run), WOOD, Kit.TIMBER, 0.0, true)
		# solid-looking steps (a stair of boxes from the floor of the flight up to its step)
		for i in n:
			var lane_x := sx0 + 0.6 if f % 2 == 0 else sx0 + 1.85
			var zc2 := (zb + 0.2 + run * (i + 0.5)) if f % 2 == 0 else (zf - 0.2 - run * (i + 0.5))
			k.box(Vector3(lane_x, y0 + rise * i, zc2), Vector3(1.1, rise, run), WOOD, Kit.TIMBER, 0.0, true)
	# the ground floor: shops with mezzanines, counters, the well in the courtyard
	for i in nshop:
		var cx: float = (bays[i] + bays[i + 1]) * 0.5
		# mezzanine over the back half, ladder up the side wall
		_span(k, bays[i] + 0.2, 2.5, zb + 0.2, bays[i + 1] - 0.2, 2.75, zb + 3.2, Color(0.56, 0.40, 0.26), Kit.TIMBER, true)
		_span(k, bays[i] + 0.2, 2.75, zb + 3.15, bays[i + 1] - 0.2, 3.45, zb + 3.25, WOOD_D, Kit.TIMBER)       # a low rail
		for q in 12:
			k.box(Vector3(bays[i] + 0.35, 0.0 + q * 0.2, zb + 3.5 - 0.0), Vector3(0.15, 0.2, 0.45 + 0.0), WOOD_D, Kit.TIMBER, 0.0, true)
		# a counter with a dolium (the thermopolium of the street) in every other shop
		if i % 2 == 0:
			_span(k, cx - 1.2, 0.0, zf - 1.3, cx + 1.2, 0.95, zf - 0.6, Color(0.66, 0.52, 0.38), Kit.STONE)
			k.cylinder(Vector3(cx - 0.6, 0.0, zf - 0.95), 0.4, 0.95, TERRA, Kit.PAINT, 9)
			k.cylinder(Vector3(cx + 0.5, 0.0, zf - 0.95), 0.36, 0.95, TERRA, Kit.PAINT, 9)
		else:
			_span(k, cx - 1.1, 0.0, zf - 1.2, cx + 1.1, 0.8, zf - 0.7, WOOD, Kit.TIMBER)
			for q in 3:
				k.box(Vector3(cx - 0.9 + q * 0.9, 0.8, zf - 0.95), Vector3(0.6, 0.35, 0.3), Color(0.8, 0.7, 0.5), Kit.THATCH, 0.0, true)
		_lamp(lights, Vector3(cx, 2.0, zb + 2.0), 0.7, 5.0)
	# courtyard: well-head, a trough, washing
	k.cylinder(Vector3((cx0 + cx1) * 0.5, 0.0, (cz0 + cz1) * 0.5), 0.7, 0.9, TRAVERTINE, Kit.STONE, 10)
	for q in 4:
		k.rod(Vector3(cx0 + 2.0 + q * 3.0, 3.2, cz0 + 1.3), Vector3(cx0 + 2.0 + q * 3.0 + 2.0, 3.0, cz0 + 1.3), 0.015, WOOD_D, Kit.TIMBER)
		k.box(Vector3(cx0 + 2.6 + q * 3.0, 2.2, cz0 + 1.3), Vector3(1.1, 0.9, 0.04), Color(0.9, 0.88, 0.82) if q % 2 == 0 else Color(0.62, 0.35, 0.3), Kit.CLOTH, 0.0, true)
	# roof: the front block under a gable, the wings under a lean-to
	kc.gable_roof(Vector3(0, ytop, (zf + zb) * 0.5), X + 0.6, sd + 0.4, 1.8, 0.5, 0.25, TILE_C, Kit.TILE, wall_cols[3], Kit.MUDBRICK)
	for s: float in [-1.0, 1.0]:
		var xw0: float = xl if s < 0 else cx1
		var xw1: float = cx0 if s < 0 else xr
		kc.box(Vector3((xw0 + xw1) * 0.5, ytop, (cz0 + cz1) * 0.5), Vector3(xw1 - xw0 + 0.5, 0.3, cz1 - cz0 + 0.5), TILE_C, Kit.TILE, 0.0, true)
	kc.box(Vector3(0, ytop, (-Z * 0.5 + cz0) * 0.5), Vector3(X + 0.5, 0.3, cz0 + Z * 0.5 + 0.5), TILE_C, Kit.TILE, 0.0, true)
	kc.box(Vector3(0, ytop, (cz0 + cz1) * 0.5), Vector3(cx1 - cx0 - 2.0 * balc + 0.0, 0.0, 0.0), TILE_C, Kit.TILE, 0.0, true)
	lights.append({"pos": Vector3(0, ys[2], (cz0 + cz1) * 0.5), "colour": Color(0.80, 0.88, 1.0), "energy": 1.6, "range": 16.0, "kind": "sky"})
	# camera points
	var spawn := look(Vector3(xl + 4.0, EYE, zf + 5.0), Vector3(xl + 8.0, 6.0, zf))
	var xm: float = (bays[1] + bays[2]) * 0.5
	var views := [
		["street", spawn],
		["taberna", look(Vector3(xm, EYE, zf - 0.8), Vector3(xm, 1.8, zb))],
		["mezzanine", look(Vector3(xm, 2.75 + EYE, zb + 2.8), Vector3(xm, 2.8, zf - 0.5))],
		["stair", look(Vector3(sx0 + 0.6, EYE, zb + 0.5), Vector3(sx0 + 0.6, 4.0, zf - 1.0))],
		["flat_1", look(Vector3((bays[2] + bays[3]) * 0.5, ys[1] + EYE, zf - 0.8), Vector3((bays[2] + bays[3]) * 0.5, ys[1] + 1.3, zb))],
		["flat_3", look(Vector3((bays[2] + bays[3]) * 0.5, ys[3] + EYE, zf - 0.8), Vector3((bays[2] + bays[3]) * 0.5, ys[3] + 1.0, zb))],
		["courtyard", look(Vector3(0, EYE, cz1 - 1.0), Vector3(0, 5.0, cz0))],
		["overview", look(Vector3(X * 0.7, Z * 1.5, -Z * 0.9), Vector3(0, 4.0, 0))],
	]
	var seats := {"taberna": views[1][1], "mezzanine": views[2][1], "flat_1": views[4][1], "flat_3": views[5][1], "courtyard": views[6][1]}
	var notes := [
		"Walls on the street no thicker than 1.5 Roman feet by law, so the tall houses are carried on piers and tied with the timbers of the floors, and the people are lodged by height: Vitruvius 2.8.17. Read.",
		"Shops with mezzanines, the stair, the courtyard with balconies, flats poorer the higher you go (plaster with a painted dado, whitewash, then bare mud-brick and straw): from Ostia and the satirists (Juvenal 3.190-202, Martial) # unverified (not read); the plan is conjecture.",
		"Storey heights 4.4 / 3.4 / 3.2 / 3.0 m (about 14 m); the Augustan limit of 70 ft (Strabo 5.3.7) # unverified.",
		"Thermopolium counters with dolia follow Pompeii and Ostia. # unverified for Rome",
	]
	return _pack(k, kc, lights, spawn, seats, views, notes, {"anchors": {"door": Vector3(xe, 0, zf), "courtyard": Vector3(0, 0, (cz0 + cz1) * 0.5), "stair": Vector3(sx0 + 0.6, 0, zb + 0.5)}, "floor_y": 0.0})
