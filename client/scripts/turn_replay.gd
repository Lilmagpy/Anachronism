## The turn played back on the map (D-124): instead of jumping to the turn's end, armies
## march along their roads with dust and drums, battles flare where they were fought (yours
## close up, with the camera there), land changing hands gets the new owner's banner, and
## newly raised armies rise from the ground. The camera returns where it was. Any click or
## key skips to the end. Nothing here decides anything: it only shows `view.replay`.
class_name TurnReplay
extends Node3D

signal finished

const MARCH_SECONDS := 2.4
const DUST := Color(0.78, 0.68, 0.52)
const FX := 3.5   ## effects are drawn larger than life, as the armies are, to read from afar

var _map: ProvinceMap
var _rig: CameraRig
var _audio: GameAudio
var _skip := false
var _camera_moved := false
var _tweens: Array[Tween] = []
var _where := {}   ## "a:"/"f:" + army or fleet id -> its province or sea, as they move


const SETTINGS := "user://settings.cfg"


## Whether turns play out on the map (Settings; on unless the player turned it off).
static func enabled() -> bool:
	var config := ConfigFile.new()
	return config.load(SETTINGS) != OK or bool(config.get_value("display", "replay", true))


static func set_enabled(on: bool) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("display", "replay", on)
	config.save(SETTINGS)


## True if there is anything worth showing in this replay.
static func worth_showing(replay: Dictionary) -> bool:
	for key in ["breakthroughs", "marches", "sails", "battles", "sieges", "taken", "raised", "lost"]:
		if not (replay.get(key, []) as Array).is_empty():
			return true
	return false


## Play the replay; `apply_new_map` redraws the map as the turn left it (called once the
## battles are over). Await `finished`, or this coroutine itself.
func play(replay: Dictionary, map: ProvinceMap, rig: CameraRig, audio: GameAudio,
		apply_new_map: Callable) -> void:
	_map = map
	_rig = rig
	_audio = audio
	var home := {"at": rig.position, "distance": rig.distance}
	for id in map.army_nodes:
		_where["a:" + str(id)] = map.army_nodes[id].get("province", "")
	for id in map.fleet_nodes:
		_where["f:" + str(id)] = map.fleet_nodes[id].get("province", "")
	await _marches(replay.get("marches", []), replay.get("sails", []))
	await _battles(replay.get("battles", []), replay.get("skirmishes", []), replay.get("lost", []))
	_fade_lost(replay.get("lost", []))
	await _sieges(replay.get("sieges", []))
	if not _skip:
		await _wait(0.3)
	apply_new_map.call()
	await _taken(replay.get("taken", []))
	await _breakthroughs(replay.get("breakthroughs", []))
	_raised(replay.get("raised", []))
	if not _skip:
		await _wait(0.8)
	if _camera_moved:
		if _skip:
			rig.look_at_point(home["at"], home["distance"])
		else:
			await _fly(home["at"], home["distance"], 1.0)
	_end()


## Jump to the end (a click or key while the turn plays).
func skip() -> void:
	_skip = true
	for tween in _tweens:
		if tween.is_valid():
			tween.custom_step(100.0)  # finish at once, landing everything where it ends


func _end() -> void:
	# the effects linger a moment, then go
	var fade := create_tween()
	fade.tween_interval(1.5 if not _skip else 0.0)
	fade.tween_callback(queue_free)
	finished.emit()


# --- pacing and the camera ---------------------------------------------------------------


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()


func _fly(at: Vector3, distance: float, seconds := -1.0) -> void:
	if _skip:
		return
	_camera_moved = true
	var flight := _rig.fly_to(at, distance, seconds)
	while flight.is_valid() and flight.is_running() and not _skip:
		await get_tree().process_frame


## Bring a set of places into view (no move if they already are, near enough).
func _frame(points: Array) -> void:
	if points.is_empty() or _skip:
		return
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	var centre := box.get_center()
	var span := maxf(box.size.x, box.size.z)
	var distance := clampf(span * 1.5 + 140.0, 150.0, 650.0)
	var screen := _rig.camera.unproject_position(centre)
	var size := _rig.get_viewport().get_visible_rect().size
	var on_screen := Rect2(size * 0.2, size * 0.6).has_point(screen) and not _rig.camera.is_position_behind(centre)
	if on_screen and absf(log(_rig.distance / distance)) < 0.5:
		return
	await _fly(centre, distance)


func _tween() -> Tween:
	var tween := create_tween()
	_tweens.append(tween)
	return tween


