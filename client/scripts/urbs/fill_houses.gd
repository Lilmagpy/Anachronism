## Urbs (U8 houses): the ordinary buildings of Republican Rome, assembled from fill_parts.gd.
## Every builder returns an UrbsFillParts.MB at the detail `lod` (0 full, 1 flat openings and no
## small parts, 2 walls and roof only). Nominal footprints are in fill_meshes.gd's key list;
## fill.gd scales instances in x and z to the lot.
##
## Sources (read unless marked):
##   Vitruvius 2.8.17 (Perseus, Morgan): "the nature of the case has made it necessary to find
##     relief by making the buildings high ... walls of burnt brick, and partitions of rubble work,
##     and provided with floor after floor" -> insulae of three to five storeys over shops.
##   Strabo 5.3.7 (Perseus, Hamilton-Falconer): Augustus limited new buildings on the public
##     streets to seventy feet (about 20.7 m); the sales, collapses and fires of houses.
##     Nothing here exceeds five storeys (about 16 m).
##   Livy 21.62.3: an ox climbed to the third storey of a house in the Forum Boarium (218 BC):
##     # unverified (cited in fill.gd's header by the previous pass).
##   Vitruvius 6.3 (Perseus, Morgan): the atrium house; the five kinds of atrium, the compluvium
##     "between a quarter and a third of the atrium's width", alae, tablinum, fauces; peristyles
##     "one third longer than they are deep", columns as high as the colonnade is wide.
##   Vitruvius 6.5 (Perseus, Morgan): men of everyday fortune need no grand atria; traders "must
##     have stalls and shops in their entrance courts"; men of rank "lofty entrance courts in regal
##     style, and most spacious atriums and peristyles". The Pompeian atrium houses (Casa del
##     Chirurgo, Casa di Sallustio, Casa del Fauno) are the surviving evidence for the plan: a blank
##     street wall, a tall door, tabernae either side, the roof falling inward to the compluvium,
##     the peristyle garden behind in the richer houses.
##   Pliny NH 16.15 (Wikisource, Rackham): "Rome was roofed with shingles right down to the war
##     with Pyrrhus, a period of 470 years" -> shingle and thatch roofs on the casae before 280 BC.
##   Platner-Ashby s.v. Horrea: # unverified (LacusCurtius unreachable this session); the Emporium
##     and the first horrea by the river from 193 BC: Livy 35.10.12, # unverified (population.yaml).
##   Fullonicae: the Pompeian fullonica of Stephanus (vats, treading stalls, drying frames) is the
##     model; no Republican text describes one.
class_name UrbsFillHouses
extends RefCounted

const P := preload("res://scripts/urbs/fill_parts.gd")
const MB := P.MB


# ---------------------------------------------------------------- insula

