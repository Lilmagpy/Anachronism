## Urbs (U8): the temples of Rome, built from their real plans with the orders of UrbsOrders.
##
## One parametric builder for every temple of the dataset. A temple's SPEC (see `spec`) comes
## from the model key (MODELS below: the plan, order, number of columns, intercolumniation and
## materials of each kit form) and, where the excavated building is published, from the
## record's `architecture` block in monuments.yaml, keyed by model (a temple can change plan
## when it is rebuilt), each with its own `source`:
##
##   architecture:
##     temple_hexastyle_ionic: {plan: prostyle, order: ionic, front: 6, flank: 3,
##       column_h_m: 11.0, column_d_m: 1.43, podium_h_m: 7.0, source: "...", unverified: [...]}
##
## Plans (front = +z, the centre of the footprint at the origin, y = 0 the ground):
##   prostyle      columns across the front and `flank` ranks deep in the porch; plain cella walls
##   pseudo        prostyle porch, engaged half-columns along the cella's flanks and back
##   peripteral    free columns all round (`front` across, `flank` along each side, corners
##                 counted in both); the cella with a porch of its own inside the colonnade
##   tuscan        Vitruvius 4.7: 6 : 5, the front half a deep porch, the back half three cellae
##                 (3 : 4 : 3); wide timber eaves on mutules
##   round         a tholos: a ring of columns on a stepped base round a cylindrical cella
##
## The footprint (`footprint_m` width x length, or radius) is the whole temple with its steps.
## `build(spec, lod)` gives a UrbsMonumentMesh: lod 0 (within 150 m) has fluted columns, dentils,
## antefixes, studs on the doors and sculpture; lod 1 (150-400 m) plain shafts and bands; lod 2 a
## few boxes. Columns are instanced (one MultiMesh per column type).
class_name UrbsTemples
extends RefCounted

const MM := preload("res://scripts/urbs/monument_mesh.gd")
const Orders := preload("res://scripts/urbs/monument_orders.gd")

## Defaults by model key. `mat` names the material set (see MATERIALS). Column sizes not given
## here follow the footprint (the column diameter is fitted to the width).
const MODELS := {
	"temple_tuscan_archaic": {"plan": "tuscan", "order": "tuscan", "front": 6, "ranks": 3, "mat": "archaic"},
	"temple_tuscan_restored": {"plan": "tuscan", "order": "tuscan", "front": 6, "ranks": 3, "mat": "stucco"},
	"temple_tuscan_small": {"plan": "tuscan", "order": "tuscan", "front": 4, "ranks": 2, "mat": "stucco", "W": 16.0},
	"temple_tetrastyle_ionic": {"plan": "pseudo", "order": "ionic", "front": 4, "flank": 2, "intercol": "eustyle", "mat": "stucco", "W": 13.0},
	"temple_tetrastyle_ionic_travertine": {"plan": "pseudo", "order": "ionic", "front": 4, "flank": 2, "intercol": "eustyle", "mat": "travertine", "W": 13.0},
	"temple_tetrastyle_ionic_marble": {"plan": "pseudo", "order": "ionic", "front": 4, "flank": 2, "intercol": "eustyle", "mat": "marble", "W": 13.0},
	"temple_hexastyle_corinthian": {"plan": "pseudo", "order": "corinthian", "front": 6, "flank": 3, "intercol": "systyle", "mat": "travertine", "W": 20.0},
	"temple_hexastyle_corinthian_marble": {"plan": "pseudo", "order": "corinthian", "front": 6, "flank": 3, "intercol": "systyle", "mat": "marble", "W": 20.0},
	"temple_hexastyle_ionic": {"plan": "prostyle", "order": "ionic", "front": 6, "flank": 3, "intercol": "systyle", "mat": "travertine", "W": 20.0},
	"temple_hexastyle_ionic_marble": {"plan": "prostyle", "order": "ionic", "front": 6, "flank": 3, "intercol": "pycnostyle", "mat": "marble", "W": 20.0},
	"temple_octastyle_peripteral": {"plan": "peripteral", "order": "corinthian", "front": 8, "flank": 11, "intercol": "systyle", "mat": "marble", "W": 30.0},
	"temple_octastyle_pycnostyle": {"plan": "pseudo", "order": "corinthian", "front": 8, "flank": 3, "intercol": "pycnostyle", "mat": "marble", "W": 30.0},
	"temple_round": {"plan": "round", "order": "ionic", "front": 20, "mat": "stucco", "R": 7.5},
	"temple_round_marble": {"plan": "round", "order": "corinthian", "front": 20, "mat": "pentelic", "R": 7.4},
}

