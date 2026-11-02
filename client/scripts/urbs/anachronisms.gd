## Urbs (F1 ideas): the works the player's ideas raised in Rome before their time.
##
## The engine records an adopted idea with `builds` in `city.anachronisms` (engine/city.py) and
## the view gives each its place and form (`form`, from engine/city.py BUILD_FORMS, through
## tools/city_view.py): the kit model, the site of the real building history raised later, its
## size, and the `twin` dataset monument that replaces it when history catches up. This script
## turns each into a monument record and hands it to UrbsMonuments, so the work is drawn,
## dated, clickable (the card says "built N years before its time by your idea"), collidable,
## kept clear of the houses and found by the spectacles like any other monument.
##
## A work stands on the real building's site while that building is absent (`twin_of`, as the
## Empire dataset uses it); when it would overlap a monument already standing, it moves to the
## nearest free spot along a fixed search pattern (so two runs place it the same way).
##
## Interface used by urbs.gd (`# F1 ideas` hook):
##   build(urbs: Node3D, city_view: Dictionary)   place the view's anachronisms in the built city
##   ids() -> Array                               the monument ids placed ("anachronism_<tech>")
##   static from_flag(flag: String, year: int) -> Dictionary
##       a city view for `--anachronisms=<builds>:<tech>[:<adopted year>],...` (renders and
##       tests without the engine): the forms come from data/city/anachronism_forms.json, the
##       mirror of BUILD_FORMS that tests keep in step.
class_name UrbsAnachronisms
extends RefCounted

const FORMS_FILE := "res://data/city/anachronism_forms.json"
const SEARCH_STEP := 40.0     ## metres between the spots tried when a site is taken
const SEARCH_RINGS := 10      ## how far out the search goes (rings of SEARCH_STEP)

var _ids: Array = []          ## monument ids this placed, sorted


## Ids of the works placed (sorted), "" when none.
func ids() -> Array:
	return _ids.duplicate()


## Places every anachronism of `city_view` ({"anachronisms": [...]}) in the city `urbs` has built.
## Call after UrbsMonuments.build and before UrbsFill.build, so the houses keep clear.
func build(urbs: Node3D, city_view: Dictionary) -> void:
	var mon: UrbsMonuments = urbs.get("monuments")
	if mon == null:
		return
	var year: int = int(urbs.get("year"))
	var wanted: Array = []
	var items: Array = city_view.get("anachronisms", []) if city_view != null else []
	for a in items:
		if a is Dictionary and a.get("form") is Dictionary:
			wanted.append(a)
	# drop records of works no longer in the view (a different game loaded)
	for old in _ids:
		if not wanted.any(func(a: Dictionary) -> bool: return str(a.get("id", "")) == old):
			mon._recs.erase(old)
			mon._routes.erase(old)
			mon._order.erase(old)
	_ids.clear()
	for a in wanted:
		var rec := record(a, mon, year)
		var id := str(rec["id"])
		mon._recs[id] = rec
		if rec.has("route"):
			mon._routes[id] = rec["route"]
		else:
			mon._routes.erase(id)
		if not mon._order.has(id):
			mon._order.append(id)
		_ids.append(id)
	_ids.sort()
	mon._order.sort()
	mon.set_year(year)