# --- marches -----------------------------------------------------------------------------


func _nodes(id: String, fleet: bool) -> Dictionary:
	return (_map.fleet_nodes if fleet else _map.army_nodes).get(id, {})


## Armies march their roads and fleets sail their courses, all at once.
func _marches(marches: Array, sails: Array) -> void:
	var focus: Array = []
	var moving: Array = []
	for group in [[marches, false], [sails, true]]:
		var fleet: bool = group[1]
		for march in group[0]:
			var nodes := _nodes(str(march["id"]), fleet)
			if nodes.is_empty():
				continue
			var piece: Node3D = nodes["piece"]
			var points: Array[Vector3] = [piece.position]
			var road: Array = march["road"]
			for i in road.size():
				var place := str(road[i])
				var last := i == road.size() - 1
				var p := (_map.fleet_point(place) if fleet else _map.army_point(place)) if last else _map.province_point(place)
				if p != Vector3.INF:
					points.append(p)
			if points.size() < 2:
				continue
			_where[("f:" if fleet else "a:") + str(march["id"])] = road[-1]
			moving.append([nodes, points, fleet])
			if march.get("mine", false):
				focus.append(points[0])
				focus.append(points[-1])
	if moving.is_empty():
		return
	await _frame(focus)
	if _skip:
		return
	if moving.any(func(item: Array) -> bool: return not item[2]):
		_audio.play("march")
	for item in moving:
		_walk(item[0], item[1], item[2])
	await _wait(MARCH_SECONDS + 0.2)


## One army walks a road of points (or a fleet sails a course), turning to face its way,
## raising dust (or spray).
func _walk(nodes: Dictionary, points: Array[Vector3], afloat := false) -> void:
	var piece: Node3D = nodes["piece"]
	var label: Node3D = nodes["label"]
	if not afloat:
		_map.stop_bobbing(piece)
	var lift := label.position - piece.position
	var lengths: Array[float] = [0.0]
	for i in range(1, points.size()):
		lengths.append(lengths[-1] + points[i - 1].distance_to(points[i]))
	var total := maxf(lengths[-1], 0.001)
	var trail := _dust_trail() if not afloat else _spray()
	piece.add_child(trail)
	var phase := randf() * TAU
	var tween := _tween()
	tween.tween_method(func(t: float) -> void:
		var e := (1.0 - cos(t * PI)) / 2.0   # eased at both ends
		var along := e * total
		var i := 1
		while i < points.size() - 1 and lengths[i] < along:
			i += 1
		var a := points[i - 1]
		var b := points[i]
		var part := clampf((along - lengths[i - 1]) / maxf(b.distance_to(a), 0.001), 0.0, 1.0)
		var at := a.lerp(b, part)
		var heading := Vector2(b.x - a.x, b.z - a.z)
		if heading.length() > 0.01:
			piece.rotation.y = lerp_angle(piece.rotation.y, -heading.angle() - PI / 2.0, 0.2)
		if afloat:  # the swell keeps the height; the ship only moves over the water
			piece.position.x = at.x
			piece.position.z = at.z
		else:
			piece.position = at + Vector3(0, absf(sin(t * 28.0 + phase)) * 0.35 * piece.scale.y, 0)
		label.position = Vector3(at.x, piece.position.y, at.z) + lift, 0.0, 1.0, MARCH_SECONDS)
	tween.tween_callback(func() -> void: trail.emitting = false)


func _spray() -> CPUParticles3D:
	var spray := _puffs(Color(0.95, 0.97, 1.0), 0.6 * FX, 1.4 * FX)
	spray.amount = 16
	spray.lifetime = 1.2
	spray.direction = Vector3(0, 0.3, 0)
	spray.spread = 80.0
	spray.initial_velocity_min = 0.5 * FX
	spray.initial_velocity_max = 1.2 * FX
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = 1.5 * FX
	return spray


func _dust_trail() -> CPUParticles3D:
	var dust := _puffs(DUST, 0.9 * FX, 1.2 * FX)
	dust.amount = 14
	dust.lifetime = 1.0
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 60.0
	dust.initial_velocity_min = 0.6 * FX
	dust.initial_velocity_max = 1.4 * FX
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 2.5 * FX
	return dust


# --- battles -----------------------------------------------------------------------------