## Tenement block, nominal 18 x 18 m (narrow: 7 x 18). shape gable|hip|stepped; feature 0 balconies
## and shutters, 1 balconies with washing lines, 2 shop awnings and a jettied upper storey; pitch 0
## 20 degrees, 1 25 degrees.
static func insula(shape: String, storeys: int, feature: int, pitch: int, lod: int, narrow := false) -> MB:
	var w := 7.0 if narrow else 18.0
	var d := 18.0
	var gf := 3.7
	var sh := 3.0
	var h := gf + sh * float(storeys - 1)
	var deg := 20.0 if pitch == 0 else 25.0
	var b := MB.new()
	var md := d
	var mz := 0.0
	var seed := storeys * 7 + feature * 3 + pitch + (100 if narrow else 0) + (shape.length() * 13)
	if shape == "stepped":
		# a lower annex at the back under its own lean-to roof
		var annex_h := maxf(gf, h - sh)
		var an := MB.new()
		P.walls(an, w, 6.0, annex_h, [[], [P.door_hole(0.0, 1.1, 2.2)], [], []], P.PLASTER, lod)
		P.door(an, 1, 0.0, 1.1, 2.2, w, 6.0, lod, seed + 1)
		if lod < 2:
			for i in (1 if narrow else 3):
				var hh := -5.0 + 5.0 * float(i) if not narrow else 0.0
				P.window_flat(an, 1, hh, annex_h - 1.9, 0.9, 1.2, w, 6.0, seed + 40 + i)
		an.shed(-w * 0.5 - 0.4, w * 0.5 + 0.4, 3.0, -3.5, annex_h + P.rise(6.5, deg), annex_h, P.TILE, lod)
		b.append(an, Vector3(0, 0, -d * 0.5 + 3.0))
		md = d - 6.0
		mz = 3.0
	var m := MB.new()
	# openings of the front: shops below, windows above
	var shops: Array = [-1.75, 1.75] if narrow else [-6.75, -2.25, 2.25, 6.75]
	var shop_w := 2.9 if narrow else 2.6
	var front_holes: Array = []
	var back_holes: Array = []
	for i in shops.size():
		front_holes.append(P.shop_hole(shops[i], shop_w))
	var win_h: Array[float] = []
	for i in (2 if narrow else 5):
		win_h.append((-1.75 + 3.5 * float(i)) if narrow else (-7.2 + 3.6 * float(i)))
	if lod == 0:
		for s in range(1, storeys):
			var y0 := gf + sh * float(s - 1) + 0.9
			for i in win_h.size():
				front_holes.append(P.window_hole(win_h[i], y0, 1.1, 1.4))
	back_holes.append(P.door_hole(0.0, 1.1, 2.3))
	P.walls(m, w, md, h, [front_holes, back_holes, [], []], P.PLASTER, lod)
	for i in shops.size():
		var awn := i if (feature == 2 or (feature == 0 and i % 2 == 1)) else -1
		P.shop_front(m, 0, shops[i], shop_w, w, md, lod, seed * 5 + i, awn, true)
	P.door(m, 1, 0.0, 1.1, 2.3, w, md, lod, seed + 2)
	if lod < 2 and not narrow:
		P.window_flat(m, 1, -5.5, 1.5, 1.0, 1.1, w, md, seed + 3)
		P.window_flat(m, 1, 5.5, 1.5, 1.0, 1.1, w, md, seed + 4)
	for s in range(1, storeys):
		var y0 := gf + sh * float(s - 1)
		if lod < 2:
			P.string_course(m, 0, y0, w, md)
			for i in win_h.size():
				if lod == 0:
					P.window(m, 0, win_h[i], y0 + 0.9, 1.1, 1.4, w, md, 0, seed * 11 + s * 11 + i)
				else:
					P.window(m, 0, win_h[i], y0 + 0.9, 1.1, 1.4, w, md, 1, seed * 11 + s * 11 + i)
				P.window_flat(m, 1, win_h[i], y0 + 1.0, 1.0, 1.2, w, md, seed * 13 + s * 13 + i)
			var n_side := 1 if md < 10.0 else 3
			for i in n_side:
				var zz := -md * 0.5 + md * (float(i) + 0.5) / float(n_side)
				P.window_flat(m, 2, zz, y0 + 1.0, 1.0, 1.2, w, md, seed * 17 + s * 17 + i)
				if not narrow:
					P.window_flat(m, 3, zz, y0 + 1.0, 1.0, 1.2, w, md, seed * 19 + s * 19 + i)
		# timber galleries (maeniana) with railings on the street face
		if lod == 0 and s >= 2 and (feature != 1 or s % 2 == 0):
			var full := feature == 2
			var xs: Array = [-6.5, 0.0, 6.5] if full else [-4.2 if s % 2 == 0 else 3.6]
			var hw := 2.3 if full else 2.0
			if narrow:
				xs = [0.0]
				hw = 2.9
			for bx: float in xs:
				P.balcony(m, 0, bx, hw, y0 + 0.08, w, md, seed * 23 + s * 7 + int(bx), feature == 1 or (feature == 0 and s % 2 == 1), s == storeys - 1 and feature == 1)
		elif lod == 1 and s >= 2 and feature != 1 and not narrow:
			m.on_wall(0, -4.2 if s % 2 == 0 else 3.6, y0 + 0.08, 4.0, 0.14, 1.1, w, md, 0.0, P.WOOD)
	# an outside stair to the first floor on the right flank
	if lod < 2 and not narrow and storeys >= 3 and P.fr(seed, 8) < 0.55:
		P.stair(m, 2, -md * 0.5 + 1.0, gf, w, md, lod, seed + 9)
	# upper storey projecting on brackets (feature 2)
	if feature == 2 and lod < 2:
		var top_y := gf + sh * float(storeys - 2)
		m.box(Vector3(-w * 0.5 - 0.1, top_y + 0.2, md * 0.5), Vector3(w * 0.5 + 0.1, top_y + sh, md * 0.5 + 0.6), P.PLASTER, false, true)
		for i in range(1, 5):
			var bx := -w * 0.5 + w * float(i) / 5.0
			m.box(Vector3(bx - 0.1, top_y - 0.5, md * 0.5), Vector3(bx + 0.1, top_y + 0.2, md * 0.5 + 0.55), P.WOOD, false, true)
	b.append(m, Vector3(0, 0, mz))
	var ov := 0.55
	var jetty := 0.6 if feature == 2 else 0.0
	var roof := MB.new()
	var rh := P.rise(md * 0.5 + ov, deg)
	if shape == "hip":
		roof.hip(-w * 0.5 - ov, w * 0.5 + ov, -md * 0.5 - ov, md * 0.5 + ov + jetty, h, rh, P.TILE, lod)
	else:
		roof.gable(-w * 0.5 - ov, w * 0.5 + ov, -md * 0.5 - ov, md * 0.5 + ov + jetty, h, rh, P.TILE, P.PLASTER, lod)
	# the kitchens' smoke holes on the back slope
	if lod == 0:
		var zs := -md * 0.25
		var ys := h + rh * 0.5 + 0.1
		P.smoke_hood(roof, -w * 0.25, ys, zs, lod)
		if not narrow:
			P.smoke_hood(roof, w * 0.3, ys, zs, lod)
	b.append(roof, Vector3(0, 0, mz))
	return b


# ---------------------------------------------------------------- domus

