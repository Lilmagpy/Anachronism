## Urbs (U8 houses): the small things of the fill: trees, street props (carts, amphorae, sacks,
## crates), street furniture (fountain, well-head, compitum shrine), roadside tombs and farmland
## furniture. Built with UrbsFillParts.MB; surfaces are the ids of fill_parts.gd.
##
## Sources: compita shrines at the crossroads (Dion. Hal. 4.14.3 on the Servian vicus shrines,
## # unverified); burial outside the city (Twelve Tables 10.1 in Cic. Leg. 2.58, read in the U3
## pass); Platner-Ashby s.v. Via Appia for the tomb-lined roads (read in the U3 pass).
class_name UrbsFillProps
extends RefCounted

const P := preload("res://scripts/urbs/fill_parts.gd")
const MB := P.MB

const TRUNK := Color(0.42, 0.30, 0.20, 0.35)
const SACK := Color(0.62, 0.52, 0.36, 0.20)
const MARBLE := Color(1, 1, 1, 0.15)


static func tree(kind: String) -> MB:
	var b := MB.new()
	match kind:
		"cypress":
			b.cone(0, 0, 0.0, 0.6, 0.18, 0.18, 5, TRUNK)
			b.cone(0, 0, 0.4, 3.4, 1.0, 0.8, 7, Color(0.16, 0.30, 0.15, 0.05))
			b.cone(0, 0, 3.4, 8.0, 0.8, 0.05, 7, Color(0.18, 0.33, 0.16, 0.05))
		"pine":
			b.cone(0, 0, 0.0, 5.5, 0.32, 0.22, 5, TRUNK)
			b.cone(0, 0, 5.2, 6.8, 1.0, 4.0, 8, Color(0.20, 0.34, 0.17, 0.05))
			b.cone(0, 0, 6.8, 7.8, 4.0, 3.2, 8, Color(0.24, 0.38, 0.19, 0.05))
			b.cone(0, 0, 7.8, 8.4, 3.2, 0.3, 8, Color(0.22, 0.36, 0.18, 0.05))
		"fruit":
			b.cone(0, 0, 0.0, 1.2, 0.18, 0.14, 5, TRUNK)
			b.cone(0, 0, 1.0, 2.4, 0.4, 1.7, 7, Color(0.36, 0.50, 0.22, 0.05))
			b.cone(0, 0, 2.4, 3.2, 1.7, 0.3, 7, Color(0.40, 0.54, 0.24, 0.05))
		_:
			b.cone(0, 0, 0.0, 2.0, 0.25, 0.2, 5, TRUNK)
			b.cone(0, 0, 1.6, 3.3, 0.6, 2.2, 8, Color(0.32, 0.47, 0.20, 0.05))
			b.cone(0, 0, 3.3, 4.6, 2.2, 0.4, 8, Color(0.36, 0.50, 0.22, 0.05))
	return b


## Small things at the foot of a wall, nominal 1 x 1 m footprint: cart, stacked amphorae, sacks, crates.
static func prop(kind: String) -> MB:
	var b := MB.new()
	match kind:
		"cart":
			b.box(Vector3(-0.55, 0.55, -1.0), Vector3(0.55, 0.7, 0.8), P.WOOD)
			for sx in [-0.6, 0.6]:
				b.box(Vector3(sx - 0.03, 0.1, -0.35), Vector3(sx + 0.03, 1.0, 0.25), P.WOOD, false)
				b.box(Vector3(sx - 0.03, 0.4, -0.65), Vector3(sx + 0.03, 0.7, -0.05), P.WOOD, false)
			b.box(Vector3(-0.5, 0.7, -1.0), Vector3(-0.44, 1.1, 0.8), P.WOOD, false)
			b.box(Vector3(0.44, 0.7, -1.0), Vector3(0.5, 1.1, 0.8), P.WOOD, false)
			b.box(Vector3(-0.05, 0.5, 0.8), Vector3(0.05, 0.55, 2.2), P.WOOD)
			for i in 3:
				P.amphora(b, -0.25 + 0.25 * float(i), 0.7, -0.4, 0.9)
		"amph":
			for i in 4:
				for j in 2:
					P.amphora(b, -0.45 + 0.3 * float(i), 0.0, -0.2 + 0.4 * float(j), 1.0)
			for i in 3:
				b.cone(-0.3 + 0.3 * float(i), 0.0, 0.8, 1.5, 0.19, 0.07, 6, P.TERRA)
		"sacks":
			for i in 3:
				b.cone(-0.5 + 0.5 * float(i), 0.0, 0.0, 0.42, 0.26, 0.3, 8, SACK)
				b.cone(-0.5 + 0.5 * float(i), 0.0, 0.42, 0.56, 0.3, 0.1, 8, SACK)
			b.cone(-0.2, 0.0, 0.56, 0.98, 0.25, 0.28, 8, SACK)
			b.cone(-0.2, 0.0, 0.98, 1.12, 0.28, 0.08, 8, SACK)
		_:
			b.box(Vector3(-0.5, 0.0, -0.4), Vector3(0.5, 0.45, 0.4), P.WOOD)
			b.box(Vector3(-0.4, 0.45, -0.3), Vector3(0.3, 0.9, 0.35), P.WOOD)
	return b