func _battles(battles: Array, skirmishes: Array, lost: Array) -> void:
	# battles elsewhere flare all at once where they were fought
	for at in skirmishes:
		var p := _map.army_point(str(at))
		if p == Vector3.INF:
			p = _map.fleet_point(str(at))
		if p != Vector3.INF:
			_burst(p, 0.6)
	for battle in battles:
		if _skip:
			return
		var sea: bool = battle.get("sea", false)
		var at := _map.fleet_point(str(battle["at"])) if sea else _map.army_point(str(battle["at"]))
		if at == Vector3.INF:
			continue
		if battle.get("mine", false):
			await _fly(at, 170.0, 1.0)
		await _clash(battle, at, lost)


func _clash(battle: Dictionary, at: Vector3, lost: Array) -> void:
	var mine: bool = battle.get("mine", false)
	# the hosts there lunge at one another
	var sea: bool = battle.get("sea", false)
	var forces: Dictionary = _map.fleet_nodes if sea else _map.army_nodes
	var here: Array = []
	for id in forces:
		if _where.get(("f:" if sea else "a:") + str(id), "") == battle["at"]:
			here.append(forces[id]["piece"])
	for piece in here:
		var rest: Vector3 = piece.position
		var towards: Vector3 = (at - rest).normalized() * 8.0 if rest.distance_to(at) > 0.5 else Vector3(5.0, 0, 0)
		var tween := _tween()
		for k in 3:
			tween.tween_property(piece, "position", rest + towards, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(piece, "position", rest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_audio.play("clash")
	_burst(at, 1.0 if mine else 0.7)
	var winner: String = battle["winner"]
	var colour: Color = _map.civ_colours.get(winner, Color.WHITE)
	var verdict := ""
	var tint := Color(1.0, 0.96, 0.86)
	if mine:
		verdict = "VICTORY" if battle.get("won", false) else "DEFEAT"
		tint = Color(1.0, 0.84, 0.3) if battle.get("won", false) else Color(1.0, 0.4, 0.32)
	else:
		verdict = "%s wins" % _map.civ_names.get(winner, winner)
	_caption(at + Vector3(0, 14, 0), "⚔ " + str(battle["name"]), 40, Color(1.0, 0.97, 0.9), colour.darkened(0.6), 0.0, 58.0)
	_caption(at + Vector3(0, 14, 0), verdict, 56 if mine else 34, tint, Color(0.08, 0.05, 0.03), 0.35)
	if mine:
		await _wait(0.9)
		_audio.play("horn" if battle.get("won", false) else "defeat")
		_sink_lost_at(str(battle["at"]), lost)
		await _wait(1.4)
	else:
		_sink_lost_at(str(battle["at"]), lost)
		await _wait(0.9)


## Dust, sparks and flashes where armies meet; `size` scales it.
func _burst(at: Vector3, size: float) -> void:
	var dust := _puffs(DUST, 2.2 * size * FX, 3.5 * size * FX)
	dust.one_shot = true
	dust.explosiveness = 0.85
	dust.amount = int(40 * size)
	dust.lifetime = 1.8
	dust.direction = Vector3(0, 0.4, 0)
	dust.spread = 180.0
	dust.initial_velocity_min = 3.0 * size * FX
	dust.initial_velocity_max = 7.0 * size * FX
	dust.damping_min = 3.0
	dust.damping_max = 5.0
	dust.position = at + Vector3(0, 1.5, 0)
	add_child(dust)
	dust.emitting = true
	var sparks := CPUParticles3D.new()
	var bit := BoxMesh.new()
	bit.size = Vector3.ONE * 0.35 * FX * 0.6
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.85, 0.4)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.7, 0.2)
	glow.emission_energy_multiplier = 3.0
	bit.material = glow
	sparks.mesh = bit
	sparks.amount = int(36 * size)
	sparks.lifetime = 0.55
	sparks.explosiveness = 0.3
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 70.0
	sparks.initial_velocity_min = 6.0 * size * FX * 0.7
	sparks.initial_velocity_max = 13.0 * size * FX * 0.7
	sparks.gravity = Vector3(0, -30 * FX * 0.7, 0)
	sparks.position = at + Vector3(0, 2.0, 0)
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sparks)
	sparks.emitting = true
	var stop := _tween()
	stop.tween_interval(1.1)
	stop.tween_callback(func() -> void: sparks.emitting = false)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.omni_range = 40.0 * size * FX * 0.6
	flash.position = at + Vector3(0, 6, 0)
	add_child(flash)
	var pulse := _tween()
	for k in 3:
		pulse.tween_property(flash, "light_energy", 5.0 * size, 0.06)
		pulse.tween_property(flash, "light_energy", 0.0, 0.3)


