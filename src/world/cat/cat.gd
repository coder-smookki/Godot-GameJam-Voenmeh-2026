class_name Cat
extends Node2D
## Кот на окне третьего этажа: замечает героя, спрыгивает и ведёт его к кабинету 316.
##
## Порядок кадров показала художница: сидит на окне, готовится, прыгает, садится на пол,
## дальше бежит по кругу кадров. Если герой отстал, кот садится и ждёт, пока тот подойдёт.
## У двери кот садится, ставит отметку arrive_mark и ждёт героя, глядя на него. Когда герой
## заходит в 316, кот становится его спутником ([CatFollower]), а этот кот больше не появляется
## (отметка gone_mark).

signal arrived

enum Phase { WINDOW, READY, JUMP, LANDED, RUN, WAIT, DOOR }

const READY_SEC := 0.5
const JUMP_SEC := 0.5
const JUMP_HEIGHT := 26.0
const LANDED_SEC := 0.3
const RUN_SPEED := 175.0
const LEAD_GAP := 300.0
const RESUME_GAP := 170.0
const MEOW_GAP := 120.0

@export var gone_mark: String = ""
@export var arrive_mark: String = ""
@export var floor_y: float = 255.0
@export var exit_x: float = 0.0

var _phase: Phase = Phase.WINDOW
var _clock: float = 0.0
var _from: Vector2 = Vector2.ZERO

@onready var _body: CatSprite = $Body
@onready var _notice: Area2D = $Notice
@onready var _meow: Node2D = $Meow


## Убирает кота, если он уже ушёл, иначе сажает его на окно и ждёт героя.
func _ready() -> void:
	if not gone_mark.is_empty() and World.is_marked(gone_mark):
		queue_free()
		return
	_meow.hide()
	if not arrive_mark.is_empty() and World.is_marked(arrive_mark):
		global_position = Vector2(exit_x, floor_y)
		_body.pose(CatSprite.SIT)
		_enter(Phase.DOOR)
		return
	_body.pose(CatSprite.WINDOW)
	_notice.body_entered.connect(_on_notice_body_entered)


## Сообщает, заметил ли кот героя.
## Возвращает true с той минуты, как кот перестал сидеть на окне.
func is_running() -> bool:
	return _phase != Phase.WINDOW


## Сообщает, сидит ли кот у двери и ждёт, пока герой войдёт.
func is_at_door() -> bool:
	return _phase == Phase.DOOR


## Сообщает, ждёт ли кот отставшего героя.
## Возвращает true, пока кот сидит посреди дороги.
func is_waiting() -> bool:
	return _phase == Phase.WAIT


## Начинает спуск: кот мяукает и готовится к прыжку.
func run_away() -> void:
	if _phase != Phase.WINDOW:
		return
	_body.face(_direction())
	_meow.show()
	_body.pose(CatSprite.READY)
	_enter(Phase.READY)


## Ведёт кота по шагам: подготовка, прыжок, посадка, бег, ожидание героя, уход за дверь.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	match _phase:
		Phase.READY:
			if _clock >= READY_SEC:
				_meow.hide()
				_from = global_position
				_body.pose(CatSprite.JUMP)
				_enter(Phase.JUMP)
		Phase.JUMP:
			_fly(minf(_clock / JUMP_SEC, 1.0))
		Phase.LANDED:
			if _clock >= LANDED_SEC:
				_enter(Phase.RUN)
		Phase.RUN:
			_run(delta)
		Phase.WAIT:
			_body.face(_hero_x() - global_position.x)
			if _behind() <= RESUME_GAP:
				_enter(Phase.RUN)
		Phase.DOOR:
			_body.face(_hero_x() - global_position.x)
			_meow.visible = absf(_hero_x() - global_position.x) < MEOW_GAP and _clock < 1.5


## Ведёт кота с подоконника на пол по дуге и сажает его.
## [param progress] - доля прыжка от 0 до 1.
func _fly(progress: float) -> void:
	var drop := floor_y - _from.y
	var x := lerpf(_from.x, _from.x + _direction() * drop * 0.6, progress)
	global_position = Vector2(x, floor_y)
	var height := (
		drop * (1.0 - progress * progress) + JUMP_HEIGHT * 4.0 * progress * (1.0 - progress)
	)
	_body.lift(height)
	if progress >= 1.0:
		_body.lift(0.0)
		_body.pose(CatSprite.SIT)
		Puff.spawn(get_parent(), global_position)
		_enter(Phase.LANDED)


## Бежит к двери; садится, если герой отстал, и садится ждать у двери, когда добежал.
## [param delta] - время кадра в секундах.
func _run(delta: float) -> void:
	if _behind() > LEAD_GAP:
		_body.pose(CatSprite.SIT)
		_enter(Phase.WAIT)
		return
	_body.face(_direction())
	global_position.x = move_toward(global_position.x, exit_x, RUN_SPEED * delta)
	if _body.run(delta):
		Puff.spawn(get_parent(), global_position, Puff.STEP_AMOUNT)
	if is_equal_approx(global_position.x, exit_x):
		_body.pose(CatSprite.SIT)
		_enter(Phase.DOOR)
		if not arrive_mark.is_empty():
			World.mark(arrive_mark)
		arrived.emit()


## Возвращает направление к двери: 1 вправо, -1 влево.
func _direction() -> float:
	return 1.0 if exit_x >= global_position.x else -1.0


## Считает, на сколько герой отстал от кота по дороге к двери.
## Возвращает расстояние в пикселях; отрицательное, если герой впереди кота.
func _behind() -> float:
	return (global_position.x - _hero_x()) * _direction()


## Возвращает положение героя по горизонтали или положение самого кота, если героя нет.
func _hero_x() -> float:
	var room := get_tree().current_scene as Room
	if room == null or not is_instance_valid(room.player):
		return global_position.x
	return room.player.global_position.x


## Переходит в новый шаг и обнуляет его таймер.
## [param phase] - новый шаг.
func _enter(phase: Phase) -> void:
	_phase = phase
	_clock = 0.0


## Замечает героя, который подошёл близко.
## [param body] - тело, вошедшее в зону внимания кота.
func _on_notice_body_entered(body: Node2D) -> void:
	if body is Player:
		run_away()
