## Procedural mesh helpers for the spectacles (U6): parametric surfaces, lathes, capsules,
## ellipsoids, swept tubes and a procedural face texture. Everything returns an ArrayMesh with
## smooth normals; meshes are cached by key by the callers (figure.gd). Units are metres.
extends RefCounted

static var _cache: Dictionary = {}
static var _face_tex: Dictionary = {}


## A parametric surface: fn(u, v) -> Vector3 for u, v in 0..1 on a (nu x nv) grid. The mesh has
## uv = (u, v). `orient`: 0 = make the normals point away from the mesh centre, 1 = as built,
## -1 = reversed (for open cloth, where "outward" is not defined). Cloth should use a
## double-sided material.
static func surface(nu: int, nv: int, fn: Callable, orient := 0) -> ArrayMesh:
	var grid: Array = []
	var uvs: Array = []
	var centre := Vector3.ZERO
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			var p: Vector3 = fn.call(u, v)
			grid.append(p)
			uvs.append(Vector2(u, v))
			centre += p
	centre /= float(grid.size())
	# decide the winding
	var flip := orient < 0
	if orient == 0:
		var score := 0.0
		for j in nv:
			for i in nu:
				var a: Vector3 = grid[j * (nu + 1) + i]
				var b: Vector3 = grid[j * (nu + 1) + i + 1]
				var c: Vector3 = grid[(j + 1) * (nu + 1) + i]
				var n := (b - a).cross(c - a)
				score += n.dot(a - centre)
		flip = score > 0.0   # Godot front faces are clockwise
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv:
		for i in nu:
			var i00 := j * (nu + 1) + i
			var i10 := i00 + 1
			var i01 := i00 + (nu + 1)
			var i11 := i01 + 1
			var quad := [i00, i10, i11, i00, i11, i01]
			if flip:
				quad = [i00, i11, i10, i00, i01, i11]
			for k in quad:
				st.set_uv(uvs[k])
				st.add_vertex(grid[k])
	st.generate_normals()
	return st.commit()


## A lathe: profile entries are Vector4(y, radius_x, radius_z, z_offset), bottom to top; the
## front of the shape (+z) is at u = 0.5. Closed with poles if the end radii are 0.
static func lathe(profile: Array, nu := 16, orient := 0) -> ArrayMesh:
	var n := profile.size()
	var fn := func(u: float, v: float) -> Vector3:
		var f := v * float(n - 1)
		var i := mini(int(f), n - 2)
		var t := f - float(i)
		var a: Vector4 = profile[i]
		var b: Vector4 = profile[i + 1]
		var y := lerpf(a.x, b.x, t)
		var rx := lerpf(a.y, b.y, t)
		var rz := lerpf(a.z, b.z, t)
		var cz := lerpf(a.w, b.w, t)
		var th := (u - 0.5) * TAU
		return Vector3(rx * sin(th), y, rz * cos(th) + cz)
	return surface(nu, (n - 1) * 2, fn, orient)


## A lathe whose v coordinate is linear in height y (so a texture can be laid by height); the
## profile (ascending y) is sampled at `nv` evenly spaced heights.
static func lathe_y(profile: Array, nu := 16, nv := 28, orient := 0) -> ArrayMesh:
	var n := profile.size()
	var y0: float = (profile[0] as Vector4).x
	var y1: float = (profile[n - 1] as Vector4).x
	var fn := func(u: float, v: float) -> Vector3:
		var y := lerpf(y0, y1, v)
		var i := 0
		while i < n - 2 and (profile[i + 1] as Vector4).x < y:
			i += 1
		var a: Vector4 = profile[i]
		var b: Vector4 = profile[i + 1]
		var t := clampf((y - a.x) / maxf(b.x - a.x, 0.00001), 0.0, 1.0)
		var th := (u - 0.5) * TAU
		var rx := lerpf(a.y, b.y, t)
		var rz := lerpf(a.z, b.z, t)
		var cz := lerpf(a.w, b.w, t)
		return Vector3(rx * sin(th), y, rz * cos(th) + cz)
	return surface(nu, nv, fn, orient)


## A tapered capsule hanging down from the origin (a joint): round at the top (radius r0, the
## ball covers the joint) and at the bottom (radius r1), `length` between the two centres.
## `belly` swells the middle a little (muscle).
static func capsule(r0: float, r1: float, length: float, nu := 10, belly := 0.0, flat_z := 1.0) -> ArrayMesh:
	var key := "cap%.3f,%.3f,%.3f,%d,%.2f,%.2f" % [r0, r1, length, nu, belly, flat_z]
	if _cache.has(key):
		return _cache[key]
	var prof: Array = []
	var rings := 4
	prof.append(Vector4(-length - r1, 0.0, 0.0, 0.0))
	for k in range(1, rings + 1):
		var a := float(k) / rings * PI / 2.0
		prof.append(Vector4(-length - r1 * cos(a), r1 * sin(a), r1 * sin(a) * flat_z, 0.0))
	var mids := 3
	for k in range(1, mids):
		var t := float(k) / mids
		var r := lerpf(r1, r0, t) + belly * sin(t * PI)
		prof.append(Vector4(lerpf(-length, 0.0, t), r, r * flat_z, 0.0))
	for k in range(rings + 1):
		var a := float(k) / rings * PI / 2.0
		prof.append(Vector4(r0 * sin(a), r0 * cos(a), r0 * cos(a) * flat_z, 0.0))
	var m := lathe(prof, nu)
	_cache[key] = m
	return m