## Soft round puffs that swell and fade.
func _puffs(colour: Color, from_size: float, to_size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	puff.material = material
	particles.mesh = puff
	var grow := Curve.new()
	grow.add_point(Vector2(0, from_size))
	grow.add_point(Vector2(1, to_size))
	particles.scale_amount_curve = grow
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	particles.color_ramp = fade
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


## Armies destroyed in a battle sink into the dust; fleets, beneath the waves.
func _sink_lost_at(place: String, lost: Array) -> void:
	for force in lost:
		var fleet: bool = force.get("fleet", false)
		var key := ("f:" if fleet else "a:") + str(force["id"])
		if str(force["at"]) == place or _where.get(key, "") == place:
			_sink(str(force["id"]), fleet)


func _fade_lost(lost: Array) -> void:
	for force in lost:
		_sink(str(force["id"]), force.get("fleet", false))


func _sink(id: String, fleet := false) -> void:
	var nodes := _nodes(id, fleet)
	if nodes.is_empty() or nodes.get("sunk", false):
		return
	nodes["sunk"] = true
	var piece: Node3D = nodes["piece"]
	var label: Node3D = nodes["label"]
	var tween := _tween().set_parallel()
	tween.tween_property(piece, "scale", Vector3.ONE * 0.01, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)


# --- sieges ------------------------------------------------------------------------------


## Stones arc from the besiegers into the city, which burns and smokes; the player's own
## sieges (theirs or against them) are visited, the rest smoke where they are.
func _sieges(sieges: Array) -> void:
	var visited := 0
	for siege in sieges:
		if _skip:
			return
		var city := _map.province_point(str(siege["at"]))
		var camp := _map.army_point(str(siege["at"]))
		if city == Vector3.INF or camp == Vector3.INF:
			continue
		var mine: bool = siege.get("mine", false)
		if mine and visited < 3:
			visited += 1
			await _fly(city.lerp(camp, 0.5), 160.0, 0.9)
		_city_burns(city, mine)
		if mine:
			var by := str(siege["by"])
			var place := _map.province_name(str(siege["at"]))
			var words := "Siege of %s · %d%%" % [place, int(siege["progress"])]
			var tint := Color(1.0, 0.84, 0.3) if by == _map.player else Color(1.0, 0.45, 0.35)
			_caption(city + Vector3(0, 18, 0), words, 40, tint, Color(0.08, 0.05, 0.03))
			_audio.play("clash")
			for k in 5:
				_stone(camp, city, 0.25 * k)
			await _wait(2.0)


## Fire and black smoke over a besieged city.
func _city_burns(city: Vector3, large: bool) -> void:
	var smoke := _puffs(Color(0.25, 0.22, 0.2), 1.2 * FX, (4.5 if large else 3.0) * FX)
	smoke.amount = 24
	smoke.lifetime = 3.0
	smoke.direction = Vector3(0.2, 1, 0)
	smoke.spread = 15.0
	smoke.initial_velocity_min = 3.0 * FX
	smoke.initial_velocity_max = 5.0 * FX
	smoke.position = city + Vector3(0, 2.0, 0)
	add_child(smoke)
	smoke.emitting = true
	var fire := _puffs(Color(1.0, 0.55, 0.15), 0.8 * FX, 0.1)
	fire.amount = 30
	fire.lifetime = 0.7
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 25.0
	fire.initial_velocity_min = 2.0 * FX
	fire.initial_velocity_max = 4.0 * FX
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 2.0 * FX
	fire.position = city + Vector3(0, 1.0, 0)
	add_child(fire)
	fire.emitting = true
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.15)
	glow.omni_range = 24.0 * FX
	glow.light_energy = 2.5
	glow.position = city + Vector3(0, 4, 0)
	add_child(glow)
	var flicker := _tween()
	flicker.set_loops(8)
	flicker.tween_property(glow, "light_energy", 1.4, 0.18)
	flicker.tween_property(glow, "light_energy", 2.8, 0.22)
	var out := _tween()
	out.tween_interval(3.2)
	out.tween_callback(func() -> void:
		smoke.emitting = false
		fire.emitting = false)
	out.tween_property(glow, "light_energy", 0.0, 0.8)


