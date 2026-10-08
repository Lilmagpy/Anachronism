## A province's chief city, planned on its ground (D-279, D-281): its outline, streets,
## square, public buildings, walls and houses. Called by Settlements.build for each chief
## city; `s` is the Settlements object, whose helpers place and claim the buildings
## (s._add, s._fit_house, s._model, s._dry, s._free, s._claim ...), whose `ground` lays the
## ground under them and whose `rng` is seeded per city.
extends RefCounted


var s: Settlements   ## the Settlements being built


func _init(settlements: Settlements) -> void:
	s = settlements


## Plan and build the chief city of `site`.
func plan(site: Dictionary, population: int, index: int) -> void:
	_city(site, population, index)

## The province's chief city, planned on its ground (D-279).
func _city(site: Dictionary, population: int, index: int) -> void:
	var centre: Vector2 = site["pixel"]
	var tier := int(site.get("tier", 0))   # village, town, city, great city, metropolis (D-127)
	var half := clampf(0.5 + sqrt(population / 100000.0) * 0.28, 0.6, 1.8) * s.S * (1.0 + 0.12 * tier)
	var houses := clampi(population / 30000, 8, 60) + tier * 8
	# a city on the water is laid out to face it; inland, on the lie of its own ground
	var sea := s._sea_direction(centre, half * 1.3)
	var theta := sea.angle() if sea != Vector2.ZERO else s.rng.randf_range(-0.5, 0.5)
	if s.earth.is_wet(centre):   # the province's point is offshore: build on the nearest shore
		for r in range(1, 12):
			var found := false
			for k in 16:
				var p := centre + Vector2(cos(k * TAU / 16.0), sin(k * TAU / 16.0)) * r * s.LOT
				if s._dry(p, s.LOT):
					centre = p
					found = true
					break
			if found:
				break
	s.clearings.append([centre, half * 1.35])
	if s.style == "steppe":
		s.rural._camp(site, centre, half, houses * 2, index)
		return
	var planned := s.style in ["classical", "east"]
	var shape := [s.rng.randf() * TAU, s.rng.randf() * TAU, s.rng.randf() * TAU]
	var reach := func(phi: float) -> float:   # the city's own outline
		if planned:   # a planned city is near square, corners a little worn
			var c := maxf(absf(cos(phi)), absf(sin(phi)))
			return half * (0.92 + 0.06 * sin(3.0 * phi + shape[0])) / c * 0.82
		return half * (0.86 + 0.12 * sin(2.0 * phi + shape[0]) + 0.07 * sin(3.0 * phi + shape[1])
			+ 0.04 * sin(5.0 * phi + shape[2]))
	# the roads out of the city: on the grid's axes when planned, else fanning out
	var roads: Array = []
	if planned:
		roads = [0.0, PI / 2.0, PI, 3.0 * PI / 2.0]
	else:
		var count := s.rng.randi_range(3, 5)
		var start := s.rng.randf() * TAU
		for k in count:
			roads.append(start + TAU * k / count + s.rng.randf_range(-0.3, 0.3))
		if sea != Vector2.ZERO:
			roads[0] = 0.0   # one road runs down to the harbour
	var base := s.earth.metres_at(centre)
	var n := int(ceil(half * 1.7 / s.LOT))
	var lots := {}   # Vector2i -> [pixel, local, kind]
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var local := Vector2(i, j) * s.LOT
			var phi := local.angle()
			var edge: float = reach.call(phi)
			var inside: bool = local.length() <= edge
			var on_road := false
			for a in roads:
				var d := Vector2(cos(a), sin(a))
				if local.dot(d) > 0.0 and absf(local.cross(d)) < s.LOT * 0.55:
					on_road = true
			var suburb: bool = not inside and tier >= 2 and local.length() < edge * 1.55 and on_road
			if not inside and not suburb:
				continue
			var p := centre + local.rotated(theta)
			if not s._dry(p, s.LOT * 0.55):
				continue
			if absf(s.earth.metres_at(p) - base) > 220.0:
				continue   # the city does not climb the mountain
			lots[Vector2i(i, j)] = [p, local, "suburb" if not inside else "lot", on_road]
	# keep only lots that can be walked to from the centre (not across a bay)
	var start_lot := Vector2i.ZERO
	if not lots.has(start_lot):
		var best := INF
		for key in lots:
			if (lots[key][1] as Vector2).length() < best:
				best = (lots[key][1] as Vector2).length()
				start_lot = key
	var reached := {start_lot: true}
	var queue: Array = [start_lot]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = at + step
			if lots.has(nxt) and not reached.has(nxt):
				reached[nxt] = true
				queue.append(nxt)
	for key in lots.keys():
		if not reached.has(key):
			lots.erase(key)
	if lots.is_empty():
		return
	var palace_part := s._palace_part() if site["capital"] else ""
	var palace_reach: float = s._foot(palace_part) if palace_part != "" else float(s.PALACE_R.get(s.style, 0.6)) * s.S
	if site["capital"]:   # the palace needs dry ground all round: the nearest lot that has it
		var palace_r := palace_reach
		var order := lots.keys()
		order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (lots[a][1] as Vector2).length() < (lots[b][1] as Vector2).length())
		for key in order:
			if s._dry(lots[key][0], palace_r):
				start_lot = key
				break
	var heart: Vector2 = lots[start_lot][0]
	# the square at the heart, large enough for the palace and the public buildings
	var plaza := s.LOT * (0.8 if site.get("buildings", []).size() == 0 and not site["capital"] else 1.3)
	if site["capital"]:
		plaza = maxf(plaza, palace_reach * 0.95)
	var heart_local: Vector2 = lots[start_lot][1]
	var streets := {}
	for key in lots:
		var local: Vector2 = lots[key][1]
		var kind := "lot"
		if (local - heart_local).length() <= plaza:
			kind = "plaza"
		elif lots[key][3]:
			kind = "street"
		elif planned and (posmod(key.x, 6) == 3 or posmod(key.y, 5) == 2):
			kind = "street"
		elif s.style == "northern" and absf(local.length() - float(reach.call(local.angle())) * 0.6) < s.LOT * 0.5:
			kind = "street"   # the ring road where the old walls stood
		elif lots[key][2] == "suburb":
			kind = "yard"
		streets[key] = kind
	var ground: Color = {"near_east": Color(0.82, 0.70, 0.50), "nile": Color(0.85, 0.74, 0.54),
		"south_asian": Color(0.76, 0.60, 0.44), "northern": Color(0.56, 0.52, 0.42)}.get(s.style, Color(0.74, 0.66, 0.50))
	var street: Color = ground.lerp(Color(0.80, 0.74, 0.64), 0.45)
	var paved: Color = ground.lerp(Color(0.84, 0.80, 0.70), 0.6)
	for key in lots:
		var kind: String = streets[key]
		if kind == "yard" or (lots[key][2] == "suburb" and tier < 4):
			continue   # suburbs stand on their own fields, not paving
		# paving grows with the city (owner's wish): a young town's houses stand on the grass
		# round a small square; a city paves its streets; a great city paves everything
		if tier <= 1 and kind != "plaza":
			continue
		if tier == 2 and kind == "lot":
			continue
		var colour: Color = paved if kind == "plaza" else (street if kind == "street" else ground.darkened(s.rng.randf() * 0.08))
		colour.a = 1.0 if kind == "plaza" else (0.66 if kind == "street" else 0.33)   # the paving's pattern (D-280)
		s._add("paving", lots[key][0], -0.55, -theta, Vector3(s.LOT * 1.03, 90.0, s.LOT * 1.03), colour)
	# the palace at the heart, the public buildings around the square
	if site["capital"]:
		if palace_part != "":   # the model kit's palace (D-280), its front to the main road
			s._add(palace_part, heart, 0.0, -theta - PI / 2.0, Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.85)
			if s.style == "nile":
				_pyramid(heart, half, index)
		else:
			s._palace(heart, index, -theta)
		s._claim(heart, maxf(plaza - s.LOT * 0.5, s.LOT * 0.5))   # the square is the palace's ground
	else:
		s._claim(heart, s.LOT * 0.5)
	var mast := heart + Vector2(plaza * 0.75, 0).rotated(theta + PI / 4.0)
	s._add("k_flag", mast, 0.0, 0.0, Vector3.ONE * (1.6 if site["capital"] else 1.0), Color.WHITE, index, 1.0)
	s._claim(mast, s.LOT * 0.25)
	var size := clampf(0.8 + population / 2000000.0, 0.8, 1.4)
	s._add("i_castle" if site["capital"] else "i_town", centre, 0.0, PI / 5.0, Vector3.ONE * size, Color.WHITE, index, 1.0)
	# walls first, so nothing is built across them: along the outline, the outline, broken where the water guards the city and opened by gates
	if site["capital"] or tier >= 2:
		_city_walls(centre, theta, lots, streets, roads, index)
	var spots: Array = []   # building plots: the lots next to the square and the main streets
	for key in lots:
		if streets[key] != "lot":
			continue
		var next_to := false
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if streets.get(key + step, "") in ["plaza", "street"]:
				next_to = true
		if next_to:
			spots.append(key)
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (lots[a][1] as Vector2).distance_to(heart_local) < (lots[b][1] as Vector2).distance_to(heart_local))
	var looks: Array = (site.get("buildings", []) as Array).duplicate()
	if str(site.get("works", "")) != "":
		looks.append("|works|" + str(site["works"]))
	for extra in _landmarks(site, tier):
		looks.append(extra)
	for look in looks:
		_public_building(str(look), spots, lots, heart, theta, index)
	# the houses fill the rest, close at the heart and thinning out to the edge
	var houses_lots: Array = []
	for key in lots:
		if streets[key] in ["lot", "yard"]:
			houses_lots.append(key)
	var want := clampf(houses * 3.5 / maxf(houses_lots.size(), 1.0), 0.75, 1.0)
	var organic := not planned
	for key in houses_lots:
		var p: Vector2 = lots[key][0]
		var local: Vector2 = lots[key][1]
		var edge_here: float = reach.call(local.angle())
		var out := clampf(local.length() / maxf(edge_here, 0.1), 0.0, 1.6)
		if s.rng.randf() > want * lerpf(1.25, 0.7, minf(out, 1.0)):
			if s.rng.randf() < 0.12 and s._dry(p, s.LOT * 0.4) and s._free(p, s.LOT * 0.4):   # a garden
				s._add("field", p, 0.0, -theta, Vector3(0.55, 1.0, 0.55), Color(0.46, 0.60, 0.30))
				s._claim(p, s.LOT * 0.4)
			continue
		# a house faces its street
		var face := -theta
		for step in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			if streets.get(key + step, "") in ["street", "plaza"]:
				face = -theta - Vector2(step).angle() + PI / 2.0
				break
		var jitter := Vector2.ZERO
		if organic:   # lanes wander; houses sit a little askew
			jitter = Vector2(s.rng.randf_range(-0.05, 0.05), s.rng.randf_range(-0.05, 0.05)) * s.LOT
			face += s.rng.randf_range(-0.25, 0.25)
		var big := lerpf(1.25, 0.85, minf(out, 1.0)) * s.rng.randf_range(0.92, 1.08)
		s._fit_house(p + jitter.rotated(theta), face, big, s.LOT * 0.44, index, 0.4)
	# by a river or the sea: wooden piers out over the water
	if sea != Vector2.ZERO:
		_piers(lots, theta, sea)
	if s.style == "nile" and site["capital"]:
		_pyramid(heart, half, index)
	if site["capital"]:
		for k in 3:
			s._chimneys.append(heart + Vector2(s.rng.randf_range(-half, half), s.rng.randf_range(-half, half)) * 0.5)


