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
	# a few houses washed in Pompeian red (softened: a whole red facade is rare in the evidence)
	out.append((UrbsMaterials.COLOURS["stucco_red"] as Color).lerp(UrbsMaterials.COLOURS["stucco_ochre"], 0.35))
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

// the words of the shop signs; letter codes A=0 B=1 C=2 E=3 F=4 G=5 I=6 L=7 M=8 N=9 O=10 P=11 Q=12 R=13 S=14 T=15 V=16 X=17 .=18 D=19, space 31
// words: VINVM, VINA, CAVPONA, OLEVM, TABERNA, PANIS, FIGVLVS, MEL, FABER, FVLLO, M.TVLLI, C.VALERI, L.CORNELI, P.CLAVDI, Q.FABI, T.MANLI, CN.OCTAVI, SEX.IVLI
// trades: 0 counter with dolia (wine, oil, an inn), 1 table of goods, 2 workbench; names in the
// genitive (the owner's), common Republican praenomina and nomina, no particular person meant
const int W_CH[180] = {16, 6, 9, 16, 8, 31, 31, 31, 31, 31, 16, 6, 9, 0, 31, 31, 31, 31, 31, 31, 2, 0, 16, 11, 10, 9, 0, 31, 31, 31, 10, 7, 3, 16, 8, 31, 31, 31, 31, 31, 15, 0, 1, 3, 13, 9, 0, 31, 31, 31, 11, 0, 9, 6, 14, 31, 31, 31, 31, 31, 4, 6, 5, 16, 7, 16, 14, 31, 31, 31, 8, 3, 7, 31, 31, 31, 31, 31, 31, 31, 4, 0, 1, 3, 13, 31, 31, 31, 31, 31, 4, 16, 7, 7, 10, 31, 31, 31, 31, 31, 8, 18, 15, 16, 7, 7, 6, 31, 31, 31, 2, 18, 16, 0, 7, 3, 13, 6, 31, 31, 7, 18, 2, 10, 13, 9, 3, 7, 6, 31, 11, 18, 2, 7, 0, 16, 19, 6, 31, 31, 12, 18, 4, 0, 1, 6, 31, 31, 31, 31, 15, 18, 8, 0, 9, 7, 6, 31, 31, 31, 2, 9, 18, 10, 2, 15, 0, 16, 6, 31, 14, 3, 17, 18, 6, 16, 7, 6, 31, 31};
const int W_LEN[18] = {5, 4, 7, 5, 7, 5, 7, 3, 5, 5, 7, 8, 9, 8, 6, 7, 9, 8};
const int W_TRADE[18] = {0, 1, 2, 3, 4, 1, 3, 5, 4, 1, 6, 7, 8, 9, 5, 6, 4, 8};
const int W_NAME[8] = {10, 11, 12, 13, 14, 15, 16, 17};
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a; vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return 1.0 - step(w, length(pa - ba * h));
}

