## Urbs F3 (houses, round 4): the top of what is drawn under a person's feet. The street life
## placed its walkers 0.22 m over the height field everywhere, while a carriageway is drawn
## UrbsStreets.SURFACE_LIFT (0.12 m, plus its street's z-order lift and camber) over the drawn
## ground, a paving at its own slab and the ground itself as a mesh that can stand ~0.15 m over
## the height field on a saddle: people floated a hand's breadth over the Via Sacra and stood in
## the paving elsewhere. This reads the drawn triangles themselves: the street strips (their
## carriageways, kerbs and footways) and the pavings (UrbsMonumentFrame.PAVINGS: the Forum's
## plaza, the paved roads, the Comitium, the Lacus Curtius), over the drawn ground mesh
## (UrbsTerrain.mesh_height_at).
##
## Lazy: a mesh's upward faces are binned on a CELL grid the first time a query falls near it, so
## only the streets round the camera are ever read.
##   var g := UrbsWalkGround.new(streets_root, monuments, height)
##   var y := g.top(Vector2(x, z), estimate_y)
class_name UrbsWalkGround
extends RefCounted

const CELL := 2.0
const BLOCK := 32.0       ## meshes are found (and binned) per BLOCK m square
const ABOVE := 2.0        ## a face higher than this over the estimate is not the one under the feet
const BELOW := 1.5        ## nor one lower than this under it (only strips and pavings are read: the
                          ## highest of them is what is seen)

var height := Callable()
var _meshes: Array = []   ## [Mesh, Transform3D, Rect2 plan]
var _mesh_blocks := {}    ## Vector2i block -> PackedInt32Array of indices into _meshes
var _binned := {}         ## index into _meshes -> true once its faces are binned
var _blocks_done := {}    ## Vector2i block -> true
var _f := PackedFloat32Array()   ## upward faces, F_STRIDE floats each: plan box, corner a, edges, 1/det
const F_STRIDE := 14
var _grid := {}           ## Vector2i cell -> PackedInt32Array of face indices


## `streets_root`: the node UrbsStreets builds its strips under (UrbsStreets._root); `mons` for
## the pavings (may be null); `ground_fn(x, z)` the height field the estimates are made from.
func _init(streets_root: Node3D, mons: UrbsMonuments, ground_fn: Callable) -> void:
	height = ground_fn
	if streets_root != null and is_instance_valid(streets_root):
		var base := _xf(streets_root)
		for ch in streets_root.get_children():
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh != null:
				_add_mesh((ch as MeshInstance3D).mesh, base * (ch as MeshInstance3D).transform)
	if mons != null:
		for mid in mons._nodes:
			if not str(mons._placed.get(mid, {}).get("model", "")) in UrbsMonumentFrame.PAVINGS:
				continue
			var node: Node3D = mons._nodes[mid]
			if node == null or not is_instance_valid(node):
				continue
			var base := _xf(node)
			for ch in node.get_children():
				if ch is MeshInstance3D and (ch as MeshInstance3D).mesh != null and (ch as MeshInstance3D).visibility_range_begin <= 0.0:
					_add_mesh((ch as MeshInstance3D).mesh, base * (ch as MeshInstance3D).transform)


