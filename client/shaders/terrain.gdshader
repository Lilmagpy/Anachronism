// Real-Earth terrain painted in a bright, lush storybook style (D-059, graphics pass G1).
//
// The satellite image only tells what grows where (forest, grassland, steppe, desert); each
// is painted in rich colour with a little painterly variation. Height gives rock and snow.
// The coastline comes from a smooth land mask (not the height grid), with a sand beach and
// a ring of surf. Owned land is tinted lightly, and glows in its owner's colour along its
// borders, as on a strategy map.
shader_type spatial;

uniform sampler2D colour_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D political : source_color, filter_linear, repeat_disable;
uniform sampler2D coast : filter_linear, repeat_disable;
uniform sampler2D coast_soft : filter_linear, repeat_disable;
uniform float tint = 0.06;
uniform float edge_tint = 0.75;
uniform float metres_per_unit = 350.0;
uniform float land_lift = 0.5;
uniform float sea_depth_scale = 0.25;

const vec3 GRASS = vec3(0.38, 0.64, 0.26);
const vec3 MEADOW = vec3(0.52, 0.72, 0.31);
const vec3 FOREST = vec3(0.24, 0.53, 0.24);
const vec3 STEPPE = vec3(0.70, 0.71, 0.42);
const vec3 DESERT = vec3(0.93, 0.80, 0.55);
const vec3 ROCK = vec3(0.60, 0.55, 0.50);
const vec3 SNOW = vec3(0.97, 0.98, 1.00);
const vec3 SAND = vec3(0.96, 0.89, 0.66);
const vec3 SHALLOW = vec3(0.30, 0.86, 0.85);
const vec3 SEA = vec3(0.12, 0.55, 0.82);
const vec3 DEEP = vec3(0.07, 0.30, 0.62);

varying float height;
varying vec3 world_normal;
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	height = VERTEX.y;
	world_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 sea_colour(float depth, float near_coast) {
	vec3 c = mix(SHALLOW, SEA, smoothstep(5.0, 220.0, depth));
	c = mix(c, DEEP, smoothstep(600.0, 3500.0, depth));
	// shallows along every coast, whatever the depth data says
	return mix(c, SHALLOW, smoothstep(0.08, 0.45, near_coast) * 0.85);
}

