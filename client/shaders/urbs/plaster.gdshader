// Urbs material library (U8 render): lime plaster and stucco. Soft trowel clouds, a fine
// sand grain that only shows close up, rain streaks from the top, grime and splash at the
// foot. `panel` > 0 paints a Pompeian-style scheme: a dark dado to 0.9 m, panels of `base`
// framed by thin `trim` bands above.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/urbs/urbs_common.gdshaderinc"

uniform vec4 base_colour : source_color = vec4(0.92, 0.90, 0.85, 1.0);
uniform vec4 trim_colour : source_color = vec4(0.20, 0.16, 0.14, 1.0);
uniform float wear : hint_range(0.0, 1.0) = 0.3;      // patches where the limewash is gone
uniform float panel = 0.0;                            // width of a painted panel (0: plain)
uniform float rough = 0.9;
uniform float grime = 0.8;

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
	vec3 col = base_colour.rgb;

	float cloud = u_fbm3(p, 0.6, fp);
	col *= 0.9 + 0.2 * cloud;
	float keep_grain = u_detail(0.02, fp);
	float grain = u_noise3(p * 60.0);
	col *= 1.0 + (grain - 0.5) * 0.08 * keep_grain;
	// worn patches: the darker coat below shows through
	float worn = smoothstep(0.62, 0.7, u_fbm3(p + 4.0, 0.9, fp)) * wear;
	col = mix(col, col * vec3(0.78, 0.74, 0.68), worn);
	// rain streaks down vertical faces
	float vertical = 1.0 - abs(n.y);
	float streak = u_fbm2(vec2(uv.x * 3.0, uv.y * 0.25), 1.0, fp);
	col *= 1.0 - smoothstep(0.55, 0.8, streak) * 0.16 * vertical * wear * 2.0;

	if (panel > 0.0) {
		float y = p.y;
		float dado = 1.0 - smoothstep(0.88, 0.9, y);
		float fade = u_detail(0.05, fp);
		float px = fract(uv.x / panel) * panel;
		float dx = min(px, panel - px);
		float frame_band = (1.0 - smoothstep(0.035, 0.035 + max(fp, 0.002), dx)) * step(1.0, y);
		float top = smoothstep(2.6, 2.62, y);
		float line_y = (1.0 - smoothstep(0.02, 0.02 + max(fp, 0.002), abs(y - 0.95))) ;
		vec3 trim = trim_colour.rgb;
		col = mix(col, trim * (0.9 + 0.2 * cloud), max(dado, top * 0.7));
		col = mix(col, trim, max(frame_band, line_y) * fade * 0.85);
	}

	// grime and splash at the foot of the wall
	col *= mix(1.0, u_grime(p.y, 1.2), grime * vertical);
	vec2 grad = vec2(0.0);
	float keep = u_detail(0.1, fp);
	if (keep > 0.0) {
		float h0 = u_noise3(p * 9.0);
		grad = vec2(u_noise3((p + t * 0.02) * 9.0) - h0, u_noise3((p + b * 0.02) * 9.0) - h0) * 0.6 * keep;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
	NORMAL = u_bump(n, t, b, grad, MODEL_MATRIX, VIEW_MATRIX);
}
