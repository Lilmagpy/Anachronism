// Urbs material library (U8 render): Roman roofs of fired clay (or gilt bronze).
//   mode 0  tegulae and imbrices: flat pan tiles with raised flanges, the joints between them
//           covered by half-round imbrices running down the slope (about 0.55 m apart), each
//           course overlapping the one below (about 0.6 m) with a shadowed lip. The ridges are
//           a real bump on the normal, plus a little occlusion in the gutters, so a low sun
//           rakes them.
//   mode 1  ridge tiles (imbrices laid along the ridge): joints across, every 0.45 m
//   mode 2  antefixes and plain terracotta: modelled relief only
// A face that is not a slope (an eave's fascia, a gable edge) keeps the colour without ridges.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/urbs/urbs_common.gdshaderinc"

uniform int mode = 0;
uniform vec4 base_colour : source_color = vec4(0.72, 0.42, 0.28, 1.0);
uniform vec4 alt_colour : source_color = vec4(0.62, 0.33, 0.22, 1.0);
uniform float pitch_w = 0.55;     // imbrex spacing along the eaves, metres
uniform float course = 0.6;       // tile course down the slope, metres
uniform float lichen : hint_range(0.0, 1.0) = 0.25;
uniform float metal = 0.0;
uniform float rough = 0.75;

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
	vec3 ca = base_colour.rgb;
	vec3 cb = alt_colour.rgb;
	// each roof weathered its own way (world position: a building's roof shares one tone)
	float big = u_fbm3(u_wpos * 0.5, 0.08, fp);
	vec3 col = mix(ca, cb, big);
	float ao = 1.0;
	vec2 grad = vec2(0.0);
	bool slope = n.y > 0.15 && n.y < 0.985;

	if (mode == 0 && slope) {
		float keep = u_detail(pitch_w * 0.5, fp);
		float row = floor(uv.y / course);
		float x = (fract(uv.x / pitch_w + 0.5) - 0.5) * pitch_w;      // 0 on an imbrex's crest
		float cell = floor(uv.x / pitch_w + 0.5);
		float fy = fract(uv.y / course);                                // 0 at a course's lower lip
		float R = pitch_w * 0.15;
		float ax = abs(x);
		float on_imbrex = 1.0 - smoothstep(R - fp, R + fp, ax);
		// the imbrex: a half-round; dh/du = -x / sqrt(R^2 - x^2), kept finite at the edge
		float hx = sqrt(max(R * R - x * x, R * R * 0.04));
		float dhdu = -x / hx * on_imbrex;
		// the pan's flanges rise just beside the imbrex; the pan dips a little between them
		float flange = smoothstep(R, R + 0.04, ax) * (1.0 - smoothstep(R + 0.04, R + 0.07, ax));
		dhdu += (1.0 - on_imbrex) * sign(x) * flange * 0.6;
		// each course: the lower lip stands proud, its shadow on the course below
		float lip = 1.0 - smoothstep(0.0, 0.08, fy);
		float under = smoothstep(0.88, 1.0, fy);
		float dhdv = -0.25 * (1.0 - on_imbrex) + 1.6 * under * (1.0 - on_imbrex * 0.5);
		grad = vec2(dhdu * 0.9, dhdv * 0.12) * keep;
		// occlusion in the gutters beside each imbrex and under each lip
		float gutter = (1.0 - smoothstep(R, R + 0.05, ax)) * (1.0 - on_imbrex);
		ao = 1.0 - (gutter * 0.35 + lip * 0.3 * (1.0 - on_imbrex)) * keep - (1.0 - keep) * 0.12;
		// tile by tile: no two fired alike
		float tile = u_hash2(vec2(cell * 2.0 + on_imbrex, row));
		col *= 1.0 + (tile - 0.5) * 0.22 * keep;
		// the crest of each imbrex catches more light and wears paler
		col *= 1.0 + on_imbrex * (1.0 - ax / R) * 0.1 * keep;
	} else if (mode == 1) {
		float keep = u_detail(0.2, fp);
		float j = fract(uv.x / 0.45);
		float joint = 1.0 - smoothstep(0.0, 0.06, min(j, 1.0 - j));
		ao = 1.0 - joint * 0.3 * keep - (1.0 - keep) * 0.05;
		grad = vec2(j < 0.5 ? 1.0 : -1.0, 0.0) * joint * 0.6 * keep;
		col *= 1.0 + (u_hash2(vec2(floor(uv.x / 0.45), 7.0)) - 0.5) * 0.2 * keep;
	} else if (mode == 2) {
		float keep = u_detail(0.05, fp);
		float h0 = u_fbm3(p, 6.0, fp);
		grad = vec2(u_fbm3(p + t * 0.01, 6.0, fp) - h0, u_fbm3(p + b * 0.01, 6.0, fp) - h0) * 30.0 * keep;
		ao = 0.85 + 0.3 * h0;
	} else {
		float row = fract(uv.y / course);
		ao = 1.0 - (1.0 - smoothstep(0.0, 0.1, row)) * 0.2 * u_detail(course, fp);
	}

	// lichen and soot on old roofs: grey-green and dark blotches
	float l = smoothstep(0.6, 0.75, u_fbm3(u_wpos + 11.0, 0.7, fp)) * lichen * (1.0 - metal);
	col = mix(col, u_lin(vec3(0.42, 0.42, 0.33)), l * 0.6);
	ALBEDO = col * ao;
	METALLIC = metal;
	ROUGHNESS = rough + l * 0.15;
	SPECULAR = 0.35;
	AO = ao;
	if (grad != vec2(0.0)) {
		NORMAL = u_bump(n, t, b, grad, MODEL_MATRIX, VIEW_MATRIX);
	}
}