## Street furniture: a fountain of the aqueduct age (basin, pillar, bronze spout), a well-head
## (ring, two uprights and a beam), a compitum shrine (small aedicula on a plinth with an altar).
static func furn(kind: String) -> MB:
	var b := MB.new()
	match kind:
		"fountain":
			b.box(Vector3(-0.9, 0.0, -0.4), Vector3(0.9, 0.9, 0.4), P.STONE)
			b.box(Vector3(-0.7, 0.88, -0.25), Vector3(0.7, 0.9, 0.25), P.WATER, true, false)
			b.box(Vector3(-0.3, 0.9, -0.4), Vector3(0.3, 1.9, -0.1), P.STONE)
			b.box(Vector3(-0.08, 1.2, -0.1), Vector3(0.08, 1.3, 0.1), P.BRONZE)
			b.box(Vector3(-1.0, 1.9, -0.5), Vector3(1.0, 2.05, 0.3), P.STONE)
		"well":
			b.cone(0, 0, 0.0, 0.9, 0.7, 0.62, 8, P.STONE)
			b.quad(Vector3(-0.4, 0.88, 0.4), Vector3(0.4, 0.88, 0.4), Vector3(0.4, 0.88, -0.4), Vector3(-0.4, 0.88, -0.4), P.SHADE, Vector3(0, 1, 0))
			for sx in [-0.7, 0.7]:
				b.box(Vector3(sx - 0.06, 0.8, -0.06), Vector3(sx + 0.06, 2.0, 0.06), P.WOOD, false)
			b.box(Vector3(-0.8, 1.9, -0.05), Vector3(0.8, 2.0, 0.05), P.WOOD)
		_:
			b.box(Vector3(-1.1, 0.0, -1.0), Vector3(1.1, 0.5, 1.0), P.STONE)
			for sx in [-0.7, 0.7]:
				b.box(Vector3(sx - 0.12, 0.5, -0.5), Vector3(sx + 0.12, 2.3, -0.2), P.STONE, false)
			b.shed(-1.0, 1.0, -0.2, -0.75, 2.6, 2.3, P.TILE, 1)
			b.box(Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 1.6, -0.2), P.SHADE)   # the niche of the Lares
			b.box(Vector3(-0.3, 0.5, 0.2), Vector3(0.3, 1.05, 0.6), P.STONE)  # altar
	return b


## Roadside tombs, nominal sizes: altar 3 x 3, columbarium 5 x 5, round 8 x 8, tumulus 9 x 9,
## stele 1 x 0.5.
static func tomb(kind: String, lod: int) -> MB:
	var b := MB.new()
	match kind:
		"altar":
			b.box(Vector3(-1.5, -1.0, -1.5), Vector3(1.5, 0.5, 1.5), P.PLINTH)
			b.box(Vector3(-1.2, 0.5, -1.2), Vector3(1.2, 1.9, 1.2), MARBLE)
			b.box(Vector3(-1.45, 1.9, -1.45), Vector3(1.45, 2.3, 1.45), P.STONE)
			b.rect_on(0, -0.8, 0.8, 0.9, 1.6, 3.0, 3.0, 0.62, P.SIGN)
		"columbarium":
			P.walls(b, 5.0, 5.0, 3.4, [[P.door_hole(0.0, 1.2, 2.2)], [], [], []], P.PLASTER, lod)
			P.door(b, 0, 0.0, 1.2, 2.2, 5.0, 5.0, lod, 71)
			b.gable(-2.8, 2.8, -2.8, 2.8, 3.4, P.rise(2.8), P.TILE, P.PLASTER, lod)
			if lod < 2:
				for i in 3:
					for j in 2:
						b.rect_on(2, -1.6 + 1.6 * float(i) - 0.35, -1.6 + 1.6 * float(i) + 0.35, 1.0 + 1.0 * float(j), 1.5 + 1.0 * float(j), 5.0, 5.0, 0.03, P.LATTICE)
		"round":
			b.cone(0, 0, -1.0, 1.5, 4.0, 3.9, 10, P.PLINTH)
			b.cone(0, 0, 1.5, 5.0, 3.8, 3.6, 10, MARBLE)
			b.cone(0, 0, 5.0, 5.4, 3.9, 3.9, 10, P.STONE)
			b.cone(0, 0, 5.4, 7.2, 3.0, 0.1, 10, Color(0.40, 0.46, 0.25, 0.05))
		"tumulus":
			b.cone(0, 0, -0.5, 0.2, 4.5, 4.3, 12, P.PLINTH)
			b.cone(0, 0, 0.2, 3.2, 4.3, 0.2, 12, Color(0.40, 0.48, 0.26, 0.05))
		_:
			b.box(Vector3(-0.5, -0.5, -0.25), Vector3(0.5, 2.0, 0.25), MARBLE)
	return b