## A node's transform in the world (the tree may not be live yet: composed by hand).
static func _xf(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _add_mesh(mesh: Mesh, xf: Transform3D) -> void:
	var bx: AABB = xf * mesh.get_aabb()
	var plan := Rect2(bx.position.x, bx.position.z, bx.size.x, bx.size.z).grow(0.1)
	var k := _meshes.size()
	_meshes.append([mesh, xf, plan])
	for bx_i in range(floori(plan.position.x / BLOCK), floori(plan.end.x / BLOCK) + 1):
		for bz_i in range(floori(plan.position.y / BLOCK), floori(plan.end.y / BLOCK) + 1):
			var key := Vector2i(bx_i, bz_i)
			if not _mesh_blocks.has(key):
				_mesh_blocks[key] = PackedInt32Array()
			var arr: PackedInt32Array = _mesh_blocks[key]
			arr.append(k)
			_mesh_blocks[key] = arr


func _bin(k: int) -> void:
	_binned[k] = true
	var mesh: Mesh = _meshes[k][0]
	var xf: Transform3D = _meshes[k][1]
	var f := mesh.get_faces()
	for i in range(0, f.size(), 3):
		var a: Vector3 = xf * f[i]
		var b: Vector3 = xf * f[i + 1]
		var c: Vector3 = xf * f[i + 2]
		var n := (b - a).cross(c - a)
		var nl := n.length()
		if nl < 1e-7 or absf(n.y) / nl < 0.5:
			continue
		var lo := a.min(b).min(c)
		var hi := a.max(b).max(c)
		var e0 := Vector2(b.x - a.x, b.z - a.z)
		var e1 := Vector2(c.x - a.x, c.z - a.z)
		var den := e0.x * e1.y - e1.x * e0.y
		if absf(den) < 1e-9:
			continue
		var fi := _f.size() / F_STRIDE
		_f.append_array([lo.x, lo.z, hi.x, hi.z, a.x, a.z, a.y, e0.x, e0.y, e1.x, e1.y, b.y - a.y, c.y - a.y, 1.0 / den])
		for gx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			for gz in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
				var key := Vector2i(gx, gz)
				if not _grid.has(key):
					_grid[key] = PackedInt32Array()
				var arr: PackedInt32Array = _grid[key]
				arr.append(fi)
				_grid[key] = arr


## The drawn ground mesh at `p` (UrbsTerrain's lod-0 chunk, as UrbsStreets._ground reads it).
static func ground_at(p: Vector2) -> float:
	return UrbsTerrain.mesh_height_at(p.x, p.y, 1 if p.length() < UrbsTerrain.NEAR_M else 2)


## The top of what is drawn at `p` near the height `est` (the life's estimate of the feet): the
## highest strip or paving face between est - BELOW and est + ABOVE, else the drawn ground.
func top(p: Vector2, est: float) -> float:
	var blk := Vector2i(floori(p.x / BLOCK), floori(p.y / BLOCK))
	if not _blocks_done.has(blk):
		_blocks_done[blk] = true
		for k: int in _mesh_blocks.get(blk, PackedInt32Array()):
			if not _binned.has(k):
				_bin(k)
	var best := -INF
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	if _grid.has(key):
		var lo_y := est - BELOW
		var hi_y := est + ABOVE
		var f := _f
		for fi: int in _grid[key]:   # _face_y inlined (the life reads ~70 feet a frame)
			var o := fi * F_STRIDE
			if p.x < f[o] - 1e-3 or p.y < f[o + 1] - 1e-3 or p.x > f[o + 2] + 1e-3 or p.y > f[o + 3] + 1e-3:
				continue
			var dx := p.x - f[o + 4]
			var dz := p.y - f[o + 5]
			var u := (dx * f[o + 10] - f[o + 9] * dz) * f[o + 13]
			if u < -1e-4:
				continue
			var w := (f[o + 7] * dz - dx * f[o + 8]) * f[o + 13]
			if w < -1e-4 or u + w > 1.0 + 1e-4:
				continue
			var y := f[o + 6] + u * f[o + 11] + w * f[o + 12]
			if y > best and y <= hi_y and y >= lo_y:
				best = y
	var g := ground_at(p)
	return maxf(best, g) if best > -INF else g


## The height of face `fi` over `p`, or -INF when `p` is not under it.
func _face_y(fi: int, p: Vector2) -> float:
	var o := fi * F_STRIDE
	if p.x < _f[o] - 1e-3 or p.y < _f[o + 1] - 1e-3 or p.x > _f[o + 2] + 1e-3 or p.y > _f[o + 3] + 1e-3:
		return -INF
	var dx := p.x - _f[o + 4]
	var dz := p.y - _f[o + 5]
	var u := (dx * _f[o + 10] - _f[o + 9] * dz) * _f[o + 13]
	var w := (_f[o + 7] * dz - dx * _f[o + 8]) * _f[o + 13]
	if u < -1e-4 or w < -1e-4 or u + w > 1.0 + 1e-4:
		return -INF
	return _f[o + 6] + u * _f[o + 11] + w * _f[o + 12]
