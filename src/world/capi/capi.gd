class_name Capi
extends Node2D
## Капи: кошка-спутник. Сидит рядом с героем, а когда он уходит, догоняет его скачками.
##
## Держится у героя за спиной. Скачок тем длиннее, чем дальше ушёл герой, поэтому Капи
## не отстаёт на ходу и не суетится, когда герой стоит.

enum Phase { SIT, LEAP, LAND, GATHER }

const FOLLOW_DISTANCE := 70.0
const REST_DISTANCE := 26.0
const SNAP_DISTANCE := 520.0
const HOP_MAX := 76.0
const HOP_HEIGHT := 16.0
const HOP_SEC := 0.26
const LAND_SEC := 0.06
const GATHER_SEC := 0.04

var _target: Player = null
var _phase: Phase = Phase.SIT
var _clock: float = 0.0
var _from_x: float = 0.0
var _to_x: float = 0.0

@onready var _body: CatSprite = $Body


## Назначает героя, за которым идёт Капи, и сажает её у него за спиной.
## [param player] - герой.
func follow(player: Player) -> void:
	_target = player
	global_position = player.global_position - Vector2(FOLLOW_DISTANCE * player.facing, 0.0)
	_sit()


## Сообщает, сидит ли Капи на месте.
## Возвращает true, когда она не в скачке и не готовится к нему.
func is_resting() -> bool:
	return _phase == Phase.SIT


## Ведёт Капи по кругу «сидит - скачок - приземление - сбор», пока она не догонит героя.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	_clock += delta
	match _phase:
		Phase.SIT:
			_rest()
		Phase.LEAP:
			_fly()
		Phase.LAND:
			if _clock >= LAND_SEC:
				_after_landing()
		Phase.GATHER:
			if _clock >= GATHER_SEC:
				_leap()


## Возвращает точку за спиной героя, где Капи хочет сидеть.
func _goal() -> float:
	return _target.global_position.x - FOLLOW_DISTANCE * _target.facing


## Сидя смотрит на героя; срывается с места, когда он отошёл, и переносится к нему,
## если он оказался слишком далеко.
func _rest() -> void:
	var gap := _goal() - global_position.x
	if absf(gap) > SNAP_DISTANCE:
		global_position.x = _goal()
	elif absf(gap) > REST_DISTANCE:
		_leap()
	else:
		_body.face(_target.global_position.x - global_position.x)


## Начинает скачок к точке за спиной героя; длина скачка ограничена.
func _leap() -> void:
	_from_x = global_position.x
	_to_x = move_toward(_from_x, _goal(), HOP_MAX)
	_body.face(_to_x - _from_x)
	_body.pose(CatSprite.LEAP)
	_enter(Phase.LEAP)


## Двигает Капи по дуге скачка и приземляет её в конце.
func _fly() -> void:
	var progress := minf(_clock / HOP_SEC, 1.0)
	global_position.x = lerpf(_from_x, _to_x, progress)
	_body.lift(HOP_HEIGHT * 4.0 * progress * (1.0 - progress))
	if progress >= 1.0:
		_body.pose(CatSprite.LAND)
		Puff.spawn(get_parent(), global_position, Puff.STEP_AMOUNT)
		_enter(Phase.LAND)


## После приземления решает: сесть рядом с героем или собраться для следующего скачка.
func _after_landing() -> void:
	if absf(_goal() - global_position.x) > REST_DISTANCE:
		_body.pose(CatSprite.CROUCH)
		_enter(Phase.GATHER)
	else:
		_sit()


## Сажает Капи.
func _sit() -> void:
	_body.lift(0.0)
	_body.pose(CatSprite.SIT)
	_enter(Phase.SIT)


## Переходит в новую фазу и обнуляет её таймер.
## [param phase] - новая фаза движения.
func _enter(phase: Phase) -> void:
	_phase = phase
	_clock = 0.0
