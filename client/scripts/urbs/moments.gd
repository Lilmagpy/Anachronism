## F2 play, U9 first slice: the year's events as moments. After End year in Urbs (or after an
## action whose `watch` produced a city event), the camera flies from where you stand to each
## place, a title card says what happens in plain words (CityFeed.describe), the spectacle plays
## there with the engine's real numbers, and at the end you are put back exactly where you
## stood (inside the building you were in, if any). Esc (or Skip) skips a moment, Q (or Stop)
## stops watching. No new art: the spectacles are U6's (spectacles/*.gd) and, for a speech, an
## election and a levy, the small `Gathering` below.
##
## Interface used by urbs.gd (marked "F2 play" blocks):
##   var moments := UrbsMoments.new(); moments.urbs = self; add_child(moments)
##   await moments.play(events, watch, pose)      plays the events in order (watch: one action's
##                                                 result, with the longer cut of its spectacle),
##                                                 then puts the camera back (at `pose` if given)
##   moments.busy                                  true while playing (the HUD and clicks wait)
##   UrbsMoments.pick(city_view, year, years)      the turn's events worth a moment, in order
##   UrbsMoments.gathering(e, urbs) -> Node3D      a speech / election / levy placed and playing
##   UrbsMoments.has_gathering(e) -> bool
## Camera paths and timing per kind are SPANS (seconds into the spectacle, seconds shown).
class_name UrbsMoments
extends Node

signal finished

const MAX_MOMENTS := 8
const FLY := 2.6
## [start, length, camera] of each spectacle in a year's moments, and when watching one action's
## result. camera: the index of the spectacle's own view (seat_views), or -1 to follow the
## action with its cinematic camera (the leading chariot, the pair fighting).
const SPANS_YEAR := {"senate": [60.0, 34.0, 0], "race": [6.0, 30.0, -1], "sacrifice": [28.0, 30.0, 0], "munus": [2.0, 34.0, -1],
	"triumph": [55.0, 30.0, 1], "gathering": [0.0, 24.0, 0]}
const SPANS_WATCH := {"senate": [26.0, 70.0, 0], "race": [0.0, 92.0, 0], "sacrifice": [8.0, 64.0, 0], "munus": [0.0, 70.0, -1],
	"triumph": [12.0, 90.0, 0], "gathering": [0.0, 30.0, 0]}
## The order of importance when a turn brings more than MAX_MOMENTS (lower first).
const PRIORITY := {"triumph": 0, "anachronism": 1, "sacrifice": 2, "senate": 3, "election": 4, "contio": 5,
	"look": 6, "levy": 7, "games": 8, "building": 9, "fire": 10, "flood": 11}
## Where a gathering stands when the event names no standing monument.
const GATHERING_AT := {"contio": ["rostra_republic", "rostra_augusti", "comitium", "forum_romanum"],
	"election": ["saepta_iulia", "villa_publica", "campus_martius", "comitium", "forum_romanum"],
	"levy": ["villa_publica", "campus_martius", "forum_romanum"]}

var urbs: Urbs                      ## the Urbs scene (cam, hud, monuments, play_watch...)
var busy := false
var speed := 1.0                   ## test flag --moment-speed: everything plays this much faster
var people := {}                   ## person id -> name (from the republic view)
var _skip := false
var _stop := false
var _layer := CanvasLayer.new()
var _card := PanelContainer.new()
var _count := Label.new()
var _heading := Label.new()
var _sentence := Label.new()
var _numbers := Label.new()
var _tween: Tween


func _ready() -> void:
	name = "Moments"
	_layer.layer = 40
	_layer.visible = false
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	_layer.add_child(root)
	var style := UiStyle.panel(Color(0.97, 0.93, 0.84, 0.95), UiStyle.GOLD_DARK, 14)
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", style)
	_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card.offset_left = -330
	_card.offset_right = 330
	_card.offset_top = 72
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.custom_minimum_size.x = 660
	root.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_card.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	_count = UiStyle.label("", 13, UiStyle.GOLD_DARK, "body", 800)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count)
	var skip := UiStyle.big_button("Skip ▸", 13, UiStyle.PARCHMENT)
	skip.tooltip_text = "Skip this moment (Esc)"
	skip.pressed.connect(skip_moment)
	top.add_child(skip)
	var stop := UiStyle.big_button("Stop", 13, UiStyle.PARCHMENT)
	stop.tooltip_text = "Stop watching and go back where you stood (Q)"
	stop.pressed.connect(stop_all)
	top.add_child(stop)
	col.add_child(top)
	_heading = UiStyle.label("", 30, UiStyle.RED, "title", 900)
	col.add_child(_heading)
	_sentence = UiStyle.wrapped("", 17, UiStyle.INK, 620.0)
	col.add_child(_sentence)
	_numbers = UiStyle.label("", 15, UiStyle.GOLD_DARK, "body", 800)
	col.add_child(_numbers)


