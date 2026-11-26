## F2 play: the places of Rome where the Republic is played (the Curia, the Rostra, the
## assemblies, the treasury, the temples, the Circus...), read from the engine's
## `view["places"]` (tools/places_view.py; the contract is in docs/plans/briefs/f2_play.md):
##
##   { "<monument id>": { role, title, blurb,
##       actions: [ {id, label, action, cost {influence, wealth, favour}, forecast {yes_bp, no_bp,
##                   tribune, tribune_bp, favour_bp, note}, enabled, why, watch} ],
##       info: [ {label, value, tip} ] } }
##
## Until the engine half lands, a view without "places" falls back on the fixture
## `client/data/fixtures/places_264.json` (written to the contract; its Curia actions are the
## real proposals of a headless 264 BC game), with `enabled` checked against the view's real
## influence. `action` is sent to the engine's `act` exactly as given; the one exception is
## kind "idea" (whisper an idea at a workshop or the harbour), which opens the idea box.
##
## Also here: the action rows the monument card and the interior panel share (`action_list`),
## the spot in an interior where its panel stands (`spot_name`), and how an action's `watch`
## finds the city event it produced (`matches`, `new_events`).
class_name UrbsPlaces
extends RefCounted

signal changed

const FIXTURE := "res://data/fixtures/places_264.json"

## The order of the "Rome this year" list: the Senate first, the people, the gods, the games.
const ROLE_ORDER := ["senate_house", "rostra", "assembly", "campus", "treasury", "temple", "circus",
	"arena", "gate", "workshop", "harbour", "domus", "anachronism"]
const ROLE_WORDS := {
	"senate_house": "The Senate meets here", "rostra": "The people are addressed here",
	"assembly": "The people vote here", "campus": "The centuries vote and the army musters here",
	"treasury": "The treasury of Rome", "temple": "A house of the gods", "circus": "The games are run here",
	"arena": "Funeral games are fought here", "gate": "The army marches out here",
	"workshop": "Craftsmen who could build an idea", "harbour": "Shipwrights who could build an idea",
	"domus": "A great family's house", "anachronism": "Your idea, built before its time",
}
## Where an interior's panel stands, by the interior kind (interiors.gd kind_of).
## F3 monuments: a temple's panel stands in the cella before the god, where the visitor comes in
## (the altar outside, where sacrifices are made, stays a spot an action may name: "altar").
const SPOTS := {"curia": "floor", "temple": "cella", "circus": "pulvinar", "arena": "rostra",
	"domus": "tablinum", "basilica": "tribunal", "theatre": "stage"}
const SPOT_WORDS := {"floor": "On the floor of the house", "cella": "Before the god", "altar": "At the altar", "pulvinar": "In the magistrates' box",
	"rostra": "At the Rostra", "tablinum": "In the tablinum", "tribunal": "At the tribunal", "stage": "Before the stage", "": "Here"}
## Places whose actions an interior also offers (the Forum's interior has the Rostra at its
## "rostra" anchor, and the Comitium beside it).
const ALSO_INSIDE := {"forum_romanum": ["rostra_republic", "comitium"]}
## The spectacle kinds a `watch` plays, and the city-event kinds that answer it.
const WATCH_EVENTS := {"senate": ["senate"], "race": ["games"], "munus": ["games"], "sacrifice": ["sacrifice"],
	"triumph": ["triumph"], "contio": ["contio"], "election": ["election"], "levy": ["levy"], "building": ["building"]}

const GOOD := Color(0.16, 0.46, 0.14)
const BAD := Color(0.70, 0.18, 0.12)
const DIM := UiStyle.INK_SOFT

var places: Dictionary = {}
var from_fixture := false
var fixture_events: Array = []     ## the fixture's year of city events (--moments)
var influence := -1                ## the view's real influence, -1 when unknown

static var _fixture: Dictionary = {}


## The fixture file, parsed once ({} when missing).
static func fixture() -> Dictionary:
	if _fixture.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
		_fixture = parsed if parsed is Dictionary else {"places": {}, "events": []}
	return _fixture


