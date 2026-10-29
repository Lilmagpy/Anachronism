## Preview of the interiors (U5): builds one interior in an empty world, lit like the game,
## and saves pictures of it.
##   cd client && /tmp/claude-0/render.sh --path . -s res://scripts/urbs/interiors_preview.gd -- \
##       --type=temple --size=30x25 --screenshot=/tmp/claude-0/interiors/temple.png
## Options: --type=temple|curia|basilica|circus|arena|domus|insula|theatre
##          --variant=capitoline|julia|hostilia|colosseum|forum|pompey
##          --size=LxW (metres, long side first; default: the kind's own)
##          --year=-100   --view=NAME (one view only; default: all, written as PATH_NAME.png)
##          --cutaway     hide roofs and ceilings in every view   --list  print views and quit
##          --monument=ID build from a record of data/city/monuments.json (size, variant)
## Views come from the interior itself (front, inside, overview...). Writes PATH (the start
## view) and PATH_<view>.png; prints triangle counts and build time.
extends SceneTree

const Roman := preload("res://scripts/models/roman_interiors.gd")
const Interiors := preload("res://scripts/urbs/interiors.gd")

var _opts := {}
var _root: Node3D
var _cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a).trim_prefix("--")
		var p := s.split("=", true, 1)
		_opts[p[0]] = p[1] if p.size() > 1 else "1"
	_root = Node3D.new()
	get_root().add_child(_root)
	_build.call_deferred()


func _build() -> void:
	var kind := str(_opts.get("type", "temple"))
	var variant := str(_opts.get("variant", ""))
	var size := Roman.default_size(kind, variant)
	if _opts.has("monument"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/city/monuments.json"))
		for m in data["monuments"]:
			if m["id"] == _opts["monument"]:
				var kv: Array = Interiors.kind_of(m)
				kind = kv[0]
				variant = kv[1]
				size = Interiors.size_of(m, kind, variant)
	if _opts.has("size"):
		var p := str(_opts["size"]).split("x")
		size = Vector2(float(p[0]), float(p[1]))
	Interiors.year = int(_opts.get("year", -100))
	var t0 := Time.get_ticks_msec()
	Interiors.enter_kind(kind, size, _root, Transform3D.IDENTITY, variant)
	var r: Dictionary = Interiors._result
	print("INTERIOR %s %s size %s: %d triangles, built in %d ms" % [kind, variant, size, r.get("tris", 0), Time.get_ticks_msec() - t0])
	for n in r.get("notes", []):
		print("  NOTE ", n)
	_world(kind)
	var views: Array = [["start", r["spawn"]]]
	views.append_array(r["views"])
	if _opts.has("list"):
		for v in views:
			print("VIEW ", v[0])
		quit()
		return
	_shoot.call_deferred(views)


func _world(kind: String) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1600, 1600)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.50, 0.46, 0.36)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position.y = -0.02
	if kind != "arena" and kind != "circus" and kind != "theatre":
		_root.add_child(ground)
	else:
		_root.add_child(ground)
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
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	env.environment = e
	_root.add_child(env)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 3000.0
	_cam.near = 0.1
	_root.add_child(_cam)


func _shoot(views: Array) -> void:
	var path := str(_opts.get("screenshot", "/tmp/claude-0/interiors/preview.png"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	for v in views:
		var name: String = v[0]
		if _opts.has("view") and _opts["view"] != name:
			continue
		var cutaway := _opts.has("cutaway") or name == "overview" or str(name).begins_with("cut")
		Interiors.set_cutaway(cutaway)
		_cam.transform = v[1]
		_cam.fov = 70.0 if not (name == "overview" or str(name).begins_with("cut")) else 55.0
		for f in 5:
			await process_frame
		var out := path if name == "start" else path.get_basename() + "_" + name + ".png"
		get_root().get_viewport().get_texture().get_image().save_png(out)
		print("SHOT ", out)
	quit()
