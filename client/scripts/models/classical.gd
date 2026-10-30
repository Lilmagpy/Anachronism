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


## The original hand-modelled kinds (other code names them directly).
const LEGACY := ["house_1", "house_2", "house_3", "house_4", "house_5", "house_6",
	"palace", "forum_hall", "triumphal_arch", "villa_great"]

## Generated houses: one family per name, a variant number at the end picks its parameters.
const GENERATED := [
	"house_rom_domus_1", "house_rom_domus_2", "house_rom_domus_3", "house_rom_domus_4",
	"house_rom_insula_1", "house_rom_insula_2", "house_rom_insula_3", "house_rom_insula_4",
	"house_rom_taberna_1", "house_rom_taberna_2", "house_rom_taberna_3",
	"house_rom_cottage_1", "house_rom_cottage_2", "house_rom_cottage_3",
	"house_rom_farm_1", "house_rom_farm_2", "house_rom_farm_3", "house_rom_farm_4",
	"house_gr_court_1", "house_gr_court_2", "house_gr_court_3", "house_gr_court_4",
	"house_gr_cube_1", "house_gr_cube_2", "house_gr_cube_3",
	"house_pun_tall_1", "house_pun_tall_2", "house_pun_tall_3", "house_pun_tall_4",
	"house_pun_low_1", "house_pun_low_2",
	"house_byz_1", "house_byz_2", "house_byz_3", "house_byz_4",
	"house_byz_chapel_1", "house_byz_chapel_2",
	"big_rom_insula_1", "big_rom_insula_2", "big_rom_domus_1", "big_rom_domus_2",
	"big_rom_farm_1", "big_rom_farm_2", "big_gr_court_1", "big_gr_court_2",
	"big_pun_row_1", "big_pun_row_2", "big_byz_1", "big_byz_2",
	"prop_amphorae", "prop_altar", "prop_herm", "prop_fountain_basin", "prop_pergola",
]


static func kinds() -> Array:
	return LEGACY + GENERATED


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
		_:
			_generate(k, kind)
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


# =============================================================================================
# GENERATED HOUSES (D-281): the same few builders, driven by tables of parameters, so every
# city draws on dozens of different houses instead of two. Each family below turns a variant
# number into a width, depth, storey list, roof form, wall finish, shopfronts, balconies,
# pergolas, stairs and so on.
# =============================================================================================

const DARKC := Color(0.07, 0.05, 0.04)
const BRICKC := Color(0.74, 0.46, 0.34)
const STONEC := Color(0.78, 0.74, 0.66)
const TILE_RED := Color(0.72, 0.34, 0.22)
const TILE_ORG := Color(0.84, 0.52, 0.28)
const TILE_BRN := Color(0.58, 0.38, 0.28)
const TILE_GRY := Color(0.60, 0.57, 0.52)
const WHITE := Color(0.97, 0.96, 0.92)
const THATCHC := Color(0.74, 0.62, 0.38)
const SAND := Color(0.86, 0.76, 0.58)
const CREAM := Color(0.95, 0.90, 0.78)
const SALMON := Color(0.92, 0.70, 0.58)
const YELLOW := Color(0.92, 0.80, 0.50)
const EARTHC := Color(0.70, 0.60, 0.46)


## Turn a generated kind's name ("house_rom_insula_3") into its family and variant.
static func _generate(k: Kit, kind: String) -> void:
	var fit := 1.0   # a few kinds are modelled a little wide for one lot
	if kind.begins_with("house_rom_domus") or kind in ["house_rom_insula_3", "house_rom_farm_1", "house_rom_cottage_2"]:
		fit = 0.92
	if fit < 1.0:
		k.push(Transform3D(Basis.from_scale(Vector3(fit, fit, fit)), Vector3.ZERO))
	_generate_family(k, kind)
	if fit < 1.0:
		k.pop()


static func _generate_family(k: Kit, kind: String) -> void:
	var v := int(kind.substr(kind.rfind("_") + 1))
	match kind.substr(0, kind.rfind("_")):
		"house_rom_domus":
			_g_domus(k, v)
		"house_rom_insula":
			_g_insula(k, v)
		"house_rom_taberna":
			_g_taberna(k, v)
		"house_rom_cottage":
			_g_cottage(k, v)
		"house_rom_farm":
			_g_farm(k, v)
		"house_gr_court":
			_g_court(k, v)
		"house_gr_cube":
			_g_cube(k, v)
		"house_pun_tall":
			_g_punic(k, v)
		"house_pun_low":
			_g_punic_low(k, v)
		"house_byz":
			_g_byz(k, v)
		"house_byz_chapel":
			_g_chapel(k, v)
		"big_rom_insula":
			_big_insula(k, v)
		"big_rom_domus":
			_big_domus(k, v)
		"big_rom_farm":
			_big_farm(k, v)
		"big_gr_court":
			_big_court(k, v)
		"big_pun_row":
			_big_punic(k, v)
		"big_byz":
			_big_byz(k, v)
		_:
			_g_prop(k, kind)


# --- small parts --------------------------------------------------------------------------------


## A window: pale frame, dark pane, optional shutters. `at_pos` = bottom middle on the wall face.
static func _op(k: Kit, at_pos: Vector3, yaw: float, w: float, h: float, shut := false, frame := MARBLE, shc := WOOD) -> void:
	k.push(Kit.at(at_pos, yaw))
	var f := w * 0.18
	var mid := Vector3(0, h / 2.0, -1.0)
	k.quad(Vector3(-w / 2 - f, -f, 0.006), Vector3(w / 2 + f, -f, 0.006), Vector3(w / 2 + f, h + f, 0.006),
		Vector3(-w / 2 - f, h + f, 0.006), frame, Kit.STONE, mid)
	k.quad(Vector3(-w / 2, 0, 0.011), Vector3(w / 2, 0, 0.011), Vector3(w / 2, h, 0.011), Vector3(-w / 2, h, 0.011),
		DARKC, Kit.DARK, mid)
	if shut:
		for s in [-1.0, 1.0]:
			var x0: float = s * (w / 2 + f)
			var x1: float = s * (w / 2 + f + w * 0.42)
			k.quad(Vector3(x0, -f, 0.016), Vector3(x1, -f, 0.016), Vector3(x1, h + f, 0.016), Vector3(x0, h + f, 0.016),
				shc, Kit.TIMBER, mid)
	k.pop()


## An arched shop opening (taberna) with a pale surround; `counter` adds a stone counter.
static func _arch_op(k: Kit, at_pos: Vector3, yaw: float, w: float, h: float, counter := false) -> void:
	k.push(Kit.at(at_pos, yaw))
	var f := w * 0.14
	var hs := maxf(h - w / 2.0, 0.02)
	var inner: Array = [Vector3(-w / 2, 0, 0.011), Vector3(w / 2, 0, 0.011)]
	var outer: Array = [Vector3(-w / 2 - f, 0, 0.006), Vector3(w / 2 + f, 0, 0.006)]
	for i in 5:
		var a := i * PI / 4.0
		inner.append(Vector3(cos(a) * w / 2, hs + sin(a) * w / 2, 0.011))
		outer.append(Vector3(cos(a) * (w / 2 + f), hs + sin(a) * (w / 2 + f), 0.006))
	var mid := Vector3(0, hs, -1.0)
	k.polygon(outer, MARBLE, Kit.STONE, mid)
	k.polygon(inner, DARKC, Kit.DARK, mid)
	if counter:
		k.box(Vector3(0, 0, 0.035), Vector3(w * 0.95, 0.06, 0.06), MARBLE_D, Kit.STONE)
	k.pop()


## A door: pale surround, wooden leaf.
static func _dr(k: Kit, at_pos: Vector3, yaw: float, w: float, h: float, leaf := DWOOD, frame := MARBLE) -> void:
	k.push(Kit.at(at_pos, yaw))
	var f := w * 0.16
	var mid := Vector3(0, h / 2.0, -1.0)
	k.quad(Vector3(-w / 2 - f, 0, 0.006), Vector3(w / 2 + f, 0, 0.006), Vector3(w / 2 + f, h + f, 0.006),
		Vector3(-w / 2 - f, h + f, 0.006), frame, Kit.STONE, mid)
	k.quad(Vector3(-w / 2, 0, 0.011), Vector3(w / 2, 0, 0.011), Vector3(w / 2, h, 0.011), Vector3(-w / 2, h, 0.011),
		leaf, Kit.TIMBER, mid)
	k.pop()


## A column that is cheap: a tapering shaft and a flat capital.
static func _pil(k: Kit, foot: Vector3, h: float, r := 0.022, col := MARBLE) -> void:
	k.frustum(foot, r, r * 0.84, h - 0.02, col, Kit.PAINT, 5, false)
	k.box(foot + Vector3(0, h - 0.02, 0), Vector3(r * 3.0, 0.02, r * 3.0), col, Kit.STONE)


## A cheap amphora: belly, shoulder, neck. About 30-40 triangles.
static func _amph(k: Kit, foot: Vector3, s := 1.0, col := TERRACOTTA, sides := 6) -> void:
	k.frustum(foot, 0.03 * s, 0.1 * s, 0.15 * s, col, Kit.PAINT, sides, false)
	k.frustum(foot + Vector3(0, 0.15 * s, 0), 0.1 * s, 0.04 * s, 0.13 * s, col, Kit.PAINT, sides, false)
	k.frustum(foot + Vector3(0, 0.28 * s, 0), 0.04 * s, 0.05 * s, 0.035 * s, col.darkened(0.15), Kit.PAINT, sides)


## A small barrel.
static func _barrel(k: Kit, foot: Vector3, s := 1.0) -> void:
	k.frustum(foot, 0.032 * s, 0.04 * s, 0.035 * s, WOOD, Kit.TIMBER, 6, false)
	k.frustum(foot + Vector3(0, 0.035 * s, 0), 0.04 * s, 0.032 * s, 0.035 * s, WOOD, Kit.TIMBER, 6)


## A grain sack leaning in a heap.
static func _sack(k: Kit, foot: Vector3, s := 1.0) -> void:
	k.box(foot, Vector3(0.07 * s, 0.07 * s, 0.05 * s), CREAM.darkened(0.08), Kit.CLOTH, 0.4)
	k.box(foot + Vector3(0, 0.07 * s, 0), Vector3(0.04 * s, 0.025 * s, 0.03 * s), CREAM.darkened(0.2), Kit.CLOTH, 0.4)


## A stack of split logs.
static func _logs(k: Kit, foot: Vector3, yaw := 0.0) -> void:
	for i in 3:
		k.box(foot + Vector3(0, i * 0.035, 0), Vector3(0.14 - i * 0.02, 0.035, 0.07), WOOD if i % 2 == 0 else DWOOD, Kit.TIMBER, yaw)


## A rounded shrub.
static func _shrub(k: Kit, foot: Vector3, r: float, col := GREEN) -> void:
	k.dome(foot, r, col, Kit.LEAF, 0.8, 2, 6)


## An awning of alternating owner-coloured and cream stripes, sloping from the wall (z0, y0) to (z1, y1).
static func _awn(k: Kit, x0: float, x1: float, y0: float, z0: float, y1: float, z1: float, n := 4) -> void:
	var w := (x1 - x0) / n
	for i in n:
		var xa := x0 + i * w
		var odd := i % 2 == 1
		k.quad(Vector3(xa, y0, z0), Vector3(xa + w, y0, z0), Vector3(xa + w, y1, z1), Vector3(xa, y1, z1),
			CREAM if odd else Color(0.85, 0.85, 0.85), Kit.CLOTH if odd else Kit.OWNER_CLOTH, Vector3(xa, y0 - 1.0, z0))


## A timber balcony (maenianum) on the front wall at z, from x0 to x1, floor at y.
static func _balc(k: Kit, x0: float, x1: float, y: float, z: float, depth := 0.11, col := WOOD) -> void:
	var cx := (x0 + x1) / 2.0
	k.box(Vector3(cx, y, z + depth / 2.0), Vector3(x1 - x0, 0.022, depth), col, Kit.TIMBER)
	var ry := y + 0.09
	k.quad(Vector3(x0, y + 0.022, z + depth), Vector3(x1, y + 0.022, z + depth), Vector3(x1, ry, z + depth),
		Vector3(x0, ry, z + depth), DWOOD, Kit.TIMBER, Vector3(cx, y, z + depth - 1.0))
	k.rod(Vector3(x0, ry, z + depth), Vector3(x1, ry, z + depth), 0.007, col, Kit.TIMBER)
	for x in [x0, x1]:
		k.rod(Vector3(x, y, z + depth), Vector3(x, ry + 0.01, z + depth), 0.009, DWOOD, Kit.TIMBER)


## External stone stairs climbing along the wall at z, starting at x and rising toward sgn.
static func _stair(k: Kit, x: float, z: float, sgn: float, top: float, n := 4, depth := 0.09) -> void:
	var sw := 0.07
	for i in n:
		k.box(Vector3(x + sgn * i * sw, 0.0, z + depth / 2.0), Vector3(sw, top * (i + 1) / n, depth), MARBLE_D, Kit.STONE)


## A vine pergola: four posts, cross beams, a few clumps of leaf.
static func _pergola(k: Kit, cx: float, y: float, cz: float, w: float, d: float, h: float) -> void:
	for x in [-w / 2, w / 2]:
		for z in [-d / 2, d / 2]:
			k.rod(Vector3(cx + x, y, cz + z), Vector3(cx + x, y + h, cz + z), 0.011, DWOOD, Kit.TIMBER)
	for z in [-d / 2, 0.0, d / 2]:
		k.rod(Vector3(cx - w / 2 - 0.02, y + h, cz + z), Vector3(cx + w / 2 + 0.02, y + h, cz + z), 0.009, WOOD, Kit.TIMBER)
	for i in 3:
		var x := cx - w / 2 + w * (i + 0.5) / 3.0
		k.box(Vector3(x, y + h + 0.008, cz), Vector3(w * 0.26, 0.026, d * 0.6), GREEN if i != 1 else DGREEN, Kit.LEAF)


## A barrel vault over a box top: ridge along x, `len` long, `span` wide, `rv` high.
static func _vault(k: Kit, cx: float, y: float, cz: float, len: float, span: float, rv: float, col: Color, mat: int, wall: Color) -> void:
	var n := 6
	var ring: Array = []
	for i in n + 1:
		var a := PI * i / n
		ring.append(Vector3(0.0, sin(a) * rv, cos(a) * span / 2.0))
	k.push(Kit.at(Vector3(cx, y, cz)))
	var inside := Vector3(0, 0.0, 0)
	for i in n:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[i + 1]
		k.quad(a + Vector3(-len / 2, 0, 0), a + Vector3(len / 2, 0, 0), b + Vector3(len / 2, 0, 0), b + Vector3(-len / 2, 0, 0), col, mat, inside)
	for sx in [-len / 2, len / 2]:
		var pts: Array = []
		for r in ring:
			var rv3: Vector3 = r
			pts.append(Vector3(sx, rv3.y, rv3.z))
		k.polygon(pts, wall, Kit.PLASTER, inside)
	k.pop()


## A half-round apse (half cylinder with a half-cone roof) facing -z from a box ending at z.
static func _apse(k: Kit, cx: float, y: float, z: float, r: float, h: float, col: Color, mat: int, roof: Color) -> void:
	var n := 6
	k.push(Kit.at(Vector3(cx, y, z)))
	for i in n:
		var a0 := PI * i / n
		var a1 := PI * (i + 1) / n
		var p0 := Vector3(cos(a0) * r, 0, -sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, -sin(a1) * r)
		k.quad(p0, p1, p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0), col, mat, Vector3(0, h / 2, 0))
		k.tri(p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), Vector3(0, h + r * 0.55, 0), roof, Kit.TILE, Vector3(0, h * 0.4, 0))
	k.pop()


