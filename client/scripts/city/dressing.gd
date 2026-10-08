## The small things that make a place lived in (D-281): barrels, crates and sacks by the
## doors, woodpiles, carts, wells and troughs, fences and hedges round yards, shrubs, flower
## beds and fruit trees in the gardens, market stalls on the square, boats at the shore ...
## chosen for each people's way of life and for how grand the place is.
##
## After each settlement is planned Settlements.build calls `decorate`, which dresses the
## buildings placed since the last call (Settlements.placed). Props are model-kit models from
## models/props.gd, models/flora.gd and the region modules ("prop_*" kinds), placed with
## Settlements.prop(), which says false for a kind no module has (yet): every choice below is a
## list of alternatives, so a missing model is simply skipped or swapped.
##
## How it works, for each cluster of buildings (a village, a town, a city):
##   1. public buildings: stalls round a market, avenues at temples, planting at forecourts;
##   2. gates and walls: carts, signposts, timber inside, shrubs outside;
##   3. houses: door props, side clutter, yard (garden, animals, trees) and fenced yards,
##      tidier and sparser towards the rich heart, more cluttered towards the poor edge;
##   4. a well, shores (boats, nets, reeds), camps (tethers, wagons, flocks, cairn);
##   5. squares: stalls, a fountain, statue or cross at the middle;
##   6. the transition ring: shrubs, tufts, rocks and trees thinning out into the country.
## Everything keeps off streets, out of buildings and out of the water, and uses only s.rng.
extends RefCounted

## Show a small coloured dome where a model is missing (to judge placement before the models
## exist). Must stay false when committed.
const DEBUG := false

const BUCKET := 1.0
## Half-width of each prop in model units (1 = a house's width), for keeping them apart.
const PROP_RADIUS := {
	"barrel": 0.07, "barrels": 0.13, "crate": 0.09, "crates": 0.14, "sacks": 0.12, "pots": 0.12,
	"bench": 0.22, "woodpile": 0.22, "laundry": 0.3, "handcart": 0.28, "vegetable_patch": 0.28,
	"chickens": 0.15, "tree_fruit": 0.28, "beehives": 0.18, "haystack": 0.3, "cart": 0.4, "well": 0.2,
	"trough": 0.22, "cooking_fire": 0.15, "scarecrow": 0.1, "signpost": 0.08, "fence": 0.35,
	"wattle": 0.35, "stone_wall": 0.35, "hedge": 0.35, "gate_small": 0.15, "market_stall": 0.3,
	"statue": 0.2, "fountain": 0.4, "rocks": 0.2, "timber": 0.3, "boat": 0.45, "nets": 0.3,
	"shrub": 0.17, "shrub_flowering": 0.17, "bush": 0.22, "flowerbed": 0.25, "grass_tuft": 0.08,
	"reeds": 0.15, "tree_broadleaf": 0.4, "tree_small": 0.25, "cypress": 0.15, "olive": 0.3,
	"palm": 0.3, "palm_small": 0.22, "bamboo": 0.25, "pine": 0.3, "willow": 0.45, "cherry": 0.35,
	"vine_trellis": 0.25, "cow": 0.3, "sheep": 0.3, "goat": 0.15, "horse": 0.3, "camel": 0.35,
	"ox": 0.3, "prop_stone_lantern": 0.1, "prop_shrine": 0.25, "prop_torii": 0.35,
	"prop_lantern_post": 0.08, "prop_water_jars": 0.12, "prop_drying_rack": 0.3, "prop_amphorae": 0.12,
	"prop_altar": 0.22, "prop_herm": 0.08, "prop_fountain_basin": 0.4, "prop_pergola": 0.4,
	"prop_market_cross": 0.25, "prop_well_roofed": 0.25, "prop_runestone": 0.12, "prop_longboat": 0.8,
	"prop_stocks": 0.15, "prop_maypole": 0.2, "prop_horse_tether": 0.5, "prop_ovoo": 0.3,
	"prop_tug": 0.15, "prop_felt_rack": 0.3, "prop_wagon": 0.5, "prop_shaduf": 0.3,
	"prop_reed_boat": 0.4, "prop_rugs": 0.3, "prop_dovecote": 0.2, "prop_shrine_india": 0.25,
	"prop_bullock_cart": 0.45, "prop_tree_platform": 0.45}
## Kinds that reserve their ground against the planners (big, or in the way of later houses).
const CLAIMS := ["cart", "well", "boat", "fountain", "statue", "haystack", "market_stall", "tree_broadleaf",
	"willow", "pine", "olive", "palm", "tree_fruit", "cherry", "prop_longboat", "prop_wagon", "prop_reed_boat",
	"prop_well_roofed", "prop_bullock_cart", "prop_tree_platform", "prop_market_cross", "prop_fountain_basin",
	"prop_horse_tether", "prop_pergola", "prop_shrine"]
const HARD_AREAS := ["flag", "cobble", "sand"]   ## squares: no clutter, but stalls and statues belong there

var s: Settlements   ## the Settlements being built
var _from := 0       ## the first entry of s.placed not yet dressed
var _indexed := 0    ## entries of s.placed already in the building hash
var _bh := {}        ## bucket -> [[pos, r, what, yaw], ...]: every building, for keeping props out
var _ph := {}        ## bucket -> [[pos, r], ...]: props placed, so they do not stack
var _rgrid := {}     ## bucket -> [[a, b, half], ...]: street segments
var _agrid := {}     ## bucket -> [[polygon, lo, hi], ...]: paved squares
var _roads_done := 0
var _areas_done := 0
var _has_cache := {}
var _count := 0      ## props placed in the current settlement
var _budget := 0
var _fl := {}        ## this style's choices (see _flavour)
var _site := -1
var _boats := 0


func _init(settlements: Settlements) -> void:
	s = settlements


