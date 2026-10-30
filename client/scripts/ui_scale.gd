## How large the interface is drawn (D-276). The layout is designed for 1600 x 900 and
## stretches to any window; on a small window everything shrinks with it, so "Auto" keeps the
## interface at least 90% of its designed size (text stays readable), and "Larger" and
## "Largest" enlarge it further - never so far that the screen holds less than 1280 x 720 of
## layout, below which panels would collide.
extends RefCounted

const SETTINGS := "user://settings.cfg"
const CHOICES := {"auto": 1.0, "larger": 1.15, "largest": 1.3}
const NAMES := {"auto": "Auto", "larger": "Larger", "largest": "Largest"}


static func choice() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS) != OK:
		return "auto"
	var picked := str(config.get_value("display", "interface", "auto"))
	return picked if CHOICES.has(picked) else "auto"


static func set_choice(picked: String, window: Window) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("display", "interface", picked)
	config.save(SETTINGS)
	apply(window)


## Set the window's content scale for its present size and the player's choice.
static func apply(window: Window) -> void:
	var size := Vector2(window.size)
	if size.x < 1.0 or size.y < 1.0:
		return
	var stretch := minf(size.x / 1600.0, size.y / 900.0)   # what the stretch alone gives
	var want := maxf(stretch, 0.9) * float(CHOICES[choice()])
	var most := minf(size.x / 1280.0, size.y / 720.0)       # keep 1280 x 720 of layout at least
	window.content_scale_factor = clampf(minf(want, most) / stretch, 1.0, 3.0)
