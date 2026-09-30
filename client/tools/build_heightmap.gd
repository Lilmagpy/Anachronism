## Stitches Terrarium elevation tiles into one height map for the game (run headless):
##   godot --headless --path client -s res://tools/build_heightmap.gd -- TILES_DIR ZOOM X0 X1 Y0 Y1 OUT_PREFIX
## Terrarium encodes metres as R*256 + G + B/256 - 32768 (Web Mercator tiles).
## Output: OUT_PREFIX.exr (half-size, metres, 32-bit float) and OUT_PREFIX.json (bounds).
extends SceneTree


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir := a[0]
	var zoom := int(a[1])
	var x0 := int(a[2])
	var x1 := int(a[3])
	var y0 := int(a[4])
	var y1 := int(a[5])
	var out := a[6]
	var cols := (x1 - x0 + 1) * 256
	var rows := (y1 - y0 + 1) * 256
	var full := Image.create(cols, rows, false, Image.FORMAT_RF)
	for tx in range(x0, x1 + 1):
		for ty in range(y0, y1 + 1):
			var tile := Image.load_from_file("%s/%d_%d_%d.png" % [dir, zoom, tx, ty])
			for py in 256:
				for px in 256:
					var c := tile.get_pixel(px, py)
					var metres := (c.r8 * 256.0 + c.g8 + c.b8 / 256.0) - 32768.0
					full.set_pixel((tx - x0) * 256 + px, (ty - y0) * 256 + py, Color(metres, 0, 0))
	full.resize(cols / 2, rows / 2, Image.INTERPOLATE_BILINEAR)
	full.save_exr(out + ".exr", true)
	var n := float(1 << zoom)
	var bounds := {
		"zoom": zoom, "width": cols / 2, "height": rows / 2,
		"west": x0 / n * 360.0 - 180.0, "east": (x1 + 1) / n * 360.0 - 180.0,
		"north": rad_to_deg(atan(sinh(PI * (1.0 - 2.0 * y0 / n)))),
		"south": rad_to_deg(atan(sinh(PI * (1.0 - 2.0 * (y1 + 1) / n)))),
		"km_per_pixel_equator": 40075.0 / n / 128.0,
		"source": "Terrarium elevation tiles (Mapzen / AWS Open Data: SRTM, GMTED, ETOPO1, others)",
	}
	var f := FileAccess.open(out + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(bounds, "  "))
	print("height map ", cols / 2, "x", rows / 2, " ", bounds)
	quit()
