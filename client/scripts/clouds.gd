## Soft cartoon clouds drifting high over the map, seen when zoomed out (like the painted
## clouds of a strategy game's world view). Each cloud is a cluster of flattened puffs; they
## drift with the wind and wrap around at the map's edge. They fade away as the camera
## comes down, so they never block the view of a province.
class_name Clouds
extends Node3D

const COUNT := 22
const HEIGHT := 140.0
const WIND := Vector3(6.0, 0.0, 1.5)   ## map units per second

var bounds := Rect2()
var _clouds: Array[Node3D] = []


func build(area: Rect2) -> void:
	bounds = area
	name = "Clouds"
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, 0.62)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.roughness = 1.0
	material.emission_enabled = true
	material.emission = Color(0.55, 0.58, 0.62)   # stay bright on the shaded side
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 12
	puff.rings = 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 7   # the same sky every time
	for i in COUNT:
		var cloud := Node3D.new()
		var size := rng.randf_range(9.0, 22.0)
		for k in rng.randi_range(4, 7):
			var part := MeshInstance3D.new()
			part.mesh = puff
			part.material_override = material
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			part.position = Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.0, 0.4), rng.randf_range(-0.6, 0.6)) * size
			part.scale = Vector3(1.0, 0.45, 0.8) * size * rng.randf_range(0.55, 1.0)
			part.visibility_range_begin = 420.0
			part.visibility_range_begin_margin = 180.0
			part.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
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
