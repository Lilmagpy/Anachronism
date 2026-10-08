// Level of detail without popping (D-123), for our own opaque shaders: the built-in
// visibility-range fade does not work with them, so each model dissolves itself with a fine
// dither as the camera passes a threshold, measured from the model itself (each building of
// a town on its own). scripts/lod.gd makes a copy of the material per pair of distances.
uniform float lod_near = 0.0;   // shown nearer than this, dissolving just beyond (0: always)
uniform float lod_far = 0.0;    // shown farther than this, appearing just before (0: always)

const float LOD_MARGIN = 0.22;

varying float lod_distance;

// How much of the model to keep at this camera distance (1: all of it).
float lod_keep(float distance) {
	float keep = 1.0;
	if (lod_near > 0.0) {
		keep *= 1.0 - smoothstep(lod_near, lod_near * (1.0 + LOD_MARGIN), distance);
	}
	if (lod_far > 0.0) {
		keep *= smoothstep(lod_far * (1.0 - LOD_MARGIN), lod_far, distance);
	}
	return keep;
}

// Interleaved gradient noise: an even, fine dither pattern across the screen.
float lod_dither(vec2 fragment) {
	return fract(52.9829189 * fract(dot(fragment, vec2(0.06711056, 0.00583715))));
}
