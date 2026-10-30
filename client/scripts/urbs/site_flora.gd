## Urbs U8 "site": the trees and green of Rome, planted per chunk as MultiMeshes.
##
## Where (topography.yaml terrain_model, each entry with its sources):
##   - `woods`: the open hills round the city (oak, umbrella pine, cypress, scrub), never closer
##     than 1 km to the Forum;
##   - `groves`: what the sources put inside the city, each from its year: the two groves of the
##     Asylum on the Capitol (Livy 1.8.5), the fig, olive and vine of the Forum (Pliny NH 15.77-78),
##     the Ficus Ruminalis, the lucus Vestae, the plane trees of Pompey's portico (Propertius
##     2.32), the gardens (horti) of Lucullus, Sallust, Caesar and Maecenas;
##   - the steep tufa faces inside the walls (scrub, holm oak, figs: the cliffs could not be built
##     on) and the crests of the Capitol, Palatine and Aventine (a few pines and cypresses):
##     generic greenery, the modeller's choice;
##   - the farmland outside the walls (UrbsSite.parcel_at): olive groves in rows on the olive
##     parcels, hedgerows on the hedged field borders, a few field trees on pasture.
## Kinds: pine (umbrella pine, Pinus pinea), cypress, plane, olive, fig, oak (holm oak), laurel,
## scrub, hedge. LOD: chunks at lod 0-1 get full meshes (two surfaces, bark and foliage); lod 2
## chunks get low crowns only (a dozen triangles a tree), which read better than flat
## billboards from the high orbit camera.
## Materials: UrbsMaterials "bark" and "foliage" when the library has them (ask the rendering
## pass), else a vertex-coloured fallback with the species' colours.
class_name UrbsSiteFlora

const KINDS := ["pine", "cypress", "plane", "olive", "fig", "oak", "laurel", "scrub", "hedge"]
const CENTRE_NO_WOODS_M := 1000.0

static var _woods: Array = []
static var _groves: Array = []
static var _loaded := false
static var _meshes: Dictionary = {}       ## kind -> [full ArrayMesh, far ArrayMesh]
static var _blocked: Dictionary = {}      ## year -> {Vector2i cell: [[centre, radius], ...]}
static var _noise: FastNoiseLite = null


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_noise = FastNoiseLite.new()
	_noise.seed = 77
	_noise.frequency = 1.0 / 140.0
	var model: Dictionary = UrbsTiber.topography().get("terrain_model", {})
	for w: Dictionary in model.get("woods", []):
		_woods.append({"c": UrbsGeo.to_local(float(w["lat"]), float(w["lon"])), "r": float(w["radius"]), "d": float(w["density"]), "kinds": _mix(w.get("mix", {}))})
	for g: Dictionary in model.get("groves", []):
		var from_y: Variant = g.get("from")
		_groves.append({"id": str(g["id"]), "c": UrbsGeo.to_local(float(g["lat"]), float(g["lon"])), "r": float(g["radius"]),
			"d": float(g["density"]), "kinds": _mix(g.get("mix", {})), "from": -9999 if from_y == null else int(from_y),
			"grid": float(g.get("grid", 0.0))})


static func _mix(mix: Dictionary) -> Array:
	var kinds: Array = []
	var keys := mix.keys()
	keys.sort()
	for kind: String in keys:
		for c in int(mix[kind]):
			kinds.append(kind)
	return kinds


static func _hash(ix: int, iz: int, seed_: int) -> float:
	return UrbsSite.ihash(ix, iz, seed_ + 1000)


## Density 0..1 of the woods at (x, z) (no centre exclusion): for UrbsTerrain's farmland.
static func wood_density(x: float, z: float) -> float:
	_load()
	var best := 0.0
	for w: Dictionary in _woods:
		var d := (w["c"] as Vector2).distance_to(Vector2(x, z))
		best = maxf(best, float(w["d"]) * (1.0 - smoothstep(0.55 * float(w["r"]), float(w["r"]), d)))
	return best


