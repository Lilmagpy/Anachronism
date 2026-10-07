## The model kit (D-280): a small modelling library for building detailed buildings in code.
##
## A model is built in its own units (1 unit = the width of an ordinary house) standing on
## y = 0, then `finish()` gives an ArrayMesh for a MultiMesh or MeshInstance3D. Every face
## carries a MATERIAL (vertex alpha = id / 16) and a base colour (vertex rgb); the shared
## shader `shaders/models.gdshader` paints each material's surface pattern (roof tiles,
## stone courses, brick, plaster, timber grain, thatch...) in model space, and colours the
## OWNER materials with the instance's custom colour (its owner's colour).
##
## Use: var k := Kit.new(); k.box(...); k.gable_roof(...); return k.finish()
## Placement: `push(transform)` / `pop()` nest a local frame (e.g. turn a wing, lift a storey).
## Faces are flat-shaded and face outward automatically (each primitive knows its centre).
extends RefCounted

# --- materials (vertex alpha = id / 16) -----------------------------------------------------
const OWNER_ROOF := 0   ## roof tiles in the owner's colour (instance custom data)
const PLASTER := 1      ## limewash / plaster walls: soft mottling
const STONE := 2        ## dressed stone: courses and joints
const BRICK := 3        ## fired brick: running bond
const MUDBRICK := 4     ## sun-dried brick: large soft blocks, rendered
const TIMBER := 5       ## wood: grain along the longest axis
const TILE := 6         ## clay / slate roof tiles in their own colour: rows of tiles
const THATCH := 7       ## straw / reed / palm thatch: streaky
const DARK := 8         ## openings: doors, windows, deep shade (no pattern)
const GOLD := 9         ## gilding and bronze: bright, slight shine
const CLOTH := 10       ## felt, awnings, curtains: soft weave
const OWNER_CLOTH := 11 ## banners and awnings in the owner's colour
const PAINT := 12       ## smooth painted surface (columns, lacquer): no pattern
const EARTH := 13       ## rammed earth / packed ground: horizontal layers
const LEAF := 14        ## foliage: dappled
const WATER := 15       ## water in a basin or channel

var _st := SurfaceTool.new()
var _frames: Array[Transform3D] = [Transform3D.IDENTITY]
var _tris := 0


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


## The model as an ArrayMesh (and how many triangles it has, in `triangles()`).
func finish() -> ArrayMesh:
	return _st.commit()


func triangles() -> int:
	return _tris


## Enter a local frame (relative to the current one) until `pop()`.
func push(local: Transform3D) -> void:
	_frames.append(_frames[-1] * local)


func pop() -> void:
	if _frames.size() > 1:
		_frames.pop_back()


## A frame turned `yaw` radians about the vertical and moved to `at`.
static func at(at_pos: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at_pos)


# --- raw faces --------------------------------------------------------------------------------


## One triangle; `outward` is a point inside the solid (the face turns away from it).
func tri(a: Vector3, b: Vector3, c: Vector3, colour: Color, material: int, inside := Vector3.INF) -> void:
	var f := _frames[-1]
	var wa := f * a
	var wb := f * b
	var wc := f * c
	var n := (wb - wa).cross(wc - wa)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if inside != Vector3.INF:
		var centre := f * inside
		if n.dot((wa + wb + wc) / 3.0 - centre) < 0.0:
			n = -n
			var t := wb
			wb = wc
			wc = t
	var col := Color(colour.r, colour.g, colour.b, (material + 0.5) / 16.0)
	# Godot's front faces wind clockwise seen from outside
	for p in [wa, wc, wb]:
		_st.set_normal(n)
		_st.set_color(col)
		_st.add_vertex(p)
	_tris += 1


## A quad a-b-c-d (in order round its edge).
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color, material: int, inside := Vector3.INF) -> void:
	tri(a, b, c, colour, material, inside)
	tri(a, c, d, colour, material, inside)


## A flat polygon (convex, points in order), facing away from `inside`.
func polygon(points: Array, colour: Color, material: int, inside := Vector3.INF) -> void:
	for i in range(1, points.size() - 1):
		tri(points[0], points[i], points[i + 1], colour, material, inside)


# --- solids -----------------------------------------------------------------------------------


