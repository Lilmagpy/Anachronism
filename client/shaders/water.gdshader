// The sea's surface: see-through over the painted sea floor, with slow rolling waves,
// cartoon glints where the sun catches them, and a brighter rim looking toward the horizon.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

uniform vec3 tint : source_color = vec3(0.04, 0.16, 0.32);
uniform float opacity = 0.42;
uniform float wave_scale = 0.035;   // waves per map unit
uniform float speed = 0.35;

varying vec3 world;

// cheap smooth value noise
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
	vec2 p = world.xz * wave_scale;
	float t = TIME * speed;
	float e = 0.08;
	float h = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t) - h;
	float hz = waves(p + vec2(0.0, e), t) - h;
	vec3 n = normalize(vec3(-hx * 3.0, 1.0, -hz * 3.0));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float facing = clamp(dot(normalize(CAMERA_POSITION_WORLD - world), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 3.0);
	// cartoon crests: thin bright bands where the wave field crosses a level
	float small = noise(p * 4.0 + vec2(t * 1.3, -t * 0.9));
	float crest = smoothstep(0.80, 0.82, small) * (1.0 - smoothstep(0.83, 0.87, small)) * (0.4 + h);
	// from high up the crests would scatter white squiggles over the whole sea: fade them out
	crest *= 1.0 - smoothstep(220.0, 520.0, distance(CAMERA_POSITION_WORLD, world));
	ALBEDO = mix(tint, vec3(0.55, 0.78, 0.92), rim * 0.6) + crest * 0.35;
	ALPHA = clamp(opacity + rim * 0.35 + crest * 0.3, 0.0, 0.95);
	ROUGHNESS = 0.2;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += (0.55 + 0.45 * ndl) * ATTENUATION * LIGHT_COLOR / PI;
	vec3 half_vector = normalize(LIGHT + VIEW);
	float glint = pow(clamp(dot(NORMAL, half_vector), 0.0, 1.0), 180.0);
	SPECULAR_LIGHT += step(0.35, glint) * LIGHT_COLOR * ATTENUATION * 0.9;   // hard-edged sparkle
}
