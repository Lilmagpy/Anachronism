## Urbs (U8): the civic buildings and the furniture of the Forum, from their published remains.
##
##   plaza            the paved Forum: travertine slabs in staggered courses, three tones, joints
##   lacus_curtius    the trapezoidal travertine field with its curb, screen, puteal on a twelve-
##                    sided base and the bases of the arae siccae; beside it, from 86 BC, the plot
##                    of the Marsyas with the fig, the olive and the vine
##   rostra           the Republican Rostra: platform faced with the beaks of the Antium ships,
##                    a straight flight up from the Comitium, statues (Sulla's gilt equestrian
##                    statue from 80 BC, Pompey's, others: Cic. Phil. 9.16)
##   rostra_augusti   the Rostra of Caesar and Augustus: a 24 m front 3 m high, marble-faced, two
##                    rows of bronze beaks, a balustrade with a central opening, curved steps behind
##   column_monument  the rostral column of Duilius; column_honorific a plain honorific column
##   curia            the senate house: brick-faced concrete under stucco, corner buttresses,
##                    marble dado, steps to a bronze door, three great windows, consoles and cornice
##   basilica, basilica_travertine   nave, two-storeyed aisles and galleries, clerestory; plan
##                    `open` (Basilica Iulia: arcades all round) or `portico` (Basilica Aemilia:
##                    a two-storeyed portico with tabernae across the front, shields hung above)
##   tabularium       substructure with six narrow windows, the gallery of eleven arches with
##                    engaged Doric half-columns, the halls behind
##   comitium         the circular stepped place of assembly
##
## Sources read for this file (Platner-Ashby, 1929, archive.org text): s.v. Rostra, Rostra
## Augusti, Lacus Curtius, Ficus Olea Vitis, Statua Marsyae, Statua Sullae, Statua Pompeii,
## Columna Maenia, Columna Rostrata C. Duilii, Curia Iulia, Basilica Aemilia, Basilica Iulia,
## Tabularium, Comitium; Vitruvius 5.1 (the basilica; Perseus). Sizes they do not give carry
## `# unverified`.
class_name UrbsCivic
extends RefCounted

const MM := preload("res://scripts/urbs/monument_mesh.gd")
const Orders := preload("res://scripts/urbs/monument_orders.gd")

const MODELS := ["plaza", "lacus_curtius", "rostra", "rostra_augusti", "column_monument", "column_honorific",
	"curia", "basilica", "basilica_travertine", "tabularium", "comitium", "portico_enclosure"]

## Surfaces of the basilicas and the curia by material set.
const SETS := {
	"tufa": {"pier": "tufa_yellow", "col": "stucco_white", "wall": "stucco_white", "trim": "travertine", "floor": "tufa_brown"},
	"travertine": {"pier": "travertine", "col": "travertine", "wall": "stucco_white", "trim": "travertine", "floor": "travertine"},
	"marble": {"pier": "marble_luna", "col": "marble_luna", "wall": "stucco_white", "trim": "marble_luna", "floor": "marble_luna"},
}

static var _beak_mesh: ArrayMesh


static func handles(model: String) -> bool:
	return MODELS.has(model)


## The spec of a civic monument: footprint, height, year, variant, and the record's
## `architecture` block for the model.
static func spec(model: String, rec: Dictionary, st: Dictionary) -> Dictionary:
	var s := {"model": model, "id": str(rec.get("id", "")), "W": float(st.get("width", 0.0)), "L": float(st.get("length", 0.0)),
		"R": float(st.get("radius", 0.0)), "H": float(st.get("height", 0.0)), "year": int(st.get("year", 0)),
		"variant": str(st.get("variant", "")), "skirt": float(st.get("skirt", 0.0)), "state": str(st.get("state", "standing")),
		"surface": str(rec.get("surface", "travertine"))}
	var arch: Variant = rec.get("architecture")
	if arch is Dictionary and (arch as Dictionary).has(model):
		for k in (arch[model] as Dictionary):
			s[k] = arch[model][k]
	return s


static func build(s: Dictionary, lod: int) -> Dictionary:
	var mm := MM.new()
	match str(s.model):
		"plaza": _plaza(mm, s, lod)
		"lacus_curtius": _lacus_curtius(mm, s, lod)
		"rostra": _rostra(mm, s, lod)
		"rostra_augusti": _rostra_augusti(mm, s, lod)
		"column_monument": _column(mm, s, lod, true)
		"column_honorific": _column(mm, s, lod, false)
		"curia": _curia(mm, s, lod)
		"basilica", "basilica_travertine": _basilica(mm, s, lod)
		"tabularium": _tabularium(mm, s, lod)
		"comitium": _comitium(mm, s, lod)
		"portico_enclosure": _portico_enclosure(mm, s, lod)
	return mm.finish()


static func _h(x: int, y: int, salt := 0) -> int:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return absi(h)


# --- the paved Forum ------------------------------------------------------------------------------