// one capital in the box q (0..1 left to right, 0..1 up); strokes about 0.09 thick
float glyph(int k, vec2 q) {
	float w = 0.12;
	vec2 bl = vec2(0.2, 0.0); vec2 tl = vec2(0.2, 1.0); vec2 br = vec2(0.75, 0.0); vec2 tr = vec2(0.75, 1.0);
	vec2 ml = vec2(0.2, 0.5);
	float s = 0.0;
	if (k == 0) {        // A
		s = max(max(seg(q, vec2(0.12, 0.0), vec2(0.47, 1.0), w), seg(q, vec2(0.47, 1.0), vec2(0.82, 0.0), w)), seg(q, vec2(0.27, 0.38), vec2(0.67, 0.38), w));
	} else if (k == 1) { // B
		s = max(seg(q, bl, tl, w), seg(q, tl, vec2(0.58, 1.0), w));
		s = max(s, max(seg(q, vec2(0.58, 1.0), vec2(0.7, 0.78), w), seg(q, vec2(0.7, 0.78), vec2(0.58, 0.52), w)));
		s = max(s, max(seg(q, ml, vec2(0.62, 0.52), w), seg(q, vec2(0.62, 0.52), vec2(0.78, 0.27), w)));
		s = max(s, max(seg(q, vec2(0.78, 0.27), vec2(0.62, 0.0), w), seg(q, vec2(0.62, 0.0), bl, w)));
	} else if (k == 2 || k == 5) { // C, G
		s = max(seg(q, vec2(0.75, 0.85), vec2(0.5, 1.0), w), seg(q, vec2(0.5, 1.0), vec2(0.27, 0.92), w));
		s = max(s, max(seg(q, vec2(0.27, 0.92), vec2(0.18, 0.7), w), seg(q, vec2(0.18, 0.7), vec2(0.18, 0.3), w)));
		s = max(s, max(seg(q, vec2(0.18, 0.3), vec2(0.27, 0.08), w), seg(q, vec2(0.27, 0.08), vec2(0.5, 0.0), w)));
		s = max(s, seg(q, vec2(0.5, 0.0), vec2(0.75, 0.15), w));
		if (k == 5) s = max(s, max(seg(q, vec2(0.75, 0.15), vec2(0.75, 0.42), w), seg(q, vec2(0.75, 0.42), vec2(0.5, 0.42), w)));
	} else if (k == 3) { // E
		s = max(max(seg(q, bl, tl, w), seg(q, tl, tr, w)), max(seg(q, ml, vec2(0.65, 0.5), w), seg(q, bl, br, w)));
	} else if (k == 4) { // F
		s = max(max(seg(q, bl, tl, w), seg(q, tl, tr, w)), seg(q, ml, vec2(0.65, 0.5), w));
	} else if (k == 6) { // I
		s = seg(q, vec2(0.47, 0.0), vec2(0.47, 1.0), w);
	} else if (k == 7) { // L
		s = max(seg(q, bl, tl, w), seg(q, bl, br, w));
	} else if (k == 8) { // M
		s = max(seg(q, vec2(0.12, 0.0), vec2(0.12, 1.0), w), seg(q, vec2(0.82, 0.0), vec2(0.82, 1.0), w));
		s = max(s, max(seg(q, vec2(0.12, 1.0), vec2(0.47, 0.35), w), seg(q, vec2(0.47, 0.35), vec2(0.82, 1.0), w)));
	} else if (k == 9) { // N
		s = max(max(seg(q, bl, tl, w), seg(q, br, tr, w)), seg(q, tl, br, w));
	} else if (k == 10 || k == 12) { // O, Q
		s = max(seg(q, vec2(0.47, 1.0), vec2(0.76, 0.82), w), seg(q, vec2(0.76, 0.82), vec2(0.76, 0.18), w));
		s = max(s, max(seg(q, vec2(0.76, 0.18), vec2(0.47, 0.0), w), seg(q, vec2(0.47, 0.0), vec2(0.18, 0.18), w)));
		s = max(s, max(seg(q, vec2(0.18, 0.18), vec2(0.18, 0.82), w), seg(q, vec2(0.18, 0.82), vec2(0.47, 1.0), w)));
		if (k == 12) s = max(s, seg(q, vec2(0.5, 0.2), vec2(0.88, -0.1), w));
	} else if (k == 11 || k == 13) { // P, R
		s = max(seg(q, bl, tl, w), seg(q, tl, vec2(0.6, 1.0), w));
		s = max(s, max(seg(q, vec2(0.6, 1.0), vec2(0.75, 0.76), w), seg(q, vec2(0.75, 0.76), vec2(0.6, 0.5), w)));
		s = max(s, seg(q, vec2(0.6, 0.5), ml, w));
		if (k == 13) s = max(s, seg(q, vec2(0.45, 0.5), vec2(0.8, 0.0), w));
	} else if (k == 14) { // S
		s = max(seg(q, vec2(0.75, 0.88), vec2(0.55, 1.0), w), seg(q, vec2(0.55, 1.0), vec2(0.32, 1.0), w));
		s = max(s, max(seg(q, vec2(0.32, 1.0), vec2(0.18, 0.84), w), seg(q, vec2(0.18, 0.84), vec2(0.26, 0.6), w)));
		s = max(s, max(seg(q, vec2(0.26, 0.6), vec2(0.68, 0.42), w), seg(q, vec2(0.68, 0.42), vec2(0.77, 0.17), w)));
		s = max(s, max(seg(q, vec2(0.77, 0.17), vec2(0.62, 0.0), w), seg(q, vec2(0.62, 0.0), vec2(0.36, 0.0), w)));
		s = max(s, seg(q, vec2(0.36, 0.0), vec2(0.17, 0.12), w));
	} else if (k == 15) { // T
		s = max(seg(q, vec2(0.1, 1.0), vec2(0.84, 1.0), w), seg(q, vec2(0.47, 0.0), vec2(0.47, 1.0), w));
	} else if (k == 16) { // V
		s = max(seg(q, vec2(0.12, 1.0), vec2(0.47, 0.0), w), seg(q, vec2(0.47, 0.0), vec2(0.82, 1.0), w));
	} else if (k == 17) { // X
		s = max(seg(q, vec2(0.15, 1.0), vec2(0.8, 0.0), w), seg(q, vec2(0.15, 0.0), vec2(0.8, 1.0), w));
	} else if (k == 18) { // interpunct
		s = 1.0 - step(0.08, length(q - vec2(0.47, 0.45)));
	} else if (k == 19) { // D
		s = max(seg(q, bl, tl, w), seg(q, tl, vec2(0.5, 1.0), w));
		s = max(s, max(seg(q, vec2(0.5, 1.0), vec2(0.76, 0.75), w), seg(q, vec2(0.76, 0.75), vec2(0.76, 0.25), w)));
		s = max(s, max(seg(q, vec2(0.76, 0.25), vec2(0.5, 0.0), w), seg(q, vec2(0.5, 0.0), bl, w)));
	}
	return s;
}

