// The ground of the settlements (D-281): trodden earth, lanes, streets, squares, yards and the
// worn apron round every building, draped over the terrain as soft, feathered, alpha-blended
// skins so the buildings grow out of the land instead of standing on it.
//
// The mesh (scripts/city/ground.gd) carries, per vertex:
//   COLOR.rgb  the local earth colour (it differs by people: dusty, red, grey-brown ...),
//   COLOR.a    strength 0..1 (also 0 over water),
//   UV         shape coordinates (see `shape`),
//   UV2        (surface kind, shape).
// Shapes: 0 road ribbon (UV.x across -1..1, UV.y along), 1 area rim (UV.x 0 inside .. 1 outer
// edge), 2 patch (UV.x 0 centre .. 1 edge, UV.y a random angle), 3 building apron (UV.x 0 at
// the wall .. 1 at the outer edge, UV.y the distance from the wall in map units).
// Surface kinds: 0 earth, 1 dirt, 2 cobble, 3 flag, 4 sand, 5 garden, 6 grass, 7 trampled
// grass (round tents), 8 contact shadow at a wall's foot.
//
// Lit with the terrain's own soft light bands, so a skin reads as part of the same painting.
// It fades by itself with the camera's distance, as the buildings do (the file name ends in
// "paving" so scripts/lod.gd treats it like the other self-dissolving shaders, but it keeps its
// own fade because a skin spans many buildings).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform float fade_near = 320.0;   // shown nearer than this, fading just beyond

const float CORE = 0.5555556;      // a road's surface as a share of its ribbon (the rest is verge)

varying vec3 world;
varying vec4 tint;
varying vec2 coord;
varying vec2 kind_shape;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = COLOR;
	coord = UV;
	kind_shape = UV2;
	// a bias towards the camera, growing with distance, keeps the skin from sinking into the
	// terrain's facets (the mesh also lies a hair above the ground)
	vec3 to_camera = CAMERA_POSITION_WORLD - world;
	float far = length(to_camera);
	VERTEX += normalize(to_camera) * (0.004 + 0.0007 * far);
}

// soft joint lines about a pixel wide at any distance
float joint(float v, float width) {
	float d = abs(fract(v) - 0.5);
	float w = max(fwidth(v), 1e-4);
	return 1.0 - smoothstep(0.5 - width - w, 0.5 - width + w, d);
}

// beaten earth: dusty variation, small pebbles, darker worn patches
vec3 earth_colour(vec3 base, vec2 p, float n1, float n2) {
	vec3 c = base * (0.88 + 0.2 * n1 + 0.08 * n2);
	float peb = hash(floor(p * 26.0));
	c *= 1.0 - 0.14 * step(0.93, peb) + 0.1 * step(0.985, peb);
	return c;
}

// fine, irregular cobbles: jittered cells, low contrast, melting to their average far off
vec3 cobble_colour(vec3 base, vec2 p) {
	vec2 q = p * 11.0;
	vec2 id = floor(q);
	vec2 f = fract(q);
	float best = 9.0;
	float second = 9.0;
	float tone = 0.5;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash(id + g), hash(id + g + 17.0));
			float d = length(g + 0.15 + 0.7 * o - f);
			if (d < best) {
				second = best;
				best = d;
				tone = hash(id + g + 5.0);
			} else if (d < second) {
				second = d;
			}
		}
	}
	float w = max(fwidth(q.x), 1e-3);
	float edge = smoothstep(0.0, 0.12 + w, second - best);
	vec3 st = mix(vec3(0.72, 0.68, 0.60), base, 0.3) * (0.94 + 0.1 * tone);
	vec3 gap = st * 0.86;
	vec3 sharp = mix(gap, st, edge);
	vec3 avg = st * 0.96;
	return mix(sharp, avg, smoothstep(0.25, 0.6, w));
}

