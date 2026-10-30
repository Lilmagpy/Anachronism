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
	if _args.has("cam"):
		urbs.cam.set_process(false)
		var c := str(_args["cam"]).split(",")
		var from := Vector3(float(c[0]), float(c[1]), float(c[2]))
		cam.global_transform = Transform3D(Basis.looking_at(Vector3(float(c[3]), float(c[4]), float(c[5])) - from, Vector3.UP), from)
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
