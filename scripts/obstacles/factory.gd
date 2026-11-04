class_name ObstacleFactory
extends RefCounted
## Fábrica dos elementos da trilha (padrão Factory): recebe o "tipo" escrito em
## data/trechos.json e devolve o nó pronto, sem o resto do jogo precisar conhecer cada classe.
##
## Para criar um obstáculo novo: um script nesta pasta que estende Obstacle, uma linha em
## TYPES e um trecho em data/trechos.json que use o tipo.
## "evitar": o piloto automático desvia (pedras, óleo); os outros ele atravessa.

const TYPES := {
	"rampa": {"script": preload("res://scripts/obstacles/ramp.gd"), "evitar": false},
	"pedregulho": {"script": preload("res://scripts/obstacles/boulder.gd"), "evitar": true},
	"boost": {"script": preload("res://scripts/obstacles/boost_pad.gd"), "evitar": false},
	"oleo": {"script": preload("res://scripts/obstacles/oil_slick.gd"), "evitar": true},
	"serra": {"script": preload("res://scripts/obstacles/saw.gd"), "evitar": false},
	"martelo": {"script": preload("res://scripts/obstacles/hammer.gd"), "evitar": false},
}


static func create(tipo: String, xf: Transform3D, params: Dictionary) -> Obstacle:
	if not TYPES.has(tipo):
		push_warning("tipo de obstáculo desconhecido: " + tipo)
		return null
	var node: Obstacle = TYPES[tipo].script.new()
	node.setup(xf, params)
	return node


static func exists(tipo: String) -> bool:
	return TYPES.has(tipo)


static func avoid(tipo: String) -> bool:
	return TYPES.has(tipo) and TYPES[tipo].evitar
