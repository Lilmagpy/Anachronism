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
const Temples := preload("res://scripts/urbs/monument_temples.gd")
const Civic := preload("res://scripts/urbs/monument_civic.gd")
const Circus := preload("res://scripts/urbs/monument_circus.gd")

## Distance bands of the three levels of detail (metres from the camera to the monument's
## origin; 0 = no limit). Parts and instances carry their band as `range`.
const LOD_RANGES := [Vector2(0.0, 150.0), Vector2(150.0, 400.0), Vector2(400.0, 0.0)]

const U := 10.0   ## metres per kit unit

## Models drawn in this file (everything else in Roman.KINDS comes from the kit, roman.gd).
const OWN := ["plaza", "comitium", "aedicula", "altar", "altar_enclosure", "basin", "arch", "column_monument",
	"hut", "bridge_stone", "bridge_timber", "sewer", "circus_maximus", "quay", "long_hall", "shipsheds",
	"tomb_drum", "tomb_pyramid", "tomb_rock", "wall", "aqueduct", "portico_enclosure"]

## What is still missing from roman.gd (nothing from the original list; kept for the report).
const TODO_KIT := {}


## How a model is made: "kit" (roman.gd), "own" (this file), "placeholder" (a box), "none".
static func kind_of(model: String) -> String:
	if model == "none":
		return "none"
	if OWN.has(model) or Temples.handles(model) or Civic.handles(model):
		return "own"
	if Roman.KINDS.has(model):
		return "kit"
	return "placeholder"


## Kit forms scaled uniformly from their native diameter (metres) to the footprint's diameter.
const UNIFORM_DIAM := {"theatre_pompey": 150.0, "theatre_stone": 150.0, "theatre_timber": 120.0,
	"amphitheatre_flavian": 200.0}

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
	var model := _alias(str(st.get("model", "none")), st)
	st = st.duplicate()
	st["model"] = model
	var state := str(st.get("state", "standing"))
	var d := _dims(model, st)
	var out := {"parts": [], "boxes": [], "kind": kind_of(model), "todo": "", "world": false, "instances": [],
		"opens": [], "tris": [0, 0, 0]}
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


## Model keys the Empire dataset uses, mapped to forms that exist (the rest become a box).
static func _alias(model: String, st: Dictionary) -> String:
	match model:
		"temple_hexastyle": return "temple_hexastyle_corinthian_marble"
		"temple_octastyle", "temple_decastyle": return "temple_octastyle_pycnostyle"
		"theatre": return "theatre_stone"
		"amphitheatre":
			return "amphitheatre_flavian" if maxf(float(st.get("length", 0.0)), float(st.get("width", 0.0))) >= 100.0 else "amphitheatre_small"
		"portico": return "portico_enclosure"
		"forum": return "plaza"
		"mausoleum": return "tomb_drum"
		"altar_precinct": return "altar_enclosure"
		"column": return "column_monument"
		"fountain", "basin": return "basin"
		"market": return "macellum"
	return model


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


static var _tri_cache := {}


## Triangles in a mesh (cached by the mesh's id).
static func mesh_tris(mesh: Mesh) -> int:
	var key := mesh.get_instance_id()
	if not _tri_cache.has(key):
		var n := 0
		for i in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(i)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			n += (idx as PackedInt32Array).size() / 3 if idx != null and (idx as PackedInt32Array).size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		_tri_cache[key] = n
	return _tri_cache[key]


## A form drawn by a UrbsMonumentMesh builder at one level of detail, visible at every distance.
static func _single(out: Dictionary, r: Dictionary) -> void:
	(out.parts as Array).append({"mesh": r.mesh, "xform": Transform3D.IDENTITY, "own": true, "range": Vector2.ZERO})
	var tris := int(r.tris)
	for key in r.instances:
		var inst: Dictionary = r.instances[key]
		(out.instances as Array).append({"key": key, "mesh": inst.mesh, "xforms": inst.xforms, "range": Vector2.ZERO})
		tris += mesh_tris(inst.mesh) * (inst.xforms as Array).size()
	out.tris = [tris, tris, tris]
	for b in r.solids:
		(out.boxes as Array).append({"centre": b.centre, "size": b.size, "yaw": 0.0, "exact": true})
	out.opens = r.opens


