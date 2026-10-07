## Classical Mediterranean buildings (Greece, Rome, Carthage, Hellenistic kingdoms, Byzantium).
## Six house types, a great peripteral temple (palace), a basilica/stoa, a triumphal arch and a
## rich urban villa with a peristyle garden. Front faces +z, units: 1.0 = an ordinary house.
extends RefCounted

const Kit := preload("res://scripts/models/kit.gd")

const MARBLE := Color(0.94, 0.92, 0.87)
const MARBLE_D := Color(0.84, 0.81, 0.74)
const OCHRE := Color(0.90, 0.70, 0.40)
const PINK := Color(0.90, 0.65, 0.54)
const LIME := Color(0.95, 0.92, 0.84)
const TERRA := Color(0.82, 0.46, 0.32)
const GREY := Color(0.64, 0.61, 0.55)
const RED := Color(0.68, 0.25, 0.20)
const BLUE := Color(0.22, 0.36, 0.56)
const WOOD := Color(0.46, 0.31, 0.18)
const DWOOD := Color(0.32, 0.21, 0.12)
const GREEN := Color(0.30, 0.46, 0.22)
const DGREEN := Color(0.20, 0.36, 0.18)
const TERRACOTTA := Color(0.78, 0.42, 0.27)


static func kinds() -> Array:
	return ["house_1", "house_2", "house_3", "house_4", "house_5", "house_6",
		"palace", "forum_hall", "triumphal_arch", "villa_great"]


# --- helpers ----------------------------------------------------------------------------------


## A tilted slab: `p` = four points of the top surface, thickness `thick` hanging below.
static func _slab(k: Kit, p: Array, thick: float, col: Color, mat: int) -> void:
	var dn := Vector3(0, -thick, 0)
	var c: Vector3 = (p[0] + p[1] + p[2] + p[3]) / 4.0 + dn * 0.5
	k.quad(p[0], p[1], p[2], p[3], col, mat, c)
	var q: Array = [p[0] + dn, p[1] + dn, p[2] + dn, p[3] + dn]
	k.quad(q[0], q[1], q[2], q[3], col.darkened(0.35), mat, c)
	for i in 4:
		var j := (i + 1) % 4
		k.quad(p[i], p[j], q[j], q[i], col.darkened(0.2), mat, c)


## A square frame of four sloping slabs around a hole: outer half-sizes (ox, oz) at height yo,
## inner (ix, iz) at yi. With yi < yo it is a Roman compluvium; with yi > yo a pent roof.
static func _frame_roof(k: Kit, centre: Vector3, ox: float, oz: float, ix: float, iz: float,
		yo: float, yi: float, thick: float, col: Color, mat := Kit.OWNER_ROOF) -> void:
	k.push(Kit.at(centre))
	_slab(k, [Vector3(-ox, yo, oz), Vector3(ox, yo, oz), Vector3(ix, yi, iz), Vector3(-ix, yi, iz)], thick, col, mat)
	_slab(k, [Vector3(ox, yo, -oz), Vector3(-ox, yo, -oz), Vector3(-ix, yi, -iz), Vector3(ix, yi, -iz)], thick, col, mat)
	_slab(k, [Vector3(ox, yo, oz), Vector3(ox, yo, -oz), Vector3(ix, yi, -iz), Vector3(ix, yi, iz)], thick, col, mat)
	_slab(k, [Vector3(-ox, yo, -oz), Vector3(-ox, yo, oz), Vector3(-ix, yi, iz), Vector3(-ix, yi, -iz)], thick, col, mat)
	k.pop()


## A classical column. order: "doric" (no base), "ionic" (base + scroll discs), "tuscan".
static func _col(k: Kit, foot: Vector3, r: float, h: float, c: Color, order := "doric", sides := 12) -> void:
	var bh := 0.0
	if order != "doric":
		bh = h * 0.05
		k.box(foot, Vector3(r * 2.5, bh, r * 2.5), c.darkened(0.05), Kit.STONE)
	var cap := h * 0.1
	var shaft := h - bh - cap
	k.frustum(foot + Vector3(0, bh, 0), r, r * 0.8, shaft, c, Kit.PAINT, sides, false)
	var ty := bh + shaft
	k.frustum(foot + Vector3(0, ty, 0), r * 0.8, r * 1.25, cap * 0.55, c, Kit.PAINT, 8, false)
	if order == "ionic":
		k.box(foot + Vector3(0, ty + cap * 0.55, 0), Vector3(r * 3.4, cap * 0.45, r * 2.0), c, Kit.STONE)
		for s in [-1.0, 1.0]:
			k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), foot + Vector3(s * r * 1.5, ty + cap * 0.35, r * 0.7)))
			k.frustum(Vector3.ZERO, r * 0.55, r * 0.55, r * 1.4, c.darkened(0.06), Kit.PAINT, 6)
			k.pop()
	else:
		k.box(foot + Vector3(0, ty + cap * 0.55, 0), Vector3(r * 3.0, cap * 0.45, r * 3.0), c, Kit.STONE)

## A cheap window: dark pane, a raised frame ring and a thin reveal. `at_pos` = centre on the wall.
## style: "plain", "shutters" (leaves each side), "arch" (round head).
static func _win(k: Kit, at_pos: Vector3, yaw: float, w: float, h: float, frame: Color, style := "plain") -> void:
	k.push(Kit.at(at_pos, yaw))
	var f := minf(w, h) * 0.2
	var hw := w / 2.0
	var hh := h / 2.0
	var top := hh - hw
	var pts: Array = [Vector3(-hw, -hh, 0), Vector3(hw, -hh, 0)]
	if style == "arch":
		for i in 5:
			var a := i * PI / 4.0
			pts.append(Vector3(cos(a) * hw, top + sin(a) * hw, 0))
	else:
		pts.append(Vector3(hw, hh, 0))
		pts.append(Vector3(-hw, hh, 0))
	var n := pts.size()
	var inner_f: Array = []
	var inner_b: Array = []
	var outer: Array = []
	for p in pts:
		var v: Vector3 = p
		inner_f.append(Vector3(v.x, v.y, 0.014))
		inner_b.append(Vector3(v.x, v.y, 0.004))
		var off := Vector3(signf(v.x) * f, signf(v.y) * f, 0)
		if style == "arch" and v.y > -hh + 0.001:
			off = Vector3(v.x, v.y - top, 0).normalized() * f
		outer.append(Vector3(v.x + off.x, v.y + off.y, 0.014))
	k.polygon(inner_b, Color(0.07, 0.05, 0.04), Kit.DARK, Vector3(0, 0, -1))
	for i in n:
		var j := (i + 1) % n
		var a: Vector3 = inner_f[i]
		var b: Vector3 = inner_f[j]
		var mp := (a + b) / 2.0
		k.quad(a, b, outer[j], outer[i], frame, Kit.STONE, Vector3(mp.x, mp.y, -1))
		k.quad(a, b, inner_b[j], inner_b[i], frame.darkened(0.3), Kit.STONE, Vector3(mp.x * 3.0, mp.y * 3.0, 0.009))
	if style == "shutters":
		for s in [-1.0, 1.0]:
			k.box(Vector3(s * (hw + f + w * 0.2), -hh, 0.0), Vector3(w * 0.4, h, 0.014), WOOD, Kit.TIMBER)
	k.box(Vector3(0, -hh - f * 1.1, 0.0), Vector3(w + f * 3.0, f * 0.9, f * 2.0), frame, Kit.STONE)   # sill
	k.pop()


static func _amphora(k: Kit, foot: Vector3, s: float, col := TERRACOTTA) -> void:
	k.frustum(foot, 0.04 * s, 0.17 * s, 0.26 * s, col, Kit.PAINT, 8, false)
	k.frustum(foot + Vector3(0, 0.26 * s, 0), 0.17 * s, 0.07 * s, 0.2 * s, col, Kit.PAINT, 8, false)
	k.frustum(foot + Vector3(0, 0.46 * s, 0), 0.09 * s, 0.09 * s, 0.04 * s, col.darkened(0.15), Kit.PAINT, 8)


static func _tree(k: Kit, foot: Vector3, s: float, col := GREEN) -> void:
	k.cylinder(foot, 0.018 * s, 0.14 * s, DWOOD, Kit.TIMBER, 5)
	k.dome(foot + Vector3(0, 0.1 * s, 0), 0.12 * s, col, Kit.LEAF, 0.85, 3, 8)


static func _cypress(k: Kit, foot: Vector3, s: float) -> void:
	k.frustum(foot, 0.06 * s, 0.0, 0.34 * s, DGREEN, Kit.LEAF, 7)