## Dress the settlement just planned: `kind` is "city", "town", "village" or "camp"; `tier`
## its rank (0 village .. 4 metropolis, D-127); `site` the province index (for owner colour).
func decorate(kind: String, tier: int, site: int) -> void:
	_index_buildings()
	var fresh: Array = []
	for i in range(_from, s.placed.size()):
		fresh.append(i)
	_from = s.placed.size()
	_site = site
	_flavour()
	var new_squares := _index_ground()
	if fresh.is_empty():
		return
	for cl in _clusters(fresh):
		_dress_cluster(cl, kind, tier, new_squares)


# --- bookkeeping -------------------------------------------------------------------------

func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / BUCKET), floori(p.y / BUCKET))


## Put every building placed so far in the hash that keeps props out of them.
func _index_buildings() -> void:
	for i in range(_indexed, s.placed.size()):
		var e: Dictionary = s.placed[i]
		var p: Vector2 = e["pos"]
		var r: float = e["r"]
		var reach := ceili(r / BUCKET) + 1
		var k := _key(p)
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				var kk := Vector2i(k.x + dx, k.y + dy)
				if not _bh.has(kk):
					_bh[kk] = []
				_bh[kk].append([p, r, e["what"], e["yaw"]])
	_indexed = s.placed.size()


## Learn the streets and squares the planners described since the last call. Returns the new
## squares as [polygon, lo, hi].
func _index_ground() -> Array:
	var roads: Variant = s.ground.get("roads")
	var areas: Variant = s.ground.get("areas")
	var squares: Array = []
	if roads is Array:
		var all_roads: Array = roads
		for i in range(_roads_done, all_roads.size()):
			var pts: PackedVector2Array = all_roads[i][0]
			var half: float = float(all_roads[i][1]) / 2.0
			for j in pts.size() - 1:
				var a := pts[j]
				var b := pts[j + 1]
				var lo := a.min(b) - Vector2.ONE * (half + 0.4)
				var hi := a.max(b) + Vector2.ONE * (half + 0.4)
				for kx in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
					for ky in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
						var kk := Vector2i(kx, ky)
						if not _rgrid.has(kk):
							_rgrid[kk] = []
						_rgrid[kk].append([a, b, half])
		_roads_done = all_roads.size()
	if areas is Array:
		var all_areas: Array = areas
		for i in range(_areas_done, all_areas.size()):
			var poly: PackedVector2Array = all_areas[i][0]
			if str(all_areas[i][1]) not in HARD_AREAS or poly.size() < 3:
				continue
			var lo := poly[0]
			var hi := poly[0]
			for q in poly:
				lo = lo.min(q)
				hi = hi.max(q)
			var item := [poly, lo, hi]
			squares.append(item)
			for kx in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
				for ky in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
					var kk := Vector2i(kx, ky)
					if not _agrid.has(kk):
						_agrid[kk] = []
					_agrid[kk].append(item)
		_areas_done = all_areas.size()
	return squares


func _on_road(p: Vector2, margin: float) -> bool:
	for item in _rgrid.get(_key(p), []):
		var closest := Geometry2D.get_closest_point_to_segment(p, item[0], item[1])
		if p.distance_to(closest) < float(item[2]) + margin:
			return true
	return false


func _in_square(p: Vector2) -> bool:
	for item in _agrid.get(_key(p), []):
		var lo: Vector2 = item[1]
		var hi: Vector2 = item[2]
		if p.x >= lo.x and p.y >= lo.y and p.x <= hi.x and p.y <= hi.y \
				and Geometry2D.is_point_in_polygon(p, item[0]):
			return true
	return false


## True when a building (walls as thin strips along their length) lies within `rad` of `p`.
func _in_building(p: Vector2, rad: float) -> bool:
	for b in _bh.get(_key(p), []):
		var bp: Vector2 = b[0]
		var br: float = b[1]
		var d := p - bp
		if d.length_squared() > (br + rad) * (br + rad):
			continue
		if str(b[2]) == "wall":
			var yaw: float = b[3]
			var along := d.dot(Vector2(cos(yaw), -sin(yaw)))
			var across := d.dot(Vector2(sin(yaw), cos(yaw)))
			if absf(along) < br + rad and absf(across) < 0.22 + rad:
				return true
			continue
		return true
	return false


func _crowded(p: Vector2, rad: float) -> bool:
	for q in _ph.get(_key(p), []):
		if (q[0] as Vector2).distance_to(p) < (float(q[1]) + rad) * 0.75:
			return true
	return false


func _wet(p: Vector2, rad: float) -> bool:
	if s.earth.is_wet(p):
		return true
	for k in 4:
		if s.earth.is_wet(p + Vector2.from_angle(k * PI / 2.0 + 0.4) * rad):
			return true
	return false


## True when a prop of radius `rad` may stand at `p`: dry, off the streets (and the squares
## unless `paved`), clear of buildings and of other props; with `open`, also clear of ground the
## planners claimed (fields and such); with `shore`, only its own spot must be dry.
func _ok(p: Vector2, rad: float, paved := false, open := false, shore := false) -> bool:
	if shore:
		if s.earth.is_wet(p):
			return false
	elif _wet(p, rad):
		return false
	if _in_building(p, rad) or _crowded(p, rad) or _on_road(p, rad * 0.6 + 0.02):
		return false
	if not paved and _in_square(p):
		return false
	if open and not s._free(p, rad * 0.5):
		return false
	return true


## Does any module have this model? (Cached; in DEBUG every kind counts, drawn as a marker.)
func _has(kind: String) -> bool:
	if DEBUG:
		return true
	if not _has_cache.has(kind):
		var found := false
		var region: String = s.REGION_MODULE.get(s.style, "")
		for module in ["props", "flora", region]:
			if module != "" and s._model(module, kind, s.HOUSE_UNIT) != "":
				found = true
				break
		_has_cache[kind] = found
	return _has_cache[kind]


