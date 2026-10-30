## Urbs (D-289, U3; rebuilt in U8): the meshes and the one building material of the ordinary city
## of Rome (insula, domus, casa, taberna, workshop, horrea, horti, trees, street props, furniture,
## tombs, farm furniture).
##
## The forms are built in fill_houses.gd (houses) and fill_props.gd (small things) from the parts
## in fill_parts.gd; their sources are in those files' headers. Every mesh is built once, in metres,
## around a footprint centred on the origin with its FRONT facing +z and its feet at y = 0 (a
## masonry plinth UrbsFillParts.SKIRT deep hangs below). Instances scale x and z to the lot.
##
## Detail levels (urbs.gd: 0 best .. 2 coarsest; chunks.gd picks by distance):
##   0  everything: recessed windows with shutters or lattices, doors with leaves, shop counters,
##      awnings, railed balconies with laundry on lines, stairs, ridge tiles and antefixes
##   1  flat shutters and doors painted on the walls, ridges and eaves, no small parts
##   2  walls and roofs only
## `lod_key(key, lod)` folds the variants that look alike at a distance into one mesh, so a chunk
## needs fewer MultiMeshes (draw calls) at LOD 1 and 2.
##
## Material: ONE ShaderMaterial (`material()`), every colour read from UrbsMaterials.COLOURS (the
## city's one palette) as shader uniforms. The vertex colour's alpha says what a surface is
## (id = round(alpha * 20), the ids in fill_parts.gd); its rgb carries cloth, linen and leaf
## colours. The instance custom data carries the plaster colour (rgb, one of the stucco_* colours)
## and a per-building random number (a). Patterns are procedural: pan-and-cover tiles with real
## shading of the cover tiles, plaster patches, rain streaks, grime and a painted dado at the foot,
## peeling plaster over brick, plank shutters and studded doors, lattices, painted shop signs,
## striped awnings, opus incertum plinths.
class_name UrbsFillMeshes
extends RefCounted

const H := preload("res://scripts/urbs/fill_houses.gd")
const PR := preload("res://scripts/urbs/fill_props.gd")
const PA := preload("res://scripts/urbs/fill_parts.gd")

const EARTH := Color(1, 1, 1, 0.0)

## The UrbsMaterials names the shader reads (uniform c_<name>).
const SURFACES: Array[String] = [
	"earth_packed", "tegulae", "tegulae_old", "ridge_terracotta", "stucco_white", "stucco_cream",
	"stucco_ochre", "stucco_red", "stucco_worn", "brick_latericium", "opus_incertum", "tufa_grey",
	"tufa_yellow", "travertine", "timber_oak", "timber_weathered", "timber_painted", "shutter_wood",
	"door_bronze_studded", "bronze", "awning_canvas", "terracotta_pot", "fountain_water", "basalt",
]

static var _cache := {}
static var _material: ShaderMaterial
static var _farm_material: ShaderMaterial


# ---------------------------------------------------------------- public

## Mesh for `key` at detail `lod` (0 full, 1 simplified, 2 walls and roof). Keys:
##   insula:<shape gable|hip|stepped>:<storeys 2-5>:<feature 0-2>:<pitch 0|1>[:n  narrow, 7 m wide]
##   domus  casa:<tile|thatch|shingle>  taberna:<0-5>  workshop:<0 potter|1 carpenter|2 fullonica>
##   horrea  horti  tree:<cypress|pine|round|fruit>  prop:<cart|amph|sacks|crates>
##   furn:<fountain|well|shrine>  tomb:<altar|columbarium|round|tumulus|stele>  rural:<vines|beds|farm>
static func get_mesh(key: String, lod := 0) -> ArrayMesh:
	var l := clampi(lod, 0, 2)
	var full := "%s@%d" % [key, l]
	if _cache.has(full):
		return _cache[full]
	var mesh := build(key, l).to_mesh()
	_cache[full] = mesh
	return mesh


## The builder of `key` at `lod` (for counts and tests).
static func build(key: String, lod: int) -> PA.MB:
	var p := key.split(":")
	match p[0]:
		"insula":
			return H.insula(p[1], int(p[2]), int(p[3]), int(p[4]), lod, p.size() > 5 and p[5] == "n")
		"domus":
			return H.domus(lod)
		"casa":
			return H.casa(p[1], lod)
		"taberna":
			return H.taberna(int(p[1]), lod)
		"workshop":
			return H.workshop(int(p[1]), lod)
		"horrea":
			return H.horrea(lod)
		"horti":
			return H.horti(lod)
		"tree":
			return PR.tree(p[1])
		"prop":
			return PR.prop(p[1])
		"furn":
			return PR.furn(p[1])
		"tomb":
			return PR.tomb(p[1], lod)
		"rural":
			return PR.rural(p[1], lod)
	var mb := PA.MB.new()
	mb.box(Vector3(-1, 0, -1), Vector3(1, 2, 1), PA.PLASTER)
	return mb