static func _wood_at(x: float, z: float) -> Dictionary:
	var best := 0.0
	var pick: Dictionary = {}
	for w: Dictionary in _woods:
		var d := (w["c"] as Vector2).distance_to(Vector2(x, z))
		var f: float = float(w["d"]) * (1.0 - smoothstep(0.55 * float(w["r"]), float(w["r"]), d))
		if f > best:
			best = f
			pick = w
	return {"d": best, "w": pick}


## Approximate crown radius of a kind at scale 1, metres.
static func crown_radius(kind: String) -> float:
	return {"pine": 5.0, "cypress": 1.3, "plane": 6.0, "olive": 2.6, "fig": 3.2, "oak": 3.6, "laurel": 2.0, "scrub": 1.5, "hedge": 1.0}.get(kind, 2.0)


# ---------------------------------------------------------------- where the monuments stand

## Circles (centre, radius) round the monuments standing in `year`, bucketed in 100 m cells.
static func _blockers(year: int) -> Dictionary:
	if _blocked.has(year):
		return _blocked[year]
	var cells := {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(UrbsTiber.MONUMENTS_PATH))
	if parsed is Dictionary:
		for m: Dictionary in parsed.get("monuments", []):
			if str(m.get("model", "none")) == "none" or m.get("lat") == null:
				continue
			var b: Variant = m.get("built")
			if b is Dictionary and b.get("year") != null and int(b["year"]) > year:
				continue
			var e: Variant = m.get("ended")
			if e is Dictionary and e.get("year") != null and int(e["year"]) <= year:
				continue
			var fp: Variant = m.get("footprint_m")
			if not fp is Dictionary:
				continue
			var r := 0.5 * maxf(maxf(float(fp.get("length", 0) if fp.get("length") != null else 0), float(fp.get("width", 0) if fp.get("width") != null else 0)), 2.0 * float(fp.get("radius", 0) if fp.get("radius") != null else 0)) + 4.0
			if r < 6.0 or r > 400.0:
				continue
			var c := UrbsGeo.to_local(float(m["lat"]), float(m["lon"]))
			for cx in range(floori((c.x - r) / 100.0), floori((c.x + r) / 100.0) + 1):
				for cz in range(floori((c.y - r) / 100.0), floori((c.y + r) / 100.0) + 1):
					var key := Vector2i(cx, cz)
					if not cells.has(key):
						cells[key] = []
					cells[key].append([c, r])
	_blocked[year] = cells
	return cells


static func _blocked_at(cells: Dictionary, p: Vector2, pad: float) -> bool:
	var key := Vector2i(floori(p.x / 100.0), floori(p.y / 100.0))
	for item: Array in cells.get(key, []):
		if (item[0] as Vector2).distance_to(p) < float(item[1]) + pad:
			return true
	return false


# ---------------------------------------------------------------- where the trees stand

## The trees of `rect` at `lod` in `year`: [[kind, Transform3D, Color tint], ...].
static func spots(rect: Rect2, lod: int, year: int) -> Array:
	_load()
	var out: Array = []
	var cells := _blockers(year)
	_spots_woods(out, rect, lod)
	_spots_groves(out, rect, lod, year, cells)
	_spots_hills(out, rect, lod, cells)
	_spots_farms(out, rect, lod)
	return out


static func _plant(out: Array, kind: String, x: float, z: float, seed_a: int, seed_b: int, scale := 1.0) -> void:
	var y := UrbsTerrain.height_at(x, z)
	var sc := (0.78 + 0.5 * _hash(seed_a, seed_b, 5)) * scale
	var basis := Basis(Vector3.UP, _hash(seed_a, seed_b, 6) * TAU).scaled(Vector3(sc, sc * (0.9 + 0.22 * _hash(seed_a, seed_b, 7)), sc))
	var tone := 0.86 + 0.28 * _hash(seed_a, seed_b, 8)
	out.append([kind, Transform3D(basis, Vector3(x, y - 0.15, z)), Color(tone, tone, tone * (0.92 + 0.16 * _hash(seed_a, seed_b, 9)))])


static func _ok_ground(x: float, z: float, min_ny: float) -> bool:
	if UrbsTerrain.normal_at(x, z).y < min_ny:
		return false
	var wl := UrbsTerrain.river_level(x, z)
	if UrbsTerrain.height_at(x, z) < wl + 2.5:
		return false
	return UrbsTerrain.river_distance(x, z) > UrbsTerrain.river_half_width(x, z) + 12.0


