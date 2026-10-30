## Preview of the street life (U8, life.gd) in the real Urbs scene: opens the city exactly as
## `--urbs` does (same camera flags as urbs.gd), builds UrbsLife on it (the hook the lead wires
## in urbs.gd), lets it run a few seconds and saves a picture.
##
##   cd client && /tmp/claude-0/render.sh --path . -s res://scripts/urbs/life_preview.gd -- \
##       --year=-44 --mode=street --at=60,20,30 --yaw=300 --pitch=-10 --hour=9 \
##       --screenshot=/tmp/claude-0/life.png [--perf] [--nolife] [--run=4] [--event=games:ludi_romani] [--t=40]
##
## Flags: the urbs.gd camera flags (--year --at --mode --yaw --pitch --hour), and
##   --nolife           the city without the life (the BEFORE picture)
##   --run=S            seconds of simulated life before the picture (default 3; fixed 1/30 s steps)
##   --event=kind:ref[:monument]   play an engine event as the city would (UrbsSpectacles.play_event);
##                      the life also gets it (set_events). --t=S holds the spectacle at S seconds.
##   --spectacle-view=N use the spectacle's seat_views()[N] as the camera
##   --cam=x,y,z,tx,ty,tz  place the camera (local metres, y above sea level)
##   --street=ID --st=0..1 [--back] [--eye=1.7] [--pitch=DEG]   stand on a street looking along it
##   --market=forum_boarium|forum_holitorium|macellum [--eye=1.7]  stand at a market's edge looking in
##   --bench            (headless is fine) time life.tick over 300 frames at the camera: mean,
##                      worst, and the LOD pass
##   --intended         keep the street camera where the flags put it: urbs.gd's push_out treats the
##                      Servian wall's box (the whole city) as solid and shoves every street camera
##                      to x = -641, and --yaw turns anticlockwise; with this flag the camera stays
##                      at --at and --yaw is a compass bearing (0 north, 90 east), as the header says
##   --perf             print draw calls, objects, primitives and frame time with and without the
##                      life, the CPU time of life.tick, and the counts
extends SceneTree

const Spectacles := preload("res://scripts/urbs/spectacles/spectacles.gd")

var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_run.call_deferred()