# --- roofs --------------------------------------------------------------------------------------


## A roof of form p.roof over a top floor w x d centred at (cx, cz), its eaves at height y.
## Forms: gable (ridge along x unless p.rz), hip, flat (parapet and terrace), lean (one slope
## falling to the front), thatch, dome, vault.
static func _roof(k: Kit, p: Dictionary, y: float, w: float, d: float, cx: float, cz: float, wall: Color) -> void:
	var form: String = p.get("roof", "gable")
	var rise: float = p.get("rise", 0.15)
	var tile: Color = p.get("tile", TERRA)
	var rmat: int = p.get("rmat", Kit.OWNER_ROOF)
	var over: float = p.get("over", 0.05)
	var rz: bool = p.get("rz", false)
	match form:
		"gable":
			if rz:
				k.gable_roof(Vector3(cx, y, cz), d, w, rise, over, 0.03, tile, rmat, wall, Kit.PLASTER, PI / 2.0)
			else:
				k.gable_roof(Vector3(cx, y, cz), w, d, rise, over, 0.03, tile, rmat, wall, Kit.PLASTER)
		"thatch":
			if rz:
				k.gable_roof(Vector3(cx, y, cz), d, w, rise, over + 0.03, 0.05, THATCHC, Kit.THATCH, wall, Kit.PLASTER, PI / 2.0)
			else:
				k.gable_roof(Vector3(cx, y, cz), w, d, rise, over + 0.03, 0.05, THATCHC, Kit.THATCH, wall, Kit.PLASTER)
		"hip":
			k.hip_roof(Vector3(cx, y, cz), w, d, rise, over, 0.03, tile, rmat)
		"lean":
			var lo := y
			var hi := y + rise
			var l := w / 2.0 + over
			var zf := cz + d / 2.0 + over
			var zb := cz - d / 2.0
			_slab(k, [Vector3(cx - l, lo, zf), Vector3(cx + l, lo, zf), Vector3(cx + l, hi, zb), Vector3(cx - l, hi, zb)], 0.03, tile, rmat)
			for s in [-1.0, 1.0]:
				k.tri(Vector3(cx + s * w / 2.0, y, cz + d / 2.0), Vector3(cx + s * w / 2.0, y, zb), Vector3(cx + s * w / 2.0, hi - 0.01, zb),
					wall, Kit.PLASTER, Vector3(cx, y + 0.1, cz))
		"flat":
			var ph: float = p.get("parapet", 0.07)
			var t := 0.04
			k.box(Vector3(cx, y, cz), Vector3(w - 0.02, 0.02, d - 0.02), p.get("deck", SAND), Kit.EARTH)
			k.box(Vector3(cx, y, cz + d / 2.0 - t / 2.0), Vector3(w + 0.02, ph, t), wall, Kit.PLASTER)
			k.box(Vector3(cx, y, cz - d / 2.0 + t / 2.0), Vector3(w + 0.02, ph, t), wall, Kit.PLASTER)
			k.box(Vector3(cx - w / 2.0 + t / 2.0, y, cz), Vector3(t, ph, d - 2.0 * t), wall, Kit.PLASTER)
			k.box(Vector3(cx + w / 2.0 - t / 2.0, y, cz), Vector3(t, ph, d - 2.0 * t), wall, Kit.PLASTER)
			k.box(Vector3(cx, y + ph, cz + d / 2.0 - t / 2.0), Vector3(w + 0.04, 0.014, t + 0.03), MARBLE, Kit.STONE)
		"dome":
			var r := minf(w, d) * 0.5
			k.cylinder(Vector3(cx, y, cz), r * 0.9, 0.05, wall, Kit.PLASTER, 8)
			k.dome(Vector3(cx, y + 0.05, cz), r, p.get("dome", WHITE), Kit.PLASTER, 0.85, 3, 8)
		"vault":
			_vault(k, cx, y, cz, w, d, rise, tile, rmat, wall)


# --- the block: a stack of storeys with openings, the workhorse ---------------------------------


## A rectangular block of storeys. Keys (all optional): w, d, cx, cz, yaw; floors = [[height,
## colour, material], ...]; fs / bs / ss = how far each storey above is set back at the front / back
## / sides (negative fs = jetty over the street); ground = "shops" | "arcade" | "door" | "blank";
## shops, door (bool: last slot is a door), nwin, nside, shut, wsz; band; roof keys (see _roof);
## bal = [floor, x0, x1]; awn = [x0, x1]; stair = [x, sgn, steps]; pergola = [cx, cz, w, d];
## chim = [x, z]; beams (protruding roof beams, Punic); plinth.
static func _block(k: Kit, p: Dictionary) -> void:
	var w: float = p.get("w", 0.8)
	var d: float = p.get("d", 0.7)
	var floors: Array = p.get("floors", [[0.26, LIME, Kit.PLASTER]])
	var fs: float = p.get("fs", 0.0)
	var bs: float = p.get("bs", 0.0)
	var ss: float = p.get("ss", 0.0)
	var wsz: float = p.get("wsz", 0.07)
	var nwin: int = p.get("nwin", 3)
	var nside: int = p.get("nside", 2)
	var shut: bool = p.get("shut", false)
	var ground: String = p.get("ground", "door")
	var shops: int = p.get("shops", 3)
	var has_door: bool = p.get("door", true)
	var band: bool = p.get("band", true)
	var band_c: Color = p.get("band_c", MARBLE)
	var plinth: bool = p.get("plinth", true)
	var sides: bool = p.get("sides", true)
	var shc: Color = p.get("shc", WOOD)
	var quoins: bool = p.get("quoins", false)
	var wbox: bool = p.get("wbox", false)
	k.push(Kit.at(Vector3(p.get("cx", 0.0), p.get("y", 0.0), p.get("cz", 0.0)), p.get("yaw", 0.0)))
	var y := 0.0
	if plinth:
		k.box(Vector3(0, 0, 0), Vector3(w + 0.04, 0.04, d + 0.04), p.get("base", GREY), Kit.STONE)
		y = 0.04
	var fw := w
	var cz := 0.0
	var fd := d
	var top_col: Color = LIME
	for i in floors.size():
		var f: Array = floors[i]
		var h: float = f[0]
		var col: Color = f[1]
		var mat: int = f[2]
		fw = w - 2.0 * ss * i
		var ef := d / 2.0 - fs * i
		var eb := -d / 2.0 + bs * i
		fd = ef - eb
		cz = (ef + eb) / 2.0
		top_col = col
		k.box(Vector3(0, y, cz), Vector3(fw, h, fd), col, mat)
		if band and i < floors.size() - 1:
			k.box(Vector3(0, y + h - 0.012, cz), Vector3(fw + 0.03, 0.024, fd + 0.03), band_c, Kit.STONE)
		if i == 0:
			match ground:
				"shops", "arcade":
					var n: int = shops
					var slot := fw / n
					var aw := minf(slot * (0.7 if ground == "shops" else 0.8), 0.22)
					var ah := minf(h - 0.05, 0.23)
					for j in n:
						var x := -fw / 2.0 + slot * (j + 0.5)
						if has_door and j == n - 1 and ground == "shops":
							_dr(k, Vector3(x, y, ef), 0.0, 0.11, minf(h - 0.06, 0.2))
						else:
							_arch_op(k, Vector3(x, y, ef), 0.0, aw, ah, ground == "shops" and fw > 0.7)
					if sides:
						_op(k, Vector3(0, y + h * 0.3, eb), PI, wsz, h * 0.42)
				"door":
					_dr(k, Vector3(p.get("door_x", 0.0), y, ef), 0.0, 0.12, minf(h - 0.06, 0.21))
					for x in [-fw * 0.3, fw * 0.3]:
						if absf(x - p.get("door_x", 0.0)) > 0.14:
							_op(k, Vector3(x, y + h * 0.3, ef), 0.0, wsz, h * 0.42, shut)
					for x in [-fw * 0.25, fw * 0.25]:
						_op(k, Vector3(x, y + h * 0.3, eb), PI, wsz, h * 0.42)
				"blank":
					_dr(k, Vector3(p.get("door_x", 0.0), y, ef), 0.0, 0.1, minf(h - 0.06, 0.2))
					_op(k, Vector3(-fw * 0.28, y + h * 0.5, ef), 0.0, 0.035, h * 0.3)
			if sides and ground != "blank":
				for sg in [-1.0, 1.0]:
					for j in nside:
						var z := cz - fd / 2.0 + fd * (j + 0.5) / nside
						_op(k, Vector3(sg * fw / 2.0, y + h * 0.3, z), sg * PI / 2.0, wsz * 0.9, h * 0.42)
		else:
			var wh := h * 0.46
			var wy := y + h * 0.26
			for j in nwin:
				var x := -fw / 2.0 + fw * (j + 0.5) / nwin
				_op(k, Vector3(x, wy, ef), 0.0, wsz, wh, shut, MARBLE, shc)
				if wbox:   # a planter under the window
					k.box(Vector3(x, wy - 0.03, ef + 0.02), Vector3(wsz + 0.03, 0.03, 0.04), WOOD, Kit.TIMBER)
					k.box(Vector3(x, wy - 0.0, ef + 0.02), Vector3(wsz, 0.02, 0.03), GREEN if j % 2 == 0 else Color(0.74, 0.36, 0.42), Kit.LEAF)
				if sides:
					_op(k, Vector3(x, wy, eb), PI, wsz, wh)
			if sides:
				for sg in [-1.0, 1.0]:
					for j in nside:
						var z := cz - fd / 2.0 + fd * (j + 0.5) / nside
						_op(k, Vector3(sg * fw / 2.0, wy, z), sg * PI / 2.0, wsz * 0.9, wh)
		if quoins:   # dressed stone corners on this storey
			for sx in [-1.0, 1.0]:
				k.box(Vector3(sx * (fw / 2.0 - 0.005), y, ef - 0.005), Vector3(0.05, h, 0.05), MARBLE_D, Kit.STONE)
				k.box(Vector3(sx * (fw / 2.0 - 0.005), y, eb + 0.005), Vector3(0.05, h, 0.05), MARBLE_D, Kit.STONE)
		y += h
	k.box(Vector3(0, y - 0.012, cz), Vector3(fw + 0.035, 0.026, fd + 0.035), band_c, Kit.STONE)   # cornice
	# openings and details on the front
	if p.has("bal"):
		var b: Array = p["bal"]
		var by := 0.04
		for i in int(b[0]):
			var fl: Array = floors[i]
			by += float(fl[0])
		var bz := d / 2.0 - fs * int(b[0])
		_balc(k, float(b[1]), float(b[2]), by + 0.01, bz)
	if p.has("awn"):
		var a: Array = p["awn"]
		var gh: float = float((floors[0] as Array)[0])
		_awn(k, float(a[0]), float(a[1]), 0.04 + gh * 0.92, d / 2.0 + 0.01, 0.04 + gh * 0.62, d / 2.0 + 0.15)
	if p.has("stair"):
		var s: Array = p["stair"]
		_stair(k, float(s[0]), d / 2.0, float(s[1]), y - 0.04, int(s[2]))
	if p.get("beams", false):
		for j in 6:
			var x := -fw / 2.0 + fw * (j + 0.5) / 6.0
			k.box(Vector3(x, y - 0.06, d / 2.0 - fs * (floors.size() - 1)), Vector3(0.035, 0.035, 0.05), DWOOD, Kit.TIMBER)
	_roof(k, p, y, fw, fd, 0.0, cz, top_col)
	var ry := y
	if p.has("pergola"):
		var pg: Array = p["pergola"]
		_pergola(k, float(pg[0]), ry + 0.02, float(pg[1]), float(pg[2]), float(pg[3]), 0.17)
	if p.has("loft"):
		var lf: Array = p["loft"]
		k.box(Vector3(float(lf[0]), ry + 0.02, float(lf[1])), Vector3(float(lf[2]), float(lf[4]), float(lf[3])), top_col, Kit.PLASTER)
		k.box(Vector3(float(lf[0]), ry + 0.02 + float(lf[4]), float(lf[1])), Vector3(float(lf[2]) + 0.04, 0.02, float(lf[3]) + 0.04), p.get("tile", TERRA), Kit.TILE)
	if p.has("chim"):
		var c: Array = p["chim"]
		k.chimney(Vector3(float(c[0]), ry + float(p.get("rise", 0.15)) * 0.35, float(c[1])), 0.07, 0.17, MARBLE_D)
	k.pop()


# --- Roman domus: front wing, atrium, back wing ---------------------------------------------------


