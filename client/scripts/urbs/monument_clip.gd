## Urbs F3 (monuments): where two sourced buildings truly overlap, the meeting is built: the one
## that YIELDS (its record's `yields_to`, monuments.yaml) loses whatever of it stands inside the
## other's solids, so it abuts the other's wall instead of running through it. Neither moves.
##
## `clip(node, boxes)`: every mesh under `node` (all levels of detail) is cut by the boxes, each
## {xf: Transform3D of the other's frame, box: AABB in that frame}; a box takes everything inside
## its plan up to its top (below it too: a foundation in the ground is not seen). Triangles are
## cut exactly (Sutherland-Hodgman against the box's four sides and its top, each vertex
## attribute interpolated), so the cut edge lies on the other's face. Instanced parts (columns)
## whose centre falls inside are dropped. Meshes are replaced, never edited: the kit's meshes are
## shared between monuments.
class_name UrbsMonumentClip
extends RefCounted

const ATTRS := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV,
	Mesh.ARRAY_TEX_UV2]


## Cut everything under `node` that stands inside `boxes`. Returns the triangles removed or cut.
static func clip(node: Node3D, boxes: Array) -> int:
	var n := 0
	for ch in node.get_children():
		if ch is MeshInstance3D:
			var mi: MeshInstance3D = ch
			if mi.mesh is ArrayMesh:
				var res := _clip_mesh(mi.mesh, node.transform * mi.transform, boxes)
				if res[1] > 0:
					mi.mesh = res[0]
					n += int(res[1])
		elif ch is MultiMeshInstance3D:
			var mmi: MultiMeshInstance3D = ch
			n += _clip_multimesh(mmi, node.transform * mmi.transform, boxes)
	return n