func _run() -> void:
	var year := int(_args.get("year", "-44"))
	var hour := float(_args.get("hour", "10"))
	var urbs := Urbs.new()
	get_root().add_child(urbs)
	await process_frame
	var flags := _args.duplicate()
	flags.erase("screenshot")
	urbs.open(year, Vector3.ZERO, flags)
	var t0 := Time.get_ticks_msec()
	var life := UrbsLife.new()
	life.auto_tick = false
	urbs.add_child(life)
	var events: Array = []
	if _args.has("event"):
		var f := str(_args["event"]).split(":")
		events.append({"kind": f[0], "ref": f[1] if f.size() > 1 else "", "monument": f[2] if f.size() > 2 else null, "value": 6400, "other": 3600, "person": "the consul"})
	if not _args.has("nolife"):
		life.build(urbs, year, hour, Callable(urbs, "height_at"))
		life.set_events(events)
	print("LIFE build %d ms  %s" % [Time.get_ticks_msec() - t0, life.counts()])
	var sp: Node3D
	if _args.has("event"):
		var sflags := {"event": _args["event"]}
		if _args.has("t"):
			sflags["t"] = _args["t"]
		sp = Spectacles.handle_flags(sflags, urbs)
		print("SPECTACLE ", sp.name if sp != null else "none")
	var cam: Camera3D = urbs.cam.camera
	if _args.has("intended") and str(_args.get("mode", "")) == "street":
		urbs.cam.set_process(false)
		var c: Camera3D = urbs.cam.camera
		var at := str(_args.get("at", "0,0"))
		var stand := Vector3.ZERO
		var bearing := float(_args.get("yaw", "0"))
		var eye := 1.7
		if at.contains(","):
			var f := at.split(",")
			stand = Vector3(float(f[0]), 0, float(f[1]))
			eye = maxf(float(f[2]) if f.size() > 2 else 1.7, 1.7)
		elif urbs.monuments.ids().has(at):
			var b: AABB = urbs.monuments.bounds(at)
			stand = Vector3(b.get_center().x, 0, b.end.z + maxf(b.size.z * 0.4, 25.0))
			bearing = 0.0
		var basis := Basis(Vector3.UP, -deg_to_rad(bearing)) * Basis(Vector3.RIGHT, deg_to_rad(float(_args.get("pitch", "3"))))
		c.global_transform = Transform3D(basis, Vector3(stand.x, urbs.height_at(stand.x, stand.z) + eye, stand.z))
		urbs.chunks.focus_on(c.global_position, false)
		urbs.fill.sync_chunks = true
		urbs.chunks.load_all_now()
		urbs.fill.sync_chunks = false
	if _args.has("cam"):
		urbs.cam.set_process(false)
		var c := str(_args["cam"]).split(",")
		var from := Vector3(float(c[0]), float(c[1]), float(c[2]))
		cam.global_transform = Transform3D(Basis.looking_at(Vector3(float(c[3]), float(c[4]), float(c[5])) - from, Vector3.UP), from)
	elif _args.has("street"):
		urbs.cam.set_process(false)
		var st := float(_args.get("st", "0.5"))
		var a: Vector3 = urbs.streets.along(str(_args["street"]), st)
		var b: Vector3 = urbs.streets.along(str(_args["street"]), st + (-0.02 if _args.has("back") else 0.02))
		var eye := float(_args.get("eye", "1.7"))
		var from := a + Vector3(0, eye, 0)
		var dir := (b - a)
		dir.y = 0.0
		var to := from + dir.normalized() * 30.0 + Vector3(0, 30.0 * tan(deg_to_rad(float(_args.get("pitch", "-3")))), 0)
		cam.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	elif _args.has("market"):
		urbs.cam.set_process(false)
		var placed: Dictionary = urbs.monuments.get("_placed")
		var pl: Dictionary = placed.get(str(_args["market"]), {})
		if not pl.is_empty():
			var c: Vector2 = pl["centre"]
			var yaw: float = pl["yaw"]
			var u := Vector2(sin(yaw), cos(yaw))
			var edge := c - u * (float(pl["length"]) * 0.5 + 4.0) + Vector2(cos(yaw), -sin(yaw)) * 6.0
			var eye := float(_args.get("eye", "1.7"))
			var from := Vector3(edge.x, urbs.height_at(edge.x, edge.y) + eye, edge.y)
			var to := Vector3(c.x, urbs.height_at(c.x, c.y) + 0.8, c.y)
			cam.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	elif _args.has("spectacle-view") and sp != null:
		urbs.cam.set_process(false)
		var views: Array[Transform3D] = sp.camera_views()
		var vi := clampi(int(_args["spectacle-view"]), 0, views.size() - 1)
		cam.global_transform = views[vi]
	# run the life at a fixed step so pictures are repeatable
	var steps := int(float(_args.get("run", "3")) * 30.0)
	for i in steps:
		life.tick(1.0 / 30.0, cam.global_position)
		if i % 15 == 0:
			await process_frame
	for i in 6:
		life.tick(1.0 / 30.0, cam.global_position)
		await process_frame
	print("LIFE counts ", life.counts(), " camera ", cam.global_position, " forum ", life._forum)
	if _args.has("bench"):
		var total := 0
		var worst := 0
		for i in 300:
			var a := Time.get_ticks_usec()
			life.tick(1.0 / 60.0, cam.global_position)
			var d := Time.get_ticks_usec() - a
			total += d
			worst = maxi(worst, d)
		var phases := []
		life._lod_begin(cam.global_position)
		while life._lod_phase >= 0:
			var c0 := Time.get_ticks_usec()
			life._lod_step()
			phases.append(snappedf((Time.get_ticks_usec() - c0) / 1000.0, 0.01))
		print("BENCH lod phases ms ", phases)
		var b := Time.get_ticks_usec()
		life._update_lod(cam.global_position)
		print("BENCH tick mean=%.2fms worst=%.2fms lod_pass=%.2fms steps per frame: near=%d mid=%d far=%d" % [total / 300000.0, worst / 1000.0, (Time.get_ticks_usec() - b) / 1000.0, life._move_figs.size() + life._move_near.size() / 2, life._move_mid.size() / 6, life._move_far.size() / 16])
	if _args.has("screenshot"):
		var path := str(_args["screenshot"])
		get_root().get_viewport().get_texture().get_image().save_png(path)
		print("PREVIEW saved ", path)
	if _args.has("perf"):
		await _perf(life, cam)
	quit()


func _perf(life: UrbsLife, cam: Camera3D) -> void:
	var ri := func(what: int) -> int: return int(RenderingServer.get_rendering_info(what))
	var sample := func() -> Array:
		for i in 4:
			life.tick(1.0 / 30.0, cam.global_position)
			await process_frame
		var n := 20
		var tick_us := 0
		var t0 := Time.get_ticks_usec()
		for i in n:
			var a := Time.get_ticks_usec()
			if life.visible:
				life.tick(1.0 / 30.0, cam.global_position)
			tick_us += Time.get_ticks_usec() - a
			await process_frame
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / n
		return [ri.call(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), ri.call(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			ri.call(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), ms, float(tick_us) / 1000.0 / n]
	var with_life: Array = await sample.call()
	life.visible = false
	var without: Array = await sample.call()
	life.visible = true
	print("PERF with life: draws=%d objects=%d prims=%d frame=%.1fms tick=%.2fms | city only: draws=%d objects=%d prims=%d frame=%.1fms | life: draws=%d objects=%d prims=%d" % [
		with_life[0], with_life[1], with_life[2], with_life[3], with_life[4], without[0], without[1], without[2], without[3],
		with_life[0] - without[0], with_life[1] - without[1], with_life[2] - without[2]])
