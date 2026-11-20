## This year in Rome (F1 client): the city's own news of the turn, in plain words, from the
## engine's `city` view. Games and funeral games, the Senate's votes, vows and dedications,
## triumphs, fires and floods, temples begun, finished or burnt, and the works your ideas
## raised before their time. Each event that Urbs can play has a Watch button, which asks
## main (through the HUD's `watch_requested`) to open the city at that venue with the event
## playing; a monument struck by fire or flood has a Look button that opens the city there.
##
## Draws only the view; keeps nothing. Names come from the city dataset shipped with the
## client (`data/city/monuments*.json`) and from the `republic` view's people.
class_name CityFeed
extends Control

signal watch_requested(event: Dictionary)   ## play this event in Urbs

const INK := UiStyle.INK
const DIM := UiStyle.INK_SOFT
const RED := Color(0.62, 0.20, 0.12)
const GOOD := Color(0.16, 0.48, 0.14)
const BAD := Color(0.72, 0.16, 0.12)
const MONTHS := ["", "January", "February", "March", "April", "May", "June", "July", "August",
	"September", "October", "November", "December"]
const FESTIVALS := {
	"ludi_romani": ["Ludi Romani", "the Roman Games: chariot races in the Circus, the senators in the front rows"],
	"ludi_plebeii": ["Ludi Plebeii", "the Plebeian Games: races in the Circus Flaminius"],
	"ludi_apollinares": ["Ludi Apollinares", "the games of Apollo: races in the Circus"],
	"ludi_megalenses": ["Ludi Megalenses", "the games of the Great Mother: plays before her temple"],
}
const ISSUE_NAMES := {"war": "war", "peace": "peace", "land": "public land", "colony": "a colony",
	"building": "public works", "idea": "a new idea", "debt": "debt", "citizenship": "citizenship"}
const STATUS_WORDS := {"building": "is begun: scaffolding rises", "standing": "is finished and dedicated",
	"burnt": "burns; it will be rebuilt", "ruined": "lies in ruins", "planned": "is vowed"}

static var _names := {}   ## monument id -> English name, read once from the dataset
static var _latin := {}

var view: Dictionary = {}
var _people := {}   ## person id -> name, from the republic view


## The English name of a monument from the client's city dataset, or the id in plain words.
static func monument_name(id: String) -> String:
	if id == "":
		return ""
	_load_names()
	if _names.has(id):
		return str(_names[id])
	return id.replace("_", " ").capitalize()


static func _load_names() -> void:
	if not _names.is_empty():
		return
	for file in ["res://data/city/monuments.json", "res://data/city/monuments_empire.json"]:
		var text := FileAccess.get_file_as_string(file)
		if text == "":
			continue
		var parsed: Variant = JSON.parse_string(text)
		var items: Variant = parsed.get("monuments", []) if parsed is Dictionary else parsed
		if not (items is Array):
			continue
		for m in items:
			if m is Dictionary and m.has("id"):
				_names[str(m["id"])] = str(m.get("english", m.get("latin", m["id"])))
				_latin[str(m["id"])] = str(m.get("latin", ""))
	if _names.is_empty():
		_names["?"] = "?"   # the files are missing: do not read them again


## A person id ("l_tarquinius_collatinus") as a name, from the view where it knows him, else
## from the id itself: "L. Tarquinius Collatinus".
func person_name(id: String) -> String:
	if id == "":
		return "a man of rank"
	if _people.has(id):
		return RepublicPanel.short_name(str(_people[id]))
	var bits := id.split("_")
	var words := PackedStringArray()
	for i in bits.size():
		var bit: String = bits[i]
		if i == 0 and bit.length() <= 3 and bits.size() > 1:
			words.append(bit.capitalize() + ".")
		else:
			words.append(bit.capitalize())
	return " ".join(words)