// one word (`wi` in the tables above) centred in the box p (0..1, 0..1) whose width is `aspect`
// times its height
float word(int wi, vec2 p, float aspect) {
	int n = W_LEN[wi];
	float cw = min(0.62, aspect * 0.9 / float(n));   // letter width, in letter heights
	float x0 = (aspect - cw * float(n)) * 0.5;
	float x = p.x * aspect - x0;
	if (x < 0.0 || x >= cw * float(n) || p.y < 0.0 || p.y > 1.0) return 0.0;
	int ci = int(floor(x / cw));
	int k = W_CH[wi * 10 + ci];
	if (k == 31) return 0.0;
	vec2 q = vec2(fract(x / cw), p.y);
	q.x = (q.x - 0.5) / 0.86 + 0.5;    // a little space between letters
	return glyph(k, q);
}

// the sign: one trade word, or the owner's name above it. UV2.y = trade * 100 + r (r 0..99);
// everything is rounded to integers first, because interpolated values differ in the last bits
// from pixel to pixel and a hash of them would change the word from one pixel to the next
float sign_text(vec2 suv, vec2 suv2, float inst) {
	int code = int(round(suv2.y));
	int t = clamp(code / 100, 0, 2);
	int r = code - (code / 100) * 100;
	int si = int(round(inst * 997.0));
	int tw = W_TRADE[t * 6 + (r * 7 + si * 3) % 6];
	float hgt = 0.55;
	if ((r + si) % 3 == 0) {
		int nm = W_NAME[(r * 5 + si) % 8];
		float a = suv2.x / (hgt * 0.34);
		return max(word(nm, vec2(suv.x, (suv.y - 0.56) / 0.34), a), word(tw, vec2(suv.x, (suv.y - 0.12) / 0.34), a));
	}
	return word(tw, vec2(suv.x, (suv.y - 0.2) / 0.6), suv2.x / (hgt * 0.6));
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
	// the underside of a roof or a ridge is the timber boarding under the tiles, not tiles
	if ((id == 9 || id == 11 || id == 14 || id == 15) && !FRONT_FACING) {
		id = 21;
	}
	vec3 tint = lin(vcust.rgb);
	vec3 vc = lin(vcol.rgb);
	vec3 col = vec3(0.5);
	float rough = 0.92;
	float metal = 0.0;
	float spec = 0.35;
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
		float peel_zone = smoothstep(0.72, 0.78, peel) * smoothstep(2.6, 0.4, up) * step(0.5, fract(vcust.a * 7.0));
		vec3 under = vcust.a > 0.6 ? brick(uv, seed, c_brick_latericium, c_stucco_worn) : masonry(uv, seed, c_opus_incertum, c_tufa_grey, c_stucco_worn);
		col = mix(base, mix(c_opus_incertum, under, fade) * 0.85, peel_zone * 0.55);
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
		vec3 base = mix(c_tegulae, c_tegulae_old, clamp(vcust.a * 0.7 + 0.4 * fbm(lpos.xz * 0.25 + seed) - 0.25, 0.0, 1.0));
		// far away the pattern averages out: use its mean (about 0.82) so distant roofs keep the
		// depth of colour of the near ones instead of washing out
		col = base * mix(0.82, tone * (0.74 + 0.26 * smoothstep(0.0, 0.3, row)) * (0.9 + 0.16 * cov), aa);
		float lich = smoothstep(0.7, 0.86, fbm(lpos.xz * 0.6 + seed));
		col = mix(col, col * lin(vec3(0.7, 0.66, 0.5)), lich * 0.5);
		nrm = normalize(NORMAL + normalize(v_across) * x * cov * 0.85 * aa);
		rough = 0.9;
		spec = 0.2;
	} else if (id == 11) {
		col = c_ridge_terracotta * (0.85 + 0.25 * vn(lpos.xz * 3.0 + lpos.y + seed));
		rough = 0.88;
		spec = 0.25;
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
		col = dark * (0.28 + 0.08 * vn(uv * 2.0 + seed)) + c_timber_oak * shelf * 0.14 * fade;
		rough = 1.0;
	} else if (id == 13) {
		// painted sign (dipinti): red capitals on a white ground, words chosen by the shop's trade
		vec3 ink = c_stucco_red * 0.85;
		float l = UV2.x > 0.1 ? sign_text(UV, UV2, vcust.a) * fade : 0.0;
		col = mix(c_stucco_white * (0.9 + 0.1 * fbm(uv * 2.0)), ink, l * 0.85);
		// a thin red frame round the panel
		float frame = UV2.x > 0.1 ? (1.0 - step(0.03, min(min(UV.x, 1.0 - UV.x) * UV2.x / 0.55, min(UV.y, 1.0 - UV.y)))) : 0.0;
		col = mix(col, ink, frame * 0.8 * fade);
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
	// a little bounce light from the sunlit street and the walls opposite, so walls in deep shade
	// (late afternoon, narrow lanes) keep their colour instead of going near-black; strongest on
	// walls, least on roofs, which see the sky anyway
	EMISSION = col * (0.045 + 0.035 * (1.0 - abs(lnorm.y)));
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	NORMAL = nrm;
}
"""
