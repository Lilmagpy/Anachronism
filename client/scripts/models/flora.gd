## Plants and animals for settlements (D-281): shrubs, beds, trees, a trellis, and farm
## beasts. They blend houses into the landscape, so they share the map's bright, faceted,
## storybook look: layered canopies in two or three greens, visible trunks, blossom and
## fruit as little coloured facets. Animals are a touch chunkier than true scale so they
## read from the high three-quarter camera. Units: 1.0 = an ordinary house's width.
## Every model stands on y = 0, is centred on x = z = 0 and faces +z (animals' heads).
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")

# --- palette ---------------------------------------------------------------------------------
const G_DARK := Color(0.22, 0.52, 0.22)
const G_MID := Color(0.32, 0.64, 0.24)
const G_LIGHT := Color(0.44, 0.74, 0.29)
const G_PALE := Color(0.58, 0.82, 0.36)
const BARK := Color(0.44, 0.30, 0.18)
const BARK_DARK := Color(0.32, 0.22, 0.15)
const SOIL := Color(0.42, 0.30, 0.20)
const CONIFER_A := Color(0.17, 0.44, 0.27)
const CONIFER_B := Color(0.24, 0.52, 0.30)
const RED := Color(0.86, 0.18, 0.14)
const PINK := Color(0.96, 0.52, 0.62)
const WHITE := Color(0.97, 0.96, 0.92)
const YELLOW := Color(0.98, 0.82, 0.20)
const PURPLE := Color(0.50, 0.22, 0.60)


static func kinds() -> Array:
	return ["shrub", "shrub_2", "shrub_flowering", "bush", "hedge", "flowerbed", "vegetable_patch",
		"grass_tuft", "reeds",
		"tree_fruit", "tree_fruit_2", "tree_broadleaf", "tree_broadleaf_2", "tree_broadleaf_3",
		"tree_small", "cypress", "olive", "palm", "palm_2", "palm_small", "bamboo", "pine", "willow",
		"cherry", "vine_trellis",
		"cow", "cow_2", "sheep", "goat", "horse", "horse_2", "camel", "camel_2", "chickens", "ox"]


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	match kind:
		"shrub":
			_shrub(k, 0.17, [G_MID, G_LIGHT, G_DARK], [])
		"shrub_2":
			_shrub(k, 0.15, [Color(0.36, 0.58, 0.30), Color(0.50, 0.68, 0.36), Color(0.28, 0.46, 0.26)], [])
		"shrub_flowering":
			_shrub(k, 0.18, [G_MID, G_DARK, G_LIGHT], [PINK, WHITE])
		"bush":
			_bush(k)
		"hedge":
			_hedge(k)
		"flowerbed":
			_flowerbed(k)
		"vegetable_patch":
			_vegetable_patch(k)
		"grass_tuft":
			_grass_tuft(k)
		"reeds":
			_reeds(k)
		"tree_fruit":
			_fruit_tree(k, RED, [G_DARK, G_MID, G_LIGHT])
		"tree_fruit_2":
			_fruit_tree(k, Color(0.98, 0.62, 0.12), [Color(0.26, 0.56, 0.24), Color(0.36, 0.66, 0.26), Color(0.50, 0.76, 0.30)])
		"tree_broadleaf":
			_broadleaf(k, [G_DARK, G_MID, G_LIGHT], 1.0)
		"tree_broadleaf_2":
			_broadleaf(k, [Color(0.20, 0.46, 0.26), Color(0.28, 0.56, 0.28), Color(0.40, 0.68, 0.32)], 0.85)
		"tree_broadleaf_3":
			_broadleaf(k, [Color(0.78, 0.40, 0.14), Color(0.92, 0.58, 0.16), Color(0.96, 0.76, 0.26)], 0.95)
		"tree_small":
			_small_tree(k)
		"cypress":
			_cypress(k)
		"olive":
			_olive(k)
		"palm":
			_palm(k, 0.62, 8, 0.045, false)
		"palm_2":
			_palm(k, 0.56, 9, 0.05, true)
		"palm_small":
			_palm(k, 0.34, 6, 0.032, false)
		"bamboo":
			_bamboo(k)
		"pine":
			_pine(k)
		"willow":
			_willow(k)
		"cherry":
			_cherry(k)
		"vine_trellis":
			_trellis(k)
		"cow":
			_cow(k, false)
		"cow_2":
			_cow(k, true)
		"sheep":
			_sheep(k)
		"goat":
			_goat(k)
		"horse":
			_horse(k, Color(0.58, 0.33, 0.18), Color(0.20, 0.12, 0.08))
		"horse_2":
			_horse(k, Color(0.90, 0.88, 0.84), Color(0.55, 0.53, 0.52))
		"camel":
			_camel(k, false)
		"camel_2":
			_camel(k, true)
		"chickens":
			_chickens(k)
		"ox":
			_ox(k)
	return k.finish()


# --- helpers ----------------------------------------------------------------------------------