## A box standing on `foot` (the middle of its base), `size` = (width x, height y, depth z),
## turned `yaw`. `bottom` false leaves out the base (saves triangles when it sits on something).
func box(foot: Vector3, size: Vector3, colour: Color, material: int, yaw := 0.0, bottom := false) -> void:
	push(at(foot, yaw))
	var h := size / 2.0
	var c := Vector3(0, h.y, 0)
	var p := [Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, size.y, -h.z), Vector3(-h.x, size.y, -h.z),
		Vector3(-h.x, 0, h.z), Vector3(h.x, 0, h.z), Vector3(h.x, size.y, h.z), Vector3(-h.x, size.y, h.z)]
	quad(p[4], p[5], p[6], p[7], colour, material, c)
	quad(p[0], p[1], p[2], p[3], colour, material, c)
	quad(p[1], p[5], p[6], p[2], colour, material, c)
	quad(p[0], p[4], p[7], p[3], colour, material, c)
	quad(p[3], p[2], p[6], p[7], colour, material, c)
	if bottom:
		quad(p[0], p[1], p[5], p[4], colour, material, c)
	pop()


## A box with its top edges chamfered by `bevel` (softer, less blocky silhouettes).
func bevel_box(foot: Vector3, size: Vector3, bevel: float, colour: Color, material: int, yaw := 0.0) -> void:
	var b := minf(bevel, minf(size.x, minf(size.y, size.z)) * 0.45)
	push(at(foot, yaw))
	var h := size / 2.0
	var c := Vector3(0, h.y, 0)
	var y1 := size.y - b
	var lo := [Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, 0, h.z), Vector3(-h.x, 0, h.z)]
	var mid := [Vector3(-h.x, y1, -h.z), Vector3(h.x, y1, -h.z), Vector3(h.x, y1, h.z), Vector3(-h.x, y1, h.z)]
	var top := [Vector3(-h.x + b, size.y, -h.z + b), Vector3(h.x - b, size.y, -h.z + b),
		Vector3(h.x - b, size.y, h.z - b), Vector3(-h.x + b, size.y, h.z - b)]
	for i in 4:
		var j := (i + 1) % 4
		quad(lo[i], lo[j], mid[j], mid[i], colour, material, c)
		quad(mid[i], mid[j], top[j], top[i], colour, material, c)
	quad(top[0], top[1], top[2], top[3], colour, material, c)
	pop()


## An upright cylinder or cone frustum on `foot`: radius r0 at the base, r1 at the top.
func frustum(foot: Vector3, r0: float, r1: float, height: float, colour: Color, material: int, sides := 10, cap := true) -> void:
	push(at(foot))
	var c := Vector3(0, height * 0.5, 0)
	for k in sides:
		var a0 := k * TAU / sides
		var a1 := (k + 1) * TAU / sides
		var b0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var t0 := Vector3(cos(a0) * r1, height, sin(a0) * r1)
		var t1 := Vector3(cos(a1) * r1, height, sin(a1) * r1)
		if r1 > 0.0001:
			quad(b0, b1, t1, t0, colour, material, c)
			if cap:
				tri(Vector3(0, height, 0), t0, t1, colour, material, Vector3(0, height * 0.5, 0))
		else:
			tri(b0, b1, t0, colour, material, c)
	pop()


func cylinder(foot: Vector3, r: float, height: float, colour: Color, material: int, sides := 10) -> void:
	frustum(foot, r, r, height, colour, material, sides)


## A column: base, fluted-looking shaft (many sides) and capital.
func column(foot: Vector3, r: float, height: float, colour: Color, material := PAINT) -> void:
	box(foot, Vector3(r * 2.6, height * 0.06, r * 2.6), colour, material)
	frustum(foot + Vector3(0, height * 0.06, 0), r, r * 0.86, height * 0.86, colour, material, 12, false)
	box(foot + Vector3(0, height * 0.92, 0), Vector3(r * 2.5, height * 0.08, r * 2.5), colour, material)


