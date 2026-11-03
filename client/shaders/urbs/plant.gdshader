// Urbs material library (U8 render): trees and green (site_flora.gd). The species colour comes
// from the vertex colour, read as LINEAR albedo (times the MultiMesh instance tint); if a renderer hands over no colour
// (black), the uniform base colour stands in.
//   kind 0  foliage: the crown is a few smooth blobs, so the shader breaks it into clumps of
//           leaves (a clumped normal and colour), darkens the underside and the inside, lets
//           the sun shine a little through (BACKLIGHT), and sways it gently in the wind
//   kind 1  bark: vertical furrows (plane bark lighter and flaking, by its own colour)
// Like the rest of the library, every pattern fades to its average once it is a few pixels
// across.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/urbs/urbs_common.gdshaderinc"

uniform int kind = 0;
uniform vec4 base_colour : source_color = vec4(0.30, 0.40, 0.20, 1.0);
uniform float wind = 1.0;          // sway strength (0: still)
uniform float translucency = 0.35;
uniform float rough = 0.85;

varying vec3 tint;

void vertex() {
	vec3 s = u_scale(MODEL_MATRIX);
	vec3 origin = MODEL_MATRIX[3].xyz;
	if (kind == 0 && wind > 0.0) {
		// the higher in the crown, the more it moves; each tree its own phase
		float h = max(VERTEX.y * s.y, 0.0);
		float ph = dot(origin.xz, vec2(0.13, 0.17));
		float sway = sin(TIME * 1.1 + ph) * 0.6 + sin(TIME * 2.3 + ph * 1.7 + VERTEX.x) * 0.4;
		VERTEX.x += sway * 0.006 * h * wind / s.x;
		VERTEX.z += cos(TIME * 0.9 + ph) * 0.004 * h * wind / s.z;
	}
	u_pos = VERTEX * s;
	u_nrm = normalize(NORMAL / s);
	u_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = COLOR.rgb;
}

void fragment() {
	vec3 p = u_pos;
	vec3 n = normalize(u_nrm);
	float fp = u_footprint(p);
	// site_flora's species colours are linear albedo (pine crown 0.15, 0.22, 0.10)
	vec3 c = dot(tint, vec3(1.0)) > 0.01 ? tint : base_colour.rgb;
	vec3 t;
	vec3 b;
	u_frame(n, t, b);
	vec2 grad = vec2(0.0);
	if (kind == 0) {
		// clumps of leaves about 0.5 m across, then single leaves that only show close up
		vec3 q = p + u_wpos * 0.07;
		float clump = u_fbm3(q, 1.4, fp);
		float leaf = u_noise3(q * 22.0);
		float keep_c = u_detail(0.25, fp);
		float keep_l = u_detail(0.04, fp);
		c *= 0.82 + 0.36 * mix(0.5, clump, keep_c);
		c *= 1.0 + (leaf - 0.5) * 0.35 * keep_l;
		// sun-bleached tips on top, darker underside and inside
		c = mix(c, c * vec3(1.15, 1.12, 0.85), smoothstep(0.3, 0.9, n.y) * 0.4);
		float ao = mix(0.72, 1.0, smoothstep(-0.6, 0.7, n.y)) * mix(0.85, 1.0, clump);
		float h0 = clump;
		grad = vec2(u_fbm3(q + t * 0.06, 1.4, fp) - h0, u_fbm3(q + b * 0.06, 1.4, fp) - h0) * 6.0 * keep_c;
		ALBEDO = c * mix(1.0, ao, 0.5);
		AO = ao;
		BACKLIGHT = c * translucency;
		ROUGHNESS = rough;
		SPECULAR = 0.25;
	} else {
		vec2 uv = vec2(dot(p, t), dot(p, b));
		float keep = u_detail(0.05, fp);
		float furrow = u_noise2(vec2(uv.x * 16.0, uv.y * 1.3 + u_noise2(uv * 3.0)));
		float ridge = smoothstep(0.25, 0.7, furrow);
		c *= mix(0.9, 0.7 + 0.45 * ridge, keep);
		c *= 0.85 + 0.3 * u_fbm3(p, 1.5, fp);
		float hx = u_noise2(vec2((uv.x + 0.01) * 16.0, uv.y * 1.3 + u_noise2((uv + vec2(0.01, 0.0)) * 3.0)));
		grad = vec2((hx - furrow) * 1.5, 0.0) * keep;
		ALBEDO = c;
		ROUGHNESS = 0.95;
		SPECULAR = 0.2;
	}
	if (grad != vec2(0.0)) {
		NORMAL = u_bump(n, t, b, grad, MODEL_MATRIX, VIEW_MATRIX);
	}
}