## Whether Urbs has a spectacle for this event (see urbs/spectacles/spectacles.gd).
static func watchable(e: Dictionary) -> bool:
	var kind := str(e.get("kind", ""))
	var ref := str(e.get("ref", ""))
	if kind == "games":
		return ref != "ludi_megalenses"
	return kind in ["senate", "sacrifice", "triumph"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(new_view: Dictionary) -> void:
	view = new_view
	_people.clear()
	var rep: Variant = view.get("republic")
	if rep != null:
		for m in rep.get("magistrates", []):
			_people[str(m["person"])] = str(m["name"])
		for p in rep.get("notable", []):
			_people[str(p["id"])] = str(p["name"])
	for child in get_children():
		child.queue_free()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.03, 0.02, 0.55)
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var book := PanelContainer.new()
	book.add_theme_stylebox_override("panel", UiStyle.ornate_panel())
	var room := get_viewport().get_visible_rect().size
	var width := minf(820.0, room.x - 40.0)
	book.custom_minimum_size = Vector2(width, 0)
	centre.add_child(book)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	book.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	# the head: the years, and a close button
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var city: Dictionary = view.get("city", {})
	var events: Array = city.get("events", [])
	var years := _years_of(events)
	titles.add_child(UiStyle.label("THIS YEAR IN ROME" if years.size() <= 1 else "THESE YEARS IN ROME", 30, RED, "title", 900))
	var span := GameHud.year_text(int(view.get("year", 0)))
	if years.size() > 1:
		span = "%s to %s" % [GameHud.year_text(int(years[0])), GameHud.year_text(int(years[years.size() - 1]))]
	elif years.size() == 1:
		span = GameHud.year_text(int(years[0]))
	titles.add_child(UiStyle.label("%s  ·  what the city saw: press Watch to stand in the crowd" % span, 14, DIM))
	head.add_child(titles)
	var shut := UiStyle.big_button("✕", 18, Color(0.85, 0.8, 0.7))
	shut.tooltip_text = "Close (Esc)"
	shut.pressed.connect(close)
	head.add_child(shut)
	column.add_child(head)
	column.add_child(_rule())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width - 28.0, 0)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	column.add_child(scroll)
	_fill(list, city, events, years, width - 60.0)
	# never taller than the screen
	var fit := func() -> void:
		if is_instance_valid(scroll) and is_instance_valid(list):
			scroll.custom_minimum_size.y = minf(list.get_combined_minimum_size().y + 4.0, room.y - 190.0)
	fit.call_deferred()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	visible = false
	queue_free()


func is_open() -> bool:
	return visible


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_R]:
			close()
			get_viewport().set_input_as_handled()


func _rule() -> Control:
	var rule := ColorRect.new()
	rule.color = Color(UiStyle.GOLD_DARK, 0.55)
	rule.custom_minimum_size.y = 2
	return rule


## The distinct years of the events, oldest first.
func _years_of(events: Array) -> Array:
	var years: Array = []
	for e in events:
		var y := int(e.get("year", 0))
		if not years.has(y):
			years.append(y)
	years.sort()
	return years


func _fill(list: VBoxContainer, city: Dictionary, events: Array, years: Array, width: float) -> void:
	var changed: Array = city.get("changed", [])
	var statuses := {}
	for m in city.get("monuments", []):
		statuses[str(m["id"])] = m
	var anachronisms: Array = city.get("anachronisms", [])
	var span := int(view.get("years_per_turn", 1))
	var now := int(view.get("year", 0))
	var recent: Array = anachronisms.filter(func(a): return int(a.get("year", -99999)) > now - span)
	if events.is_empty() and changed.is_empty() and recent.is_empty():
		list.add_child(UiStyle.wrapped("A quiet year in the city: no games fell due, the Senate held no vote of note, no temple was vowed or finished. The streets go on as ever; press Visit Rome to walk them.", 16, INK, width))
		return
	# what you built, first: it is the point of the game
	for a in recent:
		var card := _row(RED, "✦ %s" % str(a.get("name", a.get("tech", ""))).to_upper(),
			"An idea of yours takes shape in stone: %s rises in Rome, %s years before its time." % [_builds_words(str(a.get("builds", ""))), GameHud.number(int(a.get("ahead", 0)))],
			GameHud.year_text(int(a.get("year", now))), null, width)
		list.add_child(card)
	# the monuments whose state changed this turn
	for id in changed:
		var m: Dictionary = statuses.get(str(id), {})
		var status := str(m.get("status", "standing"))
		var words := str(STATUS_WORDS.get(status, "changes"))
		if status == "burnt" and int(m.get("years_left", 0)) > 0:
			words = "burns; about %d years to rebuild" % int(m["years_left"])
		elif status == "building" and int(m.get("years_left", 0)) > 0:
			words = "is begun; about %d years of work" % int(m["years_left"])
		var tint := BAD if status in ["burnt", "ruined"] else GOOD
		var look := {"kind": "look", "year": now, "ref": status, "monument": str(id), "person": "", "value": 0, "other": 0}
		list.add_child(_row(tint, "THE CITY CHANGES", "%s %s." % [monument_name(str(id)), words], GameHud.year_text(now), look, width, "Look"))
	# the events, year by year
	for y in years:
		if years.size() > 1:
			list.add_child(UiStyle.label(GameHud.year_text(int(y)), 18, RED, "title", 800))
		for e in events:
			if int(e.get("year", 0)) != int(y):
				continue
			var told := _words(e)
			list.add_child(_row(told[2], told[0], told[1], _when(e), e if watchable(e) else null, width))


