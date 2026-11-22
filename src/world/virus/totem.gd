class_name Totem
extends StaticBody2D
## Надпись ERROR из шахматки: буквы выбиваются выстрелами отладчика по одной, справа налево.
##
## Буквы нарисованы художницей одной картинкой; тотем вырезает из неё по букве.
## Когда выбита последняя, по комнате проходит волна восстановления, заражение этажа
## падает, а шахматка на двери (seal) растворяется.

signal destroyed

const LAYER_SHOOTABLE := 8
const ART: Texture2D = preload("res://assets/props/error.png")
const LETTERS: Array[Vector2] = [
	Vector2(0, 31), Vector2(32, 63), Vector2(64, 95), Vector2(97, 122), Vector2(125, 154)
]
const HIT_SEC := 0.18
const DISSOLVE_SEC := 0.7
const WAVE_SEC := 0.6
const WAVE_WIDTH := 1200.0
const WAVE_HEIGHT := 270.0
const SHARD_COLORS: Array[Color] = [Color(1.0, 0.0, 1.0), Color(0.0, 0.07, 0.0)]

@export var totem_id: String = ""
@export var heal_amount: float = 8.0
@export var seal: CanvasItem = null

var _left: int = 0
var _shake: float = 0.0

@onready var _shape: CollisionShape2D = $Shape


## Убирает уже разбитую надпись вместе с шахматкой на двери или готовит целую к бою.
func _ready() -> void:
	collision_layer = LAYER_SHOOTABLE
	collision_mask = 0
	if World.is_marked(_mark()):
		if seal != null:
			seal.queue_free()
		queue_free()
		return
	_left = LETTERS.size()
	_resize_shape()


## Рисует оставшиеся буквы; только что задетая буква вздрагивает.
func _draw() -> void:
	var width := LETTERS[LETTERS.size() - 1].y
	for index: int in _left:
		var span := LETTERS[index]
		var source := Rect2(span.x, 0.0, span.y - span.x, ART.get_height())
		var target := source
		target.position = Vector2(span.x - width * 0.5, -ART.get_height())
		if index == _left - 1:
			target.position.x += _shake
		draw_texture_rect_region(ART, target, source)


## Принимает попадание отладчика: выбивает крайнюю правую букву.
func hit() -> void:
	if _left <= 0:
		return
	_left -= 1
	_burst(_letter_center(_left))
	queue_redraw()
	if _left == 0:
		_destroy()
		return
	_resize_shape()
	var tween := create_tween()
	tween.tween_method(_set_shake, 3.0, 0.0, HIT_SEC)


## Сообщает, сколько букв ещё осталось.
## Возвращает число невыбитых букв.
func letters_left() -> int:
	return _left


## Запоминает разбитую надпись, лечит этаж, растворяет шахматку и пускает волну.
func _destroy() -> void:
	_shape.set_deferred("disabled", true)
	World.mark(_mark())
	World.mark("first_totem")
	Infection.heal(Infection.current_floor, heal_amount)
	SaveSystem.save_game()
	destroyed.emit()
	if seal != null:
		var dissolve := create_tween().set_parallel(true)
		dissolve.tween_property(seal, "modulate:a", 0.0, DISSOLVE_SEC)
		dissolve.tween_property(seal, "scale", Vector2(1.06, 0.2), DISSOLVE_SEC).set_ease(
			Tween.EASE_IN
		)
		dissolve.chain().tween_callback(seal.queue_free)
	var wave := ColorRect.new()
	wave.color = Color(1.0, 1.0, 1.0, 0.85)
	wave.size = Vector2(4.0, WAVE_HEIGHT)
	wave.position = Vector2(-2.0, -position.y)
	wave.z_index = 20
	add_child(wave)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(wave, "size:x", WAVE_WIDTH * 2.0, WAVE_SEC)
	tween.tween_property(wave, "position:x", -WAVE_WIDTH, WAVE_SEC)
	tween.tween_property(wave, "color:a", 0.0, WAVE_SEC)
	tween.chain().tween_interval(DISSOLVE_SEC - WAVE_SEC + 0.05)
	tween.chain().tween_callback(queue_free)


## Выбрасывает горсть клеток шахматки из выбитой буквы.
## [param at] - центр буквы в координатах тотема.
func _burst(at: Vector2) -> void:
	var shards := CPUParticles2D.new()
	shards.position = at
	shards.amount = 16
	shards.lifetime = 0.5
	shards.one_shot = true
	shards.explosiveness = 0.95
	shards.spread = 180.0
	shards.gravity = Vector2(0.0, 380.0)
	shards.initial_velocity_min = 40.0
	shards.initial_velocity_max = 120.0
	shards.scale_amount_min = 2.0
	shards.scale_amount_max = 4.0
	shards.color = SHARD_COLORS[_left % SHARD_COLORS.size()]
	shards.finished.connect(shards.queue_free)
	add_child(shards)
	shards.emitting = true


## Возвращает центр буквы в координатах тотема.
## [param index] - номер буквы слева направо.
func _letter_center(index: int) -> Vector2:
	var width := LETTERS[LETTERS.size() - 1].y
	var span := LETTERS[index]
	return Vector2((span.x + span.y) * 0.5 - width * 0.5, -ART.get_height() * 0.5)


## Сдвигает задетую букву и перерисовывает надпись.
## [param offset] - смещение в пикселях.
func _set_shake(offset: float) -> void:
	_shake = offset * (1.0 if int(offset * 10.0) % 2 == 0 else -1.0)
	queue_redraw()


## Подгоняет область попадания под оставшиеся буквы.
func _resize_shape() -> void:
	var width := LETTERS[LETTERS.size() - 1].y
	var right := LETTERS[_left - 1].y
	var rect := RectangleShape2D.new()
	rect.size = Vector2(right, ART.get_height())
	_shape.shape = rect
	_shape.position = Vector2(right * 0.5 - width * 0.5, -ART.get_height() * 0.5)


## Собирает имя отметки разбитой надписи.
## Возвращает строку вида "totem_<id>".
func _mark() -> String:
	return "totem_%s" % totem_id
