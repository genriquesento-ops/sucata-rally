extends SceneTree
## Confere as regras da sequência de trechos (WFC 1D) e fotografa um trecho de cada tipo.
##   godot --path . --script res://tests/track_shots.gd -- --out=C:/pasta

const NAMES := ["reta", "lombadas", "salto", "rampa", "pedras", "boost"]

var _out := ""
var _terrain: Terrain
var _cam: Camera3D
var _spots := []  # [índice do trecho, nome]
var _index := -1
var _frames := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_terrain = Terrain.new()
	_terrain.setup(777)
	root.add_child(_terrain)
	_check_rules()

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8fc3ea")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	root.add_child(_cam)

	for kind in [Track.SALTO, Track.RAMPA, Track.PEDRAS, Track.BOOST, Track.LOMBADAS]:
		for i in Track.COUNT:
			if _terrain.track.kind_of(i) == kind and i * Track.SEGMENT < 700.0 * 4.0:
				_spots.append([i, NAMES[kind]])
				break
	_next()


func _check_rules() -> void:
	var counts := {}
	var bad := 0
	for i in Track.COUNT:
		var k := _terrain.track.kind_of(i)
		counts[NAMES[k]] = counts.get(NAMES[k], 0) + 1
		if i + 1 < Track.COUNT and not Track.NEXT[k].has(_terrain.track.kind_of(i + 1)):
			bad += 1
	var first := []
	for i in 25:
		first.append(NAMES[_terrain.track.kind_of(i)])
	print("regras violadas: %d | contagem: %s" % [bad, counts])
	print("primeiros 25 trechos: %s" % ", ".join(first))


func _next() -> void:
	_index += 1
	_frames = 0
	if _index >= _spots.size():
		return
	var sz: float = _spots[_index][0] * Track.SEGMENT
	_terrain.generate_all(Vector3(_terrain.path_x(sz + 20.0), 0, sz + 20.0))
	var eye := Vector3(_terrain.path_x(sz - 4.0) + 6.0, 0, sz - 4.0)
	eye.y = _terrain.height(eye.x, eye.z) + 7.0
	var look := Vector3(_terrain.path_x(sz + 20.0), 0, sz + 20.0)
	look.y = _terrain.height(look.x, look.z)
	_cam.transform = Transform3D(Basis(), eye).looking_at(look)


func _process(_delta: float) -> bool:
	if _index >= _spots.size():
		return true
	_frames += 1
	if _frames < 8:
		return false
	root.get_viewport().get_texture().get_image().save_png(_out.path_join("%d-%s.png" % [_index + 1, _spots[_index][1]]))
	_next()
	return _index >= _spots.size()
