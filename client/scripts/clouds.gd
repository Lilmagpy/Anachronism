## Soft cartoon clouds drifting high over the map, seen when zoomed out (like the painted
## clouds of a strategy game's world view). Each cloud is a cluster of flattened puffs; they
## drift with the wind and wrap around at the map's edge. They fade away as the camera
## comes down, so they never block the view of a province.
class_name Clouds
extends Node3D

const COUNT := 16
const HEIGHT := 140.0
const WIND := Vector3(6.0, 0.0, 1.5)   ## map units per second

var bounds := Rect2()
var _clouds: Array[Node3D] = []


func build(area: Rect2) -> void:
	bounds = area
	name = "Clouds"
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, 0.7)
	# a depth pre-pass draws only each cloud's outer surface, so its overlapping puffs
	# do not show through one another as darker discs
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.roughness = 1.0
	material.emission_enabled = true
	material.emission = Color(0.42, 0.45, 0.50)   # stay bright on the shaded side
	material.rim_enabled = true
	material.rim = 0.6
	material.rim_tint = 0.2
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 14
	puff.rings = 8
	var rng := RandomNumberGenerator.new()
	rng.seed = 7   # the same sky every time
	for i in COUNT:
		var size := rng.randf_range(9.0, 22.0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var puffs := rng.randi_range(5, 8)
		for k in puffs:
			# bigger puffs in the middle, a flat base: the classic cartoon cloud
			var across := (float(k) / maxf(puffs - 1, 1) - 0.5) * 2.4
			var middle := 1.0 - absf(across) / 1.6
			var at := Vector3(across, rng.randf_range(0.0, 0.25) + middle * 0.25, rng.randf_range(-0.5, 0.5)) * size
			var scale := Vector3(1.0, 0.55, 0.85) * size * rng.randf_range(0.5, 0.75) * (0.7 + middle * 0.5)
			st.append_from(puff, 0, Transform3D(Basis().scaled(scale), at))
		var part := MeshInstance3D.new()
		part.mesh = st.commit()
		part.material_override = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # solid clouds cast black blots
		part.visibility_range_begin = 950.0   # only over the whole-world view
		part.visibility_range_begin_margin = 250.0
		part.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		var cloud := Node3D.new()
		cloud.add_child(part)
		cloud.position = Vector3(rng.randf_range(area.position.x, area.end.x), HEIGHT + rng.randf_range(-20.0, 40.0), rng.randf_range(area.position.y, area.end.y))
		add_child(cloud)
		_clouds.append(cloud)


func _process(delta: float) -> void:
	for cloud in _clouds:
		cloud.position += WIND * delta
		if cloud.position.x > bounds.end.x:
			cloud.position.x = bounds.position.x
		if cloud.position.z > bounds.end.y:
			cloud.position.z = bounds.position.y
