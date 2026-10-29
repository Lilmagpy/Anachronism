## The Republic panel (D-286): the owner's window onto the Roman state, written for someone
## who has not read Livy. It shows who holds office this year, how the Senate leans and what
## it would vote, what can be put to it, the great families and the notable men, and the
## Fasti (the list of consuls by year).
##
## It draws only what the engine's `republic` view says and keeps no game state: the view is
## handed in by `show_republic`, and the player's choices leave as `action_requested`. The
## only things remembered here are which sections and rows are unfolded (a viewing
## preference, kept in static variables so a refresh of the HUD does not fold them again).
##
## The actions it sends (each built in exactly one function, so the shapes are easy to fix):
##   propose_to_senate  {"kind", "issue", "proposal"}   see `_propose_action`
##   persuade           {"kind", "family", "issue"}     see `_persuade_action`
##   back_candidate     {"kind", "person", "office"}    see `_back_action`
class_name RepublicPanel
extends VBoxContainer

signal action_requested(action: Dictionary)

const INK := UiStyle.INK
const DIM := UiStyle.INK_SOFT
const HEADING := Color(0.62, 0.20, 0.12)
const GOOD := Color(0.16, 0.48, 0.14)
const BAD := Color(0.72, 0.16, 0.12)
const GOLD_BAR := Color(0.80, 0.55, 0.12)
const WEALTH_BAR := Color(0.30, 0.52, 0.34)
const TRACK := Color(0.85, 0.80, 0.70)
const CARD := Color(0.99, 0.96, 0.88)
const PATRICIAN := Color(0.46, 0.22, 0.52)
const PLEBEIAN := Color(0.20, 0.42, 0.55)

## What each issue the Senate votes on means, in plain words.
const ISSUES := {
	"war": ["War", "Whether Rome goes to war or raises legions."],
	"peace": ["Peace", "Whether Rome makes peace or a treaty."],
	"land": ["Land", "Dividing public land among the citizens."],
	"colony": ["Colonies", "Founding new colonies of citizens in conquered land."],
	"building": ["Public works", "Paying for temples, roads, aqueducts and other buildings."],
	"idea": ["New ideas", "Whether Rome tries an unfamiliar idea of yours."],
	"debt": ["Debt", "Relief for citizens drowning in debt."],
	"citizenship": ["Citizenship", "Giving Roman citizenship to other peoples."],
}
const ISSUE_ORDER := ["war", "peace", "land", "colony", "building", "idea", "debt", "citizenship"]

## The blocs of the Senate, as the era names them.
const BLOCS := {
	"patricians": "The old noble families, who once held every office.",
	"plebeians": "The common citizens and their leaders, who won a share of power.",
	"nobiles": "Families that have held the consulship: patricians and plebeians who now rule together.",
	"optimates": "Senators who defend the Senate's authority and the old order.",
	"populares": "Politicians who appeal to the people's assemblies over the head of the Senate.",
}

## Offices: plural heading, what they do, in the order the panel lists them.
const OFFICES := {
	"dictator": ["Dictator", "named alone in an emergency"],
	"magister_equitum": ["Master of the horse", "the dictator's deputy"],
	"consul": ["Consuls", "the two heads of state and army"],
	"consular_tribune": ["Consular tribunes", "ruled in place of the consuls"],
	"censor": ["Censors", "count the citizens, judge morals"],
	"praetor": ["Praetors", "judges, and governors abroad"],
	"aedile_curule": ["Curule aediles", "games, markets and streets"],
	"aedile_plebeian": ["Plebeian aediles", "games, markets and streets"],
	"tribune_plebs": ["Tribunes of the plebs", "protect the people; may veto"],
	"quaestor": ["Quaestors", "keep the treasury, pay the army"],
}
const OFFICE_LADDER := ["quaestor", "aedile", "praetor", "consul", "censor"]
const PRAENOMINA := {
	"Aulus": "A.", "Appius": "Ap.", "Decimus": "D.", "Gaius": "C.", "Gnaeus": "Cn.", "Kaeso": "K.",
	"Lucius": "L.", "Manius": "M'.", "Marcus": "M.", "Mamercus": "Mam.", "Numerius": "N.",
	"Publius": "P.", "Quintus": "Q.", "Servius": "Ser.", "Sextus": "Sex.", "Spurius": "Sp.",
	"Tiberius": "Ti.", "Titus": "T.", "Vibius": "V.",
}
const TRAITS := {
	"novus": ["New man", "The first of his family to reach the Senate."],
}

## Sections the player folded and rows the player unfolded; kept across refreshes.
static var _folded := {}
static var _open := {}

var colour := UiStyle.GOLD       ## Rome's colour, for the portraits
var _rep: Dictionary = {}


