## Visual sweep (F3): photograph the city from many viewpoints in one run, for review.
##   --sweep=<poses.json> --sweep-out=<dir>   (with --urbs --year=N; main.gd runs it)
## poses.json: {"poses": [ ... ]} where each pose is one of
##   {"kind": "monument", "id": "<monument id>"}          street view of its front (as --at=<id>)
##   {"kind": "all_monuments"}                            expands to every monument standing
##   F3 monuments: {"kind": "inside", "id": "<monument id>"}  inside it, from its spawn (as
##   --mode=inside); {"kind": "all_interiors"} expands to every enterable monument standing;
##   "from"/"count" on all_monuments / all_interiors take a slice of the sorted list (batches);
##   an inside pose may add "look": [yaw, pitch] in degrees to turn from the spawn (0,0 = as spawned);
##   any pose may set "life": false to skip ticking the street life before the shot (faster)
##   {"kind": "street", "x": 0, "z": 0, "yaw": 90}        eye height, compass bearing in degrees
##   {"kind": "air", "x": 0, "z": 0, "h": 120, "yaw": 0, "pitch": -35}   a low aerial
##   optional "name" (file name) and "pitch" for street views.
## Each shot: camera placed, the chunks around it built at once, street life ticked, a few frames
## rendered, the picture saved as <dir>/<name>.png, and a line "SWEEP <name> x z" printed.
class_name UrbsSweep
extends RefCounted


static func expand(urbs: Node3D, poses: Array) -> Array:
	var out: Array = []
	for p in poses:
		var d: Dictionary = p
		if str(d.get("kind", "")) == "all_monuments":
			var ids: Array = urbs.monuments.ids()
			ids.sort()
			for id in _slice(ids, d):   # F3 monuments: batches
				out.append({"kind": "monument", "id": str(id)})
		# F3 monuments (begin): every enterable monument, from inside
		elif str(d.get("kind", "")) == "all_interiors":
			var ids2: Array = []
			for id in urbs.monuments.ids():
				if bool(urbs.monuments.info(id).get("enterable", false)):
					ids2.append(id)
			ids2.sort()
			for id in _slice(ids2, d):
				out.append({"kind": "inside", "id": str(id)})
		# F3 monuments (end)
		else:
			out.append(d)
	return out


# F3 monuments (begin)
static func _slice(ids: Array, d: Dictionary) -> Array:
	var a := int(d.get("from", 0))
	var n := int(d.get("count", ids.size()))
	return ids.slice(a, mini(a + n, ids.size()))


## Inside monument `id` from its spawn (urbs.gd `--mode=inside`), turned by `look` degrees.
## false when it has no interior.
static func _inside(urbs: Node3D, id: String, d: Dictionary) -> bool:
	if urbs.interior != null:
		urbs._leave_interior_now()
	urbs._enter_interior_now(id)
	if urbs.interior == null:
		return false
	urbs.hud.visible = false
	var look: Array = d.get("look", [0, 0])
	if look.size() >= 2 and (float(look[0]) != 0.0 or float(look[1]) != 0.0):
		var xf: Transform3D = urbs.interior.spawn() if urbs.interior.has_method("spawn") else Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0))
		var b := xf.basis.rotated(Vector3.UP, -deg_to_rad(float(look[0])))
		b = b * Basis(Vector3.RIGHT, deg_to_rad(float(look[1])))
		urbs.cam.snap_inside(Transform3D(b, xf.origin))
	return true
# F3 monuments (end)


