// Urbs (U8 render): the sky over Rome. A deep blue zenith falling quickly to a pale, hazy
// horizon (the Rome Reborn look the owner asked for, made from our own gradient), the sun's
// halo (forward scattering), a warm band on the sun's side of the horizon when it is low, and
// the sun's disc itself (not in the radiance pass, so it never makes fireflies on metal).
// atmosphere.gd sets the colours by the sun's elevation; the direction is the scene's sun.
shader_type sky;
render_mode use_half_res_pass;

uniform vec4 zenith : source_color = vec4(0.16, 0.36, 0.72, 1.0);
uniform vec4 horizon : source_color = vec4(0.70, 0.80, 0.90, 1.0);
uniform vec4 ground : source_color = vec4(0.36, 0.34, 0.30, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.85, 0.65, 1.0);
uniform float energy = 1.0;
uniform float haze = 0.6;        // how much the horizon band brightens
uniform float sunset = 0.0;      // the warm band on the sun's side (0 at noon, 1 at sunset)
uniform float disc = 40.0;       // brightness of the sun's disc

void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, 0.0, 1.0);
	vec3 z = zenith.rgb;
	vec3 h = horizon.rgb;
	vec3 col = mix(h, z, 1.0 - pow(1.0 - up, 3.2));
	col = mix(col, h * 1.08, haze * exp(-up * 16.0));
	if (LIGHT0_ENABLED) {
		vec3 s = LIGHT0_DIRECTION;
		float cs = max(dot(d, s), 0.0);
		float mie = pow(cs, 5.0) * 0.18 + pow(cs, 48.0) * 0.5;
		col += glow.rgb * mie * (0.35 + 0.65 * exp(-up * 3.0)) * LIGHT0_ENERGY * 0.5;
		vec2 dh = d.xz / max(length(d.xz), 1e-4);
		vec2 sh = s.xz / max(length(s.xz), 1e-4);
		float side = max(dot(dh, sh), 0.0);
		col += glow.rgb * sunset * (0.25 + 0.75 * pow(side, 3.0)) * exp(-up * 7.0) * 0.7;
		if (!AT_CUBEMAP_PASS) {
			float sun_d = 1.0 - smoothstep(0.99996, 0.99999, dot(d, s));
			col += LIGHT0_COLOR * LIGHT0_ENERGY * disc * (1.0 - sun_d);
		}
	}
	if (d.y < 0.0) {
		col = mix(h * 0.92, ground.rgb, smoothstep(0.0, 0.1, -d.y));
	}
	COLOR = col * energy;
}
