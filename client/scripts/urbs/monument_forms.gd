## Urbs (U3): the meshes of the monuments of Rome, by model key (the `model` field of
## data/rome/city/monuments.yaml). Everything here is in metres, built about the building's
## centre at ground level (y = 0), the FRONT (the way the door or the track faces) towards +z.
## UrbsMonuments turns local +z into the compass bearing of the entry.
##
## Where the Roman kit (scripts/models/roman.gd, 1 unit = 10 m) has the form it is used and
## fitted to the footprint; every other form is built here from the same Kit primitives and
## is marked in FORMS as "own" (detailed here) or "placeholder" (a box of the right footprint
## and height, # TODO roman.gd: the kit agent can replace it; the list is TODO_KIT below).
class_name UrbsForms
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")
const Roman := preload("res://scripts/models/roman.gd")

const U := 10.0   ## metres per kit unit

## model key -> how it is made: "kit" (roman.gd), "own" (built in this file), "placeholder".
const FORMS := {
	"temple_tuscan_archaic": "kit", "temple_tuscan_restored": "kit", "temple_tuscan_small": "kit",
	"temple_tetrastyle_ionic": "kit", "temple_tetrastyle_ionic_travertine": "kit",
	"temple_tetrastyle_ionic_marble": "kit", "temple_hexastyle_corinthian": "kit",
	"temple_hexastyle_corinthian_marble": "kit", "temple_round": "kit", "temple_round_marble": "kit",
	"basilica": "kit", "basilica_travertine": "kit", "curia": "kit", "rostra": "kit",
	"tabularium": "kit", "horrea": "kit", "macellum": "kit", "theatre_pompey": "kit",
	"portico_enclosure": "kit",
	"circus_maximus": "kit", "plaza": "own", "comitium": "own", "aedicula": "own", "altar": "own",
	"altar_enclosure": "own", "basin": "own", "arch": "own", "column_monument": "own",
	"hut": "own", "gate": "own", "wall": "own", "sewer": "own", "bridge_stone": "own",
	"bridge_timber": "own", "aqueduct": "own", "theatre_stone": "own", "theatre_timber": "own",
	"amphitheatre": "own", "quay": "own", "long_hall": "own", "shipsheds": "own",
	"tomb_drum": "own", "tomb_pyramid": "own", "tomb_rock": "own", "domus": "own",
	"platform": "placeholder", "public_building": "placeholder", "regia": "placeholder",
	"baths": "placeholder", "none": "none",
}

## What the kit agent could add to roman.gd to replace a stand-in or a placeholder (TODO roman.gd).
const TODO_KIT := {
	"temple_hexastyle_corinthian": "Ionic hexastyle (Saturn, Divus Iulius), octostyle peripteral Corinthian (Castor, Venus Genetrix), transverse-cella plan (Concord), pseudo-peripteral on a high podium with a rostra (Divus Iulius)",
	"regia": "the Regia: trapezoidal marble-faced building with three rooms",
	"platform": "Graecostasis / Senaculum: a raised platform with a low portico",
	"public_building": "Atrium Libertatis (archive hall with a portico)",
	"baths": "Thermae Agrippae: a hall of vaults round a rotunda, with a pool",
	"domus": "the atrium house of Vitruvius 6.3 with impluvium, peristyle and shops (the kit header names it but has no kind)",
	"theatre_stone": "an arcaded theatre without the temple (Marcellus): split theatre_pompey into cavea, scaena, temple",
	"amphitheatre": "a stone amphitheatre (Taurus 29 BC)",
	"wall": "Servian wall with merlons, towers and the agger and ditch",
	"gate": "Servian gate (single or double arch between two towers)",
	"aqueduct": "arcade on piers with the specus channel",
}

const STONE_C := Color(0.74, 0.69, 0.60)
const SAND := Color(0.78, 0.68, 0.48)
const CHAR := Color(0.16, 0.12, 0.10)
const SOOT := Color(0.30, 0.25, 0.22)


# ---------------------------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------------------------


## The parts of one monument in one state. `st` = {state, model, variant, length, width,
## radius, height, podium}; `ground` = Callable(x, z) -> y of the ground in the local frame of
## the monument, used by route forms. Returns {parts: [{mesh, xform}], boxes: [{centre, size}],
## kind: "kit"|"own"|"placeholder"|"site"|"ruin", todo: String}. Parts are in the monument's
## local frame (centre, ground level, front +z) except for route forms, which are in world
## coordinates (`world: true`).
static func make(rec: Dictionary, st: Dictionary, route: PackedVector2Array = PackedVector2Array(),
		ground := Callable()) -> Dictionary:
	var model := str(st.get("model", "none"))
	var state := str(st.get("state", "standing"))
	var d := _dims(model, st)
	var out := {"parts": [], "boxes": [], "kind": str(FORMS.get(model, "placeholder")), "todo": "", "world": false}
	if model == "none":
		return out
	if state == "building":
		_site(out, d, model)
		out.kind = "site"
		return out
	if state == "burnt":
		_ruin(out, d, str(rec.get("id", "")))
		out.kind = "ruin"
		return out
	_standing(out, rec, st, d, model, route, ground)
	if state == "standing_scaffold":
		_site(out, d, model, true)
	if TODO_KIT.has(model):
		out.todo = str(TODO_KIT[model])
	return out


## Width (x), height (y), depth (z) in metres, or a radius, for a model in a state.
static func _dims(model: String, st: Dictionary) -> Dictionary:
	var h := float(st.get("height", 0.0))
	var r := float(st.get("radius", 0.0))
	var w := float(st.get("width", 0.0))
	var l := float(st.get("length", 0.0))
	if r > 0.0 and w <= 0.0:
		w = r * 2.0
		l = r * 2.0
	var given := h > 0.0
	if h <= 0.0:
		h = _default_height(model, w, l)
	return {"height_given": given, "w": w, "l": l, "h": h, "r": r, "podium": float(st.get("podium", 0.0)), "variant": str(st.get("variant", ""))}


static func _default_height(model: String, w: float, l: float) -> float:
	match model:
		"plaza", "quay": return 0.0
		"platform": return 2.0
		"comitium": return 1.5
		"aedicula": return 4.0
		"altar", "altar_enclosure": return 1.5
		"domus": return 8.0
		"public_building", "regia": return 8.0
		"baths": return 18.0
		"amphitheatre": return 22.0
		"long_hall": return 9.0
	return maxf(4.0, minf(w, l) * 0.3)


# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------


static func _add(out: Dictionary, mesh: ArrayMesh, xform := Transform3D.IDENTITY) -> void:
	(out.parts as Array).append({"mesh": mesh, "xform": xform})


static func _box_shape(out: Dictionary, centre: Vector3, size: Vector3, yaw := 0.0) -> void:
	(out.boxes as Array).append({"centre": centre, "size": size, "yaw": yaw})


## A box from corner extents.
static func _b(k: Kit, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, c: Color, m: int) -> void:
	k.box(Vector3((x0 + x1) * 0.5, y0, (z0 + z1) * 0.5), Vector3(absf(x1 - x0), y1 - y0, absf(z1 - z0)), c, m)


static var _kit_cache := {}


## A kit mesh, built once.
static func _kit_mesh(kind: String) -> ArrayMesh:
	if not _kit_cache.has(kind):
		_kit_cache[kind] = Roman.build(kind)
	return _kit_cache[kind]


## Native width, height, depth in metres of a kit form, and its AABB centre (x, z).
static func _kit_native(kind: String) -> Dictionary:
	var a: AABB = _kit_mesh(kind).get_aabb()
	return {"size": a.size * U, "centre": (a.position + a.size * 0.5) * U}


## How much of a kit temple's depth is the front stair (outside the podium that Platner measures).
const STAIR_SHARE := 0.10


