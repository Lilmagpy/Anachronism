## Urbs shared material library (U8). Every Urbs builder asks for a surface BY NAME; this file
## decides what it looks like, so the whole city changes together. Everyone else only uses the
## names below and never builds a StandardMaterial3D of their own for a Roman surface.
##
## The surfaces (U8 render) are procedural PBR shaders in `shaders/urbs/` (no texture files):
## stone.gdshader (veined marbles, breccia, travertine with its pores, tufa, basalt, ashlar
## courses), masonry.gdshader (brick in mortar, reticulatum, incertum, quadratum, rubble),
## plaster.gdshader (stucco, Pompeian panels), tiles.gdshader (tegulae and imbrices, ridge tiles,
## antefixes, bronze roofs), metal.gdshader (bronze, verdigris, gilt, iron, studded doors),
## wood.gdshader, cloth.gdshader, ground.gdshader (Forum slabs, polygonal basalt, gravel,
## earth, grass...), water.gdshader. `RECIPES` says which shader and which settings each name
## gets. They map themselves from the model's own position in metres (any UVs will do), and
## each pattern fades to its average colour once it is a few pixels across (no shimmer).
## `COLOURS` stays the plain colour of each surface (fallbacks, and shaders that only want
## the tint, such as the houses' own).
##
## `restyle(node)` swaps the plain StandardMaterial3Ds of an already built subtree for library
## materials where the node's name or the colour says which Roman surface it is; it leaves
## unknown materials, shader materials and the terrain alone.
##
## Stable names (add one here, with a plain-colour fallback, if a surface is missing; never
## rename):
##   stone:    marble_luna, marble_pentelic, marble_numidian (giallo antico), marble_phrygian
##             (pavonazzetto), marble_lucullan (africano), travertine, tufa_grey (peperino),
##             tufa_brown (cappellaccio), tufa_yellow (Grotta Oscura), basalt (silex paving),
##             limestone_steps
##   masonry:  brick_latericium, opus_reticulatum, opus_incertum, opus_quadratum (tufa blocks),
##             rubble_wall
##   plaster:  stucco_white, stucco_cream, stucco_ochre, stucco_red (Pompeian), stucco_worn,
##             fresco_panel
##   roof:     tegulae (terracotta pan and cover tiles), tegulae_old, ridge_terracotta,
##             antefix_terracotta, bronze_roof
##   metal:    bronze, bronze_verdigris, gilt, iron
##   wood:     timber_oak, timber_painted, timber_weathered, door_bronze_studded, shutter_wood
##   textile:  awning_canvas, awning_striped, laundry_linen, faction_red, faction_white,
##             faction_blue, faction_green
##   ground:   forum_travertine (slab paving), street_basalt, gravel, earth_packed, grass,
##             garden_bed, sand_arena, mud_bank
##   water:    tiber_water, fountain_water
##   other:    glass_lamp (emissive), smoke, statue_bronze, statue_marble, terracotta_pot
class_name UrbsMaterials