## A stone from a siege engine, flying in an arc from the camp into the city.
func _stone(camp: Vector3, city: Vector3, delay: float) -> void:
	var stone := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 1.6
	ball.height = 3.2
	stone.mesh = ball
	stone.material_override = _flat(Color(0.42, 0.38, 0.34))
	stone.visible = false
	add_child(stone)
	var start := camp + Vector3(0, 2.5, 0)
	var end := city + Vector3(randf_range(-2, 2), 1.0, randf_range(-2, 2))
	var height := start.distance_to(end) * 0.5 + 6.0
	var tween := _tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: stone.visible = true)
	tween.tween_method(func(t: float) -> void:
		stone.position = start.lerp(end, t) + Vector3(0, sin(t * PI) * height, 0), 0.0, 1.0, 0.9)
	tween.tween_callback(func() -> void:
		stone.queue_free()
		_burst(end, 0.35))


# --- land changing hands -----------------------------------------------------------------


func _taken(taken: Array) -> void:
	if taken.is_empty():
		return
	var ordered := taken.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("mine", false) and not b.get("mine", false))
	var shown := 0
	for change in ordered:
		var at := _map.province_point(str(change["at"]))
		if at == Vector3.INF:
			continue
		var mine: bool = change.get("mine", false)
		if mine and shown < 6 and not _skip:
			await _fly(at, 200.0, 0.9)
			shown += 1
		_banner(change, at, mine)
		if mine and not _skip:
			await _wait(1.6)


