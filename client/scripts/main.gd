## Starts the engine, builds the world and runs the game.
##
## Command-line options (after `--`): `--screenshot=PATH` saves a picture and quits,
## `--seed=N` picks the game, `--turns=N` plays N turns (the player does nothing) first,
## `--focus=province_id,distance` points the camera at a province.
extends Node3D

var bridge := EngineBridge.new()
var rig := CameraRig.new()
var world: WorldBuilder
var view: Dictionary = {}
var options := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_setup_environment()
	add_child(rig)
	var repo_root := ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	if not bridge.start(repo_root):
		push_error(bridge.last_error)
		get_tree().quit(1)
		return
	var result: Variant = bridge.request("new_game", {"seed": int(options.get("seed", "1"))})
	if result == null:
		push_error(bridge.last_error)
		get_tree().quit(1)
		return
	view = result
	for i in int(options.get("turns", "0")):
		view = bridge.request("end_turn")
	world = WorldBuilder.new(view)
	var holder := Node3D.new()
	holder.name = "World"
	add_child(holder)
	world.build(holder)
	PropsBuilder.new(world, view).build(holder, view)
	rig.bounds = Rect2(-350, -330, 700, 640)
	if options.has("focus"):
		# --focus=province_id,distance: look at one province (screenshots, tests)
		var f: PackedStringArray = str(options["focus"]).split(",")
		for p in view["provinces"]:
			if p["id"] == f[0]:
				var pos := Vector2(p["position"][0], p["position"][1])
				rig.look_at_point(world.to_world(pos), float(f[1]) if f.size() > 1 else 150.0)
	if options.has("screenshot"):
		_take_screenshot(str(options["screenshot"]))


func _setup_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.40, 0.66)
	sky_material.sky_horizon_color = Color(0.78, 0.74, 0.66)
	sky_material.ground_horizon_color = Color(0.55, 0.52, 0.48)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.9
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.78, 0.76, 0.72)
	environment.fog_density = 0.00025
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.ssao_enabled = true
		environment.glow_enabled = true
		environment.sdfgi_enabled = true
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 55, 0)
	sun.light_color = Color(1.0, 0.92, 0.80)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 1500.0
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.5
	add_child(sun)


func _take_screenshot(path: String) -> void:
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	bridge.stop()
	get_tree().quit()


func _exit_tree() -> void:
	bridge.stop()
