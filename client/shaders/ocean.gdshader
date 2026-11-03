// Open ocean beyond the map's edges, painted and lit like the map's own deep sea.
shader_type spatial;

const vec3 DEEP = vec3(0.09, 0.30, 0.62);

void fragment() {
	ALBEDO = pow(DEEP, vec3(2.2));
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.30 + 0.32 * smoothstep(-0.05, 0.1, ndl) + 0.22 * smoothstep(0.45, 0.6, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
