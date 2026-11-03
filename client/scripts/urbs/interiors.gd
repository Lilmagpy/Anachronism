## Urbs (D-289, U5): walk into a monument. `enter(monument, parent)` builds the interior of
## that monument in place in the world (the same coordinates as the exterior, so you walk in
## through its door) and returns the transform where the camera starts; `exit()` frees it.
##
## The monument is a record of `data/city/monuments.json` (id, type, lat, lon, form, built...).
## Optional keys the data may add, all read here when present:
##   size [L, W] in metres, or length_m / width_m   (else parsed from `form`, else a default)
##   bearing  compass degrees the building's front faces (default: temples east, Vitruvius
##            4.5; the Capitoline south, Dion. Hal. 4.61; the circus along its valley, NW-SE)
##   floor_y  ground height in metres (default 10, the ancient Forum floor)
## Which interior: temple, curia, basilica, circus (Maximus only), amphitheatre (the Flavian
## amphitheatre, built from AD 80), forum (the games in the Forum), house (domus), theatre.
## The lead wires `enter` to the click/Enter button; the camera agent moves the camera.
##
## Pieces: the interior is a Node3D "UrbsInterior" with a MeshInstance3D "Body", a
## "Cover" (roof and ceiling; `set_cutaway(true)` hides it) and an OmniLight3D per lamp.
class_name UrbsInteriors
extends RefCounted

const Roman := preload("res://scripts/models/roman_interiors.gd")
const Geo := preload("res://scripts/urbs/geo.gd")
const Figure := preload("res://scripts/urbs/spectacles/figure.gd")
const MeshLib := preload("res://scripts/urbs/spectacles/meshlib.gd")

static var current: Node3D = null
static var _result: Dictionary = {}
static var _kind := ""
static var _size := Vector2.ZERO
static var _xf := Transform3D.IDENTITY
static var _material: ShaderMaterial = null

## The year the interiors are dressed for (frescoes, statues, tiers): set it from the game.
static var year := -100


## Which interior kind a monument gets ("" when it has none), and the variant.
static func kind_of(monument: Dictionary) -> Array:
	var id := str(monument.get("id", ""))
	match str(monument.get("type", "")):
		"temple":
			return ["temple", "capitoline" if "capitolini" in id else ""]
		"curia":
			return ["curia", "julia" if "iulia" in id else ("pompeia" if "pompeia" in id else "hostilia")]
		"basilica":
			return ["basilica", id.trim_prefix("basilica_")]
		"circus":
			return ["circus", ""] if id == "circus_maximus" else ["", ""]
		"amphitheatre":
			return ["arena", "colosseum"]
		"forum":
			return ["arena", "forum"]
		"house":
			return ["domus", ""]
		"insula":
			return ["insula", ""]
		"theatre":
			return ["theatre", "pompey" if "pompei" in id else ""]
		"shrine", "altar":
			return ["temple", ""]
	return ["", ""]


## The (L, W) of a monument: explicit keys, else "A x B m" in its form text, else a default.
static func size_of(monument: Dictionary, kind: String, variant: String) -> Vector2:
	if monument.has("size") and monument["size"] is Array and monument["size"].size() >= 2:
		return Vector2(float(monument["size"][0]), float(monument["size"][1]))
	if monument.has("length_m") and monument.has("width_m"):
		return Vector2(float(monument["length_m"]), float(monument["width_m"]))
	var form := str(monument.get("form", ""))
	var rx := RegEx.new()
	rx.compile("(\\d+(?:\\.\\d+)?)\\s*(?:x|×)\\s*(\\d+(?:\\.\\d+)?)\\s*m")
	var m := rx.search(form)
	if m != null:
		return Vector2(float(m.get_string(1)), float(m.get_string(2)))
	rx.compile("(\\d+(?:\\.\\d+)?)\\s*m\\s*diameter")
	m = rx.search(form)
	if m != null and kind == "theatre":
		return Vector2(float(m.get_string(1)), float(m.get_string(1)))
	return Roman.default_size(kind, variant)


