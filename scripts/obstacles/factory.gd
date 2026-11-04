class_name ObstacleFactory
extends RefCounted
## Fábrica dos elementos da trilha (padrão Factory): recebe o "tipo" escrito em
## data/trechos.json e devolve o nó pronto, sem o resto do jogo precisar conhecer cada classe.
##
## Para criar um obstáculo novo: um script nesta pasta que estende Obstacle, uma linha em
## TYPES e um trecho em data/trechos.json que use o tipo.
## "evitar": o piloto automático desvia (pedras, óleo); os outros ele atravessa.
## "params": valores padrão (o trecho pode trocar). Assim um mesmo script serve a vários
## tipos: óleo e gelo são a mesma "mancha escorregadia" com malha e força diferentes.

const TYPES := {
	"rampa": {"script": preload("res://scripts/obstacles/ramp.gd"), "evitar": false},
	"pedregulho": {"script": preload("res://scripts/obstacles/boulder.gd"), "evitar": true},
	"boost": {"script": preload("res://scripts/obstacles/boost_pad.gd"), "evitar": false},
	"oleo": {"script": preload("res://scripts/obstacles/oil_slick.gd"), "evitar": true},
	"gelo": {"script": preload("res://scripts/obstacles/oil_slick.gd"), "evitar": true,
		"params": {"malha": "ice_patch", "aderencia": 0.45, "segundos": 1.0, "giro": 0.5, "evento": "ice"}},
	"lava": {"script": preload("res://scripts/obstacles/lava_pool.gd"), "evitar": true},
	"serra": {"script": preload("res://scripts/obstacles/saw.gd"), "evitar": false},
	"martelo": {"script": preload("res://scripts/obstacles/hammer.gd"), "evitar": false},
	"barril": {"script": preload("res://scripts/obstacles/barrel.gd"), "evitar": true},
	"vento": {"script": preload("res://scripts/obstacles/fan.gd"), "evitar": false},
}


static func create(tipo: String, xf: Transform3D, params: Dictionary) -> Obstacle:
	if not TYPES.has(tipo):
		push_warning("tipo de obstáculo desconhecido: " + tipo)
		return null
	var info: Dictionary = TYPES[tipo]
	var merged: Dictionary = info.get("params", {}).duplicate()
	merged.merge(params, true)
	var node: Obstacle = info.script.new()
	node.setup(xf, merged)
	return node


static func exists(tipo: String) -> bool:
	return TYPES.has(tipo)


static func avoid(tipo: String) -> bool:
	return TYPES.has(tipo) and TYPES[tipo].evitar
