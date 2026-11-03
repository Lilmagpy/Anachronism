// Urbs material library (U8 render): timber. Grain runs up a wall-like face (doors, posts,
// shutters) and along object x on a level one (beams, floors, benches); boards `plank` metres
// wide with dark seams; `slats` > 0 turns the boards into a shutter's horizontal louvres;
// `paint` lays a colour over the grain that has worn off at the edges of each board.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/urbs/urbs_common.gdshaderinc"

uniform vec4 base_colour : source_color = vec4(0.52, 0.38, 0.24, 1.0);
uniform vec4 paint_colour : source_color = vec4(0.45, 0.16, 0.12, 1.0);
uniform float paint : hint_range(0.0, 1.0) = 0.0;
uniform float plank = 0.22;
uniform float slats = 0.0;
uniform float grey = 0.0;      // weathered silver-grey
uniform float rough = 0.8;

void vertex() {
	vec3 s = u_scale(MODEL_MATRIX);
	u_pos = VERTEX * s;
	u_nrm = normalize(NORMAL / s);
	u_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = u_pos;
	vec3 n = normalize(u_nrm);
	if (!FRONT_FACING) {
		n = -n;
	}
	vec3 t;
	vec3 b;
	u_frame(n, t, b);
	vec2 uv = vec2(dot(p, t), dot(p, b));
	float fp = u_footprint(p);
	// across the boards (a) and along the grain (g)
	float a = abs(n.y) > 0.97 ? uv.y : uv.x;
	float g = abs(n.y) > 0.97 ? uv.x : uv.y;
	vec2 grad = vec2(0.0);
	float board = floor(a / plank);
	float fa = fract(a / plank);
	float keep_b = u_detail(plank, fp);
	float seam = (1.0 - smoothstep(0.0, 0.04 + fp / plank, min(fa, 1.0 - fa))) * keep_b;
	float sb = u_hash2(vec2(board, 1.3));
	// grain: stretched noise with rings
	float keep_g = u_detail(0.02, fp);
	float ring = u_noise2(vec2(a * 40.0 + sb * 10.0, g * 1.5));
	float grain = mix(0.5, fract(ring * 6.0), keep_g * 0.6);
	vec3 col = base_colour.rgb * (0.75 + 0.35 * grain) * (0.85 + 0.3 * sb * keep_b + 0.15 * (1.0 - keep_b));
	col = mix(col, u_lin(vec3(0.55, 0.53, 0.50)) * (0.8 + 0.3 * grain), grey);
	if (slats > 0.0) {
		float fs = fract(uv.y / slats);
		float ks = u_detail(slats, fp);
		grad.y += (fs < 0.85 ? -0.5 : 2.5) * ks;
		col *= 1.0 - (1.0 - smoothstep(0.0, 0.2, fs)) * 0.5 * ks;
	}
	if (paint > 0.0) {
		float chip = smoothstep(0.55, 0.62, u_fbm3(p + 2.0, 3.0, fp) + (1.0 - min(fa, 1.0 - fa) * 4.0) * 0.15 * keep_b);
		col = mix(col, paint_colour.rgb * (0.92 + 0.1 * grain), paint * (1.0 - chip));
	}
	col *= 1.0 - seam * 0.55;
	grad.x += seam * (fa < 0.5 ? 1.0 : -1.0) * 0.5;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	NORMAL = u_bump(n, t, b, abs(n.y) > 0.97 ? grad.yx : grad, MODEL_MATRIX, VIEW_MATRIX);
}
