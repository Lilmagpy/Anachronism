## Houses shaped by each civilisation's own way of building (D-275), built here from simple
## solids with their details modelled, not painted: posts, lattice windows and curling eaves
## in East Asia; mud brick with parapets, roof shelters and palms along the Nile; plastered
## cubes, domes and wind towers in the Near East; whitewash, crenellated parapets, roof
## pavilions and balconies in India; limewash, terracotta, porches and tall tenements around
## the Mediterranean; and landmarks to match (a pagoda, an obelisk).
##
## Walls and trim keep their own colours (vertex colours); roofs and awnings are marked (vertex
## alpha 0) to take the instance's colour, so a town's roofs can wear its owner's colour.
## Meshes are in grid cells (one cell = a house's width) and cached by style and variant.
extends RefCounted

const VARIANTS := {"east": 3, "nile": 3, "near_east": 3, "south_asian": 3, "classical": 3}

const PLASTER := Color(0.93, 0.90, 0.84)
const TIMBER := Color(0.30, 0.19, 0.12)
const DARK := Color(0.10, 0.08, 0.07)
const STONE := Color(0.58, 0.56, 0.52)
const LEAF := Color(0.34, 0.52, 0.24)

static var _cache := {}

var _st: SurfaceTool
var _centre := Vector3.ZERO   ## the middle of the solid being built: faces point away from it


## The mesh for one variant of a style's house (`cell` map units to one grid cell).
static func house(style: String, variant: int, cell: float) -> ArrayMesh:
	var key := "%s|%d|%s" % [style, variant, cell]
	if _cache.has(key):
		return _cache[key]
	var maker: RefCounted = (load("res://scripts/folk_houses.gd") as GDScript).new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	maker.set("_st", tool)
	match style:
		"east":
			maker.call("_east", variant)
		"nile":
			maker.call("_nile", variant)
		"near_east":
			maker.call("_near_east", variant)
		"south_asian":
			maker.call("_south_asian", variant)
		"classical":
			maker.call("_classical", variant)
		"pagoda":
			maker.call("_pagoda")
		"obelisk":
			maker.call("_obelisk")
	var mesh: ArrayMesh = tool.commit()
	var scaled := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.append_from(mesh, 0, Transform3D(Basis().scaled(Vector3.ONE * cell), Vector3.ZERO))
	st.commit(scaled)
	_cache[key] = scaled
	return scaled


# --- East Asia: plaster and timber under curling tiled eaves -------------------------------


func _east(variant: int) -> void:
	match variant:
		0:
			_box(Vector3(0, 0, 0), Vector3(1.1, 0.1, 0.85), STONE)
			_east_body(Vector3(0, 0.1, 0), 1.0, 0.75, 0.46)
			_hip(Vector3(0, 0.56, 0), 1.0, 0.75, 0.34, 0.16, 0.07, Color(0.38, 0.40, 0.44))
			_ridge(Vector3(0, 0.9, 0), 0.5)
		1:
			_box(Vector3(0, 0, 0), Vector3(1.15, 0.1, 0.9), STONE)
			_east_body(Vector3(0, 0.1, 0), 1.05, 0.8, 0.42)
			_hip(Vector3(0, 0.52, 0), 1.05, 0.8, 0.16, 0.14, 0.06, Color(0.38, 0.40, 0.44), 0.62)
			_east_body(Vector3(0, 0.66, 0), 0.7, 0.55, 0.3)
			_hip(Vector3(0, 0.96, 0), 0.7, 0.55, 0.28, 0.14, 0.07, Color(0.38, 0.40, 0.44))
			_ridge(Vector3(0, 1.24, 0), 0.3)
		_:
			# a long townhouse: dark timber below, plaster above, a lean-to over the shop front
			_box(Vector3(0, 0, 0), Vector3(1.4, 0.32, 0.7), Color(0.42, 0.28, 0.18))
			_box(Vector3(0, 0.32, 0), Vector3(1.4, 0.24, 0.7), PLASTER)
			for k in 7:
				_box(Vector3(-0.6 + k * 0.2, 0.06, 0.352), Vector3(0.03, 0.22, 0.01), DARK)   # slatted front
			_lean_to(Vector3(0, 0.32, 0.35), 1.4, 0.2, 0.08, Color(0.36, 0.38, 0.42))
			_gable(Vector3(0, 0.56, 0), 1.4, 0.7, 0.3, 0.1, Color(0.36, 0.38, 0.42))