## A form drawn by a UrbsMonumentMesh builder at the three levels of detail: `make(lod)` returns
## UrbsMonumentMesh.finish(). Each level's mesh and instanced parts carry their distance band;
## the solids and open footprints of lod 0 become the boxes for collision and picking.
static func _lodded(out: Dictionary, make: Callable) -> void:
	for l in 3:
		var r: Dictionary = make.call(l)
		var rng: Vector2 = LOD_RANGES[l]
		(out.parts as Array).append({"mesh": r.mesh, "xform": Transform3D.IDENTITY, "own": true, "range": rng})
		var tris := int(r.tris)
		for key in r.instances:
			var inst: Dictionary = r.instances[key]
			(out.instances as Array).append({"key": key, "mesh": inst.mesh, "xforms": inst.xforms, "range": rng})
			tris += mesh_tris(inst.mesh) * (inst.xforms as Array).size()
		(out.tris as Array)[l] = tris
		if l == 0:
			for b in r.solids:
				(out.boxes as Array).append({"centre": b.centre, "size": b.size, "yaw": 0.0, "exact": true})
			out.opens = r.opens


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
	if Temples.handles(model):
		var sp := Temples.spec(model, rec, st)
		_lodded(out, func(l: int) -> Dictionary: return Temples.build(sp.duplicate(), l))
		out.no_skirt = true
		out.base = "lo"
		out.door = Temples.door(sp)
		return
	if model == "circus_maximus":
		# 621 m long: one level of detail (a band measured from its centre would coarsen the
		# carceres for someone standing at them); its seat rows are long boxes, so it is cheap
		_single(out, Circus.build(Circus.spec(rec, st)))
		out.no_skirt = true
		out.base = "hi"
		return
	if Civic.handles(model):
		var sc := Civic.spec(model, rec, st)
		_lodded(out, func(l: int) -> Dictionary: return Civic.build(sc.duplicate(), l))
		out.no_skirt = true
		out.base = "lo" if model == "tabularium" else "hi"
		return
	match model:
		"plaza": _plaza(out, d, str(rec.get("surface", "travertine")))
		"comitium": _comitium(out, d)
		"aedicula": _aedicula(out, d)
		"altar": _altar(out, d)
		"altar_enclosure": _altar_enclosure(out, d)
		"basin": _basin(out, d)
		"arch": _arch_monument(out, d)
		"column_monument": _column_monument(out, d)
		"hut": _hut(out, d)
		"wall": _wall(out, st, route, ground)
		"sewer": _sewer(out, d, route, ground)
		"bridge_stone": _bridge_stone(out, d)
		"bridge_timber": _bridge_timber(out, d)
		"aqueduct": _aqueduct(out, d, st, route, ground)
		"circus_maximus": _circus(out, d)
		"quay": _quay(out, d)
		"long_hall": _long_hall(out, d)
		"shipsheds": _shipsheds(out, d)
		"portico_enclosure": _portico_ring(out, d, str(rec.get("id", "")))
		"tomb_drum": _tomb_drum(out, d)
		"tomb_pyramid": _tomb_pyramid(out, d)
		"tomb_rock": _tomb_rock(out, d)
		_:
			if Roman.KINDS.has(model):
				_kit(out, model, d, float(UNIFORM_DIAM.get(model, 0.0)))
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


# ---------------------------------------------------------------------------------------------
# Walking round curves and along routes
# ---------------------------------------------------------------------------------------------


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
	var yaw := Roman.yaw_z(dir)
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
				var col := Roman.EARTH_C.lightened(0.12) if j < 2 else Roman.WOOD.lightened(0.18)
				var mat := Kit.EARTH if j < 2 else Kit.TIMBER
				k.box(Vector3(x0, 0, (zstart + zs) / 2.0), Vector3(bd / 4.0 + 0.2, hh, zs - zstart), col, mat)
	# the curved end (sphendone): seat rings and, once in stone, the arcaded outer wall
	var arc_rows := 5
	if stone:
		Roman.seat_rings(k, 0.0, zs, tw / 2.0, tw / 2.0, 0.0, PI, arc_rows, bd / arc_rows, 1.7, Roman.TRAVERT.darkened(0.1), Roman.WOOD, Kit.STONE, Kit.TIMBER)
		Roman.arc_facade(k, 0.0, zs, W / 2.0 + 1.0, W / 2.0 + 1.0, 0.0, PI, 2, 5.0, Roman.TRAVERT.darkened(0.05), Kit.STONE, 7.0)
	else:
		Roman.seat_rings(k, 0.0, zs, tw / 2.0, tw / 2.0, 0.0, PI, arc_rows, bd / arc_rows, 1.6, Roman.EARTH_C, Roman.WOOD, Kit.EARTH, Kit.TIMBER)
	# the euripus: a water channel 10 ft wide inside the banks, but not at the carceres (Dion. Hal. 3.68)
	if stone:
		for side: float in [-1.0, 1.0]:
			k.box(Vector3(side * (tw / 2.0 - 1.6), 0.0, (zc0 + 40.0 + zs) / 2.0), Vector3(3.0, 0.3, zs - zc0 - 40.0), Roman.WATER_C, Kit.WATER)
		for e in Roman.arc_walk(0.0, zs, tw / 2.0 - 1.6, tw / 2.0 - 1.6, 0.0, PI, 6.0):
			var p: Vector2 = e.pos
			k.box(Vector3(p.x, 0.0, p.y), Vector3(float(e.len) * 1.05, 0.3, 3.0), Roman.WATER_C, Kit.WATER, Roman.yaw_x(e.tangent))
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