## A town house round an atrium. Keys: wall, tile, rmat, front ("shops" | "porch" | "upper"),
## back ("tablinum" | "garden" | "tower"), fh (front height), bh (back height), trim, balcony.
static func _atrium(k: Kit, p: Dictionary) -> void:
	var w: float = p.get("w", 0.92)
	var d: float = p.get("d", 0.94)
	var wc: Color = p.get("wall", OCHRE)
	var trim: Color = p.get("trim", RED)
	var tile: Color = p.get("tile", TERRA)
	var rmat: int = p.get("rmat", Kit.OWNER_ROOF)
	var front: String = p.get("front", "shops")
	var back: String = p.get("back", "tablinum")
	var fh: float = p.get("fh", 0.3)
	var bh: float = p.get("bh", 0.4)
	var fd := 0.26
	var bd := 0.28
	var md := d - fd - bd
	var zf := d / 2.0 - fd / 2.0
	var zb := -d / 2.0 + bd / 2.0
	var y0 := 0.04
	k.box(Vector3(0, 0, 0), Vector3(w + 0.04, y0, d + 0.04), GREY, Kit.STONE)
	# front wing
	k.box(Vector3(0, y0, zf), Vector3(w, fh, fd), wc, Kit.PLASTER)
	k.box(Vector3(0, y0, zf), Vector3(w + 0.012, 0.07, fd + 0.012), trim, Kit.PLASTER)
	k.box(Vector3(0, y0 + fh - 0.014, zf), Vector3(w + 0.035, 0.028, fd + 0.035), MARBLE, Kit.STONE)
	var fz := d / 2.0
	match front:
		"shops":
			for x in [-0.3, 0.3]:
				_arch_op(k, Vector3(x, y0, fz), 0.0, 0.17, minf(fh - 0.06, 0.21), true)
			_dr(k, Vector3(0, y0, fz), 0.0, 0.13, minf(fh - 0.08, 0.2), WOOD)
			_amph(k, Vector3(0.44, y0, fz + 0.04), 0.5)
		"porch":
			_dr(k, Vector3(0, y0, fz), 0.0, 0.14, minf(fh - 0.08, 0.22), WOOD)
			for x in [-0.32, 0.32]:
				_op(k, Vector3(x, y0 + 0.12, fz), 0.0, 0.09, 0.1)
			for x in [-0.17, 0.17]:
				_pil(k, Vector3(x, y0, fz + 0.1), fh - 0.04, 0.026)
			k.box(Vector3(0, y0 + fh - 0.04, fz + 0.1), Vector3(0.46, 0.04, 0.07), MARBLE, Kit.STONE)
			k.box(Vector3(0, y0, fz + 0.09), Vector3(0.46, 0.02, 0.16), GREY, Kit.STONE)
		"upper":
			_dr(k, Vector3(0, y0, fz), 0.0, 0.13, 0.2, WOOD)
			for x in [-0.3, 0.3]:
				_arch_op(k, Vector3(x, y0, fz), 0.0, 0.16, 0.2, true)
			for x in [-0.3, -0.1, 0.1, 0.3]:
				_op(k, Vector3(x, y0 + fh * 0.58, fz), 0.0, 0.08, 0.13, true)
			_balc(k, -0.34, 0.34, y0 + fh * 0.5, fz)
	var rise_f: float = p.get("frise", 0.11)
	k.gable_roof(Vector3(0, y0 + fh, zf), w, fd, rise_f, 0.04, 0.03, tile, rmat, wc, Kit.PLASTER)
	# the atrium: side walls under a roof that slopes in to an open compluvium
	for sg in [-1.0, 1.0]:
		k.box(Vector3(sg * (w / 2.0 - 0.03), y0, 0), Vector3(0.06, fh + 0.02, md + 0.01), wc, Kit.PLASTER)
		k.box(Vector3(sg * (w / 2.0 - 0.03), y0, 0), Vector3(0.07, 0.07, md + 0.02), trim, Kit.PLASTER)
	var ry := y0 + fh + 0.04
	_frame_roof(k, Vector3(0, 0, 0), w / 2.0 + 0.04, md / 2.0 + 0.01, 0.27, md / 2.0 - 0.07, ry, ry - 0.09, 0.03, tile, rmat)
	k.box(Vector3(0, y0, 0), Vector3(w - 0.12, 0.012, md), Color(0.72, 0.60, 0.46), Kit.STONE)
	k.box(Vector3(0, y0 + 0.012, 0), Vector3(0.4, 0.03, md * 0.5), MARBLE, Kit.STONE)
	k.box(Vector3(0, y0 + 0.042, 0), Vector3(0.34, 0.008, md * 0.5 - 0.06), Color.WHITE, Kit.WATER)
	# back wing
	match back:
		"tablinum":
			k.box(Vector3(0, y0, zb), Vector3(w, bh, bd), SALMON if wc != SALMON else wc, Kit.PLASTER)
			k.box(Vector3(0, y0, zb + 0.002), Vector3(w + 0.012, 0.07, bd + 0.012), trim, Kit.PLASTER)
			k.box(Vector3(0, y0 + bh - 0.014, zb), Vector3(w + 0.035, 0.028, bd + 0.035), MARBLE, Kit.STONE)
			for x in [-0.28, 0.0, 0.28]:
				_op(k, Vector3(x, y0 + bh * 0.5, zb - bd / 2.0), PI, 0.08, 0.12)
				_op(k, Vector3(x, y0 + bh * 0.5, -d / 2.0 + bd + 0.0), 0.0, 0.07, 0.1)
			k.hip_roof(Vector3(0, y0 + bh, zb), w, bd, 0.17, 0.045, 0.03, tile, rmat)
		"garden":
			for sg in [-1.0, 1.0]:
				k.box(Vector3(sg * (w / 2.0 - 0.025), y0, zb), Vector3(0.05, 0.3, bd), wc, Kit.PLASTER)
			k.box(Vector3(0, y0, -d / 2.0 + 0.025), Vector3(w, 0.3, 0.05), wc, Kit.PLASTER)
			k.box(Vector3(0, y0 + 0.3, -d / 2.0 + 0.03), Vector3(w + 0.03, 0.025, 0.07), MARBLE, Kit.STONE)
			k.box(Vector3(0, y0, zb + 0.03), Vector3(w - 0.12, 0.012, bd - 0.1), EARTHC, Kit.EARTH)
			_pergola(k, 0.22, y0, zb + 0.02, 0.36, 0.2, 0.2)
			_shrub(k, Vector3(-0.28, y0, zb + 0.02), 0.09)
			_shrub(k, Vector3(-0.12, y0, zb - 0.08), 0.07, DGREEN)
		"tower":
			k.box(Vector3(0, y0, zb), Vector3(w, 0.32, bd), wc, Kit.PLASTER)
			k.box(Vector3(0, y0 + 0.31, zb), Vector3(w + 0.035, 0.028, bd + 0.035), MARBLE, Kit.STONE)
			k.hip_roof(Vector3(0, y0 + 0.32, zb), w, bd, 0.12, 0.045, 0.03, tile, rmat)
			var tx: float = p.get("tx", 0.3)
			k.box(Vector3(tx, y0 + 0.32, zb + 0.01), Vector3(0.28, 0.4, 0.28), LIME, Kit.PLASTER)
			for s in [-1.0, 1.0]:
				_op(k, Vector3(tx + s * 0.141, y0 + 0.5, zb + 0.01), s * PI / 2.0, 0.07, 0.14)
			_op(k, Vector3(tx, y0 + 0.5, zb + 0.151), 0.0, 0.07, 0.14)
			k.hip_roof(Vector3(tx, y0 + 0.72, zb + 0.01), 0.28, 0.28, 0.17, 0.05, 0.03, tile, rmat)
	for x in [-0.35, 0.35]:
		_shrub(k, Vector3(x, y0, fz + 0.1), 0.05, DGREEN)


# --- the families -------------------------------------------------------------------------------


static func _g_domus(k: Kit, v: int) -> void:
	match v:
		1:   # a Pompeian town house: shops flank the door, a tall tablinum behind
			_atrium(k, {wall = OCHRE, front = "shops", back = "tablinum", bh = 0.46, tile = TILE_RED, rmat = Kit.TILE})
		2:   # two storeys of street front with a balcony, a vine garden behind
			_atrium(k, {wall = SALMON, front = "upper", fh = 0.5, back = "garden", trim = BRICKC, frise = 0.13, tile = TILE_ORG})
		3:   # white house with a porch, a stair tower at the back corner
			_atrium(k, {wall = WHITE, front = "porch", back = "tower", tx = -0.3, trim = BLUE, fh = 0.34, tile = TERRA})
		4:   # pale yellow, porch, high tablinum with a hipped roof
			_atrium(k, {wall = YELLOW, front = "porch", back = "tablinum", bh = 0.34, trim = RED, tile = TILE_BRN, rmat = Kit.TILE, d = 0.9})


static func _g_insula(k: Kit, v: int) -> void:
	var brick := [0.26, BRICKC, Kit.BRICK]
	match v:
		1:   # three floors over a brick arcade of shops, a wooden balcony
			_block(k, {w = 0.9, d = 0.76, floors = [brick, [0.24, OCHRE, Kit.PLASTER], [0.23, SALMON, Kit.PLASTER]],
				ground = "shops", shops = 3, nwin = 4, shut = true, bal = [1, -0.15, 0.3], awn = [-0.38, -0.02], quoins = true,
				roof = "gable", rise = 0.16, over = 0.07, tile = TILE_RED, rmat = Kit.TILE, chim = [-0.25, -0.1]})
		2:   # a narrow tall tenement, each floor jettied out over the street
			_block(k, {w = 0.62, d = 0.8, floors = [[0.24, STONEC, Kit.STONE], [0.22, OCHRE, Kit.PLASTER], [0.22, LIME, Kit.PLASTER], [0.2, PINK, Kit.PLASTER]],
				fs = -0.035, ground = "shops", shops = 2, nwin = 2, nside = 3, shut = true, wsz = 0.075, quoins = true, wbox = true,
				roof = "hip", rise = 0.2, over = 0.06, tile = TILE_GRY, rmat = Kit.TILE})
		3:   # a block with a lower wing: flat roof, vine pergola and an outside stair
			_block(k, {w = 0.6, d = 0.74, cx = -0.18, floors = [brick, [0.24, PINK, Kit.PLASTER], [0.22, LIME, Kit.PLASTER]],
				ground = "shops", shops = 2, nwin = 3, shut = true, wbox = true, roof = "gable", rise = 0.15, tile = TERRA, rz = true, chim = [-0.1, 0.0]})
			_block(k, {w = 0.36, d = 0.6, cx = 0.33, cz = -0.05, floors = [[0.26, OCHRE, Kit.PLASTER]], ground = "door",
				door_x = -0.04, nwin = 1, nside = 1, roof = "flat", parapet = 0.06, deck = EARTHC, stair = [0.0, 1.0, 4],
				pergola = [0.0, 0.0, 0.26, 0.4]})
		4:   # terraces stepping back, a stone base, a shed roof on top
			_block(k, {w = 0.9, d = 0.82, floors = [[0.26, GREY, Kit.STONE], [0.23, OCHRE, Kit.PLASTER], [0.21, PINK, Kit.PLASTER], [0.18, WHITE, Kit.PLASTER]],
				fs = 0.1, ground = "shops", shops = 3, nwin = 3, shut = true, nside = 3, quoins = true, roof = "lean", rise = 0.14, over = 0.04,
				tile = TILE_BRN, rmat = Kit.TILE, bal = [1, -0.3, 0.3]})
			for i in 3:   # parapets and pots where each floor steps back
				var yy := 0.04 + 0.26 + i * 0.22
				k.box(Vector3(0, yy, 0.41 - i * 0.1), Vector3(0.88, 0.05, 0.03), MARBLE, Kit.STONE)


static func _g_taberna(k: Kit, v: int) -> void:
	match v:
		1:   # a row of four shops under one lean-to roof, awnings and jars
			_block(k, {w = 0.92, d = 0.5, floors = [[0.28, LIME, Kit.PLASTER]], ground = "shops", shops = 4, door = false,
				roof = "lean", rise = 0.12, over = 0.05, tile = TILE_ORG, rmat = Kit.TILE, nside = 1, awn = [-0.4, 0.05], quoins = true})
			_amph(k, Vector3(0.38, 0.04, 0.34), 0.45)
			_amph(k, Vector3(0.3, 0.04, 0.37), 0.4, Color(0.7, 0.5, 0.32))
			_barrel(k, Vector3(0.1, 0.04, 0.36))
			_barrel(k, Vector3(0.17, 0.04, 0.34), 0.85)
			_sack(k, Vector3(-0.18, 0.04, 0.37))
			_sack(k, Vector3(-0.42, 0.04, 0.34), 0.9)
			k.box(Vector3(-0.1, 0.04, 0.39), Vector3(0.2, 0.05, 0.06), WOOD, Kit.TIMBER)
		2:   # a bakery: gabled shop with a domed oven and a chimney
			_block(k, {w = 0.58, d = 0.54, cx = -0.18, floors = [[0.3, SAND, Kit.PLASTER]], ground = "door", door_x = 0.1, nwin = 1, nside = 1,
				roof = "gable", rise = 0.16, tile = TILE_RED, rmat = Kit.TILE, rz = true, quoins = true, awn = [-0.4, -0.05]})
			k.box(Vector3(0.27, 0.0, 0.0), Vector3(0.26, 0.2, 0.3), STONEC, Kit.STONE)
			k.dome(Vector3(0.27, 0.2, 0.0), 0.15, Color(0.74, 0.58, 0.46), Kit.PLASTER, 0.9, 3, 8)
			k.chimney(Vector3(0.27, 0.34, -0.08), 0.06, 0.17, MARBLE_D)
			for i in 3:
				k.box(Vector3(0.12 + i * 0.05, 0.0, 0.34), Vector3(0.045, 0.06 + i * 0.015, 0.06), CREAM, Kit.CLOTH)
			_logs(k, Vector3(0.32, 0.0, 0.3), 0.3)
			_barrel(k, Vector3(-0.1, 0.0, 0.34))
			_op(k, Vector3(-0.3, 0.12, 0.271), 0.0, 0.07, 0.1, true, MARBLE, WOOD)

		3:   # a thermopolium with a loft: counter and sunken jars, balcony above
			_block(k, {w = 0.8, d = 0.62, floors = [[0.25, YELLOW, Kit.PLASTER], [0.22, WHITE, Kit.PLASTER]], ground = "shops", shops = 2,
				door = true, nwin = 3, shut = true, bal = [1, -0.3, 0.1], quoins = true, wbox = true, roof = "gable", rise = 0.15, tile = TILE_BRN, rmat = Kit.TILE, chim = [0.2, -0.1]})
			k.rod(Vector3(0.42, 0.52, 0.34), Vector3(0.42, 0.52, 0.5), 0.008, DWOOD, Kit.TIMBER)
			k.box(Vector3(0.42, 0.4, 0.5), Vector3(0.012, 0.1, 0.1), GOLD_C, Kit.GOLD)
			_amph(k, Vector3(0.38, 0.04, 0.42), 0.45)
			for i in 3:
				k.cylinder(Vector3(-0.3 + i * 0.12, 0.04, 0.375), 0.04, 0.07, TERRACOTTA, Kit.PAINT, 6)
			k.box(Vector3(0.36, 0.04, 0.4), Vector3(0.16, 0.05, 0.07), WOOD, Kit.TIMBER)