## A striped awning sloping from the wall (z0, y0) out and down to (z1, y1), across x0..x1.
static func _awning(k: Kit, x0: float, x1: float, y0: float, z0: float, y1: float, z1: float, stripes: int) -> void:
	var w := (x1 - x0) / stripes
	for i in stripes:
		var xa := x0 + i * w
		var col := Color(0.93, 0.88, 0.76)
		var mat := Kit.CLOTH
		if i % 2 == 0:
			col = Color(0.85, 0.85, 0.85)
			mat = Kit.OWNER_CLOTH
		_slab(k, [Vector3(xa, y0, z0), Vector3(xa + w, y0, z0), Vector3(xa + w, y1, z1), Vector3(xa, y1, z1)], 0.008, col, mat)
	for i in stripes:   # scalloped valance
		var xa := x0 + i * w
		var col2 := Color(0.93, 0.88, 0.76) if i % 2 == 1 else Color(0.85, 0.85, 0.85)
		var mat2 := Kit.CLOTH if i % 2 == 1 else Kit.OWNER_CLOTH
		k.tri(Vector3(xa, y1, z1), Vector3(xa + w, y1, z1), Vector3(xa + w * 0.5, y1 - 0.04, z1 + 0.005), col2, mat2, Vector3(0, y1, z1 - 1.0))
		k.tri(Vector3(xa, y1, z1), Vector3(xa + w, y1, z1), Vector3(xa + w * 0.5, y1 - 0.04, z1 + 0.005), col2, mat2, Vector3(0, y1, z1 + 1.0))


static func _tile_gable(k: Kit, foot: Vector3, w: float, d: float, rise: float, over: float, wall: Color, yaw := 0.0) -> void:
	k.gable_roof(foot, w, d, rise, over, 0.03, TERRA, Kit.OWNER_ROOF, wall, Kit.PLASTER, yaw)


# --- build ------------------------------------------------------------------------------------


static func build(kind: String) -> ArrayMesh:
	var k := Kit.new()
	match kind:
		"house_1":
			k.push(Transform3D(Basis.from_scale(Vector3(0.96, 0.92, 0.86)), Vector3(0, 0, -0.03)))
			_domus(k)
			k.pop()
		"house_2":
			_insula(k)
		"house_3":
			k.push(Transform3D(Basis.from_scale(Vector3(0.9, 0.95, 0.9)), Vector3.ZERO))
			_greek_house(k)
			k.pop()
		"house_4":
			k.push(Transform3D(Basis.from_scale(Vector3(0.93, 0.95, 0.93)), Vector3.ZERO))
			_hill_villa(k)
			k.pop()
		"house_5":
			_punic_house(k)
		"house_6":
			_tavern(k)
		"palace":
			_temple(k)
		"forum_hall":
			_basilica(k)
		"triumphal_arch":
			_arch(k)
		"villa_great":
			_great_villa(k)
	return k.finish()


# --- house 1: Roman domus round an atrium -----------------------------------------------------


static func _domus(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(0.98, 0.05, 0.98), GREY, Kit.STONE)
	for sg in [-1.0, 1.0]:   # perimeter walls only: the atrium stays open to the sky
		k.box(Vector3(0, 0.05, sg * 0.43), Vector3(0.92, 0.5, 0.06), OCHRE, Kit.PLASTER)
		k.box(Vector3(sg * 0.43, 0.05, 0), Vector3(0.06, 0.5, 0.8), OCHRE, Kit.PLASTER)
	for sg in [-1.0, 1.0]:   # red dado
		k.box(Vector3(0, 0.05, sg * 0.465), Vector3(0.935, 0.08, 0.012), RED, Kit.PLASTER)
		k.box(Vector3(sg * 0.465, 0.05, 0), Vector3(0.012, 0.08, 0.92), RED, Kit.PLASTER)
	for sg in [-1.0, 1.0]:   # string course and cornice, as rings round the open atrium
		for yy in [0.40, 0.55]:
			var th := 0.025 if yy < 0.5 else 0.035
			k.box(Vector3(0, yy, sg * 0.46), Vector3(0.97, th, 0.05), MARBLE, Kit.STONE)
			k.box(Vector3(sg * 0.46, yy, 0), Vector3(0.05, th, 0.87), MARBLE, Kit.STONE)
	for x in [-0.46, 0.46]:   # corner pilasters
		for z in [-0.46, 0.46]:
			k.box(Vector3(x, 0.05, z), Vector3(0.06, 0.5, 0.06), MARBLE, Kit.STONE)
	# front porch with two columns and a little pediment
	k.box(Vector3(0, 0.05, 0.56), Vector3(0.44, 0.03, 0.2), GREY, Kit.STONE)
	for x in [-0.17, 0.17]:
		_col(k, Vector3(x, 0.08, 0.60), 0.032, 0.36, MARBLE, "tuscan", 10)
	k.box(Vector3(0, 0.44, 0.60), Vector3(0.46, 0.05, 0.08), MARBLE, Kit.STONE)
	k.gable_roof(Vector3(0, 0.49, 0.56), 0.22, 0.46, 0.11, 0.03, 0.025, TERRA, Kit.OWNER_ROOF, LIME, Kit.PLASTER, PI / 2.0)
	k.door(Vector3(0, 0.08, 0.46), 0.0, 0.15, 0.27, MARBLE, WOOD)
	for x in [-0.32, 0.32]:
		_win(k, Vector3(x, 0.33, 0.46), 0.0, 0.09, 0.11, MARBLE, "plain")
		_win(k, Vector3(x, 0.33, -0.46), PI, 0.09, 0.11, MARBLE, "plain")
	for z in [-0.25, 0.1, 0.32]:
		for s in [-1.0, 1.0]:
			_win(k, Vector3(s * 0.46, 0.34, z), s * PI / 2.0, 0.07, 0.1, MARBLE, "plain")
	# the compluvium: roof slopes inward round an open atrium with an impluvium
	_frame_roof(k, Vector3(0, 0, 0.02), 0.52, 0.52, 0.2, 0.2, 0.62, 0.50, 0.035, TERRA)
	for s in [-1.0, 1.0]:   # atrium inner walls
		k.quad(Vector3(s * 0.2, 0.5, 0.22), Vector3(s * 0.2, 0.5, -0.18), Vector3(s * 0.2, 0.12, -0.18),
			Vector3(s * 0.2, 0.12, 0.22), PINK, Kit.PLASTER, Vector3(s * 2.0, 0.3, 0))
		k.quad(Vector3(-0.2, 0.5, 0.02 + s * 0.2), Vector3(0.2, 0.5, 0.02 + s * 0.2), Vector3(0.2, 0.12, 0.02 + s * 0.2),
			Vector3(-0.2, 0.12, 0.02 + s * 0.2), PINK, Kit.PLASTER, Vector3(0, 0.3, 0.02 + s * 2.0))
	k.box(Vector3(0, 0.1, 0.02), Vector3(0.4, 0.02, 0.4), Color(0.72, 0.60, 0.46), Kit.STONE)
	k.box(Vector3(0, 0.12, 0.02), Vector3(0.18, 0.02, 0.18), MARBLE, Kit.STONE)
	k.box(Vector3(0, 0.138, 0.02), Vector3(0.14, 0.01, 0.14), Color.WHITE, Kit.WATER)
	# the raised tablinum at the back
	k.box(Vector3(0, 0.58, -0.325), Vector3(0.9, 0.16, 0.27), PINK, Kit.PLASTER)
	for x in [-0.28, 0.0, 0.28]:
		_win(k, Vector3(x, 0.67, -0.19), 0.0, 0.07, 0.08, MARBLE, "plain")
	k.gable_roof(Vector3(0, 0.74, -0.325), 0.9, 0.27, 0.17, 0.04, 0.03, TERRA, Kit.OWNER_ROOF, PINK, Kit.PLASTER)
	# potted bush at the porch
	for x in [-0.3, 0.3]:
		k.cylinder(Vector3(x, 0.05, 0.6), 0.03, 0.05, TERRACOTTA, Kit.PAINT, 7)
		k.dome(Vector3(x, 0.1, 0.6), 0.05, GREEN, Kit.LEAF, 0.9, 2, 7)


# --- house 2: insula (apartment block) ---------------------------------------------------------


