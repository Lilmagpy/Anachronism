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
	var all: Array = ["yurt_1", "yurt_2", "yurt_3", "great_tent", "wagon_tent"]
	var names: Array = _rows().keys()
	names.sort()
	all.append_array(names)
	all.append_array(BIG_KINDS)
	all.append_array(PROP_KINDS)
	return all


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	var row: Dictionary = _rows().get(kind, {})
	if not row.is_empty():
		_from_row(k, row)
		return k.finish()
	if kind.begins_with("ger_cluster"):
		_cluster(k, kind)
		return k.finish()
	if kind.begins_with("prop_"):
		_prop(k, kind)
		return k.finish()
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


# =================================================================================================
# Many more gers and tents (D-281): size, felt, door colour, painted bands, smoke-hole cap, porch,
# stove pipe, and what stands beside each (cart, saddles, dung stacks, a sheep pen, a horse).
# =================================================================================================

const FELTS := {"white": Color(0.95, 0.93, 0.86), "cream": Color(0.92, 0.86, 0.72), "grey": Color(0.74, 0.72, 0.66),
	"brown": Color(0.60, 0.52, 0.40), "dark": Color(0.45, 0.40, 0.34), "tan": Color(0.82, 0.72, 0.55)}
const DOORS := {"red": Color(0.65, 0.16, 0.12), "blue": Color(0.18, 0.36, 0.62), "orange": Color(0.80, 0.38, 0.14),
	"green": Color(0.22, 0.45, 0.28), "wood": Color(0.40, 0.27, 0.16), "yellow": Color(0.85, 0.65, 0.18)}
const BIG_KINDS := ["ger_cluster_1", "ger_cluster_2", "ger_cluster_3", "ger_cluster_4"]
const PROP_KINDS := ["prop_horse_tether", "prop_ovoo", "prop_tug", "prop_felt_rack", "prop_wagon"]
static var _rows_cache := {}


static func _rows() -> Dictionary:
	if not _rows_cache.is_empty():
		return _rows_cache
	var t := {}
	t["yurt_4"] = {"fam": "ger", "r": 0.38, "felt": "white", "door": "red", "band": "blue", "pat": "stripes", "ropes": 2, "crown": "cap",
		"bits": [["dung", 0.4, 0.3, 0.0], ["hitch", -0.38, 0.34, 0.0]]}
	t["yurt_5"] = {"fam": "ger", "r": 0.34, "felt": "grey", "door": "wood", "band": "wood", "pat": "none", "ropes": 1, "crown": "pipe",
		"porch": true, "bits": [["bundle", 0.4, 0.3, 0.0], ["dung", -0.4, 0.2, 0.0]]}
	t["yurt_6"] = {"fam": "ger", "r": 0.43, "wh": 0.22, "rh": 0.2, "felt": "cream", "door": "blue", "owner": true, "pat": "bands", "ropes": 3,
		"crown": "ring", "porch": true, "bits": [["rug", 0.0, 0.58, 0.0], ["hitch", 0.46, 0.2, 0.0]]}
	t["yurt_7"] = {"fam": "ger", "r": 0.3, "wh": 0.17, "rh": 0.16, "felt": "dark", "door": "orange", "band": "orange", "pat": "none", "ropes": 1,
		"crown": "cap", "bits": [["bundle", -0.4, 0.3, 0.0], ["bundle", 0.38, 0.34, 0.0], ["dung", 0.0, -0.44, 0.0]]}
	t["yurt_8"] = {"fam": "ger", "r": 0.35, "felt": "white", "door": "green", "band": "green", "pat": "stripes", "ropes": 2, "crown": "ring",
		"ox": -0.14, "bits": [["cart", 0.42, 0.14, -0.5], ["hitch", -0.4, 0.4, 0.0]]}
	t["yurt_9"] = {"fam": "ger", "r": 0.37, "felt": "cream", "door": "red", "band": "red", "pat": "bands", "ropes": 2, "crown": "cap",
		"lean": true, "ox": -0.1, "bits": [["saddle", 0.34, 0.4, 0.0], ["dung", -0.4, -0.2, 0.0]]}
	t["yurt_10"] = {"fam": "ger", "r": 0.31, "wh": 0.27, "rh": 0.2, "felt": "tan", "door": "red", "band": "yellow", "pat": "stripes", "ropes": 2,
		"crown": "ring", "bits": [["stool", 0.0, 0.5, 0.0], ["bundle", -0.4, 0.3, 0.0]]}
	t["yurt_11"] = {"fam": "ger", "r": 0.46, "wh": 0.17, "rh": 0.14, "felt": "grey", "door": "blue", "band": "blue", "pat": "stripes", "ropes": 2,
		"crown": "pipe", "bits": [["sheep", -0.4, 0.34, 0.0], ["dung", 0.46, 0.0, 0.0]]}
	t["yurt_12"] = {"fam": "ger", "r": 0.39, "felt": "white", "door": "orange", "band": "red", "pat": "diamonds", "ropes": 1, "crown": "cap",
		"bits": [["rack", 0.42, 0.2, 0.3], ["pot", -0.36, 0.38, 0.0]]}
	t["yurt_13"] = {"fam": "ger", "r": 0.36, "felt": "cream", "door": "green", "band": "yellow", "pat": "bands", "ropes": 2, "crown": "ring",
		"porch": true, "bits": [["rug", 0.0, 0.56, 0.0], ["stool", 0.18, 0.5, 0.0], ["fire", -0.38, 0.4, 0.0]]}
	t["yurt_14"] = {"fam": "ger", "r": 0.34, "felt": "brown", "door": "wood", "band": "orange", "pat": "none", "ropes": 2, "crown": "cap",
		"ox": -0.12, "bits": [["pen", 0.42, 0.1, 0.0], ["sheep", 0.42, 0.1, 0.0]]}
	t["yurt_15"] = {"fam": "ger", "r": 0.37, "felt": "white", "door": "blue", "band": "blue", "pat": "diamonds", "ropes": 2, "crown": "ring",
		"ox": -0.1, "bits": [["horse", 0.4, 0.3, 0.7], ["hitch", 0.3, 0.46, 0.0]]}
	t["yurt_16"] = {"fam": "ger", "r": 0.33, "wh": 0.2, "rh": 0.2, "felt": "tan", "door": "yellow", "band": "red", "pat": "stripes", "ropes": 1,
		"crown": "pipe", "lean": true, "ox": -0.1, "bits": [["churn", 0.38, 0.36, 0.0], ["dung", -0.36, -0.3, 0.0]]}
	t["tent_cone_1"] = {"fam": "cone", "r": 0.3, "h": 0.5, "felt": "grey", "bits": [["bundle", 0.36, 0.3, 0.0], ["fire", -0.3, 0.36, 0.0]]}
	t["tent_cone_2"] = {"fam": "cone", "r": 0.36, "h": 0.46, "felt": "cream", "stripe": "red", "bits": [["horse", 0.4, 0.24, 0.5]]}
	t["tent_a_1"] = {"fam": "atent", "w": 0.6, "d": 0.46, "h": 0.3, "felt": "brown", "bits": [["fire", 0.0, 0.44, 0.0], ["saddle", 0.4, 0.36, 0.0]]}
	t["tent_a_2"] = {"fam": "atent", "w": 0.72, "d": 0.5, "h": 0.34, "felt": "white", "stripe": "blue", "awning": true,
		"bits": [["bundle", -0.4, 0.4, 0.0], ["dung", 0.4, -0.4, 0.0]]}
	t["tent_lean_1"] = {"fam": "lean", "felt": "dark", "bits": [["fire", 0.0, 0.2, 0.0], ["bundle", -0.36, 0.0, 0.0]]}
	t["tent_dome_1"] = {"fam": "dome", "r": 0.34, "felt": "tan", "door": "red", "bits": [["cart", 0.4, 0.24, -0.4], ["hitch", -0.36, 0.36, 0.0]]}
	t["wagon_supply_1"] = {"fam": "wagon", "load": "covered", "felt": "cream", "ox": true}
	t["wagon_supply_2"] = {"fam": "wagon", "load": "bundles", "felt": "grey"}
	t["wagon_supply_3"] = {"fam": "wagon", "load": "barrels", "felt": "white", "ox": true}
	t["wagon_supply_4"] = {"fam": "wagon", "load": "sacks", "felt": "tan"}
	_rows_cache = t
	return t


