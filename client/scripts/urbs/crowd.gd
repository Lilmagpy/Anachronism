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
var lod_distance := 30.0
## Beyond this the cheap figure; beyond cull_distance nothing is drawn.
var far_distance := 110.0
var cull_distance := 700.0
var cell_size := 48.0
var _cells: Array[Dictionary] = []
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


## Build the MultiMeshes from the seats added so far: the seats are grouped into square cells
## (so each cell is culled by the camera on its own) and each cell has one MultiMesh per level
## of detail.
func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("face", M.face_texture(Color(0.86, 0.66, 0.52), 3))
	_mat.set_shader_parameter("shoulder_y", (0.92 if standing else 0.49) + F.SH_Y)
	var cell_of: Dictionary = {}
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
		var inst := {"xf": Transform3D(b, p), "col": col, "custom": Color(rng.randf(), float(s["u"]), rng.randf(), rng.randf())}
		var key := Vector2i(floori(p.x / cell_size), floori(p.z / cell_size))
		if not cell_of.has(key):
			cell_of[key] = {"inst": [], "lo": p, "hi": p, "last": [-1, -1, -1], "mm": [], "mi": []}
		var c: Dictionary = cell_of[key]
		(c["inst"] as Array).append(inst)
		c["lo"] = (c["lo"] as Vector3).min(p)
		c["hi"] = (c["hi"] as Vector3).max(p)
	var meshes: Array = [_figure_mesh(1, standing), _figure_mesh(2, standing), _figure_mesh(3, standing)]
	for key in cell_of:
		var c: Dictionary = cell_of[key]
		var lo: Vector3 = c["lo"]
		var hi: Vector3 = c["hi"]
		var aabb := AABB(lo - Vector3(2, 2, 2), hi - lo + Vector3(4, 6, 4))
		c["centre"] = aabb.get_center()
		c["radius"] = aabb.size.length() * 0.5
		var n: int = (c["inst"] as Array).size()
		for lv in 3:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = meshes[lv]
			mm.instance_count = n
			mm.visible_instance_count = 0
			mm.custom_aabb = aabb
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = _mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			(c["mm"] as Array).append(mm)
			(c["mi"] as Array).append(mi)
		_cells.append(c)
	update_lod(Vector3(1e8, 0, 0))   # everything far until a camera is known