## Atrium house of the Republican type, nominal 20 x 34 m, the street at +z: a blank front wall with
## the tall door (fauces) in the middle and a taberna either side; the atrium roof falls inward to
## the compluvium over the impluvium; the tablinum; the peristyle garden with its colonnade behind.
static func domus(lod: int) -> MB:
	var w := 20.0
	var d := 34.0
	var b := MB.new()
	var hx := w * 0.5
	var hz := d * 0.5
	# the atrium block: z from 3.0 to 17.0, walls 6.8 m
	var az0 := 3.0
	var h0 := 6.8
	var front_holes: Array = [P.door_hole(0.0, 1.8, 3.4), P.shop_hole(-5.4, 2.6), P.shop_hole(5.4, 2.6)]
	# front
	b.rect_on(0, -hx, hx, -P.SKIRT, 0.0, w, d, 0.0, P.PLINTH)
	b.face_with_holes(0, -hx, hx, 0.0, h0, w, d, front_holes if lod == 0 else [], P.PLASTER)
	P.door(b, 0, 0.0, 1.8, 3.4, w, d, lod, 31, true)
	P.shop_front(b, 0, -5.4, 2.6, w, d, lod, 32, 3 if lod == 0 else -1, true)
	P.shop_front(b, 0, 5.4, 2.6, w, d, lod, 33, -1, true)
	if lod < 2:
		for sx in [-8.2, -2.6, 2.6, 8.2]:
			P.window_flat(b, 0, sx, 4.6, 0.8, 0.9, w, d, 34 + int(sx))
	# flanks and back: tall blank walls, the back part lower (peristyle wing 5.6 m)
	var h1 := 5.6
	for face in [2, 3]:
		b.rect_on(face, -hz, hz, -P.SKIRT, 0.0, w, d, 0.0, P.PLINTH)
		b.rect_on(face, az0, hz, 0.0, h0, w, d, 0.0, P.PLASTER)
		b.rect_on(face, -hz, az0, 0.0, h1, w, d, 0.0, P.PLASTER)
		if lod < 2:
			for i in 3:
				P.window_flat(b, face, 5.0 + 4.0 * float(i), 4.8, 0.8, 0.9, w, d, 40 + face * 5 + i)
			for i in 4:
				P.window_flat(b, face, -14.0 + 4.0 * float(i), 3.6, 0.8, 0.9, w, d, 50 + face * 5 + i)
	b.rect_on(1, -hx, hx, -P.SKIRT, 0.0, w, d, 0.0, P.PLINTH)
	b.face_with_holes(1, -hx, hx, 0.0, h1, w, d, [P.door_hole(6.0, 1.2, 2.3)] if lod == 0 else [], P.PLASTER)
	P.door(b, 1, 6.0, 1.2, 2.3, w, d, lod, 36)
	# the step between the two heights, on the flanks' line
	b.quad(Vector3(-hx, h1, az0), Vector3(hx, h1, az0), Vector3(hx, h0, az0), Vector3(-hx, h0, az0), P.PLASTER, Vector3(0, 0, -1))
	# atrium roof: four slopes falling inward to the compluvium (inset 4.8 m, opening 10.4 x 3.4)
	var ins := 4.8
	var ix0 := -hx + ins
	var ix1 := hx - ins
	var iz0 := az0 + ins
	var iz1 := hz - ins
	var hi := h0 - P.rise(ins)
	var up := Vector3(0, 1, 0)
	var ov := 0.5
	b.quad(Vector3(-hx - ov, h0 + 0.2, hz + ov), Vector3(hx + ov, h0 + 0.2, hz + ov), Vector3(ix1, hi, iz1), Vector3(ix0, hi, iz1), P.TILE, up)
	b.quad(Vector3(hx + ov, h0 + 0.2, az0), Vector3(-hx - ov, h0 + 0.2, az0), Vector3(ix0, hi, iz0), Vector3(ix1, hi, iz0), P.TILE, up)
	b.quad(Vector3(-hx - ov, h0 + 0.2, az0), Vector3(-hx - ov, h0 + 0.2, hz + ov), Vector3(ix0, hi, iz1), Vector3(ix0, hi, iz0), P.TILE, up)
	b.quad(Vector3(hx + ov, h0 + 0.2, hz + ov), Vector3(hx + ov, h0 + 0.2, az0), Vector3(ix1, hi, iz0), Vector3(ix1, hi, iz1), P.TILE, up)
	if lod < 2:
		# hips from the outer corners to the compluvium corners, the compluvium rim, eaves
		b.ridge(Vector3(-hx - ov, h0 + 0.2, hz + ov), Vector3(ix0, hi, iz1), 0.16)
		b.ridge(Vector3(hx + ov, h0 + 0.2, hz + ov), Vector3(ix1, hi, iz1), 0.16)
		b.ridge(Vector3(-hx - ov, h0 + 0.2, az0), Vector3(ix0, hi, iz0), 0.16)
		b.ridge(Vector3(hx + ov, h0 + 0.2, az0), Vector3(ix1, hi, iz0), 0.16)
		b.box(Vector3(ix0 - 0.3, hi - 0.1, iz0 - 0.3), Vector3(ix1 + 0.3, hi + 0.2, iz0), P.STONE)
		b.box(Vector3(ix0 - 0.3, hi - 0.1, iz1), Vector3(ix1 + 0.3, hi + 0.2, iz1 + 0.3), P.STONE)
		b.box(Vector3(ix0 - 0.3, hi - 0.1, iz0), Vector3(ix0, hi + 0.2, iz1), P.STONE)
		b.box(Vector3(ix1, hi - 0.1, iz0), Vector3(ix1 + 0.3, hi + 0.2, iz1), P.STONE)
		b.fascia(Vector3(-hx - ov, h0 + 0.2, hz + ov), Vector3(hx + ov, h0 + 0.2, hz + ov), Vector3(0, 0, 1))
		b.fascia(Vector3(hx + ov, h0 + 0.2, az0), Vector3(hx + ov, h0 + 0.2, hz + ov), Vector3(1, 0, 0))
		b.fascia(Vector3(-hx - ov, h0 + 0.2, az0), Vector3(-hx - ov, h0 + 0.2, hz + ov), Vector3(-1, 0, 0))
	if lod == 0:
		var sl := P.rise(ins) / ins
		b.antefixes(Vector3(-hx - ov, h0 + 0.2, hz + ov), Vector3(hx + ov, h0 + 0.2, hz + ov), Vector3(0, 0, 1), sl)
		b.antefixes(Vector3(hx + ov, h0 + 0.2, az0), Vector3(hx + ov, h0 + 0.2, hz + ov), Vector3(1, 0, 0), sl)
		b.antefixes(Vector3(-hx - ov, h0 + 0.2, az0), Vector3(-hx - ov, h0 + 0.2, hz + ov), Vector3(-1, 0, 0), sl)
	# the atrium floor seen through the compluvium: impluvium basin
	b.quad(Vector3(ix0 - 1.0, 0.3, iz1 + 1.0), Vector3(ix1 + 1.0, 0.3, iz1 + 1.0), Vector3(ix1 + 1.0, 0.3, iz0 - 1.0), Vector3(ix0 - 1.0, 0.3, iz0 - 1.0), P.STONE, up)
	b.quad(Vector3(ix0 + 0.4, 0.5, iz1 - 0.4), Vector3(ix1 - 0.4, 0.5, iz1 - 0.4), Vector3(ix1 - 0.4, 0.5, iz0 + 0.4), Vector3(ix0 + 0.4, 0.5, iz0 + 0.4), P.WATER, up)
	# the peristyle wing: z from -17 to 3; colonnade roofs fall inward to the garden
	var gx0 := -6.8
	var gx1 := 6.8
	var gz0 := -13.8
	var gz1 := -3.0
	var hl := h1 - P.rise(hx - gx1)
	b.quad(Vector3(-hx - ov, h1 + 0.2, az0), Vector3(hx + ov, h1 + 0.2, az0), Vector3(gx1, hl, gz1), Vector3(gx0, hl, gz1), P.TILE, up)
	b.quad(Vector3(hx + ov, h1 + 0.2, -hz - ov), Vector3(-hx - ov, h1 + 0.2, -hz - ov), Vector3(gx0, hl, gz0), Vector3(gx1, hl, gz0), P.TILE, up)
	b.quad(Vector3(-hx - ov, h1 + 0.2, -hz - ov), Vector3(-hx - ov, h1 + 0.2, az0), Vector3(gx0, hl, gz1), Vector3(gx0, hl, gz0), P.TILE, up)
	b.quad(Vector3(hx + ov, h1 + 0.2, az0), Vector3(hx + ov, h1 + 0.2, -hz - ov), Vector3(gx1, hl, gz0), Vector3(gx1, hl, gz1), P.TILE, up)
	if lod < 2:
		b.ridge(Vector3(-hx - ov, h1 + 0.2, -hz - ov), Vector3(gx0, hl, gz0), 0.16)
		b.ridge(Vector3(hx + ov, h1 + 0.2, -hz - ov), Vector3(gx1, hl, gz0), 0.16)
		b.fascia(Vector3(-hx - ov, h1 + 0.2, -hz - ov), Vector3(hx + ov, h1 + 0.2, -hz - ov), Vector3(0, 0, -1))
		b.fascia(Vector3(hx + ov, h1 + 0.2, -hz - ov), Vector3(hx + ov, h1 + 0.2, az0), Vector3(1, 0, 0))
		b.fascia(Vector3(-hx - ov, h1 + 0.2, -hz - ov), Vector3(-hx - ov, h1 + 0.2, az0), Vector3(-1, 0, 0))
		# inner eave of the colonnade: fascia and antefixes over the garden
		b.fascia(Vector3(gx0, hl, gz1), Vector3(gx1, hl, gz1), Vector3(0, 0, -1))
		b.fascia(Vector3(gx0, hl, gz0), Vector3(gx1, hl, gz0), Vector3(0, 0, 1))
		b.fascia(Vector3(gx0, hl, gz0), Vector3(gx0, hl, gz1), Vector3(1, 0, 0))
		b.fascia(Vector3(gx1, hl, gz0), Vector3(gx1, hl, gz1), Vector3(-1, 0, 0))
	if lod == 0:
		var sl2 := P.rise(hx - gx1) / (hx - gx1)
		b.antefixes(Vector3(-hx - ov, h1 + 0.2, -hz - ov), Vector3(hx + ov, h1 + 0.2, -hz - ov), Vector3(0, 0, -1), sl2)
		b.antefixes(Vector3(hx + ov, h1 + 0.2, -hz - ov), Vector3(hx + ov, h1 + 0.2, az0), Vector3(1, 0, 0), sl2)
		b.antefixes(Vector3(-hx - ov, h1 + 0.2, -hz - ov), Vector3(-hx - ov, h1 + 0.2, az0), Vector3(-1, 0, 0), sl2)
	# garden: beds, a long basin, the colonnade's columns on a low stylobate
	b.quad(Vector3(gx0, 0.3, gz1), Vector3(gx1, 0.3, gz1), Vector3(gx1, 0.3, gz0), Vector3(gx0, 0.3, gz0), P.LEAF, up)
	b.box(Vector3(gx0 - 0.4, 0.0, gz0 - 0.4), Vector3(gx1 + 0.4, 0.4, gz1 + 0.4), P.STONE, false)
	b.quad(Vector3(-1.6, 0.45, -6.0), Vector3(1.6, 0.45, -6.0), Vector3(1.6, 0.45, -11.4), Vector3(-1.6, 0.45, -11.4), P.WATER, up)
	if lod < 2:
		var col_h := hl - 0.45
		var nx := 6
		for i in nx:
			var x := gx0 + (gx1 - gx0) * float(i) / float(nx - 1)
			b.cone(x, gz1, 0.4, col_h, 0.24, 0.2, 8, P.STONE)
			b.cone(x, gz0, 0.4, col_h, 0.24, 0.2, 8, P.STONE)
		for j in range(1, 4):
			var z := gz0 + (gz1 - gz0) * float(j) / 4.0
			b.cone(gx0, z, 0.4, col_h, 0.24, 0.2, 8, P.STONE)
			b.cone(gx1, z, 0.4, col_h, 0.24, 0.2, 8, P.STONE)
		# architrave over the columns
		b.box(Vector3(gx0 - 0.3, col_h, gz0 - 0.3), Vector3(gx1 + 0.3, hl, gz0 + 0.3), P.WOOD)
		b.box(Vector3(gx0 - 0.3, col_h, gz1 - 0.3), Vector3(gx1 + 0.3, hl, gz1 + 0.3), P.WOOD)
		b.box(Vector3(gx0 - 0.3, col_h, gz0), Vector3(gx0 + 0.3, hl, gz1), P.WOOD)
		b.box(Vector3(gx1 - 0.3, col_h, gz0), Vector3(gx1 + 0.3, hl, gz1), P.WOOD)
		# two small trees and clipped box in the garden
		for t in [Vector2(-4.4, -8.6), Vector2(4.4, -8.6)]:
			b.cone(t.x, t.y, 0.4, 1.6, 0.12, 0.1, 5, P.WOOD)
			b.cone(t.x, t.y, 1.4, 2.6, 0.5, 1.5, 7, P.LEAF)
			b.cone(t.x, t.y, 2.6, 3.4, 1.5, 0.2, 7, P.LEAF)
		for s in [Vector2(-4.6, -4.6), Vector2(4.6, -4.6), Vector2(-4.6, -12.4), Vector2(4.6, -12.4)]:
			b.box(Vector3(s.x - 0.6, 0.3, s.y - 0.6), Vector3(s.x + 0.6, 1.1, s.y + 0.6), P.LEAF)
	return b


