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
##   F3: --sweep=<poses.json> --sweep-out=<dir>  photograph many viewpoints in one run (sweep.gd)
##   F2 play (places.gd, moments.gd): --places-fixture  use client/data/fixtures/places_264.json
##   even when the view has places; --moments  play the fixture's year of events as moments;
##   --list-closed  start with "Rome this year" folded; --moment-speed=X  moments X times faster;
##   --moments-pick=i,j  only those of the fixture's events (0-based). main.gd's --then=act|moments|endyear
##   (with --act=<action id> at --at=<monument>) drive them for screenshots.
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
var anachronisms := UrbsAnachronisms.new()   # F1 ideas: the player's early works (anachronisms.gd)
var city_view: Dictionary = {}      ## F1 ideas: view["city"] (main.gd sets it before open)
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
# --- F2 play (begin): the places' actions, End year and the moments (places.gd, moments.gd) ---
var places := UrbsPlaces.new()
var moments := UrbsMoments.new()
var play_view: Dictionary = {}   ## the game view (main.gd: set_play_view before open and after each act)
var act_hook: Callable           ## main.gd: func(action) -> {accepted, message, view}, or null
var end_year_hook: Callable      ## main.gd: func() -> the new view after end_turn, or null
var idea_hook: Callable          ## main.gd: func(text, context, done: Callable(reply))
var interior_id := ""            ## the monument whose interior is open
var force_fixture := false
var _results := {}               ## place id -> the last action's {accepted, message} there
var _result_for := ""            ## the place of the last action
var _idea_place := ""
var _acting := false
var _fixture_pick: Array = []    ## --moments-pick=i,j: which of the fixture's events --moments plays
# --- F2 play (end) ---------------------------------------------------------------------------


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
	# --- F2 play (begin)
	moments.urbs = self
	add_child(moments)
	hud.camera = cam.camera
	hud.action_pressed.connect(_on_place_action)
	hud.end_year_confirmed.connect(end_year)
	hud.place_chosen.connect(fly_to_place)
	hud.idea_sent.connect(_on_idea)
	# --- F2 play (end)
	close()
	_ready_done = true


# --- opening and closing -----------------------------------------------------------------

## Build the city of `new_year` (once per year) and take over the screen. `at` is the local
## point to open over (default the Forum); `flags` are the command-line options.
func open(new_year: int, at := Vector3.ZERO, flags := {}, new_events: Array = []) -> void:
	year = new_year
	if flags.has("anachronisms"):   # F1 ideas: --anachronisms=<builds>:<tech>[:<year>],... for renders
		city_view = UrbsAnachronisms.from_flag(str(flags["anachronisms"]), year)
	if _built_year != year:
		_rebuild()
	events = new_events
	# --- F2 play (begin)
	if flags.has("places-fixture"):
		force_fixture = true
		places.set_view(play_view, true)
	if flags.has("list-closed"):
		hud.toggle_list(false)
	if flags.has("moment-speed"):
		moments.speed = maxf(0.1, float(flags["moment-speed"]))
	if flags.has("moments-pick"):
		_fixture_pick = Array(str(flags["moments-pick"]).split(",")).map(func(i): return int(i))
	_refresh_play()
	# --- F2 play (end)
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
	if flags.has("moments"):   # F2 play: the fixture's year of events as moments
		play_fixture_moments.call_deferred()


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
	anachronisms.build(self, city_view)   # F1 ideas: the player's works, before the houses fill in
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
			var pitch := float(flags.get("pitch", "3"))
			if at != "" and not at.contains(","):
				var view := monument_view(at)   # F3 monuments
				stand = view.stand
				if not yaw_set:
					facing = float(view.facing)
				if not flags.has("pitch"):
					pitch = float(view.get("pitch", 3.0))   # F3 monuments: a raised stand looks down
				height = maxf(height, (view.eye as Vector3).y - height_at(stand.x, stand.z))   # on a court's floor
			cam.snap_street(stand, facing, maxf(height, UrbsCamera.EYE), deg_to_rad(pitch))
		"inside":
			if at != "" and not at.contains(","):
				_enter_interior_now(at)
		_:
			cam.snap_city(spot, height if height > 0.0 else 320.0, yaw if yaw_set else 0.3)
	if selected != "" and mode != "inside":
		_show_card(selected)   # F2 play: with the place's actions


# --- F3 monuments (begin): the street view of a monument (`--at=<id> --mode=street`) ----------

## Where `--at=<id> --mode=street` stands and which way it looks (monument_view.gd): out in
## front of the door with the façade in sight past the houses, the other monuments and the hill.
func monument_view(id: String) -> Dictionary:
	return UrbsMonumentView.new(monuments, Callable(self, "height_at"), fill).pick(id)