## Unfold a family's row from outside (screenshots and tests): `family_id` as in the view.
static func unfold_family(family_id: String) -> void:
	_open["f:" + family_id] = true


## A little painted symbol: `senate` (a temple front, for the tab), `laurel` (a real person),
## `open` / `shut` (a section's arrow).
class Glyph:
	extends Control

	var kind := "laurel"
	var tint := Color(0.30, 0.50, 0.18)

	func _init(glyph_kind := "laurel", px := 16.0, glyph_tint := Color(0.30, 0.50, 0.18)) -> void:
		kind = glyph_kind
		tint = glyph_tint
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size / 2.0
		match kind:
			"open":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.15),
					c + Vector2(s * 0.3, -s * 0.15), c + Vector2(0, s * 0.25)]), tint)
			"shut":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.15, -s * 0.3),
					c + Vector2(s * 0.25, 0), c + Vector2(-s * 0.15, s * 0.3)]), tint)
			"laurel":
				# a wreath: two sprays of leaves up either side, open at the top
				var radius := s * 0.34
				var centre := c + Vector2(0, s * 0.04)
				for side in [-1, 1]:
					for i in 6:
						var phi: float = deg_to_rad(90.0 + side * (18.0 + i * 25.0))   # round from the bottom up the side
						var at := centre + Vector2(cos(phi), sin(phi)) * radius
						var tangent: float = phi + side * PI / 2.0
						draw_set_transform(at, tangent + side * 0.5, Vector2.ONE)
						draw_colored_polygon(_leaf(s * 0.2), tint)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"senate":
				var ink := Color(0.25, 0.16, 0.08)
				var stone := Color(0.93, 0.86, 0.68)
				draw_colored_polygon(PackedVector2Array([Vector2(c.x, c.y - s * 0.44),
					Vector2(c.x + s * 0.46, c.y - s * 0.16), Vector2(c.x - s * 0.46, c.y - s * 0.16)]), stone)
				draw_polyline(PackedVector2Array([Vector2(c.x - s * 0.46, c.y - s * 0.16),
					Vector2(c.x, c.y - s * 0.44), Vector2(c.x + s * 0.46, c.y - s * 0.16),
					Vector2(c.x - s * 0.46, c.y - s * 0.16)]), ink, 1.5)
				for i in 4:
					var x := c.x - s * 0.34 + i * s * 0.227
					draw_rect(Rect2(x - s * 0.04, c.y - s * 0.12, s * 0.08, s * 0.4), stone)
					draw_rect(Rect2(x - s * 0.04, c.y - s * 0.12, s * 0.08, s * 0.4), ink, false, 1.2)
				draw_rect(Rect2(c.x - s * 0.46, c.y + s * 0.28, s * 0.92, s * 0.12), Color(0.80, 0.58, 0.20))
				draw_rect(Rect2(c.x - s * 0.46, c.y + s * 0.28, s * 0.92, s * 0.12), ink, false, 1.2)

	func _leaf(r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 10:
			var a := TAU * i / 10.0
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.45))
		return pts


## A bar made of coloured stretches (fractions 0..1 of its width) on a pale track.
class Bar:
	extends Control

	var segments: Array = []   ## [from, to, Color]
	var tick := false          ## a mark in the middle (for bars that run both ways)

	func _init(bar_height := 12.0) -> void:
		custom_minimum_size = Vector2(40, bar_height)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.85, 0.80, 0.70)
		back.set_corner_radius_all(int(size.y / 2.0))
		draw_style_box(back, Rect2(Vector2.ZERO, size))
		for seg in segments:
			var from_x: float = clampf(float(seg[0]), 0.0, 1.0) * size.x
			var to_x: float = clampf(float(seg[1]), 0.0, 1.0) * size.x
			if to_x - from_x < 1.0:
				continue
			var box := StyleBoxFlat.new()
			box.bg_color = seg[2]
			box.set_corner_radius_all(int(size.y / 2.0))
			draw_style_box(box, Rect2(from_x, 0, maxf(to_x - from_x, size.y * 0.6), size.y))
		if tick:
			draw_line(Vector2(size.x / 2.0, 0), Vector2(size.x / 2.0, size.y), Color(0.3, 0.22, 0.12, 0.8), 2.0)


## The tab's picture for the Senate (the HUD's own icons have no temple).
static func tab_icon(px := 22.0) -> Control:
	return Glyph.new("senate", px)


## Fill the panel from the `republic` view; `rome_colour` tints the portraits.
func show_republic(rep: Variant, rome_colour: Color) -> void:
	colour = rome_colour
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if typeof(rep) != TYPE_DICTIONARY:
		add_child(_wrap("There is no Senate in this age.", 14, DIM))
		return
	_rep = rep
	_build_header()
	_build_this_year()
	_build_senate()
	if _rep.has("proposals"):
		_build_proposals()
	_build_families()
	_build_notable()
	_build_fasti()


