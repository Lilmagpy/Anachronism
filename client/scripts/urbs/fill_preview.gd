## Preview of streets.gd and fill.gd on flat ground (no terrain needed), for screenshots.
##
## cd client && /tmp/claude-0/render.sh --path . -s res://scripts/urbs/fill_preview.gd -- \
##     --year=-50 --street=subura --t=0.35 --eye=1.7 --pitch=-3 --shot=/tmp/claude-0/streets_a.png
##
## Flags: --year=N (default -50)           --shot=PATH (default: no picture, just counts)
##   --street=ID --t=0..1                  stand on that street, looking along it (+ --back to look the other way)
##   --at=x,z                              or stand at local metres x, z (then --yaw=DEG, 0 = north)
##   --eye=M (default 1.7)  --pitch=DEG (default -3)  --yaw=DEG  --radius=M (chunks loaded, default 450)
##   --lod=0..2   --hour=H (default 10)   --steps: time the incremental chunk build (worst step, ms)   --count: report building counts inside the Servian wall    --flat: flat ground instead of the real terrain; --slope: with --flat, tilt the ground (+4% to the east) to test the foundations
extends SceneTree

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		var kv := s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _run() -> void:
	var year := int(args.get("year", "-50"))
	var radius := float(args.get("radius", "450"))
	var lod := int(args.get("lod", "0"))
	var tilt := args.has("slope")
	var flat := args.has("flat")
	var height: Callable = func(x: float, z: float) -> float:
		if flat:
			return 10.0 + (x * 0.04 if tilt else 0.0)
		return UrbsTerrain.height_at(x, z)
	var root := Node3D.new()
	get_root().add_child(root)
	_environment(root, float(args.get("hour", "10")))
	# ground
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8000, 8000)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.42, 0.30)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position.y = 9.95
	if flat and not tilt:
		root.add_child(ground)
	var streets := UrbsStreets.new()
	streets.build(root, year, height)
	var fill := UrbsFill.new()
	var feet := UrbsFill.footprints_from_json(year)
	# camera pose
	var pos := Vector3.ZERO
	var yaw := deg_to_rad(float(args.get("yaw", "0")))
	if args.has("street"):
		var sid := str(args["street"])
		var t := float(args.get("t", "0.5"))
		var p := streets.along(sid, t)
		var p2 := streets.along(sid, t + (-0.01 if args.has("back") else 0.01))
		var dir := Vector2(p2.x - p.x, p2.z - p.z).normalized()
		yaw = atan2(dir.x, -dir.y)
		pos = Vector3(p.x, 0, p.z)
	elif args.has("at"):
		var f := String(args["at"]).split(",")
		pos = Vector3(float(f[0]), 0, float(f[1]))
	var started := Time.get_ticks_msec()
	fill.footprints = feet
	fill.sync_chunks = true
	fill.year = year
	fill.height = height
	fill.prepare()
	var t_prep := Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	var holder := Node3D.new()
	holder.name = "Fill"
	root.add_child(holder)
	var chunks := fill.chunks_in(radius, Vector2(pos.x, pos.z))
	for key in chunks:
		fill.build_chunk_into(holder, key, year, height, feet, lod)
		if not flat:
			var rect := Rect2(Vector2(key) * 250.0, Vector2(250, 250))
			root.add_child(UrbsTerrain.build_chunk(rect, 0 if lod == 0 else 1))
	var t_chunks := Time.get_ticks_msec() - started
	if args.has("count"):
		_count(fill, chunks, year)
	if args.has("steps"):
		fill.sync_chunks = false
		var worst := 0.0
		var steps := 0
		var total := 0.0
		for key in chunks:
			var job := fill._chunk_job(key, lod)
			job.set_process(false)
			holder.add_child(job)
			while not job.done:
				var t0 := Time.get_ticks_usec()
				job.step(2.5)
				var dt := float(Time.get_ticks_usec() - t0) / 1000.0
				worst = maxf(worst, dt)
				total += dt
				steps += 1
		print("STEPS chunks=%d steps=%d worst_step_ms=%.1f avg_chunk_ms=%.1f" % [chunks.size(), steps, worst, total / maxf(chunks.size(), 1)])
	# monument placeholders
	var mon := Node3D.new()
	root.add_child(mon)
	for r in feet:
		var rect := r as Rect2
		if rect.get_center().distance_to(Vector2(pos.x, pos.z)) > radius + 100:
			continue
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rect.size.x * 0.7, 9.0, rect.size.y * 0.7)
		box.mesh = bm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.8, 0.78, 0.7)
		box.material_override = mm
		box.position = Vector3(rect.get_center().x, 14.5, rect.get_center().y)
		mon.add_child(box)
	# stats
	var stats := {}
	var tris := 0
	for ch in holder.get_children():
		for mi in ch.get_children():
			if not (mi is MultiMeshInstance3D):
				continue
			var m := mi as MultiMeshInstance3D
			var fam := String(mi.name).split("_")[0]
			stats[fam] = int(stats.get(fam, 0)) + m.multimesh.instance_count
			tris += m.multimesh.instance_count * (m.multimesh.mesh.get_faces().size() / 3)
	print("PREVIEW year=%d chunks=%d prep_ms=%d chunks_ms=%d instances=%s tris=%d" % [year, chunks.size(), t_prep, t_chunks, str(stats), tris])
	print("PREVIEW street_lots=%s" % str(fill.count_stats))
	var shown := {}
	for lot in fill._street_lots:
		var m := str(lot["mesh"])
		if m.begins_with("furn:") and int(shown.get(m, 0)) < 3 and lot["c"].distance_to(Vector2(pos.x, pos.z)) < 900.0:
			shown[m] = int(shown.get(m, 0)) + 1
			print("FURN %s at %d,%d yaw=%.0f" % [m, lot["c"].x, lot["c"].y, rad_to_deg(lot["th"])])
	# camera
	var cam := Camera3D.new()
	cam.fov = float(args.get("fov", "70"))
	cam.far = 3000.0
	var eye := float(args.get("eye", "1.7"))
	var ground_y: float = height.call(pos.x, pos.z)
	cam.position = Vector3(pos.x, ground_y + eye, pos.z)
	root.add_child(cam)
	cam.rotation = Vector3(deg_to_rad(float(args.get("pitch", "-3"))), -yaw, 0)
	cam.current = true
	for i in 6:
		await process_frame
	if args.has("shot"):
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		img.save_png(str(args["shot"]))
		print("PREVIEW saved ", args["shot"])
	quit()