static func _insula(k: Kit) -> void:
	var fw := 0.92
	var fd := 0.78
	k.box(Vector3(0, 0, 0), Vector3(fw + 0.04, 0.05, fd + 0.04), GREY, Kit.STONE)
	k.box(Vector3(0, 0.05, 0), Vector3(fw, 0.26, fd), Color(0.74, 0.46, 0.34), Kit.BRICK)   # ground floor of brick
	k.box(Vector3(0, 0.31, 0), Vector3(fw + 0.025, 0.025, fd + 0.025), MARBLE, Kit.STONE)
	var floors: Array = [[0.335, OCHRE], [0.585, PINK], [0.80, LIME]]
	for fl in floors:
		var y0: float = fl[0]
		var c: Color = fl[1]
		var h := 0.25 if y0 < 0.7 else 0.2
		var inset := 0.0 if y0 < 0.7 else 0.04
		k.box(Vector3(0, y0, 0), Vector3(fw - inset * 2.0, h, fd - inset * 2.0), c, Kit.PLASTER)
		k.box(Vector3(0, y0 + h, 0), Vector3(fw - inset * 2.0 + 0.025, 0.02, fd - inset * 2.0 + 0.025), MARBLE_D, Kit.STONE)
	for x in [-0.46, 0.46]:
		k.box(Vector3(x, 0.05, 0.39), Vector3(0.07, 0.26, 0.04), MARBLE, Kit.STONE)   # brick piers
		k.box(Vector3(x, 0.05, -0.39), Vector3(0.07, 0.26, 0.04), MARBLE, Kit.STONE)
	# tabernae: arched shop openings with counters
	for x in [-0.30, 0.0, 0.30]:
		_win(k, Vector3(x, 0.19, 0.39), 0.0, 0.17, 0.2, MARBLE, "arch")
		k.box(Vector3(x, 0.05, 0.4), Vector3(0.2, 0.07, 0.05), MARBLE_D, Kit.STONE)
	_amphora(k, Vector3(0.38, 0.05, 0.43), 0.45)
	_amphora(k, Vector3(-0.38, 0.05, 0.43), 0.4, Color(0.7, 0.5, 0.32))
	_awning(k, 0.2, 0.42, 0.3, 0.39, 0.23, 0.5, 4)
	k.door(Vector3(-0.42, 0.05, 0.39), 0.0, 0.1, 0.19, MARBLE, WOOD)
	# window rows
	for x in [-0.32, -0.11, 0.11, 0.32]:
		_win(k, Vector3(x, 0.47, 0.39), 0.0, 0.08, 0.11, WOOD, "shutters")
		_win(k, Vector3(x, 0.47, -0.39), PI, 0.08, 0.11, WOOD, "shutters")
	for x in [-0.28, 0.0, 0.28]:
		_win(k, Vector3(x, 0.69, -0.39), PI, 0.08, 0.1, MARBLE, "plain")
	for x in [-0.28, 0.28]:
		_win(k, Vector3(x, 0.69, 0.39), 0.0, 0.08, 0.1, MARBLE, "plain")
	for x in [-0.24, 0.0, 0.24]:
		_win(k, Vector3(x, 0.9, 0.35), 0.0, 0.07, 0.09, MARBLE, "plain")
		_win(k, Vector3(x, 0.9, -0.35), PI, 0.07, 0.09, MARBLE, "plain")
	for z in [-0.22, 0.0, 0.22]:
		for s in [-1.0, 1.0]:
			_win(k, Vector3(s * 0.46, 0.47, z), s * PI / 2.0, 0.07, 0.1, WOOD, "plain")
			_win(k, Vector3(s * 0.46, 0.69, z), s * PI / 2.0, 0.07, 0.09, MARBLE, "plain")
	# wooden balcony on the third floor
	k.box(Vector3(0.1, 0.585, 0.46), Vector3(0.5, 0.025, 0.13), WOOD, Kit.TIMBER)
	for x in [-0.14, 0.34]:
		k.rod(Vector3(x, 0.585, 0.52), Vector3(x, 0.72, 0.52), 0.01, DWOOD, Kit.TIMBER)
	for i in 7:
		var x := -0.14 + i * 0.08
		k.rod(Vector3(x, 0.61, 0.52), Vector3(x, 0.67, 0.52), 0.005, DWOOD, Kit.TIMBER)
	k.rod(Vector3(-0.14, 0.67, 0.52), Vector3(0.34, 0.67, 0.52), 0.008, DWOOD, Kit.TIMBER)
	for x in [-0.1, 0.38 - 0.08]:
		k.rod(Vector3(x, 0.585, 0.41), Vector3(x + 0.03, 0.54, 0.46), 0.007, DWOOD, Kit.TIMBER)   # struts
	# washing line
	for i in 3:
		var cx := -0.38 + i * 0.07
		k.quad(Vector3(cx, 0.73, 0.395), Vector3(cx + 0.05, 0.73, 0.395), Vector3(cx + 0.05, 0.64, 0.395), Vector3(cx, 0.64, 0.395),
			[Color(0.9, 0.9, 0.85), Color(0.75, 0.3, 0.25), Color(0.4, 0.5, 0.7)][i], Kit.CLOTH, Vector3(cx, 0.7, 0.0))
	# low pitched roof and rooftop details
	_tile_gable(k, Vector3(0, 1.0, 0), fw - 0.08, fd - 0.08, 0.17, 0.08, OCHRE)
	k.chimney(Vector3(-0.25, 1.04, -0.1), 0.07, 0.2, MARBLE_D)
	k.box(Vector3(0.28, 1.0, 0.18), Vector3(0.12, 0.05, 0.1), WOOD, Kit.TIMBER)
	k.box(Vector3(0.28, 1.05, 0.18), Vector3(0.14, 0.015, 0.12), TERRA, Kit.TILE)


# --- house 3: Greek courtyard house -----------------------------------------------------------


static func _greek_house(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(1.0, 0.02, 1.0), Color(0.72, 0.66, 0.54), Kit.EARTH)   # court floor
	k.box(Vector3(0.05, 0.02, 0.06), Vector3(0.5, 0.01, 0.55), Color(0.78, 0.74, 0.66), Kit.STONE)  # paving
	# back wing, deeper and taller, with a portico
	k.box(Vector3(0, 0.02, -0.34), Vector3(0.98, 0.44, 0.32), LIME, Kit.PLASTER)
	k.box(Vector3(0, 0.02, -0.34), Vector3(1.0, 0.06, 0.34), GREY, Kit.STONE)
	k.box(Vector3(0, 0.38, -0.34), Vector3(1.0, 0.03, 0.34), BLUE, Kit.PAINT)   # painted band
	_tile_gable(k, Vector3(0, 0.46, -0.32), 0.94, 0.36, 0.17, 0.05, LIME)
	for x in [-0.33, -0.11, 0.11, 0.33]:
		_col(k, Vector3(x, 0.02, -0.12), 0.025, 0.34, MARBLE, "doric", 10)
	k.box(Vector3(0, 0.36, -0.12), Vector3(0.9, 0.04, 0.06), MARBLE, Kit.STONE)
	k.door(Vector3(0, 0.02, -0.175), 0.0, 0.13, 0.25, MARBLE, BLUE)
	for x in [-0.32, 0.32]:
		_win(k, Vector3(x, 0.25, -0.175), 0.0, 0.1, 0.1, MARBLE, "plain")
	# left wing (long), pent roof facing the court
	k.box(Vector3(-0.38, 0.02, 0.18), Vector3(0.24, 0.3, 0.64), LIME, Kit.PLASTER)
	k.box(Vector3(-0.38, 0.02, 0.18), Vector3(0.26, 0.05, 0.66), GREY, Kit.STONE)
	k.push(Kit.at(Vector3(-0.38, 0.32, 0.18), PI / 2.0))
	k.gable_roof(Vector3.ZERO, 0.66, 0.24, 0.11, 0.05, 0.03, TERRA, Kit.OWNER_ROOF, LIME, Kit.PLASTER)
	k.pop()
	for z in [0.0, 0.3]:
		_win(k, Vector3(-0.505, 0.22, z), -PI / 2.0, 0.07, 0.09, MARBLE, "shutters")
		_win(k, Vector3(-0.255, 0.22, z), PI / 2.0, 0.07, 0.09, WOOD, "plain")
	# right wing with an upper room (andron)
	k.box(Vector3(0.38, 0.02, -0.02), Vector3(0.24, 0.34, 0.3), PINK, Kit.PLASTER)
	k.box(Vector3(0.38, 0.36, -0.02), Vector3(0.2, 0.17, 0.22), LIME, Kit.PLASTER)
	_win(k, Vector3(0.38, 0.47, 0.095), 0.0, 0.07, 0.08, BLUE, "plain")
	k.hip_roof(Vector3(0.38, 0.53, -0.02), 0.2, 0.22, 0.12, 0.05, 0.028, TERRA)
	_win(k, Vector3(0.258, 0.22, -0.02), -PI / 2.0, 0.07, 0.09, WOOD, "plain")
	# front wall with a gate
	k.box(Vector3(0.14, 0.02, 0.47), Vector3(0.74, 0.25, 0.06), LIME, Kit.PLASTER)
	k.box(Vector3(0.14, 0.27, 0.47), Vector3(0.78, 0.03, 0.09), TERRA, Kit.TILE)
	k.box(Vector3(0.14, 0.02, 0.47), Vector3(0.78, 0.05, 0.08), GREY, Kit.STONE)
	k.box(Vector3(0.2, 0.02, 0.47), Vector3(0.2, 0.34, 0.08), MARBLE, Kit.STONE)
	k.door(Vector3(0.2, 0.02, 0.515), 0.0, 0.13, 0.22, MARBLE_D, BLUE)
	for sg in [-1.0, 1.0]:
		k.box(Vector3(0.2 + sg * 0.1, 0.27, 0.47), Vector3(0.06, 0.12, 0.09), MARBLE, Kit.STONE)
		k.frustum(Vector3(0.2 + sg * 0.1, 0.39, 0.47), 0.03, 0.0, 0.05, TERRA, Kit.TILE, 4)
	# pergola with vine, well, olive tree
	for x in [0.0, 0.24]:
		for z in [0.0, 0.3]:
			k.rod(Vector3(x, 0.02, z), Vector3(x, 0.3, z), 0.012, DWOOD, Kit.TIMBER)
	for z in [0.0, 0.1, 0.2, 0.3]:
		k.rod(Vector3(-0.03, 0.3, z), Vector3(0.27, 0.3, z), 0.008, WOOD, Kit.TIMBER)
	for x in [0.0, 0.24]:
		k.rod(Vector3(x, 0.31, -0.03), Vector3(x, 0.31, 0.33), 0.012, DWOOD, Kit.TIMBER)
	for p in [Vector3(0.04, 0.33, 0.05), Vector3(0.14, 0.33, 0.14), Vector3(0.2, 0.33, 0.25), Vector3(0.06, 0.33, 0.27)]:
		k.dome(p, 0.07, GREEN, Kit.LEAF, 0.35, 2, 7)
	k.cylinder(Vector3(-0.1, 0.02, 0.38), 0.05, 0.07, MARBLE_D, Kit.STONE, 8)
	k.cylinder(Vector3(-0.1, 0.085, 0.38), 0.036, 0.005, Color.WHITE, Kit.WATER, 8)
	_tree(k, Vector3(-0.14, 0.02, 0.2), 1.5, Color(0.46, 0.55, 0.36))
	_amphora(k, Vector3(0.42, 0.02, 0.28), 0.5)
	_amphora(k, Vector3(0.36, 0.02, 0.32), 0.4)


