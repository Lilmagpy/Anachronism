## Steppe nomads (Mongols, Turks and others): camps, not towns. Felt gers (yurts) with crown
## rings and rope bands, a khan's great tent with banners and a horse-tail standard inside a
## fenced enclosure, and a ger on an ox cart. Models face +z, stand on y = 0, centred on x = z = 0.
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")

const FELT := Color(0.93, 0.90, 0.82)
const FELT_D := Color(0.82, 0.78, 0.68)
const WOOD := Color(0.40, 0.27, 0.16)
const ROPE := Color(0.30, 0.22, 0.16)
const ORANGE := Color(0.80, 0.38, 0.14)
const RED := Color(0.65, 0.16, 0.12)
const BLUE := Color(0.18, 0.36, 0.62)
const HAIR := Color(0.12, 0.10, 0.09)


static func kinds() -> Array:
	return ["yurt_1", "yurt_2", "yurt_3", "great_tent", "wagon_tent"]


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	match kind:
		"yurt_1":
			_ger(k, Vector3(-0.05, 0, -0.02), 0.0, 0.36, 0.2, 0.2, FELT, ORANGE, Color(0.7, 0.4, 0.2), false)
			# stove pipe, a saddle on a stand and a hitching post
			k.push(Kit.at(Vector3(-0.05, 0, -0.02)))
			k.rod(Vector3(0.1, 0.36, -0.06), Vector3(0.12, 0.62, -0.06), 0.012, Color(0.2, 0.2, 0.22), Kit.DARK)
			k.box(Vector3(0.1, 0.62, -0.06), Vector3(0.05, 0.02, 0.05), Color(0.2, 0.2, 0.22), Kit.DARK)
			k.pop()
			_hitch(k, Vector3(0.38, 0, 0.3))
			_bundle(k, Vector3(-0.38, 0, 0.32))
		"yurt_2":
			_ger(k, Vector3(0, 0, 0), 0.0, 0.42, 0.22, 0.24, FELT, RED, BLUE, true)
			k.banner(Vector3(0.36, 0, 0.36), 0.7, 0.22)
			k.push(Kit.at(Vector3(0, 0, 0)))
			k.box(Vector3(-0.4, 0, 0.3), Vector3(0.1, 0.07, 0.14), WOOD, Kit.TIMBER)
			k.box(Vector3(-0.4, 0.07, 0.3), Vector3(0.08, 0.04, 0.1), Color(0.55, 0.15, 0.1), Kit.CLOTH)
			k.pop()
		"yurt_3":
			_ger(k, Vector3(-0.2, 0, -0.08), 0.35, 0.3, 0.17, 0.2, FELT_D, BLUE, ORANGE, false)
			_cart(k, Vector3(0.28, 0, 0.12), -0.4, 0.8)
			_hitch(k, Vector3(-0.38, 0, 0.35))
		"great_tent":
			_great_tent(k)
		"wagon_tent":
			_wagon_tent(k)
	return k.finish()


# --- helpers -----------------------------------------------------------------------------------


## A felt ger at `pos`, its door turned to `yaw`: wall `wh` high, a low conical roof `rh` more,
## rope bands, painted door and eave band, crown ring. `owner` makes the eave band owner-coloured.
static func _ger(k: Kit, pos: Vector3, yaw: float, r: float, wh: float, rh: float, felt: Color,
		band: Color, door_c: Color, owner: bool) -> void:
	k.push(Kit.at(pos, yaw))
	k.frustum(Vector3.ZERO, r, r, wh, felt, Kit.CLOTH, 14, false)
	k.frustum(Vector3(0, 0, 0), r * 1.03, r * 1.03, 0.025, WOOD, Kit.TIMBER, 14, false)   # lattice foot / skirt board
	k.frustum(Vector3(0, wh, 0), r * 1.1, r * 0.2, rh, felt.darkened(0.04), Kit.CLOTH, 14)
	# the eave band, in the owner's colour or painted
	k.frustum(Vector3(0, wh - 0.002, 0), r * 1.101, r * 1.09, 0.045, Color.WHITE if owner else band,
		Kit.OWNER_CLOTH if owner else Kit.PAINT, 14, false)
	for t: float in [0.0, 0.35, 0.7]:   # rope bands over wall and roof
		if t == 0.0:
			k.frustum(Vector3(0, wh * 0.45, 0), r * 1.012, r * 1.012, 0.02, ROPE, Kit.CLOTH, 14, false)
		else:
			var rr := lerpf(r * 1.1, r * 0.2, t)
			k.frustum(Vector3(0, wh + rh * t, 0), rr * 1.02, rr * 1.0, 0.02, ROPE, Kit.CLOTH, 14, false)
	# crown ring and smoke hole
	k.frustum(Vector3(0, wh + rh - 0.005, 0), r * 0.23, r * 0.2, 0.04, WOOD, Kit.TIMBER, 10)
	k.frustum(Vector3(0, wh + rh + 0.036, 0), r * 0.13, r * 0.13, 0.004, Color(0.06, 0.04, 0.03), Kit.DARK, 10)
	# the door, painted, with a felt flap rolled over it
	var dw := minf(0.15, r * 0.4)
	k.door(Vector3(0, 0, r * 0.975 + 0.004), 0.0, dw, wh * 0.82, door_c, door_c.darkened(0.25))
	k.box(Vector3(0, wh * 0.86, r * 0.99), Vector3(dw + 0.07, 0.05, 0.03), felt.darkened(0.12), Kit.CLOTH)
	# lattice trellis showing beside the door
	for s: float in [-1.0, 1.0]:
		k.rod(Vector3(s * (dw * 0.5 + 0.05), 0.02, r * 0.95 + 0.012), Vector3(s * (dw * 0.5 + 0.12), wh * 0.75, r * 0.93 + 0.012), 0.006, WOOD, Kit.TIMBER)
		k.rod(Vector3(s * (dw * 0.5 + 0.12), 0.02, r * 0.93 + 0.012), Vector3(s * (dw * 0.5 + 0.05), wh * 0.75, r * 0.95 + 0.012), 0.006, WOOD, Kit.TIMBER)
	k.pop()


