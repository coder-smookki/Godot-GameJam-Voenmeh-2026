class_name Blob
extends StaticBody2D
## Сгусток ошибки: живой слизень из шахматки, который перекрывает коридор и дверь.
##
## Стоит стеной: герой не может пройти мимо. Когда герой подходит, сам начинается
## [QuizGame] - вопросы по программированию. Каждый правильный ответ бьёт сгусток: он
## вздрагивает, сплющивается, показывает кадр «с уроном», теряет клетки и съёживается.
## На неверный ответ сгусток бросается на героя. Когда нужное число ответов набрано, сгусток
## лопается, шахматка на двери (seal) и надпись над ним (label) растворяются. Проигранная
## викторина отбрасывает героя и отнимает сердце; подойти можно снова.
## Слизень живой: дышит (сплющивается и вытягивается), покачивается, ползёт на месте, с него
## капает шахматка, а глаза моргают и следят за героем.

signal destroyed

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const WHOLE: Texture2D = preload("res://assets/props/blob.png")
const HURT: Texture2D = preload("res://assets/props/blob_hit.png")
const SIZE := Vector2(208.0, 140.0)
const ZONE_REACH := 70.0
const BREATH := 0.05
const BREATH_RATE := 3.2
const SWAY := 0.07
const CREEP := 3.0
const SHRINK_PER_HIT := 0.07
const HURT_SEC := 0.6
const ATTACK_SEC := 0.5
const LUNGE := 26.0
const FLASH := Color(2.0, 0.6, 0.6)
const POP_SEC := 0.45
const PUSH := Vector2(320.0, -240.0)
const EYES: Array[Vector2] = [Vector2(-26.0, -96.0), Vector2(26.0, -96.0)]
const EYE_RADIUS := 9.0
const PUPIL_RADIUS := 4.0
const BLINK_EVERY := 3.4
const INK := Color("061006")

@export var blob_id: String = ""
@export var heal_amount: float = 8.0
@export var seal: CanvasItem = null
@export var label: CanvasItem = null

var _left: int = 0
var _total: int = 0
var _busy: bool = false
var _clock: float = 0.0
var _hurt: float = 0.0
var _attack: float = 0.0
var _size: float = 1.0
var _popped: bool = false
var _face: Node2D = null
var _drips: CPUParticles2D = null

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $Shape
@onready var _burst: CPUParticles2D = $Burst


## Убирает уже лопнувший сгусток вместе с шахматкой или ставит стену, зону викторины,
## глаза и капли.
func _ready() -> void:
	collision_layer = LAYER_WORLD
	collision_mask = 0
	if World.is_marked(mark_name()):
		for item: CanvasItem in [seal, label]:
			if item != null:
				item.queue_free()
		queue_free()
		return
	_total = Difficulty.value("quiz_answers")
	_left = _total
	_sprite.centered = false
	_sprite.offset = Vector2(-SIZE.x * 0.5, -SIZE.y)
	_build_zone()
	_build_drips()
	_face = Node2D.new()
	_face.z_index = 1
	_face.draw.connect(_draw_face)
	add_child(_face)


## Дышит, покачивается, ползёт на месте, вздрагивает от урона и бросается на героя.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if _popped:
		return
	_clock += delta
	_hurt = maxf(_hurt - delta, 0.0)
	_attack = maxf(_attack - delta, 0.0)
	var wounded := 1.0 - float(_left) / maxf(_total, 1.0)
	var breath := sin(_clock * BREATH_RATE * (1.0 + wounded))
	var squash := Vector2(1.0 + BREATH * breath, 1.0 - BREATH * breath)
	var side := _hero_side()
	var lunge := 0.0
	if _attack > 0.0:
		var t := 1.0 - _attack / ATTACK_SEC
		lunge = sin(t * PI)
		squash += Vector2(0.25, -0.15) * lunge
	if _hurt > 0.0:
		var shake := sin(_hurt * 60.0) * 0.08 * (_hurt / HURT_SEC)
		squash += Vector2(shake, -shake)
	_sprite.scale = squash * _size
	_sprite.skew = SWAY * sin(_clock * 1.6) + 0.12 * lunge * side
	_sprite.position.x = CREEP * sin(_clock * 0.8) + LUNGE * lunge * side
	_sprite.texture = HURT if _hurt > 0.0 else WHOLE
	_sprite.modulate = (
		FLASH.lerp(Color.WHITE, 1.0 - _hurt / HURT_SEC) if _hurt > 0.0 else Color.WHITE
	)
	_face.queue_redraw()


## Принимает урон от правильного ответа: вздрагивает, теряет клетки и съёживается.
func damage() -> void:
	if _left <= 0:
		return
	_left -= 1
	_hurt = HURT_SEC
	_sprite.texture = HURT
	_size = 1.0 - SHRINK_PER_HIT * float(_total - _left)
	_burst.restart()
	_burst.emitting = true


## Бросается на героя: неверный ответ.
func attack() -> void:
	_attack = ATTACK_SEC


## Сообщает, сколько правильных ответов сгусток ещё выдержит.
func hits_left() -> int:
	return _left


## Сообщает, идёт ли сейчас викторина у этого сгустка.
func is_busy() -> bool:
	return _busy


## Возвращает имя отметки лопнувшего сгустка: "blob_<id>".
func mark_name() -> String:
	return "blob_%s" % blob_id