## [new mesh, triangles touched]. `to_world` takes the mesh's coordinates to the world.
static func _clip_mesh(mesh: ArrayMesh, to_world: Transform3D, boxes: Array) -> Array:
	var frames: Array = []   # per box: the mesh's coordinates into the box's frame
	var mb := mesh.get_aabb()
	for b in boxes:
		var to_box: Transform3D = (b.xf as Transform3D).affine_inverse() * to_world
		var bb: AABB = b.box
		var mbb := _aabb_under(to_box, mb)
		if mbb.position.x > bb.end.x or mbb.end.x < bb.position.x or mbb.position.z > bb.end.z \
				or mbb.end.z < bb.position.z or mbb.position.y > bb.end.y:
			continue
		frames.append({"t": to_box, "box": bb})
	if frames.is_empty():
		return [mesh, 0]
	var out := ArrayMesh.new()
	var touched := 0
	for s in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return [mesh, 0]
		var arr := mesh.surface_get_arrays(s)
		var res := _clip_surface(arr, frames)
		touched += int(res[1])
		var na: Array = res[0]
		if (na[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(s))
	if touched == 0:
		return [mesh, 0]
	return [out, touched]


static func _aabb_under(t: Transform3D, b: AABB) -> AABB:
	var r := AABB(t * b.position, Vector3.ZERO)
	for i in 8:
		r = r.expand(t * b.get_endpoint(i))
	return r


## One surface's arrays cut by the boxes: [new arrays (not indexed), triangles touched].
static func _clip_surface(arr: Array, frames: Array) -> Array:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var nv := idx.size() if idx.size() > 0 else verts.size()
	# the output, attribute by attribute (only those the surface has)
	var have: Array = []
	for a in ATTRS:
		if arr[a] != null and (a == Mesh.ARRAY_VERTEX or _len(arr[a], a) > 0):
			have.append(a)
	for k in arr.size():
		if arr[k] != null and k != Mesh.ARRAY_INDEX and not have.has(k) and _len(arr[k], k) > 0:
			return [arr, 0]   # an attribute this cutter does not know (bones...): leave it whole
	var dst := {}
	for a in have:
		dst[a] = _empty(a)
	var touched := 0
	for t in range(0, nv, 3):
		var ids := [idx[t] if idx.size() > 0 else t, idx[t + 1] if idx.size() > 0 else t + 1, idx[t + 2] if idx.size() > 0 else t + 2]
		var poly: Array = []
		for i in ids:
			poly.append(_vertex(arr, have, int(i)))
		var pieces := [poly]
		for f in frames:
			var nxt: Array = []
			for pc in pieces:
				nxt.append_array(_outside(pc, f.t, f.box))
			pieces = nxt
			if pieces.is_empty():
				break
		if pieces.size() == 1 and pieces[0] == poly:
			_emit(dst, have, poly)
			continue
		touched += 1
		for pc in pieces:
			_emit(dst, have, pc)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for a in have:
		out[a] = dst[a]
	return [out, touched]


static func _len(v: Variant, a: int) -> int:
	if v is PackedVector3Array:
		return (v as PackedVector3Array).size()
	if v is PackedVector2Array:
		return (v as PackedVector2Array).size()
	if v is PackedColorArray:
		return (v as PackedColorArray).size()
	if v is PackedFloat32Array:
		return (v as PackedFloat32Array).size() / (4 if a == Mesh.ARRAY_TANGENT else 1)
	if v is PackedInt32Array:
		return (v as PackedInt32Array).size()
	if v is PackedByteArray:
		return (v as PackedByteArray).size()
	return 0


static func _empty(a: int) -> Variant:
	match a:
		Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
			return PackedVector3Array()
		Mesh.ARRAY_TANGENT:
			return PackedFloat32Array()
		Mesh.ARRAY_COLOR:
			return PackedColorArray()
	return PackedVector2Array()


## A vertex as an Array of its attributes (in `have` order; a tangent as a Vector4).
static func _vertex(arr: Array, have: Array, i: int) -> Array:
	var v: Array = []
	for a in have:
		match a:
			Mesh.ARRAY_TANGENT:
				var tg: PackedFloat32Array = arr[a]
				v.append(Vector4(tg[i * 4], tg[i * 4 + 1], tg[i * 4 + 2], tg[i * 4 + 3]))
			_:
				v.append(arr[a][i])
	return v


static func _lerp_vertex(p: Array, q: Array, t: float) -> Array:
	var v: Array = []
	for k in p.size():
		var a: Variant = p[k]
		var b: Variant = q[k]
		if a is Vector4:
			var r: Vector4 = (a as Vector4).lerp(b, t)
			r.w = (a as Vector4).w   # the handedness stays
			v.append(r)
		elif a is Color:
			v.append((a as Color).lerp(b, t))
		elif a is Vector3:
			v.append((a as Vector3).lerp(b, t))
		else:
			v.append((a as Vector2).lerp(b, t))
	if p.size() > 1 and v[1] is Vector3:
		v[1] = (v[1] as Vector3).normalized()   # the normal (ARRAY_NORMAL follows the position)
	return v


## The convex pieces of polygon `poly` (vertices: attribute arrays, position first) that lie
## outside the box (`t` takes positions into its frame; the box reaches down without end).
static func _outside(poly: Array, t: Transform3D, box: AABB) -> Array:
	# planes as (axis, bound, sign): the inside is sign * (u[axis] - bound) <= 0
	var planes := [[0, box.position.x, -1.0], [0, box.end.x, 1.0], [2, box.position.z, -1.0], [2, box.end.z, 1.0],
		[1, box.end.y, 1.0]]
	var pieces: Array = []
	var rest := poly
	for pl in planes:
		var parts := _split(rest, t, int(pl[0]), float(pl[1]), float(pl[2]))
		if (parts[1] as Array).size() >= 3:
			pieces.append(parts[1])
		rest = parts[0]
		if rest.size() < 3:
			return pieces
	# what is left is inside the box: dropped
	if pieces.size() == 1 and (pieces[0] as Array).size() == poly.size():
		var same := true
		for k in poly.size():
			if pieces[0][k] != poly[k]:
				same = false
		if same:
			return [poly]
	return pieces


## [inside part, outside part] of a convex polygon by the plane sign * (u[axis] - bound) = 0.
static func _split(poly: Array, t: Transform3D, axis: int, bound: float, sgn: float) -> Array:
	var ins: Array = []
	var outs: Array = []
	var n := poly.size()
	var d := PackedFloat32Array()
	d.resize(n)
	var all_in := true
	var all_out := true
	for i in n:
		var u: Vector3 = t * (poly[i][0] as Vector3)
		d[i] = sgn * (u[axis] - bound)
		if d[i] > 0.0:
			all_in = false
		else:
			all_out = false
	if all_in:
		return [poly, []]
	if all_out:
		return [[], poly]
	for i in n:
		var j := (i + 1) % n
		var a: Array = poly[i]
		var b: Array = poly[j]
		var da := d[i]
		var db := d[j]
		if da <= 0.0:
			ins.append(a)
		else:
			outs.append(a)
		if (da <= 0.0) != (db <= 0.0):
			var c := _lerp_vertex(a, b, da / (da - db))
			ins.append(c)
			outs.append(c)
	return [ins, outs]


## A convex polygon written as a fan of triangles.
static func _emit(dst: Dictionary, have: Array, poly: Array) -> void:
	for i in range(1, poly.size() - 1):
		for v in [poly[0], poly[i], poly[i + 1]]:
			for k in have.size():
				var a: int = have[k]
				match a:
					Mesh.ARRAY_TANGENT:
						var tg: Vector4 = v[k]
						var pf: PackedFloat32Array = dst[a]
						pf.append(tg.x)
						pf.append(tg.y)
						pf.append(tg.z)
						pf.append(tg.w)
						dst[a] = pf
					_:
						dst[a].append(v[k])


## Drops the instances whose box centre stands inside a box; the count dropped.
static func _clip_multimesh(mmi: MultiMeshInstance3D, to_world: Transform3D, boxes: Array) -> int:
	var mm := mmi.multimesh
	if mm == null or mm.mesh == null:
		return 0
	var c0 := mm.mesh.get_aabb().get_center()
	var keep: Array = []
	for itv in instance_xforms(mmi):
		var it: Transform3D = itv
		var w := to_world * (it * c0)
		var inside := false
		for b in boxes:
			var u: Vector3 = (b.xf as Transform3D).affine_inverse() * w
			var bb: AABB = b.box
			if u.x >= bb.position.x and u.x <= bb.end.x and u.z >= bb.position.z and u.z <= bb.end.z and u.y <= bb.end.y:
				inside = true
				break
		if not inside:
			keep.append(it)
	var dropped := mm.instance_count - keep.size()
	if dropped == 0:
		return 0
	var nm := MultiMesh.new()
	nm.transform_format = MultiMesh.TRANSFORM_3D
	nm.use_colors = mm.use_colors
	nm.mesh = mm.mesh
	nm.instance_count = keep.size()
	for k in keep.size():
		nm.set_instance_transform(k, keep[k])
		if nm.use_colors:
			nm.set_instance_color(k, Color.WHITE)
	mmi.multimesh = nm
	mmi.set_meta("xforms", keep)
	return dropped


## The instance transforms of a MultiMeshInstance3D: its "xforms" meta when UrbsMonuments set
## one (a MultiMesh under the headless renderer keeps no transforms), else the MultiMesh's own.
static func instance_xforms(mmi: MultiMeshInstance3D) -> Array:
	if mmi.has_meta("xforms"):
		return mmi.get_meta("xforms")
	var out: Array = []
	if mmi.multimesh != null:
		for k in mmi.multimesh.instance_count:
			out.append(mmi.multimesh.get_instance_transform(k))
	return out