static func _g_cottage(k: Kit, v: int) -> void:
	match v:
		1:   # a mud-brick hut under thatch, with a lean-to shed
			_block(k, {w = 0.5, d = 0.42, cx = -0.08, floors = [[0.22, SAND, Kit.MUDBRICK]], ground = "door", door_x = 0.05, nwin = 1, nside = 1,
				roof = "thatch", rise = 0.18, over = 0.04, band = false, plinth = false, sides = true})
			_block(k, {w = 0.24, d = 0.3, cx = 0.34, cz = -0.02, floors = [[0.14, EARTHC, Kit.MUDBRICK]], ground = "blank", roof = "lean", rise = 0.07,
				tile = THATCHC, rmat = Kit.THATCH, band = false, plinth = false, sides = false})
			_logs(k, Vector3(-0.28, 0.0, 0.28), 0.2)
			_barrel(k, Vector3(0.12, 0.0, 0.26))
			_barrel(k, Vector3(0.2, 0.0, 0.3), 0.8)
			_sack(k, Vector3(0.3, 0.0, 0.22))
			k.chimney(Vector3(-0.2, 0.28, -0.08), 0.06, 0.12, STONEC)
			_op(k, Vector3(-0.28, 0.08, 0.131), 0.0, 0.05, 0.08, true, SAND, DWOOD)
			k.dome(Vector3(-0.38, 0.0, -0.22), 0.1, Color(0.82, 0.70, 0.40), Kit.THATCH, 0.9, 2, 6)
			for i in 3:   # a bean row
				k.box(Vector3(-0.2 + i * 0.07, 0.0, -0.3), Vector3(0.03, 0.05, 0.14), GREEN if i != 1 else DGREEN, Kit.LEAF)
			k.box(Vector3(0.05, 0.0, 0.17), Vector3(0.12, 0.025, 0.06), MARBLE_D, Kit.STONE)
		2:   # a round hut and a smaller one
			k.cylinder(Vector3(-0.1, 0, 0.0), 0.25, 0.2, SAND, Kit.MUDBRICK, 8)
			k.frustum(Vector3(-0.1, 0.2, 0.0), 0.34, 0.0, 0.3, THATCHC, Kit.THATCH, 8)
			_dr(k, Vector3(-0.1, 0, 0.25), 0.0, 0.1, 0.15, DWOOD, EARTHC)
			k.cylinder(Vector3(0.3, 0, 0.12), 0.14, 0.13, EARTHC, Kit.MUDBRICK, 7)
			k.frustum(Vector3(0.3, 0.13, 0.12), 0.2, 0.0, 0.17, THATCHC.darkened(0.1), Kit.THATCH, 7)
			_op(k, Vector3(-0.32, 0.08, 0.19), -0.6, 0.05, 0.07, true, SAND, DWOOD)
			_op(k, Vector3(0.12, 0.08, 0.19), 0.6, 0.05, 0.07, true, SAND, DWOOD)
			_amph(k, Vector3(0.12, 0.0, 0.34), 0.6)
			_barrel(k, Vector3(-0.36, 0.0, 0.3))
			_logs(k, Vector3(0.42, 0.0, -0.1), 0.5)
			k.dome(Vector3(-0.38, 0.0, -0.22), 0.1, Color(0.82, 0.70, 0.40), Kit.THATCH, 0.9, 2, 6)
			for x in [0.2, 0.42]:   # a drying rack with a cloth
				k.rod(Vector3(x, 0.0, -0.3), Vector3(x, 0.17, -0.3), 0.01, DWOOD, Kit.TIMBER)
			k.rod(Vector3(0.2, 0.17, -0.3), Vector3(0.42, 0.17, -0.3), 0.007, WOOD, Kit.TIMBER)
			k.quad(Vector3(0.24, 0.17, -0.3), Vector3(0.36, 0.17, -0.3), Vector3(0.36, 0.07, -0.3), Vector3(0.24, 0.07, -0.3), Color(0.78, 0.35, 0.28), Kit.CLOTH, Vector3(0.3, 0.1, -1.0))
			k.box(Vector3(-0.34, 0.0, 0.08), Vector3(0.06, 0.12, 0.06), STONEC, Kit.STONE)
			for i in 3:
				k.box(Vector3(-0.1 + i * 0.07, 0.0, -0.42), Vector3(0.03, 0.05, 0.12), GREEN if i != 1 else DGREEN, Kit.LEAF)
		3:   # a stone hovel with a low tiled roof, a woodpile and a porch of posts
			_block(k, {w = 0.55, d = 0.46, cx = 0.0, floors = [[0.23, GREY, Kit.STONE]], ground = "door", door_x = -0.1, nwin = 1, nside = 1,
				roof = "gable", rise = 0.13, over = 0.05, tile = TILE_BRN, rmat = Kit.TILE, band = false, rz = true, chim = [0.0, 0.0], quoins = true, wbox = true})
			for x in [-0.22, 0.0]:
				k.rod(Vector3(x, 0.04, 0.34), Vector3(x, 0.2, 0.34), 0.012, DWOOD, Kit.TIMBER)
			k.rod(Vector3(-0.24, 0.2, 0.34), Vector3(0.02, 0.2, 0.34), 0.012, WOOD, Kit.TIMBER)
			_logs(k, Vector3(0.38, 0.0, 0.12), 1.57)
			_logs(k, Vector3(0.38, 0.0, -0.06), 1.57)
			_barrel(k, Vector3(-0.34, 0.0, 0.36))
			_sack(k, Vector3(0.28, 0.0, 0.34))
			_op(k, Vector3(0.12, 0.08, 0.231), 0.0, 0.07, 0.09, true, SAND, DWOOD)
			_op(k, Vector3(-0.276, 0.08, 0.0), -PI / 2.0, 0.07, 0.09, true, SAND, DWOOD)


static func _g_farm(k: Kit, v: int) -> void:
	match v:
		1:   # a farmhouse and a long thatched barn at right angles
			_block(k, {w = 0.5, d = 0.4, cx = -0.24, cz = 0.22, floors = [[0.25, LIME, Kit.PLASTER], [0.16, OCHRE, Kit.PLASTER]], ground = "door", door_x = 0.0,
				nwin = 2, nside = 1, roof = "gable", rise = 0.14, tile = TILE_RED, rmat = Kit.TILE, band = false})
			_block(k, {w = 0.4, d = 0.7, cx = 0.28, cz = -0.12, floors = [[0.26, Color(0.62, 0.50, 0.36), Kit.TIMBER]], ground = "blank", roof = "thatch",
				rise = 0.2, rz = true, band = false, sides = false})
			k.box(Vector3(0.28, 0.04, 0.236), Vector3(0.2, 0.2, 0.014), DWOOD, Kit.TIMBER)
			k.dome(Vector3(-0.38, 0.0, -0.18), 0.14, Color(0.82, 0.70, 0.40), Kit.THATCH, 0.9, 3, 7)
			_barrel(k, Vector3(-0.1, 0.0, 0.42))
			_barrel(k, Vector3(-0.03, 0.0, 0.44), 0.85)
			_sack(k, Vector3(0.0, 0.0, 0.2))
			_sack(k, Vector3(0.08, 0.0, 0.22), 0.9)
			_op(k, Vector3(-0.38, 0.1, 0.421), 0.0, 0.07, 0.1, true, MARBLE, DWOOD)
			_op(k, Vector3(-0.1, 0.12, 0.421), 0.0, 0.07, 0.1, true, MARBLE, DWOOD)
			_op(k, Vector3(-0.15, 0.31, 0.421), 0.0, 0.06, 0.07)
			k.chimney(Vector3(-0.3, 0.42, 0.18), 0.06, 0.1, STONEC)
			_logs(k, Vector3(0.4, 0.0, 0.4), 0.0)
		2:   # a granary raised on stone posts, steps up to its door
			for x in [-0.28, 0.0, 0.28]:
				for z in [-0.2, 0.2]:
					k.frustum(Vector3(x, 0, z), 0.04, 0.035, 0.1, STONEC, Kit.STONE, 5)
					k.cylinder(Vector3(x, 0.1, z), 0.055, 0.015, GREY, Kit.STONE, 5)
			k.box(Vector3(0, 0.115, 0), Vector3(0.78, 0.04, 0.5), WOOD, Kit.TIMBER)
			k.box(Vector3(0, 0.155, 0), Vector3(0.7, 0.28, 0.44), Color(0.66, 0.52, 0.34), Kit.TIMBER)
			_dr(k, Vector3(0.1, 0.155, 0.221), 0.0, 0.12, 0.2, DWOOD, WOOD)
			k.gable_roof(Vector3(0, 0.435, 0), 0.7, 0.44, 0.17, 0.07, 0.03, TILE_BRN, Kit.TILE, Color(0.66, 0.52, 0.34), Kit.TIMBER)
			for i in 3:
				k.box(Vector3(0.1, 0.0, 0.26 + (2 - i) * 0.055), Vector3(0.14, 0.05 * (i + 1), 0.055), MARBLE_D, Kit.STONE)
			_barrel(k, Vector3(-0.2, 0.0, 0.34))
			_sack(k, Vector3(-0.32, 0.0, 0.32))
			_sack(k, Vector3(-0.26, 0.0, 0.38))
			k.box(Vector3(0.36, 0.0, 0.3), Vector3(0.18, 0.04, 0.12), WOOD, Kit.TIMBER)
		3:   # a press house with a lean-to roof, big storage jars and a watch tower
			_block(k, {w = 0.52, d = 0.6, cx = -0.18, floors = [[0.28, STONEC, Kit.STONE], [0.2, LIME, Kit.PLASTER]], ground = "door", door_x = 0.1, nwin = 2, nside = 2,
				roof = "lean", rise = 0.16, tile = TILE_ORG, rmat = Kit.TILE, band = false})
			k.box(Vector3(0.32, 0.0, -0.18), Vector3(0.26, 0.62, 0.26), STONEC, Kit.STONE)
			_op(k, Vector3(0.32, 0.38, -0.047), 0.0, 0.05, 0.12)
			_op(k, Vector3(0.451, 0.38, -0.18), PI / 2.0, 0.05, 0.12)
			k.hip_roof(Vector3(0.32, 0.62, -0.18), 0.26, 0.26, 0.15, 0.04, 0.03, TILE_RED, Kit.TILE)
			for i in 3:
				k.frustum(Vector3(0.1 + i * 0.12, 0, 0.36), 0.04, 0.07, 0.08, TERRACOTTA, Kit.PAINT, 7, false)
				k.frustum(Vector3(0.1 + i * 0.12, 0.08, 0.36), 0.07, 0.035, 0.05, TERRACOTTA, Kit.PAINT, 7)
			k.dome(Vector3(-0.42, 0.0, 0.32), 0.13, Color(0.84, 0.72, 0.4), Kit.THATCH, 0.9, 3, 7)
			_barrel(k, Vector3(-0.2, 0.0, 0.34))
			_sack(k, Vector3(0.0, 0.0, 0.34))
			_logs(k, Vector3(0.0, 0.0, -0.45), 0.0)
			_op(k, Vector3(-0.3, 0.12, 0.301), 0.0, 0.07, 0.1, true, MARBLE, DWOOD)
		4:   # a stable with an open front, hay on the ground and a dovecote
			k.box(Vector3(0, 0, 0), Vector3(0.9, 0.04, 0.6), EARTHC, Kit.EARTH)
			k.box(Vector3(0, 0.04, -0.14), Vector3(0.84, 0.3, 0.3), Color(0.62, 0.48, 0.34), Kit.TIMBER)
			for x in [-0.4, -0.15, 0.15, 0.4]:
				k.box(Vector3(x, 0.04, 0.1), Vector3(0.04, 0.3, 0.04), DWOOD, Kit.TIMBER)
			k.box(Vector3(0, 0.04, -0.0), Vector3(0.8, 0.3, 0.012), DARKC, Kit.DARK)
			k.gable_roof(Vector3(0, 0.34, -0.02), 0.9, 0.56, 0.17, 0.05, 0.03, TILE_BRN, Kit.TILE, Color(0.62, 0.48, 0.34), Kit.TIMBER)
			k.cylinder(Vector3(0.25, 0.46, -0.1), 0.07, 0.14, WHITE, Kit.PLASTER, 6)
			k.frustum(Vector3(0.25, 0.6, -0.1), 0.09, 0.0, 0.1, TILE_RED, Kit.TILE, 6)
			k.dome(Vector3(-0.28, 0.04, 0.34), 0.14, Color(0.84, 0.72, 0.4), Kit.THATCH, 0.85, 3, 7)
			k.dome(Vector3(-0.02, 0.04, 0.38), 0.09, Color(0.84, 0.72, 0.4), Kit.THATCH, 0.85, 2, 6)
			k.box(Vector3(0.3, 0.04, 0.33), Vector3(0.24, 0.05, 0.08), WOOD, Kit.TIMBER)   # trough
			_barrel(k, Vector3(0.42, 0.04, 0.26))
			for x in [-0.3, -0.1, 0.1]:
				_op(k, Vector3(x, 0.2, 0.0), PI, 0.06, 0.08)
			k.box(Vector3(0.0, 0.3, 0.0), Vector3(0.12, 0.07, 0.014), DWOOD, Kit.TIMBER)
			for sg in [-1.0, 1.0]:   # stall partitions
				k.box(Vector3(sg * 0.28, 0.04, 0.0), Vector3(0.025, 0.14, 0.2), DWOOD, Kit.TIMBER)


# --- Greek houses: a court ringed by rooms ----------------------------------------------------------


## A courtyard house. Keys: wall, trim, tile, rmat, bh (back wing height), sh (side wings), broof
## ("gable" | "flat" | "hip"), sroof ("pent" | "flat" | "in"), pastas (columns before the back wing),
## door colour, court features: tree, well, altar, pergola, fountain, stair, balcony.
static func _court(k: Kit, p: Dictionary) -> void:
	var w: float = p.get("w", 0.9)
	var d: float = p.get("d", 0.92)
	var wc: Color = p.get("wall", WHITE)
	var trim: Color = p.get("trim", BLUE)
	var tile: Color = p.get("tile", TERRA)
	var rmat: int = p.get("rmat", Kit.OWNER_ROOF)
	var bd: float = p.get("bd", 0.3)
	var sd: float = p.get("sd", 0.2)
	var bh: float = p.get("bh", 0.34)
	var sh: float = p.get("sh", 0.24)
	var fh := 0.2
	var y0 := 0.04
	k.box(Vector3(0, 0, 0), Vector3(w + 0.04, y0, d + 0.04), GREY, Kit.STONE)
	var zb := -d / 2.0 + bd / 2.0
	var zs0 := -d / 2.0 + bd
	var zs1 := d / 2.0 - 0.06
	var zs := (zs0 + zs1) / 2.0
	var ls := zs1 - zs0
	# the court floor
	k.box(Vector3(0, y0, zs), Vector3(w - 2.0 * sd, 0.012, ls), p.get("floor", Color(0.74, 0.68, 0.56)), Kit.EARTH)
	# back wing
	k.box(Vector3(0, y0, zb), Vector3(w, bh, bd), wc, Kit.PLASTER)
	k.box(Vector3(0, y0 + bh - 0.012, zb), Vector3(w + 0.03, 0.024, bd + 0.03), p.get("band_c", MARBLE), Kit.STONE)
	var zf := zs0 + 0.0
	_dr(k, Vector3(p.get("door_x", 0.0), y0, zf), 0.0, 0.12, 0.22, trim)
	for x in [-0.32, 0.32]:
		_op(k, Vector3(x, y0 + 0.1, zf), 0.0, 0.08, 0.1, true, MARBLE, trim)
	if bh > 0.4:
		for x in [-0.3, 0.0, 0.3]:
			_op(k, Vector3(x, y0 + bh * 0.64, zf), 0.0, 0.07, 0.11, true, MARBLE, trim)
		for x in [-0.25, 0.25]:
			_op(k, Vector3(x, y0 + bh * 0.64, -d / 2.0), PI, 0.07, 0.11)
	for x in [-0.25, 0.25]:
		_op(k, Vector3(x, y0 + 0.1, -d / 2.0), PI, 0.07, 0.1)
	match p.get("broof", "gable"):
		"gable":
			k.gable_roof(Vector3(0, y0 + bh, zb), w, bd, p.get("brise", 0.14), 0.05, 0.03, tile, rmat, wc, Kit.PLASTER)
		"hip":
			k.hip_roof(Vector3(0, y0 + bh, zb), w, bd, 0.15, 0.05, 0.03, tile, rmat)
		"flat":
			_roof(k, {roof = "flat", parapet = 0.07, deck = SAND}, y0 + bh, w, bd, 0.0, zb, wc)
	if p.has("balcony"):
		_balc(k, -0.3, 0.3, y0 + bh * 0.55, zf, 0.1, trim)
	if p.get("pastas", 0) > 0:
		var n: int = p["pastas"]
		for i in n:
			_pil(k, Vector3(-0.34 + 0.68 * i / maxf(n - 1, 1), y0, zf + 0.1), 0.22, 0.024)
		k.box(Vector3(0, y0 + 0.22, zf + 0.1), Vector3(0.8, 0.035, 0.06), MARBLE, Kit.STONE)
	# side wings
	for sg in [-1.0, 1.0]:
		var sx: float = sg * (w / 2.0 - sd / 2.0)
		k.box(Vector3(sx, y0, zs), Vector3(sd, sh, ls), wc if sg < 0 or not p.has("wall2") else p["wall2"], Kit.PLASTER)
		k.box(Vector3(sx, y0 + sh - 0.012, zs), Vector3(sd + 0.03, 0.024, ls + 0.03), MARBLE, Kit.STONE)
		for z in [zs - 0.14, zs + 0.14]:
			_op(k, Vector3(sg * w / 2.0, y0 + sh * 0.3, z), sg * PI / 2.0, 0.07, 0.1, true, MARBLE, trim)
		var roof_kind: String = p.get("sroof", "pent")
		if roof_kind == "pent":   # a shed roof falling away from the court
			var yo := y0 + sh
			var xo: float = sg * (w / 2.0 + 0.04)
			var xi: float = sg * (w / 2.0 - sd)
			_slab(k, [Vector3(xo, yo - 0.01, zs0), Vector3(xo, yo - 0.01, zs1), Vector3(xi, yo + 0.1, zs1), Vector3(xi, yo + 0.1, zs0)], 0.03, tile, rmat)
			for z in [zs0, zs1]:
				k.tri(Vector3(xo * 0.97, yo, z), Vector3(xi, yo, z), Vector3(xi, yo + 0.1, z), wc, Kit.PLASTER, Vector3(sx, yo, zs))
		elif roof_kind == "in":   # a shed roof falling toward the court, over columns
			var yo2 := y0 + sh
			var xo2: float = sg * (w / 2.0 + 0.03)
			var xi2: float = sg * (w / 2.0 - sd - 0.08)
			_slab(k, [Vector3(xo2, yo2 + 0.1, zs0), Vector3(xo2, yo2 + 0.1, zs1), Vector3(xi2, yo2 - 0.01, zs1), Vector3(xi2, yo2 - 0.01, zs0)], 0.03, tile, rmat)
			for i in 4:
				_pil(k, Vector3(sg * (w / 2.0 - sd - 0.06), y0, zs0 + ls * (i + 0.5) / 4.0), sh - 0.01, 0.02)
		elif roof_kind == "gable":   # a ridge running along the wing
			_roof(k, {roof = "gable", rz = true, rise = 0.1, over = 0.03, tile = tile, rmat = rmat}, y0 + sh, sd, ls, sx, zs, wc)
		else:
			_roof(k, {roof = "flat", parapet = 0.06, deck = SAND}, y0 + sh, sd, ls, sx, zs, wc)
	# the front wall with its gate
	k.box(Vector3(0, y0, d / 2.0 - 0.03), Vector3(w, fh, 0.06), wc, Kit.PLASTER)
	k.box(Vector3(0, y0 + fh, d / 2.0 - 0.03), Vector3(w + 0.02, 0.025, 0.09), TERRA, Kit.TILE)
	var gx: float = p.get("gate_x", 0.2)
	k.box(Vector3(gx, y0, d / 2.0 - 0.03), Vector3(0.24, 0.3, 0.08), MARBLE, Kit.STONE)
	_dr(k, Vector3(gx, y0, d / 2.0 + 0.012), 0.0, 0.13, 0.2, trim)
	for sg in [-1.0, 1.0]:
		k.frustum(Vector3(gx + sg * 0.1, y0 + 0.3, d / 2.0 - 0.03), 0.04, 0.0, 0.05, tile, Kit.TILE, 4)
	# court features
	var features: Array = p.get("court", [])
	for f in features:
		match str(f):
			"tree":
				k.cylinder(Vector3(-0.1, y0, zs + 0.08), 0.02, 0.16, DWOOD, Kit.TIMBER, 5)
				k.dome(Vector3(-0.1, y0 + 0.12, zs + 0.08), 0.15, Color(0.46, 0.55, 0.36), Kit.LEAF, 0.7, 2, 7)
			"well":
				k.cylinder(Vector3(0.14, y0, zs - 0.06), 0.06, 0.07, MARBLE_D, Kit.STONE, 7)
				k.cylinder(Vector3(0.14, y0 + 0.065, zs - 0.06), 0.045, 0.005, Color.WHITE, Kit.WATER, 7)
			"altar":
				k.box(Vector3(0.0, y0, zs), Vector3(0.1, 0.09, 0.1), MARBLE, Kit.STONE)
				k.frustum(Vector3(0.0, y0 + 0.09, zs), 0.025, 0.0, 0.05, Color(0.95, 0.55, 0.2), Kit.GOLD, 4)
			"pergola":
				_pergola(k, -0.12, y0, zs + 0.02, 0.34, 0.26, 0.18)
			"fountain":
				k.cylinder(Vector3(0.0, y0, zs), 0.11, 0.05, MARBLE, Kit.STONE, 8)
				k.cylinder(Vector3(0.0, y0 + 0.05, zs), 0.09, 0.005, Color.WHITE, Kit.WATER, 8)
				k.frustum(Vector3(0.0, y0 + 0.05, zs), 0.02, 0.012, 0.1, MARBLE, Kit.STONE, 5)
			"cypress":
				_cypress(k, Vector3(0.2, y0, zs + 0.15), 1.1)
			"pots":
				for i in 2:
					_amph(k, Vector3(0.12 + i * 0.07, y0, zs + 0.2 - i * 0.04), 0.45)
	if p.has("stair"):
		var st: Array = p["stair"]
		var sgn: float = st[1]
		for i in 4:
			k.box(Vector3(float(st[0]) + sgn * i * 0.07, y0, zs0 + 0.06), Vector3(0.07, 0.07 * (i + 1) * sh / 0.24 / 1.1, 0.1), MARBLE_D, Kit.STONE)


