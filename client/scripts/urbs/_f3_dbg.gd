extends "res://scripts/urbs/audit.gd"
func _initialize() -> void:
	_year = -44
	UrbsTerrain.year = _year
	UrbsTerrain.prepare()
	var c0 := Vector2(-1545, -470)
	for line: PackedVector2Array in _f3_shorelines():
		var t := ""
		var n := 0
		for p in line:
			if p.distance_to(c0) < 40.0:
				t += "(%.1f,%.1f) " % [p.x, p.y]
				n += 1
		if n > 0:
			print("LINE ", n, " ", t)
	for dz in range(-20, 21, 5):
		var l := ""
		for dx in range(-20, 21, 5):
			var x := roundf((c0.x + dx) / 5.0) * 5.0
			var z := roundf((c0.y + dz) / 5.0) * 5.0
			l += "%6.2f " % (UrbsTerrain.height_at(x, z) - UrbsTerrain.river_level(x, z))
		print("G ", l)
	quit()