func _unhandled_key_input(event: InputEvent) -> void:
	if not busy or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE, KEY_SPACE:
			skip_moment()
			get_viewport().set_input_as_handled()
		KEY_Q:
			stop_all()
			get_viewport().set_input_as_handled()


func skip_moment() -> void:
	_skip = true


func stop_all() -> void:
	_stop = true
	_skip = true


# --- choosing the moments --------------------------------------------------------------------

## The turn's events worth a moment, in the engine's order: each event with a place, the
## monuments finished, begun or burnt this turn, and the player's works risen before their
## time; one of each yearly festival; at most MAX_MOMENTS, the most important kept.
static func pick(city: Dictionary, now: int, span: int) -> Array:
	var out: Array = []
	var festivals := {}
	for e in city.get("events", []):
		if not (e is Dictionary):
			continue
		var kind := str(e.get("kind", ""))
		var ref := str(e.get("ref", ""))
		if kind == "games" and ref != "munus":
			if festivals.has(ref) or ref == "ludi_megalenses":
				continue
			festivals[ref] = true
		out.append(e)
	var statuses := {}
	for m in city.get("monuments", []):
		statuses[str(m["id"])] = str(m.get("status", ""))
	for id in city.get("changed", []):
		var st := str(statuses.get(str(id), "standing"))
		if st in ["standing", "building", "burnt", "ruined"]:
			out.append({"kind": "look", "year": now, "ref": st, "monument": str(id), "person": "", "value": 0, "other": 0})
	for a in city.get("anachronisms", []):
		if int(a.get("year", -99999)) > now - span:
			out.append({"kind": "anachronism", "year": int(a.get("year", now)), "ref": str(a.get("tech", "")),
				"monument": "anachronism_" + str(a.get("tech", "")), "person": str(a.get("name", "")), "value": int(a.get("ahead", 0)), "other": 0})
	if out.size() > MAX_MOMENTS:
		var ranked: Array = range(out.size())
		ranked.sort_custom(func(a, b):
			var pa := int(PRIORITY.get(str(out[a].get("kind", "")), 20))
			var pb := int(PRIORITY.get(str(out[b].get("kind", "")), 20))
			return pa < pb if pa != pb else a < b)
		var keep: Array = ranked.slice(0, MAX_MOMENTS)
		keep.sort()
		out = keep.map(func(i): return out[i])
	return out


# --- playing ---------------------------------------------------------------------------------

## Play `events` as moments, then put the camera back where it was (or at `pose`, from
## capture()). `watch`: one action's result (the longer cut, no counter).
func play(events: Array, watch := false, pose: Dictionary = {}) -> void:
	if busy or urbs == null or events.is_empty():
		return
	busy = true
	_stop = false
	if pose.is_empty():
		pose = capture()
	urbs.hud.set_watching(true)
	_layer.visible = true
	for i in events.size():
		if _stop:
			break
		await _moment(events[i], i, events.size(), watch)
	_card.visible = false
	await urbs.fade_to(1.0, 0.35)
	urbs._stop_spectacle()
	restore(pose)
	_layer.visible = false
	urbs.hud.set_watching(false)
	await urbs.fade_to(0.0, 0.5)
	busy = false
	finished.emit()


