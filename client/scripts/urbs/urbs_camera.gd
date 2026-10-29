## Urbs (D-289): the city's three cameras and the glides between them.
##
## CITY   orbit over the city: drag (or WASD) pans, wheel zooms, right-drag turns and tilts.
##        Never lower than 30 m above the ground. Zooming in past the closest orbit dives to
##        STREET; zooming out past the whole city asks to leave (`exit_requested`).
## STREET free fly at walking height: WASD or arrows move, right-drag looks, wheel changes
##        the height (1.7 m is walking; higher is a bird's-eye fly), shift runs. Terrain and
##        buildings stop you (`Urbs.push_out`). Wheel out past 150 m rises to CITY.
## INSIDE looking round an interior: right-drag looks, WASD walks. Its scene is the
##        interiors agent's; Urbs hands the camera the pose.
##
## Every change of mode is a glide of the camera between two poses (no pops): the new mode's
## pose is computed every frame and the camera eases from where it was to it. Esc steps back
## one level (`back_requested`).
class_name UrbsCamera
extends Node3D

enum Mode { CITY, STREET, INSIDE }

signal mode_changed(mode: int)
signal exit_requested       ## wheel out past the whole city (the strategy map takes over)
signal back_requested       ## Esc
signal clicked(screen: Vector2)
signal glide_finished

const MIN_ORBIT := 90.0             ## closest orbit distance (camera is >= 30 m up there)
const MAX_ORBIT := 4600.0
const MIN_ABOVE_GROUND := 30.0      ## the city camera never goes lower than this
const EYE := 1.7
const MAX_FLY := 150.0
const ZOOM_STEP := 0.82
const FOV_CITY := 45.0
const FOV_STREET := 70.0

var urbs: Node                       ## provides height_at(x, z) and push_out(pos, radius, h)
var camera := Camera3D.new()
var mode := Mode.CITY
# --- CITY state
var target := Vector3.ZERO           ## the ground point being orbited
var yaw := 0.0                       ## 0 = looking north
var tilt := 0.0                      ## the player's extra pitch on top of the zoom's
var dist := 1800.0
var dist_goal := 1800.0
# --- STREET / INSIDE state
var pos := Vector3.ZERO              ## x, z of the walker (street) or the full eye point (inside)
var pitch := -0.1
var h := EYE                         ## eye height above the ground (street)
var h_goal := EYE
var _vel := Vector3.ZERO
# --- input / glide
var _drag_left := false
var _drag_right := false
var _press_at := Vector2.ZERO
var _moved_px := 0.0
var _glide_left := 0.0
var _glide_total := 1.0
var _glide_from := Transform3D()
var _glide_fov := FOV_CITY
var _fov_goal := FOV_CITY


func _ready() -> void:
	camera.far = 9000.0
	camera.near = 0.3
	camera.fov = FOV_CITY
	add_child(camera)


func is_gliding() -> bool:
	return _glide_left > 0.0


## The point the world loads around: the orbit target, or the walker.
func focus() -> Vector3:
	return target if mode == Mode.CITY else Vector3(pos.x, camera.global_position.y, pos.z)


# --- poses -----------------------------------------------------------------------------

func _ground(x: float, z: float) -> float:
	return float(urbs.height_at(x, z)) if urbs != null else 10.0


func _orbit_pitch() -> float:
	var k := inverse_lerp(log(MIN_ORBIT), log(MAX_ORBIT), log(dist))   # 0 near .. 1 far
	return clampf(lerpf(0.36, 1.05, k) + tilt, 0.2, 1.5)


func _pose() -> Transform3D:
	match mode:
		Mode.CITY:
			var p := _orbit_pitch()
			var at := target + Vector3(sin(yaw) * cos(p), sin(p), cos(yaw) * cos(p)) * dist
			var floor_y := _ground(at.x, at.z) + MIN_ABOVE_GROUND
			at.y = maxf(at.y, floor_y)
			return Transform3D(Basis.IDENTITY, at).looking_at(target, Vector3.UP)
		Mode.STREET:
			var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
			return Transform3D(basis, Vector3(pos.x, _ground(pos.x, pos.z) + h, pos.z))
		_:
			var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
			return Transform3D(basis, pos)


func _glide(seconds: float, to_fov: float) -> void:
	_glide_from = camera.global_transform
	_glide_fov = camera.fov
	_fov_goal = to_fov
	_glide_total = maxf(seconds, 0.01)
	_glide_left = _glide_total


# --- mode changes ------------------------------------------------------------------------

