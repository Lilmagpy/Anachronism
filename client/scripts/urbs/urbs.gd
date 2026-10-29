## Urbs (D-289): the city of Rome you can walk into. The scene root of the whole mode: it owns
## the sun and time of day, the sky and the distance fog, the three cameras and the HUD, the
## chunk loader, and it calls the other scripts' builders.
##
## ## The interface the other scripts keep (stubs of each are in `stubs/`; the real class
## replaces the stub and keeps these names and signatures)
##
##   UrbsTerrain (terrain.gd)
##     build(urbs: Node3D)                       whole-scene parts: Tiber, sea, walls...
##     height_at(x, z) -> float                  ground height, local metres
##     build_chunk(rect: Rect2, lod: int) -> Node3D    the ground of one 250 m chunk
##   UrbsStreets (streets.gd)
##     build(urbs: Node3D, year: int, height: Callable)   streets of the year; height(x, z) -> y
##   UrbsMonuments (monuments.gd)
##     build(urbs: Node3D, year: int, height: Callable)   every monument standing in `year`
##     ids() -> Array                            ids of those standing
##     bounds(id) -> AABB                        local-metre box, used for clicking and collision
##     info(id) -> Dictionary                    {latin, english, year, by, form, sources: Array,
##                                               enterable: bool}
##     entrance(id) -> Transform3D               the doorway, looking inwards, local metres
##   UrbsFill (fill.gd)
##     build(urbs: Node3D, year: int, height: Callable)   per-year set-up (density from population)
##     build_chunk(rect: Rect2, lod: int, height: Callable) -> Node3D   houses of one chunk
##     push_out(p: Vector2, radius: float, h: float) -> Vector2          optional: collision
##   UrbsInterior (interior.gd)
##     build(urbs: Node3D, id: String, year: int) -> Node3D   the inside; may define
##                                               spawn() -> Transform3D (default: 1.7 m above
##                                               the origin facing -z)
##   `lod` is 0 (best) to 2 (coarsest); chunks are `UrbsChunks.SIZE` = 250 m squares.
##
## ## Command-line flags (main.gd passes them in `open`)
##   --urbs                open the city straight away (after the map has loaded)
##   --year=N              the year to build (default: the game's year; BC is negative)
##   --at=<monument_id>    put the camera at that monument; or --at=x,z,h : local metres x, z
##                         and h (street: eye height; city: orbit distance)
##   --mode=city|street|inside   which camera (default city)
##   --yaw=DEG --pitch=DEG  look direction (0 = north) for the street camera
##   --hour=H              time of day, 0-24 (default 10)
##   --then=street|city|inside   after opening, glide to that mode (to photograph a transition)
##   --urbs-shots=t1,t2    with --screenshot: save PATH_tT.png at those seconds of the glide
class_name Urbs
extends Node3D

signal exit_requested        ## leave for the strategy map (Esc from CITY, or zoom out past the city)
signal entered_monument(id: String)

const FADE_COLOUR := Color(0.05, 0.045, 0.04)

var year := -300
var active := false
var terrain := UrbsTerrain.new()
var streets := UrbsStreets.new()
var monuments := UrbsMonuments.new()
var fill := UrbsFill.new()
var interiors := UrbsInterior.new()
var chunks := UrbsChunks.new()
var cam := UrbsCamera.new()
var hud := UrbsHud.new()
var sun := DirectionalLight3D.new()
var environment := Environment.new()
var sky_material := ProceduralSkyMaterial.new()
var hour := 10.0
var selected := ""                  ## the monument whose card is open
var interior: Node3D                ## the interior being visited, if INSIDE
var _built_year := 999999
var _city_nodes: Array = []         ## nodes the builders added (freed when the year changes)
var _hidden: Array = []             ## nodes hidden while inside
var _fader := CanvasLayer.new()
var _fade := ColorRect.new()
var _fade_tween: Tween
var _entry := Transform3D()         ## the doorway we went in by
var _ready_done := false


