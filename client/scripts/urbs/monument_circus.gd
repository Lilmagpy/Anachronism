## Urbs (U8): the Circus Maximus, phase by phase, on the shared materials.
##
## Local frame: z along the length, the carceres at -z, the curved end (sphendone) at +z; +x is
## the Palatine side. The footprint is Dionysius' (3.68, via Platner-Ashby s.v. Circus Maximus,
## read): 621 x 118 m. Variants (the record's phases): "" / early (before 329 BC: earth banks with
## timber stands, no gates), carceres (329 BC, Livy 8.20.2), eggs (174 BC: the carceres restored
## and sets of seven wooden eggs to count the laps, Livy 41.27.6), caesar (46 BC: the euripus,
## a moat 10 ft wide and deep between the arena and the seats, Suet. Iul. 39; the lowest seats of
## stone), augustan (33 BC: Agrippa's seven bronze dolphins, Dio 49.43.2; then the obelisk from
## Heliopolis and the pulvinar of Augustus, Mon. Anc. 4.4, dates # unverified: drawn from 10 BC
## and 27 BC).
##
## From Platner-Ashby (read): twelve carceres set on a curve, closed by rope barriers on small
## herms, uncovered (Dionysius); the presiding magistrate's box above the middle; towers and
## battlements at each end (the oppidum); a podium round the arena; the seats in three zones
## separated by corridors, the lowest of stone, the upper two of timber; outside, a one-storey
## arcade of shops with the entrances and stairs; the curved end with a gateway in its centre;
## on the spina the eggs, the dolphins, the obelisk, the altar of Consus near the east end, and
## at each end the metae, three cones (of gilt bronze in the final circus, Cassiodorus; wooden
## before Claudius replaced them, Suet. Claud. 21). The arena's widths (75-87 m) and the spina's
## length (344 m) are those of the final circus; they are used for every phase (# unverified for
## the Republic).
class_name UrbsCircus
extends RefCounted

const MM := preload("res://scripts/urbs/monument_mesh.gd")
const Orders := preload("res://scripts/urbs/monument_orders.gd")


static func spec(rec: Dictionary, st: Dictionary) -> Dictionary:
	return {"L": maxf(float(st.get("length", 621.0)), 300.0), "W": maxf(float(st.get("width", 118.0)), 80.0),
		"variant": str(st.get("variant", "")), "year": int(st.get("year", 0)), "id": str(rec.get("id", "")),
		"skirt": float(st.get("skirt", 0.0))}


