// Cartoon props (trees, buildings): the instance colour paints the model, except parts the
// mesh marks red in its vertex colour (tree trunks), which stay brown. Toon light bands.
shader_type spatial;

varying vec3 paint;

void vertex() {
	paint = COLOR.r > 0.5 ? vec3(0.45, 0.30, 0.18) : INSTANCE_CUSTOM.rgb;
}

void fragment() {
	ALBEDO = pow(paint, vec3(2.2));
	ROUGHNESS = 0.85;
	SPECULAR = 0.1;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.40 + 0.35 * smoothstep(-0.05, 0.1, ndl) + 0.2 * smoothstep(0.45, 0.6, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
