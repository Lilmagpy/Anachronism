## A skinned, level-of-detail rig for the spectacles' people and animals (U6 performance pass).
##
## A figure or animal is still a hierarchy of plain Node3D "bones" (so every pose function keeps
## writing node rotations), but nothing is drawn by those nodes. Their body parts are baked into
## ONE skinned mesh per level of detail (a single draw call), driven on the GPU by a Skeleton3D
## whose bone poses are copied from the nodes every frame. Level 0 (near, < 30 m) has the full
## detail and the painted face; level 1 is lighter and casts no shadow; the engine's visibility
## ranges switch between them by distance.
##
## All parts share one shader (rig_shader below). Colour comes from a slot: 0 skin, 1 tunic,
## 2 outer cloth (toga), 3 trim, 4 hair, 5 a fixed colour baked into the part, 6 the painted face.
## The slots 0-4 are per-instance uniforms, so one baked mesh serves every colour variation.
## Rigid kit that does not bend (a shield, a sword, a fasces) is merged with rigid().
extends Node

const M := preload("res://scripts/urbs/spectacles/meshlib.gd")

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D face : source_color, filter_linear;
instance uniform vec3 c_skin : source_color = vec3(0.86, 0.66, 0.52);
instance uniform vec3 c_face : source_color = vec3(0.86, 0.66, 0.52);
instance uniform vec3 c_tunic : source_color = vec3(0.8, 0.75, 0.65);
instance uniform vec3 c_toga : source_color = vec3(0.94, 0.92, 0.84);
instance uniform vec3 c_trim : source_color = vec3(0.52, 0.1, 0.32);
instance uniform vec3 c_hair : source_color = vec3(0.17, 0.12, 0.09);
varying vec2 info;
void vertex() { info = UV2; }
void fragment() {
	int s = int(info.x + 0.5);
	vec3 c = COLOR.rgb;
	if (s == 0) { c = c_skin; }
	else if (s == 1) { c = c_tunic; }
	else if (s == 2) { c = c_toga; }
	else if (s == 3) { c = c_trim; }
	else if (s == 4) { c = c_hair; }
	else if (s == 6) {
		vec4 t = texture(face, UV);
		c = mix(c_face, t.rgb, t.a);
	}
	ALBEDO = c;
	METALLIC = info.y;
	ROUGHNESS = mix(0.92, 0.34, info.y);
}
"""

static var _material: ShaderMaterial
static var _baked: Dictionary = {}
static var _nodes_made := 0

var root: Node3D
var bone_nodes: Array[Node3D] = []
var bone_parent: Array[int] = []
var bone_rest: Array[Transform3D] = []
var parts: Array[Dictionary] = []
var skeleton: Skeleton3D
var mi0: MeshInstance3D
var mi1: MeshInstance3D
var dirty := true
var colours: Dictionary = {}
var lod_distance := 24.0
var _tick := 0


static func material() -> ShaderMaterial:
	if _material == null:
		var sh := Shader.new()
		sh.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = sh
		_material.set_shader_parameter("face", M.face_texture(Color(0.86, 0.66, 0.52), 3))
	return _material


## Make a rig under `root_node` (the figure or animal's own Node3D).
static func create(root_node: Node3D) -> Node:
	var r = (load("res://scripts/urbs/spectacles/rig.gd") as GDScript).new()
	r.root = root_node
	root_node.add_child(r)
	return r


## Register a bone: its node (already at its rest position under its parent) and parent index.
func add_bone(node: Node3D, parent: int) -> int:
	bone_nodes.append(node)
	bone_parent.append(parent)
	bone_rest.append(node.transform)
	return bone_nodes.size() - 1


## Add a baked part. `fn.call(lod)` returns the ArrayMesh for that level (or null to leave it out);
## `key` names the part (with its parameters) for the bake cache; `xf` places it in the bone's frame.
func add_part(bone: int, key: String, fn: Callable, xf := Transform3D.IDENTITY, slot := 5, col := Color.WHITE, metal := 0.0) -> void:
	parts.append({"bone": bone, "key": key, "fn": fn, "xf": xf, "slot": slot, "col": col, "metal": metal})
	dirty = true


func set_colour(slot_name: String, c: Color) -> void:
	colours[slot_name] = c
	for mi in [mi0, mi1]:
		if mi != null:
			mi.set_instance_shader_parameter(slot_name, c)


func _rest_global(i: int) -> Transform3D:
	var g := bone_rest[i]
	var p := bone_parent[i]
	while p >= 0:
		g = bone_rest[p] * g
		p = bone_parent[p]
	return g


func _bake(lod: int) -> ArrayMesh:
	var key := "L%d|" % lod
	for p in parts:
		key += "%s@%d@%s;" % [p["key"], p["bone"], p["xf"]]
	key += "|" + str(bone_rest.size())
	if _baked.has(key):
		return _baked[key]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cols := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var rest_g: Array[Transform3D] = []
	for i in bone_nodes.size():
		rest_g.append(_rest_global(i))
	for p in parts:
		var m: ArrayMesh = (p["fn"] as Callable).call(lod)
		if m == null:
			continue
		var arr := m.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var t: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var xf: Transform3D = rest_g[int(p["bone"])] * (p["xf"] as Transform3D)
		var slot := float(p["slot"])
		if slot == 6.0 and lod > 0:
			slot = 0.0
		var metal := float(p["metal"])
		var col: Color = (p["col"] as Color).srgb_to_linear()
		var b := int(p["bone"])
		for i in v.size():
			verts.append(xf * v[i])
			norms.append((xf.basis * n[i]).normalized())
			uvs.append(t[i])
			uv2.append(Vector2(slot, metal))
			cols.append(col)
			bones.append(b)
			bones.append(0)
			bones.append(0)
			bones.append(0)
			weights.append(1.0)
			weights.append(0.0)
			weights.append(0.0)
			weights.append(0.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_baked[key] = mesh
	return mesh


func _rebuild() -> void:
	dirty = false
	if skeleton == null:
		skeleton = Skeleton3D.new()
		skeleton.name = "RigSkeleton"
		for i in bone_nodes.size():
			skeleton.add_bone("b%d" % i)
		for i in bone_nodes.size():
			skeleton.set_bone_parent(i, bone_parent[i])
			skeleton.set_bone_rest(i, bone_rest[i])
		skeleton.reset_bone_poses()
		root.add_child(skeleton)
	var skin := skeleton.create_skin_from_rest_transforms()
	if mi0 == null:
		mi0 = _instance(0, skin)
		mi1 = _instance(1, skin)
		for k in colours:
			mi0.set_instance_shader_parameter(k, colours[k])
			mi1.set_instance_shader_parameter(k, colours[k])
	mi0.mesh = _bake(0)
	mi1.mesh = _bake(1)
	mi0.skin = skin
	mi1.skin = skin


func _instance(lod: int, skin: Skin) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = material()
	mi.skin = skin
	root.add_child(mi)
	mi.skeleton = mi.get_path_to(skeleton)
	if lod == 0:
		mi.visibility_range_end = lod_distance
	else:
		mi.visibility_range_begin = lod_distance
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _process(_delta: float) -> void:
	if dirty:
		_rebuild()
	if skeleton == null or not root.is_visible_in_tree():
		return
	_tick += 1
	# far figures update their bones a quarter as often
	var cam := get_viewport().get_camera_3d()
	if cam != null and _tick % 4 != 0:
		if cam.global_position.distance_squared_to(root.global_position) > 90.0 * 90.0:
			return
	for i in bone_nodes.size():
		skeleton.set_bone_pose(i, bone_nodes[i].transform)


## Merge rigid (non-bending) parts into ONE static mesh instance under `parent`.
## parts: [{key, fn(lod) -> ArrayMesh, xf, slot, col, metal}]. Returns the MeshInstance3D.
static func rigid(parent: Node3D, key: String, plist: Array, at := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mkey := "R|" + key
	var mesh: ArrayMesh
	if _baked.has(mkey):
		mesh = _baked[mkey]
	else:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var uv2 := PackedVector2Array()
		var cols := PackedColorArray()
		for p in plist:
			var m: ArrayMesh = (p["fn"] as Callable).call(0)
			if m == null:
				continue
			var arr := m.surface_get_arrays(0)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var t: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var xf: Transform3D = p.get("xf", Transform3D.IDENTITY)
			var slot := float(p.get("slot", 5))
			var metal := float(p.get("metal", 0.0))
			var col: Color = (p.get("col", Color.WHITE) as Color).srgb_to_linear()
			for i in v.size():
				verts.append(xf * v[i])
				norms.append((xf.basis * n[i]).normalized())
				uvs.append(t[i])
				uv2.append(Vector2(slot, metal))
				cols.append(col)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_COLOR] = cols
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_baked[mkey] = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material()
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi
