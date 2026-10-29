## Preview of the monuments (U3), standalone: flat ground at y = 10 (or UrbsTerrain if --terrain),
## a sun, the monuments of a year, and a screenshot. Run from client/:
##   /tmp/claude-0/render.sh --path . -s res://scripts/urbs/monuments_preview.gd -- --year=-50 --at=aedes_saturni --screenshot=/tmp/claude-0/x.png
## Flags (after `--`):
##   --year=-50            the year (negative = BC), default -50
##   --at=<id>             look at that monument from the front, three-quarter view
##   --at=x,z,distance     look at local x, z from a distance (aerial)
##   --view=forum|circus|campus|capitol   preset (forum: from the Capitol; circus: from the Palatine;
##                         campus: from above)
##   --cam=x,y,z --look=x,y,z   explicit camera and target (local metres, y a.s.l.)
##   --fov=DEGREES         (default 60)
##   --screenshot=PATH     save and quit
##   --report              print the counts of real forms and placeholders, and what is unverified
##   --labels              float each monument's id above it
##   --pick=px,py          print the monument id under that screen pixel (tests UrbsMonuments.pick)
extends SceneTree

var _args := {}
var _mon: UrbsMonuments
var _cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var year := int(_args.get("year", "-50"))
	var root := Node3D.new()
	get_root().add_child(root)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000, 9000)
	ground.mesh = plane
	ground.position = Vector3(0, 9.9, 0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.46, 0.55, 0.32)
	gm.roughness = 1.0
	ground.material_override = gm
	root.add_child(ground)
	_mon = UrbsMonuments.new()
	_mon.build(root, year, Callable())
	print("year %d: %d monuments" % [year, _mon.ids().size()])
	if _args.has("report"):
		var r := _mon.report(year)
		print("by kind: ", r.by_kind)
		print("by model: ", r.by_model)
		for k in r.todo:
			print("TODO roman.gd ", k, ": ", r.todo[k])
	_light(root)
	if _args.has("labels"):
		for id in _mon.ids():
			var b := _mon.bounds(id)
			var l := Label3D.new()
			l.text = str(id).replace("aedes_", "").replace("porta_", "P.")
			l.font_size = 40
			l.pixel_size = 0.12 if b.size.length() > 60.0 else 0.05
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.modulate = Color(0.05, 0.05, 0.3)
			l.outline_size = 8
			l.position = Vector3(b.get_center().x, b.end.y + 4.0, b.get_center().z)
			root.add_child(l)
	_cam = Camera3D.new()
	_cam.fov = float(_args.get("fov", "60"))
	_cam.far = 12000.0
	_cam.near = 0.5
	root.add_child(_cam)
	var pos := Vector3(-60, 25, 40)
	var look := Vector3(-215, 25, -50)
	var view := str(_args.get("view", ""))
	match view:
		"forum":
			pos = Vector3(-190, 48, -20)
			look = Vector3(40, 12, 10)
		"circus":
			pos = Vector3(40, 60, 330)
			look = Vector3(0, 8, 700)
		"campus":
			pos = Vector3(-800, 1500, -250)
			look = Vector3(-800, 10, -520)
			_cam.fov = 45.0
		"capitol":
			pos = Vector3(-60, 80, 160)
			look = Vector3(-215, 25, -45)
	if _args.has("at"):
		var at := str(_args["at"])
		if _mon.entry(at).is_empty():
			var p := at.split(",")
			var dist := float(p[2]) if p.size() > 2 else 300.0
			look = Vector3(float(p[0]), 10, float(p[1]))
			pos = look + Vector3(0, dist * 0.7, dist * 0.8)
		else:
			var b := _mon.bounds(at)
			var e := _mon.entrance(at)
			var size := maxf(b.size.length(), 20.0)
			look = b.get_center()
			var fwd := (e.origin - look)
			fwd.y = 0.0
			var out := fwd.normalized() if fwd.length() > 0.1 else Vector3(0, 0, 1)
			var side := Vector3(-out.z, 0, out.x)
			pos = look + out * size * 0.9 + side * size * 0.5 + Vector3(0, size * 0.55, 0)
	if _args.has("cam"):
		pos = _vec(str(_args["cam"]))
	if _args.has("look"):
		look = _vec(str(_args["look"]))
	_cam.look_at_from_position(pos, look)
	_shoot.call_deferred()


func _vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _light(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 3000.0
	root.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.22, 0.40, 0.66)
	sm.sky_horizon_color = Color(0.78, 0.74, 0.66)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)


func _shoot() -> void:
	for i in 8:
		await process_frame
	if _args.has("pick"):
		var p := str(_args["pick"]).split(",")
		print("pick at ", p, " -> '", _mon.pick(_cam, Vector2(float(p[0]), float(p[1]))), "'")
	if _args.has("screenshot"):
		get_root().get_viewport().get_texture().get_image().save_png(str(_args["screenshot"]))
		print("saved ", _args["screenshot"])
		quit()
	elif _args.has("report") or _args.has("pick"):
		quit()
