## On quitting, lets go of what the scripts keep in static variables (their model, mesh,
## material and text caches). Left held, those outlive the renderer that owns them: they were
## reported as leaks on every machine, and on Windows the program crashed on its way out once a
## game had been loaded (D-306).
class_name StaticCaches
extends RefCounted


## Empty every loaded script's static dictionaries and arrays and drop its static objects.
static func release() -> void:
	for entry in ProjectSettings.get_global_class_list():
		var path := str(entry.get("path", ""))
		if not ResourceLoader.has_cached(path):
			continue   # never loaded in this run: nothing to let go of
		var script := load(path) as GDScript
		if script == null:
			continue
		for prop in script.get_property_list():
			if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			var key := str(prop["name"])
			match int(prop["type"]):
				TYPE_DICTIONARY:
					(script.get(key) as Dictionary).clear()
				TYPE_ARRAY:
					(script.get(key) as Array).clear()
				TYPE_OBJECT:
					script.set(key, null)
