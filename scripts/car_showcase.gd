class_name CarShowcase
extends SubViewportContainer
## Carro 3D girando num pedestal, num mundo à parte (usado na garagem e na tela inicial).

var _viewport: SubViewport
var _pivot: Node3D
var _cam: Camera3D


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(0, 150)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.size = Vector2i(320, 150)  # tamanho inicial pequeno; o container estica
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.75)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	_viewport.add_child(light)
	_pivot = Node3D.new()
	_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # gira no _process
	_viewport.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_viewport.add_child(_cam)


func _process(delta: float) -> void:
	_pivot.rotate_y(delta * 0.5)


func set_car(tier: int, paint: int) -> void:
	for child in _pivot.get_children():
		child.queue_free()
	var t: Dictionary = GameData.TIERS[tier]
	var size: Vector3 = t.size
	var bottom: float = -size.y / 2.0 - CarModel.REST_LENGTH * 0.5 - t.wheel
	_pivot.add_child(CarModel.build_preview(tier, paint))
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = size.z * 0.9
	floor_mesh.bottom_radius = size.z * 0.9
	floor_mesh.height = 0.1
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = bottom - 0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("4a4658")
	floor_node.material_override = mat
	_pivot.add_child(floor_node)
	# enquadra o carro conforme o tamanho do estágio
	var dist := size.z * 1.6 + 2.5
	_cam.transform = Transform3D(Basis(), Vector3(dist * 0.75, dist * 0.5, dist * 0.75)) \
		.looking_at(Vector3(0, bottom * 0.2 + 0.2, 0))
