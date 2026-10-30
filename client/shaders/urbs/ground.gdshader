// Urbs material library (U8 render): what you walk on. Mapped on the level plane (object x, z
// in metres), so a street or a plaza can be any shape.
//   mode 0  forum travertine: rectangular slabs (about 1.5 x 0.9 m, rows staggered), each its
//           own cream, worn smooth and darker along the joints
//   mode 1  street basalt (silex): the polygonal blocks of Roman paving, dark blue-grey,
//           polished by wheels and feet, sand in the joints
//   mode 2  gravel   mode 3 packed earth   mode 4 grass   mode 5 garden bed   mode 6 arena sand
//   mode 7  mud bank (wet, dark, glossy)
shader_type spatial;
render_mode cull_back;

#include "res://shaders/urbs/urbs_common.gdshaderinc"

uniform int mode = 0;
uniform vec4 base_colour : source_color = vec4(0.84, 0.80, 0.70, 1.0);
uniform vec4 alt_colour : source_color = vec4(0.70, 0.64, 0.52, 1.0);
uniform vec4 joint_colour : source_color = vec4(0.45, 0.40, 0.33, 1.0);
uniform float unit = 1.5;
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
	vec3 t;
	vec3 b;
	u_frame(n, t, b);
	vec2 uv = vec2(dot(p, t), dot(p, b));
	float fp = u_footprint(p);
	vec3 ca = base_colour.rgb;
	vec3 cb = alt_colour.rgb;
	vec3 cj = joint_colour.rgb;
	vec3 col = mix(ca, cb, u_fbm3(p, 0.15, fp));
	float r = rough;
	vec2 grad = vec2(0.0);
	float spec = 0.4;

	if (mode == 0) {
		vec4 bk = u_blocks(uv, vec2(unit, unit * 0.6), 0.012, 0.03, fp);
		float keep = u_detail(unit * 0.6, fp);
		col = mix(ca, cb, bk.w * 0.8 + 0.2 * u_fbm3(p, 0.8, fp));
		col *= 0.92 + 0.12 * u_fbm3(p, 4.0, fp);
		// wear: darker grime near the joints, the slab centres polished
		col = mix(col, cj, bk.x * 0.9);
		col = mix(mix(ca, cb, 0.45) * 0.95, col, keep);
		grad = bk.yz * 0.01;
		float pore = smoothstep(0.78, 0.85, u_noise2(vec2(uv.x * 10.0, uv.y * 40.0))) * u_detail(0.05, fp);
		col *= 1.0 - pore * 0.3;
		r = rough - 0.15 * (1.0 - bk.x) * keep;
	} else if (mode == 1) {
		vec2 q = uv / unit;
		vec3 vo = u_voronoi(q);
		float keep = u_detail(unit * 0.6, fp);
		float joint = (1.0 - smoothstep(0.012, 0.03 + fp / unit, vo.y)) * keep;
		col = mix(ca, cb, vo.z) * (0.85 + 0.3 * u_fbm3(p, 5.0, fp));
		// polished crowns, sand and dust lodged in the joints
		float crown = smoothstep(0.04, 0.3, vo.y);
		col = mix(col, cj, joint);
		col = mix(mix(ca, cb, 0.5) * 0.95 + cj * 0.05, col, keep);
		r = mix(0.95, rough - 0.12 * crown, keep);
		spec = 0.35;
		if (keep > 0.01) {   // the edge bevel, only where it is big enough to see
			float hx = u_voronoi(q + vec2(0.02, 0.0)).y - vo.y;
			float hy = u_voronoi(q + vec2(0.0, 0.02)).y - vo.y;
			grad = vec2(hx, hy) * (1.0 - crown) * 6.0 * keep;
		}
	} else if (mode == 2) {
		float keep = u_detail(0.04, fp);
		vec3 vo = keep > 0.0 ? u_voronoi(uv * 25.0) : vec3(0.5, 0.3, 0.5);
		float peb = smoothstep(0.0, 0.15, vo.y);
		col = mix(col * 0.75, mix(ca, cb, vo.z) * 1.1, mix(0.6, peb, keep));
		r = 0.95;
	} else if (mode == 3 || mode == 6) {
		float keep = u_detail(0.025, fp);
		col *= 0.85 + 0.3 * u_fbm3(p, 3.0, fp);
		float grit = u_noise2(uv * 40.0);
		col *= 1.0 + (grit - 0.5) * 0.25 * keep;
		float h0 = u_fbm2(uv, 4.0, fp);
		grad = vec2(u_fbm2(uv + vec2(0.02, 0.0), 4.0, fp) - h0, u_fbm2(uv + vec2(0.0, 0.02), 4.0, fp) - h0) * 6.0 * u_detail(0.25, fp);
		r = 0.98;
		spec = 0.25;
	} else if (mode == 4) {
		float keep = u_detail(0.016, fp);
		float blades = u_noise2(uv * vec2(60.0, 60.0));
		col *= 0.75 + 0.5 * u_fbm3(p, 0.5, fp);
		col = mix(col, col * vec3(1.4, 1.25, 0.7), smoothstep(0.55, 0.75, u_fbm3(p + 3.0, 0.2, fp)) * 0.6);
		col *= 1.0 + (blades - 0.5) * 0.5 * keep;
		r = 0.95;
		spec = 0.3;
	} else if (mode == 5) {
		float keep = u_detail(0.3, fp);
		float rows = 0.5 + 0.5 * sin(uv.x / unit * 6.2832);
		col *= mix(0.9, 0.7 + 0.5 * rows, keep);
		float green = smoothstep(0.55, 0.7, u_noise2(uv * 6.0)) * rows * keep;
		col = mix(col, u_lin(vec3(0.30, 0.42, 0.18)), green * 0.7);
		r = 1.0;
	} else {
		float wet = smoothstep(0.35, 0.65, u_fbm3(p, 0.5, fp));
		col *= mix(1.0, 0.55, wet);
		r = mix(0.95, 0.25, wet);
		spec = 0.5;
	}
	ALBEDO = col;
	ROUGHNESS = clamp(r, 0.05, 1.0);
	SPECULAR = spec;
	if (grad != vec2(0.0)) {
		NORMAL = u_bump(n, t, b, grad, MODEL_MATRIX, VIEW_MATRIX);
	}
}
