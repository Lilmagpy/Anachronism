// Real-Earth terrain painted in a bright cartoon style (D-059).
//
// The satellite image is only used to tell what grows where (forest, grassland, steppe,
// desert); each is then painted in a flat, cheerful colour. Height gives rock and snow,
// the sea floor is painted by depth with foam along the coasts, and the light falls in soft
// bands (toon shading) so hills read like an illustrated map. Owners tint their lands.
shader_type spatial;

uniform sampler2D colour_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D political : source_color, filter_linear, repeat_disable;
uniform float tint = 0.30;
uniform float metres_per_unit = 350.0;
uniform float land_lift = 0.5;
uniform float sea_depth_scale = 0.25;

const vec3 GRASS = vec3(0.47, 0.69, 0.33);
const vec3 MEADOW = vec3(0.58, 0.75, 0.38);
const vec3 FOREST = vec3(0.27, 0.52, 0.27);
const vec3 STEPPE = vec3(0.74, 0.71, 0.50);
const vec3 DESERT = vec3(0.86, 0.77, 0.60);
const vec3 ROCK = vec3(0.62, 0.56, 0.50);
const vec3 SNOW = vec3(0.96, 0.97, 1.00);
const vec3 SHALLOW = vec3(0.33, 0.83, 0.86);
const vec3 SEA = vec3(0.16, 0.52, 0.82);
const vec3 DEEP = vec3(0.09, 0.30, 0.62);

varying float height;
varying vec3 world_normal;

void vertex() {
	height = VERTEX.y;
	world_normal = NORMAL;
}

void fragment() {
	// Thresholds below are in everyday (sRGB) colour values; the GPU hands us linear ones.
	vec3 sat = pow(texture(colour_map, UV).rgb, vec3(1.0 / 2.2));
	vec3 colour;
	if (height < 0.0) {
		float depth = -((height + land_lift) * metres_per_unit / sea_depth_scale);
		colour = mix(SHALLOW, SEA, smoothstep(10.0, 250.0, depth));
		colour = mix(colour, DEEP, smoothstep(600.0, 3500.0, depth));
		colour = mix(vec3(0.93, 0.98, 0.97), colour, smoothstep(0.0, 25.0, depth));  // foam
	} else {
		float metres = (height - land_lift) * metres_per_unit;
		float lum = dot(sat, vec3(0.3, 0.59, 0.11));
		float veg = clamp((sat.g - sat.r) * 7.0 + 0.55, 0.0, 1.0);
		float dark = 1.0 - smoothstep(0.16, 0.32, lum);
		vec4 w = vec4(
			veg * dark,                                         // forest
			veg * (1.0 - dark),                                 // grass
			(1.0 - veg) * (1.0 - smoothstep(0.42, 0.62, lum)),  // steppe
			(1.0 - veg) * smoothstep(0.42, 0.62, lum));         // desert
		w /= max(w.x + w.y + w.z + w.w, 0.001);
		vec3 grass = mix(GRASS, MEADOW, smoothstep(0.25, 0.4, lum));
		colour = FOREST * w.x + grass * w.y + STEPPE * w.z + DESERT * w.w;
		float slope = 1.0 - world_normal.y;
		colour = mix(colour, ROCK, smoothstep(1800.0, 3200.0, metres) * 0.8 + smoothstep(0.25, 0.5, slope) * 0.4);
		// high plateaus are brown alpine grassland; only the highest peaks keep snow
		colour = mix(colour, vec3(0.66, 0.60, 0.44), smoothstep(3300.0, 4200.0, metres) * 0.7);
		float snow = smoothstep(5200.0, 5800.0, metres) + smoothstep(4500.0, 5200.0, metres) * smoothstep(0.6, 0.8, lum);
		colour = mix(colour, SNOW, clamp(snow, 0.0, 1.0));
		colour = mix(colour, vec3(dot(colour, vec3(0.3, 0.59, 0.11))), 0.12);  // a little softer
		vec4 owner = texture(political, UV);
		colour = mix(colour, owner.rgb, owner.a * tint);
	}
	ALBEDO = pow(colour, vec3(2.2));  // paint colours are sRGB; lighting wants linear
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}

// Soft light bands instead of smooth shading: the cartoon look.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.30 + 0.32 * smoothstep(-0.05, 0.1, ndl) + 0.22 * smoothstep(0.45, 0.6, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