func _east_body(at: Vector3, w: float, d: float, h: float) -> void:
	_box(at, Vector3(w, h, d), PLASTER)
	for x in [-w / 2.0, 0.0, w / 2.0]:   # timber posts at the corners and between
		for z in [-d / 2.0, d / 2.0]:
			_box(at + Vector3(x, 0, z), Vector3(0.06, h, 0.06), TIMBER)
	_box(at + Vector3(0, h - 0.05, 0), Vector3(w + 0.04, 0.05, d + 0.04), TIMBER)   # the beam under the eaves
	for x in [-w / 4.0, w / 4.0]:   # lattice windows
		_box(at + Vector3(x, h * 0.4, d / 2.0 + 0.005), Vector3(w * 0.28, h * 0.4, 0.01), Color(0.24, 0.16, 0.10))
		for k in 3:
			_box(at + Vector3(x - w * 0.09 + k * w * 0.09, h * 0.4, d / 2.0 + 0.012), Vector3(0.012, h * 0.4, 0.01), Color(0.70, 0.62, 0.48))


func _ridge(at: Vector3, length: float) -> void:
	_box(at, Vector3(length, 0.05, 0.06), Color(0.30, 0.31, 0.34))
	for s in [-1.0, 1.0]:   # the ridge ends curl up
		_box(at + Vector3(s * length / 2.0, 0.0, 0), Vector3(0.06, 0.11, 0.07), Color(0.30, 0.31, 0.34))


func _pagoda() -> void:
	_box(Vector3(0, 0, 0), Vector3(1.6, 0.14, 1.6), STONE)
	var y := 0.14
	for tier in 5:
		var w := 1.1 - tier * 0.14
		_box(Vector3(0, y, 0), Vector3(w, 0.32, w), Color(0.70, 0.22, 0.15) if tier == 0 else PLASTER)
		for x in [-w / 2.0, w / 2.0]:
			for z in [-w / 2.0, w / 2.0]:
				_box(Vector3(x, y, z), Vector3(0.06, 0.32, 0.06), Color(0.62, 0.16, 0.10))
		_hip(Vector3(0, y + 0.32, 0), w, w, 0.14, 0.2, 0.08, Color(0.36, 0.38, 0.42), 0.55)
		y += 0.44
	_cyl(Vector3(0, y, 0), 0.04, 0.6, Color(0.80, 0.62, 0.24))   # the spire
	for k in 4:
		_cyl(Vector3(0, y + 0.1 + k * 0.1, 0), 0.08, 0.03, Color(0.80, 0.62, 0.24))


# --- the Nile: mud brick, parapets, a shelter on the roof, palms -----------------------------


func _nile(variant: int) -> void:
	var brick := Color(0.74, 0.56, 0.36)
	match variant:
		0:
			_brick_block(Vector3(0, 0, 0), 0.95, 0.75, 0.55, brick)
			_shelter(Vector3(0.22, 0.55, -0.15))
		1:
			_brick_block(Vector3(0, 0, 0), 1.05, 0.85, 0.45, brick)
			_brick_block(Vector3(-0.2, 0.45, -0.12), 0.55, 0.55, 0.38, brick.lightened(0.05))
			_stair(Vector3(0.38, 0, 0.0), 0.45, brick.darkened(0.1))
		_:
			_brick_block(Vector3(0, 0, -0.12), 0.9, 0.6, 0.5, brick)
			for s in [-1.0, 1.0]:   # a walled yard in front
				_box(Vector3(s * 0.45, 0, 0.32), Vector3(0.05, 0.22, 0.32), brick.darkened(0.08))
			_box(Vector3(0.2, 0, 0.48), Vector3(0.5, 0.22, 0.05), brick.darkened(0.08))
			_palm(Vector3(-0.25, 0, 0.32), 0.95)


func _brick_block(at: Vector3, w: float, d: float, h: float, brick: Color) -> void:
	_box(at, Vector3(w, h, d), brick)
	_box(at + Vector3(0, h, 0), Vector3(w - 0.06, 0.02, d - 0.06), brick.darkened(0.25), true)   # the roof terrace
	for side in [[0, d / 2.0, w, 0.04], [0, -d / 2.0, w, 0.04], [w / 2.0, 0, 0.04, d], [-w / 2.0, 0, 0.04, d]]:
		_box(at + Vector3(side[0], h, side[1]), Vector3(side[2], 0.07, side[3]), brick.lightened(0.06))   # parapet
	_box(at + Vector3(0.1, 0, d / 2.0 + 0.005), Vector3(0.14, h * 0.5, 0.01), DARK)   # door
	for x in [-w * 0.3, w * 0.3]:
		_box(at + Vector3(x, h * 0.66, d / 2.0 + 0.005), Vector3(0.09, 0.06, 0.01), DARK)   # small high windows