## The first of `kinds` (starting from a random one) that exists; "" if none do.
func _choose(kinds: Array) -> String:
	if kinds.is_empty():
		return ""
	var start := s.rng.randi() % kinds.size()
	for i in kinds.size():
		var k: String = kinds[(start + i) % kinds.size()]
		if _has(k):
			return k
	return ""


func _radius(kind: String, size: float) -> float:
	return float(PROP_RADIUS.get(kind, 0.15)) * s.HOUSE_UNIT * size


## Place a prop of the first existing kind in `kinds` at `p` if the ground is fit for it.
func _put(kinds: Array, p: Vector2, yaw: float, size := 1.0, paved := false, open := false,
		shore := false) -> bool:
	if _count >= _budget:
		return false
	var kind := _choose(kinds)
	if kind == "":
		return false
	var rad := _radius(kind, size)
	if not _ok(p, rad, paved, open, shore):
		return false
	_place(kind, p, yaw, size, rad)
	return true


func _place(kind: String, p: Vector2, yaw: float, size: float, rad: float) -> void:
	if not s.prop(kind, p, yaw, size, _site):
		if not DEBUG:
			return
		var colour := Color.from_hsv(float(hash(kind) % 97) / 97.0, 0.8, 0.95)
		s._add("dome", p, 0.0, 0.0, Vector3.ONE * (rad / 1.28), colour)
	_count += 1
	var key := _key(p)
	if not _ph.has(key):
		_ph[key] = []
	_ph[key].append([p, rad])
	if kind in CLAIMS:
		s._claim(p, rad * 0.7)


## A row of fence-like pieces (1.0 model units long) from `a` to `b`, placed only where the
## ground allows; skipped altogether when most of it would not fit (a half fence looks odd).
## `gap` leaves that fraction of the middle open (a doorway).
func _run(a: Vector2, b: Vector2, kinds: Array, size: float, gap := 0.0) -> void:
	var kind := _choose(kinds)
	if kind == "":
		return
	var step := s.HOUSE_UNIT * size
	var n := maxi(1, roundi(a.distance_to(b) / step))
	var yaw := atan2(-(b - a).y, (b - a).x)
	var rad := _radius(kind, size)
	var spots: Array = []
	for i in n:
		var t := (i + 0.5) / n
		if absf(t - 0.5) < gap:
			continue
		var p := a.lerp(b, t)
		if _ok(p, rad * 0.8):
			spots.append(p)
	if spots.size() < n * 0.6:
		return
	for p in spots:
		if _count >= _budget:
			return
		_place(kind, p, yaw, size, rad * 0.8)


# --- this people's choices ---------------------------------------------------------------

## Fill `_fl` with the kinds of props this style of settlement uses.
func _flavour() -> void:
	var door := ["barrel", "barrels", "crate", "crates", "sacks", "pots", "bench", "barrel", "pots"]
	var tidy := ["pots", "bench", "shrub", "pots", "flowerbed", "shrub_flowering"]
	var side := ["woodpile", "laundry", "handcart", "woodpile", "trough", "timber"]
	var yard_rural := ["vegetable_patch", "vegetable_patch", "chickens", "tree_fruit", "beehives",
		"haystack", "vegetable_patch", "goat", "scarecrow"]
	var yard_urban := ["flowerbed", "shrub", "tree_small", "tree_fruit", "vegetable_patch", "bush"]
	var trees := ["tree_broadleaf", "tree_small"]
	var big_trees := ["tree_broadleaf"]
	var shrubs := ["shrub", "bush", "grass_tuft", "shrub_flowering", "grass_tuft"]
	var fence := ["fence"]
	var temple := ["cypress"]
	var centre := ["statue", "fountain"]
	var civic := ["statue"]
	var animals := ["sheep", "cow", "goat", "sheep", "ox"]
	match s.style:
		"classical":
			door += ["prop_amphorae", "prop_amphorae"]
			tidy += ["prop_amphorae", "prop_herm", "vine_trellis"]
			yard_rural += ["vine_trellis", "tree_fruit"]
			yard_urban += ["vine_trellis", "prop_pergola"]
			trees = ["olive", "olive", "cypress", "tree_small", "tree_fruit"]
			big_trees = ["olive", "cypress", "pine"]
			fence = ["stone_wall", "stone_wall", "hedge", "fence"]
			temple = ["cypress"]
			centre = ["fountain", "prop_fountain_basin", "statue", "prop_herm"]
			civic = ["prop_altar", "statue"]
		"nile":
			door += ["prop_water_jars", "prop_water_jars", "pots"]
			tidy += ["prop_water_jars"]
			yard_rural += ["prop_shaduf", "prop_dovecote"]
			trees = ["palm", "palm", "palm_small", "tree_small"]
			big_trees = ["palm", "palm_small"]
			shrubs = ["shrub", "bush", "grass_tuft", "reeds", "grass_tuft"]
			fence = ["stone_wall", "wattle"]
			temple = ["palm", "palm_small"]
			centre = ["statue", "prop_water_jars", "fountain"]
			civic = ["statue", "prop_water_jars"]
		"near_east":
			door += ["prop_water_jars", "prop_rugs", "pots"]
			tidy += ["prop_water_jars", "vine_trellis"]
			yard_rural += ["prop_dovecote", "vine_trellis"]
			yard_urban += ["prop_dovecote", "vine_trellis"]
			trees = ["palm", "palm_small", "olive", "tree_small", "tree_fruit"]
			big_trees = ["palm", "olive"]
			fence = ["stone_wall", "stone_wall", "wattle"]
			temple = ["palm", "cypress"]
			centre = ["fountain", "prop_fountain_basin", "statue"]
			civic = ["prop_rugs", "statue"]
		"south_asian":
			door += ["prop_water_jars", "pots"]
			tidy += ["prop_water_jars", "flowerbed"]
			yard_rural += ["prop_bullock_cart", "vine_trellis"]
			trees = ["palm", "tree_broadleaf", "tree_fruit", "bamboo", "palm_small"]
			big_trees = ["tree_broadleaf", "palm"]
			fence = ["wattle", "hedge", "stone_wall"]
			temple = ["palm", "tree_broadleaf"]
			centre = ["prop_tree_platform", "fountain"]
			civic = ["prop_shrine_india", "statue"]
		"northern":
			door += ["woodpile", "barrels"]
			yard_rural += ["cow", "haystack"]
			trees = ["tree_broadleaf", "pine", "willow", "tree_small", "tree_fruit"]
			big_trees = ["tree_broadleaf", "pine", "willow"]
			shrubs = ["shrub", "bush", "grass_tuft", "bush", "rocks"]
			fence = ["wattle", "wattle", "hedge", "fence"]
			temple = ["pine", "tree_broadleaf"]
			centre = ["prop_market_cross", "prop_well_roofed", "prop_maypole"]
			civic = ["prop_stocks", "prop_market_cross"]
		"steppe":
			trees = ["tree_small"]
			big_trees = ["tree_small"]
			shrubs = ["grass_tuft", "grass_tuft", "bush", "rocks", "shrub"]
			animals = ["sheep", "goat", "horse", "sheep", "camel"]
		_:   # east
			door += ["prop_water_jars", "prop_lantern_post"]
			tidy += ["prop_stone_lantern", "prop_water_jars", "bamboo"]
			yard_rural += ["prop_drying_rack", "tree_fruit"]
			yard_urban += ["prop_stone_lantern", "bamboo", "cherry"]
			if s.culture in ["samurai", "joseon", "yamato"]:
				trees = ["pine", "cherry", "pine", "tree_small", "bamboo"]
				big_trees = ["pine", "cherry"]
				temple = ["pine", "cherry"]
			else:
				trees = ["bamboo", "willow", "cherry", "tree_small", "pine", "tree_fruit"]
				big_trees = ["pine", "willow", "bamboo"]
				temple = ["pine", "cypress"]
			fence = ["fence", "fence", "wattle", "hedge"]
			centre = ["prop_stone_lantern", "prop_shrine", "statue"]
			civic = ["prop_stone_lantern", "prop_shrine"]
	_fl = {"door": door, "tidy": tidy, "side": side, "yard_rural": yard_rural, "yard_urban": yard_urban,
		"trees": trees, "big_trees": big_trees, "shrubs": shrubs, "fence": fence, "temple": temple,
		"centre": centre, "civic": civic, "animals": animals}


