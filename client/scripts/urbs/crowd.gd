## A crowd for the spectacles (U6): thousands of simple figures on seats or along a street,
## drawn with ONE MultiMesh and animated entirely in a vertex shader, so it costs nothing on the
## CPU. Each figure sways, and when the crowd "roars" the figures hop and throw their arms up;
## a travelling wave of that movement follows `wave_pos` round the ring of seats (the race sends
## the leader's position round the circus).
##
## Usage:
##   var c = preload("res://scripts/urbs/crowd.gd").new()
##   c.add_seats(UrbsCrowdSeats...)   # or the static makers below, then
##   c.build(); parent.add_child(c)
##   c.set_state(clock_seconds, roar 0..1, wave_pos 0..1)
## Seats are described by position, facing yaw and u (0..1 position round the ring, for the wave).
## Makers: stadium_seats() for a circus, ellipse_seats() for an arena, line_seats() for a street.
extends Node3D

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float clock = 0.0;
uniform float roar = 0.2;       // 0 sits quietly, 1 on their feet cheering
uniform float wave_pos = 0.0;   // 0..1 round the ring
uniform float wave_amt = 0.8;
uniform vec3 skin = vec3(0.86, 0.66, 0.52);
varying vec3 tint;
varying float part;
void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float u = INSTANCE_CUSTOM.y;
	float d = abs(fract(u - wave_pos + 0.5) - 0.5);
	float w = exp(-pow(d * 12.0, 2.0)) * wave_amt;
	float lift = clamp(roar * (0.45 + 0.55 * sin(clock * 7.0 + phase * 6.283)) + w, 0.0, 1.0);
	part = UV.x;
	tint = COLOR.rgb;
	vec3 v = VERTEX;
	if (UV.x > 1.5) {
		vec3 p = v - vec3(sign(v.x) * 0.2, 0.82, 0.0);
		float a = lift * lift * 2.9 * sign(v.x);
		float ca = cos(a); float sa = sin(a);
		p = vec3(p.x * ca - p.y * sa, p.x * sa + p.y * ca, p.z);
		v = p + vec3(sign(v.x) * 0.2, 0.82, 0.0);
	}
	v.y += lift * 0.18 * abs(sin(clock * 9.0 + phase * 6.283)) + 0.02 * sin(clock * 1.7 + phase * 20.0);
	VERTEX = v;
}
void fragment() {
	vec3 c = (part > 0.5 && part < 1.5) ? tint : skin;
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

var _seats: Array[Dictionary] = []   # {pos, yaw, u}
var _mm: MultiMeshInstance3D
var _mat: ShaderMaterial
var palette: Array[Color] = [
	Color(0.92, 0.9, 0.84), Color(0.85, 0.8, 0.68), Color(0.7, 0.45, 0.3), Color(0.55, 0.62, 0.7),
	Color(0.62, 0.5, 0.38), Color(0.78, 0.7, 0.5), Color(0.4, 0.5, 0.35), Color(0.72, 0.3, 0.25),
]
var seed_value := 7
## The share of the crowd that wears `fan_colours` (faction colours at the races).
var fan_colours: Array[Color] = []
var fan_share := 0.0


func add_seat(pos: Vector3, yaw: float, u: float) -> void:
	_seats.append({"pos": pos, "yaw": yaw, "u": u})


func add_seats(list: Array) -> void:
	for s in list:
		_seats.append(s)


func count() -> int:
	return _seats.size()


## Build the MultiMesh from the seats added so far.
func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _figure_mesh()
	mm.instance_count = _seats.size()
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for i in _seats.size():
		var s: Dictionary = _seats[i]
		var p: Vector3 = s["pos"]
		var sc := rng.randf_range(0.9, 1.08)
		var b := Basis(Vector3.UP, float(s["yaw"]) + rng.randf_range(-0.25, 0.25)).scaled(Vector3.ONE * sc)
		mm.set_instance_transform(i, Transform3D(b, p))
		var col: Color = palette[rng.randi() % palette.size()]
		if fan_colours.size() > 0 and rng.randf() < fan_share:
			col = fan_colours[rng.randi() % fan_colours.size()]
		mm.set_instance_color(i, col.lerp(Color(0.5, 0.5, 0.5), rng.randf() * 0.15))
		mm.set_instance_custom_data(i, Color(rng.randf(), float(s["u"]), 0, 0))
		lo = lo.min(p)
		hi = hi.max(p)
	if _seats.size() > 0:
		mm.custom_aabb = AABB(lo - Vector3(2, 2, 2), hi - lo + Vector3(4, 6, 4))
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mm.material_override = _mat
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mm)


## Drive the animation. `clock` seconds (use the spectacle's own time so seeking works).
func set_state(clock: float, roar: float, wave_pos: float, wave_amt := 0.8) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("clock", clock)
	_mat.set_shader_parameter("roar", clampf(roar, 0.0, 1.0))
	_mat.set_shader_parameter("wave_pos", wave_pos)
	_mat.set_shader_parameter("wave_amt", wave_amt)


# A standing/sitting spectator: torso (cloth), head, two arms (UV.x = 0 skin, 1 cloth, 2 arm).
static func _figure_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, Vector3(0, 0.62, 0), Vector3(0.40, 0.56, 0.24), 1.0)
	_add_box(st, Vector3(0, 0.28, 0), Vector3(0.36, 0.30, 0.30), 1.0)
	_add_box(st, Vector3(0, 1.02, 0), Vector3(0.2, 0.22, 0.2), 0.0)
	_add_box(st, Vector3(0.25, 0.63, 0), Vector3(0.09, 0.40, 0.1), 2.0)
	_add_box(st, Vector3(-0.25, 0.63, 0), Vector3(0.09, 0.40, 0.1), 2.0)
	st.generate_normals()
	return st.commit()


static func _add_box(st: SurfaceTool, c: Vector3, size: Vector3, part: float) -> void:
	var h := size / 2.0
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var corners: Array[Vector3] = []
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				corners.append(c + (n + a * sa + b * sb) * h)
		# corners order: (-,-),(-,+),(+,-),(+,+)
		var order := [0, 1, 3, 0, 3, 2]
		var flip: bool = (n.cross(a)).dot(b) < 0.0
		if flip:
			order = [0, 3, 1, 0, 2, 3]
		for idx in order:
			st.set_uv(Vector2(part, 0))
			st.add_vertex(corners[idx])


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
			out.append({"pos": Vector3(p.x, y, p.z), "yaw": atan2(inward.x, inward.z), "u": d / total})
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
			out.append({"pos": p, "yaw": atan2(-p.x, -p.z), "u": float(i) / n})
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
				out.append({"pos": q, "yaw": atan2(-s * side.x, -s * side.z), "u": d / total})
	return out