## A dome (a half sphere, squashed by `squash`) sitting on `foot`.
func dome(foot: Vector3, r: float, colour: Color, material: int, squash := 1.0, rings := 5, sides := 14, onion := false) -> void:
	push(at(foot))
	var c := Vector3(0, r * squash * 0.3, 0)
	for i in rings:
		var p0 := i * PI / 2.0 / rings
		var p1 := (i + 1) * PI / 2.0 / rings
		var w0 := cos(p0)
		var w1 := cos(p1)
		if onion:   # bulging out above the drum, then drawn up to a point
			w0 *= 1.0 + 0.35 * sin(p0 * 2.0)
			w1 *= 1.0 + 0.35 * sin(p1 * 2.0)
		for k in sides:
			var a0 := k * TAU / sides
			var a1 := (k + 1) * TAU / sides
			var v00 := Vector3(cos(a0) * w0 * r, sin(p0) * r * squash, sin(a0) * w0 * r)
			var v01 := Vector3(cos(a1) * w0 * r, sin(p0) * r * squash, sin(a1) * w0 * r)
			var v10 := Vector3(cos(a0) * w1 * r, sin(p1) * r * squash, sin(a0) * w1 * r)
			var v11 := Vector3(cos(a1) * w1 * r, sin(p1) * r * squash, sin(a1) * w1 * r)
			if i == rings - 1:
				tri(v00, v01, v10, colour, material, c)
			else:
				quad(v00, v01, v11, v10, colour, material, c)
	pop()


## A wedge: a triangular prism along x (a gable end, a buttress), the ridge at height h.
func wedge(foot: Vector3, length: float, depth: float, h: float, colour: Color, material: int, yaw := 0.0) -> void:
	push(at(foot, yaw))
	var c := Vector3(0, h * 0.3, 0)
	var l := length / 2.0
	var d := depth / 2.0
	quad(Vector3(-l, 0, -d), Vector3(l, 0, -d), Vector3(l, h, 0), Vector3(-l, h, 0), colour, material, c)
	quad(Vector3(-l, 0, d), Vector3(l, 0, d), Vector3(l, h, 0), Vector3(-l, h, 0), colour, material, c)
	tri(Vector3(-l, 0, -d), Vector3(-l, 0, d), Vector3(-l, h, 0), colour, material, c)
	tri(Vector3(l, 0, -d), Vector3(l, 0, d), Vector3(l, h, 0), colour, material, c)
	pop()


# --- roofs ------------------------------------------------------------------------------------
# Roofs are slabs with real thickness and overhanging eaves, so they cast a shadow line and
# read as roofs, not as prisms. `curl` lifts the corners/eaves (East Asian roofs).


## A gabled roof over a w (x) by d (z) body: ridge along x at height `rise` above `foot`,
## eaves standing out by `over`, slab `thick`. The gable ends are closed with `wall` colour
## (pass material -1 to leave them open, e.g. when a hip covers them).
func gable_roof(foot: Vector3, w: float, d: float, rise: float, over: float, thick: float, colour: Color,
		material := OWNER_ROOF, wall := Color.WHITE, wall_material := PLASTER, yaw := 0.0, curl := 0.0) -> void:
	push(at(foot, yaw))
	var hw := w / 2.0 + over
	var hd := d / 2.0 + over
	var drop := over * rise / maxf(d / 2.0, 0.001)   # the eaves continue the slope down past the wall
	var inner := Vector3(0, -1.0, 0)
	for s in [-1.0, 1.0]:
		var e0 := Vector3(-hw, -drop + curl, s * hd)
		var e1 := Vector3(hw, -drop + curl, s * hd)
		var r0 := Vector3(-hw, rise, 0)
		var r1 := Vector3(hw, rise, 0)
		var up := Vector3(0, thick, 0)
		quad(e0 + up, e1 + up, r1 + up, r0 + up, colour, material, inner)         # top
		quad(e0, e1, r1, r0, colour.darkened(0.35), material, Vector3(0, 10, 0))   # underside
		quad(e0, e1, e1 + up, e0 + up, colour.darkened(0.2), material, Vector3(0, rise, 0))   # eave edge
		for x in [-hw, hw]:   # verge edges
			quad(Vector3(x, -drop + curl, s * hd), Vector3(x, rise, 0), Vector3(x, rise + thick, 0),
				Vector3(x, -drop + curl + thick, s * hd), colour.darkened(0.2), material, Vector3(0, rise * 0.4, 0))
	if wall_material >= 0:
		for x in [-w / 2.0, w / 2.0]:
			tri(Vector3(x, 0, -d / 2.0), Vector3(x, 0, d / 2.0), Vector3(x, rise - thick, 0), wall, wall_material,
				Vector3(0, rise * 0.3, 0))
	# the ridge piece
	box(Vector3(0, rise + thick * 0.6, 0), Vector3(w + over * 2.0 + thick, thick * 1.2, thick * 1.6), colour.darkened(0.15), material)
	pop()