static func _spots_woods(out: Array, rect: Rect2, lod: int) -> void:
	var spacing := 12.0 if lod <= 0 else (24.0 if lod == 1 else 36.0)
	var comp := 1.0 if lod <= 0 else (2.0 if lod == 1 else 3.0)   # fewer, bigger samples further out keep the look
	for gz in range(floori(rect.position.y / spacing), ceili(rect.end.y / spacing)):
		for gx in range(floori(rect.position.x / spacing), ceili(rect.end.x / spacing)):
			var x := (gx + _hash(gx, gz, 1)) * spacing
			var z := (gz + _hash(gx, gz, 2)) * spacing
			if not rect.has_point(Vector2(x, z)):
				continue
			var wood := _wood_at(x, z)
			var dens: float = wood["d"]
			if dens <= 0.0:
				continue
			var centre := smoothstep(CENTRE_NO_WOODS_M, CENTRE_NO_WOODS_M + 300.0, Vector2(x, z).length())
			var clump := smoothstep(-0.3, 0.3, _noise.get_noise_2d(x, z))
			var p := dens * (spacing * spacing / 100.0) * centre * clump / (comp * comp) * comp
			if _hash(gx, gz, 3) > p or not _ok_ground(x, z, 0.72):
				continue
			if UrbsTerrain.built_at(x, z) > 0.4:
				continue
			var kinds: Array = (wood["w"] as Dictionary)["kinds"]
			var kind: String = kinds[int(_hash(gx, gz, 4) * kinds.size()) % kinds.size()]
			if UrbsTerrain.normal_at(x, z).y < 0.84 and kind != "scrub":
				kind = "scrub"
			_plant(out, kind, x, z, gx, gz, 1.0 if lod <= 0 else 1.1)


static func _spots_groves(out: Array, rect: Rect2, lod: int, year: int, cells: Dictionary) -> void:
	for g: Dictionary in _groves:
		if year < int(g["from"]):
			continue
		var c: Vector2 = g["c"]
		var r: float = g["r"]
		if not rect.grow(r).has_point(c):
			continue
		var kinds: Array = g["kinds"]
		var gh := hash(str(g["id"])) & 0xffff
		if r < 12.0:   # a single tree or two: the sacred fig, the Forum's fig, olive and vine
			for k in kinds.size():
				var ang := TAU * float(k) / kinds.size() + float(gh)
				var p := c + Vector2(cos(ang), sin(ang)) * (r * 0.5 if kinds.size() > 1 else 0.0)
				if rect.has_point(p):
					_plant(out, kinds[k], p.x, p.y, gh, k, 1.0)
			continue
		var grid: float = g["grid"]
		var spacing: float = grid if grid > 0.0 else 9.0
		if lod >= 2:
			spacing *= 1.6
		for gz in range(floori((c.y - r) / spacing), ceili((c.y + r) / spacing) + 1):
			for gx in range(floori((c.x - r) / spacing), ceili((c.x + r) / spacing) + 1):
				var jit := 0.0 if grid > 0.0 else 1.0   # planes in a portico garden stand in rows
				var x := (gx + 0.5 + jit * (_hash(gx, gz, 21 + gh) - 0.5)) * spacing
				var z := (gz + 0.5 + jit * (_hash(gx, gz, 22 + gh) - 0.5)) * spacing
				var p := Vector2(x, z)
				if not rect.has_point(p) or p.distance_to(c) > r:
					continue
				if _hash(gx, gz, 23 + gh) > float(g["d"]) * (1.0 - smoothstep(0.7 * r, r, p.distance_to(c))):
					continue
				if UrbsSite.platform_at(x, z) == "" and UrbsTerrain.built_at(x, z) > 0.5:
					continue   # a street
				if _blocked_at(cells, p, 1.0) or not _ok_ground(x, z, 0.75):
					continue
				var kind: String = kinds[int(_hash(gx, gz, 24 + gh) * kinds.size()) % kinds.size()]
				_plant(out, kind, x, z, gx + gh, gz, 1.0)