# --- house 4: hillside villa with a loggia ----------------------------------------------------


static func _hill_villa(k: Kit) -> void:
	k.box(Vector3(0, 0, 0.0), Vector3(1.0, 0.2, 0.92), Color(0.68, 0.63, 0.55), Kit.STONE)   # terrace podium
	k.box(Vector3(0, 0.2, 0.0), Vector3(1.0, 0.02, 0.92), MARBLE_D, Kit.STONE)
	for x in [-0.36, -0.12, 0.12, 0.36]:   # arched niches in the retaining wall
		_win(k, Vector3(x, 0.14, 0.46), 0.0, 0.1, 0.12, MARBLE, "arch")
	for i in 4:   # steps
		k.box(Vector3(0, i * 0.045, 0.5 + (3 - i) * 0.0 - 0.0), Vector3(0.24 - i * 0.02, 0.045, 0.04 + (i + 1) * 0.03), MARBLE, Kit.STONE)
	k.box(Vector3(-0.1, 0.22, -0.15), Vector3(0.72, 0.5, 0.5), OCHRE, Kit.PLASTER)   # main block
	k.box(Vector3(-0.1, 0.22, -0.15), Vector3(0.74, 0.06, 0.52), RED, Kit.PLASTER)
	k.box(Vector3(-0.1, 0.62, -0.15), Vector3(0.75, 0.03, 0.53), MARBLE, Kit.STONE)
	k.hip_roof(Vector3(-0.1, 0.65, -0.15), 0.72, 0.5, 0.2, 0.06, 0.032, TERRA)
	for x in [-0.34, 0.14]:
		_win(k, Vector3(x, 0.5, 0.101), 0.0, 0.1, 0.16, MARBLE, "arch")
		_win(k, Vector3(x, 0.5, -0.401), PI, 0.1, 0.16, MARBLE, "arch")
	_win(k, Vector3(-0.462, 0.5, -0.15), -PI / 2.0, 0.1, 0.16, MARBLE, "arch")
	# loggia in front: columns, entablature, pent roof
	for i in 5:
		var x := -0.4 + i * 0.15
		_col(k, Vector3(x + 0.0, 0.22, 0.28), 0.026, 0.3, MARBLE, "ionic", 10)
	k.box(Vector3(-0.1, 0.52, 0.28), Vector3(0.7, 0.045, 0.07), MARBLE, Kit.STONE)
	_slab(k, [Vector3(-0.48, 0.60, 0.12), Vector3(0.28, 0.60, 0.12), Vector3(0.3, 0.54, 0.34), Vector3(-0.5, 0.54, 0.34)], 0.03, TERRA, Kit.OWNER_ROOF)
	k.door(Vector3(-0.1, 0.22, 0.101), 0.0, 0.15, 0.28, MARBLE, WOOD)
	# belvedere tower at the back
	k.box(Vector3(-0.3, 0.68, -0.28), Vector3(0.3, 0.3, 0.28), LIME, Kit.PLASTER)
	for s in [-1.0, 1.0]:
		_win(k, Vector3(-0.3 + s * 0.151, 0.86, -0.28), s * PI / 2.0, 0.07, 0.14, MARBLE, "arch")
	_win(k, Vector3(-0.3, 0.86, -0.139), 0.0, 0.08, 0.14, MARBLE, "arch")
	k.box(Vector3(-0.3, 0.98, -0.28), Vector3(0.34, 0.03, 0.32), MARBLE, Kit.STONE)
	k.hip_roof(Vector3(-0.3, 1.01, -0.28), 0.3, 0.28, 0.17, 0.05, 0.03, TERRA)
	# garden terrace on the right: pergola, cypresses, fountain
	for z in [-0.1, 0.25]:
		for x in [0.3, 0.46]:
			k.rod(Vector3(x, 0.22, z), Vector3(x, 0.5, z), 0.012, DWOOD, Kit.TIMBER)
		k.rod(Vector3(0.28, 0.5, z), Vector3(0.48, 0.5, z), 0.01, WOOD, Kit.TIMBER)
	for x in [0.3, 0.46]:
		k.rod(Vector3(x, 0.51, -0.1), Vector3(x, 0.51, 0.25), 0.01, WOOD, Kit.TIMBER)
	for z in [0.0, 0.1, 0.18]:
		k.dome(Vector3(0.38, 0.5, z), 0.07, GREEN, Kit.LEAF, 0.3, 2, 6)
	_cypress(k, Vector3(0.4, 0.22, -0.34), 1.2)
	_cypress(k, Vector3(0.28, 0.22, -0.4), 1.0)
	_cypress(k, Vector3(-0.46, 0.22, 0.38), 0.9)
	k.cylinder(Vector3(0.36, 0.22, 0.38), 0.07, 0.05, MARBLE, Kit.STONE, 8)
	k.cylinder(Vector3(0.36, 0.27, 0.38), 0.056, 0.005, Color.WHITE, Kit.WATER, 8)


# --- house 5: Carthaginian flat-roofed house --------------------------------------------------