## The monument record for one anachronism `a` of the view, placed clear of what stands in `year`.
func record(a: Dictionary, mon: UrbsMonuments, year: int) -> Dictionary:
	var form: Dictionary = a["form"]
	var id := str(a.get("id", "anachronism_" + str(a.get("tech", ""))))
	var ahead := int(a.get("ahead", 0))
	var adopted := int(a.get("year", year))
	var twin := str(form.get("twin", ""))
	var model := str(form.get("model", "none"))
	var centre: Vector2 = UrbsGeo.to_local(float(form.get("lat", UrbsGeo.ORIGIN_LAT)), float(form.get("lon", UrbsGeo.ORIGIN_LON)))
	var off: Variant = form.get("offset", [0, 0])
	if off is Array and (off as Array).size() >= 2:
		centre += Vector2(float(off[0]), -float(off[1]))
	var fp := {"length": float(form.get("length", 0.0)), "width": float(form.get("width", 0.0)), "radius": float(form.get("radius", 0.0))}
	var route_form := model in ["aqueduct", "sewer", "road_paved", "wall"]
	var route_of := str(form.get("route_of", ""))
	if not route_form and (twin == "" or mon.state_at(twin, year).is_empty()):
		centre = free_site(mon, centre, fp, id)
	var latlon := UrbsGeo.to_latlon(centre)
	var early := "%d years before its time" % ahead if ahead > 0 else "in its own time"
	var rec := {
		"id": id, "latin": str(form.get("latin", "")), "english": str(a.get("name", form.get("english", ""))),
		"type": "anachronism", "regio": 0, "lat": latlon.x, "lon": latlon.y, "precision": "game",
		"location": str(form.get("site", "")),
		"built": {"year": adopted, "certainty": "", "by": "your idea, " + early},
		"form": "Built %s by your idea (%s). In our history: %s" % [early, str(form.get("site", "")), str(a.get("history", ""))],
		"sources": a.get("sources", []) + ([str(form.get("source", ""))] if str(form.get("source", "")) != "" else []),
		"model": model, "bearing_deg": float(form.get("bearing", 0)), "footprint_m": fp,
		"height_m": float(form.get("height", 0.0)), "anachronism": true, "tech": str(a.get("tech", "")),
		"ahead": ahead, "place_like": id,
		"geometry_source": "F1 ideas: " + str(form.get("source", "")),
	}
	if twin != "" and mon._recs.has(twin):
		rec["twin_of"] = twin
	if int(form.get("arcade_m", 0)) > 0:
		rec["arcade_m"] = int(form["arcade_m"])
	if route_of != "" and mon._routes.has(route_of):
		rec["route"] = mon._routes[route_of]
	return rec


## The nearest spot to `centre` where a footprint `fp` does not overlap a standing monument's
## footprint: `centre` itself, else rings of SEARCH_STEP metres in eight directions, nearest first.
static func free_site(mon: UrbsMonuments, centre: Vector2, fp: Dictionary, own_id := "") -> Vector2:
	var r := footprint_radius(fp)
	if r <= 0.0:
		return centre
	var others: Array = []
	for f in mon.footprints():
		if str(f.get("id", "")) != own_id:
			others.append(f)
	if _clear(centre, r, others):
		return centre
	for ring in range(1, SEARCH_RINGS + 1):
		for dir in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
			var p: Vector2 = centre + (dir as Vector2).normalized() * SEARCH_STEP * ring
			if p.length() < UrbsGeo.RADIUS_M and _clear(p, r, others):
				return p
	return centre


static func _clear(p: Vector2, r: float, others: Array) -> bool:
	for f in others:
		if p.distance_to(f["centre"]) < r + float(f["radius"]):
			return false
	return true


## Half the footprint's diagonal (its radius for a round plan), 0 for a work without a footprint.
static func footprint_radius(fp: Dictionary) -> float:
	var rad := float(fp.get("radius", 0.0))
	if rad > 0.0:
		return rad
	return 0.5 * Vector2(float(fp.get("width", 0.0)), float(fp.get("length", 0.0))).length()


## The forms table (the mirror of engine/city.py BUILD_FORMS), {} if the file is missing.
static func forms() -> Dictionary:
	if not FileAccess.file_exists(FORMS_FILE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FORMS_FILE))
	return parsed.get("forms", {}) if parsed is Dictionary else {}


## A city view for `--anachronisms=<builds>:<tech>[:<adopted year>],...`: each work adopted in
## the year given (default: `year`), `ahead` counted from the form's own year when the table
## carries one (it does not; renders show "in its own time" unless a year is given earlier).
static func from_flag(flag: String, year: int) -> Dictionary:
	var table := forms()
	var items: Array = []
	for part in flag.split(","):
		var f := part.strip_edges().split(":")
		if f.size() < 1 or f[0] == "":
			continue
		var builds := f[0]
		if not table.has(builds):
			push_warning("anachronisms: no form for '%s'" % builds)
			continue
		var tech := f[1] if f.size() > 1 and f[1] != "" else builds
		var adopted := int(f[2]) if f.size() > 2 else year
		var ahead := int(f[3]) if f.size() > 3 else maxi(0, year - adopted)
		items.append({"id": "anachronism_" + tech, "tech": tech, "name": str(table[builds].get("english", builds)),
			"builds": builds, "year": adopted, "ahead": ahead, "form": table[builds],
			"history": "", "sources": []})
	return {"anachronisms": items}