func _shelter(at: Vector3) -> void:
	for x in [-0.14, 0.14]:
		for z in [-0.1, 0.1]:
			_box(at + Vector3(x, 0, z), Vector3(0.03, 0.2, 0.03), TIMBER)
	_box(at + Vector3(0, 0.2, 0), Vector3(0.36, 0.03, 0.28), Color(0.62, 0.50, 0.28), true)   # palm thatch


func _stair(at: Vector3, h: float, colour: Color) -> void:
	for k in 5:
		_box(at + Vector3(0, 0, -0.3 + k * 0.08), Vector3(0.14, h * (5 - k) / 5.0, 0.08), colour)


func _palm(at: Vector3, h: float) -> void:
	_cyl(at, 0.035, h, Color(0.46, 0.34, 0.22))
	for k in 6:
		_centre = at + Vector3(0, h - 0.6, 0)
		var a := k * TAU / 6.0
		var tip := at + Vector3(cos(a) * 0.32, h - 0.12, sin(a) * 0.32)
		_tri(at + Vector3(0, h + 0.04, 0), tip + Vector3(-sin(a) * 0.06, 0, cos(a) * 0.06),
			tip + Vector3(sin(a) * 0.06, 0, -cos(a) * 0.06), LEAF)
		_tri(at + Vector3(0, h + 0.04, 0), tip + Vector3(sin(a) * 0.06, 0, -cos(a) * 0.06),
			tip + Vector3(-sin(a) * 0.06, 0, cos(a) * 0.06), LEAF)


func _obelisk() -> void:
	var granite := Color(0.74, 0.52, 0.42)
	_box(Vector3(0, 0, 0), Vector3(0.5, 0.12, 0.5), STONE)
	_frustum(Vector3(0, 0.12, 0), 0.22, 0.14, 2.6, granite)
	_frustum(Vector3(0, 2.72, 0), 0.14, 0.0, 0.22, Color(0.92, 0.76, 0.32))   # gilded tip


# --- the Near East: plaster cubes, domes and wind towers ------------------------------------


func _near_east(variant: int) -> void:
	var wall := Color(0.96, 0.92, 0.82)
	match variant:
		0:
			_brick_block(Vector3(0, 0, 0), 1.0, 0.8, 0.6, wall)
			_box(Vector3(0.1, 0, 0.405), Vector3(0.16, 0.3, 0.01), Color(0.22, 0.38, 0.58))   # a blue door
		1:
			_brick_block(Vector3(0, 0, 0), 0.95, 0.85, 0.55, wall)
			_cyl(Vector3(0, 0.55, 0), 0.26, 0.08, wall.darkened(0.06))   # the drum
			_dome(Vector3(0, 0.63, 0), 0.26, Color(0.80, 0.74, 0.62), true)
		_:
			_brick_block(Vector3(0, 0, 0), 1.0, 0.8, 0.5, wall)
			_box(Vector3(-0.3, 0.5, -0.22), Vector3(0.2, 0.5, 0.2), wall.lightened(0.04))   # the wind tower
			for s in [-1.0, 1.0]:
				_box(Vector3(-0.3, 0.82, -0.22 + s * 0.101), Vector3(0.14, 0.12, 0.01), DARK)
				_box(Vector3(-0.3 + s * 0.101, 0.82, -0.22), Vector3(0.01, 0.12, 0.14), DARK)
			_box(Vector3(-0.3, 1.0, -0.22), Vector3(0.24, 0.03, 0.24), wall.darkened(0.2), true)


# --- India: whitewash and brick, parapets, roof pavilions, balconies -------------------------


func _south_asian(variant: int) -> void:
	var white := Color(0.95, 0.92, 0.85)
	var brick := Color(0.78, 0.47, 0.33)
	match variant:
		0:
			_merloned(Vector3(0, 0, 0), 1.0, 0.8, 0.58, white)
		1:
			_merloned(Vector3(0, 0, 0), 1.0, 0.85, 0.55, white)
			_chhatri(Vector3(0.18, 0.55, -0.12), 0.18)
		_:
			_merloned(Vector3(0, 0, 0), 0.95, 0.75, 0.75, brick)
			_box(Vector3(0, 0.38, 0.42), Vector3(0.36, 0.2, 0.1), Color(0.86, 0.66, 0.40))   # the balcony
			_box(Vector3(0, 0.42, 0.47), Vector3(0.28, 0.12, 0.01), DARK)
			_dome(Vector3(0, 0.58, 0.42), 0.16, Color(0.86, 0.66, 0.40), true, 0.5)