## The mesh key that stands for `key` at `lod`: variants that differ only in small parts share one
## mesh far away (fewer MultiMeshes per chunk). Nominal sizes never change, so the lot's scale holds.
static func lod_key(key: String, lod: int) -> String:
	if lod == 0:
		return key
	var p := key.split(":")
	match p[0]:
		"insula":
			var narrow := p.size() > 5 and p[5] == "n"
			var shape := p[1]
			var pitch := p[4]
			if lod >= 2:
				shape = "hip" if shape == "hip" else "gable"
				pitch = "0"
			return "insula:%s:%s:0:%s%s" % [shape, p[2], pitch, ":n" if narrow else ""]
		"taberna":
			return "taberna:4" if p[1] == "4" else "taberna:0"
		"workshop":
			return key if lod == 1 else "workshop:0"
	return key


## Material of the farmland ground meshes (fill.gd rural_build): vertex alpha 1.0 = sown or
## ploughed strips (rows 1.1 m apart along the parcel's own axes, taken from UV in metres),
## 0.5 = meadow. Vertex colour is the tint.
static func farm_material() -> ShaderMaterial:
	if _farm_material == null:
		var sh := Shader.new()
		sh.code = FARM_SHADER
		_farm_material = ShaderMaterial.new()
		_farm_material.shader = sh
	return _farm_material


## The one material every building, prop and tree uses; its colours are UrbsMaterials.COLOURS.
static func material() -> ShaderMaterial:
	if _material == null:
		var sh := Shader.new()
		sh.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = sh
		for name in SURFACES:
			var c: Color = UrbsMaterials.COLOURS.get(name, Color(1, 0, 1))
			_material.set_shader_parameter("c_" + name, Color(c.r, c.g, c.b))
	return _material


## Plaster colours for the houses (instance custom rgb): the stucco_* surfaces of the shared
## palette, with lighter and darker washes of each so neighbouring houses differ.
static func plaster_palette() -> Array[Color]:
	var out: Array[Color] = []
	var names := ["stucco_white", "stucco_cream", "stucco_ochre", "stucco_worn", "stucco_cream", "stucco_white", "stucco_ochre", "stucco_white"]
	for nm in names:
		var c: Color = UrbsMaterials.COLOURS[nm]
		out.append(c)
		out.append(c.lerp(Color(0.95, 0.93, 0.88), 0.35) if nm != "stucco_white" else c.darkened(0.06))
	return out


# ---------------------------------------------------------------- shader

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 c_earth_packed : source_color;
uniform vec3 c_tegulae : source_color;
uniform vec3 c_tegulae_old : source_color;
uniform vec3 c_ridge_terracotta : source_color;
uniform vec3 c_stucco_white : source_color;
uniform vec3 c_stucco_cream : source_color;
uniform vec3 c_stucco_ochre : source_color;
uniform vec3 c_stucco_red : source_color;
uniform vec3 c_stucco_worn : source_color;
uniform vec3 c_brick_latericium : source_color;
uniform vec3 c_opus_incertum : source_color;
uniform vec3 c_tufa_grey : source_color;
uniform vec3 c_tufa_yellow : source_color;
uniform vec3 c_travertine : source_color;
uniform vec3 c_timber_oak : source_color;
uniform vec3 c_timber_weathered : source_color;
uniform vec3 c_timber_painted : source_color;
uniform vec3 c_shutter_wood : source_color;
uniform vec3 c_door_bronze_studded : source_color;
uniform vec3 c_bronze : source_color;
uniform vec3 c_awning_canvas : source_color;
uniform vec3 c_terracotta_pot : source_color;
uniform vec3 c_fountain_water : source_color;
uniform vec3 c_basalt : source_color;

varying vec4 vcol;
varying vec4 vcust;
varying vec3 lpos;
varying vec3 lnorm;
varying vec3 v_across;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.5 + vn(p * 2.03 + 7.1) * 0.3 + vn(p * 4.1 + 3.7) * 0.2; }
vec3 lin(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }

void vertex() {
	vcol = COLOR;
	vcust = INSTANCE_CUSTOM;
	lpos = VERTEX;
	lnorm = NORMAL;
	vec2 nh = NORMAL.xz;
	vec3 acr = length(nh) > 0.01 ? normalize(vec3(-nh.y, 0.0, nh.x)) : vec3(1.0, 0.0, 0.0);
	v_across = (MODELVIEW_MATRIX * vec4(acr, 0.0)).xyz;
}

