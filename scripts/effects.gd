class_name Effects
extends RefCounted
## Efeitos de partículas (CPUParticles3D, que funcionam bem no renderizador Compatibility e
## no celular): poeira das rodas, fogo do Foguete, chama do boost, brilho das moedas,
## neve e cinzas.

static var _dot: GradientTexture2D


## Poeira saindo de trás do carro. Ligue/desligue com `emitting`; a cor muda por região.
static func dust() -> CPUParticles3D:
	var p := _base(28, 0.9, 0.35)
	p.direction = Vector3(0, 0.6, -1)
	p.spread = 35.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _grow_curve()
	p.color_ramp = _fade(Color(1, 1, 1, 0.55))
	p.emitting = false
	return p


## Jato de fogo (Foguete) ou chama azul do boost, apontado para trás (-Z).
static func flame(color: Color) -> CPUParticles3D:
	var p := _base(32, 0.35, 0.3)
	p.direction = Vector3(0, 0, -1)
	p.spread = 12.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 0.8, 1))
	g.set_color(1, Color(color, 0))
	g.add_point(0.35, color)
	p.color_ramp = g
	p.emitting = false
	return p


## Brilho rápido ao pegar uma moeda; se apaga sozinho.
static func sparkle(parent: Node3D, pos: Vector3, color: Color) -> void:
	var p := _base(14, 0.5, 0.25)
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -5, 0)
	p.color_ramp = _fade(color)
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Faíscas de metal numa batida (serra, martelo): rápidas, quentes e caindo.
static func sparks(parent: Node3D, pos: Vector3) -> void:
	var p := _base(48, 0.7, 0.22)
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3(0, -18, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 0.75, 1))
	g.set_color(1, Color(1, 0.3, 0.05, 0))
	g.add_point(0.4, Color("ffb030"))
	p.color_ramp = g
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Nuvem de poeira no pouso de um salto; se apaga sozinha.
static func landing_dust(parent: Node3D, pos: Vector3, color: Color) -> void:
	var p := _base(24, 0.9, 0.5)
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -1, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_curve = _grow_curve()
	p.color_ramp = _fade(Color(color.lightened(0.5), 0.7))
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Neve ou cinzas caindo numa caixa à frente da câmera (filho da câmera).
static func weather() -> CPUParticles3D:
	var p := _base(220, 5.0, 0.18)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(28, 1, 28)
	p.position = Vector3(0, 9, -14)
	p.direction = Vector3(0.2, -1, 0)
	p.spread = 15.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.emitting = false
	return p


## Ajusta o clima conforme a região: neve na Neve, cinzas no Vulcão, nada nas outras.
static func set_weather(p: CPUParticles3D, biome_title: String) -> void:
	match biome_title:
		"Neve":
			p.color_ramp = _fade(Color(1, 1, 1, 0.9))
			p.gravity = Vector3(0, -2.5, 0)
			p.emitting = true
		"Vulcão":
			p.color_ramp = _fade(Color(0.55, 0.45, 0.42, 0.85))
			p.gravity = Vector3(0, -1.2, 0)
			p.emitting = true
		_:
			p.emitting = false


static func _base(amount: int, lifetime: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size) * 2.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _soft_dot()
	quad.material = m
	p.mesh = quad
	return p


## Bolinha branca de borda suave (gerada em código, sem imagem).
static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(0.5, 0.0)
		_dot.width = 32
		_dot.height = 32
	return _dot


static func _fade(color: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0))
	return g


static func _grow_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.0))
	return c