static func _plate(k: Kit, x0: float, y0: float, x1: float, y1: float, col: Color, mat: int, z := 0.006) -> void:
	k.quad(Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), col, mat,
		Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, -1.0))


## A ring of facets round a cone slice, alternate facets in `b` (a painted band or stripes).
static func _ring(k: Kit, y: float, r0: float, r1: float, h: float, sides: int, a: Color, b: Color, mat: int, every := 2) -> void:
	var c := Vector3(0, y + h * 0.5, 0)
	for i in sides:
		var a0 := i * TAU / sides
		var a1 := (i + 1) * TAU / sides
		var col := b if i % every == 0 else a
		k.quad(Vector3(cos(a0) * r0, y, sin(a0) * r0), Vector3(cos(a1) * r0, y, sin(a1) * r0),
			Vector3(cos(a1) * r1, y + h, sin(a1) * r1), Vector3(cos(a0) * r1, y + h, sin(a0) * r1), col, mat, c)


## A ger in full: see the rows for the parameters.
static func _ger2(k: Kit, pos: Vector3, yaw: float, g: Dictionary) -> void:
	var r: float = g.get("r", 0.38)
	var wh: float = g.get("wh", 0.2)
	var rh: float = g.get("rh", 0.19)
	var sides := 14 if r > 0.36 else 10
	var felt: Color = FELTS.get(str(g.get("felt", "white")), FELT)
	var door_c: Color = DOORS.get(str(g.get("door", "red")), RED)
	var band_c: Color = DOORS.get(str(g.get("band", g.get("door", "red"))), RED)
	var owner: bool = g.get("owner", false)
	var pat: String = g.get("pat", "none")
	k.push(Kit.at(pos, yaw))
	k.frustum(Vector3.ZERO, r * 1.025, r * 1.025, wh * 0.26, felt.darkened(0.28), Kit.CLOTH, sides, false)
	k.frustum(Vector3(0, wh * 0.26, 0), r, r, wh * 0.74, felt, Kit.CLOTH, sides, false)
	k.frustum(Vector3(0, wh, 0), r * 1.1, r * 0.2, rh, felt.darkened(0.04), Kit.CLOTH, sides)
	# eave band: owner colour, painted, or striped in alternate facets
	var eave := wh - 0.002
	if owner:
		k.frustum(Vector3(0, eave, 0), r * 1.101, r * 1.09, 0.045, Color.WHITE, Kit.OWNER_CLOTH, sides, false)
	elif pat == "stripes":
		_ring(k, eave, r * 1.101, r * 1.09, 0.05, sides, felt.darkened(0.06), band_c, Kit.PAINT)
	else:
		k.frustum(Vector3(0, eave, 0), r * 1.101, r * 1.09, 0.045, band_c, Kit.PAINT, sides, false)
	if pat == "bands":
		var rr := lerpf(r * 1.1, r * 0.2, 0.45)
		k.frustum(Vector3(0, wh + rh * 0.45, 0), rr * 1.01, rr * 0.97, 0.035, band_c, Kit.PAINT, sides, false)
	elif pat == "diamonds":
		var y0 := wh + rh * 0.3
		_ring(k, y0, lerpf(r * 1.1, r * 0.2, 0.3) * 1.01, lerpf(r * 1.1, r * 0.2, 0.55) * 1.01, rh * 0.25, sides, felt.darkened(0.04), band_c, Kit.PAINT)
	var ropes: int = g.get("ropes", 2)
	for i in ropes:
		var t := 0.3 + i * 0.28
		var rr := lerpf(r * 1.1, r * 0.2, t)
		k.frustum(Vector3(0, wh + rh * t, 0), rr * 1.02, rr * 1.0, 0.018, ROPE, Kit.CLOTH, sides, false)
	k.frustum(Vector3(0, wh * 0.5, 0), r * 1.012, r * 1.012, 0.018, ROPE, Kit.CLOTH, sides, false)
	# crown
	var top := wh + rh
	match str(g.get("crown", "ring")):
		"cap":   # a felt cover pulled half over the smoke hole, held by a cord
			k.frustum(Vector3(0, top - 0.004, 0), r * 0.26, r * 0.1, 0.05, felt.darkened(0.08), Kit.CLOTH, 8)
			k.rod(Vector3(r * 0.2, top + 0.03, 0), Vector3(r * 0.5, top - rh * 0.3, 0), 0.006, ROPE, Kit.CLOTH)
		"pipe":
			k.frustum(Vector3(0, top - 0.005, 0), r * 0.23, r * 0.2, 0.035, WOOD, Kit.TIMBER, 8)
			k.rod(Vector3(r * 0.12, top, 0), Vector3(r * 0.12, top + 0.2, 0), 0.014, Color(0.2, 0.2, 0.22), Kit.DARK)
			k.box(Vector3(r * 0.12, top + 0.2, 0), Vector3(0.05, 0.02, 0.05), Color(0.2, 0.2, 0.22), Kit.DARK)
		_:
			k.frustum(Vector3(0, top - 0.005, 0), r * 0.23, r * 0.2, 0.04, WOOD, Kit.TIMBER, 8)
			k.frustum(Vector3(0, top + 0.036, 0), r * 0.13, r * 0.13, 0.004, Color(0.06, 0.04, 0.03), Kit.DARK, 8)
	# the door, trellis beside it, felt flap above
	var ap := r * cos(PI / sides)
	k.push(Kit.at(Vector3(0, 0, ap)))
	var dw := minf(0.15, r * 0.4)
	_plate(k, -dw / 2.0 - 0.02, 0.0, dw / 2.0 + 0.02, wh * 0.86, door_c.darkened(0.15), Kit.PAINT, 0.004)
	_plate(k, -dw / 2.0, 0.0, dw / 2.0, wh * 0.8, door_c, Kit.PAINT, 0.008)
	_plate(k, -0.006, 0.0, 0.006, wh * 0.8, door_c.darkened(0.35), Kit.PAINT, 0.011)
	k.box(Vector3(0, wh * 0.86, 0.01), Vector3(dw + 0.07, 0.04, 0.025), felt.darkened(0.12), Kit.CLOTH)
	for s: float in [-1.0, 1.0]:
		var x0 := s * (dw * 0.5 + 0.04)
		var x1 := s * (dw * 0.5 + 0.12)
		k.quad(Vector3(x0, 0.02, 0.004), Vector3(x1, wh * 0.7, 0.004), Vector3(x1 + 0.016, wh * 0.7, 0.004), Vector3(x0 + 0.016, 0.02, 0.004),
			WOOD, Kit.TIMBER, Vector3(x0, 0.1, -1.0))
		k.quad(Vector3(x1, 0.02, 0.004), Vector3(x0, wh * 0.7, 0.004), Vector3(x0 + 0.016, wh * 0.7, 0.004), Vector3(x1 + 0.016, 0.02, 0.004),
			WOOD, Kit.TIMBER, Vector3(x0, 0.1, -1.0))
	if g.get("porch", false):   # a felt awning on two sticks over the door
		for s: float in [-1.0, 1.0]:
			k.rod(Vector3(s * 0.12, 0.0, 0.2), Vector3(s * 0.12, wh * 0.82, 0.2), 0.008, WOOD, Kit.TIMBER)
		k.quad(Vector3(-0.15, wh * 0.9, 0.0), Vector3(0.15, wh * 0.9, 0.0), Vector3(0.15, wh * 0.78, 0.22), Vector3(-0.15, wh * 0.78, 0.22),
			felt.darkened(0.1), Kit.CLOTH, Vector3(0, 0, 0.1))
		k.quad(Vector3(-0.15, wh * 0.9, 0.0), Vector3(-0.15, wh * 0.78, 0.22), Vector3(0.15, wh * 0.78, 0.22), Vector3(0.15, wh * 0.9, 0.0),
			felt.darkened(0.3), Kit.CLOTH, Vector3(0, 3.0, 0.1))
	k.pop()
	if g.get("lean", false):   # a lean-to storage shed of felt against the wall
		k.push(Kit.at(Vector3(r * 0.95, 0, -r * 0.35), PI / 2.0 - 0.3))
		k.box(Vector3(0, 0, 0), Vector3(0.22, 0.13, 0.26), felt.darkened(0.12), Kit.CLOTH)
		k.wedge(Vector3(0, 0.13, 0), 0.26, 0.22, 0.07, felt.darkened(0.2), Kit.CLOTH, PI / 2.0)
		k.pop()
	k.pop()