## A kit form fitted to a footprint (width across the front x depth) and a height. Axes the data
## does not give keep the kit's own size. Non-uniform scaling is kept within 1 : 1.5 so a
## temple is not squashed into something else; a bigger mismatch scales uniformly by the width.
static func _kit(out: Dictionary, kind: String, d: Dictionary, uniform_diam := 0.0) -> void:
	var n := _kit_native(kind)
	var size: Vector3 = n.size
	var ctr: Vector3 = n.centre
	var sx := 1.0
	var sz := 1.0
	var sy := 1.0
	if uniform_diam > 0.0 and float(d.w) > 0.0:
		sx = float(d.w) / uniform_diam
		sz = sx
		sy = sx
	else:
		var w := float(d.w)
		var l := float(d.l)
		var temple := kind.begins_with("temple_") and not kind.begins_with("temple_round")
		if w > 0.0:
			sx = w / size.x
		if l > 0.0:
			sz = l * (1.0 + (STAIR_SHARE if temple else 0.0)) / size.z
		if w > 0.0 and l <= 0.0:
			sz = sx
		if l > 0.0 and w <= 0.0:
			sx = sz
		if w > 0.0 and l > 0.0:
			var ratio := sx / sz
			if ratio > 1.5 or ratio < 1.0 / 1.5:
				var s := sqrt(sx * sz)
				sx = s
				sz = s
		sy = sqrt(sx * sz)
		if _height_given(d):
			sy = float(d.h) / size.y
	var xf := Transform3D(Basis.from_scale(Vector3(sx * U, sy * U, sz * U)), Vector3(-ctr.x * sx, 0.0, -ctr.z * sz))
	_add(out, _kit_mesh(kind), xf)
	_box_shape(out, Vector3(0, size.y * sy * 0.5, 0), Vector3(size.x * sx, size.y * sy, size.z * sz))


## Whether the data gave a height (as opposed to the default of this file).
static func _height_given(d: Dictionary) -> bool:
	return bool(d.get("height_given", false))


# ---------------------------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------------------------


static func _standing(out: Dictionary, rec: Dictionary, st: Dictionary, d: Dictionary, model: String,
		route: PackedVector2Array, ground: Callable) -> void:
	match model:
		"plaza": _plaza(out, d, str(rec.get("surface", "travertine")))
		"comitium": _comitium(out, d)
		"platform": _platform(out, d)
		"aedicula": _aedicula(out, d)
		"altar": _altar(out, d)
		"altar_enclosure": _altar_enclosure(out, d)
		"basin": _basin(out, d)
		"arch": _arch_monument(out, d)
		"column_monument": _column_monument(out, d)
		"hut": _hut(out, d)
		"gate": _gate(out, d)
		"wall": _wall(out, st, route, ground)
		"sewer": _sewer(out, d, route, ground)
		"bridge_stone": _bridge_stone(out, d)
		"bridge_timber": _bridge_timber(out, d)
		"aqueduct": _aqueduct(out, d, st, route, ground)
		"circus_maximus": _circus(out, d)
		"theatre_stone": _theatre(out, d, false)
		"theatre_timber": _theatre(out, d, true)
		"amphitheatre": _amphitheatre(out, d)
		"quay": _quay(out, d)
		"long_hall": _long_hall(out, d)
		"shipsheds": _shipsheds(out, d)
		"portico_enclosure": _portico_ring(out, d, str(rec.get("id", "")))
		"tomb_drum": _tomb_drum(out, d)
		"tomb_pyramid": _tomb_pyramid(out, d)
		"tomb_rock": _tomb_rock(out, d)
		"domus": _domus(out, d)
		"regia": _regia(out, d)
		"baths": _block(out, d, Roman.STUCCO_W, Roman.TERRA, true)
		"public_building": _block(out, d, Roman.STUCCO, Roman.TERRA, false)
		_:
			if Roman.KINDS.has(model):
				_kit(out, model, d, 150.0 if model == "theatre_pompey" else 0.0)
			else:
				_block(out, d, Roman.STUCCO, Roman.TERRA, false)   # TODO roman.gd: unknown model key
				out.kind = "placeholder"


## A box with a pitched roof of the footprint and height: the stand-in for any form not yet drawn
## (# TODO roman.gd). `hip` gives a hipped roof.
static func _block(out: Dictionary, d: Dictionary, wall: Color, roof: Color, hip: bool) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 3.0)
	var l := maxf(float(d.l), 3.0)
	var h := maxf(float(d.h), 3.0)
	var wh := h * 0.72
	k.box(Vector3(0, 0, 0), Vector3(w, wh, l), wall, Kit.PLASTER)
	if hip:
		k.hip_roof(Vector3(0, wh, 0), w, l, h - wh, 0.6, 0.25, roof, Kit.TILE)
	else:
		k.gable_roof(Vector3(0, wh, 0), w, l, h - wh, 0.6, 0.25, roof, Kit.TILE, wall, Kit.PLASTER, 0.0 if w >= l else PI / 2.0)
	k.door(Vector3(0, 0, l * 0.5 + 0.02), 0.0, minf(3.0, w * 0.25), minf(4.0, wh * 0.6), Roman.DWOOD)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w, h, l))


static func _regia(out: Dictionary, d: Dictionary) -> void:
	# TODO roman.gd: the Regia is trapezoidal, three rooms, marble-faced (Platner-Ashby s.v. Regia)
	_block(out, d, Roman.MARBLE, Roman.TERRA, false)


# ---------------------------------------------------------------------------------------------
# Open places, platforms, small things
# ---------------------------------------------------------------------------------------------


static func _plaza(out: Dictionary, d: Dictionary, surface: String) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 4.0)
	var l := maxf(float(d.l), 4.0)
	var col := Roman.TRAVERT.darkened(0.12)
	var mat := Kit.STONE
	match surface:
		"earth":
			col = Roman.EARTH_C.lightened(0.1)
			mat = Kit.EARTH
		"black":
			col = CHAR
	k.box(Vector3(0, 0, 0), Vector3(w, 0.14, l), col, mat)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, 0.3, 0), Vector3(w, 0.6, l))


static func _comitium(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var r := maxf(float(d.r), 6.0)
	for i in 3:
		k.cylinder(Vector3.ZERO, r * (1.0 - 0.15 * i), 0.4 * (i + 1), STONE_C.darkened(0.04 * i), Kit.STONE, 32)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, 0.6, 0), Vector3(r * 2.0, 1.2, r * 2.0))


static func _platform(out: Dictionary, d: Dictionary) -> void:
	# TODO roman.gd: a raised platform with a low portico (Graecostasis, Senaculum)
	var k := Kit.new()
	var w := maxf(float(d.w), 3.0)
	var l := maxf(float(d.l), 3.0)
	var h := maxf(float(d.h), 0.8)
	k.box(Vector3.ZERO, Vector3(w, h, l), Roman.GROTTA, Kit.STONE)
	k.box(Vector3(0, h, 0), Vector3(w * 1.04, 0.25, l * 1.04), Roman.GROTTA.lightened(0.08), Kit.STONE)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w, h + 0.25, l))


static func _aedicula(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 2.0)
	var l := maxf(float(d.l), 2.0)
	var h := maxf(float(d.h), 2.5)
	var base := minf(0.5, h * 0.12)
	var wh := h * 0.62
	k.box(Vector3.ZERO, Vector3(w * 1.1, base, l * 1.1), Roman.GROTTA, Kit.STONE)
	k.box(Vector3(0, base, 0), Vector3(w * 0.9, wh, l * 0.9), Roman.STUCCO, Kit.PLASTER)
	Roman._gable_z(k, Vector3(0, base + wh, 0), l * 0.9, w * 0.9, h - base - wh, 0.3, Roman.TERRA, Roman.STUCCO, Kit.PLASTER)
	k.door(Vector3(0, base, l * 0.45 + 0.02), 0.0, minf(1.4, w * 0.4), wh * 0.7, Roman.DWOOD)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w * 1.1, h, l * 1.1))


