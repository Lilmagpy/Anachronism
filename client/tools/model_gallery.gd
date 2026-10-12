## Lays out every model in a folder in a grid with names and saves a picture (for choosing art).
## godot --path client -s res://tools/model_gallery.gd -- res://assets/kenney/hexagon OUT.png
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0]
	var out: String = args[1]
	var root := Node3D.new()
	get_root().add_child(root)
	var files := Array(DirAccess.get_files_at(folder)).filter(func(f): return f.ends_with(".glb"))
	var per_row := int(ceil(sqrt(files.size())))
	for i in files.size():
		var scene: PackedScene = load(folder.path_join(files[i]))
		var node := scene.instantiate() as Node3D
		var at := Vector3((i % per_row) * 2.2, 0, (i / per_row) * 2.2)
		node.position = at
		root.add_child(node)
		var label := Label3D.new()
		label.text = files[i].get_basename()
		label.font_size = 40
		label.pixel_size = 0.004
		label.position = at + Vector3(0, -0.05, 0.9)
		label.rotation.x = -PI / 2.6
		label.modulate = Color.BLACK
		root.add_child(label)
	var cam := Camera3D.new()
	var mid := Vector3((per_row - 1) * 1.1, 0, (per_row - 1) * 1.1)
	root.add_child(cam)
	cam.look_at_from_position(mid + Vector3(0, per_row * 1.9, per_row * 1.5), mid)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.6, 0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.85, 0.88, 0.9)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	for k in 5:
		await process_frame
	get_root().get_texture().get_image().save_png(out)
	quit()