## Things standing about a ger: name, x, z, yaw (or a size) in the model's frame.
static func _bit(k: Kit, what: String, x: float, z: float, a: float) -> void:
	match what:
		"cart":
			_cart(k, Vector3(x, 0, z), a, 0.7)
		"hitch":
			_hitch(k, Vector3(x, 0, z))
		"bundle":
			_bundle(k, Vector3(x, 0, z))
		"dung":   # stacked dung cakes drying for fuel
			k.box(Vector3(x, 0, z), Vector3(0.14, 0.06, 0.08), Color(0.42, 0.32, 0.2), Kit.EARTH)
			k.box(Vector3(x + 0.01, 0.06, z), Vector3(0.1, 0.05, 0.07), Color(0.45, 0.34, 0.22), Kit.EARTH)
		"saddle":
			k.box(Vector3(x, 0, z), Vector3(0.03, 0.08, 0.03), WOOD, Kit.TIMBER)
			k.box(Vector3(x, 0.08, z), Vector3(0.14, 0.035, 0.07), Color(0.5, 0.2, 0.12), Kit.CLOTH)
		"stool":
			k.box(Vector3(x, 0, z), Vector3(0.07, 0.05, 0.07), Color(0.6, 0.2, 0.12), Kit.PAINT)
		"rug":
			k.box(Vector3(x, 0, z), Vector3(0.26, 0.006, 0.18), Color(0.6, 0.15, 0.12), Kit.CLOTH)
			k.box(Vector3(x, 0.006, z), Vector3(0.2, 0.004, 0.12), Color(0.18, 0.3, 0.55), Kit.CLOTH)
		"fire":
			k.frustum(Vector3(x, 0, z), 0.07, 0.07, 0.03, Color(0.4, 0.38, 0.35), Kit.STONE, 6)
			k.frustum(Vector3(x, 0.03, z), 0.045, 0.0, 0.07, Color(0.9, 0.5, 0.15), Kit.GOLD, 5)
		"pot":
			k.frustum(Vector3(x, 0, z), 0.06, 0.06, 0.03, Color(0.4, 0.38, 0.35), Kit.STONE, 6)
			k.frustum(Vector3(x, 0.03, z), 0.05, 0.065, 0.07, Color(0.14, 0.12, 0.11), Kit.DARK, 6)
		"churn":   # a tall leather bag of fermenting mare's milk on a stand
			k.frustum(Vector3(x, 0, z), 0.04, 0.06, 0.14, Color(0.5, 0.36, 0.22), Kit.CLOTH, 6)
			k.rod(Vector3(x + 0.03, 0.05, z), Vector3(x + 0.07, 0.18, z), 0.008, WOOD, Kit.TIMBER)
		"sheep":
			for i in 3:
				k.dome(Vector3(x + (i - 1) * 0.07, 0.0, z + (i % 2) * 0.06), 0.04, Color(0.9, 0.88, 0.8), Kit.CLOTH, 0.9, 2, 5)
		"pen":
			for s: float in [-1.0, 1.0]:
				k.box(Vector3(x + s * 0.13, 0, z), Vector3(0.012, 0.06, 0.24), WOOD, Kit.TIMBER)
			k.box(Vector3(x, 0, z - 0.12), Vector3(0.26, 0.06, 0.012), WOOD, Kit.TIMBER)
		"rack":   # a rack of drying felt and strips of meat
			_felt_rack(k, Vector3(x, 0, z), a, 0.7)
		"horse":
			_horse(k, Vector3(x, 0, z), a, Color(0.45, 0.30, 0.18))


