// Map lines (borders, rivers) that keep the same thickness on screen at every zoom.
// Each vertex sits on the line's centre; UV2 holds the sideways direction (times -1 or +1),
// and UV.x the line's width as a fraction of the camera distance. UV.y is the distance
// along the line, for dashed lines that flow from start to end.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float lift = 0.0015;  // raise lines above the ground, also relative to distance
uniform float dash = 0.0;     // dashes per screen-width-ish; 0 for a solid line
uniform float flow = 0.6;     // how fast dashes run along the line
uniform float near_fade = 0.0;   // fade out when the camera comes closer than this

varying vec4 colour;
varying float along;
varying float camera_distance;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(CAMERA_POSITION_WORLD - world);
	VERTEX.xz += UV2 * UV.x * d;
	VERTEX.y += lift * d + 0.05;
	colour = COLOR;
	along = UV.y;
	camera_distance = d;
}

void fragment() {
	float a = colour.a;
	if (dash > 0.0) {
		float phase = fract(along * dash / max(camera_distance, 1.0) - TIME * flow);
		a *= smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.55, 0.63, phase));
	}
	if (near_fade > 0.0) {
		a *= smoothstep(near_fade * 0.6, near_fade, camera_distance);
	}
	ALBEDO = colour.rgb;
	ALPHA = a;
}