## The great buildings a city of this style and rank raises beside its houses (D-280), as
## "|m:module:kind" entries for `_public_building`.
func _landmarks(site: Dictionary, tier: int) -> Array:
	var out: Array = []
	var capital: bool = site["capital"]
	match s.style:
		"east":
			if capital or tier >= 2:
				out.append("|m:east:pagoda")
			if tier >= 1:
				out.append("|m:east:gate")
		"classical":
			if tier >= 2 or capital:
				out.append("|m:classical:forum_hall")
			if tier >= 3:
				out.append("|m:classical:triumphal_arch")
			if tier >= 3 or (capital and tier >= 2):
				out.append("|m:classical:villa_great")
		"northern":
			if tier >= 1 or capital:
				out.append("|m:northern:church")
			if tier >= 2:
				out.append("|m:northern:market_hall")
		"nile":
			if capital or tier >= 2:
				out.append("|m:south:obelisk")
			if capital and tier >= 2:
				out.append("|m:south:sphinx")
		"near_east":
			if tier >= 2 and not capital:
				out.append("|m:south:ziggurat")
		"south_asian":
			if capital or tier >= 2:
				out.append("|m:south:stupa")
			if tier >= 1:
				out.append("|m:south:temple_shikhara")
	return out


## A public building (D-111) on the best free plot by the square or a main street, facing it.
## "|works|look" is one going up (in scaffolding); "|pagoda" the pagoda of an eastern city.
func _public_building(look: String, spots: Array, lots: Dictionary, heart: Vector2, theta: float, index: int) -> void:
	var building := look
	var part := ""
	if look.begins_with("|m:"):
		var bits := look.split(":")
		part = s._model(bits[1], bits[2], s.GRAND_UNIT)
		if part == "":
			return
	elif look == "|pagoda":
		part = "f_pagoda"
	else:
		if look.begins_with("|works|"):
			building = look.substr(7)
		var entry_look: Array = Buildings.CITY_LOOKS.get(building, Buildings.CITY_LOOKS["hall"])
		var civic := str(s.CIVIC_OF.get(str(entry_look[0]), ""))
		part = s._model("civic", civic, s.CIVIC_UNIT) if civic != "" else ""
		if part == "":
			part = "b_" + building
		if not s._parts.has(part):
			var entry: Array = Buildings.CITY_LOOKS.get(building, Buildings.CITY_LOOKS["hall"])
			s._parts[part] = {"mesh": Buildings.city_building(building, float(entry[1]) * s.S), "transforms": [],
				"colours": [], "kit": true}
	var scale := 1.3 if part == "f_pagoda" else 1.0
	var r := s._foot(part) * scale
	for key in spots:
		var p: Vector2 = lots[key][0]
		if not s._dry(p, r) or not s._free(p, r):
			continue
		var face := -(heart - p).angle() + PI / 2.0 if p.distance_to(heart) > 0.1 else -theta
		if look.begins_with("|works|"):
			_scaffold_at(part, p, face, r, index)
		elif part.begins_with("m_civic_"):
			s._add(part, p, 0.0, face, Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.6)
		elif look.begins_with("|m:"):
			s._add(part, p, 0.0, face, Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.6)
		elif part == "f_pagoda":
			s._add(part, p, 0.0, -theta, Vector3.ONE * scale, Color(0.36, 0.38, 0.42), index, 0.3)
		else:
			s._add(part, p, 0.0, face, Vector3.ONE, Color(0.88, 0.55, 0.38), index, 0.4)
		s._claim(p, r)
		return