static func build(s: Dictionary) -> Dictionary:
	var mm := MM.new()
	var L := float(s.L)
	var W := float(s.W)
	var v := str(s.variant)
	var year := int(s.year)
	var gates := v != "" and v != "early"
	var stone := v == "caesar" or v == "augustan"
	var aw := 80.0                       # the arena's width
	var cav := (W - aw) * 0.5            # the depth of the seating on each flank
	var zc := -L * 0.5                   # the back of the carceres
	var zg := zc + 14.0                  # the carceres' front: the arena starts here
	var zcurve := L * 0.5 - W * 0.5      # where the flanks end and the curved end begins
	# a foundation under the whole circus down to the lowest ground (it stands on the highest)
	var sk := float(s.get("skirt", 0.0)) + 0.5
	mm.ext(-W * 0.5, -sk, -L * 0.5, W * 0.5, -0.1, L * 0.5 - W * 0.5, "opus_quadratum")
	mm.cylinder(Vector3(0, -sk, L * 0.5 - W * 0.5), W * 0.5, sk - 0.1, "opus_quadratum", 40)
	# the arena: sand, open (walked on, not picked)
	mm.ext(-aw * 0.5, -0.1, zg - 2.0, aw * 0.5, 0.05, zcurve, "sand_arena")
	mm.cylinder(Vector3(0, -0.1, zcurve), aw * 0.5, 0.15, "sand_arena", 40)
	mm.open(Vector3(0, -0.1, (zg + L * 0.5) * 0.5), Vector3(aw, 0.2, L * 0.5 - zg))
	# the seating along both flanks and round the curved end
	for sx: float in [-1.0, 1.0]:
		_flank(mm, sx, aw, cav, zc, zcurve, stone, gates)
	_sphendone(mm, aw, cav, zcurve, stone)
	# the euripus (from 46 BC): a channel 3 m wide and 3 deep (10 ft, Dion. Hal. 3.68) at the foot
	# of the podium, round the arena except at the carceres
	if stone:
		for sx: float in [-1.0, 1.0]:
			mm.ext(sx * (aw * 0.5 - 3.0), -0.6, zg + 6.0, sx * aw * 0.5, -0.3, zcurve, "fountain_water")
			mm.ext(sx * (aw * 0.5 - 3.3), -0.1, zg + 6.0, sx * (aw * 0.5 - 3.0), 0.6, zcurve, "travertine")
		var segs := 28
		for g in segs:
			var a0 := PI * g / segs
			var a1 := PI * (g + 1) / segs
			var am := (a0 + a1) * 0.5
			var r := aw * 0.5 - 1.5
			var p := Vector3(cos(am) * r, -0.6, zcurve + sin(am) * r)
			mm.push(MM.at(p, -am + PI / 2.0))
			mm.box(Vector3.ZERO, Vector3(2.0 * r * sin(PI / segs / 2.0) + 0.1, 0.3, 3.0), "fountain_water")
			mm.pop()
	# the spina and the metae
	_spina(mm, zg, zcurve, v, year, gates)
	# the carceres
	if gates:
		_carceres(mm, aw, cav, zc, zg, year)
	else:
		# before 329 BC: a rope across the start, and the stands' ends
		mm.ext(-aw * 0.5, 0.0, zg - 0.2, aw * 0.5, 1.0, zg, "timber_weathered")
	# the gateway in the middle of the curved end
	mm.push(MM.at(Vector3(0, 0, L * 0.5 - 1.5)))
	mm.ext(-6.0, 0.0, -1.5, -3.0, 12.0, 1.5, "travertine" if stone else "tufa_yellow")
	mm.ext(3.0, 0.0, -1.5, 6.0, 12.0, 1.5, "travertine" if stone else "tufa_yellow")
	mm.arch(-3.0, 3.0, 7.0, 12.0, -1.5, 1.5, "travertine" if stone else "tufa_yellow", 8)
	mm.pop()
	# the pulvinar of Augustus on the Palatine side (Mon. Anc. 4.4; form # unverified: a temple-like box)
	if year >= -27 and v == "augustan":
		mm.push(MM.at(Vector3(aw * 0.5 + cav * 0.55, 0, (zg + zcurve) * 0.5 + 40.0), -PI / 2.0))
		mm.ext(-8.0, 0.0, -5.0, 8.0, 12.0, 5.0, "travertine")
		for i in 6:
			Orders.column(mm, Vector3(-7.0 + i * 2.8, 12.0, 4.0), 5.5, "corinthian", "marble_luna", 1)
		mm.ext(-8.0, 17.5, -5.0, 8.0, 18.4, 5.0, "marble_luna")
		Orders.roof(mm, -8.5, 8.5, -5.0, 5.0, 18.4, 2.2, 0.4, 1)
		mm.pop()
	return mm.finish()