# --- clusters ----------------------------------------------------------------------------

## Group the new buildings into settlements: ones whose edges nearly touch belong together.
## Each cluster: {ids, c (centre of its houses), R (how far the houses reach), houses}.
func _clusters(fresh: Array) -> Array:
	var parent: Array = []
	var grid := {}
	for n in fresh.size():
		parent.append(n)
		var pos: Vector2 = s.placed[fresh[n]]["pos"]
		var key := Vector2i(floori(pos.x / 3.0), floori(pos.y / 3.0))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(n)
	for n in fresh.size():
		var e: Dictionary = s.placed[fresh[n]]
		var pos: Vector2 = e["pos"]
		var key := Vector2i(floori(pos.x / 3.0), floori(pos.y / 3.0))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for m in grid.get(Vector2i(key.x + dx, key.y + dy), []):
					if m <= n:
						continue
					var o: Dictionary = s.placed[fresh[m]]
					var reach := minf(float(e["r"]), 1.0) + minf(float(o["r"]), 1.0) + 0.9
					var opos: Vector2 = o["pos"]
					if pos.distance_to(opos) < reach:
						var ra := _root(parent, n)
						var rb := _root(parent, m)
						if ra != rb:
							parent[maxi(ra, rb)] = mini(ra, rb)
	var groups := {}
	for n in fresh.size():
		var root := _root(parent, n)
		if not groups.has(root):
			groups[root] = []
		groups[root].append(fresh[n])
	var out: Array = []
	var roots := groups.keys()
	roots.sort()
	for root in roots:
		var ids: Array = groups[root]
		var homes: Array = []
		for i in ids:
			if str(s.placed[i]["what"]) in ["house", "tent"]:
				homes.append(i)
		var basis: Array = homes if not homes.is_empty() else ids
		var sum := Vector2.ZERO
		for i in basis:
			sum += s.placed[i]["pos"] as Vector2
		var c: Vector2 = sum / basis.size()
		var dists: Array = []
		for i in basis:
			dists.append((s.placed[i]["pos"] as Vector2).distance_to(c))
		dists.sort()
		var reach: float = maxf(float(dists[mini(dists.size() - 1, int(dists.size() * 0.85))]), 0.8)
		out.append({"ids": ids, "c": c, "R": reach, "houses": homes.size()})
	return out


func _root(parent: Array, n: int) -> int:
	var x := n
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


## How many other buildings stand within `near` of `p`, and the way from their middle to `p`
## (so, the way out).
func _outward(p: Vector2, near: float) -> Array:
	var sum := Vector2.ZERO
	var n := 0
	var lo := _key(p - Vector2.ONE * near)
	var hi := _key(p + Vector2.ONE * near)
	for kx in range(lo.x, hi.x + 1):
		for ky in range(lo.y, hi.y + 1):
			for b in _bh.get(Vector2i(kx, ky), []):
				var bp: Vector2 = b[0]
				if bp != p and bp.distance_to(p) < near and str(b[2]) in ["house", "tent", "public", "palace"]:
					sum += bp
					n += 1
	if n == 0:
		return [0, Vector2.ZERO]
	return [n, p - sum / n]


# --- one settlement ----------------------------------------------------------------------

