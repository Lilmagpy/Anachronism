## Map camera in the style of Rise of Kingdoms: a fixed heading, drag or WASD to pan, wheel or
## pinch to zoom. Zoomed out it looks almost straight down at the strategic map; zooming in
## tilts it towards the horizon so towns and forests stand up (D-052).
class_name CameraRig
extends Node3D

const NEAR := 60.0
const FAR := 1100.0
const PITCH_NEAR := 0.72  ## radians above the horizon when fully zoomed in (about 41°)
const PITCH_FAR := 1.30   ## when fully zoomed out (about 75°)

var distance := 760.0
var target_distance := 760.0
var bounds := Rect2(-400, -400, 800, 800)  ## where the camera may look, on the ground plane
var camera := Camera3D.new()
var _dragging := false


func _ready() -> void:
	camera.fov = 40.0
	camera.near = 1.0
	camera.far = 6000.0
	add_child(camera)
	_apply()


## How far zoomed in, from 0 (fully out) to 1 (fully in).
func zoom_level() -> float:
	return 1.0 - inverse_lerp(log(NEAR), log(FAR), log(distance))


func look_at_point(point: Vector3, new_distance: float) -> void:
	position = Vector3(point.x, 0, point.z)
	distance = new_distance
	target_distance = new_distance
	_apply()


func _apply() -> void:
	distance = clampf(distance, NEAR, FAR)
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)
	var pitch := lerpf(PITCH_FAR, PITCH_NEAR, zoom_level())
	camera.position = Vector3(0, sin(pitch), cos(pitch)) * distance
	camera.look_at(global_position, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_distance = clampf(target_distance * 0.85, NEAR, FAR)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_distance = clampf(target_distance / 0.85, NEAR, FAR)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
	elif event is InputEventMagnifyGesture:
		target_distance = clampf(target_distance / event.factor, NEAR, FAR)
	elif event is InputEventPanGesture:
		_pan(event.delta * distance * 0.01)
	elif event is InputEventMouseMotion and _dragging:
		_pan(-event.relative * distance * 0.0015)


func _process(delta: float) -> void:
	var move := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if move != Vector2.ZERO:
		_pan(move * distance * delta)
	if absf(distance - target_distance) > 0.1:
		distance = lerpf(distance, target_distance, minf(1.0, delta * 8.0))
		_apply()


func _pan(amount: Vector2) -> void:
	position += Vector3(amount.x, 0, amount.y)
	_apply()
