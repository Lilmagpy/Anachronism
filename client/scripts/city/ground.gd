## The ground of the settlements (D-281): trodden earth round the houses, lanes and streets,
## paved squares, gardens and yards, and footings where a building meets sloping ground, so
## the buildings grow out of the land instead of standing on it.
##
## The planners (plan_city.gd, plan_rural.gd) describe the ground as they lay a place out;
## `build` makes it at the end. Positions are map pixels (as for Settlements._add).
## Kinds of surface: "earth" (trodden earth, a yard), "dirt" (an earth lane), "cobble",
## "flag" (flagstones), "sand", "garden" (dug beds), "grass" (lusher, darker grass).
##
## THIS IS A STUB (lead, D-281): it draws everything as flat paving tiles. The ground agent
## replaces it, keeping these function signatures.
extends RefCounted

const KIND_COLOUR := {"earth": Color(0.66, 0.56, 0.40, 0.33), "dirt": Color(0.70, 0.60, 0.44, 0.33),
	"cobble": Color(0.72, 0.68, 0.60, 0.66), "flag": Color(0.82, 0.78, 0.68, 1.0),
	"sand": Color(0.86, 0.76, 0.56, 0.33), "garden": Color(0.42, 0.34, 0.22, 0.33),
	"grass": Color(0.36, 0.52, 0.22, 0.33)}

var s: Settlements   ## the Settlements being built
## Everything described, for others to read (the dressing keeps props off the streets):
var roads: Array = []     ## [points: PackedVector2Array, width: float, kind: String]
var areas: Array = []     ## [points: PackedVector2Array, kind: String]
var patches: Array = []   ## [centre: Vector2, radius: float, kind: String]


func _init(settlements: Settlements) -> void:
	s = settlements


## A soft, irregular patch of surface `kind` round `centre`, `radius` map units across;
## `strength` (0..1) how worn or complete it is (fades out at its edge).
func patch(centre: Vector2, radius: float, kind: String, strength := 1.0) -> void:
	patches.append([centre, radius, kind])
	var colour: Color = KIND_COLOUR.get(kind, KIND_COLOUR["earth"])
	s._add("paving", centre, -0.55, 0.0, Vector3(radius * 1.6, 90.0, radius * 1.6), colour)


## A lane, street or road along `points`, `width` map units wide, of surface `kind`.
func road(points: PackedVector2Array, width: float, kind: String) -> void:
	roads.append([points, width, kind])
	var colour: Color = KIND_COLOUR.get(kind, KIND_COLOUR["dirt"])
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var steps := maxi(1, int(ceil(a.distance_to(b) / width)))
		for k in steps:
			var p := a.lerp(b, (k + 0.5) / steps)
			s._add("paving", p, -0.55, -(b - a).angle(), Vector3(a.distance_to(b) / steps * 1.05, 90.0, width), colour)


## A whole area (a square, a court, a yard) inside the polygon `points`, of surface `kind`.
func area(points: PackedVector2Array, kind: String) -> void:
	areas.append([points, kind])
	var colour: Color = KIND_COLOUR.get(kind, KIND_COLOUR["flag"])
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	s._add("paving", (lo + hi) / 2.0, -0.55, 0.0, Vector3(hi.x - lo.x, 90.0, hi.y - lo.y), colour)


## True when `p` lies on a road or square (within `margin` of its edge).
func on_street(p: Vector2, margin := 0.0) -> bool:
	for r in roads:
		var pts: PackedVector2Array = r[0]
		var half: float = float(r[1]) / 2.0 + margin
		for i in pts.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])) < half:
				return true
	for a in areas:
		if Geometry2D.is_point_in_polygon(p, a[0]):
			return true
	return false


## Where a building stands: `size` (map units, x across its front, y deep) turned by `yaw`
## (as in Settlements._add). Lays its footing into the slope and the worn ground round it.
func footing(centre: Vector2, yaw: float, size: Vector2, kind := "earth") -> void:
	pass


## Make everything described so far, under `parent`. Called once, after every settlement.
func build(parent: Node3D) -> void:
	pass