## The Forum's paving: travertine slabs in courses along the long axis (z), staggered, each one
## of three tones, with joints of packed earth between them. Slab size about 1.5 x 3 m
## (# unverified: the Augustan paving's slabs vary). The paving sits on the highest point of the
## ground under it; a kerb steps down to the ground round its edge.
static func _plaza(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var W := maxf(float(s.W), 4.0)
	var L := maxf(float(s.L), 4.0)
	var skirt := float(s.skirt) + 0.3
	var surf := str(s.get("surface", "travertine"))
	if surf == "black":
		# the Lapis Niger: black marble paving (Platner-Ashby s.v. Lapis Niger) within a kerb
		mm.ext(-W / 2, -skirt, -L / 2, W / 2, 0.06, L / 2, "basalt")
		mm.ring(0.0, 0.0, W / 2 + 0.25, L / 2 + 0.25, 0.25, -skirt, 0.35, "travertine")
		mm.open(Vector3(0, -skirt, 0), Vector3(W, skirt, L))
		return
	if surf == "earth":
		mm.ext(-W / 2, -skirt, -L / 2, W / 2, 0.02, L / 2, "earth_packed")
		mm.open(Vector3(0, -skirt, 0), Vector3(W, skirt, L))
		return
	var tones := ["forum_travertine", "travertine", "limestone_steps"]
	# the bed and the kerb
	mm.ext(-W / 2, -skirt, -L / 2, W / 2, -0.02, L / 2, "earth_packed")
	mm.ring(0.0, 0.0, W / 2 + 0.3, L / 2 + 0.3, 0.3, -skirt, 0.08, "travertine")
	if lod >= 2:
		mm.ext(-W / 2, -0.02, -L / 2, W / 2, 0.08, L / 2, "forum_travertine")
	else:
		var sw := 1.5 if lod == 0 else 6.0     # across
		var sl := 3.0 if lod == 0 else 9.0     # along the axis
		var joint := 0.035 if lod == 0 else 0.0
		var nx := int(ceil(W / sw))
		var nz := int(ceil(L / sl))
		for i in nx:
			var x0 := -W / 2 + i * sw
			var x1 := minf(W / 2, x0 + sw)
			var stagger := sl * 0.5 if i % 2 == 1 else 0.0
			var z := -L / 2 - stagger
			var j := 0
			while z < L / 2:
				var z0 := maxf(-L / 2, z)
				var z1 := minf(L / 2, z + sl)
				if z1 - z0 > 0.05:
					var tone: String = tones[_h(i, j, 7) % 3]
					mm.ext(x0 + joint * 0.5, -0.02, z0 + joint * 0.5, x1 - joint * 0.5, 0.08, z1 - joint * 0.5, tone)
				z += sl
				j += 1
	mm.open(Vector3(0, -skirt, 0), Vector3(W, skirt + 0.08, L))


## The Lacus Curtius (Platner-Ashby s.v., read): an irregularly trapezoidal field about 10 m long
## and nearly 9 in greatest width, of tufa slabs under a layer of travertine blocks with a curb;
## marks on the curb for a screen or balustrade; traces of rectangular bases on the western part
## (the arae siccae of Ovid); near the eastern corner the plinth of a puteal or round altar of
## cappellaccio on a twelve-sided base. Next to it (from 86 BC, the coins of L. Marcius
## Censorinus; how long before is not known) the open plot about 4 m square where the statue of
## Marsyas stood on a square pedestal with the fig, the olive and the vine (s.v. Statua Marsyae,
## Ficus Olea Vitis); the plot's exact spot is # unverified. Local +x here is west (bearing 0).
static func _lacus_curtius(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var L := maxf(float(s.L), 10.0)
	var W := maxf(float(s.W), 9.0)
	var skirt := float(s.skirt) + 0.3
	var y := 0.22
	# the trapezoid: full width at the west (+x local), narrower to the east
	var pts := [Vector3(W / 2, y, -L / 2), Vector3(W / 2, y, L / 2), Vector3(-W / 2, y, L / 2 - 1.2), Vector3(-W / 2, y, -L / 2 + 1.6)]
	var lo := pts.map(func(p: Vector3) -> Vector3: return Vector3(p.x, -skirt, p.z))
	var c := Vector3(0, -0.5, 0)
	mm.polygon(pts, "travertine", c)
	for i in 4:
		var j := (i + 1) % 4
		mm.quad(lo[i], lo[j], pts[j], pts[i], "tufa_grey", c)
	if lod < 2:
		# the curb and the screen on it
		for i in 4:
			var j := (i + 1) % 4
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[j]
			mm.rod(a + Vector3(0, 0.12, 0), b + Vector3(0, 0.12, 0), 0.14, "travertine")
			if lod == 0:
				var n := int(a.distance_to(b) / 1.1)
				for k in n + 1:
					var p := a.lerp(b, float(k) / maxf(n, 1))
					mm.box(p + Vector3(0, 0.25, 0), Vector3(0.12, 0.85, 0.12), "marble_luna")
				mm.rod(a + Vector3(0, 1.1, 0), b + Vector3(0, 1.1, 0), 0.06, "marble_luna")
		# the puteal (round altar of cappellaccio) on its twelve-sided base, near the east corner
		var pe := Vector3(-W / 2 + 1.6, y, -L / 2 + 2.6)
		mm.cylinder(pe, 0.95, 0.25, "tufa_brown", 12)
		mm.lathe(pe + Vector3(0, 0.25, 0), PackedVector2Array([Vector2(0.62, 0.0), Vector2(0.6, 0.12), Vector2(0.52, 0.2), Vector2(0.52, 0.72),
			Vector2(0.6, 0.8), Vector2(0.62, 0.92), Vector2(0.45, 0.94)]), "tufa_brown", 16 if lod == 0 else 8)
		# bases of the arae siccae on the western part
		for k in 2:
			mm.box(Vector3(W / 2 - 1.6, y, -1.6 + k * 3.2), Vector3(1.2, 0.45, 1.6), "tufa_grey")
	mm.open(Vector3(0, -skirt, 0), Vector3(W, skirt + y, L))
	if int(s.year) >= -86:
		_marsyas_plot(mm, Vector3(-W / 2 - 3.5, 0.0, 0.0), lod)


## The plot of the Marsyas: unpaved earth 4 m square inside a low kerb, the satyr on a square
## pedestal, right foot forward, a wine-skin on the left shoulder, right hand raised (coins of
## Censorinus, Platner-Ashby s.v. Statua Marsyae), with the fig, the olive and the vine.
static func _marsyas_plot(mm: UrbsMonumentMesh, at: Vector3, lod: int) -> void:
	mm.push(MM.at(at))
	mm.ext(-2.0, -0.3, -2.0, 2.0, 0.04, 2.0, "garden_bed")
	mm.ring(0.0, 0.0, 2.1, 2.1, 0.2, -0.3, 0.25, "travertine")
	mm.box(Vector3(0.8, 0.0, 0.8), Vector3(1.0, 1.4, 1.0), "marble_luna")
	Orders.statue(mm, Vector3(0.8, 1.4, 0.8), 1.9, "statue_bronze", 1.0)
	if lod < 2:
		mm.box(Vector3(1.0, 2.2, 0.75), Vector3(0.35, 0.5, 0.3), "statue_bronze")   # the wine-skin
		_tree(mm, Vector3(-1.1, 0.0, -1.0), 5.5, 2.4, lod)    # the fig
		_tree(mm, Vector3(-1.2, 0.0, 1.1), 4.5, 1.8, lod)     # the olive
		# the vine on a pole
		mm.cylinder(Vector3(1.4, 0.0, -1.4), 0.06, 2.4, "timber_weathered", 5)
		mm.lathe(Vector3(1.4, 1.0, -1.4), PackedVector2Array([Vector2(0.15, 0.0), Vector2(0.55, 0.5), Vector2(0.5, 1.2), Vector2(0.001, 1.7)]), "grass", 7)
	mm.solid(Vector3(0.8, 0.0, 0.8), Vector3(1.0, 3.3, 1.0))
	mm.pop()


## A small tree: a trunk and a crown of a few lumps (fig, olive).
static func _tree(mm: UrbsMonumentMesh, foot: Vector3, h: float, r: float, lod: int) -> void:
	mm.frustum(foot, 0.16, 0.1, h * 0.5, "timber_weathered", 6, false)
	var sides := 8 if lod == 0 else 6
	for k in 3:
		var a := k * TAU / 3.0
		var p := foot + Vector3(cos(a) * r * 0.35, h * 0.45, sin(a) * r * 0.35)
		mm.lathe(p, PackedVector2Array([Vector2(0.001, 0.0), Vector2(r * 0.6, r * 0.25), Vector2(r * 0.65, r * 0.6), Vector2(r * 0.35, r * 0.95), Vector2(0.001, r * 1.05)]), "grass", sides)


# --- the Rostra ------------------------------------------------------------------------------------


## A bronze ram (rostrum) pointing +z: a tapering body with three horizontal fins, about 1.4 m
## long (# unverified: the Antium rams are lost; the Athlit ram is 2.26 m).
static func beak_mesh() -> ArrayMesh:
	if _beak_mesh != null:
		return _beak_mesh
	var mm := MM.new()
	mm.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO))
	mm.frustum(Vector3(0, 0, 0), 0.32, 0.08, 1.35, "bronze", 8, true, true)
	mm.pop()
	for k in 3:
		var y := (k - 1) * 0.2
		mm.slab([Vector3(-0.42, y + 0.025, 0.0), Vector3(0.42, y + 0.025, 0.0), Vector3(0.06, y + 0.025, 1.3), Vector3(-0.06, y + 0.025, 1.3)], 0.05, "bronze")
	mm.ext(-0.45, -0.45, -0.1, 0.45, 0.45, 0.06, "bronze_verdigris")   # the cowl on the wall
	_beak_mesh = mm.finish_mesh()
	return _beak_mesh


