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


## One close cinematic view (it may follow the action at `time`); local to this node.
func cine_view(_time: float) -> Transform3D:
	var v := seat_views()
	return v[0] if v.size() > 0 else Transform3D()


## The cinematic view in WORLD space.
func cine_camera(time: float) -> Transform3D:
	return (global_transform if is_inside_tree() else transform) * cine_view(time)


func view_names() -> PackedStringArray:
	return PackedStringArray()


## F2 play: the ground the spectacle takes, as capsules [Vector2 a, Vector2 b, radius] in world x,
## z (a == b is a circle): the street life (life.gd set_clear_zone) keeps out of it while it
## plays. Default: 30 m round the origin; each spectacle gives its own.
func clear_area() -> Array:
	return [zone_circle(Vector3.ZERO, 30.0)]


## A circle of `r` metres round local point `p`, for clear_area.
func zone_circle(p: Vector3, r: float) -> Array:
	return zone_capsule(p, p, r)


## A capsule from local `a` to local `b`, `r` metres wide each side, for clear_area.
func zone_capsule(a: Vector3, b: Vector3, r: float) -> Array:
	var g := global_transform if is_inside_tree() else transform
	var wa := g * a
	var wb := g * b
	return [Vector2(wa.x, wa.z), Vector2(wb.x, wb.z), r]


## A floating text line (speech, a label) that faces the camera.
func make_label(text: String, size := 0.5, col := Color(1, 1, 1)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = 0.009 * size
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
