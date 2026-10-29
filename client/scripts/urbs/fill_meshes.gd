## Urbs (D-289, step U3): procedural meshes and the building shader for the ordinary city of Rome
## (insula, domus, casa, taberna, workshop, horti, trees, street props and furniture).
##
## Every mesh is built once, in metres, around a footprint centred on the origin with its FRONT
## facing +z and its feet at y = 0 (a 4 m foundation skirt hangs below, so buildings sit on sloping
## ground). Instances scale x and z to the lot size; y is never scaled.
##
## Material: ONE ShaderMaterial (`material()`), everything procedural (no files). The vertex
## colour's alpha says what a surface is (id = round(alpha * 10): 0 earth, 1 grass, 2 masonry
## foundation, 3 stone, 4 cloth, 5 dark opening, 6 water, 7 wood, 8 terracotta, 9 roof tile, 10
## plaster); the instance's custom data carries the plaster tint (rgb) and a per-building random
## number (a). The shader gives plaster colour patches, weathering streaks, grime toward the ground,
## peeling plaster over brick and tufa at the foot of walls, tile courses with moss, wood grain,
## striped cloth awnings.
##
## Sources for the forms (all in the file headers of data/rome/city/regions.yaml `districts` too):
##   Vitruvius 2.8.17 (LacusCurtius, read): the crowd obliged Romans to gain in height what the plan
##     could not hold, by piers of stone, burnt brick or rubble walls tied with timber floors, so
##     that they were lodged in many storeys -> insulae of 3-5 storeys with timber galleries.
##   Vitruvius 6.3 (read): the atrium house; entrance passage, atrium with the opening in the roof
##     over the basin, alae, tablinum, peristyle.
##   Strabo 5.3.7 (read): Augustus forbade frontages above 70 feet; Livy 21.62.3 (read): an ox
##     climbed to the third storey of a house in the Forum Boarium in 218 BC.
##   Livy 5.55.2-5 (read): hasty irregular rebuilding after the Gauls.
##   Pliny NH 16.36: shingle roofs until the war with Pyrrhus (# unverified).
##   Shops (tabernae) with a masonry counter holding dolia and a wooden shutter closing the
##     opening, awnings, laundry lines and street shrines at crossroads (the compita; Dion. Hal.
##     4.14.3 on the Servian vicus shrines, # unverified) follow Pompeii's streets as the
##     closest surviving evidence of a Roman street at eye height.
class_name UrbsFillMeshes
extends RefCounted

const SKIRT := 4.0
const PLASTER := Color(1, 1, 1, 1.0)
const FOUND := Color(0.62, 0.56, 0.46, 0.2)
const STONE := Color(0.80, 0.77, 0.70, 0.3)
const DARK := Color(0.10, 0.07, 0.05, 0.5)
const WOOD := Color(0.40, 0.28, 0.18, 0.7)
const TERRA := Color(0.74, 0.44, 0.27, 0.8)
const TILE := Color(0.74, 0.33, 0.20, 0.9)
const THATCH := Color(0.74, 0.60, 0.34, 0.9)
const SHINGLE := Color(0.52, 0.38, 0.26, 0.9)
const GRASS := Color(0.38, 0.5, 0.25, 0.1)
const WATER := Color(0.30, 0.42, 0.50, 0.6)
const EARTH := Color(0.5, 0.4, 0.3, 0.0)
const CLOTHS: Array[Color] = [
	Color(0.80, 0.22, 0.16, 0.4), Color(0.86, 0.66, 0.20, 0.4), Color(0.30, 0.42, 0.62, 0.4),
	Color(0.88, 0.84, 0.74, 0.4), Color(0.30, 0.50, 0.36, 0.4), Color(0.62, 0.30, 0.52, 0.4),
]

static var _cache := {}
static var _material: ShaderMaterial


# ---------------------------------------------------------------- public

## Mesh for `key` at detail `lod` (0 full, 1 no small parts, 2 boxes and roofs). Keys:
##   insula:<shape gable|hip|stepped>:<storeys 2-5>:<feature 0-2>:<pitch 0|1>[:n  narrow, 7 m wide]
##   domus  casa:<tile|thatch|shingle>  taberna:<0-5>  workshop:<0|1>  horti  tree:<cypress|pine|round>
##   prop:<cart|amph|sacks|crates>  furn:<fountain|well|shrine>
static func get_mesh(key: String, lod := 0) -> ArrayMesh:
	var full := "%s@%d" % [key, clampi(lod, 0, 2)]
	if _cache.has(full):
		return _cache[full]
	var p := key.split(":")
	var mb: MB
	match p[0]:
		"insula":
			mb = _insula(p[1], int(p[2]), int(p[3]), int(p[4]), lod, p.size() > 5 and p[5] == "n")
		"domus":
			mb = _domus(lod)
		"casa":
			mb = _casa(p[1], lod)
		"taberna":
			mb = _taberna(int(p[1]), lod)
		"workshop":
			mb = _workshop(int(p[1]), lod)
		"horti":
			mb = _horti(lod)
		"tree":
			mb = _tree(p[1])
		"prop":
			mb = _prop(p[1])
		"furn":
			mb = _furn(p[1])
		_:
			mb = MB.new()
			mb.box(Vector3(-1, 0, -1), Vector3(1, 2, 1), PLASTER)
	var mesh := mb.to_mesh()
	_cache[full] = mesh
	return mesh


## The one material every building, prop and tree uses.
static func material() -> ShaderMaterial:
	if _material == null:
		var sh := Shader.new()
		sh.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = sh
	return _material


# ---------------------------------------------------------------- shader

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

varying vec4 vcol;
varying vec4 vcust;
varying vec3 lpos;
varying vec3 lnorm;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.5 + vn(p * 2.03 + 7.1) * 0.3 + vn(p * 4.1 + 3.7) * 0.2; }

void vertex() {
	vcol = COLOR;
	vcust = INSTANCE_CUSTOM;
	lpos = VERTEX;
	lnorm = NORMAL;
}

vec3 masonry(vec2 uv, float seed) {
	// opus incertum / tufa blocks: rows 0.28 m high, blocks 0.5-0.8 m wide, each its own tone
	float row = floor(uv.y * 3.6);
	float off = h21(vec2(row, seed)) * 3.0;
	float bx = uv.x * 1.6 + off;
	vec2 cell = vec2(floor(bx), row);
	vec2 f = vec2(fract(bx), fract(uv.y * 3.6));
	float mortar = step(f.y, 0.08) + step(f.x, 0.05);
	float tone = 0.7 + 0.5 * h21(cell + seed);
	vec3 col = mix(vec3(0.50, 0.44, 0.35), vec3(0.58, 0.50, 0.38), h21(cell * 1.7 + 3.0)) * tone;
	return mix(col, vec3(0.70, 0.66, 0.58), clamp(mortar, 0.0, 1.0));
}

