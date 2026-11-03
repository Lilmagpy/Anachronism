## Urbs (U8 render): the light of Rome. Owns the sky, the sun and the environment of the
## city scene; urbs.gd calls `setup` once, `set_hour` when the time changes and `update` every
## frame with the camera mode.
##
## - Sun: the real sun over Rome (latitude 41.9 N) at local solar time `hour` on `day` of the
##   year (default 120, the end of April: noon 63 degrees high, sunrise about 5:20, sunset
##   about 18:40). Its colour comes from the air mass it shines through (Kasten and Young's
##   formula with a little Rayleigh and haze), so it is white at noon, gold at 9 and 17,
##   orange-red as it sets.
## - Sky: shaders/urbs/sky.gdshader, deep blue above, hazy at the horizon, a halo round the
##   sun, a warm band on its side when it is low; it also lights the scene (ambient and
##   reflections come from it).
## - Shadows: hard sun (no penumbra blur), four cascades fitted per camera mode: in the street
##   the first ends 10 m away (crisp at your feet), from the air they spread over the city.
## - Aerial perspective: depth fog that begins well away from the camera and only takes the
##   far hills, tinted like the horizon of the sky (not soup).
## - Post: AgX tone mapping (keeps saturated reds from turning neon), SSAO (contact shadows), SSIL in the street and inside (the light
##   bounced off sunny walls), a little glow on the brightest highlights (gilt, the sun).
##   SSAO and SSIL exist only in the Forward+ renderer; on the Compatibility renderer (a
##   software GPU) the scene stands without them.
## - `--fx=nossao,nossil,noglow,nofog` turns effects off for testing (`set_fx`).
class_name UrbsAtmosphere
extends RefCounted

const LATITUDE := 41.9          ## Rome, degrees north
const NOON_ENERGY := 1.75        ## the sun's light energy at full height
const SKY_SHADER := "res://shaders/urbs/sky.gdshader"

var environment: Environment
var sun: DirectionalLight3D
var sky := Sky.new()
var sky_material := ShaderMaterial.new()
var day := 120                   ## day of the year (1 = 1 January)
var hour := 10.0
var elevation := 45.0            ## the sun's height above the horizon, degrees
var direction := Vector3.UP      ## towards the sun (x east, y up, z south)
var fx := {"ssao": true, "ssil": true, "glow": true, "fog": true}
var tonemap := Environment.TONE_MAPPER_AGX   ## (tuning) the tone mapper
var exposure := 1.35                         ## (tuning) tone-mapping exposure
var ambient := 1.3                           ## (tuning) scales the ambient light
var bounce := 0.6                            ## (tuning) share of the ambient that is warm bounce
var _mode := ""
var _forward_plus := true


## Build the sky and set up the environment and the sun (once).
func setup(env: Environment, sun_light: DirectionalLight3D) -> void:
	environment = env
	sun = sun_light
	var shader := load(SKY_SHADER) as Shader
	if shader != null:
		sky_material.shader = shader
		sky.sky_material = sky_material
	else:
		sky.sky_material = ProceduralSkyMaterial.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# shade is lit by the blue sky AND by sunlight bounced off the ground and the walls (warm);
	# without bounce (no GI here) shadowed walls go blue-black
	env.ambient_light_sky_contribution = 1.0 - bounce
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_forward_plus = RenderingServer.get_current_rendering_method() == "forward_plus"
	apply_tonemap()
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12   # AgX desaturates; give the terracotta back
	# aerial perspective: depth fog from far away, tinted by the sky
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_curve = 1.3
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.6
	env.fog_sun_scatter = 0.12
	env.fog_light_energy = 1.0
	# contact shadows and bounce (Forward+ only)
	env.ssao_enabled = _forward_plus
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssao_horizon = 0.06
	env.ssao_sharpness = 0.98
	env.ssao_light_affect = 0.05
	env.ssao_ao_channel_affect = 0.3
	env.ssil_enabled = false
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.7
	env.ssil_sharpness = 0.98
	env.ssil_normal_rejection = 1.0
	# glow on the brightest highlights only
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.3
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.05
	env.glow_hdr_scale = 2.0
	# the sun: hard and crisp, four cascades
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.light_angular_distance = 0.0
	sun.shadow_blur = 0.6
	_apply_fx()
	set_hour(hour)
	update(true, 1500.0, false)