## Read the places from a game view (or the fixture, see the header).
func set_view(view: Dictionary, force_fixture := false) -> void:
	var rep: Variant = view.get("republic")
	influence = int(rep.get("influence", -1)) if rep is Dictionary else -1
	fixture_events = (fixture().get("events", []) as Array).duplicate(true)
	var given: Variant = view.get("places")
	if given is Dictionary and not force_fixture:
		places = given
		from_fixture = false
	else:
		places = (fixture().get("places", {}) as Dictionary).duplicate(true)
		from_fixture = true
		_check_fixture(view)
	changed.emit()


## The fixture does not change with the game: at least its costs follow the real influence and
## the Curia's line of it.
func _check_fixture(view: Dictionary) -> void:
	if influence < 0:
		return
	for id in places:
		for a in places[id].get("actions", []):
			var need := int((a.get("cost", {}) as Dictionary).get("influence", 0))
			if bool(a.get("enabled", true)) and need > influence:
				a["enabled"] = false
				a["why"] = "Not enough influence: %d of %d" % [influence, need]
		for row in places[id].get("info", []):
			if str(row.get("label", "")) == "Your influence":
				row["value"] = str(influence)
	var stores: Variant = (view.get("status", {}) as Dictionary).get("stores")
	if stores is Dictionary and places.has("aedes_saturni"):
		for row in places["aedes_saturni"].get("info", []):
			if str(row.get("label", "")) == "Treasury":
				row["value"] = GameHud.number(int(stores.get("wealth", 0)))


## The place on monument `id`, or {}.
func place(id: String) -> Dictionary:
	return places.get(id, {})


## The actions of `id` that can be taken now.
func open_actions(id: String) -> Array:
	return (place(id).get("actions", []) as Array).filter(func(a): return bool(a.get("enabled", true)))


## "Rome this year": the places among `standing` with actions that can be taken, in ROLE_ORDER:
## [{id, title, role, open, total}].
func todo(standing: Array) -> Array:
	var out: Array = []
	var ids: Array = places.keys()
	ids.sort()
	for id in ids:
		if not standing.has(id):
			continue
		var p: Dictionary = places[id]
		var total: int = (p.get("actions", []) as Array).size()
		var n := open_actions(str(id)).size()
		if n > 0:
			out.append({"id": str(id), "title": str(p.get("title", id)), "role": str(p.get("role", "")), "open": n, "total": total})
	out.sort_custom(func(a, b):
		var ra := ROLE_ORDER.find(a["role"])
		var rb := ROLE_ORDER.find(b["role"])
		return ra < rb if ra != rb else str(a["id"]) < str(b["id"]))
	return out


## The places an interior of monument `id` offers: its own and ALSO_INSIDE's, with actions.
func inside(id: String) -> Array:
	var out: Array = []
	for pid in [id] + (ALSO_INSIDE.get(id, []) as Array):
		if not (place(pid).get("actions", []) as Array).is_empty():
			out.append(pid)
	return out


# --- matching an action to the city event it produced ---------------------------------------

## The events of `after` that `before` did not have (by content).
static func new_events(before: Array, after: Array) -> Array:
	var seen := {}
	for e in before:
		var k := JSON.stringify(e)
		seen[k] = int(seen.get(k, 0)) + 1
	var out: Array = []
	for e in after:
		var k := JSON.stringify(e)
		if int(seen.get(k, 0)) > 0:
			seen[k] = int(seen[k]) - 1
		else:
			out.append(e)
	return out


## Whether city event `e` is what an action with `watch` plays.
static func matches(watch: String, e: Dictionary) -> bool:
	var kind := str(e.get("kind", ""))
	if not (WATCH_EVENTS.get(watch, [watch]) as Array).has(kind):
		return false
	if watch == "munus":
		return str(e.get("ref", "")) == "munus"
	if watch == "race":
		return str(e.get("ref", "")) != "munus"
	return true


# --- words ----------------------------------------------------------------------------------