func _dress_cluster(cl: Dictionary, kind: String, tier: int, squares: Array) -> void:
	var ids: Array = cl["ids"]
	var houses: int = cl["houses"]
	var camp := s.style == "steppe" or kind == "camp"
	_count = 0
	_boats = 0
	_budget = clampi(24 + houses * 9 + tier * 6, 24, 2200)
	var c: Vector2 = cl["c"]
	var rural := houses < 9
	# the grand and civic buildings first, so they get the best of the budget
	for i in ids:
		var e: Dictionary = s.placed[i]
		if str(e["what"]) in ["public", "palace"]:
			_civic(e, tier)
	for i in ids:
		var e: Dictionary = s.placed[i]
		match str(e["what"]):
			"gate":
				_gate(e, cl)
			"wall":
				_wall(e, cl)
			"house", "tent":
				if camp:
					_tent(e, houses)
				else:
					_home(e, cl, rural)
	if camp:
		_camp_extras(cl)
	elif houses < 40:
		_well(cl)
	for sq in squares:
		var mid := ((sq[1] as Vector2) + (sq[2] as Vector2)) / 2.0
		if mid.distance_to(c) < float(cl["R"]) * 1.6 + 2.0:
			_square(sq, tier)
	_ring(cl, rural, camp)


## A house's frame: its door at the front, the sides, the yard behind.
func _home(e: Dictionary, cl: Dictionary, rural: bool) -> void:
	var pos: Vector2 = e["pos"]
	var yaw: float = e["yaw"]
	var r := clampf(float(e["r"]), 0.15, 0.7)
	var f := Vector2(sin(yaw), cos(yaw))
	var lat := Vector2(f.y, -f.x)
	var u := clampf(pos.distance_to(cl["c"]) / float(cl["R"]), 0.0, 1.4)
	var base := 0.55 if int(cl["houses"]) < 9 else (0.3 if int(cl["houses"]) < 40 else 0.05)
	var poor := clampf(base + 0.45 * u + s.rng.randf_range(-0.1, 0.1), 0.0, 1.0)
	# at the door
	var n_door := s.rng.randi_range(0, 1) + (1 if s.rng.randf() < poor else 0)
	for i in n_door:
		var sd := 1.0 if s.rng.randf() < 0.5 else -1.0
		var p := pos + f * (r * 0.9 + 0.08 + s.rng.randf() * 0.08) + lat * (sd * r * s.rng.randf_range(0.35, 0.85))
		var list: Array = _fl["door"] if poor > 0.3 else _fl["tidy"]
		_put(list, p, yaw + s.rng.randf_range(-0.7, 0.7), s.rng.randf_range(0.9, 1.15))
	# at the side
	if s.rng.randf() < 0.1 + 0.6 * poor:
		var sd := 1.0 if s.rng.randf() < 0.5 else -1.0
		var p := pos + lat * (sd * (r + 0.14 + s.rng.randf() * 0.1)) + f * (r * s.rng.randf_range(-0.4, 0.3))
		var list: Array = _fl["side"] if poor > 0.35 else ["laundry", "bench", "woodpile"]
		_put(list, p, yaw + sd * PI / 2.0 + s.rng.randf_range(-0.25, 0.25), s.rng.randf_range(0.9, 1.1))
	# in the yard behind
	var n_yard := s.rng.randi_range(0, 1) + (s.rng.randi_range(0, 2) if poor > 0.4 else 0)
	for i in n_yard:
		var p := pos - f * (r + 0.2 + s.rng.randf() * 0.3) + lat * (s.rng.randf_range(-1.0, 1.0) * r * 0.9)
		var list: Array = _fl["yard_rural"] if (rural or poor > 0.6) else _fl["yard_urban"]
		_put(list, p, yaw + s.rng.randf_range(-0.3, 0.3), s.rng.randf_range(0.9, 1.2), false, true)
	# a fenced yard (more in the country)
	if s.rng.randf() < 0.1 + 0.55 * poor:
		_enclosure(pos, yaw, r, poor)
	# a tree now and again, to break up the rows
	if s.rng.randf() < 0.18 + 0.2 * poor:
		var p := pos - f * (r + 0.55 + s.rng.randf() * 0.4) + lat * s.rng.randf_range(-0.7, 0.7)
		_put(_fl["trees"], p, s.rng.randf() * TAU, s.rng.randf_range(0.85, 1.2), false, true)
	_shore(pos, r, cl)


## Fence, wall or hedge round the back and sides of a yard.
func _enclosure(pos: Vector2, yaw: float, r: float, poor: float) -> void:
	var f := Vector2(sin(yaw), cos(yaw))
	var lat := Vector2(f.y, -f.x)
	var fence: Array = [_choose(_fl["fence"])]
	if fence[0] == "":
		return
	var size := s.rng.randf_range(0.9, 1.1)
	var hw := r + 0.3
	var back := r + 0.55 + s.rng.randf() * 0.25
	var front := r * 0.5
	var b1 := pos - f * back - lat * hw
	var b2 := pos - f * back + lat * hw
	var a1 := pos + f * front - lat * hw
	var a2 := pos + f * front + lat * hw
	_run(b1, b2, fence, size)
	if s.rng.randf() < 0.75:
		_run(a1, b1, fence, size)
	if s.rng.randf() < 0.75:
		_run(a2, b2, fence, size)
	if poor > 0.5 and s.rng.randf() < 0.3:
		_run(a1, a2, fence, size, 0.2)   # a front fence with a gap for the door


# --- shores ------------------------------------------------------------------------------

