class_name Capi
extends Node2D
## Капи: кошка-спутник. Сидит рядом с героем, а когда он уходит, бежит следом.
##
## Держится у героя за спиной. Бежит быстрее героя, поэтому не отстаёт, и садится,
## когда догнала. Если герой оказался слишком далеко, Капи сразу появляется рядом.

const FOLLOW_DISTANCE := 90.0
const REST_DISTANCE := 14.0
const START_DISTANCE := 40.0
const SNAP_DISTANCE := 600.0
const RUN_SPEED := 200.0

var _target: Player = null
var _running: bool = false

@onready var _body: CatSprite = $Body


## Назначает героя, за которым идёт Капи, и сажает её у него за спиной.
## [param player] - герой.
func follow(player: Player) -> void:
	_target = player
	global_position = player.global_position - Vector2(FOLLOW_DISTANCE * player.facing, 0.0)
	_sit()


## Сообщает, сидит ли Капи на месте.
## Возвращает true, когда она не бежит.
func is_resting() -> bool:
	return not _running


## Сидя смотрит на героя; когда он отошёл, бежит на место за его спиной.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var goal := _target.global_position.x - FOLLOW_DISTANCE * _target.facing
	var gap := goal - global_position.x
	if absf(gap) > SNAP_DISTANCE:
		global_position.x = goal
		_sit()
	elif _running:
		global_position.x = move_toward(global_position.x, goal, RUN_SPEED * delta)
		_body.face(gap)
		if _body.run(delta):
			Puff.spawn(get_parent(), global_position, Puff.STEP_AMOUNT)
		if absf(goal - global_position.x) <= REST_DISTANCE:
			_sit()
	elif absf(gap) > START_DISTANCE:
		_running = true
	else:
		_body.face(_target.global_position.x - global_position.x)


## Сажает Капи.
func _sit() -> void:
	_running = false
	_body.lift(0.0)
	_body.pose(CatSprite.SIT)