## A row of beaks along x at height y on the face z (pointing +z).
static func _beaks(mm: UrbsMonumentMesh, x0: float, x1: float, n: int, y: float, z: float) -> void:
	var mesh := beak_mesh()
	for i in n:
		var x := lerpf(x0, x1, (i + 0.5) / n)
		mm.instance("beak", mesh, Transform3D(Basis.IDENTITY, Vector3(x, y, z)))


## An equestrian statue on a pedestal, the horse walking towards +z.
static func equestrian(mm: UrbsMonumentMesh, foot: Vector3, mat: String, ped_mat: String, lod: int) -> void:
	mm.push(MM.at(foot))
	mm.box(Vector3(0, 0, 0), Vector3(1.4, 1.7, 3.0), ped_mat)
	mm.box(Vector3(0, 1.7, 0), Vector3(1.55, 0.18, 3.15), ped_mat)
	var y := 1.88
	if lod < 2:
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var top := Vector3(sx * 0.25, y + 1.3, sz * 0.8)
				var hoof := Vector3(sx * 0.27, y, sz * 0.85 + (0.25 if sz > 0 and sx > 0 else 0.0))
				mm.rod(hoof, top, 0.07, mat)
	mm.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, y + 1.55, -1.05)))
	mm.frustum(Vector3.ZERO, 0.42, 0.38, 2.1, mat, 8, true, true)    # the barrel
	mm.pop()
	mm.rod(Vector3(0, y + 1.6, 0.9), Vector3(0, y + 2.4, 1.35), 0.2, mat)     # the neck
	mm.box(Vector3(0, y + 2.2, 1.55), Vector3(0.26, 0.4, 0.65), mat)          # the head
	mm.rod(Vector3(0, y + 1.6, -1.1), Vector3(0, y + 0.8, -1.4), 0.07, mat)   # the tail
	Orders.statue(mm, Vector3(0, y + 1.85, 0.05), 1.6, mat, 1.0)              # the rider
	mm.solid(Vector3.ZERO, Vector3(1.55, 5.6, 3.2))
	mm.pop()