## An ellipsoid centred on the origin.
static func ellipsoid(rx: float, ry: float, rz: float, nu := 14, nv := 8) -> ArrayMesh:
	var key := "ell%.3f,%.3f,%.3f,%d,%d" % [rx, ry, rz, nu, nv]
	if _cache.has(key):
		return _cache[key]
	var prof: Array = []
	for k in nv + 1:
		var a := -PI / 2.0 + float(k) / nv * PI
		prof.append(Vector4(ry * sin(a), rx * cos(a), rz * cos(a), 0.0))
	var m := lathe(prof, nu)
	_cache[key] = m
	return m


## A tube swept along `pts` with radius `radii` (same length as pts), closed ends.
static func tube(pts: Array, radii: Array, nu := 8) -> ArrayMesh:
	var n := pts.size()
	var frames: Array = []
	var tan0: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).normalized()
	var ref := Vector3.UP if absf(tan0.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var nrm := tan0.cross(ref).normalized()
	for i in n:
		var t: Vector3
		if i == 0:
			t = tan0
		elif i == n - 1:
			t = ((pts[i] as Vector3) - (pts[i - 1] as Vector3)).normalized()
		else:
			t = ((pts[i + 1] as Vector3) - (pts[i - 1] as Vector3)).normalized()
		nrm = (nrm - t * nrm.dot(t)).normalized()
		frames.append([t, nrm, t.cross(nrm)])
	var fn := func(u: float, v: float) -> Vector3:
		var f := v * float(n + 1)   # one extra ring each end for the caps
		var idx := clampi(int(f) - 1, 0, n - 1)
		var rad: float = radii[idx]
		var cap := 0.0
		if f < 1.0:
			cap = f
			rad = radii[0] * sin(cap * PI / 2.0)
		elif f > float(n):
			cap = f - float(n)
			rad = radii[n - 1] * cos(cap * PI / 2.0)
		var fr: Array = frames[idx]
		var a := u * TAU
		var p: Vector3 = pts[idx]
		if f < 1.0:
			p = (pts[0] as Vector3) - (fr[0] as Vector3) * radii[0] * cos(cap * PI / 2.0)
		elif f > float(n):
			p = (pts[n - 1] as Vector3) + (fr[0] as Vector3) * radii[n - 1] * sin(cap * PI / 2.0)
		return p + ((fr[1] as Vector3) * cos(a) + (fr[2] as Vector3) * sin(a)) * rad
	return surface(nu, n + 1, fn)


## A simple procedural face for a head lathe whose front is at u = 0.5 (see figure.gd):
## skin, brows, eyes, nose shading, mouth. `seed_value` varies brows and mouth slightly.
static func face_texture(skin: Color, seed_value := 0) -> ImageTexture:
	var key := "%s:%d" % [skin.to_html(), seed_value]
	if _face_tex.has(key):
		return _face_tex[key]
	var W := 128
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(skin)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 17
	var dark := skin.darkened(0.55)
	var brow := Color(0.2, 0.14, 0.1)
	var lip := skin.lerp(Color(0.62, 0.25, 0.22), 0.55)
	var shade := skin.darkened(0.14)
	# front of the face is u = 0.5; v runs from the chin (0) up to the crown (1)
	for y in H:
		for x in W:
			var u := float(x) / W
			var v := float(y) / H
			var dx := (u - 0.5)
			var c := skin
			var side := smoothstep(0.16, 0.34, absf(dx))
			c = c.lerp(shade, side * 0.6)
			c = c.lerp(skin.lightened(0.06), smoothstep(0.7, 0.9, v) * 0.5)   # forehead
			for s: float in [-1.0, 1.0]:
				var ex := dx - s * 0.085
				var ey := v - 0.535
				var e := (ex * ex) / (0.036 * 0.036) + (ey * ey) / (0.0185 * 0.0185)
				if e < 1.0:
					c = Color(0.95, 0.94, 0.9)
					if (ex * ex + ey * ey) < 0.0165 * 0.0165:
						c = Color(0.3, 0.2, 0.12)
						if (ex * ex + ey * ey) < 0.0085 * 0.0085:
							c = Color(0.04, 0.03, 0.03)
				elif e < 2.0 and ey > 0.0:
					c = c.lerp(dark, 0.5)   # upper lid
				elif e < 1.6 and ey < 0.0:
					c = c.lerp(shade, 0.5)  # under-eye
				var by := v - (0.605 + 0.004 * (1.0 - absf(ex) / 0.05))
				if absf(ex) < 0.052 and absf(by) < 0.0125:
					c = c.lerp(brow, 0.9)
			# nose: shaded sides and a darker underside with nostrils
			if absf(dx) < 0.03 and v > 0.34 and v < 0.52:
				c = c.lerp(shade, 0.35 * (1.0 - absf(dx) / 0.03))
			if v > 0.34 and v < 0.38 and absf(dx) < 0.045:
				c = c.lerp(dark, 0.16 * (1.0 - smoothstep(0.02, 0.045, absf(dx))))
			# mouth
			var my := v - 0.235
			if absf(dx) < 0.05 and absf(my) < 0.009:
				c = lip if absf(my) > 0.0015 else dark
			elif absf(dx) < 0.036 and my < -0.0 and my > -0.02:
				c = c.lerp(lip, 0.4)
			# a little stubble shadow on the chin for older faces
			if (seed_value % 3) == 1 and v < 0.2 and absf(dx) < 0.1:
				c = c.lerp(dark, 0.18)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_face_tex[key] = tex
	return tex


## Merge several meshes into one: parts = [[mesh, Transform3D, part_id], ...]. The part id goes
## into UV2.x (the crowd shader picks skin, cloth, hair and face by it).
static func merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for p in parts:
		var mesh: ArrayMesh = p[0]
		var xf: Transform3D = p[1]
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var t: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in v.size():
			verts.append(xf * v[i])
			norms.append((xf.basis * n[i]).normalized())
			uvs.append(t[i])
			uv2.append(Vector2(float(p[2]), 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