## A faceted foliage blob: a squashed dome turned `yaw` so neighbours do not line up.
static func _blob(k: Kit, c: Vector3, r: float, squash: float, col: Color, yaw := 0.0, sides := 7, rings := 2) -> void:
	k.push(Kit.at(c, yaw))
	k.dome(Vector3.ZERO, r, col, Kit.LEAF, squash, rings, sides)
	k.pop()


## The underside of a canopy: a shallow inverted dome, so no hollow shows from the side.
static func _belly(k: Kit, c: Vector3, r: float, depth: float, col: Color, sides := 7) -> void:
	k.push(Transform3D(Basis.from_scale(Vector3(1, -1, 1)), c))
	k.dome(Vector3.ZERO, r, col, Kit.LEAF, depth / r, 1, sides)
	k.pop()


## Several blobs at once. Each entry is [x, y, z, radius, squash, colour index].
static func _canopy(k: Kit, blobs: Array, cols: Array, sides := 7) -> void:
	for i in blobs.size():
		var b: Array = blobs[i]
		var ci: int = b[5]
		_blob(k, Vector3(b[0], b[1], b[2]), b[3], b[4], cols[ci % cols.size()], i * 0.7, sides)


## A little faceted bead (fruit, blossom, flower head) at `p`.
static func _dot(k: Kit, p: Vector3, r: float, col: Color, sides := 4) -> void:
	k.dome(p, r, col, Kit.PAINT, 0.9, 1, sides)


## Scatter `count` beads over a squashed dome canopy (centre c, radius r), deterministic.
static func _dots(k: Kit, c: Vector3, r: float, squash: float, count: int, cols: Array, size: float, seed_ := 0.0) -> void:
	for i in count:
		var a := i * 2.39996 + seed_
		var e := 0.2 + fposmod(i * 0.37 + seed_ * 0.13, 1.0) * 0.85
		var d := Vector3(cos(a) * cos(e), sin(e) * squash, sin(a) * cos(e))
		_dot(k, c + d * r * 0.96, size, cols[i % cols.size()])


## A tapering trunk with a slight flare at the foot.
static func _trunk(k: Kit, h: float, r: float, col := BARK, sides := 6) -> void:
	k.frustum(Vector3.ZERO, r * 1.0, r * 0.7, h, col, Kit.TIMBER, sides, false)


## A flat sheet seen from both sides (leaves, fronds, curtains). Points in order, convex.
static func _sheet(k: Kit, pts: Array, col: Color, mat: int) -> void:
	k.polygon(pts, col, mat, Vector3(0, -10, 0))
	k.polygon(pts, col, mat, Vector3(0, 10, 0))


## A narrow upright leg, tapering a little (four sides, open top and bottom).
static func _leg(k: Kit, x: float, z: float, h: float, r: float, col: Color, sides := 4) -> void:
	k.frustum(Vector3(x, 0, z), r, r * 0.8, h, col, Kit.PAINT, sides, false)


# --- shrubs and beds ---------------------------------------------------------------------------


static func _shrub(k: Kit, width: float, cols: Array, beads: Array) -> void:
	var r := width * 0.36
	var blobs := [[-r * 0.7, r * 0.45, r * 0.1, r, 0.8, 0], [r * 0.75, r * 0.4, -r * 0.2, r * 0.9, 0.8, 2],
		[0.0, r * 0.8, r * 0.1, r * 0.85, 0.85, 1], [r * 0.1, r * 0.35, r * 0.75, r * 0.7, 0.8, 1]]
	_canopy(k, blobs, cols, 6)
	if beads.size() > 0:
		_dots(k, Vector3(0, r * 0.8, r * 0.1), r * 0.9, 0.85, 7, beads, width * 0.07, 0.4)
		_dots(k, Vector3(-r * 0.7, r * 0.45, r * 0.1), r, 0.8, 3, beads, width * 0.07, 1.9)


static func _bush(k: Kit) -> void:
	var blobs := [[-0.07, 0.06, 0.0, 0.085, 0.85, 0], [0.07, 0.06, 0.02, 0.08, 0.85, 2], [0.0, 0.07, -0.06, 0.08, 0.85, 0],
		[0.0, 0.1, 0.02, 0.085, 0.85, 1], [0.02, 0.05, 0.07, 0.07, 0.85, 2]]
	_canopy(k, blobs, [G_DARK, G_MID, G_LIGHT], 7)


## A clipped hedge, exactly 1.0 long along x, built of slightly uneven segments.
static func _hedge(k: Kit) -> void:
	var cols := [G_MID, Color(0.27, 0.58, 0.23), G_MID.lightened(0.06), Color(0.30, 0.61, 0.24)]
	var hs := [0.092, 0.104, 0.096, 0.1]
	for i in 4:
		var h: float = hs[i]
		k.bevel_box(Vector3(-0.375 + i * 0.25, 0, 0), Vector3(0.25, h, 0.1), 0.025, cols[i], Kit.LEAF)
	k.box(Vector3(0, 0, 0), Vector3(1.0, 0.012, 0.06), SOIL, Kit.EARTH)
	for i in 4:   # leafy tufts break up the clipped line
		_blob(k, Vector3(-0.375 + i * 0.25 + (0.03 if i % 2 == 0 else -0.03), 0.1, 0), 0.05, 0.5, G_LIGHT, i, 6, 1)


