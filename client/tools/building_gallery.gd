## Renders the kit-built houses and landmarks (scripts/buildings.gd) side by side.
## godot --path client -s res://tools/building_gallery.gd -- OUT.png
extends SceneTree

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var root := Node3D.new()
	get_root().add_child(root)
	var meshes: Array = [
		Buildings.house(1, 1, 1, false, "point", 1.0), Buildings.house(2, 1, 1, false, "gable", 1.0),
		Buildings.house(2, 1, 2, true, "high", 1.6), Buildings.house(1, 1, 2, true, "high", 1.6),
		Buildings.house(3, 2, 1, false, "high", 1.3)]
	var colours := [Color(0.75, 0.35, 0.22), Color(0.3, 0.32, 0.38), Color(0.8, 0.2, 0.2), Color(0.55, 0.4, 0.25), Color(0.2, 0.5, 0.8)]
	meshes.append(Buildings.castle_icon(2.5))
	colours.append(Color(0.2, 0.4, 0.8))
	meshes.append(Buildings.town_icon(1.6))
	colours.append(Color(0.2, 0.4, 0.8))
	for kind in ["windmill", "water_wheel", "clock_tower", "watchtower", "observatory", "school", "workshop", "forge", "mint", "harbour"]:
		meshes.append(Buildings.landmark(kind, 2.0))
		colours.append(Color(0.8, 0.2, 0.2))
	var per_row := 5
	for i in meshes.size():
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i]
		mi.position = Vector3((i % per_row) * 3.0, 0, (i / per_row) * 3.0)
		root.add_child(mi)
		# instance colour: via a one-instance MultiMesh, as in the game
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[i]
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D(Basis(), mi.position))
		mm.set_instance_color(0, colours[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		root.add_child(mmi)
		mi.queue_free()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(6, 4.5, 11), Vector3(6, 0, 3.5))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.7, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.4, 0.65, 0.3)
	ground.material_override = gm
	root.add_child(ground)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.75, 0.9)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	for k in 8:
		await process_frame
	get_root().get_texture().get_image().save_png(out)
	quit()
