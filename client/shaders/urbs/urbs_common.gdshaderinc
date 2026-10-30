// Urbs material library (U8 render): what every procedural Roman surface shares.
//
// Mapping: no textures and no reliance on the mesh's UVs. The vertex stage passes the
// position and normal in OBJECT space, scaled to metres (so a MultiMesh instance scaled in x
// and z keeps its bricks 30 cm long). The fragment stage builds a frame on the face from its
// normal: T runs level along the face, B runs up the face (down the slope of a roof is -B), so
// a wall turned at any angle gets level courses, and a roof gets its rows along the eaves.
//
// Detail by screen size: `u_fp` is how many metres one pixel covers here. Every pattern of
// period P fades to its average as P shrinks below a few pixels (`detail(P)`), and the bump
// fades with it, so nothing shimmers at 500 m and nothing is blurred at 1 m.

varying vec3 u_pos;      // object-space position in metres
varying vec3 u_nrm;      // object-space normal (metre space)
varying vec3 u_wpos;     // world position

// Per-axis scale of the model matrix (metres per object unit). Each shader's vertex() does:
//   vec3 s = u_scale(MODEL_MATRIX); u_pos = VERTEX * s; u_nrm = normalize(NORMAL / s);
//   u_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
vec3 u_scale(mat4 model) {
	return max(vec3(length(model[0].xyz), length(model[1].xyz), length(model[2].xyz)), vec3(1e-4));
}

// --- noise -----------------------------------------------------------------------------------

float u_hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float u_hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec2 u_hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float u_noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(u_hash2(i), u_hash2(i + vec2(1.0, 0.0)), f.x),
			mix(u_hash2(i + vec2(0.0, 1.0)), u_hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float u_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(u_hash3(i), u_hash3(i + vec3(1, 0, 0)), f.x), mix(u_hash3(i + vec3(0, 1, 0)), u_hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(u_hash3(i + vec3(0, 0, 1)), u_hash3(i + vec3(1, 0, 1)), f.x), mix(u_hash3(i + vec3(0, 1, 1)), u_hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

// Fractal noise whose finer octaves drop out once they are smaller than a pixel (fp metres).
// `freq` is the frequency of the first octave in cycles per metre. Average 0.5.
float u_fbm3(vec3 p, float freq, float fp) {
	float sum = 0.0;
	float amp = 0.5;
	float f = freq;
	for (int i = 0; i < 4; i++) {
		float keep = 1.0 - smoothstep(0.25, 0.6, fp * f);
		sum += amp * mix(0.5, u_noise3(p * f + float(i) * 17.31), keep);
		amp *= 0.5;
		f *= 2.07;
	}
	return sum / 0.9375;
}

float u_fbm2(vec2 p, float freq, float fp) {
	float sum = 0.0;
	float amp = 0.5;
	float f = freq;
	for (int i = 0; i < 4; i++) {
		float keep = 1.0 - smoothstep(0.25, 0.6, fp * f);
		sum += amp * mix(0.5, u_noise2(p * f + float(i) * 7.17), keep);
		amp *= 0.5;
		f *= 2.03;
	}
	return sum / 0.9375;
}

// Voronoi on a plane: x = distance to the nearest centre, y = distance to the edge between
// the nearest two (the joint), z = the cell's own random number.
vec3 u_voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = u_hash22(n + g) * 0.8 + 0.1;
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	float edge = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = u_hash22(n + g) * 0.8 + 0.1;
			vec2 r = g + o - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				edge = min(edge, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec3(sqrt(md), edge, u_hash2(n + mg));
}

// --- the face's frame and the pixel footprint -------------------------------------------------

// T: level along the face; B: up the face (for a floor or a flat roof: object x and z).
void u_frame(vec3 n, out vec3 t, out vec3 b) {
	if (abs(n.y) > 0.97) {
		t = vec3(1.0, 0.0, 0.0);
		b = vec3(0.0, 0.0, -sign(n.y));
		return;
	}
	t = normalize(cross(vec3(0.0, 1.0, 0.0), n));
	b = normalize(cross(n, t));
}

// Metres covered by one pixel at this point.
float u_footprint(vec3 p) {
	return max(max(length(dFdx(p)), length(dFdy(p))), 1e-5);
}

// 1 while a pattern of period `period` metres is several pixels across, 0 once it is ~2.
float u_detail(float period, float fp) {
	return 1.0 - smoothstep(period * 0.2, period * 0.55, fp);
}

// An anti-aliased step: 0 below `edge`, 1 above, blurred over about a pixel (`w` coords/px).
float u_aastep(float edge, float x, float w) {
	return smoothstep(edge - w, edge + w, x);
}

// Tilt the shading normal by a height gradient (dh/dT, dh/dB, in metres per metre). Returns
// the new normal in view space from the object-space frame.
vec3 u_bump(vec3 n_obj, vec3 t, vec3 b, vec2 grad, mat4 model, mat4 view) {
	vec3 nb = normalize(n_obj - grad.x * t - grad.y * b);
	mat3 rot = mat3(normalize(model[0].xyz), normalize(model[1].xyz), normalize(model[2].xyz));
	return normalize(mat3(view) * (rot * nb));
}

vec3 u_lin(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

// Grime toward the foot of a wall: 1 clean .. lower near the model's base (object y = 0).
float u_grime(float y, float height) {
	return mix(0.78, 1.0, smoothstep(0.0, height, y));
}

// Ashlar blocks / slabs on the face plane: rows of `size` metres (x along, y up), every other
// row shifted half a block; size.y <= 0 gives only the upright joints (step treads, slabs in
// one course). Returns (joint mask 0..1, dh/du, dh/dv, the block's random number). The height
// rises from the joint over `bevel` metres, so each block's edge catches the sun.
vec4 u_blocks(vec2 uv, vec2 size, float joint, float bevel, float fp) {
	float rows = size.y > 0.0 ? size.y : 1e6;
	float row = floor(uv.y / rows);
	float u2 = uv.x / size.x + mod(row, 2.0) * 0.5;
	float col = floor(u2);
	float fx = fract(u2) * size.x;
	float fy = size.y > 0.0 ? fract(uv.y / rows) * rows : 1e6;
	float dxl = fx;
	float dxr = size.x - fx;
	float dyb = fy;
	float dyt = rows - fy;
	float dx = min(dxl, dxr);
	float dy = min(dyb, dyt);
	float d = min(dx, dy);
	float half_j = joint * 0.5;
	float fade = u_detail(min(size.x, rows), fp);
	float mask = (1.0 - smoothstep(half_j, half_j + max(fp, 0.001), d)) * fade;
	float slope = (d > half_j && d < half_j + bevel) ? 1.0 / bevel : 0.0;
	slope *= fade * u_detail(bevel * 2.0, fp);
	vec2 g = vec2(0.0);
	if (dx < dy) {
		g.x = dxl < dxr ? slope : -slope;
	} else {
		g.y = dyb < dyt ? slope : -slope;
	}
	return vec4(mask, g, u_hash2(vec2(col, row) + 0.37));
}