## A wheel standing in the plane facing `yaw` (0 = wheel face to +z): disc, hub and spokes.
static func _wheel(k: Kit, c: Vector3, yaw: float, r: float, thick: float) -> void:
	k.push(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2.0), c))
	k.frustum(Vector3(0, -thick / 2.0, 0), r, r, thick, Color(0.30, 0.20, 0.12), Kit.TIMBER, 14)
	k.frustum(Vector3(0, -thick * 0.7, 0), r * 0.2, r * 0.2, thick * 1.4, Color(0.5, 0.36, 0.2), Kit.TIMBER, 8)
	k.pop()
	k.push(Transform3D(Basis(Vector3.UP, yaw), c))
	for i in 4:
		k.push(Transform3D(Basis(Vector3(0, 0, 1), i * PI / 4.0), Vector3.ZERO))
		k.box(Vector3(0, -r * 0.92, 0), Vector3(0.022, r * 1.84, thick * 1.25), Color(0.5, 0.36, 0.2), Kit.TIMBER)
		k.pop()
	k.pop()


## A two-wheeled cart: bed, big wheels, shafts and a pile of felt bundles.
static func _cart(k: Kit, pos: Vector3, yaw: float, scale: float) -> void:
	k.push(Kit.at(pos, yaw))
	var r := 0.17 * scale
	k.box(Vector3(0, r * 1.05, 0), Vector3(0.3 * scale, 0.03, 0.42 * scale), WOOD, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		_wheel(k, Vector3(s * 0.17 * scale, r, 0), PI / 2.0, r, 0.035)
		k.box(Vector3(s * 0.14 * scale, r * 1.05 + 0.03, 0), Vector3(0.02, 0.05, 0.42 * scale), WOOD, Kit.TIMBER)
		k.rod(Vector3(s * 0.07 * scale, r * 1.1, 0.2 * scale), Vector3(s * 0.02 * scale, r * 1.0, 0.42 * scale), 0.011, WOOD, Kit.TIMBER)
	for i in 3:
		k.box(Vector3(-0.07 * scale + i * 0.07 * scale, r * 1.05 + 0.03, -0.05 * scale), Vector3(0.06 * scale, 0.07 * scale, 0.1 * scale), Color(0.7, 0.55, 0.35), Kit.CLOTH)
	k.pop()


static func _hitch(k: Kit, foot: Vector3) -> void:
	k.box(foot, Vector3(0.03, 0.17, 0.03), WOOD, Kit.TIMBER)
	k.box(foot + Vector3(0, 0.17, 0), Vector3(0.05, 0.03, 0.05), Color(0.8, 0.65, 0.3), Kit.GOLD)
	k.rod(foot + Vector3(0, 0.12, 0), foot + Vector3(0.1, 0.03, 0.06), 0.005, ROPE, Kit.CLOTH)


static func _bundle(k: Kit, foot: Vector3) -> void:
	k.box(foot, Vector3(0.12, 0.05, 0.08), Color(0.62, 0.42, 0.2), Kit.TIMBER)
	k.dome(foot + Vector3(0, 0.05, 0), 0.05, Color(0.72, 0.62, 0.42), Kit.CLOTH, 0.8, 2, 7)


## A horse-tail standard (tug): a pole with a spearhead, a crossbar and hanging tails.
static func _tug(k: Kit, foot: Vector3, h: float) -> void:
	k.cylinder(foot, 0.018, h, WOOD, Kit.TIMBER, 6)
	k.frustum(foot + Vector3(0, h, 0), 0.05, 0.05, 0.02, Color(0.9, 0.75, 0.3), Kit.GOLD, 8)
	k.frustum(foot + Vector3(0, h + 0.02, 0), 0.035, 0.0, 0.12, Color(0.9, 0.75, 0.3), Kit.GOLD, 6)
	k.box(foot + Vector3(0, h * 0.82, 0), Vector3(0.3, 0.018, 0.018), WOOD, Kit.TIMBER)
	for i in 9:   # nine tails round the ring
		var a := i * TAU / 9.0
		var top := foot + Vector3(cos(a) * 0.045, h - 0.01, sin(a) * 0.045)
		var bot := foot + Vector3(cos(a) * 0.09, h * 0.52 - (i % 3) * 0.04, sin(a) * 0.09)
		k.rod(top, bot, 0.008, HAIR if i % 3 != 0 else Color(0.9, 0.88, 0.82), Kit.CLOTH)
	for s: float in [-1.0, 1.0]:
		for j in 3:
			k.rod(foot + Vector3(s * (0.04 + j * 0.05), h * 0.82, 0), foot + Vector3(s * (0.07 + j * 0.05), h * 0.6 - j * 0.03, 0), 0.007, HAIR, Kit.CLOTH)


# --- great tent: the khan's court --------------------------------------------------------------------


static func _great_tent(k: Kit) -> void:
	var gold := Color(0.9, 0.75, 0.3)
	# trampled ground
	k.box(Vector3(0, 0, 0), Vector3(2.9, 0.02, 2.9), Color(0.58, 0.5, 0.34), Kit.EARTH)
	# fenced enclosure with a gate at the front
	var e := 1.42
	for i in 15:
		var t := -e + i * (2.0 * e / 14.0)
		for pos: Vector3 in [Vector3(t, 0, -e), Vector3(-e, 0, t), Vector3(e, 0, t)]:
			k.box(pos, Vector3(0.05, 0.2, 0.05), WOOD, Kit.TIMBER)
		if absf(t) > 0.3:
			k.box(Vector3(t, 0, e), Vector3(0.05, 0.2, 0.05), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.08, -e), Vector3(2.9, 0.025, 0.03), WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.15, -e), Vector3(2.9, 0.025, 0.03), WOOD, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * e, 0.08, 0), Vector3(0.03, 0.025, 2.9), WOOD, Kit.TIMBER)
		k.box(Vector3(s * e, 0.15, 0), Vector3(0.03, 0.025, 2.9), WOOD, Kit.TIMBER)
		k.box(Vector3(s * 0.78, 0.08, e), Vector3(1.28, 0.025, 0.03), WOOD, Kit.TIMBER)
		k.box(Vector3(s * 0.78, 0.15, e), Vector3(1.28, 0.025, 0.03), WOOD, Kit.TIMBER)
		k.box(Vector3(s * 0.32, 0, e), Vector3(0.07, 0.42, 0.07), RED, Kit.PAINT)
		k.box(Vector3(s * 0.32, 0.42, e), Vector3(0.1, 0.05, 0.1), gold, Kit.GOLD)
	k.box(Vector3(0, 0.38, e), Vector3(0.65, 0.04, 0.05), RED, Kit.PAINT)
	# carpet path to the great door
	k.box(Vector3(0, 0.02, 0.85), Vector3(0.3, 0.012, 1.45), Color(0.6, 0.15, 0.12), Kit.CLOTH)
	# smaller tents joined to the great one by felt passages
	var main := Vector3(0, 0, -0.05)
	for s: float in [-1.0, 1.0]:
		k.box(main + Vector3(s * 0.7, 0, 0), Vector3(0.45, 0.2, 0.17), FELT_D, Kit.CLOTH)
		_ger(k, main + Vector3(s * 1.08, 0, 0.0), s * PI / 2.0, 0.34, 0.26, 0.2, FELT, BLUE, ORANGE, true)
	k.box(main + Vector3(0, 0, -0.7), Vector3(0.17, 0.2, 0.3), FELT_D, Kit.CLOTH)
	_ger(k, main + Vector3(0, 0, -0.98), PI, 0.34, 0.26, 0.2, FELT, BLUE, ORANGE, true)
	# the great tent itself
	_ger(k, main, 0.0, 0.7, 0.46, 0.44, Color(0.97, 0.95, 0.9), RED, gold, true)
	k.frustum(main + Vector3(0, 0.92, 0), 0.07, 0.0, 0.14, gold, Kit.GOLD, 8)
	k.frustum(main + Vector3(0, 0.88, 0), 0.06, 0.06, 0.05, gold, Kit.GOLD, 8)
	# an awning porch in front of the door, on painted posts
	var fz := main.z + 0.7
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.2, 0, fz + 0.3), Vector3(0.04, 0.3, 0.04), RED, Kit.PAINT)
	k.quad(Vector3(-0.28, 0.4, fz - 0.02), Vector3(0.28, 0.4, fz - 0.02), Vector3(0.28, 0.31, fz + 0.34), Vector3(-0.28, 0.31, fz + 0.34),
		Color.WHITE, Kit.OWNER_CLOTH, Vector3(0, 0.0, fz + 0.15))
	k.quad(Vector3(-0.28, 0.4, fz - 0.02), Vector3(-0.28, 0.31, fz + 0.34), Vector3(0.28, 0.31, fz + 0.34), Vector3(0.28, 0.4, fz - 0.02),
		Color.WHITE.darkened(0.3), Kit.OWNER_CLOTH, Vector3(0, 2.0, fz + 0.15))
	# banners and horse-tail standards
	k.banner(Vector3(-0.45, 0, fz + 0.45), 0.8, 0.26, 0.2)
	k.banner(Vector3(0.45, 0, fz + 0.45), 0.8, 0.26, -0.2)
	_tug(k, Vector3(-0.75, 0, 0.95), 0.9)
	_tug(k, Vector3(0.75, 0, 0.95), 0.9)
	# the cooking fire with a cauldron, a cart and some horses' water trough
	k.frustum(Vector3(-1.0, 0, 0.7), 0.1, 0.1, 0.05, Color(0.3, 0.28, 0.26), Kit.STONE, 8)
	k.frustum(Vector3(-1.0, 0.04, 0.7), 0.07, 0.09, 0.09, Color(0.14, 0.12, 0.11), Kit.DARK, 8)
	_cart(k, Vector3(1.05, 0, 0.95), 0.5, 1.0)
	k.box(Vector3(0.95, 0, -1.1), Vector3(0.3, 0.07, 0.1), WOOD, Kit.TIMBER)
	k.box(Vector3(0.95, 0.06, -1.1), Vector3(0.26, 0.01, 0.07), Color(0.25, 0.45, 0.6), Kit.WATER)