static func _altar(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 1.5)
	var l := maxf(float(d.l), 1.5)
	var h := maxf(float(d.h), 1.0)
	k.box(Vector3.ZERO, Vector3(w * 1.3, h * 0.2, l * 1.3), Roman.GROTTA, Kit.STONE)
	k.box(Vector3(0, h * 0.2, 0), Vector3(w, h * 0.7, l), Roman.GROTTA.lightened(0.05), Kit.STONE)
	k.box(Vector3(0, h * 0.9, 0), Vector3(w * 1.1, h * 0.1, l * 1.1), Roman.GROTTA.lightened(0.1), Kit.STONE)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w * 1.3, h, l * 1.3))


## The Ara Pacis: a marble precinct wall with a doorway front and back, the altar on steps inside.
static func _altar_enclosure(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 6.0)
	var l := maxf(float(d.l), 6.0)
	var h := maxf(float(d.h), 3.0)
	var t := 0.5
	var door := minf(3.5, w * 0.35)
	var c := Roman.MARBLE
	_b(k, -w / 2, 0, -l / 2, w / 2, h, -l / 2 + t, c, Kit.STONE)
	_b(k, -w / 2, 0, -l / 2 + t, -w / 2 + t, h, l / 2 - t, c, Kit.STONE)
	_b(k, w / 2 - t, 0, -l / 2 + t, w / 2, h, l / 2 - t, c, Kit.STONE)
	_b(k, -w / 2, 0, l / 2 - t, -door / 2, h, l / 2, c, Kit.STONE)
	_b(k, door / 2, 0, l / 2 - t, w / 2, h, l / 2, c, Kit.STONE)
	k.box(Vector3(0, 0, 0), Vector3(w * 0.5, 0.5, l * 0.4), c.darkened(0.05), Kit.STONE)
	k.box(Vector3(0, 0.5, 0), Vector3(w * 0.4, 1.4, l * 0.3), c, Kit.STONE)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w, h, l))


static func _basin(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 4.0)
	var l := maxf(float(d.l), 4.0)
	var h := maxf(float(d.h), 0.8)
	Roman._ring(k, 0.0, 0.0, w / 2, l / 2, 0.5, 0.0, h, Roman.TRAVERT, Kit.STONE)
	k.box(Vector3(0, 0.05, 0), Vector3(w - 1.0, h * 0.7, l - 1.0), Roman.WATER_C, Kit.WATER)
	k.box(Vector3(0, 0, 0), Vector3(3.0, h + 0.8, 2.0), Roman.TRAVERT, Kit.STONE)   # the base of the Dioscuri statues
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w, h + 0.8, l))


static func _arch_monument(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 6.0)
	var l := maxf(float(d.l), 3.0)
	var h := maxf(float(d.h), 6.0)
	var pw := minf(3.95, w * 0.4)
	var yt := h * 0.72
	var c := Roman.TRAVERT
	_b(k, -w / 2, 0, -l / 2, -pw / 2, yt, l / 2, c, Kit.STONE)
	_b(k, pw / 2, 0, -l / 2, w / 2, yt, l / 2, c, Kit.STONE)
	Roman._arch(k, -pw / 2, pw / 2, yt * 0.45, yt, -l / 2, l / 2, c, Kit.STONE, 8)
	_b(k, -w / 2 - 0.3, yt, -l / 2 - 0.3, w / 2 + 0.3, h * 0.82, l / 2 + 0.3, c.lightened(0.05), Kit.STONE)
	_b(k, -w * 0.2, h * 0.82, -l * 0.2, w * 0.2, h, l * 0.2, c, Kit.STONE)   # the statue group above
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w, h, l))


## A rostral column: a plinth, a shaft with ships' beaks (Plin. NH 34.20), a statue on top.
static func _column_monument(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var h := maxf(float(d.h), 6.0)
	var r := maxf(h * 0.05, 0.5)
	k.box(Vector3.ZERO, Vector3(r * 4.0, h * 0.1, r * 4.0), Roman.GROTTA, Kit.STONE)
	k.frustum(Vector3(0, h * 0.1, 0), r, r * 0.8, h * 0.78, Roman.TRAVERT, Kit.STONE, 12)
	for i in 3:   # three pairs of ships' beaks
		for s: float in [-1.0, 1.0]:
			k.box(Vector3(s * r * 1.05, h * (0.25 + 0.18 * i), 0), Vector3(r * 0.7, r * 0.25, r * 0.4), Roman.BRONZE, Kit.GOLD)
			k.box(Vector3(0, h * (0.25 + 0.18 * i), s * r * 1.05), Vector3(r * 0.4, r * 0.25, r * 0.7), Roman.BRONZE, Kit.GOLD)
	k.box(Vector3(0, h * 0.88, 0), Vector3(r * 2.2, h * 0.04, r * 2.2), Roman.TRAVERT, Kit.STONE)
	k.box(Vector3(0, h * 0.92, 0), Vector3(r * 0.9, h * 0.08, r * 0.9), Roman.BRONZE, Kit.GOLD)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(r * 4.0, h, r * 4.0))


## The hut of Romulus (Vitr. 2.1.5): a round wattle hut under a thatched cone.
static func _hut(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var r := maxf(float(d.w) * 0.5, 1.5)
	var h := maxf(float(d.h), 2.5)
	k.cylinder(Vector3.ZERO, r, h * 0.42, Roman.EARTH_C, Kit.MUDBRICK, 12)
	k.frustum(Vector3(0, h * 0.4, 0), r * 1.35, 0.05, h * 0.6, Roman.OCHRE, Kit.THATCH, 12)
	k.box(Vector3(0, 0, r - 0.02), Vector3(r * 0.5, h * 0.3, 0.1), Roman.DARK_C, Kit.DARK)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(r * 2.7, h, r * 2.7))


## A Servian gate: two towers and a single arched passage between them, built of Grotta Oscura
## tufa (Platner-Ashby s.v. Murus Servii Tullii); the arch of 3.30 m is the one found south of
## S. Maria in Cosmedin (s.v. Porta Trigemina). Front = the outer face.
static func _gate(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 8.0)
	var l := maxf(float(d.l), 4.0)
	var h := maxf(float(d.h), 8.0)
	var pw := minf(3.3, w * 0.3)
	var c := Roman.GROTTA
	var yt := h * 0.62
	_b(k, -w / 2, 0, -l / 2, -pw / 2, h, l / 2, c, Kit.STONE)
	_b(k, pw / 2, 0, -l / 2, w / 2, h, l / 2, c, Kit.STONE)
	Roman._arch(k, -pw / 2, pw / 2, yt * 0.55, yt, -l / 2, l / 2, c, Kit.STONE, 8)
	_b(k, -pw / 2, yt, -l / 2, pw / 2, h * 0.82, l / 2, c, Kit.STONE)
	_b(k, -w / 2 - 0.3, h, -l / 2 - 0.3, -pw / 2 + 0.3, h + 0.7, l / 2 + 0.3, c.lightened(0.06), Kit.STONE)
	_b(k, pw / 2 - 0.3, h, -l / 2 - 0.3, w / 2 + 0.3, h + 0.7, l / 2 + 0.3, c.lightened(0.06), Kit.STONE)
	for s: float in [-1.0, 1.0]:   # arrow slits
		k.box(Vector3(s * (pw / 2 + (w - pw) / 4), h * 0.5, l / 2 + 0.01), Vector3(0.25, 1.2, 0.05), Roman.DARK_C, Kit.DARK)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w, h, l))


# ---------------------------------------------------------------------------------------------
# Walking round curves and along routes
# ---------------------------------------------------------------------------------------------


