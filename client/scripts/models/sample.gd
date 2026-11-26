## An example module for the model kit (D-280): a plastered house with a tiled gable roof,
## framed windows and a door, a chimney; and a little tower. Copy its shape for new modules.
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")


static func kinds() -> Array:
	return ["house", "tower"]


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	match kind:
		"house":
			var wall := Color(0.93, 0.89, 0.80)
			var wood := Color(0.40, 0.27, 0.16)
			k.box(Vector3(0, 0, 0), Vector3(0.95, 0.06, 0.72), Color(0.62, 0.60, 0.55), Kit.STONE)   # plinth
			k.box(Vector3(0, 0.06, 0), Vector3(0.9, 0.5, 0.66), wall, Kit.PLASTER)
			for x in [-0.45, 0.45]:   # corner posts
				for z in [-0.33, 0.33]:
					k.box(Vector3(x, 0.06, z), Vector3(0.05, 0.5, 0.05), wood, Kit.TIMBER)
			k.door(Vector3(0.0, 0.06, 0.335), 0.0, 0.16, 0.28, wood)
			for x in [-0.27, 0.27]:
				k.window(Vector3(x, 0.42, 0.335), 0.0, 0.12, 0.13, wood, "shutters")
				k.window(Vector3(x, 0.42, -0.335), PI, 0.12, 0.13, wood, "shutters")
			k.gable_roof(Vector3(0, 0.56, 0), 0.9, 0.66, 0.32, 0.08, 0.035, Color(0.85, 0.48, 0.32),
				Kit.OWNER_ROOF, wall, Kit.PLASTER)
			k.chimney(Vector3(0.25, 0.7, -0.12), 0.08, 0.28, Color(0.6, 0.56, 0.5))
		"tower":
			k.frustum(Vector3.ZERO, 0.32, 0.28, 1.2, Color(0.72, 0.68, 0.6), Kit.STONE, 12)
			k.frustum(Vector3(0, 1.2, 0), 0.36, 0.36, 0.08, Color(0.66, 0.62, 0.55), Kit.STONE, 12)
			for i in 8:
				var a := i * TAU / 8.0
				k.box(Vector3(cos(a) * 0.31, 1.28, sin(a) * 0.31), Vector3(0.1, 0.1, 0.1), Color(0.70, 0.66, 0.58), Kit.STONE, -a)
			k.frustum(Vector3(0, 1.28, 0), 0.3, 0.0, 0.5, Color(0.8, 0.3, 0.25), Kit.TILE, 12)
			k.window(Vector3(0, 0.8, 0.31), 0.0, 0.08, 0.16, Color(0.6, 0.56, 0.5), "arch")
			k.banner(Vector3(0, 1.75, 0), 0.4, 0.25)
	return k.finish()