const COLOURS := {
	"marble_luna": Color(0.93, 0.92, 0.89), "marble_pentelic": Color(0.90, 0.88, 0.80),
	"marble_numidian": Color(0.85, 0.65, 0.30), "marble_phrygian": Color(0.80, 0.72, 0.78),
	"marble_lucullan": Color(0.30, 0.22, 0.20), "travertine": Color(0.86, 0.82, 0.72),
	"tufa_grey": Color(0.55, 0.54, 0.50), "tufa_brown": Color(0.50, 0.42, 0.33),
	"tufa_yellow": Color(0.72, 0.64, 0.46), "basalt": Color(0.28, 0.28, 0.29),
	"limestone_steps": Color(0.80, 0.78, 0.70),
	"brick_latericium": Color(0.68, 0.40, 0.30), "opus_reticulatum": Color(0.60, 0.52, 0.42),
	"opus_incertum": Color(0.58, 0.54, 0.48), "opus_quadratum": Color(0.62, 0.58, 0.48),
	"rubble_wall": Color(0.56, 0.52, 0.46),
	"stucco_white": Color(0.92, 0.90, 0.85), "stucco_cream": Color(0.90, 0.85, 0.72),
	"stucco_ochre": Color(0.82, 0.66, 0.40), "stucco_red": Color(0.62, 0.22, 0.16),
	"stucco_worn": Color(0.78, 0.72, 0.62), "fresco_panel": Color(0.70, 0.30, 0.25),
	"tegulae": Color(0.72, 0.42, 0.28), "tegulae_old": Color(0.60, 0.40, 0.30),
	"ridge_terracotta": Color(0.66, 0.38, 0.26), "antefix_terracotta": Color(0.74, 0.46, 0.30),
	"bronze_roof": Color(0.55, 0.40, 0.22),
	"bronze": Color(0.62, 0.45, 0.22), "bronze_verdigris": Color(0.35, 0.55, 0.48),
	"gilt": Color(0.95, 0.78, 0.30), "iron": Color(0.30, 0.30, 0.32),
	"timber_oak": Color(0.52, 0.38, 0.24), "timber_painted": Color(0.45, 0.30, 0.25),
	"timber_weathered": Color(0.50, 0.46, 0.40), "door_bronze_studded": Color(0.45, 0.32, 0.16),
	"shutter_wood": Color(0.40, 0.30, 0.20),
	"awning_canvas": Color(0.88, 0.82, 0.66), "awning_striped": Color(0.80, 0.40, 0.30),
	"laundry_linen": Color(0.92, 0.90, 0.84), "faction_red": Color(0.75, 0.15, 0.12),
	"faction_white": Color(0.95, 0.95, 0.92), "faction_blue": Color(0.18, 0.30, 0.65),
	"faction_green": Color(0.20, 0.50, 0.25),
	"forum_travertine": Color(0.84, 0.80, 0.70), "street_basalt": Color(0.30, 0.30, 0.31),
	"gravel": Color(0.70, 0.66, 0.58), "earth_packed": Color(0.58, 0.48, 0.36),
	"grass": Color(0.42, 0.52, 0.26), "garden_bed": Color(0.36, 0.28, 0.20),
	"sand_arena": Color(0.86, 0.76, 0.56), "mud_bank": Color(0.50, 0.42, 0.32),
	"tiber_water": Color(0.42, 0.50, 0.40), "fountain_water": Color(0.55, 0.70, 0.75),
	"glass_lamp": Color(1.0, 0.85, 0.55), "smoke": Color(0.6, 0.6, 0.6, 0.4),
	"statue_bronze": Color(0.50, 0.38, 0.20), "statue_marble": Color(0.92, 0.90, 0.86),
	"terracotta_pot": Color(0.70, 0.44, 0.30),
}

