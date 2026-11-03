## Every civilisation symbol on a shield, in a grid with its id (for checking the art).
## godot --path client -s res://tools/symbol_sheet.gd -- OUT.png
extends SceneTree

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var files := Array(DirAccess.get_files_at("res://assets/symbols")).filter(func(f): return f.ends_with(".svg"))
	var sheet := Image.create(1600, 1000, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.95, 0.92, 0.85))
	var per_row := 10
	for i in files.size():
		var id: String = files[i].get_basename()
		var img := Symbols.shield(Color.from_hsv(float(i) / files.size(), 0.6, 0.65), id, 128).get_image()
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(20 + (i % per_row) * 158, 10 + (i / per_row) * 160))
	sheet.save_png(out)
	print(", ".join(files.map(func(f): return f.get_basename())))
	quit()