## Points on an ellipse arc (centre cx, cz, radii rx, rz, parameter a0..a1, p = c + (rx cos, rz sin))
## about `step` metres apart: [{pos: Vector2, normal: Vector2 (outward), tangent: Vector2, len}].
static func _arc_walk(cx: float, cz: float, rx: float, rz: float, a0: float, a1: float, step: float) -> Array:
	var res := []
	var circ := 0.0
	var n_probe := 64
	var prev := Vector2(rx * cos(a0), rz * sin(a0))
	for i in range(1, n_probe + 1):
		var a := a0 + (a1 - a0) * i / n_probe
		var p := Vector2(rx * cos(a), rz * sin(a))
		circ += p.distance_to(prev)
		prev = p
	var n := maxi(1, int(round(circ / step)))
	var seg := circ / n
	for i in n:
		var a := a0 + (a1 - a0) * (i + 0.5) / n
		var p := Vector2(cx + rx * cos(a), cz + rz * sin(a))
		var nrm := Vector2(cos(a) / rx, sin(a) / rz).normalized()
		var tan := Vector2(-rx * sin(a), rz * cos(a)).normalized()
		res.append({"pos": p, "normal": nrm, "tangent": tan, "len": seg})
	return res


## Yaw that turns local +x along the 2D direction t (x, z).
static func _yaw_x(t: Vector2) -> float:
	return atan2(-t.y, t.x)


## Yaw that turns local +z along the 2D direction n (x, z).
static func _yaw_z(n: Vector2) -> float:
	return atan2(n.x, n.y)


## Rings of seats on an elliptical arc: `rows` steps rising from radius (rx, rz) outwards.
static func _seat_rings(k: Kit, cx: float, cz: float, rx: float, rz: float, a0: float, a1: float,
		rows: int, row_w: float, step_h: float, c0: Color, c1: Color, m0: int, m1: int, first_row_h := 0.5) -> void:
	for j in rows:
		var rrx := rx + j * row_w
		var rrz := rz + j * row_w
		var hh := first_row_h + (j + 1) * step_h
		var col := c0 if j < rows / 3 else c1
		var mat := m0 if j < rows / 3 else m1
		for e in _arc_walk(cx, cz, rrx + row_w * 0.5, rrz + row_w * 0.5, a0, a1, 6.0):
			var p: Vector2 = e.pos
			k.box(Vector3(p.x, 0, p.y), Vector3(float(e.len) * 1.06, hh, row_w * 1.02), col, mat, _yaw_x(e.tangent) + 0.0)


## A two-storey arcaded facade along an arc: bays of arches, a cornice, an attic. Faces outward.
static func _arc_facade(k: Kit, cx: float, cz: float, rx: float, rz: float, a0: float, a1: float,
		storeys: int, sh: float, c: Color, m: int, bay := 6.0) -> void:
	for e in _arc_walk(cx, cz, rx, rz, a0, a1, bay):
		var p: Vector2 = e.pos
		var yaw := _yaw_z(e.normal)
		k.push(Kit.at(Vector3(p.x, 0, p.y), yaw))
		var bw: float = e.len
		for s in storeys:
			var y0 := s * sh
			Roman._arcade(k, 0.0, 1, bw, bw * 0.34, y0, y0 + sh * 0.56, y0 + sh * 0.9, -0.6, 0.6, c, m, 5, true)
			k.box(Vector3(0, y0 + sh * 0.9, 0), Vector3(bw * 1.02, sh * 0.1, 1.4), c.lightened(0.06), m)
		k.pop()


## Distances along a closed or open polyline, with a sample function.
static func _route_length(route: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(1, route.size()):
		s += route[i].distance_to(route[i - 1])
	return s


## Point and direction at distance s along the route.
static func _route_at(route: PackedVector2Array, s: float) -> Dictionary:
	var acc := 0.0
	for i in range(1, route.size()):
		var seg := route[i].distance_to(route[i - 1])
		if acc + seg >= s or i == route.size() - 1:
			var t := clampf((s - acc) / maxf(seg, 0.001), 0.0, 1.0)
			return {"pos": route[i - 1].lerp(route[i], t), "dir": (route[i] - route[i - 1]).normalized()}
		acc += seg
	return {"pos": route[0], "dir": Vector2.RIGHT}


## The Servian wall along its route: ashlar wall 3.6 m thick with a parapet on the outer face,
## and on the Esquiline stretch (st.agger = Vector2 of route distances) the earth agger behind it
## (Dion. Hal. 9.68: 50 ft thick). Gaps are left at the gates (st.gates = distances).
## World coordinates; parts are chunks of about 250 m. # TODO roman.gd: towers, merlons, ditch.
static func _wall(out: Dictionary, st: Dictionary, route: PackedVector2Array, ground: Callable) -> void:
	out.world = true
	if route.size() < 2:
		return
	var h := float(st.get("height", 10.0))
	var th := float(st.get("thickness", 3.6))
	var total := _route_length(route)
	var area := 0.0
	for i in route.size() - 1:
		area += route[i].x * route[i + 1].y - route[i + 1].x * route[i].y
	var outward_sign := 1.0 if area > 0.0 else -1.0   # sign of the right-hand normal that points out
	var agger: Vector2 = st.get("agger", Vector2(-1, -1))
	var gates: Array = st.get("gates", [])
	var k := Kit.new()
	var acc_len := 0.0
	var s := 0.0
	var step := 10.0
	var c := Roman.GROTTA
	while s < total:
		var mid := _route_at(route, s + step * 0.5)
		var skip := false
		for g in gates:
			if absf(float(g) - (s + step * 0.5)) < 6.5:
				skip = true
		if not skip:
			var p: Vector2 = mid.pos
			var dir: Vector2 = mid.dir
			var y: float = ground.call(p.x, p.y) if ground.is_valid() else 10.0
			var yaw := _yaw_x(dir)
			var right := Vector2(-dir.y, dir.x)   # a right-hand normal in (x, z)
			var out_n := right * (1.0 if (right.x * 0.0 + 0.0) == 0.0 else 1.0) * outward_sign
			var local_z := out_n.dot(Vector2(sin(yaw), cos(yaw)))
			k.box(Vector3(p.x, y - 1.0, p.y), Vector3(step * 1.03, h + 1.0, th), c, Kit.STONE, yaw)
			var off := Vector2(sin(yaw), cos(yaw)) * (th * 0.5 - 0.45) * signf(local_z)
			k.box(Vector3(p.x + off.x, y + h, p.y + off.y), Vector3(step * 1.03, 1.3, 0.9), c.lightened(0.07), Kit.STONE, yaw)
			if s >= agger.x and s <= agger.y:
				var inner := -out_n * (th * 0.5 + 7.5)
				k.box(Vector3(p.x + inner.x, y - 1.0, p.y + inner.y), Vector3(step * 1.03, h - 0.3, 15.0), Roman.EARTH_C, Kit.EARTH, yaw)
		acc_len += step
		s += step
		if acc_len >= 250.0 or s >= total:
			var mesh := k.finish()
			_add(out, mesh)
			_box_shape(out, mesh.get_aabb().get_center(), mesh.get_aabb().size)
			k = Kit.new()
			acc_len = 0.0


## The Cloaca Maxima outfall into the Tiber (the last point of the route, facing the river):
## a masonry mouth 3.2 m wide and 4.2 m high (Platner-Ashby s.v. Cloaca Maxima) in the bank wall.
## The rest of the sewer is underground and not drawn.
static func _sewer(out: Dictionary, d: Dictionary, route: PackedVector2Array, ground: Callable) -> void:
	out.world = true
	if route.size() < 2:
		return
	var p: Vector2 = route[route.size() - 1]
	var dir := (route[route.size() - 1] - route[route.size() - 2]).normalized()
	var y: float = ground.call(p.x, p.y) if ground.is_valid() else 10.0
	var k := Kit.new()
	var yaw := _yaw_z(dir)
	k.push(Kit.at(Vector3(p.x, y - 3.0, p.y), yaw))
	var c := Roman.PEPERINO
	_b(k, -5.0, 0, -2.0, -1.6, 7.5, 2.0, c, Kit.STONE)
	_b(k, 1.6, 0, -2.0, 5.0, 7.5, 2.0, c, Kit.STONE)
	Roman._arch(k, -1.6, 1.6, 0.0, 7.5, -2.0, 2.0, c, Kit.STONE, 8)
	_b(k, -5.0, 7.5, -2.2, 5.0, 8.3, 2.2, c.lightened(0.06), Kit.STONE)
	k.pop()
	var mesh := k.finish()
	_add(out, mesh)
	_box_shape(out, mesh.get_aabb().get_center(), mesh.get_aabb().size + Vector3(4, 4, 4))


## A masonry arch bridge: local +z is along the bridge (its bearing), y = 0 is the roadway; the
## piers go down. Spans about 22 m; piers a fifth of a span thick, cutwaters up and down stream.
static func _bridge_stone(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var l := maxf(float(d.l), 20.0)
	var w := maxf(float(d.w), 5.0)
	var depth := maxf(float(d.h), 8.0)
	var timber := str(d.variant) == "timber_deck"
	var n := maxi(1, int(round(l / 32.0)))
	var pt := 0.0 if n == 1 else 5.0
	var abut := 4.0
	var span := (l - 2.0 * abut - (n - 1) * pt) / n
	var c := Roman.TRAVERT.darkened(0.06)
	k.push(Kit.at(Vector3.ZERO, -PI / 2.0))   # build along x; this turns it onto +z
	var crown := -1.4
	var spring := crown - span * 0.5 * 0.8
	var bottom := minf(spring - 3.0, -depth)
	var x := -l / 2.0
	_b(k, x, bottom, -w / 2, x + abut, -0.4, w / 2, c, Kit.STONE)
	for i in n:
		var x0 := x + abut + i * (span + pt)
		var x1 := x0 + span
		if not timber:
			Roman._arch(k, x0, x1, spring, -0.4, -w / 2, w / 2, c, Kit.STONE, 10, true, true, 0.8)
		if i < n - 1:
			_b(k, x1, bottom, -w / 2, x1 + pt, -0.4, w / 2, c.darkened(0.04), Kit.STONE)
			k.wedge(Vector3(x1 + pt / 2, bottom, w / 2 + 0.9), pt, 1.8, 3.0, c, Kit.STONE, 0.0)
	_b(k, l / 2 - abut, bottom, -w / 2, l / 2, -0.4, w / 2, c, Kit.STONE)
	if timber:
		_b(k, -l / 2, -0.8, -w / 2, l / 2, -0.4, w / 2, Roman.WOOD, Kit.TIMBER)
	_b(k, -l / 2, -0.4, -w / 2, l / 2, 0.0, w / 2, Roman.PEPERINO, Kit.STONE)
	_b(k, -l / 2, 0.0, -w / 2, l / 2, 1.0, -w / 2 + 0.5, c.lightened(0.05), Kit.STONE)
	_b(k, -l / 2, 0.0, w / 2 - 0.5, l / 2, 1.0, w / 2, c.lightened(0.05), Kit.STONE)
	k.pop()
	var mesh := k.finish()
	_add(out, mesh)
	_box_shape(out, Vector3(0, -2.0, 0), Vector3(w, 6.0, l))


## The Pons Sublicius: timber pile bridge, no iron (Plin. NH 36.100): rows of piles, a deck on beams.
static func _bridge_timber(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var l := maxf(float(d.l), 20.0)
	var w := maxf(float(d.w), 4.0)
	var n := int(l / 6.0)
	for i in n + 1:
		var z := -l / 2.0 + i * l / n
		for s: float in [-1.0, 1.0]:
			k.cylinder(Vector3(s * (w / 2 - 0.4), -7.0, z), 0.4, 7.2, Roman.DWOOD, Kit.TIMBER, 6)
		k.box(Vector3(0, -0.9, z), Vector3(w, 0.5, 0.6), Roman.WOOD, Kit.TIMBER)
	k.box(Vector3(0, -0.4, 0), Vector3(w, 0.4, l), Roman.WOOD, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * (w / 2 - 0.1), 0.0, 0), Vector3(0.2, 1.0, l), Roman.DWOOD, Kit.TIMBER)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, -2.0, 0), Vector3(w, 6.0, l))