## Put the camera straight into CITY mode over `at` (no glide).
func snap_city(at: Vector3, new_dist: float, new_yaw := 0.3) -> void:
	mode = Mode.CITY
	target = Vector3(at.x, _ground(at.x, at.z), at.z)
	dist = clampf(new_dist, MIN_ORBIT, MAX_ORBIT)
	dist_goal = dist
	yaw = new_yaw
	tilt = 0.0
	_glide_left = 0.0
	camera.fov = FOV_CITY
	_fov_goal = FOV_CITY
	camera.global_transform = _pose()
	mode_changed.emit(mode)


## Put the camera straight on the street at `at` facing `new_yaw`.
func snap_street(at: Vector3, new_yaw: float, height := EYE, new_pitch := -0.05) -> void:
	mode = Mode.STREET
	pos = at
	yaw = new_yaw
	pitch = new_pitch
	h = height
	h_goal = height
	_vel = Vector3.ZERO
	_glide_left = 0.0
	camera.fov = FOV_STREET
	_fov_goal = FOV_STREET
	camera.global_transform = _pose()
	mode_changed.emit(mode)


## Look round an interior from the pose `xform` (no glide).
func snap_inside(xform: Transform3D) -> void:
	_set_inside(xform)
	_glide_left = 0.0
	camera.fov = 75.0
	_fov_goal = 75.0
	camera.global_transform = _pose()
	mode_changed.emit(mode)


func _set_inside(xform: Transform3D) -> void:
	mode = Mode.INSIDE
	var euler := xform.basis.get_euler(EULER_ORDER_YXZ)
	yaw = euler.y
	pitch = euler.x
	pos = xform.origin
	_vel = Vector3.ZERO


## Glide from wherever the camera is to the orbit over `at`.
func go_city(at: Vector3, new_dist := 300.0, seconds := 1.4) -> void:
	_glide(seconds, FOV_CITY)
	mode = Mode.CITY
	target = Vector3(at.x, _ground(at.x, at.z), at.z)
	dist = clampf(new_dist, MIN_ORBIT, MAX_ORBIT)
	dist_goal = dist
	tilt = 0.0
	mode_changed.emit(mode)


## Glide down to the street at `at` (x, z used), facing `new_yaw` (default: the current view).
func go_street(at: Vector3, new_yaw := NAN, seconds := 1.3) -> void:
	_glide(seconds, FOV_STREET)
	if not is_nan(new_yaw):
		yaw = new_yaw
	mode = Mode.STREET
	pos = at
	pitch = -0.08
	h = EYE
	h_goal = EYE
	_vel = Vector3.ZERO
	mode_changed.emit(mode)


## Glide through a doorway: to `xform` (from the monuments script's `entrance(id)`).
func go_inside(xform: Transform3D, seconds := 1.2) -> void:
	_glide(seconds, 75.0)
	_set_inside(xform)
	mode_changed.emit(mode)


## Glide to a look at `at` from `from_pos` (used by --at=x,z,h).
func look_from(from_pos: Vector3, at: Vector3) -> void:
	var dir := (at - from_pos)
	snap_street(from_pos - Vector3(0, _ground(from_pos.x, from_pos.z), 0), atan2(-dir.x, -dir.z),
		maxf(from_pos.y - _ground(from_pos.x, from_pos.z), EYE),
		atan2(dir.y, Vector2(dir.x, dir.z).length()))