## Boats, nets and reeds where a house stands near water.
func _shore(pos: Vector2, r: float, cl: Dictionary) -> void:
	if s.rng.randf() > 0.5:
		return
	var best := 99.0
	var best_dir := Vector2.ZERO
	for k in 8:
		var dir := Vector2.from_angle(k * TAU / 8.0 + 0.2)
		for dist in [0.4, 0.8, 1.3]:
			if s.earth.is_wet(pos + dir * dist):
				if dist < best:
					best = dist
					best_dir = dir
				break
	if best_dir == Vector2.ZERO:
		return
	# the last dry ground on the way to the water
	var shore_p := pos
	var t := r
	while t < best + 0.3:
		var q := pos + best_dir * t
		if s.earth.is_wet(q):
			break
		shore_p = q
		t += 0.05
	var along := best_dir.rotated(PI / 2.0)
	var yaw_along := atan2(-along.y, along.x)
	var boat_list := ["boat"]
	if s.style == "nile":
		boat_list = ["prop_reed_boat", "boat"]
	elif s.culture in ["viking", "norse"] and _boats == 0 and s.rng.randf() < 0.5:
		boat_list = ["prop_longboat", "boat"]
	if _boats < maxi(1, int(cl["houses"]) / 5):
		if _put(boat_list, shore_p, yaw_along + s.rng.randf_range(-0.3, 0.3), s.rng.randf_range(0.9, 1.1), false, false, true):
			_boats += 1
	if s.rng.randf() < 0.5:
		_put(["nets", "prop_drying_rack"], shore_p - best_dir * 0.25 + along * s.rng.randf_range(0.2, 0.5),
			yaw_along, 1.0, false, false, true)
	var reed_n := s.rng.randi_range(1, 3) if s.style != "nile" else s.rng.randi_range(3, 5)
	for i in reed_n:
		var p := shore_p + along * (i - reed_n / 2.0) * 0.18 + best_dir * s.rng.randf_range(-0.05, 0.1)
		_put(["reeds", "grass_tuft"], p, s.rng.randf() * TAU, s.rng.randf_range(0.8, 1.2), false, false, true)


# --- gates and walls ---------------------------------------------------------------------

## Outside a gate: a signpost, a cart and goods; inside, timber stacked.
func _gate(e: Dictionary, cl: Dictionary) -> void:
	var pos: Vector2 = e["pos"]
	var yaw: float = e["yaw"]
	var out := (pos - (cl["c"] as Vector2)).normalized()
	if out == Vector2.ZERO:
		out = Vector2(sin(yaw), cos(yaw))
	var side := Vector2(out.y, -out.x)
	var r := clampf(float(e["r"]), 0.3, 0.9)
	var sd := 1.0 if s.rng.randf() < 0.5 else -1.0
	var yaw_out := atan2(out.x, out.y)
	_put(["signpost"], pos + out * (r + 0.35) + side * (sd * (0.7 + s.rng.randf() * 0.3)), yaw_out + PI)
	var carts: Array = ["cart", "handcart", "crates", "barrels"]
	if s.style == "south_asian":
		carts = ["prop_bullock_cart", "cart", "crates"]
	for k in s.rng.randi_range(1, 3):
		var p := pos + out * (r + 0.3 + s.rng.randf() * 0.8) + side * (-sd * (0.6 + s.rng.randf() * 0.7))
		_put(carts if k == 0 else ["crate", "crates", "barrels", "sacks", "barrel"], p,
			s.rng.randf() * TAU, s.rng.randf_range(0.9, 1.1))
	if s.rng.randf() < 0.5:
		_put(["timber", "woodpile", "barrels"], pos - out * (r + 0.3) + side * (sd * 0.8), yaw)


## Along a wall: stacks against the inner face now and then, planting at the outer foot.
func _wall(e: Dictionary, cl: Dictionary) -> void:
	var pos: Vector2 = e["pos"]
	var yaw: float = e["yaw"]
	var out := (pos - (cl["c"] as Vector2)).normalized()
	var face := Vector2(sin(yaw), cos(yaw))
	var normal := face if face.dot(out) >= 0.0 else -face   # the wall's outer side
	var roll := s.rng.randf()
	if roll < 0.14:
		_put(["woodpile", "timber", "barrels", "crates", "haystack"], pos - normal * 0.42, yaw + s.rng.randf_range(-0.2, 0.2))
	elif roll < 0.4:
		_put(_fl["shrubs"] + ["bush", "rocks"], pos + normal * 0.4 + normal.rotated(PI / 2.0) * s.rng.randf_range(-0.3, 0.3),
			s.rng.randf() * TAU, s.rng.randf_range(0.8, 1.2), false, true)


# --- public buildings --------------------------------------------------------------------

