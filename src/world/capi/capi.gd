class_name Capi
extends Node2D
## Капи: спутник, который идёт за героем и держится у него за спиной.

const FOLLOW_DISTANCE := 70.0
const FOLLOW_SPEED := 4.0

var _target: Player = null


## Назначает героя, за которым идёт Капи, и ставит Капи рядом с ним.
## [param player] - герой.
func follow(player: Player) -> void:
	_target = player
	global_position = player.global_position - Vector2(FOLLOW_DISTANCE * player.facing, 0.0)


## Плавно подтягивает Капи к точке за спиной героя.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var goal := _target.global_position.x - FOLLOW_DISTANCE * _target.facing
	global_position.x = lerpf(global_position.x, goal, minf(FOLLOW_SPEED * delta, 1.0))