## Generic green on the steep tufa faces and the hill crests inside the walls.
static func _spots_hills(out: Array, rect: Rect2, lod: int, cells: Dictionary) -> void:
	if rect.get_center().length() > 2600.0:
		return
	var poly := UrbsTerrain.circuit()
	var spacing := 9.0 if lod <= 0 else (14.0 if lod == 1 else 22.0)
	for gz in range(floori(rect.position.y / spacing), ceili(rect.end.y / spacing)):
		for gx in range(floori(rect.position.x / spacing), ceili(rect.end.x / spacing)):
			var x := (gx + _hash(gx, gz, 31)) * spacing
			var z := (gz + _hash(gx, gz, 32)) * spacing
			var p := Vector2(x, z)
			if not rect.has_point(p):
				continue
			var ny := UrbsTerrain.normal_at(x, z).y
			var top := UrbsTerrain.plateau_at(x, z)
			var steep := ny < 0.8 and ny > 0.45
			var crest := top > 0.35 and top < 0.97 and ny > 0.75
			if not steep and not crest:
				continue
			if UrbsTerrain.built_at(x, z) > 0.3 or UrbsTerrain.terrace_at(x, z) > 0.3:
				continue
			if poly.size() > 2 and not Geometry2D.is_point_in_polygon(p, poly) and top < 0.3:
				continue
			var prob := (0.55 if steep else 0.10) * (spacing * spacing / 81.0) / (1.0 if lod <= 0 else 1.8)
			if _hash(gx, gz, 33) > prob:
				continue
			if _blocked_at(cells, p, 2.0) or not _ok_ground(x, z, 0.4):
				continue
			var roll := _hash(gx, gz, 34)
			var kind := ""
			if steep:
				kind = "scrub" if roll < 0.5 else ("oak" if roll < 0.72 else ("fig" if roll < 0.86 else ("laurel" if roll < 0.95 else "cypress")))
			else:
				kind = "pine" if roll < 0.45 else ("cypress" if roll < 0.75 else ("oak" if roll < 0.9 else "laurel"))
			_plant(out, kind, x, z, gx, gz, 1.0)


## Olive groves in rows, hedgerows and field trees on the farmland.
static func _spots_farms(out: Array, rect: Rect2, lod: int) -> void:
	var c := rect.get_center()
	var any := false
	for sx in 3:
		for sz in 3:
			if UrbsTerrain.rural_at(rect.position.x + rect.size.x * (0.1 + 0.4 * sx), rect.position.y + rect.size.y * (0.1 + 0.4 * sz)) > 0.05:
				any = true
	if not any:
		return
	var step := 5.0 if lod <= 0 else (8.0 if lod == 1 else 12.0)
	var seen := {}
	for gz in range(floori(rect.position.y / step), ceili(rect.end.y / step)):
		for gx in range(floori(rect.position.x / step), ceili(rect.end.x / step)):
			var x := (gx + 0.5) * step
			var z := (gz + 0.5) * step
			var rural := UrbsTerrain.rural_at(x, z)
			if rural < 0.35:
				continue
			var pc := UrbsSite.parcel_at(x, z)
			var kind: String = pc["kind"]
			var q: Vector2 = pc["local"]
			var pid: Vector2i = pc["id"]
			if kind == "olive":
				var row := 9.0 if lod <= 1 else 18.0
				var cell := Vector2i(floori(q.x / row), floori(q.y / row))
				var key := "%d,%d,%d,%d" % [pid.x, pid.y, cell.x, cell.y]
				if seen.has(key):
					continue
				seen[key] = true
				var lq := (Vector2(cell) + Vector2(0.5, 0.5)) * row
				var size: Vector2 = pc["size"]
				var inside := Vector2(fposmod(lq.x, size.x), fposmod(lq.y, size.y))
				if inside.x < 3.0 or inside.x > size.x - 3.0 or inside.y < 3.0 or inside.y > size.y - 3.0:
					continue
				var w := UrbsSite.parcel_to_world(pc["angle"], pc["origin"], lq)
				if not rect.has_point(w) or UrbsTerrain.rural_at(w.x, w.y) < 0.35 or not _ok_ground(w.x, w.y, 0.85):
					continue
				_plant(out, "olive", w.x, w.y, pid.x * 97 + cell.x, pid.y * 89 + cell.y, 1.0 if lod <= 1 else 1.3)
			elif bool(pc["hedge"]) and float(pc["edge"]) < step * 0.5 and lod <= 1:
				# a hedgerow: an uneven line of shrubs with a tree now and then
				var hr := _hash(gx, gz, 41)
				if hr < (0.75 if lod == 0 else 0.55) and _ok_ground(x, z, 0.85) and UrbsTerrain.built_at(x, z) < 0.3:
					var hk := "hedge" if hr < 0.66 else ("oak" if hr < 0.71 else "laurel")
					_plant(out, hk, x + (_hash(gx, gz, 43) - 0.5) * 2.0, z + (_hash(gx, gz, 44) - 0.5) * 2.0, gx, gz, (0.8 + 0.9 * _hash(gx, gz, 45)) * (1.0 if lod == 0 else 1.4))
			elif kind == "pasture" and _hash(gx, gz, 42) < 0.004 * step * step / 25.0 and _ok_ground(x, z, 0.85):
				_plant(out, "oak", x, z, gx, gz, 1.1)
	var _unused := c