// opus incertum / tufa blocks: rows 0.3 m high, blocks 0.4-0.7 m, each its own tone
vec3 masonry(vec2 uv, float seed, vec3 a, vec3 b, vec3 mortar_c) {
	float row = floor(uv.y * 3.3);
	float off = h21(vec2(row, seed)) * 3.0;
	float bx = uv.x * 1.9 + off;
	vec2 cell = vec2(floor(bx), row);
	vec2 f = vec2(fract(bx), fract(uv.y * 3.3));
	float mortar = step(f.y, 0.09) + step(f.x, 0.06);
	vec3 col = mix(a, b, h21(cell * 1.7 + 3.0)) * (0.8 + 0.35 * h21(cell + seed));
	return mix(col, mortar_c, clamp(mortar, 0.0, 1.0));
}

vec3 brick(vec2 uv, float seed, vec3 c, vec3 mortar_c) {
	float row = floor(uv.y * 22.0);
	float bx = uv.x * 2.4 + row * 0.5;
	vec2 f = vec2(fract(bx), fract(uv.y * 22.0));
	float mortar = step(f.y, 0.16) + step(f.x, 0.05);
	return mix(c * (0.78 + 0.4 * h21(vec2(floor(bx), row) + seed)), mortar_c, clamp(mortar, 0.0, 1.0));
}

// painted letters of a shop sign (dipinti): rows of strokes in red or black on white
float letters(vec2 uv, float seed) {
	float rowh = 0.24;
	float ry = fract(uv.y / rowh);
	float rown = floor(uv.y / rowh);
	if (ry < 0.18 || ry > 0.86) return 0.0;
	float cw = 0.15;
	float cx = uv.x / cw;
	float ci = floor(cx);
	float fx = fract(cx);
	float g = h21(vec2(ci, rown + seed));
	if (g < 0.16) return 0.0;  // a space between words
	float ly = (ry - 0.18) / 0.68;
	float s = 0.0;
	float w = 0.16;
	if (h21(vec2(ci, rown + 3.1)) < 0.75) s = max(s, step(abs(fx - 0.2), w * 0.6));
	if (h21(vec2(ci, rown + 5.7)) < 0.45) s = max(s, step(abs(fx - 0.7), w * 0.6));
	if (h21(vec2(ci, rown + 8.3)) < 0.5) s = max(s, step(abs(ly - 0.92), 0.1) * step(0.1, fx) * step(fx, 0.8));
	if (h21(vec2(ci, rown + 9.9)) < 0.35) s = max(s, step(abs(ly - 0.5), 0.09) * step(0.1, fx) * step(fx, 0.75));
	if (h21(vec2(ci, rown + 2.2)) < 0.35) s = max(s, step(abs(ly - 0.06), 0.1) * step(0.1, fx) * step(fx, 0.8));
	if (g > 0.85) s = max(s, step(abs(fx - ly * 0.6 - 0.15), w * 0.6));   // a diagonal stroke (V, A, M)
	return s * step(0.04, fx) * step(fx, 0.86);
}