# --- wagon tent ------------------------------------------------------------------------------------------


static func _wagon_tent(k: Kit) -> void:
	var cz := -0.28
	var r := 0.22
	k.box(Vector3(0, r * 1.05, cz), Vector3(0.58, 0.04, 0.66), WOOD, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		_wheel(k, Vector3(s * 0.33, r, cz), PI / 2.0, r, 0.045)
		k.box(Vector3(s * 0.29, r * 1.05 + 0.04, cz), Vector3(0.025, 0.05, 0.66), Color(0.3, 0.2, 0.12), Kit.TIMBER)
	k.box(Vector3(0, r - 0.015, cz), Vector3(0.7, 0.03, 0.03), Color(0.3, 0.2, 0.12), Kit.TIMBER)   # axle
	_ger(k, Vector3(0, r * 1.05 + 0.04, cz), 0.0, 0.26, 0.17, 0.16, FELT, ORANGE, RED, true)
	# the draught pole, yoke and a pair of oxen
	k.rod(Vector3(-0.1, r * 1.1, cz + 0.3), Vector3(-0.1, 0.2, 0.55), 0.012, WOOD, Kit.TIMBER)
	k.rod(Vector3(0.1, r * 1.1, cz + 0.3), Vector3(0.1, 0.2, 0.55), 0.012, WOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.2, 0.55), Vector3(0.4, 0.025, 0.03), WOOD, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		_ox(k, Vector3(s * 0.15, 0, 0.3))
	k.box(Vector3(0.0, r * 1.05 + 0.04, cz + 0.36), Vector3(0.1, 0.02, 0.08), Color(0.5, 0.3, 0.1), Kit.TIMBER)


static func _ox(k: Kit, foot: Vector3) -> void:
	var hide := Color(0.36, 0.24, 0.16)
	k.push(Kit.at(foot))
	k.box(Vector3(0, 0.1, 0), Vector3(0.11, 0.11, 0.3), hide, Kit.CLOTH)
	k.box(Vector3(0, 0.15, 0.1), Vector3(0.09, 0.12, 0.09), hide.darkened(0.1), Kit.CLOTH)   # hump
	k.box(Vector3(0, 0.12, 0.25), Vector3(0.07, 0.08, 0.12), hide.lightened(0.05), Kit.CLOTH)   # head
	for s: float in [-1.0, 1.0]:
		k.rod(Vector3(s * 0.03, 0.2, 0.3), Vector3(s * 0.07, 0.25, 0.3), 0.008, Color(0.9, 0.86, 0.75), Kit.PAINT)
		for z in [-0.1, 0.1]:
			k.box(Vector3(s * 0.035, 0, z), Vector3(0.03, 0.1, 0.03), hide.darkened(0.2), Kit.CLOTH)
	k.pop()
