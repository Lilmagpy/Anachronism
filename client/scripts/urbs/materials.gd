## Urbs shared material library (U8). Every Urbs builder asks for a surface BY NAME; this file
## decides what it looks like, so the whole city changes together. The rendering pass replaces
## the insides of `get_material` with PBR shaders; everyone else only uses the names below and
## never builds a StandardMaterial3D of their own for a Roman surface.
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

static var _cache: Dictionary = {}


## The shared material for a surface name. Unknown names get a magenta material and a warning,
## so a typo shows in the picture instead of hiding.
static func get_material(name: String) -> Material:
	if _cache.has(name):
		return _cache[name]
	var m := StandardMaterial3D.new()
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
	_cache[name] = m
	return m


## Whether `name` is a known surface.
static func has(name: String) -> bool:
	return COLOURS.has(name)
