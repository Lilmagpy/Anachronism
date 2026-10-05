## Level of detail without popping (D-123): things that appear or vanish with the camera's
## distance fade over a margin instead of blinking, and the margin also keeps them from
## flickering when the camera rests right at the threshold.
##
## Ordinary materials use Godot's own visibility-range fade. Our own opaque shaders
## (Kenney kit buildings, mountain peaks) dissolve themselves instead (shaders/lod.gdshaderinc):
## the built-in fade hides them outright.
class_name Lod
extends RefCounted

const MARGIN := 0.22   ## the fade, as a share of the threshold distance (as in the shader)
const SELF_FADING := ["kit.gdshader", "peak.gdshader", "house.gdshader", "field.gdshader", "paving.gdshader", "folk.gdshader"]


static var _materials := {}   ## [material, near, far] -> its copy with those distances
static var _meshes := {}      ## [mesh, near, far] -> its copy wearing such materials


## Let go of the material copies (on quitting, so nothing is reported as leaked).
static func release() -> void:
	_materials.clear()
	_meshes.clear()


## Shown while the camera is nearer than `end`, fading out just beyond it.
static func near(item: GeometryInstance3D, end: float) -> void:
	if _dissolves(item):
		_set_distances(item, end, -1.0)
		item.visibility_range_end = end * (1.0 + MARGIN) + _radius(item)
		item.visibility_range_end_margin = 0.0
	else:
		item.visibility_range_end = end
		item.visibility_range_end_margin = end * MARGIN
		item.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Shown while the camera is farther than `begin`, fading in just before it.
static func far(item: GeometryInstance3D, begin: float) -> void:
	if _dissolves(item):
		_set_distances(item, -1.0, begin)
		item.visibility_range_begin = maxf(0.0, begin * (1.0 - MARGIN) - _radius(item))
	else:
		item.visibility_range_begin = begin
		item.visibility_range_begin_margin = begin * MARGIN
		item.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Shown between `begin` and `end`, fading at both ends.
static func between(item: GeometryInstance3D, begin: float, end: float) -> void:
	far(item, begin)
	near(item, end)


## Half the item's size: each model dissolves by its own distance, so a batch of them must
## stay drawn while its farthest model may still be seen.
static func _radius(item: GeometryInstance3D) -> float:
	return item.get_aabb().size.length() / 2.0


## Our own shaders that dissolve themselves (the built-in fade hides them outright).
static func _is_ours(material: Material) -> bool:
	if not (material is ShaderMaterial) or (material as ShaderMaterial).shader == null:
		return false
	var path := (material as ShaderMaterial).shader.resource_path
	for name in SELF_FADING:
		if path.ends_with(name):
			return true
	return false


static func _mesh_of(item: GeometryInstance3D) -> Mesh:
	if item is MeshInstance3D:
		return (item as MeshInstance3D).mesh
	if item is MultiMeshInstance3D and (item as MultiMeshInstance3D).multimesh != null:
		return (item as MultiMeshInstance3D).multimesh.mesh
	return null


static func _dissolves(item: GeometryInstance3D) -> bool:
	if _is_ours(item.material_override):
		return true
	var mesh := _mesh_of(item)
	if mesh != null:
		for i in mesh.get_surface_count():
			if _is_ours(mesh.surface_get_material(i)):
				return true
	return false


## Give the item materials that dissolve at these distances (-1 keeps what it has).
static func _set_distances(item: GeometryInstance3D, near_at: float, far_at: float) -> void:
	if _is_ours(item.material_override):
		item.material_override = _variant(item.material_override, near_at, far_at)
		return
	var mesh := _mesh_of(item)
	if mesh == null:
		return
	if item is MeshInstance3D:
		for i in mesh.get_surface_count():
			var own := (item as MeshInstance3D).get_surface_override_material(i)
			var material := own if own != null else mesh.surface_get_material(i)
			if _is_ours(material):
				(item as MeshInstance3D).set_surface_override_material(i, _variant(material, near_at, far_at))
	elif mesh is ArrayMesh:
		(item as MultiMeshInstance3D).multimesh.mesh = _mesh_variant(mesh as ArrayMesh, near_at, far_at)


static func _variant(material: ShaderMaterial, near_at: float, far_at: float) -> ShaderMaterial:
	var base: ShaderMaterial = material.get_meta("lod_base", material)
	var near_value: float = near_at if near_at >= 0.0 else float(material.get_shader_parameter("lod_near") if material.get_shader_parameter("lod_near") != null else 0.0)
	var far_value: float = far_at if far_at >= 0.0 else float(material.get_shader_parameter("lod_far") if material.get_shader_parameter("lod_far") != null else 0.0)
	var key := [base.get_instance_id(), near_value, far_value]
	if not _materials.has(key):
		var copy := base.duplicate() as ShaderMaterial
		copy.set_shader_parameter("lod_near", near_value)
		copy.set_shader_parameter("lod_far", far_value)
		copy.set_meta("lod_base", base)
		_materials[key] = copy
	return _materials[key]


static func _mesh_variant(mesh: ArrayMesh, near_at: float, far_at: float) -> ArrayMesh:
	var base: ArrayMesh = mesh.get_meta("lod_base", mesh)
	var key := [base.get_instance_id(), near_at, far_at, mesh.get_instance_id()]
	if _meshes.has(key):
		return _meshes[key]
	var copy := mesh.duplicate() as ArrayMesh
	for i in copy.get_surface_count():
		var material := copy.surface_get_material(i)
		if _is_ours(material):
			copy.surface_set_material(i, _variant(material, near_at, far_at))
	copy.set_meta("lod_base", base)
	_meshes[key] = copy
	return copy
