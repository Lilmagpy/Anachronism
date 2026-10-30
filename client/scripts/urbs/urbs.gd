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
##   --yaw=DEG --pitch=DEG  look direction as a compass bearing (0 north, 90 east, 270 west)
##   --hour=H              time of day, 0-24 (default 10), local solar time   # U8 render
##   --day=N               day of the year for the sun's path (default 120)    # U8 render
##   --fx=nossao,nossil,noglow,nofog   turn post effects off (testing; atmosphere.gd)  # U8 render
##   --then=street|city|inside   after opening, glide to that mode (to photograph a transition)
##   --urbs-shots=t1,t2    with --screenshot: save PATH_tT.png at those seconds of the glide
##   --event=kind:ref[:monument]  play an engine event's spectacle (spectacles.gd header)
##   --spectacle=race|munus|senate|sacrifice|triumph  play one directly (with --at=<monument>)
##   --spectacle-view=N    put the camera at the spectacle's Nth own view
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
var life := UrbsLife.new()          ## U8 life: people, stalls, carts, smoke, lamps (life.gd)
var spectacle: Node3D               ## the spectacle playing, if any (spectacles/spectacles.gd)
var events: Array = []              ## the turn's city events (view["city"]["events"])
var sun := DirectionalLight3D.new()
var environment := Environment.new()
var atmosphere := UrbsAtmosphere.new()   # U8 render: sky, sun, haze, shadows, post (atmosphere.gd)
var sky_material: ShaderMaterial         # U8 render: the sky shader (atmosphere.sky_material)
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
	add_child(life)
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
func open(new_year: int, at := Vector3.ZERO, flags := {}, new_events: Array = []) -> void:
	year = new_year
	if _built_year != year:
		_rebuild()
	events = new_events
	life.set_events(events)
	if flags.has("fx"):   # U8 render
		atmosphere.set_fx(str(flags["fx"]))
	if flags.has("day"):   # U8 render
		atmosphere.day = int(flags["day"])
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
	_start_spectacle(flags)
	if spectacle != null and flags.has("spectacle-view") and spectacle.has_method("camera_views"):
		# --spectacle-view=N: one of the spectacle's own camera positions (stands, track, box ...)
		var views: Array = spectacle.camera_views()
		if not views.is_empty():
			cam.snap_inside(views[clampi(int(flags["spectacle-view"]), 0, views.size() - 1)])
	chunks.focus_on(cam.focus(), cam.mode == UrbsCamera.Mode.CITY)
	# The first picture is complete, not popping in: the fill finishes its chunks at once here,
	# then goes back to spreading its work over frames.
	fill.sync_chunks = true
	chunks.load_all_now()
	fill.sync_chunks = false
	# and the first crowd is in place too (life spreads its placement over frames otherwise)
	for i in 30:
		life.tick(1.0 / 30.0, cam.camera.global_position)


func close() -> void:
	active = false
	_stop_spectacle()
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
	life.build(self, year, hour, height)   # after the streets and monuments it walks among
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
	# The flag is a compass bearing; the camera's yaw turns the other way (it looks along
	# -sin(yaw), -cos(yaw) with x east and z south), so bearing B is yaw -B.
	var yaw := -deg_to_rad(float(flags.get("yaw", "0")))
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
			if at != "" and not at.contains(","):
				# stand out in front of the doorway, looking back at the façade
				var door: Transform3D = monuments.entrance(at)
				var model := str(monuments.entry(at).get("model", ""))
				var open_air := false
				var into := 0.0   # how far in from the entrance: past the stands to the arena's edge
				for k in ["circus", "theatre", "amphitheatre", "stadium", "plaza", "forum"]:
					if model.contains(k):
						open_air = true
						into = 0.0 if k in ["plaza", "forum"] else 35.0
				var outward := door.basis.z
				outward.y = 0.0
				outward = outward.normalized() if outward.length() > 0.01 else Vector3(0, 0, 1)
				# from the door out to the front of the steps, then far enough back to frame the façade
				var b := monuments.bounds(at)
				var front := 0.0
				for i in 8:
					var corner := b.get_endpoint(i) - door.origin
					front = maxf(front, corner.x * outward.x + corner.z * outward.z)
				var back := front + clampf(b.size.y * 1.8, 22.0, 60.0)
				stand = Vector3(door.origin.x, 0, door.origin.z) + outward * back
				if open_air:   # a venue open to the sky: stand at its entrance, looking in
					stand = Vector3(door.origin.x, 0, door.origin.z) - outward * into   # facing still looks in
				if not yaw_set:
					facing = atan2(outward.x, outward.z)   # looks along -outward, at the door
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
	# against each monument's real solids (open courts, plazas and low platforms do not block)
	p = monuments.push_out(p, radius, height_at(p.x, p.y) + h)
	if fill.has_method("push_out"):
		p = fill.push_out(p, radius, h)
	return p


func _process(_delta: float) -> void:
	if not active:
		return
	var orbit := cam.mode == UrbsCamera.Mode.CITY
	chunks.focus_on(cam.focus(), orbit)
	atmosphere.update(orbit, cam.dist, interior != null)   # U8 render: cascades, haze, SSAO by mode


# --- time of day, sky, fog ------------------------------------------------------------------

# U8 render: the sky, the sun and the environment are atmosphere.gd's.
func _build_sky() -> void:
	atmosphere.setup(environment, sun)
	sky_material = atmosphere.sky_material


## Time of day in hours, local solar time (about 5:20 sunrise, 12 noon, 18:40 sunset at the
## default day): moves the sun over Rome and re-tints sky, light and haze.   # U8 render
func set_hour(new_hour: float) -> void:
	hour = fposmod(new_hour, 24.0)
	atmosphere.set_hour(hour)
	sun.visible = atmosphere.sun_up() and interior == null
	life.set_hour(hour)


# --- spectacles -----------------------------------------------------------------------------

## Play what the city shows on opening: the `--event` / `--spectacle` flags if given, else the
## first of the turn's events that has a spectacle (a race in the Circus, the Senate at the
## Curia, a sacrifice, a triumph, a munus). One at a time; the street keeps fewer skinned
## figures meanwhile so both fit the renderer's per-instance budget.
func _start_spectacle(flags: Dictionary) -> void:
	_stop_spectacle()
	var sp: Node3D = UrbsSpectacles.handle_flags(flags, self)
	if sp == null:
		for e in events:
			if e is Dictionary and not UrbsSpectacles.from_event(e).is_empty():
				sp = UrbsSpectacles.play_event(e, self)
				if sp != null:
					break
	spectacle = sp
	life.set_spectacle(spectacle != null)


func _stop_spectacle() -> void:
	if spectacle != null and is_instance_valid(spectacle):
		UrbsSpectacles.stop()
	spectacle = null
	life.set_spectacle(false)


# --- picking and the monument card ---------------------------------------------------------

## The monument under a screen point, or "".
func pick_monument(screen: Vector2) -> String:
	return monuments.pick(cam.camera, screen)   # against the solids, so open courts are not picked


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
	# The circus, the arena and the theatre are open to the sky and keep the sun; a roofed
	# interior lights itself (lamps, doors, the compluvium) under a dark ceiling.
	var open_sky: bool = interior.has_method("open_sky") and interior.open_sky()
	sun.visible = open_sky
	if not open_sky:
		environment.background_mode = Environment.BG_COLOR
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
