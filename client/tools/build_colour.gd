## Reprojects a whole-Earth satellite image (equirectangular, e.g. NASA Blue Marble) onto a
## region's height-map grid (Web Mercator), so colour and elevation line up pixel for pixel:
##   godot --headless --path client -s res://tools/build_colour.gd -- EARTH_IMAGE REGION_PREFIX
## Reads REGION_PREFIX_height.json (from build_heightmap.gd); writes REGION_PREFIX_colour.png.
extends SceneTree


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var earth := Image.load_from_file(a[0])
	var prefix := a[1]
	var bounds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix + "_height.json"))
	var w := int(bounds["width"])
	var h := int(bounds["height"])
	var top := log(tan(PI / 4.0 + deg_to_rad(bounds["north"]) / 2.0))
	var bottom := log(tan(PI / 4.0 + deg_to_rad(bounds["south"]) / 2.0))
	var ew := earth.get_width()
	var eh := earth.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var merc := top - (y + 0.5) / h * (top - bottom)
		var lat := rad_to_deg(2.0 * atan(exp(merc)) - PI / 2.0)
		var sy := (90.0 - lat) / 180.0 * eh - 0.5
		for x in w:
			var lon: float = bounds["west"] + (x + 0.5) / w * (bounds["east"] - bounds["west"])
			var sx := (lon + 180.0) / 360.0 * ew - 0.5
			out.set_pixel(x, y, _bilinear(earth, sx, sy))
	out.save_png(prefix + "_colour.png")
	print("colour map ", w, "x", h, " from ", ew, "x", eh)
	quit()


func _bilinear(image: Image, x: float, y: float) -> Color:
	var x0 := clampi(int(floor(x)), 0, image.get_width() - 2)
	var y0 := clampi(int(floor(y)), 0, image.get_height() - 2)
	var fx := clampf(x - x0, 0.0, 1.0)
	var fy := clampf(y - y0, 0.0, 1.0)
	var top := image.get_pixel(x0, y0).lerp(image.get_pixel(x0 + 1, y0), fx)
	var low := image.get_pixel(x0, y0 + 1).lerp(image.get_pixel(x0 + 1, y0 + 1), fx)
	return top.lerp(low, fy)