static func _default_bearing(kind: String, variant: String) -> float:
	if kind == "temple":
		return 180.0 if variant == "capitoline" else 90.0
	if kind == "circus":
		return 135.0     # the Vallis Murcia runs NW-SE: carceres NW, sphendone SE (Platner-Ashby)
	return 180.0


## The interior of one monument record as a free-standing node at `at` (world), or null when
## the monument has no interior. `year` dresses it (frescoes, columns). Used by interior.gd.
static func build_node(monument: Dictionary, at: Transform3D, for_year: int) -> Node3D:
	var kv := kind_of(monument)
	if kv[0] == "":
		return null
	var size := size_of(monument, kv[0], kv[1])
	var r := Roman.build(kv[0], size, {"year": for_year, "variant": kv[1]})
	if r.is_empty():
		return null
	var root := Node3D.new()
	root.name = "UrbsInterior"
	root.transform = at
	_attach(root, r)
	root.set_meta("result", r)
	return root


## Build the interior in `parent` and return the camera's starting transform (world).
static func enter(monument: Dictionary, parent: Node3D) -> Transform3D:
	exit()
	var kv := kind_of(monument)
	var kind: String = kv[0]
	var variant: String = kv[1]
	if kind == "":
		push_warning("UrbsInteriors: no interior for %s" % str(monument.get("id", "?")))
		return Transform3D.IDENTITY
	var size := size_of(monument, kind, variant)
	var opts := {"year": year, "variant": variant}
	var r := Roman.build(kind, size, opts)
	if r.is_empty():
		return Transform3D.IDENTITY
	var root := Node3D.new()
	root.name = "UrbsInterior"
	var floor_y := float(monument.get("floor_y", 10.0))
	var at := Geo.at(float(monument.get("lat", Geo.ORIGIN_LAT)), float(monument.get("lon", Geo.ORIGIN_LON)), floor_y)
	var bearing := float(monument.get("bearing", _default_bearing(kind, variant)))
	root.transform = Transform3D(Basis(Vector3.UP, Geo.yaw_from_bearing(bearing)), at)
	parent.add_child(root)
	_attach(root, r)
	current = root
	_result = r
	_kind = kind
	_size = size
	_xf = root.transform
	return _xf * (r["spawn"] as Transform3D)


## Build an interior straight from a kind and size at a given transform (previews, tests).
static func enter_kind(kind: String, size: Vector2, parent: Node3D, at := Transform3D.IDENTITY, variant := "") -> Transform3D:
	exit()
	var r := Roman.build(kind, size, {"year": year, "variant": variant})
	if r.is_empty():
		return Transform3D.IDENTITY
	var root := Node3D.new()
	root.name = "UrbsInterior"
	root.transform = at
	parent.add_child(root)
	_attach(root, r)
	current = root
	_result = r
	_kind = kind
	_size = size
	_xf = at
	return _xf * (r["spawn"] as Transform3D)


static func _attach(root: Node3D, r: Dictionary) -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/models.gdshader")
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = r["mesh"]
	body.scale = Vector3.ONE * Roman.MS
	body.material_override = _material
	root.add_child(body)
	if r["cover"] != null:
		var cover := MeshInstance3D.new()
		cover.name = "Cover"
		cover.mesh = r["cover"]
		cover.scale = Vector3.ONE * Roman.MS
		cover.material_override = _material
		root.add_child(cover)
	for spec in r.get("statues", []):
		root.add_child(_make_statue(spec))
	if r.get("ground", false):   # the street round a building (the scene hides the city's own ground)
		var ground := MeshInstance3D.new()
		ground.name = "Ground"
		var plane := PlaneMesh.new()
		plane.size = Vector2(500, 500)
		ground.mesh = plane
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.50, 0.45, 0.35)
		gm.roughness = 1.0
		ground.material_override = gm
		ground.position.y = -0.03
		root.add_child(ground)
	# The scene turns its own sun off while inside, so the interior brings the sun that comes
	# through its real openings (doors, windows, the compluvium, the open sky).
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	root.add_child(sun)
	for l in r["lights"]:
		var light := OmniLight3D.new()
		light.name = "Lamp"
		light.position = l["pos"]
		light.light_color = l["colour"]
		light.light_energy = l["energy"]
		light.omni_range = l["range"]
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		root.add_child(light)


