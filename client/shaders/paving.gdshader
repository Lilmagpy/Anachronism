// City ground (city graphics, D-271): beaten earth, streets and squares in the instance's
// colour, lit flat like the storybook terrain around it, with a faint stone grain. Dissolves
// with distance by itself (D-123): the built-in fade hid whole cities' ground at once.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/lod.gdshaderinc"

varying vec3 ground;

void vertex() {
	ground = COLOR.rgb;
	lod_distance = length(CAMERA_POSITION_WORLD - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
}

float grain(vec2 p) {
	return fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	if (lod_keep(lod_distance) <= lod_dither(FRAGCOORD.xy)) {
		discard;
	}
	vec3 c = pow(ground, vec3(2.2));
	c *= 0.94 + 0.08 * grain(UV * 24.0);   // a little stone and dust texture
	c *= 0.9;   // unshaded under the filmic tonemap: kept a shade below the sunlit terrain so it reads as stone
	ALBEDO = c;
}