## Surfaces of each material set: columns, podium, cella walls, entablature, frieze, steps,
## pediment sculpture and roof.
const MATERIALS := {
	"archaic": {"col": "stucco_cream", "podium": "tufa_brown", "wall": "stucco_cream", "ent": "timber_painted",
		"frieze": "antefix_terracotta", "steps": "tufa_brown", "sculpt": "antefix_terracotta", "roof": "tegulae_old"},
	"stucco": {"col": "stucco_white", "podium": "tufa_yellow", "wall": "stucco_white", "ent": "stucco_white",
		"frieze": "stucco_red", "steps": "tufa_yellow", "sculpt": "antefix_terracotta", "roof": "tegulae"},
	"travertine": {"col": "travertine", "podium": "travertine", "wall": "stucco_white", "ent": "travertine",
		"frieze": "stucco_white", "steps": "travertine", "sculpt": "statue_marble", "roof": "tegulae"},
	"marble": {"col": "marble_luna", "podium": "marble_luna", "wall": "marble_luna", "ent": "marble_luna",
		"frieze": "marble_luna", "steps": "marble_luna", "sculpt": "statue_marble", "roof": "tegulae"},
	"pentelic": {"col": "marble_pentelic", "podium": "marble_pentelic", "wall": "marble_pentelic", "ent": "marble_pentelic",
		"frieze": "marble_pentelic", "steps": "marble_pentelic", "sculpt": "statue_marble", "roof": "tegulae"},
}


## Whether the model is a temple this file draws.
static func handles(model: String) -> bool:
	return MODELS.has(model)


## The full spec of a temple: the model's defaults, then the record's `architecture` for that
## model, then the footprint of the state `st` (width W, length L, radius R, podium, height).
static func spec(model: String, rec: Dictionary, st: Dictionary) -> Dictionary:
	var s: Dictionary = (MODELS.get(model, MODELS["temple_tetrastyle_ionic"]) as Dictionary).duplicate()
	s["model"] = model
	s["id"] = str(rec.get("id", ""))
	var arch: Variant = rec.get("architecture")
	if arch is Dictionary and (arch as Dictionary).has(model):
		for k in (arch[model] as Dictionary):
			s[k] = arch[model][k]
	var w := float(st.get("width", 0.0))
	var l := float(st.get("length", 0.0))
	var r := float(st.get("radius", 0.0))
	if r > 0.0:
		s["R"] = r
	if w > 0.0:
		s["W"] = w
	if l > 0.0:
		s["L"] = l
	if float(st.get("podium", 0.0)) > 0.0 and not s.has("podium_h_m"):
		s["podium_h_m"] = float(st.podium)
	var m: Dictionary = MATERIALS.get(str(s.get("mat", "stucco")), MATERIALS["stucco"])
	s["m"] = m
	return s


## Builds a temple at detail `lod`. Returns UrbsMonumentMesh.finish() (mesh, instances, solids).
static func build(s: Dictionary, lod: int) -> Dictionary:
	var mm := MM.new()
	match str(s.plan):
		"round":
			_round(mm, s, lod)
		"tuscan":
			_tuscan(mm, s, lod)
		_:
			_classical(mm, s, lod)
	return mm.finish()