static func _flowerbed(k: Kit) -> void:
	k.box(Vector3.ZERO, Vector3(0.3, 0.025, 0.2), SOIL, Kit.EARTH)
	var rim := Color(0.70, 0.67, 0.60)
	k.box(Vector3(0, 0, 0.1), Vector3(0.32, 0.03, 0.02), rim, Kit.STONE)
	k.box(Vector3(0, 0, -0.1), Vector3(0.32, 0.03, 0.02), rim, Kit.STONE)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.15, 0, 0), Vector3(0.02, 0.03, 0.2), rim, Kit.STONE)
	var cols := [PINK, YELLOW, WHITE, RED, PURPLE]
	for i in 9:
		var x := -0.11 + (i % 3) * 0.11 + (0.015 if i > 4 else -0.01)
		var z := -0.06 + (i / 3) * 0.06
		_blob(k, Vector3(x, 0.02, z), 0.032, 0.8, G_MID, i * 0.5, 5, 1)
		_dot(k, Vector3(x, 0.05, z), 0.022, cols[(i * 2) % cols.size()], 5)


static func _vegetable_patch(k: Kit) -> void:
	k.box(Vector3.ZERO, Vector3(0.5, 0.02, 0.4), SOIL.darkened(0.1), Kit.EARTH)
	var leaf := [G_LIGHT, G_PALE, G_MID, Color(0.60, 0.72, 0.30)]
	for r in 4:
		var z := -0.15 + r * 0.1
		k.box(Vector3(0, 0.02, z), Vector3(0.46, 0.02, 0.05), SOIL.lightened(0.08), Kit.EARTH)
		for i in 4:
			var x := -0.17 + i * 0.115 + (0.03 if r % 2 == 1 else 0.0)
			k.dome(Vector3(x, 0.035, z), 0.04, leaf[(r + i) % 4], Kit.LEAF, 0.8, 1, 6)
	for x in [-0.25, 0.25]:   # stakes at the ends
		k.box(Vector3(x, 0.0, 0.0), Vector3(0.015, 0.09, 0.015), BARK, Kit.TIMBER)


static func _grass_tuft(k: Kit) -> void:
	for i in 9:
		var a := i * 2.4
		var lean := 0.25 + (i % 3) * 0.12
		var h := 0.05 + (i % 4) * 0.012
		k.push(Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), lean),
			Vector3(cos(a) * 0.025, 0, sin(a) * 0.025)))
		k.frustum(Vector3.ZERO, 0.011, 0.0, h, [G_LIGHT, G_MID, G_PALE][i % 3], Kit.LEAF, 3)
		k.pop()


static func _reeds(k: Kit) -> void:
	for i in 10:
		var a := i * 2.4
		var rr := 0.012 + (i % 4) * 0.018
		var x := cos(a) * rr
		var z := sin(a) * rr
		var h := 0.24 + (i % 5) * 0.035
		var lean := 0.07 + (i % 3) * 0.05
		k.push(Transform3D(Basis(Vector3(cos(a + 1.5), 0, sin(a + 1.5)).cross(Vector3.UP).normalized(), lean), Vector3(x, 0, z)))
		k.frustum(Vector3.ZERO, 0.009, 0.003, h, [G_MID, Color(0.56, 0.70, 0.32), G_DARK][i % 3], Kit.LEAF, 3, false)
		if i % 3 == 0:   # a brown cattail head
			k.frustum(Vector3(0, h * 0.72, 0), 0.012, 0.009, 0.05, Color(0.45, 0.28, 0.14), Kit.TIMBER, 4)
		k.pop()


# --- trees --------------------------------------------------------------------------------------


static func _fruit_tree(k: Kit, fruit: Color, cols: Array) -> void:
	_trunk(k, 0.2, 0.034)
	var blobs := [[-0.09, 0.27, 0.02, 0.1, 0.85, 0], [0.09, 0.28, -0.02, 0.1, 0.85, 0], [0.0, 0.27, -0.09, 0.1, 0.85, 0],
		[0.01, 0.28, 0.1, 0.1, 0.85, 1], [0.0, 0.38, 0.0, 0.13, 0.85, 1], [-0.03, 0.46, 0.02, 0.08, 0.8, 2]]
	_canopy(k, blobs, cols, 7)
	_belly(k, Vector3(0, 0.3, 0), 0.15, 0.07, cols[0])
	_dots(k, Vector3(0, 0.38, 0), 0.13, 0.85, 6, [fruit], 0.02, 0.2)
	_dots(k, Vector3(0.09, 0.28, -0.02), 0.1, 0.85, 3, [fruit], 0.02, 2.1)
	_dots(k, Vector3(-0.09, 0.27, 0.02), 0.1, 0.85, 3, [fruit], 0.02, 4.3)
	_dots(k, Vector3(0.01, 0.28, 0.1), 0.1, 0.85, 3, [fruit], 0.02, 5.7)