## Проводит викторину: правильные ответы бьют сгусток, победа его лопает, поражение
## отбрасывает героя и отнимает сердце.
## [param player] - герой, который подошёл.
func _quiz(player: Player) -> void:
	_busy = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	Ui.quiz.answered.connect(_on_answered)
	var won: bool = await Ui.quiz.play()
	Ui.quiz.answered.disconnect(_on_answered)
	if not is_inside_tree():
		return
	process_mode = Node.PROCESS_MODE_INHERIT
	if won:
		Ui.toast(tr("QUIZ_WON"), ToastStack.KIND_HINT)
		_pop()
		return
	attack()
	player.knock_back(Vector2(PUSH.x * _hero_side(), PUSH.y))
	Ui.toast(tr("QUIZ_LOST"), ToastStack.KIND_LABA)
	_busy = false
	Game.lose_heart()


## Лопает сгусток: запоминает победу, лечит этаж и растворяет всё, что он держал.
func _pop() -> void:
	_popped = true
	_shape.set_deferred("disabled", true)
	_drips.emitting = false
	_face.hide()
	_burst.amount = 60
	_burst.restart()
	_burst.emitting = true
	World.mark(mark_name())
	Infection.heal(Infection.current_floor, heal_amount)
	SaveSystem.save_game()
	destroyed.emit()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(1.6, 0.1), POP_SEC).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, "modulate:a", 0.0, POP_SEC)
	for item: CanvasItem in [seal, label]:
		if item != null:
			tween.tween_property(item, "modulate:a", 0.0, POP_SEC * 1.5)
	tween.chain().tween_interval(0.6)
	tween.chain().tween_callback(_cleanup)


## Убирает сгусток, шахматку и надпись после того, как они растворились.
func _cleanup() -> void:
	for item: CanvasItem in [seal, label]:
		if item != null:
			item.queue_free()
	queue_free()


## Рисует глаза: они моргают, следят за героем, от урона жмурятся крестиками, в атаке злятся.
func _draw_face() -> void:
	var look := Vector2(_hero_side() * 3.0, 1.0)
	var squash := _sprite.scale
	var blink := fmod(_clock, BLINK_EVERY) < 0.12
	for eye: Vector2 in EYES:
		var at := Vector2(eye.x * squash.x, eye.y * squash.y)
		at.x += _sprite.position.x + _sprite.skew * -at.y
		if _hurt > 0.0:
			_face.draw_line(at - Vector2(5.0, 5.0), at + Vector2(5.0, 5.0), Color.WHITE, 2.0)
			_face.draw_line(at + Vector2(-5.0, 5.0), at + Vector2(5.0, -5.0), Color.WHITE, 2.0)
			continue
		if blink:
			_face.draw_line(
				at - Vector2(EYE_RADIUS, 0.0), at + Vector2(EYE_RADIUS, 0.0), Color.WHITE, 2.0
			)
			continue
		_face.draw_circle(at, EYE_RADIUS + 1.0, INK)
		_face.draw_circle(at, EYE_RADIUS, Color.WHITE)
		_face.draw_circle(at + look, PUPIL_RADIUS, INK)
		_face.draw_rect(Rect2(at + look + Vector2(-2.0, -3.0), Vector2(2.0, 2.0)), Color.WHITE)
		if _attack > 0.0:
			var brow := 4.0 if eye.x < 0.0 else -4.0
			_face.draw_line(
				at + Vector2(-EYE_RADIUS, -EYE_RADIUS - 2.0 - brow),
				at + Vector2(EYE_RADIUS, -EYE_RADIUS - 2.0 + brow),
				INK,
				3.0
			)


## Возвращает, с какой стороны герой: 1 справа, -1 слева.
func _hero_side() -> float:
	var room := get_tree().current_scene as Room
	if room == null or not is_instance_valid(room.player):
		return 1.0
	return 1.0 if room.player.global_position.x >= global_position.x else -1.0


## Создаёт зону перед сгустком: вошедший в неё герой начинает викторину.
func _build_zone() -> void:
	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = LAYER_PLAYER
	zone.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(SIZE.x + ZONE_REACH * 2.0, 150.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -75.0)
	zone.add_child(shape)
	zone.body_entered.connect(_on_zone_body_entered)
	add_child(zone)


## Создаёт капли шахматки, которые стекают со сгустка.
func _build_drips() -> void:
	_drips = CPUParticles2D.new()
	_drips.position = Vector2(0.0, -40.0)
	_drips.amount = 10
	_drips.lifetime = 0.9
	_drips.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_drips.emission_rect_extents = Vector2(SIZE.x * 0.42, 30.0)
	_drips.direction = Vector2.DOWN
	_drips.spread = 5.0
	_drips.gravity = Vector2(0.0, 160.0)
	_drips.initial_velocity_min = 0.0
	_drips.initial_velocity_max = 10.0
	_drips.scale_amount_min = 2.0
	_drips.scale_amount_max = 3.0
	_drips.color_initial_ramp = _burst.color_initial_ramp
	add_child(_drips)


## Отвечает на ответ викторины: правильный бьёт сгусток, неверный злит его.
## [param correct] - true, если ответ правильный.
func _on_answered(correct: bool) -> void:
	if correct:
		damage()
	else:
		attack()


## Начинает викторину, когда герой подошёл к сгустку.
## [param body] - тело, вошедшее в зону.
func _on_zone_body_entered(body: Node2D) -> void:
	if body is Player and not _busy and _left > 0 and not _popped and not Ui.is_modal_open():
		_quiz(body)
