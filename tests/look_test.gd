extends SceneTree
## Compara configurações de luz/cor do terreno, salvando uma imagem por configuração.
##   godot --path . --script res://tests/look_test.gd -- --out=C:/pasta

var _out := ""
var _env: Environment
var _sun: DirectionalLight3D
var _terrain: Terrain
var _frames := 0
var _index := 0

var _configs := [
	{"name": "a-atual", "ambient": Environment.AMBIENT_SOURCE_SKY, "tonemap": Environment.TONE_MAPPER_FILMIC, "fog": true, "srgb": true},
	{"name": "b-sem-srgb", "ambient": Environment.AMBIENT_SOURCE_SKY, "tonemap": Environment.TONE_MAPPER_FILMIC, "fog": true, "srgb": false},
	{"name": "c-linear", "ambient": Environment.AMBIENT_SOURCE_SKY, "tonemap": Environment.TONE_MAPPER_LINEAR, "fog": true, "srgb": true},
	{"name": "d-ambiente-cor", "ambient": Environment.AMBIENT_SOURCE_COLOR, "tonemap": Environment.TONE_MAPPER_LINEAR, "fog": false, "srgb": true},
]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_terrain = Terrain.new()
	_terrain.setup(1234)
	root.add_child(_terrain)
	_terrain.generate_all(Vector3(0, 0, 60))
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_energy = 0.45
	_env.ambient_light_color = Color(0.6, 0.65, 0.75)
	_env.fog_density = 0.003
	_env.fog_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = _env
	root.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55, -30, 0)
	_sun.light_energy = 0.75
	_sun.shadow_enabled = true
	root.add_child(_sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.transform = Transform3D(Basis(), Vector3(0, _terrain.height(0, 50) + 5, 50)) \
		.looking_at(Vector3(_terrain.path_x(80), _terrain.height(0, 80), 80))
	_apply(_configs[0])


func _apply(c: Dictionary) -> void:
	_env.ambient_light_source = c.ambient
	_env.tonemap_mode = c.tonemap
	_env.fog_enabled = c.fog
	_terrain._material.vertex_color_is_srgb = c.srgb


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	root.get_viewport().get_texture().get_image().save_png(_out.path_join(_configs[_index].name + ".png"))
	_index += 1
	if _index >= _configs.size():
		return true
	_apply(_configs[_index])
	_frames = 0
	return false
