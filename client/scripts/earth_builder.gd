## Builds real Earth terrain from measured elevation (client/data/<region>_height.i16: whole
## metres as little-endian 16-bit integers, row by row) and
## Natural Earth rivers. One world unit = one height-map pixel (about 5 km at the equator,
## Web Mercator). Heights are exaggerated so mountains read from a strategy camera.
##
## Colour is real satellite imagery (NASA Blue Marble, reprojected by tools/build_colour.gd),
## so deserts, forests, farmland and snow sit where they really are.
class_name EarthBuilder
extends RefCounted

const STRIDE := 2               ## mesh vertex every N height-map pixels
const METRES_PER_UNIT := 350.0  ## vertical exaggeration: about 14x at 5 km per unit
const SEA_DEPTH_SCALE := 0.25   ## flatten the sea floor so coasts stay crisp
const LAND_LIFT := 0.5          ## gap between land and water so the two never flicker

var region := ""
var bounds: Dictionary = {}
var cols := 0
var rows := 0
var ocean := PackedByteArray()
var elev := PackedFloat32Array()
var terrain_material := ShaderMaterial.new()
var colour_image: Image   ## the satellite colours (sRGB), for placing forests and fields


func _init(region_name: String) -> void:
	region = region_name
	var base := "res://data/%s_height" % region
	bounds = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	var metres := FileAccess.get_file_as_bytes(base + ".i16")
	var width := int(bounds["width"])
	cols = width / STRIDE
	rows = int(bounds["height"]) / STRIDE
	elev.resize(cols * rows)
	for r in rows:
		for q in cols:
			elev[r * cols + q] = metres.decode_s16((r * STRIDE * width + q * STRIDE) * 2)
	_find_ocean()


## Size of the map in world units.
func size() -> Vector2:
	return Vector2(bounds["width"], bounds["height"])


func to_world(pixel: Vector2, metres: float) -> Vector3:
	return Vector3(pixel.x - size().x / 2.0, _height_units(metres, metres < 0.0), pixel.y - size().y / 2.0)


func latitude(pixel_y: float) -> float:
	var top := log(tan(PI / 4.0 + deg_to_rad(bounds["north"]) / 2.0))
	var bottom := log(tan(PI / 4.0 + deg_to_rad(bounds["south"]) / 2.0))
	var merc := top - pixel_y / size().y * (top - bottom)
	return rad_to_deg(2.0 * atan(exp(merc)) - PI / 2.0)


func longitude(pixel_x: float) -> float:
	return bounds["west"] + pixel_x / size().x * (bounds["east"] - bounds["west"])


## Height-map pixel for a real place (degrees north, degrees east).
func pixel_of(lat: float, lon: float) -> Vector2:
	var top := log(tan(PI / 4.0 + deg_to_rad(bounds["north"]) / 2.0))
	var bottom := log(tan(PI / 4.0 + deg_to_rad(bounds["south"]) / 2.0))
	var merc := log(tan(PI / 4.0 + deg_to_rad(lat) / 2.0))
	var x: float = (lon - bounds["west"]) / (bounds["east"] - bounds["west"]) * size().x
	return Vector2(x, (top - merc) / (top - bottom) * size().y)


## World position on the ground for a real place.
func ground_at(lat: float, lon: float) -> Vector3:
	return ground_at_pixel(pixel_of(lat, lon))


## World position on the ground at a height-map pixel.
func ground_at_pixel(pixel: Vector2) -> Vector3:
	return Vector3(pixel.x - size().x / 2.0, _ground(pixel), pixel.y - size().y / 2.0)


## Elevation in metres at a height-map pixel (nearest grid point).
func metres_at(pixel: Vector2) -> float:
	return elev[_grid_index(pixel)]


## True where the pixel is open sea (not a lake or a dry basin below sea level).
func is_ocean_at(pixel: Vector2) -> bool:
	return ocean[_grid_index(pixel)] == 1


## Colours the land by owner: one texel per map cell, alpha = how strongly to tint.
func set_political(image: Image) -> void:
	terrain_material.set_shader_parameter("political", ImageTexture.create_from_image(image))