void fragment() {
	vec3 sat = pow(texture(colour_map, UV).rgb, vec3(1.0 / 2.2));
	float mask = texture(coast, UV).r;
	float aa = max(fwidth(mask) * 1.5, 0.02);
	float land = smoothstep(0.5 - aa, 0.5 + aa, mask);
	float near_coast = texture(coast_soft, UV).r;   // 0 open sea .. 1 inland
	float wobble = noise(world_pos.xz * 0.9) * 0.6 + noise(world_pos.xz * 3.1) * 0.4;
	float depth = height < 0.0 ? -((height + land_lift) * metres_per_unit / sea_depth_scale) : 0.0;
	vec3 sea = sea_colour(depth, near_coast);
	// surf: a broken white ring just off the beach
	float off = 1.0 - smoothstep(0.30, 0.5, mask);
	float surf = smoothstep(0.18, 0.32, mask) * off * smoothstep(0.35, 0.6, wobble + 0.15 * sin(TIME * 1.5 + world_pos.x * 0.3));
	sea = mix(sea, vec3(0.96, 1.0, 1.0), surf * 0.85);

	float metres = max(height - land_lift, 0.0) * metres_per_unit;
	float lum = dot(sat, vec3(0.3, 0.59, 0.11));
	// lush like an illustrated map: anything not plainly desert reads as green country
	float veg = clamp((sat.g - sat.r) * 7.0 + 0.85, 0.0, 1.0);
	float dark = 1.0 - smoothstep(0.14, 0.28, lum);
	vec4 w = vec4(
		veg * dark,                                         // forest
		veg * (1.0 - dark),                                 // grass
		(1.0 - veg) * (1.0 - smoothstep(0.45, 0.62, lum)),  // steppe
		(1.0 - veg) * smoothstep(0.45, 0.62, lum));         // desert
	w /= max(w.x + w.y + w.z + w.w, 0.001);
	vec3 grass = mix(GRASS, MEADOW, smoothstep(0.25, 0.4, lum) * 0.7 + wobble * 0.3);
	vec3 colour = FOREST * w.x + grass * w.y + STEPPE * w.z + DESERT * w.w;
	colour *= 0.92 + wobble * 0.16;   // painterly variation
	// close up, the grass gets texture: darker tufts, sunlit patches and a few flowers
	float near = 1.0 - smoothstep(60.0, 180.0, length(CAMERA_POSITION_WORLD - world_pos));
	if (near > 0.0) {
		float tuft = noise(world_pos.xz * 6.0) * 0.6 + noise(world_pos.xz * 17.0) * 0.4;
		float patch = noise(world_pos.xz * 1.7 + 11.0);
		float green = w.x + w.y;
		vec3 detailed = colour * (0.86 + tuft * 0.26);
		detailed = mix(detailed, detailed * vec3(1.08, 1.1, 0.85), smoothstep(0.55, 0.8, patch) * 0.6);
		float flower = step(0.93, hash(floor(world_pos.xz * 9.0))) * step(0.6, patch) * green;
		detailed = mix(detailed, mix(vec3(1.0, 0.95, 0.6), vec3(1.0, 0.75, 0.8), hash(floor(world_pos.xz * 9.0) + 3.0)), flower * 0.7);
		colour = mix(colour, detailed, near);
	}
	float slope = 1.0 - world_normal.y;
	colour = mix(colour, ROCK, smoothstep(1800.0, 3200.0, metres) * 0.8 + smoothstep(0.25, 0.5, slope) * 0.45);
	colour = mix(colour, vec3(0.66, 0.60, 0.44), smoothstep(3300.0, 4200.0, metres) * 0.6);
	float snow = smoothstep(4600.0, 5400.0, metres) + smoothstep(3800.0, 4600.0, metres) * smoothstep(0.55, 0.75, lum);
	snow += smoothstep(2600.0, 3400.0, metres) * smoothstep(0.35, 0.6, world_normal.y) * 0.5;  // snowy caps on high ridges
	colour = mix(colour, SNOW, clamp(snow, 0.0, 1.0));
	// a sand beach along the shore (not on cliffs)
	float beach = (1.0 - smoothstep(0.5, 0.62, mask)) * (1.0 - smoothstep(150.0, 400.0, metres));
	colour = mix(colour, SAND, beach * 0.9);

	// owners: a light wash inside, a strong glow along the border
	vec2 texel = 1.0 / vec2(textureSize(political, 0));
	vec4 owner = texture(political, UV);
	float edge = 0.0;
	for (int r = 1; r <= 2; r++) {
		for (int k = 0; k < 8; k++) {
			float a = float(k) * 0.785398;
			vec2 d = vec2(cos(a), sin(a)) * texel * 2.5 * float(r);
			// the sea is no frontier: only land of another owner (or none) counts
			if (texture(coast, UV + d).r < 0.9) continue;
			vec4 o = texture(political, UV + d);
			float differs = length(o.rgb * o.a - owner.rgb * owner.a);
			edge = max(edge, smoothstep(0.05, 0.3, differs) * (r == 1 ? 1.0 : 0.55));
		}
	}
	edge *= owner.a;
	vec3 owned = mix(colour, mix(owner.rgb, vec3(1.0), 0.3), owner.a * tint);   // a pale wash: red over green turns rosy, not muddy
	owned = mix(owned, mix(owner.rgb, vec3(1.0), 0.15), edge * edge_tint);
	colour = mix(colour, owned, land);

	colour = mix(sea, colour, land);
	ALBEDO = pow(colour, vec3(2.2));
	ROUGHNESS = mix(0.35, 0.9, land);
	SPECULAR = mix(0.4, 0.1, land);
}

// Soft light bands instead of smooth shading: the illustrated-map look.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.32 + 0.30 * smoothstep(-0.05, 0.15, ndl) + 0.25 * smoothstep(0.45, 0.65, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