## One flank of seats, from the carceres to the curve, on side `sx`: the podium wall at the
## arena's edge, three zones of rows separated by corridors (the lowest of stone from Caesar on,
## the rest timber; before that earth banks below, timber stands above), the outer arcade of shops.
static func _flank(mm: UrbsMonumentMesh, sx: float, aw: float, cav: float, zc: float, zcurve: float, stone: bool, gates: bool) -> void:
	var x0 := sx * aw * 0.5
	var z0 := zc + (14.0 if gates else 0.0)
	var z1 := zcurve
	var rows := [[8, "travertine" if stone else "earth_packed"], [8, "timber_weathered"], [6, "timber_weathered"]]
	var podium := 1.6
	var x := 0.0      # distance out from the arena's edge
	var y := podium
	mm.ext(minf(x0, x0 + sx * 1.0), 0.0, z0, maxf(x0, x0 + sx * 1.0), podium + 0.9, z1, "travertine" if stone else "timber_weathered")
	x = 1.0
	for zi in rows.size():
		var n := int(rows[zi][0])
		var mat := str(rows[zi][1])
		for r in n:
			var xa := x0 + sx * x
			var xb := x0 + sx * (x + 0.75)
			mm.ext(minf(xa, xb), 0.0, z0, maxf(xa, xb), y + 0.42, z1, mat)
			x += 0.75
			y += 0.42
		if zi < rows.size() - 1:   # the corridor (praecinctio) and its parapet
			var xa2 := x0 + sx * x
			var xb2 := x0 + sx * (x + 1.4)
			mm.ext(minf(xa2, xb2), 0.0, z0, maxf(xa2, xb2), y + 0.1, z1, "travertine" if stone else "timber_weathered")
			mm.ext(minf(xa2, xa2 + sx * 0.25), y + 0.1, z0, maxf(xa2, xa2 + sx * 0.25), y + 1.0, z1, "timber_weathered" if not stone else "travertine")
			x += 1.4
			y += 0.6
	# the back: the outer arcade of shops under the top rows, one storey (Dionysius)
	var xo := x0 + sx * x
	var xw := x0 + sx * cav
	mm.ext(minf(xo, xw), 0.0, z0, maxf(xo, xw), y + 1.2, z1, "tufa_yellow" if not stone else "travertine")
	mm.solid(Vector3(x0 + sx * cav * 0.5, 0.0, (z0 + z1) * 0.5), Vector3(cav, y + 1.2, z1 - z0))
	var bay := 6.0
	var n_arch := int((z1 - z0) / bay)
	var face := x0 + sx * cav
	mm.push(MM.at(Vector3(face, 0, 0), sx * PI / 2.0))
	for i in n_arch:
		var z := z0 + (i + 0.5) * bay
		var c := -z   # the frame turned: local x runs along -z for sx > 0
		if sx < 0.0:
			c = z
		mm.arch(c - 1.8, c + 1.8, 3.6, 6.5, -0.6, 0.15, "travertine" if stone else "tufa_yellow", 6, true, false)
		# behind each arch a shop with its shutters, or an entrance (every fourth bay)
		if i % 4 != 0:
			mm.ext(c - 1.8, 0.0, -0.75, c + 1.8, 3.6, -0.6, "shutter_wood")
		else:
			mm.ext(c - 1.8, 0.0, -2.5, c + 1.8, 0.05, -0.6, "limestone_steps")
	# pilasters between the bays, a band, and a row of small windows lighting the stairs above
	for i in n_arch + 1:
		var z := z0 + i * bay
		var c2 := -z if sx > 0.0 else z
		mm.box(Vector3(c2, 0.0, 0.2), Vector3(0.7, 7.2, 0.3), "travertine" if stone else "tufa_yellow")
		if i < n_arch:
			var cw := c2 + (-bay * 0.5 if sx > 0.0 else bay * 0.5)
			mm.push(MM.at(Vector3(cw, 8.6, 0.15)))
			Orders.window(mm, Vector3.ZERO, 0.8, 1.2, "travertine", "grille", 1)
			mm.pop()
	mm.ext(minf(-z0, -z1) if sx > 0.0 else z0, 7.0, 0.0, maxf(-z0, -z1) if sx > 0.0 else z1, 7.6, 0.45, "travertine" if stone else "tufa_yellow")
	mm.pop()
	# the stairways (scalae) down through the seats every 20 m, a lighter strip
	var zz := z0 + 10.0
	while zz < z1 - 5.0:
		var xa3 := x0 + sx * 1.0
		var xb3 := x0 + sx * (cav - 1.0)
		mm.push(MM.at(Vector3.ZERO))
		var n_st := 28
		for k in n_st:
			var f0 := float(k) / n_st
			var xs0 := lerpf(xa3, xb3, f0)
			var xs1 := lerpf(xa3, xb3, f0 + 1.0 / n_st)
			mm.ext(minf(xs0, xs1), 0.0, zz - 0.6, maxf(xs0, xs1), 1.6 + (y - 1.6) * (f0 + 0.5 / n_st) + 0.08, zz + 0.6, "limestone_steps")
		mm.pop()
		zz += 20.0


