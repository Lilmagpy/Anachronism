## Behind a triumph card (D-273): slow-turning rays of light in the conqueror's colour, and
## gold and colour flakes falling like thrown petals. Drawn, not stored: it only decorates.
extends Control

var colour := Color(0.95, 0.75, 0.3)
var _turn := 0.0
var _flakes: Array = []   ## [position, velocity, spin, size, colour]
var _age := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		var tint := Color(1.0, 0.82, 0.3) if i % 3 != 0 else colour.lightened(0.2)
		_flakes.append([Vector2(rng.randf(), rng.randf_range(-1.2, -0.05)), rng.randf_range(0.10, 0.22),
			rng.randf_range(-4.0, 4.0), rng.randf_range(5.0, 11.0), tint])


func _process(delta: float) -> void:
	_turn += delta * 0.12
	_age += delta
	for f in _flakes:
		f[0].y += f[1] * delta
		f[0].x += sin(_age * 1.7 + f[2]) * 0.0006
		if f[0].y > 1.1:
			f[0].y = -0.05
	queue_redraw()


func _draw() -> void:
	var centre := size / 2.0
	var reach := size.length()
	var glow := minf(1.0, _age / 0.6)
	for k in 16:
		var a := _turn + k * TAU / 16.0
		var spread := 0.09
		var points := PackedVector2Array([centre,
			centre + Vector2(cos(a - spread), sin(a - spread)) * reach,
			centre + Vector2(cos(a + spread), sin(a + spread)) * reach])
		var tint := Color(1.0, 0.85, 0.45) if k % 2 == 0 else colour.lightened(0.3)
		tint.a = 0.10 * glow
		draw_colored_polygon(points, tint)
	for f in _flakes:
		var at := Vector2(f[0].x * size.x, f[0].y * size.y)
		var spin: float = _age * f[2]
		var s: float = f[3]
		var flutter := absf(cos(spin))   # turning over as it falls
		var c: Color = f[4]
		c.a = 0.9 * glow
		draw_set_transform(at, spin * 0.5, Vector2(1.0, maxf(0.2, flutter)))
		draw_rect(Rect2(-s / 2.0, -s / 4.0, s, s / 2.0), c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