static func _punic_house(k: Kit) -> void:
	var cx := -0.08
	k.box(Vector3(cx, 0, 0), Vector3(0.84, 0.05, 0.84), GREY, Kit.STONE)
	k.box(Vector3(cx, 0.05, 0), Vector3(0.8, 0.44, 0.8), Color(0.93, 0.86, 0.80), Kit.PLASTER)
	k.box(Vector3(cx, 0.05, 0), Vector3(0.815, 0.07, 0.815), Color(0.64, 0.38, 0.30), Kit.PLASTER)
	k.box(Vector3(cx, 0.49, 0), Vector3(0.84, 0.035, 0.84), MARBLE, Kit.STONE)   # cornice
	# protruding roof beams below the parapet
	for i in 8:
		var x := cx - 0.35 + i * 0.1
		k.box(Vector3(x, 0.44, 0.405), Vector3(0.035, 0.035, 0.05), DWOOD, Kit.TIMBER)
		k.box(Vector3(x, 0.44, -0.405), Vector3(0.035, 0.035, 0.05), DWOOD, Kit.TIMBER)
	# parapet round the terrace
	for z in [-0.395, 0.395]:
		k.box(Vector3(cx, 0.525, z), Vector3(0.84, 0.07, 0.05), Color(0.93, 0.86, 0.80), Kit.PLASTER)
		k.box(Vector3(cx, 0.595, z), Vector3(0.86, 0.015, 0.07), MARBLE, Kit.STONE)
	for x in [cx - 0.395, cx + 0.395]:
		k.box(Vector3(x, 0.525, 0), Vector3(0.05, 0.07, 0.74), Color(0.93, 0.86, 0.80), Kit.PLASTER)
		k.box(Vector3(x, 0.595, 0), Vector3(0.07, 0.015, 0.76), MARBLE, Kit.STONE)
	# second storey set back to the rear-left
	k.box(Vector3(cx - 0.14, 0.525, -0.1), Vector3(0.44, 0.3, 0.46), Color(0.96, 0.92, 0.86), Kit.PLASTER)
	k.box(Vector3(cx - 0.14, 0.825, -0.1), Vector3(0.48, 0.03, 0.5), MARBLE, Kit.STONE)
	_win(k, Vector3(cx - 0.14, 0.7, 0.131), 0.0, 0.07, 0.12, BLUE, "arch")
	_win(k, Vector3(cx - 0.361, 0.7, -0.1), -PI / 2.0, 0.06, 0.1, MARBLE, "plain")
	_win(k, Vector3(cx - 0.14, 0.7, -0.331), PI, 0.06, 0.1, MARBLE, "plain")
	# small dome shrine on the top
	k.cylinder(Vector3(cx - 0.14, 0.855, -0.1), 0.1, 0.07, MARBLE, Kit.PLASTER, 10)
	k.dome(Vector3(cx - 0.14, 0.925, -0.1), 0.11, MARBLE, Kit.PLASTER, 0.9, 4, 10)
	k.cylinder(Vector3(cx - 0.14, 1.02, -0.1), 0.012, 0.07, GOLD_C, Kit.GOLD, 5)
	# awning on poles over the terrace front-right
	for p in [Vector3(cx + 0.14, 0.6, 0.3), Vector3(cx + 0.36, 0.6, 0.3), Vector3(cx + 0.14, 0.6, 0.0), Vector3(cx + 0.36, 0.6, 0.0)]:
		k.rod(p, p + Vector3(0, 0.3 if p.z < 0.1 else 0.22, 0), 0.01, DWOOD, Kit.TIMBER)
	_awning_z(k, cx + 0.12, cx + 0.38, 0.0, 0.3, 0.9, 0.84)
	# front door, narrow windows and outside stair
	k.door(Vector3(cx, 0.05, 0.4), 0.0, 0.16, 0.28, MARBLE, BLUE)
	for x in [cx - 0.28, cx + 0.28]:
		_win(k, Vector3(x, 0.32, 0.4), 0.0, 0.05, 0.14, MARBLE, "plain")
	_win(k, Vector3(cx - 0.18, 0.32, -0.4), PI, 0.05, 0.14, MARBLE, "plain")
	_win(k, Vector3(cx + 0.18, 0.32, -0.4), PI, 0.05, 0.14, MARBLE, "plain")
	_win(k, Vector3(cx - 0.4, 0.3, 0.1), -PI / 2.0, 0.06, 0.12, MARBLE, "arch")
	for i in 6:
		k.box(Vector3(0.40, 0.0, 0.3 - i * 0.1), Vector3(0.14, 0.08 * (i + 1), 0.1), MARBLE_D, Kit.STONE)
	k.box(Vector3(0.40, 0.0, -0.24), Vector3(0.14, 0.5, 0.1), MARBLE_D, Kit.STONE)
	_amphora(k, Vector3(cx + 0.3, 0.05, 0.46), 0.5)
	_amphora(k, Vector3(cx + 0.22, 0.05, 0.47), 0.4, Color(0.72, 0.5, 0.35))
	for x in [cx + 0.2, cx + 0.34]:   # pots on the terrace
		k.cylinder(Vector3(x, 0.525, -0.3), 0.035, 0.05, TERRACOTTA, Kit.PAINT, 7)


const GOLD_C := Color(0.86, 0.68, 0.25)


