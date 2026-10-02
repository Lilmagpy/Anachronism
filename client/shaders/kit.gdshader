// Models from the Kenney CC0 kits (G1): their own texture or colour, with chosen parts
// repainted in the instance colour - the blue accents of buildings (roofs, flags) in their
// owner's colour, whole surfaces for foliage. The instance colour's alpha says how much.
// Soft light bands like the rest of the map.
shader_type spatial;

#include "res://shaders/lod.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 base_colour : source_color = vec4(1.0);
uniform bool textured = true;
uniform int recolour = 1;   // 0: keep, 1: blue accents, 2: the whole surface, 3: roofs

varying float local_y;

void vertex() {
	lod_distance = length(CAMERA_POSITION_WORLD - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	local_y = VERTEX.y;
}

void fragment() {
	if (lod_keep(lod_distance) <= lod_dither(FRAGCOORD.xy)) {
		discard;
	}
	vec3 c = textured ? texture(tex, UV).rgb : base_colour.rgb;
	vec3 s = pow(c, vec3(1.0 / 2.2));
	float w = 0.0;
	if (recolour == 1) {
		w = smoothstep(0.05, 0.16, s.b - max(s.r, s.g));
	} else if (recolour == 2) {
		w = 1.0;
	} else if (recolour == 3) {
		// the fantasy-town colour map: its roof and awning swatches (red, green) take the
		// instance colour; its cold blue-grey plaster is warmed to limewash
		w = (UV.x < 0.25 && UV.y > 0.75) ? 1.0 : 0.0;
		if (UV.x >= 0.125 && UV.x < 0.25 && UV.y >= 0.5 && UV.y < 0.75) {
			float l = dot(s, vec3(0.3, 0.59, 0.11));
			c = pow(l * vec3(1.08, 1.0, 0.86), vec3(2.2));
			s = pow(c, vec3(1.0 / 2.2));
		}
	}
	float lum = dot(s, vec3(0.3, 0.59, 0.11));
	vec3 target = COLOR.rgb * (recolour == 2 ? 1.0 : clamp(0.55 + lum * 0.7, 0.6, 1.15));
	vec3 painted = mix(c, pow(target, vec3(2.2)), w * COLOR.a);
	// a little darker at the foot, as if in each other's shadow
	painted *= mix(0.72, 1.0, smoothstep(0.0, 0.8, local_y));
	ALBEDO = painted * 0.86;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.42 + 0.33 * smoothstep(-0.05, 0.1, ndl) + 0.22 * smoothstep(0.45, 0.6, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
