## Standalone test for the ground of Rome (task U2): builds UrbsTerrain and the Tiber alone,
## with a sun, and saves a screenshot. Run from client/:
##   /tmp/claude-0/render.sh --path . -s res://scripts/urbs/terrain_preview.gd -- --screenshot=/tmp/claude-0/terrain.png
## Flags (after the `--`):
##   --screenshot=PATH      save the picture and quit (without it the window stays open)
##   --view=NAME            a camera preset (see VIEWS; default aerial); --views=a,b,c takes
##                          several in one run and saves PATH_a.png, PATH_b.png, ...
##   --at=x,z,height        camera position in local metres (height above the ground at x,z? no:
##                          absolute y a.s.l.); overrides the preset
##   --look=x,z,height      point the camera looks at (default: the Forum, y = 12)
##   --fov=DEGREES          field of view (default 60)
##   --lod=0|1|2           chunk detail level (default 0)
##   --plain                grey clay material (debug: judge the shape alone)
##   --noshadow             sun without shadows
##   --marks                stand a pole with a name on each hill summit and on the Forum
##   --probe=x,z;x,z        print the ground height at those local points and quit
##   --perf=x,z,street|orbit  build the chunks UrbsChunks would load for a camera there (lod by
##                          distance) and print triangles and instances by kind, then quit
extends SceneTree

var _shot := ""
var _frames := 0
var args_noshadow := false
var _cam: Camera3D
var _args := {}
var _queue: PackedStringArray = PackedStringArray()
var _qi := 0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		var kv := s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	args_noshadow = args.has("noshadow")
	_shot = args.get("screenshot", "")
	var t0 := Time.get_ticks_msec()
	UrbsTerrain.prepare()
	print("heightfield: %d ms" % (Time.get_ticks_msec() - t0))
	if args.has("probe"):   # --probe=x,z;x,z;...  print the ground height at local points and quit
		for pt in String(args["probe"]).split(";"):
			var f := pt.split(",")
			if f.size() >= 2:
				print("probe %s: y=%.2f" % [pt, UrbsTerrain.height_at(float(f[0]), float(f[1]))])
		quit()
		return
	if args.has("perf"):
		_perf(String(args["perf"]))
		quit()
		return
	var root := Node3D.new()
	get_root().add_child(root)
	t0 = Time.get_ticks_msec()
	var ground := UrbsTerrain.build_all(root, int(args.get("lod", "0")))
	if args.has("plain"):   # debug: grey clay, to judge the shape alone
		var clay := StandardMaterial3D.new()
		clay.albedo_color = Color(0.7, 0.7, 0.7)
		for c in ground.get_children():
			if c is MeshInstance3D and c.name.begins_with("Chunk"):
				(c as MeshInstance3D).material_override = clay
	print("meshes: %d ms" % (Time.get_ticks_msec() - t0))
	_environment(root)
	if args.has("marks"):
		_marks(root)
	_cam = Camera3D.new()
	_cam.far = 12000.0
	_cam.near = 0.5
	root.add_child(_cam)
	_args = args
	_queue = String(args.get("views", args.get("view", "aerial"))).split(",")
	_apply_view(_queue[0])


const VIEWS := {
	"aerial": [Vector3(-300, 750, 1500), Vector3(0, 10, -50), 55.0],
	"forum": [Vector3(60, 14, 20), Vector3(-215, 25, -60), 70.0],
	"tiber": [Vector3(-300, 80, -200), Vector3(-640, 6, 0), 70.0],
	"island": [Vector3(-420, 110, 420), Vector3(-640, 6, 0), 60.0],
	"capitol": [Vector3(250, 120, 400), Vector3(-200, 30, -100), 60.0],
	"cliffs": [Vector3(-420, 45, 120), Vector3(-260, 30, -30), 60.0],
	"palatine": [Vector3(-100, 60, 560), Vector3(250, 35, 330), 60.0],
	"campus": [Vector3(-200, 400, -2600), Vector3(-800, 10, -1000), 60.0],
	"circus": [Vector3(600, 120, 900), Vector3(150, 12, 330), 65.0],
	"east": [Vector3(300, 140, 700), Vector3(1500, 45, 400), 60.0],
	"janiculum": [Vector3(-900, 150, 300), Vector3(-1900, 70, 0), 60.0],
	"top": [Vector3(0, 3200, 1), Vector3(0, 0, 0), 55.0],
	"aventine": [Vector3(-230, 52, 880), Vector3(120, 40, 430), 62.0],
	"isola": [Vector3(-480, 60, 140), Vector3(-640, 6, 280), 62.0],
	"forum_low": [Vector3(60, 12, 20), Vector3(-215, 25, -60), 70.0],
	"farms": [Vector3(1500, 160, 1500), Vector3(2100, 30, 2100), 60.0],
	"slopes": [Vector3(150, 60, -150), Vector3(400, 45, -400), 62.0],
}