func _ready() -> void:
	name = "Urbs"
	_build_sky()
	add_child(sun)
	cam.urbs = self
	add_child(cam)
	cam.camera.environment = environment
	chunks.terrain = terrain
	chunks.fill = fill
	chunks.height = Callable(self, "height_at")
	add_child(chunks)
	add_child(hud)
	hud.back_pressed.connect(_back)
	hud.enter_pressed.connect(func() -> void:
		if selected != "":
			enter_monument(selected))
	hud.card_closed.connect(func() -> void: selected = "")
	cam.back_requested.connect(_back)
	cam.exit_requested.connect(func() -> void: exit_requested.emit())
	cam.clicked.connect(_on_click)
	cam.mode_changed.connect(func(m: int) -> void: hud.set_mode(m))
	_fader.layer = 90
	_fade.color = FADE_COLOUR
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fader.add_child(_fade)
	add_child(_fader)
	set_hour(hour)
	close()
	_ready_done = true


# --- opening and closing -----------------------------------------------------------------

## Build the city of `new_year` (once per year) and take over the screen. `at` is the local
## point to open over (default the Forum); `flags` are the command-line options.
func open(new_year: int, at := Vector3.ZERO, flags := {}) -> void:
	year = new_year
	if _built_year != year:
		_rebuild()
	if flags.has("hour"):
		set_hour(float(flags["hour"]))
	hud.set_year(year)
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	hud.visible = true
	_fader.visible = true
	cam.camera.current = true
	set_hour(hour)
	var target := at
	cam.snap_city(target, 1500.0)
	_apply_flags(flags)
	chunks.focus_on(cam.focus(), cam.mode == UrbsCamera.Mode.CITY)
	chunks.load_all_now()   # the first picture is complete, not popping in


func close() -> void:
	active = false
	if interior != null:
		_leave_interior_now()
	visible = false
	hud.visible = false
	hud.hide_card()
	selected = ""
	process_mode = Node.PROCESS_MODE_DISABLED
	cam.camera.current = false


func _rebuild() -> void:
	for node in _city_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_city_nodes.clear()
	for key in chunks.loaded.keys():
		chunks._free(key)
	chunks._wanted.clear()
	var before := get_children()
	terrain.build(self)
	var height := Callable(self, "height_at")
	streets.build(self, year, height)
	monuments.build(self, year, height)
	fill.build(self, year, height)
	for node in get_children():
		if not before.has(node):
			_city_nodes.append(node)
	_built_year = year


func _apply_flags(flags: Dictionary) -> void:
	var mode := str(flags.get("mode", "city"))
	var at := str(flags.get("at", ""))
	var spot := Vector3.ZERO
	var has_spot := false
	var height := -1.0
	var yaw_set := flags.has("yaw")
	var yaw := deg_to_rad(float(flags.get("yaw", "0")))
	if at.contains(","):
		var f := at.split(",")
		spot = Vector3(float(f[0]), 0, float(f[1]))
		height = float(f[2]) if f.size() > 2 else -1.0
		has_spot = true
	elif at != "" and monuments.ids().has(at):
		var b := monuments.bounds(at)
		spot = b.get_center()
		has_spot = true
		selected = at
	if not has_spot:
		return
	spot.y = height_at(spot.x, spot.z)
	match mode:
		"street":
			var stand := spot
			var facing := yaw
			if at != "" and not at.contains(","):   # stand south of the monument, looking at it
				var b := monuments.bounds(at)
				stand = Vector3(spot.x, 0, b.end.z + maxf(b.size.z * 0.4, 25.0))
				facing = 0.0
			cam.snap_street(stand, facing, maxf(height, UrbsCamera.EYE), deg_to_rad(float(flags.get("pitch", "3"))))
		"inside":
			if at != "" and not at.contains(","):
				_enter_interior_now(at)
		_:
			cam.snap_city(spot, height if height > 0.0 else 320.0, yaw if yaw_set else 0.3)
	if selected != "" and mode != "inside":
		hud.show_card(monuments.info(selected))