## The Republican Rostra (front +z, towards the Forum): a platform `H` high faced with tufa, the
## beaks along its front (their number is not recorded: six, # unverified), a straight flight of
## steps up from the Comitium behind, a parapet, statues: Sulla's gilt equestrian statue from 80
## BC (s.v. Statua Sullae), Pompey's standing statue (s.v. Statua Pompeii), and three more of the
## famous men whose statues crowded it (Cic. Phil. 9.16, via s.v. Rostra).
static func _rostra(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var W := maxf(float(s.W), 8.0)
	var L := maxf(float(s.L), 6.0)
	var H := maxf(float(s.H), 1.5)
	var skirt := float(s.skirt)
	var stair_d := minf(L * 0.4, 3.6)
	var z0 := -L / 2 + stair_d
	var z1 := L / 2
	mm.ext(-W / 2, -skirt, z0, W / 2, H - 0.3, z1, "tufa_brown")
	mm.ext(-W / 2 - 0.15, H - 0.3, z0 - 0.1, W / 2 + 0.15, H, z1 + 0.15, "tufa_grey")
	mm.ext(-W / 2 - 0.2, -skirt, z1 - 0.1, W / 2 + 0.2, 0.35, z1 + 0.3, "tufa_grey")   # the plinth
	mm.push(MM.at(Vector3(0, 0, z0), PI))
	mm.stair(0.0, W * 0.5, 0.0, H, "tufa_grey", 0.32)
	mm.pop()
	_beaks(mm, -W / 2 + 0.5, W / 2 - 0.5, 6, H * 0.5, z1)
	mm.solid(Vector3(0, -skirt, (z0 + z1) * 0.5), Vector3(W, H + skirt, z1 - z0))
	if lod < 2:
		# a low parapet round the platform, open at the back
		mm.ext(-W / 2, H, z1 - 0.3, W / 2, H + 0.9, z1, "tufa_grey")
		for sx: float in [-1.0, 1.0]:
			mm.ext(sx * W / 2 - (0.3 if sx > 0 else 0.0), H, z0, sx * W / 2 + (0.0 if sx > 0 else 0.3), H + 0.9, z1, "tufa_grey")
	var y := int(s.year)
	if y >= -80:
		equestrian(mm, Vector3(-W * 0.25, H, (z0 + z1) * 0.5), "gilt", "marble_luna", lod)
	var spots := [Vector3(W * 0.12, H, z0 + 1.0), Vector3(W * 0.3, H, z0 + 1.0), Vector3(W * 0.42, H, (z0 + z1) * 0.5), Vector3(-W * 0.42, H, z0 + 1.0)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		mm.box(p, Vector3(0.9, 1.1, 0.9), "marble_luna")
		Orders.statue(mm, p + Vector3(0, 1.1, 0), 2.1, "statue_bronze", 1.0)


## The Rostra of Caesar and Augustus (front +z, ESE; Platner-Ashby s.v. Rostra Augusti, read):
## the platform 10 m deep from the western wall, its front about 24 m long and 3 m high, of tufa
## blocks faced with marble, bronze beaks in two rows let into the facing (how many is not
## recorded: 2 x 9, # unverified), travertine paving, a marble balustrade along the sides and
## front with an opening in the middle; behind, the curved flight of steps on the west across
## the whole length. Statues stood on it (Tac. Ann. 4.67): generic figures here.
static func _rostra_augusti(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var W := maxf(float(s.W), 24.0)
	var L := maxf(float(s.L), 14.0)
	var H := maxf(float(s.H), 3.0)
	var skirt := float(s.skirt)
	var z1 := L / 2
	var z0 := z1 - 10.0
	mm.ext(-W / 2, -skirt, z0, W / 2, H - 0.35, z1, "opus_quadratum")
	# the marble facing of front and sides, then the cornice
	mm.ext(-W / 2 - 0.12, -skirt, z1 - 0.2, W / 2 + 0.12, H - 0.35, z1 + 0.12, "marble_luna")
	for sx: float in [-1.0, 1.0]:
		mm.ext(sx * W / 2 - 0.12, -skirt, z0, sx * W / 2 + 0.12, H - 0.35, z1, "marble_luna")
	mm.ext(-W / 2 - 0.3, H - 0.35, z0, W / 2 + 0.3, H, z1 + 0.3, "marble_luna")
	mm.ext(-W / 2, H - 0.02, z0, W / 2, H + 0.04, z1, "travertine")
	_beaks(mm, -W / 2 + 0.8, W / 2 - 0.8, 9, H * 0.68, z1 + 0.12)
	_beaks(mm, -W / 2 + 2.0, W / 2 - 2.0, 9, H * 0.3, z1 + 0.12)
	mm.solid(Vector3(0, -skirt, (z0 + z1) * 0.5), Vector3(W, H + skirt, z1 - z0))
	# the curved steps behind, across the whole length: arcs centred well in front
	var steps := 12
	var R := W * 0.62
	var cz := z0 + R - 4.0
	var span := asin(clampf((W * 0.5) / R, 0.0, 1.0))
	var segs := 14 if lod == 0 else 6
	for k in steps:
		var top := H * (k + 1) / steps
		var r_out := R - (steps - k) * (4.0 / steps) + 4.0 / steps
		for g in segs:
			var a0 := -span + 2.0 * span * g / segs
			var a1 := -span + 2.0 * span * (g + 1) / segs
			var am := (a0 + a1) * 0.5
			var chord := 2.0 * r_out * sin((a1 - a0) * 0.5) + 0.05
			var p := Vector3(sin(am) * r_out, -skirt, cz - cos(am) * r_out)
			var depth := 4.0 / steps * (steps - k)
			mm.push(MM.at(p, -am))
			mm.box(Vector3(0, 0, depth * 0.5), Vector3(chord, top + skirt, depth), "marble_luna" if lod == 0 else "travertine")
			mm.pop()
	if lod < 2:
		# the balustrade with its opening in the middle of the front
		var bh := 1.0
		for seg: Array in [[-W / 2, -2.0], [2.0, W / 2]]:
			mm.ext(float(seg[0]), H, z1 - 0.25, float(seg[1]), H + 0.15, z1, "marble_luna")
			mm.ext(float(seg[0]), H + bh - 0.12, z1 - 0.3, float(seg[1]), H + bh, z1 + 0.02, "marble_luna")
			if lod == 0:
				var n := int((float(seg[1]) - float(seg[0])) / 0.45)
				for i in n:
					var x := float(seg[0]) + (i + 0.5) * (float(seg[1]) - float(seg[0])) / n
					mm.lathe(Vector3(x, H + 0.15, z1 - 0.13), PackedVector2Array([Vector2(0.09, 0.0), Vector2(0.14, 0.3), Vector2(0.07, 0.55), Vector2(0.09, 0.73)]), "marble_luna", 6, false)
			else:
				mm.ext(float(seg[0]), H + 0.15, z1 - 0.2, float(seg[1]), H + bh - 0.12, z1 - 0.05, "marble_luna")
		for sx: float in [-1.0, 1.0]:
			mm.ext(sx * W / 2 - 0.15, H, z0, sx * W / 2 + 0.15, H + bh, z1, "marble_luna")
	for x: float in [-W * 0.32, -W * 0.12, W * 0.12, W * 0.32]:
		mm.box(Vector3(x, H, z0 + 3.0), Vector3(1.0, 1.4, 1.0), "marble_luna")
		Orders.statue(mm, Vector3(x, H + 1.4, z0 + 3.0), 2.3, "statue_bronze" if x < 0.0 else "statue_marble", 1.0)


# --- honorific columns ---------------------------------------------------------------------------


## An honorific column: a moulded pedestal, a column, a statue on top (the honour of a column was
## to raise the honoured man's statue above everyone: Pliny NH 34.20 as summarised by
## Platner-Ashby s.v. Columna Maenia; the statues themselves # unverified). `rostral`: the column of
## Duilius, set with the beaks of the Carthaginian ships in pairs (s.v. Columna Rostrata C.
## Duilii); its order and height # unverified.
static func _column(mm: UrbsMonumentMesh, s: Dictionary, lod: int, rostral: bool) -> void:
	var H := maxf(float(s.H), 8.0)
	var ped := H * 0.18
	var col_h := H * 0.68
	var d := col_h / 8.0
	var mat := "marble_luna" if int(s.year) >= -150 else "travertine"
	mm.box(Vector3.ZERO, Vector3(d * 2.6, 0.3, d * 2.6), "tufa_grey")
	mm.box(Vector3(0, 0.3, 0), Vector3(d * 2.2, ped - 0.6, d * 2.2), mat)
	mm.box(Vector3(0, ped - 0.3, 0), Vector3(d * 2.5, 0.3, d * 2.5), mat)
	Orders.column(mm, Vector3(0, ped, 0), col_h, "doric" if rostral else "tuscan", mat, lod, d)
	if rostral and lod < 2:
		var mesh := beak_mesh()
		for k in 3:
			var y := ped + col_h * (0.22 + 0.24 * k)
			for q in 4:
				var a := q * PI / 2.0 + (PI / 4.0 if k % 2 == 1 else 0.0)
				var b := Basis(Vector3.UP, a) * Basis.from_scale(Vector3(0.55, 0.55, 0.55))
				mm.instance("beak_small", mesh, Transform3D(b, Vector3(sin(a) * d * 0.45, y, cos(a) * d * 0.45)))
	mm.box(Vector3(0, ped + col_h, 0), Vector3(d * 1.1, 0.25, d * 1.1), mat)
	Orders.statue(mm, Vector3(0, ped + col_h + 0.25, 0), H - ped - col_h - 0.25, "statue_bronze" if not rostral else "gilt", 1.0)
	mm.solid(Vector3.ZERO, Vector3(d * 2.6, H, d * 2.6))


# --- the Curia ------------------------------------------------------------------------------------


## The Curia (Platner-Ashby s.v. Curia Iulia, read): a hall of brick-faced concrete with a huge
## buttress at each angle; the lower part of the front wall faced with marble slabs, the upper
## part and the flanks in stucco imitating white marble blocks; travertine consoles carrying a
## brick cornice, continued round the triangular pediment, all stuccoed; a flight of steps up to
## the entrance door; three large windows over the door. `H` is the height to the eaves (21 m in
## the dataset). The Curia Hostilia (until 52/45 BC) is drawn with the same plan in stuccoed tufa
## (its form # unverified; Livy 1.48: approached by a flight of steps).
static func _curia(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var W := maxf(float(s.W), 12.0)
	var L := maxf(float(s.L), 12.0)
	var H := maxf(float(s.H), 12.0)
	var iulia := str(s.id).begins_with("curia_iulia")
	var wall := "stucco_white" if iulia else "stucco_cream"
	var base := "travertine" if iulia else "tufa_yellow"
	var skirt := float(s.skirt)
	var pod := 1.2
	var zf := L / 2 - 3.2    # the front wall; the steps run out to the footprint's edge
	var z0 := -L / 2
	mm.ext(-W / 2 - 0.3, -skirt, z0 - 0.3, W / 2 + 0.3, pod, zf + 0.3, base)
	mm.stair(0.0, W * 0.4, zf + 0.3, pod, base, 0.55)
	# the hall
	mm.ext(-W / 2, pod, z0, W / 2, pod + H, zf, wall)
	mm.solid(Vector3(0, -skirt, (z0 + zf) * 0.5), Vector3(W + 0.6, H + pod + skirt, zf - z0 + 0.6))
	if lod < 2:
		# the marble dado of the front, the buttresses at the angles
		mm.ext(-W / 2, pod, zf, W / 2, pod + H * 0.3, zf + 0.15, "marble_luna" if iulia else wall)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var zc := zf if sz > 0.0 else z0
				mm.ext(sx * W / 2 - (1.6 if sx > 0 else -0.4), pod, zc - (0.4 if sz < 0 else 1.2), sx * W / 2 + (0.4 if sx > 0 else -1.6), pod + H, zc + (0.4 if sz > 0 else 1.2), wall)
		# the cornice on its consoles
		mm.ext(-W / 2 - 0.5, pod + H - 0.2, z0 - 0.5, W / 2 + 0.5, pod + H + 0.45, zf + 0.5, wall)
		if lod == 0:
			var n := int(W / 1.4)
			for i in n + 1:
				var x := -W / 2 + i * W / n
				mm.box(Vector3(x, pod + H - 0.75, zf + 0.25), Vector3(0.25, 0.55, 0.5), "travertine")
			var m2 := int((zf - z0) / 1.4)
			for sx: float in [-1.0, 1.0]:
				for i in m2 + 1:
					mm.box(Vector3(sx * (W / 2 + 0.25), pod + H - 0.75, z0 + i * (zf - z0) / m2), Vector3(0.5, 0.55, 0.25), "travertine")
	# the door, and the three great windows over it
	var dw := minf(3.4, W * 0.16)
	var dh := minf(H * 0.36, dw * 2.0)
	mm.push(MM.at(Vector3(0, pod, zf + 0.15)))
	Orders.door(mm, Vector3.ZERO, dw, dh, "travertine" if iulia else base, "door_bronze_studded", lod, 0.6)
	mm.pop()
	if lod < 2:
		for x: float in [-W * 0.27, 0.0, W * 0.27]:
			mm.push(MM.at(Vector3(x, pod + H * 0.52, zf + 0.15)))
			Orders.window(mm, Vector3.ZERO, W * 0.14, H * 0.36, "travertine", "grille", lod)
			mm.pop()
	# the pediment and the roof, ridge along z
	var rise := W * 0.16
	Orders.pediment(mm, -W / 2 - 0.5, W / 2 + 0.5, zf + 0.5, pod + H + 0.45, true, 0.9, wall, wall, "statue_marble", lod, false, rise, 0.0)
	Orders.pediment(mm, -W / 2 - 0.5, W / 2 + 0.5, z0 - 0.5, pod + H + 0.45, false, 0.9, wall, wall, "statue_marble", lod, false, rise, 0.0)
	mm.push(Transform3D(Basis(Vector3.UP, 0.0), Vector3.ZERO))
	Orders.roof(mm, -W / 2 - 0.5, W / 2 + 0.5, z0 - 0.5 + 0.45, zf + 0.5 - 0.45, pod + H + 0.5, rise, 0.25, lod, "tegulae")
	mm.pop()


# --- the basilicas ---------------------------------------------------------------------------------


## A Roman basilica (Vitruvius 5.1.4-5, read: the width a third to a half of the length, the
## aisles a third of the nave's width, the upper columns smaller, a screen between the storeys,
## light let in between the upper columns). The long side (x, `W`) faces the Forum (+z).
## plan `open` (Basilica Iulia, Platner-Ashby s.v., read: 101 x 49 m, a central court 82 x 16
## surrounded on all sides by two aisles 7.50 m wide with galleries above; the facade an open
## arcade of marble pillars, eighteen on each long side and eight on the ends, joined by marble
## balustrades; the court rose above the aisles' roofs and was lit by windows; steps down from
## the outer aisle to the street) or `portico` (Basilica Aemilia, s.v., read: a two-storeyed
## porticus with shields hung on it on the coin of Lepidus, c. 65 BC; behind it the tabernae on
## the Forum side and the hall). Storey heights are not published: 10 m and 8 m, # unverified.
static func _basilica(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var W := maxf(float(s.W), 30.0)
	var L := maxf(float(s.L), 18.0)
	var plan := str(s.get("plan", "open" if str(s.model) == "basilica_travertine" else "portico"))
	var set_name := str(s.get("mat", "travertine" if str(s.model) == "basilica_travertine" else "tufa"))
	var m: Dictionary = SETS.get(set_name, SETS["tufa"])
	var skirt := float(s.skirt)
	var pod := float(s.get("podium_h_m", 1.2))
	var h1 := float(s.get("storey1_h_m", 10.0))
	var h2 := float(s.get("storey2_h_m", 8.0))
	var nave_w := float(s.get("nave_w_m", L * 0.36))
	var aisles := int(s.get("aisles", 2 if plan == "open" else 1))
	var aisle_w := (L - nave_w) / (2.0 * aisles)
	var n_long := int(s.get("piers_long", maxi(6, int(W / 6.0))))
	var n_short := int(s.get("piers_short", maxi(3, int(L / 6.0))))
	var steps_d := 2.0
	var x0 := -W / 2 + (steps_d if plan == "open" else 0.0)
	var x1 := W / 2 - (steps_d if plan == "open" else 0.0)
	var z0 := -L / 2 + (steps_d if plan == "open" else 0.0)
	var z1 := L / 2 - steps_d
	# the platform and its steps (front; all round for the open plan)
	mm.ext(x0, -skirt, z0, x1, pod, z1, str(m.floor))
	mm.stair(0.0, x1 - x0, z1, pod, str(m.floor), steps_d / maxf(1.0, round(pod / 0.24)))
	if plan == "open":
		for sx: float in [-1.0, 1.0]:
			mm.push(MM.at(Vector3(sx * x1, 0, 0), sx * PI / 2.0))
			mm.stair(0.0, z1 - z0, 0.0, pod, str(m.floor), steps_d / maxf(1.0, round(pod / 0.24)))
			mm.pop()
	var y1 := pod + h1
	var y2 := y1 + h2
	var yc := y2 + h2 * 0.85      # the top of the clerestory
	var dx := x1 - x0
	var dz := z1 - z0
	mm.solid(Vector3(0, -skirt, (z0 + z1) * 0.5), Vector3(dx, pod + skirt, dz))
	# the nave's clerestory walls and windows, and its roof (ridge along x)
	var nz0 := (z0 + z1) * 0.5 - nave_w * 0.5
	var nz1 := (z0 + z1) * 0.5 + nave_w * 0.5
	var nx0 := x0 + aisle_w * aisles
	var nx1 := x1 - aisle_w * aisles
	for z: float in [nz0, nz1]:
		mm.ext(nx0, y1, z - 0.4, nx1, yc, z + 0.4, str(m.wall))
	for x: float in [nx0, nx1]:
		mm.ext(x - 0.4, y1, nz0, x + 0.4, yc, nz1, str(m.wall))
	if lod < 2:
		var nwin := int((nx1 - nx0) / 5.0)
		for zi in 2:
			var zf := nz1 + 0.4 if zi == 1 else nz0 - 0.4
			for i in nwin:
				var x := nx0 + (i + 0.5) * (nx1 - nx0) / nwin
				mm.push(MM.at(Vector3(x, y2 + 1.0, zf), 0.0 if zi == 1 else PI))
				Orders.window(mm, Vector3.ZERO, 2.0, h2 * 0.55, str(m.trim), "grille", lod)
				mm.pop()
	var nave_span := nz1 - nz0 + 0.8
	mm.push(MM.at(Vector3((nx0 + nx1) * 0.5, 0, (nz0 + nz1) * 0.5), PI / 2.0))
	Orders.roof(mm, -nave_span * 0.5, nave_span * 0.5, -(nx1 - nx0) * 0.5 - 0.4, (nx1 - nx0) * 0.5 + 0.4, yc + 0.1, nave_span * 0.2, 0.6, lod, "tegulae")
	for sz: float in [-1.0, 1.0]:   # the gable ends of the nave roof
		var zz: float = sz * ((nx1 - nx0) * 0.5 + 0.4)
		mm.polygon([Vector3(-nave_span * 0.5, yc + 0.1, zz), Vector3(nave_span * 0.5, yc + 0.1, zz), Vector3(0, yc + 0.1 + nave_span * 0.2, zz)], str(m.wall), Vector3(0, yc, 0))
	mm.pop()
	mm.solid(Vector3((nx0 + nx1) * 0.5, y1, (nz0 + nz1) * 0.5), Vector3(nx1 - nx0, yc - y1 + nave_span * 0.2, nave_w))
	# the aisles' lean-to roofs, from the outer walls up to the clerestory
	var ya := y2 + 0.6
	var yb := y2 + h2 * 0.35
	mm.slab([Vector3(x0 - 0.5, ya, z1 + 0.5), Vector3(x1 + 0.5, ya, z1 + 0.5), Vector3(nx1, yb, nz1 + 0.4), Vector3(nx0, yb, nz1 + 0.4)], 0.25, "tegulae", "timber_oak")
	mm.slab([Vector3(x1 + 0.5, ya, z0 - 0.5), Vector3(x0 - 0.5, ya, z0 - 0.5), Vector3(nx0, yb, nz0 - 0.4), Vector3(nx1, yb, nz0 - 0.4)], 0.25, "tegulae", "timber_oak")
	mm.slab([Vector3(x1 + 0.5, ya, z1 + 0.5), Vector3(x1 + 0.5, ya, z0 - 0.5), Vector3(nx1 + 0.4, yb, nz0), Vector3(nx1 + 0.4, yb, nz1)], 0.25, "tegulae", "timber_oak")
	mm.slab([Vector3(x0 - 0.5, ya, z0 - 0.5), Vector3(x0 - 0.5, ya, z1 + 0.5), Vector3(nx0 - 0.4, yb, nz1), Vector3(nx0 - 0.4, yb, nz0)], 0.25, "tegulae", "timber_oak")
	mm.solid(Vector3(0, pod, (z0 + z1) * 0.5), Vector3(dx, y2 - pod + 0.6, dz) if plan != "open" else Vector3(dx, 0.01, dz))
	# the outer walls: arcades of two storeys all round (open) or on the front only (portico)
	var sides: Array = [[Vector3(0, 0, z1), 0.0, dx, n_long]]
	if plan == "open":
		sides.append([Vector3(0, 0, z0), PI, dx, n_long])
		sides.append([Vector3(x1, 0, (z0 + z1) * 0.5), PI / 2.0, dz, n_short])
		sides.append([Vector3(x0, 0, (z0 + z1) * 0.5), -PI / 2.0, dz, n_short])
	for side: Array in sides:
		mm.push(MM.at(side[0], float(side[1])))
		_arcade_wall(mm, float(side[2]), int(side[3]), pod, h1, h2, m, lod, plan == "portico", int(s.year) >= -78 and plan == "portico")
		mm.pop()
	if plan == "open":
		# the outer arcades' solids: thin walls, so you can walk under the arches into the aisles
		for side: Array in sides:
			mm.push(MM.at(side[0], float(side[1])))
			var len := float(side[2])
			mm.solid(Vector3(-len / 2 + 0.6, pod, -0.6), Vector3(1.2, h1 + h2, 1.2))
			mm.solid(Vector3(len / 2 - 0.6, pod, -0.6), Vector3(1.2, h1 + h2, 1.2))
			mm.pop()
		# the inner rows of pillars round the court (brick faced with marble), lod 0 only
		if lod == 0:
			for k in range(1, aisles + 1):
				var inset := aisle_w * k
				var zs := [z0 + inset, z1 - inset]
				var nl := n_long - 2 * k
				for z: float in zs:
					for i in nl:
						var x := x0 + inset + i * (dx - 2.0 * inset) / maxf(nl - 1, 1)
						mm.box(Vector3(x, pod, z), Vector3(1.3, h1, 1.3), str(m.pier))
				mm.ext(x0 + inset - 0.6, y1 - 0.8, z0 + inset - 0.6, x1 - inset + 0.6, y1, z0 + inset + 0.6, str(m.pier))
				mm.ext(x0 + inset - 0.6, y1 - 0.8, z1 - inset - 0.6, x1 - inset + 0.6, y1, z1 - inset + 0.6, str(m.pier))
			# the gallery floor over the aisles
			mm.ext(x0, y1 - 0.3, z0, x1, y1, nz0, str(m.floor))
			mm.ext(x0, y1 - 0.3, nz1, x1, y1, z1, str(m.floor))
	else:
		# the hall's solid walls on the flanks and back
		mm.ext(x0, pod, z0, x1, y2 + 0.6, z0 + 0.9, str(m.wall))
		for x: float in [x0, x1 - 0.9]:
			mm.ext(x, pod, z0, x + 0.9, y2 + 0.6, z1 - 6.0, str(m.wall))
		# the front wall of the hall behind the portico, with the tabernae's doors
		mm.ext(x0, pod, z1 - 6.6, x1, y2 + 0.6, z1 - 6.0, str(m.wall))
		if lod < 2:
			var nb := n_long - 1
			for i in nb:
				var x := x0 + (i + 0.5) * dx / nb
				mm.push(MM.at(Vector3(x, pod, z1 - 6.0)))
				Orders.window(mm, Vector3(0, 0.0, 0), minf(3.2, dx / nb * 0.6), minf(4.0, h1 * 0.42), str(m.trim), "shutters", lod)
				mm.pop()
		# the portico's floor between storeys and its roof
		mm.ext(x0, y1 - 0.4, z1 - 6.0, x1, y1, z1, str(m.floor))
		mm.slab([Vector3(x0 - 0.3, y2 + 0.4, z1 + 0.6), Vector3(x1 + 0.3, y2 + 0.4, z1 + 0.6), Vector3(x1 + 0.3, y2 + 1.6, z1 - 6.6), Vector3(x0 - 0.3, y2 + 1.6, z1 - 6.6)], 0.25, "tegulae", "timber_oak")
		mm.solid(Vector3(0, pod, z1 - 3.0), Vector3(dx, 0.01, 6.0))


## One side of a basilica's outer wall: `n` pillars over `len` metres along x on the face z = 0,
## two storeys of arches between them with an engaged half-column on each pillar (Tuscan below,
## Ionic above, the upper a quarter smaller: Vitr. 5.1.5), an entablature at each storey, marble
## balustrades between the pillars (Basilica Iulia; the upper one is Vitruvius' screen, a quarter
## lower than the upper columns). `shields`: bronze shields hung in the upper arches (the coin
## of Lepidus, c. 65 BC, s.v. Basilica Aemilia).
static func _arcade_wall(mm: UrbsMonumentMesh, len: float, n: int, pod: float, h1: float, h2: float, m: Dictionary, lod: int,
		portico: bool, shields: bool) -> void:
	var bay := len / (n - 1)
	var pw := minf(bay * 0.34, 2.2)
	var depth := 1.2
	var y1 := pod + h1
	var y2 := y1 + h2
	for st in 2:
		var yb := pod if st == 0 else y1
		var hh := h1 if st == 0 else h2
		var spring := yb + hh * (0.55 if st == 0 else 0.5)
		var col_h := hh * (0.82 if st == 0 else 0.78)
		var order := "tuscan" if st == 0 else "ionic"
		var d := col_h / (7.0 if st == 0 else 9.0)
		for i in n:
			var x := -len / 2 + i * bay
			mm.box(Vector3(x, yb, -depth * 0.5), Vector3(pw, hh, depth), str(m.pier))
			if lod < 2:
				mm.instance("bcol|%s|%.2f|%.2f|%d" % [order, col_h, d, maxi(lod, 1)], Orders.column_mesh(order, col_h, str(m.col), maxi(lod, 1), d),
					Transform3D(Basis.IDENTITY, Vector3(x, yb, d * 0.15)))
		for i in n - 1:
			var xa := -len / 2 + i * bay + pw * 0.5
			var xb := -len / 2 + (i + 1) * bay - pw * 0.5
			mm.arch(xa, xb, spring, yb + hh - 0.2, -depth, 0.0, str(m.pier), 8 if lod == 0 else 4, true, true, 1.0)
			if lod < 2 and not (st == 0 and portico):
				# the balustrade between the pillars (none in the ground arcade of the portico: the
				# way into the tabernae)
				var bh := 1.1 if st == 0 else hh * 0.22
				if not (st == 0 and i == (n - 1) / 2):
					mm.ext(xa, yb, -depth * 0.6, xb, yb + bh, -depth * 0.4, str(m.trim))
			if shields and st == 1 and lod < 2:
				# a round shield about 1.1 m across hung in the arch (# unverified size)
				mm.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3((xa + xb) * 0.5, spring + 0.4, 0.05)))
				mm.frustum(Vector3.ZERO, 0.55, 0.5, 0.1, "bronze", 12, true, true)
				mm.pop()
				mm.rod(Vector3((xa + xb) * 0.5, spring + 0.95, 0.0), Vector3((xa + xb) * 0.5, spring + (xb - xa) * 0.5, -0.3), 0.02, "iron")
		# the entablature of the storey
		mm.ext(-len / 2 - pw * 0.5, yb + hh - 0.2, -depth, len / 2 + pw * 0.5, yb + hh + 0.5, d * 0.7, str(m.trim))
		mm.ext(-len / 2 - pw * 0.5 - 0.1, yb + hh + 0.5, -depth, len / 2 + pw * 0.5 + 0.1, yb + hh + 0.75, d * 0.95, str(m.trim))


# --- the Tabularium -------------------------------------------------------------------------------


## The Tabularium (Platner-Ashby s.v., read; front +z towards the Forum): the substructure wall,
## 3.43 m thick, with six recesses opening in narrow windows and the arched doorway of the stair
## of sixty-six steps; above it the gallery, 5 m wide and 10 high, open to the Forum in an arcade
## of the Doric order with engaged columns of peperino, eleven arches 7.50 m high and 3.54-3.60
## wide; behind it the halls rising up the hill. A second, Corinthian arcade over the first is
## Flavian or later (s.v.): drawn only from AD 70 (# unverified date). The substructure's height
## and the length (70 m) are # unverified.
static func _tabularium(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var W := maxf(float(s.W), 40.0)
	var L := maxf(float(s.L), 20.0)
	var skirt := float(s.skirt)
	var sub_h := float(s.get("substructure_h_m", 10.0))
	var z1 := L / 2
	var stone := "opus_quadratum"
	# substructure
	mm.ext(-W / 2, -skirt, -L / 2, W / 2, sub_h, z1, stone)
	mm.ext(-W / 2 - 0.2, sub_h - 0.5, z1 - 0.2, W / 2 + 0.2, sub_h, z1 + 0.25, "travertine")
	if lod < 2:
		for i in 6:
			var x := -W / 2 + (i + 0.5) * W / 6.0
			mm.push(MM.at(Vector3(x, sub_h * 0.45, z1)))
			Orders.window(mm, Vector3.ZERO, 0.6, 2.4, "travertine", "grille", lod)
			mm.pop()
		mm.push(MM.at(Vector3(W * 0.08, 0.0, z1)))   # the doorway of the stair up to the Capitol
		Orders.door(mm, Vector3.ZERO, 1.6, 3.2, "travertine", "timber_oak", lod, 0.8)
		mm.pop()
	mm.solid(Vector3(0, -skirt, 0), Vector3(W, sub_h + skirt, L))
	# the gallery: 11 arches between engaged Doric half-columns, the Doric entablature
	var gy := sub_h
	var gh := 10.0
	var n := 11
	var bay := W / n
	var aw := 3.57
	var ah := 7.5
	var gz := z1 - 0.2
	mm.ext(-W / 2, gy, -L / 2, W / 2, gy + gh + 1.2, gz - 5.0 - 1.0, stone)     # the inner wall of the gallery
	mm.ext(-W / 2, gy, gz - 5.0, W / 2, gy + 0.3, gz, "travertine")             # the gallery floor
	for i in n:
		var xc := -W / 2 + (i + 0.5) * bay
		var xa := xc - aw * 0.5
		var xb := xc + aw * 0.5
		mm.ext(xb, gy, gz - 1.6, xc + bay - aw * 0.5, gy + gh, gz, stone)
		if i == 0:
			mm.ext(-W / 2, gy, gz - 1.6, xa, gy + gh, gz, stone)
		mm.arch(xa, xb, gy + ah - aw * 0.5, gy + gh, gz - 1.6, gz, stone, 8 if lod == 0 else 4)
	for i in n + 1:
		var x := -W / 2 + i * bay
		if i == 0 or i == n:
			x = clampf(x, -W / 2 + 0.6, W / 2 - 0.6)
		if lod < 2:
			mm.instance("tcol|%d" % maxi(lod, 1), Orders.column_mesh("doric", gh - 1.0, "tufa_grey", maxi(lod, 1), 1.0), Transform3D(Basis.IDENTITY, Vector3(x, gy, gz + 0.3)))
	var col_xs := PackedFloat32Array()
	var ytop := Orders.entablature(mm, "doric", gh - 1.0, 1.0, -W / 2 - 0.1, W / 2 + 0.1, gz - 1.6, gz + 0.8, gy + gh - 1.0, "tufa_grey", "tufa_grey", lod, false, col_xs)
	mm.solid(Vector3(0, gy, gz - 3.0), Vector3(W, 0.01, 6.0))
	mm.solid(Vector3(0, gy, -L / 2 + (L - 6.0) * 0.5 - 1.0), Vector3(W, gh + 1.2, L - 7.0))
	# the halls behind, rising up the hill, under a tiled roof
	var hy := gy + gh + 1.2
	var hall_z0 := -L / 2
	var hall_z1 := gz - 6.0
	mm.ext(-W / 2, hy - 1.2, hall_z0, W / 2, hy + 6.0, hall_z1, stone)
	mm.push(MM.at(Vector3(0, 0, (hall_z0 + hall_z1) * 0.5), PI / 2.0))
	Orders.roof(mm, -(hall_z1 - hall_z0) * 0.5, (hall_z1 - hall_z0) * 0.5, -W / 2 - 0.3, W / 2 + 0.3, hy + 6.0, (hall_z1 - hall_z0) * 0.18, 0.5, lod, "tegulae")
	mm.pop()
	# the gallery's lean-to roof
	mm.slab([Vector3(-W / 2, ytop + 0.1, gz + 0.9), Vector3(W / 2, ytop + 0.1, gz + 0.9), Vector3(W / 2, hy + 1.5, hall_z1), Vector3(-W / 2, hy + 1.5, hall_z1)], 0.25, "tegulae", "timber_oak")
	if int(s.year) >= 70:
		var uy := ytop + 0.4
		for i in n:
			var xc := -W / 2 + (i + 0.5) * bay
			mm.arch(xc - aw * 0.45, xc + aw * 0.45, uy + 4.0, uy + 7.0, gz - 2.2, gz - 0.8, stone, 6)
		for i in n + 1:
			var x := clampf(-W / 2 + i * bay, -W / 2 + 0.6, W / 2 - 0.6)
			mm.box(Vector3(x, uy, gz - 1.5), Vector3(bay - aw * 0.9, 7.0, 1.4), stone)
	mm.solid(Vector3(0, hy - 1.2, (hall_z0 + hall_z1) * 0.5), Vector3(W, 9.0, hall_z1 - hall_z0))


# --- the Comitium ---------------------------------------------------------------------------------


## The Comitium (Platner-Ashby s.v., read): the circular place of assembly before the Curia, its
## floors at successive levels from 10.4 to 11.8 m, steps round it (the radius from the steps,
## # unverified). Rings of tufa steps round a paved floor of cappellaccio.
static func _comitium(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var r := maxf(float(s.R), 8.0)
	var sides := 48 if lod == 0 else (24 if lod == 1 else 12)
	var skirt := float(s.skirt)
	mm.cylinder(Vector3(0, -skirt, 0), r - 3.2, skirt + 0.05, "tufa_brown", sides)
	for i in 4:
		mm.lathe(Vector3(0, -skirt, 0), PackedVector2Array([Vector2(r - i * 0.8, 0.0), Vector2(r - i * 0.8, skirt + 1.2 - i * 0.3),
			Vector2(r - (i + 1) * 0.8, skirt + 1.2 - i * 0.3)]), "tufa_grey", sides, false)
	mm.open(Vector3(0, -skirt, 0), Vector3(r * 1.4, skirt + 1.2, r * 1.4))


# --- colonnaded enclosures ------------------------------------------------------------------------


## A colonnaded enclosure (the Porticus of Metellus/Octavia, the Porticus of Pompey, the Saepta,
## the Porticus Minucia, the Villa Publica): an open court (walked on, never picked) with a
## colonnade facing inward on every side under a lean-to tiled roof against a plain outer wall,
## and a gabled propylon of four columns in the middle of the front. Vitruvius 5.9 (porticoes;
## # unverified, not re-read). The column height is about 0.7 of `height_m`, their spacing 3.5 m,
## the colonnade 7 m deep (# unverified). Marble and Ionic from 146 BC for the Porticus of
## Metellus (Vell. Pat. 1.11.3-5, the first marble temple, as cited in the dataset), Tuscan in
## stuccoed tufa otherwise; the Saepta of 26 BC marble (dataset form).
static func _portico_enclosure(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var W := maxf(float(s.W), 30.0)
	var L := maxf(float(s.L), 30.0)
	var H := maxf(float(s.H), 7.0)
	var id := str(s.id)
	var marble := id.begins_with("porticus_octaviae") or id.begins_with("saepta") or id == "porticus_pompeiana"
	var order := "ionic" if marble else "tuscan"
	var col_mat := "marble_luna" if marble else "stucco_white"
	var wall := "stucco_cream" if not marble else "travertine"
	var skirt := float(s.skirt)
	var depth := 7.0
	var col_h := H * 0.7
	var d := col_h / (9.0 if marble else 7.0)
	var sp := 3.5
	# the court, open
	mm.ext(-W / 2, -skirt, -L / 2, W / 2, 0.05, L / 2, "gravel" if not marble else "forum_travertine")
	mm.open(Vector3(0, -skirt, 0), Vector3(W - 2.0 * depth, skirt + 0.05, L - 2.0 * depth))
	var gate := minf(14.0, W * 0.25)
	# four wings: each (centre, yaw, length); local +z of a wing faces the court
	var wings := [[Vector3(0, 0, L / 2 - depth * 0.5), PI, W], [Vector3(0, 0, -L / 2 + depth * 0.5), 0.0, W],
		[Vector3(W / 2 - depth * 0.5, 0, 0), -PI / 2.0, L], [Vector3(-W / 2 + depth * 0.5, 0, 0), PI / 2.0, L]]
	for wi in wings.size():
		var wg: Array = wings[wi]
		var len := float(wg[2])
		mm.push(MM.at(wg[0], float(wg[1])))
		var front := wi == 0
		var segs: Array = [[-len / 2, len / 2]] if not front else [[-len / 2, -gate / 2], [gate / 2, len / 2]]
		for sg: Array in segs:
			var a := float(sg[0])
			var b := float(sg[1])
			# the stylobate, the outer wall, the roof
			mm.ext(a, 0.0, -depth * 0.5, b, 0.4, depth * 0.5, "travertine")
			mm.ext(a, 0.0, -depth * 0.5, b, col_h + 2.6, -depth * 0.5 + 0.8, wall)
			mm.solid(Vector3((a + b) * 0.5, 0.0, -depth * 0.5 + 0.4), Vector3(b - a, col_h + 2.6, 0.8))
			mm.slab([Vector3(a, col_h + 1.6, depth * 0.5 + 0.4), Vector3(b, col_h + 1.6, depth * 0.5 + 0.4),
				Vector3(b, col_h + 3.4, -depth * 0.5), Vector3(a, col_h + 3.4, -depth * 0.5)], 0.25, "tegulae", "timber_oak")
			# the beam over the columns
			mm.ext(a, col_h + 0.4, depth * 0.5 - d * 0.7, b, col_h + 1.6, depth * 0.5 + 0.1, col_mat if marble else "stucco_white")
			if lod < 2:
				var n := maxi(1, int((b - a) / sp))
				for i in n:
					var x := a + (i + 0.5) * (b - a) / n
					# long colonnades: plain shafts even close up (hundreds of columns)
					mm.instance("pcol|%s|%.2f|%d" % [order, col_h, maxi(lod, 1)], Orders.column_mesh(order, col_h, col_mat, maxi(lod, 1), d), Transform3D(Basis.IDENTITY, Vector3(x, 0.4, depth * 0.5 - d * 0.6)))
				# doors in the outer wall now and then (shops or rooms behind)
				if lod == 0 and not marble:
					var nd := int((b - a) / 14.0)
					for k in nd:
						var xd := a + (k + 0.5) * (b - a) / nd
						mm.push(MM.at(Vector3(xd, 0.4, -depth * 0.5 + 0.8)))
						Orders.door(mm, Vector3.ZERO, 1.6, 2.8, "travertine", "timber_oak", 1, 0.3)
						mm.pop()
		mm.pop()
	# the propylon: four columns before and behind a gabled porch over the gate
	mm.push(MM.at(Vector3(0, 0, L / 2 - depth * 0.5), 0.0))
	var pw := gate + 2.0
	mm.ext(-pw / 2, 0.0, -depth * 0.5 - 1.0, pw / 2, 0.4, depth * 0.5 + 1.0, "travertine")
	for zf: float in [depth * 0.5 + 0.4, -depth * 0.5 - 0.4]:
		for i in 4:
			var x := -pw / 2 + 0.8 + i * (pw - 1.6) / 3.0
			if lod < 2:
				mm.instance("pcol|%s|%.2f|%d|p" % [order, col_h + 1.2, lod], Orders.column_mesh(order, col_h + 1.2, col_mat, lod), Transform3D(Basis.IDENTITY, Vector3(x, 0.4, zf)))
	var ye := Orders.entablature(mm, order, col_h + 1.2, d * 1.1, -pw / 2, pw / 2, -depth * 0.5 - 0.6, depth * 0.5 + 0.6, col_h + 1.6, col_mat, col_mat, lod)
	Orders.pediment(mm, -pw / 2 - 0.3, pw / 2 + 0.3, depth * 0.5 + 0.9, ye, true, 0.9, col_mat, col_mat, "statue_marble", lod, false, (pw + 0.6) / 8.0)
	Orders.pediment(mm, -pw / 2 - 0.3, pw / 2 + 0.3, -depth * 0.5 - 0.9, ye, false, 0.9, col_mat, col_mat, "statue_marble", lod, false, (pw + 0.6) / 8.0)
	Orders.roof(mm, -pw / 2 - 0.3, pw / 2 + 0.3, -depth * 0.5 - 0.5, depth * 0.5 + 0.5, ye + 0.1, (pw + 0.6) / 8.0, 0.3, lod)
	mm.pop()
