// Urbs material library (U8 render): bronze, gilt bronze and iron. Real metals (metallic 1,
// coloured specular), polished where hands and weather rub them, a patina gathering in the
// hollows (`patina`: dark brown on bronze, green verdigris where it has run, rust on iron).
// `studs` > 0 casts a door: square coffers framed by rails, a boss at every crossing.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/urbs/urbs_common.gdshaderinc"

uniform vec4 base_colour : source_color = vec4(0.62, 0.45, 0.22, 1.0);
uniform vec4 patina_colour : source_color = vec4(0.22, 0.42, 0.36, 1.0);
uniform float patina : hint_range(0.0, 1.0) = 0.2;
uniform float rough = 0.35;
uniform float studs = 0.0;     // coffer size, metres (0: plain)
uniform float hammered = 0.3;  // the slight unevenness of beaten or cast metal

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
	vec3 metal_c = base_colour.rgb;
	float cloud = u_fbm3(p, 1.3, fp);
	float pat = smoothstep(0.45, 0.75, cloud + (1.0 - n.y) * 0.1 - 0.15) * patina;
	float r = rough + 0.25 * (cloud - 0.5);
	vec2 grad = vec2(0.0);
	float hollow = 0.0;

	if (studs > 0.0) {
		float keep = u_detail(studs * 0.3, fp);
		vec2 g = fract(uv / studs) * studs;
		vec2 d2 = min(g, studs - g);
		float rail = 1.0 - smoothstep(studs * 0.12, studs * 0.12 + max(fp, 0.002), min(d2.x, d2.y));
		vec2 c = (fract(uv / studs + 0.5) - 0.5) * studs;     // to the nearest crossing
		float rr = length(c);
		float boss = 1.0 - smoothstep(studs * 0.07, studs * 0.07 + max(fp, 0.002), rr);
		vec2 bg = rr > 0.0 ? -c / rr : vec2(0.0);
		grad += boss * (-bg) * 1.5 * keep;
		float edge = smoothstep(studs * 0.12, studs * 0.16, min(d2.x, d2.y)) * (1.0 - smoothstep(studs * 0.16, studs * 0.2, min(d2.x, d2.y)));
		grad += (d2.x < d2.y ? vec2(g.x < studs * 0.5 ? -1.0 : 1.0, 0.0) : vec2(0.0, g.y < studs * 0.5 ? -1.0 : 1.0)) * edge * 0.8 * keep;
		hollow = (1.0 - rail) * (1.0 - boss) * 0.5 * keep;
		r -= (rail + boss) * 0.15 * keep;
	}
	if (hammered > 0.0) {
		float keep = u_detail(0.06, fp);
		float h0 = u_noise3(p * 18.0);
		grad += vec2(u_noise3((p + t * 0.01) * 18.0) - h0, u_noise3((p + b * 0.01) * 18.0) - h0) * 4.0 * hammered * keep;
	}
	pat = clamp(pat + hollow * patina * 1.5, 0.0, 1.0);
	vec3 pc = patina_colour.rgb * (0.8 + 0.4 * cloud);
	ALBEDO = mix(metal_c * (0.9 + 0.2 * cloud), pc, pat);
	METALLIC = mix(1.0, 0.0, pat);
	ROUGHNESS = clamp(mix(r, 0.85, pat), 0.08, 1.0);
	SPECULAR = 0.5;
	if (grad != vec2(0.0)) {
		NORMAL = u_bump(n, t, b, grad, MODEL_MATRIX, VIEW_MATRIX);
	}
}