static func run(urbs: Node3D, tree: SceneTree, poses_path: String, out_dir: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(poses_path))
	var poses: Array = expand(urbs, (parsed as Dictionary).get("poses", []) if parsed is Dictionary else [])
	DirAccess.make_dir_recursive_absolute(out_dir)
	urbs.hud.visible = false
	for layer in tree.root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	var n := 0
	var view: UrbsMonumentView = null
	for p in poses:
		var d: Dictionary = p
		var kind := str(d.get("kind", ""))
		var name := str(d.get("name", ""))
		if kind != "inside" and urbs.interior != null:   # F3 monuments: back out to the street
			urbs._leave_interior_now()
		match kind:
			"inside":   # F3 monuments
				var iid := str(d.get("id", ""))
				if not urbs.monuments.ids().has(iid) or not _inside(urbs, iid, d):
					print("SWEEP NOINTERIOR %s" % iid)
					continue
				if name == "":
					name = "i_" + iid + ("" if not d.has("look") else "_%d_%d" % [int(d.look[0]), int(d.look[1])])
			"monument":
				var id := str(d.get("id", ""))
				if not urbs.monuments.ids().has(id):
					continue
				urbs._apply_flags({"mode": "street", "at": id})
				urbs.hud.visible = false
				if name == "":
					name = "m_" + id
			"street":
				var x := float(d.get("x", 0.0))
				var z := float(d.get("z", 0.0))
				var yaw := -deg_to_rad(float(d.get("yaw", 0.0)))
				var p2: Vector2 = urbs.push_out(Vector2(x, z), 0.6, 1.7)
				if view == null:
					view = UrbsMonumentView.new(urbs.monuments, Callable(urbs, "height_at"), urbs.fill)
				p2 = clear_stand(view, p2, yaw)
				urbs.cam.snap_street(Vector3(p2.x, 0, p2.y), yaw, UrbsCamera.EYE, deg_to_rad(float(d.get("pitch", -3.0))))
				if name == "":
					name = "s_%d_%d_%d" % [int(x), int(z), int(d.get("yaw", 0))]
			"air":
				var x := float(d.get("x", 0.0))
				var z := float(d.get("z", 0.0))
				var yaw := -deg_to_rad(float(d.get("yaw", 0.0)))
				var h := float(d.get("h", 120.0))
				urbs.cam.snap_street(Vector3(x, 0, z), yaw, h, deg_to_rad(float(d.get("pitch", -35.0))))
				if name == "":
					name = "a_%d_%d_%d" % [int(x), int(z), int(d.get("yaw", 0))]
			_:
				continue
		if kind != "inside":   # F3 monuments: the city is hidden inside
			urbs.chunks.focus_on(urbs.cam.focus(), false)
			urbs.fill.sync_chunks = true
			urbs.chunks.load_all_now()
			urbs.fill.sync_chunks = false
			for i in (20 if bool(d.get("life", true)) else 0):   # F3 monuments: "life": false skips the street life
				urbs.life.tick(1.0 / 30.0, urbs.cam.camera.global_position)
		for i in 5:
			await tree.process_frame
		var path := out_dir.path_join(name + ".png")
		tree.root.get_viewport().get_texture().get_image().save_png(path)
		var at: Vector3 = urbs.cam.camera.global_position
		print("SWEEP %s %.0f %.0f %.0f" % [name, at.x, at.z, at.y])
		print("SWEEP_MS %d" % Time.get_ticks_msec())   # F3 monuments: when each shot was taken
		n += 1
	if urbs.interior != null:   # F3 monuments
		urbs._leave_interior_now()
	print("SWEEP DONE %d" % n)


## F3: the sight distance a street pose must have straight ahead (and 20 degrees either side).
const CLEAR_AHEAD := 6.0


## F3: where a street pose stands: `p` (already pushed out of the houses and monuments) when the
## eye there is free (UrbsMonumentView.is_free: not in a house, a monument's solid or drawn body, a
## tree's crown, at the foot of a bank) and sees CLEAR_AHEAD m along the view and 20 degrees either
## side (UrbsMonumentView.is_clear: the ground, the monuments' solids, the wall's stones, the
## houses, the trees); else the nearest stand that does, on rings 1.5 m apart out to 45 m. The
## camera stood in the 1.4 m slot between two insulae looking at a side wall (-603, -499, 44 BC).
static func clear_stand(view: UrbsMonumentView, p: Vector2, yaw: float) -> Vector2:
	view._load_lots(p, 60.0)
	# the houses' envelopes (eaves, balconies, awnings and their poles): the eye stays out of them
	_envs = []
	if view.fill != null:
		for lot in view.fill.lots_for_chunk(Vector2i(floori(p.x / UrbsFill.CHUNK), floori(p.y / UrbsFill.CHUNK))) \
				+ _near_chunks(view.fill, p):
			if str(lot.get("kind", "")) in ["prop", "tree", "furn"] or (lot["c"] as Vector2).distance_to(p) > 80.0:
				continue
			_envs.append(view.fill._env(lot))
		# the farm steadings of the open country (UrbsFill.rural_step: not among the chunks' lots;
		# the camera stood inside a barn at -1200,100 in 264 BC), each as its whole steading
		var k0 := Vector2i(floori(p.x / UrbsFill.CHUNK), floori(p.y / UrbsFill.CHUNK))
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var st := {}
				view.fill.rural_step(k0 + Vector2i(dx, dz), st, Time.get_ticks_usec() + 1000000000)
				for lot in view.fill.rural_lots(st.get("parcels", [])):
					if (lot["c"] as Vector2).distance_to(p) < 120.0:
						var ax: Array = view.fill._axes(lot)
						_envs.append({"c": lot["c"], "ax": ax[0], "az": ax[1], "hx": lot["hx"], "hz": lot["hz"]})
	if _stand_ok(view, p, yaw):
		return p
	for ring in range(1, 31):
		var r := 1.5 * ring
		var steps := maxi(8, int(TAU * r / 1.5))
		for k in steps:
			var a := TAU * float(k) / float(steps)
			var q := p + Vector2(cos(a), sin(a)) * r
			if _stand_ok(view, q, yaw):
				return q
	return p