## Sort the seats into the three detail levels by distance from `cam_pos` (world space).
func update_lod(cam_pos: Vector3) -> void:
	_last_cam = cam_pos
	var cam_local := global_transform.affine_inverse() * cam_pos
	var d1 := lod_distance * lod_distance
	var d2 := far_distance * far_distance
	for c in _cells:
		var dc: float = (c["centre"] as Vector3).distance_to(cam_local)
		var r: float = c["radius"]
		var mms: Array = c["mm"]
		if dc - r > cull_distance:
			for lv in 3:
				(mms[lv] as MultiMesh).visible_instance_count = 0
			c["last"] = [-1, -1, -1]
			continue
		var insts: Array = c["inst"]
		var all_far := dc - r > far_distance
		if all_far and (c["last"] as Array)[2] == insts.size():
			continue
		var n := [0, 0, 0]
		for it in insts:
			var xf: Transform3D = it["xf"]
			var dd := xf.origin.distance_squared_to(cam_local)
			var lv := 0 if dd < d1 else (1 if dd < d2 else 2)
			var m: MultiMesh = mms[lv]
			var k: int = n[lv]
			m.set_instance_transform(k, xf)
			m.set_instance_color(k, it["col"])
			m.set_instance_custom_data(k, it["custom"])
			n[lv] = k + 1
		for lv in 3:
			(mms[lv] as MultiMesh).visible_instance_count = n[lv]
		c["last"] = n


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.4 or _cells.is_empty():
		return
	_timer = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	if cp.distance_to(_last_cam) > 10.0:
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
	var xf0 := Transform3D(Basis(), Vector3(0, seat_y, 0))
	if lod == 1:
		parts.append([M.lathe(F.TORSO_PROFILE, 10), xf0, 1.0])
		parts.append([M.lathe([Vector4(0.06, 0.0, 0.0, 0.0), Vector4(0.06, 0.168, 0.118, 0.0), Vector4(-0.05, 0.2, 0.14, 0.0), Vector4(-0.2, 0.235, 0.17, 0.0)], 10, 1), xf0, 1.0])
		parts.append([M.lathe_y(F.HEAD_PROFILE, 10, 12), Transform3D(Basis(), Vector3(0, seat_y + F.HEAD_Y + 0.03, 0)), 0.0])
		parts.append([F._hair_mesh(), Transform3D(Basis(), Vector3(0, seat_y + F.HEAD_Y + 0.03, 0)), 4.0])
		parts.append([M.ellipsoid(0.013, 0.024, 0.02, 5, 3), Transform3D(Basis(), Vector3(0, seat_y + F.HEAD_Y + 0.152, 0.106)), 2.0])
		for s in [-1.0, 1.0]:
			parts.append([M.capsule(0.055, 0.034, 0.5, 7), Transform3D(Basis(Vector3(0, 0, 1), -0.05 * s), Vector3(F.SH_X * s, seat_y + F.SH_Y, 0)), 2.0])
			if stand:
				parts.append([M.capsule(0.085, 0.06, F.THIGH, 7), Transform3D(Basis(), Vector3(F.HIP_X * s, seat_y, 0)), 3.0])
				parts.append([M.capsule(0.058, 0.04, F.SHIN, 7), Transform3D(Basis(), Vector3(F.HIP_X * s, seat_y - F.THIGH, 0)), 3.0])
			else:
				parts.append([M.capsule(0.085, 0.06, F.THIGH, 7), Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(F.HIP_X * s, seat_y, 0)), 3.0])
				parts.append([M.capsule(0.058, 0.04, F.SHIN, 7), Transform3D(Basis(), Vector3(F.HIP_X * s, seat_y, F.THIGH)), 3.0])
	elif lod == 2:
		parts.append([M.lathe(F.TORSO_PROFILE, 6, 0, 1), xf0, 1.0])
		parts.append([M.ellipsoid(0.075, 0.115, 0.095, 6, 3), Transform3D(Basis(), Vector3(0, seat_y + F.HEAD_Y + 0.15, 0)), 0.0])
		for s in [-1.0, 1.0]:
			parts.append([M.ellipsoid(0.045, 0.26, 0.045, 4, 3), Transform3D(Basis(), Vector3(F.SH_X * s, seat_y + F.SH_Y - 0.22, 0)), 2.0])
			if stand:
				parts.append([M.ellipsoid(0.07, 0.42, 0.07, 4, 3), Transform3D(Basis(), Vector3(F.HIP_X * s, seat_y - 0.42, 0)), 3.0])
	else:
		parts.append([M.ellipsoid(0.19, 0.3, 0.11, 5, 3), Transform3D(Basis(), Vector3(0, seat_y + 0.3, 0)), 1.0])
		parts.append([M.ellipsoid(0.08, 0.11, 0.09, 4, 2), Transform3D(Basis(), Vector3(0, seat_y + F.HEAD_Y + 0.15, 0)), 0.0])
		if stand:
			parts.append([M.ellipsoid(0.15, 0.45, 0.09, 4, 2), Transform3D(Basis(), Vector3(0, seat_y - 0.45, 0)), 3.0])
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


# ---- walkers (U8 street life): a vertex-shader walk cycle for moving MultiMesh figures ------
#
# life.gd moves thousands of people along the streets. Each is one MultiMesh instance whose
# transform is written by the simulation; the legs, arms and body bob come from this shader, so
# the CPU touches one transform per person and nothing else.
#   INSTANCE_CUSTOM.x  phase offset (0..1, turns)       .y  walk amplitude (0 stands, 1 walks, 1.4 hurries)
#   INSTANCE_CUSTOM.z  skin tone (0 light .. 1 dark)     .w  floor(w) = flags (bit 0 pilleus, bit 1 long robe,
#                                                             bit 2 dog), fract(w) = hair shade
#   COLOR              cloth colour (tunic, toga, stola; the dog's coat)
# Part ids (UV2.x) as the seated crowd, plus 5 = pilleus (drawn only with flag 1) and 6 = long robe
# (drawn only with flag 2): toga to the shin, stola to the ankle.

