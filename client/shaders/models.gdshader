// Buildings from the model kit (D-280): each face's material (vertex alpha * 16) gets its own
// surface pattern, drawn in model space so it stays put on the model at any distance:
// roof tiles in rows, stone courses, brick bond, plaster mottling, timber grain, thatch
// streaks, felt weave. OWNER materials take the instance's colour (custom data) - a roof or a
// banner in its owner's colour. Soft light bands like the rest of the map; dissolves itself
// with distance (the built-in fade hides custom shaders, D-123).
shader_type spatial;

#include "res://shaders/lod.gdshaderinc"

varying vec3 local_pos;
varying vec3 local_normal;
varying vec4 owner;
varying float scale;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	owner = INSTANCE_CUSTOM;
	scale = length(MODEL_MATRIX[0].xyz);
	lod_distance = length(CAMERA_POSITION_WORLD - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// The face's own 2D coordinates: across it and up it (box mapping by the normal).
vec2 face_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y > a.x && a.y > a.z) {
		return p.xz;
	}
	if (a.x > a.z) {
		return vec2(p.z, p.y);
	}
	return vec2(p.x, p.y);
}

// Coordinates along a sloping roof: x across the slope, y down the slope.
vec2 roof_uv(vec3 p, vec3 n) {
	vec2 h = normalize(n.xz + vec2(1e-4));
	float across = dot(p.xz, vec2(-h.y, h.x));
	float down = dot(p.xz, h) - p.y * 0.0;
	return vec2(across, down + p.y * length(n.xz) / max(n.y, 0.2));
}

// Line weight that stays about a pixel wide whatever the distance (soft, no shimmer).
float line(float v, float width) {
	float d = abs(fract(v) - 0.5);
	float w = max(fwidth(v), 1e-4);
	return 1.0 - smoothstep(0.5 - width - w, 0.5 - width + w, d);
}

vec3 pattern(int id, vec3 base, vec3 p, vec3 n) {
	vec2 uv = face_uv(p, n);
	vec3 c = base;
	if (id == 0 || id == 6) {
		// roof tiles: rows down the slope, staggered joints, a darker lip at each row
		vec2 r = (n.y > 0.25 && n.y < 0.98) ? roof_uv(p, n) : uv;
		float row = r.y * 11.0;
		float col = r.x * 9.0 + floor(row) * 0.5;
		float lip = smoothstep(0.65, 1.0, fract(row));
		c *= 1.0 - 0.28 * lip;
		c *= 1.0 - 0.18 * line(col, 0.44);
		c *= 0.9 + 0.2 * hash(floor(vec2(col, row)));
	} else if (id == 1) {
		// plaster: soft mottling and a little grime near the ground
		c *= 0.93 + 0.1 * noise(uv * 9.0) + 0.04 * noise(uv * 31.0);
		c *= mix(0.82, 1.0, smoothstep(0.0, 0.25, p.y));
	} else if (id == 2) {
		// dressed stone: courses, staggered joints, each block its own shade
		float row = uv.y * 7.0;
		float col = uv.x * 4.0 + floor(row) * 0.5;
		c *= 1.0 - 0.32 * max(line(row, 0.45), line(col, 0.46));
		c *= 0.86 + 0.24 * hash(floor(vec2(col, row)));
	} else if (id == 3) {
		// fired brick: running bond, mortar lighter
		float row = uv.y * 16.0;
		float col = uv.x * 8.0 + floor(row) * 0.5;
		float mortar = max(line(row, 0.42), line(col, 0.45));
		c = mix(c * (0.85 + 0.25 * hash(floor(vec2(col, row)))), vec3(0.82, 0.78, 0.70), mortar * 0.7);
	} else if (id == 4) {
		// sun-dried brick under a worn render: big soft blocks showing through
		float row = uv.y * 8.0;
		float col = uv.x * 4.0 + floor(row) * 0.5;
		float worn = smoothstep(0.55, 0.8, noise(uv * 5.0));
		c *= 1.0 - 0.18 * worn * max(line(row, 0.44), line(col, 0.45));
		c *= 0.92 + 0.12 * noise(uv * 12.0);
	} else if (id == 5) {
		// timber: grain along the longest run, planks
		vec3 a = abs(n);
		float along = a.y > 0.5 ? p.x : (abs(p.y) > 0.0 ? p.y : p.x);
		float plank = (a.x > a.z ? p.z : p.x) * 14.0;
		c *= 0.88 + 0.12 * noise(vec2(along * 3.0, plank * 4.0));
		c *= 1.0 - 0.22 * line(plank, 0.46);
	} else if (id == 7) {
		// thatch: dense streaks down the slope, rough edge
		vec2 r = roof_uv(p, n);
		c *= 0.8 + 0.25 * noise(vec2(r.x * 60.0, r.y * 4.0));
		c *= 1.0 - 0.15 * line(r.y * 6.0, 0.4);
	} else if (id == 9) {
		c *= 1.1 + 0.15 * noise(uv * 20.0);
	} else if (id == 10 || id == 11) {
		c *= 0.92 + 0.08 * line(uv.x * 40.0, 0.3) + 0.06 * noise(uv * 20.0);
	} else if (id == 13) {
		// rammed earth: horizontal pour layers
		c *= 0.9 + 0.12 * noise(vec2(uv.x * 3.0, uv.y * 30.0));
		c *= 1.0 - 0.15 * line(uv.y * 9.0, 0.47);
	} else if (id == 14) {
		c *= 0.75 + 0.4 * noise(uv * 14.0);
	} else if (id == 15) {
		c = mix(c, vec3(0.75, 0.9, 1.0), 0.25 * noise(uv * 10.0 + TIME * 0.2));
	}
	return c;
}

void fragment() {
	if (lod_keep(lod_distance) <= lod_dither(FRAGCOORD.xy)) {
		discard;
	}
	int id = int(COLOR.a * 16.0);
	vec3 base = COLOR.rgb;
	if (id == 0 || id == 11) {   // the owner's colour, keeping the modelled light and dark
		float shade = dot(base, vec3(0.3, 0.59, 0.11));
		base = owner.rgb * clamp(0.35 + shade * 0.75, 0.4, 1.1);
	}
	vec3 c = pattern(id, base, local_pos, normalize(local_normal));
	c = pow(clamp(c, 0.0, 1.5), vec3(2.2));
	// ambient occlusion by height: darker at the foot, as if in each other's shadow
	c *= mix(0.72, 1.0, smoothstep(0.0, 0.35, local_pos.y));
	ALBEDO = c * 0.92;
	ROUGHNESS = id == 9 ? 0.4 : 0.88;
	SPECULAR = id == 9 ? 0.5 : 0.1;
	METALLIC = id == 9 ? 0.6 : 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = 0.40 + 0.35 * smoothstep(-0.05, 0.1, ndl) + 0.22 * smoothstep(0.45, 0.6, ndl);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
	if (SPECULAR_AMOUNT > 0.3) {
		vec3 h = normalize(LIGHT + VIEW);
		SPECULAR_LIGHT += pow(max(dot(NORMAL, h), 0.0), 24.0) * 0.6 * ATTENUATION * LIGHT_COLOR;
	}
}