## Which shader and settings each surface gets (colours sRGB). Names missing here fall back to
## a plain StandardMaterial3D of their COLOURS entry.
const RECIPES := {
	# --- stone: mode 0 veined marble, 1 breccia, 2 travertine, 3 tufa, 4 basalt
	"marble_luna": ["stone", {"mode": 0, "base_colour": Color(0.93, 0.92, 0.89), "vein_colour": Color(0.48, 0.50, 0.53), "vein_amount": 0.6, "vein_scale": 1.1, "mottle": 0.06, "rough": 0.26, "spec": 0.5, "grime": 0.35}],
	"marble_pentelic": ["stone", {"mode": 0, "base_colour": Color(0.92, 0.89, 0.81), "vein_colour": Color(0.72, 0.66, 0.54), "vein_amount": 0.3, "vein_scale": 0.9, "mottle": 0.1, "rough": 0.3, "spec": 0.5, "grime": 0.35}],
	"marble_numidian": ["stone", {"mode": 0, "base_colour": Color(0.86, 0.68, 0.34), "vein_colour": Color(0.70, 0.36, 0.17), "vein_amount": 0.6, "vein_scale": 2.0, "mottle": 0.15, "rough": 0.22, "spec": 0.5, "grime": 0.2}],
	"marble_phrygian": ["stone", {"mode": 0, "base_colour": Color(0.91, 0.88, 0.86), "vein_colour": Color(0.40, 0.24, 0.30), "vein_amount": 0.75, "vein_scale": 1.6, "mottle": 0.12, "rough": 0.22, "spec": 0.5, "grime": 0.2}],
	"marble_lucullan": ["stone", {"mode": 1, "base_colour": Color(0.16, 0.12, 0.11), "accent_colour": Color(0.56, 0.18, 0.15), "vein_colour": Color(0.46, 0.43, 0.41), "vein_amount": 0.9, "mottle": 0.1, "rough": 0.2, "spec": 0.5, "grime": 0.1}],
	"travertine": ["stone", {"mode": 2, "base_colour": Color(0.86, 0.82, 0.72), "vein_amount": 0.8, "mottle": 0.12, "block": Vector2(1.4, 0.6), "joint_colour": Color(0.66, 0.62, 0.53), "joint_width": 0.006, "rough": 0.72, "spec": 0.4, "grime": 0.6}],
	"tufa_grey": ["stone", {"mode": 3, "base_colour": Color(0.56, 0.55, 0.51), "vein_colour": Color(0.26, 0.25, 0.24), "vein_amount": 0.8, "mottle": 0.15, "block": Vector2(1.2, 0.6), "joint_colour": Color(0.44, 0.43, 0.40), "joint_width": 0.008, "rough": 0.92, "spec": 0.3, "grime": 0.6}],
	"tufa_brown": ["stone", {"mode": 3, "base_colour": Color(0.52, 0.44, 0.34), "vein_colour": Color(0.30, 0.24, 0.18), "vein_amount": 0.8, "mottle": 0.18, "block": Vector2(1.2, 0.6), "joint_colour": Color(0.40, 0.34, 0.26), "joint_width": 0.01, "rough": 0.94, "spec": 0.3, "grime": 0.6}],
	"tufa_yellow": ["stone", {"mode": 3, "base_colour": Color(0.75, 0.65, 0.45), "vein_colour": Color(0.46, 0.36, 0.24), "vein_amount": 0.7, "mottle": 0.15, "block": Vector2(1.2, 0.6), "joint_colour": Color(0.58, 0.50, 0.36), "joint_width": 0.008, "rough": 0.92, "spec": 0.3, "grime": 0.6}],
	"basalt": ["stone", {"mode": 4, "base_colour": Color(0.29, 0.29, 0.30), "mottle": 0.1, "rough": 0.7, "spec": 0.45, "grime": 0.2}],
	"limestone_steps": ["stone", {"mode": 2, "base_colour": Color(0.82, 0.79, 0.70), "vein_amount": 0.4, "mottle": 0.1, "block": Vector2(1.6, 0.0), "joint_colour": Color(0.60, 0.57, 0.50), "joint_width": 0.006, "rough": 0.7, "spec": 0.4, "grime": 0.3}],
	"statue_marble": ["stone", {"mode": 0, "base_colour": Color(0.94, 0.92, 0.88), "vein_colour": Color(0.70, 0.70, 0.70), "vein_amount": 0.15, "vein_scale": 1.5, "mottle": 0.05, "rough": 0.35, "spec": 0.5, "grime": 0.3}],
	# --- masonry: pattern 0 brick, 1 reticulatum, 2 incertum, 3 quadratum, 4 rubble
	"brick_latericium": ["masonry", {"pattern": 0, "unit_colour": Color(0.70, 0.41, 0.30), "unit_colour_b": Color(0.56, 0.29, 0.19), "mortar_colour": Color(0.72, 0.69, 0.62), "unit_size": 0.3, "rough": 0.88}],
	"opus_reticulatum": ["masonry", {"pattern": 1, "unit_colour": Color(0.68, 0.59, 0.44), "unit_colour_b": Color(0.56, 0.50, 0.40), "mortar_colour": Color(0.66, 0.63, 0.56), "unit_size": 0.09, "rough": 0.9}],
	"opus_incertum": ["masonry", {"pattern": 2, "unit_colour": Color(0.62, 0.57, 0.50), "unit_colour_b": Color(0.49, 0.45, 0.39), "mortar_colour": Color(0.64, 0.61, 0.55), "unit_size": 0.16, "rough": 0.92}],
	"opus_quadratum": ["masonry", {"pattern": 3, "unit_colour": Color(0.66, 0.60, 0.47), "unit_colour_b": Color(0.55, 0.49, 0.39), "mortar_colour": Color(0.46, 0.42, 0.34), "unit_size": 0.6, "rough": 0.92}],
	"rubble_wall": ["masonry", {"pattern": 4, "unit_colour": Color(0.58, 0.54, 0.48), "unit_colour_b": Color(0.45, 0.42, 0.37), "mortar_colour": Color(0.70, 0.66, 0.58), "unit_size": 0.35, "rough": 0.95}],
	# --- plaster
	"stucco_white": ["plaster", {"base_colour": Color(0.92, 0.90, 0.85), "wear": 0.15}],
	"stucco_cream": ["plaster", {"base_colour": Color(0.90, 0.85, 0.72), "wear": 0.25}],
	"stucco_ochre": ["plaster", {"base_colour": Color(0.82, 0.66, 0.40), "wear": 0.3}],
	"stucco_red": ["plaster", {"base_colour": Color(0.62, 0.22, 0.16), "wear": 0.3}],
	"stucco_worn": ["plaster", {"base_colour": Color(0.78, 0.72, 0.62), "wear": 0.75}],
	"fresco_panel": ["plaster", {"base_colour": Color(0.62, 0.20, 0.15), "trim_colour": Color(0.13, 0.11, 0.10), "panel": 1.8, "wear": 0.1, "rough": 0.7, "grime": 0.3}],
	# --- roofs: mode 0 tegulae and imbrices, 1 ridge, 2 relief
	"tegulae": ["tiles", {"mode": 0, "base_colour": Color(0.74, 0.43, 0.28), "alt_colour": Color(0.64, 0.34, 0.22), "lichen": 0.12}],
	"tegulae_old": ["tiles", {"mode": 0, "base_colour": Color(0.62, 0.41, 0.31), "alt_colour": Color(0.50, 0.36, 0.28), "lichen": 0.5}],
	"ridge_terracotta": ["tiles", {"mode": 1, "base_colour": Color(0.68, 0.39, 0.26), "alt_colour": Color(0.58, 0.32, 0.21), "lichen": 0.15}],
	"antefix_terracotta": ["tiles", {"mode": 2, "base_colour": Color(0.76, 0.47, 0.31), "alt_colour": Color(0.68, 0.40, 0.26), "lichen": 0.05}],
	"bronze_roof": ["tiles", {"mode": 0, "base_colour": Color(0.66, 0.50, 0.26), "alt_colour": Color(0.48, 0.42, 0.28), "lichen": 0.0, "metal": 1.0, "rough": 0.4}],
	"terracotta_pot": ["tiles", {"mode": 2, "base_colour": Color(0.70, 0.44, 0.30), "alt_colour": Color(0.64, 0.38, 0.26), "lichen": 0.0, "rough": 0.85}],
	# --- metal
	"bronze": ["metal", {"base_colour": Color(0.66, 0.48, 0.25), "patina_colour": Color(0.30, 0.24, 0.14), "patina": 0.25, "rough": 0.35}],
	"bronze_verdigris": ["metal", {"base_colour": Color(0.55, 0.40, 0.22), "patina_colour": Color(0.32, 0.56, 0.47), "patina": 0.85, "rough": 0.5}],
	"gilt": ["metal", {"base_colour": Color(0.97, 0.80, 0.38), "patina": 0.0, "rough": 0.22, "hammered": 0.15}],
	"iron": ["metal", {"base_colour": Color(0.38, 0.37, 0.38), "patina_colour": Color(0.40, 0.22, 0.12), "patina": 0.4, "rough": 0.55}],
	"statue_bronze": ["metal", {"base_colour": Color(0.56, 0.42, 0.22), "patina_colour": Color(0.20, 0.17, 0.12), "patina": 0.4, "rough": 0.38, "hammered": 0.15}],
	"door_bronze_studded": ["metal", {"base_colour": Color(0.58, 0.42, 0.21), "patina_colour": Color(0.24, 0.20, 0.12), "patina": 0.35, "rough": 0.4, "studs": 0.42}],
	# --- wood
	"timber_oak": ["wood", {"base_colour": Color(0.52, 0.38, 0.24)}],
	"timber_painted": ["wood", {"base_colour": Color(0.45, 0.30, 0.25), "paint_colour": Color(0.58, 0.18, 0.13), "paint": 0.9, "rough": 0.65}],
	"timber_weathered": ["wood", {"base_colour": Color(0.50, 0.46, 0.40), "grey": 0.6, "rough": 0.9}],
	"shutter_wood": ["wood", {"base_colour": Color(0.42, 0.31, 0.20), "slats": 0.07, "plank": 0.18}],
	# --- textile
	"awning_canvas": ["cloth", {"base_colour": Color(0.88, 0.82, 0.66)}],
	"awning_striped": ["cloth", {"base_colour": Color(0.88, 0.82, 0.66), "stripe_colour": Color(0.74, 0.28, 0.20), "stripe": 0.3}],
	"laundry_linen": ["cloth", {"base_colour": Color(0.92, 0.90, 0.84), "thin": 0.4}],
	"faction_red": ["cloth", {"base_colour": Color(0.75, 0.15, 0.12)}],
	"faction_white": ["cloth", {"base_colour": Color(0.95, 0.95, 0.92)}],
	"faction_blue": ["cloth", {"base_colour": Color(0.18, 0.30, 0.65)}],
	"faction_green": ["cloth", {"base_colour": Color(0.20, 0.50, 0.25)}],
	# --- ground: mode 0 slabs, 1 polygonal basalt, 2 gravel, 3 earth, 4 grass, 5 beds, 6 sand, 7 mud
	"forum_travertine": ["ground", {"mode": 0, "base_colour": Color(0.86, 0.82, 0.72), "alt_colour": Color(0.75, 0.70, 0.59), "joint_colour": Color(0.52, 0.47, 0.39), "unit": 1.5, "rough": 0.72}],
	"street_basalt": ["ground", {"mode": 1, "base_colour": Color(0.36, 0.36, 0.36), "alt_colour": Color(0.26, 0.26, 0.27), "joint_colour": Color(0.16, 0.15, 0.14), "unit": 0.85, "rough": 0.7}],
	"gravel": ["ground", {"mode": 2, "base_colour": Color(0.70, 0.66, 0.58), "alt_colour": Color(0.56, 0.52, 0.46)}],
	"earth_packed": ["ground", {"mode": 3, "base_colour": Color(0.58, 0.48, 0.36), "alt_colour": Color(0.49, 0.40, 0.30)}],
	"grass": ["ground", {"mode": 4, "base_colour": Color(0.42, 0.52, 0.26), "alt_colour": Color(0.34, 0.45, 0.21)}],
	"garden_bed": ["ground", {"mode": 5, "base_colour": Color(0.38, 0.29, 0.21), "alt_colour": Color(0.32, 0.25, 0.18), "unit": 0.5}],
	"sand_arena": ["ground", {"mode": 6, "base_colour": Color(0.86, 0.76, 0.56), "alt_colour": Color(0.79, 0.69, 0.50)}],
	"mud_bank": ["ground", {"mode": 7, "base_colour": Color(0.50, 0.42, 0.32), "alt_colour": Color(0.42, 0.36, 0.28)}],
	# --- water
	"tiber_water": ["water", {"base_colour": Color(0.42, 0.50, 0.40), "clarity": 0.1}],
	"fountain_water": ["water", {"base_colour": Color(0.50, 0.66, 0.72), "clarity": 0.6, "flow_speed": 0.1}],
}