## Building work in a city (D-127): the new building half-risen in its place, wrapped in
## timber scaffolding, with a crane over it.
func _scaffold_at(part: String, spot: Vector2, face: float, r: float, index: int) -> void:
	s._add(part, spot, 0.0, face, Vector3(1.0, 0.55, 1.0), Color(0.88, 0.55, 0.38), index, 0.4)
	var timber := Color(0.62, 0.44, 0.26)
	var e := r * 0.8
	for corner in [Vector2(-e, -e), Vector2(e, -e), Vector2(e, e), Vector2(-e, e)]:
		s._add("pole", spot + corner, 0.0, 0.0, Vector3(1.6, 0.9, 1.6), timber)
	for height in [0.18, 0.4]:   # walkways of planks
		s._add("terrace", spot, height * s.S, face, Vector3(e * 2.0 / (0.7 * s.S), 0.2, e * 2.0 / (0.5 * s.S)), timber.lightened(0.1))
	var mast := spot + Vector2(e, 0)
	s._add("pole", mast, 0.0, 0.0, Vector3(2.0, 1.8, 2.0), timber.darkened(0.1))
	s._add("terrace", mast + Vector2(-e * 0.7, 0), 1.2 * s.S, 0.0, Vector3(1.1, 0.8, 0.1), timber.darkened(0.1))


