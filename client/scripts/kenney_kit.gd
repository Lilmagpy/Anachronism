## Models from the Kenney CC0 kits (client/assets/kenney, G1), ready for MultiMesh batches.
##
## `mesh()` turns a .glb into one mesh with every part's placement baked in, standing on
## y = 0, centred, and scaled to a given height. Each surface gets the kit shader: buildings
## repaint their blue accents (roofs, flags) in the instance colour, trees their foliage.
class_name KenneyKit
extends RefCounted

const ROOT := "res://assets/kenney/"

static var _cache := {}


## `name` is "pack/model" (e.g. "hexagon/unit-house"); `height` the height wanted in map units.
## `recolour`: "accents" (blue parts take the instance colour), "foliage" (green surfaces do),
## "roofs" (the fantasy-town roof and awning colours do, its pale plaster turns warm),
## or "none".
static func mesh(name: String, height: float, recolour := "accents") -> ArrayMesh:
	return compose("%s|%s|%s" % [name, height, recolour], [[name, Transform3D(), recolour]], height)


## A building put together from kit pieces: each of `pieces` is [model name, its placement in
## the kit's own units (one grid cell = 1), recolour mode]. The result stands on y = 0,
## centred, scaled to `height`, with every piece sharing a material merged into one surface
## (one draw call per material). `key` names the result for the cache.
static func compose(key: String, pieces: Array, height: float) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var parts: Array = []   # [placement, mesh, recolour]
	for piece in pieces:
		var found: Array = []
		var scene := (load(ROOT + str(piece[0]) + ".glb") as PackedScene).instantiate()
		_collect(scene, piece[1], found)
		scene.free()
		for f in found:
			parts.append([f[0], f[1], piece[2]])
	var box := AABB()
	var first := true
	for part in parts:
		var b: AABB = part[0] * (part[1] as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var k := height / maxf(box.size.y, 0.001)
	var fit := Transform3D(Basis().scaled(Vector3.ONE * k), Vector3(-box.get_center().x * k, -box.position.y * k, -box.get_center().z * k))
	var tools := {}   # material -> SurfaceTool
	var order: Array = []
	for part in parts:
		var source: Mesh = part[1]
		for s in source.get_surface_count():
			var material := _material(source.surface_get_material(s), part[2])
			if not tools.has(material):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material] = st
				order.append(material)
			(tools[material] as SurfaceTool).append_from(source, s, fit * part[0])
	var out := ArrayMesh.new()
	for material in order:
		(tools[material] as SurfaceTool).commit(out)
		out.surface_set_material(out.get_surface_count() - 1, material)
	_cache[key] = out
	return out


## Several models stacked one on another (a tower: base, middle, roof), as one mesh of the
## given height.
static func stack(names: Array, height: float, recolour := "accents") -> ArrayMesh:
	var key := "%s|%s|%s" % [",".join(names), height, recolour]
	if _cache.has(key):
		return _cache[key]
	var pieces: Array = []
	var total := 0.0
	for n in names:
		var m := mesh(n, 1.0, recolour)
		var native := _native_height(n)
		pieces.append([m, native])
		total += native
	var out := ArrayMesh.new()
	var y := 0.0
	var k := height / maxf(total, 0.001)
	for piece in pieces:
		var m: ArrayMesh = piece[0]
		var native: float = piece[1]
		var xf := Transform3D(Basis().scaled(Vector3.ONE * native * k), Vector3(0, y * k, 0))
		for s in m.get_surface_count():
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.append_from(m, s, xf)
			st.commit(out)
			out.surface_set_material(out.get_surface_count() - 1, m.surface_get_material(s))
		y += native
	_cache[key] = out
	return out


## A model's own height (before `mesh()` scales it).
static func _native_height(name: String) -> float:
	var scene := (load(ROOT + name + ".glb") as PackedScene).instantiate()
	var parts: Array = []
	_collect(scene, Transform3D(), parts)
	scene.free()
	var top := -INF
	var bottom := INF
	for part in parts:
		var b: AABB = part[0] * (part[1] as Mesh).get_aabb()
		top = maxf(top, b.end.y)
		bottom = minf(bottom, b.position.y)
	return top - bottom


static func _collect(node: Node, xf: Transform3D, parts: Array) -> void:
	var here := xf * (node as Node3D).transform if node is Node3D else xf
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		parts.append([here, (node as MeshInstance3D).mesh])
	for child in node.get_children():
		_collect(child, here, parts)


static var _materials := {}


static func _material(source: Material, recolour: String) -> ShaderMaterial:
	var key := [source, recolour]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/kit.gdshader")
	var colour := Color.WHITE
	var texture: Texture2D = null
	if source is BaseMaterial3D:
		colour = (source as BaseMaterial3D).albedo_color
		texture = (source as BaseMaterial3D).albedo_texture
	m.set_shader_parameter("textured", texture != null)
	if texture != null:
		m.set_shader_parameter("tex", texture)
	m.set_shader_parameter("base_colour", colour)
	var mode := 0
	if recolour == "accents":
		mode = 1
	elif recolour == "roofs":
		mode = 3
	elif recolour == "foliage" and colour.g > colour.r * 1.2 and colour.g > colour.b * 0.9:
		mode = 2   # leaves, not trunks
	m.set_shader_parameter("recolour", mode)
	_materials[key] = m
	return m
