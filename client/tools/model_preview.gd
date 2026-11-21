## Renders every model of a model-kit module (D-280) on a grass plot, lit as in the game, and
## saves pictures: an overview of all of them, and a close look at each in turn.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path client \
##     -s res://tools/model_preview.gd -- res://scripts/models/east.gd /tmp/out [kind ...]
## Writes OUT_all.png and OUT_<kind>.png (three-quarter view, as the game camera sees it), and
## prints each model's triangle count. A module has `static func kinds() -> Array` and
## `static func build(kind: String) -> ArrayMesh`; owner-coloured parts show a sample red.
extends SceneTree

const OWNER := Color(0.78, 0.22, 0.18)

var _out := ""
var _kinds: Array = []
var _module: GDScript
var _cam: Camera3D
var _root: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_module = load(args[0])
	_out = args[1]
	_kinds = args.slice(2) if args.size() > 2 else _module.call("kinds")
	_root = Node3D.new()
	get_root().add_child(_root)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/models.gdshader")
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.45, 0.62, 0.30)
	grass.roughness = 1.0
	ground.material_override = grass
	_root.add_child(ground)
	var per_row := int(ceil(sqrt(_kinds.size())))
	var spacing := 4.5
	for i in _kinds.size():
		var mesh: ArrayMesh = _module.call("build", str(_kinds[i]))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = 1
		var at := Vector3((i % per_row) * spacing, 0, (i / per_row) * spacing)
		mm.set_instance_transform(0, Transform3D(Basis(), at))
		mm.set_instance_custom_data(0, OWNER)
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_root.add_child(node)
		var tris := 0
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_array_len(s) / 3
		var aabb := mesh.get_aabb()
		print("MODEL %s: %d triangles, size %.2f x %.2f x %.2f" % [_kinds[i], tris, aabb.size.x, aabb.size.y, aabb.size.z])
		var label := Label3D.new()
		label.text = str(_kinds[i])
		label.font_size = 48
		label.pixel_size = 0.006
		label.position = at + Vector3(0, 0.02, 1.9)
		label.rotation.x = -PI / 2.0
		label.modulate = Color(0.1, 0.08, 0.05)
		_root.add_child(label)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 55, 0)
	sun.light_color = Color(1.0, 0.92, 0.80)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	_root.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.40, 0.66)
	sky_material.sky_horizon_color = Color(0.78, 0.74, 0.66)
	sky.sky_material = sky_material
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.92
	env.environment = e
	_root.add_child(env)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_root.add_child(_cam)
	var mid := Vector3((per_row - 1) * spacing / 2.0, 0, (ceil(_kinds.size() / float(per_row)) - 1) * spacing / 2.0)
	_shoot.call_deferred(mid, per_row * spacing, spacing)


func _shoot(mid: Vector3, span: float, spacing: float) -> void:
	_cam.look_at_from_position(mid + Vector3(span * 0.55, span * 0.75, span * 0.95), mid)
	await _settle()
	get_root().get_viewport().get_texture().get_image().save_png(_out + "_all.png")
	var per_row := int(ceil(sqrt(_kinds.size())))
	for i in _kinds.size():
		var at := Vector3((i % per_row) * spacing, 0, (i / per_row) * spacing)
		var size := 1.7
		var aabb_h: float = (_module.call("build", str(_kinds[i])) as ArrayMesh).get_aabb().size.y
		size = maxf(size, aabb_h * 1.1)
		_cam.look_at_from_position(at + Vector3(size * 0.9, size * 0.95, size * 1.3), at + Vector3(0, aabb_h * 0.4, 0))
		await _settle()
		get_root().get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, _kinds[i]])
	quit()


func _settle() -> void:
	for f in 6:
		await process_frame
