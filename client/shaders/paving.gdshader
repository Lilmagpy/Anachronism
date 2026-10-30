// City ground (city graphics, D-271, D-280): flagstones in the squares, cobbles in the streets,
// beaten earth with worn ruts in the yards - by the instance colour's alpha (1 square, 0.66
// street, 0.33 earth). Drawn in world space, so neighbouring tiles join without seams. Lit
// flat like the storybook terrain around it; dissolves with distance by itself (D-123).
shader_type spatial;
render_mode unshaded;

#include "res://shaders/lod.gdshaderinc"

varying vec4 ground;
varying vec3 world;

void vertex() {
	ground = COLOR;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lod_distance = length(CAMERA_POSITION_WORLD - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// soft joint lines about a pixel wide at any distance
float joint(float v, float width) {
	float d = abs(fract(v) - 0.5);
	float w = max(fwidth(v), 1e-4);
	return 1.0 - smoothstep(0.5 - width - w, 0.5 - width + w, d);
}

void fragment() {
	if (lod_keep(lod_distance) <= lod_dither(FRAGCOORD.xy)) {
		discard;
	}
	vec2 p = world.xz;
	vec3 c = ground.rgb;
	if (ground.a > 0.8) {
		// a square: large flagstones in staggered rows, each its own shade
		vec2 q = p * 2.2;
		q.x += floor(q.y) * 0.5;
		float lines = max(joint(q.y, 0.46), joint(q.x, 0.46));
		c *= 0.9 + 0.16 * hash(floor(q));
		c *= 1.0 - 0.3 * lines;
	} else if (ground.a > 0.5) {
		// a street: small cobbles, rounded and uneven
		vec2 q = p * 6.5;
		q.x += floor(q.y) * 0.5;
		vec2 f = fract(q) - 0.5;
		float stone = smoothstep(0.5, 0.32, length(f * vec2(1.0, 1.25)));
		c *= mix(0.78, 1.0 + 0.1 * hash(floor(q)), stone);
	} else {
		// beaten earth: dusty patches and darker worn ground
		c *= 0.88 + 0.16 * noise(p * 1.5) + 0.06 * noise(p * 9.0);
	}
	c = pow(c, vec3(2.2)) * 0.9;   // unshaded under the filmic tonemap: a shade below the sunlit land
	ALBEDO = c;
}
