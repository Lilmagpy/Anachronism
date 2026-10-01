// The sea's surface: clear over the painted sea floor near the coast, deepening to rich blue
// offshore, with slow swells, soft sun glints and a bright rim toward the horizon (G1).
// It thins out over the smooth coastline so beaches and surf show through.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

uniform vec3 tint : source_color = vec3(0.03, 0.20, 0.42);
uniform float opacity = 0.38;
uniform float wave_scale = 0.035;   // waves per map unit
uniform float speed = 0.35;
uniform sampler2D coast : filter_linear, repeat_disable;
uniform sampler2D coast_soft : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(1664.0, 1664.0);

varying vec3 world;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float waves(vec2 p, float t) {
	float h = noise(p + vec2(t * 0.6, t * 0.25)) * 0.6;
	h += noise(p * 2.3 - vec2(t * 0.4, t * 0.7)) * 0.3;
	h += noise(p * 5.1 + vec2(t, -t * 0.5)) * 0.1;
	return h;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world.xz + map_size * 0.5) / map_size;
	bool inside = uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0;
	float mask = inside ? texture(coast, uv).r : 0.0;
	float near_coast = inside ? texture(coast_soft, uv).r : 0.0;
	vec2 p = world.xz * wave_scale;
	float t = TIME * speed;
	float e = 0.08;
	float h = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t) - h;
	float hz = waves(p + vec2(0.0, e), t) - h;
	vec3 n = normalize(vec3(-hx * 2.0, 1.0, -hz * 2.0));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float facing = clamp(dot(normalize(CAMERA_POSITION_WORLD - world), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 3.0);
	// soft swell shading: lighter on wave tops
	float swell = smoothstep(0.35, 0.85, h);
	vec3 colour = mix(tint, tint * 1.6 + vec3(0.02, 0.06, 0.08), swell * 0.5);
	// broad painted swells on the open sea, readable from far away
	float broad = noise(world.xz * 0.012 + vec2(t * 0.03, t * 0.012)) * 0.65 + noise(world.xz * 0.031 - vec2(t * 0.02, 0.0)) * 0.35;
	float ridge = smoothstep(0.55, 0.62, broad) * (1.0 - smoothstep(0.64, 0.75, broad));
	colour = mix(colour, colour * 1.45 + vec3(0.03, 0.06, 0.07), ridge * 0.6 * (1.0 - clamp(near_coast * 2.0, 0.0, 1.0)));
	colour *= 0.88 + broad * 0.22;
	colour = mix(colour, vec3(0.55, 0.80, 0.95), rim * 0.55);
	ALBEDO = colour;
	// clear in the shallows, thinning to nothing over the coastline
	float clear = smoothstep(0.1, 0.45, near_coast);
	float alpha = opacity * (1.0 - clear * 0.75) + rim * 0.3;
	alpha *= 1.0 - smoothstep(0.42, 0.5, mask);
	ALPHA = clamp(alpha, 0.0, 0.92);
	ROUGHNESS = 0.15;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += (0.6 + 0.4 * ndl) * ATTENUATION * LIGHT_COLOR / PI;
	vec3 half_vector = normalize(LIGHT + VIEW);
	float glint = pow(clamp(dot(NORMAL, half_vector), 0.0, 1.0), 120.0);
	SPECULAR_LIGHT += smoothstep(0.25, 0.45, glint) * LIGHT_COLOR * ATTENUATION * 0.7;
}