func _moment(e: Dictionary, index: int, total: int, watch: bool) -> void:
	_skip = false
	var kind := str(e.get("kind", ""))
	var mon := _venue(e)
	_title(e, index, total, watch)
	urbs._stop_spectacle()
	var sp_kind := _spectacle_kind(e)
	# already in the house where it happens (a vote called from the Curia's floor): stay
	var stay := sp_kind == "senate" and urbs.interior != null and urbs.interior_id == mon
	if not stay:
		if urbs.interior != null:
			await urbs.fade_to(1.0, 0.25)
			urbs._leave_interior_now()
			urbs.fade_to(0.0, 0.4)
		# the flight: from wherever the camera is to an orbit over the place
		urbs.cam.go_city(_centre(mon), _orbit(mon), FLY / speed)
		await _wait(FLY + 0.3)
		if _skip:
			return
		# the spectacle: the Senate inside its house, the rest in the open
		if sp_kind == "senate" and urbs.monuments.ids().has(mon) and bool(urbs.monuments.info(mon).get("enterable", false)):
			await urbs.fade_to(1.0, 0.3)
			urbs._enter_interior_now(mon)
	var sp: Node3D = urbs.play_watch(e) if sp_kind != "" else null
	if sp != null:
		var spans: Dictionary = SPANS_WATCH if watch else SPANS_YEAR
		var cut: Array = spans.get(sp_kind, [0.0, 24.0])
		sp.seek(float(cut[0]))
		sp.time_scale = speed
		var views: Array = sp.camera_views()
		var which := int(cut[2]) if cut.size() > 2 else 0
		var follow := Callable()
		var v := Transform3D()
		if which < 0 or views.is_empty():
			v = _above_ground(sp.cine_camera(sp.t))
			follow = func() -> void: urbs.cam.snap_inside(_above_ground(sp.cine_camera(sp.t)))
		else:
			v = _above_ground(views[clampi(which, 0, views.size() - 1)])
		if urbs.interior != null:
			urbs.cam.snap_inside(v)
			urbs.fade_to(0.0, 0.4)
		else:
			urbs.cam.go_inside(v, 1.8 / speed)
			if follow.is_valid():
				await _wait(1.8)
				follow.call()
		await _wait(minf(float(cut[1]), maxf(4.0, sp.duration - float(cut[0]))), follow)
	else:
		if urbs.interior != null:
			urbs.fade_to(0.0, 0.4)
		await _wait(5.0 if kind in ["look", "anachronism", "building", "fire", "flood"] else 4.0)


func _wait(seconds: float, each_frame := Callable()) -> void:
	var t := 0.0
	seconds /= maxf(speed, 0.01)
	while t < seconds and not _skip and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
		if each_frame.is_valid() and not urbs.cam.is_gliding():
			each_frame.call()


## A camera pose kept out of the ground (the spectacles' views are laid out on flat ground; the
## triumph's route crosses the hills).
func _above_ground(v: Transform3D) -> Transform3D:
	if urbs.interior != null:
		return v
	var ground := float(urbs.height_at(v.origin.x, v.origin.z))
	if v.origin.y < ground + 1.6:
		v.origin.y = ground + 1.6
	return v


## The title card for a moment.
func _title(e: Dictionary, index: int, total: int, watch: bool) -> void:
	var told := words(e, people)
	_count.text = ("YOUR ACTION" if watch else "THE YEAR IN ROME · %d OF %d" % [index + 1, total]) + "  ·  " + GameHud.year_text(int(e.get("year", urbs.year)))
	_heading.text = str(told[0])
	_heading.add_theme_color_override("font_color", told[2])
	_sentence.text = str(told[1])
	_numbers.text = numbers(e)
	_numbers.visible = _numbers.text != ""
	_sentence.visible = true
	_card.visible = true
	_card.modulate.a = 0.0
	_card.reset_size()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = _card.create_tween()
	_tween.tween_property(_card, "modulate:a", 1.0, 0.35)
	_tween.tween_interval(6.0 / speed)
	_tween.tween_property(_card, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func() -> void:   # then only the heading and the numbers stay, so the spectacle is seen
		_sentence.visible = false
		_card.reset_size())
	_tween.tween_property(_card, "modulate:a", 0.9, 0.3)


## [heading, sentence, colour] for a moment: CityFeed's words, and the moments' own kinds.
static func words(e: Dictionary, people_names: Dictionary = {}) -> Array:
	var kind := str(e.get("kind", ""))
	var venue := CityFeed.monument_name(str(e.get("monument", "")))
	match kind:
		"look":
			var st := str(e.get("ref", "standing"))
			return ["THE CITY CHANGES", "%s %s." % [venue, str(CityFeed.STATUS_WORDS.get(st, "changes"))],
				CityFeed.BAD if st in ["burnt", "ruined"] else CityFeed.GOOD]
		"anachronism":
			return ["✦ " + str(e.get("person", "YOUR IDEA")).to_upper(),
				"An idea of yours takes shape in stone: it rises in Rome, %s years before its time." % GameHud.number(int(e.get("value", 0))), UiStyle.RED]
	return CityFeed.describe(e, people_names)