# ---------------------------------------------------------------- casa

## Small one-storey house, nominal 8 x 9 m: a door, a shuttered window, a gable roof of tiles,
## shingles or thatch (Pliny NH 16.15: shingles until Pyrrhus), a jar and firewood by the wall.
static func casa(roof_kind: String, lod: int) -> MB:
	var w := 8.0
	var d := 9.0
	var h := 2.9
	var col := P.TILE
	var deg := P.PITCH_DEG
	if roof_kind == "thatch":
		col = P.THATCH
		deg = 40.0
	elif roof_kind == "shingle":
		col = P.SHINGLE
		deg = 30.0
	var b := MB.new()
	var holes: Array = [P.door_hole(-0.6, 1.0, 2.1)]
	if lod == 0:
		holes.append(P.window_hole(2.1, 1.2, 0.9, 0.9))
	P.walls(b, w, d, h, [holes, [], [], []], P.PLASTER, lod)
	P.door(b, 0, -0.6, 1.0, 2.1, w, d, lod, 51)
	if lod == 0:
		P.window(b, 0, 2.1, 1.2, 0.9, 0.9, w, d, 0, 52)
		P.window_flat(b, 2, -1.0, 1.3, 0.8, 0.8, w, d, 53)
		P.amphora(b, -2.6, 0.0, d * 0.5 + 0.4, 0.9)
		b.box(Vector3(-w * 0.5 - 0.5, 0.0, -2.0), Vector3(-w * 0.5, 0.8, 0.5), P.WOOD)
	elif lod == 1:
		P.window_flat(b, 0, 2.1, 1.2, 0.9, 0.9, w, d, 52)
	var roof := MB.new()
	var rh := P.rise(d * 0.5 + 0.5, deg)
	if col == P.TILE:
		roof.gable(-w * 0.5 - 0.5, w * 0.5 + 0.5, -d * 0.5 - 0.5, d * 0.5 + 0.6, h, rh, col, P.PLASTER, lod)
		if lod == 0:
			P.smoke_hood(roof, 1.5, h + rh * 0.55, -d * 0.25, lod)
	else:
		roof.gable(-w * 0.5 - 0.6, w * 0.5 + 0.6, -d * 0.5 - 0.6, d * 0.5 + 0.7, h, rh, col, P.PLASTER, 2)
		if lod < 2:
			var zm := 0.05
			roof.box(Vector3(-w * 0.5 - 0.6, h + rh - 0.1, -0.25), Vector3(w * 0.5 + 0.6, h + rh + 0.15, 0.25), col if col == P.SHINGLE else P.WOOD)
			if col == P.THATCH:
				for i in 4:
					var x := -w * 0.5 + 1.0 + float(i) * 2.0
					roof.box(Vector3(x - 0.06, h + rh - 0.6, -1.2 + zm), Vector3(x + 0.06, h + rh + 0.25, 1.2 + zm), P.WOOD, true, false)
	b.append(roof, Vector3.ZERO)
	return b


