// Urbs material library (U8 render): walls built of small units in mortar.
//   pattern 0  opus latericium: fired bricks (bessales/sesquipedales cut, faces about
//              0.30 x 0.045 m) in courses with 1-1.5 cm mortar beds
//   pattern 1  opus reticulatum: square tufa tufelli set diagonally, a net of 8-10 cm squares
//   pattern 2  opus incertum: irregular fist-sized stones in a lot of mortar
//   pattern 3  opus quadratum: large tufa blocks (about 2 x 2 x 4 Roman feet: 0.6 x 0.6 x 1.2 m)
//   pattern 4  rubble: big rough stones, coarse joints
// The mortar sits back from the face (a bump at every unit's edge); units fade to their average
// colour and the bump to nothing once they are a few pixels across.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/urbs/urbs_common.gdshaderinc"

uniform int pattern = 0;
uniform vec4 unit_colour : source_color = vec4(0.68, 0.40, 0.30, 1.0);
uniform vec4 unit_colour_b : source_color = vec4(0.58, 0.32, 0.22, 1.0);
uniform vec4 mortar_colour : source_color = vec4(0.78, 0.74, 0.66, 1.0);
uniform float unit_size = 0.3;     // pattern-dependent: brick length, net square, stone size
uniform float rough = 0.88;
uniform float grime = 0.6;

void vertex() {
	vec3 s = u_scale(MODEL_MATRIX);
	u_pos = VERTEX * s;
	u_nrm = normalize(NORMAL / s);
	u_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = u_pos;
	vec3 n = normalize(u_nrm);
	vec3 t;
	vec3 b;
	u_frame(n, t, b);
	vec2 uv = vec2(dot(p, t), dot(p, b));
	float fp = u_footprint(p);
	vec3 ca = unit_colour.rgb;
	vec3 cb = unit_colour_b.rgb;
	vec3 cm = mortar_colour.rgb;
	float mortar = 0.0;
	float tone = 0.5;
	vec2 grad = vec2(0.0);
	float period = unit_size;
	float mean_mortar = 0.2;

	if (pattern == 0) {
		vec4 bk = u_blocks(uv, vec2(unit_size, unit_size * 0.19), unit_size * 0.045, 0.006, fp);
		mortar = bk.x;
		tone = bk.w;
		grad = bk.yz * 0.004;
		period = unit_size * 0.19;
		mean_mortar = 0.3;
	} else if (pattern == 1) {
		// rotate 45 degrees: a net of squares standing on their corners
		vec2 r = vec2(uv.x + uv.y, uv.y - uv.x) * 0.70711;
		vec2 g = fract(r / unit_size) * unit_size;
		vec2 d2 = min(g, unit_size - g);
		float d = min(d2.x, d2.y);
		float hj = unit_size * 0.06;
		float fade = u_detail(unit_size, fp);
		mortar = (1.0 - smoothstep(hj, hj + max(fp, 0.001), d)) * fade;
		tone = u_hash2(floor(r / unit_size) + 0.5);
		float slope = (d > hj && d < hj + 0.012) ? fade / 0.012 : 0.0;
		vec2 gr = d2.x < d2.y ? vec2(g.x < unit_size * 0.5 ? slope : -slope, 0.0) : vec2(0.0, g.y < unit_size * 0.5 ? slope : -slope);
		// back from the rotated frame to the face's own
		grad = vec2(gr.x - gr.y, gr.x + gr.y) * 0.70711 * 0.004;
		mean_mortar = 0.25;
	} else if (pattern == 2 || pattern == 4) {
		float sz = unit_size;
		vec2 q = uv / sz + (u_fbm2(uv, 1.5 / sz, fp) - 0.5) * 0.5;
		vec3 vo = u_voronoi(q);
		float fade = u_detail(sz, fp);
		float jw = pattern == 2 ? 0.16 : 0.09;
		mortar = (1.0 - smoothstep(jw, jw + max(fp / sz, 0.01) + 0.05, vo.y)) * fade;
		tone = vo.z;
		// each stone's face rough; the mortar between stays flat
		float e = smoothstep(jw, jw + 0.25, vo.y);
		mean_mortar = pattern == 2 ? 0.35 : 0.2;
		period = sz;
		// pebbly roughness from the stones' own grain
		tone += (u_noise2(uv * 30.0) - 0.5) * 0.3 * u_detail(0.04, fp);
		float hn = u_noise2(q * 3.0);
		grad = (vec2(u_noise2(q * 3.0 + vec2(0.05, 0.0)), u_noise2(q * 3.0 + vec2(0.0, 0.05))) - hn) * 4.0 * fade * e;
	} else {
		vec4 bk = u_blocks(uv, vec2(unit_size * 2.0, unit_size), 0.008, 0.03, fp);
		mortar = bk.x;
		tone = bk.w;
		grad = bk.yz * 0.015;
		period = unit_size;
		mean_mortar = 0.02;
	}

	float keep = u_detail(period, fp);
	vec3 unit = mix(ca, cb, tone) * (0.9 + 0.2 * u_noise2(uv * 6.0 + tone * 13.0));
	vec3 avg = mix(mix(ca, cb, 0.5), cm, mean_mortar);
	vec3 col = mix(unit, cm, mortar);
	col = mix(avg, col, keep);
	col *= 0.9 + 0.2 * u_fbm3(p, 0.4, fp);
	col *= mix(1.0, u_grime(p.y, 2.0), grime);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	if (keep > 0.0) {
		NORMAL = u_bump(n, t, b, grad * keep, MODEL_MATRIX, VIEW_MATRIX);
	}
}
