extends SceneTree
## Prints FRAME <year> <id> <json score> for every monument's --at pick (tuning the frame check).
func _initialize() -> void:
	var years: Array = Array(OS.get_environment("F3YEARS").split(",", false)).map(func(x): return int(x)) if OS.get_environment("F3YEARS") != "" else [-509, -264, -44]
	var only := OS.get_environment("F3IDS").split(",", false)
	for y in years:
		UrbsTerrain.year = y
		UrbsTerrain.prepare()
		var root := Node3D.new()
		get_root().add_child(root)
		var mon := UrbsMonuments.new()
		mon.build(root, y, Callable(UrbsTerrain, "height_at"))
		var fill := UrbsFill.new()
		var stand_in := UrbsMonumentAudit.AuditUrbs.new()
		stand_in.monuments = mon
		stand_in.ground = Callable(UrbsTerrain, "height_at")
		fill.build(stand_in, y, Callable(UrbsTerrain, "height_at"))
		var ids: Array = mon.ids()
		ids.sort()
		for id in ids:
			if not only.is_empty() and not only.has(id):
				continue
			var mv := UrbsMonumentView.new(mon, Callable(UrbsTerrain, "height_at"), fill)
			var v := mv.pick(id)
			if not v.has("eye"):
				continue
			var eye: Vector3 = v.eye
			var fr := UrbsMonumentFrame.new(mv)
			var t: Vector3 = v.get("target", eye)
			fr.prepare(Vector2(t.x, t.z), eye.distance_to(t) + 80.0)
			var pts: Array = UrbsMonumentFrame.facade_points(v.front) if v.has("front") else []
			var sc := fr.score(id, eye, float(v.facing), float(v.get("pitch", 3.0)), pts)
			var hf: Vector2 = mon._placed.get(id, {}).get("half", Vector2.ONE * 9.0)
			print("FRAME %d %s %s %s eye=%s t=%s f=%.2f p=%.1f k=%s" % [y, id, JSON.stringify(sc), JSON.stringify(UrbsMonumentFrame.faults(sc, hf.x * 2.0 < 2.5)), eye, t, float(v.facing), float(v.get("pitch", 3.0)), v.keys()])
			print("PLACED ", mon._placed.get(id, {}))
			var basis := Basis(Vector3.UP, float(v.facing)) * Basis(Vector3.RIGHT, deg_to_rad(float(v.get("pitch", 3.0))))
			var ty := tan(deg_to_rad(35.0))
			var tx := ty * 16.0 / 9.0
			var whos := {}
			for j in 18:
				var line := ""
				for i in 32:
					var u := ((i + 0.5) / 32) * 2.0 - 1.0
					var w := 1.0 - ((j + 0.5) / 18) * 2.0
					var d := (basis * Vector3(u * tx, w * ty, -1.0)).normalized()
					var hit := fr.cast(eye, d, 400.0)
					var k := str(hit[1])
					var wh := str(hit[2])
					var ch := "."
					if wh == id:
						ch = "#"
					elif k == "mon" or (k == "ground" and wh != ""):
						if not whos.has(wh):
							whos[wh] = "abcdefghijklmnopqrstuvwxyz"[whos.size() % 26]
						ch = whos[wh]
					elif k == "ground":
						ch = "_" if float(hit[0]) > 10.0 else "="
					elif k == "house":
						ch = "H"
					elif k == "tree":
						ch = "T"
					line += ch
				print("MAP ", line)
			print("KEY ", whos)
			for mid2 in mon._nodes:
				var nd2: Node3D = mon._nodes[mid2]
				for dsc in nd2.find_children("*", "GeometryInstance3D", true, false):
					if dsc.get_parent() == nd2:
						continue
					var gb: AABB = (dsc as VisualInstance3D).get_aabb()
					var gx: Transform3D = nd2.global_transform.affine_inverse() * (dsc as Node3D).global_transform if nd2.is_inside_tree() else Transform3D()
					var wb: AABB = nd2.transform * gx * gb
					if wb.grow(30.0).has_point(Vector3(eye.x, wb.get_center().y, eye.z)):
						print("DEEP ", mid2, " ", dsc.get_path(), " ", dsc.get_class(), " ", wb)
			for kk2 in 25:
				var q3: Vector3 = eye + Vector3(-sin(float(v.facing)), 0, -cos(float(v.facing))) * float(kk2)
				print("SITE ", kk2, " pf=", UrbsSite.platform_at(q3.x, q3.z), " terr=", UrbsTerrain.terrace_at(q3.x, q3.z), " th=", UrbsSite.terrace_height_at(q3.x, q3.z))
			for ang in [-60.0, -40.0, -20.0, 0.0, 20.0, 40.0, 60.0]:
				var yy := float(v.facing) + deg_to_rad(ang)
				for pd in [-5.0, -15.0, -30.0, -60.0]:
					var dv := Basis(Vector3.UP, yy) * Basis(Vector3.RIGHT, deg_to_rad(pd)) * Vector3(0, 0, -1)
					var hh: Array = fr.cast(eye, dv, 60.0)
					print("RAY yaw+%d pitch%d -> %.2f %s %s  y=%.2f" % [ang, pd, float(hh[0]), hh[1], hh[2], (eye + dv * float(hh[0])).y])
			var stz := UrbsStreets.new()
			stz.load_data(y)
			for kk in [0.0, 3.0, 6.0, 9.0, 13.0]:
				var qq: Vector3 = eye + Vector3(-sin(float(v.facing)), 0, -cos(float(v.facing))) * kk
				var ns: Dictionary = stz.nearest_street(Vector2(qq.x, qq.z))
				print("STREET ", kk, " ", ns.get("id"), " d=", ns.get("distance"), " hw=", ns.get("half_width"), " kind=", ns.get("kind"))
			var dd := Vector3(-sin(float(v.facing)), 0, -cos(float(v.facing)))
			var prof := ""
			for k in 25:
				var q := eye + dd * float(k)
				prof += "%d:%.2f " % [k, UrbsTerrain.height_at(q.x, q.z)]
			print("PROF ", prof)
			for k in [2.0, 4.0, 6.0, 8.0, 12.0]:
				var q2: Vector3 = eye + dd * float(k)
				var h2: Array = fr.cast(Vector3(q2.x, 70.0, q2.z), Vector3.DOWN, 40.0)
				print("DOWN ", k, " ", h2, " y=", 70.0 - float(h2[0]))
			var ck := UrbsFill.CHUNK
			for i in range(floori((eye.x - 40) / ck), floori((eye.x + 40) / ck) + 1):
				for j in range(floori((eye.z - 40) / ck), floori((eye.z + 40) / ck) + 1):
					for lot in fill.lots_for_chunk(Vector2i(i, j)):
						var lc: Vector2 = lot["c"]
						if lc.distance_to(Vector2(eye.x, eye.z)) < 45.0:
							print("LOT ", lot.get("kind", ""), " ", lot.get("mesh", ""), " c=", lc, " hx=", lot.get("hx"), " hz=", lot.get("hz"), " y=", lot.get("y"), " top=", lot.get("top"), " g=", UrbsTerrain.height_at(lc.x, lc.y))
			for mid in mon._nodes:
				var nd: Node3D = mon._nodes[mid]
				var pl: Dictionary = mon._placed.get(mid, {})
				var near_any := false
				for ch in nd.get_children():
					if ch is MeshInstance3D and (ch as MeshInstance3D).mesh != null:
						var bx: AABB = (nd.transform * (ch as MeshInstance3D).transform) * (ch as MeshInstance3D).mesh.get_aabb()
						if bx.grow(20.0).has_point(Vector3(eye.x, bx.get_center().y, eye.z)):
							near_any = true
							print("NEAR ", mid, " ", pl.get("model", ""), " ", ch.name, " vis=", (ch as MeshInstance3D).visibility_range_begin, "-", (ch as MeshInstance3D).visibility_range_end, " box=", bx)
				if not near_any and Vector2(eye.x, eye.z).distance_to(pl.get("centre", Vector2.INF)) < 60.0:
					print("NEARC ", mid, " ", pl.get("model", ""), " kids=", nd.get_child_count())
		root.queue_free()
	quit()