## A hipped roof (slopes on all four sides) over a w by d body; corners lifted by `curl`.
func hip_roof(foot: Vector3, w: float, d: float, rise: float, over: float, thick: float, colour: Color,
		material := OWNER_ROOF, yaw := 0.0, curl := 0.0) -> void:
	push(at(foot, yaw))
	var hw := w / 2.0 + over
	var hd := d / 2.0 + over
	var ridge := maxf(0.0, (w - d) / 2.0)
	var e := [Vector3(-hw, curl, -hd), Vector3(hw, curl, -hd), Vector3(hw, curl, hd), Vector3(-hw, curl, hd)]
	var mids := [Vector3(0, 0, -hd), Vector3(hw, 0, 0), Vector3(0, 0, hd), Vector3(-hw, 0, 0)]
	var r0 := Vector3(-ridge, rise, 0)
	var r1 := Vector3(ridge, rise, 0)
	var tops := [[r0, r1], [r1, r1], [r1, r0], [r0, r0]]
	var up := Vector3(0, thick, 0)
	var inner := Vector3(0, -1.0, 0)
	for i in 4:
		var j := (i + 1) % 4
		var a: Vector3 = e[i]
		var m: Vector3 = mids[i]
		var b: Vector3 = e[j]
		var ta: Vector3 = tops[i][0]
		var tb: Vector3 = tops[i][1]
		tri(a + up, m + up, ta + up, colour, material, inner)
		tri(m + up, b + up, tb + up, colour, material, inner)
		if ta != tb:
			tri(m + up, tb + up, ta + up, colour, material, inner)
		quad(a, b, b + up, a + up, colour.darkened(0.2), material, Vector3(0, rise, 0))   # eave edge
		tri(a, m, ta, colour.darkened(0.35), material, Vector3(0, 10, 0))   # underside
		tri(m, b, tb, colour.darkened(0.35), material, Vector3(0, 10, 0))
	for i in 4:   # hip ridges: a raised roll along each hip
		var corner: Vector3 = e[i] + up
		var top: Vector3 = (r0 if i in [0, 3] else r1) + up
		_roll(corner, top, thick * 0.7, colour.darkened(0.12), material)
	if ridge > 0.0:
		_roll(r0 + up, r1 + up, thick * 0.8, colour.darkened(0.12), material)
	pop()


## A thin square rod from a to b (ridge rolls, rafters, poles, railings).
func rod(a: Vector3, b: Vector3, r: float, colour: Color, material: int) -> void:
	_roll(a, b, r, colour, material)


func _roll(a: Vector3, b: Vector3, r: float, colour: Color, material: int) -> void:
	var d := b - a
	if d.length() < 1e-5:
		return
	var axis := d.normalized()
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.01:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized() * r
	var up := side.cross(axis).normalized() * r
	var c := (a + b) / 2.0
	var ring := [side + up, -side + up, -side - up, side - up]
	for i in 4:
		var j := (i + 1) % 4
		quad(a + ring[i], b + ring[i], b + ring[j], a + ring[j], colour, material, c)


## A flat-topped pyramid (a stepped base, a plinth, a ziggurat stage): w x d at the foot,
## shrinking by `inset` on each side over `height`.
func plinth(foot: Vector3, w: float, d: float, height: float, inset: float, colour: Color, material: int, yaw := 0.0) -> void:
	push(at(foot, yaw))
	var a := [Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0, -d / 2), Vector3(w / 2, 0, d / 2), Vector3(-w / 2, 0, d / 2)]
	var b := [Vector3(-w / 2 + inset, height, -d / 2 + inset), Vector3(w / 2 - inset, height, -d / 2 + inset),
		Vector3(w / 2 - inset, height, d / 2 - inset), Vector3(-w / 2 + inset, height, d / 2 - inset)]
	var c := Vector3(0, height * 0.4, 0)
	for i in 4:
		var j := (i + 1) % 4
		quad(a[i], a[j], b[j], b[i], colour, material, c)
	quad(b[0], b[1], b[2], b[3], colour, material, c)
	pop()