# --- F3 monuments (end) ----------------------------------------------------------------------


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
	if sp == null and not flags.has("spectacle") and not flags.has("event"):   # F2 play: a speech, an election, a levy
		for e in events:
			if e is Dictionary and UrbsMoments.has_gathering(e):
				sp = UrbsMoments.gathering(e, self)
				break
	spectacle = sp
	life.set_spectacle(spectacle != null)
	_clear_life_for(spectacle)   # F2 play


func _stop_spectacle() -> void:
	if spectacle != null and is_instance_valid(spectacle):
		UrbsSpectacles.stop()
		if is_instance_valid(spectacle) and not spectacle.is_queued_for_deletion():   # F2 play: a gathering
			spectacle.queue_free()
	spectacle = null
	life.set_spectacle(false)
	life.set_clear_zone([])   # F2 play: the street comes back


## F2 play: the street life keeps out of the spectacle's ground while it plays.
func _clear_life_for(sp: Node3D) -> void:
	life.set_clear_zone(sp.clear_area() if sp != null and sp.has_method("clear_area") else [])


# --- picking and the monument card ---------------------------------------------------------

## The monument under a screen point, or "".
func pick_monument(screen: Vector2) -> String:
	return monuments.pick(cam.camera, screen)   # against the solids, so open courts are not picked


func _on_click(screen: Vector2) -> void:
	if interior != null or moments.busy or hud.dialog_open():   # F2 play: not while the moments play
		return
	var id := pick_monument(screen)
	if id == "":
		hud.hide_card()
		selected = ""
		return
	selected = id
	_show_card(id)   # F2 play: with the place's actions


# --- going in and out -----------------------------------------------------------------------

## Esc: close a card; INSIDE -> street; STREET -> city; CITY -> the map.
func _back() -> void:
	if moments.busy:   # F2 play: Esc skips the moment playing
		moments.skip_moment()
		return
	if cam.is_gliding() or hud.dialog_open():
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
		environment.ambient_light_color = Color(0.62, 0.56, 0.48)
		environment.ambient_light_energy = 1.4   # F3 monuments: the light bounced round the room (0.6 left it black)
	var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0))
	if interior.has_method("spawn"):
		spawn = interior.spawn()
	cam.snap_inside(spawn)
	hud.set_inside(true, monuments.info(id))
	interior_id = id   # F2 play: the panel of the place's actions at its spot
	_show_spot()


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
	interior_id = ""   # F2 play
	for node in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()
	chunks.process_mode = Node.PROCESS_MODE_INHERIT
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	set_hour(hour)
	hud.set_inside(false, {})


# --- F2 play (begin): the city as the interface ---------------------------------------------
# The places' actions on the cards and in the interiors, End year and the year's moments,
# "Rome this year" (docs/plans/briefs/f2_play.md; places.gd, moments.gd, urbs_hud.gd). main.gd
# wires act_hook, end_year_hook and idea_hook, and calls set_play_view with every new view.

## The game view, from main.gd: the places, the Republic's people, the years per turn.
func set_play_view(view: Dictionary) -> void:
	play_view = view
	if view.get("city") is Dictionary:
		city_view = view["city"]
	places.set_view(view, force_fixture)
	var people := {}
	var rep: Variant = view.get("republic")
	if rep is Dictionary:
		for m in rep.get("magistrates", []):
			people[str(m["person"])] = str(m["name"])
		for p in rep.get("notable", []):
			people[str(p["id"])] = str(p["name"])
	moments.people = people
	_refresh_play()


func _city_events() -> Array:
	var city: Variant = play_view.get("city")
	return (city.get("events", []) as Array).duplicate() if city is Dictionary else []


## The HUD's list, End year button, card and panel, after the view changed.
func _refresh_play() -> void:
	if _built_year == 999999:
		return
	hud.set_todo(places.todo(monuments.ids()))
	var span := maxi(1, int(play_view.get("years_per_turn", 1)))
	hud.set_end_year(end_year_hook.is_valid(), span)
	hud.set_end_year_text(_end_year_words(span))
	if hud.card_open() and selected != "":
		_show_card(selected)
	if interior != null:
		_show_spot()


func _end_year_words(span: int) -> String:
	var to := year + span
	var text := ("The year ends here in Rome." if span == 1 else "%d years pass here in Rome: %s to %s." % [span, GameHud.year_text(year), GameHud.year_text(to)])
	text += " Its events then play where they happened, and you come back to where you stand."
	if play_view.get("dilemma") != null:
		text += "\n\nA question waits for your answer on the map: if you end the year now, Rome answers it as it would by itself."
	var chron: Variant = play_view.get("chronicle")
	if chron is Dictionary and (chron as Dictionary).get("chapter") != null:
		text += "\n\nA chapter of the chronicle waits on the map."
	return text