# --- small pieces -----------------------------------------------------------------------

static func _px(size: int) -> int:
	return size + 3 if size <= 13 else size + 2


func _t(text: String, size := 14, tint := INK, weight := 700) -> Label:
	return UiStyle.label(text, _px(size), tint, "body", weight)


## A label that wraps to the width it is given.
func _wrap(text: String, size := 14, tint := DIM, weight := 600) -> Label:
	var label := _t(text, size, tint, weight)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 60
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_constant_override("line_spacing", -4)   # Nunito's lines are tall; keep paragraphs snug
	return label


func _chip(text: String, back: Color, tip := "", fore := Color.WHITE) -> Control:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = back
	style.set_corner_radius_all(9)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	box.add_theme_stylebox_override("panel", style)
	box.add_child(_t(text, 12, fore, 800))
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if tip != "":
		box.tooltip_text = UiStyle.wrap_tip(tip, 48)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


func _card(tint := CARD) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = Color(0.78, 0.66, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _bar(segments: Array, tick := false, height := 12.0, tip := "") -> Bar:
	var bar := Bar.new(height)
	bar.segments = segments
	bar.tick = tick
	if tip != "":
		bar.tooltip_text = UiStyle.wrap_tip(tip, 48)
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
	return bar


func _small_button(text: String, action: Callable, enabled := true, tip := "") -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not enabled
	button.add_theme_font_size_override("font_size", _px(13))
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if tip != "":
		button.tooltip_text = UiStyle.wrap_tip(tip, 48)
	button.pressed.connect(action)
	return button


## Makes a control answer a left click (a hand cursor shows it can be pressed).
func _clickable(control: Control, on_click: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_click.call())


## A section: a heading you can click to fold, over a body; returns the body to fill.
func _section(id: String, title: String, note := "") -> VBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var name := UiStyle.label(title.to_upper(), _px(16), HEADING, "title", 900)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.clip_text = true
	head.add_child(name)
	var arrow := Glyph.new("shut" if _folded.has(id) else "open", 16.0, HEADING)
	head.add_child(arrow)
	head.custom_minimum_size.y = 30
	add_child(head)
	var rule := ColorRect.new()
	rule.color = Color(UiStyle.GOLD_DARK, 0.55)
	rule.custom_minimum_size.y = 2
	add_child(rule)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	body.visible = not _folded.has(id)
	if note != "":
		body.add_child(_wrap(note, 13, DIM))
	add_child(body)
	_clickable(head, func():
		body.visible = not body.visible
		if body.visible:
			_folded.erase(id)
		else:
			_folded[id] = true
		arrow.kind = "open" if body.visible else "shut"
		arrow.queue_redraw())
	return body


static func _num(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	while text.length() > 3:
		out = "," + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + out


func _pct(bp: int) -> String:
	return "%d%%" % roundi(bp / 100.0)


func _years(year: int) -> String:
	return "%d BC" % -year if year < 0 else "AD %d" % year


## "Lucius Tarquinius Collatinus" -> "L. Tarquinius Collatinus" (Roman writing, and shorter).
static func short_name(full: String) -> String:
	var parts := full.split(" ", false)
	if parts.size() >= 3 and PRAENOMINA.has(parts[0]):
		parts[0] = PRAENOMINA[parts[0]] + "\u00a0" + parts[1]   # a non-breaking space: "M'. Valerius" never splits
		parts.remove_at(1)
	return " ".join(parts)


func _order_chip(order: String) -> Control:
	if order == "patrician":
		return _chip("Patrician", PATRICIAN, "Born into one of the old noble families.")
	if order == "plebeian":
		return _chip("Plebeian", PLEBEIAN, "A commoner by birth; the plebeians won the right to high office step by step.")
	return _chip(order.capitalize(), DIM)


func _issue_name(issue: String) -> String:
	return str(ISSUES[issue][0]) if ISSUES.has(issue) else issue.capitalize()


func _issue_help(issue: String) -> String:
	return str(ISSUES[issue][1]) if ISSUES.has(issue) else ""


## How a leaning (-10000..10000) reads in words.
func _lean_word(bp: int) -> String:
	if bp >= 6000:
		return "strongly for"
	if bp >= 2000:
		return "for"
	if bp > 0:
		return "leans for"
	if bp <= -6000:
		return "strongly against"
	if bp <= -2000:
		return "against"
	if bp < 0:
		return "leans against"
	return "no view"


func _lean_colour(bp: int) -> Color:
	if bp > 0:
		return GOOD
	if bp < 0:
		return BAD
	return DIM


## A bar that runs left (against, red) or right (for, green) from the middle.
func _lean_bar(bp: int, scale_bp := 10000.0, height := 10.0, tip := "") -> Bar:
	var half := clampf(bp / scale_bp, -1.0, 1.0) * 0.5
	var segments: Array = []
	if half > 0.0:
		segments.append([0.5, 0.5 + half, GOOD])
	elif half < 0.0:
		segments.append([0.5 + half, 0.5, BAD])
	return _bar(segments, true, height, tip)


# --- the top of the tab -----------------------------------------------------------------

func _build_header() -> void:
	add_child(_wrap("You do not command Rome: you advise. Win families over with your influence and the Senate may follow.", 13, DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var influence := _chip("Influence %s" % _num(int(_rep.get("influence", 0))), UiStyle.GOLD_DARK,
		"Your standing with the Senate. You spend it to win a family over on an issue, to back a man at an election, or to put a proposal to the Senate.")
	row.add_child(influence)
	var emergency := int(_rep.get("emergency_bp", 0))
	if emergency > 0:
		row.add_child(_chip("Emergency %s" % _pct(emergency), BAD,
			"Rome is at war or in danger. The worse it is, the likelier the Senate names a dictator for six months."))
	if bool(_rep.get("history_turned", false)):
		row.add_child(_chip("History has turned", Color(0.35, 0.30, 0.55),
			"Rome's story has left the one in the books: some magistrates are no longer the real ones."))
	add_child(row)
	var census: Array = _rep.get("census", [])
	if not census.is_empty():
		var last: Dictionary = census[census.size() - 1]
		add_child(_wrap("Last census (%s): %s citizens." % [_years(int(last["year"])), _num(int(last["citizens"]))], 13, DIM))


# --- this year ----------------------------------------------------------------------------

func _build_this_year() -> void:
	var body := _section("year", "This year, %s" % str(_rep.get("year_label", "")))
	var mags: Array = _rep.get("magistrates", [])
	var consuls: Array = mags.filter(func(m): return m["office"] == "consul")
	consuls.sort_custom(func(a, b): return (1 if a["suffect"] else 0) < (1 if b["suffect"] else 0))
	var shown := consuls.slice(0, 2)
	if shown.is_empty():
		body.add_child(_wrap("There are no consuls this year.", 14, DIM))
	for m in shown:
		body.add_child(_consul_card(m))
	# everyone else, grouped by office in rank order
	var rest: Array = mags.filter(func(m): return not shown.has(m))
	var order: Array = []
	var groups := {}
	for m in rest:
		var key: String = str(m["office"])
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(m)
	order.sort_custom(func(a, b): return _office_rank(a) < _office_rank(b))
	for key in order:
		body.add_child(_office_group(key, groups[key], mags))


func _office_rank(office: String) -> int:
	var keys: Array = OFFICES.keys()
	var at: int = keys.find(office)
	return at if at >= 0 else keys.size()


func _consul_card(m: Dictionary) -> Control:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_portrait(str(m["person"]), 74, 92, _age_of(m)))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := "Suffect consul" if bool(m["suffect"]) else "Consul"
	text.add_child(_t(title.to_upper(), 12, HEADING, 800))
	var name := _wrap(str(m["name"]), 16, INK, 800)
	text.add_child(name)
	var facts := "Gens %s" % str(m["gens"]).capitalize()
	var age := _age_of(m)
	if age > 0:
		facts += " · age %d" % age
	text.add_child(_wrap(facts, 13, DIM))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 5)
	chips.add_theme_constant_override("v_separation", 3)
	chips.add_child(_order_chip(str(m["order"])))
	if bool(m.get("from_fasti", false)):
		chips.add_child(_chip("From the Fasti", Color(0.30, 0.38, 0.55),
			"History's own consul for this year: the election went as it did in Rome's records."))
	else:
		chips.add_child(_chip("Elected by you", UiStyle.GOLD_DARK,
			"Not taken from the Fasti: the game's own election chose him, with your influence in it."))
	if bool(m.get("historical", false)):
		chips.add_child(Glyph.new("laurel", 18.0))
	text.add_child(chips)
	row.add_child(text)
	card.add_child(row)
	return card


func _age_of(m: Dictionary) -> int:
	var age: Variant = m.get("age")
	return int(age) if typeof(age) == TYPE_FLOAT or typeof(age) == TYPE_INT else 0


## A Portrait in the Roman style; the same id always gives the same face, and the face is aged.
func _portrait(id: String, width: float, height: float, age_years := 0) -> Control:
	var portrait := Portrait.new()
	portrait.custom_minimum_size = Vector2(width, height)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.setup({"colour": colour, "portrait": "roman", "culture": "roman", "id": "senate_" + id})
	if age_years > 0:
		portrait.age = clampf((age_years - 28.0) / 50.0, 0.0, 1.0)
	return portrait


func _office_group(office: String, members: Array, all: Array) -> Control:
	var info: Array = OFFICES.get(office, [office.capitalize(), ""])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(_t(str(info[0]), 14, INK, 800))
	var blurb := _t("· " + str(info[1]), 12, DIM, 600)
	blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blurb.clip_text = true
	head.add_child(blurb)
	box.add_child(head)
	var names := PackedStringArray()
	for m in members:
		var label := short_name(str(m["name"]))
		if bool(m["suffect"]):
			label += " (suffect)"
		if office == "magister_equitum" and str(m["master_of"]) != "":
			for other in all:
				if other["person"] == m["master_of"]:
					label += ", under %s" % short_name(str(other["name"]))
		names.append(label)
	box.add_child(_wrap("; ".join(names), 13, INK, 600))
	return box


# --- the Senate ---------------------------------------------------------------------------

func _build_senate() -> void:
	var senate: Dictionary = _rep.get("senate", {})
	var body := _section("senate", "The Senate",
		"Senators gather in blocs. A bloc's weight is how much of the Senate it holds; its mood is how willing it is to go along with new business.")
	var blocs_now: Array = senate.get("blocs_now", [])
	for faction in senate.get("factions", []):
		if not blocs_now.is_empty() and not blocs_now.has(faction["id"]):
			continue
		body.add_child(_bloc_card(faction))
	body.add_child(_t("If the Senate voted today", 15, HEADING, 800))
	body.add_child(_wrap("Each family leans for or against each matter; a vote carries if more of the Senate's weight is for than against.", 12, DIM))
	for vote in senate.get("votes", []):
		body.add_child(_vote_row(vote))


func _bloc_card(faction: Dictionary) -> Control:
	var card := _card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.add_child(_t(str(faction["name"]), 15, INK, 800))
	var id := str(faction["id"])
	if BLOCS.has(id):
		box.add_child(_wrap(str(BLOCS[id]), 12, DIM))
	var weight := int(faction["weight_bp"])
	box.add_child(_bar_row("Weight", _bar([[0.0, weight / 10000.0, GOLD_BAR]], false, 12.0,
		"How much of the Senate's total weight this bloc holds."), _pct(weight)))
	var mood := int(faction["mood_bp"])
	box.add_child(_bar_row("Mood", _lean_bar(mood, 4000.0, 12.0,
		"How readily the bloc goes along with new business, averaged over every issue. Red: reluctant. Green: willing."),
		_mood_word(mood), _lean_colour(mood)))
	var issues: Dictionary = faction.get("issues", {})
	var keen: Array = []
	var wary: Array = []
	for issue in ISSUE_ORDER:
		var lean := int(issues.get(issue, 0))
		if lean >= 500:
			keen.append([lean, _issue_name(issue)])
		elif lean <= -500:
			wary.append([-lean, _issue_name(issue)])
	keen.sort_custom(func(a, b): return a[0] > b[0])
	wary.sort_custom(func(a, b): return a[0] > b[0])
	if not keen.is_empty():
		box.add_child(_wrap("Keenest on: " + ", ".join(keen.slice(0, 3).map(func(k): return k[1])), 12, GOOD))
	if not wary.is_empty():
		box.add_child(_wrap("Against: " + ", ".join(wary.slice(0, 3).map(func(k): return k[1])), 12, BAD))
	card.add_child(box)
	return card


func _mood_word(bp: int) -> String:
	if bp >= 2500:
		return "eager"
	if bp >= 800:
		return "willing"
	if bp > -800:
		return "undecided"
	if bp > -2500:
		return "wary"
	return "hostile"


## A caption, a bar and a figure on one line.
func _bar_row(caption: String, bar: Control, figure: String, figure_colour := INK) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var cap := _t(caption, 12, DIM, 700)
	cap.custom_minimum_size.x = 52
	row.add_child(cap)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value := _t(figure, 12, figure_colour, 800)
	value.custom_minimum_size.x = 66
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row


func _vote_row(vote: Dictionary) -> Control:
	var issue := str(vote["issue"])
	var yes := int(vote["yes_bp"])
	var no := int(vote["no_bp"])
	var passes := bool(vote["passes"])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var name := _t(_issue_name(issue), 14, INK, 800)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	if yes + no == 0:
		head.add_child(_chip("No one cares", DIM, "No family has a view on this yet."))
	elif passes:
		head.add_child(_chip("Would pass", GOOD, "More of the Senate's weight is for this than against."))
	else:
		head.add_child(_chip("Would fail", BAD, "More of the Senate's weight is against this than for it."))
	box.add_child(head)
	box.add_child(_wrap(_issue_help(issue), 12, DIM))
	if yes + no == 0:
		return box
	var segments: Array = [[0.0, yes / 10000.0, GOOD], [1.0 - no / 10000.0, 1.0, BAD]]
	var bar := _bar(segments, false, 10.0, "Green: share of the Senate's weight for. Red: against. The grey between is indifferent.")
	box.add_child(bar)
	box.add_child(_t("For %s · Against %s" % [_pct(yes), _pct(no)], 12, DIM, 700))
	return box


# --- what you can put to the Senate -------------------------------------------------------

func _build_proposals() -> void:
	var body := _section("proposals", "Put to the Senate",
		"Business you can bring before the Senate this year. The bar forecasts the vote: green for, red against.")
	var proposals: Array = _rep.get("proposals", [])
	if proposals.is_empty():
		body.add_child(_wrap("Nothing to put to the Senate just now.", 14, DIM))
		return
	var influence := int(_rep.get("influence", 0))
	for p in proposals:
		var cost := int(p.get("cost", 0))
		var yes := int(p.get("forecast_yes_bp", 0))
		var no := int(p.get("forecast_no_bp", 0))
		var card := _card()
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		box.add_child(_wrap(str(p.get("label", p.get("proposal", ""))), 14, INK, 800))
		box.add_child(_wrap(_issue_help(str(p.get("issue", ""))), 12, DIM))
		box.add_child(_bar([[0.0, yes / 10000.0, GOOD], [1.0 - no / 10000.0, 1.0, BAD]], false, 10.0,
			"Forecast of the vote if you put it to the Senate."))
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 8)
		var forecast := _t("Forecast: %s for, %s against" % [_pct(yes), _pct(no)], 12, DIM, 700)
		forecast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(forecast)
		var action := _propose_action(p)
		foot.add_child(_small_button("Put to the Senate (%d)" % cost if cost > 0 else "Put to the Senate",
			func(): action_requested.emit(action), cost <= influence,
			"Costs %d influence; you have %d." % [cost, influence] if cost > 0 else ""))
		box.add_child(foot)
		card.add_child(box)
		body.add_child(card)


## The action for a proposal. (One place to change if the engine's key names differ.)
func _propose_action(p: Dictionary) -> Dictionary:
	return {"kind": "propose_to_senate", "issue": str(p.get("issue", "")), "proposal": str(p.get("proposal", ""))}


## The action for winning a family over on an issue.
func _persuade_action(family_id: String, issue: String) -> Dictionary:
	return {"kind": "persuade", "family": family_id, "issue": issue}


## The action for backing a man at the coming election for an office.
func _back_action(person_id: String, office: String) -> Dictionary:
	return {"kind": "back_candidate", "person": person_id, "office": office}


# --- the great families -------------------------------------------------------------------

func _build_families() -> void:
	var body := _section("families", "The great families",
		"The old houses that fill the Senate. Dignitas is a family's standing in Rome; the more it has, the more its voice weighs. Press a family to see where it stands and to win it over.")
	var families: Array = _rep.get("families", [])
	var rows := families.duplicate()
	rows.sort_custom(func(a, b):
		var a_alive: int = 1 if int(a["living"]) > 0 else 0
		var b_alive: int = 1 if int(b["living"]) > 0 else 0
		if a_alive != b_alive:
			return a_alive > b_alive
		return int(a["dignitas_bp"]) > int(b["dignitas_bp"]))
	var top_dignitas := 1
	var top_wealth := 1
	for f in families:
		top_dignitas = maxi(top_dignitas, int(f["dignitas_bp"]))
		top_wealth = maxi(top_wealth, int(f["wealth"]))
	for f in rows:
		body.add_child(_family_card(f, top_dignitas, top_wealth))


func _family_card(f: Dictionary, top_dignitas: int, top_wealth: int) -> Control:
	var id := str(f["id"])
	var living := int(f["living"])
	var card := _card(CARD if living > 0 else Color(0.93, 0.89, 0.80))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	var open := _open.has("f:" + id)
	var arrow := Glyph.new("open" if open else "shut", 14.0, DIM)
	line.add_child(arrow)
	var name := _t(str(f["name"]), 15, INK if living > 0 else DIM, 800)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(name)
	line.add_child(_order_chip(str(f["order"])))
	var members := _t("%d living" % living if living > 0 else "no living men", 12, DIM, 700)
	members.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(members)
	head.add_child(line)
	var dignitas := int(f["dignitas_bp"])
	head.add_child(_bar_row("Dignitas", _bar([[0.0, float(dignitas) / top_dignitas, GOLD_BAR]], false, 10.0,
		"Dignitas: the family's standing in Rome, won through offices, triumphs and old renown. It sets how much its voice weighs in the Senate."),
		_num(dignitas)))
	var wealth := int(f["wealth"])
	head.add_child(_bar_row("Wealth", _bar([[0.0, float(wealth) / top_wealth, WEALTH_BAR]], false, 10.0,
		"The family's wealth, and with it how many clients (dependants who vote with it) it can count on."),
		_num(wealth)))
	box.add_child(head)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 3)
	details.visible = open
	_family_details(details, f)
	box.add_child(details)
	_clickable(head, func():
		details.visible = not details.visible
		if details.visible:
			_open["f:" + id] = true
		else:
			_open.erase("f:" + id)
		arrow.kind = "open" if details.visible else "shut"
		arrow.queue_redraw())
	card.add_child(box)
	return card


