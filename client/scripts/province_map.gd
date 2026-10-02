## Divides the real map into provinces and sea zones, and draws them: owner colours, borders
## and names.
##
## Each province grows outward from its centre (its `latlon`) across the land, and crossing
## steep or high ground costs more, so borders settle on mountain ridges the way real
## frontiers did. Sea zones share out the nearby sea the same way. The same division is what
## tools/province_report.gd checks the content's neighbours and coasts against.
class_name ProvinceMap
extends RefCounted

const CELL := 4                ## height-map pixels per cell (about 20 km)
const LAND_REACH := 42.0       ## how far (in flat cells) a province can reach
const SEA_REACH := 70.0
const MIN_SHARED_EDGE := 2     ## cell edges two regions must share to count as neighbours

var earth: EarthBuilder
var cols := 0
var rows := 0
var sites: Array[Dictionary] = []   ## {id, name, pixel, sea, owner, capital, population}
var region := PackedInt32Array()    ## site index per cell, or -1
var ocean := PackedByteArray()
var metres := PackedFloat32Array()
var civ_colours := {}
var civ_portraits := {}   ## civ id -> portrait style, which also picks its building style
var civ_names := {}
var civ_symbols := {}   ## civ id -> heraldic symbol id (G1)


func _init(earth_builder: EarthBuilder, view: Dictionary) -> void:
	player = str(view.get("player", ""))
	earth = earth_builder
	cols = int(earth.size().x) / CELL
	rows = int(earth.size().y) / CELL
	ocean.resize(cols * rows)
	metres.resize(cols * rows)
	for r in rows:
		for q in cols:
			var pixel := Vector2(q * CELL + CELL / 2.0, r * CELL + CELL / 2.0)
			ocean[r * cols + q] = 1 if earth.is_ocean_at(pixel) else 0
			metres[r * cols + q] = earth.metres_at(pixel)
	for civ in view["civs"]:
		civ_colours[civ["id"]] = Color(civ["colour"])
		civ_portraits[civ["id"]] = str(civ.get("portrait", ""))
		civ_names[civ["id"]] = civ["name"]
		civ_symbols[civ["id"]] = str(civ.get("symbol", ""))
	for p in view["provinces"]:
		if p["latlon"] == null:
			continue
		sites.append({
			"id": p["id"], "name": p["name"], "sea": false, "owner": p["owner"],
			"capital": p["capital"], "population": p["population"],
			"pixel": earth.pixel_of(p["latlon"][0], p["latlon"][1]),
			"resources": p.get("resources", {}),
			"buildings": _looks(p),
		})
	for s in view["seas"]:
		if s["latlon"] == null:
			continue
		sites.append({
			"id": s["id"], "name": s["name"], "sea": true, "owner": null,
			"capital": false, "population": 0,
			"pixel": earth.pixel_of(s["latlon"][0], s["latlon"][1]),
		})
	_grow()


# --- dividing the map --------------------------------------------------------------------

func _cell_of(pixel: Vector2) -> int:
	var q := clampi(int(pixel.x / CELL), 0, cols - 1)
	var r := clampi(int(pixel.y / CELL), 0, rows - 1)
	return r * cols + q


## Multi-source Dijkstra: every cell goes to the cheapest-to-reach site of its kind.
func _grow() -> void:
	region.resize(cols * rows)
	region.fill(-1)
	var cost := PackedFloat32Array()
	cost.resize(cols * rows)
	cost.fill(INF)
	var heap := _Heap.new()
	for index in sites.size():
		var site: Dictionary = sites[index]
		var start := _snap(_cell_of(site["pixel"]), site["sea"])
		if start < 0:
			push_warning("%s is not on %s" % [site["id"], "sea" if site["sea"] else "land"])
			continue
		cost[start] = 0.0
		region[start] = index
		heap.push(0.0, start)
	var steps := [[1, 0, 1.0], [-1, 0, 1.0], [0, 1, 1.0], [0, -1, 1.0],
		[1, 1, 1.414], [1, -1, 1.414], [-1, 1, 1.414], [-1, -1, 1.414]]
	while not heap.is_empty():
		var top := heap.pop()
		var c: int = top[1]
		if top[0] > cost[c]:
			continue
		var sea: bool = sites[region[c]]["sea"]
		var reach := SEA_REACH if sea else LAND_REACH
		var q := c % cols
		var r := c / cols
		for step in steps:
			var nq: int = q + step[0]
			var nr: int = r + step[1]
			if nq < 0 or nr < 0 or nq >= cols or nr >= rows:
				continue
			var n := nr * cols + nq
			if (ocean[n] == 1) != sea:
				continue
			var extra := 0.0 if sea else _terrain_cost(c, n)
			var next: float = cost[c] + step[2] * (1.0 + extra)
			if next < cost[n] and next <= reach:
				cost[n] = next
				region[n] = region[c]
				heap.push(next, n)


