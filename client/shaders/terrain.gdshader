// Real-Earth terrain: satellite colour, tinted by who rules each province.
shader_type spatial;

uniform sampler2D colour_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D political : source_color, filter_linear, repeat_disable;
uniform float tint = 0.30;

void fragment() {
	vec3 ground = texture(colour_map, UV).rgb;
	vec4 owner = texture(political, UV);
	ALBEDO = mix(ground, owner.rgb, owner.a * tint);
	ROUGHNESS = 0.95;
}