## A low-poly horse standing at `foot`, turned `yaw`.
static func _horse(k: Kit, foot: Vector3, yaw: float, hide: Color) -> void:
	k.push(Kit.at(foot, yaw))
	k.box(Vector3(0, 0.11, 0), Vector3(0.075, 0.085, 0.2), hide, Kit.CLOTH)
	k.rod(Vector3(0, 0.17, 0.08), Vector3(0, 0.25, 0.14), 0.026, hide, Kit.CLOTH)
	k.rod(Vector3(0, 0.25, 0.14), Vector3(0, 0.21, 0.2), 0.02, hide.lightened(0.05), Kit.CLOTH)
	k.rod(Vector3(0, 0.17, -0.1), Vector3(0, 0.08, -0.14), 0.01, HAIR, Kit.CLOTH)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.frustum(Vector3(sx * 0.025, 0, sz * 0.075), 0.011, 0.008, 0.11, hide.darkened(0.2), Kit.CLOTH, 3, false)
	k.pop()


## A rack of drying felt sheets and meat strips on a post frame.
static func _felt_rack(k: Kit, foot: Vector3, yaw: float, sc: float) -> void:
	k.push(Kit.at(foot, yaw))
	for s: float in [-1.0, 1.0]:
		k.rod(Vector3(s * 0.15 * sc, 0, 0), Vector3(s * 0.15 * sc, 0.2 * sc, 0), 0.01, WOOD, Kit.TIMBER)
	k.rod(Vector3(-0.16 * sc, 0.2 * sc, 0), Vector3(0.16 * sc, 0.2 * sc, 0), 0.008, WOOD, Kit.TIMBER)
	k.rod(Vector3(-0.16 * sc, 0.1 * sc, 0), Vector3(0.16 * sc, 0.1 * sc, 0), 0.008, WOOD, Kit.TIMBER)
	k.box(Vector3(-0.07 * sc, 0.05 * sc, 0), Vector3(0.1 * sc, 0.15 * sc, 0.012), FELT_D, Kit.CLOTH)
	k.box(Vector3(0.07 * sc, 0.1 * sc, 0), Vector3(0.09 * sc, 0.1 * sc, 0.012), Color(0.72, 0.62, 0.42), Kit.CLOTH)
	k.pop()


# --- other tents ------------------------------------------------------------------------------------------