func _merloned(at: Vector3, w: float, d: float, h: float, wall: Color) -> void:
	_box(at, Vector3(w, h, d), wall)
	_box(at + Vector3(0, h - 0.08, 0), Vector3(w + 0.02, 0.05, d + 0.02), Color(0.80, 0.58, 0.24))   # an ochre band
	_box(at + Vector3(0, h, 0), Vector3(w - 0.06, 0.02, d - 0.06), wall.darkened(0.2), true)
	var n := 5
	for k in n:   # merlons along the parapet
		var x := -w / 2.0 + (k + 0.5) * w / n
		for z in [-d / 2.0 + 0.03, d / 2.0 - 0.03]:
			_box(at + Vector3(x, h, z), Vector3(w / n * 0.55, 0.09, 0.05), wall)
	_box(at + Vector3(0, 0, d / 2.0 + 0.005), Vector3(0.2, h * 0.5, 0.01), Color(0.62, 0.14, 0.10))   # a red door frame
	_box(at + Vector3(0, 0, d / 2.0 + 0.012), Vector3(0.13, h * 0.44, 0.01), DARK)
	for x in [-w * 0.32, w * 0.32]:
		_box(at + Vector3(x, h * 0.45, d / 2.0 + 0.005), Vector3(0.1, 0.14, 0.01), DARK)


func _chhatri(at: Vector3, r: float) -> void:
	for x in [-r, r]:
		for z in [-r, r]:
			_box(at + Vector3(x, 0, z), Vector3(0.03, 0.2, 0.03), Color(0.86, 0.66, 0.40))
	_box(at + Vector3(0, 0.2, 0), Vector3(r * 2.4, 0.03, r * 2.4), Color(0.86, 0.66, 0.40))
	_dome(at + Vector3(0, 0.23, 0), r, Color(0.95, 0.92, 0.85), true)


# --- the Mediterranean: limewash, terracotta, porches, tenements -----------------------------


func _classical(variant: int) -> void:
	var lime := Color(0.95, 0.92, 0.85)
	var tile := Color(0.82, 0.46, 0.32)
	match variant:
		0:
			# a town house round its atrium, with a columned porch
			_box(Vector3(0, 0, 0), Vector3(1.0, 0.08, 0.8), Color(0.72, 0.30, 0.22))   # red plinth
			_box(Vector3(0, 0.08, 0), Vector3(1.0, 0.4, 0.8), lime)
			_hip(Vector3(0, 0.48, 0), 1.0, 0.8, 0.22, 0.08, 0.0, tile)
			_box(Vector3(0, 0.6, 0), Vector3(0.22, 0.1, 0.18), DARK)   # the opening over the atrium
			for x in [-0.14, 0.14]:
				_cyl(Vector3(x, 0.08, 0.5), 0.03, 0.36, lime)
			_box(Vector3(0, 0.44, 0.47), Vector3(0.4, 0.04, 0.12), lime)
			_gable(Vector3(0, 0.48, 0.47), 0.12, 0.42, 0.1, 0.02, tile, true)
			_box(Vector3(0, 0.08, 0.405), Vector3(0.14, 0.24, 0.01), DARK)
		1:
			# a tenement: shops below, two floors of windows, a wooden balcony
			_box(Vector3(0, 0, 0), Vector3(1.0, 1.05, 0.8), Color(0.90, 0.80, 0.66))
			for k in 3:
				_box(Vector3(-0.32 + k * 0.32, 0, 0.405), Vector3(0.2, 0.24, 0.01), DARK)   # shop arches
			for floor in 2:
				for k in 4:
					_box(Vector3(-0.36 + k * 0.24, 0.42 + floor * 0.3, 0.405), Vector3(0.1, 0.13, 0.01), DARK)
			_box(Vector3(0, 0.36, 0.45), Vector3(0.9, 0.03, 0.1), TIMBER)   # the balcony
			_box(Vector3(0, 0.39, 0.495), Vector3(0.9, 0.08, 0.01), TIMBER)
			_hip(Vector3(0, 1.05, 0), 1.0, 0.8, 0.18, 0.06, 0.0, tile)
		_:
			# a small house with a vine pergola
			_box(Vector3(-0.15, 0, 0), Vector3(0.7, 0.42, 0.7), lime)
			_gable(Vector3(-0.15, 0.42, 0), 0.7, 0.7, 0.2, 0.06, tile)
			for x in [0.25, 0.48]:
				for z in [-0.28, 0.28]:
					_box(Vector3(x, 0, z), Vector3(0.03, 0.34, 0.03), TIMBER)
			_box(Vector3(0.37, 0.34, 0), Vector3(0.32, 0.04, 0.66), LEAF)
			_box(Vector3(-0.15, 0, 0.355), Vector3(0.12, 0.24, 0.01), DARK)