# ---------------------------------------------------------------- taberna

## Shop-front unit, nominal 4.6 x 5.2 m, a lean-to against the house behind. 0-3: one storey with
## awnings of different cloth; 4: two storeys with a balcony (the shopkeeper's pergula above);
## 5: open front with a long counter and goods.
static func taberna(variant: int, lod: int) -> MB:
	var w := 4.6
	var d := 5.2
	var h := 3.6 if variant != 4 else 6.4
	var b := MB.new()
	var holes: Array = [P.shop_hole(0.0, 3.2)]
	if variant == 4 and lod == 0:
		holes.append(P.window_hole(0.0, 4.4, 1.2, 1.3))
	P.walls(b, w, d, h, [holes, [], [], []], P.PLASTER, lod)
	P.shop_front(b, 0, 0.0, 3.2, w, d, lod, variant * 3 + 1, variant if variant < 4 else -1, variant != 5)
	if variant == 4 and lod < 2:
		if lod == 0:
			P.window(b, 0, 0.0, 4.4, 1.2, 1.3, w, d, 0, 77)
			P.balcony(b, 0, 0.0, 1.9, 3.75, w, d, 78, true, false)
		else:
			P.window_flat(b, 0, 0.0, 4.4, 1.2, 1.3, w, d, 77)
	if variant == 5 and lod == 0:
		b.box(Vector3(-w * 0.5 + 0.5, 0.0, d * 0.5 - 0.1), Vector3(w * 0.5 - 0.5, 1.0, d * 0.5 + 0.55), P.STONE)
		for i in 5:
			P.amphora(b, -1.6 + 0.8 * float(i), 1.0, d * 0.5 + 0.2, 0.7)
		for i in 3:
			P.amphora(b, w * 0.5 + 0.35, 0.0, d * 0.5 - 0.6 - 0.6 * float(i), 1.0)
	var rh := P.rise(d + 0.7)
	b.shed(-w * 0.5 - 0.2, w * 0.5 + 0.2, -d * 0.5 - 0.3, d * 0.5 + 0.4, h + rh, h, P.TILE, lod)
	b.tri(Vector3(w * 0.5, h, d * 0.5), Vector3(w * 0.5, h, -d * 0.5), Vector3(w * 0.5, h + rh, -d * 0.5), P.PLASTER, Vector3(1, 0, 0))
	b.tri(Vector3(-w * 0.5, h, -d * 0.5), Vector3(-w * 0.5, h, d * 0.5), Vector3(-w * 0.5, h + rh, -d * 0.5), P.PLASTER, Vector3(-1, 0, 0))
	return b