func _family_details(box: VBoxContainer, f: Dictionary) -> void:
	box.add_child(_t("Clients: %s · Auctoritas: %s" % [_num(int(f.get("clients", 0))), _num(int(f.get("auctoritas_bp", 0)))], 12, DIM, 700))
	box.add_child(_t("Where it stands on the matters of the day", 13, HEADING, 800))
	var stance: Dictionary = f.get("stance", {})
	var influence := int(_rep.get("influence", 0))
	var cost := int(_rep.get("persuade_cost", 0))
	for issue in ISSUE_ORDER:
		if not stance.has(issue):
			continue
		var lean := int(stance[issue])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.tooltip_text = UiStyle.wrap_tip(_issue_help(issue), 48)
		var name := _t(_issue_name(issue), 12, INK, 700)
		name.custom_minimum_size.x = 82
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(name)
		var bar := _lean_bar(lean, 10000.0, 10.0)
		bar.custom_minimum_size.x = 50
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var word := _t(_lean_word(lean), 12, _lean_colour(lean), 700)
		word.custom_minimum_size.x = 72
		word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(word)
		if lean < 10000:
			var action := _persuade_action(str(f["id"]), issue)
			row.add_child(_small_button("Persuade (%d)" % cost if cost > 0 else "Persuade",
				func(): action_requested.emit(action), cost <= influence,
				"Spend %d influence to win the %s over on %s. You have %d." % [cost, str(f["name"]), _issue_name(issue).to_lower(), influence]))
		box.add_child(row)