# ---------------------------------------------------------------------------------------------
# Routes drawn with the kit's tiles (the Servian wall, the aqueducts)
# ---------------------------------------------------------------------------------------------


## Appends the kit tile `mesh` (1.0 long = 10 m) at p, ground height y, along dir, `seg_len` metres
## long, its front (+z) turned towards `front`.
static func _tile(st: SurfaceTool, mesh: ArrayMesh, p: Vector2, y: float, dir: Vector2, front: Vector2,
		seg_len: float, sy := 1.0) -> void:
	var yaw := Roman.yaw_x(dir)
	if front.dot(Vector2(sin(yaw), cos(yaw))) < 0.0:
		yaw += PI
	var b := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(U * seg_len / 10.0, U * sy, U))
	st.append_from(mesh, 0, Transform3D(b, Vector3(p.x, y, p.y)))


static func _flush(out: Dictionary, st: SurfaceTool) -> void:
	var mesh := st.commit()
	if mesh.get_surface_count() > 0:
		_add(out, mesh)
		var a := mesh.get_aabb()
		_box_shape(out, a.get_center(), a.size)


## The Servian wall as kit tiles along the route (a closed circuit through the gates): `servian_wall`
## tiles of 10 m, `servian_wall_agger` between the Colline and Esquiline gates (st.agger, route
## distances), a tower every 90 m (assumed; Platner-Ashby mention towers only at the agger), a gap
## of 36 m at each gate (st.gates) for the `servian_gate` form. World coordinates.
static func _wall(out: Dictionary, st: Dictionary, route: PackedVector2Array, ground: Callable) -> void:
	out.world = true
	if route.size() < 2:
		return
	var total := _route_length(route)
	var area := 0.0
	for i in route.size() - 1:
		area += route[i].x * route[i + 1].y - route[i + 1].x * route[i].y
	var sign_out := 1.0 if area > 0.0 else -1.0
	var agger: Vector2 = st.get("agger", Vector2(-1, -1))
	var gates: Array = st.get("gates", [])
	var plain := _kit_mesh("servian_wall")
	var banked := _kit_mesh("servian_wall_agger")
	var tower := _kit_mesh("servian_tower")
	var sb := SurfaceTool.new()
	var acc := 0.0
	var s := 0.0
	var next_tower := 45.0
	while s < total:
		var seg := minf(10.0, total - s)
		var a := _route_at(route, s)
		var b := _route_at(route, s + seg)
		var pa: Vector2 = a.pos
		var pb: Vector2 = b.pos
		var dir := (pb - pa).normalized()
		var out_n := Vector2(-dir.y, dir.x) * sign_out
		var mid := (pa + pb) * 0.5
		var skip := false
		for g in gates:
			if absf(float(g) - (s + seg * 0.5)) < 18.0:
				skip = true
		if not skip and seg > 0.5:
			var y: float = minf(float(ground.call(pa.x, pa.y)), float(ground.call(pb.x, pb.y))) if ground.is_valid() else 10.0
			var on_agger := s >= agger.x and s <= agger.y
			_tile(sb, banked if on_agger else plain, mid, y, dir, out_n, seg)
			if s >= next_tower and not on_agger:
				_tile(sb, tower, mid + out_n * 0.8, y, dir, out_n, 10.0)
				next_tower = s + 90.0
		acc += seg
		s += seg
		if acc >= 250.0 or s >= total:
			_flush(out, sb)
			sb = SurfaceTool.new()
			acc = 0.0


## Aqueduct arcades as kit tiles along the route over the intervals st.arcade (route distances);
## `aqueduct_arcade_tall` scaled in height to d.h. World coordinates.
static func _aqueduct(out: Dictionary, d: Dictionary, st: Dictionary, route: PackedVector2Array, ground: Callable) -> void:
	out.world = true
	var tile := _kit_mesh("aqueduct_arcade_tall")
	var sy := maxf(float(d.h), 6.0) / 20.0
	for iv in st.get("arcade", []):
		var sb := SurfaceTool.new()
		var s := float(iv[0])
		var s1 := float(iv[1])
		var acc := 0.0
		while s < s1:
			var seg := minf(10.0, s1 - s)
			var a := _route_at(route, s)
			var b := _route_at(route, s + seg)
			var pa: Vector2 = a.pos
			var pb: Vector2 = b.pos
			var dir := (pb - pa).normalized()
			var y: float = minf(float(ground.call(pa.x, pa.y)), float(ground.call(pb.x, pb.y))) if ground.is_valid() else 10.0
			_tile(sb, tile, (pa + pb) * 0.5, y, dir, Vector2(-dir.y, dir.x), seg, sy)
			s += seg
			acc += seg
			if acc >= 240.0 or s >= s1:
				_flush(out, sb)
				sb = SurfaceTool.new()
				acc = 0.0