func _place(id: String) -> Dictionary:
	var p: Dictionary = places.place(id).duplicate()
	if not p.is_empty():
		p["_id"] = id
	return p


func _show_card(id: String) -> void:
	hud.show_card(monuments.info(id), _place(id), _results.get(id, {}))


## The panel of the interior's places at its spot (the Curia's floor, the altar, the box...).
func _show_spot() -> void:
	if interior == null:
		return
	var ids: Array = places.inside(interior_id)
	if ids.is_empty():
		hud.hide_spot()
		return
	var sections: Array = []
	var spot := ""
	for pid in ids:
		var p := places.place(pid)
		var here := ""
		if pid != interior_id and str(p.get("role", "")) == "rostra":
			here = "rostra"
		if spot == "":
			spot = here
		var words := str(UrbsPlaces.SPOT_WORDS.get(here if here != "" else str(UrbsPlaces.SPOTS.get(_interior_kind(), "")), "Here"))
		if pid != interior_id and here == "":
			words = "Close by"   # a neighbour the interior offers (the Comitium beside the Rostra)
		sections.append([pid, p, words])
	var at: Vector3 = interior.call("action_spot", spot) if interior.has_method("action_spot") else interior.global_position
	hud.show_spot(sections, at, _results.get(_result_for, {}), _result_for)


func _interior_kind() -> String:
	return str(interior.get("kind")) if interior != null and interior.get("kind") != null else ""


## Fly to a place of "Rome this year" and open its card (from inside, step out first).
func fly_to_place(id: String) -> void:
	if moments.busy or not monuments.ids().has(id):
		return
	if interior != null:
		await leave_monument()
	var b := monuments.bounds(id)
	selected = id
	cam.go_city(b.get_center(), clampf(maxf(b.size.x, b.size.z) * 2.4, 160.0, 600.0), 1.6)
	_show_card(id)


## A place's action pressed on the card or the panel: send it, show the result, refresh, and
## play what it set going (the new city event its `watch` names) with the real numbers.
func _on_place_action(place_id: String, entry: Dictionary) -> void:
	if _acting or moments.busy:
		return
	var action: Dictionary = entry.get("action", {})
	if str(action.get("kind", "")) == "idea":   # a workshop or the harbour: the idea box
		_idea_place = place_id
		hud.ask_idea(str(entry.get("label", "Whisper an idea")), str(action.get("context", place_id)))
		return
	var result := {}
	if not act_hook.is_valid():
		result = {"accepted": false, "message": "No game is running here to act on."}
	else:
		_acting = true
		var before := _city_events()
		var reply: Variant = act_hook.call(action)
		_acting = false
		if not (reply is Dictionary):
			result = {"accepted": false, "message": "The engine did not answer."}
		else:
			result = {"accepted": bool(reply.get("accepted", false)), "message": str(reply.get("message", ""))}
			if str(result["message"]).begins_with("bad action"):   # a kind the engine half has not added yet
				result["message"] = "The engine does not know this action yet (%s): it comes with the engine half of F2." % str(action.get("kind", ""))
			if reply.get("view") is Dictionary:
				set_play_view(reply["view"])
		_results[place_id] = result
		_result_for = place_id
		_refresh_play()
		var watch := str(entry.get("watch", ""))
		if result["accepted"] and watch != "":
			var after := _city_events()
			events = after
			life.set_events(events)
			var fresh: Array = UrbsPlaces.new_events(before, after).filter(func(e): return UrbsPlaces.matches(watch, e))
			if not fresh.is_empty():
				await moments.play([fresh[fresh.size() - 1]], true)
				if interior == null and selected == place_id:
					_show_card(place_id)
				_refresh_play()
		return
	_results[place_id] = result
	_result_for = place_id
	_refresh_play()


## The idea box of a place sent its words: the court rules (main.gd's idea_hook).
func _on_idea(text: String, context: String) -> void:
	if not idea_hook.is_valid():
		_results[_idea_place] = {"accepted": false, "message": "No game is running here to hear an idea."}
		_refresh_play()
		return
	hud.set_busy("The court considers your idea…")
	var place_id := _idea_place
	idea_hook.call(text, context, func(reply: Variant) -> void:
		hud.set_busy("")
		_results[place_id] = idea_result(reply)
		_result_for = place_id
		if reply is Dictionary and reply.get("view") is Dictionary:
			set_play_view(reply["view"])
		else:
			_refresh_play())