# --- notable Romans -----------------------------------------------------------------------

func _build_notable() -> void:
	var body := _section("notable", "Notable Romans",
		"The men who matter now: those in office and those with the most glory. A laurel marks a man from the history books.")
	var people: Array = _rep.get("notable", [])
	if people.is_empty():
		body.add_child(_wrap("No one of note.", 14, DIM))
		return
	var top_glory := 1
	for p in people:
		top_glory = maxi(top_glory, int(p["glory"]))
	var holders := {}
	for m in _rep.get("magistrates", []):
		holders[str(m["person"])] = str(m["office_name"])
	for p in people:
		body.add_child(_person_card(p, top_glory, holders))


func _person_card(p: Dictionary, top_glory: int, holders: Dictionary) -> Control:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.add_child(_portrait(str(p["id"]), 52, 64, int(p["age"])))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	var name := _wrap(str(p["name"]), 14, INK, 800)
	head.add_child(name)
	if bool(p.get("historical", false)):
		var laurel := Glyph.new("laurel", 18.0)
		laurel.mouse_filter = Control.MOUSE_FILTER_STOP
		laurel.tooltip_text = "A real Roman, known from the history books."
		laurel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(laurel)
	text.add_child(head)
	var line := "Age %d · %s · %s" % [int(p["age"]), str(p["order"]).capitalize(), str(p.get("gens_name", p.get("gens", "")))]
	if holders.has(str(p["id"])):
		line += " · %s now" % str(holders[str(p["id"])])
	text.add_child(_wrap(line, 12, DIM))
	var held := _offices_held(p.get("offices", []))
	if held != "":
		text.add_child(_wrap(held, 12, INK, 600))
	var traits: Array = p.get("traits", [])
	if not traits.is_empty():
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 4)
		for trait_id in traits:
			var info: Array = TRAITS.get(str(trait_id), [str(trait_id).capitalize(), ""])
			chips.add_child(_chip(str(info[0]), Color(0.45, 0.38, 0.28), str(info[1])))
		text.add_child(chips)
	var glory := int(p["glory"])
	text.add_child(_bar_row("Glory", _bar([[0.0, float(glory) / top_glory, GOLD_BAR]], false, 9.0,
		"Renown won in war and in office. Glorious men win elections and carry the people with them."),
		_num(glory)))
	var back := _back_button(p)
	if back != null:
		text.add_child(back)
	row.add_child(text)
	card.add_child(row)
	return card