## The curved end: the same rows on half-rings round the arena's end.
static func _sphendone(mm: UrbsMonumentMesh, aw: float, cav: float, zcurve: float, stone: bool) -> void:
	var segs := 36
	var r := aw * 0.5
	var y := 1.6
	var zones := [[8, "travertine" if stone else "earth_packed"], [8, "timber_weathered"], [6, "timber_weathered"]]
	var rr := r + 1.0
	for zi in zones.size():
		for k in int(zones[zi][0]):
			_ring_step(mm, zcurve, rr, rr + 0.75, y + 0.42, str(zones[zi][1]), segs)
			rr += 0.75
			y += 0.42
		if zi < zones.size() - 1:
			_ring_step(mm, zcurve, rr, rr + 1.4, y + 0.1, "travertine" if stone else "timber_weathered", segs)
			rr += 1.4
			y += 0.6
	_ring_step(mm, zcurve, rr, r + cav, y + 1.2, "tufa_yellow" if not stone else "travertine", segs)
	_ring_step(mm, zcurve, r, r + 1.0, 2.5, "travertine" if stone else "timber_weathered", segs)
	mm.solid(Vector3(0, 0, zcurve + (r + cav) * 0.5), Vector3(aw + cav * 2.0, y + 1.2, r + cav))


## A half-ring step from radius r0 to r1 round (0, zc) on the +z side, `top` high, in segments.
static func _ring_step(mm: UrbsMonumentMesh, zc: float, r0: float, r1: float, top: float, mat: String, segs: int) -> void:
	for g in segs:
		var a0 := PI * g / segs
		var a1 := PI * (g + 1) / segs
		var p := [Vector3(cos(a0) * r0, 0, zc + sin(a0) * r0), Vector3(cos(a1) * r0, 0, zc + sin(a1) * r0),
			Vector3(cos(a1) * r1, 0, zc + sin(a1) * r1), Vector3(cos(a0) * r1, 0, zc + sin(a0) * r1)]
		var t: Array = p.map(func(q: Vector3) -> Vector3: return q + Vector3(0, top, 0))
		var c: Vector3 = (p[0] + p[2]) * 0.5 + Vector3(0, top * 0.5, 0)
		mm.quad(t[0], t[1], t[2], t[3], mat, c)
		mm.quad(p[0], p[1], t[1], t[0], mat, c)
		mm.quad(p[2], p[3], t[3], t[2], mat, c)