## Walls along the city's own outline (Kenney castle kit): towers at the turns, a gatehouse
## where each road leaves, nothing where the water guards it. Roofs fly the owner's colours.
func _city_walls(centre: Vector2, theta: float, lots: Dictionary, streets: Dictionary, roads: Array, index: int) -> void:
	var sectors := 28
	var radius: Array = []
	radius.resize(sectors)
	radius.fill(0.0)
	for key in lots:
		if lots[key][2] != "lot":
			continue
		var local: Vector2 = lots[key][1]
		var k := posmod(int(round(local.angle() / TAU * sectors)), sectors)
		radius[k] = maxf(radius[k], local.length() + s.LOT * 0.75)
	var smooth: Array = []
	for k in sectors:   # an even line, not a saw
		var a: float = radius[(k + sectors - 1) % sectors]
		var b: float = radius[k]
		var c: float = radius[(k + 1) % sectors]
		smooth.append(maxf(b, (a + b + c) / 3.0) if b > 0.0 else 0.0)
	var corner_part := "k_round" if s.style in ["northern", "classical"] else "k_tower"
	var piece_width := 0.24 * s.S / 1.31   # the wall model's width for its height
	# the model kit's walls (D-280): one family per style, segments one unit long
	var family: String = {"east": "east", "classical": "classical", "northern": "northern", "nile": "mud",
		"near_east": "mud", "south_asian": "south_asian", "steppe": "steppe"}.get(s.style, "northern")
	var wall_part := s._model("walls", "wall_" + family, s.WALL_UNIT)
	var tower_part := s._model("walls", "tower_" + family, s.WALL_UNIT)
	var gate_part := s._model("walls", "gate_nile" if s.style == "nile" else "gate_" + family, s.WALL_UNIT)   # Egypt: a pylon
	var kit := wall_part != "" and tower_part != "" and gate_part != ""
	if kit:
		piece_width = s.WALL_UNIT
		corner_part = tower_part
	var gates := {}
	for a in roads:
		gates[posmod(int(round(float(a) / TAU * sectors)), sectors)] = true
	for k in sectors:
		var r0: float = smooth[k]
		var r1: float = smooth[(k + 1) % sectors]
		if r0 <= 0.0 or r1 <= 0.0:
			continue   # no city that way: the water is the wall
		var a := centre + Vector2(cos(k * TAU / sectors), sin(k * TAU / sectors)).rotated(theta) * r0
		var b := centre + Vector2(cos((k + 1) * TAU / sectors), sin((k + 1) * TAU / sectors)).rotated(theta) * r1
		var length := a.distance_to(b)
		var angle := -(b - a).angle()
		var pieces := maxi(1, int(ceil(length / piece_width)))
		for m in pieces:
			var p := a.lerp(b, (m + 0.5) / pieces)
			if s.earth.is_wet(p) or not s._free(p, piece_width * 0.3):
				continue
			var stretch := length / pieces / piece_width
			if kit:   # the battlements face out of the city (the model's +z), so turn it round
				if gates.has(k) and m == pieces / 2:
					s._add(gate_part, p, 0.0, angle + PI, Vector3(stretch, 1, 1), s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.9)
					s._claim(p, piece_width * 0.6)
					continue
				s._add(wall_part, p, 0.0, angle + PI, Vector3(stretch * 1.01, 1, 1), s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.9)
				continue
			if gates.has(k) and m == pieces / 2:
				s._add("k_gate", p, 0.0, angle, Vector3.ONE, Color.WHITE, index, 1.0)
				s._claim(p, piece_width * 0.8)
				continue
			s._add("k_wall", p, 0.0, angle, Vector3(stretch * 1.02, 1, 1), Color.WHITE, index, 1.0)
		if k % 3 == 0 and s._dry(a, piece_width * 0.4) and s._free(a, piece_width * 0.4):
			if kit:
				s._add(corner_part, a, 0.0, angle, Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.9)
			else:
				s._add(corner_part, a, 0.0, 0.0, Vector3.ONE, Color.WHITE, index, 1.0)
			s._claim(a, piece_width * 0.5)