static func _cone_tent(k: Kit, g: Dictionary) -> void:
	var r: float = g.get("r", 0.3)
	var h: float = g.get("h", 0.5)
	var felt: Color = FELTS.get(str(g.get("felt", "grey")), FELT)
	k.frustum(Vector3.ZERO, r * 1.02, r * 1.02, 0.03, felt.darkened(0.25), Kit.CLOTH, 8, false)
	k.frustum(Vector3(0, 0.03, 0), r, 0.03, h, felt, Kit.CLOTH, 8)
	if g.has("stripe"):
		_ring(k, 0.03 + h * 0.2, r * 0.8 * 1.01, r * 0.6 * 1.01, h * 0.15, 8, felt, DOORS.get(str(g["stripe"]), RED), Kit.PAINT)
	for i in 5:   # the tent poles crossing at the top
		var a := i * TAU / 5.0
		k.rod(Vector3(cos(a) * r * 0.5, 0.03 + h * 0.5, sin(a) * r * 0.5), Vector3(0, h + 0.14, 0), 0.008, WOOD, Kit.TIMBER)
	var ap := r * cos(PI / 8.0)
	k.quad(Vector3(-0.07, 0.0, ap - 0.0), Vector3(0.07, 0.0, ap - 0.0), Vector3(0.0, 0.2, ap * 0.7), Vector3(0.0, 0.2, ap * 0.7),
		HAIR, Kit.DARK, Vector3(0, 0.1, 0))
	k.tri(Vector3(-0.07, 0.0, ap * 0.99), Vector3(0.07, 0.0, ap * 0.99), Vector3(0.0, 0.2, ap * 0.72), HAIR, Kit.DARK, Vector3(0, 0.1, 0))


static func _a_tent(k: Kit, g: Dictionary) -> void:
	var w: float = g.get("w", 0.6)
	var d: float = g.get("d", 0.46)
	var h: float = g.get("h", 0.3)
	var felt: Color = FELTS.get(str(g.get("felt", "brown")), FELT)
	k.gable_roof(Vector3(0, 0, 0), w, d, h, 0.03, 0.02, felt, Kit.CLOTH, felt.darkened(0.1), Kit.CLOTH)
	if g.has("stripe"):
		k.box(Vector3(0, h - 0.01, 0), Vector3(w + 0.08, 0.025, 0.05), DOORS.get(str(g["stripe"]), RED), Kit.PAINT)
	for s: float in [-1.0, 1.0]:   # ridge poles standing proud at each end
		k.rod(Vector3(s * (w / 2.0 + 0.03), 0, 0), Vector3(s * (w / 2.0 + 0.03), h + 0.1, 0), 0.01, WOOD, Kit.TIMBER)
	k.rod(Vector3(-w / 2.0 - 0.03, h + 0.1, 0), Vector3(w / 2.0 + 0.03, h + 0.1, 0), 0.008, WOOD, Kit.TIMBER)
	k.push(Kit.at(Vector3(w / 2.0 - 0.03, 0, 0), PI / 2.0))
	_plate(k, -0.1, 0.0, 0.1, h * 0.6, Color(0.1, 0.07, 0.05), Kit.DARK, 0.01)
	k.pop()
	if g.get("awning", false):
		for s: float in [-1.0, 1.0]:
			k.rod(Vector3(s * 0.2, 0, d / 2.0 + 0.2), Vector3(s * 0.2, 0.2, d / 2.0 + 0.2), 0.008, WOOD, Kit.TIMBER)
		k.quad(Vector3(-0.25, 0.2, d / 2.0 + 0.2), Vector3(0.25, 0.2, d / 2.0 + 0.2), Vector3(0.25, h * 0.55, d / 2.0 - 0.02),
			Vector3(-0.25, h * 0.55, d / 2.0 - 0.02), Color.WHITE, Kit.OWNER_CLOTH, Vector3(0, 0, d / 2.0 + 0.1))


static func _lean_tent(k: Kit, g: Dictionary) -> void:
	var felt: Color = FELTS.get(str(g.get("felt", "dark")), FELT)
	for s: float in [-1.0, 1.0]:
		k.rod(Vector3(s * 0.3, 0, -0.12), Vector3(s * 0.3, 0.3, -0.12), 0.012, WOOD, Kit.TIMBER)
		k.rod(Vector3(s * 0.3, 0, 0.18), Vector3(s * 0.3, 0.14, 0.18), 0.012, WOOD, Kit.TIMBER)
	k.quad(Vector3(-0.34, 0.3, -0.14), Vector3(0.34, 0.3, -0.14), Vector3(0.34, 0.14, 0.22), Vector3(-0.34, 0.14, 0.22), felt, Kit.CLOTH, Vector3(0, 0.0, 0.0))
	k.quad(Vector3(-0.34, 0.3, -0.14), Vector3(-0.34, 0.14, 0.22), Vector3(0.34, 0.14, 0.22), Vector3(0.34, 0.3, -0.14), felt.darkened(0.3), Kit.CLOTH, Vector3(0, 3.0, 0.0))
	k.quad(Vector3(-0.34, 0.3, -0.14), Vector3(0.34, 0.3, -0.14), Vector3(0.34, 0.0, -0.14), Vector3(-0.34, 0.0, -0.14), felt.darkened(0.1), Kit.CLOTH, Vector3(0, 0.1, 0.5))
	k.box(Vector3(0, 0, -0.04), Vector3(0.5, 0.01, 0.2), Color(0.55, 0.15, 0.12), Kit.CLOTH)


static func _dome_tent(k: Kit, g: Dictionary) -> void:
	var r: float = g.get("r", 0.34)
	var felt: Color = FELTS.get(str(g.get("felt", "tan")), FELT)
	var door_c: Color = DOORS.get(str(g.get("door", "red")), RED)
	k.frustum(Vector3.ZERO, r, r, 0.12, felt, Kit.CLOTH, 10, false)
	k.dome(Vector3(0, 0.12, 0), r, felt.darkened(0.04), Kit.CLOTH, 0.9, 4, 10)
	for i in [0, 2, 4]:
		k.frustum(Vector3(0, 0.12 + 0.05 * i, 0), r * (1.0 - i * 0.2) * 1.02, r * (1.0 - i * 0.2) * 1.01, 0.014, ROPE, Kit.CLOTH, 10, false)
	var ap := r * cos(PI / 10.0)
	_plate_at(k, ap, door_c)
	k.rod(Vector3(0, 0.12 + r * 0.9, 0), Vector3(0, 0.12 + r * 0.9 + 0.1, 0), 0.01, WOOD, Kit.TIMBER)