func _grid_index(pixel: Vector2) -> int:
	var q := clampi(int(round(pixel.x / STRIDE)), 0, cols - 1)
	var r := clampi(int(round(pixel.y / STRIDE)), 0, rows - 1)
	return r * cols + q


func _height_units(metres: float, is_ocean: bool) -> float:
	if is_ocean:
		return minf(metres, 0.0) * SEA_DEPTH_SCALE / METRES_PER_UNIT - LAND_LIFT
	# Dry land (even basins below sea level, like Turpan) always stands clear of the water.
	return maxf(metres, 0.0) / METRES_PER_UNIT + LAND_LIFT


## Ocean = below sea level and connected to the map's edge, or a basin large enough to be
## an inland sea (the Black Sea's strait is narrower than a map cell; the Caspian has none).
## Small dry depressions below sea level (Turpan, Qattara) stay land.
const INLAND_SEA_CELLS := 2500


func _find_ocean() -> void:
	ocean.resize(cols * rows)
	ocean.fill(0)
	var starts: Array[int] = []
	for q in cols:
		starts.append(q)
		starts.append((rows - 1) * cols + q)
	for r in rows:
		starts.append(r * cols)
		starts.append(r * cols + cols - 1)
	_flood(starts, 1)
	# every other basin below sea level: flood it, keep it if it is big
	for i in cols * rows:
		if ocean[i] == 0 and elev[i] < 0.0:
			var cells := _flood([i], 2)
			if cells.size() >= INLAND_SEA_CELLS:
				for c in cells:
					ocean[c] = 1
	for i in cols * rows:
		if ocean[i] == 2:
			ocean[i] = 0


## Marks below-sea-level cells reachable from `starts` with `mark`; returns them.
func _flood(starts: Array[int], mark: int) -> PackedInt32Array:
	var filled := PackedInt32Array()
	var queue: Array[int] = starts.duplicate()
	while not queue.is_empty():
		var i: int = queue.pop_back()
		if ocean[i] != 0 or elev[i] >= 0.0:
			continue
		ocean[i] = mark
		filled.append(i)
		var q := i % cols
		var r := i / cols
		if q > 0: queue.append(i - 1)
		if q < cols - 1: queue.append(i + 1)
		if r > 0: queue.append(i - cols)
		if r < rows - 1: queue.append(i + cols)
	return filled


func build(parent: Node3D) -> void:
	parent.add_child(_terrain())
	parent.add_child(_open_ocean())
	parent.add_child(_sea())
	parent.add_child(_rivers())


func _terrain() -> MeshInstance3D:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(cols * rows)
	normals.resize(cols * rows)
	uvs.resize(cols * rows)
	var h := PackedFloat32Array()
	h.resize(cols * rows)
	for i in cols * rows:
		h[i] = _height_units(elev[i], ocean[i] == 1)
	for r in rows:
		for q in cols:
			var i := r * cols + q
			var hl := h[r * cols + maxi(q - 1, 0)]
			var hr := h[r * cols + mini(q + 1, cols - 1)]
			var hu := h[maxi(r - 1, 0) * cols + q]
			var hd := h[mini(r + 1, rows - 1) * cols + q]
			var normal := Vector3(hl - hr, 2.0 * STRIDE, hu - hd).normalized()
			var pixel := Vector2(q * STRIDE, r * STRIDE)
			verts[i] = Vector3(pixel.x - size().x / 2.0, h[i], pixel.y - size().y / 2.0)
			normals[i] = normal
			uvs[i] = (pixel + Vector2(0.5, 0.5)) / size()
	var indices := PackedInt32Array()
	indices.resize((rows - 1) * (cols - 1) * 6)
	var k := 0
	for r in rows - 1:
		for q in cols - 1:
			var i := r * cols + q
			indices[k] = i
			indices[k + 1] = i + 1
			indices[k + 2] = i + cols
			indices[k + 3] = i + 1
			indices[k + 4] = i + cols + 1
			indices[k + 5] = i + cols
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var image := Image.new()
	image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://data/%s_colour.png" % region))
	colour_image = image.duplicate()
	image.generate_mipmaps()
	terrain_material.shader = load("res://shaders/terrain.gdshader")
	terrain_material.set_shader_parameter("metres_per_unit", METRES_PER_UNIT)
	terrain_material.set_shader_parameter("land_lift", LAND_LIFT)
	terrain_material.set_shader_parameter("sea_depth_scale", SEA_DEPTH_SCALE)
	terrain_material.set_shader_parameter("colour_map", ImageTexture.create_from_image(image))
	var clear := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	terrain_material.set_shader_parameter("political", ImageTexture.create_from_image(clear))
	var instance := MeshInstance3D.new()
	instance.name = "Terrain"
	instance.mesh = mesh
	# The satellite image already holds real shading; cast shadows only add jagged artefacts.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = terrain_material
	return instance


