## Urbs (D-289): loads and frees the city in 250 m square chunks by distance from the camera.
##
## Each chunk holds the terrain mesh and the fill (houses, shops) for its square, built by
## `UrbsTerrain.build_chunk(rect, lod)` and `UrbsFill.build_chunk(rect, lod, height)`. At
## street level about 1.5 km around the camera is kept, finest near, coarser further out;
## orbiting high, everything within the city is held at the coarsest detail. Builds are
## spread over frames under a time budget so walking never hitches.
class_name UrbsChunks
extends Node3D

const SIZE := 250.0
const STREET_RADIUS := 1500.0       ## kept around the camera at street level
const ORBIT_RADIUS := 2800.0        ## kept when orbiting (the Servian city and the Campus Martius)
const BUDGET_MSEC := 4.0            ## building time allowed per frame
const LOD_NEAR := 250.0             ## finest detail within this distance of the camera
const LOD_MID := 1100.0

var terrain: Object
var fill: Object
var height: Callable
var loaded := {}                    ## Vector2i -> {"node": Node3D, "lod": int}
var _wanted: Array = []             ## [Vector2i, lod], nearest first
var _focus := Vector3.ZERO
var _orbit := true


func _ready() -> void:
	UrbsTerrain.walls_later = true   # F3: the walls follow the houses (_walls_step)


## Chunk coordinates containing local point (x, z).
static func key_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / SIZE), floori(z / SIZE))


static func rect_of(key: Vector2i) -> Rect2:
	return Rect2(Vector2(key) * SIZE, Vector2(SIZE, SIZE))


## Say where the camera is (`orbit`: high above the city). Cheap; recomputes the wanted list
## only when the camera crosses into another chunk or changes mode.
func focus_on(point: Vector3, orbit: bool) -> void:
	var moved := key_of(point.x, point.z) != key_of(_focus.x, _focus.z)
	if not moved and orbit == _orbit and not _wanted.is_empty():
		return
	_focus = point
	_orbit = orbit
	_plan()


func _plan() -> void:
	var radius := ORBIT_RADIUS if _orbit else STREET_RADIUS
	var reach := int(ceil(radius / SIZE))
	var centre := key_of(_focus.x, _focus.z)
	var wanted := {}
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var key := centre + Vector2i(dx, dz)
			var c := rect_of(key).get_center()
			var d := Vector2(c.x - _focus.x, c.y - _focus.z).length()
			if d > radius + SIZE * 0.5 or c.length() > UrbsGeo.RADIUS_M + SIZE:
				continue
			wanted[key] = [d, 2 if _orbit and _focus.y > 400.0 else _lod_at(d)]
	for key in loaded.keys():   # free what is out of reach
		if not wanted.has(key):
			_free(key)
	_wanted = []
	for key in wanted:
		if not loaded.has(key) or loaded[key]["lod"] != wanted[key][1]:
			_wanted.append([wanted[key][0], key, wanted[key][1]])
	_wanted.sort_custom(func(a, b): return a[0] < b[0])


static func _lod_at(d: float) -> int:
	return 0 if d < LOD_NEAR else (1 if d < LOD_MID else 2)


func _free(key: Vector2i) -> void:
	var entry: Dictionary = loaded[key]
	(entry["node"] as Node).queue_free()
	loaded.erase(key)


func _build(key: Vector2i, lod: int) -> void:
	if loaded.has(key):
		_free(key)
	var rect := rect_of(key)
	var node := Node3D.new()
	node.name = "Chunk_%d_%d" % [key.x, key.y]
	if terrain != null:
		var ground: Node3D = terrain.build_chunk(rect, lod)
		if ground != null:
			node.add_child(ground)
	if fill != null:
		var houses: Node3D = fill.build_chunk(rect, lod, height)
		if houses != null:
			node.add_child(houses)
	add_child(node)
	loaded[key] = {"node": node, "lod": lod, "ground": node.get_child(0) if terrain != null and node.get_child_count() > 0 else null,
		"houses": node.get_child(node.get_child_count() - 1) if fill != null and node.get_child_count() > 0 else null,
		"walls": lod > 1 or fill == null}
	if fill != null and fill.get("sync_chunks"):
		_walls_for(key)


## F3: the twilight's light on the ground follows the sun (UrbsTerrain.set_sky_fill).
var _fill := -1.0


func _sky_fill() -> void:
	var atm: Variant = get_parent().get("atmosphere") if get_parent() != null else null
	if atm == null:
		return
	var f := UrbsTerrain.sky_fill_for(float(atm.get("elevation")))
	if absf(f - _fill) > 0.001:
		_fill = f
		UrbsTerrain.set_sky_fill(f)


## F3: the terrace walls of a chunk wait for its houses: only the walls holding up a tread that
## something stands on are built (UrbsSite.build_chunk_walls with wall_uses).
func _walls_step() -> void:
	for key: Vector2i in loaded:
		var e: Dictionary = loaded[key]
		if not bool(e["walls"]):
			var houses: Variant = e["houses"]
			if houses == null or not is_instance_valid(houses) or bool(houses.get("done")):
				_walls_for(key)
				return   # one chunk a frame


func _walls_for(key: Vector2i) -> void:
	var e: Dictionary = loaded[key]
	e["walls"] = true
	var ground: Variant = e["ground"]
	if ground == null or not is_instance_valid(ground):
		return
	var keys: Array = []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			keys.append(key + Vector2i(dx, dz))
	var uses := UrbsSite.wall_uses(fill, keys)
	var walls := UrbsSite.build_chunk_walls(rect_of(key), int(e["lod"]), UrbsTerrain.year, uses)
	if walls != null:
		(ground as Node3D).add_child(walls)


func _process(_delta: float) -> void:
	_walls_step()
	_sky_fill()
	var started := Time.get_ticks_usec()
	while not _wanted.is_empty():
		var next: Array = _wanted.pop_front()
		_build(next[1], next[2])
		if (Time.get_ticks_usec() - started) / 1000.0 > BUDGET_MSEC:
			break


## Build everything wanted at once (opening the city, screenshots).
func load_all_now() -> void:
	while not _wanted.is_empty():
		var next: Array = _wanted.pop_front()
		_build(next[1], next[2])


## How many of the nearest chunks (within 600 m) are still to be built.
func pending_near() -> int:
	var n := 0
	for w in _wanted:
		if w[0] < LOD_NEAR:
			n += 1
	return n