## The real numbers of an event, in one line ("" when it has none to show).
static func numbers(e: Dictionary) -> String:
	var v := int(e.get("value", 0)) if e.get("value") != null else 0
	var o := int(e.get("other", 0)) if e.get("other") != null else 0
	match str(e.get("kind", "")):
		"senate":
			return "For %d%% · against %d%% · the motion is %s" % [roundi(v / 100.0), roundi(o / 100.0), "carried" if v > o else "lost"]
		"contio":
			return "Popular favour %+d%%" % roundi(v / 100.0)
		"election":
			return "%d votes to %d" % [v, o]
		"levy":
			return "%s men%s" % [GameHud.number(v), " · %d legions" % o if o > 0 else ""]
	return ""


## The monument a moment flies to.
func _venue(e: Dictionary) -> String:
	var ids: Array = urbs.monuments.ids()
	var mon := str(e.get("monument", "")) if e.get("monument") != null else ""
	if mon != "" and ids.has(mon):
		return mon
	var kind := str(e.get("kind", ""))
	for alt in GATHERING_AT.get(kind, []):
		if ids.has(alt):
			return alt
	if kind == "triumph":
		for alt in ["circus_maximus", "forum_romanum"]:
			if ids.has(alt):
				return alt
	var sp := UrbsSpectacles.from_event(e)
	if not sp.is_empty() and ids.has(str(sp["monument"])):
		return str(sp["monument"])
	return "forum_romanum" if ids.has("forum_romanum") else ""


func _centre(mon: String) -> Vector3:
	if mon == "":
		return Vector3.ZERO
	return (urbs.monuments.bounds(mon) as AABB).get_center()


func _orbit(mon: String) -> float:
	if mon == "":
		return 500.0
	var b: AABB = urbs.monuments.bounds(mon)
	return clampf(maxf(b.size.x, b.size.z) * 2.4, 180.0, 650.0)


## The spectacle kind an event plays: U6's, "gathering", or "".
static func _spectacle_kind(e: Dictionary) -> String:
	var sp := UrbsSpectacles.from_event(e)
	if not sp.is_empty():
		return str(sp["kind"])
	return "gathering" if has_gathering(e) else ""


# --- the camera, kept and given back ---------------------------------------------------------

## Where the camera is now (mode, orbit or walker, the building you are inside).
func capture() -> Dictionary:
	var c: UrbsCamera = urbs.cam
	return {"mode": c.mode, "target": c.target, "dist": c.dist_goal, "yaw": c.yaw, "pos": c.pos, "pitch": c.pitch,
		"h": c.h_goal, "inside": urbs.interior_id if urbs.interior != null else ""}


func restore(p: Dictionary) -> void:
	var c: UrbsCamera = urbs.cam
	if urbs.interior != null:
		urbs._leave_interior_now()
	var inside := str(p.get("inside", ""))
	if inside != "":
		urbs._enter_interior_now(inside)
		c.snap_inside(Transform3D(Basis(Vector3.UP, float(p["yaw"])) * Basis(Vector3.RIGHT, float(p["pitch"])), p["pos"]))
		return
	match int(p.get("mode", UrbsCamera.Mode.CITY)):
		UrbsCamera.Mode.STREET:
			c.snap_street(p["pos"], float(p["yaw"]), float(p["h"]), float(p["pitch"]))
		UrbsCamera.Mode.INSIDE:   # a spectacle's seat: back to an orbit over it
			c.snap_city(p["pos"], 300.0, float(p["yaw"]))
		_:
			c.snap_city(p["target"], float(p["dist"]), float(p["yaw"]))


# --- the gatherings: a speech, an election, a levy -------------------------------------------

static func has_gathering(e: Dictionary) -> bool:
	return str(e.get("kind", "")) in ["contio", "election", "levy"]


