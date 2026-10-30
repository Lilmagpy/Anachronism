## Urbs (U8 render): preview of the material library and the light. Run from client/:
##   /tmp/claude-0/render.sh --path . -s res://scripts/urbs/materials_preview.gd -- --shot=/tmp/claude-0/mat.png
## Views (--view=NAME, default gallery):
##   gallery   21 surfaces of the library (--page=0|1|2) on a wall, a column and a ball, or a
##             roof, or a slab, each named
##   far       the same from 400 m (shimmer check)
##   column    a fluted marble column at 1 m          roof   a tiled roof at 3 m
##   wall      brick, reticulatum and stucco at 2 m
##   city      the real city: opens Urbs itself (no engine needed) with the Urbs flags given
##             here (--year, --mode, --at, --yaw, --pitch, --hour, --day, --fx); --restyle swaps
##             the builders' plain materials for library ones first (UrbsMaterials.restyle)
## Flags: --hour=H (default 10) --day=N --fx=nossao,nossil,noglow,nofog --plain (flat colours)
##   --tonemap=aces|filmic|agx|reinhard --exposure=E --ambient=A --bounce=B (tuning the light)
##   --shot=PATH  save the picture and quit
##   --perf       time the frame with each post effect on and off and print PERF lines:
##                wall-clock frame ms and the renderer's own CPU/GPU ms (--frames=N measured,
##                default 4, after --warm=N, default 3: a software GPU takes seconds a frame)
extends SceneTree

var args := {}
var atmosphere := UrbsAtmosphere.new()
var scene := Node3D.new()
var cam := Camera3D.new()
var env := Environment.new()
var sun := DirectionalLight3D.new()
var urbs: Urbs


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		var kv := s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	UrbsMaterials.plain = args.has("plain")
	_run.call_deferred()


func _run() -> void:
	get_root().add_child(scene)
	var view := str(args.get("view", "gallery"))
	if view == "city":
		await _city()
	else:
		var we := WorldEnvironment.new()
		we.environment = env
		scene.add_child(we)
		scene.add_child(sun)
		atmosphere.day = int(args.get("day", "120"))
		atmosphere.setup(env, sun)
		if args.has("fx"):
			atmosphere.set_fx(str(args["fx"]))
		_tuning()
		atmosphere.update(false, 0.0, false)
		cam.far = 8000.0
		cam.near = 0.05
		scene.add_child(cam)
		cam.current = true
		_ground()
		_build(view)
	for i in 8:
		await process_frame
	if args.has("perf"):
		await _perf()
	if args.has("shot"):
		await RenderingServer.frame_post_draw
		get_root().get_viewport().get_texture().get_image().save_png(str(args["shot"]))
		print("saved ", args["shot"])
	quit()


# --- the city --------------------------------------------------------------------------------

func _city() -> void:
	urbs = Urbs.new()
	scene.add_child(urbs)
	var flags := {}
	for key in ["mode", "at", "yaw", "pitch", "hour", "day", "fx"]:
		if args.has(key):
			flags[key] = args[key]
	var t0 := Time.get_ticks_msec()
	urbs.open(int(args.get("year", "-44")), Vector3.ZERO, flags)
	print("city built in %d ms" % (Time.get_ticks_msec() - t0))
	if args.has("restyle"):
		print("restyled %d surfaces: %s" % [UrbsMaterials.restyle(urbs), UrbsMaterials.last_restyle])
	env = urbs.environment
	sun = urbs.sun
	atmosphere = urbs.atmosphere
	_tuning()
	for i in 20:
		await process_frame


func _tuning() -> void:
	var maps := {"aces": Environment.TONE_MAPPER_ACES, "filmic": Environment.TONE_MAPPER_FILMIC,
		"agx": Environment.TONE_MAPPER_AGX, "reinhard": Environment.TONE_MAPPER_REINHARDT}
	if args.has("tonemap"):
		atmosphere.tonemap = maps.get(str(args["tonemap"]), atmosphere.tonemap)
	atmosphere.exposure = float(args.get("exposure", str(atmosphere.exposure)))
	atmosphere.ambient = float(args.get("ambient", str(atmosphere.ambient)))
	atmosphere.bounce = float(args.get("bounce", str(atmosphere.bounce)))
	atmosphere.apply_tonemap()
	atmosphere.set_hour(float(args.get("hour", str(atmosphere.hour))))