static func _plate_at(k: Kit, ap: float, door_c: Color) -> void:
	k.push(Kit.at(Vector3(0, 0, ap)))
	_plate(k, -0.07, 0.0, 0.07, 0.14, door_c, Kit.PAINT, 0.006)
	k.pop()


# --- supply wagons ------------------------------------------------------------------------------------------


static func _supply_wagon(k: Kit, g: Dictionary) -> void:
	var load_kind: String = g.get("load", "covered")
	var felt: Color = FELTS.get(str(g.get("felt", "cream")), FELT)
	var cz := -0.1
	var r := 0.17
	k.box(Vector3(0, r * 1.05, cz), Vector3(0.36, 0.035, 0.6), WOOD, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		_wheel(k, Vector3(s * 0.21, r, cz), PI / 2.0, r, 0.04)
		k.box(Vector3(s * 0.17, r * 1.05 + 0.035, cz), Vector3(0.02, 0.07, 0.6), WOOD, Kit.TIMBER)
	k.box(Vector3(0, r - 0.015, cz), Vector3(0.44, 0.03, 0.03), Color(0.3, 0.2, 0.12), Kit.TIMBER)
	var by := r * 1.05 + 0.035
	match load_kind:
		"covered":
			k.gable_roof(Vector3(0, by + 0.1, cz), 0.5, 0.34, 0.1, 0.0, 0.02, felt, Kit.CLOTH, felt.darkened(0.1), Kit.CLOTH, PI / 2.0)
			for s: float in [-1.0, 1.0]:
				k.box(Vector3(s * 0.16, by, cz), Vector3(0.015, 0.1, 0.46), WOOD, Kit.TIMBER)
			k.box(Vector3(0, by, cz - 0.24), Vector3(0.32, 0.1, 0.012), felt.darkened(0.1), Kit.CLOTH)
		"bundles":
			for i in 3:
				for j in 2:
					k.box(Vector3(-0.1 + j * 0.2, by + (i % 2) * 0.0, cz - 0.17 + i * 0.17), Vector3(0.15, 0.1, 0.14), Color(0.66, 0.5, 0.3) if (i + j) % 2 == 0 else felt, Kit.CLOTH)
			k.box(Vector3(0, by + 0.1, cz), Vector3(0.18, 0.08, 0.2), Color(0.5, 0.2, 0.12), Kit.CLOTH)
		"barrels":
			for i in 3:
				k.frustum(Vector3(-0.08 + (i % 2) * 0.16, by, cz - 0.15 + i * 0.15), 0.07, 0.07, 0.14, Color(0.5, 0.34, 0.18), Kit.TIMBER, 7)
		_:
			for i in 6:
				k.dome(Vector3(-0.09 + (i % 2) * 0.18, by, cz - 0.2 + (i / 2) * 0.2), 0.09, Color(0.82, 0.76, 0.6), Kit.CLOTH, 0.7, 2, 6)
	# draught pole and yoke
	k.rod(Vector3(-0.08, r * 1.1, cz + 0.28), Vector3(-0.08, 0.2, 0.56), 0.012, WOOD, Kit.TIMBER)
	k.rod(Vector3(0.08, r * 1.1, cz + 0.28), Vector3(0.08, 0.2, 0.56), 0.012, WOOD, Kit.TIMBER)
	if g.get("ox", false):
		k.box(Vector3(0, 0.2, 0.56), Vector3(0.36, 0.025, 0.03), WOOD, Kit.TIMBER)
		for s: float in [-1.0, 1.0]:
			_ox(k, Vector3(s * 0.12, 0, 0.34))


static func _from_row(k: Kit, g: Dictionary) -> void:
	var ox: float = g.get("ox", 0.0)
	match str(g.get("fam", "ger")):
		"ger":
			_ger2(k, Vector3(ox, 0, g.get("oz", 0.0)), 0.0, g)
		"cone":
			_cone_tent(k, g)
		"atent":
			_a_tent(k, g)
		"lean":
			_lean_tent(k, g)
		"dome":
			_dome_tent(k, g)
		"wagon":
			_supply_wagon(k, g)
	var bits: Array = g.get("bits", [])
	for b: Array in bits:
		_bit(k, str(b[0]), float(b[1]), float(b[2]), float(b[3]))


# --- two-lot family clusters (about 2.0 wide by 1.0 deep) ------------------------------------------------------


static func _cluster(k: Kit, kind: String) -> void:
	match kind:
		"ger_cluster_1":   # a big family ger with two small ones round a shared yard
			_ger2(k, Vector3(-0.55, 0, 0.0), 0.2, {"r": 0.43, "wh": 0.22, "felt": "cream", "door": "blue", "band": "blue", "pat": "stripes", "ropes": 3,
				"crown": "ring", "porch": true})
			_ger2(k, Vector3(0.45, 0, -0.2), -0.4, {"r": 0.3, "felt": "white", "door": "red", "band": "red", "pat": "bands", "crown": "cap"})
			_ger2(k, Vector3(0.62, 0, 0.3), -0.9, {"r": 0.27, "wh": 0.17, "rh": 0.15, "felt": "grey", "door": "wood", "band": "wood", "crown": "pipe"})
			_bit(k, "bundle", -0.05, 0.4, 0.5)
			_bit(k, "dung", -0.1, -0.3, 0.0)
			_bit(k, "hitch", 0.1, 0.1, 0.0)
		"ger_cluster_2":   # two gers, a sheep pen and a horse
			_ger2(k, Vector3(-0.5, 0, 0.0), 0.0, {"r": 0.4, "felt": "white", "door": "orange", "band": "red", "pat": "diamonds", "ropes": 2, "crown": "cap"})
			_ger2(k, Vector3(0.35, 0, -0.18), 0.5, {"r": 0.32, "felt": "tan", "door": "green", "band": "green", "pat": "stripes", "crown": "ring", "lean": true})
			_bit(k, "pen", 0.78, 0.25, 0.0)
			_bit(k, "sheep", 0.78, 0.25, 0.0)
			_bit(k, "horse", -0.1, 0.38, 0.4)
			_bit(k, "horse", 0.08, 0.4, -0.3)
		"ger_cluster_3":   # the khan's relatives: owner-coloured band on the main ger, wagons and a standard
			_ger2(k, Vector3(-0.3, 0, -0.05), 0.0, {"r": 0.46, "wh": 0.24, "rh": 0.2, "felt": "white", "door": "red", "owner": true, "pat": "bands",
				"ropes": 3, "crown": "ring", "porch": true})
			_ger2(k, Vector3(0.6, 0, 0.05), -0.3, {"r": 0.3, "felt": "cream", "door": "red", "band": "yellow", "pat": "stripes", "crown": "cap"})
			_tug(k, Vector3(0.1, 0, 0.45), 0.5)
			_bit(k, "rug", -0.3, 0.55, 0.0)
			_bit(k, "saddle", 0.3, 0.4, 0.0)
		"ger_cluster_4":   # a trading camp: a ger, a loaded wagon and a drying rack
			_ger2(k, Vector3(-0.55, 0, 0.0), 0.0, {"r": 0.38, "felt": "grey", "door": "blue", "band": "blue", "pat": "none", "ropes": 2, "crown": "pipe"})
			k.push(Kit.at(Vector3(0.45, 0, 0.0), -0.4))
			_supply_wagon(k, {"load": "bundles", "felt": "tan", "ox": false})
			k.pop()
			_bit(k, "rack", 0.0, -0.3, 0.0)
			_bit(k, "dung", -0.1, 0.4, 0.0)
			_bit(k, "bundle", 0.9, -0.3, 0.0)


# --- regional props ------------------------------------------------------------------------------------------------


static func _prop(k: Kit, kind: String) -> void:
	match kind:
		"prop_horse_tether":
			# a hitching line between two posts with three horses tied to it
			for s: float in [-1.0, 1.0]:
				k.rod(Vector3(s * 0.4, 0, 0), Vector3(s * 0.4, 0.17, 0), 0.012, WOOD, Kit.TIMBER)
			k.rod(Vector3(-0.4, 0.15, 0), Vector3(0.4, 0.13, 0), 0.006, ROPE, Kit.CLOTH)
			_horse(k, Vector3(-0.24, 0, 0.1), PI * 0.5 + 0.2, Color(0.45, 0.30, 0.18))
			_horse(k, Vector3(0.02, 0, 0.1), PI * 0.5 - 0.2, Color(0.80, 0.76, 0.68))
			_horse(k, Vector3(0.28, 0, 0.1), PI * 0.5 + 0.1, Color(0.22, 0.17, 0.14))
		"prop_ovoo":
			# a cairn of stones with sacred poles hung with blue scarves
			var st := Color(0.60, 0.58, 0.54)
			k.frustum(Vector3(0, 0, 0), 0.2, 0.15, 0.08, st, Kit.STONE, 7)
			k.frustum(Vector3(0, 0.08, 0), 0.14, 0.09, 0.07, st.darkened(0.08), Kit.STONE, 6)
			k.frustum(Vector3(0, 0.15, 0), 0.09, 0.03, 0.06, st.lightened(0.05), Kit.STONE, 5)
			for i in 6:
				var a := i * TAU / 6.0
				var top := Vector3(cos(a) * 0.045, 0.62 + (i % 3) * 0.04, sin(a) * 0.045)
				k.rod(Vector3(cos(a) * 0.1, 0.12, sin(a) * 0.1), top, 0.008, WOOD, Kit.TIMBER)
			for i in 4:
				var a := i * TAU / 4.0 + 0.4
				var p0 := Vector3(cos(a) * 0.05, 0.6, sin(a) * 0.05)
				k.quad(p0, p0 + Vector3(cos(a) * 0.12, -0.05, sin(a) * 0.12), p0 + Vector3(cos(a) * 0.12, -0.12, sin(a) * 0.12), p0 + Vector3(0, -0.07, 0),
					BLUE if i % 2 == 0 else Color(0.8, 0.8, 0.78), Kit.CLOTH, Vector3(0, 0.3, 0))
			k.rod(Vector3(-0.15, 0.12, 0.1), Vector3(0.13, 0.12, 0.12), 0.005, BLUE, Kit.CLOTH)
		"prop_tug":
			_tug2(k, Vector3(0, 0, 0), 0.75)
			for i in 4:   # a ring of stones at its foot
				var a := i * PI / 2.0 + 0.3
				k.box(Vector3(cos(a) * 0.07, 0, sin(a) * 0.07), Vector3(0.05, 0.03, 0.05), Color(0.58, 0.56, 0.52), Kit.STONE)
		"prop_felt_rack":
			_felt_rack(k, Vector3(0, 0, 0), 0.0, 1.3)
			k.rod(Vector3(-0.2, 0.15, 0.0), Vector3(0.2, 0.15, 0.0), 0.006, WOOD, Kit.TIMBER)
			for i in 4:
				k.box(Vector3(-0.15 + i * 0.1, 0.07, 0.014), Vector3(0.025, 0.1, 0.01), Color(0.5, 0.2, 0.15), Kit.CLOTH)
		"prop_wagon":
			_light_wagon(k)


## A cheap wagon for the standalone prop: two light wheels, bed, pole and a load.
static func _light_wagon(k: Kit) -> void:
	var r := 0.16
	k.box(Vector3(0, r * 1.05, 0), Vector3(0.34, 0.03, 0.56), WOOD, Kit.TIMBER)
	for s: float in [-1.0, 1.0]:
		k.push(Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.RIGHT, PI / 2.0), Vector3(s * 0.2, r, 0)))
		k.frustum(Vector3(0, -0.015, 0), r, r, 0.03, Color(0.30, 0.20, 0.12), Kit.TIMBER, 8)
		k.pop()
		k.box(Vector3(s * 0.2, r - 0.01, 0), Vector3(0.04, r * 1.8, 0.02), Color(0.5, 0.36, 0.2), Kit.TIMBER)
		k.rod(Vector3(s * 0.08, r * 1.1, 0.25), Vector3(s * 0.04, r, 0.5), 0.011, WOOD, Kit.TIMBER)
	k.box(Vector3(0, r - 0.015, 0), Vector3(0.4, 0.025, 0.025), Color(0.3, 0.2, 0.12), Kit.TIMBER)
	for i in 2:
		k.box(Vector3(0, r * 1.05 + 0.03, -0.15 + i * 0.2), Vector3(0.24, 0.1, 0.16), Color(0.66, 0.5, 0.3) if i == 0 else FELT, Kit.CLOTH)