static func _g_court(k: Kit, v: int) -> void:
	match v:
		1:   # whitewashed ring, blue doors, an olive in the court
			_court(k, {wall = WHITE, trim = BLUE, tile = TILE_ORG, rmat = Kit.TILE, court = ["tree", "well"], bh = 0.34, sroof = "gable"})
		2:   # a colonnaded porch (pastas) before a two-storey back wing with a balcony
			_court(k, {wall = OCHRE, trim = WOOD, tile = TERRA, bh = 0.52, balcony = true, pastas = 4, sh = 0.22, sroof = "pent", court = ["altar", "cypress"],
				door_x = 0.0, brise = 0.15})
		3:   # flat earth roofs and parapets, an outside stair, a vine in the court
			_court(k, {wall = SALMON, wall2 = SAND, trim = BLUE, broof = "flat", sroof = "flat", bh = 0.46, sh = 0.26, court = ["pergola", "pots"],
				stair = [-0.2, 1.0], gate_x = -0.22})
		4:   # a Hellenistic peristyle house: columns round a fountain court, hipped roofs
			_court(k, {wall = CREAM, trim = RED, tile = TILE_RED, rmat = Kit.TILE, broof = "hip", bh = 0.36, sroof = "in", sh = 0.26, court = ["fountain"],
				pastas = 4, band_c = BLUE, gate_x = 0.0, door_x = 0.0})


static func _g_cube(k: Kit, v: int) -> void:
	match v:
		1:   # stacked whitewashed cubes, blue door, a little dome
			k.bevel_box(Vector3(-0.05, 0.0, 0.0), Vector3(0.62, 0.34, 0.6), 0.025, WHITE, Kit.PLASTER)
			k.bevel_box(Vector3(-0.18, 0.34, -0.08), Vector3(0.38, 0.26, 0.4), 0.025, CREAM, Kit.PLASTER)
			k.bevel_box(Vector3(0.36, 0.0, 0.1), Vector3(0.26, 0.22, 0.34), 0.02, WHITE, Kit.PLASTER)
			_dr(k, Vector3(-0.05, 0.0, 0.301), 0.0, 0.12, 0.22, BLUE, BLUE)
			_op(k, Vector3(-0.26, 0.14, 0.301), 0.0, 0.08, 0.1, true, WHITE, BLUE)
			_op(k, Vector3(-0.18, 0.4, 0.121), 0.0, 0.07, 0.1, true, WHITE, BLUE)
			_op(k, Vector3(0.36, 0.08, 0.271), 0.0, 0.07, 0.09, true, WHITE, BLUE)
			k.cylinder(Vector3(0.36, 0.22, 0.1), 0.1, 0.03, WHITE, Kit.PLASTER, 8)
			k.dome(Vector3(0.36, 0.25, 0.1), 0.1, BLUE, Kit.PAINT, 0.9, 3, 8)
			_shrub(k, Vector3(0.12, 0.0, 0.36), 0.07, Color(0.78, 0.35, 0.5))
			for i in 4:   # an outside stair up to the roof of the low cube
				k.box(Vector3(0.24 + i * 0.07, 0.0, 0.32), Vector3(0.07, 0.055 * (i + 1), 0.1), WHITE, Kit.PLASTER)
			_amph(k, Vector3(-0.3, 0.0, 0.36), 0.55)
			_amph(k, Vector3(-0.22, 0.0, 0.4), 0.4, WHITE.darkened(0.2))
			for sg in [-1.0, 1.0]:
				_op(k, Vector3(-0.18 + sg * 0.1, 0.38, 0.121), 0.0, 0.05, 0.1, true, WHITE, BLUE)
				_op(k, Vector3(-0.05 + sg * 0.265, 0.15, -0.301), PI, 0.07, 0.1, true, WHITE, BLUE)
		2:   # two cubes, an outside stair up to a vine roof terrace
			k.bevel_box(Vector3(-0.2, 0.0, -0.05), Vector3(0.5, 0.3, 0.7), 0.02, WHITE, Kit.PLASTER)
			k.bevel_box(Vector3(0.28, 0.0, -0.1), Vector3(0.4, 0.46, 0.5), 0.02, SAND, Kit.PLASTER)
			_dr(k, Vector3(-0.2, 0.0, 0.301), 0.0, 0.12, 0.2, BLUE, WHITE)
			_op(k, Vector3(0.28, 0.2, 0.151), 0.0, 0.08, 0.12, true, WHITE, BLUE)
			for i in 4:
				k.box(Vector3(-0.38 + i * 0.075, 0.0, 0.4), Vector3(0.075, 0.07 * (i + 1), 0.12), WHITE, Kit.PLASTER)
			_pergola(k, -0.12, 0.3, -0.05, 0.36, 0.4, 0.17)
			k.box(Vector3(0.28, 0.46, -0.1), Vector3(0.44, 0.03, 0.54), WHITE, Kit.PLASTER)
			_shrub(k, Vector3(0.1, 0.0, 0.42), 0.08)
			_shrub(k, Vector3(-0.42, 0.0, 0.34), 0.07, Color(0.78, 0.35, 0.5))
			_amph(k, Vector3(-0.02, 0.0, 0.34), 0.5)
			_op(k, Vector3(-0.38, 0.12, 0.301), 0.0, 0.07, 0.1, true, WHITE, BLUE)
			_op(k, Vector3(-0.02, 0.12, 0.301), 0.0, 0.07, 0.1, true, WHITE, BLUE)
			_op(k, Vector3(0.28, 0.32, 0.151), 0.0, 0.07, 0.09, true, WHITE, BLUE)
			_op(k, Vector3(0.48, 0.2, -0.1), PI / 2.0, 0.07, 0.1, true, WHITE, BLUE)
			k.chimney(Vector3(0.38, 0.49, -0.26), 0.06, 0.1, WHITE, Kit.PLASTER)
		3:   # a tall house topped by a barrel vault, a chimney and a flat annex
			k.bevel_box(Vector3(-0.1, 0.0, 0.0), Vector3(0.56, 0.4, 0.62), 0.02, WHITE, Kit.PLASTER)
			_vault(k, -0.1, 0.4, 0.0, 0.6, 0.62, 0.15, Color(0.86, 0.80, 0.70), Kit.PLASTER, WHITE)
			k.bevel_box(Vector3(0.36, 0.0, 0.05), Vector3(0.3, 0.22, 0.4), 0.02, CREAM, Kit.PLASTER)
			k.chimney(Vector3(0.36, 0.22, -0.05), 0.06, 0.12, WHITE, Kit.PLASTER)
			_dr(k, Vector3(-0.1, 0.0, 0.311), 0.0, 0.13, 0.24, DWOOD, WHITE)
			_op(k, Vector3(-0.3, 0.2, 0.311), 0.0, 0.07, 0.1, true, WHITE, BLUE)
			_op(k, Vector3(0.1, 0.2, 0.311), 0.0, 0.07, 0.1, true, WHITE, BLUE)
			_op(k, Vector3(-0.1, 0.3, 0.311), 0.0, 0.06, 0.08)
			_op(k, Vector3(0.36, 0.08, 0.251), 0.0, 0.07, 0.09, true, WHITE, BLUE)
			_amph(k, Vector3(0.2, 0.0, 0.32), 0.55)
			_shrub(k, Vector3(-0.38, 0.0, 0.36), 0.08, Color(0.78, 0.35, 0.5))
			_shrub(k, Vector3(0.52, 0.0, 0.3), 0.06)
			_op(k, Vector3(-0.1 + 0.0, 0.28, -0.311), PI, 0.07, 0.1, true, WHITE, BLUE)
			_op(k, Vector3(0.48, 0.1, 0.05), PI / 2.0, 0.07, 0.1, true, WHITE, BLUE)
			_pergola(k, 0.36, 0.22, 0.05, 0.22, 0.3, 0.14)


# --- Carthaginian houses: tall, flat-roofed, terraces -----------------------------------------------


## The roof furniture a terrace gets: pots, an awning on poles, a washing line.
static func _terrace(k: Kit, y: float, cx: float, cz: float, w: float, d: float, kind: int) -> void:
	match kind:
		0:
			for x in [-w * 0.3, w * 0.1]:
				k.cylinder(Vector3(cx + x, y + 0.02, cz + d * 0.28), 0.035, 0.05, TERRACOTTA, Kit.PAINT, 6)
			_awn(k, cx + w * 0.05, cx + w * 0.42, y + 0.24, cz - d * 0.3, y + 0.17, cz + d * 0.05, 4)
			for x in [cx + w * 0.05, cx + w * 0.42]:
				k.rod(Vector3(x, y + 0.02, cz + d * 0.05), Vector3(x, y + 0.17, cz + d * 0.05), 0.01, DWOOD, Kit.TIMBER)
				k.rod(Vector3(x, y + 0.02, cz - d * 0.3), Vector3(x, y + 0.24, cz - d * 0.3), 0.01, DWOOD, Kit.TIMBER)
		1:
			_pergola(k, cx, y + 0.02, cz, w * 0.6, d * 0.5, 0.16)
		2:
			for i in 3:
				k.quad(Vector3(cx - w * 0.3 + i * 0.1, y + 0.2, cz), Vector3(cx - w * 0.3 + i * 0.1 + 0.07, y + 0.2, cz),
					Vector3(cx - w * 0.3 + i * 0.1 + 0.07, y + 0.1, cz), Vector3(cx - w * 0.3 + i * 0.1, y + 0.1, cz),
					[WHITE, Color(0.75, 0.3, 0.25), BLUE][i], Kit.CLOTH, Vector3(cx, y + 0.15, cz - 1.0))
			k.rod(Vector3(cx - w * 0.35, y + 0.2, cz), Vector3(cx + w * 0.1, y + 0.2, cz), 0.006, DWOOD, Kit.TIMBER)
			for x in [cx - w * 0.35, cx + w * 0.1]:
				k.rod(Vector3(x, y + 0.02, cz), Vector3(x, y + 0.2, cz), 0.008, DWOOD, Kit.TIMBER)