## [heading, sentence, colour] for one city event, in plain words.
func _words(e: Dictionary) -> Array:
	var kind := str(e.get("kind", ""))
	var ref := str(e.get("ref", ""))
	var venue := monument_name(str(e.get("monument", "")) if e.get("monument") != null else "")
	var who := person_name(str(e.get("person", "")) if e.get("person") != null else "")
	var value := int(e.get("value", 0)) if e.get("value") != null else 0
	var other := int(e.get("other", 0)) if e.get("other") != null else 0
	match kind:
		"games":
			if ref == "munus":
				return ["FUNERAL GAMES", "%s is dead. His heirs give a munus at his funeral in the %s: pairs of gladiators fight before the crowd." % [who, venue if venue != "" else "Forum"], Color(0.45, 0.30, 0.30)]
			var festival: Array = FESTIVALS.get(ref, [ref.replace("_", " ").capitalize(), "games"])
			var month := str(MONTHS[value]) if value >= 1 and value <= 12 else ""
			return ["GAMES", "%s%s: %s%s." % [str(festival[0]), " in " + month if month != "" else "", str(festival[1]), " at the " + venue if venue != "" else ""], Color(0.62, 0.42, 0.10)]
		"senate":
			var carried := value > other
			return ["THE SENATE", "The Senate meets%s and votes on %s: %d%% for, %d%% against. The motion is %s." % [
				" in the " + venue if venue != "" else "", str(ISSUE_NAMES.get(ref, ref.replace("_", " "))), value / 100, other / 100, "carried" if carried else "refused"],
				GOOD if carried else BAD]
		"sacrifice":
			if ref == "dedication":
				return ["DEDICATION", "The %s is dedicated: a sacrifice at the altar, the god takes his house, and the people feast." % venue, GOOD]
			return ["A VOW", "A vow is made at the %s: a temple promised to the god in return for his favour." % venue, Color(0.30, 0.38, 0.55)]
		"triumph":
			var over := "over the enemy" if ref == "" else ("for the taking of the enemy's capital" if ref == "capital" else "for the victory at " + ref.replace("_", " ").capitalize())
			return ["TRIUMPH", "%s rides in triumph %s: the procession enters by the Campus Martius, rounds the Circus Maximus and climbs the Via Sacra to the Capitol." % [who, over], Color(0.62, 0.20, 0.12)]
		"fire":
			return ["FIRE", "Fire in the city: the %s burns." % venue, BAD]
		"flood":
			return ["FLOOD", "The Tiber rises and floods the %s." % venue, Color(0.20, 0.42, 0.55)]
	return [kind.to_upper(), "%s %s%s." % [kind.capitalize(), ref, " at the " + venue if venue != "" else ""], DIM]


func _when(e: Dictionary) -> String:
	return GameHud.year_text(int(e.get("year", 0)))


func _builds_words(builds: String) -> String:
	var words := {"aqueduct": "an aqueduct on arches", "dome": "a great dome", "road": "a paved road out of the city",
		"bridge": "a stone bridge", "basilica": "a basilica", "theatre": "a stone theatre", "sewer": "a vaulted sewer",
		"harbour": "a built harbour", "wall": "new walls", "granary": "great granaries", "bath": "public baths",
		"mill": "a water mill", "lighthouse": "a lighthouse"}
	return str(words.get(builds, "a " + builds.replace("_", " ") if builds != "" else "a new work"))


## One event on a line: a coloured heading, the sentence, the year, and Watch if Urbs can play it.
func _row(tint: Color, heading: String, sentence: String, when: String, event: Variant, width: float, verb := "Watch") -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.96, 0.88)
	style.border_color = tint
	style.set_border_width_all(0)
	style.border_width_left = 5
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UiStyle.label(heading, 12, tint, "body", 800))
	head.add_child(UiStyle.label(when, 12, DIM, "body", 700))
	text.add_child(head)
	var words := UiStyle.wrapped(sentence, 15, INK, width - (130.0 if event != null else 20.0))
	words.add_theme_constant_override("line_spacing", -3)
	text.add_child(words)
	row.add_child(text)
	if event != null:
		var watch := UiStyle.big_button(verb + "  ▸", 15)
		watch.custom_minimum_size = Vector2(104, 40)
		watch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		watch.tooltip_text = ("Open the city of Rome at the %s with this playing before you." % monument_name(str(event.get("monument", ""))) if verb == "Watch"
			else "Open the city of Rome at the %s." % monument_name(str(event.get("monument", ""))))
		watch.pressed.connect(func(): watch_requested.emit(event))
		row.add_child(watch)
	card.add_child(row)
	return card