# ---------------------------------------------------------------- meshes

## Adds the MultiMesh trees of one chunk to `node` (lod 0-1 full meshes, lod 2 low crowns).
static func build_chunk(node: Node3D, rect: Rect2, lod: int, year: int) -> void:
	_ensure_meshes()
	var lists := {}
	for item: Array in spots(rect, lod, year):
		var kind: String = item[0]
		if not lists.has(kind):
			lists[kind] = []
		(lists[kind] as Array).append(item)
	for kind: String in KINDS:
		if not lists.has(kind):
			continue
		var items: Array = lists[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[kind][0 if lod <= 1 else 1]
		mm.instance_count = items.size()
		for q in items.size():
			mm.set_instance_transform(q, items[q][1])
			mm.set_instance_color(q, items[q][2])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Flora_" + kind
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = (1400.0 if lod <= 1 else 4500.0) if kind != "hedge" else 700.0
		node.add_child(mmi)


static func _material(name: String, colour_fallback: bool) -> Material:
	if UrbsMaterials.has(name):
		return UrbsMaterials.get_material(name)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = colour_fallback
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	m.albedo_color = Color(1, 1, 1)
	return m


static func _ensure_meshes() -> void:
	if not _meshes.is_empty():
		return
	var bark := Color(0.33, 0.27, 0.21)
	var bark_grey := Color(0.48, 0.45, 0.40)
	var bark_plane := Color(0.62, 0.58, 0.48)
	var tr := func(pos: Vector3, scl: Vector3, rot := 0.0) -> Transform3D:
		return Transform3D(Basis(Vector3.FORWARD, rot).scaled(scl), pos)
	var trunk := _cyl(6, 0.22, 0.34)
	var blob := _sphere(9, 5)
	var blob_far := _sphere(6, 3)
	var spindle := _sphere(8, 7)
	# umbrella pine: a tall bare trunk, a little crooked, a broad flat crown of dark green
	var pine_crown := Color(0.20, 0.29, 0.13)
	_meshes["pine"] = [_tree([[trunk, tr.call(Vector3(0.3, 4.2, 0), Vector3(1.3, 8.6, 1.3), 0.06), bark]],
		[[blob, tr.call(Vector3(0.6, 9.4, 0), Vector3(5.6, 1.7, 5.2)), pine_crown], [blob, tr.call(Vector3(2.4, 9.0, 1.2), Vector3(3.0, 1.3, 2.8)), pine_crown.lightened(0.06)],
		[blob, tr.call(Vector3(-1.6, 9.2, -1.4), Vector3(3.2, 1.4, 3.0)), pine_crown.darkened(0.06)]], 0.35),
		_tree([], [[blob_far, tr.call(Vector3(0.6, 9.4, 0), Vector3(5.6, 1.7, 5.2)), pine_crown]], 0.0)]
	# cypress: a dark narrow spindle
	var cyp := Color(0.13, 0.22, 0.10)
	_meshes["cypress"] = [_tree([[trunk, tr.call(Vector3(0, 0.6, 0), Vector3(0.7, 1.2, 0.7)), bark]],
		[[spindle, tr.call(Vector3(0, 6.2, 0), Vector3(1.35, 5.8, 1.35)), cyp]], 0.12),
		_tree([], [[_sphere(5, 4), tr.call(Vector3(0, 6.2, 0), Vector3(1.35, 5.8, 1.35)), cyp]], 0.0)]
	# plane: a pale mottled trunk, a broad high crown of light green
	var plane := Color(0.31, 0.41, 0.16)
	_meshes["plane"] = [_tree([[trunk, tr.call(Vector3(0, 3.0, 0), Vector3(1.8, 6.0, 1.8)), bark_plane]],
		[[blob, tr.call(Vector3(0, 9.5, 0), Vector3(5.6, 4.2, 5.6)), plane], [blob, tr.call(Vector3(3.0, 8.2, 1.0), Vector3(3.4, 2.8, 3.4)), plane.lightened(0.05)],
		[blob, tr.call(Vector3(-2.6, 8.6, -1.8), Vector3(3.6, 3.0, 3.6)), plane.darkened(0.05)], [blob, tr.call(Vector3(0.6, 11.8, -0.8), Vector3(3.0, 2.2, 3.0)), plane.lightened(0.08)]], 0.3),
		_tree([], [[blob_far, tr.call(Vector3(0, 9.5, 0), Vector3(6.2, 4.4, 6.2)), plane]], 0.0)]
	# olive: a short twisted grey trunk, a loose silvery crown
	var olive := Color(0.29, 0.33, 0.22)
	_meshes["olive"] = [_tree([[trunk, tr.call(Vector3(0.15, 0.8, 0), Vector3(2.2, 1.6, 2.2), 0.2), bark_grey], [trunk, tr.call(Vector3(-0.35, 1.7, 0.2), Vector3(1.3, 1.2, 1.3), -0.5), bark_grey]],
		[[blob, tr.call(Vector3(0.2, 2.9, 0), Vector3(2.5, 1.7, 2.4)), olive], [blob, tr.call(Vector3(-1.2, 2.5, 0.9), Vector3(1.6, 1.3, 1.6)), olive.lightened(0.05)],
		[blob, tr.call(Vector3(1.4, 2.3, -1.0), Vector3(1.5, 1.2, 1.5)), olive.darkened(0.05)]], 0.4),
		_tree([], [[blob_far, tr.call(Vector3(0.2, 2.7, 0), Vector3(2.7, 1.8, 2.6)), olive]], 0.0)]
	# fig: low and spreading, big leaves, mid green
	var fig := Color(0.27, 0.38, 0.14)
	_meshes["fig"] = [_tree([[trunk, tr.call(Vector3(0, 0.7, 0), Vector3(1.8, 1.4, 1.8)), bark_grey]],
		[[blob, tr.call(Vector3(0, 2.6, 0), Vector3(3.2, 1.9, 3.0)), fig], [blob, tr.call(Vector3(1.6, 2.3, 0.6), Vector3(1.8, 1.2, 1.8)), fig.lightened(0.05)]], 0.3),
		_tree([], [[blob_far, tr.call(Vector3(0, 2.6, 0), Vector3(3.4, 1.7, 3.2)), fig]], 0.0)]
	# holm oak: dark, dense, rounded
	var oak := Color(0.20, 0.28, 0.12)
	_meshes["oak"] = [_tree([[trunk, tr.call(Vector3(0, 1.5, 0), Vector3(1.2, 3.0, 1.2)), bark]],
		[[blob, tr.call(Vector3(0, 5.0, 0), Vector3(3.5, 2.9, 3.5)), oak], [blob, tr.call(Vector3(1.8, 4.2, 0.7), Vector3(2.1, 1.8, 2.1)), oak.lightened(0.05)],
		[blob, tr.call(Vector3(-1.5, 4.5, -0.9), Vector3(2.2, 1.9, 2.2)), oak.darkened(0.05)]], 0.3),
		_tree([], [[blob_far, tr.call(Vector3(0, 4.8, 0), Vector3(3.8, 3.0, 3.8)), oak]], 0.0)]
	# laurel: a dense dark bush-tree
	var laurel := Color(0.17, 0.27, 0.11)
	_meshes["laurel"] = [_tree([[trunk, tr.call(Vector3(0, 0.5, 0), Vector3(0.8, 1.0, 0.8)), bark]],
		[[spindle, tr.call(Vector3(0, 3.0, 0), Vector3(2.0, 2.8, 2.0)), laurel]], 0.25),
		_tree([], [[blob_far, tr.call(Vector3(0, 3.0, 0), Vector3(2.0, 2.8, 2.0)), laurel]], 0.0)]
	var scrub := Color(0.32, 0.35, 0.16)
	_meshes["scrub"] = [_tree([], [[blob, tr.call(Vector3(0, 0.7, 0), Vector3(1.5, 1.0, 1.5)), scrub], [blob, tr.call(Vector3(1.0, 0.5, 0.6), Vector3(1.0, 0.7, 1.0)), scrub.lightened(0.05)]], 0.35),
		_tree([], [[blob_far, tr.call(Vector3(0, 0.7, 0), Vector3(1.6, 1.0, 1.6)), scrub]], 0.0)]
	var hedge := Color(0.24, 0.32, 0.14)
	_meshes["hedge"] = [_tree([], [[blob, tr.call(Vector3(0, 1.0, 0), Vector3(1.4, 1.3, 1.4)), hedge], [blob, tr.call(Vector3(1.1, 0.9, 0.3), Vector3(1.1, 1.1, 1.1)), hedge.darkened(0.05)]], 0.3),
		_tree([], [[blob_far, tr.call(Vector3(0, 1.0, 0), Vector3(1.6, 1.3, 1.6)), hedge]], 0.0)]


static func _cyl(segments: int, top: float, bottom: float) -> PrimitiveMesh:
	var c := CylinderMesh.new()
	c.radial_segments = segments
	c.rings = 1
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = 1.0
	c.cap_top = false
	c.cap_bottom = false
	return c


static func _sphere(segments: int, rings: int) -> PrimitiveMesh:
	var s := SphereMesh.new()
	s.radial_segments = segments
	s.rings = rings
	s.radius = 1.0
	s.height = 2.0
	return s


## A tree mesh: surface 0 the wood ("bark"), surface 1 the leaves ("foliage"); each part is
## [PrimitiveMesh, Transform3D, Color]; crown vertices are pushed in and out by up to `lumpy`
## of their radius so the crowns are not smooth balls.
static func _tree(wood: Array, leaves: Array, lumpy: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not wood.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _merge(wood, 0.0))
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material("bark", true))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _merge(leaves, lumpy))
	mesh.surface_set_material(mesh.get_surface_count() - 1, _material("foliage", true))
	return mesh