## Deep water beyond the map's edges, so the world never ends in a void.
func _open_ocean() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size() * 6.0
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/ocean.gdshader")
	var ocean_plane := MeshInstance3D.new()
	ocean_plane.name = "OpenOcean"
	ocean_plane.mesh = plane
	ocean_plane.material_override = material
	ocean_plane.position.y = -3.0
	ocean_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ocean_plane


func _sea() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size() * 6.0  # the water surface covers the open ocean too
	var material := ShaderMaterial.new()  # animated waves over the painted sea floor
	material.shader = load("res://shaders/water.gdshader")
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.material_override = material
	return sea


## Real rivers as ribbons lying on the terrain; bigger rivers are wider.
func _rivers() -> MeshInstance3D:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_rivers.json" % region))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.10, 0.24, 0.38))
	for river in data["rivers"]:
		var width := lerpf(0.0011, 0.0004, clampf((float(river["rank"]) - 1.0) / 8.0, 0.0, 1.0))
		var line: Array[Vector3] = []
		for p in river["points"]:
			var v := Vector2(p[0], p[1])
			line.append(ground_at_pixel(v))
		EarthBuilder.add_line(st, line, width, Color(0.10, 0.24, 0.38))
	var instance := MeshInstance3D.new()
	instance.name = "Rivers"
	instance.mesh = st.commit()
	instance.material_override = EarthBuilder.line_material(0.0012)
	return instance


## Adds a line that keeps its on-screen thickness at every zoom (shaders/line.gdshader).
## `width` is a fraction of the camera distance (0.001 is about 4 pixels).
static func add_line(st: SurfaceTool, points: Array[Vector3], width: float, colour: Color) -> void:
	var pts: Array[Vector3] = []
	for p in points:
		if pts.is_empty() or Vector2(pts[-1].x, pts[-1].z).distance_to(Vector2(p.x, p.z)) > 0.05:
			pts.append(p)
	if pts.size() < 2:
		return
	var sides: Array[Vector2] = []
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		sides.append(Vector2(b.x - a.x, b.z - a.z).normalized().orthogonal())
	st.set_color(colour)
	st.set_uv(Vector2(width, 0))
	for i in pts.size() - 1:
		for corner in [[i, 1.0], [i + 1, 1.0], [i, -1.0], [i, -1.0], [i + 1, 1.0], [i + 1, -1.0]]:
			st.set_uv2(sides[corner[0]] * corner[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(pts[corner[0]])


static func line_material(lift: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/line.gdshader")
	material.set_shader_parameter("lift", lift)
	return material


## Height of the terrain surface (world units) at a height-map pixel, bilinear on the grid.
func _ground(pixel: Vector2) -> float:
	var gx := clampf(pixel.x / STRIDE, 0.0, cols - 1.001)
	var gy := clampf(pixel.y / STRIDE, 0.0, rows - 1.001)
	var q := int(gx)
	var r := int(gy)
	var fx := gx - q
	var fy := gy - r
	var h00 := _cell_height(r * cols + q)
	var h10 := _cell_height(r * cols + q + 1)
	var h01 := _cell_height((r + 1) * cols + q)
	var h11 := _cell_height((r + 1) * cols + q + 1)
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fy)


func _cell_height(i: int) -> float:
	return _height_units(elev[i], ocean[i] == 1)