static var _envs: Array = []


static func _near_chunks(fill: UrbsFill, p: Vector2) -> Array:
	var out: Array = []
	var k0 := Vector2i(floori(p.x / UrbsFill.CHUNK), floori(p.y / UrbsFill.CHUNK))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var k := k0 + Vector2i(dx, dz)
			if (Vector2(k) * UrbsFill.CHUNK + Vector2(UrbsFill.CHUNK, UrbsFill.CHUNK) * 0.5).distance_to(p) > UrbsFill.CHUNK:
				continue
			for rk in fill.regions_for_chunk(k):
				while not fill.advance_region(rk, Time.get_ticks_usec() + 1000000000):
					pass
			out.append_array(fill.lots_for_chunk(k))
	return out


## The view's rays: straight ahead CLEAR_AHEAD m, and 3 m out to the frame's sides (the picture is
## about 105 degrees wide).
const RAYS := [[0.0, CLEAR_AHEAD], [-0.4, CLEAR_AHEAD], [0.4, CLEAR_AHEAD], [-0.8, 3.0], [0.8, 3.0]]


static func _stand_ok(view: UrbsMonumentView, q: Vector2, yaw: float) -> bool:
	# not in the river (the camera stood under the Tiber's surface at -900,100)
	if UrbsTerrain.in_river(q.x, q.y) or UrbsTerrain.height_at(q.x, q.y) < UrbsTerrain.river_level(q.x, q.y) + 0.3:
		return false
	for e: Dictionary in _envs:
		var r: Vector2 = q - (e["c"] as Vector2)
		if absf(r.dot(e["ax"])) < float(e["hx"]) + 0.6 and absf(r.dot(e["az"])) < float(e["hz"]) + 0.6:
			return false
	var eye := Vector3(q.x, view.floor_at(Vector3(q.x, 0.0, q.y)) + UrbsCamera.EYE, q.y)
	if not view.is_free(eye):
		return false
	# the site works (quays, clivus and platform walls, the steps' side walls: UrbsFill keeps
	# their faces): the stand 1 m clear of them, the view rays 0.3 m (the camera stood between
	# a quay wall and the Pons Aemilius's abutment at -604,100)
	if view.fill != null:
		if _works_near(view.fill, q, 1.0):
			return false
		for ray: Array in RAYS:
			var a: float = yaw + float(ray[0])
			var dir := Vector2(-sin(a), -cos(a))
			for s in int(float(ray[1]) / 0.5):
				if _works_near(view.fill, q + dir * (0.5 * float(s + 1)), 0.3):
					return false
	for ray: Array in RAYS:
		var a: float = yaw + float(ray[0])
		var ahead := eye + Vector3(-sin(a), 0.0, -cos(a)) * (float(ray[1]) + 1.5)   # is_clear spares the last 1.5 m
		if not view.is_clear(eye, ahead, ""):
			return false
	# and at chest height straight ahead: a podium or a barrier whose top is at the eye's level
	# (the Circus's arena wall stood 1 m before the camera, its coping filling the picture)
	var low := eye - Vector3(0.0, 0.8, 0.0)
	if not view.is_clear(low, low + Vector3(-sin(yaw), 0.0, -cos(yaw)) * (CLEAR_AHEAD + 1.5), ""):
		return false
	return true


## Whether a wall face of the site works (UrbsFill._works_grid, 2D) lies within `r` of `p`.
static func _works_near(fill: UrbsFill, p: Vector2, r: float) -> bool:
	var cell := UrbsFill.WORKS_CELL
	for gz in range(floori((p.y - r) / cell), floori((p.y + r) / cell) + 1):
		for gx in range(floori((p.x - r) / cell), floori((p.x + r) / cell) + 1):
			for tri: PackedVector2Array in fill._works_grid.get(Vector2i(gx, gz), []):
				if Geometry2D.point_is_inside_triangle(p, tri[0], tri[1], tri[2]):
					return true
				for i in 3:
					if Geometry2D.get_closest_point_to_segment(p, tri[i], tri[(i + 1) % 3]).distance_to(p) < r:
						return true
	return false