## Climbing, and high ground itself, are slow to cross: ridges become frontiers.
func _terrain_cost(from: int, to: int) -> float:
	var climb := absf(metres[to] - metres[from])
	return climb / 120.0 + maxf(metres[to], 0.0) / 1500.0


## The nearest cell of the right kind (a city on the shore may sit in a sea cell).
func _snap(cell: int, sea: bool) -> int:
	var q0 := cell % cols
	var r0 := cell / cols
	for radius in 6:
		for dr in range(-radius, radius + 1):
			for dq in range(-radius, radius + 1):
				var q := q0 + dq
				var r := r0 + dr
				if q >= 0 and r >= 0 and q < cols and r < rows and (ocean[r * cols + q] == 1) == sea:
					return r * cols + q
	return -1


## Pairs of sites sharing a border: {"a|b": shared edge count}, ids sorted.
func shared_edges() -> Dictionary:
	var pairs := {}
	for r in rows:
		for q in cols:
			var a := region[r * cols + q]
			for n in [r * cols + q + 1 if q < cols - 1 else -1, (r + 1) * cols + q if r < rows - 1 else -1]:
				if n < 0:
					continue
				var b := region[n]
				if a < 0 or b < 0 or a == b:
					continue
				var ids := [sites[a]["id"], sites[b]["id"]]
				ids.sort()
				var key := "%s|%s" % ids
				pairs[key] = int(pairs.get(key, 0)) + 1
	return pairs


## Neighbour ids per site id, from shared_edges (at least MIN_SHARED_EDGE edges).
func neighbours() -> Dictionary:
	var result := {}
	for site in sites:
		result[site["id"]] = []
	var edges := shared_edges()
	for key in edges:
		if edges[key] < MIN_SHARED_EDGE:
			continue
		var ids: PackedStringArray = key.split("|")
		result[ids[0]].append(ids[1])
		result[ids[1]].append(ids[0])
	return result


# --- drawing -----------------------------------------------------------------------------

var _overlay: Node3D
var _war_marks: Node3D
var _outline: MeshInstance3D


func build(parent: Node3D) -> void:
	_overlay = Node3D.new()
	_overlay.name = "Provinces"
	parent.add_child(_overlay)
	_war_marks = Node3D.new()
	_war_marks.name = "WarFronts"
	parent.add_child(_war_marks)
	_redraw()


## Owners change during the game (revolts, collapses): recolour and relabel the map.
## Returns whether anything changed hands, so cities can be repainted too.
func update(view: Dictionary) -> bool:
	var owners := {}
	var capitals := {}
	for p in view["provinces"]:
		owners[p["id"]] = p["owner"]
		capitals[p["id"]] = p["capital"]
	var changed := false
	var by_id := {}
	for p in view["provinces"]:
		by_id[p["id"]] = p
	for site in sites:
		if by_id.has(site["id"]):   # cities grow, and raise new buildings (D-111)
			site["population"] = by_id[site["id"]]["population"]
			site["buildings"] = _looks(by_id[site["id"]])
		if owners.has(site["id"]) and (site["owner"] != owners[site["id"]] or site["capital"] != capitals[site["id"]]):
			site["owner"] = owners[site["id"]]
			site["capital"] = capitals[site["id"]]
			changed = true
	if changed:
		_redraw()
	return changed


## The looks of a province's standing buildings, in the order they were built.
static func _looks(p: Dictionary) -> Array:
	return p.get("buildings", []).map(func(b): return str(b["look"]))


## A fingerprint of every city's size and buildings: when it changes, the cities are
## rebuilt. Sizes count in steps of a quarter, so a city does not rebuild every turn.
func growth_signature() -> String:
	var parts: PackedStringArray = []
	for site in sites:
		if site["sea"]:
			continue
		var step := int(log(maxf(float(site["population"]), 1000.0)) / log(1.25))
		parts.append("%s:%d:%s" % [site["id"], step, ",".join(site.get("buildings", []))])
	return "|".join(parts)