## Aqueduct arcades along the route where it ran above ground. st.arcade = list of [s0, s1]
## route-distance intervals. One bay = a pier and an arch; the specus (channel) on top.
## World coordinates. # TODO roman.gd: the kit agent's aqueduct arcade.
static func _aqueduct(out: Dictionary, d: Dictionary, st: Dictionary, route: PackedVector2Array, ground: Callable) -> void:
	out.world = true
	var h := maxf(float(d.h), 6.0)
	var arcade: Array = st.get("arcade", [])
	var c := Roman.PEPERINO.lightened(0.08)
	var bay := 6.0
	var pw := 2.2
	for iv in arcade:
		var k := Kit.new()
		var s: float = float(iv[0])
		var s1: float = float(iv[1])
		var acc := 0.0
		while s < s1:
			var mid := _route_at(route, s + bay * 0.5)
			var p: Vector2 = mid.pos
			var dir: Vector2 = mid.dir
			var y: float = ground.call(p.x, p.y) if ground.is_valid() else 10.0
			var yaw := _yaw_z(Vector2(-dir.y, dir.x))   # local +z across the line
			k.push(Kit.at(Vector3(p.x, y, p.y), yaw))
			var ys := h * 0.62
			Roman._arcade(k, 0.0, 1, bay, pw, -0.5, ys, h, -1.1, 1.1, c, Kit.STONE, 5, true)
			k.box(Vector3(0, h, 0), Vector3(bay * 1.01, 1.9, 2.6), c.lightened(0.05), Kit.STONE)
			k.pop()
			s += bay
			acc += bay
			if acc >= 240.0 or s >= s1:
				var mesh := k.finish()
				if mesh.get_surface_count() > 0:
					_add(out, mesh)
					_box_shape(out, mesh.get_aabb().get_center(), mesh.get_aabb().size + Vector3(2, 0, 2))
				k = Kit.new()
				acc = 0.0


# ---------------------------------------------------------------------------------------------
# The Circus Maximus
# ---------------------------------------------------------------------------------------------