static func _g_punic(k: Kit, v: int) -> void:
	match v:
		1:   # three storeys, protruding beams, a stair to the terrace and a room on top
			_block(k, {w = 0.76, d = 0.7, cx = -0.1, floors = [[0.3, WHITE, Kit.PLASTER], [0.26, SAND, Kit.PLASTER], [0.24, WHITE, Kit.PLASTER]],
				ground = "blank", nwin = 2, nside = 2, wsz = 0.055, roof = "flat", parapet = 0.07, beams = true, band_c = Color(0.64, 0.38, 0.30),
				stair = [0.2, 1.0, 5], door_x = -0.2})
			_block(k, {w = 0.36, d = 0.34, cx = -0.22, cz = -0.12, y = 0.84, plinth = false, floors = [[0.22, WHITE, Kit.PLASTER]], ground = "door", door_x = 0.0,
				nside = 1, roof = "dome", dome = WHITE, band = false})
			_terrace(k, 0.9, 0.12, 0.12, 0.3, 0.4, 0)
		2:   # a narrow four-storey tower house with tiny windows and a rooftop awning
			_block(k, {w = 0.56, d = 0.58, floors = [[0.28, Color(0.90, 0.78, 0.55), Kit.PLASTER], [0.24, WHITE, Kit.PLASTER], [0.24, Color(0.90, 0.78, 0.55), Kit.PLASTER], [0.22, WHITE, Kit.PLASTER]],
				ground = "blank", nwin = 2, nside = 2, wsz = 0.045, roof = "flat", parapet = 0.08, beams = true, band_c = SAND, door_x = 0.0, ss = 0.0})
			_terrace(k, 1.06, 0.0, 0.0, 0.5, 0.5, 0)
		3:   # two steps of terrace: a low front block, a taller back block, a shrine dome
			_block(k, {w = 0.9, d = 0.46, cz = 0.24, floors = [[0.28, SAND, Kit.PLASTER], [0.24, WHITE, Kit.PLASTER]], ground = "door", door_x = 0.0, nwin = 3, nside = 1,
				wsz = 0.06, roof = "flat", parapet = 0.06, beams = true, shut = true, shc = BLUE})
			_block(k, {w = 0.7, d = 0.44, cz = -0.27, floors = [[0.3, WHITE, Kit.PLASTER], [0.26, WHITE, Kit.PLASTER], [0.2, SAND, Kit.PLASTER]], ground = "blank", nwin = 2,
				wsz = 0.055, roof = "flat", parapet = 0.07, plinth = false, sides = true, band_c = SAND})
			k.cylinder(Vector3(-0.15, 0.82, -0.27), 0.1, 0.06, WHITE, Kit.PLASTER, 8)
			k.dome(Vector3(-0.15, 0.88, -0.27), 0.11, WHITE, Kit.PLASTER, 0.85, 3, 8)
			_terrace(k, 0.56, 0.2, 0.24, 0.5, 0.3, 1)
		4:   # an ochre house over a workshop arcade, blue trims, washing on the terrace
			_block(k, {w = 0.86, d = 0.72, floors = [[0.27, Color(0.88, 0.68, 0.42), Kit.PLASTER], [0.25, Color(0.92, 0.74, 0.50), Kit.PLASTER], [0.2, Color(0.88, 0.68, 0.42), Kit.PLASTER]],
				ground = "arcade", shops = 3, nwin = 3, wsz = 0.06, shut = true, shc = BLUE, roof = "flat", parapet = 0.07, deck = SAND, band_c = WHITE,
				stair = [-0.35, 1.0, 4]})
			_terrace(k, 0.8, 0.0, 0.0, 0.7, 0.5, 2)


static func _g_punic_low(k: Kit, v: int) -> void:
	match v:
		1:   # a one-storey house behind its yard wall, flat roof and a small upper room
			_block(k, {w = 0.7, d = 0.46, cz = -0.2, floors = [[0.26, WHITE, Kit.PLASTER]], ground = "door", door_x = 0.1, nwin = 2, nside = 1, wsz = 0.06,
				roof = "flat", parapet = 0.06, beams = true})
			_block(k, {w = 0.32, d = 0.3, cx = 0.18, cz = -0.26, y = 0.3, plinth = false, floors = [[0.2, SAND, Kit.PLASTER]], ground = "door", door_x = 0.0, nside = 1,
				roof = "flat", parapet = 0.05})
			k.box(Vector3(0, 0, 0.36), Vector3(0.9, 0.17, 0.06), SAND, Kit.PLASTER)
			k.box(Vector3(0, 0.17, 0.36), Vector3(0.94, 0.02, 0.08), MARBLE, Kit.STONE)
			_dr(k, Vector3(-0.2, 0, 0.392), 0.0, 0.14, 0.15, BLUE)
			_amph(k, Vector3(0.3, 0.0, 0.2), 0.5)
			_shrub(k, Vector3(-0.3, 0.0, 0.2), 0.07, Color(0.40, 0.5, 0.28))
		2:   # two cubes of different heights, ochre and white, stair between
			_block(k, {w = 0.5, d = 0.55, cx = -0.22, floors = [[0.28, Color(0.90, 0.76, 0.52), Kit.PLASTER], [0.2, WHITE, Kit.PLASTER]], ground = "door", door_x = 0.0, nwin = 1, nside = 2,
				wsz = 0.06, roof = "flat", parapet = 0.06, beams = true})
			_block(k, {w = 0.38, d = 0.5, cx = 0.28, cz = 0.02, floors = [[0.24, WHITE, Kit.PLASTER]], ground = "door", door_x = 0.06, nwin = 1, nside = 1, wsz = 0.06,
				roof = "flat", parapet = 0.05, stair = [0.0, -1.0, 4], pergola = [0.0, 0.0, 0.26, 0.32]})


# --- Byzantine houses: banded masonry, timber upper floors, small domes ------------------------------


static func _g_byz(k: Kit, v: int) -> void:
	match v:
		1:   # banded stone and brick below, a jettied timber storey above
			_block(k, {w = 0.76, d = 0.62, floors = [[0.3, STONEC, Kit.STONE], [0.25, Color(0.74, 0.58, 0.38), Kit.TIMBER]], fs = -0.06, ground = "door", door_x = -0.15,
				nwin = 3, nside = 2, shut = true, shc = DWOOD, wbox = true, roof = "gable", rise = 0.17, over = 0.06, tile = TILE_BRN, rmat = Kit.TILE, rz = false, chim = [0.2, -0.1]})
			for yy in [0.09, 0.19, 0.29]:
				k.box(Vector3(0, yy, 0), Vector3(0.766, 0.03, 0.626), BRICKC, Kit.BRICK)
			for sx in [-1.0, 1.0]:   # timber brackets under the jetty
				for z in [0.28, 0.34]:
					k.rod(Vector3(sx * 0.3, 0.3, z - 0.04), Vector3(sx * 0.3, 0.2, z + 0.0), 0.012, DWOOD, Kit.TIMBER)
			_barrel(k, Vector3(0.34, 0.04, 0.36))
			_sack(k, Vector3(-0.34, 0.04, 0.36))
			_logs(k, Vector3(0.3, 0.04, -0.2), 1.57)
		2:   # an arcade of stone arches under a plaster storey, hipped tile roof
			_block(k, {w = 0.84, d = 0.7, floors = [[0.28, STONEC, Kit.STONE], [0.25, YELLOW, Kit.PLASTER]], fs = -0.07, ground = "arcade", shops = 3, nwin = 4, nside = 2,
				shut = true, shc = BLUE, quoins = true, wbox = true, roof = "hip", rise = 0.18, tile = TILE_RED, rmat = Kit.TILE, bal = [1, -0.3, 0.1], band_c = BRICKC, chim = [0.2, 0.0]})
			_amph(k, Vector3(0.38, 0.04, 0.46), 0.5)
			_shrub(k, Vector3(-0.4, 0.04, 0.5), 0.06, DGREEN)
		3:   # a house with a tall stair tower and a pyramid roof
			_block(k, {w = 0.6, d = 0.66, cx = -0.15, floors = [[0.28, BRICKC, Kit.BRICK], [0.24, CREAM, Kit.PLASTER]], ground = "door", door_x = 0.0, nwin = 3, nside = 2,
				shut = true, roof = "gable", rise = 0.15, tile = TILE_GRY, rmat = Kit.TILE, rz = true})
			_block(k, {w = 0.3, d = 0.3, cx = 0.33, cz = -0.14, floors = [[0.28, STONEC, Kit.STONE], [0.22, STONEC, Kit.STONE], [0.2, BRICKC, Kit.BRICK]], ground = "blank",
				nwin = 1, nside = 1, wsz = 0.05, roof = "hip", rise = 0.2, tile = TILE_RED, rmat = Kit.TILE, door_x = 0.0, band_c = CREAM})
		4:   # a low stone house with a lean-to roof, a cross on the gable and a yard wall
			_block(k, {w = 0.62, d = 0.5, cx = -0.1, cz = -0.12, floors = [[0.26, GREY, Kit.STONE]], ground = "door", door_x = 0.1, nwin = 2, nside = 1, shut = true, shc = DWOOD,
				roof = "lean", rise = 0.14, tile = TILE_BRN, rmat = Kit.TILE, quoins = true, chim = [-0.15, -0.2]})
			k.box(Vector3(0.0, 0.0, 0.34), Vector3(0.92, 0.12, 0.05), STONEC, Kit.STONE)
			_logs(k, Vector3(-0.36, 0.0, 0.0), 1.57)
			_barrel(k, Vector3(-0.3, 0.0, 0.2))
			_sack(k, Vector3(0.1, 0.0, 0.25))
			k.box(Vector3(0.3, 0.0, 0.34), Vector3(0.12, 0.2, 0.07), STONEC, Kit.STONE)
			k.box(Vector3(0.3, 0.2, 0.34), Vector3(0.015, 0.09, 0.015), GOLD_C, Kit.GOLD)
			k.box(Vector3(0.3, 0.255, 0.34), Vector3(0.06, 0.015, 0.015), GOLD_C, Kit.GOLD)
			_shrub(k, Vector3(-0.3, 0.0, 0.24), 0.07, DGREEN)
			_amph(k, Vector3(0.38, 0.0, 0.1), 0.45)


## A small chapel: a drum and dome, an apse, a cross.
static func _g_chapel(k: Kit, v: int) -> void:
	var stone := STONEC
	match v:
		1:   # cross-in-square: a cube under a dome on a drum, apse behind
			k.box(Vector3(0, 0, 0), Vector3(0.56, 0.04, 0.56), GREY, Kit.STONE)
			k.box(Vector3(0, 0.04, 0.0), Vector3(0.5, 0.34, 0.5), stone, Kit.STONE)
			for yy in [0.1, 0.2, 0.3]:
				k.box(Vector3(0, yy, 0.0), Vector3(0.506, 0.03, 0.506), BRICKC, Kit.BRICK)
			k.box(Vector3(0, 0.37, 0.0), Vector3(0.54, 0.025, 0.54), MARBLE, Kit.STONE)
			_apse(k, 0.0, 0.04, -0.25, 0.17, 0.26, stone, Kit.STONE, TILE_RED)
			_dr(k, Vector3(0, 0.04, 0.251), 0.0, 0.12, 0.22, DWOOD)
			_op(k, Vector3(-0.17, 0.2, 0.251), 0.0, 0.05, 0.12)
			_op(k, Vector3(0.17, 0.2, 0.251), 0.0, 0.05, 0.12)
			k.cylinder(Vector3(0, 0.395, 0.0), 0.17, 0.15, CREAM, Kit.PLASTER, 8)
			for i in 4:
				_op(k, Vector3(sin(i * PI / 2.0) * 0.172, 0.43, cos(i * PI / 2.0) * 0.172), i * PI / 2.0, 0.04, 0.07)
			k.dome(Vector3(0, 0.545, 0.0), 0.18, TILE_GRY, Kit.TILE, 0.95, 3, 8)
			k.rod(Vector3(0, 0.715, 0.0), Vector3(0, 0.82, 0.0), 0.008, GOLD_C, Kit.GOLD)
			k.rod(Vector3(-0.04, 0.78, 0.0), Vector3(0.04, 0.78, 0.0), 0.008, GOLD_C, Kit.GOLD)
			for i in 2:
				k.box(Vector3(0, 0.0, 0.3 + i * 0.05), Vector3(0.24 + i * 0.06, 0.04 * (2 - i), 0.05), MARBLE_D, Kit.STONE)
			for sg in [-1.0, 1.0]:
				k.box(Vector3(sg * 0.26, 0.04, 0.0), Vector3(0.03, 0.3, 0.2), stone, Kit.STONE)
				_op(k, Vector3(sg * 0.2511, 0.2, 0.0), sg * PI / 2.0, 0.05, 0.12)
			_cypress(k, Vector3(-0.38, 0.0, 0.2), 1.3)
			_cypress(k, Vector3(0.38, 0.0, 0.2), 1.1)
		2:   # a single-nave chapel with a bell gable, an apse and a small dome over the choir
			k.box(Vector3(0, 0, 0), Vector3(0.5, 0.04, 0.92), GREY, Kit.STONE)
			k.box(Vector3(0, 0.04, 0.1), Vector3(0.38, 0.3, 0.6), CREAM, Kit.PLASTER)
			k.gable_roof(Vector3(0, 0.34, 0.1), 0.6, 0.38, 0.16, 0.04, 0.03, TILE_RED, Kit.TILE, CREAM, Kit.PLASTER, PI / 2.0)
			_apse(k, 0.0, 0.04, -0.2, 0.16, 0.26, CREAM, Kit.PLASTER, TILE_RED)
			k.box(Vector3(0, 0.04, -0.1), Vector3(0.3, 0.3, 0.2), CREAM, Kit.PLASTER)
			k.cylinder(Vector3(0, 0.34, -0.1), 0.12, 0.08, CREAM, Kit.PLASTER, 8)
			k.dome(Vector3(0, 0.42, -0.1), 0.125, TILE_GRY, Kit.TILE, 0.95, 3, 8)
			_dr(k, Vector3(0, 0.04, 0.401), 0.0, 0.13, 0.22, DWOOD)
			for z in [0.0, 0.22]:
				for sg in [-1.0, 1.0]:
					_op(k, Vector3(sg * 0.191, 0.16, z), sg * PI / 2.0, 0.05, 0.12)
			k.box(Vector3(0, 0.34, 0.37), Vector3(0.12, 0.26, 0.05), stone, Kit.STONE)
			k.box(Vector3(0, 0.6, 0.37), Vector3(0.13, 0.03, 0.06), stone.darkened(0.1), Kit.STONE)
			k.dome(Vector3(0, 0.63, 0.37), 0.045, GOLD_C, Kit.GOLD, 0.9, 2, 6)
			_cypress(k, Vector3(-0.3, 0.0, 0.3), 1.3)
			_cypress(k, Vector3(0.3, 0.0, -0.05), 1.0)
			k.box(Vector3(0, 0.04, 0.46), Vector3(0.22, 0.03, 0.06), MARBLE_D, Kit.STONE)
			for z in [-0.0, 0.22]:
				for sg in [-1.0, 1.0]:
					k.box(Vector3(sg * 0.205, 0.04, z), Vector3(0.03, 0.24, 0.07), stone, Kit.STONE)


# --- two-lot buildings (about 2.0 wide by 1.0 deep) -----------------------------------------------


