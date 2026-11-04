extends SceneTree
## Fotografa cada região do terreno e mede o tempo de geração dos chunks.
##   godot --path . --script res://tests/biome_shots.gd -- --out=C:/pasta

const SPOTS := [[200.0, "1-campo"], [900.0, "2-deserto"], [1600.0, "3-neve"], [2300.0, "4-vulcao"], [3000.0, "5-lua"], [690.0, "6-transicao"]]

var _out := ""
var _terrain: Terrain
var _cam: Camera3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _index := -1
var _frames := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_terrain = Terrain.new()
	_terrain.setup(4242)
	root.add_child(_terrain)
	_sky = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_energy = 0.6
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.fog_enabled = true
	_env.fog_density = 0.002
	_env.fog_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = _env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	root.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 300.0
	root.add_child(_cam)
	_next()


func _next() -> void:
	_index += 1
	_frames = 0
	if _index >= SPOTS.size():
		return
	var z: float = SPOTS[_index][0]
	var b: Dictionary = GameData.BIOMES[GameData.biome_index(z)]
	_sky.sky_top_color = b.sky
	_sky.sky_horizon_color = b.horizon
	_sky.ground_horizon_color = b.horizon
	_sky.ground_bottom_color = b.ground
	_env.fog_light_color = b.horizon
	_env.ambient_light_color = b.horizon.lerp(Color(0.55, 0.55, 0.55), 0.6)

	var pos := Vector3(_terrain.path_x(z), 0, z)
	var t0 := Time.get_ticks_usec()
	var before := _terrain.get_child_count()
	_terrain.generate_all(pos)
	var built := _terrain.get_child_count() - before
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("%s: %d chunks novos em %.0f ms (%.1f ms/chunk)" % [SPOTS[_index][1], built, ms, ms / maxf(built, 1)])

	var ahead := Vector3(_terrain.path_x(z + 20.0), 0, z + 20.0)
	ahead.y = _terrain.height(ahead.x, ahead.z)
	var eye := Vector3(_terrain.path_x(z - 11.0), 0, z - 11.0)
	eye.y = _terrain.height(eye.x, eye.z) + 6.5
	_cam.transform = Transform3D(Basis(), eye).looking_at(ahead)


func _process(_delta: float) -> bool:
	if _index >= SPOTS.size():
		return true
	_frames += 1
	if _frames < 8:
		return false
	root.get_viewport().get_texture().get_image().save_png(_out.path_join(SPOTS[_index][1] + ".png"))
	_next()
	return _index >= SPOTS.size()