// flagstones: larger staggered slabs, thin joints, gentle tone changes
vec3 flag_colour(vec3 base, vec2 p) {
	vec2 q = p * 3.0;
	q.x += floor(q.y) * 0.5 + hash(vec2(floor(q.y), 3.0)) * 0.3;
	float w = max(fwidth(q.x), 1e-3);
	float lines = max(joint(q.y, 0.485), joint(q.x, 0.485));
	vec3 st = mix(vec3(0.82, 0.78, 0.68), base, 0.18) * (0.95 + 0.08 * hash(floor(q)));
	return mix(st * (1.0 - 0.14 * lines), st * 0.97, smoothstep(0.25, 0.6, w));
}

void fragment() {
	float dist = length(CAMERA_POSITION_WORLD - world);
	float keep = 1.0 - smoothstep(fade_near, fade_near * 1.22, dist);
	if (keep <= 0.0) {
		discard;
	}
	vec2 p = world.xz;
	float n1 = noise(p * 2.3);
	float n2 = noise(p * 7.0);
	float n3 = noise(p * 19.0);
	int kind = int(kind_shape.x + 0.5);
	int shape = int(kind_shape.y + 0.5);
	vec3 base = tint.rgb;
	bool paved = kind == 2 || kind == 3;

	// t: 0 on the surface itself .. 1 at the outer edge of its feathered skirt
	float t = 0.0;
	float ragged = 0.55;
	float along = 0.0;
	float across = 0.0;
	if (shape == 0) {
		across = abs(coord.x);
		along = coord.y;
		t = clamp((across - CORE) / (1.0 - CORE), 0.0, 1.0);
	} else if (shape == 1) {
		t = coord.x;
	} else if (shape == 2) {
		t = clamp((coord.x - 0.3) / 0.7, 0.0, 1.0);
		ragged = 0.8;
	} else {
		t = coord.x;
	}

	// the surface
	float dry = smoothstep(0.76, 0.84, base.r);   // sandier peoples keep more bare earth
	float green_share = mix(0.55, 0.15, dry);
	vec3 c = earth_colour(base, p, n1, n2);
	float wall_dist = shape == 3 ? coord.y : 1.0;
	if (kind == 1) {
		c = earth_colour(base * 1.04, p, n1, n2);
		if (shape == 0) {
			// wheel ruts either side of a grassy hump, broken here and there
			float broken = smoothstep(0.25, 0.55, noise(vec2(along * 1.3, across * 3.0) + 7.0));
			float rut = (1.0 - smoothstep(0.0, 0.07, abs(across - 0.3 * CORE * 1.5))) * broken;
			c *= 1.0 - 0.2 * rut;
			float hump = (1.0 - smoothstep(0.0, 0.16, across)) * smoothstep(0.35, 0.65, n2);
			c = mix(c, c * vec3(0.78, 0.95, 0.5), hump * 0.55);
			float worn = 1.0 - smoothstep(0.0, 0.5 * CORE, across);
			c *= 1.0 + 0.05 * worn;
		}
	} else if (kind == 2) {
		c = mix(earth_colour(base, p, n1, n2), cobble_colour(base, p), 1.0 - smoothstep(0.0, 0.3, t + (n1 - 0.5) * 0.3));
	} else if (kind == 3) {
		c = mix(earth_colour(base, p, n1, n2), flag_colour(base, p), 1.0 - smoothstep(0.0, 0.3, t + (n1 - 0.5) * 0.3));
	} else if (kind == 4) {
		vec3 sand = mix(vec3(0.93, 0.83, 0.60), base, 0.22);
		float ripple = sin(p.x * 9.0 + p.y * 5.0 + n1 * 6.0) * 0.5 + 0.5;
		c = sand * (0.92 + 0.1 * n1 + 0.05 * ripple);
	} else if (kind == 5) {
		// dug beds: rows of dark soil with green sprouts, turned by a random angle
		float a = coord.y;
		vec2 q = vec2(cos(a) * p.x - sin(a) * p.y, sin(a) * p.x + cos(a) * p.y) * 9.0;
		float row = smoothstep(0.25, 0.5, abs(fract(q.x) - 0.5));
		vec3 soil = vec3(0.40, 0.29, 0.18) * (0.9 + 0.2 * n2);
		vec3 shoot = vec3(0.34, 0.55, 0.20) * (0.85 + 0.3 * n3);
		c = mix(soil * 0.8, mix(soil, shoot, 0.55 * step(0.45, noise(q * vec2(0.4, 3.0)))), row);
	} else if (kind == 6) {
		vec3 g = vec3(0.30, 0.52, 0.20);
		c = g * (0.82 + 0.3 * n2 + 0.12 * n3);
		c = mix(c, c * vec3(1.15, 1.1, 0.8), smoothstep(0.55, 0.8, n1) * 0.5);
	} else if (kind == 7) {
		// round tents: bare earth by the felt, then flattened, yellowed grass
		vec3 bare = earth_colour(base, p, n1, n2);
		vec3 flat_grass = vec3(0.56, 0.58, 0.30) * (0.88 + 0.2 * n2);
		c = mix(bare, flat_grass, smoothstep(0.05, 0.5, t + (n1 - 0.5) * 0.3));
	} else if (kind == 8) {
		c = vec3(0.16, 0.11, 0.07);
	}

	// feathered edge: ragged, noisy, never a line
	float a = 1.0 - smoothstep(0.0, 1.0, t + (n1 - 0.5) * ragged + (n3 - 0.5) * 0.25 * ragged);
	if (shape == 0 && !paved) {
		a = 1.0 - smoothstep(0.1, 1.0, t + (n1 - 0.5) * ragged * 0.8);
	}
	if (shape == 2) {
		// worn patches thin out into speckled grass at the edge, however strong
		a = 1.0 - smoothstep(0.35, 1.0, t + (n1 - 0.5) * ragged + (n3 - 0.5) * 0.3);
	}
	if (shape == 3) {
		a = (1.0 - smoothstep(0.1, 1.0, t + (n1 - 0.5) * 0.9 + (n3 - 0.5) * 0.4)) * 0.9;
		// fake ambient occlusion: a dark band tight against the wall, and a softer one beyond
		float ao = 1.0 - smoothstep(0.0, 0.16, wall_dist);
		float soft = 1.0 - smoothstep(0.0, 0.55, wall_dist);
		c *= 1.0 - 0.3 * ao - 0.06 * soft;
		a = max(a, 0.5 * ao);
	}
	if (kind == 8) {
		a = pow(1.0 - clamp(t, 0.0, 1.0), 2.0) * 0.34 * (0.7 + 0.6 * n1);
	}
	// worn ground is patchy: grass survives in the gaps (not in paved places)
	float patchy = smoothstep(0.2, 0.55, 0.55 * n1 + 0.3 * n2 + 0.15 * n3 + 0.12 + 0.25 * tint.a);
	if (kind == 0 && shape != 0) {
		a *= mix(1.0, patchy, 0.8 * (1.0 - dry * 0.5));
	}
	if (kind == 1 && shape == 0) {
		a *= mix(1.0, patchy, 0.35);
	}
	// grass creeping in at the margins of earth: the ragged edge reads as thinning ground
	if (kind <= 1 || kind == 7) {
		c = mix(c, c * vec3(0.9, 1.0, 0.7), smoothstep(0.2, 1.0, t) * 0.6);
		c = mix(c, vec3(0.42, 0.58, 0.27) * (0.9 + 0.2 * n2), green_share * (0.25 + 0.5 * smoothstep(0.0, 1.0, t)));
	}
	float own_alpha = tint.a;
	if (kind == 9) {
		// a farm field: furrows along its length in the crop colour, a darker bank at the rim
		float row = step(0.5, fract(coord.x * 8.0));
		float soft = 0.5 + 0.5 * smoothstep(0.1, 0.9, noise(p * 3.0));
		c = base * (0.8 + 0.28 * row) * (0.92 + 0.12 * n2) * soft + base * 0.2;
		float inside = smoothstep(0.35, 0.95, tint.a);
		c = mix(base * 0.55, c, inside);
		a = 1.0;
		own_alpha = smoothstep(0.0, 0.45, tint.a);
	}
	ALBEDO = pow(c, vec3(2.2));
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
	ALPHA = clamp(a * own_alpha * keep, 0.0, 1.0);
}

// The terrain's soft light bands, so the ground sits in the same light as the land round it.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.32 + 0.30 * smoothstep(-0.05, 0.15, ndl) + 0.25 * smoothstep(0.45, 0.65, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