## A lean horse-tail standard for the standalone prop.
static func _tug2(k: Kit, foot: Vector3, h: float) -> void:
	k.cylinder(foot, 0.016, h, WOOD, Kit.TIMBER, 5)
	k.frustum(foot + Vector3(0, h, 0), 0.04, 0.04, 0.02, Color(0.9, 0.75, 0.3), Kit.GOLD, 6)
	k.frustum(foot + Vector3(0, h + 0.02, 0), 0.03, 0.0, 0.1, Color(0.9, 0.75, 0.3), Kit.GOLD, 5)
	k.box(foot + Vector3(0, h * 0.82, 0), Vector3(0.26, 0.016, 0.016), WOOD, Kit.TIMBER)
	for i in 7:
		var a := i * TAU / 7.0
		k.rod(foot + Vector3(cos(a) * 0.04, h - 0.01, sin(a) * 0.04), foot + Vector3(cos(a) * 0.08, h * 0.5 - (i % 3) * 0.04, sin(a) * 0.08),
			0.007, HAIR if i % 3 != 0 else Color(0.9, 0.88, 0.82), Kit.CLOTH)
	for s: float in [-1.0, 1.0]:
		for j in 2:
			k.rod(foot + Vector3(s * (0.04 + j * 0.06), h * 0.82, 0), foot + Vector3(s * (0.06 + j * 0.06), h * 0.6 - j * 0.03, 0), 0.006, HAIR, Kit.CLOTH)


