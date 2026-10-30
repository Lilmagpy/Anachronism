// Urbs material library (U8 render): natural stone. Solid (3D) texturing, so a column, a
// capital or a step is veined right through without any UVs.
//   mode 0  veined marble (Luna, Pentelic, statue marble): long warped veins, soft clouds,
//           a polished sheen
//   mode 1  breccia (africano / marmor Luculleum): clasts of red, grey and white in a dark matrix
//   mode 2  travertine: cream, banded, with the long pores of the Tibur stone
//   mode 3  tufa / peperino: porous, mottled, specks of dark scoria
//   mode 4  basalt (silex): fine dark grain
// `block` cuts the stone into ashlar courses (metres; 0 = one piece).
shader_type spatial;
render_mode cull_back;

#include "res://shaders/urbs/urbs_common.gdshaderinc"

uniform int mode = 0;
uniform vec4 base_colour : source_color = vec4(0.93, 0.92, 0.89, 1.0);
uniform vec4 vein_colour : source_color = vec4(0.55, 0.56, 0.58, 1.0);
uniform vec4 accent_colour : source_color = vec4(0.6, 0.2, 0.15, 1.0);
uniform float vein_amount : hint_range(0.0, 1.0) = 0.5;
uniform float vein_scale = 1.4;        // vein bands per metre
uniform float mottle : hint_range(0.0, 1.0) = 0.12;
uniform vec2 block = vec2(0.0, 0.0);
uniform vec4 joint_colour : source_color = vec4(0.62, 0.60, 0.55, 1.0);
uniform float joint_width = 0.006;
uniform float rough = 0.3;
uniform float spec = 0.5;
uniform float grime = 0.5;

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
	vec3 base = base_colour.rgb;
	vec3 col = base;
	float r = rough;
	vec2 grad = vec2(0.0);

	// broad clouds every stone has
	float cloud = u_fbm3(p, 0.35, fp);
	col *= 1.0 + (cloud - 0.5) * mottle * 2.0;

	if (mode == 0) {
		// veins: ridges of warped noise (where it crosses 0.5), a main network and a fainter
		// fine one; each pixel's own footprint sets how sharp the line can be drawn
		vec3 q = p * vein_scale + (vec3(u_fbm3(p, 0.5, fp), u_fbm3(p + 5.2, 0.5, fp), u_fbm3(p + 9.7, 0.5, fp)) - 0.5) * 1.6;
		float n1 = u_fbm3(q, 0.55, fp * vein_scale);
		float w1 = fwidth(n1) + 1e-4;
		float v1 = 1.0 - smoothstep(0.0, 0.012 + w1, abs(n1 - 0.5));
		float n2 = u_fbm3(q * 2.3 + 4.0, 0.7, fp * vein_scale * 2.3);
		float w2 = fwidth(n2) + 1e-4;
		float v2 = 1.0 - smoothstep(0.0, 0.008 + w2, abs(n2 - 0.5));
		// a vein too thin for the pixel fades to the faint tint it would average to
		v1 = mix(v1, 0.05, smoothstep(0.03, 0.12, w1));
		v2 = mix(v2, 0.03, smoothstep(0.03, 0.12, w2));
		float soft = smoothstep(0.42, 0.5, n1) * (1.0 - smoothstep(0.5, 0.58, n1));
		float vein = clamp(v1 * 0.8 + v2 * 0.35 + soft * 0.25, 0.0, 1.0) * vein_amount;
		col = mix(col, vein_colour.rgb, vein);
		// polish: a little duller where the veins and the weather run
		r = rough + 0.1 * vein + 0.12 * (cloud - 0.5);
	} else if (mode == 1) {
		vec3 vo = u_voronoi(uv * 9.0 + u_fbm3(p, 1.2, fp) * 2.0);
		float clast = smoothstep(0.03, 0.09, vo.y) * u_detail(0.08, fp);
		vec3 c1 = accent_colour.rgb;
		vec3 c2 = vein_colour.rgb;
		vec3 c3 = u_lin(vec3(0.82, 0.80, 0.76));
		vec3 cc = vo.z < 0.45 ? c1 : (vo.z < 0.8 ? c2 : c3);
		cc *= 0.8 + 0.4 * u_hash2(vec2(vo.z * 91.0, 3.0));
		col = mix(col, mix(col, cc, 0.85), clast * vein_amount + (1.0 - u_detail(0.08, fp)) * 0.35 * vein_amount);
		r = rough;
	} else if (mode == 2) {
		float band = u_fbm2(vec2(p.y * 3.0, cloud * 2.0), 1.0, fp);
		col *= 0.9 + 0.2 * band;
		float pore_n = u_noise2(vec2(uv.x * 9.0, uv.y * 42.0) + floor(p.z * 3.0));
		float keep = u_detail(0.06, fp);
		float pore = smoothstep(0.74, 0.82, pore_n) * keep;
		col *= 1.0 - pore * 0.45 * vein_amount;
		col *= 1.0 - (1.0 - keep) * 0.04 * vein_amount;
		r = rough + pore * 0.2;
		grad.y += (u_noise2(vec2(uv.x * 9.0, uv.y * 42.0 + 0.3)) - pore_n) * 0.8 * keep * vein_amount;
	} else if (mode == 3) {
		float speck_n = u_noise3(p * 40.0);
		float keep = u_detail(0.03, fp);
		float speck = smoothstep(0.78, 0.86, speck_n) * keep;
		col = mix(col, vein_colour.rgb, speck * vein_amount + (1.0 - keep) * 0.05 * vein_amount);
		float hole = smoothstep(0.8, 0.9, u_noise3(p * 13.0 + 5.0)) * u_detail(0.08, fp);
		col *= 1.0 - hole * 0.35;
		col *= 0.92 + 0.16 * u_fbm3(p, 2.5, fp);
	} else {
		col *= 0.85 + 0.3 * u_fbm3(p, 9.0, fp);
	}

	if (block.x > 0.0) {
		vec4 bk = u_blocks(uv, block, joint_width, 0.025, fp);
		float keep = u_detail(min(block.x, block.y > 0.0 ? block.y : block.x), fp);
		col *= 1.0 + (bk.w - 0.5) * 0.14 * keep;
		col = mix(col, joint_colour.rgb, bk.x * 0.85);
		grad += bk.yz * 0.012;
	}

	col *= mix(1.0, u_grime(p.y, 1.6), grime);
	ALBEDO = col;
	ROUGHNESS = clamp(r, 0.04, 1.0);
	SPECULAR = spec;
	if (grad != vec2(0.0)) {
		NORMAL = u_bump(n, t, b, grad, MODEL_MATRIX, VIEW_MATRIX);
	}
}
