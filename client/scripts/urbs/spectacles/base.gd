## Base of every spectacle (U6): a Node3D with its own clock. The scene is a pure function of
## the time `t` (seek(t) draws the scene at t), so a preview can jump to any moment and a
## replay always looks the same. `_process` just advances `t` and calls seek.
## Subclasses override `_apply(t)`, `seat_views()` and `view_names()`.
extends Node3D

signal finished

var t := 0.0
var duration := 60.0
var playing := true
var time_scale := 1.0
var params: Dictionary = {}


func _process(delta: float) -> void:
	if not playing:
		return
	t += delta * time_scale
	seek(t)
	if t >= duration:
		playing = false
		finished.emit()


## Draw the scene at time `time` seconds.
func seek(time: float) -> void:
	t = time
	_apply(time)


func _apply(_time: float) -> void:
	pass


## Camera presets, local to this node (multiply by global_transform for world use).
func seat_views() -> Array[Transform3D]:
	return []


## The camera presets in WORLD space (seat_views() moved by this node's transform), for the
## city's camera to glide to.
func camera_views() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var g := global_transform if is_inside_tree() else transform
	for v in seat_views():
		out.append(g * v)
	return out


func view_names() -> PackedStringArray:
	return PackedStringArray()


## A floating text line (speech, a label) that faces the camera.
func make_label(text: String, size := 0.5, col := Color(1, 1, 1)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = 0.012 * size
	l.font_size = 48
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color(0.05, 0.04, 0.03)
	add_child(l)
	return l


static func smooth(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


static func look(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