## The Circus Maximus. Local +z = the way the carceres face (towards the curved end), the origin
## the middle of the 621 x 118 m outline. d.variant: early (before 329 BC: earth banks with timber
## stands, no gates), carceres (329 BC, Livy 8.20.2), eggs (174 BC, Livy 41.27.6: the seven eggs),
## caesar (46 BC: stone lowest tier, the euripus; Suet. Iul. 39, Plin. NH 36.102), augustan (33 BC:
## the seven dolphins, Dio 49.43.2). Track 79 m wide, banks ~19.5 m (Dion. Hal. 3.68: 118 m total).
static func _circus(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var L := maxf(float(d.l), 300.0)
	var W := maxf(float(d.w), 80.0)
	var tw := 79.0
	var bd := (W - tw) / 2.0
	var v := str(d.variant)
	var stone := v == "caesar" or v == "augustan"
	var gates := v != "early" and v != ""
	var zc0 := -L / 2.0                       # the carceres line
	var zs := L / 2.0 - W / 2.0               # where the curve begins
	# the track
	k.box(Vector3(0, 0, (zc0 + L / 2.0) / 2.0), Vector3(W, 0.18, L), SAND, Kit.EARTH)
	# the banks along both flanks
	var seg := _kit_mesh("circus_segment")
	var sa: AABB = seg.get_aabb()
	var sdep := bd / (sa.size.z * U)
	var zf := (sa.position.z + sa.size.z) * U * sdep   # the track-side edge of a segment
	var nseg := int((zs - (zc0 + 30.0)) / U)
	var zstart := zc0 + 30.0 + U * 0.5
	var flank_mesh := ArrayMesh.new()
	if stone:
		var st := SurfaceTool.new()
		for side: float in [-1.0, 1.0]:
			var yaw: float = -PI / 2.0 if side > 0.0 else PI / 2.0
			var ox: float = side * (tw / 2.0 + zf) if side > 0.0 else side * (tw / 2.0 + zf)
			for i in nseg:
				var z := zstart + i * U
				var b := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(U, U, U * sdep))
				st.append_from(seg, 0, Transform3D(b, Vector3(ox, 0, z)))
		flank_mesh = st.commit()
		_add(out, flank_mesh)
	else:
		for side: float in [-1.0, 1.0]:
			for j in 4:   # stepped earth banks with timber stands above
				var x0 := side * (tw / 2.0 + j * bd / 4.0 + bd / 8.0)
				var hh := 1.6 + j * 2.2
				var col := Roman.EARTH_C if j < 2 else Roman.WOOD
				var mat := Kit.EARTH if j < 2 else Kit.TIMBER
				k.box(Vector3(x0, 0, (zstart + zs) / 2.0), Vector3(bd / 4.0 + 0.2, hh, zs - zstart), col, mat)
	# the curved end (sphendone): seat rings and, once in stone, the arcaded outer wall
	var arc_rows := 5
	if stone:
		_seat_rings(k, 0.0, zs, tw / 2.0, tw / 2.0, 0.0, PI, arc_rows, bd / arc_rows, 1.7, Roman.TRAVERT.darkened(0.1), Roman.WOOD, Kit.STONE, Kit.TIMBER)
		_arc_facade(k, 0.0, zs, W / 2.0 + 1.0, W / 2.0 + 1.0, 0.0, PI, 2, 5.0, Roman.TRAVERT.darkened(0.05), Kit.STONE, 7.0)
	else:
		_seat_rings(k, 0.0, zs, tw / 2.0, tw / 2.0, 0.0, PI, arc_rows, bd / arc_rows, 1.6, Roman.EARTH_C, Roman.WOOD, Kit.EARTH, Kit.TIMBER)
	# the euripus: a water channel 10 ft wide inside the banks, but not at the carceres (Dion. Hal. 3.68)
	if stone:
		for side: float in [-1.0, 1.0]:
			k.box(Vector3(side * (tw / 2.0 - 1.6), 0.0, (zc0 + 40.0 + zs) / 2.0), Vector3(3.0, 0.3, zs - zc0 - 40.0), Roman.WATER_C, Kit.WATER)
		for e in _arc_walk(0.0, zs, tw / 2.0 - 1.6, tw / 2.0 - 1.6, 0.0, PI, 6.0):
			var p: Vector2 = e.pos
			k.box(Vector3(p.x, 0.0, p.y), Vector3(float(e.len) * 1.05, 0.3, 3.0), Roman.WATER_C, Kit.WATER, _yaw_x(e.tangent))
	# the spina with its two turning posts (metae), the eggs and, later, the dolphins
	var za := -160.0
	var zb := minf(180.0, zs - 70.0)
	k.box(Vector3(0, 0, (za + zb) / 2.0), Vector3(8.0, 1.3, zb - za), Roman.TRAVERT.darkened(0.08), Kit.STONE)
	k.box(Vector3(0, 1.3, (za + zb) / 2.0), Vector3(3.0, 0.4, zb - za - 6.0), Roman.WATER_C, Kit.WATER)
	for z in [za - 3.0, zb + 3.0]:
		for i in 3:
			k.frustum(Vector3((i - 1) * 2.4, 0, z), 1.3, 0.6, 5.5, Roman.GROTTA if v != "" else Roman.WOOD, Kit.STONE, 8)
	if v == "eggs" or v == "caesar" or v == "augustan":
		for i in 7:   # the lap counters: seven eggs on a beam between two pillars (Varro RR 1.2.11)
			k.box(Vector3(-0.0, 0, za + 10.0), Vector3(0.1, 0.1, 0.1), Roman.TRAVERT, Kit.STONE)
			k.box(Vector3(0, 1.7, za + 10.0 + (i - 3) * 1.6), Vector3(0.9, 1.1, 0.9), Roman.STUCCO_W, Kit.PLASTER)
		k.box(Vector3(0, 1.3, za + 10.0), Vector3(1.2, 3.4, 1.2), Roman.TRAVERT, Kit.STONE)
		k.box(Vector3(0, 1.3, za + 10.0 - 14.0), Vector3(1.2, 3.4, 1.2), Roman.TRAVERT, Kit.STONE)
	if v == "augustan":
		for i in 7:   # the seven dolphins of Agrippa, 33 BC
			k.box(Vector3(0, 1.7, zb - 10.0 + (i - 3) * 1.6), Vector3(0.6, 0.6, 1.3), Roman.BRONZE, Kit.GOLD)
		k.box(Vector3(0, 1.3, zb - 10.0), Vector3(1.2, 3.0, 1.2), Roman.TRAVERT, Kit.STONE)
	# the starting gates, the carceres, from the kit
	var track_mesh := k.finish()
	_add(out, track_mesh)
	if gates:
		var en := _kit_native("circus_end")
		var ctr: Vector3 = en.centre
		var size: Vector3 = en.size
		var a: AABB = _kit_mesh("circus_end").get_aabb()
		# the carceres' back edge sits on the line z = zc0
		var xf := Transform3D(Basis.from_scale(Vector3(U, U, U)), Vector3(-ctr.x, 0, zc0 - a.position.z * U))
		_add(out, _kit_mesh("circus_end"), xf)
	# the arcaded back wall of the flanks (caesar+) is part of the segment; the picks:
	_box_shape(out, Vector3(0, 0.5, 0), Vector3(tw, 1.0, L - W))
	_box_shape(out, Vector3(tw / 2.0 + bd / 2.0, 6.0, (zc0 + zs) / 2.0), Vector3(bd, 12.0, zs - zc0))
	_box_shape(out, Vector3(-tw / 2.0 - bd / 2.0, 6.0, (zc0 + zs) / 2.0), Vector3(bd, 12.0, zs - zc0))
	_box_shape(out, Vector3(0, 6.0, zs + W / 4.0), Vector3(W, 12.0, W / 2.0))


# ---------------------------------------------------------------------------------------------
# Theatres, amphitheatre
# ---------------------------------------------------------------------------------------------


## A theatre: the semicircular cavea opens to +z (the stage side), centre at the origin.
## Stone: two arcaded storeys outside and an attic (Marcellus: Doric then Ionic; Plat.-Ash.).
## Timber: a temporary frame (Scaurus 58 BC, Plin. NH 36.113-115).
static func _theatre(out: Dictionary, d: Dictionary, timber: bool) -> void:
	var k := Kit.new()
	var R := maxf(float(d.r), maxf(float(d.w), 40.0) * 0.5)
	var h := maxf(float(d.h), 14.0)
	var rows := 14
	var orch := R * 0.24
	var row_w := (R - orch) / rows
	var c := Roman.TRAVERT.darkened(0.05)
	var c2 := Roman.WOOD if timber else c
	var m2 := Kit.TIMBER if timber else Kit.STONE
	_seat_rings(k, 0.0, 0.0, orch, orch, PI, TAU, rows, row_w, h * 0.5 / rows, c2, c2, m2, m2, 0.4)
	k.cylinder(Vector3.ZERO, orch, 0.2, SAND, Kit.EARTH, 24)
	if timber:
		for e in _arc_walk(0.0, 0.0, R, R, PI, TAU, 5.0):
			var p: Vector2 = e.pos
			k.box(Vector3(p.x, 0, p.y), Vector3(0.7, h, 0.7), Roman.DWOOD, Kit.TIMBER)
	else:
		_arc_facade(k, 0.0, 0.0, R, R, PI, TAU, 2, h * 0.4, c, Kit.STONE, 7.0)
		for e in _arc_walk(0.0, 0.0, R + 0.3, R + 0.3, PI, TAU, 7.0):   # the attic above
			var p: Vector2 = e.pos
			k.box(Vector3(p.x, h * 0.8, p.y), Vector3(float(e.len) * 1.03, h * 0.2, 1.2), c.lightened(0.04), Kit.STONE, _yaw_x(e.tangent))
	# the stage: a podium and the scaena frons (a wall of columns), 85 m long, 20 m deep (Platner-Ashby)
	var sw := minf(R * 1.2, 90.0)
	k.box(Vector3(0, 0, 8.0), Vector3(sw, 1.4, 16.0), c2, m2)
	k.box(Vector3(0, 1.4, 17.0), Vector3(sw, h * 0.8, 4.0), c if not timber else Roman.WOOD, Kit.STONE if not timber else Kit.TIMBER)
	for i in int(sw / 4.5):
		k.column(Vector3(-sw / 2.0 + 2.0 + i * 4.5, 1.4, 14.5), 0.5, h * 0.55, Roman.MARBLE)
	for s: float in [-1.0, 1.0]:   # the apsidal halls at each end of the scaena
		k.box(Vector3(s * (sw / 2.0 + 6.0), 0, 14.0), Vector3(12.0, h * 0.7, 20.0), c, Kit.STONE)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.4, -R * 0.4), Vector3(R * 2.0, h * 0.8, R * 1.2))
	_box_shape(out, Vector3(0, h * 0.4, 12.0), Vector3(sw + 24.0, h * 0.8, 22.0))


