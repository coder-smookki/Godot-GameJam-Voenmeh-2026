class_name CatFollower
extends Node2D
## Кошка-спутник: после кабинета 316 ходит за героем по всем комнатам.
##
## Её место - чуть позади героя. Рядом с местом она сидит и смотрит на героя; если герой ушёл
## дальше, бежит следом по кругу кадров бега, поднимая пыль. Если герой оказался совсем далеко
## (переход, прыжок через полкомнаты), кошка сразу переносится к нему.

const FOLLOW_DISTANCE := 80.0
const REST_DISTANCE := 14.0
const START_DISTANCE := 40.0
const RUN_SPEED := 210.0
const SNAP_DISTANCE := 600.0

var _hero: Node2D = null
var _resting: bool = true

@onready var _body: CatSprite = $Body


## Сажает кошку.
func _ready() -> void:
	_body.pose(CatSprite.SIT)


## Назначает героя, за которым ходит кошка, и ставит её за его спиной.
## [param hero] - герой.
func follow(hero: Node2D) -> void:
	_hero = hero
	global_position = Vector2(_goal_x(), hero.global_position.y)


## Сообщает, сидит ли кошка.
func is_resting() -> bool:
	return _resting


## Бежит к месту за спиной героя или сидит рядом с ним.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if not is_instance_valid(_hero):
		return
	var goal := _goal_x()
	var gap := goal - global_position.x
	if absf(gap) > SNAP_DISTANCE:
		global_position.x = goal
		gap = 0.0
	if _resting and absf(gap) > START_DISTANCE or not _resting and absf(gap) > REST_DISTANCE:
		_resting = false
		_body.face(gap)
		global_position.x = move_toward(global_position.x, goal, RUN_SPEED * delta)
		if _body.run(delta):
			Puff.spawn(get_parent(), global_position, Puff.STEP_AMOUNT)
		return
	if not _resting:
		_resting = true
		_body.pose(CatSprite.SIT)
	_body.face(_hero.global_position.x - global_position.x)


## Возвращает место кошки: позади героя по направлению его взгляда.
func _goal_x() -> float:
	var facing := 1.0
	if _hero is Player:
		facing = float((_hero as Player).facing)
	return _hero.global_position.x - FOLLOW_DISTANCE * facing
