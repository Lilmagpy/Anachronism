// Farm fields (G1): furrowed strips in the instance's crop colour, a darker hedge at the edge.
shader_type spatial;

varying vec3 crop;

void vertex() {
	crop = COLOR.rgb;
}

void fragment() {
	vec3 c = pow(crop, vec3(2.2));
	float rows = step(0.5, fract(UV.x * 7.0));
	c *= mix(0.82, 1.06, rows);
	vec2 e = min(UV, 1.0 - UV);
	float hedge = 1.0 - smoothstep(0.0, 0.06, min(e.x, e.y));
	c = mix(c, vec3(0.06, 0.16, 0.04), hedge * 0.8);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
}
