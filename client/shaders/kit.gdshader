// Models from the Kenney CC0 kits (G1): their own texture or colour, with chosen parts
// repainted in the instance colour - the blue accents of buildings (roofs, flags) in their
// owner's colour, whole surfaces for foliage. The instance colour's alpha says how much.
// Soft light bands like the rest of the map.
shader_type spatial;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 base_colour : source_color = vec4(1.0);
uniform bool textured = true;
uniform int recolour = 1;   // 0: keep, 1: blue accents, 2: the whole surface

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	vec3 c = textured ? texture(tex, UV).rgb : base_colour.rgb;
	vec3 s = pow(c, vec3(1.0 / 2.2));
	float w = 0.0;
	if (recolour == 1) {
		w = smoothstep(0.05, 0.16, s.b - max(s.r, s.g));
	} else if (recolour == 2) {
		w = 1.0;
	}
	float lum = dot(s, vec3(0.3, 0.59, 0.11));
	vec3 target = COLOR.rgb * (recolour == 2 ? 1.0 : clamp(0.55 + lum * 0.7, 0.6, 1.15));
	vec3 painted = mix(c, pow(target, vec3(2.2)), w * COLOR.a);
	// a little darker at the foot, as if in each other's shadow
	painted *= mix(0.72, 1.0, smoothstep(0.0, 0.8, local_y));
	ALBEDO = painted * 0.86;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.42 + 0.33 * smoothstep(-0.05, 0.1, ndl) + 0.22 * smoothstep(0.45, 0.6, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
