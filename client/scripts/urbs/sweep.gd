## Visual sweep (F3): photograph the city from many viewpoints in one run, for review.
##   --sweep=<poses.json> --sweep-out=<dir>   (with --urbs --year=N; main.gd runs it)
## poses.json: {"poses": [ ... ]} where each pose is one of
##   {"kind": "monument", "id": "<monument id>"}          street view of its front (as --at=<id>)
##   {"kind": "all_monuments"}                            expands to every monument standing
##   {"kind": "street", "x": 0, "z": 0, "yaw": 90}        eye height, compass bearing in degrees
##   {"kind": "air", "x": 0, "z": 0, "h": 120, "yaw": 0, "pitch": -35}   a low aerial
##   optional "name" (file name) and "pitch" for street views.
## Each shot: camera placed, the chunks around it built at once, street life ticked, a few frames
## rendered, the picture saved as <dir>/<name>.png, and a line "SWEEP <name> x z" printed.
class_name UrbsSweep
extends RefCounted


static func expand(urbs: Node3D, poses: Array) -> Array:
	var out: Array = []
	for p in poses:
		var d: Dictionary = p
		if str(d.get("kind", "")) == "all_monuments":
			var ids: Array = urbs.monuments.ids()
			ids.sort()
			for id in ids:
				out.append({"kind": "monument", "id": str(id)})
		else:
			out.append(d)
	return out


static func run(urbs: Node3D, tree: SceneTree, poses_path: String, out_dir: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(poses_path))
	var poses: Array = expand(urbs, (parsed as Dictionary).get("poses", []) if parsed is Dictionary else [])
	DirAccess.make_dir_recursive_absolute(out_dir)
	urbs.hud.visible = false
	for layer in tree.root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	var n := 0
	for p in poses:
		var d: Dictionary = p
		var kind := str(d.get("kind", ""))
		var name := str(d.get("name", ""))
		match kind:
			"monument":
				var id := str(d.get("id", ""))
				if not urbs.monuments.ids().has(id):
					continue
				urbs._apply_flags({"mode": "street", "at": id})
				urbs.hud.visible = false
				if name == "":
					name = "m_" + id
			"street":
				var x := float(d.get("x", 0.0))
				var z := float(d.get("z", 0.0))
				var yaw := -deg_to_rad(float(d.get("yaw", 0.0)))
				var p2: Vector2 = urbs.push_out(Vector2(x, z), 0.6, 1.7)
				urbs.cam.snap_street(Vector3(p2.x, 0, p2.y), yaw, UrbsCamera.EYE, deg_to_rad(float(d.get("pitch", -3.0))))
				if name == "":
					name = "s_%d_%d_%d" % [int(x), int(z), int(d.get("yaw", 0))]
			"air":
				var x := float(d.get("x", 0.0))
				var z := float(d.get("z", 0.0))
				var yaw := -deg_to_rad(float(d.get("yaw", 0.0)))
				var h := float(d.get("h", 120.0))
				urbs.cam.snap_street(Vector3(x, 0, z), yaw, h, deg_to_rad(float(d.get("pitch", -35.0))))
				if name == "":
					name = "a_%d_%d_%d" % [int(x), int(z), int(d.get("yaw", 0))]
			_:
				continue
		urbs.chunks.focus_on(urbs.cam.focus(), false)
		urbs.fill.sync_chunks = true
		urbs.chunks.load_all_now()
		urbs.fill.sync_chunks = false
		for i in 20:
			urbs.life.tick(1.0 / 30.0, urbs.cam.camera.global_position)
		for i in 5:
			await tree.process_frame
		var path := out_dir.path_join(name + ".png")
		tree.root.get_viewport().get_texture().get_image().save_png(path)
		var at: Vector3 = urbs.cam.camera.global_position
		print("SWEEP %s %.0f %.0f %.0f" % [name, at.x, at.z, at.y])
		n += 1
	print("SWEEP DONE %d" % n)