const WALK_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float clock = 0.0;
uniform float stride = 1.9;      // walk cycles per second at amplitude 1
uniform float hip_y = 0.92;
uniform float knee_y = 0.49;
uniform float shoulder_y = 1.39;
uniform sampler2D face : source_color, filter_linear;
varying vec3 tint;
varying float part;
varying float tone;
varying float hairv;
void vertex() {
	float ph0 = INSTANCE_CUSTOM.x * 6.2832;
	float amp = INSTANCE_CUSTOM.y;
	float flags = floor(INSTANCE_CUSTOM.w + 0.001);
	hairv = fract(INSTANCE_CUSTOM.w);
	tone = INSTANCE_CUSTOM.z;
	tint = COLOR.rgb;
	part = UV2.x;
	bool cap = mod(flags, 2.0) >= 1.0;
	bool robe = mod(floor(flags / 2.0), 2.0) >= 1.0;
	bool dog = flags >= 4.0;
	vec3 v = VERTEX;
	bool hide = (part > 4.5 && part < 5.5 && !cap) || (part > 5.5 && part < 6.5 && !robe);   // a part this person does not wear
	float phase = clock * 6.2832 * stride * (dog ? 1.8 : 1.0) + ph0;
	if (part > 2.5 && part < 3.5) {               // legs: swing from the hip, knee bends on the forward swing
		float side = sign(v.x);
		if (dog) { side *= (v.z > 0.0 ? 1.0 : -1.0); }
		float ph = phase + (side > 0.0 ? 3.14159 : 0.0);
		float sw = sin(ph) * 0.5 * amp * (robe ? 0.55 : 1.0);
		float hy = dog ? 0.32 : hip_y;
		float ky = dog ? 0.16 : knee_y;
		if (v.y < ky && !dog) {
			float kb = max(0.0, -cos(ph)) * 0.8 * amp;
			vec3 k = vec3(v.x, ky, 0.0);
			vec3 p = v - k;
			p = vec3(p.x, p.y * cos(kb) - p.z * sin(kb), p.y * sin(kb) + p.z * cos(kb));
			v = p + k;
		}
		vec3 h = vec3(v.x, hy, dog ? v.z : 0.0);
		if (dog) { h.z = v.z > 0.0 ? 0.22 : -0.24; }
		vec3 p = v - h;
		p = vec3(p.x, p.y * cos(sw) - p.z * sin(sw), p.y * sin(sw) + p.z * cos(sw));
		v = p + h;
	} else if (part > 1.5 && part < 2.5 && !dog) {    // arms: opposite the same-side leg
		float side = sign(v.x);
		float ph = phase + (side > 0.0 ? 0.0 : 3.14159);
		float a = sin(ph) * 0.42 * amp;
		vec3 s = vec3(v.x, shoulder_y, 0.0);
		vec3 p = v - s;
		p = vec3(p.x, p.y * cos(a) - p.z * sin(a), p.y * sin(a) + p.z * cos(a));
		v = p + s;
	} else if (!dog && part > 0.5 && part < 1.5 && v.y < hip_y + 0.02 && v.y > knee_y) {
		v.z += sin(phase) * 0.03 * amp * (hip_y - v.y) / (hip_y - knee_y);   // the skirt follows the legs a little
	}
	v.y += 0.03 * amp * (0.5 - 0.5 * cos(2.0 * phase)) + 0.008 * (1.0 - min(amp, 1.0)) * sin(clock * 1.3 + ph0 * 3.0);
	VERTEX = hide ? vec3(0.0) : v;
}
void fragment() {
	// colours are authored in sRGB (as the rig's source_color uniforms are); ALBEDO is linear
	vec3 skin = mix(vec3(0.86, 0.66, 0.52), vec3(0.55, 0.37, 0.27), tone);
	vec3 c = skin;
	if (part < 0.5) {
		c = texture(face, UV).rgb * mix(1.0, 0.55, tone);
	} else {
		if (part < 1.5 || (part > 5.5 && part < 6.5)) {
			c = tint;
		} else if (part > 3.5 && part < 4.5) {
			c = mix(vec3(0.12, 0.09, 0.07), vec3(0.42, 0.3, 0.2), hairv);
		} else if (part > 4.5 && part < 5.5) {
			c = vec3(0.78, 0.72, 0.6);   // undyed felt
		}
		c = pow(c, vec3(2.2));
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

static var _walk_mat: ShaderMaterial


## The shared material of every walking crowd (life.gd drives `clock`).
static func walk_material() -> ShaderMaterial:
	if _walk_mat == null:
		var sh := Shader.new()
		sh.code = WALK_SHADER
		_walk_mat = ShaderMaterial.new()
		_walk_mat.shader = sh
		_walk_mat.set_shader_parameter("face", M.face_texture(Color(0.86, 0.66, 0.52), 5))
		_walk_mat.set_shader_parameter("hip_y", 0.92)
		_walk_mat.set_shader_parameter("knee_y", 0.92 - F.THIGH)
		_walk_mat.set_shader_parameter("shoulder_y", 0.92 + F.SH_Y)
	return _walk_mat


## A standing figure for the walk shader, made for the purpose (cheap limbs, no capsules):
## level 1 (near, ~900 triangles), 2 (middle, ~230), 3 (far, ~80). Parts: 0 head (painted face at
## level 1), 1 tunic body and skirt, 2 arms, 3 legs, 4 hair, 5 pilleus (shown with flag 1), 6 long
## robe to the shin, toga or stola (flag 2). Feet at y = 0, faces +z.
static func walker_mesh(lod: int) -> ArrayMesh:
	var ck := 100 + lod
	if _fig_cache.has(ck):
		return _fig_cache[ck]
	var hip := 0.92
	var parts: Array = []
	var top := hip + F.HEAD_Y + 0.03
	var nu: int = [0, 9, 6, 4][lod]
	var cap_prof := [Vector4(0.0, 0.088, 0.1, -0.004), Vector4(0.06, 0.075, 0.085, -0.004), Vector4(0.135, 0.0, 0.0, -0.004)]
	var robe_prof := [Vector4(0.04, 0.172, 0.12, 0.0), Vector4(-0.2, 0.215, 0.155, 0.0), Vector4(-0.80, 0.262, 0.195, 0.0)]
	var skirt_prof := [Vector4(0.04, 0.17, 0.118, 0.0), Vector4(-0.36, 0.232, 0.172, 0.0)]
	var limb := func(r0: float, r1: float, length: float, n: int) -> ArrayMesh:
		return M.lathe([Vector4(-length - r1 * 0.6, 0.0, 0.0, 0.0), Vector4(-length, r1, r1, 0.0), Vector4(-length * 0.5, (r0 + r1) * 0.5, (r0 + r1) * 0.5, 0.0), Vector4(0.0, r0, r0, 0.0), Vector4(r0 * 0.6, 0.0, 0.0, 0.0)], n, 0, 1)
	if lod == 1:
		parts.append([M.lathe(F.TORSO_PROFILE, nu, 0, 1), Transform3D(Basis(), Vector3(0, hip, 0)), 1.0])
		parts.append([M.lathe(skirt_prof, nu, 1, 1), Transform3D(Basis(), Vector3(0, hip, 0)), 1.0])
		parts.append([M.lathe_y(F.HEAD_PROFILE, 10, 8), Transform3D(Basis(), Vector3(0, top, 0)), 0.0])
		parts.append([F._hair_mesh(), Transform3D(Basis(), Vector3(0, top, 0)), 4.0])
		for sx in [-1.0, 1.0]:
			parts.append([limb.call(0.056, 0.036, 0.52, 6), Transform3D(Basis(Vector3(0, 0, 1), -0.05 * sx), Vector3(F.SH_X * sx, hip + F.SH_Y, 0)), 2.0])
			parts.append([limb.call(0.08, 0.045, F.THIGH + F.SHIN, 6), Transform3D(Basis(), Vector3(F.HIP_X * sx, hip, 0)), 3.0])
			parts.append([M.ellipsoid(0.045, 0.035, 0.11, 5, 3), Transform3D(Basis(), Vector3(F.HIP_X * sx, 0.035, 0.04)), 3.0])
	elif lod == 2:
		parts.append([M.lathe([Vector4(-0.36, 0.0, 0.0, 0.0), Vector4(-0.36, 0.22, 0.16, 0.0), Vector4(0.0, 0.17, 0.115, 0.0), Vector4(0.42, 0.19, 0.11, 0.0), Vector4(0.56, 0.0, 0.0, 0.0)], nu, 0, 1), Transform3D(Basis(), Vector3(0, hip, 0)), 1.0])
		parts.append([M.ellipsoid(0.08, 0.115, 0.095, 6, 4), Transform3D(Basis(), Vector3(0, top + 0.12, 0)), 0.0])
		parts.append([M.ellipsoid(0.085, 0.07, 0.1, 6, 3), Transform3D(Basis(), Vector3(0, top + 0.17, -0.01)), 4.0])
		for sx in [-1.0, 1.0]:
			parts.append([limb.call(0.05, 0.035, 0.52, 4), Transform3D(Basis(), Vector3(F.SH_X * sx, hip + F.SH_Y, 0)), 2.0])
			parts.append([limb.call(0.075, 0.045, F.THIGH + F.SHIN, 4), Transform3D(Basis(), Vector3(F.HIP_X * sx, hip, 0)), 3.0])
	else:
		parts.append([M.ellipsoid(0.19, 0.42, 0.13, 4, 3), Transform3D(Basis(), Vector3(0, hip + 0.1, 0)), 1.0])
		parts.append([M.ellipsoid(0.085, 0.12, 0.1, 4, 2), Transform3D(Basis(), Vector3(0, top + 0.13, 0)), 0.0])
		for sx in [-1.0, 1.0]:
			parts.append([M.ellipsoid(0.075, 0.46, 0.075, 3, 2), Transform3D(Basis(), Vector3(F.HIP_X * sx, hip - 0.46, 0)), 3.0])
	if lod < 3:
		parts.append([M.lathe(cap_prof, maxi(nu, 4), 0, 1), Transform3D(Basis(), Vector3(0, top + 0.17, 0)), 5.0])
	parts.append([M.lathe(robe_prof, maxi(nu, 5), 1, 1), Transform3D(Basis(), Vector3(0, hip, 0)), 6.0])
	var m := _merge_keep(parts)
	_fig_cache[ck] = m
	return m


## A dog for the walk shader (flag 4): body, head, four legs, tail; 0.55 m at the shoulder.
## Varro RR 2.9 (read): white guard dogs were preferred, seen more easily in the dark.
static func dog_mesh() -> ArrayMesh:
	if _fig_cache.has(200):
		return _fig_cache[200]
	var parts: Array = []
	parts.append([M.ellipsoid(0.13, 0.15, 0.33, 7, 4), Transform3D(Basis(), Vector3(0, 0.42, 0)), 1.0])
	parts.append([M.ellipsoid(0.09, 0.09, 0.14, 6, 3), Transform3D(Basis(), Vector3(0, 0.52, 0.38)), 1.0])
	parts.append([M.ellipsoid(0.045, 0.045, 0.09, 4, 2), Transform3D(Basis(), Vector3(0, 0.49, 0.52)), 4.0])
	for s in [-1.0, 1.0]:
		parts.append([M.ellipsoid(0.02, 0.05, 0.012, 3, 2), Transform3D(Basis(), Vector3(0.06 * s, 0.61, 0.36)), 4.0])
		for z in [0.22, -0.24]:
			parts.append([M.ellipsoid(0.04, 0.17, 0.04, 4, 3), Transform3D(Basis(), Vector3(0.085 * s, 0.17, z)), 3.0])
	parts.append([M.ellipsoid(0.025, 0.025, 0.17, 4, 2), Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(0, 0.55, -0.4)), 4.0])
	var m := M.merge(parts)
	_fig_cache[200] = m
	return m


# Merge parts, keeping the part ids already in a merged mesh's UV2 when the id given is < 0.
static func _merge_keep(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for p in parts:
		var mesh: ArrayMesh = p[0]
		var xf: Transform3D = p[1]
		var pid: float = p[2]
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var t: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var t2: Variant = arr[Mesh.ARRAY_TEX_UV2]
		var ix: Variant = arr[Mesh.ARRAY_INDEX]
		var base := verts.size()
		for i in v.size():
			verts.append(xf * v[i])
			norms.append((xf.basis * n[i]).normalized())
			uvs.append(t[i] if t != null and i < t.size() else Vector2.ZERO)
			if pid < 0.0 and t2 != null:
				uv2.append((t2 as PackedVector2Array)[i])
			else:
				uv2.append(Vector2(pid, 0.0))
		if ix != null and (ix as PackedInt32Array).size() > 0:
			for k in (ix as PackedInt32Array):
				idx.append(base + k)
		else:
			for i in v.size():
				idx.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