static func _broadleaf(k: Kit, cols: Array, s: float) -> void:
	_trunk(k, 0.3 * s, 0.045 * s, BARK, 7)
	var blobs := [[-0.12, 0.34, 0.03, 0.13, 0.85, 0], [0.12, 0.35, -0.03, 0.13, 0.85, 0], [0.0, 0.33, -0.12, 0.12, 0.85, 0],
		[0.02, 0.34, 0.12, 0.12, 0.85, 1], [-0.05, 0.48, -0.03, 0.14, 0.85, 1], [0.07, 0.49, 0.05, 0.12, 0.85, 1],
		[0.0, 0.6, 0.0, 0.11, 0.8, 2]]
	for i in blobs.size():
		var b: Array = blobs[i]
		var ci: int = b[5]
		var bs := s
		_blob(k, Vector3(float(b[0]) * bs, float(b[1]) * bs, float(b[2]) * bs), float(b[3]) * bs, b[4], cols[ci], i * 0.7, 7)
	_belly(k, Vector3(0, 0.36 * s, 0), 0.19 * s, 0.1 * s, cols[0])


static func _small_tree(k: Kit) -> void:
	_trunk(k, 0.14, 0.025)
	var blobs := [[-0.05, 0.19, 0.0, 0.07, 0.85, 0], [0.06, 0.2, 0.01, 0.07, 0.85, 1], [0.0, 0.2, -0.06, 0.07, 0.85, 0],
		[0.0, 0.27, 0.01, 0.08, 0.85, 2]]
	_canopy(k, blobs, [G_DARK, G_MID, G_LIGHT], 6)
	_belly(k, Vector3(0, 0.2, 0), 0.09, 0.05, G_DARK, 6)


static func _cypress(k: Kit) -> void:
	k.frustum(Vector3.ZERO, 0.02, 0.017, 0.08, BARK_DARK, Kit.TIMBER, 5, false)
	# overlapping flared tiers give a ruffled flame silhouette
	var tiers := [[0.04, 0.08, 0.055, 0.3, CONIFER_A], [0.2, 0.074, 0.05, 0.28, CONIFER_B],
		[0.36, 0.062, 0.04, 0.24, CONIFER_A], [0.5, 0.048, 0.025, 0.2, CONIFER_B], [0.62, 0.032, 0.0, 0.17, CONIFER_A]]
	for i in tiers.size():
		var t: Array = tiers[i]
		k.push(Kit.at(Vector3.ZERO, i * 0.5))
		k.frustum(Vector3(0, t[0], 0), t[1], t[2], t[3], t[4], Kit.LEAF, 7, false)
		k.pop()


static func _olive(k: Kit) -> void:
	# a short gnarled trunk that splits in two
	k.push(Transform3D(Basis(Vector3.BACK, 0.18), Vector3(-0.01, 0, 0)))
	k.frustum(Vector3.ZERO, 0.042, 0.03, 0.2, Color(0.50, 0.42, 0.34), Kit.TIMBER, 6, false)
	k.pop()
	k.push(Transform3D(Basis(Vector3.BACK, -0.45), Vector3(0.0, 0.1, 0.0)))
	k.frustum(Vector3.ZERO, 0.026, 0.02, 0.17, Color(0.46, 0.38, 0.30), Kit.TIMBER, 5, false)
	k.pop()
	var silver := [Color(0.34, 0.52, 0.32), Color(0.46, 0.64, 0.38), Color(0.58, 0.74, 0.46)]
	var blobs := [[-0.1, 0.24, 0.02, 0.11, 0.6, 0], [0.12, 0.28, -0.03, 0.1, 0.6, 0], [0.0, 0.25, -0.1, 0.1, 0.6, 1],
		[0.02, 0.24, 0.11, 0.1, 0.6, 1], [-0.03, 0.31, 0.0, 0.12, 0.6, 1], [0.05, 0.36, 0.02, 0.08, 0.6, 2]]
	_canopy(k, blobs, silver, 7)
	_belly(k, Vector3(0, 0.25, 0), 0.15, 0.05, silver[0])


