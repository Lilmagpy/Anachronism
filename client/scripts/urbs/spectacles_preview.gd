## Preview of the spectacles on stand-in geometry (U6).
##   cd client && /tmp/claude-0/render.sh --path . -s res://scripts/urbs/spectacles_preview.gd -- \
##       --kind=race|munus|senate|sacrifice|triumph --t=12 --screenshot=/tmp/claude-0/u6.png [--view=N]
## --t takes seconds or a comma list (one picture each, named PATH_t<sec>.png). --view=N uses
## the spectacle's seat_views()[N]; --follow=metres puts the camera beside the race leader (default: an overview); --cam=x,y,z,tx,ty,tz places the camera. Other flags: --seed=N, --fav=0|1
## (sacrifice), --pass=0|1 (senate), --missio=0|1 (munus).
extends SceneTree

const Spectacles := preload("res://scripts/urbs/spectacles/spectacles.gd")
const Standin := preload("res://scripts/urbs/spectacles/standin.gd")

var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	var kind := str(_args.get("kind", "race"))
	var root := Node3D.new()
	get_root().add_child(root)
	_environment(root)
	var params := _params(kind, root)
	var sp := Spectacles.play(kind, params, root)
	var cam := Camera3D.new()
	cam.far = 3000.0
	cam.fov = 62.0
	root.add_child(cam)
	cam.current = true
	await process_frame
	await process_frame
	if sp.has_method("debug_info"):
		print("INFO ", sp.debug_info())
	var views: Array[Transform3D] = sp.seat_views()
	var vi := int(_args.get("view", -1))
	var times := str(_args.get("t", "0")).split(",")
	for ts in times:
		sp.playing = false
		sp.seek(float(ts))
		if _args.has("cam"):
			var c := str(_args["cam"]).split(",")
			var f := Vector3(float(c[0]), float(c[1]), float(c[2]))
			cam.transform = Transform3D(Basis.looking_at(Vector3(float(c[3]), float(c[4]), float(c[5])) - f, Vector3.UP), f)
		elif _args.has("gen") and sp.has_method("general_at"):
			var g: Vector3 = sp.general_at(float(ts))
			var o := float(_args["gen"])
			cam.transform = Transform3D(Basis.looking_at(Vector3(0, -0.3, -1) * 1.0 + Vector3(-o, 0, 0) * 0.0 + (Vector3(0, 0.5, 0) - Vector3(0, 4, o)) * 0.0 + (-Vector3(0, 4.0, o)).normalized() * 0.0 + Vector3(0, -1, -o) .normalized(), Vector3.UP), g + Vector3(-6, 4.0, o))
		elif _args.has("follow") and sp.has_method("leader_view"):
			cam.transform = sp.leader_view(float(ts), float(_args["follow"]), int(_args.get("who", -1)))
		elif vi >= 0 and vi < views.size():
			cam.transform = views[vi]
		else:
			cam.transform = _overview(kind, sp)
		for i in 4:
			await process_frame
		var path := str(_args.get("screenshot", "/tmp/claude-0/u6.png"))
		if times.size() > 1:
			path = path.replace(".png", "_t%s.png" % ts)
		get_root().get_viewport().get_texture().get_image().save_png(path)
		print("PREVIEW saved ", path)
	quit()


func _overview(kind: String, sp: Node3D) -> Transform3D:
	var look := func(f: Vector3, a: Vector3) -> Transform3D:
		return Transform3D(Basis.looking_at(a - f, Vector3.UP), f)
	match kind:
		"race":
			return look.call(Vector3(-60, 95, 150), Vector3(0, 0, 0))
		"munus":
			return look.call(Vector3(0, 30, 38), Vector3(0, 0, 0))
		"senate":
			return look.call(Vector3(0, 16, 24), Vector3(0, 1, -2))
		"sacrifice":
			return look.call(Vector3(14, 6, 18), Vector3(0, 1.5, -2))
		_:
			var v: Array[Transform3D] = sp.seat_views()
			return v[0] if v.size() > 0 else Transform3D()


func _params(kind: String, root: Node3D) -> Dictionary:
	var p := {"seed": int(_args.get("seed", 3))}
	match kind:
		"race":
			Standin.ground(root, 1600.0)
			Standin.circus(root, 580.0, 90.0)
		"munus":
			Standin.ground(root, 300.0)
			Standin.arena(root, 28.0, 18.0)
			p["rx"] = 28.0
			p["rz"] = 18.0
			p["missio"] = str(_args.get("missio", "1")) == "1"
		"senate":
			var hall := Vector2(24.0, 40.0)
			Standin.ground(root, 200.0)
			Standin.curia(root, hall)
			p["hall"] = hall
			p["vote"] = {"issue": "the grain for the legions", "yes_bp": 6400, "no_bp": 3600, "passes": str(_args.get("pass", "1")) == "1"}
		"sacrifice":
			Standin.ground(root, 200.0)
			Standin.temple(root)
			p["favourable"] = str(_args.get("fav", "1")) == "1"
		"triumph":
			Standin.ground(root, 3000.0)
			var poly := PackedVector3Array()
			# Campus Martius -> Forum -> Capitol: a bend, then the ascent
			for i in 11:
				poly.append(Vector3(-400.0 + i * 40.0, 0.0, 0.0))
			for i in 1:
				pass
			poly.append(Vector3(30.0, 0.0, -30.0))
			poly.append(Vector3(60.0, 1.0, -70.0))
			poly.append(Vector3(75.0, 6.0, -110.0))
			poly.append(Vector3(90.0, 14.0, -140.0))
			poly.append(Vector3(90.0, 22.0, -175.0))
			Standin.street(root, poly)
			p["route"] = poly
			p["spoils"] = ["captured Punic standards", "Syracusan statues", "silver, 40,000 pounds", "pictures of the taken city"]
			p["general"] = "P. Cornelius Scipio"
	return p


func _environment(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 40, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	root.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.74, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