## --count: lots inside the Servian wall for the chunks loaded, and per-step build times.
func _count(fill: UrbsFill, chunks: Array, year: int) -> void:
	var poly := fill._circuit
	var inside := {}
	var total := 0
	for key in chunks:
		for lot in fill.lots_for_chunk(key):
			var k := str(lot["mesh"]).split(":")[0]
			if k == "prop" or k == "furn" or k == "tree":
				continue
			total += 1
			if Geometry2D.is_point_in_polygon(lot["c"], poly):
				inside[k] = int(inside.get(k, 0)) + 1
	var n := 0
	for k in inside:
		n += int(inside[k])
	print("COUNT year=%d all=%d inside_walls=%d %s" % [year, total, n, str(inside)])
	print("REJECT %s" % str(fill.reject_stats))


func _environment(root: Node3D, hour: float) -> void:
	var sun := DirectionalLight3D.new()
	var az := deg_to_rad(150.0)
	var el := deg_to_rad(clampf(15.0 + 60.0 * sin((hour - 6.0) / 12.0 * PI), 10.0, 70.0))
	sun.rotation = Vector3(-el, az, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	sun.light_energy = 0.75
	root.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.5, 0.8)
	sm.sky_horizon_color = Color(0.74, 0.8, 0.88)
	sm.ground_horizon_color = Color(0.7, 0.72, 0.72)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.8, 0.76)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.82, 0.88)
	env.fog_density = 0.00012
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