## Things standing on farm parcels (nominal 44 x 44 m): vineyard rows, kitchen-garden beds, a
## farm steading.
static func rural(kind: String, lod: int) -> MB:
	var b := MB.new()
	var leaf := Color(0.26, 0.42, 0.18, 0.05)
	match kind:
		"vines":
			var rows := 9 if lod == 0 else 4
			for i in rows:
				var x := -18.0 + 36.0 * float(i) / float(rows - 1)
				b.box(Vector3(x - 0.3, 0.0, -18.0), Vector3(x + 0.3, 1.35, 18.0), leaf)
				if lod == 0:
					for j in 7:
						var z := -17.0 + 34.0 * float(j) / 6.0
						b.box(Vector3(x - 0.04, 0.0, z - 0.04), Vector3(x + 0.04, 1.9, z + 0.04), P.WOOD, false)
		"beds":
			for i in 4:
				for j in 3:
					var x0 := -17.0 + 9.0 * float(i)
					var z0 := -15.0 + 10.5 * float(j)
					var g := Color(0.32 + 0.1 * float((i + j) % 2), 0.48, 0.2, 0.05)
					b.box(Vector3(x0, 0.0, z0), Vector3(x0 + 7.5, 0.28, z0 + 8.0), g)
			var shed := MB.new()
			P.walls(shed, 4.0, 4.0, 2.6, [[P.door_hole(0.0, 1.0, 2.0)], [], [], []], P.PLASTER, lod)
			P.door(shed, 0, 0.0, 1.0, 2.0, 4.0, 4.0, lod, 72)
			shed.gable(-2.4, 2.4, -2.4, 2.4, 2.6, P.rise(2.4), P.TILE, P.PLASTER, lod)
			b.append(shed, Vector3(17.0, 0.0, 17.0))
		"farm":
			var house := MB.new()
			P.walls(house, 12.0, 9.0, 3.4, [[P.door_hole(0.0, 1.4, 2.2)], [], [], []], P.PLASTER, lod)
			P.door(house, 0, 0.0, 1.4, 2.2, 12.0, 9.0, lod, 73)
			house.gable(-6.6, 6.6, -5.0, 5.0, 3.4, P.rise(5.0), P.TILE, P.PLASTER, lod)
			if lod < 2:
				P.window_flat(house, 0, 3.0, 1.2, 1.0, 1.0, 12.0, 9.0, 74)
				P.window_flat(house, 0, -3.0, 1.2, 1.0, 1.0, 12.0, 9.0, 75)
			b.append(house, Vector3(-4.0, 0.0, -10.0))
			var barn := MB.new()
			P.walls(barn, 14.0, 9.0, 4.2, [[Rect2(-2.0, 0.0, 4.0, 3.4)], [], [], []], P.WOOD, lod)
			barn.rect_on(0, -2.0, 2.0, 0.0, 3.4, 14.0, 9.0, -0.3, P.SHADE)
			barn.gable(-7.6, 7.6, -5.0, 5.0, 4.2, P.rise(5.0, 30.0), P.SHINGLE, P.WOOD, 2)
			b.append(barn, Vector3(-3.0, 0.0, 10.0))
			for s in [Vector2(14.0, 10.0), Vector2(15.5, 4.0)]:
				b.cone(s.x, s.y, 0.0, 2.2, 1.9, 1.4, 8, P.THATCH)
				b.cone(s.x, s.y, 2.2, 3.4, 1.4, 0.1, 8, P.THATCH)
			b.box(Vector3(12.0, 0.0, -14.0), Vector3(15.0, 1.0, -10.5), P.WOOD)   # woodpile
			if lod == 0:
				P.amphora(b, 3.5, 0.0, -5.0, 1.3)
	return b