## Wooden piers from the waterfront out over the water, where the harbour road meets it.
func _piers(lots: Dictionary, theta: float, sea: Vector2) -> void:
	var timber := Color(0.50, 0.36, 0.22)
	var made := 0
	var keys := lots.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return absf((lots[a][1] as Vector2).cross(Vector2.RIGHT)) < absf((lots[b][1] as Vector2).cross(Vector2.RIGHT)))
	for key in keys:
		if made >= 2:
			return
		var p: Vector2 = lots[key][0]
		var out := p + sea * s.LOT * 0.9
		if not s.earth.is_wet(out) or not s.earth.is_wet(out + sea * s.LOT):
			continue
		var shore := s.earth.ground_at_pixel(p).y
		for m in 3:
			var q := p + sea * s.LOT * (0.7 + m * 0.8)
			var lift := shore - s.earth.ground_at_pixel(q).y + 0.05
			s._add("terrace", q, lift, -sea.angle(), Vector3(0.35, 0.25, 0.12) * 4.0 / s.S, timber)
		made += 1


## A pyramid on the desert edge beyond a Nile capital: dry ground, away from the river.
func _pyramid(heart: Vector2, half: float, index: int) -> void:
	var r := 0.45 * s.S * 2.0
	for step in 16:
		var a := step * TAU / 16.0
		for dist in [half * 1.6, half * 2.0, half * 2.5]:
			var p := heart + Vector2(cos(a), sin(a)) * float(dist)
			if s._dry(p, r * 1.4) and s._free(p, r * 1.2):
				var model := s._model("south", "pyramid", s.GRAND_UNIT * 1.2)   # with its causeway (D-280)
				if model != "":
					s._add(model, p, 0.0, -(heart - p).angle() + PI / 2.0, Vector3.ONE, Color.WHITE, index, 0.0)
				else:
					s._add("pyramid", p, 0.0, PI / 4.0, Vector3.ONE, Color(0.84, 0.70, 0.46))
				s._claim(p, r * 1.2)
				s.clearings.append([p, r * 1.5])
				return
