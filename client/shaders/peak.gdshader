// Cartoon mountain peaks (step 2.11b, G1): vertex colours in soft light bands, like the
// rest of the map. They exaggerate the real relief so ranges read from afar, and settle into
// lower hills as the camera comes down, so they never wall off the towns beneath them.
shader_type spatial;

uniform float near = 40.0;    // camera distance at which peaks are lowest
uniform float far = 180.0;    // and from which they stand full height

varying vec3 colour;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float d = length(CAMERA_POSITION_WORLD - base);
	VERTEX.y *= mix(0.55, 1.0, smoothstep(near, far, d));
	colour = pow(COLOR.rgb, vec3(2.2));
}

void fragment() {
	ALBEDO = colour;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.40 + 0.30 * smoothstep(-0.1, 0.15, ndl) + 0.22 * smoothstep(0.45, 0.65, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