## Dress a public building by what it is: stalls round a market, goods round a granary or
## workshop, and for a temple or palace an avenue at the front and planted forecourt.
func _civic(e: Dictionary, tier: int) -> void:
	var pos: Vector2 = e["pos"]
	var yaw: float = e["yaw"]
	var r := clampf(float(e["r"]), 0.3, 2.5)
	var f := Vector2(sin(yaw), cos(yaw))
	var lat := Vector2(f.y, -f.x)
	var part := str(e["part"])
	var big := tier >= 2 or r > 1.0
	if "market" in part or "harbour" in part:
		for i in s.rng.randi_range(3, 5) + (2 if big else 0):
			var dir := Vector2.from_angle(s.rng.randf() * TAU)
			var p := pos + dir * (r + 0.35 + s.rng.randf() * 0.5)
			var out_yaw := atan2(dir.x, dir.y)   # the stall faces away from the hall
			if _put(["market_stall", "market_stall", "prop_rugs"], p, out_yaw, 1.0, true):
				_put(["crates", "barrels", "sacks", "pots", "prop_amphorae", "prop_water_jars"],
					p + dir.rotated(PI / 2.0) * 0.35, out_yaw, 1.0, true)
		if "harbour" in part:
			_put(["boat"], pos + f * (r + 0.6), yaw, 1.0, false, false, true)
			_put(["nets", "barrels", "crates"], pos - lat * (r + 0.4), yaw)
		return
	if "granary" in part:
		for i in s.rng.randi_range(2, 4):
			_put(["sacks", "cart", "haystack", "crates", "handcart"],
				pos + Vector2.from_angle(s.rng.randf() * TAU) * (r + 0.35 + s.rng.randf() * 0.3), s.rng.randf() * TAU)
		return
	if "workshop" in part or "forge" in part or "factory" in part or "mine" in part:
		for i in s.rng.randi_range(2, 4):
			_put(["timber", "woodpile", "barrels", "crates", "cart"],
				pos + Vector2.from_angle(s.rng.randf() * TAU) * (r + 0.3 + s.rng.randf() * 0.3), s.rng.randf() * TAU)
		return
	if "windmill" in part or "water_wheel" in part:
		for i in 2:
			_put(["sacks", "haystack", "reeds", "cart"],
				pos + Vector2.from_angle(s.rng.randf() * TAU) * (r + 0.3 + s.rng.randf() * 0.3), s.rng.randf() * TAU)
		return
	var grand := big or "temple" in part or "palace" in part or "pagoda" in part or "shrine" in part \
			or str(e["what"]) == "palace"
	if not grand:
		for i in 2:
			_put(_fl["tidy"], pos + f * (r + 0.2) + lat * s.rng.randf_range(-0.8, 0.8) * r, yaw)
		return
	# an avenue of cypress, palm, pine or lanterns up to the front
	var pairs := 2 + (1 if big else 0) + (1 if tier >= 3 else 0)
	var gap := 0.6 + (0.1 if s.style in ["classical", "south_asian"] else 0.0)
	for k in pairs:
		for sd in [-1.0, 1.0]:
			var p: Vector2 = pos + f * (r + 0.45 + k * gap) + lat * (sd * (0.45 + r * 0.35))
			if s.style == "east" and k % 2 == 0:
				_put(["prop_stone_lantern"] + (_fl["temple"] as Array), p, yaw)
			else:
				_put(_fl["temple"], p, s.rng.randf() * TAU, s.rng.randf_range(0.95, 1.2))
	# planting at the corners and a feature in the forecourt
	for sd in [-1.0, 1.0]:
		_put(["shrub_flowering", "shrub", "bush"] + (["flowerbed"] if big else []),
			pos + f * (r * 0.9 + 0.2) + lat * (sd * (r + 0.2)), yaw, 1.1)
		if big:
			_put(_fl["trees"], pos - f * (r * 0.4) + lat * (sd * (r + 0.55)), s.rng.randf() * TAU, 1.1, false, true)
	if big and s.rng.randf() < 0.6:
		_put(_fl["civic"], pos + f * (r + 0.5) + lat * s.rng.randf_range(-0.3, 0.3), yaw, 1.0)
	if s.style == "east" and (tier >= 2 or "shrine" in part or "temple" in part):
		_put(["prop_shrine", "prop_torii"], pos + f * (r + 0.6 + pairs * gap), yaw, 1.0)
	_put(["bench", "pots"], pos + f * (r + 0.15) + lat * (r * 0.8), yaw)


# --- squares -----------------------------------------------------------------------------

## A paved square: a fountain, statue or cross at the middle (its people's way), market stalls
## about it with goods beside, a few benches and pots.
func _square(sq: Array, tier: int) -> void:
	var poly: PackedVector2Array = sq[0]
	var lo: Vector2 = sq[1]
	var hi: Vector2 = sq[2]
	var size := hi - lo
	if size.x < 0.8 or size.y < 0.8:
		return
	var mid := (lo + hi) / 2.0
	var best := Vector2.ZERO
	var best_d := 99.0
	for i in 24:
		var p := mid + Vector2(s.rng.randf_range(-0.5, 0.5) * size.x, s.rng.randf_range(-0.5, 0.5) * size.y) * 0.7
		var d := p.distance_to(mid)
		if d < best_d and Geometry2D.is_point_in_polygon(p, poly) and _ok(p, 0.45, true, true):
			best = p
			best_d = d
	if best_d < 99.0 and (tier >= 1 or size.x > 1.5):
		_put(_fl["centre"], best, s.rng.randf() * TAU, 1.0, true)
		if s.style == "south_asian" and _has("prop_tree_platform"):
			_put(["tree_broadleaf"], best, 0.0, 1.0, true)   # the sacred tree the platform rings
	var stalls := clampi(int(size.x * size.y * 2.0), 1, 4 + tier * 3)
	for i in stalls * 3:
		if stalls <= 0:
			break
		var p := lo + Vector2(s.rng.randf() * size.x, s.rng.randf() * size.y)
		if not Geometry2D.is_point_in_polygon(p, poly) or p.distance_to(mid) < 0.5:
			continue
		var face := atan2((mid - p).x, (mid - p).y)   # the stall faces the middle
		if _put(["market_stall", "market_stall", "prop_rugs"], p, face, 1.0, true):
			stalls -= 1
			_put(["crates", "barrels", "sacks", "pots", "barrel", "prop_amphorae"],
				p + Vector2(cos(face), -sin(face)) * 0.35, face, 1.0, true)
	for i in 4:
		var p := lo + Vector2(s.rng.randf() * size.x, s.rng.randf() * size.y)
		if Geometry2D.is_point_in_polygon(p, poly):
			_put(["bench", "pots", "shrub", "barrel"], p, s.rng.randf() * TAU, 1.0, true)


## A well, a trough and a tree where a village's houses gather.
func _well(cl: Dictionary) -> void:
	var c: Vector2 = cl["c"]
	var wells: Array = ["well", "trough"]
	if s.style == "northern":
		wells = ["prop_well_roofed", "well"]
	for attempt in 14:
		var p := c + Vector2.from_angle(s.rng.randf() * TAU) * s.rng.randf_range(0.0, 0.6) * float(cl["R"])
		if _put(wells, p, s.rng.randf() * TAU, 1.0, false, true):
			_put(["trough", "bench", "barrels", "pots"], p + Vector2.from_angle(s.rng.randf() * TAU) * 0.4,
				s.rng.randf() * TAU)
			if int(cl["houses"]) >= 4 and s.rng.randf() < 0.6:
				_put(_fl["trees"], p + Vector2.from_angle(s.rng.randf() * TAU) * 0.6, s.rng.randf() * TAU, 1.2, false, true)
			return