# --- the gallery -----------------------------------------------------------------------------

const VIEWS := {
	"gallery": [Vector3(11.4, 7.5, 13.5), Vector3(11.4, 0.6, 1.5), 62.0],
	"far": [Vector3(11.4, 140.0, 400.0), Vector3(11.4, 0.6, 1.5), 5.0],
	"column": [Vector3(0.2, 1.9, 1.15), Vector3(0.0, 1.6, 0.0), 60.0],
	"roof": [Vector3(1.8, 6.2, 3.4), Vector3(0.0, 4.2, -0.5), 60.0],
	"wall": [Vector3(0.0, 1.6, 2.4), Vector3(0.0, 1.4, 0.0), 65.0],
}


func _build(view: String) -> void:
	var v: Array = VIEWS.get(view, VIEWS["gallery"])
	cam.fov = v[2]
	cam.look_at_from_position(v[0], v[1], Vector3.UP)
	match view:
		"column":
			_column(Vector3.ZERO, "marble_luna", 0.42, 7.0)
			_column(Vector3(-1.6, 0, -0.8), "marble_numidian", 0.42, 7.0)
			_column(Vector3(1.6, 0, -0.8), "marble_phrygian", 0.42, 7.0)
			_box(Vector3(0, -0.3, 0), Vector3(6, 0.3, 4), "forum_travertine")
		"roof":
			_roof(Vector3(0, 3.0, -1.5), Vector3(8, 2.2, 6), "tegulae")
			_box(Vector3(0, 0, -1.5), Vector3(7.6, 3.0, 5.6), "stucco_ochre")
			_box(Vector3(0, 5.2, -1.5), Vector3(8.2, 0.25, 0.3), "ridge_terracotta")
		"wall":
			_box(Vector3(-1.6, 0, -0.3), Vector3(1.5, 3, 0.4), "brick_latericium")
			_box(Vector3(0.0, 0, -0.3), Vector3(1.5, 3, 0.4), "opus_reticulatum")
			_box(Vector3(1.6, 0, -0.3), Vector3(1.5, 3, 0.4), "stucco_red")
			_box(Vector3(0, -0.2, 0.6), Vector3(5, 0.2, 2.5), "street_basalt")
		_:
			var names := UrbsMaterials.names()
			var page := int(args.get("page", "0"))
			var i := 0
			for name in names.slice(page * 21, page * 21 + 21):
				var at := Vector3((i % 7) * 3.8, 0, (i / 7) * 3.8 - 3.0)
				_sample(at, name)
				i += 1


func _sample(at: Vector3, name: String) -> void:
	var recipe: Array = UrbsMaterials.RECIPES.get(name, ["", {}])
	match String(recipe[0]):
		"tiles":
			_roof(at + Vector3(0, 0.4, 0), Vector3(2.8, 1.0, 2.6), name)
			_box(at, Vector3(2.6, 0.4, 2.4), name)
		"ground", "water":
			_box(at, Vector3(3.2, 0.08, 3.2), name)
		_:
			_box(at + Vector3(0, 0, -0.6), Vector3(2.6, 2.4, 0.6), name)
			_column(at + Vector3(-0.6, 0, 0.6), name, 0.3, 2.2)
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.45
			sm.height = 0.9
			s.mesh = sm
			s.material_override = UrbsMaterials.get_material(name)
			s.position = at + Vector3(0.7, 0.45, 0.6)
			scene.add_child(s)
	var label := Label3D.new()
	label.text = name
	label.font_size = 64
	label.pixel_size = 0.006
	label.position = at + Vector3(0, 0.05, 1.5)
	label.rotation_degrees = Vector3(-60, 0, 0)
	label.modulate = Color(0.1, 0.08, 0.06)
	label.outline_size = 0
	scene.add_child(label)


func _box(foot: Vector3, size: Vector3, name: String) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = UrbsMaterials.get_material(name)
	mi.position = foot + Vector3(0, size.y * 0.5, 0)
	scene.add_child(mi)


