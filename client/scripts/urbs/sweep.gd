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
				p2 = clear_stand(view, p2, yaw, float(d.get("pitch", -3.0)))
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
		var img := tree.root.get_viewport().get_texture().get_image()
		if img != null:   # headless (no picture): the stands are still chosen and printed
			img.save_png(path)
		var at: Vector3 = urbs.cam.camera.global_position
		print("SWEEP %s %.0f %.0f %.0f" % [name, at.x, at.z, at.y])
		print("SWEEP_MS %d" % Time.get_ticks_msec())   # F3 monuments: when each shot was taken
		n += 1
	if urbs.interior != null:   # F3 monuments
		urbs._leave_interior_now()
	print("SWEEP DONE %d" % n)


## F3: the sight distance a street pose must have straight ahead (and 20 degrees either side).
const CLEAR_AHEAD := 6.0
## F3 round 4: the frame test (UrbsMonumentFrame.cast, the monuments' frame-coverage rays): what
## each of FRAME_COLS x FRAME_ROWS lines through the street camera's frame meets first within
## CLEAR_AHEAD m (the floor below the horizon not counted). A stand fails when more than
## FRAME_MAX of the whole frame, or more than FRAME_MID_MAX of its middle third, is filled so near
## (a street's two house fronts fill the frame's sides, a wall in the camera's face its middle).
const FRAME_COLS := 15
const FRAME_ROWS := 8
const FRAME_MAX := 0.6
const FRAME_MID_MAX := 0.1


## F3: where a street pose stands: `p` (already pushed out of the houses and monuments) when the
## eye there is free (UrbsMonumentView.is_free: not in a house, a monument's solid or drawn body, a
## tree's crown, at the foot of a bank) and sees CLEAR_AHEAD m along the view and 20 degrees either
## side (UrbsMonumentView.is_clear: the ground, the monuments' solids, the wall's stones, the
## houses, the trees); else the nearest stand that does, on rings 1.5 m apart out to 90 m. The
## camera stood in the 1.4 m slot between two insulae looking at a side wall (-603, -499, 44 BC).
## F3 round 4: the sight test is what is drawn (_frame_near): the monuments' own triangles (the
## Circus's barrier, a podium's mouldings), the houses down to their plinths on a slope, the trees'
## crowns. The plan rectangles and solid boxes passed six stands against a wall or the barrier.
static func clear_stand(view: UrbsMonumentView, p: Vector2, yaw: float, pitch := -3.0) -> Vector2:
	view._load_lots(p, 100.0)
	_plinths(view)
	if _frame == null or _frame.view != view:
		_frame = UrbsMonumentFrame.new(view)
	_frame.prepare(p, 100.0)
	_pitch = pitch
	var eye0 := Vector3(p.x, view.floor_at(Vector3(p.x, 0.0, p.y)) + UrbsCamera.EYE, p.y)
	var f0 := _frame_near(eye0, yaw, pitch)
	print("SWEEP_FRAME asked (%.0f, %.0f): %.2f of the frame, %.2f of its middle within %.0f m" % [p.x, p.y, f0[0], f0[1], CLEAR_AHEAD])
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
	for ring in range(1, 61):   # out to 90 m (by the Tiber Island every stand within 45 m was in the water)
		var r := 1.5 * ring
		var steps := maxi(8, int(TAU * r / 1.5))
		for k in steps:
			var a := TAU * float(k) / float(steps)
			var q := p + Vector2(cos(a), sin(a)) * r
			if _stand_ok(view, q, yaw):
				print("SWEEP_FRAME stand (%.0f, %.0f), %.1f m off" % [q.x, q.y, r])
				return q
	print("SWEEP_FRAME no clear stand within 90 m")
	return p


static var _envs: Array = []
static var _frame: UrbsMonumentFrame = null
static var _pitch := -3.0


## F3 round 4: the house lots as the frame test sees them (UrbsMonumentView._load_lots: a box from
## 1 m under the ground at the lot's centre) taken down to the lowest ground under the lot's
## corners: a house on a slope stands on a plinth to the ground at its downhill side.
static func _plinths(view: UrbsMonumentView) -> void:
	for lot: Dictionary in view._lots:
		if lot.has("plinth"):
			continue
		lot["plinth"] = true
		var c: Vector2 = lot.c
		var lo := INF
		var hi := -INF
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var q: Vector2 = c + (lot.ax as Vector2) * float(lot.hx) * sx + (lot.az as Vector2) * float(lot.hz) * sz
				var g := view._ground(q.x, q.y)
				lo = minf(lo, g)
				hi = maxf(hi, g)
		lot.y0 = minf(float(lot.y0), lo - 0.2)
		lot.y1 = maxf(float(lot.y1), hi + float(lot.y1) - view._ground(c.x, c.y))