vec3 brick(vec2 uv, float seed) {
	float row = floor(uv.y * 14.0);
	float bx = uv.x * 3.4 + row * 0.5;
	vec2 f = vec2(fract(bx), fract(uv.y * 14.0));
	float mortar = step(f.y, 0.14) + step(f.x, 0.07);
	vec3 col = vec3(0.58, 0.27, 0.17) * (0.75 + 0.5 * h21(vec2(floor(bx), row) + seed));
	return mix(col, vec3(0.72, 0.68, 0.58), clamp(mortar, 0.0, 1.0));
}

void fragment() {
	float dist = length(VERTEX);
	float fade = clamp(1.0 - (dist - 6.0) / 22.0, 0.0, 1.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float seed = vcust.a * 91.0;
	vec3 an = abs(lnorm);
	vec2 uv = (an.y > 0.6 ? lpos.xz : (an.x > an.z ? lpos.zy : lpos.xy)) + vec2(seed * 0.37, seed * 0.11);
	int id = int(vcol.a * 10.0 + 0.5);
	vec3 col = vcol.rgb;
	float rough = 0.92;
	float up = clamp(lpos.y, 0.0, 30.0);
	if (id == 10) {
		// plaster: tint, large patches, grain, stains, grime, peeling over brick, masonry foot
		vec3 base = vcol.rgb * vcust.rgb * 0.95;
		float patch = fbm(uv * 0.33 + seed);
		base *= 0.78 + 0.42 * patch;
		base *= 0.94 + 0.12 * vn(uv * 7.0 + seed);
		float streak = fbm(vec2(uv.x * 2.6 + seed, wp.y * 0.14));
		base *= mix(1.0, 0.70, smoothstep(0.56, 0.82, streak) * 0.9);
		base *= mix(0.72, 1.0, smoothstep(0.0, 3.5, up));
		float peel = fbm(uv * 1.15 + seed * 3.0);
		float peel_zone = smoothstep(0.60, 0.68, peel) * smoothstep(5.5, 0.6, up);
		float foot = smoothstep(1.35 + 0.5 * vn(uv * 1.4 + seed), 0.9, up);
		vec3 br = mix(vec3(0.52, 0.30, 0.22), brick(uv, seed), fade);
		vec3 ms = mix(vec3(0.55, 0.49, 0.40), masonry(uv, seed), fade);
		col = mix(base, br, peel_zone * 0.9);
		col = mix(col, ms, foot);
	} else if (id == 9) {
		// roof tile: courses with a ridge-parallel rib, per-roof tone, moss
		float course = abs(lpos.z) * 0.9 + lpos.y * 2.2;
		float rows = fract(course * 2.4);
		float ribs = abs(fract(lpos.x * 2.7) - 0.5);
		float tone = 0.72 + 0.5 * vcust.a + 0.2 * h21(floor(vec2(lpos.x * 2.7, course * 2.4)));
		col = vcol.rgb * tone * mix(0.95, (0.82 + 0.3 * smoothstep(0.0, 0.5, ribs)) * (0.78 + 0.28 * rows), fade);
		float moss = smoothstep(0.62, 0.8, fbm(uv * 0.9 + seed));
		col = mix(col, vec3(0.30, 0.34, 0.20), moss * 0.45);
		rough = 0.8;
	} else if (id == 7) {
		float g = vn(vec2(uv.x * 28.0 + uv.y * 3.0, uv.y * 1.5 + seed));
		col = vcol.rgb * (0.7 + 0.55 * g);
	} else if (id == 5) {
		col = vcol.rgb * (0.7 + 0.9 * vn(uv * 3.0));
	} else if (id == 4) {
		float stripe = step(0.5, fract(lpos.x * 1.3 + seed));
		col = mix(vcol.rgb, vec3(0.90, 0.86, 0.78), stripe * 0.85);
		col *= 0.85 + 0.2 * vn(uv * 9.0);
		rough = 1.0;
	} else if (id == 3) {
		col = vcol.rgb * (0.86 + 0.24 * fbm(uv * 4.0 + seed));
	} else if (id == 2) {
		col = mix(vec3(0.55, 0.49, 0.40), masonry(uv, seed + 11.0), fade);
	} else if (id == 8) {
		col = vcol.rgb * (0.82 + 0.32 * vn(uv * 12.0 + seed));
		rough = 0.9;
	} else if (id == 1) {
		col = vcol.rgb * (0.7 + 0.6 * fbm(wp.xz * 0.8));
	} else if (id == 6) {
		col = vcol.rgb;
		rough = 0.08;
	} else {
		// packed earth between the houses: dust, pebbles, trodden darker lanes
		float n = fbm(wp.xz * 0.45);
		col = mix(vec3(0.27, 0.21, 0.15), vec3(0.37, 0.30, 0.22), n);
		col *= 0.88 + 0.24 * vn(wp.xz * 5.0);
		col *= 0.9 + 0.2 * smoothstep(0.4, 0.9, vn(wp.xz * 1.7));
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
"""


# ---------------------------------------------------------------- mesh builder

class MB:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()

	func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, hint := Vector3.ZERO) -> void:
		var nrm := (b - a).cross(d - a)
		if nrm.length_squared() < 1e-10:
			return
		nrm = nrm.normalized()
		if hint != Vector3.ZERO and nrm.dot(hint) < 0.0:
			var t := b
			b = d
			d = t
			nrm = -nrm
		v.append(a); v.append(b); v.append(d)
		n.append(nrm); n.append(nrm); n.append(nrm)
		c.append(col); c.append(col); c.append(col)

	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color, hint := Vector3.ZERO) -> void:
		tri(a, b, d, col, hint)
		tri(a, d, e, col, hint)

	func box(lo: Vector3, hi: Vector3, col: Color, top := true) -> void:
		quad(Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), col)
		quad(Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), col)
		quad(Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), col)
		quad(Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z), col)
		if top:
			quad(Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), col)

	## Rectangle on a wall of a W x D block: face 0 front(+z) 1 back(-z) 2 right(+x) 3 left(-x).
	func rect_on(face: int, h0: float, h1: float, y0: float, y1: float, w: float, d: float, off: float, col: Color) -> void:
		match face:
			0:
				var z := d * 0.5 + off
				quad(Vector3(h0, y0, z), Vector3(h1, y0, z), Vector3(h1, y1, z), Vector3(h0, y1, z), col)
			1:
				var z := -d * 0.5 - off
				quad(Vector3(h1, y0, z), Vector3(h0, y0, z), Vector3(h0, y1, z), Vector3(h1, y1, z), col)
			2:
				var x := w * 0.5 + off
				quad(Vector3(x, y0, h1), Vector3(x, y0, h0), Vector3(x, y1, h0), Vector3(x, y1, h1), col)
			_:
				var x := -w * 0.5 - off
				quad(Vector3(x, y0, h0), Vector3(x, y0, h1), Vector3(x, y1, h1), Vector3(x, y1, h0), col)

	## A box standing on a wall face: (h, y) centre along the wall and height, size (wide, tall,
	## proud), `off` standoff from the wall.
	func on_wall(face: int, h: float, y0: float, wide: float, tall: float, proud: float, w: float, d: float, off: float, col: Color) -> void:
		match face:
			0:
				var z := d * 0.5 + off
				box(Vector3(h - wide * 0.5, y0, z), Vector3(h + wide * 0.5, y0 + tall, z + proud), col)
			1:
				var z := -d * 0.5 - off
				box(Vector3(h - wide * 0.5, y0, z - proud), Vector3(h + wide * 0.5, y0 + tall, z), col)
			2:
				var x := w * 0.5 + off
				box(Vector3(x, y0, h - wide * 0.5), Vector3(x + proud, y0 + tall, h + wide * 0.5), col)
			_:
				var x := -w * 0.5 - off
				box(Vector3(x - proud, y0, h - wide * 0.5), Vector3(x, y0 + tall, h + wide * 0.5), col)

	func gable(x0: float, x1: float, z0: float, z1: float, base: float, rh: float, roof: Color, wall_col: Color) -> void:
		var zm := (z0 + z1) * 0.5
		var top := base + rh
		quad(Vector3(x0, base, z1), Vector3(x1, base, z1), Vector3(x1, top, zm), Vector3(x0, top, zm), roof, Vector3(0, 1, 0.3))
		quad(Vector3(x1, base, z0), Vector3(x0, base, z0), Vector3(x0, top, zm), Vector3(x1, top, zm), roof, Vector3(0, 1, -0.3))
		tri(Vector3(x1, base, z1), Vector3(x1, base, z0), Vector3(x1, top, zm), wall_col, Vector3(1, 0, 0))
		tri(Vector3(x0, base, z0), Vector3(x0, base, z1), Vector3(x0, top, zm), wall_col, Vector3(-1, 0, 0))

	func hip(x0: float, x1: float, z0: float, z1: float, base: float, rh: float, roof: Color) -> void:
		var zm := (z0 + z1) * 0.5
		var inset := minf((x1 - x0), (z1 - z0)) * 0.3
		var rx0 := x0 + inset
		var rx1 := x1 - inset
		var top := base + rh
		quad(Vector3(x0, base, z1), Vector3(x1, base, z1), Vector3(rx1, top, zm), Vector3(rx0, top, zm), roof, Vector3(0, 1, 0.3))
		quad(Vector3(x1, base, z0), Vector3(x0, base, z0), Vector3(rx0, top, zm), Vector3(rx1, top, zm), roof, Vector3(0, 1, -0.3))
		tri(Vector3(x1, base, z1), Vector3(x1, base, z0), Vector3(rx1, top, zm), roof, Vector3(1, 1, 0))
		tri(Vector3(x0, base, z0), Vector3(x0, base, z1), Vector3(rx0, top, zm), roof, Vector3(-1, 1, 0))

	func shed(x0: float, x1: float, z_hi: float, z_lo: float, y_hi: float, y_lo: float, roof: Color) -> void:
		quad(Vector3(x0, y_hi, z_hi), Vector3(x1, y_hi, z_hi), Vector3(x1, y_lo, z_lo), Vector3(x0, y_lo, z_lo), roof, Vector3(0, 1, 0))

	func cone(cx: float, cz: float, y0: float, y1: float, r0: float, r1: float, sides: int, col: Color) -> void:
		for s in sides:
			var a0 := TAU * float(s) / sides
			var a1 := TAU * float(s + 1) / sides
			var p0 := Vector3(cx + cos(a0) * r0, y0, cz + sin(a0) * r0)
			var p1 := Vector3(cx + cos(a1) * r0, y0, cz + sin(a1) * r0)
			var q0 := Vector3(cx + cos(a0) * r1, y1, cz + sin(a0) * r1)
			var q1 := Vector3(cx + cos(a1) * r1, y1, cz + sin(a1) * r1)
			var out := Vector3(cos((a0 + a1) * 0.5), 0.2, sin((a0 + a1) * 0.5))
			quad(p0, p1, q1, q0, col, out)
		if r1 > 0.05:
			var top := Vector3(cx, y1, cz)
			for s in sides:
				var a0 := TAU * float(s) / sides
				var a1 := TAU * float(s + 1) / sides
				tri(top, Vector3(cx + cos(a0) * r1, y1, cz + sin(a0) * r1), Vector3(cx + cos(a1) * r1, y1, cz + sin(a1) * r1), col, Vector3(0, 1, 0))

	func to_mesh() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


# ---------------------------------------------------------------- shared pieces

static func _walls(b: MB, w: float, d: float, h: float, col := PLASTER) -> void:
	for face in 4:
		var span := (w if face < 2 else d) * 0.5
		b.rect_on(face, -span, span, -SKIRT, 0.0, w, d, 0.0, FOUND)
		b.rect_on(face, -span, span, 0.0, h, w, d, 0.0, col)


static func _append(dst: MB, src: MB, offset: Vector3) -> void:
	for i in src.v.size():
		dst.v.append(src.v[i] + offset)
	dst.n.append_array(src.n)
	dst.c.append_array(src.c)


static func _fr(i: int, k: int) -> float:
	return float(((i * 7919 + k * 104729) ^ (i * 31 + k)) & 1023) / 1024.0


## Amphora standing at (x, y, z): foot, belly, neck, mouth ring.
static func _amphora(b: MB, x: float, y: float, z: float, s := 1.0, col := TERRA) -> void:
	b.cone(x, z, y, y + 0.26 * s, 0.05 * s, 0.19 * s, 6, col)
	b.cone(x, z, y + 0.26 * s, y + 0.58 * s, 0.19 * s, 0.11 * s, 6, col)
	b.cone(x, z, y + 0.58 * s, y + 0.84 * s, 0.11 * s, 0.065 * s, 6, col)


## Window centred at h on `face`; dl 0 full (sill box, shutters), 1 flat sill, 2 just the opening.
static func _window(b: MB, face: int, h: float, y0: float, wid: float, tall: float, w: float, d: float, dl: int, k: int) -> void:
	b.rect_on(face, h - wid * 0.5, h + wid * 0.5, y0, y0 + tall, w, d, 0.03, DARK)
	if dl == 0:
		b.on_wall(face, h, y0 - 0.12, wid + 0.3, 0.12, 0.16, w, d, 0.0, STONE)
		var r := _fr(k, 3)
		if r < 0.55:
			b.rect_on(face, h - wid * 0.5 - 0.5, h - wid * 0.5 - 0.02, y0, y0 + tall, w, d, 0.07, WOOD)
			b.rect_on(face, h + wid * 0.5 + 0.02, h + wid * 0.5 + 0.5, y0, y0 + tall, w, d, 0.07, WOOD)
		elif r < 0.7:
			b.rect_on(face, h - wid * 0.5, h + wid * 0.5, y0, y0 + tall * 0.55, w, d, 0.07, WOOD)
	elif dl == 1:
		b.rect_on(face, h - wid * 0.5 - 0.1, h + wid * 0.5 + 0.1, y0 - 0.1, y0, w, d, 0.06, STONE)


## Shop opening with step, lintel, pilasters, masonry counter holding dolia and amphorae.
static func _shop_opening(b: MB, face: int, h: float, wid: float, w: float, d: float, dl: int, k: int, awning := -1) -> void:
	b.rect_on(face, h - wid * 0.5, h + wid * 0.5, 0.0, 2.45, w, d, 0.03, DARK)
	b.on_wall(face, h, 2.45, wid + 0.5, 0.32, 0.12, w, d, 0.0, WOOD)
	if dl == 2:
		return
	b.on_wall(face, h, 0.0, wid + 0.7, 0.22, 0.45, w, d, 0.0, STONE)
	b.rect_on(face, h - wid * 0.5 - 0.3, h - wid * 0.5, 0.0, 2.45, w, d, 0.08, STONE)
	b.rect_on(face, h + wid * 0.5, h + wid * 0.5 + 0.3, 0.0, 2.45, w, d, 0.08, STONE)
	if dl == 0:
		var r := _fr(k, 5)
		if r < 0.5:
			# masonry counter with two dolia sunk in it, amphorae on top and beside
			b.on_wall(face, h, 0.0, wid - 0.6, 1.0, 0.6, w, d, 0.1, STONE)
			var fz := d * 0.5 + 0.1 if face == 0 else -d * 0.5 - 0.1
			if face == 0:
				for dx in [-0.45, 0.45]:
					b.cone(h + dx, fz + 0.3, 1.0, 1.02, 0.28, 0.26, 6, DARK)
				_amphora(b, h - 0.2, 1.0, fz + 0.3, 0.8)
				_amphora(b, h + 0.3, 1.0, fz + 0.3, 0.7)
				_amphora(b, h + wid * 0.5 + 0.5, 0.0, fz + 0.5, 1.0)
		elif r < 0.8:
			# shuttered boards leaning open
			b.on_wall(face, h - wid * 0.25, 0.1, wid * 0.4, 2.2, 0.06, w, d, 0.05, WOOD)
	if awning >= 0 and face == 0:
		var col: Color = CLOTHS[awning % CLOTHS.size()]
		b.shed(h - wid * 0.5 - 0.3, h + wid * 0.5 + 0.3, d * 0.5 + 0.05, d * 0.5 + 1.7, 3.25, 2.55, col)
		for sx in [-1.0, 1.0]:
			b.box(Vector3(h + sx * (wid * 0.5 + 0.2) - 0.04, 0.0, d * 0.5 + 1.6), Vector3(h + sx * (wid * 0.5 + 0.2) + 0.04, 2.6, d * 0.5 + 1.68), WOOD, false)


# ---------------------------------------------------------------- insula

## Tenement block, nominal 18 x 18 m. shape gable|hip|stepped; feature 0 shutters and balconies,
## 1 laundry lines, 2 shop awnings and a jettied upper storey; pitch 0 low, 1 steep.
static func _insula(shape: String, storeys: int, feature: int, pitch: int, lod: int, narrow := false) -> MB:
	var w := 7.0 if narrow else 18.0
	var d := 18.0
	var gf := 3.7
	var sh := 3.1
	var h := gf + sh * float(storeys - 1)
	var b := MB.new()
	var md := d
	var mz := 0.0
	if shape == "stepped":
		var annex_h := maxf(gf, h - sh)
		var an := MB.new()
		_walls(an, w, 6.0, annex_h)
		an.shed(-w * 0.5 - 0.3, w * 0.5 + 0.3, 3.0, -3.4, annex_h + 1.0, annex_h, TILE)
		_append(b, an, Vector3(0, 0, -d * 0.5 + 3.0))
		md = d - 6.0
		mz = 3.0
	var m := MB.new()
	_walls(m, w, md, h)
	# ground floor: four shop openings on the front, a door and a light at the back
	var cols4 := [-1.75, 1.75] if narrow else [-6.75, -2.25, 2.25, 6.75]
	for i in cols4.size():
		_shop_opening(m, 0, cols4[i], 2.5 if not narrow else 2.9, w, md, lod, i + feature * 5, i if feature == 2 else -1)
	m.rect_on(1, -1.0, 1.0, 0.0, 2.4, w, md, 0.03, DARK)
	if lod == 0 and not narrow:
		m.rect_on(1, -5.5, -4.3, 1.4, 2.5, w, md, 0.03, DARK)
		m.rect_on(1, 4.3, 5.5, 1.4, 2.5, w, md, 0.03, DARK)
	for s in range(1, storeys):
		var y0 := gf + sh * float(s - 1)
		# a string course between floors
		if lod < 2:
			m.on_wall(0, 0.0, y0 - 0.1, w, 0.16, 0.08, w, md, 0.0, STONE)
		var nwin := 2 if narrow else 5
		for i in nwin:
			var hh := (-1.75 + 3.5 * float(i)) if narrow else (-7.2 + 3.6 * float(i))
			if lod < 2:
				_window(m, 0, hh, y0 + 0.9, 1.15, 1.5, w, md, lod, s * 11 + i)
				_window(m, 1, hh, y0 + 0.9, 1.15, 1.5, w, md, mini(lod + 1, 2), s * 13 + i)
			else:
				m.rect_on(0, hh - 0.55, hh + 0.55, y0 + 0.9, y0 + 2.3, w, md, 0.03, DARK)
		if lod < 2:
			for i in 3:
				var zz := -md * 0.5 + md * (float(i) + 0.5) / 3.0
				m.rect_on(2, zz - 0.55, zz + 0.55, y0 + 0.9, y0 + 2.3, w, md, 0.03, DARK)
				if not narrow:
					m.rect_on(3, zz - 0.55, zz + 0.55, y0 + 0.9, y0 + 2.3, w, md, 0.03, DARK)
		# timber gallery (maenianum) with a railing, on the street face
		if lod == 0 and s >= 2 and (feature != 1 or s % 2 == 0):
			var full := feature == 2
			var xs: Array = [-7.0, 0.0, 7.0] if full else [-4.2 if s % 2 == 0 else 3.6]
			var hw := 2.2 if full else 1.9
			if narrow:
				xs = [0.0]
				hw = 2.8
			for bx: float in xs:
				var zb := md * 0.5
				m.box(Vector3(bx - hw, y0 + 0.05, zb), Vector3(bx + hw, y0 + 0.2, zb + 1.15), WOOD)
				m.box(Vector3(bx - hw, y0 + 1.0, zb + 1.08), Vector3(bx + hw, y0 + 1.1, zb + 1.15), WOOD, false)
				var n_post := int(hw)
				for q in range(n_post + 1):
					var px := bx - hw + 0.1 + (2.0 * hw - 0.2) * float(q) / float(maxi(n_post, 1))
					m.box(Vector3(px - 0.04, y0 + 0.2, zb + 1.08), Vector3(px + 0.04, y0 + 1.0, zb + 1.14), WOOD, false)
				# brackets under the floor
				m.box(Vector3(bx - hw, y0 - 0.1, zb), Vector3(bx - hw + 0.1, y0 + 0.05, zb + 0.9), WOOD, false)
				m.box(Vector3(bx + hw - 0.1, y0 - 0.1, zb), Vector3(bx + hw, y0 + 0.05, zb + 0.9), WOOD, false)
		# laundry lines on a pole across the side face
		if lod == 0 and feature == 1 and s >= 2:
			var yp := y0 + 1.9
			m.box(Vector3(w * 0.5, yp, -md * 0.5 + 1.5), Vector3(w * 0.5 + 2.4, yp + 0.05, md * 0.5 - 1.5), WOOD, false)
			for q in 4:
				var zq := -md * 0.5 + 3.0 + float(q) * 3.4
				var cl: Color = CLOTHS[(q + s) % CLOTHS.size()]
				m.quad(Vector3(w * 0.5 + 0.5, yp, zq), Vector3(w * 0.5 + 0.5, yp, zq + 1.1), Vector3(w * 0.5 + 0.5, yp - 1.1, zq + 1.1), Vector3(w * 0.5 + 0.5, yp - 1.1, zq), cl)
	# upper storey projecting on brackets (feature 2)
	if feature == 2 and lod < 2:
		var top_y := gf + sh * float(storeys - 2)
		m.box(Vector3(-w * 0.5 - 0.1, top_y + 0.2, md * 0.5), Vector3(w * 0.5 + 0.1, top_y + sh, md * 0.5 + 0.6), PLASTER, false)
	_append(b, m, Vector3(0, 0, mz))
	var rh := 1.9 if pitch == 0 else 3.3
	var ov := 0.5 if pitch == 0 else 0.9
	var roof := MB.new()
	if shape == "hip":
		roof.hip(-w * 0.5 - ov, w * 0.5 + ov, -md * 0.5 - ov, md * 0.5 + ov + (0.6 if feature == 2 else 0.0), h, rh + 0.4, TILE)
	else:
		roof.gable(-w * 0.5 - ov, w * 0.5 + ov, -md * 0.5 - ov, md * 0.5 + ov + (0.6 if feature == 2 else 0.0), h, rh, TILE, PLASTER)
		if lod < 2:
			roof.box(Vector3(-w * 0.5 - ov, h + rh - 0.08, -0.2), Vector3(w * 0.5 + ov, h + rh + 0.18, 0.2), TILE)
	_append(b, roof, Vector3(0, 0, mz))
	return b


# ---------------------------------------------------------------- casa

static func _casa(roof_kind: String, lod: int) -> MB:
	var w := 8.0
	var d := 9.0
	var h := 2.9
	var col := TILE
	if roof_kind == "thatch":
		col = THATCH
	elif roof_kind == "shingle":
		col = SHINGLE
	var b := MB.new()
	_walls(b, w, d, h)
	b.rect_on(0, -0.5, 0.5, 0.0, 2.1, w, d, 0.03, DARK)
	if lod < 2:
		b.on_wall(0, 0.0, 0.0, 1.5, 0.18, 0.4, w, d, 0.0, STONE)
		b.rect_on(0, 1.6, 2.7, 1.2, 2.0, w, d, 0.03, DARK)
		b.rect_on(2, -1.0, 0.0, 1.2, 2.0, w, d, 0.03, DARK)
	if lod == 0:
		b.on_wall(0, 2.15, 1.2, 1.2, 0.8, 0.05, w, d, 0.0, WOOD)
		# a jar by the door and a bundle of firewood against the wall
		_amphora(b, -1.6, 0.0, d * 0.5 + 0.4, 0.9)
		b.box(Vector3(-w * 0.5 - 0.5, 0.0, -2.0), Vector3(-w * 0.5, 0.8, 0.5), WOOD)
	b.gable(-w * 0.5 - 0.5, w * 0.5 + 0.5, -d * 0.5 - 0.5, d * 0.5 + 0.7, h, 2.1, col, PLASTER)
	return b


# ---------------------------------------------------------------- taberna

## Shop-front unit, nominal 4.6 x 5.2 m. 0-3: one storey with awnings of different cloth,
## 4: two storeys with a gallery, 5: open front with a long counter and goods.
static func _taberna(variant: int, lod: int) -> MB:
	var w := 4.6
	var d := 5.2
	var h := 3.5 if variant != 4 else 6.4
	var b := MB.new()
	_walls(b, w, d, h)
	_shop_opening(b, 0, 0.0, 3.2, w, d, lod, variant * 3 + 1, variant if variant < 4 else -1)
	if variant == 4 and lod < 2:
		_window(b, 0, 0.0, 4.4, 1.2, 1.4, w, d, lod, 77)
		if lod == 0:
			b.box(Vector3(-1.9, 3.7, d * 0.5), Vector3(1.9, 3.85, d * 0.5 + 1.0), WOOD)
			b.box(Vector3(-1.9, 4.5, d * 0.5 + 0.93), Vector3(1.9, 4.6, d * 0.5 + 1.0), WOOD, false)
	if variant == 5 and lod == 0:
		b.box(Vector3(-w * 0.5 + 0.5, 0.0, d * 0.5 - 0.2), Vector3(w * 0.5 - 0.5, 1.05, d * 0.5 + 0.55), STONE)
		for i in 5:
			_amphora(b, -1.6 + 0.8 * float(i), 1.05, d * 0.5 + 0.2, 0.75)
		for i in 3:
			_amphora(b, w * 0.5 + 0.35, 0.0, d * 0.5 - 0.6 - 0.6 * float(i), 1.0)
	b.shed(-w * 0.5 - 0.2, w * 0.5 + 0.2, d * 0.5 + 0.4, -d * 0.5 - 0.3, h + 1.0, h, TILE)
	b.tri(Vector3(w * 0.5, h, d * 0.5), Vector3(w * 0.5, h, -d * 0.5), Vector3(w * 0.5, h + 1.0, d * 0.5), PLASTER, Vector3(1, 0, 0))
	b.tri(Vector3(-w * 0.5, h, -d * 0.5), Vector3(-w * 0.5, h, d * 0.5), Vector3(-w * 0.5, h + 1.0, d * 0.5), PLASTER, Vector3(-1, 0, 0))
	return b


# ---------------------------------------------------------------- workshop

static func _workshop(variant: int, lod: int) -> MB:
	var w := 16.0
	var d := 14.0
	var h := 5.0
	var b := MB.new()
	var hd := 9.0
	var hz := -d * 0.5 + hd * 0.5
	var hall := MB.new()
	_walls(hall, w, hd, h)
	hall.rect_on(0, -4.8, -1.4, 0.0, 3.4, w, hd, 0.03, DARK)
	hall.rect_on(0, 1.4, 4.8, 0.0, 3.4, w, hd, 0.03, DARK)
	if lod < 2:
		for i in 2:
			var hh := -3.1 + 6.2 * float(i)
			hall.on_wall(0, hh, 3.4, 3.7, 0.3, 0.12, w, hd, 0.0, WOOD)
			hall.on_wall(0, hh, 0.0, 3.9, 0.2, 0.4, w, hd, 0.0, STONE)
		for i in 2:
			hall.rect_on(2, -2.0 + 4.0 * float(i) - 0.45, -2.0 + 4.0 * float(i) + 0.45, 2.8, 4.0, w, hd, 0.03, DARK)
	hall.gable(-w * 0.5 - 0.6, w * 0.5 + 0.6, -hd * 0.5 - 0.6, hd * 0.5 + 0.6, h, 2.6 + float(variant) * 0.5, TILE, PLASTER)
	_append(b, hall, Vector3(0, 0, hz))
	var yz0 := -d * 0.5 + hd
	b.box(Vector3(-w * 0.5, 0.0, d * 0.5 - 0.4), Vector3(w * 0.5, 1.8, d * 0.5), PLASTER)
	b.box(Vector3(-w * 0.5, 0.0, yz0), Vector3(-w * 0.5 + 0.4, 1.8, d * 0.5), PLASTER)
	b.box(Vector3(w * 0.5 - 0.4, 0.0, yz0), Vector3(w * 0.5, 1.8, d * 0.5), PLASTER)
	b.rect_on(0, -1.5, 1.5, 0.0, 1.8, w, d, 0.0, DARK)
	if lod < 2:
		b.box(Vector3(-1.7, 1.8, d * 0.5 - 0.5), Vector3(1.7, 2.0, d * 0.5 + 0.1), WOOD)
	if variant == 0:
		for i in 4:
			for j in 2:
				_amphora(b, -6.2 + 0.85 * float(i), 0.0, yz0 + 1.2 + 0.85 * float(j), 1.3 if lod < 2 else 1.0)
				if lod == 0 and j == 0:
					_amphora(b, -5.8 + 0.85 * float(i), 0.0, yz0 + 1.6, 1.3)
	else:
		b.box(Vector3(3.0, 0.0, yz0 + 0.8), Vector3(6.4, 1.6, yz0 + 2.0), WOOD)
		b.box(Vector3(3.4, 1.6, yz0 + 1.0), Vector3(6.0, 2.2, yz0 + 1.8), WOOD)
		if lod < 2:
			b.cone(-4.5, yz0 + 1.6, 0.0, 1.1, 0.9, 0.7, 7, TERRA)   # a big dolium
	return b


# ---------------------------------------------------------------- domus

static func _domus(lod: int) -> MB:
	var w := 20.0
	var d := 34.0
	var h0 := 4.9
	var b := MB.new()
	_walls(b, w, d, h0)
	b.rect_on(0, -1.5, 1.5, 0.0, 3.3, w, d, 0.02, STONE)
	b.rect_on(0, -0.9, 0.9, 0.0, 2.8, w, d, 0.04, DARK)
	if lod < 2:
		b.on_wall(0, 0.0, 0.0, 3.2, 0.2, 0.5, w, d, 0.0, STONE)
		b.on_wall(0, 0.0, 3.3, 3.4, 0.28, 0.18, w, d, 0.0, STONE)
		for sx in [-6.4, 6.4]:
			b.rect_on(0, sx - 0.5, sx + 0.5, 3.4, 4.2, w, d, 0.03, DARK)
		# two shops flanking the doorway, as in many Pompeian atrium houses
		if lod == 0:
			for sx in [-5.0, 5.0]:
				b.rect_on(0, sx - 1.3, sx + 1.3, 0.0, 2.5, w, d, 0.04, DARK)
				b.on_wall(0, sx, 0.0, 2.9, 1.0, 0.5, w, d, 0.0, STONE)
	var hx := w * 0.5
	var hz := d * 0.5
	var oz0 := 4.0
	var ix0 := -3.2
	var ix1 := 3.2
	var iz0 := 7.6
	var iz1 := 13.4
	var ho := h0
	var hi := h0 - 0.9
	var up := Vector3(0, 1, 0)
	b.quad(Vector3(-hx, ho, hz), Vector3(hx, ho, hz), Vector3(ix1, hi, iz1), Vector3(ix0, hi, iz1), TILE, up)
	b.quad(Vector3(hx, ho, oz0), Vector3(-hx, ho, oz0), Vector3(ix0, hi, iz0), Vector3(ix1, hi, iz0), TILE, up)
	b.quad(Vector3(-hx, ho, oz0), Vector3(-hx, ho, hz), Vector3(ix0, hi, iz1), Vector3(ix0, hi, iz0), TILE, up)
	b.quad(Vector3(hx, ho, hz), Vector3(hx, ho, oz0), Vector3(ix1, hi, iz0), Vector3(ix1, hi, iz1), TILE, up)
	b.quad(Vector3(ix0, 1.0, iz1), Vector3(ix1, 1.0, iz1), Vector3(ix1, 1.0, iz0), Vector3(ix0, 1.0, iz0), STONE, up)
	b.quad(Vector3(ix0 + 0.8, 0.5, iz1 - 0.8), Vector3(ix1 - 0.8, 0.5, iz1 - 0.8), Vector3(ix1 - 0.8, 0.5, iz0 + 0.8), Vector3(ix0 + 0.8, 0.5, iz0 + 0.8), WATER, up)
	b.gable(-hx, hx, -1.0, oz0, h0, 1.4, TILE, PLASTER)
	var gx0 := -6.8
	var gx1 := 6.8
	var gz0 := -13.8
	var gz1 := -4.2
	var hl := 3.6
	b.quad(Vector3(-hx, h0, -1.0), Vector3(hx, h0, -1.0), Vector3(gx1, hl, gz1), Vector3(gx0, hl, gz1), TILE, up)
	b.quad(Vector3(hx, h0, -hz), Vector3(-hx, h0, -hz), Vector3(gx0, hl, gz0), Vector3(gx1, hl, gz0), TILE, up)
	b.quad(Vector3(-hx, h0, -hz), Vector3(-hx, h0, -1.0), Vector3(gx0, hl, gz1), Vector3(gx0, hl, gz0), TILE, up)
	b.quad(Vector3(hx, h0, -1.0), Vector3(hx, h0, -hz), Vector3(gx1, hl, gz0), Vector3(gx1, hl, gz1), TILE, up)
	b.quad(Vector3(gx0, 0.3, gz1), Vector3(gx1, 0.3, gz1), Vector3(gx1, 0.3, gz0), Vector3(gx0, 0.3, gz0), GRASS, up)
	b.quad(Vector3(-1.8, 0.4, -6.2), Vector3(1.8, 0.4, -6.2), Vector3(1.8, 0.4, -11.8), Vector3(-1.8, 0.4, -11.8), WATER, up)
	if lod < 2:
		for s in [Vector2(-5.0, -5.4), Vector2(5.0, -5.4), Vector2(-5.0, -12.6), Vector2(5.0, -12.6), Vector2(-5.4, -9.0), Vector2(5.4, -9.0)]:
			b.box(Vector3(s.x - 0.7, 0.3, s.y - 0.7), Vector3(s.x + 0.7, 1.3, s.y + 0.7), GRASS)
		var nx := 6
		for i in nx:
			var x := gx0 + (gx1 - gx0) * float(i) / float(nx - 1)
			b.box(Vector3(x - 0.2, 0.0, gz1 - 0.2), Vector3(x + 0.2, hl, gz1 + 0.2), STONE, false)
			b.box(Vector3(x - 0.2, 0.0, gz0 - 0.2), Vector3(x + 0.2, hl, gz0 + 0.2), STONE, false)
		for j in range(1, 4):
			var z := gz0 + (gz1 - gz0) * float(j) / 4.0
			b.box(Vector3(gx0 - 0.2, 0.0, z - 0.2), Vector3(gx0 + 0.2, hl, z + 0.2), STONE, false)
			b.box(Vector3(gx1 - 0.2, 0.0, z - 0.2), Vector3(gx1 + 0.2, hl, z + 0.2), STONE, false)
	return b


# ---------------------------------------------------------------- horti

static func _horti(lod: int) -> MB:
	var w := 70.0
	var d := 70.0
	var b := MB.new()
	var up := Vector3(0, 1, 0)
	b.quad(Vector3(-w * 0.5, 0.15, d * 0.5), Vector3(w * 0.5, 0.15, d * 0.5), Vector3(w * 0.5, 0.15, -d * 0.5), Vector3(-w * 0.5, 0.15, -d * 0.5), GRASS, up)
	var t := 0.5
	var wh := 2.6
	b.box(Vector3(-w * 0.5, -SKIRT, -d * 0.5), Vector3(w * 0.5, wh, -d * 0.5 + t), PLASTER)
	b.box(Vector3(-w * 0.5, -SKIRT, -d * 0.5), Vector3(-w * 0.5 + t, wh, d * 0.5), PLASTER)
	b.box(Vector3(w * 0.5 - t, -SKIRT, -d * 0.5), Vector3(w * 0.5, wh, d * 0.5), PLASTER)
	b.box(Vector3(-w * 0.5, -SKIRT, d * 0.5 - t), Vector3(-2.5, wh, d * 0.5), PLASTER)
	b.box(Vector3(2.5, -SKIRT, d * 0.5 - t), Vector3(w * 0.5, wh, d * 0.5), PLASTER)
	b.rect_on(0, -2.5, 2.5, 0.0, 2.2, w, d, 0.02, DARK)
	b.quad(Vector3(-1.6, 0.25, d * 0.5), Vector3(1.6, 0.25, d * 0.5), Vector3(1.6, 0.25, 4.0), Vector3(-1.6, 0.25, 4.0), EARTH, up)
	var vz := -2.0
	var villa := MB.new()
	_walls(villa, 26.0, 13.0, 7.0)
	for i in 6:
		var hh := -10.8 + 4.3 * float(i)
		villa.rect_on(0, hh - 0.7, hh + 0.7, 1.2, 3.4, 26.0, 13.0, 0.03, DARK)
		villa.rect_on(0, hh - 0.55, hh + 0.55, 4.2, 5.6, 26.0, 13.0, 0.03, DARK)
	villa.hip(-13.6, 13.6, -7.0, 7.0, 7.0, 3.6, TILE)
	_append(b, villa, Vector3(0, 0, vz))
	for sx in [-22.0, 22.0]:
		var pav := MB.new()
		_walls(pav, 8.0, 8.0, 4.6)
		pav.hip(-4.6, 4.6, -4.6, 4.6, 4.6, 2.6, TILE)
		_append(b, pav, Vector3(sx, 0, 8.0))
	if lod < 2:
		for i in 9:
			var x := -12.0 + float(i) * 3.0
			b.box(Vector3(x - 0.25, 0.0, vz + 7.6), Vector3(x + 0.25, 3.6, vz + 8.1), STONE, false)
		b.shed(-12.5, 12.5, vz + 7.0, vz + 8.4, 3.9, 3.6, TILE)
		b.quad(Vector3(-8.0, 0.3, 22.0), Vector3(8.0, 0.3, 22.0), Vector3(8.0, 0.3, 14.0), Vector3(-8.0, 0.3, 14.0), WATER, up)
	return b


# ---------------------------------------------------------------- trees

static func _tree(kind: String) -> MB:
	var b := MB.new()
	var trunk := Color(0.42, 0.30, 0.20, 0.7)
	match kind:
		"cypress":
			b.cone(0, 0, 0.0, 0.6, 0.18, 0.18, 5, trunk)
			b.cone(0, 0, 0.4, 3.2, 1.0, 0.75, 7, Color(0.16, 0.30, 0.15, 0.1))
			b.cone(0, 0, 3.2, 7.4, 0.75, 0.05, 7, Color(0.18, 0.33, 0.16, 0.1))
		"pine":
			b.cone(0, 0, 0.0, 4.5, 0.3, 0.22, 5, trunk)
			b.cone(0, 0, 4.2, 5.8, 1.0, 3.6, 8, Color(0.20, 0.34, 0.17, 0.1))
			b.cone(0, 0, 5.8, 6.8, 3.6, 3.0, 8, Color(0.24, 0.38, 0.19, 0.1))
			b.cone(0, 0, 6.8, 7.4, 3.0, 0.3, 8, Color(0.22, 0.36, 0.18, 0.1))
		_:
			b.cone(0, 0, 0.0, 2.0, 0.25, 0.2, 5, trunk)
			b.cone(0, 0, 1.6, 3.3, 0.6, 2.2, 8, Color(0.32, 0.47, 0.20, 0.1))
			b.cone(0, 0, 3.3, 4.6, 2.2, 0.4, 8, Color(0.36, 0.50, 0.22, 0.1))
	return b


# ---------------------------------------------------------------- street props and furniture

## Small things at the foot of a wall, nominal 1 x 1 m footprint: cart, stacked amphorae, sacks, crates.
static func _prop(kind: String) -> MB:
	var b := MB.new()
	match kind:
		"cart":
			b.box(Vector3(-0.55, 0.55, -1.0), Vector3(0.55, 0.7, 0.8), WOOD)
			for sx in [-0.6, 0.6]:
				b.box(Vector3(sx - 0.03, 0.1, -0.35), Vector3(sx + 0.03, 1.0, 0.25), WOOD, false)
				b.box(Vector3(sx - 0.03, 0.4, -0.65), Vector3(sx + 0.03, 0.7, -0.05), WOOD, false)
			b.box(Vector3(-0.5, 0.7, -1.0), Vector3(-0.44, 1.1, 0.8), WOOD, false)
			b.box(Vector3(0.44, 0.7, -1.0), Vector3(0.5, 1.1, 0.8), WOOD, false)
			b.box(Vector3(-0.05, 0.5, 0.8), Vector3(0.05, 0.55, 2.2), WOOD)
			for i in 3:
				_amphora(b, -0.25 + 0.25 * float(i), 0.7, -0.4, 0.9)
		"amph":
			for i in 4:
				for j in 2:
					_amphora(b, -0.45 + 0.3 * float(i), 0.0, -0.2 + 0.4 * float(j), 1.0)
			for i in 3:
				b.cone(-0.3 + 0.3 * float(i), 0.0, 0.8, 1.5, 0.19, 0.07, 6, TERRA)
		"sacks":
			for i in 3:
				b.cone(-0.5 + 0.5 * float(i), 0.0, 0.0, 0.42, 0.26, 0.3, 8, Color(0.62, 0.52, 0.36, 0.8))
				b.cone(-0.5 + 0.5 * float(i), 0.0, 0.42, 0.56, 0.3, 0.1, 8, Color(0.62, 0.52, 0.36, 0.8))
			b.cone(-0.2, 0.0, 0.56, 0.98, 0.25, 0.28, 8, Color(0.58, 0.48, 0.34, 0.8))
			b.cone(-0.2, 0.0, 0.98, 1.12, 0.28, 0.08, 8, Color(0.58, 0.48, 0.34, 0.8))
		_:
			b.box(Vector3(-0.5, 0.0, -0.4), Vector3(0.5, 0.45, 0.4), WOOD)
			b.box(Vector3(-0.4, 0.45, -0.3), Vector3(0.3, 0.9, 0.35), WOOD)
	return b


## Street furniture: a fountain of the aqueduct age (basin, pillar, spout), a well-head (ring, two
## uprights and a beam), a compitum shrine (small aedicula on a plinth with an altar).
static func _furn(kind: String) -> MB:
	var b := MB.new()
	match kind:
		"fountain":
			b.box(Vector3(-0.9, 0.0, -0.4), Vector3(0.9, 0.9, 0.4), STONE)
			b.box(Vector3(-0.7, 0.88, -0.25), Vector3(0.7, 0.9, 0.25), WATER, false)
			b.box(Vector3(-0.3, 0.9, -0.4), Vector3(0.3, 1.9, -0.1), STONE)
			b.box(Vector3(-0.08, 1.2, -0.1), Vector3(0.08, 1.3, 0.1), STONE)
			b.box(Vector3(-1.0, 1.9, -0.5), Vector3(1.0, 2.05, 0.3), STONE)
		"well":
			b.cone(0, 0, 0.0, 0.9, 0.7, 0.62, 8, STONE)
			b.quad(Vector3(-0.4, 0.88, 0.4), Vector3(0.4, 0.88, 0.4), Vector3(0.4, 0.88, -0.4), Vector3(-0.4, 0.88, -0.4), DARK, Vector3(0, 1, 0))
			for sx in [-0.7, 0.7]:
				b.box(Vector3(sx - 0.06, 0.8, -0.06), Vector3(sx + 0.06, 2.0, 0.06), WOOD, false)
			b.box(Vector3(-0.8, 1.9, -0.05), Vector3(0.8, 2.0, 0.05), WOOD)
		_:
			b.box(Vector3(-1.1, 0.0, -1.0), Vector3(1.1, 0.5, 1.0), STONE)
			for sx in [-0.7, 0.7]:
				b.box(Vector3(sx - 0.12, 0.5, -0.5), Vector3(sx + 0.12, 2.3, -0.2), STONE, false)
			b.shed(-1.0, 1.0, -0.2, -0.7, 2.6, 2.3, TILE)
			b.box(Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 1.6, -0.2), DARK)   # the niche of the Lares
			b.box(Vector3(-0.3, 0.5, 0.2), Vector3(0.3, 1.05, 0.6), STONE)  # altar
	return b