## The court's ruling on an idea as a result line.
static func idea_result(reply: Variant) -> Dictionary:
	if not (reply is Dictionary):
		return {"accepted": false, "message": "The court did not answer."}
	if str(reply.get("question", "")) != "":
		return {"accepted": true, "message": "The court asks: " + str(reply["question"])}
	var rulings: Array = reply.get("rulings", [])
	if rulings.is_empty():
		return {"accepted": false, "message": str(reply.get("note", "The court made nothing of it."))}
	var r: Dictionary = rulings[0]
	var words := str(r.get("message", "")) if str(r.get("message", "")) != "" else str(r.get("reason", ""))
	return {"accepted": bool(r.get("accepted", false)), "message": "%s: %s" % [str(r.get("name", r.get("idea", "Your idea"))), words]}


## End the year without leaving Rome: the engine's turn, the city of the new year, then the
## year's events as moments, and back to where you stood.
func end_year() -> void:
	if _acting or moments.busy or not end_year_hook.is_valid():
		return
	_acting = true
	var pose := moments.capture()
	var span := maxi(1, int(play_view.get("years_per_turn", 1)))
	hud.set_busy("The year passes…" if span == 1 else "%d years pass…" % span)
	for i in 3:
		await get_tree().process_frame
	var reply: Variant = end_year_hook.call()
	if not (reply is Dictionary):
		hud.set_busy("")
		_acting = false
		return
	var new_year := int(reply.get("year", year))
	_results.clear()
	if new_year != year:
		if interior != null:
			_leave_interior_now()
		city_view = reply.get("city", {}) if reply.get("city") is Dictionary else {}
		year = new_year
		hud.hide_card()
		_rebuild()
		hud.set_year(year)
		fill.sync_chunks = true
		chunks.load_all_now()
		fill.sync_chunks = false
	set_play_view(reply)
	events = _city_events()
	life.set_events(events)
	hud.set_busy("")
	_acting = false
	var list := UrbsMoments.pick(city_view, year, span)
	if list.is_empty():
		moments.restore(pose)
		return
	await moments.play(list, false, pose)
	_refresh_play()


## For screenshots (main.gd --then=tour): fly to each place of "Rome this year" in turn,
## `step` seconds apart, its card open.
func tour_places(step := 8.0) -> void:
	for item in places.todo(monuments.ids()):
		fly_to_place(str(item["id"]))
		await get_tree().create_timer(step).timeout


## --moments: the fixture's year of events (its venues standing in this year's city).
func play_fixture_moments() -> void:
	var list: Array = places.fixture_events
	if not _fixture_pick.is_empty():
		list = _fixture_pick.filter(func(i): return i >= 0 and i < list.size()).map(func(i): return list[i])
	await moments.play(list)


## Spectacle for one event (U6's, or a gathering), placed and playing; null if none.
func play_watch(e: Dictionary) -> Node3D:
	_stop_spectacle()
	var sp: Node3D = _senate_inside(e)
	if sp == null:
		sp = UrbsSpectacles.play_event(e, self)
	if sp == null:
		sp = UrbsMoments.gathering(e, self)
	spectacle = sp
	life.set_spectacle(sp != null)
	_clear_life_for(sp)
	return sp


## The Senate's vote inside the Curia's interior when it is open: the division fitted to the
## hall (its floor, its length and width), so the senators walk the real floor.
func _senate_inside(e: Dictionary) -> Node3D:
	if interior == null or str(e.get("kind", "")) != "senate" or _interior_kind() != "curia":
		return null
	var sp_def := UrbsSpectacles.from_event(e)
	var r: Dictionary = interior.get("result")
	var anchors: Dictionary = r.get("anchors", {})
	if sp_def.is_empty() or not anchors.has("door"):
		return null
	var m: Dictionary = monuments.entry(interior_id)
	var kv: Array = UrbsInteriors.kind_of(m)
	var size := UrbsInteriors.size_of(m, str(kv[0]), str(kv[1]))   # (length, width)
	var params: Dictionary = (sp_def["params"] as Dictionary).duplicate()
	params["hall"] = Vector2(maxf(size.y - 1.6, 8.0), maxf(size.x - 1.2, 12.0))
	var sp := UrbsSpectacles.play("senate", params, self)
	if sp != null:
		var door: Vector3 = anchors["door"]
		sp.transform = (interior.get("xf") as Transform3D) * Transform3D(Basis(), Vector3(0, door.y, 0))
	return sp


## For screenshots and tests (main.gd --then=act --act=<id>): press the action `id` of the
## place `place_id` as if clicked.
func act_by_id(place_id: String, id: String) -> void:
	for a in places.place(place_id).get("actions", []):
		if str(a.get("id", "")) == id:
			await _on_place_action(place_id, a)
			return
	push_warning("Urbs: no action %s at %s" % [id, place_id])
# --- F2 play (end) ---------------------------------------------------------------------------
