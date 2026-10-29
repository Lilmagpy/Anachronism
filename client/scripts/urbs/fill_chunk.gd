## Urbs (D-289): one 250 m chunk of houses, filled over several frames. `UrbsFill.build_chunk`
## returns this node at once; each frame it works for at most `BUDGET_MS` (the lot layout of the
## regions it covers, then one MultiMesh per kind of building, trees, props, the ground between the
## houses) and adds its parts to itself, so walking or flying never hitches. `finish_now()` does
## everything immediately (previews, tests).
class_name UrbsFillChunk
extends Node3D

const BUDGET_MS := 2.5

var fill: UrbsFill
var key := Vector2i.ZERO
var lod := 0
var done := false
var stage := 0
var lots: Array = []
var _regions: Array = []
var _buckets := {}
var _bucket_keys: Array = []
var _bi := 0
var _floor_state := {}
var _rural_state := {}


func _process(_delta: float) -> void:
	if done:
		set_process(false)
		return
	step(BUDGET_MS)


func finish_now() -> void:
	while not done:
		step(1.0e6)


## Work for about `ms` milliseconds.
func step(ms: float) -> void:
	var deadline := Time.get_ticks_usec() + int(ms * 1000.0)
	while not done and Time.get_ticks_usec() < deadline:
		match stage:
			0:
				if _regions.is_empty():
					_regions = fill.regions_for_chunk(key)
				var pending := false
				for rk in _regions:
					if not fill.advance_region(rk, deadline):
						pending = true
						break
				if not pending:
					stage = 1
			1:
				lots = fill.lots_for_chunk(key)
				for lot in lots:
					var mk := str(lot["mesh"])
					if lod >= 2 and (mk.begins_with("taberna") or mk.begins_with("prop") or mk.begins_with("furn")):
						continue
					if lod >= 1 and mk.begins_with("prop"):
						continue
					if not _buckets.has(mk):
						_buckets[mk] = []
					_buckets[mk].append(lot)
					if mk == "horti":
						fill.add_trees(lot, _buckets, lod)
				_bucket_keys = _buckets.keys()
				_bucket_keys.sort()
				stage = 2
			2:
				if _bi < _bucket_keys.size():
					var mk: String = _bucket_keys[_bi]
					add_child(fill.make_instances(_buckets[mk], mk, lod))
					_bi += 1
				else:
					stage = 3
			3:
				if fill.rural_step(key, _rural_state, deadline):
					stage = 4
			4:
				fill.rural_build(self, _rural_state.get("parcels", []), lod)
				stage = 5
			5:
				if fill.floor_step(self, key, lots, lod, _floor_state, deadline):
					stage = 6
			_:
				fill.chunk_finished(key, lots)
				done = true