func _redraw() -> void:
	for child in _overlay.get_children():
		child.queue_free()
	earth.set_political(_political_image())
	_overlay.add_child(_borders())
	_labels.clear()
	for index in sites.size():
		if not sites[index]["sea"]:
			var label := _province_label(sites[index])
			_overlay.add_child(label)
			_labels.append([label, (1000000 if sites[index]["capital"] else 0) + _cells_of(sites[index])])
	for civ_id in civ_colours:
		var label := _civ_label(civ_id)
		if label != null:
			_overlay.add_child(label)
			_labels.append([label, 3000000 if civ_id == player else 2000000 + label.font_size])
	_labels.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])


## Hide any name that would overlap a more important one on screen: state names first, then
## capitals, then larger provinces. Called as the camera moves.
func declutter(camera: Camera3D) -> void:
	var view_height := camera.get_viewport().get_visible_rect().size.y
	var scale := view_height / (2.0 * tan(deg_to_rad(camera.fov) / 2.0))
	var placed: Array[Rect2] = []
	var everything := _labels + _war_labels
	everything.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	for entry in everything:
		var label: Label3D = entry[0]
		if not is_instance_valid(label):
			continue
		var at := label.global_position
		var distance := camera.global_position.distance_to(at)
		var in_range := distance >= label.visibility_range_begin and (
			label.visibility_range_end <= 0.0 or distance < label.visibility_range_end)
		if not in_range or camera.is_position_behind(at):
			label.visible = true  # its visibility range decides
			continue
		# measured from screenshots: a line is about 1.3 font sizes tall with its outline
		var height := label.font_size * label.pixel_size * scale * 1.3
		var per_char := 0.62 if label.text == label.text.to_upper() else 0.48
		var width := label.text.length() * height * per_char
		var rect := Rect2(camera.unproject_position(at) - Vector2(width, height) / 2.0, Vector2(width, height)).grow(3.0)
		for child in label.get_children():
			if child is Sprite3D:  # a state's shield stands above its name
				var arms := child as Sprite3D
				var tall := arms.texture.get_height() * arms.pixel_size * scale
				rect = rect.merge(Rect2(rect.get_center() - Vector2(tall * 0.43, tall * 1.7), Vector2(tall * 0.86, tall)))
		var clear := true
		for other in placed:
			if other.intersects(rect):
				clear = false
				break
		label.visible = clear
		if clear:
			placed.append(rect)


## The province or sea at a height-map pixel, or -1.
func site_at(pixel: Vector2) -> int:
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= earth.size().x or pixel.y >= earth.size().y:
		return -1
	return region[_cell_of(pixel)]