## The doorway of a temple in its own frame: the threshold just outside the cella door, at the
## height of the floor (the top of the podium). Computed from the same sizes as `_classical`.
static func door(s0: Dictionary) -> Vector3:
	var s := s0.duplicate()
	match str(s.plan):
		"round":
			var R := float(s.get("R", 7.5))
			return Vector3(0, float(s.get("podium_h_m", 1.2)), R)
		"tuscan":
			var W := float(s.get("W", 16.0))
			var L := float(s.get("L", W * 1.2))
			var h := float(s.get("column_h_m", W / 3.0))
			var ph := float(s.get("podium_h_m", clampf(W * 0.085, 1.5, 4.5)))
			var steps_n := maxi(1, int(round(ph / 0.24)))
			if steps_n % 2 == 0:
				steps_n += 1
			var body_l := L - steps_n * 0.45
			h = h
			return Vector3(0, ph, -L * 0.5 + body_l * 0.5 + 1.5)
	var W2 := float(s.get("W", 15.0))
	_size_columns(s, W2)
	var d := float(s._d)
	var h2 := float(s._h)
	var sp := float(s._s)
	var ph2 := float(s.get("podium_h_m", maxf(1.5, h2 * 0.33)))
	var steps2 := maxi(1, int(round(ph2 / 0.24)))
	if steps2 % 2 == 0:
		steps2 += 1
	var stair_d := steps2 * (0.45 if ph2 < 4.0 else 0.4)
	if s.has("platform"):
		var pf0: Dictionary = s.platform
		stair_d = int(pf0.get("steps", 11)) * 0.4 + float(pf0.get("depth_m", 6.0))
	var flank := int(s.get("flank", 3))
	var body_l2 := (flank - 1) * sp + 1.8 * d if str(s.plan) == "peripteral" else W2 * 1.6
	var L2 := float(s.get("L", body_l2 + stair_d))
	var zf := -L2 * 0.5 + L2 - stair_d
	var zcol := zf - 0.9 * d
	var cz1 := zcol - 2.0 * sp if str(s.plan) == "peripteral" else zcol - (flank - 0.4) * sp
	return Vector3(0, ph2, cz1 + 1.2)


# --- helpers ----------------------------------------------------------------------------------


## A moulded podium (Vitr. 3.4.5: plinth, die, cornice and cymatium on the stylobate): spans x
## ±hx, z z0..z1, height ph.
static func _podium(mm: UrbsMonumentMesh, hx: float, z0: float, z1: float, ph: float, mat: String, lod: int) -> void:
	if lod >= 2:
		mm.ext(-hx, 0.0, z0, hx, ph, z1, mat)
		return
	var b := minf(0.35, ph * 0.12)
	mm.ext(-hx - 0.15, 0.0, z0 - 0.15, hx + 0.15, b, z1 + 0.15, mat)                # plinth
	mm.ext(-hx - 0.08, b, z0 - 0.08, hx + 0.08, b + 0.12, z1 + 0.08, mat)          # base moulding
	mm.ext(-hx, b + 0.12, z0, hx, ph - 0.4, z1, mat)                               # the die
	mm.ext(-hx - 0.06, ph - 0.4, z0 - 0.06, hx + 0.06, ph - 0.26, z1 + 0.06, mat)  # cymatium
	mm.ext(-hx - 0.2, ph - 0.26, z0 - 0.2, hx + 0.2, ph, z1 + 0.2, mat)            # cornice


## The front steps between two cheek walls (the podium's wings run forward beside the flight
## and carry its cornice). The flight is `w` wide, from the podium face at z_face out over
## `depth`. Odd number of steps, Vitr. 3.4.4.
static func _front_stair(mm: UrbsMonumentMesh, w: float, cheek: float, z_face: float, ph: float, steps_mat: String,
		podium_mat: String, lod: int, tread := 0.45) -> float:
	var depth := mm.stair(0.0, w, z_face, ph, steps_mat, tread) if lod < 2 else 0.0
	if lod >= 2:
		var n := maxi(1, int(round(ph / 0.24)))
		depth = n * tread
		mm.ext(-w / 2, 0.0, z_face, w / 2, ph * 0.5, z_face + depth, steps_mat)
	if cheek > 0.0:
		for s: float in [-1.0, 1.0]:
			var x0 := s * w / 2.0
			var x1 := s * (w / 2.0 + cheek)
			mm.ext(minf(x0, x1), 0.0, z_face - 0.01, maxf(x0, x1), ph, z_face + depth, podium_mat)
			if lod < 2:
				mm.ext(minf(x0, x1) - 0.12, ph - 0.26, z_face, maxf(x0, x1) + 0.12, ph, z_face + depth + 0.12, podium_mat)
	return depth