## The spina down the middle of the arena: a low wall with basins, the two metae of three cones
## at its ends (wooden until Claudius, then gilt bronze), the eggs (from 174 BC) and dolphins
## (from 33 BC) on their frames, the obelisk (from 10 BC, # unverified date; 23.7 m without its
## base, # unverified), the altar of Consus near the east end, statues and small shrines.
static func _spina(mm: UrbsMonumentMesh, zg: float, zcurve: float, v: String, year: int, gates: bool) -> void:
	var len := 344.0
	var za := zg + (zcurve - zg - len) * 0.5 + 20.0
	var zb := za + len
	var stone := v == "caesar" or v == "augustan"
	var wall := "travertine" if stone else ("tufa_yellow" if gates else "timber_weathered")
	mm.ext(-4.0, 0.0, za, 4.0, 1.2, zb, wall)
	mm.ext(-4.3, 1.2, za - 0.3, 4.3, 1.45, zb + 0.3, wall)
	mm.solid(Vector3(0, 0, (za + zb) * 0.5), Vector3(8.6, 1.45, len))
	if stone:   # basins along the top
		mm.ext(-3.0, 1.3, za + 6.0, 3.0, 1.5, zb - 6.0, "fountain_water")
	# the metae: a semicircular base and three tall cones
	var gilt := year >= 41
	for e: Array in [[za - 5.0, -1.0], [zb + 5.0, 1.0]]:
		var z := float(e[0])
		mm.cylinder(Vector3(0, 0, z), 4.5, 2.2, wall, 20)
		for i in 3:
			var x := (i - 1) * 2.6
			mm.frustum(Vector3(x, 2.2, z), 1.1, 0.25, 8.0, "gilt" if gilt else "timber_painted", 10)
			mm.lathe(Vector3(x, 10.2, z), PackedVector2Array([Vector2(0.35, 0.0), Vector2(0.5, 0.3), Vector2(0.001, 0.9)]), "gilt" if gilt else "timber_painted", 8)
		mm.solid(Vector3(0, 0, z), Vector3(9.0, 11.0, 9.0))
	# the seven eggs (Livy 41.27.6) near the west end: a frame on two posts with the eggs on top
	if v == "eggs" or stone:
		var ze := za + 40.0
		for sx: float in [-1.0, 1.0]:
			mm.box(Vector3(sx * 4.6, 1.45, ze), Vector3(0.5, 4.2, 0.5), "travertine" if stone else "timber_painted")
		mm.ext(-5.0, 5.65, ze - 0.3, 5.0, 6.05, ze + 0.3, "timber_painted")
		for i in 7:
			var x := -4.2 + i * 1.4
			mm.lathe(Vector3(x, 6.05, ze), PackedVector2Array([Vector2(0.001, 0.0), Vector2(0.4, 0.25), Vector2(0.42, 0.6), Vector2(0.28, 1.0), Vector2(0.001, 1.15)]), "stucco_white", 10)
	# Agrippa's seven bronze dolphins (Dio 49.43.2), near the east end
	if v == "augustan":
		var zd := zb - 40.0
		for sx: float in [-1.0, 1.0]:
			mm.box(Vector3(sx * 4.6, 1.45, zd), Vector3(0.5, 4.2, 0.5), "travertine")
		mm.ext(-5.0, 5.65, zd - 0.3, 5.0, 6.05, zd + 0.3, "travertine")
		for i in 7:
			var x := -4.2 + i * 1.4
			mm.push(Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(x, 6.4, zd)))
			mm.frustum(Vector3.ZERO, 0.28, 0.06, 1.2, "bronze", 8, true, true)
			mm.pop()
			mm.box(Vector3(x, 6.05, zd + 0.3), Vector3(0.1, 0.35, 0.5), "bronze")
	# the obelisk of Augustus from Heliopolis (Plin. NH 36.71 via Platner-Ashby)
	if v == "augustan" and year >= -10:
		var zo := (za + zb) * 0.5
		mm.box(Vector3(0, 1.45, zo), Vector3(4.0, 3.5, 4.0), "marble_luna")
		mm.frustum(Vector3(0, 4.95, zo), 1.35, 0.95, 23.7, "marble_pentelic", 4, false)
		mm.frustum(Vector3(0, 28.65, zo), 0.95, 0.001, 1.6, "gilt", 4)
		mm.solid(Vector3(0, 0, zo), Vector3(4.0, 30.0, 4.0))
	# the altar of Consus near the east end, and a few statues on columns along the spina
	if gates:
		mm.box(Vector3(0, 1.45, zb - 15.0), Vector3(2.4, 1.3, 1.6), "tufa_grey")
		for k in 4:
			var z := za + 90.0 + k * 50.0
			Orders.column(mm, Vector3(0, 1.45, z), 6.0, "tuscan", "travertine" if stone else "stucco_white", 1)
			Orders.statue(mm, Vector3(0, 7.45, z), 1.9, "statue_bronze")