## A bright outline around one site (the selection); -1 clears it.
func outline(parent: Node3D, index: int) -> void:
	if _outline != null:
		_outline.queue_free()
		_outline = null
	if index < 0:
		return
	var segments: Array = []
	for r in rows:
		for q in cols:
			var c := r * cols + q
			if q < cols - 1 and (region[c] == index) != (region[c + 1] == index):
				segments.append([Vector2(q + 1, r), Vector2(q + 1, r + 1)])
			if r < rows - 1 and (region[c] == index) != (region[c + cols] == index):
				segments.append([Vector2(q, r + 1), Vector2(q + 1, r + 1)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line in _join(segments):
		_ribbon(st, _smooth(line), 0.0018, Color(1.0, 0.85, 0.35))
	_outline = MeshInstance3D.new()
	_outline.name = "Selection"
	_outline.mesh = st.commit()
	_outline.material_override = EarthBuilder.line_material(0.003)
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(_outline)


func _owner_of(index: int) -> Variant:
	return null if index < 0 else sites[index]["owner"]


## A colour per cell: the owner's colour where a civ rules, clear elsewhere.
func _political_image() -> Image:
	var image := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	for c in cols * rows:
		var owner: Variant = _owner_of(region[c])
		if owner != null:
			var colour: Color = civ_colours[owner]
			image.set_pixel(c % cols, c / cols, Color(colour.r, colour.g, colour.b, 1.0))
		else:
			image.set_pixel(c % cols, c / cols, Color(0, 0, 0, 0))
	return image


## Border lines along cell edges, joined into smooth lines. Frontiers between civs are bold.
func _borders() -> MeshInstance3D:
	var chains := {}  # "kind" -> Array of corner-to-corner segments
	for r in rows:
		for q in cols:
			var c := r * cols + q
			if q < cols - 1:
				_edge(chains, c, c + 1, Vector2(q + 1, r), Vector2(q + 1, r + 1))
			if r < rows - 1:
				_edge(chains, c, c + cols, Vector2(q, r + 1), Vector2(q + 1, r + 1))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for kind in chains:
		var width := 0.0012 if kind == "frontier" else 0.0005
		var colour := Color(0.98, 0.95, 0.85) if kind == "frontier" else Color(0.95, 0.92, 0.82, 0.55)
		for line in _join(chains[kind]):
			_ribbon(st, _smooth(line), width, colour)
	var instance := MeshInstance3D.new()
	instance.name = "Borders"
	instance.mesh = st.commit()
	instance.material_override = EarthBuilder.line_material(0.002)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _edge(chains: Dictionary, a: int, b: int, p: Vector2, q: Vector2) -> void:
	var ra := region[a]
	var rb := region[b]
	if ra == rb or ocean[a] == 1 or ocean[b] == 1:
		return
	if ra < 0 and rb < 0:
		return
	var oa: Variant = _owner_of(ra)
	var ob: Variant = _owner_of(rb)
	var kind := "province" if oa == ob and oa != null else "frontier"
	if oa == null and ob == null:
		kind = "province"
	if not chains.has(kind):
		chains[kind] = []
	chains[kind].append([p, q])


## Joins segments that meet end to end into longer lines.
func _join(segments: Array) -> Array:
	var at := {}
	for i in segments.size():
		for end in segments[i]:
			if not at.has(end):
				at[end] = []
			at[end].append(i)
	var used := PackedByteArray()
	used.resize(segments.size())
	var lines := []
	for i in segments.size():
		if used[i] == 1:
			continue
		used[i] = 1
		var line: Array = [segments[i][0], segments[i][1]]
		for direction in 2:
			while true:
				var tip: Vector2 = line[-1]
				if at[tip].size() != 2:
					break  # a junction or a dead end: stop here
				var next := -1
				for j in at[tip]:
					if used[j] == 0:
						next = j
				if next < 0:
					break
				used[next] = 1
				line.append(segments[next][1] if segments[next][0] == tip else segments[next][0])
			line.reverse()
		lines.append(line)
	return lines


## Chaikin corner cutting; the ends stay put so lines still meet at junctions.
func _smooth(line: Array) -> Array:
	var points := line
	for pass_index in 3:
		if points.size() < 3:
			return points
		var out := [points[0]]
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		out.append(points[-1])
		points = out
	return points


func _ribbon(st: SurfaceTool, cells: Array, width: float, colour: Color) -> void:
	var pts: Array[Vector2] = []
	for c in cells:
		pts.append(c * CELL)
	var line: Array[Vector3] = []
	for p in pts:
		line.append(earth.ground_at_pixel(p))
	EarthBuilder.add_line(st, line, width, colour)

## Your friendly ties as arcs from your capital to each partner's: gold for trade, green
## for allies, purple for tributaries - your network, at a glance.
func show_ties(view: Dictionary) -> void:
	if _ties != null:
		_ties.queue_free()
		_ties = null
	var capitals := {}
	for site in sites:
		if site["capital"] and site["owner"] != null:
			capitals[site["owner"]] = site["pixel"]
	var home: Variant = capitals.get(view["player"])
	if home == null:
		return
	var colours := {"trading": Color(1.0, 0.82, 0.2), "allied": Color(0.30, 0.90, 0.40),
		"tributary": Color(0.75, 0.50, 0.95)}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drawn := 0
	for civ in view["civs"]:
		var relation: Variant = civ.get("relation")
		if not colours.has(relation) or not capitals.has(civ["id"]) or not civ["alive"]:
			continue
		var a: Vector2 = home
		var b: Vector2 = capitals[civ["id"]]
		var rise := a.distance_to(b) * 0.12
		var line: Array[Vector3] = []
		for k in 25:
			var t := k / 24.0
			line.append(earth.ground_at_pixel(a.lerp(b, t)) + Vector3(0, sin(t * PI) * rise, 0))
		EarthBuilder.add_line(st, line, 0.0016, colours[relation])
		drawn += 1
	if drawn == 0:
		return
	_ties = MeshInstance3D.new()
	_ties.name = "Ties"
	_ties.mesh = st.commit()
	var material := EarthBuilder.line_material(0.002)
	material.set_shader_parameter("dash", 40.0)   # dashes flowing out from your capital
	material.set_shader_parameter("near_fade", 260.0)   # not across the city streets
	_ties.material_override = material
	_ties.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_war_marks.get_parent().add_child(_ties)


## Ships rock on the swell and marching armies bob (called every frame with the time in
## seconds). Armies and fleets are drawn large to read from afar, and shrink toward life size
## as the camera comes down to a city (`distance`, the camera's distance), as in Rise of
## Kingdoms.
func animate(t: float, distance := 1000.0) -> void:
	var near := clampf(distance / 140.0, 0.4, 1.0)
	for item in _sized:
		if is_instance_valid(item[0]):
			(item[0] as Node3D).scale = Vector3.ONE * item[1] * near
	for item in _afloat:
		var piece: Node3D = item[0]
		if not is_instance_valid(piece):
			continue
		var phase: float = item[2]
		piece.position.y = item[1] + sin(t * 1.3 + phase) * 0.25
		piece.rotation.z = sin(t * 0.9 + phase) * 0.06
		piece.rotation.x = sin(t * 1.1 + phase * 1.7) * 0.04
	for item in _marching:
		var army: Node3D = item[0]
		if is_instance_valid(army):
			army.position.y = item[1] + absf(sin(t * 5.0 + item[2])) * 0.35 * army.scale.y


## Roads between neighbouring provinces' chief cities (G1): dirt tracks following the
## ground, seen as the camera comes down. Drawn once; borders change, roads stay.
func show_roads(view: Dictionary, parent: Node3D) -> void:
	var by_id := {}
	for site in sites:
		by_id[site["id"]] = site
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drawn := {}
	for p in view["provinces"]:
		if not by_id.has(p["id"]):
			continue
		for n in p["neighbours"]:
			var key := [p["id"], n] if str(p["id"]) < str(n) else [n, p["id"]]
			if drawn.has(key) or not by_id.has(n):
				continue
			drawn[key] = true
			var a: Vector2 = by_id[p["id"]]["pixel"]
			var b: Vector2 = by_id[n]["pixel"]
			if a.distance_to(b) > 160.0:
				continue
			# a gentle bend, so roads do not look ruled
			var bend := (b - a).orthogonal().normalized() * a.distance_to(b) * 0.08 * (1.0 if hash(key) % 2 == 0 else -1.0)
			var line: Array[Vector3] = []
			var wet := false
			for i in 17:
				var t := i / 16.0
				var at := a.lerp(b, t) + bend * sin(t * PI)
				if earth.is_ocean_at(at):
					wet = true
					break
				line.append(earth.ground_at_pixel(at) + Vector3(0, 0.15, 0))
			if not wet:
				EarthBuilder.add_line(st, line, 0.0016, Color(0.86, 0.74, 0.52))
	var roads := MeshInstance3D.new()
	roads.name = "Roads"
	roads.mesh = st.commit()
	roads.material_override = EarthBuilder.line_material(0.0015)
	roads.visibility_range_end = 420.0
	roads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(roads)


## Armies in the field (D-099): soldiers in their owner's colours, larger for larger hosts,
## with their strength above them; a marching army's road drawn ahead of it; crossed swords
## where battles were fought last turn. `selected_army` is drawn with a gold ring. Fleets
## (D-107) are drawn the same way on their seas.
func show_armies(armies: Array, battles: Array, selected_army := "", fleets: Array = [],
		sea_battles: Array = [], selected_fleet := "") -> void:
	for child in _war_marks.get_children():
		child.queue_free()
	_war_labels.clear()
	_afloat.clear()
	_marching.clear()
	_sized.clear()
	var by_id := {}
	for site in sites:
		by_id[site["id"]] = site
	var count := {}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var roads := 0
	for army in armies:
		var here: String = army["province"]
		if not by_id.has(here):
			continue
		var k: int = count.get(here, 0)
		count[here] = k + 1
		# beside the city, not on it; a second army in the same place stands across from it
		var spot := _army_spot(by_id[here], k)
		var facing := 0.0
		var route: Array = army.get("route", [])
		if not route.is_empty() and by_id.has(route[0]):
			facing = -(by_id[route[0]]["pixel"] - spot).angle() - PI / 2.0
		var colour: Color = civ_colours.get(army["owner"], Color.GRAY)
		var siege: bool = army.get("troops", []).any(func(t): return str(t["unit"]) in ["siege_engines", "cannon"])
		var piece := Armies.make(colour, facing, siege)
		var men := float(army["men"])
		piece.scale = Vector3.ONE * clampf(0.6 + log(maxf(men, 1000.0) / 1000.0) / log(10.0) * 0.25, 0.6, 1.25)
		piece.position = earth.ground_at_pixel(spot)
		_war_marks.add_child(piece)
		_sized.append([piece, piece.scale.x])
		if not route.is_empty():  # on the march: the ranks bob as they walk
			_marching.append([piece, piece.position.y, float(hash(army["id"]) % 628) / 100.0])
		var label := Label3D.new()
		var text := _men_text(int(army["men"]))
		if int(army.get("siege_needed", 0)) > 0:
			text += " · siege %d%%" % mini(99, int(army["siege_bp"]) * 100 / int(army["siege_needed"]))
		label.text = text
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.0006
		label.font_size = 34
		label.outline_size = 12
		var mine: bool = army["owner"] == player
		label.modulate = Color(1.0, 0.86, 0.35) if mine else Color(1, 1, 1)
		label.outline_modulate = colour.darkened(0.5)
		label.no_depth_test = true
		label.render_priority = 13  # an army's strength reads over place names
		label.outline_render_priority = 12
		label.position = earth.ground_at_pixel(spot) + Vector3(0, 10.0 * piece.scale.y, 0)
		label.visibility_range_end = 1300.0   # not over the whole-world view
		_war_marks.add_child(label)
		_war_labels.append([label, 1500000 + (500000 if mine else 0) + int(men / 1000)])
		if army["id"] == selected_army:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 6.0
			torus.outer_radius = 7.2
			ring.mesh = torus
			var gold := StandardMaterial3D.new()
			gold.albedo_color = Color(1.0, 0.82, 0.2)
			gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ring.material_override = gold
			ring.position = earth.ground_at_pixel(spot) + Vector3(0, 0.4, 0)
			_war_marks.add_child(ring)
		if not route.is_empty():
			var line: Array[Vector3] = [earth.ground_at_pixel(spot) + Vector3(0, 0.8, 0)]
			for step in route:
				if by_id.has(step):
					line.append(earth.ground_at_pixel(by_id[step]["pixel"]) + Vector3(0, 0.8, 0))
			EarthBuilder.add_line(st, line, 0.0022, colour.lightened(0.35) if not mine else Color(1.0, 0.86, 0.35))
			roads += 1
	roads += _draw_fleets(st, by_id, fleets, selected_fleet)
	if roads > 0:
		var paths := MeshInstance3D.new()
		paths.mesh = st.commit()
		paths.material_override = EarthBuilder.line_material(0.002)
		paths.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_war_marks.add_child(paths)
	for place in battles + sea_battles:
		if not by_id.has(place):
			continue
		var mark := Label3D.new()
		mark.text = "⚔"
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.fixed_size = true
		mark.pixel_size = 0.0007
		mark.font_size = 44
		mark.outline_size = 14
		mark.modulate = Color(1.0, 0.92, 0.75)
		mark.outline_modulate = Color(0.65, 0.08, 0.05)
		mark.no_depth_test = true
		mark.position = earth.ground_at_pixel(by_id[place]["pixel"]) + Vector3(0, 14.0, 0)
		_war_marks.add_child(mark)


## Fleets on their seas, with their ship counts; a sailing fleet's course drawn ahead of it.
## Returns how many courses were added to `st`.
func _draw_fleets(st: SurfaceTool, by_id: Dictionary, fleets: Array, selected_fleet: String) -> int:
	var count := {}
	var courses := 0
	for fleet in fleets:
		var sea: String = fleet["sea"]
		if not by_id.has(sea):
			continue
		var k: int = count.get(sea, 0)
		count[sea] = k + 1
		var spot := _fleet_spot(by_id[sea], k)
		var at := earth.ground_at_pixel(spot)
		at.y = maxf(at.y, 0.0) + 0.3
		var facing := 0.0
		var course: Array = fleet.get("route", [])
		if not course.is_empty() and by_id.has(course[0]):
			facing = -(by_id[course[0]]["pixel"] - spot).angle() - PI / 2.0
		var colour: Color = civ_colours.get(fleet["owner"], Color.GRAY)
		var ships := int(fleet["ships"])
		var piece := Armies.make_fleet(colour, facing, 1 if ships < 20 else (2 if ships < 50 else 3))
		piece.scale = Vector3.ONE * clampf(0.7 + log(maxf(ships, 5.0) / 5.0) / log(10.0) * 0.3, 0.7, 1.3)
		piece.position = at
		_war_marks.add_child(piece)
		_sized.append([piece, piece.scale.x])
		_afloat.append([piece, at.y, float(hash(fleet["id"]) % 628) / 100.0])
		var label := Label3D.new()
		label.text = "%d ships" % ships
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.0006
		label.font_size = 32
		label.outline_size = 12
		var mine: bool = fleet["owner"] == player
		label.modulate = Color(1.0, 0.86, 0.35) if mine else Color(1, 1, 1)
		label.outline_modulate = colour.darkened(0.5)
		label.no_depth_test = true
		label.render_priority = 13
		label.outline_render_priority = 12
		label.position = at + Vector3(0, 9.0 * piece.scale.y, 0)
		label.visibility_range_end = 1300.0
		_war_marks.add_child(label)
		_war_labels.append([label, 1400000 + (500000 if mine else 0) + ships])
		if fleet["id"] == selected_fleet:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 7.0
			torus.outer_radius = 8.2
			ring.mesh = torus
			var gold := StandardMaterial3D.new()
			gold.albedo_color = Color(1.0, 0.82, 0.2)
			gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ring.material_override = gold
			ring.position = at + Vector3(0, 0.2, 0)
			_war_marks.add_child(ring)
		if not course.is_empty():
			var line: Array[Vector3] = [at + Vector3(0, 0.6, 0)]
			for step in course:
				if by_id.has(step):
					var p := earth.ground_at_pixel(by_id[step]["pixel"])
					line.append(Vector3(p.x, maxf(p.y, 0.0) + 0.9, p.z))
			EarthBuilder.add_line(st, line, 0.0022, colour.lightened(0.35) if not mine else Color(1.0, 0.86, 0.35))
			courses += 1
	return courses


## Where a fleet lies in its sea: near the sea's centre, on open water inside the sea zone
## (a second fleet in the same sea lies elsewhere around it).
func _fleet_spot(site: Dictionary, k: int) -> Vector2:
	var centre: Vector2 = site["pixel"]
	var index := sites.find(site)
	for radius in [16.0, 24.0, 10.0]:
		for turn in 8:
			var spot: Vector2 = centre + Vector2(radius, 0).rotated(k * 2.3 + turn * PI / 4.0 + 2.4)
			var cell := _cell_of(spot)
			if earth.is_wet(spot) and cell >= 0 and cell < region.size() and region[cell] == index:
				return spot
	return centre


## Where an army stands in a province: beside the city, on dry land inside the province
## (a second army in the same place stands elsewhere around the city).
func _army_spot(site: Dictionary, k: int) -> Vector2:
	var city: Vector2 = site["pixel"]
	var index := sites.find(site)
	for radius in [16.0, 11.0, 7.0]:
		for turn in 8:
			var spot: Vector2 = city + Vector2(radius, 0).rotated(k * 2.1 + turn * PI / 4.0 + 0.6)
			var cell := _cell_of(spot)
			if not earth.is_wet(spot) and cell >= 0 and cell < region.size() and region[cell] == index:
				return spot
	return city + Vector2(6.0, 4.0)


static func _men_text(men: int) -> String:
	if men >= 1000000:
		return "%.1fM" % (men / 1000000.0)
	if men >= 10000:
		return "%dk" % (men / 1000)
	if men >= 1000:
		return "%.1fk" % (men / 1000.0)
	return str(men)


var _ties: MeshInstance3D = null   ## the arcs of show_ties
var player := ""   ## the player's civ: its name is never hidden by another's
var _region_cells := {}   ## site index -> Array of its cells (built once)
var _labels: Array = []   ## [label, priority], most important first, for decluttering
var _war_labels: Array = []   ## [label, priority] of armies' and fleets' strengths
var _afloat: Array = []   ## [fleet piece, its resting height, a phase] to rock on the waves
var _marching: Array = []   ## [army piece, its resting height, a phase] bobbing on the march
var _sized: Array = []   ## [army or fleet piece, its scale from afar]: smaller up close


## The map cells of a site, indexed once (borders never move; only owners change).
func cells_in(index: int) -> Array:
	if _region_cells.is_empty():
		for c in cols * rows:
			var r: int = region[c]
			if r >= 0:
				if not _region_cells.has(r):
					_region_cells[r] = []   # an Array is shared by reference; a packed array is not
				_region_cells[r].append(c)
	return _region_cells.get(index, [])


## How many map cells a site covers (its size on the map).
func _cells_of(site: Dictionary) -> int:
	return cells_in(sites.find(site)).size()


func _province_label(site: Dictionary) -> Label3D:
	var label := Label3D.new()
	label.name = "Label_" + str(site["id"])
	label.text = ("♛ " if site["capital"] else "") + str(site["name"])
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34 if site["capital"] else 26
	label.fixed_size = true
	label.pixel_size = 0.0007
	label.outline_size = 12
	label.modulate = Color(1.0, 0.97, 0.90)
	label.outline_modulate = Color(0.06, 0.05, 0.05, 0.9)
	label.no_depth_test = true
	label.render_priority = 11  # names draw over the clouds
	label.outline_render_priority = 10
	# small provinces are named only when the camera is close, so labels never pile up
	label.visibility_range_end = clampf(160.0 + sqrt(float(_cells_of(site))) * 30.0, 220.0, 700.0)
	label.position = earth.ground_at_pixel(site["pixel"]) + Vector3(0, 6.0, 0)
	# on a plate in its owner's colours, like a city's name banner
	label.outline_size = 6
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
	var plate := Sprite3D.new()
	var owner_colour: Color = civ_colours.get(site["owner"], Color(0.55, 0.52, 0.48))
	plate.texture = UiStyle.name_plate(int(text_width) + label.font_size + 34, int(label.font_size * 1.55), owner_colour)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.fixed_size = true
	plate.pixel_size = label.pixel_size
	plate.offset = Vector2(-label.font_size * 0.18, 0)
	plate.no_depth_test = true
	plate.render_priority = 9
	plate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	plate.visibility_range_end = label.visibility_range_end
	label.add_child(plate)
	# the province's usable map resources, in small type under its name, when close
	var found: Array = []
	var resources: Dictionary = site.get("resources", {})
	for res in resources:
		if resources[res] != "unexplored":
			found.append(str(res) + ("" if resources[res] == "accessible" else " (little)"))
	if not found.is_empty():
		var tag := Label3D.new()
		tag.text = " · ".join(found)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.fixed_size = true
		tag.pixel_size = 0.0007
		tag.font_size = 18
		tag.outline_size = 8
		tag.modulate = Color(1.0, 0.88, 0.55)
		tag.outline_modulate = Color(0.06, 0.05, 0.05, 0.85)
		tag.no_depth_test = true
		tag.visibility_range_end = 300.0
		tag.position = Vector3(0, -0.03, 0)
		tag.offset = Vector2(0, -46)
		label.add_child(tag)
	return label


## A state's name, large, over the middle of its lands; shown when zoomed out.
func _civ_label(civ_id: String) -> Label3D:
	var total := Vector2.ZERO
	var count := 0
	for index in sites.size():
		if sites[index]["owner"] != civ_id:
			continue
		for c in cells_in(index):
			total += Vector2(c % cols + 0.5, c / cols + 0.5) * CELL
			count += 1
	if count == 0:
		return null
	var centre := total / count
	var label := Label3D.new()
	label.name = "State_" + civ_id
	label.text = str(civ_names[civ_id]).to_upper()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = clampi(16 + int(sqrt(count) * 1.2), 18, 44)
	label.fixed_size = true
	label.pixel_size = 0.0007
	label.outline_size = 16
	label.modulate = Color(1.0, 0.96, 0.86)
	label.outline_modulate = civ_colours[civ_id].darkened(0.6)
	label.no_depth_test = true
	label.render_priority = 11  # names draw over the clouds
	label.outline_render_priority = 10
	# big states are named from far away; small ones once the camera is a little closer,
	# as their provinces' own names only appear closer still
	label.visibility_range_begin = 480.0 if count >= 60 else 300.0
	label.position = earth.ground_at_pixel(centre) + Vector3(0, 8.0, 0)
	if civ_symbols.get(civ_id, "") != "":
		# the state's arms above its name, as a banner over its lands
		var arms := Sprite3D.new()
		arms.texture = Symbols.shield(civ_colours[civ_id], civ_symbols[civ_id], 128)
		arms.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		arms.fixed_size = true
		arms.pixel_size = 0.00042 * clampf(label.font_size / 30.0, 0.8, 1.3)
		arms.offset = Vector2(0, 150)
		arms.no_depth_test = true
		arms.render_priority = 12
		arms.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		label.add_child(arms)
	return label


## A small binary min-heap of [cost, cell].
class _Heap:
	var keys := PackedFloat32Array()
	var values := PackedInt32Array()

	func is_empty() -> bool:
		return keys.is_empty()

	func push(key: float, value: int) -> void:
		keys.append(key)
		values.append(value)
		var i := keys.size() - 1
		while i > 0:
			var parent := (i - 1) / 2
			if keys[parent] <= keys[i]:
				break
			_swap(i, parent)
			i = parent

	func pop() -> Array:
		var top := [keys[0], values[0]]
		var last := keys.size() - 1
		_swap(0, last)
		keys.resize(last)
		values.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < last and keys[l] < keys[m]:
				m = l
			if r < last and keys[r] < keys[m]:
				m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return top

	func _swap(a: int, b: int) -> void:
		var k := keys[a]
		keys[a] = keys[b]
		keys[b] = k
		var v := values[a]
		values[a] = values[b]
		values[b] = v