## A palm: leaning ringed trunk, a crown of drooping fronds, nuts or date bunches.
static func _palm(k: Kit, height: float, fronds: int, trunk_r: float, dates: bool) -> void:
	var lean := 0.16 if not dates else 0.05
	var pos := Vector3.ZERO
	var segs := 4
	var tan := Color(0.60, 0.45, 0.30)
	for i in segs:
		var a := lean * (1.0 - i * 0.12) + (0.0)
		var basis := Basis(Vector3.BACK, a * (i + 1) / 2.0)
		var h := height / segs
		var r0 := trunk_r * (1.0 - i * 0.12)
		var r1 := trunk_r * (1.0 - (i + 1) * 0.12)
		k.push(Transform3D(basis, pos))
		k.frustum(Vector3.ZERO, r0, r1, h, tan if i % 2 == 0 else tan.darkened(0.14), Kit.TIMBER, 6, i == segs - 1)
		k.pop()
		pos += basis * Vector3(0, h, 0)
	var len_ := height * 0.62
	for i in fronds:
		var yaw := i * TAU / fronds + (0.3 if i % 2 == 0 else 0.0)
		var l := len_ * (0.9 if i % 2 == 0 else 1.05)
		var w := l * 0.15
		var rise := l * 0.2
		var droop := 0.8 if i % 2 == 0 else 0.6
		k.push(Kit.at(pos, yaw))
		var pts := [Vector3(0, 0, 0), Vector3(-w, rise, l * 0.35), Vector3(-w * 0.8, rise * 0.9 - l * 0.1, l * 0.72),
			Vector3(0, rise - l * droop, l), Vector3(w * 0.8, rise * 0.9 - l * 0.1, l * 0.72), Vector3(w, rise, l * 0.35)]
		_sheet(k, pts, [G_MID, G_LIGHT][i % 2] if not dates else [Color(0.30, 0.58, 0.26), Color(0.42, 0.68, 0.28)][i % 2], Kit.LEAF)
		k.pop()
	# the heart of the crown, and what hangs in it
	k.dome(pos + Vector3(0, -0.01, 0), trunk_r * 1.1, G_DARK, Kit.LEAF, 0.8, 1, 6)
	if dates:
		for i in 3:
			var a := i * 2.1 + 0.4
			var p := pos + Vector3(cos(a) * trunk_r * 1.2, -trunk_r * 1.4, sin(a) * trunk_r * 1.2)
			k.frustum(p, trunk_r * 0.35, trunk_r * 0.7, trunk_r * 1.4, Color(0.82, 0.40, 0.12), Kit.PAINT, 5)
	else:
		for i in 3:
			var a := i * 2.1 + 0.4
			_dot(k, pos + Vector3(cos(a) * trunk_r * 0.9, -trunk_r * 0.9, sin(a) * trunk_r * 0.9), trunk_r * 0.5, Color(0.40, 0.30, 0.16), 5)


static func _bamboo(k: Kit) -> void:
	var stalk := [Color(0.60, 0.74, 0.30), Color(0.70, 0.80, 0.34), Color(0.52, 0.68, 0.28)]
	for i in 6:
		var a := i * 1.05
		var x := cos(a) * 0.03
		var z := sin(a) * 0.03
		var h := 0.5 + (i % 3) * 0.07
		var lean := 0.1 + (i % 3) * 0.06
		k.push(Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), lean), Vector3(x, 0, z)))
		k.frustum(Vector3.ZERO, 0.011, 0.007, h, stalk[i % 3], Kit.PAINT, 4, false)
		k.frustum(Vector3(0, h * 0.45, 0), 0.0135, 0.0135, 0.008, Color(0.42, 0.56, 0.24), Kit.PAINT, 4, false)   # a node ring
		_blob(k, Vector3(0, h * 0.98, 0), 0.07, 0.4, [G_LIGHT, G_PALE, G_MID][i % 3], i * 0.9, 5, 1)
		_blob(k, Vector3(0.035, h * 0.85, 0), 0.05, 0.4, G_MID, i * 0.4, 5, 1)
		k.pop()


static func _pine(k: Kit) -> void:
	k.frustum(Vector3.ZERO, 0.03, 0.022, 0.14, BARK_DARK, Kit.TIMBER, 5, false)
	var tiers := [[0.08, 0.17, 0.2], [0.2, 0.14, 0.19], [0.32, 0.11, 0.18], [0.44, 0.08, 0.17], [0.55, 0.055, 0.15]]
	for i in tiers.size():
		var t: Array = tiers[i]
		k.push(Kit.at(Vector3.ZERO, i * 0.4))
		k.frustum(Vector3(0, t[0], 0), t[1], 0.0, t[2], CONIFER_A if i % 2 == 0 else CONIFER_B, Kit.LEAF, 8, false)
		k.pop()


static func _willow(k: Kit) -> void:
	_trunk(k, 0.3, 0.045, Color(0.40, 0.32, 0.22), 6)
	var pale := [Color(0.38, 0.62, 0.30), Color(0.50, 0.73, 0.34), Color(0.64, 0.83, 0.42)]
	var blobs := [[-0.07, 0.36, 0.02, 0.14, 0.65, 1], [0.08, 0.37, -0.02, 0.13, 0.65, 2], [0.0, 0.42, 0.0, 0.12, 0.7, 2]]
	_canopy(k, blobs, pale, 8)
	# hanging curtains of fine branches: dense, overlapping, uneven pendants in three rings
	var rings := [[10, 0.2, 0.34, 0.08, 0.06], [8, 0.15, 0.38, 0.16, 0.055], [5, 0.08, 0.42, 0.26, 0.05]]
	for ring in rings:
		var n: int = ring[0]
		for i in n:
			var a: float = i * TAU / n + float(ring[1]) * 7.0
			var rr: float = ring[1]
			var bottom: float = float(ring[3]) + (0.05 if i % 3 == 0 else (0.02 if i % 3 == 1 else 0.0))
			k.frustum(Vector3(cos(a) * rr, bottom, sin(a) * rr), 0.0, float(ring[4]), float(ring[2]) - bottom,
				pale[(i + n) % 3], Kit.LEAF, 4, false)


