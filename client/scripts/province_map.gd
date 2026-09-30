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
var civ_names := {}


func _init(earth_builder: EarthBuilder, view: Dictionary) -> void:
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
		civ_names[civ["id"]] = civ["name"]
	for p in view["provinces"]:
		if p["latlon"] == null:
			continue
		sites.append({
			"id": p["id"], "name": p["name"], "sea": false, "owner": p["owner"],
			"capital": p["capital"], "population": p["population"],
			"pixel": earth.pixel_of(p["latlon"][0], p["latlon"][1]),
			"resources": p.get("resources", {}),
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
	for site in sites:
		if owners.has(site["id"]) and (site["owner"] != owners[site["id"]] or site["capital"] != capitals[site["id"]]):
			site["owner"] = owners[site["id"]]
			site["capital"] = capitals[site["id"]]
			changed = true
	if changed:
		_redraw()
	return changed


func _redraw() -> void:
	for child in _overlay.get_children():
		child.queue_free()
	earth.set_political(_political_image())
	_overlay.add_child(_borders())
	for index in sites.size():
		if not sites[index]["sea"]:
			_overlay.add_child(_province_label(sites[index]))
	for civ_id in civ_colours:
		var label := _civ_label(civ_id)
		if label != null:
			_overlay.add_child(label)


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

## Where states are at war: an army of each side on each side of the border, with
## crossed swords between them (the view's "wars").
func show_wars(wars: Array) -> void:
	for child in _war_marks.get_children():
		child.queue_free()
	var by_id := {}
	for site in sites:
		by_id[site["id"]] = site
	for war in wars:
		for clash in war.get("clashes", []):
			if not by_id.has(clash[0]) or not by_id.has(clash[1]):
				continue
			var a: Vector2 = by_id[clash[0]]["pixel"]
			var b: Vector2 = by_id[clash[1]]["pixel"]
			var towards := (b - a).angle()
			for side in [[war["a"], a.lerp(b, 0.3), -towards - PI / 2.0], [war["b"], b.lerp(a, 0.3), -towards + PI / 2.0]]:
				var army := Armies.make(civ_colours.get(side[0], Color.GRAY), side[2])
				army.position = earth.ground_at_pixel(side[1])
				_war_marks.add_child(army)
			var mark := Label3D.new()
			mark.text = "⚔"
			mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			mark.fixed_size = true
			mark.pixel_size = 0.0007
			mark.font_size = 40
			mark.outline_size = 14
			mark.modulate = Color(1.0, 0.92, 0.75)
			mark.outline_modulate = Color(0.65, 0.08, 0.05)
			mark.no_depth_test = true
			mark.position = earth.ground_at_pixel(a.lerp(b, 0.5)) + Vector3(0, 10.0, 0)
			_war_marks.add_child(mark)


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
	label.visibility_range_end = 700.0  # zoomed out, only the states' names show
	label.position = earth.ground_at_pixel(site["pixel"]) + Vector3(0, 6.0, 0)
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
		tag.offset = Vector2(0, -34)
		label.add_child(tag)
	return label


## A state's name, large, over the middle of its lands; shown when zoomed out.
func _civ_label(civ_id: String) -> Label3D:
	var total := Vector2.ZERO
	var count := 0
	for c in cols * rows:
		if _owner_of(region[c]) == civ_id:
			total += Vector2(c % cols + 0.5, c / cols + 0.5) * CELL
			count += 1
	if count < 60:
		return null  # small states: their capital's label names them when zoomed in
	var centre := total / count
	var label := Label3D.new()
	label.name = "State_" + civ_id
	label.text = str(civ_names[civ_id]).to_upper()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = clampi(16 + int(sqrt(count) * 1.2), 22, 44)
	label.fixed_size = true
	label.pixel_size = 0.0007
	label.outline_size = 16
	label.modulate = Color(1.0, 0.96, 0.86)
	label.outline_modulate = civ_colours[civ_id].darkened(0.6)
	label.no_depth_test = true
	label.visibility_range_begin = 700.0
	label.position = earth.ground_at_pixel(centre) + Vector3(0, 8.0, 0)
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
