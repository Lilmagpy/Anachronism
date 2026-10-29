## Entry point of the spectacles (U6): UrbsSpectacles.play(kind, params, parent) -> Node3D.
## kind is "race", "munus", "senate", "sacrifice" or "triumph"; params are the engine's view of
## the event plus the venue's geometry (see each script's header). The returned node is a
## spectacle (base.gd): it plays by itself in _process, can be seeked (seek(t)), exposes
## seat_views() camera presets and emits `finished`. stop() frees the current one.
class_name UrbsSpectacles
extends RefCounted

const PATHS := {
	"race": "res://scripts/urbs/spectacles/race.gd",
	"munus": "res://scripts/urbs/spectacles/munus.gd",
	"senate": "res://scripts/urbs/spectacles/senate.gd",
	"sacrifice": "res://scripts/urbs/spectacles/sacrifice.gd",
	"triumph": "res://scripts/urbs/spectacles/triumph.gd",
}

static var _current: Node3D


static func kinds() -> PackedStringArray:
	return PackedStringArray(PATHS.keys())


## Start a spectacle under `parent` (placed by the caller: set .transform / .position on the result).
static func play(kind: String, params: Dictionary, parent: Node) -> Node3D:
	stop()
	if not PATHS.has(kind):
		push_error("UrbsSpectacles: unknown kind %s" % kind)
		return null
	var script: GDScript = load(PATHS[kind])
	var node: Node3D = script.new(params)
	node.name = "Spectacle_" + kind
	parent.add_child(node)
	_current = node
	return node


## Remove the spectacle that is playing.
static func stop() -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = null