## Apply `tonemap` and `exposure` (after changing them).
func apply_tonemap() -> void:
	environment.tonemap_mode = tonemap
	environment.tonemap_exposure = exposure
	environment.tonemap_white = 6.0


## Effects off for testing: a comma list of nossao, nossil, noglow, nofog.
func set_fx(spec: String) -> void:
	for word in spec.split(",", false):
		var w := word.strip_edges().to_lower()
		if w.begins_with("no") and fx.has(w.substr(2)):
			fx[w.substr(2)] = false
	_apply_fx()
	_mode = ""


func _apply_fx() -> void:
	if environment == null:
		return
	environment.glow_enabled = fx["glow"]
	if not fx["ssao"] or not _forward_plus:
		environment.ssao_enabled = false
	if not fx["ssil"] or not _forward_plus:
		environment.ssil_enabled = false
	if not fx["fog"]:
		environment.fog_enabled = false


## Whether the sun is above the horizon (its light is on).
func sun_up() -> bool:
	return elevation > -2.0


## Move the sun to `new_hour` (local solar time, 0-24) and re-tint sky, light and haze.
func set_hour(new_hour: float) -> void:
	hour = fposmod(new_hour, 24.0)
	direction = sun_direction(hour, day, LATITUDE)
	elevation = rad_to_deg(asin(clampf(direction.y, -1.0, 1.0)))
	# the light travels opposite to `direction`; keep a sliver above the horizon so a setting
	# sun still rakes the city instead of shining up from below
	var lit := direction
	if lit.y < 0.035:
		lit = Vector3(lit.x, 0.0, lit.z).normalized() * 0.9994 + Vector3(0, 0.035, 0)
	sun.basis = Basis.looking_at(-lit, Vector3.UP if absf(lit.y) < 0.99 else Vector3.FORWARD)
	var colour := sun_colour(elevation)
	sun.light_color = colour
	sun.light_energy = NOON_ENERGY * _transmittance(elevation).length() / _transmittance(90.0).length() * smoothstep(-1.5, 4.0, elevation)
	sun.visible = sun_up()
	_tint_sky(colour)


## The colours of the sky, the haze and the ambient for the sun's elevation.
func _tint_sky(sun_c: Color) -> void:
	var e := elevation
	var day_w := smoothstep(4.0, 25.0, e)          # full day
	var low := 1.0 - smoothstep(0.0, 14.0, e)       # golden hour .. sunset
	var night := 1.0 - smoothstep(-9.0, 1.0, e)
	var zenith := Color(0.13, 0.33, 0.70).lerp(Color(0.16, 0.30, 0.56), low * 0.7)
	var horizon := Color(0.66, 0.78, 0.90).lerp(Color(0.92, 0.76, 0.58), low * 0.85)
	zenith = zenith.lerp(Color(0.012, 0.018, 0.045), night)
	horizon = horizon.lerp(Color(0.05, 0.06, 0.10), night)
	var ground := Color(0.40, 0.38, 0.33).lerp(Color(0.02, 0.02, 0.03), night)
	sky_material.set_shader_parameter("zenith", zenith)
	sky_material.set_shader_parameter("horizon", horizon)
	sky_material.set_shader_parameter("ground", ground)
	sky_material.set_shader_parameter("glow", sun_c.lerp(Color(1.0, 0.55, 0.30), low * 0.5))
	sky_material.set_shader_parameter("sunset", low * (1.0 - night))
	sky_material.set_shader_parameter("haze", lerpf(0.35, 0.6, day_w))
	sky_material.set_shader_parameter("energy", lerpf(1.0, 0.85, low) * lerpf(1.0, 0.15, night))
	# bounce fades gently with the sun: the sunlit ground and walls still glow at sunset
	var sun_share := sqrt(clampf(sun.light_energy / NOON_ENERGY, 0.0, 1.0))
	var ground_lit := Color(0.78, 0.72, 0.62) * sun_c.lerp(Color.WHITE, 0.4) * lerpf(0.45, 1.0, sun_share)
	# a low sun leaves more of the scene in shade, lit by the whole bright sky: more ambient
	environment.ambient_light_energy = ambient * 0.87 * lerpf(2.0, 1.0, sun_share) * lerpf(1.0, 0.35, night)
	# as the sun sinks, shade is lit more by the sky (blue shade under golden light)
	environment.ambient_light_sky_contribution = 1.0 - bounce * lerpf(0.35, 1.0, sun_share)
	environment.ambient_light_color = ground_lit.lerp(Color(0.05, 0.06, 0.09), night)
	environment.fog_light_color = horizon.lerp(Color(0.80, 0.84, 0.90), 0.2 * day_w)
	environment.fog_light_energy = lerpf(1.0, 0.25, night)


