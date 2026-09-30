## Builds real Earth terrain from measured elevation (client/data/<region>_height.exr) and
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
var heights: Image
var cols := 0
var rows := 0
var ocean := PackedByteArray()
var elev := PackedFloat32Array()


func _init(region_name: String) -> void:
	region = region_name
	var base := "res://data/%s_height" % region
	bounds = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	heights = Image.load_from_file(ProjectSettings.globalize_path(base + ".exr"))
	cols = int(bounds["width"]) / STRIDE
	rows = int(bounds["height"]) / STRIDE
	elev.resize(cols * rows)
	for r in rows:
		for q in cols:
			elev[r * cols + q] = heights.get_pixel(q * STRIDE, r * STRIDE).r
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
	var p := pixel_of(lat, lon)
	return Vector3(p.x - size().x / 2.0, _ground(p), p.y - size().y / 2.0)


func _height_units(metres: float, is_ocean: bool) -> float:
	if is_ocean:
		return minf(metres, 0.0) * SEA_DEPTH_SCALE / METRES_PER_UNIT - LAND_LIFT
	# Dry land (even basins below sea level, like Turpan) always stands clear of the water.
	return maxf(metres, 0.0) / METRES_PER_UNIT + LAND_LIFT


## Ocean = below sea level and connected to the map's edge (inland basins stay dry).
func _find_ocean() -> void:
	ocean.resize(cols * rows)
	ocean.fill(0)
	var queue: Array[int] = []
	for q in cols:
		for r in [0, rows - 1]:
			queue.append(r * cols + q)
	for r in rows:
		for q in [0, cols - 1]:
			queue.append(r * cols + q)
	while not queue.is_empty():
		var i: int = queue.pop_back()
		if ocean[i] == 1 or elev[i] >= 0.0:
			continue
		ocean[i] = 1
		var q := i % cols
		var r := i / cols
		if q > 0: queue.append(i - 1)
		if q < cols - 1: queue.append(i + 1)
		if r > 0: queue.append(i - cols)
		if r < rows - 1: queue.append(i + cols)


func build(parent: Node3D) -> void:
	parent.add_child(_terrain())
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
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://data/%s_colour.png" % region))
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.95
	var instance := MeshInstance3D.new()
	instance.name = "Terrain"
	instance.mesh = mesh
	# The satellite image already holds real shading; cast shadows only add jagged artefacts.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = material
	return instance


func _sea() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.04, 0.14, 0.28, 0.45)  # Blue Marble already shades the sea floor
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.3
	material.roughness = 0.08
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
		var width := lerpf(1.4, 0.5, clampf((float(river["rank"]) - 1.0) / 6.0, 0.0, 1.0))
		var pts: Array[Vector2] = []
		for p in river["points"]:
			var v := Vector2(p[0], p[1])
			if pts.is_empty() or pts[-1].distance_to(v) > 0.3:
				pts.append(v)
		if pts.size() < 2:
			continue
		# One continuous ribbon: each point is offset along the average of its two segments.
		var left: Array[Vector3] = []
		var right: Array[Vector3] = []
		for j in pts.size():
			var dir := (pts[mini(j + 1, pts.size() - 1)] - pts[maxi(j - 1, 0)]).normalized()
			var side := dir.orthogonal() * width * 0.5
			var y := _ground(pts[j]) + 0.12
			left.append(Vector3(pts[j].x + side.x - size().x / 2.0, y, pts[j].y + side.y - size().y / 2.0))
			right.append(Vector3(pts[j].x - side.x - size().x / 2.0, y, pts[j].y - side.y - size().y / 2.0))
		for j in pts.size() - 1:
			for p in [left[j], left[j + 1], right[j], right[j], left[j + 1], right[j + 1]]:
				st.set_normal(Vector3.UP)
				st.add_vertex(p)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.2
	material.metallic = 0.2
	var instance := MeshInstance3D.new()
	instance.name = "Rivers"
	instance.mesh = st.commit()
	instance.material_override = material
	return instance


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
