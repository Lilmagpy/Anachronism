## Towns, villages and camps (D-279, D-281): everything outside the chief cities. Called by
## Settlements.build after every chief city is planned; `s` is the Settlements object.
extends RefCounted

var s: Settlements   ## the Settlements being built


func _init(settlements: Settlements) -> void:
	s = settlements


## The towns and villages of province `index`, spread over its good farmland `cells`.
func countryside(site: Dictionary, population: int, cells: Array, index: int) -> void:
	var towns := clampi(population / s.PEOPLE_PER_TOWN, 0, 12)
	var villages := clampi(population / s.PEOPLE_PER_VILLAGE, 1, s.MAX_VILLAGES)
	for i in towns:
		_village(cells, s.rng.randi_range(7, 14), true, index, 0.45)
	for i in villages:
		_village(cells, s.rng.randi_range(2, 5), s.rng.randf() < 0.6, index, 0.0)
	s.dressing.decorate("village", 0, index)

## A khan's camp: tents in loose rings around the great tent, none touching.
func _camp(site: Dictionary, centre: Vector2, half: float, tents: int, index: int) -> void:
	var court := s._palace_part() if site["capital"] else ""
	if court != "":   # the khan's court from the model kit, with its own standards (D-280)
		s._add(court, centre, 0.0, s.rng.randf() * TAU, Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.85)
		s._claim(centre, s._foot(court))
	else:
		if site["capital"]:
			s._palace(centre, index, 0.0)
		s._claim(centre, float(s.PALACE_R["steppe"]) * s.S)
		s._add("k_flag", centre + Vector2(s.LOT, -s.LOT), 0.0, 0.0, Vector3.ONE, Color.WHITE, index, 1.0)
	var placed := 0
	for attempt in tents * 4:
		if placed >= tents:
			break
		var ring := sqrt(s.rng.randf()) * half
		var a := s.rng.randf() * TAU
		var p := centre + Vector2(cos(a), sin(a)) * ring
		if s._fit_house(p, s.rng.randf() * TAU, s.rng.randf_range(0.9, 1.3), s.LOT * 0.45, index, 0.4, "camp"):
			placed += 1


## A town or village: a street or two of houses along a lane, its fields beyond, on the
## province's best farmland and clear of the cities and of each other.
func _village(cells: Array, houses: int, fields: bool, site: int, mix: float) -> void:
	var spacing := s.LOT * 0.95
	var reach := spacing * (houses / 2.0 + 1.0)
	var centre := Vector2.ZERO
	for attempt in 8:
		var p := s._pick(cells)
		if s._dry(p, spacing) and s._free(p, reach * 0.6):
			centre = p
			break
	if centre == Vector2.ZERO:
		return
	var lane := s.rng.randf() * PI
	var along := Vector2(cos(lane), sin(lane))
	var across := Vector2(-along.y, along.x)
	var bend := s.rng.randf_range(-0.04, 0.04)   # the lane curves gently
	var placed := 0
	for k in houses * 2:
		if placed >= houses:
			break
		var t := (k / 2 - houses / 4.0) * spacing
		var side := 1.0 if k % 2 == 0 else -1.0
		var p := centre + along * t + across * (side * spacing * 0.62 + bend * t * t)
		p += Vector2(s.rng.randf_range(-0.1, 0.1), s.rng.randf_range(-0.1, 0.1)) * spacing
		var face := -lane + (PI / 2.0 if side > 0.0 else -PI / 2.0) + s.rng.randf_range(-0.2, 0.2)
		if s._fit_house(p, face, s.rng.randf_range(0.85, 1.1), spacing * 0.45, site, mix, "town" if mix > 0.0 else "village"):
			placed += 1
	if placed == 0:
		return
	s.clearings.append([centre, reach * 0.7])
	if not fields:
		return
	var crops := [Color(0.86, 0.72, 0.30), Color(0.55, 0.70, 0.28), Color(0.74, 0.64, 0.30), Color(0.45, 0.62, 0.26)]
	var field_r := s._foot("field") * 1.05
	for k in houses + 2:
		var a := s.rng.randf() * TAU
		var p := centre + Vector2(cos(a), sin(a)) * (reach * 0.6 + s.rng.randf_range(0.3, 1.2) * s.S)
		if s._dry(p, field_r) and s._free(p, field_r):
			s._add("field", p, 0.0, -lane, Vector3.ONE, crops[s.rng.randi() % crops.size()])
			s._claim(p, field_r)