# ---------------------------------------------------------------- workshop

## Craft yard, nominal 16 x 14 m: a gabled hall at the back with two wide doors, a walled yard in
## front with a gate. 0 potter (kiln and rows of amphorae), 1 carpenter (timber stacks, a dolium),
## 2 fullonica (treading vats and drying frames in the yard).
static func workshop(variant: int, lod: int) -> MB:
	var w := 16.0
	var d := 14.0
	var h := 5.0
	var b := MB.new()
	var hd := 9.0
	var hz := -d * 0.5 + hd * 0.5
	var hall := MB.new()
	var holes: Array = [Rect2(-4.8, 0.0, 3.4, 3.4), Rect2(1.4, 0.0, 3.4, 3.4)]
	P.walls(hall, w, hd, h, [holes, [], [], []], P.PLASTER, lod)
	for hh in [-3.1, 3.1]:
		if lod == 0:
			hall.reveal(0, hh - 1.7, hh + 1.7, 0.0, 3.4, w, hd, 0.5, P.PLASTER, P.SHADE, 0.5)
			hall.rect_on(0, hh - 1.7, hh - 0.2, 0.02, 3.38, w, hd, -0.42, P.DOOR)   # one leaf open
		else:
			hall.rect_on(0, hh - 1.7, hh + 1.7, 0.0, 3.4, w, hd, 0.02, P.SHADE)
		if lod < 2:
			hall.on_wall(0, hh, 3.4, 3.7, 0.3, 0.12, w, hd, 0.0, P.WOOD)
			hall.on_wall(0, hh, 0.0, 3.9, 0.14, 0.4, w, hd, 0.0, P.STONE)
	if lod < 2:
		for i in 2:
			P.window_flat(hall, 2, -2.0 + 4.0 * float(i), 3.0, 0.9, 0.9, w, hd, 61 + i)
			P.window_flat(hall, 3, -2.0 + 4.0 * float(i), 3.0, 0.9, 0.9, w, hd, 63 + i)
	hall.gable(-w * 0.5 - 0.6, w * 0.5 + 0.6, -hd * 0.5 - 0.6, hd * 0.5 + 0.6, h, P.rise(hd * 0.5 + 0.6), P.TILE, P.PLASTER, lod)
	if lod == 0:
		P.smoke_hood(hall, -w * 0.3, h + P.rise(hd * 0.5 + 0.6) * 0.5, -hd * 0.25, lod)
	b.append(hall, Vector3(0, 0, hz))
	# the yard wall with a gate
	var yz0 := -d * 0.5 + hd
	b.box(Vector3(-w * 0.5, -P.SKIRT, d * 0.5 - 0.4), Vector3(-1.6, 2.0, d * 0.5), P.PLASTER)
	b.box(Vector3(1.6, -P.SKIRT, d * 0.5 - 0.4), Vector3(w * 0.5, 2.0, d * 0.5), P.PLASTER)
	b.box(Vector3(-w * 0.5, -P.SKIRT, yz0), Vector3(-w * 0.5 + 0.4, 2.0, d * 0.5), P.PLASTER)
	b.box(Vector3(w * 0.5 - 0.4, -P.SKIRT, yz0), Vector3(w * 0.5, 2.0, d * 0.5), P.PLASTER)
	if lod < 2:
		b.box(Vector3(-1.8, 2.0, d * 0.5 - 0.5), Vector3(1.8, 2.25, d * 0.5 + 0.1), P.WOOD)
		b.rect_on(0, -1.5, -0.05, 0.0, 1.95, w, d, -0.35, P.DOOR)    # one gate leaf shut
	b.quad(Vector3(-w * 0.5 + 0.4, 0.05, d * 0.5 - 0.4), Vector3(w * 0.5 - 0.4, 0.05, d * 0.5 - 0.4), Vector3(w * 0.5 - 0.4, 0.05, yz0), Vector3(-w * 0.5 + 0.4, 0.05, yz0), P.EARTH, Vector3.UP)
	if lod >= 2:
		return b
	match variant:
		0:
			# kiln: a domed oven with a stoke hole, and rows of amphorae drying
			b.cone(-5.0, yz0 + 2.0, 0.0, 1.4, 1.5, 1.3, 8, P.BRICK)
			b.cone(-5.0, yz0 + 2.0, 1.4, 2.6, 1.3, 0.3, 8, P.BRICK)
			b.rect_on(0, -5.5, -4.5, 0.0, 0.8, 10.0, -(yz0 + 2.0) * 2.0 + 3.0, 0.02, P.SHADE)
			for i in 5:
				for j in 2:
					P.amphora(b, 1.0 + 0.9 * float(i), 0.0, yz0 + 1.0 + 0.9 * float(j), 1.2)
			if lod == 0:
				for i in 4:
					P.amphora(b, 1.4 + 0.9 * float(i), 0.0, yz0 + 2.8, 1.2)
				b.cone(5.5, d * 0.5 - 2.0, 0.0, 0.9, 0.8, 0.6, 7, P.TERRA)   # a dolium
		1:
			b.box(Vector3(3.0, 0.0, yz0 + 0.8), Vector3(6.6, 1.5, yz0 + 2.2), P.WOOD)
			b.box(Vector3(3.4, 1.5, yz0 + 1.0), Vector3(6.2, 2.1, yz0 + 2.0), P.WOOD)
			b.box(Vector3(-6.4, 0.0, yz0 + 0.6), Vector3(-2.6, 0.9, yz0 + 1.4), P.WOOD)
			if lod == 0:
				b.box(Vector3(-5.8, 0.0, d * 0.5 - 2.4), Vector3(-3.8, 0.8, d * 0.5 - 1.2), P.WOOD)   # a bench
				b.cone(5.0, d * 0.5 - 1.8, 0.0, 1.1, 0.9, 0.7, 7, P.TERRA)
		_:
			# fullonica: a row of treading stalls (small square tubs) and two big rinsing basins,
			# with drying frames (poles and cross-bars) along the wall, cloth hung over them
			for i in 4:
				var x := -6.0 + 1.3 * float(i)
				b.box(Vector3(x, 0.0, yz0 + 0.6), Vector3(x + 1.0, 0.7, yz0 + 1.6), P.STONE)
				b.quad(Vector3(x + 0.1, 0.6, yz0 + 1.5), Vector3(x + 0.9, 0.6, yz0 + 1.5), Vector3(x + 0.9, 0.6, yz0 + 0.7), Vector3(x + 0.1, 0.6, yz0 + 0.7), P.WATER, Vector3.UP)
			for i in 2:
				var x := 1.0 + 3.2 * float(i)
				b.box(Vector3(x, 0.0, yz0 + 0.6), Vector3(x + 2.8, 0.9, yz0 + 2.8), P.STONE)
				b.quad(Vector3(x + 0.2, 0.8, yz0 + 2.6), Vector3(x + 2.6, 0.8, yz0 + 2.6), Vector3(x + 2.6, 0.8, yz0 + 0.8), Vector3(x + 0.2, 0.8, yz0 + 0.8), P.WATER, Vector3.UP)
			if lod == 0:
				for i in 3:
					var x := -6.0 + 4.0 * float(i)
					for sx in [0.0, 2.6]:
						b.box(Vector3(x + sx - 0.05, 0.0, d * 0.5 - 1.6), Vector3(x + sx + 0.05, 2.2, d * 0.5 - 1.5), P.WOOD, true, false)
					b.box(Vector3(x, 2.1, d * 0.5 - 1.6), Vector3(x + 2.6, 2.18, d * 0.5 - 1.5), P.WOOD)
					var cl: Color = P.LINENS[i % P.LINENS.size()]
					b.quad(Vector3(x + 0.2, 2.1, d * 0.5 - 1.52), Vector3(x + 2.4, 2.1, d * 0.5 - 1.52), Vector3(x + 2.4, 0.5, d * 0.5 - 1.45), Vector3(x + 0.2, 0.5, d * 0.5 - 1.45), cl, Vector3(0, 0, 1))
	return b


