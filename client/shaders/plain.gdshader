// Plain painted parts of towns (palaces, terraces, columns, tents, banners): the instance's
// colour, soft light bands like the rest of the map, and the self-dissolve with distance
// (the built-in fade left them half see-through, D-279).
shader_type spatial;

#include "res://shaders/lod.gdshaderinc"

varying float local_y;

void vertex() {
	lod_distance = length(CAMERA_POSITION_WORLD - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	local_y = VERTEX.y;
}

void fragment() {
	if (lod_keep(lod_distance) <= lod_dither(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * 0.92;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.42 + 0.33 * smoothstep(-0.05, 0.1, ndl) + 0.22 * smoothstep(0.45, 0.6, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