# --- solids ---------------------------------------------------------------------------------


func _vertex(p: Vector3, n: Vector3, c: Color) -> void:
	_st.set_normal(n)
	_st.set_color(c)
	_st.add_vertex(p)


func _tri(a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length() < 0.000001:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - _centre) < 0.0:   # face away from the solid's middle
		n = -n
		var t := b
		b = c
		c = t
	# Godot's front faces wind clockwise seen from outside
	_vertex(a, n, colour)
	_vertex(c, n, colour)
	_vertex(b, n, colour)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	_tri(a, b, c, colour)
	_tri(a, c, d, colour)


## A box standing on `foot` (the centre of its base); `roof` marks it to take the owner colour.
func _box(foot: Vector3, size: Vector3, colour: Color, roof := false) -> void:
	var c := Color(colour, 0.0 if roof else 1.0)
	var h := size / 2.0
	var o := foot + Vector3(0, h.y, 0)
	_centre = o
	var p := [o + Vector3(-h.x, -h.y, -h.z), o + Vector3(h.x, -h.y, -h.z), o + Vector3(h.x, h.y, -h.z), o + Vector3(-h.x, h.y, -h.z),
		o + Vector3(-h.x, -h.y, h.z), o + Vector3(h.x, -h.y, h.z), o + Vector3(h.x, h.y, h.z), o + Vector3(-h.x, h.y, h.z)]
	_quad(p[4], p[5], p[6], p[7], c)   # +z
	_quad(p[1], p[0], p[3], p[2], c)   # -z
	_quad(p[5], p[1], p[2], p[6], c)   # +x
	_quad(p[0], p[4], p[7], p[3], c)   # -x
	_quad(p[7], p[6], p[2], p[3], c)   # top


## A hipped roof over a w x d body: eaves standing out by `over`, the corners turned up by
## `curl`; `top` < 1 cuts it flat at that share of its height (a skirt roof between storeys).
func _hip(base: Vector3, w: float, d: float, h: float, over: float, curl: float, colour: Color, top := 1.0) -> void:
	var c := Color(colour, 0.0)
	_centre = base + Vector3(0, -0.05, 0)
	var hw := w / 2.0 + over
	var hd := d / 2.0 + over
	var ridge := maxf(0.0, (w - d) / 2.0)
	var corners := [Vector3(-hw, curl, -hd), Vector3(hw, curl, -hd), Vector3(hw, curl, hd), Vector3(-hw, curl, hd)]
	var mids := [Vector3(0, 0, -hd), Vector3(hw, 0, 0), Vector3(0, 0, hd), Vector3(-hw, 0, 0)]
	var peak := [Vector3(-ridge, h, 0), Vector3(ridge, h, 0)]
	if top < 1.0:
		var k := top
		var inner := []
		for corner in corners:
			inner.append(Vector3(corner.x * (1.0 - k) * 0.9, h * k, corner.z * (1.0 - k) * 0.9))
		for i in 4:
			var j := (i + 1) % 4
			_quad(base + corners[i], base + corners[j], base + inner[j], base + inner[i], c)
		_quad(base + inner[3], base + inner[2], base + inner[1], base + inner[0], c)
		return
	# each side: corner, middle of the eave, corner, up to the ridge
	var top_of := [[peak[0], peak[1]], [peak[1], peak[1]], [peak[1], peak[0]], [peak[0], peak[0]]]
	for i in 4:
		var j := (i + 1) % 4
		var a: Vector3 = base + corners[i]
		var m: Vector3 = base + mids[i]
		var b: Vector3 = base + corners[j]
		var ta: Vector3 = base + top_of[i][0]
		var tb: Vector3 = base + top_of[i][1]
		_tri(a, m, ta, c)
		_tri(m, b, tb, c)
		if ta != tb:
			_tri(m, tb, ta, c)
	# the underside of the eaves, darker
	_centre = base + Vector3(0, h, 0)
	var under := Color(colour.darkened(0.45), 0.0)
	_quad(base + corners[3], base + corners[2], base + corners[1], base + corners[0], under)