## "Consul 305, 294 BC · Censor 258 BC", newest office last.
func _offices_held(offices: Array) -> String:
	var order: Array = []
	var years := {}
	for h in offices:
		var key := str(h["office"])
		if not years.has(key):
			years[key] = []
			order.append(key)
		years[key].append(int(h["year"]))
	var parts := PackedStringArray()
	for key in order:
		var info: Array = OFFICES.get(key, [key.capitalize(), ""])
		var name := str(info[0])
		if key == "consul":
			name = "Consul"
		elif key == "praetor":
			name = "Praetor"
		elif key == "censor":
			name = "Censor"
		elif key.begins_with("aedile"):
			name = "Aedile"
		elif key == "tribune_plebs":
			name = "Tribune"
		elif key == "quaestor":
			name = "Quaestor"
		var yrs: Array = years[key]
		var shown_years := ", ".join(yrs.map(func(y): return str(absi(int(y)))))
		parts.append("%s %s%s" % [name, shown_years, " BC" if int(yrs[0]) < 0 else ""])
	return " · ".join(parts)


## A Back button for the next office up his career (or the offices the view says are open).
func _back_button(p: Dictionary) -> Control:
	var influence := int(_rep.get("influence", 0))
	var cost := int(_rep.get("back_cost", 0))
	var options: Array = p.get("backable", [])
	if options.is_empty():
		var next := _next_office(p)
		if next == "":
			return null
		options = [{"office": next, "label": _office_singular(next)}]
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	for option in options:
		var action := _back_action(str(p["id"]), str(option["office"]))
		var text := "Back for %s" % str(option.get("label", option["office"]))
		if cost > 0:
			text += " (%d)" % cost
		flow.add_child(_small_button(text, func(): action_requested.emit(action), cost <= influence,
			"Spend %d influence to throw your weight behind %s at the next election for this office. You have %d. If he cannot stand, you are told and keep your influence." % [cost, short_name(str(p["name"])), influence]))
	return flow


