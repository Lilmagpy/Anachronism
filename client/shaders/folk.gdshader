// Houses in each civilisation's own style (D-275): walls and trim keep their vertex colours;
// roofs (vertex alpha 0) take the instance's colour from its custom data, so a town's roofs
// can wear its owner's colour. Soft light bands like the rest of the map; dissolves with
// distance itself (the built-in fade hides custom shaders, D-123).
shader_type spatial;

#include "res://shaders/lod.gdshaderinc"

varying vec4 paint;
varying float local_y;

void vertex() {
	paint = INSTANCE_CUSTOM;
	local_y = VERTEX.y;
	lod_distance = length(CAMERA_POSITION_WORLD - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
}

void fragment() {
	if (lod_keep(lod_distance) <= lod_dither(FRAGCOORD.xy)) {
		discard;
	}
	vec3 own = COLOR.rgb;
	float shade = dot(own, vec3(0.3, 0.59, 0.11));
	// a roof: the instance colour, keeping the light and dark of the modelled tiles
	vec3 roof = paint.rgb * clamp(0.55 + shade * 0.9, 0.55, 1.15);
	vec3 c = mix(roof, own, step(0.5, COLOR.a));
	c = pow(c, vec3(2.2));
	c *= mix(0.78, 1.0, smoothstep(0.0, 0.25, local_y));   // darker at the foot
	ALBEDO = c * 0.9;
	ROUGHNESS = 0.88;
	SPECULAR = 0.12;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.42 + 0.33 * smoothstep(-0.05, 0.1, ndl) + 0.22 * smoothstep(0.45, 0.6, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