## "200 influence · 150 wealth", or "free".
static func cost_text(cost: Variant) -> String:
	var parts := PackedStringArray()
	if cost is Dictionary:
		for key in ["influence", "wealth", "favour"]:
			var n := int((cost as Dictionary).get(key, 0))
			if n != 0:
				parts.append("%s %s" % [GameHud.number(n), key])
	return " · ".join(parts) if not parts.is_empty() else "free"


## The forecast in one line: "66% for, 34% against: it passes" (+ the tribune), or the note.
static func forecast_text(f: Variant) -> String:
	if not (f is Dictionary):
		return ""
	var d: Dictionary = f
	var bits := PackedStringArray()
	if d.has("yes_bp"):
		var yes := int(d["yes_bp"])
		var no := int(d.get("no_bp", 10000 - yes))
		bits.append("%d%% for, %d%% against: %s" % [roundi(yes / 100.0), roundi(no / 100.0), "it passes" if yes > no else "it fails"])
	if d.has("favour_bp") and int(d["favour_bp"]) != 0:
		bits.append("popular favour %+d%%" % roundi(int(d["favour_bp"]) / 100.0))
	var note := str(d.get("note", ""))
	if note != "":
		bits.append(note.left(1).to_upper() + note.substr(1))
	if not bits.is_empty():
		bits[0] = bits[0].left(1).to_upper() + bits[0].substr(1)
	return ". ".join(bits) + ("." if not bits.is_empty() and not bits[bits.size() - 1].ends_with(".") and not bits[bits.size() - 1].ends_with(")") else "")


static func role_words(role: String) -> String:
	return str(ROLE_WORDS.get(role, ""))


# --- the action rows (card and interior panel) -----------------------------------------------

## A list of `place`'s actions as rows; pressing one calls `on_act(action_entry)`. Rows are
## numbered from `first` (the keys 1-9 pick them). Returns the VBox; its rows are `ActionRow`s.
static func action_list(p: Dictionary, width: float, on_act: Callable, first := 1) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var n := first
	for a in p.get("actions", []):
		var row := ActionRow.new()
		row.setup(a, n, width)
		row.pressed.connect(func() -> void: on_act.call(a))
		box.add_child(row)
		n += 1
	return box


## The place's info lines ("Treasury: 628"), small; {} lines are skipped.
static func info_lines(p: Dictionary, width: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	for row in p.get("info", []):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var l := UiStyle.label(str(row.get("label", "")) + ":", 13, DIM, "body", 700)
		var v := UiStyle.label(str(row.get("value", "")), 13, UiStyle.INK, "body", 800)
		v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.custom_minimum_size.x = 40
		line.add_child(l)
		line.add_child(v)
		line.tooltip_text = str(row.get("tip", ""))
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		line.custom_minimum_size.x = width
		box.add_child(line)
	return box


## The result of the last action, as a coloured line.
static func result_line(result: Dictionary, width: float) -> Control:
	var ok := bool(result.get("accepted", false))
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GOOD, 0.12) if ok else Color(BAD, 0.10)
	style.border_color = GOOD if ok else BAD
	style.border_width_left = 4
	style.set_corner_radius_all(5)
	style.content_margin_left = 9
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var text := str(result.get("message", ""))
	if text == "":
		text = "Done." if ok else "Refused."
	var l := UiStyle.wrapped(text, 14, GOOD.darkened(0.2) if ok else BAD.darkened(0.1), width - 20.0)
	panel.add_child(l)
	return panel