# --- camps -------------------------------------------------------------------------------

## A tent: a felt rack at its side, a cooking fire before it; the great tent gets its standard.
func _tent(e: Dictionary, houses: int) -> void:
	var pos: Vector2 = e["pos"]
	var yaw: float = e["yaw"]
	var r := clampf(float(e["r"]), 0.2, 1.5)
	var f := Vector2(sin(yaw), cos(yaw))
	var lat := Vector2(f.y, -f.x)
	if r > 0.9:
		_put(["prop_tug"], pos + f * (r + 0.25) + lat * 0.3, yaw)
		_put(["prop_tug"], pos + f * (r + 0.25) - lat * 0.3, yaw)
		_put(["prop_horse_tether"], pos + lat * (r + 0.9), yaw + PI / 2.0)
		_put(["cooking_fire"], pos + f * (r + 0.8), 0.0)
		return
	if s.rng.randf() < 0.5:
		_put(["cooking_fire", "cooking_fire", "barrels"], pos + f * (r + 0.2 + s.rng.randf() * 0.2) + lat * s.rng.randf_range(-0.2, 0.2), 0.0)
	if s.rng.randf() < 0.45:
		var sd := 1.0 if s.rng.randf() < 0.5 else -1.0
		_put(["prop_felt_rack", "prop_drying_rack", "woodpile"], pos + lat * (sd * (r + 0.28)), yaw + sd * PI / 2.0)
	if s.rng.randf() < 0.3:
		_put(["sacks", "barrels", "crates", "horse"], pos - f * (r + 0.25) + lat * s.rng.randf_range(-0.3, 0.3), s.rng.randf() * TAU)
	if houses > 0 and s.rng.randf() < 0.1:
		_put(["horse"], pos - f * (r + 0.5), s.rng.randf() * TAU)


## Tethered horses and wagons among the tents, flocks grazing outside, a cairn on a rise.
func _camp_extras(cl: Dictionary) -> void:
	var c: Vector2 = cl["c"]
	var reach: float = cl["R"]
	var houses: int = cl["houses"]
	for k in clampi(houses / 5, 1, 6):
		_put(["prop_horse_tether"], c + Vector2.from_angle(s.rng.randf() * TAU) * reach * s.rng.randf_range(0.3, 0.9), s.rng.randf() * TAU)
	for k in clampi(houses / 6, 1, 5):
		_put(["prop_wagon", "cart"], c + Vector2.from_angle(s.rng.randf() * TAU) * reach * s.rng.randf_range(0.7, 1.2), s.rng.randf() * TAU)
	for k in clampi(houses / 2, 2, 24):
		_put(_fl["animals"], c + Vector2.from_angle(s.rng.randf() * TAU) * (reach + s.rng.randf_range(0.5, 2.2)),
			s.rng.randf() * TAU, s.rng.randf_range(0.9, 1.2), false, true)
	var best := c
	var best_h := -1.0e9
	for k in 12:
		var p := c + Vector2.from_angle(k * TAU / 12.0) * (reach + 1.0)
		var h := s.earth.metres_at(p)
		if h > best_h and not s.earth.is_wet(p):
			best_h = h
			best = p
	if houses >= 6:
		_put(["prop_ovoo"], best, s.rng.randf() * TAU)


# --- the transition ring -----------------------------------------------------------------

## Scatter shrubs, tufts, rocks and trees round the outer edge, thinning outwards, so the
## settlement melts into the country. Buildings on the outside of the cluster (few neighbours)
## seed it, in the direction away from their neighbours, so it follows any outline.
func _ring(cl: Dictionary, rural: bool, camp: bool) -> void:
	var fruit: Array = _fl["trees"]
	var shrubs: Array = _fl["shrubs"]
	var farm := rural and not camp
	for i in cl["ids"]:
		var e: Dictionary = s.placed[i]
		var what := str(e["what"])
		if what in ["wall", "tower", "gate"]:
			continue
		var pos: Vector2 = e["pos"]
		var r := clampf(float(e["r"]), 0.15, 1.5)
		var near := _outward(pos, 1.5)
		var count: int = near[0]
		if count > 6:
			continue
		var away: Vector2 = near[1]
		var exposure := 1.0 - count / 7.0   # 1: stands alone, near 0: in the thick of it
		var dir := away.normalized() if away.length() > 0.12 else Vector2.from_angle(s.rng.randf() * TAU)
		var picks := 1 + int(exposure * (3.0 if what == "house" or what == "tent" else 2.0))
		for k in picks:
			var d := r + 0.15 + (-log(maxf(s.rng.randf(), 0.02))) * 0.55   # most near, a few far
			var p := pos + dir.rotated(s.rng.randf_range(-1.2, 1.2)) * d
			if s.rng.randf() > exp(-(d - r) / 1.6) * (0.35 + 0.65 * exposure):
				continue
			var list: Array
			if d < r + 0.55:
				list = shrubs.duplicate()
				if not camp:
					list += fruit
					if not farm:
						list.append("flowerbed")
			elif d < r + 1.4:
				list = shrubs + ["rocks", "bush"]
				if not camp:
					list += fruit
			else:
				list = shrubs + (_fl["big_trees"] as Array) + (_fl["big_trees"] as Array)
			_put(list, p, s.rng.randf() * TAU, s.rng.randf_range(0.8, 1.3), false, true)
		if farm and s.rng.randf() < 0.18:   # stock grazing by the village
			_put(_fl["animals"], pos + dir * (r + 1.0 + s.rng.randf()), s.rng.randf() * TAU, 1.0, false, true)