## A gabled roof along x (or z, `across`): two slopes and the end walls' triangles.
func _gable(base: Vector3, w: float, d: float, h: float, over: float, colour: Color, across := false) -> void:
	var c := Color(colour, 0.0)
	_centre = base + Vector3(0, h * 0.3, 0)
	var hw := w / 2.0 + over
	var hd := d / 2.0 + over
	if across:
		var a := [base + Vector3(-hw, 0, -hd), base + Vector3(hw, 0, -hd), base + Vector3(hw, 0, hd), base + Vector3(-hw, 0, hd)]
		var r0 := base + Vector3(0, h, -hd)
		var r1 := base + Vector3(0, h, hd)
		_quad(a[3], r1, r0, a[0], c)
		_quad(a[1], r0, r1, a[2], c)
		_tri(a[2], r1, a[3], Color(PLASTER, 1.0))
		_tri(a[0], r0, a[1], Color(PLASTER, 1.0))
		return
	var p := [base + Vector3(-hw, 0, -hd), base + Vector3(hw, 0, -hd), base + Vector3(hw, 0, hd), base + Vector3(-hw, 0, hd)]
	var q0 := base + Vector3(-hw, h, 0)
	var q1 := base + Vector3(hw, h, 0)
	_quad(p[3], p[2], q1, q0, c)
	_quad(p[1], p[0], q0, q1, c)
	var wall := Color(PLASTER, 1.0)
	_tri(base + Vector3(-w / 2.0, 0, -d / 2.0), base + Vector3(-w / 2.0, 0, d / 2.0), base + Vector3(-w / 2.0, h * (1.0 - over), 0), wall)
	_tri(base + Vector3(w / 2.0, 0, d / 2.0), base + Vector3(w / 2.0, 0, -d / 2.0), base + Vector3(w / 2.0, h * (1.0 - over), 0), wall)


## A roof sloping down from a wall (an awning over a shop front).
func _lean_to(base: Vector3, w: float, out: float, drop: float, colour: Color) -> void:
	var c := Color(colour, 0.0)
	_centre = base + Vector3(0, -1.0, 0)
	_quad(base + Vector3(-w / 2.0, 0, 0), base + Vector3(-w / 2.0, -drop, out),
		base + Vector3(w / 2.0, -drop, out), base + Vector3(w / 2.0, 0, 0), c)


func _cyl(foot: Vector3, r: float, h: float, colour: Color, sides := 8) -> void:
	_frustum(foot, r, r, h, colour, sides)


func _frustum(foot: Vector3, r0: float, r1: float, h: float, colour: Color, sides := 8) -> void:
	_centre = foot + Vector3(0, h * 0.4, 0)
	for k in sides:
		var a0 := k * TAU / sides
		var a1 := (k + 1) * TAU / sides
		var b0 := foot + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var b1 := foot + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var t0 := foot + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var t1 := foot + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		if r1 > 0.0:
			_quad(b1, b0, t0, t1, colour)
			_tri(foot + Vector3(0, h, 0), t1, t0, colour)
		else:
			_tri(b1, b0, t0, colour)


func _dome(foot: Vector3, r: float, colour: Color, roof := false, squash := 1.0) -> void:
	var c := Color(colour, 0.0 if roof else 1.0)
	_centre = foot
	var rings := 4
	var sides := 10
	for i in rings:
		var p0 := i * PI / 2.0 / rings
		var p1 := (i + 1) * PI / 2.0 / rings
		for k in sides:
			var a0 := k * TAU / sides
			var a1 := (k + 1) * TAU / sides
			var v00 := foot + Vector3(cos(a0) * cos(p0) * r, sin(p0) * r * squash, sin(a0) * cos(p0) * r)
			var v01 := foot + Vector3(cos(a1) * cos(p0) * r, sin(p0) * r * squash, sin(a1) * cos(p0) * r)
			var v10 := foot + Vector3(cos(a0) * cos(p1) * r, sin(p1) * r * squash, sin(a0) * cos(p1) * r)
			var v11 := foot + Vector3(cos(a1) * cos(p1) * r, sin(p1) * r * squash, sin(a1) * cos(p1) * r)
			_quad(v01, v00, v10, v11, c)