## The carceres: twelve stalls on a shallow curve so that each is the same distance from the
## starting line (Platner-Ashby), arched openings closed by rope barriers on small herms, without
## a roof (Dionysius); above the middle the box of the presiding magistrate; at each end a tower
## with battlements (the oppidum). Tufa until Claudius rebuilt them in marble (# drawn tufa).
static func _carceres(mm: UrbsMonumentMesh, aw: float, cav: float, zc: float, zg: float, year: int) -> void:
	var mat := "tufa_yellow" if year < 41 else "marble_luna"
	var n := 12
	var span := aw - 6.0
	var bay := span / n
	var h := 7.0
	var curve := 4.0   # how much the ends stand forward of the middle
	# the back wall and the passage behind
	mm.ext(-aw * 0.5 - 2.0, 0.0, zc, aw * 0.5 + 2.0, h + 1.0, zc + 3.0, mat)
	mm.solid(Vector3(0, 0, zc + 1.5), Vector3(aw + 4.0, h + 1.0, 3.0))
	for i in n:
		var t := (i + 0.5) / n - 0.5
		var x := t * span
		var zf := zg - curve * (1.0 - (2.0 * t) * (2.0 * t)) - 0.5   # the middle is set back
		mm.push(MM.at(Vector3(x, 0, zf)))
		# the piers either side and the arch over the stall
		mm.ext(-bay * 0.5, 0.0, -(zf - zc - 3.0), -bay * 0.5 + 0.9, h, 0.0, mat)
		if i == n - 1:
			mm.ext(bay * 0.5 - 0.9, 0.0, -(zf - zc - 3.0), bay * 0.5, h, 0.0, mat)
		mm.arch(-bay * 0.5 + 0.9, bay * 0.5, 4.2, h, -0.9, 0.0, mat, 8)
		# the rope barrier on two small herms
		for sx: float in [-1.0, 1.0]:
			mm.box(Vector3(sx * (bay * 0.5 - 1.1), 0.0, 0.6), Vector3(0.3, 1.3, 0.3), "marble_luna")
			mm.lathe(Vector3(sx * (bay * 0.5 - 1.1), 1.3, 0.6), PackedVector2Array([Vector2(0.001, 0.0), Vector2(0.14, 0.05), Vector2(0.13, 0.25), Vector2(0.001, 0.32)]), "marble_luna", 6)
		mm.rod(Vector3(-(bay * 0.5 - 1.1), 1.1, 0.6), Vector3(bay * 0.5 - 1.1, 1.1, 0.6), 0.03, "awning_canvas")
		mm.pop()
	# the cornice over the stalls (no roof: Dionysius), the magistrate's box above the middle
	mm.ext(-span * 0.5 - 1.0, h, zc, span * 0.5 + 1.0, h + 1.0, zg - curve * 0.2, mat)
	mm.ext(-6.0, h + 1.0, zc, 6.0, h + 5.0, zc + 6.0, mat)
	mm.ext(-6.5, h + 5.0, zc - 0.3, 6.5, h + 5.6, zc + 6.6, "travertine")
	for x: float in [-4.5, -1.5, 1.5, 4.5]:
		mm.box(Vector3(x, h + 1.0, zc + 6.0), Vector3(0.6, 4.0, 0.6), "marble_luna")
	Orders.roof(mm, -6.5, 6.5, zc - 0.3, zc + 6.6, h + 5.6, 1.8, 0.3, 0)
	# the towers at the ends (oppidum), with battlements
	for sx: float in [-1.0, 1.0]:
		var tx := sx * (aw * 0.5 + 1.0)
		mm.ext(tx - 5.0, 0.0, zc, tx + 5.0, h + 7.0, zg + 1.0, mat)
		mm.solid(Vector3(tx, 0.0, (zc + zg + 1.0) * 0.5), Vector3(10.0, h + 7.0, zg + 1.0 - zc))
		for k in 4:
			for side: float in [-1.0, 1.0]:
				mm.box(Vector3(tx - 3.75 + k * 2.5, h + 7.0, (zc + zg) * 0.5 + side * ((zg - zc) * 0.5 + 0.2)), Vector3(1.2, 1.4, 0.8), mat)
		mm.push(MM.at(Vector3(tx, 4.0, zg + 1.0)))
		Orders.window(mm, Vector3.ZERO, 1.0, 2.2, "travertine", "shutters", 0)
		mm.pop()