## One action as a row you can click, focus with Tab or a number key, and press with Enter or
## Space: the number and label, the cost on the right, the forecast below (with the vote as a
## bar), and why it cannot be taken when it cannot.
class ActionRow extends PanelContainer:
	signal pressed

	var entry: Dictionary = {}
	var enabled := true
	var _hover := false
	var _styles := {}

	func setup(a: Dictionary, number: int, width: float) -> void:
		entry = a
		enabled = bool(a.get("enabled", true))
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
		custom_minimum_size.x = width
		for state in ["normal", "hover", "focus", "disabled"]:
			_styles[state] = _box(state)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 7)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key := UiStyle.label(str(number) if number <= 9 else "·", 13, UiStyle.CREAM if enabled else Color(0.9, 0.88, 0.84), "body", 900)
		var badge := PanelContainer.new()
		var bs := StyleBoxFlat.new()
		bs.bg_color = UiStyle.GOLD_DARK if enabled else Color(0.62, 0.59, 0.55)
		bs.set_corner_radius_all(9)
		bs.content_margin_left = 6
		bs.content_margin_right = 6
		badge.add_theme_stylebox_override("panel", bs)
		badge.add_child(key)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(badge)
		var title := UiStyle.label(str(a.get("label", a.get("id", ""))), 15, UiStyle.INK if enabled else UrbsPlaces.DIM, "body", 800)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.custom_minimum_size.x = 60
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(title)
		var cost := UiStyle.label(UrbsPlaces.cost_text(a.get("cost", {})), 12, UiStyle.GOLD_DARK if enabled else UrbsPlaces.DIM, "body", 800)
		cost.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(cost)
		col.add_child(top)
		var f: Variant = a.get("forecast", {})
		if f is Dictionary and (f as Dictionary).has("yes_bp"):
			col.add_child(_vote_bar(f, width - 40.0))
		var words := UrbsPlaces.forecast_text(f)
		if words != "":
			var fl := UiStyle.wrapped(words, 12, UrbsPlaces.DIM, width - 34.0)
			fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(fl)
		if not enabled and str(a.get("why", "")) != "":
			var why := UiStyle.wrapped("✗ " + str(a["why"]), 12, UrbsPlaces.BAD, width - 34.0)
			why.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(why)
		add_child(col)
		_restyle()
		mouse_entered.connect(func() -> void:
			_hover = true
			_restyle())
		mouse_exited.connect(func() -> void:
			_hover = false
			_restyle())
		focus_entered.connect(_restyle)
		focus_exited.connect(_restyle)
		var watch := str(a.get("watch", ""))
		tooltip_text = ("Press to do it (Enter)." + (" Then watch it happen here." if watch != "" else "")) if enabled else str(a.get("why", ""))

	func _box(state: String) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(8)
		s.content_margin_left = 7
		s.content_margin_right = 8
		s.content_margin_top = 5
		s.content_margin_bottom = 6
		s.set_border_width_all(2)
		s.border_width_bottom = 3
		match state:
			"hover":
				s.bg_color = Color(1.0, 0.92, 0.70)
				s.border_color = UiStyle.GOLD_DARK
			"focus":
				s.bg_color = Color(1.0, 0.90, 0.64)
				s.border_color = UiStyle.RED
				s.set_border_width_all(3)
			"disabled":
				s.bg_color = Color(0.90, 0.87, 0.81, 0.85)
				s.border_color = Color(0.70, 0.66, 0.60)
			_:
				s.bg_color = Color(0.99, 0.96, 0.88)
				s.border_color = Color(UiStyle.GOLD_DARK, 0.7)
		return s

	func _restyle() -> void:
		var state := "disabled" if not enabled else ("focus" if has_focus() else ("hover" if _hover else "normal"))
		add_theme_stylebox_override("panel", _styles[state])

	func _vote_bar(f: Dictionary, w: float) -> Control:
		var yes := clampi(int(f.get("yes_bp", 5000)), 0, 10000)
		var no := clampi(int(f.get("no_bp", 10000 - yes)), 0, 10000)
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(26, 7)
		bar.add_child(pad)
		var total := maxf(float(yes + no), 1.0)
		for part in [[yes, UrbsPlaces.GOOD], [no, UrbsPlaces.BAD]]:
			var r := ColorRect.new()
			r.color = Color(part[1], 0.85 if enabled else 0.35)
			r.custom_minimum_size = Vector2(maxf(1.0, w * 0.75 * float(part[0]) / total), 7)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.add_child(r)
		return bar

	func _gui_input(event: InputEvent) -> void:
		if not enabled:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if get_global_rect().has_point(get_global_mouse_position()):
				accept_event()
				pressed.emit()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
		elif event.is_action_pressed("ui_accept") and not event.is_echo():
			accept_event()
			pressed.emit()