static func _cherry(k: Kit) -> void:
	_trunk(k, 0.2, 0.034, BARK_DARK)
	var pinks := [Color(0.94, 0.62, 0.72), Color(0.97, 0.74, 0.82), Color(0.99, 0.86, 0.90)]
	var blobs := [[-0.09, 0.27, 0.02, 0.1, 0.85, 0], [0.09, 0.28, -0.02, 0.1, 0.85, 0], [0.0, 0.27, -0.09, 0.1, 0.85, 1],
		[0.01, 0.28, 0.1, 0.1, 0.85, 1], [0.0, 0.38, 0.0, 0.13, 0.85, 1], [-0.03, 0.46, 0.02, 0.08, 0.8, 2]]
	_canopy(k, blobs, pinks, 7)
	_belly(k, Vector3(0, 0.3, 0), 0.15, 0.07, pinks[0])
	_dots(k, Vector3(0, 0.38, 0), 0.13, 0.85, 5, [WHITE, Color(0.88, 0.40, 0.55)], 0.018, 0.6)
	# fallen petals beneath
	for i in 5:
		var a := i * 2.4
		k.box(Vector3(cos(a) * 0.14, 0.0, sin(a) * 0.14), Vector3(0.025, 0.004, 0.02), pinks[i % 3], Kit.PAINT, a)


## An arbour of posts and rails carrying a grape vine, long side along x.
static func _trellis(k: Kit) -> void:
	for x in [-0.24, 0.24]:
		for z in [-0.08, 0.08]:
			k.box(Vector3(x, 0, z), Vector3(0.022, 0.26, 0.022), BARK, Kit.TIMBER)
	for z in [-0.08, 0.08]:
		k.box(Vector3(0, 0.26, z), Vector3(0.54, 0.02, 0.025), BARK_DARK, Kit.TIMBER)
	for i in 5:
		k.box(Vector3(-0.2 + i * 0.1, 0.28, 0), Vector3(0.02, 0.015, 0.2), BARK, Kit.TIMBER)
	var cols := [G_MID, G_LIGHT, G_DARK]
	for i in 4:
		_blob(k, Vector3(-0.19 + i * 0.127, 0.29, (0.03 if i % 2 == 0 else -0.03)), 0.085, 0.45, cols[i % 3], i * 0.8, 6, 1)
	# a leafy curtain down the back, and grape bunches hanging in front
	for i in 3:
		_blob(k, Vector3(-0.14 + i * 0.14, 0.2, -0.085), 0.06, 0.8, cols[(i + 1) % 3], i, 5, 1)
	for i in 5:
		k.frustum(Vector3(-0.2 + i * 0.1, 0.16 + (i % 2) * 0.03, 0.06), 0.003, 0.017, 0.07 - (i % 2) * 0.02, PURPLE, Kit.PAINT, 5)


# --- animals ------------------------------------------------------------------------------------


## A quadruped's torso and legs: body length along z. Returns nothing; heads are added by callers.
static func _torso(k: Kit, len_: float, wid: float, hgt: float, leg_h: float, col: Color, leg_col: Color, mat: int, bevel := 0.02) -> void:
	k.bevel_box(Vector3(0, leg_h, 0), Vector3(wid, hgt, len_), bevel, col, mat)
	var lr := wid * 0.13
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_leg(k, sx * wid * 0.3, sz * len_ * 0.33, leg_h + 0.004, lr, leg_col)


static func _cow(k: Kit, brown: bool) -> void:
	var white := Color(0.95, 0.94, 0.90)
	var dark := Color(0.14, 0.12, 0.12)
	var body := white if not brown else Color(0.62, 0.38, 0.20)
	var spot := dark if not brown else Color(0.95, 0.93, 0.88)
	_torso(k, 0.2, 0.1, 0.09, 0.05, body, Color(0.30, 0.24, 0.20) if brown else white.darkened(0.12), Kit.PAINT, 0.025)
	if not brown:
		k.box(Vector3(-0.012, 0.14, 0.04), Vector3(0.082, 0.01, 0.075), spot, Kit.PAINT, 0.2)
		k.box(Vector3(0.051, 0.09, -0.04), Vector3(0.006, 0.07, 0.07), spot, Kit.PAINT)
		k.box(Vector3(-0.051, 0.1, -0.05), Vector3(0.006, 0.05, 0.06), spot, Kit.PAINT)
		k.box(Vector3(0.0, 0.14, -0.07), Vector3(0.07, 0.01, 0.05), spot, Kit.PAINT, -0.3)
	else:
		k.box(Vector3(0.0, 0.14, 0.0), Vector3(0.07, 0.01, 0.08), body.darkened(0.15), Kit.PAINT)
	# head with pale muzzle, ears, horns
	k.box(Vector3(0, 0.1, 0.1), Vector3(0.07, 0.07, 0.08), body if not brown else body.lightened(0.05), Kit.PAINT, 0.0, true)
	k.box(Vector3(0, 0.1, 0.14), Vector3(0.05, 0.035, 0.03), Color(0.95, 0.72, 0.68), Kit.PAINT)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.045, 0.145, 0.095), Vector3(0.03, 0.012, 0.025), dark if not brown else body.darkened(0.2), Kit.PAINT)
		k.rod(Vector3(s * 0.03, 0.17, 0.1), Vector3(s * 0.05, 0.19, 0.1), 0.006, Color(0.92, 0.88, 0.76), Kit.PAINT)
	k.box(Vector3(0, 0.05, -0.07), Vector3(0.045, 0.02, 0.04), Color(0.95, 0.70, 0.66), Kit.PAINT)   # udder
	k.rod(Vector3(0, 0.14, -0.1), Vector3(0, 0.07, -0.112), 0.006, dark, Kit.PAINT)