## A shaft with 24 concave flutes parted by narrow fillets (the Ionic and Corinthian shaft,
## Vitruvius 3.5.14; # unverified), tapering by a sixth, smooth normals; a plain base and capital
## block. Only for looking at the materials: the monuments build the real orders.
func _column(foot: Vector3, name: String, r: float, h: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flutes := 24
	var steps := flutes * 10
	var top := 5.0 / 6.0
	var ring: Array = []
	for i in steps + 1:
		var a := TAU * float(i) / steps
		var phi := fmod(float(i) / steps * flutes, 1.0)
		var depth := 0.0
		var slope := 0.0
		if phi > 0.1 and phi < 0.9:
			var x := (phi - 0.5) / 0.4
			depth = sqrt(maxf(1.0 - x * x, 0.0))
			slope = -x / maxf(sqrt(maxf(1.0 - x * x, 0.0)), 0.15) / 0.4 * flutes / TAU
		var rr := 1.0 - 0.06 * depth
		var drr := -0.06 * slope
		var radial := Vector3(cos(a), 0, sin(a))
		var tang := Vector3(-sin(a), 0, cos(a))
		# outward normal of r(a): radial * r - tangent * dr/da
		var nrm := (radial * rr - tang * drr).normalized()
		ring.append([radial * rr, nrm])
	for i in steps:
		var p0: Vector3 = ring[i][0]
		var p1: Vector3 = ring[i + 1][0]
		var n0: Vector3 = ring[i][1]
		var n1: Vector3 = ring[i + 1][1]
		var quad := [[p0 * r, n0], [p1 * r, n1], [p0 * r * top + Vector3(0, h, 0), n0],
			[p1 * r, n1], [p1 * r * top + Vector3(0, h, 0), n1], [p0 * r * top + Vector3(0, h, 0), n0]]
		for v in quad:
			st.set_normal(v[1])
			st.add_vertex(foot + (v[0] as Vector3))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = UrbsMaterials.get_material(name)
	scene.add_child(mi)
	_box(foot - Vector3(0, r * 0.25, 0), Vector3(r * 2.6, r * 0.5, r * 2.6), name)
	_box(foot + Vector3(0, h, 0), Vector3(r * 2.2, r * 0.6, r * 2.2), name)


func _roof(foot: Vector3, size: Vector3, name: String) -> void:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(size.z, size.y, size.x)
	mi.mesh = pm
	mi.material_override = UrbsMaterials.get_material(name)
	mi.position = foot + Vector3(0, size.y * 0.5, 0)
	mi.rotation_degrees = Vector3(0, 90, 0)
	scene.add_child(mi)


func _ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	mi.mesh = pm
	mi.material_override = UrbsMaterials.get_material("earth_packed")
	mi.position.y = -0.02
	scene.add_child(mi)


# --- frame cost ---------------------------------------------------------------------------------

func _perf() -> void:
	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	print("PERF renderer=%s device=%s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	var configs := [["all", ""], ["nossao", "ssao"], ["nossil", "ssil"], ["noglow", "glow"], ["nofog", "fog"], ["none", "*"]]
	var base := {}
	for c in configs:
		atmosphere.fx = {"ssao": true, "ssil": true, "glow": true, "fog": true}
		if c[1] == "*":
			for k in atmosphere.fx:
				atmosphere.fx[k] = false
		elif c[1] != "":
			atmosphere.fx[c[1]] = false
		atmosphere._apply_fx()
		atmosphere._mode = ""
		var street := urbs == null or urbs.cam.mode != UrbsCamera.Mode.CITY
		atmosphere.update(not street, urbs.cam.dist if urbs != null else 0.0, false)
		for i in int(args.get("warm", "3")):
			await process_frame
		var t0 := Time.get_ticks_usec()
		var cpu := 0.0
		var gpu := 0.0
		var frames := int(args.get("frames", "4"))
		for i in frames:
			await process_frame
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var wall := (Time.get_ticks_usec() - t0) / 1000.0 / frames
		base[c[0]] = wall
		print("PERF fx=%-7s frame_ms=%.1f render_cpu_ms=%.2f render_gpu_ms=%.2f draw_calls=%d" % [c[0], wall, cpu / frames, gpu / frames,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	for c in configs.slice(1, 5):
		print("PERF cost of %s: %.1f ms (frame with it %.1f, without %.1f)" % [String(c[1]), base["all"] - base[c[0]], base["all"], base[c[0]]])
	atmosphere.fx = {"ssao": true, "ssil": true, "glow": true, "fog": true}
	atmosphere._apply_fx()
	atmosphere._mode = ""