# --- input ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not camera.current:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		back_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if is_gliding():
		return
	if event is InputEventMouseButton:
		var wheel := 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			wheel = 1.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			wheel = -1.0
		if wheel != 0.0:
			_wheel(wheel)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_drag_left = event.pressed
			if event.pressed:
				_press_at = event.position
				_moved_px = 0.0
			elif _moved_px < 6.0:
				clicked.emit(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_drag_right = event.pressed
	elif event is InputEventMagnifyGesture:
		_wheel(1.0 if event.factor > 1.0 else -1.0)
	elif event is InputEventMouseMotion:
		if _drag_left:
			_moved_px += event.relative.length()
		if _drag_right:
			_look(event.relative)
		elif _drag_left and mode == Mode.CITY and _moved_px >= 6.0:
			var scale := dist * 0.0016
			var right := Vector3(cos(yaw), 0, -sin(yaw))
			var forward := Vector3(-sin(yaw), 0, -cos(yaw))
			target += (-right * event.relative.x + forward * event.relative.y) * scale
			_clamp_target()
		elif _drag_left and mode != Mode.CITY and _moved_px >= 6.0:
			_look(event.relative * 0.6)   # dragging with the left button looks round, too


func _look(relative: Vector2) -> void:
	if mode == Mode.CITY:
		yaw -= relative.x * 0.005
		tilt = clampf(tilt + relative.y * 0.003, -0.5, 0.4)
	else:
		yaw -= relative.x * 0.004
		pitch = clampf(pitch - relative.y * 0.004, -1.45, 1.45)


func _wheel(direction: float) -> void:
	match mode:
		Mode.CITY:
			if direction > 0.0:
				if dist_goal <= MIN_ORBIT * 1.05:
					go_street(target)          # past the closest orbit: dive to the street
				else:
					dist_goal = maxf(dist_goal * ZOOM_STEP, MIN_ORBIT)
			else:
				if dist_goal >= MAX_ORBIT * 0.95:
					exit_requested.emit()      # past the whole city: back to the map
				else:
					dist_goal = minf(dist_goal / ZOOM_STEP, MAX_ORBIT)
		Mode.STREET:
			if direction > 0.0:
				h_goal = maxf(h_goal / 1.22, EYE)
			elif h_goal >= MAX_FLY:
				var ahead := Vector3(-sin(yaw), 0, -cos(yaw))
				go_city(pos + ahead * 80.0, 260.0)
			else:
				h_goal = minf(h_goal * 1.22, MAX_FLY)


func _clamp_target() -> void:
	var flat := Vector2(target.x, target.z)
	if flat.length() > UrbsGeo.RADIUS_M:
		flat = flat.normalized() * UrbsGeo.RADIUS_M
		target.x = flat.x
		target.z = flat.y
	target.y = _ground(target.x, target.z)


func _axis() -> Vector2:
	var x := Input.get_axis("ui_left", "ui_right") + _key(KEY_D) - _key(KEY_A)
	var y := Input.get_axis("ui_up", "ui_down") + _key(KEY_S) - _key(KEY_W)
	return Vector2(clampf(x, -1, 1), clampf(y, -1, 1))


func _key(code: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(code) else 0.0


# --- per frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var move := Vector2.ZERO if is_gliding() else _axis()
	match mode:
		Mode.CITY:
			if move != Vector2.ZERO:
				var speed := dist * 0.7
				var right := Vector3(cos(yaw), 0, -sin(yaw))
				var forward := Vector3(-sin(yaw), 0, -cos(yaw))
				target += (right * move.x - forward * move.y) * speed * delta
				_clamp_target()
			dist = exp(lerpf(log(dist), log(dist_goal), 1.0 - exp(-9.0 * delta)))
			target.y = lerpf(target.y, _ground(target.x, target.z), 1.0 - exp(-8.0 * delta))
		Mode.STREET:
			_walk(move, delta)
			h = lerpf(h, h_goal, 1.0 - exp(-10.0 * delta))
		Mode.INSIDE:
			var run := Input.is_physical_key_pressed(KEY_SHIFT)
			var basis := Basis(Vector3.UP, yaw)
			var want := (basis * Vector3(move.x, 0, move.y)) * (7.0 if run else 3.0)
			_vel = _vel.lerp(want, 1.0 - exp(-10.0 * delta))
			pos += _vel * delta
	camera.near = 0.3 if mode != Mode.CITY else maxf(1.0, dist * 0.02)
	if _glide_left > 0.0:
		_glide_left = maxf(_glide_left - delta, 0.0)
		var t := 1.0 - _glide_left / _glide_total
		var e := t * t * (3.0 - 2.0 * t)   # smoothstep: eased at both ends
		camera.global_transform = _glide_from.interpolate_with(_pose(), e)
		camera.fov = lerpf(_glide_fov, _fov_goal, e)
		if _glide_left <= 0.0:
			glide_finished.emit()
	else:
		camera.global_transform = _pose()
		camera.fov = _fov_goal


## Walk or fly in STREET mode: smooth acceleration, then terrain and building collision.
func _walk(move: Vector2, delta: float) -> void:
	var run := Input.is_physical_key_pressed(KEY_SHIFT)
	var flying := h > 3.0
	var speed := (4.0 + h * 0.6) * (3.0 if run else 1.0) if flying else (9.0 if run else 4.0)
	var basis := Basis(Vector3.UP, yaw)
	var want := (basis * Vector3(move.x, 0, move.y)) * speed
	_vel = _vel.lerp(want, 1.0 - exp(-8.0 * delta))
	var next := pos + _vel * delta
	if urbs != null and urbs.has_method("push_out"):
		var fixed: Vector2 = urbs.push_out(Vector2(next.x, next.z), 0.5, h)
		next.x = fixed.x
		next.z = fixed.y
	var flat := Vector2(next.x, next.z)
	if flat.length() > UrbsGeo.RADIUS_M:
		flat = flat.normalized() * UrbsGeo.RADIUS_M
		next.x = flat.x
		next.z = flat.y
	pos = next