func _office_singular(office: String) -> String:
	return {"quaestor": "quaestor", "aedile_curule": "aedile", "aedile_plebeian": "aedile", "praetor": "praetor",
		"consul": "consul", "censor": "censor"}.get(office, office)


## The office after the highest he has held, on the usual ladder of a Roman career.
func _next_office(p: Dictionary) -> String:
	var best := -1
	for h in p.get("offices", []):
		var key := str(h["office"])
		if key.begins_with("aedile"):
			key = "aedile"
		var at: int = OFFICE_LADDER.find(key)
		best = maxi(best, at)
	if best >= OFFICE_LADDER.size() - 1:
		return ""
	var next: String = OFFICE_LADDER[best + 1]
	if next == "aedile":
		return "aedile_plebeian" if str(p["order"]) == "plebeian" else "aedile_curule"
	return next


# --- the Fasti ----------------------------------------------------------------------------

func _build_fasti() -> void:
	var turned := bool(_rep.get("history_turned", false))
	var note := "Your Republic's own record of who held the highest offices, newest first."
	var body := _section("fasti", "The Fasti", note)
	if turned:
		body.add_child(_chip("Diverged from history", Color(0.35, 0.30, 0.55),
			"At some point your Rome stopped matching the real Fasti: later years show your Republic's own officeholders."))
	else:
		body.add_child(_wrap("So far these years match the real Fasti.", 12, GOOD))
	var record: Array = _rep.get("fasti", [])
	if record.is_empty():
		body.add_child(_wrap("No years are recorded yet. End a turn and the first will be written here.", 13, DIM))
		return
	var years: Array = []
	var by_year := {}
	for entry in record:
		var y := int(entry["year"])
		if not by_year.has(y):
			by_year[y] = []
			years.append(y)
		by_year[y].append(entry)
	years.sort_custom(func(a, b): return a > b)
	for y in years:
		var entries: Array = by_year[y]
		entries.sort_custom(func(a, b): return _office_rank(str(a["office"])) < _office_rank(str(b["office"])))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var year := _t(_years(int(y)), 13, HEADING, 800)
		year.custom_minimum_size.x = 62
		year.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(year)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		for line in _fasti_lines(entries):
			column.add_child(_wrap(line, 13, INK, 600))
		row.add_child(column)
		body.add_child(row)


## One year's entries as lines: "Consuls: ...", "Censors: ...".
func _fasti_lines(entries: Array) -> PackedStringArray:
	var order: Array = []
	var groups := {}
	for e in entries:
		var key := str(e["office"])
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		var label := short_name(str(e["name"]))
		if bool(e.get("suffect", false)):
			label += " (suffect)"
		groups[key].append(label)
	var lines := PackedStringArray()
	for key in order:
		var info: Array = OFFICES.get(key, [str(key).capitalize(), ""])
		var names: Array = groups[key]
		lines.append("%s: %s" % [str(info[0]), ", ".join(names)])
	return lines