# --- details ----------------------------------------------------------------------------------
# Openings are shallow recesses with a frame, set into a wall face. `face` is the wall's
# outward normal direction as a yaw (0 = +z, PI/2 = +x), `at_pos` the middle of the opening
# on the wall surface.


## A window: dark recess, frame (sill, lintel, jambs), optional shutters or lattice bars.
func window(at_pos: Vector3, yaw: float, w: float, h: float, frame: Color, style := "frame") -> void:
	push(at(at_pos, yaw))
	var f := w * 0.14
	box(Vector3(0, -h / 2, 0.0), Vector3(w, h, 0.012), Color(0.07, 0.05, 0.04), DARK)
	box(Vector3(0, -h / 2 - f, 0.01), Vector3(w + f * 2.4, f, f * 1.6), frame, TIMBER if style != "stone" else STONE)   # sill
	box(Vector3(0, h / 2, 0.01), Vector3(w + f * 2.0, f, f * 1.2), frame, TIMBER if style != "stone" else STONE)        # lintel
	for s in [-1.0, 1.0]:
		box(Vector3(s * (w / 2 + f / 2), -h / 2, 0.01), Vector3(f, h, f), frame, TIMBER if style != "stone" else STONE)
	if style == "shutters":
		for s in [-1.0, 1.0]:
			box(Vector3(s * (w * 0.75 + f), -h / 2, 0.012), Vector3(w * 0.45, h, f * 0.5), frame.darkened(0.15), TIMBER)
	elif style == "lattice":
		for k in 3:
			box(Vector3(-w / 2 + w * (k + 1) / 4.0, -h / 2, 0.02), Vector3(f * 0.35, h, f * 0.4), frame, TIMBER)
		box(Vector3(0, -h * 0.05, 0.02), Vector3(w, f * 0.35, f * 0.4), frame, TIMBER)
	elif style == "arch":
		dome(Vector3(0, h / 2, 0.006), w / 2, Color(0.07, 0.05, 0.04), DARK, 0.8, 2, 6)
	pop()


## A door: dark opening, frame and a little step.
func door(at_pos: Vector3, yaw: float, w: float, h: float, frame: Color, leaf := Color(0.42, 0.26, 0.14)) -> void:
	push(at(at_pos, yaw))
	var f := w * 0.14
	box(Vector3(0, 0, 0.0), Vector3(w, h, 0.012), leaf, TIMBER)
	box(Vector3(0, h, 0.01), Vector3(w + f * 2.0, f, f * 1.4), frame, TIMBER)
	for s in [-1.0, 1.0]:
		box(Vector3(s * (w / 2 + f / 2), 0, 0.01), Vector3(f, h, f * 1.2), frame, TIMBER)
	box(Vector3(0, 0, w * 0.18), Vector3(w * 1.4, f * 0.6, w * 0.35), Color(0.62, 0.60, 0.56), STONE)   # step
	pop()


## A chimney stack with a cap, standing at `foot` (put it on the roof slope).
func chimney(foot: Vector3, w: float, h: float, colour: Color, material := STONE) -> void:
	box(foot, Vector3(w, h, w), colour, material)
	box(foot + Vector3(0, h, 0), Vector3(w * 1.3, w * 0.25, w * 1.3), colour.darkened(0.1), material)


## A flag on a pole: pole height `h`, cloth in the owner's colour.
func banner(foot: Vector3, h: float, size: float, yaw := 0.0) -> void:
	cylinder(foot, size * 0.04, h, Color(0.35, 0.25, 0.15), TIMBER, 5)
	push(at(foot + Vector3(0, h - size * 0.65, 0), yaw))
	box(Vector3(size * 0.5, 0, 0), Vector3(size, size * 0.6, size * 0.03), Color.WHITE, OWNER_CLOTH)
	pop()
