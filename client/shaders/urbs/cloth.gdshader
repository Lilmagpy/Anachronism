// Urbs material library (U8 render): linen, canvas and wool. Seen from both sides; a woven
// grain close up; `stripe` > 0 paints bands `stripe` metres wide of the second colour (awnings
// across their width); the sun shines a little through thin cloth (`thin`).
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/urbs/urbs_common.gdshaderinc"

uniform vec4 base_colour : source_color = vec4(0.88, 0.82, 0.66, 1.0);
uniform vec4 stripe_colour : source_color = vec4(0.70, 0.22, 0.16, 1.0);
uniform float stripe = 0.0;
uniform float thin = 0.25;
uniform float rough = 0.95;

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
	vec3 col = base_colour.rgb;
	if (stripe > 0.0) {
		float s = fract(uv.x / stripe);
		float w = fp / stripe;
		float band = smoothstep(0.5 - w, 0.5 + w, s) * (1.0 - smoothstep(1.0 - w, 1.0, s));
		band = mix(0.5, band, u_detail(stripe, fp));
		col = mix(col, stripe_colour.rgb, band);
	}
	float keep = u_detail(0.006, fp);
	float weave = (sin(uv.x * 900.0) * sin(uv.y * 900.0)) * 0.5 + 0.5;
	col *= 1.0 + (weave - 0.5) * 0.12 * keep;
	col *= 0.9 + 0.2 * u_fbm3(p, 1.5, fp);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.2;
	BACKLIGHT = col * thin;
	NORMAL = u_bump(n, t, b, vec2(0.0), MODEL_MATRIX, VIEW_MATRIX);
}
