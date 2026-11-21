## Urbs (D-289): the shared coordinate frame of the city of Rome. Every city script uses
## this and nothing else, so terrain, streets, monuments and cameras all agree.
##
## Local metres, origin at the centre of the Forum Romanum (lat 41.8925, lon 12.4853):
## x grows east, z grows south (so Godot's -z is north), y is height above sea level in
## metres. 1 unit = 1 metre. The ancient Forum floor is at about y = 10 (modern 14-16 m,
## the valley has been filled since: topography.yaml).
class_name UrbsGeo

const ORIGIN_LAT := 41.8925
const ORIGIN_LON := 12.4853
const M_PER_DEG_LAT := 111_132.0
const M_PER_DEG_LON := 82_850.0   # 111,320 * cos(41.89 degrees)

## The city's extent in local metres: the Servian wall and the Campus Martius fit within
## about 2.5 km of the Forum; the Aurelian wall (AD 271) within 4 km.
const RADIUS_M := 4000.0


## Local (x, z) in metres for a WGS84 point.
static func to_local(lat: float, lon: float) -> Vector2:
	return Vector2((lon - ORIGIN_LON) * M_PER_DEG_LON, -(lat - ORIGIN_LAT) * M_PER_DEG_LAT)


## WGS84 (lat, lon) for a local (x, z).
static func to_latlon(p: Vector2) -> Vector2:
	return Vector2(ORIGIN_LAT - p.y / M_PER_DEG_LAT, ORIGIN_LON + p.x / M_PER_DEG_LON)


## A full 3D position: local (x, z) with the given height.
static func at(lat: float, lon: float, height: float) -> Vector3:
	var p := to_local(lat, lon)
	return Vector3(p.x, height, p.y)


## Compass bearing in degrees (0 = north, 90 = east) turned into a Godot yaw (radians,
## rotation about y, where a model's "front" faces +z, i.e. south, at yaw 0).
static func yaw_from_bearing(bearing_deg: float) -> float:
	return deg_to_rad(180.0 - bearing_deg)