static func _sheep(k: Kit) -> void:
	var spots := [[-0.07, 0.05, 0.4, 1.0], [0.08, -0.02, -0.7, 0.95], [0.0, -0.1, 2.2, 0.9], [-0.1, -0.12, 0.2, 0.7]]
	for i in spots.size():
		var s: Array = spots[i]
		k.push(Kit.at(Vector3(s[0], 0, s[1]), s[2]))
		var sc: float = s[3]
		k.push(Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), Vector3.ZERO))
		var wool := Color(0.96, 0.94, 0.88) if i != 2 else Color(0.80, 0.76, 0.68)
		k.bevel_box(Vector3(0, 0.03, 0), Vector3(0.08, 0.062, 0.1), 0.026, wool, Kit.PAINT)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_leg(k, sx * 0.022, sz * 0.032, 0.034, 0.007, Color(0.22, 0.18, 0.16), 3)
		k.dome(Vector3(0, 0.092, -0.005), 0.034, wool.lightened(0.04), Kit.PAINT, 0.8, 1, 5)
		k.box(Vector3(0, 0.045, 0.05), Vector3(0.036, 0.04, 0.036), Color(0.30, 0.23, 0.20), Kit.PAINT)
		k.pop()
		k.pop()


static func _goat(k: Kit) -> void:
	var coat := Color(0.80, 0.70, 0.54)
	_torso(k, 0.12, 0.055, 0.055, 0.045, coat, Color(0.40, 0.32, 0.26), Kit.PAINT, 0.015)
	k.box(Vector3(0, 0.1, 0.06), Vector3(0.04, 0.05, 0.04), coat, Kit.PAINT, 0.0, true)   # neck and head
	k.box(Vector3(0, 0.12, 0.085), Vector3(0.036, 0.04, 0.04), coat.lightened(0.08), Kit.PAINT)
	k.box(Vector3(0, 0.1, 0.1), Vector3(0.012, 0.03, 0.012), Color(0.95, 0.92, 0.86), Kit.PAINT)   # beard
	for s in [-1.0, 1.0]:
		k.rod(Vector3(s * 0.012, 0.15, 0.08), Vector3(s * 0.02, 0.18, 0.065), 0.004, Color(0.86, 0.82, 0.72), Kit.PAINT)
	k.rod(Vector3(0, 0.1, -0.06), Vector3(0, 0.12, -0.075), 0.005, coat.darkened(0.2), Kit.PAINT)


static func _horse(k: Kit, coat: Color, mane: Color) -> void:
	_torso(k, 0.24, 0.085, 0.09, 0.085, coat, coat.darkened(0.2), Kit.PAINT, 0.03)
	# neck rising forward, head angled down, dark mane and tail
	k.push(Transform3D(Basis(Vector3.RIGHT, 0.7), Vector3(0, 0.15, 0.1)))
	k.box(Vector3.ZERO, Vector3(0.05, 0.11, 0.055), coat, Kit.PAINT)
	k.box(Vector3(0, 0.02, -0.03), Vector3(0.016, 0.1, 0.03), mane, Kit.PAINT)
	k.pop()
	k.push(Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, 0.235, 0.165)))
	k.box(Vector3.ZERO, Vector3(0.04, 0.045, 0.075), coat, Kit.PAINT, 0.0, true)
	k.box(Vector3(0, -0.005, 0.045), Vector3(0.032, 0.035, 0.03), coat.lightened(0.1), Kit.PAINT)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.014, 0.04, -0.015), Vector3(0.012, 0.025, 0.012), coat.darkened(0.1), Kit.PAINT)
	k.pop()
	for i in 3:   # tail
		k.rod(Vector3(0, 0.17, -0.12), Vector3((i - 1) * 0.008, 0.08 + i % 2 * 0.01, -0.145), 0.008, mane, Kit.PAINT)
	for sx in [-1.0, 1.0]:   # hooves
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.0255, 0, sz * 0.08), Vector3(0.016, 0.014, 0.016), mane.darkened(0.3), Kit.DARK)