## Places a column instance (or builds one at lod 2 into the body for fewer draw calls).
static func _col(mm: UrbsMonumentMesh, s: Dictionary, p: Vector3, lod: int, engaged := false) -> void:
	var order := str(s.order)
	var h := float(s._h)
	var d := float(s._d)
	var mat := str(s.m.col)
	var l := lod if not engaged else maxi(lod, 1)
	var mesh := Orders.column_mesh(order, h, mat, l, d)
	mm.instance("col|%s|%s|%.2f|%.2f|%d" % [order, mat, h, d, l], mesh, Transform3D(Basis.IDENTITY, p))


## Column size for a front of `n` columns over a stylobate `w` wide: d from the width (the
## outer columns' axes 0.9 d in from the edge), h from the order and spacing; given sizes win.
static func _size_columns(s: Dictionary, w: float) -> void:
	var n := int(s.front)
	var intercol := str(s.get("intercol", "eustyle"))
	var sp := Orders.spacing_ratio(intercol)
	var d := float(s.get("column_d_m", 0.0))
	var h := float(s.get("column_h_m", 0.0))
	if d <= 0.0 and h > 0.0:
		d = h / Orders.height_ratio(str(s.order), intercol)
	if d <= 0.0:
		d = w / ((n - 1) * sp + 1.8)
	if h <= 0.0:
		h = d * Orders.height_ratio(str(s.order), intercol)
	var spacing := (w - 1.8 * d) / maxf(n - 1, 1)
	s["_d"] = d
	s["_h"] = h
	s["_s"] = spacing


# --- prostyle, pseudoperipteral and peripteral temples -------------------------------------------


