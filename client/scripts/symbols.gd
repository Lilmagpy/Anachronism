## Civilisations' heraldic symbols (G1): white silhouettes from game-icons.net (CC BY 3.0),
## tinted when drawn. `content/packs/core/symbols.yaml` lists them; each civ names one.
class_name Symbols
extends RefCounted

static var _cache := {}


## The symbol's picture, or null if the civ has none (callers then show its emblem letters).
static func texture(id: String) -> Texture2D:
	if id == "":
		return null
	if not _cache.has(id):
		var path := "res://assets/symbols/%s.svg" % id
		_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _cache[id]


static var _shields := {}


## A heraldic shield in `colour` with a gold rim and the symbol on it in cream, `height`
## pixels tall (width 0.86 of that). Falls back to the emblem letters' civ when no symbol.
static func shield(colour: Color, id: String, height := 128) -> ImageTexture:
	var key := "%s|%s|%d" % [colour.to_html(), id, height]
	if _shields.has(key):
		return _shields[key]
	var w := int(height * 0.86)
	var h := height
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := _base(w, h)   # per pixel: 0 outside, 1 dark rim, 2 rim, 3 field (+ its shade)
	var rim := Color(0.93, 0.76, 0.32)
	var rim_dark := Color(0.55, 0.38, 0.12)
	var field := colour
	for y in h:
		for x in w:
			var b := base.get_pixel(x, y)
			var kind := int(round(b.r * 3.0))
			if kind == 1:
				image.set_pixel(x, y, rim_dark)
			elif kind == 2:
				image.set_pixel(x, y, rim)
			elif kind == 3:
				var shade := 0.85 + b.g * 0.4
				image.set_pixel(x, y, Color(field.r * shade, field.g * shade, field.b * shade))
	var symbol := texture(id)
	if symbol != null:
		var art := symbol.get_image()
		if art.is_compressed():
			art.decompress()
		art.convert(Image.FORMAT_RGBA8)
		var size := int(h * 0.56)
		art.resize(size, size, Image.INTERPOLATE_LANCZOS)
		var at := Vector2i((w - size) / 2, int(h * 0.16))
		var ink := Color(1.0, 0.95, 0.82)
		var shadow := field.darkened(0.55)
		for y in size:
			for x in size:
				var a := art.get_pixel(x, y).a
				if a <= 0.0:
					continue
				for pass_ in 2:  # a drop shadow, then the symbol
					var q := at + Vector2i(x, y) + (Vector2i(2, 3) if pass_ == 0 else Vector2i.ZERO)
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var under := image.get_pixel(q.x, q.y)
					if under.a <= 0.0:
						continue
					var top := shadow if pass_ == 0 else ink
					image.set_pixel(q.x, q.y, under.lerp(top, a * (0.6 if pass_ == 0 else 1.0)))
	var tex := ImageTexture.create_from_image(image)
	_shields[key] = tex
	return tex


static var _bases := {}


## The shield's shape at a size, worked out once: which pixels are rim and which field.
static func _base(w: int, h: int) -> Image:
	var key := Vector2i(w, h)
	if _bases.has(key):
		return _bases[key]
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var outline := _shield_outline(w, h)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(p, outline):
				continue
			var edge := _distance_to_edge(p, outline)
			var kind := 1 if edge < h * 0.035 else (2 if edge < h * 0.075 else 3)
			# a little light from the top left, as on enamel
			var light := clampf(1.0 - (p.y / h * 0.8 + p.x / w * 0.3), 0.0, 1.0)
			image.set_pixel(x, y, Color(kind / 3.0, light, 0, 1))
	_bases[key] = image
	return image


static func _shield_outline(w: float, h: float) -> PackedVector2Array:
	# a heater shield: a slightly arched top, straight sides, then curving to a point
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		pts.append(Vector2(w * t, h * 0.04 + sin(t * PI) * -h * 0.03 + h * 0.03))
	pts.append(Vector2(w, h * 0.5))
	for i in range(1, 13):
		var t := i / 12.0
		pts.append(Vector2(w * 0.5 + w * 0.5 * cos(t * PI / 2.0), h * 0.5 + h * 0.5 * sin(t * PI / 2.0)))
	for i in range(1, 13):
		var t := 1.0 - i / 12.0
		pts.append(Vector2(w * 0.5 - w * 0.5 * cos(t * PI / 2.0), h * 0.5 + h * 0.5 * sin(t * PI / 2.0)))
	return pts


static func _distance_to_edge(p: Vector2, outline: PackedVector2Array) -> float:
	var best := INF
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best