static func _big_insula(k: Kit, v: int) -> void:
	var brick := [0.26, BRICKC, Kit.BRICK]
	match v:
		1:   # a block of shops with three floors over them and a taller tenement at one end
			k.box(Vector3(0, 0, 0), Vector3(2.0, 0.04, 0.96), GREY, Kit.STONE)
			_block(k, {w = 1.3, d = 0.88, cx = -0.34, plinth = false, floors = [brick, [0.24, OCHRE, Kit.PLASTER], [0.22, SALMON, Kit.PLASTER]],
				y = 0.0, ground = "shops", shops = 5, nwin = 6, shut = true, bal = [1, -0.5, 0.0], awn = [0.2, 0.55], roof = "gable", rise = 0.17, over = 0.07,
				tile = TILE_RED, rmat = Kit.TILE, chim = [-0.4, -0.1]})
			_block(k, {w = 0.6, d = 0.88, cx = 0.65, plinth = false, floors = [[0.27, STONEC, Kit.STONE], [0.23, LIME, Kit.PLASTER], [0.22, PINK, Kit.PLASTER], [0.2, OCHRE, Kit.PLASTER]],
				fs = -0.03, ground = "shops", shops = 2, nwin = 3, shut = true, roof = "hip", rise = 0.2, tile = TILE_GRY, rmat = Kit.TILE})
		2:   # three tenements in a row, differing in height, colour and roof
			k.box(Vector3(0, 0, 0), Vector3(2.0, 0.04, 0.96), GREY, Kit.STONE)
			_block(k, {w = 0.66, d = 0.86, cx = -0.67, plinth = false, floors = [brick, [0.23, PINK, Kit.PLASTER], [0.2, LIME, Kit.PLASTER]], ground = "shops", shops = 2, nwin = 2,
				shut = true, roof = "gable", rise = 0.14, tile = TILE_ORG, rmat = Kit.TILE, rz = true, bal = [1, -0.2, 0.2]})
			_block(k, {w = 0.66, d = 0.86, cx = 0.0, plinth = false, floors = [[0.27, GREY, Kit.STONE], [0.24, OCHRE, Kit.PLASTER], [0.22, WHITE, Kit.PLASTER], [0.2, SALMON, Kit.PLASTER]],
				ground = "shops", shops = 2, nwin = 2, shut = true, roof = "hip", rise = 0.18, tile = TILE_RED, rmat = Kit.TILE, ss = 0.02})
			_block(k, {w = 0.66, d = 0.86, cx = 0.67, plinth = false, floors = [brick, [0.23, YELLOW, Kit.PLASTER]], ground = "shops", shops = 2, nwin = 2, shut = true,
				roof = "flat", parapet = 0.07, pergola = [0.0, 0.0, 0.4, 0.4], stair = [0.1, -1.0, 4]})


static func _big_domus(k: Kit, v: int) -> void:
	match v:
		1:   # an atrium house beside its own peristyle garden
			k.push(Kit.at(Vector3(-0.5, 0, 0)))
			_atrium(k, {wall = OCHRE, front = "porch", back = "tablinum", bh = 0.4, tile = TILE_RED, rmat = Kit.TILE, w = 0.96, d = 0.96})
			k.pop()
			_peristyle(k, 0.5, 0.0, 0.96, 0.96, 4, 4, CREAM)
		2:   # shops along the street, then a long atrium and a high dining hall with a tower
			k.box(Vector3(0, 0, 0), Vector3(2.0, 0.04, 0.96), GREY, Kit.STONE)
			_block(k, {w = 2.0, d = 0.3, cz = 0.33, plinth = false, floors = [[0.3, SALMON, Kit.PLASTER]], ground = "shops", shops = 6, nwin = 0, nside = 1, door = true,
				roof = "gable", rise = 0.11, tile = TILE_ORG, rmat = Kit.TILE, band_c = MARBLE, awn = [-0.7, -0.2]})
			_block(k, {w = 0.9, d = 0.5, cx = -0.55, cz = -0.2, plinth = false, floors = [[0.34, WHITE, Kit.PLASTER], [0.2, CREAM, Kit.PLASTER]], ground = "door", nwin = 2, nside = 1,
				roof = "hip", rise = 0.17, tile = TILE_RED, rmat = Kit.TILE})
			_block(k, {w = 0.9, d = 0.5, cx = 0.55, cz = -0.2, plinth = false, floors = [[0.3, YELLOW, Kit.PLASTER]], ground = "door", nwin = 2, nside = 1,
				roof = "gable", rise = 0.15, tile = TILE_BRN, rmat = Kit.TILE})
			k.box(Vector3(0, 0.04, -0.2), Vector3(0.7, 0.012, 0.5), EARTHC, Kit.EARTH)
			k.box(Vector3(0, 0.05, -0.2), Vector3(0.2, 0.04, 0.2), MARBLE, Kit.STONE)
			k.box(Vector3(0, 0.09, -0.2), Vector3(0.16, 0.008, 0.16), Color.WHITE, Kit.WATER)
			_shrub(k, Vector3(-0.22, 0.04, -0.3), 0.08)
			_shrub(k, Vector3(0.22, 0.04, -0.1), 0.08, DGREEN)


## A peristyle garden: a ring of columns under a shed roof, round a garden with a pool.
static func _peristyle(k: Kit, cx: float, cz: float, w: float, d: float, nx: int, nz: int, wall: Color) -> void:
	var y0 := 0.04
	k.push(Kit.at(Vector3(cx, 0, cz)))
	k.box(Vector3(0, 0, 0), Vector3(w + 0.04, y0, d + 0.04), GREY, Kit.STONE)
	var wh := 0.34
	var wt := 0.05
	k.box(Vector3(0, y0, -d / 2.0 + wt / 2.0), Vector3(w, wh, wt), wall, Kit.PLASTER)
	k.box(Vector3(0, y0, d / 2.0 - wt / 2.0), Vector3(w, wh - 0.1, wt), wall, Kit.PLASTER)
	for sg in [-1.0, 1.0]:
		k.box(Vector3(sg * (w / 2.0 - wt / 2.0), y0, 0), Vector3(wt, wh - 0.04, d - 2.0 * wt), wall, Kit.PLASTER)
	k.box(Vector3(0, y0 + wh, -d / 2.0 + wt / 2.0), Vector3(w + 0.03, 0.025, wt + 0.03), MARBLE, Kit.STONE)
	var ix := w / 2.0 - 0.2
	var iz := d / 2.0 - 0.2
	k.box(Vector3(0, y0, 0), Vector3(ix * 2.0, 0.012, iz * 2.0), Color(0.62, 0.64, 0.42), Kit.EARTH)
	for i in nx:
		var x := -ix + 2.0 * ix * i / (nx - 1)
		_pil(k, Vector3(x, y0, iz), 0.27)
		_pil(k, Vector3(x, y0, -iz), 0.27)
	for j in range(1, nz - 1):
		var z := -iz + 2.0 * iz * j / (nz - 1)
		_pil(k, Vector3(-ix, y0, z), 0.27)
		_pil(k, Vector3(ix, y0, z), 0.27)
	_frame_roof(k, Vector3(0, 0, 0), w / 2.0 - wt, d / 2.0 - wt, ix + 0.03, iz + 0.03, y0 + 0.37, y0 + 0.27, 0.025, TERRA, Kit.OWNER_ROOF)
	k.box(Vector3(0, y0, 0), Vector3(0.34, 0.05, 0.2), MARBLE, Kit.STONE)
	k.box(Vector3(0, y0 + 0.045, 0), Vector3(0.3, 0.01, 0.16), Color.WHITE, Kit.WATER)
	_shrub(k, Vector3(-0.2, y0, 0.14), 0.07)
	_shrub(k, Vector3(0.2, y0, -0.14), 0.07, DGREEN)
	_cypress(k, Vector3(0.22, y0, 0.1), 1.0)
	k.pop()


static func _big_farm(k: Kit, v: int) -> void:
	match v:
		1:   # a farmyard: house, long barn, and a wall round the yard with a well
			k.box(Vector3(0, 0, 0), Vector3(2.0, 0.03, 0.96), EARTHC, Kit.EARTH)
			_block(k, {w = 0.7, d = 0.46, cx = -0.62, cz = -0.22, plinth = false, floors = [[0.26, LIME, Kit.PLASTER], [0.18, OCHRE, Kit.PLASTER]], ground = "door", door_x = 0.0, nwin = 3, nside = 1,
				roof = "gable", rise = 0.15, tile = TILE_RED, rmat = Kit.TILE, band = false, y = 0.03, chim = [-0.2, 0.0]})
			_block(k, {w = 0.9, d = 0.46, cx = 0.4, cz = -0.25, plinth = false, floors = [[0.26, Color(0.62, 0.50, 0.36), Kit.TIMBER]], ground = "blank", roof = "thatch", rise = 0.2,
				band = false, sides = false, y = 0.03})
			k.box(Vector3(0.4, 0.03, -0.019), Vector3(0.24, 0.2, 0.014), DWOOD, Kit.TIMBER)
			k.cylinder(Vector3(-0.1, 0.03, 0.2), 0.08, 0.09, MARBLE_D, Kit.STONE, 7)
			k.cylinder(Vector3(-0.1, 0.12, 0.2), 0.065, 0.005, Color.WHITE, Kit.WATER, 7)
			k.box(Vector3(0.0, 0.03, 0.46), Vector3(1.9, 0.1, 0.04), Color(0.7, 0.66, 0.58), Kit.STONE)
			k.dome(Vector3(0.7, 0.03, 0.2), 0.14, Color(0.84, 0.72, 0.4), Kit.THATCH, 0.9, 3, 7)
			_shrub(k, Vector3(-0.7, 0.03, 0.2), 0.09, Color(0.46, 0.55, 0.36))
		2:   # a villa rustica: a long portico house facing a yard, a press room and a granary
			k.box(Vector3(0, 0, 0), Vector3(2.0, 0.03, 0.96), EARTHC, Kit.EARTH)
			_block(k, {w = 1.2, d = 0.4, cx = -0.38, cz = -0.26, plinth = false, floors = [[0.3, OCHRE, Kit.PLASTER]], ground = "door", door_x = 0.0, nwin = 4, nside = 1, shut = true,
				roof = "gable", rise = 0.15, tile = TILE_ORG, rmat = Kit.TILE, y = 0.03, band_c = MARBLE})
			for i in 6:
				_pil(k, Vector3(-0.9 + i * 0.22, 0.03, -0.03), 0.27, 0.024)
			k.box(Vector3(-0.38, 0.3, -0.03), Vector3(1.2, 0.035, 0.06), MARBLE, Kit.STONE)
			_block(k, {w = 0.5, d = 0.55, cx = 0.62, cz = -0.12, plinth = false, floors = [[0.3, STONEC, Kit.STONE], [0.18, LIME, Kit.PLASTER]], ground = "door", door_x = -0.1, nwin = 2, nside = 1,
				roof = "lean", rise = 0.14, tile = TILE_BRN, rmat = Kit.TILE, y = 0.03, band = false})
			for i in 3:
				k.frustum(Vector3(0.1 + i * 0.2, 0.03, 0.3), 0.07, 0.1, 0.12, TERRACOTTA, Kit.PAINT, 6, false)
				k.frustum(Vector3(0.1 + i * 0.2, 0.15, 0.3), 0.1, 0.05, 0.07, TERRACOTTA, Kit.PAINT, 6)
			_cypress(k, Vector3(-0.8, 0.03, 0.3), 1.4)
			_cypress(k, Vector3(-0.65, 0.03, 0.36), 1.2)
			_pergola(k, 0.82, 0.03, 0.3, 0.3, 0.28, 0.17)


static func _big_court(k: Kit, v: int) -> void:
	match v:
		1:   # two courts side by side
			k.push(Kit.at(Vector3(-0.5, 0, 0)))
			_court(k, {wall = WHITE, trim = BLUE, tile = TILE_ORG, rmat = Kit.TILE, court = ["tree"], w = 0.96, d = 0.96, bh = 0.34})
			k.pop()
			k.push(Kit.at(Vector3(0.5, 0, 0)))
			_court(k, {wall = OCHRE, trim = WOOD, tile = TERRA, bh = 0.5, balcony = true, pastas = 3, sh = 0.22, court = ["well", "pots"], w = 0.96, d = 0.96, gate_x = -0.2})
			k.pop()
		2:   # a terrace of whitewashed cubes stepping up a slope
			k.box(Vector3(0, 0, 0), Vector3(2.0, 0.04, 0.96), GREY, Kit.STONE)
			var hs := [0.26, 0.34, 0.44, 0.3]
			var cols := [WHITE, CREAM, WHITE, SAND]
			for i in 4:
				var h: float = hs[i]
				var x: float = -0.75 + i * 0.5
				k.bevel_box(Vector3(x, 0.04, 0.0), Vector3(0.5, h, 0.86), 0.02, cols[i], Kit.PLASTER)
				_dr(k, Vector3(x - 0.1, 0.04, 0.431), 0.0, 0.1, minf(h - 0.06, 0.2), BLUE, WHITE)
				_op(k, Vector3(x + 0.12, 0.04 + h * 0.4, 0.431), 0.0, 0.07, 0.09, true, WHITE, BLUE)
				if h > 0.33:
					_op(k, Vector3(x, 0.04 + h * 0.75, 0.431), 0.0, 0.07, 0.08, true, WHITE, BLUE)
			k.dome(Vector3(0.0, 0.38, 0.0), 0.15, BLUE, Kit.PAINT, 0.9, 3, 8)
			_pergola(k, 0.75, 0.34, 0.0, 0.34, 0.5, 0.16)
			_stair(k, -0.62, 0.43, 1.0, 0.26, 3, 0.1)


static func _big_punic(k: Kit, v: int) -> void:
	match v:
		1:   # a terraced row of three tall houses sharing a roof terrace
			k.box(Vector3(0, 0, 0), Vector3(2.0, 0.04, 0.96), GREY, Kit.STONE)
			_block(k, {w = 0.7, d = 0.86, cx = -0.65, plinth = false, floors = [[0.3, WHITE, Kit.PLASTER], [0.26, SAND, Kit.PLASTER]], ground = "blank", nwin = 2, wsz = 0.055, roof = "flat",
				beams = true, door_x = -0.2, stair = [0.1, 1.0, 4]})
			_block(k, {w = 0.62, d = 0.86, cx = 0.0, plinth = false, floors = [[0.3, SAND, Kit.PLASTER], [0.26, WHITE, Kit.PLASTER], [0.24, SAND, Kit.PLASTER], [0.2, WHITE, Kit.PLASTER]], ground = "blank", nwin = 2,
				wsz = 0.05, roof = "flat", parapet = 0.08, beams = true, door_x = 0.1})
			_block(k, {w = 0.7, d = 0.86, cx = 0.65, plinth = false, floors = [[0.3, WHITE, Kit.PLASTER], [0.26, WHITE, Kit.PLASTER], [0.22, SAND, Kit.PLASTER]], ground = "blank", nwin = 2,
				wsz = 0.055, roof = "flat", beams = true, door_x = 0.15})
			_terrace(k, 0.6, -0.65, 0.0, 0.6, 0.6, 0)
			_terrace(k, 0.84, 0.65, 0.0, 0.6, 0.6, 2)
		2:   # a row with a covered gateway, a workshop arcade and a domed shrine on top
			k.box(Vector3(0, 0, 0), Vector3(2.0, 0.04, 0.96), GREY, Kit.STONE)
			_block(k, {w = 1.2, d = 0.86, cx = -0.4, plinth = false, floors = [[0.28, Color(0.90, 0.72, 0.46), Kit.PLASTER], [0.26, WHITE, Kit.PLASTER]], ground = "arcade", shops = 4, nwin = 4,
				wsz = 0.06, shut = true, shc = BLUE, roof = "flat", parapet = 0.07, beams = false, band_c = WHITE})
			_block(k, {w = 0.7, d = 0.86, cx = 0.65, plinth = false, floors = [[0.3, WHITE, Kit.PLASTER], [0.26, WHITE, Kit.PLASTER], [0.22, SAND, Kit.PLASTER]], ground = "blank", nwin = 2,
				wsz = 0.05, roof = "flat", parapet = 0.07, beams = true, door_x = -0.1})
			k.cylinder(Vector3(-0.5, 0.58, 0.0), 0.15, 0.08, WHITE, Kit.PLASTER, 8)
			k.dome(Vector3(-0.5, 0.66, 0.0), 0.16, WHITE, Kit.PLASTER, 0.85, 3, 8)
			_terrace(k, 0.58, 0.0, 0.0, 0.5, 0.4, 1)