void fragment() {
	float dist = length(VERTEX);
	float fade = clamp(1.0 - (dist - 10.0) / 70.0, 0.0, 1.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float seed = vcust.a * 91.0;
	vec3 an = abs(lnorm);
	bool flat_face = an.y > 0.6;
	float u = an.x > an.z ? lpos.z : lpos.x;
	vec2 uv = flat_face ? lpos.xz : vec2(u, lpos.y);
	int id = int(vcol.a * 20.0 + 0.5);
	vec3 tint = lin(vcust.rgb);
	vec3 vc = lin(vcol.rgb);
	vec3 col = vec3(0.5);
	float rough = 0.92;
	float metal = 0.0;
	float up = lpos.y;
	vec3 nrm = NORMAL;
	if (id == 10) {
		// plaster: the house's stucco colour, washes, rain streaks, grime, dado, peeling
		vec3 base = tint;
		base *= 0.84 + 0.26 * fbm(uv * 0.3 + seed);
		base *= mix(1.0, 0.94 + 0.12 * vn(uv * 5.0 + seed), fade);
		float streak = fbm(vec2(uv.x * 2.4 + seed, uv.y * 0.1));
		base *= mix(1.0, 0.8, smoothstep(0.58, 0.82, streak));
		// painted dado (socle) on about half the houses: red or ochre up to 1.1 m
		float dado = step(vcust.a, 0.55) * (1.0 - smoothstep(1.08, 1.12, up)) * step(0.0, up);
		vec3 dado_c = (vcust.a < 0.25 ? c_stucco_red : c_stucco_ochre) * (0.82 + 0.2 * fbm(uv * 1.3 + seed));
		base = mix(base, dado_c, dado);
		base *= mix(0.68, 1.0, smoothstep(-0.2, 2.2, up));
		float peel = fbm(uv * 0.9 + seed * 3.0);
		float peel_zone = smoothstep(0.62, 0.68, peel) * smoothstep(4.5, 0.8, up) * step(0.3, fract(vcust.a * 7.0));
		vec3 under = vcust.a > 0.6 ? brick(uv, seed, c_brick_latericium, c_stucco_worn) : masonry(uv, seed, c_opus_incertum, c_tufa_grey, c_stucco_worn);
		col = mix(base, mix(c_opus_incertum, under, fade), peel_zone * 0.9);
		rough = 0.95;
	} else if (id == 9) {
		// pan-and-cover tiles: cover tiles (imbrices) every 0.42 m across the slope, shaded as
		// half-rounds; courses of pan tiles (tegulae) with the shadow of the overlap
		vec2 nh = lnorm.xz;
		vec2 perp = length(nh) > 0.01 ? normalize(vec2(-nh.y, nh.x)) : vec2(1.0, 0.0);
		float across = dot(lpos.xz, perp) / 0.42 + seed * 0.13;
		float aa = clamp(1.0 - fwidth(across) * 1.6, 0.0, 1.0) * fade;
		float fp = fract(across);
		float cov = smoothstep(0.30, 0.37, fp) * (1.0 - smoothstep(0.63, 0.70, fp));
		float x = clamp((fp - 0.5) / 0.17, -1.0, 1.0);
		float course = lpos.y / 0.15;
		float row = fract(course + h21(vec2(floor(across), 1.0)) * 0.5);
		float tone = 0.86 + 0.28 * h21(vec2(floor(across), floor(course)));
		vec3 base = mix(c_tegulae, c_tegulae_old, clamp(vcust.a * 0.6 + 0.5 * fbm(lpos.xz * 0.25 + seed) - 0.2, 0.0, 1.0));
		col = base * mix(1.0, tone, aa);
		col *= mix(1.0, (0.74 + 0.26 * smoothstep(0.0, 0.3, row)) * (0.9 + 0.16 * cov), aa);
		float lich = smoothstep(0.66, 0.84, fbm(lpos.xz * 0.6 + seed));
		col = mix(col, lin(vec3(0.42, 0.42, 0.34)), lich * 0.35);
		nrm = normalize(NORMAL + normalize(v_across) * x * cov * 0.85 * aa);
		rough = 0.78;
	} else if (id == 11) {
		col = c_ridge_terracotta * (0.85 + 0.25 * vn(lpos.xz * 3.0 + lpos.y + seed));
		rough = 0.8;
	} else if (id == 12 || id == 20) {
		// shutters and doors: vertical planks, a batten, the doors with bronze studs
		float pw = id == 12 ? 0.13 : 0.2;
		float pl = fract(u / pw);
		float pi = floor(u / pw);
		vec3 wood = id == 12 ? (vcust.a < 0.35 ? c_timber_painted : (vcust.a < 0.7 ? c_shutter_wood : c_timber_weathered)) : mix(c_door_bronze_studded, c_timber_oak, 0.55);
		col = wood * (0.82 + 0.3 * h21(vec2(pi, seed)));
		col *= 0.9 + 0.2 * vn(vec2(u * 30.0, lpos.y * 1.2 + pi));
		col *= mix(1.0, 0.55, (step(pl, 0.07)) * fade);
		float bat = step(abs(fract(lpos.y / 0.9) - 0.5), 0.05);
		col *= mix(1.0, 0.8, bat * fade);
		if (id == 20) {
			vec2 sp = vec2(u / 0.3, lpos.y / 0.3);
			float stud = 1.0 - step(0.09, length(fract(sp) - 0.5));
			col = mix(col, c_bronze, stud * fade);
			metal = stud * 0.7 * fade;
		}
		rough = 0.85;
	} else if (id == 19) {
		// wooden lattice (transenna) over the dark room behind
		float d1 = abs(fract((u + lpos.y) * 3.6) - 0.5);
		float d2 = abs(fract((u - lpos.y) * 3.6) - 0.5);
		float bar = step(min(d1, d2), 0.11);
		vec3 dark = mix(tint, c_earth_packed, 0.5) * 0.1;
		col = mix(dark, c_timber_weathered * 0.9, mix(0.45, bar, fade));
	} else if (id == 5) {
		// the inside of a shop or a doorway in shade: dim, never black
		vec3 dark = mix(tint, c_earth_packed, 0.4);
		float shelf = step(0.82, fract(lpos.y * 1.6)) * step(0.9, up);
		col = dark * (0.13 + 0.06 * vn(uv * 2.0 + seed)) + c_timber_oak * shelf * 0.1 * fade;
		rough = 1.0;
	} else if (id == 13) {
		// painted sign: white ground, red or black letters
		vec3 ink = vcust.a < 0.6 ? c_stucco_red : c_basalt * 0.5;
		float l = letters(vec2(u + seed * 0.37, up), seed) * fade;
		col = mix(c_stucco_white * (0.9 + 0.1 * fbm(uv * 2.0)), ink, l * 0.9);
	} else if (id == 7) {
		float g = vn(vec2(uv.x * 24.0 + uv.y * 3.0, uv.y * 1.5 + seed));
		col = mix(c_timber_weathered, c_timber_oak, step(0.5, vcust.a)) * (0.72 + 0.4 * g);
		rough = 0.85;
	} else if (id == 4) {
		// awning: stripes of the cloth colour on canvas
		float s = lpos.x + lpos.z;
		float stripe = step(0.5, fract(s * 1.25 + seed));
		col = mix(vc, c_awning_canvas, stripe * 0.85 * step(0.5, fract(seed * 3.3)));
		col *= 0.88 + 0.16 * vn(uv * 9.0);
		rough = 1.0;
	} else if (id == 18) {
		col = vc * (0.9 + 0.12 * vn(uv * 6.0 + seed));
		rough = 1.0;
	} else if (id == 3) {
		col = c_travertine * (0.84 + 0.22 * fbm(uv * 3.0 + seed));
		rough = 0.8;
	} else if (id == 2) {
		col = mix(c_opus_incertum, masonry(uv, seed + 11.0, c_tufa_grey, c_tufa_yellow, c_stucco_worn), fade) * 0.92;
	} else if (id == 17) {
		col = mix(c_brick_latericium, brick(uv, seed, c_brick_latericium, c_stucco_worn), fade);
	} else if (id == 8) {
		col = c_terracotta_pot * (0.82 + 0.3 * vn(uv * 12.0 + seed));
	} else if (id == 6) {
		col = c_fountain_water * 0.7;
		rough = 0.08;
	} else if (id == 14) {
		// thatch: straw streaks down the slope
		col = mix(c_awning_canvas, c_timber_weathered, 0.45) * (0.7 + 0.45 * vn(vec2(u * 9.0, lpos.y * 0.8) + seed));
		rough = 1.0;
	} else if (id == 15) {
		// shingles: small courses of grey wood
		float sr = floor(lpos.y / 0.12);
		float sc = fract(u / 0.25 + h21(vec2(sr, 2.0)) * 0.5);
		col = c_timber_weathered * (0.72 + 0.3 * h21(vec2(floor(u / 0.25 + h21(vec2(sr, 2.0)) * 0.5), sr)));
		col *= mix(1.0, 0.7, step(sc, 0.06) * fade);
	} else if (id == 16) {
		col = c_bronze;
		metal = 0.8;
		rough = 0.45;
	} else if (id == 1) {
		col = vc * (0.7 + 0.6 * fbm(wp.xz * 0.8 + lpos.y));
		rough = 0.95;
	} else {
		// packed earth between the houses: dust, pebbles, trodden darker lanes
		float n = fbm(wp.xz * 0.45);
		col = c_earth_packed * mix(0.62, 0.86, n);
		col *= 0.9 + 0.2 * vn(wp.xz * 5.0);
		col *= 0.92 + 0.16 * smoothstep(0.4, 0.9, vn(wp.xz * 1.7));
		rough = 1.0;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	NORMAL = nrm;
}
"""


const FARM_SHADER := """
shader_type spatial;
render_mode cull_disabled;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.5 + vn(p * 2.03 + 7.1) * 0.3 + vn(p * 4.1 + 3.7) * 0.2; }

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	if (COLOR.a > 0.75) {
		float rows = 0.5 + 0.5 * sin(UV.x * 5.7);
		float n = fbm(UV * 0.11 + floor(col.r * 97.0));
		col = col * (0.50 + 0.34 * rows) * (0.62 + 0.38 * n);
	} else {
		float n = fbm(wp.xz * 0.28);
		col = col * (0.42 + 0.5 * n);
		col = mix(col, vec3(0.40, 0.36, 0.2), smoothstep(0.62, 0.85, fbm(wp.xz * 0.11 + 4.0)) * 0.55);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
"""