## A stone amphitheatre: an elliptical bowl, two arcaded storeys, an attic.
static func _amphitheatre(out: Dictionary, d: Dictionary) -> void:
	# TODO roman.gd: the real amphitheatre (Statilius Taurus 29 BC, plan unknown)
	var k := Kit.new()
	var a := maxf(float(d.l), 40.0) * 0.5
	var b := maxf(float(d.w), 30.0) * 0.5
	var h := maxf(float(d.h), 14.0)
	var rows := 8
	var row_w := (b - b * 0.35) / rows
	var c := Roman.TRAVERT.darkened(0.05)
	for j in rows:
		var rx := a * 0.45 + j * row_w * (a / b)
		var rz := b * 0.35 + j * row_w
		var hh := 0.5 + (j + 1) * h * 0.55 / rows
		for e in _arc_walk(0.0, 0.0, rx, rz, 0.0, TAU, 6.0):
			var p: Vector2 = e.pos
			k.box(Vector3(p.x, 0, p.y), Vector3(float(e.len) * 1.06, hh, row_w * 1.1), c, Kit.STONE, _yaw_x(e.tangent))
	_arc_facade(k, 0.0, 0.0, a, b, 0.0, TAU, 2, h * 0.4, c, Kit.STONE, 7.0)
	k.cylinder(Vector3.ZERO, 1.0, 0.05, SAND, Kit.EARTH, 6)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(a * 2.0, h, b * 2.0))


# ---------------------------------------------------------------------------------------------
# Large flat-roofed and long forms
# ---------------------------------------------------------------------------------------------


static func _quay(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 10.0)
	var l := maxf(float(d.l), 20.0)
	k.box(Vector3.ZERO, Vector3(w, 0.25, l), Roman.TRAVERT.darkened(0.1), Kit.STONE)
	for i in 4:   # the stone steps of the bank (Livy 41.27.8)
		k.box(Vector3(-w / 2.0 + 2.0 + i * 1.6, 0, 0), Vector3(1.6, 0.3 + i * 0.25, l), Roman.TRAVERT, Kit.STONE)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, 0.6, 0), Vector3(w, 1.2, l))


## The Porticus Aemilia: a long hall of transverse barrel-vaulted aisles (50 in the data).
static func _long_hall(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 20.0)    # across the aisles' length
	var l := maxf(float(d.l), 50.0)    # along the row of aisles
	var h := maxf(float(d.h), 6.0)
	var n := 50
	var aw := l / n
	var c := Roman.STUCCO.darkened(0.04)
	k.box(Vector3.ZERO, Vector3(w + 1.0, 0.5, l + 1.0), Roman.PEPERINO, Kit.STONE)
	for i in n:
		var z := -l / 2.0 + (i + 0.5) * aw
		k.box(Vector3(0, 0.5, z), Vector3(w, h * 0.55, aw * 0.9), c, Kit.PLASTER)
		Roman._gable_x(k, Vector3(0, 0.5 + h * 0.55, z), w, aw * 0.9, h * 0.35, 0.2, Roman.TERRA, c, Kit.PLASTER, 0.12)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w, h, l))


static func _shipsheds(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 20.0)
	var l := maxf(float(d.l), 20.0)
	var h := maxf(float(d.h), 6.0)
	var n := maxi(2, int(l / 8.0))
	var bw := l / n
	k.box(Vector3.ZERO, Vector3(w, 0.3, l), Roman.EARTH_C, Kit.EARTH)
	for i in n:   # a row of slipways, each under its own long gable roof, open at the water end
		var z := -l / 2.0 + (i + 0.5) * bw
		for s: float in [-1.0, 1.0]:
			k.box(Vector3(0, 0.3, z + s * bw * 0.45), Vector3(w, h * 0.6, 0.35), Roman.WOOD, Kit.TIMBER)
		Roman._gable_x(k, Vector3(0, 0.3 + h * 0.6, z), w, bw, h * 0.4, 0.2, Roman.TERRA, Roman.WOOD, Kit.TIMBER, 0.12)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w, h, l))


## A colonnaded enclosure: the kit's portico bays along the four sides, turned to face inward,
## round an open court. Front (+z) = the entrance side.
static func _portico_ring(out: Dictionary, d: Dictionary, id: String) -> void:
	var seg := _kit_mesh("portico_marble" if id == "porticus_octaviae" else "portico")
	var sa: AABB = seg.get_aabb()
	var L := maxf(float(d.l), 30.0)
	var W := maxf(float(d.w), 30.0)
	var h := maxf(float(d.h), 6.0)
	var st := SurfaceTool.new()
	var depth := sa.size.z * U
	var sy := h / (sa.size.y * U)
	var sides := [
		{"len": W, "z": -L / 2.0, "yaw": 0.0, "dx": 1.0},
		{"len": W, "z": L / 2.0, "yaw": PI, "dx": 1.0},
		{"len": L, "z": 0.0, "yaw": -PI / 2.0, "dx": 0.0},
		{"len": L, "z": 0.0, "yaw": PI / 2.0, "dx": 0.0},
	]
	for si in 4:
		var s: Dictionary = sides[si]
		var n := maxi(1, int(round(float(s.len) / U)))
		var seg_len := float(s.len) / n
		for i in n:
			var t := -float(s.len) / 2.0 + (i + 0.5) * seg_len
			var b := Basis(Vector3.UP, float(s.yaw)) * Basis.from_scale(Vector3(seg_len, h / (sa.size.y), U))
			# the back wall of the segment lies at local z = a.position.z
			var local_back := sa.position.z * U
			var pos: Vector3
			match si:
				0: pos = Vector3(t, 0, -L / 2.0 - local_back)
				1: pos = Vector3(-t, 0, L / 2.0 + local_back)
				2: pos = Vector3(-W / 2.0 - local_back, 0, -t)
				_: pos = Vector3(W / 2.0 + local_back, 0, t)
			if si == 2 or si == 3:
				# the sides run along z: a segment's local x must follow z
				b = Basis(Vector3.UP, float(s.yaw)) * Basis.from_scale(Vector3(seg_len, h / sa.size.y, U))
			st.append_from(seg, 0, Transform3D(b, pos))
	var mesh := st.commit()
	_add(out, mesh)
	var k := Kit.new()
	k.box(Vector3.ZERO, Vector3(W, 0.1, L), Roman.TRAVERT.darkened(0.12), Kit.STONE)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(W, h, L))


# ---------------------------------------------------------------------------------------------
# Tombs, houses
# ---------------------------------------------------------------------------------------------