static func _classical(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var m: Dictionary = s.m
	var W := float(s.get("W", 15.0))
	var plan := str(s.plan)
	var n := int(s.front)
	_size_columns(s, W)
	var d := float(s._d)
	var h := float(s._h)
	var sp := float(s._s)
	var ph := float(s.get("podium_h_m", maxf(1.5, h * 0.33)))
	var hx := W * 0.5
	var xo := (n - 1) * 0.5 * sp
	var flank := int(s.get("flank", 3))
	var steps_n := maxi(1, int(round(ph / 0.24)))
	if steps_n % 2 == 0:
		steps_n += 1
	var tread := 0.45 if ph < 4.0 else 0.4
	var stair_d := steps_n * tread
	if s.has("platform"):
		var pf0: Dictionary = s.platform
		stair_d = int(pf0.get("steps", 11)) * 0.4 + float(pf0.get("depth_m", 6.0))
	# length: given, or from the plan (Vitruvius 4.4.1: the length twice the width # unverified)
	var body_l: float
	if plan == "peripteral":
		body_l = (flank - 1) * sp + 1.8 * d
	else:
		body_l = W * 1.6
	var L := float(s.get("L", body_l + stair_d))
	body_l = L - stair_d
	if plan == "peripteral" and s.has("L"):
		# keep the given length: re-space nothing, only the flank count follows the length
		flank = maxi(3, int(round((body_l - 1.8 * d) / sp)) + 1)
	var z0 := -L * 0.5                  # the back of the podium
	var zf := z0 + body_l               # the front face of the podium (the stair starts here)
	var zcol := zf - 0.9 * d            # the front row of columns
	# podium and stair
	_podium(mm, hx, z0, zf, ph, str(m.podium), lod)
	var stair_w := W - 2.0 * maxf(0.8, d * 0.9)
	if s.has("platform"):
		# Castor (Platner-Ashby s.v.): a flight of eleven steps, nearly the temple's width, from
		# the pronaos down to a platform 3.66 m above the area, with a railing; two narrow
		# stairs at its ends. The platform's depth is not given (# unverified).
		var pf: Dictionary = s.platform
		var pl_h := float(pf.get("height_m", 3.66))
		var nfl := int(pf.get("steps", 11))
		var zend := L * 0.5
		mm.ext(-hx, 0.0, zf, hx, pl_h, zend, str(m.podium))
		mm.solid(Vector3(0, 0, (zf + zend) * 0.5), Vector3(W, pl_h, zend - zf))
		if lod < 2:
			mm.ext(-hx - 0.12, pl_h - 0.25, zf, hx + 0.12, pl_h, zend + 0.12, str(m.podium))
			mm.push(Transform3D(Basis.IDENTITY, Vector3(0, pl_h, 0)))
			mm.stair(0.0, stair_w, zf, ph - pl_h, str(m.steps), 0.4, 0.24, nfl)
			mm.pop()
			for sx: float in [-1.0, 1.0]:   # the narrow stairs at the ends
				mm.push(MM.at(Vector3(sx * (hx + 0.0), 0.0, zend - 1.2), sx * PI / 2.0))
				mm.stair(0.0, 1.6, 0.0, pl_h, str(m.steps), 0.3, 0.24)
				mm.pop()
		if lod == 0:   # the railing along the front of the platform
			var nr := int(W / 1.2)
			for i in nr + 1:
				mm.box(Vector3(-hx + i * W / nr, pl_h, zend - 0.15), Vector3(0.08, 1.0, 0.08), "bronze")
			mm.ext(-hx, pl_h + 0.95, zend - 0.2, hx, pl_h + 1.05, zend - 0.1, "bronze")
	else:
		_front_stair(mm, stair_w, (W - stair_w) * 0.5, zf, ph, str(m.steps), str(m.podium), lod, tread)
	mm.solid(Vector3(0, 0, (z0 + zf) * 0.5), Vector3(W, ph, body_l))
	# the cella
	var wall_t := maxf(0.6, d * 0.75)
	var cx := xo - (0.0 if plan == "pseudo" else (sp if plan == "peripteral" else 0.0))
	var cz0 := z0 + 0.9 * d + (sp if plan == "peripteral" else 0.0) - (0.0 if plan != "pseudo" else 0.0)
	var cz1: float   # the cella's front wall
	if plan == "peripteral":
		cz1 = zcol - 2.0 * sp
	else:
		cz1 = zcol - (flank - 0.4) * sp
	if plan == "prostyle":
		cx = xo
	var ytop := ph + h
	# the cella walls rise into the entablature (they carry it on the flanks and back), so no
	# gap opens between the wall's top and the roof
	var e_h := float(s.get("entablature_h_m", Orders.entablature_height(str(s.order), h, d)))
	var wall_top := ytop + e_h * 0.85
	var wall := str(m.wall)
	if lod >= 2:
		mm.ext(-cx, ph, cz0, cx, wall_top, cz1, wall)
	else:
		mm.ring(0.0, (cz0 + cz1) * 0.5, cx, (cz1 - cz0) * 0.5, wall_t, ph, wall_top, wall)
		# the wall base (toichobate) and a band at the top under the architrave
		mm.ring(0.0, (cz0 + cz1) * 0.5, cx + 0.06, (cz1 - cz0) * 0.5 + 0.06, wall_t + 0.06, ph, ph + 0.45, str(m.podium) if wall != str(m.podium) else wall)
		# the antae: pilasters at the front corners of the cella
		for sx: float in [-1.0, 1.0]:
			mm.box(Vector3(sx * (cx - d * 0.35), ph, cz1 - d * 0.1), Vector3(d * 0.9, h, d * 0.5), str(m.col))
		# the cella's roof space is closed by the floor of the attic: a ceiling over the cella
		mm.ext(-cx + wall_t, wall_top - 0.3, cz0 + wall_t, cx - wall_t, wall_top, cz1 - wall_t, "timber_oak")
	mm.solid(Vector3(0, ph, (cz0 + cz1) * 0.5), Vector3(cx * 2.0, h, cz1 - cz0))
	# the door: bronze leaves in a moulded frame (never a black hole)
	var dw := minf(sp * 0.6, h * 0.3)
	var dh := minf(h * 0.62, dw * 2.2)
	mm.push(MM.at(Vector3(0, ph, cz1)))
	Orders.door(mm, Vector3.ZERO, dw, dh, str(m.col), "door_bronze_studded", lod, wall_t * 0.8)
	mm.pop()
	# columns
	var xs: Array = []
	for i in n:
		xs.append(-xo + i * sp)
	for x: float in xs:
		_col(mm, s, Vector3(x, ph, zcol), lod)
	match plan:
		"prostyle", "pseudo":
			for j in range(1, flank):
				for sx: float in [-1.0, 1.0]:
					var z := zcol - j * sp
					if z > cz1 + d * 0.6:
						_col(mm, s, Vector3(sx * xo, ph, z), lod)
			if plan == "pseudo" and lod < 2:
				# engaged half-columns along the cella's flanks and back, on its wall line
				var zz := cz1 - sp * 0.5
				while zz > cz0 + d * 0.5:
					for sx: float in [-1.0, 1.0]:
						_col(mm, s, Vector3(sx * (cx - d * 0.15), ph, zz), lod, true)
					zz -= sp
				for x: float in xs:
					if absf(x) < cx - d * 0.3:
						_col(mm, s, Vector3(x, ph, cz0 + d * 0.15), lod, true)
				for sx: float in [-1.0, 1.0]:
					_col(mm, s, Vector3(sx * (cx - d * 0.15), ph, cz0 + d * 0.15), lod, true)
		"peripteral":
			var zback := zcol - (flank - 1) * sp
			for x: float in xs:
				_col(mm, s, Vector3(x, ph, zback), lod)
			for j in range(1, flank - 1):
				for sx: float in [-1.0, 1.0]:
					_col(mm, s, Vector3(sx * xo, ph, zcol - j * sp), lod)
			# the inner porch: two columns in antis before the cella door
			for sx: float in [-1.0, 1.0]:
				_col(mm, s, Vector3(sx * (cx - sp), ph, zcol - sp), lod)
	# the entablature round the whole building
	var ex := xo + d * 0.5
	var ez0 := (cz0 - (0.0 if plan != "peripteral" else 0.0)) if plan != "peripteral" else zcol - (flank - 1) * sp - d * 0.5
	if plan == "prostyle":
		ez0 = cz0
	elif plan == "pseudo":
		ez0 = cz0 - d * 0.15
	var ez1 := zcol + d * 0.5
	var ytop_e := Orders.entablature(mm, str(s.order), h, d, -ex, ex, ez0, ez1, ytop, str(m.ent), str(m.frieze), lod, false,
		PackedFloat32Array(), float(s.get("entablature_h_m", 0.0)))
	# the porch ceiling (coffered in stone; here a soffit at the top of the architrave)
	if lod < 2:   # the porch ceiling, level with the top of the architrave, up to the cella wall
		mm.ext(-ex + d * 0.4, ytop + (ytop_e - ytop) * 0.35, cz1 - 0.05, ex - d * 0.4, wall_top, ez1 - d * 0.4, str(m.ent))
	# pediments front and back, and the roof between them
	var span := ex * 2.0 + d * 0.6
	var rise := span / 9.0 * 1.1
	var pd := d * 1.2
	Orders.pediment(mm, -span * 0.5, span * 0.5, ez1 + d * 0.3, ytop_e, true, pd, str(m.ent), str(m.wall), str(m.sculpt), lod, true, rise)
	Orders.pediment(mm, -span * 0.5, span * 0.5, ez0 - d * 0.3, ytop_e, false, pd, str(m.ent), str(m.wall), str(m.sculpt), lod, false, rise)
	Orders.roof(mm, -span * 0.5, span * 0.5, ez0 - d * 0.3 + pd * 0.5, ez1 + d * 0.3 - pd * 0.5, ytop_e + 0.12, rise, 0.35, lod, str(m.roof))
	mm.solid(Vector3(0, ytop, (ez0 + ez1) * 0.5), Vector3(span, ytop_e - ytop + rise, ez1 - ez0))


# --- the Tuscan temple (Vitruvius 4.7) --------------------------------------------------------------


## Vitruvius 4.7 (read): length to width 6 : 5; the front half for the columns, the back half
## for the cellae, the width in ten parts, 3 : 4 : 3; columns a third of the width high, d one
## seventh of that, bases d/2, taper a quarter, capitals d/2; compound timber beams; mutules
## projecting a quarter of the column height. `ranks`: rows of columns in the porch (the
## Capitolium had three, Platner-Ashby s.v. Iuppiter O. M. Capitolinus).
static func _tuscan(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var m: Dictionary = s.m
	var W := float(s.get("W", 16.0))
	var L := float(s.get("L", W * 1.2))
	var n := int(s.front)
	var ranks := int(s.get("ranks", 2))
	var h := float(s.get("column_h_m", W / 3.0))
	var d := float(s.get("column_d_m", h / 7.0))
	s["_h"] = h
	s["_d"] = d
	s["order"] = "tuscan"
	var ph := float(s.get("podium_h_m", clampf(W * 0.085, 1.5, 4.5)))
	var hx := W * 0.5
	var steps_n := maxi(1, int(round(ph / 0.24)))
	if steps_n % 2 == 0:
		steps_n += 1
	var stair_d := steps_n * 0.45
	var body_l := L - stair_d
	var z0 := -L * 0.5
	var zf := z0 + body_l
	_podium(mm, hx, z0, zf, ph, str(m.podium), lod)
	_front_stair(mm, W * 0.5, W * 0.12, zf, ph, str(m.steps), str(m.podium), lod)
	mm.solid(Vector3(0, 0, (z0 + zf) * 0.5), Vector3(W, ph, body_l))
	# the cellae in the back half: three chambers 3 : 4 : 3 (a wall between each)
	var cw := W * 0.92
	var cz1 := z0 + body_l * 0.5
	var cz0 := z0 + d * 0.6
	var ytop := ph + h
	var wall := str(m.wall)
	var t := maxf(0.6, d * 0.7)
	if lod >= 2:
		mm.ext(-cw / 2, ph, cz0, cw / 2, ytop, cz1, wall)
	else:
		mm.ring(0.0, (cz0 + cz1) * 0.5, cw / 2, (cz1 - cz0) * 0.5, t, ph, ytop, wall)
		for sx: float in [-1.0, 1.0]:
			mm.ext(sx * cw * 0.2 - t * 0.5, ph, cz0, sx * cw * 0.2 + t * 0.5, ytop, cz1, wall)
		mm.ext(-cw / 2 + t, ytop - 0.3, cz0 + t, cw / 2 - t, ytop, cz1 - t, "timber_oak")
	mm.solid(Vector3(0, ph, (cz0 + cz1) * 0.5), Vector3(cw, h, cz1 - cz0))
	# a door to each cella, the middle one larger
	for e: Array in [[0.0, minf(W * 0.14, h * 0.32)], [-cw * 0.35, minf(W * 0.085, h * 0.25)], [cw * 0.35, minf(W * 0.085, h * 0.25)]]:
		mm.push(MM.at(Vector3(float(e[0]), ph, cz1)))
		Orders.door(mm, Vector3.ZERO, float(e[1]), float(e[1]) * 2.1, str(m.col), "door_bronze_studded" if str(s.mat) != "archaic" else "timber_painted", lod, t * 0.8)
		mm.pop()
	# columns: the front rank of n, further ranks of n behind it (the Capitolium) or only the
	# flank columns for a small temple
	var xs: Array
	if n == 4:
		xs = [-0.44 * W, -0.15 * W, 0.15 * W, 0.44 * W]
	else:
		xs = [-0.44 * W, -0.27 * W, -0.09 * W, 0.09 * W, 0.27 * W, 0.44 * W]
	var zcol := zf - d * 0.9
	var rank_sp := (zcol - cz1 - d) / maxf(ranks - 1, 1) if ranks > 1 else 0.0
	for r in ranks:
		for x: float in xs:
			if r == 0 or ranks >= 3 or absf(x) > W * 0.4:
				_col(mm, s, Vector3(x, ph, zcol - r * rank_sp), lod)
	# entablature: paired timber beams, the painted terracotta frieze, the mutules
	var ex := W * 0.44 + d * 0.5
	var ytop_e := Orders.entablature(mm, "tuscan", h, d, -ex, ex, cz0, zcol + d * 0.5, ytop, str(m.ent), str(m.frieze), lod)
	# the wide, low roof: the eaves carried out a quarter of the column height (Vitr. 4.7.5)
	var over := 0.25 * h
	var span := ex * 2.0
	var rise := span * 0.2   # unverified: Vitruvius gives no pitch
	Orders.roof(mm, -span * 0.5, span * 0.5, cz0 - over * 0.5, zcol + d * 0.5 + over * 0.5, ytop_e + 0.1, rise, over, lod, str(m.roof), 0.3)
	# the front gable: a tympanum of timber faced with terracotta plaques, acroteria of
	# terracotta statues (the quadriga on the Capitolium: Plin. NH 28.16, # unverified)
	Orders.pediment(mm, -span * 0.5 - over * 0.5, span * 0.5 + over * 0.5, zcol + d * 0.5 + over, ytop_e + 0.1 - over * rise / (span * 0.5), true,
		d * 0.8, str(m.ent), str(m.frieze), str(m.sculpt), lod, true, rise + over * rise / (span * 0.5), 0.3)
	# the back gable, closed and plain
	Orders.pediment(mm, -span * 0.5 - over * 0.5, span * 0.5 + over * 0.5, cz0 - over, ytop_e + 0.1 - over * rise / (span * 0.5), false,
		d * 0.8, str(m.ent), str(m.wall), str(m.sculpt), lod, false, rise + over * rise / (span * 0.5), 0.3)
	mm.solid(Vector3(0, ytop, (cz0 + zcol) * 0.5), Vector3(span, ytop_e - ytop + rise, zcol - cz0))


# --- round temples ---------------------------------------------------------------------------------


## A tholos (Vitruvius 4.8, # unverified: not re-read): a stepped circular base, a ring of
## columns, the cylindrical cella set back inside them, a conical roof (of bronze on the temple of
## Vesta, Plin. NH 34.13 as cited by Platner-Ashby s.v. Vesta; base of three steps on the coins).
static func _round(mm: UrbsMonumentMesh, s: Dictionary, lod: int) -> void:
	var m: Dictionary = s.m
	var R := float(s.get("R", 7.5))
	var n := int(s.front)
	var h := float(s.get("column_h_m", R * 0.95))
	var d := float(s.get("column_d_m", h / Orders.height_ratio(str(s.order))))
	s["_h"] = h
	s["_d"] = d
	var ph := float(s.get("podium_h_m", 1.2))
	var sides := 32 if lod == 0 else (20 if lod == 1 else 12)
	var nst := int(s.get("steps", 3))
	var sh := ph / nst
	for i in nst:
		mm.cylinder(Vector3(0, i * sh, 0), R - i * 0.45, sh, str(m.steps), sides)
	var rt := R - nst * 0.45
	mm.solid(Vector3.ZERO, Vector3(R * 1.5, ph, R * 1.5))
	var rc := rt - d * 0.9         # the ring of column axes
	var rw := rc - d * 1.6         # the cella wall
	var ytop := ph + h
	mm.cylinder(Vector3(0, ph, 0), rw, h, str(m.wall), sides)
	mm.solid(Vector3(0, ph, 0), Vector3(rw * 1.6, h, rw * 1.6))
	for i in n:
		var a := (i + 0.5) * TAU / n
		_col(mm, s, Vector3(cos(a) * rc, ph, sin(a) * rc), lod)
	# the door on +z, between two columns
	mm.push(MM.at(Vector3(0, ph, rw)))
	Orders.door(mm, Vector3.ZERO, minf(2.2, rw * 0.5), minf(h * 0.6, 5.0), str(m.col), "door_bronze_studded", lod, 0.5)
	mm.pop()
	# the entablature ring: architrave, frieze, cornice
	var a_h := Orders.architrave_height(h, d)
	mm.lathe(Vector3(0, ytop, 0), PackedVector2Array([Vector2(rc + d * 0.5, 0.0), Vector2(rc + d * 0.55, a_h), Vector2(rc + d * 0.55, a_h * 1.75),
		Vector2(rc + d * 0.95, a_h * 2.0), Vector2(rc + d * 1.0, a_h * 2.4), Vector2(rc + d * 0.4, a_h * 2.45)]), str(m.ent), sides, false)
	if lod == 0:
		mm.cylinder(Vector3(0, ytop + a_h, 0), rc + d * 0.56, a_h * 0.75, str(m.frieze), sides, false)
	mm.cylinder(Vector3(0, ytop - 0.05, 0), rc - d * 0.4, a_h * 2.4, str(m.ent), sides, false)
	# the conical roof and its finial
	var ry := ytop + a_h * 2.4
	var roof := str(s.get("roof", "bronze_roof" if str(s.id) == "aedes_vestae" else m.roof))
	mm.frustum(Vector3(0, ry, 0), rc + d * 1.05, 0.25, R * 0.5, roof, sides, true)
	mm.lathe(Vector3(0, ry + R * 0.5 - 0.05, 0), PackedVector2Array([Vector2(0.35, 0.0), Vector2(0.45, 0.25), Vector2(0.2, 0.7), Vector2(0.001, 1.1)]), "gilt", 8)
	mm.solid(Vector3(0, ytop, 0), Vector3(rc * 2.0, a_h * 2.4 + R * 0.5, rc * 2.0))