# --- what a settlement draws -----------------------------------------------------------------------------------------


## Gers, tents and wagons for a camp or a steppe town of this `rank` (all steppe cultures alike:
## the Mongols, Turks and others differ in colour, not in kind). Repeat a kind to weight it.
static func house_set(_culture: String, rank: String) -> Array:
	match rank:
		"core":
			return ["yurt_6", "yurt_6", "yurt_2", "yurt_10", "yurt_12", "yurt_13", "yurt_4", "yurt_9", "yurt_15", "tent_a_2"]
		"city":
			return ["yurt_4", "yurt_6", "yurt_9", "yurt_12", "yurt_13", "yurt_10", "yurt_16", "yurt_1", "yurt_8", "wagon_tent", "tent_a_2"]
		"edge", "suburb":
			return ["yurt_1", "yurt_3", "yurt_5", "yurt_7", "yurt_11", "yurt_14", "yurt_16", "tent_cone_1", "tent_a_1", "wagon_supply_2", "wagon_supply_4"]
		"town":
			return ["yurt_1", "yurt_4", "yurt_5", "yurt_8", "yurt_9", "yurt_11", "yurt_12", "yurt_15", "yurt_16", "wagon_tent", "wagon_supply_1", "tent_dome_1"]
		"village":
			return ["yurt_1", "yurt_3", "yurt_5", "yurt_7", "yurt_8", "yurt_14", "yurt_16", "yurt_11", "tent_cone_1", "tent_cone_2", "wagon_supply_2"]
		"farm":
			return ["yurt_14", "yurt_14", "yurt_8", "yurt_11", "yurt_16", "wagon_supply_2", "wagon_supply_4"]
		"camp":
			return ["yurt_1", "yurt_3", "yurt_4", "yurt_5", "yurt_7", "yurt_8", "yurt_9", "yurt_14", "yurt_15", "yurt_16", "tent_cone_1", "tent_cone_2",
				"tent_a_1", "tent_a_2", "tent_lean_1", "tent_dome_1", "wagon_tent", "wagon_supply_1", "wagon_supply_2", "wagon_supply_3", "wagon_supply_4"]
		_:
			return ["yurt_1", "yurt_2", "yurt_3", "yurt_4", "yurt_5", "wagon_tent"]


## Two-lot family clusters of 2-3 gers on one base.
static func big_house_set(_culture: String, rank: String) -> Array:
	match rank:
		"core":
			return ["ger_cluster_3", "ger_cluster_1", "ger_cluster_3"]
		"farm":
			return ["ger_cluster_2", "ger_cluster_1"]
		"camp":
			return ["ger_cluster_1", "ger_cluster_2", "ger_cluster_3", "ger_cluster_4"]
		_:
			return ["ger_cluster_1", "ger_cluster_2", "ger_cluster_4", "ger_cluster_3"]