## A round tomb: the Mausoleum of Augustus (a travertine drum under an earth mound planted with
## cypresses, Strabo 5.3.8) and the tomb of Caecilia Metella (a drum on a square base).
static func _tomb_drum(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var r := maxf(float(d.r), 8.0)
	var h := maxf(float(d.h), 8.0)
	var big := r > 30.0
	var dh := h * (0.34 if big else 0.7)
	k.cylinder(Vector3.ZERO, r, dh, Roman.TRAVERT, Kit.STONE, 40)
	k.cylinder(Vector3(0, dh, 0), r * 1.02, 0.8, Roman.TRAVERT.lightened(0.06), Kit.STONE, 40)
	if big:
		k.frustum(Vector3(0, dh + 0.8, 0), r * 0.92, r * 0.3, h - dh - 0.8, Roman.GREEN, Kit.LEAF, 32)
		k.box(Vector3(0, h - 0.1, 0), Vector3(4, 5, 4), Roman.BRONZE, Kit.GOLD)
		k.box(Vector3(-r * 0.02, 0, r - 0.3), Vector3(7, 7, 1.0), Roman.DARK_C, Kit.DARK)
	else:
		k.box(Vector3.ZERO, Vector3(r * 1.5, h * 0.25, r * 1.5), Roman.TRAVERT, Kit.STONE)
		k.cylinder(Vector3(0, h * 0.25, 0), r, dh * 0.7, Roman.TRAVERT, Kit.STONE, 32)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(r * 2.0, h, r * 2.0))


## The Pyramid of Cestius: white marble over brick-faced concrete, on a travertine base.
static func _tomb_pyramid(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 8.0)
	var l := maxf(float(d.l), 8.0)
	var h := maxf(float(d.h), 8.0)
	k.box(Vector3.ZERO, Vector3(w * 1.08, 1.0, l * 1.08), Roman.TRAVERT, Kit.STONE)
	k.plinth(Vector3(0, 1.0, 0), w, l, h - 1.0, minf(w, l) * 0.499, Roman.MARBLE, Kit.STONE)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w, h, l))


## A rock-cut tomb with a tufa facade (the Scipios).
static func _tomb_rock(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 6.0)
	var l := maxf(float(d.l), 6.0)
	var h := maxf(float(d.h), 4.0)
	k.box(Vector3.ZERO, Vector3(w, h, l), Roman.CAPPELLACCIO, Kit.EARTH)
	k.box(Vector3(0, 0, l / 2.0 + 0.1), Vector3(w * 0.8, h * 0.8, 0.3), Roman.GROTTA, Kit.STONE)
	k.door(Vector3(0, 0, l / 2.0 + 0.3), 0.0, minf(2.5, w * 0.2), h * 0.55, Roman.DWOOD)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w, h, l))


## A town house (domus): street front, a pent roof round the open atrium.
## TODO roman.gd: the atrium house of Vitruvius 6.3 (impluvium, peristyle, shops).
static func _domus(out: Dictionary, d: Dictionary) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 10.0)
	var l := maxf(float(d.l), 10.0)
	var h := maxf(float(d.h), 6.0)
	var wh := h * 0.6
	k.box(Vector3.ZERO, Vector3(w, wh, l), Roman.STUCCO, Kit.PLASTER)
	Roman._frame_roof(k, Vector3(0, wh, 0), w / 2 + 0.5, l / 2 + 0.5, w * 0.16, l * 0.16, 0.0, h - wh, 0.25, Roman.TERRA)
	k.door(Vector3(0, 0, l / 2.0 + 0.02), 0.0, 2.4, 3.4, Roman.DWOOD)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.5, 0), Vector3(w, h, l))


# ---------------------------------------------------------------------------------------------
# Building sites and burnt shells
# ---------------------------------------------------------------------------------------------


## A building site: foundations, a low core of new masonry, timber scaffolding round the edge
## and a Roman crane (a tripod with a block and tackle: Vitr. 10.2). `overlay` draws only the
## scaffolding, for a building that stays in use while it is rebuilt.
static func _site(out: Dictionary, d: Dictionary, model: String, overlay := false) -> void:
	var k := Kit.new()
	var w := maxf(float(d.w), 6.0)
	var l := maxf(float(d.l), 6.0)
	var h := maxf(float(d.h), 5.0)
	if model == "circus_maximus":
		h = 12.0
	if not overlay:
		k.box(Vector3.ZERO, Vector3(w, 0.8, l), Roman.CAPPELLACCIO, Kit.STONE)
		k.box(Vector3(0, 0.8, 0), Vector3(w * 0.8, h * 0.18, l * 0.8), Roman.GROTTA, Kit.STONE)
		k.box(Vector3(w * 0.25, 0.8, l * 0.3), Vector3(3, 1.2, 3), Roman.TRAVERT, Kit.STONE)   # stacked blocks
	var top := h * (0.9 if overlay else 0.55)
	var nx := maxi(2, int(w / 6.0))
	var nz := maxi(2, int(l / 6.0))
	for i in nx + 1:
		for s: float in [-1.0, 1.0]:
			k.box(Vector3(-w / 2.0 + i * w / nx, 0, s * l / 2.0), Vector3(0.25, top, 0.25), Roman.WOOD, Kit.TIMBER)
	for i in range(1, nz):
		for s: float in [-1.0, 1.0]:
			k.box(Vector3(s * w / 2.0, 0, -l / 2.0 + i * l / nz), Vector3(0.25, top, 0.25), Roman.WOOD, Kit.TIMBER)
	for lv in range(1, 4):
		var y := top * lv / 3.5
		for s: float in [-1.0, 1.0]:
			k.box(Vector3(0, y, s * l / 2.0), Vector3(w, 0.15, 0.2), Roman.DWOOD, Kit.TIMBER)
			k.box(Vector3(s * w / 2.0, y, 0), Vector3(0.2, 0.15, l), Roman.DWOOD, Kit.TIMBER)
	if not overlay:
		var cx := -w * 0.3
		for s: float in [-1.0, 1.0]:   # the crane: two legs and a jib
			k.rod(Vector3(cx + s * 2.0, 0.8, 0), Vector3(cx, h * 0.7, 0), 0.2, Roman.DWOOD, Kit.TIMBER)
		k.rod(Vector3(cx, h * 0.7, 0), Vector3(cx + 5.0, h * 0.62, 2.0), 0.18, Roman.DWOOD, Kit.TIMBER)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.4, 0), Vector3(w, h * 0.8, l))


## A burnt shell: charred footing, ragged wall stumps round the edge, fallen column drums.
static func _ruin(out: Dictionary, d: Dictionary, id: String) -> void:
	var k := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var w := maxf(float(d.w), 6.0)
	var l := maxf(float(d.l), 6.0)
	var h := maxf(float(d.h), 5.0)
	k.box(Vector3.ZERO, Vector3(w, 0.7, l), SOOT, Kit.STONE)
	var n := maxi(8, int((w + l) / 3.0))
	for i in n:
		var t := float(i) / n
		var p := Vector2.ZERO
		var perim := 2.0 * (w + l)
		var s := t * perim
		if s < w:
			p = Vector2(-w / 2 + s, -l / 2)
		elif s < w + l:
			p = Vector2(w / 2, -l / 2 + (s - w))
		elif s < 2 * w + l:
			p = Vector2(w / 2 - (s - w - l), l / 2)
		else:
			p = Vector2(-w / 2, l / 2 - (s - 2 * w - l))
		var hh := h * rng.randf_range(0.12, 0.42)
		var col := CHAR if rng.randf() < 0.5 else SOOT
		k.box(Vector3(p.x, 0.7, p.y), Vector3(maxf(1.2, perim / n), hh, 1.2), col, Kit.STONE, 0.0)
	for i in maxi(3, int(w / 8.0)):
		var fx := rng.randf_range(-w * 0.4, w * 0.4)
		var fz := rng.randf_range(-l * 0.4, l * 0.4)
		k.box(Vector3(fx, 0.7, fz), Vector3(rng.randf_range(2.0, 4.0), 0.9, 0.9), CHAR, Kit.TIMBER, rng.randf() * PI)
	_add(out, k.finish())
	_box_shape(out, Vector3(0, h * 0.2, 0), Vector3(w, h * 0.4, l))