static func _big_byz(k: Kit, v: int) -> void:
	match v:
		1:   # a house and a small domed chapel side by side
			k.push(Kit.at(Vector3(-0.45, 0, 0)))
			_g_byz(k, 2)
			k.pop()
			k.push(Kit.at(Vector3(0.68, 0, 0.0), 0.0))
			k.push(Transform3D(Basis.from_scale(Vector3(0.8, 0.8, 0.8)), Vector3.ZERO))
			_g_chapel(k, 1)
			k.pop()
			k.pop()
		2:   # a long timber-fronted row of three houses with different roofs
			k.box(Vector3(0, 0, 0), Vector3(2.0, 0.04, 0.96), GREY, Kit.STONE)
			_block(k, {w = 0.66, d = 0.84, cx = -0.67, plinth = false, floors = [[0.28, STONEC, Kit.STONE], [0.24, Color(0.74, 0.58, 0.38), Kit.TIMBER]], fs = -0.06, ground = "door", nwin = 2,
				shut = true, shc = DWOOD, roof = "gable", rise = 0.16, tile = TILE_BRN, rmat = Kit.TILE, rz = true})
			_block(k, {w = 0.66, d = 0.84, cx = 0.0, plinth = false, floors = [[0.28, BRICKC, Kit.BRICK], [0.24, CREAM, Kit.PLASTER], [0.2, Color(0.74, 0.58, 0.38), Kit.TIMBER]], fs = -0.04, ground = "arcade", shops = 2, nwin = 2,
				roof = "hip", rise = 0.18, tile = TILE_RED, rmat = Kit.TILE})
			_block(k, {w = 0.66, d = 0.84, cx = 0.67, plinth = false, floors = [[0.3, GREY, Kit.STONE], [0.22, YELLOW, Kit.PLASTER]], ground = "door", nwin = 2, shut = true, shc = BLUE,
				roof = "lean", rise = 0.14, tile = TILE_GRY, rmat = Kit.TILE, bal = [1, -0.2, 0.2]})


# --- regional props -------------------------------------------------------------------------------


static func _g_prop(k: Kit, kind: String) -> void:
	match kind:
		"prop_amphorae":   # a cluster of storage jars, one leaning on the others
			_amph(k, Vector3(-0.07, 0, 0.0), 0.95, TERRACOTTA, 5)
			_amph(k, Vector3(0.07, 0, 0.03), 0.9, Color(0.70, 0.50, 0.32), 5)
			_amph(k, Vector3(0.0, 0, -0.1), 1.0, Color(0.80, 0.55, 0.36), 5)
			k.push(Transform3D(Basis(Vector3(0, 0, 1), -0.45), Vector3(0.02, 0.03, 0.12)))
			_amph(k, Vector3.ZERO, 0.85, TERRACOTTA.darkened(0.1), 5)
			k.pop()
		"prop_altar":   # a stone altar on two steps with a flame
			k.box(Vector3(0, 0, 0), Vector3(0.3, 0.03, 0.22), GREY, Kit.STONE)
			k.box(Vector3(0, 0.03, 0), Vector3(0.22, 0.03, 0.16), MARBLE_D, Kit.STONE)
			k.box(Vector3(0, 0.06, 0), Vector3(0.14, 0.12, 0.1), MARBLE, Kit.STONE)
			k.box(Vector3(0, 0.18, 0), Vector3(0.18, 0.025, 0.13), MARBLE, Kit.STONE)
			for x in [-0.07, 0.07]:
				k.box(Vector3(x, 0.205, 0), Vector3(0.03, 0.03, 0.03), MARBLE, Kit.STONE)
			k.frustum(Vector3(0, 0.205, 0), 0.04, 0.0, 0.08, Color(0.95, 0.55, 0.2), Kit.GOLD, 5)
		"prop_herm":   # a square pillar with a head and two stumps for arms
			k.box(Vector3(0, 0, 0), Vector3(0.12, 0.03, 0.12), GREY, Kit.STONE)
			k.frustum(Vector3(0, 0.03, 0), 0.055, 0.04, 0.26, MARBLE, Kit.STONE, 4)
			for s in [-1.0, 1.0]:
				k.box(Vector3(s * 0.05, 0.22, 0), Vector3(0.03, 0.025, 0.03), MARBLE, Kit.STONE)
			k.dome(Vector3(0, 0.29, 0), 0.04, MARBLE, Kit.STONE, 1.1, 2, 6)
			k.box(Vector3(0, 0.27, 0.0), Vector3(0.07, 0.015, 0.07), MARBLE_D, Kit.STONE)
		"prop_fountain_basin":   # a round basin with a central pillar and a bowl
			k.cylinder(Vector3(0, 0, 0), 0.26, 0.1, MARBLE, Kit.STONE, 8)
			k.cylinder(Vector3(0, 0.1, 0), 0.22, 0.004, Color.WHITE, Kit.WATER, 8)
			k.frustum(Vector3(0, 0.1, 0), 0.05, 0.035, 0.14, MARBLE, Kit.STONE, 6, false)
			k.frustum(Vector3(0, 0.24, 0), 0.04, 0.1, 0.04, MARBLE, Kit.STONE, 6)
			k.cylinder(Vector3(0, 0.28, 0), 0.085, 0.004, Color.WHITE, Kit.WATER, 6)
			k.frustum(Vector3(0, 0.28, 0), 0.015, 0.0, 0.07, MARBLE, Kit.STONE, 4)
		"prop_pergola":   # a vine pergola over a bench-sized strip
			_pergola(k, 0.0, 0.0, 0.0, 0.5, 0.34, 0.26)
			k.box(Vector3(0, 0, -0.1), Vector3(0.36, 0.05, 0.07), WOOD, Kit.TIMBER)


# --- house sets: what a city of each culture is drawn from -----------------------------------------


## The kinds for a rank, repeated to weight them. `culture` is the owner's portrait style; any
## culture that is not Greek, Hellenistic, Punic or Byzantine is drawn as Roman.
static func house_set(culture: String, rank: String) -> Array:
	match culture:
		"greek", "hellenistic":
			return _set_greek(rank, culture == "hellenistic")
		"punic":
			return _set_punic(rank)
		"byzantine":
			return _set_byz(rank)
	return _set_roman(rank)


static func _set_roman(rank: String) -> Array:
	match rank:
		"core":
			return ["house_rom_domus_1", "house_rom_domus_2", "house_rom_domus_3", "house_rom_domus_4", "house_rom_domus_2", "house_rom_domus_4",
				"house_rom_insula_1", "house_rom_insula_2", "house_rom_insula_4", "house_1", "house_4"]
		"city":
			return ["house_rom_domus_1", "house_rom_domus_3", "house_rom_insula_1", "house_rom_insula_2", "house_rom_insula_3", "house_rom_insula_4",
				"house_rom_taberna_1", "house_rom_taberna_3", "house_rom_domus_4", "house_1", "house_2", "house_6"]
		"edge":
			return ["house_rom_insula_3", "house_rom_insula_1", "house_rom_taberna_1", "house_rom_taberna_2", "house_rom_taberna_3", "house_rom_cottage_1",
				"house_rom_cottage_3", "house_6", "house_2", "house_rom_insula_2"]
		"suburb":
			return ["house_rom_cottage_1", "house_rom_cottage_3", "house_rom_taberna_2", "house_rom_taberna_1", "house_rom_farm_1", "house_rom_domus_1",
				"house_rom_insula_3", "house_6", "house_rom_cottage_2"]
		"town":
			return ["house_rom_domus_1", "house_rom_domus_3", "house_rom_insula_3", "house_rom_taberna_1", "house_rom_taberna_2", "house_rom_cottage_1",
				"house_rom_cottage_3", "house_1", "house_6", "house_rom_insula_1"]
		"village":
			return ["house_rom_cottage_1", "house_rom_cottage_1", "house_rom_cottage_3", "house_rom_cottage_3", "house_rom_cottage_2", "house_rom_farm_1",
				"house_rom_farm_2", "house_rom_taberna_2", "house_6"]
		"farm":
			return ["house_rom_farm_1", "house_rom_farm_2", "house_rom_farm_3", "house_rom_farm_4", "house_rom_farm_1", "house_rom_cottage_1"]
		"camp":
			return ["house_rom_cottage_2", "house_rom_cottage_2", "house_rom_cottage_1", "house_rom_cottage_3"]
	return ["house_rom_domus_1", "house_rom_insula_1", "house_rom_taberna_1", "house_rom_cottage_1", "house_1", "house_2"]


static func _set_greek(rank: String, hellenistic: bool) -> Array:
	var rich: Array = ["house_gr_court_1", "house_gr_court_2", "house_gr_court_3", "house_gr_court_4", "house_3", "house_4"]
	if hellenistic:
		rich = ["house_gr_court_4", "house_gr_court_2", "house_gr_court_4", "house_gr_court_1", "house_gr_court_3", "house_rom_domus_2", "house_4"]
	match rank:
		"core":
			return rich + ["house_gr_court_2", "house_gr_court_4"]
		"city":
			return rich + ["house_gr_cube_1", "house_gr_cube_2", "house_gr_cube_3", "house_rom_taberna_1", "house_rom_insula_3", "house_6"]
		"edge":
			return ["house_gr_cube_1", "house_gr_cube_2", "house_gr_cube_3", "house_gr_court_3", "house_rom_taberna_2", "house_gr_cube_2", "house_rom_cottage_1",
				"house_rom_insula_3", "house_gr_court_1"]
		"suburb":
			return ["house_gr_cube_1", "house_gr_cube_2", "house_gr_cube_3", "house_rom_cottage_1", "house_rom_cottage_3", "house_rom_taberna_2", "house_rom_farm_1"]
		"town":
			return ["house_gr_cube_1", "house_gr_cube_2", "house_gr_cube_3", "house_gr_court_1", "house_gr_court_3", "house_rom_taberna_1", "house_rom_cottage_3"]
		"village":
			return ["house_gr_cube_1", "house_gr_cube_1", "house_gr_cube_2", "house_gr_cube_3", "house_rom_cottage_1", "house_rom_cottage_3", "house_rom_farm_2",
				"house_rom_cottage_2"]
		"farm":
			return ["house_rom_farm_1", "house_rom_farm_2", "house_rom_farm_3", "house_rom_farm_4", "house_gr_cube_1"]
		"camp":
			return ["house_rom_cottage_2", "house_rom_cottage_3", "house_rom_cottage_1"]
	return ["house_gr_court_1", "house_gr_cube_1", "house_gr_cube_2"]


static func _set_punic(rank: String) -> Array:
	match rank:
		"core":
			return ["house_pun_tall_1", "house_pun_tall_2", "house_pun_tall_3", "house_pun_tall_4", "house_pun_tall_3", "house_pun_tall_1", "house_5", "house_pun_tall_2"]
		"city":
			return ["house_pun_tall_1", "house_pun_tall_2", "house_pun_tall_3", "house_pun_tall_4", "house_pun_low_1", "house_pun_low_2", "house_5", "house_rom_taberna_1"]
		"edge":
			return ["house_pun_low_1", "house_pun_low_2", "house_pun_tall_2", "house_pun_tall_4", "house_5", "house_rom_taberna_2", "house_pun_low_2"]
		"suburb":
			return ["house_pun_low_1", "house_pun_low_2", "house_pun_low_1", "house_rom_cottage_1", "house_rom_cottage_3", "house_rom_taberna_2", "house_rom_farm_2"]
		"town":
			return ["house_pun_low_1", "house_pun_low_2", "house_pun_tall_4", "house_5", "house_pun_tall_1", "house_rom_taberna_1"]
		"village":
			return ["house_pun_low_1", "house_pun_low_2", "house_pun_low_1", "house_rom_cottage_1", "house_rom_cottage_2", "house_rom_farm_2", "house_gr_cube_2"]
		"farm":
			return ["house_rom_farm_2", "house_rom_farm_3", "house_rom_farm_4", "house_rom_farm_1", "house_pun_low_1"]
		"camp":
			return ["house_rom_cottage_2", "house_rom_cottage_2", "house_rom_cottage_3"]
	return ["house_pun_tall_1", "house_pun_low_1", "house_5"]


static func _set_byz(rank: String) -> Array:
	match rank:
		"core":
			return ["house_byz_1", "house_byz_2", "house_byz_3", "house_byz_2", "house_byz_3", "house_byz_chapel_1", "house_rom_domus_2", "house_4"]
		"city":
			return ["house_byz_1", "house_byz_2", "house_byz_3", "house_byz_4", "house_byz_chapel_2", "house_rom_insula_2", "house_rom_taberna_3", "house_byz_1"]
		"edge":
			return ["house_byz_4", "house_byz_1", "house_byz_4", "house_rom_taberna_2", "house_rom_cottage_3", "house_byz_3", "house_rom_insula_3"]
		"suburb":
			return ["house_byz_4", "house_byz_4", "house_rom_cottage_1", "house_rom_cottage_3", "house_rom_taberna_2", "house_rom_farm_1", "house_byz_1"]
		"town":
			return ["house_byz_1", "house_byz_4", "house_byz_2", "house_byz_chapel_2", "house_rom_taberna_1", "house_rom_cottage_3", "house_byz_3"]
		"village":
			return ["house_byz_4", "house_byz_4", "house_rom_cottage_1", "house_rom_cottage_3", "house_byz_chapel_2", "house_rom_farm_1", "house_rom_farm_2", "house_rom_cottage_2"]
		"farm":
			return ["house_rom_farm_1", "house_rom_farm_2", "house_rom_farm_3", "house_rom_farm_4", "house_byz_4"]
		"camp":
			return ["house_rom_cottage_2", "house_rom_cottage_3", "house_rom_cottage_1"]
	return ["house_byz_1", "house_byz_4", "house_byz_2"]


## The two-lot buildings (about 2.0 wide by 1.0 deep) for a rank, or [] where a rank has none.
static func big_house_set(culture: String, rank: String) -> Array:
	match culture:
		"greek", "hellenistic":
			match rank:
				"core", "city":
					return ["big_gr_court_1", "big_gr_court_2", "big_gr_court_1", "big_rom_domus_2"]
				"edge", "suburb", "town":
					return ["big_gr_court_2", "big_gr_court_1"]
				"farm":
					return ["big_rom_farm_1", "big_rom_farm_2"]
		"punic":
			match rank:
				"core", "city":
					return ["big_pun_row_1", "big_pun_row_2", "big_pun_row_1"]
				"edge", "suburb", "town":
					return ["big_pun_row_1", "big_pun_row_2"]
				"farm":
					return ["big_rom_farm_1", "big_rom_farm_2"]
		"byzantine":
			match rank:
				"core", "city":
					return ["big_byz_1", "big_byz_2", "big_byz_2", "big_rom_insula_2"]
				"edge", "suburb", "town":
					return ["big_byz_2", "big_byz_1"]
				"farm":
					return ["big_rom_farm_1", "big_rom_farm_2"]
		_:
			match rank:
				"core":
					return ["big_rom_domus_1", "big_rom_domus_2", "big_rom_insula_1", "big_rom_domus_1", "big_rom_insula_2"]
				"city":
					return ["big_rom_insula_1", "big_rom_insula_2", "big_rom_domus_1", "big_rom_domus_2"]
				"edge", "suburb":
					return ["big_rom_insula_2", "big_rom_insula_1"]
				"town":
					return ["big_rom_insula_2", "big_rom_domus_2"]
				"farm":
					return ["big_rom_farm_1", "big_rom_farm_2"]
				"village":
					return ["big_rom_farm_1"]
	return []