static func _merge(parts: Array, lumpy: float) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var pi := 0
	for part: Array in parts:
		var arr: Array = (part[0] as PrimitiveMesh).get_mesh_arrays()
		var xf: Transform3D = part[1]
		var inv := xf.basis.inverse().transposed()
		var base := verts.size()
		var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for k in pv.size():
			var v := pv[k]
			if lumpy > 0.0:   # a deterministic bump per direction (the seam vertices share a direction, so no cracks)
				var dkey := (v * 7.0).round()
				var bump := 1.0 + lumpy * (UrbsSite.ihash(int(dkey.x) + pi * 13, int(dkey.y) * 7 + int(dkey.z), 3) - 0.5)
				v *= bump
			verts.append(xf * v)
			norms.append((inv * pn[k]).normalized())
			var shade := 0.82 + 0.25 * clampf(pn[k].y * 0.5 + 0.5, 0.0, 1.0)   # darker underneath
			var col: Color = part[2]
			cols.append(Color(col.r * shade, col.g * shade, col.b * shade))
		for i: int in arr[Mesh.ARRAY_INDEX]:
			idx.append(base + i)
		pi += 1
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = norms
	out[Mesh.ARRAY_COLOR] = cols
	out[Mesh.ARRAY_INDEX] = idx
	return out
