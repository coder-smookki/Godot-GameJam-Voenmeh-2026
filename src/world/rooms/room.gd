class_name Room
extends Node2D
## Основа комнаты: ставит героя в точку появления, ограничивает камеру, добавляет пыль.
##
## Точки появления лежат в узле Spawns и называются так же, как их указывают двери.
## Сюжетные флаги комната не хранит: всё состояние лежит в мире.

const PLAYER_SCENE: PackedScene = preload("res://src/world/player/player.tscn")
const DUST_SCENE: PackedScene = preload("res://src/world/effects/dust.tscn")
const DUST_SPACING := 24
const HEIGHT := 270

@export var width: int = 480

var player: Player = null

@onready var _spawns: Node2D = $Spawns
@onready var _actors: Node2D = $Actors


## Создаёт героя в точке, которую выбрала игра.
func _ready() -> void:
	var spawn := _spawns.get_node_or_null(NodePath(Game.spawn_id)) as Marker2D
	if spawn == null and _spawns.get_child_count() > 0:
		spawn = _spawns.get_child(0) as Marker2D
	player = PLAYER_SCENE.instantiate()
	_actors.add_child(player)
	if spawn != null:
		player.global_position = spawn.global_position
	player.set_camera_limits(width, HEIGHT)
	_add_dust()


## Пускает по комнате редкие пылинки: их число зависит от ширины комнаты.
func _add_dust() -> void:
	var dust: CPUParticles2D = DUST_SCENE.instantiate()
	dust.position = Vector2(width * 0.5, HEIGHT * 0.45)
	dust.emission_rect_extents = Vector2(width * 0.5, HEIGHT * 0.4)
	dust.amount = maxi(width / DUST_SPACING, 8)
	add_child(dust)
