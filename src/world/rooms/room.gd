class_name Room
extends Node2D
## Основа комнаты: ставит героя и Капи в точку появления и ограничивает камеру.
##
## Точки появления лежат в узле Spawns и называются так же, как их указывают двери.
## Сюжетные флаги комната не хранит: всё состояние лежит в мире.

const PLAYER_SCENE: PackedScene = preload("res://src/world/player/player.tscn")
const CAPI_SCENE: PackedScene = preload("res://src/world/capi/capi.tscn")
const HEIGHT := 270
const CAPI_MARK := "capi_joined"
const CAPI_STAYS := "capy"

@export var width: int = 480

var player: Player = null

var _capi: Capi = null

@onready var _spawns: Node2D = $Spawns
@onready var _actors: Node2D = $Actors


## Создаёт героя в точке, которую выбрала игра, и Капи, если она уже идёт с героем.
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
	_spawn_capi()


## Ставит Капи рядом с героем, если она уже присоединилась и не осталась у рубильника.
func _spawn_capi() -> void:
	if _capi != null or not World.is_marked(CAPI_MARK) or World.f["mozh"] == CAPI_STAYS:
		return
	_capi = CAPI_SCENE.instantiate()
	_actors.add_child(_capi)
	_capi.follow(player)


## Добавляет Капи в комнату в тот момент, когда она присоединяется к герою.
## [param id] - имя новой отметки мира.
func _on_world_marked(id: String) -> void:
	if id == CAPI_MARK:
		_spawn_capi()