# ---------------------------------------------------------------------------------------------
# The old kit meshes on the shared material library (U8)
# ---------------------------------------------------------------------------------------------


## Candidate surfaces for each kit material id, with the colour each stands for (the kit's
## palette in roman.gd). A kit face goes to the nearest candidate by colour.
const LIB_CANDIDATES := {
	1: [["stucco_white", Color(0.95, 0.93, 0.88)], ["stucco_cream", Color(0.93, 0.88, 0.76)], ["stucco_ochre", Color(0.82, 0.62, 0.30)],
		["stucco_red", Color(0.66, 0.20, 0.15)], ["stucco_worn", Color(0.78, 0.72, 0.62)]],
	2: [["travertine", Color(0.88, 0.83, 0.72)], ["tufa_yellow", Color(0.76, 0.65, 0.42)], ["tufa_grey", Color(0.60, 0.56, 0.50)],
		["tufa_brown", Color(0.55, 0.49, 0.40)], ["marble_luna", Color(0.93, 0.91, 0.86)], ["basalt", Color(0.30, 0.30, 0.31)],
		["fountain_water", Color(0.55, 0.75, 0.85)]],
	5: [["timber_oak", Color(0.52, 0.38, 0.24)], ["timber_weathered", Color(0.62, 0.55, 0.45)], ["timber_painted", Color(0.30, 0.20, 0.12)]],
	9: [["bronze", Color(0.62, 0.45, 0.22)], ["gilt", Color(0.95, 0.78, 0.30)]],
	12: [["stucco_red", Color(0.66, 0.20, 0.15)], ["stucco_white", Color(0.95, 0.93, 0.88)], ["antefix_terracotta", Color(0.84, 0.52, 0.32)],
		["timber_painted", Color(0.30, 0.20, 0.12)], ["faction_blue", Color(0.22, 0.36, 0.56)], ["stucco_ochre", Color(0.82, 0.62, 0.30)]],
	13: [["earth_packed", Color(0.58, 0.48, 0.36)], ["sand_arena", Color(0.78, 0.68, 0.48)]],
}
## Kit material ids with a single surface.
const LIB_FIXED := {0: "tegulae", 3: "brick_latericium", 4: "stucco_worn", 6: "tegulae", 7: "timber_weathered",
	8: "shutter_wood", 10: "awning_canvas", 11: "awning_canvas", 14: "grass", 15: "fountain_water"}

static var _lib_cache := {}


## The surface name for a kit face of material `id` and colour `c`.
static func lib_name(id: int, c: Color) -> String:
	if LIB_FIXED.has(id):
		return LIB_FIXED[id]
	var best := "stucco_worn"
	var best_d := INF
	for cand in LIB_CANDIDATES.get(id, LIB_CANDIDATES[1]):
		var k: Color = cand[1]
		var d := Vector3(c.r - k.r, c.g - k.g, c.b - k.b).length_squared()
		if d < best_d:
			best_d = d
			best = cand[0]
	return best


## A kit mesh (vertex colours, material id in the alpha) split into one surface per UrbsMaterials
## name, with UVs in metres (`unit` metres per mesh unit) and tangents. Cached by the mesh.
static func to_library(mesh: ArrayMesh, unit := U) -> ArrayMesh:
	var key := mesh.get_instance_id()
	if _lib_cache.has(key):
		return _lib_cache[key]
	var tools := {}
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		var order := PackedInt32Array()
		if idx != null and (idx as PackedInt32Array).size() > 0:
			order = idx
		else:
			order.resize(verts.size())
			for i in verts.size():
				order[i] = i
		for t in range(0, order.size() - 2, 3):
			var i0 := order[t]
			var c := cols[i0] if cols.size() > i0 else Color(0.8, 0.8, 0.8, 0.15)
			var name := lib_name(int(c.a * 16.0), c)
			if not tools.has(name):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[name] = st
			var sto: SurfaceTool = tools[name]
			for k in 3:
				var vi := order[t + k]
				var p := verts[vi]
				var n := norms[vi] if norms.size() > vi else Vector3.UP
				sto.set_normal(n)
				sto.set_uv(UrbsMonumentMesh._uv(p * unit, n))
				sto.add_vertex(p)
	var out := ArrayMesh.new()
	var names: Array = tools.keys()
	names.sort()
	for name in names:
		var st2: SurfaceTool = tools[name]
		st2.generate_tangents()
		st2.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, UrbsMaterials.get_material(name))
	_lib_cache[key] = out
	return out