# --- the world ---------------------------------------------------------------------------

## Ground height at local (x, z).
func height_at(x: float, z: float) -> float:
	return terrain.height_at(x, z)


## Keep a walker of `radius` at `h` m above the ground out of buildings: the new position.
func push_out(p: Vector2, radius: float, h: float) -> Vector2:
	var eye_y := height_at(p.x, p.y) + h
	for id in monuments.ids():
		var b: AABB = monuments.bounds(id)
		if eye_y > b.end.y + 0.5:
			continue   # flying over it
		var grown := Rect2(b.position.x - radius, b.position.z - radius, b.size.x + radius * 2, b.size.z + radius * 2)
		if grown.has_point(p):
			var left := p.x - grown.position.x
			var right := grown.end.x - p.x
			var top := p.y - grown.position.y
			var bottom := grown.end.y - p.y
			var m := minf(minf(left, right), minf(top, bottom))
			if m == left: p.x = grown.position.x
			elif m == right: p.x = grown.end.x
			elif m == top: p.y = grown.position.y
			else: p.y = grown.end.y
	if fill.has_method("push_out"):
		p = fill.push_out(p, radius, h)
	return p


func _process(_delta: float) -> void:
	if not active:
		return
	var orbit := cam.mode == UrbsCamera.Mode.CITY
	chunks.focus_on(cam.focus(), orbit)
	var reach: float = cam.dist * 1.6 if orbit else 400.0
	sun.directional_shadow_max_distance = clampf(reach, 150.0, 2500.0)
	environment.fog_density = 0.00012 if orbit else 0.00032
	if interior != null:
		environment.fog_enabled = false
	else:
		environment.fog_enabled = true


# --- time of day, sky, fog ------------------------------------------------------------------

func _build_sky() -> void:
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_density = 0.00025
	environment.fog_sky_affect = 0.6
	environment.fog_aerial_perspective = 0.25
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.light_angular_distance = 0.5


## Time of day in hours (6 sunrise, 12 noon, 18 sunset): moves the sun and re-tints sky and fog.
func set_hour(new_hour: float) -> void:
	hour = fposmod(new_hour, 24.0)
	var day := clampf((hour - 6.0) / 12.0, -0.2, 1.2)
	var elevation := sin(clampf(day, 0.0, 1.0) * PI) * 62.0 + 2.0   # degrees; 2 degrees at the horizon
	if hour < 5.5 or hour > 18.5:
		elevation = -10.0
	sun.rotation_degrees = Vector3(-elevation, (12.0 - hour) / 6.0 * 90.0, 0.0)
	var high := smoothstep(0.0, 25.0, elevation)            # 0 at the horizon .. 1 in full day
	sun.light_energy = 1.7 * smoothstep(-2.0, 12.0, elevation)
	sun.visible = elevation > -2.0 and interior == null
	sun.light_color = Color(1.0, 0.62, 0.38).lerp(Color(1.0, 0.94, 0.84), high)
	var night := 1.0 - smoothstep(-8.0, 6.0, elevation)
	var top := Color(0.20, 0.38, 0.68).lerp(Color(0.02, 0.03, 0.08), night)
	var horizon := Color(0.80, 0.68, 0.56).lerp(Color(0.80, 0.74, 0.66), high).lerp(Color(0.06, 0.06, 0.10), night)
	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	sky_material.ground_bottom_color = horizon.darkened(0.35)
	sky_material.sun_angle_max = 40.0
	environment.fog_light_color = horizon.lerp(Color(0.8, 0.8, 0.8), 0.15)
	environment.ambient_light_energy = lerpf(0.25, 0.65, 1.0 - night)


# --- picking and the monument card ---------------------------------------------------------