## Camera-dependent settings, every frame: the shadow cascades, where the haze begins, how wide
## the contact shadows reach, SSIL in the street only. `dist` is the orbit distance (city).
func update(orbit: bool, dist: float, inside: bool) -> void:
	var mode := "inside" if inside else ("city" if orbit else "street")
	if orbit:
		var reach := clampf(dist * 1.8, 400.0, 3500.0)
		sun.directional_shadow_max_distance = reach
		environment.fog_depth_begin = maxf(dist * 0.8, 600.0)
		environment.fog_depth_end = maxf(dist * 3.5, 5000.0)
		environment.fog_density = 0.55
	if mode == _mode:
		return
	_mode = mode
	match mode:
		"city":
			sun.directional_shadow_split_1 = 0.08
			sun.directional_shadow_split_2 = 0.22
			sun.directional_shadow_split_3 = 0.5
			sun.shadow_bias = 0.05
			sun.shadow_normal_bias = 1.6
			environment.ssao_radius = 5.0
			environment.ssao_intensity = 1.6
			environment.ssil_enabled = false
		"street":
			sun.directional_shadow_max_distance = 300.0
			sun.directional_shadow_split_1 = 0.035
			sun.directional_shadow_split_2 = 0.11
			sun.directional_shadow_split_3 = 0.34
			sun.shadow_bias = 0.03
			sun.shadow_normal_bias = 1.2
			environment.fog_depth_begin = 220.0
			environment.fog_depth_end = 4500.0
			environment.fog_density = 0.62
			environment.ssao_radius = 1.2
			environment.ssao_intensity = 2.0
			environment.ssil_enabled = fx["ssil"] and _forward_plus
		"inside":
			sun.directional_shadow_max_distance = 160.0
			sun.directional_shadow_split_1 = 0.05
			sun.directional_shadow_split_2 = 0.15
			sun.directional_shadow_split_3 = 0.4
			sun.shadow_bias = 0.03
			sun.shadow_normal_bias = 1.2
			environment.ssao_radius = 0.8
			environment.ssao_intensity = 2.4
			environment.ssil_enabled = fx["ssil"] and _forward_plus
	environment.ssao_enabled = fx["ssao"] and _forward_plus
	environment.fog_enabled = fx["fog"] and not inside


## The direction towards the sun (x east, y up, z south) at local solar time `h` on day `d` of
## the year at latitude `lat` degrees: the usual equatorial-to-horizontal conversion with
## Cooper's formula for the declination.
static func sun_direction(h: float, d: int, lat: float) -> Vector3:
	var decl := deg_to_rad(23.44) * sin(TAU * (284.0 + d) / 365.0)
	var ha := deg_to_rad(15.0 * (h - 12.0))
	var phi := deg_to_rad(lat)
	var up := sin(phi) * sin(decl) + cos(phi) * cos(decl) * cos(ha)
	var east := -cos(decl) * sin(ha)
	var north := cos(phi) * sin(decl) - sin(phi) * cos(decl) * cos(ha)
	return Vector3(east, up, -north).normalized()


## The sun's colour at `elevation` degrees, white at noon (a touch warm) to red at the horizon.
static func sun_colour(elev: float) -> Color:
	var t := _transmittance(elev)
	var z := _transmittance(90.0)
	var c := Vector3(t.x / z.x, t.y / z.y, t.z / z.z)
	c /= maxf(c.x, maxf(c.y, c.z))
	return Color(c.x, c.y * 0.98, c.z * 0.93)


## Light left after the air: Kasten-Young air mass, optical depths for red, green and blue.
static func _transmittance(elev: float) -> Vector3:
	var e := maxf(elev, -0.5)
	var mass := 1.0 / (sin(deg_to_rad(maxf(e, 0.0))) + 0.50572 * pow(e + 6.07995, -1.6364))
	var tau := Vector3(0.12, 0.2, 0.36)
	return Vector3(exp(-tau.x * mass), exp(-tau.y * mass), exp(-tau.z * mass))