# ---------------------------------------------------------------- horrea

## Warehouse by the river, nominal 24 x 16 m: a long hall on a heavy plinth with buttress piers,
## slit windows high up, wide doors on the front, a tiled gable roof. (Platner-Ashby s.v. Horrea
## for the plan of rows of deep rooms: # unverified this session.)
static func horrea(lod: int) -> MB:
	var w := 24.0
	var d := 16.0
	var h := 7.0
	var b := MB.new()
	var holes: Array = []
	var doors: Array = [-8.0, 0.0, 8.0]
	for x in doors:
		holes.append(Rect2(x - 1.6, 0.0, 3.2, 3.6))
	P.walls(b, w, d, h, [holes, [], [], []], P.PLASTER, lod)
	for i in doors.size():
		var x: float = doors[i]
		if lod == 0:
			b.reveal(0, x - 1.6, x + 1.6, 0.0, 3.6, w, d, 0.6, P.PLASTER, P.DOOR, 0.6)
			if i == 1:
				b.rect_on(0, x - 1.6, x, 0.02, 3.58, w, d, -0.58, P.SHADE)   # one leaf open
		else:
			b.rect_on(0, x - 1.6, x + 1.6, 0.0, 3.6, w, d, 0.02, P.DOOR)
		if lod < 2:
			b.on_wall(0, x, 3.6, 3.9, 0.35, 0.14, w, d, 0.0, P.STONE)
			b.on_wall(0, x, 0.0, 4.0, 0.16, 0.5, w, d, 0.0, P.STONE)
	if lod < 2:
		# buttress piers on the long faces and slit windows between them
		for face in [0, 1]:
			for i in range(-2, 3):
				var x := float(i) * 5.0 + (2.5 if face == 0 else 0.0)
				if absf(x) > w * 0.5 - 0.5:
					continue
				b.on_wall(face, x, -P.SKIRT, 0.9, P.SKIRT + h - 1.4, 0.5, w, d, 0.0, P.PLINTH)
				if i < 2:
					b.rect_on(face, x + 2.3, x + 2.7, 5.0, 6.0, w, d, 0.02, P.LATTICE)
		for face in [2, 3]:
			for z in [-5.0, 0.0, 5.0]:
				b.on_wall(face, z, -P.SKIRT, 0.9, P.SKIRT + h - 1.4, 0.5, w, d, 0.0, P.PLINTH)
	var rh := P.rise(d * 0.5 + 0.6)
	b.gable(-w * 0.5 - 0.6, w * 0.5 + 0.6, -d * 0.5 - 0.6, d * 0.5 + 0.6, h, rh, P.TILE, P.PLASTER, lod)
	if lod == 0:
		# sacks and amphorae at the doors, a cart
		for i in 3:
			b.cone(-9.5 + float(i) * 0.6, d * 0.5 + 1.0, 0.0, 0.45, 0.28, 0.3, 7, P.CLOTH)
		for i in 4:
			P.amphora(b, 2.6 + float(i) * 0.5, 0.0, d * 0.5 + 0.8, 1.0)
	return b


# ---------------------------------------------------------------- horti