## The monument under a screen point, or "".
func pick_monument(screen: Vector2) -> String:
	var origin := cam.camera.project_ray_origin(screen)
	var dir := cam.camera.project_ray_normal(screen)
	var best := ""
	var best_t := INF
	for id in monuments.ids():
		var t := _ray_box(origin, dir, monuments.bounds(id))
		if t >= 0.0 and t < best_t:
			best_t = t
			best = id
	return best


static func _ray_box(origin: Vector3, dir: Vector3, box: AABB) -> float:
	var t_min := 0.0
	var t_max := INF
	for axis in 3:
		var inv := 1.0 / dir[axis] if absf(dir[axis]) > 1e-9 else 1e9
		var t1 := (box.position[axis] - origin[axis]) * inv
		var t2 := (box.end[axis] - origin[axis]) * inv
		t_min = maxf(t_min, minf(t1, t2))
		t_max = minf(t_max, maxf(t1, t2))
	return t_min if t_min <= t_max else -1.0


func _on_click(screen: Vector2) -> void:
	if interior != null:
		return
	var id := pick_monument(screen)
	if id == "":
		hud.hide_card()
		selected = ""
		return
	selected = id
	hud.show_card(monuments.info(id))


# --- going in and out -----------------------------------------------------------------------

## Esc: close a card; INSIDE -> street; STREET -> city; CITY -> the map.
func _back() -> void:
	if cam.is_gliding():
		return
	if hud.card_open():
		hud.hide_card()
		selected = ""
	elif cam.mode == UrbsCamera.Mode.INSIDE:
		leave_monument()
	elif cam.mode == UrbsCamera.Mode.STREET:
		var ahead := Vector3(-sin(cam.yaw), 0, -cos(cam.yaw))
		cam.go_city(cam.pos + ahead * 80.0, 260.0)
	else:
		exit_requested.emit()


## Fade a black veil in (1) or out (0).
func fade_to(alpha: float, seconds: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "modulate:a", alpha, seconds).set_trans(Tween.TRANS_SINE)
	await _fade_tween.finished


## Glide through the monument's door, then fade into its interior.
func enter_monument(id: String) -> void:
	if cam.is_gliding() or interior != null:
		return
	_entry = monuments.entrance(id)
	hud.hide_card()
	cam.go_inside(_entry)
	await cam.glide_finished
	await fade_to(1.0, 0.25)
	_enter_interior_now(id)
	await fade_to(0.0, 0.5)
	entered_monument.emit(id)


func _enter_interior_now(id: String) -> void:
	_entry = monuments.entrance(id)
	interior = interiors.build(self, id, year)
	if interior == null:
		return
	interior.name = "Interior"
	add_child(interior)
	_hidden.clear()
	for node in get_children():
		if node is Node3D and node != interior and node != cam and node != sun and node.visible:
			node.visible = false
			_hidden.append(node)
	chunks.process_mode = Node.PROCESS_MODE_DISABLED
	sun.visible = false
	environment.background_mode = Environment.BG_COLOR   # a roof, not the sky: the interior lights itself
	environment.background_color = Color(0.04, 0.035, 0.03)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.50, 0.44)
	environment.ambient_light_energy = 0.6
	var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0))
	if interior.has_method("spawn"):
		spawn = interior.spawn()
	cam.snap_inside(spawn)
	hud.set_inside(true, monuments.info(id))


## Back out of the door to the street.
func leave_monument() -> void:
	if interior == null:
		return
	await fade_to(1.0, 0.25)
	_leave_interior_now()
	var out := Vector3(_entry.origin.x, 0, _entry.origin.z)
	var facing := atan2(-(-_entry.basis.z).x, -(-_entry.basis.z).z) + PI   # turn round to face the street
	cam.snap_street(out, facing)
	await fade_to(0.0, 0.5)


func _leave_interior_now() -> void:
	if interior != null:
		interior.queue_free()
		interior = null
	for node in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()
	chunks.process_mode = Node.PROCESS_MODE_INHERIT
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	set_hour(hour)
	hud.set_inside(false, {})