## F3 round 4: the share of the frame from `eye` (turned `yaw`, tilted `pitch_deg`) filled by
## something drawn within CLEAR_AHEAD m, [whole frame, its middle third].
static func _frame_near(eye: Vector3, yaw: float, pitch_deg: float) -> Array:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(pitch_deg))
	var ty := tan(deg_to_rad(UrbsMonumentFrame.VFOV * 0.5))
	var tx := ty * UrbsMonumentFrame.ASPECT
	var near := 0
	var mid := 0
	var n_mid := 0
	var dbg := OS.has_environment("F3_FRAME_DEBUG")
	var rows: Array = []
	for j in FRAME_ROWS:
		rows.append("")
	for i in FRAME_COLS:
		var u := ((i + 0.5) / FRAME_COLS) * 2.0 - 1.0
		var in_mid := absf(u) < 1.0 / 3.0
		for j in FRAME_ROWS:
			var w := 1.0 - ((j + 0.5) / FRAME_ROWS) * 2.0
			var d := (basis * Vector3(u * tx, w * ty, -1.0)).normalized()
			var hit := _frame.cast(eye, d, CLEAR_AHEAD)
			var full := str(hit[1]) != "" and float(hit[0]) < CLEAR_AHEAD and not (str(hit[1]) == "ground" and d.y < 0.0)
			if dbg:
				rows[j] += (str(hit[1]).substr(0, 1) if str(hit[1]) != "" else ".") + ("%d" % mini(int(float(hit[0])), 9) if str(hit[1]) != "" else " ") + " "
			if in_mid:
				n_mid += 1
			if full:
				near += 1
				if in_mid:
					mid += 1
	if dbg:
		print("FRAMEDBG eye %s lots %d" % [eye, _frame.view._lots.size()])
		for r: String in rows:
			print("FRAMEDBG " + r)
	return [float(near) / (FRAME_COLS * FRAME_ROWS), float(mid) / maxi(n_mid, 1)]


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
	if UrbsTerrain.in_river(q.x, q.y) or UrbsTerrain.height_at(q.x, q.y) < UrbsTerrain.river_level(q.x, q.y) + 0.3 \
			or UrbsTerrain.river_distance(q.x, q.y) < UrbsTerrain.river_half_width(q.x, q.y) + 6.0:
		return false   # (and off the drawn water's edge: a camera stood in it below the Pons Aemilius)
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
	# F3 round 4: what is drawn within CLEAR_AHEAD m fills too much of the frame (the monuments'
	# triangles, the houses to their plinths, the trees; the Circus's barrier 1 m off)
	return _frame_ok(eye, yaw, _pitch)


## F3 round 4: _frame_near's test, stopping at the first line that settles it (the middle third
## first): most stands round the Circus failed, each over its 120 lines.
static func _frame_ok(eye: Vector3, yaw: float, pitch_deg: float) -> bool:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(pitch_deg))
	var ty := tan(deg_to_rad(UrbsMonumentFrame.VFOV * 0.5))
	var tx := ty * UrbsMonumentFrame.ASPECT
	var cols: Array = []
	for i in FRAME_COLS:
		cols.append(i)
	cols.sort_custom(func(x: int, y: int) -> bool: return absf(x - (FRAME_COLS - 1) * 0.5) < absf(y - (FRAME_COLS - 1) * 0.5))
	var n_mid := 0
	for i: int in cols:
		if absf(((i + 0.5) / FRAME_COLS) * 2.0 - 1.0) < 1.0 / 3.0:
			n_mid += 1
	var near := 0
	var mid := 0
	for i: int in cols:
		var u := ((i + 0.5) / FRAME_COLS) * 2.0 - 1.0
		var in_mid := absf(u) < 1.0 / 3.0
		for j in FRAME_ROWS:
			var w := 1.0 - ((j + 0.5) / FRAME_ROWS) * 2.0
			var d := (basis * Vector3(u * tx, w * ty, -1.0)).normalized()
			var hit := _frame.cast(eye, d, CLEAR_AHEAD)
			if str(hit[1]) != "" and float(hit[0]) < CLEAR_AHEAD and not (str(hit[1]) == "ground" and d.y < 0.0):
				near += 1
				if in_mid:
					mid += 1
					if mid > FRAME_MID_MAX * n_mid * FRAME_ROWS:
						return false
				if near > FRAME_MAX * FRAME_COLS * FRAME_ROWS:
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
