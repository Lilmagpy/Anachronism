// House walls (G1): the instance's wall colour with a timber frame line, small dark windows
// and a door on the long sides, so boxes read as buildings. Soft light bands.
shader_type spatial;

varying vec3 wall;
varying vec3 local_normal;

void vertex() {
	wall = COLOR.rgb;
	local_normal = NORMAL;
}

void fragment() {
	vec3 c = pow(wall, vec3(2.2));
	vec2 uv = fract(UV * vec2(3.0, 2.0));   // BoxMesh faces share the atlas: 3 x 2
	bool side = abs(local_normal.y) < 0.5;
	if (side) {
		// windows: two little squares up high
		float wx = abs(fract(uv.x * 2.0) - 0.5);
		float win = step(wx, 0.14) * step(0.42, uv.y) * step(uv.y, 0.68);
		// a door at the middle, low down, on the long faces only
		float door = step(abs(uv.x - 0.5), 0.1) * step(0.7, uv.y) * step(abs(local_normal.z), 0.5);
		c = mix(c, vec3(0.08, 0.06, 0.05), max(win, door) * 0.85);
		// a darker plinth and a timber line under the eaves
		c *= mix(0.78, 1.0, step(uv.y, 0.86));
		c = mix(c, c * 0.6, step(uv.y, 0.06));
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.40 + 0.35 * smoothstep(-0.05, 0.1, ndl) + 0.2 * smoothstep(0.45, 0.6, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
