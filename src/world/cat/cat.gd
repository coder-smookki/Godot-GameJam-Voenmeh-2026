class_name Cat
extends Node2D
## Кот: сидит на месте, а когда герой подходит, мяукает, спрыгивает и скачет к выходу.
##
## Кадры художниц смотрят влево; при беге вправо спрайт отражается. Весь побег собран
## в одну цепочку движений, поэтому он останавливается вместе с миром на паузе.
## Убежавший кот ставит отметку мира и больше в комнате не появляется.

signal ran_away

const POSES: Dictionary = {
	&"sit": preload("res://assets/characters/cat/sit.png"),
	&"crouch": preload("res://assets/characters/cat/crouch.png"),
	&"leap": preload("res://assets/characters/cat/leap.png"),
	&"land": preload("res://assets/characters/cat/land.png"),
}
const NOTICE_SEC := 0.45
const HOP_LENGTH := 56.0
const HOP_HEIGHT := 18.0
const HOP_SEC := 0.28
const DROP_SEC_PER_PX := 0.0016
const LAND_SEC := 0.09
const GATHER_SEC := 0.06
const FADE_SEC := 0.2
const SHADOW_FADE_HEIGHT := 120.0
const SHADOW_MIN_SCALE := 0.4

@export var gone_mark: String = ""
@export var floor_y: float = 264.0
@export var exit_x: float = 0.0

var _running: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _shadow: Node2D = $Shadow
@onready var _notice: Area2D = $Notice
@onready var _meow: Node2D = $Meow


## Убирает кота, если он уже убегал, иначе ждёт героя.
func _ready() -> void:
	if not gone_mark.is_empty() and World.is_marked(gone_mark):
		queue_free()
		return
	_meow.hide()
	_notice.body_entered.connect(_on_notice_body_entered)


## Сообщает, бежит ли кот сейчас.
## Возвращает true с момента, когда кот заметил героя.
func is_running() -> bool:
	return _running


## Запускает побег: присед с «мяу», прыжок на пол и скачки до выхода.
func run_away() -> void:
	if _running:
		return
	_running = true
	var direction := 1.0 if exit_x >= global_position.x else -1.0
	_sprite.flip_h = direction > 0.0
	_meow.show()
	_pose(&"crouch")
	var tween := create_tween()
	tween.tween_interval(NOTICE_SEC)
	tween.tween_callback(_meow.hide)
	var from := global_position
	while not is_equal_approx(from.x, exit_x) or not is_equal_approx(from.y, floor_y):
		var to := Vector2(move_toward(from.x, exit_x, HOP_LENGTH), floor_y)
		_add_hop(tween, from, to)
		from = to
	tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	tween.tween_callback(_leave)


## Добавляет в цепочку один скачок: полёт по дуге, приземление и сбор перед следующим.
## [param tween] - цепочка движений побега.
## [param from] - точка толчка в координатах мира.
## [param to] - точка приземления на полу.
func _add_hop(tween: Tween, from: Vector2, to: Vector2) -> void:
	var sec := HOP_SEC + absf(to.y - from.y) * DROP_SEC_PER_PX
	tween.tween_callback(_pose.bind(&"leap"))
	tween.tween_method(_fly.bind(from, to), 0.0, 1.0, sec)
	tween.tween_callback(_touch_down)
	tween.tween_interval(LAND_SEC)
	tween.tween_callback(_pose.bind(&"crouch"))
	tween.tween_interval(GATHER_SEC)


## Ставит кота в точку дуги и держит тень на полу под ним.
## [param progress] - доля скачка от 0 до 1.
## [param from] - точка толчка.
## [param to] - точка приземления.
func _fly(progress: float, from: Vector2, to: Vector2) -> void:
	var point := Vector2(lerpf(from.x, to.x, progress), lerpf(from.y, to.y, progress * progress))
	point.y -= HOP_HEIGHT * 4.0 * progress * (1.0 - progress)
	global_position = point
	var lift := maxf(to.y - point.y, 0.0)
	var shrink := clampf(1.0 - lift / SHADOW_FADE_HEIGHT, SHADOW_MIN_SCALE, 1.0)
	_shadow.global_position = Vector2(point.x, to.y)
	_shadow.scale = Vector2(shrink, shrink)


## Показывает кадр приземления и выбивает пыль из-под лап.
func _touch_down() -> void:
	_pose(&"land")
	_shadow.position = Vector2.ZERO
	_shadow.scale = Vector2.ONE
	Puff.spawn(get_parent(), global_position, Puff.STEP_AMOUNT + 1)


## Меняет кадр кота.
## [param pose] - имя кадра: sit, crouch, leap или land.
func _pose(pose: StringName) -> void:
	_sprite.texture = POSES[pose]


## Запоминает, что кот убежал, и убирает его из комнаты.
func _leave() -> void:
	if not gone_mark.is_empty():
		World.mark(gone_mark)
	ran_away.emit()
	queue_free()


## Замечает героя, который подошёл близко.
## [param body] - тело, вошедшее в зону внимания кота.
func _on_notice_body_entered(body: Node2D) -> void:
	if body is Player:
		run_away()
