// Map lines (borders, rivers) that keep the same thickness on screen at every zoom.
// Each vertex sits on the line's centre; UV2 holds the sideways direction (times -1 or +1),
// and UV.x the line's width as a fraction of the camera distance.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float lift = 0.0015;  // raise lines above the ground, also relative to distance

varying vec4 colour;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(CAMERA_POSITION_WORLD - world);
	VERTEX.xz += UV2 * UV.x * d;
	VERTEX.y += lift * d + 0.05;
	colour = COLOR;
}

void fragment() {
	ALBEDO = colour.rgb;
	ALPHA = colour.a;
}
