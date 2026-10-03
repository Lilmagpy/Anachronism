## Checks a scenario's provinces against the real map (run headless):
##   godot --headless --path client -s res://tools/province_report.gd -- SCENARIO [OUT.json]
## Divides the map exactly as the game does (ProvinceMap) and prints, for every province,
## the land neighbours and seas it really touches, and where the content disagrees. With
## OUT.json it also writes {"provinces": {id: [neighbours]}, "seas": {id: [shores]}}.
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var bridge := EngineBridge.new()
	var repo_root := ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	if not bridge.start(repo_root):
		push_error(bridge.last_error)
		quit(1)
		return
	var view: Variant = bridge.request("new_game", {"scenario": args[0], "seed": 1})
	bridge.stop()
	if view == null or view.get("map") == null:
		push_error("scenario %s is not on a real map" % args[0])
		quit(1)
		return
	var map := ProvinceMap.new(EarthBuilder.new(str(view["map"])), view)
	var found := map.neighbours()
	var is_sea := {}
	for s in view["seas"]:
		is_sea[s["id"]] = true
	var result := {"provinces": {}, "seas": {}}
	for s in view["seas"]:
		result["seas"][s["id"]] = []
	var problems := 0
	for p in view["provinces"]:
		var land: Array = []
		for other in found.get(p["id"], []):
			if is_sea.has(other):
				result["seas"][other].append(p["id"])
			else:
				land.append(other)
		land.sort()
		result["provinces"][p["id"]] = land
		var declared: Array = p["neighbours"].duplicate()
		declared.sort()
		if declared != land:
			problems += 1
			print("%s: map says %s, content says %s" % [p["id"], land, declared])
	for sid in result["seas"]:
		result["seas"][sid].sort()
	var coasts: Dictionary = {}
	for sid in result["seas"]:
		for pid in result["seas"][sid]:
			coasts[pid] = true
	for p in view["provinces"]:
		if bool(p["coastal"]) != coasts.has(p["id"]):
			problems += 1
			print("%s: map says coastal=%s, content says %s" % [p["id"], coasts.has(p["id"]), p["coastal"]])
	print("%d problem(s)" % problems)
	if args.size() > 1:
		var f := FileAccess.open(args[1], FileAccess.WRITE)
		f.store_string(JSON.stringify(result, "  ", true))
	quit(0 if problems == 0 else 2)