static var _statue_mats: Dictionary = {}


static func _statue_mat(style: String) -> StandardMaterial3D:
	if _statue_mats.has(style):
		return _statue_mats[style]
	var m := StandardMaterial3D.new()
	m.roughness = 0.75
	match style:
		"terracotta":
			m.albedo_color = Color(0.70, 0.34, 0.22)
		"gilt":
			m.albedo_color = Color(0.92, 0.74, 0.28)
			m.metallic = 0.85
			m.roughness = 0.35
		"marble":
			m.albedo_color = Color(0.92, 0.90, 0.85)
		"bronze":
			m.albedo_color = Color(0.55, 0.40, 0.20)
			m.metallic = 0.7
			m.roughness = 0.4
	_statue_mats[style] = m
	return m


## One cult statue: the spectacles' jointed figure, scaled up, posed and finished in its material.
static func _make_statue(spec: Dictionary) -> Node3D:
	var style: String = spec["style"]
	var opts := {"toga": true, "tunic": Color(0.9, 0.85, 0.7)}
	if style == "person":
		opts = {"toga": false, "tunic": spec.get("colour", Color(0.7, 0.6, 0.45)), "seed": int(spec["foot"].x * 7.0)}
	if style == "chryselephantine":
		opts = {"bare": true, "skin": Color(0.93, 0.89, 0.78), "tunic": Color(0.92, 0.74, 0.28), "hair": Color(0.9, 0.72, 0.3)}
	var f: Node3D = Figure.person(opts)
	var attr: String = spec.get("attr", "")
	if spec["pose"] == "seated":
		f.sit(1.0)
	if attr == "sceptre":
		f.equip_sceptre()
	elif attr == "helmet":
		f.equip_helmet()
		f.equip_shield()
	elif attr == "spear":
		f.equip_spear()
	elif attr == "wings":
		for sx in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			wing.mesh = MeshLib.ellipsoid(0.04, 0.32, 0.16, 10, 6)
			wing.position = Vector3(sx * 0.2, 0.3, -0.12)
			wing.rotation = Vector3(0.0, 0.0, -sx * 0.5)
			f.torso.add_child(wing)
	if style != "chryselephantine" and style != "person":
		_override(f, _statue_mat(style))
	f.scale = Vector3.ONE * (float(spec["h"]) / 1.75)
	f.position = spec["foot"]
	f.rotation.y = float(spec["yaw"])
	return f


static func _override(node: Node, m: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = m
	for c in node.get_children():
		_override(c, m)


## Free the interior.
static func exit() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null
	_result = {}


## Hide or show the roof and ceiling (a cutaway to look down into the rooms).
static func set_cutaway(on: bool) -> void:
	if current != null and current.has_node("Cover"):
		(current.get_node("Cover") as Node3D).visible = not on


## The camera transform (world) for a named seat section of the current interior.
static func seat(section: String) -> Transform3D:
	var seats: Dictionary = _result.get("seats", {})
	if seats.has(section):
		return _xf * (seats[section] as Transform3D)
	return _xf * (_result.get("spawn", Transform3D.IDENTITY) as Transform3D)


## Names of the seat sections of the current interior.
static func seat_names() -> Array:
	return (_result.get("seats", {}) as Dictionary).keys()


## Places inside for the spectacle code (altar, statue, tribunal, doors...), in world space.
static func anchor(name: String) -> Vector3:
	var a: Dictionary = _result.get("anchors", {})
	if a.has(name):
		return _xf * (a[name] as Vector3)
	return _xf.origin


## What the builder assumed and which sources it used (for the info card).
static func notes() -> Array:
	return _result.get("notes", [])
