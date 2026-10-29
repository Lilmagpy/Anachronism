## A crowd for the spectacles (U6): thousands of seated figures on tiers or along a street, drawn
## with MultiMeshes and animated entirely in a vertex shader (sway, hop, arms thrown up, and a
## travelling wave of that movement that follows `wave_pos` round the ring), so it costs nothing
## on the CPU while it plays.
##
## Two levels of detail (re-sorted by distance from the camera as it moves): lod 1 is a proper
## low-poly person (torso, painted face, hair, arms, seated legs, hem) for the near seats, lod 2
## a cheap one (torso, head, arms) for the rest. Tunic colours go by class: the first `toga_rows`
## rows wear white togas, the rows behind coloured tunics; a share can wear faction colours.
##
## Usage:
##   var c = preload("res://scripts/urbs/crowd.gd").new()
##   c.add_seats(UrbsCrowd.stadium_seats(...))   # or ellipse_seats / line_seats
##   c.build(); parent.add_child(c)
##   c.set_state(clock_seconds, roar 0..1, wave_pos 0..1)
## Seats are {pos, yaw, u, row}: position, facing, position round the ring (for the wave), tier.
extends Node3D

const M := preload("res://scripts/urbs/spectacles/meshlib.gd")
const F := preload("res://scripts/urbs/spectacles/figure.gd")

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float clock = 0.0;
uniform float roar = 0.2;       // 0 sits quietly, 1 on their feet cheering
uniform float wave_pos = 0.0;   // 0..1 round the ring
uniform float wave_amt = 0.8;
uniform float shoulder_y = 0.96;
uniform sampler2D face : source_color, filter_linear;
varying vec3 tint;
varying float part;
varying float tone;
varying float hairv;
void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float u = INSTANCE_CUSTOM.y;
	float d = abs(fract(u - wave_pos + 0.5) - 0.5);
	float w = exp(-pow(d * 12.0, 2.0)) * wave_amt;
	float lift = clamp(roar * (0.45 + 0.55 * sin(clock * 7.0 + phase * 6.283)) + w, 0.0, 1.0);
	part = UV2.x;
	tint = COLOR.rgb;
	tone = INSTANCE_CUSTOM.z;
	hairv = INSTANCE_CUSTOM.w;
	vec3 v = VERTEX;
	if (part > 1.5 && part < 2.5) {
		vec3 sh = vec3(sign(v.x) * 0.205, shoulder_y, 0.0);
		vec3 p = v - sh;
		float a = lift * lift * 2.9 * sign(v.x);
		float ca = cos(a); float sa = sin(a);
		p = vec3(p.x * ca - p.y * sa, p.x * sa + p.y * ca, p.z);
		v = p + sh;
	}
	v.y += lift * 0.12 * abs(sin(clock * 9.0 + phase * 6.283)) + 0.012 * sin(clock * 1.7 + phase * 20.0);
	VERTEX = v;
}
void fragment() {
	vec3 skin = mix(vec3(0.95, 0.75, 0.6), vec3(0.6, 0.4, 0.3), tone);
	vec3 c = skin;
	if (part < 0.5) {
		c = texture(face, UV).rgb * mix(1.1, 0.72, tone);
	} else if (part < 1.5) {
		c = tint;
	} else if (part > 3.5) {
		c = mix(vec3(0.12, 0.09, 0.07), vec3(0.42, 0.3, 0.2), hairv);
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

var _seats: Array[Dictionary] = []   # {pos, yaw, u, row}
var _inst: Array[Dictionary] = []    # per seat: {xf, col, custom}
var _mm1: MultiMeshInstance3D
var _mm2: MultiMeshInstance3D
var _mat: ShaderMaterial
var palette: Array[Color] = [
	Color(0.78, 0.7, 0.5), Color(0.7, 0.45, 0.3), Color(0.55, 0.62, 0.7), Color(0.62, 0.5, 0.38),
	Color(0.4, 0.5, 0.35), Color(0.72, 0.3, 0.25), Color(0.85, 0.8, 0.68), Color(0.5, 0.4, 0.55),
]
var seed_value := 7
## The first rows are the knights and senators in white togas.
var toga_rows := 3
## The share that wears `fan_colours` (faction colours at the races).
var fan_colours: Array[Color] = []
var fan_share := 0.0
## Seats nearer the camera than this get the detailed figure.
var lod_distance := 42.0
## Standing figures (a street) instead of seated ones (tiers).
var standing := false
var _last_cam := Vector3(1e9, 1e9, 1e9)
var _timer := 0.0


func add_seat(pos: Vector3, yaw: float, u: float, row := 0) -> void:
	_seats.append({"pos": pos, "yaw": yaw, "u": u, "row": row})


func add_seats(list: Array) -> void:
	for s in list:
		_seats.append(s)


func count() -> int:
	return _seats.size()


## Build the MultiMeshes from the seats added so far.
func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for s in _seats:
		var p: Vector3 = s["pos"]
		var sc := rng.randf_range(0.92, 1.08)
		var b := Basis(Vector3.UP, float(s["yaw"]) + rng.randf_range(-0.2, 0.2)).scaled(Vector3.ONE * sc)
		var row := int(s.get("row", 0))
		var col: Color
		if row < toga_rows:
			col = Color(0.94, 0.92, 0.85).lerp(Color(0.8, 0.78, 0.7), rng.randf() * 0.35)
		else:
			col = palette[rng.randi() % palette.size()]
			if fan_colours.size() > 0 and rng.randf() < fan_share:
				col = fan_colours[rng.randi() % fan_colours.size()]
			col = col.lerp(Color(0.5, 0.5, 0.5), rng.randf() * 0.15)
		_inst.append({"xf": Transform3D(b, p), "col": col,
			"custom": Color(rng.randf(), float(s["u"]), rng.randf(), rng.randf())})
		lo = lo.min(p)
		hi = hi.max(p)
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("face", M.face_texture(Color(0.86, 0.66, 0.52), 3))
	var aabb := AABB(lo - Vector3(2, 2, 2), hi - lo + Vector3(4, 6, 4)) if _seats.size() > 0 else AABB()
	_mat.set_shader_parameter("shoulder_y", (0.92 if standing else 0.49) + F.SH_Y)
	_mm1 = _make_mm(_figure_mesh(1, standing), aabb)
	_mm2 = _make_mm(_figure_mesh(2, standing), aabb)
	update_lod(Vector3(1e8, 0, 0))   # everything far until a camera is known


func _make_mm(mesh: Mesh, aabb: AABB) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = _inst.size()
	mm.visible_instance_count = 0
	if _inst.size() > 0:
		mm.custom_aabb = aabb
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Sort the seats into the two detail levels by distance from `cam_pos`.
func update_lod(cam_pos: Vector3) -> void:
	_last_cam = cam_pos
	var m1 := _mm1.multimesh
	var m2 := _mm2.multimesh
	var n1 := 0
	var n2 := 0
	var d2 := lod_distance * lod_distance
	var g := global_transform
	var cam_local := g.affine_inverse() * cam_pos
	for it in _inst:
		var xf: Transform3D = it["xf"]
		if xf.origin.distance_squared_to(cam_local) < d2:
			m1.set_instance_transform(n1, xf)
			m1.set_instance_color(n1, it["col"])
			m1.set_instance_custom_data(n1, it["custom"])
			n1 += 1
		else:
			m2.set_instance_transform(n2, xf)
			m2.set_instance_color(n2, it["col"])
			m2.set_instance_custom_data(n2, it["custom"])
			n2 += 1
	m1.visible_instance_count = n1
	m2.visible_instance_count = n2


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.4 or _mm1 == null:
		return
	_timer = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	if cp.distance_to(_last_cam) > 12.0:
		update_lod(cp)


## Drive the animation. `clock` seconds (use the spectacle's own time so seeking works).
func set_state(clock: float, roar: float, wave_pos: float, wave_amt := 0.8) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("clock", clock)
	_mat.set_shader_parameter("roar", clampf(roar, 0.0, 1.0))
	_mat.set_shader_parameter("wave_pos", wave_pos)
	_mat.set_shader_parameter("wave_amt", wave_amt)


# ---- the figure meshes ---------------------------------------------------------------------

static var _fig_cache: Dictionary = {}


static func _figure_mesh(lod: int, stand := false) -> ArrayMesh:
	var ck := lod + (10 if stand else 0)
	if _fig_cache.has(ck):
		return _fig_cache[ck]
	var parts: Array = []
	var seat_y := 0.92 if stand else 0.49
	if lod == 1:
		parts.append([M.lathe(F.TORSO_PROFILE, 10), Transform3D(Basis(), Vector3(0, seat_y, 0)), 1.0])
		parts.append([M.lathe([Vector4(0.06, 0.0, 0.0, 0.0), Vector4(0.06, 0.168, 0.118, 0.0), Vector4(-0.05, 0.2, 0.14, 0.0), Vector4(-0.2, 0.235, 0.17, 0.0)], 10, 1), Transform3D(Basis(), Vector3(0, seat_y, 0)), 1.0])
		parts.append([M.lathe_y(F.HEAD_PROFILE, 10, 12), Transform3D(Basis(), Vector3(0, seat_y + F.HEAD_Y + 0.03, 0)), 0.0])
		parts.append([F._hair_mesh(), Transform3D(Basis(), Vector3(0, seat_y + F.HEAD_Y + 0.03, 0)), 4.0])
		parts.append([M.ellipsoid(0.013, 0.024, 0.02, 5, 3), Transform3D(Basis(), Vector3(0, seat_y + F.HEAD_Y + 0.152, 0.106)), 2.0])
		for s in [-1.0, 1.0]:
			parts.append([M.capsule(0.055, 0.034, 0.5, 7), Transform3D(Basis(Vector3(0, 0, 1), -0.05 * s), Vector3(F.SH_X * s, seat_y + F.SH_Y, 0)), 2.0])
			# seated legs: the thigh forward, the shin down
			if stand:
				parts.append([M.capsule(0.085, 0.06, F.THIGH, 7), Transform3D(Basis(), Vector3(F.HIP_X * s, seat_y, 0)), 3.0])
				parts.append([M.capsule(0.058, 0.04, F.SHIN, 7), Transform3D(Basis(), Vector3(F.HIP_X * s, seat_y - F.THIGH, 0)), 3.0])
			else:
				parts.append([M.capsule(0.085, 0.06, F.THIGH, 7), Transform3D(Basis(Vector3.RIGHT, -PI / 2.0 + 0.0), Vector3(F.HIP_X * s, seat_y, 0)), 3.0])
				parts.append([M.capsule(0.058, 0.04, F.SHIN, 7), Transform3D(Basis(), Vector3(F.HIP_X * s, seat_y, F.THIGH)), 3.0])
	else:
		parts.append([M.lathe(F.TORSO_PROFILE, 6), Transform3D(Basis(), Vector3(0, seat_y, 0)), 1.0])
		parts.append([M.ellipsoid(0.075, 0.115, 0.095, 6, 3), Transform3D(Basis(), Vector3(0, seat_y + F.HEAD_Y + 0.15, 0)), 0.0])
		for s in [-1.0, 1.0]:
			parts.append([M.capsule(0.055, 0.034, 0.5, 4), Transform3D(Basis(), Vector3(F.SH_X * s, seat_y + F.SH_Y, 0)), 2.0])
	var m := M.merge(parts)
	_fig_cache[ck] = m
	return m


## Seats for a circus: rows of figures round a stadium-shaped track. `half_straight` is half the
## length of the straight (turn centres are at x = +-half_straight), `r0` the radius of the first
## row from the spina axis, rows go outward and upward. Set `skip_west` to leave the carceres
## end empty. Faces the centre line. The wave coordinate u runs 0..1 anticlockwise from the
## west end of the south straight, matching the race's progress.
static func stadium_seats(half_straight: float, r0: float, rows: int, spacing := 1.4, row_depth := 0.9, rise := 0.5, base_y := 0.0, skip_west := true) -> Array:
	var out: Array = []
	for k in rows:
		var r := r0 + k * row_depth
		var y := base_y + k * rise
		var straight := 2.0 * half_straight
		var turn := PI * r
		var total := 2.0 * straight + 2.0 * turn
		var n := int(total / spacing)
		for i in n:
			var d := total * (float(i) + 0.5) / n
			var p := _stadium_point(half_straight, r, d)
			if skip_west and p.x < -half_straight - 1.0:
				continue
			var inward := Vector3(-p.x, 0, -p.z)
			if absf(p.x) <= half_straight:
				inward = Vector3(0, 0, -p.z)
			else:
				inward = Vector3(-(p.x - signf(p.x) * half_straight), 0, -p.z)
			out.append({"pos": Vector3(p.x, y, p.z), "yaw": atan2(inward.x, inward.z), "u": d / total, "row": k})
	return out


# Point at distance d along the stadium path of radius r: start (-L, r) heading east on the
# south side (z = +r), east turn, north straight heading west, west turn: anticlockwise from above.
static func _stadium_point(half_straight: float, r: float, d: float) -> Vector3:
	var straight := 2.0 * half_straight
	var turn := PI * r
	if d < straight:
		return Vector3(-half_straight + d, 0, r)
	d -= straight
	if d < turn:
		var a := d / r   # 0..PI, from south (+z) round east to north
		return Vector3(half_straight + sin(a) * r, 0, cos(a) * r)
	d -= turn
	if d < straight:
		return Vector3(half_straight - d, 0, -r)
	d -= straight
	var a2 := d / r
	return Vector3(-half_straight - sin(a2) * r, 0, -cos(a2) * r)


## Seats round an ellipse (an arena or a forum floor): rows from the radii (rx, rz) outward.
static func ellipse_seats(rx: float, rz: float, rows: int, spacing := 1.3, row_depth := 0.9, rise := 0.5, base_y := 0.0) -> Array:
	var out: Array = []
	for k in rows:
		var a := rx + (k + 0.5) * row_depth
		var b := rz + (k + 0.5) * row_depth
		var circ := PI * (3.0 * (a + b) - sqrt((3.0 * a + b) * (a + 3.0 * b)))
		var n := int(circ / spacing)
		for i in n:
			var t := TAU * (float(i) + 0.5) / n
			var p := Vector3(cos(t) * a, base_y + k * rise, sin(t) * b)
			out.append({"pos": p, "yaw": atan2(-p.x, -p.z), "u": float(i) / n, "row": k})
	return out


## Spectators along a polyline (a street): `rows` rows each side starting `offset` metres from
## the line, `step` apart along it, facing the line. u runs 0..1 along the line, so the wave
## can travel with the procession.
static func line_seats(poly: PackedVector3Array, offset: float, rows := 2, step := 1.2, row_depth := 0.9, rise := 0.35) -> Array:
	var out: Array = []
	var lens: Array[float] = [0.0]
	for i in range(1, poly.size()):
		lens.append(lens[i - 1] + poly[i].distance_to(poly[i - 1]))
	var total: float = lens[lens.size() - 1]
	var n := int(total / step)
	var seg := 0
	for i in n:
		var d := total * (float(i) + 0.5) / n
		while seg < poly.size() - 2 and lens[seg + 1] < d:
			seg += 1
		var span: float = maxf(lens[seg + 1] - lens[seg], 0.001)
		var t: float = (d - lens[seg]) / span
		var p := poly[seg].lerp(poly[seg + 1], t)
		var dir := (poly[seg + 1] - poly[seg])
		dir.y = 0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		for k in rows:
			for s in [-1.0, 1.0]:
				var q: Vector3 = p + side * s * (offset + k * row_depth)
				q.y += k * rise
				out.append({"pos": q, "yaw": atan2(-s * side.x, -s * side.z), "u": d / total, "row": k})
	return out
