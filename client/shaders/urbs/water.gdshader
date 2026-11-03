// Urbs material library (U8 render): water. Small moving ripples on the normal (two layers
// of noise drifting apart), the sky reflected by Fresnel, a murky body colour (the Tiber is
// "flavus", yellow with silt: Horace, Odes 1.2.13; Virgil, Aen. 7.31).
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

#include "res://shaders/urbs/urbs_common.gdshaderinc"

uniform vec4 base_colour : source_color = vec4(0.42, 0.50, 0.40, 1.0);
uniform float clarity : hint_range(0.0, 1.0) = 0.15;
uniform float flow_speed = 0.3;

void vertex() {
	vec3 s = u_scale(MODEL_MATRIX);
	u_pos = VERTEX * s;
	u_nrm = normalize(NORMAL / s);
	u_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = u_wpos;
	vec3 n = vec3(0.0, 1.0, 0.0);
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, -1.0);
	float fp = u_footprint(p);
	float keep = u_detail(0.3, fp);
	vec2 a = p.xz * 0.9 + vec2(TIME * flow_speed, TIME * 0.1);
	vec2 c = p.xz * 2.3 - vec2(TIME * 0.2, TIME * flow_speed * 0.7);
	float h0 = u_noise2(a) + 0.5 * u_noise2(c);
	float hx = u_noise2(a + vec2(0.05, 0.0)) + 0.5 * u_noise2(c + vec2(0.05, 0.0));
	float hz = u_noise2(a + vec2(0.0, 0.05)) + 0.5 * u_noise2(c + vec2(0.0, 0.05));
	vec2 grad = vec2(hx - h0, hz - h0) * 3.0 * mix(0.25, 1.0, keep);
	vec3 nb = normalize(n - grad.x * t + grad.y * b);
	NORMAL = normalize(mat3(VIEW_MATRIX) * nb);
	ALBEDO = base_colour.rgb * 0.6;
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	ALPHA = mix(0.92, 0.75, clarity);
}