static func _camel(k: Kit, bactrian: bool) -> void:
	var coat := Color(0.78, 0.60, 0.38) if not bactrian else Color(0.60, 0.44, 0.28)
	_torso(k, 0.22, 0.08, 0.08, 0.1, coat, coat.darkened(0.15), Kit.PAINT, 0.025)
	if bactrian:
		k.dome(Vector3(0, 0.18, -0.045), 0.04, coat.lightened(0.04), Kit.PAINT, 1.1, 2, 6)
		k.dome(Vector3(0, 0.18, 0.045), 0.04, coat.lightened(0.04), Kit.PAINT, 1.1, 2, 6)
		k.box(Vector3(0, 0.17, 0.0), Vector3(0.07, 0.01, 0.1), coat.darkened(0.1), Kit.PAINT)
	else:
		k.dome(Vector3(0, 0.17, -0.005), 0.055, coat.lightened(0.04), Kit.PAINT, 1.0, 2, 7)
	# a long neck curving up and forward
	k.push(Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, 0.17, 0.08)))
	k.box(Vector3.ZERO, Vector3(0.04, 0.12, 0.04), coat, Kit.PAINT)
	k.pop()
	k.push(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.27, 0.15)))
	k.box(Vector3.ZERO, Vector3(0.042, 0.04, 0.06), coat, Kit.PAINT, 0.0, true)
	k.box(Vector3(0, -0.002, 0.04), Vector3(0.034, 0.03, 0.03), coat.lightened(0.1), Kit.PAINT)
	k.pop()
	k.rod(Vector3(0, 0.15, -0.11), Vector3(0, 0.1, -0.125), 0.006, coat.darkened(0.3), Kit.PAINT)
	for sx in [-1.0, 1.0]:   # pads
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.024, 0, sz * 0.073), Vector3(0.02, 0.01, 0.022), coat.darkened(0.35), Kit.DARK)


static func _chickens(k: Kit) -> void:
	var spots := [[-0.035, 0.02, 0.5, 0], [0.04, 0.03, -1.0, 1], [0.0, -0.04, 2.6, 2], [-0.05, -0.03, 1.2, 1]]
	var bodies := [WHITE, Color(0.72, 0.40, 0.18), Color(0.30, 0.22, 0.18)]
	for s in spots:
		var body: Color = bodies[int(s[3])]
		k.push(Kit.at(Vector3(s[0], 0, s[1]), s[2]))
		k.dome(Vector3(0, 0.014, -0.002), 0.022, body, Kit.PAINT, 0.95, 2, 6)
		k.dome(Vector3(0, 0.03, 0.017), 0.012, body, Kit.PAINT, 1.1, 1, 5)   # head
		k.dome(Vector3(0, 0.044, 0.016), 0.006, RED, Kit.PAINT, 1.0, 1, 3)   # comb
		k.tri(Vector3(0, 0.034, 0.028), Vector3(-0.004, 0.032, 0.022), Vector3(0.004, 0.032, 0.022), YELLOW, Kit.PAINT, Vector3(0, 0.03, 0.017))
		k.box(Vector3(0, 0.02, -0.026), Vector3(0.008, 0.02, 0.01), body.darkened(0.12), Kit.PAINT)   # tail
		for sx in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.008, 0, 0.0), Vector3(0.004, 0.016, 0.004), YELLOW.darkened(0.2), Kit.PAINT)
		k.pop()


static func _ox(k: Kit) -> void:
	var coat := Color(0.50, 0.34, 0.22)
	_torso(k, 0.23, 0.11, 0.1, 0.05, coat, coat.darkened(0.25), Kit.PAINT, 0.03)
	k.dome(Vector3(0, 0.15, 0.05), 0.05, coat.lightened(0.04), Kit.PAINT, 0.8, 2, 6)   # shoulder hump
	k.box(Vector3(0, 0.1, 0.12), Vector3(0.08, 0.08, 0.09), coat.lightened(0.04), Kit.PAINT, 0.0, true)
	k.box(Vector3(0, 0.1, 0.17), Vector3(0.055, 0.04, 0.03), Color(0.30, 0.22, 0.18), Kit.PAINT)
	var horn := Color(0.90, 0.86, 0.74)
	for s in [-1.0, 1.0]:
		k.rod(Vector3(s * 0.04, 0.18, 0.115), Vector3(s * 0.075, 0.2, 0.115), 0.008, horn, Kit.PAINT)
		k.rod(Vector3(s * 0.075, 0.2, 0.115), Vector3(s * 0.085, 0.235, 0.125), 0.007, horn, Kit.PAINT)
		k.box(Vector3(s * 0.05, 0.15, 0.1), Vector3(0.03, 0.012, 0.025), coat.darkened(0.2), Kit.PAINT)
	k.box(Vector3(0, 0.09, 0.07), Vector3(0.06, 0.03, 0.04), coat.darkened(0.1), Kit.PAINT)   # dewlap
	k.rod(Vector3(0, 0.14, -0.115), Vector3(0, 0.06, -0.125), 0.007, Color(0.25, 0.17, 0.12), Kit.PAINT)