## Place and play a gathering for event `e` on its venue (see GATHERING_AT); null if none.
static func gathering(e: Dictionary, u) -> Node3D:
	if not has_gathering(e):
		return null
	var kind := str(e.get("kind", ""))
	var ids: Array = u.monuments.ids()
	var mon := str(e.get("monument", "")) if e.get("monument") != null else ""
	if not ids.has(mon):
		mon = ""
		for alt in GATHERING_AT.get(kind, []):
			if ids.has(alt):
				mon = alt
				break
	var params := {"kind": kind, "value": int(e.get("value", 0)) if e.get("value") != null else 0,
		"other": int(e.get("other", 0)) if e.get("other") != null else 0,
		"who": CityFeed.name_of(str(e.get("person", "")) if e.get("person") != null else "", str(e.get("person_name", "")) if e.get("person_name") != null else "", {}),
		"ref": str(e.get("ref", ""))}
	var xf := Transform3D()
	if mon != "":
		var box: AABB = u.monuments.bounds(mon)
		var c := box.get_center()
		var door: Transform3D = u.monuments.entrance(mon)
		var out := door.basis.z
		out.y = 0.0
		out = out.normalized() if out.length() > 0.01 else Vector3(0, 0, 1)
		var at := Vector3(c.x, 0, c.z)
		if kind == "contio":
			# the platform's top: the Rostra's box includes the statues standing on it (~3.2 m)
			params["stage_h"] = clampf(box.size.y - (3.2 if mon.contains("rostra") else 0.0), 1.2, 4.0)
		elif kind == "levy" or kind == "election":
			# out on the open ground in front of the venue, not inside its walls
			at = Vector3(door.origin.x, 0, door.origin.z) + out * 30.0
		at.y = float(u.call("height_at", at.x, at.z))
		xf = Transform3D(Basis.looking_at(-out, Vector3.UP), at)
	UrbsSpectacles.stop()
	var sp := Gathering.new(params)
	sp.name = "Spectacle_" + kind
	u.add_child(sp)
	sp.transform = xf
	return sp


