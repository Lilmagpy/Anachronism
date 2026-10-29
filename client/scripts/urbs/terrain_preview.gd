## Standalone test for the ground of Rome (task U2): builds UrbsTerrain and the Tiber alone,
## with a sun, and saves a screenshot. Run from client/:
##   /tmp/claude-0/render.sh --path . -s res://scripts/urbs/terrain_preview.gd -- --screenshot=/tmp/claude-0/terrain.png
## Flags (after the `--`):
##   --screenshot=PATH      save the picture and quit (without it the window stays open)
##   --view=aerial|forum|tiber|capitol|campus|circus   a camera preset (default aerial)
##   --at=x,z,height        camera position in local metres (height above the ground at x,z? no:
##                          absolute y a.s.l.); overrides the preset
##   --look=x,z,height      point the camera looks at (default: the Forum, y = 12)
##   --fov=DEGREES          field of view (default 60)
##   --plain                grey clay material (debug: judge the shape alone)
##   --noshadow             sun without shadows
##   --marks                stand a pole with a name on each hill summit and on the Forum
extends SceneTree

var _shot := ""
var _frames := 0
var args_noshadow := false


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
	var root := Node3D.new()
	get_root().add_child(root)
	t0 = Time.get_ticks_msec()
	var ground := UrbsTerrain.build_all(root)
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
	var views := {
		"aerial": [Vector3(-300, 750, 1500), Vector3(0, 10, -50), 55.0],
		"forum": [Vector3(60, 14, 20), Vector3(-215, 25, -60), 70.0],
		"tiber": [Vector3(-300, 80, -200), Vector3(-640, 6, 0), 70.0],
		"capitol": [Vector3(250, 120, 400), Vector3(-200, 30, -100), 60.0],
		"campus": [Vector3(-200, 400, -2600), Vector3(-800, 10, -1000), 60.0],
		"circus": [Vector3(600, 120, 900), Vector3(150, 12, 330), 65.0],
	}
	var v: Array = views.get(args.get("view", "aerial"), views["aerial"])
	var pos: Vector3 = v[0]
	var look: Vector3 = v[1]
	var fov: float = v[2]
	if args.has("at"):
		pos = _vec(args["at"])
	if args.has("look"):
		look = _vec(args["look"])
	if args.has("fov"):
		fov = float(args["fov"])
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 12000.0
	cam.near = 0.5
	root.add_child(cam)
	cam.look_at_from_position(pos, look)
	print("camera at %s looking at %s; ground there %.1f m" % [pos, look, UrbsTerrain.height_at(pos.x, pos.z)])


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
	if _shot != "" and _frames == 8:
		var img := get_root().get_texture().get_image()
		img.save_png(_shot)
		print("saved ", _shot)
		quit()
	return false