## Plain flat colours instead of the shaders (a debugging switch: compare, or a weak GPU).
static var plain := false
static var _cache: Dictionary = {}
static var _shaders: Dictionary = {}
static var _library: Dictionary = {}        ## instance id of every material made here -> name


## The shared material for a surface name. Unknown names get a magenta material and a warning,
## so a typo shows in the picture instead of hiding.
static func get_material(name: String) -> Material:
	if _cache.has(name):
		return _cache[name]
	var m: Material = null
	if not plain and RECIPES.has(name):
		m = _shader_material(name)
	if m == null:
		m = _plain_material(name)
	_cache[name] = m
	_library[m.get_instance_id()] = name
	return m


## Whether `name` is a known surface.
static func has(name: String) -> bool:
	return COLOURS.has(name)


## Every surface name, sorted.
static func names() -> Array:
	var out := COLOURS.keys()
	out.sort()
	return out


static func _shader_material(name: String) -> Material:
	var recipe: Array = RECIPES[name]
	var family := String(recipe[0])
	if not _shaders.has(family):
		_shaders[family] = load("res://shaders/urbs/%s.gdshader" % family)
	var shader: Shader = _shaders[family]
	if shader == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = shader
	var params: Dictionary = recipe[1]
	for key in params:
		m.set_shader_parameter(key, params[key])
	m.resource_name = name
	return m