## A banner pole rises in the new owner's colours with their arms, a ring sweeps out over
## the land, and a line says what happened.
func _banner(change: Dictionary, at: Vector3, mine: bool) -> void:
	var to = change.get("to")
	var was = change.get("from")
	var place := _map.province_name(str(change["at"]))
	var colour: Color = _map.civ_colours.get(to, Color(0.85, 0.82, 0.75)) if to != null else Color(0.85, 0.82, 0.75)
	var holder := Node3D.new()
	holder.position = at
	add_child(holder)
	var pole := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.25
	stick.bottom_radius = 0.3
	stick.height = 14.0
	pole.mesh = stick
	pole.material_override = _flat(Color(0.35, 0.24, 0.14))
	pole.position = Vector3(0, 7.0, 0)
	holder.add_child(pole)
	var cloth := MeshInstance3D.new()
	var sheet := BoxMesh.new()
	sheet.size = Vector3(5.5, 3.6, 0.15)
	cloth.mesh = sheet
	cloth.material_override = _flat(colour)
	cloth.position = Vector3(2.9, 12.0, 0)
	holder.add_child(cloth)
	if to != null and str(_map.civ_symbols.get(to, "")) != "":
		var arms := Sprite3D.new()
		arms.texture = Symbols.shield(colour, str(_map.civ_symbols[to]), 128)
		arms.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		arms.pixel_size = 0.05
		arms.position = Vector3(0, 18.5, 0)
		holder.add_child(arms)
	holder.scale = Vector3(2.2, 0.01, 2.2)
	var rise := _tween()
	rise.tween_property(holder, "scale", Vector3.ONE * 2.2, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var wave := _tween()
	wave.set_loops(4)
	wave.tween_property(cloth, "rotation:y", 0.25, 0.4).set_trans(Tween.TRANS_SINE)
	wave.tween_property(cloth, "rotation:y", -0.15, 0.4).set_trans(Tween.TRANS_SINE)
	# the ring sweeping out over the province
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	ring.mesh = torus
	var ring_material := _flat(colour.lightened(0.2))
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_material
	ring.position = at + Vector3(0, 0.6, 0)
	ring.scale = Vector3.ONE * 2.0
	add_child(ring)
	var sweep := _tween().set_parallel()
	sweep.tween_property(ring, "scale", Vector3(60, 1, 60), 1.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	sweep.tween_property(ring_material, "albedo_color:a", 0.0, 1.6)
	var me := _map.player
	var line := ""
	if to == me:
		line = "%s is ours!" % place
	elif was == me:
		line = "%s is lost" % place
	elif to == null:
		line = "%s throws off its rulers" % place
	else:
		line = "%s falls to %s" % [place, _map.civ_names.get(to, str(to))]
	var tint := Color(1.0, 0.84, 0.3) if to == me else (Color(1.0, 0.45, 0.35) if was == me else Color(1.0, 0.97, 0.9))
	_caption(at + Vector3(0, 46, 0), line, 44 if mine else 30, tint, colour.darkened(0.6))
	if mine:
		_audio.play("horn" if to == me else "defeat")


# --- ideas from the future come to life (D-126) ---------------------------------------------


## The camera goes to the capital, where a pillar of golden light rises: an idea from the
## future works, centuries early.
func _breakthroughs(items: Array) -> void:
	var at := _map.capital_point(_map.player)
	if items.is_empty() or at == Vector3.INF or _skip:
		return
	await _fly(at, 230.0, 1.0)
	for item in items.slice(0, 2):
		if _skip:
			return
		_audio.play("victory")
		_pillar(at)
		_caption(at + Vector3(0, 40, 0), "✦ %s ✦" % str(item["name"]).to_upper(), 54, Color(1.0, 0.86, 0.35), Color(0.25, 0.12, 0.02), 0.2, 64.0)
		_caption(at + Vector3(0, 40, 0), "%s years before its time" % GameHud.number(int(item["ahead"])), 30, Color(1.0, 0.97, 0.9), Color(0.25, 0.12, 0.02), 0.5)
		await _wait(2.6)


func _pillar(at: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 3.0
	cylinder.bottom_radius = 7.0
	cylinder.height = 140.0
	beam.mesh = cylinder
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	light.albedo_color = Color(1.0, 0.8, 0.35, 0.0)
	light.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = light
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = at + Vector3(0, 70, 0)
	beam.scale = Vector3(0.2, 1, 0.2)
	add_child(beam)
	var grow := _tween().set_parallel()
	grow.tween_property(beam, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(light, "albedo_color:a", 0.55, 0.4)
	grow.set_parallel(false)
	grow.tween_interval(1.6)
	grow.tween_property(light, "albedo_color:a", 0.0, 1.0)
	var sparkles := _puffs(Color(1.0, 0.88, 0.45), 0.6 * FX, 0.05)
	sparkles.amount = 60
	sparkles.lifetime = 2.2
	sparkles.direction = Vector3(0, 1, 0)
	sparkles.spread = 20.0
	sparkles.initial_velocity_min = 10.0 * FX
	sparkles.initial_velocity_max = 18.0 * FX
	sparkles.gravity = Vector3.ZERO
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 6.0
	sparkles.position = at + Vector3(0, 2, 0)
	add_child(sparkles)
	sparkles.emitting = true
	var stop := _tween()
	stop.tween_interval(2.0)
	stop.tween_callback(func() -> void: sparkles.emitting = false)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.82, 0.4)
	glow.omni_range = 60.0 * FX
	glow.position = at + Vector3(0, 12, 0)
	add_child(glow)
	var shine := _tween()
	shine.tween_property(glow, "light_energy", 4.0, 0.4)
	shine.tween_interval(1.4)
	shine.tween_property(glow, "light_energy", 0.0, 1.0)


# --- new armies --------------------------------------------------------------------------


func _raised(raised: Array) -> void:
	for army in raised:
		var nodes: Dictionary = _map.army_nodes.get(army["id"], {})
		if nodes.is_empty():
			continue
		var piece: Node3D = nodes["piece"]
		var size := piece.scale
		piece.scale = size * 0.01
		var grow := _tween()
		grow.tween_interval(randf() * 0.4)
		grow.tween_property(piece, "scale", size, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var puff := _puffs(DUST, 1.5, 3.0)
		puff.one_shot = true
		puff.explosiveness = 0.9
		puff.amount = 16
		puff.lifetime = 1.2
		puff.spread = 180.0
		puff.initial_velocity_min = 2.0
		puff.initial_velocity_max = 4.0
		puff.position = piece.position + Vector3(0, 1, 0)
		add_child(puff)
		puff.emitting = true


# --- small helpers -----------------------------------------------------------------------


## Words over the map that rise a little and fade.
func _caption(at: Vector3, text: String, size: int, colour: Color, outline: Color, delay := 0.0,
		lift_px := 0.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0007
	label.font_size = size
	label.outline_size = 14
	label.modulate = Color(colour, 0.0)
	label.outline_modulate = Color(outline, 0.0)
	label.no_depth_test = true
	label.render_priority = 20
	label.outline_render_priority = 19
	label.position = at
	label.offset = Vector2(0, lift_px)   # lines over one place stack on screen, not on the map
	label.font = UiStyle.font("title", 800)
	add_child(label)
	var tween := _tween()
	tween.tween_interval(delay)
	tween.set_parallel()
	tween.tween_property(label, "modulate:a", 1.0, 0.25)
	tween.tween_property(label, "outline_modulate:a", outline.a, 0.25)
	tween.tween_property(label, "position:y", at.y + 4.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(1.6)
	tween.set_parallel()
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.6)


func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	return material