func _apply_view(name: String) -> void:
	var v: Array = VIEWS.get(name, VIEWS["aerial"])
	var pos: Vector3 = v[0]
	var look: Vector3 = v[1]
	var fov: float = v[2]
	if _args.has("at"):
		pos = _vec(_args["at"])
	if _args.has("look"):
		look = _vec(_args["look"])
	if _args.has("fov"):
		fov = float(_args["fov"])
	_cam.fov = fov
	_cam.look_at_from_position(pos, look)
	print("view %s: camera at %s looking at %s; ground there %.1f m" % [name, pos, look, UrbsTerrain.height_at(pos.x, pos.z)])


func _vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[2]), float(p[1]))


func _environment(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -60, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = not args_noshadow
	sun.directional_shadow_max_distance = 5000.0
	root.add_child(sun)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.5, 0.78)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.88)
	sky_mat.ground_bottom_color = Color(0.45, 0.42, 0.36)
	sky_mat.ground_horizon_color = Color(0.72, 0.8, 0.88)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.8, 0.86)
	env.fog_density = 0.000012
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)


func _marks(root: Node3D) -> void:
	var spots := {"Forum": Vector2(0, 0)}
	var topo := UrbsTiber.topography()
	for key in ["hills", "other_heights"]:
		for hill: Dictionary in topo.get(key, []):
			spots[hill["english"]] = UrbsGeo.to_local(float(hill["lat"]), float(hill["lon"]))
	for name in spots:
		var p: Vector2 = spots[name]
		var y := UrbsTerrain.height_at(p.x, p.y)
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 3.0
		cyl.bottom_radius = 3.0
		cyl.height = 90.0
		pole.mesh = cyl
		pole.position = Vector3(p.x, y + 45.0, p.y)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.9, 0.1, 0.1)
		pole.material_override = m
		root.add_child(pole)
		var lab := Label3D.new()
		lab.text = "%s %.0f m" % [name, y]
		lab.pixel_size = 0.4
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		lab.position = Vector3(p.x, y + 70.0, p.y)
		root.add_child(lab)


func _process(_delta: float) -> bool:
	_frames += 1
	if _shot != "" and _frames % 8 == 0:
		var path := _shot
		if _queue.size() > 1:
			path = _shot.trim_suffix(".png") + "_" + _queue[_qi] + ".png"
		get_root().get_texture().get_image().save_png(path)
		print("saved ", path)
		_qi += 1
		if _qi >= _queue.size():
			quit()
		else:
			_apply_view(_queue[_qi])
	return false


## Triangles and draw items of the ground a camera at `spec` (x,z,street|orbit) would load.
func _perf(spec: String) -> void:
	var f := spec.split(",")
	var focus := Vector2(float(f[0]), float(f[1]))
	var orbit := f.size() > 2 and f[2] == "orbit"
	var radius := UrbsChunks.ORBIT_RADIUS if orbit else UrbsChunks.STREET_RADIUS
	var reach := int(ceil(radius / UrbsChunks.SIZE))
	var centre := UrbsChunks.key_of(focus.x, focus.y)
	var tris := {}
	var items := {}
	var count := 0
	var t0 := Time.get_ticks_msec()
	var worst := 0
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var key := centre + Vector2i(dx, dz)
			var rect := UrbsChunks.rect_of(key)
			var c := rect.get_center()
			var d := c.distance_to(focus)
			if d > radius + UrbsChunks.SIZE * 0.5 or c.length() > UrbsGeo.RADIUS_M + UrbsChunks.SIZE:
				continue
			var lod := 2 if orbit else UrbsChunks._lod_at(d)
			var t1 := Time.get_ticks_msec()
			var node := UrbsTerrain.build_chunk(rect, lod)
			worst = maxi(worst, Time.get_ticks_msec() - t1)
			count += 1
			for ch in node.get_children():
				var kind := String(ch.name).split("_")[0]
				var n := 0
				if ch is MeshInstance3D:
					n = _mesh_tris((ch as MeshInstance3D).mesh)
				elif ch is MultiMeshInstance3D:
					var mm := (ch as MultiMeshInstance3D).multimesh
					n = _mesh_tris(mm.mesh) * mm.instance_count
					items[kind + "_instances"] = int(items.get(kind + "_instances", 0)) + mm.instance_count
				else:
					continue
				tris[kind] = int(tris.get(kind, 0)) + n
				items[kind] = int(items.get(kind, 0)) + 1
			node.free()
	var total := 0
	for k in tris:
		total += int(tris[k])
	print("perf %s: %d chunks in %d ms (worst chunk %d ms); triangles %d" % [spec, count, Time.get_ticks_msec() - t0, worst, total])
	var keys := tris.keys()
	keys.sort()
	for k in keys:
		print("  %-12s %9d tris  %4d nodes  %s" % [k, tris[k], items.get(k, 0), ("%d instances" % items[k + "_instances"]) if items.has(k + "_instances") else ""])


func _mesh_tris(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var n := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		n += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n
