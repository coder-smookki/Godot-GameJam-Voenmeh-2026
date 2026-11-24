class_name CatFollower
extends Node2D
## Кошка-спутник: после кабинета 316 ходит за героем по всем комнатам.
##
## Пока герой идёт, кошка идёт следом в его темпе, чуть позади, и кадры бега сменяются
## медленнее, как шаг. Когда герой остановился, она подходит к нему ещё немного ближе, плавно
## тормозит и садится, глядя на него. Если она сильно отстала, бежит быстрее и поднимает пыль;
## если герой оказался совсем далеко (переход, прыжок через полкомнаты), кошка сразу
## переносится к нему. Бой может посадить
## кошку на своё место ([method stay_at]); тогда она бежит туда и ждёт, глядя на героя.

const FOLLOW_DISTANCE := 45.0
const STOP_DISTANCE := 30.0
const START_DISTANCE := 12.0
const ARRIVE_DISTANCE := 2.0
const WALK_SPEED := 150.0
const CATCH_SPEED := 250.0
const CATCH_FROM := 140.0
const MIN_SPEED := 25.0
const EASE := 6.0
const ACCELERATION := 800.0
const RUN_SPEED := 210.0
const DUST_FROM := 180.0
const HERO_MOVING := 10.0
const SNAP_DISTANCE := 600.0

var _hero: Node2D = null
var _resting: bool = true
var _post: float = 0.0
var _posted: bool = false
var _speed: float = 0.0

@onready var _body: CatSprite = $Body


## Сажает кошку.
func _ready() -> void:
	_body.pose(CatSprite.SIT)


## Назначает героя, за которым ходит кошка, и ставит её за его спиной.
## [param hero] - герой.
func follow(hero: Node2D) -> void:
	_hero = hero
	global_position = Vector2(_goal_x(), hero.global_position.y)


## Отправляет кошку на место и держит её там, пока бой не отпустит.
## [param x] - место на полу.
func stay_at(x: float) -> void:
	_post = x
	_posted = true


## Отпускает кошку: она снова ходит за героем.
func release() -> void:
	_posted = false


## Сообщает, сидит ли кошка.
func is_resting() -> bool:
	return _resting


## Идёт к своему месту рядом с героем: разгоняется до его темпа, у места тормозит и садится.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if not is_instance_valid(_hero):
		return
	var gap := _goal_x() - global_position.x
	if absf(gap) > SNAP_DISTANCE and not _posted:
		global_position.x += gap
		gap = 0.0
		_speed = 0.0
	var wanted := 0.0
	var far := absf(gap) > (START_DISTANCE if _resting else ARRIVE_DISTANCE)
	if far:
		var top := WALK_SPEED if absf(gap) < CATCH_FROM else CATCH_SPEED
		wanted = clampf(absf(gap) * EASE, MIN_SPEED, top)
	_speed = move_toward(_speed, wanted, ACCELERATION * delta)
	if _speed > 1.0 and far:
		_resting = false
		_body.face(gap)
		global_position.x += signf(gap) * minf(_speed * delta, absf(gap))
		if _body.run(delta * clampf(_speed / RUN_SPEED, 0.35, 1.2)) and _speed > DUST_FROM:
			Puff.spawn(get_parent(), global_position, Puff.STEP_AMOUNT)
		return
	_speed = 0.0
	if not _resting:
		_resting = true
		_body.pose(CatSprite.SIT)
	_body.face(_hero.global_position.x - global_position.x)


## Возвращает место кошки: место, куда её посадили, или позади героя по направлению взгляда;
## у идущего героя дальше, у стоящего ближе.
func _goal_x() -> float:
	if _posted:
		return _post
	var facing := 1.0
	var distance := FOLLOW_DISTANCE
	if _hero is Player:
		var player := _hero as Player
		facing = float(player.facing)
		if absf(player.velocity.x) < HERO_MOVING:
			distance = STOP_DISTANCE
	return _hero.global_position.x - distance * facing