## An awning laid over a terrace, sloping in z from the high edge (z0) to the low edge (z1).
static func _awning_z(k: Kit, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
	var n := 4
	var w := (x1 - x0) / n
	for i in n:
		var xa := x0 + i * w
		var col := Color(0.93, 0.88, 0.76)
		var mat := Kit.CLOTH
		if i % 2 == 0:
			col = Color(0.85, 0.85, 0.85)
			mat = Kit.OWNER_CLOTH
		_slab(k, [Vector3(xa, y0, z0), Vector3(xa + w, y0, z0), Vector3(xa + w, y1, z1), Vector3(xa, y1, z1)], 0.01, col, mat)


# --- house 6: shop / tavern -------------------------------------------------------------------


static func _tavern(k: Kit) -> void:
	k.box(Vector3(0, 0, 0), Vector3(0.9, 0.04, 0.62), GREY, Kit.STONE)
	k.box(Vector3(0.0, 0.04, -0.02), Vector3(0.8, 0.34, 0.5), Color(0.92, 0.80, 0.60), Kit.PLASTER)
	k.box(Vector3(0.0, 0.04, -0.02), Vector3(0.815, 0.06, 0.515), Color(0.55, 0.52, 0.47), Kit.STONE)
	# open timber shopfront: posts, lintel, counter
	for x in [-0.34, -0.1, 0.14, 0.34]:
		k.box(Vector3(x, 0.04, 0.245), Vector3(0.045, 0.26, 0.045), DWOOD, Kit.TIMBER)
	k.box(Vector3(0, 0.30, 0.245), Vector3(0.8, 0.05, 0.05), WOOD, Kit.TIMBER)
	k.box(Vector3(-0.22, 0.04, 0.245), Vector3(0.2, 0.26, 0.012), Color(0.1, 0.07, 0.05), Kit.DARK)
	k.box(Vector3(0.02, 0.04, 0.245), Vector3(0.2, 0.26, 0.012), Color(0.1, 0.07, 0.05), Kit.DARK)
	k.box(Vector3(-0.22, 0.04, 0.275), Vector3(0.2, 0.1, 0.07), MARBLE_D, Kit.STONE)    # counter
	k.box(Vector3(-0.22, 0.14, 0.275), Vector3(0.22, 0.02, 0.09), WOOD, Kit.TIMBER)
	k.door(Vector3(0.24, 0.04, 0.2501), 0.0, 0.12, 0.23, WOOD, DWOOD)
	k.box(Vector3(0, 0.34, 0.0), Vector3(0.84, 0.03, 0.55), MARBLE, Kit.STONE)
	# upper loft with window under the roof gable
	k.box(Vector3(0.0, 0.37, -0.1), Vector3(0.7, 0.14, 0.3), Color(0.94, 0.88, 0.76), Kit.PLASTER)
	for x in [-0.2, 0.2]:
		_win(k, Vector3(x, 0.45, 0.051), 0.0, 0.08, 0.08, WOOD, "shutters")
	_awning(k, -0.4, 0.4, 0.3, 0.27, 0.22, 0.43, 8)
	_tile_gable(k, Vector3(0, 0.51, -0.1), 0.7, 0.3, 0.17, 0.08, LIME)
	k.chimney(Vector3(0.22, 0.58, -0.18), 0.07, 0.2, MARBLE_D)
	# sign: a bracket with a hanging amphora board
	k.rod(Vector3(0.4, 0.5, 0.1), Vector3(0.4, 0.5, 0.36), 0.008, DWOOD, Kit.TIMBER)
	k.box(Vector3(0.4, 0.38, 0.34), Vector3(0.015, 0.1, 0.09), GOLD_C, Kit.GOLD)
	# lean-to wine shed on the left with barrels and amphorae
	k.box(Vector3(-0.4, 0.04, -0.2), Vector3(0.12, 0.25, 0.3), Color(0.60, 0.50, 0.38), Kit.MUDBRICK)
	_slab(k, [Vector3(-0.56, 0.32, -0.38), Vector3(-0.32, 0.32, -0.38), Vector3(-0.32, 0.24, 0.12), Vector3(-0.56, 0.24, 0.12)], 0.03, TERRA, Kit.TILE)
	for z in [-0.1, 0.02]:
		k.cylinder(Vector3(-0.46, 0.04, z), 0.055, 0.1, WOOD, Kit.TIMBER, 8)
		k.cylinder(Vector3(-0.46, 0.04 + 0.1, z), 0.057, 0.008, DWOOD, Kit.TIMBER, 8)
	_amphora(k, Vector3(-0.48, 0.04, 0.2), 0.45)
	_amphora(k, Vector3(-0.40, 0.04, 0.22), 0.4)
	_amphora(k, Vector3(0.38, 0.04, 0.22), 0.4)
	_amphora(k, Vector3(0.34, 0.04, 0.27), 0.45, Color(0.7, 0.5, 0.32))
	# bench and table out front
	k.box(Vector3(0.0, 0.04, 0.42), Vector3(0.18, 0.045, 0.07), WOOD, Kit.TIMBER)


# --- palace: the great peripteral temple ------------------------------------------------------


static func _temple(k: Kit) -> void:
	var sx := 0.92
	var sz := 1.32
	for i in 3:   # krepis
		var e := (2 - i) * 0.06
		k.box(Vector3(0, i * 0.09, 0), Vector3((sx + e) * 2.0, 0.09, (sz + e) * 2.0), Color(0.90, 0.88, 0.82).darkened(0.03 * (2 - i)), Kit.STONE)
	var y0 := 0.27
	var cxs := 0.80
	var czs := 1.2
	var hc := 0.95
	var nf := 6
	var ns := 9
	# cella and pronaos
	k.box(Vector3(0, y0, -0.1), Vector3(1.0, 1.06, 1.9), Color(0.92, 0.82, 0.62), Kit.PLASTER)
	k.box(Vector3(0, y0, -0.1), Vector3(1.03, 0.05, 1.93), MARBLE_D, Kit.STONE)
	for s in [-1.0, 1.0]:   # antae
		k.box(Vector3(s * 0.5, y0, 0.86), Vector3(0.08, 1.06, 0.1), MARBLE, Kit.STONE)
	k.door(Vector3(0, y0, 0.86), 0.0, 0.26, 0.62, MARBLE, DWOOD)
	for s in [-1.0, 1.0]:
		_win(k, Vector3(s * 0.28, y0 + 0.72, 0.8501), 0.0, 0.08, 0.1, MARBLE, "plain")
	# peristyle
	for i in nf:
		var x := -cxs + i * (2.0 * cxs / (nf - 1))
		_col(k, Vector3(x, y0, czs), 0.06, hc, MARBLE, "doric", 14)
		_col(k, Vector3(x, y0, -czs), 0.06, hc, MARBLE, "doric", 14)
	for i in range(1, ns - 1):
		var z := -czs + i * (2.0 * czs / (ns - 1))
		_col(k, Vector3(-cxs, y0, z), 0.06, hc, MARBLE, "doric", 14)
		_col(k, Vector3(cxs, y0, z), 0.06, hc, MARBLE, "doric", 14)
	# entablature
	var ya := y0 + hc
	var ex := cxs + 0.08
	var ez := czs + 0.08
	for s in [-1.0, 1.0]:
		k.box(Vector3(0, ya, s * czs), Vector3(ex * 2.0, 0.1, 0.17), MARBLE, Kit.STONE)
		k.box(Vector3(s * cxs, ya, 0), Vector3(0.17, 0.1, ez * 2.0), MARBLE, Kit.STONE)
		k.box(Vector3(0, ya + 0.1, s * czs), Vector3(ex * 2.0 - 0.02, 0.13, 0.14), Color(0.88, 0.76, 0.58), Kit.PLASTER)
		k.box(Vector3(s * cxs, ya + 0.1, 0), Vector3(0.14, 0.13, ez * 2.0 - 0.02), Color(0.88, 0.76, 0.58), Kit.PLASTER)
		k.box(Vector3(0, ya + 0.23, s * czs), Vector3(ex * 2.0 + 0.04, 0.045, 0.2), MARBLE, Kit.STONE)
		k.box(Vector3(s * cxs, ya + 0.23, 0), Vector3(0.2, 0.045, ez * 2.0 + 0.04), MARBLE, Kit.STONE)
		k.box(Vector3(0, ya + 0.275, s * czs), Vector3(ex * 2.0 + 0.1, 0.02, 0.24), MARBLE_D, Kit.STONE)
		k.box(Vector3(s * cxs, ya + 0.275, 0), Vector3(0.24, 0.02, ez * 2.0 + 0.1), MARBLE_D, Kit.STONE)
	# triglyphs on all four sides
	var bay_x := 2.0 * cxs / (nf - 1)
	for i in nf * 2 - 1:
		var x := -cxs + i * bay_x / 2.0
		for s in [-1.0, 1.0]:
			k.box(Vector3(x, ya + 0.1, s * (czs + 0.075)), Vector3(0.045, 0.13, 0.02), BLUE, Kit.PAINT)
	var bay_z := 2.0 * czs / (ns - 1)
	for i in range(1, (ns - 1) * 2):
		var z := -czs + i * bay_z / 2.0
		for s in [-1.0, 1.0]:
			k.box(Vector3(s * (cxs + 0.075), ya + 0.1, z), Vector3(0.02, 0.13, 0.045), BLUE, Kit.PAINT)
	# roof and pediment
	var rf := ya + 0.295
	k.gable_roof(Vector3(0, rf, 0), ez * 2.0 + 0.06, ex * 2.0 + 0.06, 0.34, 0.05, 0.035, TERRA, Kit.OWNER_ROOF,
		Color(0.36, 0.50, 0.66), Kit.PLASTER, PI / 2.0)
	for s in [-1.0, 1.0]:
		var zf: float = s * (ez + 0.03)
		k.rod(Vector3(-ex - 0.05, rf + 0.01, zf + s * 0.02), Vector3(0, rf + 0.35, zf + s * 0.02), 0.018, MARBLE, Kit.STONE)
		k.rod(Vector3(ex + 0.05, rf + 0.01, zf + s * 0.02), Vector3(0, rf + 0.35, zf + s * 0.02), 0.018, MARBLE, Kit.STONE)
		k.box(Vector3(0, rf, zf + s * 0.01), Vector3(ex * 2.0 + 0.1, 0.025, 0.045), MARBLE, Kit.STONE)
		# sculpture group in the tympanum: standing and reclining figures
		for i in 7:
			var fx := -0.7 + i * 0.233
			var room := 0.34 * (1.0 - absf(fx) / (ex + 0.05)) - 0.05
			if room < 0.03:
				continue
			if i % 3 == 0 and i != 3:
				k.box(Vector3(fx, rf + 0.03, zf), Vector3(0.12, 0.04, 0.03), MARBLE, Kit.STONE)
				k.dome(Vector3(fx - 0.04, rf + 0.07, zf), 0.022, MARBLE, Kit.STONE, 1.0, 2, 6)
			else:
				k.frustum(Vector3(fx, rf + 0.03, zf), 0.022, 0.014, room * 0.8, MARBLE, Kit.STONE, 6)
				k.dome(Vector3(fx, rf + 0.03 + room * 0.8, zf), 0.02, MARBLE, Kit.STONE, 1.0, 2, 6)
		# acroteria: a palmette fan at the apex, smaller ones at the corners
		for q in 5:
			var qa := -0.5 + q * 0.25
			k.push(Transform3D(Basis(Vector3(0, 0, 1), qa * 1.2), Vector3(0, rf + 0.355, zf)))
			k.box(Vector3.ZERO, Vector3(0.025, 0.1 - absf(qa) * 0.05, 0.03), GOLD_C, Kit.GOLD)
			k.pop()
		for sx2 in [-1.0, 1.0]:
			k.box(Vector3(sx2 * (ex + 0.03), rf - 0.02, zf), Vector3(0.05, 0.06, 0.03), GOLD_C, Kit.GOLD)
	# altar in front
	k.box(Vector3(0, 0.0, 1.5), Vector3(0.34, 0.04, 0.2), GREY, Kit.STONE)
	k.box(Vector3(0, 0.04, 1.5), Vector3(0.26, 0.12, 0.14), MARBLE, Kit.STONE)
	k.box(Vector3(0, 0.16, 1.5), Vector3(0.3, 0.025, 0.17), MARBLE, Kit.STONE)
	for x in [-0.13, 0.13]:
		for z in [1.43, 1.57]:
			k.box(Vector3(x, 0.185, z), Vector3(0.03, 0.03, 0.03), MARBLE, Kit.STONE)
	k.frustum(Vector3(0, 0.185, 1.5), 0.04, 0.0, 0.07, Color(0.95, 0.55, 0.2), Kit.GOLD, 5)
	# braziers either side of the steps
	for x in [-0.45, 0.45]:
		k.frustum(Vector3(x, 0.0, 1.5), 0.04, 0.025, 0.14, GOLD_C.darkened(0.2), Kit.GOLD, 6)
		k.frustum(Vector3(x, 0.14, 1.5), 0.05, 0.065, 0.03, GOLD_C, Kit.GOLD, 6)


# --- forum hall: basilica with colonnade ---------------------------------------------------


static func _basilica(k: Kit) -> void:
	var hl := 1.15   # half length
	for i in 2:
		var e := (1 - i) * 0.04
		k.box(Vector3(0, i * 0.04, 0.05), Vector3(hl * 2.0 + 0.1 + e * 2.0, 0.04, 1.3 + e * 2.0), Color(0.86, 0.83, 0.76), Kit.STONE)
	var y0 := 0.08
	# aisle body and nave
	k.box(Vector3(0, y0, -0.12), Vector3(hl * 2.0, 0.66, 1.0), Color(0.92, 0.74, 0.58), Kit.PLASTER)
	k.box(Vector3(0, y0, -0.12), Vector3(hl * 2.0 + 0.03, 0.06, 1.03), MARBLE_D, Kit.STONE)
	k.box(Vector3(0, y0 + 0.66, -0.12), Vector3(hl * 2.0 + 0.04, 0.03, 1.04), MARBLE, Kit.STONE)
	k.box(Vector3(0, y0 + 0.69, -0.12), Vector3(hl * 2.0 - 0.1, 0.3, 0.56), Color(0.95, 0.88, 0.74), Kit.PLASTER)   # clerestory
	k.box(Vector3(0, y0 + 0.99, -0.12), Vector3(hl * 2.0 - 0.06, 0.025, 0.6), MARBLE, Kit.STONE)
	for i in 11:
		var x := -1.0 + i * 0.2
		_win(k, Vector3(x, y0 + 0.86, 0.1601), 0.0, 0.07, 0.15, MARBLE, "arch")
		_win(k, Vector3(x, y0 + 0.86, -0.4001), PI, 0.07, 0.15, MARBLE, "arch")
	# nave roof and aisle pent roofs
	_tile_gable(k, Vector3(0, y0 + 1.015, -0.12), hl * 2.0 - 0.06, 0.6, 0.14, 0.04, Color(0.95, 0.88, 0.74))
	_slab(k, [Vector3(-hl - 0.04, y0 + 0.76, 0.5), Vector3(hl + 0.04, y0 + 0.76, 0.5), Vector3(hl + 0.04, y0 + 0.96, 0.12), Vector3(-hl - 0.04, y0 + 0.96, 0.12)], 0.03, TERRA, Kit.OWNER_ROOF)
	_slab(k, [Vector3(hl + 0.04, y0 + 0.76, -0.74), Vector3(-hl - 0.04, y0 + 0.76, -0.74), Vector3(-hl - 0.04, y0 + 0.96, -0.44), Vector3(hl + 0.04, y0 + 0.96, -0.44)], 0.03, TERRA, Kit.OWNER_ROOF)
	# front colonnade
	for i in 12:
		var x := -hl + 0.06 + i * ((hl * 2.0 - 0.12) / 11.0)
		_col(k, Vector3(x, y0, 0.56), 0.036, 0.6, MARBLE, "ionic", 10)
	k.box(Vector3(0, y0 + 0.6, 0.56), Vector3(hl * 2.0 + 0.04, 0.07, 0.1), MARBLE, Kit.STONE)
	k.box(Vector3(0, y0 + 0.67, 0.56), Vector3(hl * 2.0 + 0.08, 0.025, 0.12), MARBLE_D, Kit.STONE)
	# doors and windows behind the colonnade
	for x in [-0.8, -0.4, 0.4, 0.8]:
		_win(k, Vector3(x, y0 + 0.4, 0.3801), 0.0, 0.1, 0.18, MARBLE, "arch")
	for x in [-0.2, 0.2]:
		k.door(Vector3(x, y0, 0.3801), 0.0, 0.14, 0.34, MARBLE, DWOOD)
	# central porch: temple front with pediment
	for x in [-0.2, -0.07, 0.07, 0.2]:
		_col(k, Vector3(x, y0, 0.68), 0.04, 0.8, MARBLE, "ionic", 10)
	k.box(Vector3(0, y0, 0.66), Vector3(0.6, 0.02, 0.3), MARBLE_D, Kit.STONE)
	k.box(Vector3(0, y0 + 0.8, 0.62), Vector3(0.58, 0.07, 0.26), MARBLE, Kit.STONE)
	k.gable_roof(Vector3(0, y0 + 0.87, 0.62), 0.26, 0.56, 0.18, 0.03, 0.03, TERRA, Kit.OWNER_ROOF, Color(0.36, 0.50, 0.66),
		Kit.PLASTER, PI / 2.0)
	k.dome(Vector3(0, y0 + 0.9, 0.76), 0.04, GOLD_C, Kit.GOLD, 0.6, 2, 6)
	# end gables closed with pediment and corner acroteria
	for s in [-1.0, 1.0]:
		_win(k, Vector3(s * (hl + 0.0001), y0 + 0.4, -0.12), s * PI / 2.0, 0.1, 0.2, MARBLE, "arch")
		k.frustum(Vector3(s * (hl + 0.02), y0 + 0.76, 0.5), 0.03, 0.0, 0.1, GOLD_C, Kit.GOLD, 5)
	# banner of the owner over the porch


# --- triumphal arch ---------------------------------------------------------------------------


static func _arch(k: Kit) -> void:
	var d := 0.5
	var hd := d / 2.0
	k.box(Vector3(0, 0, 0), Vector3(1.38, 0.05, d + 0.12), GREY, Kit.STONE)
	k.box(Vector3(0, 0.05, 0), Vector3(1.32, 0.04, d + 0.06), MARBLE_D, Kit.STONE)
	var yb := 0.09
	var r := 0.22
	var spring := yb + 0.4
	var ytop := spring + r + 0.07
	var hh := ytop - yb
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.435, yb, 0), Vector3(0.43, hh, d), Color(0.92, 0.88, 0.80), Kit.STONE)
	# arch spandrels, archivolt and soffit
	var n := 10
	var stone := Color(0.92, 0.88, 0.80)
	var dark := Color(0.30, 0.26, 0.22)
	for zf in [hd, -hd]:
		for i in n:
			var a0 := PI - PI * i / n
			var a1 := PI - PI * (i + 1) / n
			var p0 := Vector3(cos(a0) * r, spring + sin(a0) * r, zf)
			var p1 := Vector3(cos(a1) * r, spring + sin(a1) * r, zf)
			k.quad(p0, p1, Vector3(p1.x, ytop, zf), Vector3(p0.x, ytop, zf), stone, Kit.STONE, Vector3(0, spring, 0))
			# archivolt moulding
			var q0 := Vector3(cos(a0) * (r + 0.045), spring + sin(a0) * (r + 0.045), zf + signf(zf) * 0.014)
			var q1 := Vector3(cos(a1) * (r + 0.045), spring + sin(a1) * (r + 0.045), zf + signf(zf) * 0.014)
			var r0 := Vector3(cos(a0) * r, spring + sin(a0) * r, zf + signf(zf) * 0.014)
			var r1 := Vector3(cos(a1) * r, spring + sin(a1) * r, zf + signf(zf) * 0.014)
			k.quad(r0, r1, q1, q0, MARBLE, Kit.STONE, Vector3(0, spring, 0))
			if zf > 0.0:
				var s0 := Vector3(cos(a0) * r, spring + sin(a0) * r, hd)
				var s1 := Vector3(cos(a1) * r, spring + sin(a1) * r, hd)
				var t0 := Vector3(cos(a0) * r, spring + sin(a0) * r, -hd)
				var t1 := Vector3(cos(a1) * r, spring + sin(a1) * r, -hd)
				k.quad(s0, s1, t1, t0, dark, Kit.STONE, Vector3(0, 10, 0))
	k.quad(Vector3(-r, yb, hd), Vector3(-r, spring, hd), Vector3(-r, spring, -hd), Vector3(-r, yb, -hd), dark, Kit.STONE, Vector3(0, 0.3, 0))
	k.quad(Vector3(r, yb, hd), Vector3(r, spring, hd), Vector3(r, spring, -hd), Vector3(r, yb, -hd), dark, Kit.STONE, Vector3(0, 0.3, 0))
	k.quad(Vector3(-r, yb, hd), Vector3(r, yb, hd), Vector3(r, yb, -hd), Vector3(-r, yb, -hd), dark.darkened(0.2), Kit.STONE, Vector3(0, 5, 0))
	# side niches with statues
	for s in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_win(k, Vector3(s * 0.54, yb + 0.28, z * (hd + 0.001)), 0.0 if z > 0 else PI, 0.1, 0.24, MARBLE, "arch")
			k.box(Vector3(s * 0.54, yb + 0.05, z * (hd + 0.01)), Vector3(0.03, 0.14, 0.02), GOLD_C, Kit.GOLD)
	# engaged columns on pedestals, front and back
	for z in [-1.0, 1.0]:
		for x in [-0.64, -0.3, 0.3, 0.64]:
			k.box(Vector3(x, yb, z * (hd + 0.03)), Vector3(0.1, 0.1, 0.08), MARBLE, Kit.STONE)
			_col(k, Vector3(x, yb + 0.1, z * (hd + 0.035)), 0.034, ytop - yb - 0.1, MARBLE, "ionic", 10)
	# entablature with projecting blocks, attic, inscription
	k.box(Vector3(0, ytop, 0), Vector3(1.34, 0.05, d + 0.04), MARBLE, Kit.STONE)
	k.box(Vector3(0, ytop + 0.05, 0), Vector3(1.36, 0.03, d + 0.07), MARBLE_D, Kit.STONE)
	for z in [-1.0, 1.0]:
		for x in [-0.64, -0.3, 0.3, 0.64]:
			k.box(Vector3(x, ytop, z * (hd + 0.045)), Vector3(0.12, 0.08, 0.07), MARBLE, Kit.STONE)
	var ya := ytop + 0.08
	k.box(Vector3(0, ya, 0), Vector3(1.0, 0.26, d - 0.08), Color(0.90, 0.85, 0.76), Kit.STONE)
	k.box(Vector3(0, ya + 0.26, 0), Vector3(1.06, 0.035, d - 0.02), MARBLE, Kit.STONE)
	for z in [-1.0, 1.0]:
		k.box(Vector3(0, ya + 0.08, z * (hd - 0.035)), Vector3(0.62, 0.1, 0.012), Color(0.30, 0.26, 0.22), Kit.PAINT)
		for x in [-0.45, 0.45]:   # relief panels
			k.box(Vector3(x, ya + 0.06, z * (hd - 0.035)), Vector3(0.14, 0.14, 0.012), MARBLE_D, Kit.STONE)
	# quadriga
	var yq := ya + 0.295
	k.box(Vector3(0, yq, 0), Vector3(0.3, 0.04, 0.2), MARBLE, Kit.STONE)
	k.box(Vector3(0, yq + 0.04, -0.03), Vector3(0.12, 0.05, 0.1), GOLD_C, Kit.GOLD)
	k.frustum(Vector3(0, yq + 0.09, -0.03), 0.02, 0.015, 0.07, GOLD_C, Kit.GOLD, 5)
	k.dome(Vector3(0, yq + 0.16, -0.03), 0.022, GOLD_C, Kit.GOLD, 1.0, 2, 6)
	for i in 4:
		var hx := -0.108 + i * 0.072
		k.box(Vector3(hx, yq + 0.04, 0.05), Vector3(0.04, 0.06, 0.1), GOLD_C, Kit.GOLD)
		k.box(Vector3(hx, yq + 0.1, 0.09), Vector3(0.035, 0.05, 0.035), GOLD_C, Kit.GOLD)


