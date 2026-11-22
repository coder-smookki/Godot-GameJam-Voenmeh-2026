class_name Room
extends Node2D
## Основа комнаты: ставит героя в точку появления, ограничивает камеру, добавляет пыль.
## Кошка-спутник появляется рядом с героем, если она уже с ним (отметка cat_joined).
##
## Точки появления лежат в узле Spawns и называются так же, как их указывают двери.
## Сюжетные флаги комната не хранит: всё состояние лежит в мире.

const PLAYER_SCENE: PackedScene = preload("res://src/world/player/player.tscn")
const DUST_SCENE: PackedScene = preload("res://src/world/effects/dust.tscn")
const CAT_SCENE: PackedScene = preload("res://src/world/cat/cat_follower.tscn")
const CAT_MARK := "cat_joined"
const DUST_SPACING := 24
const HEIGHT := 270

@export var width: int = 480

var player: Player = null
var cat: CatFollower = null

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
	World.marked.connect(_on_world_marked)
	_spawn_cat()
	_add_dust()


## Пускает по комнате редкие пылинки: их число зависит от ширины комнаты.
func _add_dust() -> void:
	var dust: CPUParticles2D = DUST_SCENE.instantiate()
	dust.position = Vector2(width * 0.5, HEIGHT * 0.45)
	dust.emission_rect_extents = Vector2(width * 0.5, HEIGHT * 0.4)
	dust.amount = maxi(width / DUST_SPACING, 8)
	add_child(dust)


## Ставит кошку-спутника за спиной героя, если она с ним ходит.
func _spawn_cat() -> void:
	if cat != null or not World.is_marked(CAT_MARK):
		return
	cat = CAT_SCENE.instantiate()
	_actors.add_child(cat)
	cat.follow(player)


## Добавляет кошку в тот момент, когда она присоединяется к герою.
## [param id] - имя новой отметки мира.
func _on_world_marked(id: String) -> void:
	if id == CAT_MARK:
		_spawn_cat()