## Walled garden estate, nominal 70 x 70 m: a villa with a hip roof, a colonnade, two pavilions,
## a long pool, the garden wall with its gate; trees come from fill.gd.
static func horti(lod: int) -> MB:
	var w := 70.0
	var d := 70.0
	var b := MB.new()
	var up := Vector3(0, 1, 0)
	b.quad(Vector3(-w * 0.5, 0.15, d * 0.5), Vector3(w * 0.5, 0.15, d * 0.5), Vector3(w * 0.5, 0.15, -d * 0.5), Vector3(-w * 0.5, 0.15, -d * 0.5), P.LEAF, up)
	var t := 0.5
	var wh := 2.8
	b.box(Vector3(-w * 0.5, -P.SKIRT, -d * 0.5), Vector3(w * 0.5, wh, -d * 0.5 + t), P.PLASTER)
	b.box(Vector3(-w * 0.5, -P.SKIRT, -d * 0.5), Vector3(-w * 0.5 + t, wh, d * 0.5), P.PLASTER)
	b.box(Vector3(w * 0.5 - t, -P.SKIRT, -d * 0.5), Vector3(w * 0.5, wh, d * 0.5), P.PLASTER)
	b.box(Vector3(-w * 0.5, -P.SKIRT, d * 0.5 - t), Vector3(-2.5, wh, d * 0.5), P.PLASTER)
	b.box(Vector3(2.5, -P.SKIRT, d * 0.5 - t), Vector3(w * 0.5, wh, d * 0.5), P.PLASTER)
	if lod < 2:
		# a tiled coping on the wall
		for seg in [[Vector3(-w * 0.5 - 0.2, wh, -d * 0.5 + t * 0.5), Vector3(w * 0.5 + 0.2, wh, -d * 0.5 + t * 0.5)],
				[Vector3(-w * 0.5 + t * 0.5, wh, -d * 0.5), Vector3(-w * 0.5 + t * 0.5, wh, d * 0.5)],
				[Vector3(w * 0.5 - t * 0.5, wh, -d * 0.5), Vector3(w * 0.5 - t * 0.5, wh, d * 0.5)],
				[Vector3(-w * 0.5, wh, d * 0.5 - t * 0.5), Vector3(-2.5, wh, d * 0.5 - t * 0.5)],
				[Vector3(2.5, wh, d * 0.5 - t * 0.5), Vector3(w * 0.5, wh, d * 0.5 - t * 0.5)]]:
			b.ridge(seg[0], seg[1], 0.34)
	b.rect_on(0, -2.5, 2.5, 0.0, 2.4, w, d, -0.3, P.DOOR)
	b.box(Vector3(-2.9, 2.4, d * 0.5 - 0.6), Vector3(2.9, 2.75, d * 0.5 + 0.1), P.STONE)
	b.quad(Vector3(-1.6, 0.25, d * 0.5), Vector3(1.6, 0.25, d * 0.5), Vector3(1.6, 0.25, 4.0), Vector3(-1.6, 0.25, 4.0), P.EARTH, up)
	var vz := -2.0
	var villa := MB.new()
	var vholes: Array = []
	for i in 6:
		var hh := -10.8 + 4.3 * float(i)
		vholes.append(P.window_hole(hh, 1.2, 1.4, 2.2))
	vholes.append(P.door_hole(0.0, 1.6, 3.0))
	P.walls(villa, 26.0, 13.0, 7.0, [vholes if lod == 0 else [P.door_hole(0.0, 1.6, 3.0)], [], [], []], P.PLASTER, lod)
	P.door(villa, 0, 0.0, 1.6, 3.0, 26.0, 13.0, lod, 81, true)
	for i in 6:
		var hh := -10.8 + 4.3 * float(i)
		if absf(hh) < 1.5:
			continue
		if lod == 0:
			P.window(villa, 0, hh, 1.2, 1.4, 2.2, 26.0, 13.0, 0, 82 + i)
		elif lod == 1:
			P.window_flat(villa, 0, hh, 1.2, 1.4, 2.2, 26.0, 13.0, 82 + i)
		if lod < 2:
			P.window_flat(villa, 0, hh, 4.4, 1.1, 1.3, 26.0, 13.0, 90 + i)
	villa.hip(-13.6, 13.6, -7.1, 7.1, 7.0, P.rise(7.1), P.TILE, lod)
	b.append(villa, Vector3(0, 0, vz))
	for sx in [-22.0, 22.0]:
		var pav := MB.new()
		P.walls(pav, 8.0, 8.0, 4.6, [[P.door_hole(0.0, 1.2, 2.4)], [], [], []], P.PLASTER, lod)
		P.door(pav, 0, 0.0, 1.2, 2.4, 8.0, 8.0, lod, 95)
		pav.hip(-4.6, 4.6, -4.6, 4.6, 4.6, P.rise(4.6), P.TILE, lod)
		b.append(pav, Vector3(sx, 0, 8.0))
	if lod < 2:
		for i in 9:
			var x := -12.0 + float(i) * 3.0
			b.cone(x, vz + 7.9, 0.0, 3.6, 0.25, 0.21, 8, P.STONE)
		b.box(Vector3(-12.5, 3.6, vz + 7.5), Vector3(12.5, 4.0, vz + 8.3), P.WOOD)
		b.shed(-12.5, 12.5, vz + 6.6, vz + 8.6, 4.0 + P.rise(2.0), 4.0, P.TILE, lod)
		b.box(Vector3(-8.4, 0.0, 13.6), Vector3(8.4, 0.5, 22.4), P.STONE)
		b.quad(Vector3(-8.0, 0.45, 22.0), Vector3(8.0, 0.45, 22.0), Vector3(8.0, 0.45, 14.0), Vector3(-8.0, 0.45, 14.0), P.WATER, up)
	return b