static func _plain_material(name: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name
	if COLOURS.has(name):
		m.albedo_color = COLOURS[name]
	else:
		push_warning("UrbsMaterials: unknown surface '%s'" % name)
		m.albedo_color = Color(1.0, 0.0, 1.0)
	m.roughness = 0.9
	if name.begins_with("marble") or name == "statue_marble":
		m.roughness = 0.35
	elif name in ["bronze", "gilt", "bronze_roof", "statue_bronze", "door_bronze_studded", "iron"]:
		m.metallic = 1.0
		m.roughness = 0.45
	elif name in ["tiber_water", "fountain_water"]:
		m.roughness = 0.1
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.85
	elif name == "glass_lamp":
		m.emission_enabled = true
		m.emission = COLOURS[name]
		m.emission_energy_multiplier = 2.0
	elif name == "smoke":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# --- restyle --------------------------------------------------------------------------------

## Node-name words that say which surface a plain material is (checked before the colour).
const NAME_WORDS := {
	"tegul": "tegulae", "roof": "tegulae", "ridge": "ridge_terracotta", "antefix": "antefix_terracotta",
	"brick": "brick_latericium", "reticul": "opus_reticulatum", "kerb": "travertine",
	"marble": "marble_luna", "travertin": "travertine", "basalt": "street_basalt", "gilt": "gilt",
	"bronze": "bronze", "stucco": "stucco_cream", "plaster": "stucco_cream", "awning": "awning_canvas",
	"door": "door_bronze_studded", "shutter": "shutter_wood", "timber": "timber_oak",
}
## Surfaces a ground mesh (a street, a plaza) may be.
const GROUND := ["forum_travertine", "street_basalt", "gravel", "earth_packed", "grass", "garden_bed", "sand_arena", "mud_bank"]
## Surfaces a plain colour may be taken for on a building (the colour alone is too weak a clue
## for textiles, water and the coloured marbles).
const BUILDING := ["marble_luna", "marble_pentelic", "travertine", "tufa_grey", "tufa_brown", "tufa_yellow",
	"basalt", "limestone_steps", "brick_latericium", "opus_reticulatum", "opus_incertum", "opus_quadratum",
	"rubble_wall", "stucco_white", "stucco_cream", "stucco_ochre", "stucco_red", "stucco_worn",
	"tegulae", "tegulae_old", "ridge_terracotta", "bronze", "gilt", "iron", "timber_oak",
	"timber_weathered", "shutter_wood"]
## Names of the nodes that hold the ground; restyle never goes inside them.
const TERRAIN_NODES := ["UrbsTerrain", "UrbsRiver", "Terrain", "TiberWater"]

static var _texture_means: Dictionary = {}


## Swap the plain StandardMaterial3Ds of a built subtree for library materials where the node's
## name or the colour identifies a Roman surface. Shader materials, vertex-coloured, emissive and
## transparent materials, unknown colours and the terrain are left alone. Returns how many
## surfaces were swapped. Safe to call twice.
static func restyle(root: Node) -> int:
	var swapped := 0
	var stack: Array = [[root, false]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var ground: bool = item[1]
		if _is_terrain(node):
			continue
		ground = ground or String(node.name) == "Streets" or String(node.name).begins_with("Plaza")
		if node is MeshInstance3D:
			swapped += _restyle_mesh(node as MeshInstance3D, ground)
		elif node is MultiMeshInstance3D:
			var mmi := node as MultiMeshInstance3D
			var pick := _identify(mmi.material_override, String(mmi.name), ground)
			if pick != "":
				mmi.material_override = get_material(pick)
				swapped += 1
		for child in node.get_children():
			stack.append([child, ground])
	return swapped


static func _restyle_mesh(mi: MeshInstance3D, ground: bool) -> int:
	var label := String(mi.name) + " " + String(mi.get_parent().name if mi.get_parent() != null else "")
	if mi.material_override != null:
		var pick := _identify(mi.material_override, label, ground)
		if pick != "":
			mi.material_override = get_material(pick)
			return 1
		return 0
	if mi.mesh == null:
		return 0
	var n := 0
	for i in mi.mesh.get_surface_count():
		var mat := mi.get_surface_override_material(i)
		if mat == null:
			mat = mi.mesh.surface_get_material(i)
		var pick := _identify(mat, label, ground)
		if pick != "":
			mi.set_surface_override_material(i, get_material(pick))
			n += 1
	return n


static func _is_terrain(node: Node) -> bool:
	var nm := String(node.name)
	return nm in TERRAIN_NODES or nm.begins_with("Ground_") or nm.begins_with("Chunk")


## The library name for a plain material, or "" to leave it alone.
static func _identify(mat: Material, label: String, ground: bool) -> String:
	if mat == null or not (mat is BaseMaterial3D) or _library.has(mat.get_instance_id()):
		return ""
	var m := mat as BaseMaterial3D
	if m.vertex_color_use_as_albedo or m.emission_enabled or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return ""
	var lower := label.to_lower()
	if not ground:
		for word in NAME_WORDS:
			if lower.contains(word):
				return NAME_WORDS[word]
	var c := m.albedo_color
	if m.albedo_texture != null:
		var mean := _texture_mean(m.albedo_texture)
		if mean.a < 0.0:
			return ""
		c = Color(c.r * mean.r, c.g * mean.g, c.b * mean.b)
	return _nearest(c, GROUND if ground else BUILDING, 0.16 if ground else 0.07)


static func _nearest(c: Color, candidates: Array, limit: float) -> String:
	var best := ""
	var best_d := limit
	for name in candidates:
		var k: Color = COLOURS[name]
		var d := Vector3(c.r - k.r, c.g - k.g, c.b - k.b).length()
		if d < best_d:
			best_d = d
			best = name
	return best


## The average colour of a texture (alpha -1 when it cannot be read).
static func _texture_mean(tex: Texture2D) -> Color:
	var key := tex.get_instance_id()
	if _texture_means.has(key):
		return _texture_means[key]
	var out := Color(0, 0, 0, -1.0)
	var img := tex.get_image()
	if img != null and not img.is_empty():
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		img.resize(8, 8, Image.INTERPOLATE_BILINEAR)
		var sum := Color(0, 0, 0, 0)
		for y in 8:
			for x in 8:
				sum += img.get_pixel(x, y)
		out = Color(sum.r / 64.0, sum.g / 64.0, sum.b / 64.0, 1.0)
	_texture_means[key] = out
	return out