## A crowd at a speech from the Rostra (contio), the voters filing over the gangways to the
## tellers (an election: the voting units one after another), or the levy mustering in its
## maniples before the consul's tribunal. Figures from figure.gd, crowds from crowd.gd; the
## numbers are the event's. Local frame: +z towards the crowd, floor y = 0.
class Gathering extends "res://scripts/urbs/spectacles/base.gd":
	const F := preload("res://scripts/urbs/spectacles/figure.gd")
	const Crowd := preload("res://scripts/urbs/crowd.gd")
	const M := preload("res://scripts/urbs/spectacles/meshlib.gd")

	var kind := "contio"
	var stage_h := 2.6
	var _speaker   # figure.gd
	var _crowd   # crowd.gd
	var _walkers: Array = []
	var _blocks: Array = []        # [node, from, to]
	var _label: Label3D
	var _tally: Label3D

	func _init(p: Dictionary = {}) -> void:
		params = p
		kind = str(p.get("kind", "contio"))
		stage_h = float(p.get("stage_h", 2.6))
		duration = 30.0

	func _ready() -> void:
		match kind:
			"contio":
				_build_contio()
			"election":
				_build_election()
			"levy":
				_build_levy()
		seek(0.0)

	func _magistrate(at: Vector3, seed_value: int):
		var f = F.person({"tunic": Color(0.9, 0.87, 0.8), "toga": true, "border": Color(0.52, 0.1, 0.32), "seed": seed_value,
			"hair": Color(0.3, 0.24, 0.2), "belt_on": false})
		f.position = at
		add_child(f)
		return f

	func _box(size: Vector3, at: Vector3, col: Color) -> void:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
		mi.material_override = F.mat(col)
		mi.position = at + Vector3(0, size.y / 2.0, 0)
		add_child(mi)

	func _build_contio() -> void:
		if stage_h < 1.3:
			_box(Vector3(5, 1.2, 3), Vector3.ZERO, Color(0.62, 0.55, 0.45))
			stage_h = 1.2
		_speaker = _magistrate(Vector3(0, stage_h, 0.6), 41)
		F.face(_speaker, Vector3(0, 0, 1))
		var c = Crowd.new()
		c.standing = true
		c.toga_rows = 2
		var seats: Array = []
		for k in 16:
			var r := 7.0 + k * 1.05
			var n := int(r * 2.3 / 0.85)
			for i in n:
				var a := lerpf(-1.15, 1.15, (float(i) + 0.5) / n)
				var p := Vector3(sin(a) * r, 0, cos(a) * r)
				seats.append({"pos": p, "yaw": atan2(-p.x, -p.z), "u": float(i) / n, "row": k})
		c.add_seats(seats)
		c.build()
		add_child(c)
		_crowd = c
		_label = make_label("%s speaks %s" % [str(params.get("who", "")), _issue()], 1.6, Color(1, 0.95, 0.8))
		_label.position = Vector3(0, stage_h + 5.0, 0.6)
		_tally = make_label("", 1.8, Color(0.8, 1.0, 0.7))
		_tally.position = Vector3(0, stage_h + 4.1, 0.6)

	func _issue() -> String:
		var ref := str(params.get("ref", ""))
		var names := {"war": "for war", "peace": "for peace", "land": "for the land law", "debt": "for easing debt",
			"colony": "for a colony", "citizenship": "for the allies' rights", "building": "for the public works"}
		return str(names.get(ref, "to the people"))

	func _build_election() -> void:
		# the gangway (pons) the voters cross, one unit after another, to the tellers' table
		_box(Vector3(22, 0.5, 1.8), Vector3(-5, 0, 0), Color(0.55, 0.42, 0.28))
		_box(Vector3(2.2, 0.9, 1.0), Vector3(7.8, 0, 0), Color(0.48, 0.36, 0.24))
		_box(Vector3(4, 1.4, 3), Vector3(9, 0, -5.5), Color(0.62, 0.55, 0.45))
		_speaker = _magistrate(Vector3(9, 1.4, -5.5), 52)
		F.face(_speaker, Vector3(-1, 0, 1))
		for i in 2:
			var teller = F.person({"tunic": Color(0.85, 0.8, 0.7), "toga": true, "seed": 60 + i})
			teller.position = Vector3(8.6, 0, -1.2 if i == 0 else 1.2)
			F.face(teller, Vector3(-1, 0, 0))
			add_child(teller)
		for i in 14:
			var v = F.person({"tunic": [Color(0.72, 0.6, 0.45), Color(0.6, 0.45, 0.35), Color(0.8, 0.76, 0.66)][i % 3],
				"toga": i % 2 == 0, "seed": 100 + i})
			add_child(v)
			_walkers.append(v)
		var c = Crowd.new()
		c.standing = true
		c.toga_rows = 0
		var seats: Array = []
		for gx in 14:
			for gz in 16:
				var p := Vector3(-30.0 + gx * 0.95, 0, -7.5 + gz * 0.95)
				seats.append({"pos": p, "yaw": PI / 2.0, "u": float(gx) / 14.0, "row": 3})
		c.add_seats(seats)
		c.build()
		add_child(c)
		_crowd = c
		_label = make_label("The vote: %s" % str(params.get("ref", "")).replace("_plebs", " of the plebs").replace("_", " "), 1.4, Color(1, 0.95, 0.8))
		_label.position = Vector3(2, 5.0, 0)
		_tally = make_label("", 1.5, Color(0.8, 1.0, 0.7))
		_tally.position = Vector3(2, 3.6, 0)

	func _build_levy() -> void:
		_box(Vector3(5, 1.6, 3.2), Vector3(0, 0, -14), Color(0.6, 0.54, 0.44))
		_speaker = _magistrate(Vector3(0, 1.6, -13.6), 71)
		F.face(_speaker, Vector3(0, 0, 1))
		var legions := clampi(int(params.get("other", 2)), 1, 4)
		var blocks := legions * 6
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for b in blocks:
			var c = Crowd.new()
			c.standing = true
			c.toga_rows = 0
			var pal: Array[Color] = [Color(0.66, 0.24, 0.18), Color(0.58, 0.3, 0.2), Color(0.72, 0.62, 0.48), Color(0.5, 0.36, 0.26)]
			c.palette = pal
			var seats: Array = []
			for gx in 10:
				for gz in 6:
					seats.append({"pos": Vector3(gx * 1.0 - 4.5, 0, gz * 1.1), "yaw": PI, "u": float(gx) / 10.0, "row": 3})
			c.add_seats(seats)
			c.seed_value = 11 + b
			c.build()
			add_child(c)
			var col := b % 6
			var row := b / 6
			var to := Vector3((col - 2.5) * 12.5, 0, 2.0 + row * 9.0)
			var from := to + Vector3(rng.randf_range(-30, 30), 0, 40.0 + rng.randf_range(0, 30))
			_blocks.append([c, from, to])
			# a standard-bearer before each maniple
			var s = F.person({"tunic": Color(0.62, 0.22, 0.16), "seed": 200 + b})
			s.equip_helmet("samnis", Color(0.72, 0.6, 0.3), Color(0.72, 0.1, 0.1))
			add_child(s)
			_walkers.append(s)
		_label = make_label("The levy", 1.6, Color(1, 0.95, 0.8))
		_label.position = Vector3(0, 6.0, -13.6)
		_tally = make_label("", 1.6, Color(0.8, 1.0, 0.7))
		_tally.position = Vector3(0, 4.6, -13.6)

	func _apply(time: float) -> void:
		var tt := clampf(time, 0.0, duration)
		var k := clampf(tt / (duration * 0.8), 0.0, 1.0)
		var v := int(params.get("value", 0))
		var o := int(params.get("other", 0))
		match kind:
			"contio":
				if _speaker != null:
					var g := sin(tt * 1.7)
					_speaker.pose_arms(-0.9 - 0.6 * maxf(0.0, g), 0.1, 0.25, 0.05)
					_speaker.look_yaw(0.35 * sin(tt * 0.45))
				var roar := 0.15 + 0.7 * smoothstep(18.0, 24.0, tt) * (0.5 + 0.5 * sin(tt * 0.9))
				_crowd.set_state(tt, roar, fposmod(tt * 0.05, 1.0), 0.3)
				_tally.text = "Popular favour %+d%%" % roundi(lerpf(0.0, v / 100.0, smoothstep(6.0, 24.0, tt))) if v != 0 else ""
			"election":
				for i in _walkers.size():
					var w = _walkers[i]
					var x := fposmod(tt * 1.4 - i * 1.75, 24.5) - 16.0
					w.position = Vector3(x, 0.5, 0.0)
					w.visible = x < 7.4
					F.face(w, Vector3(1, 0, 0))
					w.walk(tt * 5.2 + i)
				_crowd.set_state(tt, 0.1 + 0.6 * smoothstep(24.0, 28.0, tt), 0.0, 0.0)
				var shown_v := roundi(lerpf(0.0, float(v), k))
				var shown_o := roundi(lerpf(0.0, float(o), k))
				_tally.text = "%s: %d votes  ·  against: %d" % [str(params.get("who", "")), shown_v, shown_o] if v + o > 0 else ""
			"levy":
				for i in _blocks.size():
					var b: Array = _blocks[i]
					var u := smoothstep(0.0, 1.0, clampf((tt - i * 0.35) / 14.0, 0.0, 1.0))
					(b[0] as Node3D).position = (b[1] as Vector3).lerp(b[2], u)
					var s = _walkers[i]
					s.position = (b[0] as Node3D).position + Vector3(0, 0, -1.6)
					F.face(s, Vector3(0, 0, -1) if u >= 1.0 else ((b[2] as Vector3) - (b[1] as Vector3)))
					s.walk(tt * 5.0 + i, 0.0 if u >= 1.0 else 1.0)
					b[0].set_state(tt, 0.0, 0.0, 0.0)
				if _speaker != null:
					_speaker.pose_arms(-1.2 * smoothstep(15.0, 17.0, tt), 0.0, 0.2, 0.0)
				_tally.text = "%s men enrolled%s" % [GameHud.number(roundi(lerpf(0.0, float(v), k))), " · %d legions" % o if o > 0 else ""] if v > 0 else ""

	func seat_views() -> Array[Transform3D]:
		var out: Array[Transform3D] = []
		match kind:
			"contio":
				out.append(look(Vector3(3.5, stage_h + 2.6, 14.0), Vector3(0, stage_h + 1.0, 0)))
				out.append(look(Vector3(2.5, 2.6, 25.0), Vector3(0, stage_h + 1.4, 0)))
				out.append(look(Vector3(-2.0, stage_h + 2.4, -3.5), Vector3(0, 1.0, 16.0)))
			"election":
				out.append(look(Vector3(-2.0, 4.5, 15.0), Vector3(1.0, 1.0, 0.0)))
				out.append(look(Vector3(12.0, 3.0, 6.0), Vector3(-6.0, 1.0, 0.0)))
			_:
				out.append(look(Vector3(0.0, 4.2, -21.0), Vector3(0, 1.0, 8.0)))
				out.append(look(Vector3(-40.0, 9.0, 40.0), Vector3(0, 0.0, 6.0)))
		return out

	func view_names() -> PackedStringArray:
		return PackedStringArray(["front", "behind"])