# --- villa_great: a rich urban mansion with a peristyle garden ----------------------------------


static func _great_villa(k: Kit) -> void:
	var o := 0.95
	k.box(Vector3(0, 0, 0), Vector3(2.0, 0.04, 2.0), Color(0.80, 0.72, 0.58), Kit.EARTH)
	k.box(Vector3(0, 0.04, 0), Vector3(1.96, 0.02, 1.96), GREY, Kit.STONE)
	var ic := 0.56      # inner court half-size
	var wl := Color(0.92, 0.72, 0.50)
	# front wing: street frontage with shops, the grand doorway and the fauces
	k.box(Vector3(0, 0.06, 0.76), Vector3(1.88, 0.42, 0.36), wl, Kit.PLASTER)
	k.box(Vector3(0, 0.06, 0.76), Vector3(1.9, 0.07, 0.38), RED, Kit.PLASTER)
	k.box(Vector3(0, 0.48, 0.76), Vector3(1.92, 0.035, 0.4), MARBLE, Kit.STONE)
	_tile_gable(k, Vector3(0, 0.515, 0.76), 1.88, 0.36, 0.13, 0.05, wl)
	for x in [-0.75, -0.55, 0.55, 0.75]:
		_win(k, Vector3(x, 0.27, 0.9401), 0.0, 0.1, 0.22, MARBLE, "arch")
	for x in [-0.4, 0.4]:
		_win(k, Vector3(x, 0.34, 0.9401), 0.0, 0.1, 0.1, MARBLE, "plain")
	k.box(Vector3(0, 0.06, 0.94), Vector3(0.36, 0.4, 0.05), MARBLE, Kit.STONE)
	k.door(Vector3(0, 0.06, 0.966), 0.0, 0.18, 0.3, MARBLE, DWOOD)
	k.gable_roof(Vector3(0, 0.46, 0.94), 0.12, 0.4, 0.1, 0.03, 0.025, TERRA, Kit.OWNER_ROOF, LIME, Kit.PLASTER, PI / 2.0)
	for x in [-0.15, 0.15]:
		_col(k, Vector3(x, 0.06, 0.99), 0.026, 0.36, MARBLE, "tuscan", 10)
	# side wings
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.79, 0.06, -0.12), Vector3(0.32, 0.38, 1.1), wl, Kit.PLASTER)
		k.box(Vector3(s * 0.79, 0.06, -0.12), Vector3(0.34, 0.06, 1.12), RED, Kit.PLASTER)
		k.box(Vector3(s * 0.79, 0.44, -0.12), Vector3(0.35, 0.03, 1.13), MARBLE, Kit.STONE)
		k.push(Kit.at(Vector3(s * 0.79, 0.47, -0.12), PI / 2.0))
		k.gable_roof(Vector3.ZERO, 1.1, 0.32, 0.11, 0.04, 0.028, TERRA, Kit.OWNER_ROOF, wl, Kit.PLASTER)
		k.pop()
		for z in [-0.4, -0.12, 0.16]:
			_win(k, Vector3(s * 0.951, 0.3, z), s * PI / 2.0, 0.07, 0.12, MARBLE, "plain")
	# rear wing: the big dining hall, two storeys with a tower-like clerestory
	k.box(Vector3(0, 0.06, -0.78), Vector3(1.88, 0.5, 0.34), Color(0.95, 0.80, 0.66), Kit.PLASTER)
	k.box(Vector3(0, 0.06, -0.78), Vector3(1.9, 0.07, 0.36), RED, Kit.PLASTER)
	k.box(Vector3(0, 0.56, -0.78), Vector3(1.92, 0.035, 0.38), MARBLE, Kit.STONE)
	k.box(Vector3(0, 0.595, -0.78), Vector3(0.8, 0.26, 0.3), LIME, Kit.PLASTER)
	for x in [-0.28, 0.0, 0.28]:
		_win(k, Vector3(x, 0.74, -0.629), 0.0, 0.1, 0.14, MARBLE, "arch")
		_win(k, Vector3(x, 0.74, -0.931), PI, 0.1, 0.14, MARBLE, "arch")
	_tile_gable(k, Vector3(0, 0.855, -0.78), 0.8, 0.3, 0.17, 0.05, LIME)
	_tile_gable(k, Vector3(-0.64, 0.595, -0.78), 0.6, 0.34, 0.15, 0.05, Color(0.95, 0.8, 0.66))
	_tile_gable(k, Vector3(0.64, 0.595, -0.78), 0.6, 0.34, 0.15, 0.05, Color(0.95, 0.8, 0.66))
	for x in [-0.7, 0.7]:
		_win(k, Vector3(x, 0.4, -0.629), 0.0, 0.1, 0.16, MARBLE, "arch")
	# peristyle colonnade round the court, with a pent roof
	var ch := 0.34
	var n := 6
	for i in n:
		var t := -ic + i * 2.0 * ic / (n - 1)
		_col(k, Vector3(t, 0.06, ic), 0.024, ch, MARBLE, "tuscan", 8)
		_col(k, Vector3(t, 0.06, -ic), 0.024, ch, MARBLE, "tuscan", 8)
		if i > 0 and i < n - 1:
			_col(k, Vector3(-ic, 0.06, t), 0.024, ch, MARBLE, "tuscan", 8)
			_col(k, Vector3(ic, 0.06, t), 0.024, ch, MARBLE, "tuscan", 8)
	k.box(Vector3(0, 0.06 + ch, ic), Vector3(ic * 2.0 + 0.1, 0.04, 0.06), MARBLE, Kit.STONE)
	k.box(Vector3(0, 0.06 + ch, -ic), Vector3(ic * 2.0 + 0.1, 0.04, 0.06), MARBLE, Kit.STONE)
	k.box(Vector3(-ic, 0.06 + ch, 0), Vector3(0.06, 0.04, ic * 2.0), MARBLE, Kit.STONE)
	k.box(Vector3(ic, 0.06 + ch, 0), Vector3(0.06, 0.04, ic * 2.0), MARBLE, Kit.STONE)
	# garden: central pool, bushes, trees, paths
	k.box(Vector3(0, 0.06, 0), Vector3(1.0, 0.01, 1.0), Color(0.78, 0.74, 0.62), Kit.EARTH)
	k.box(Vector3(0, 0.06, 0), Vector3(0.14, 0.012, 1.0), Color(0.80, 0.78, 0.70), Kit.STONE)
	k.box(Vector3(0, 0.06, 0), Vector3(1.0, 0.012, 0.14), Color(0.80, 0.78, 0.70), Kit.STONE)
	k.box(Vector3(0, 0.06, 0), Vector3(0.36, 0.05, 0.26), MARBLE, Kit.STONE)
	k.box(Vector3(0, 0.1, 0), Vector3(0.3, 0.012, 0.2), Color.WHITE, Kit.WATER)
	k.frustum(Vector3(0, 0.1, 0), 0.025, 0.012, 0.1, MARBLE, Kit.STONE, 6)
	for qx in [-1.0, 1.0]:
		for qz in [-1.0, 1.0]:
			k.dome(Vector3(qx * 0.3, 0.06, qz * 0.3), 0.12, GREEN, Kit.LEAF, 0.55, 3, 8)
			k.dome(Vector3(qx * 0.38, 0.06, qz * 0.22), 0.07, DGREEN, Kit.LEAF, 0.8, 2, 7)
	_cypress(k, Vector3(-0.42, 0.06, 0.0), 1.1)
	_cypress(k, Vector3(0.42, 0.06, 0.0), 1.1)
	# statues in the garden
	for p in [Vector3(-0.28, 0.06, 0.0), Vector3(0.28, 0.06, 0.0)]:
		k.box(p, Vector3(0.05, 0.08, 0.05), MARBLE, Kit.STONE)
		k.frustum(p + Vector3(0, 0.08, 0), 0.016, 0.01, 0.09, MARBLE, Kit.PAINT, 6)
	# a little shrine/lararium with banner on the roof ridge
	# corner amphorae and planters outside
	_amphora(k, Vector3(-0.9, 0.06, 1.02), 0.5)
	_amphora(k, Vector3(0.9, 0.06, 1.02), 0.5)
