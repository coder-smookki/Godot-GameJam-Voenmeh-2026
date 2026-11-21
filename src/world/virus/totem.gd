class_name Totem
extends StaticBody2D
## ERROR-тотем: столбик блоков-букв, которые выбиваются выстрелами отладчика по одному.
##
## Когда выбита последняя буква, по комнате проходит волна восстановления,
## заражение этажа падает, а заражённые участки (дочерние узлы) исчезают.

signal destroyed

const LAYER_SHOOTABLE := 8
const BLOCK := 32.0
const LETTER_SIZE := 16
const LETTER_BASELINE := 8.0
const WAVE_SEC := 0.6
const WAVE_WIDTH := 960.0
const WAVE_HEIGHT := 270.0

@export var totem_id: String = ""
@export var letters: String = "ERROR"
@export var heal_amount: float = 8.0

var _left: int = 0

@onready var _shape: CollisionShape2D = $Shape


## Убирает уже разбитый тотем или готовит целый к бою.
func _ready() -> void:
	collision_layer = LAYER_SHOOTABLE
	collision_mask = 0
	if World.is_marked(_mark()):
		queue_free()
		return
	_left = letters.length()
	_resize_shape()


## Рисует оставшиеся блоки-буквы.
func _draw() -> void:
	var font := Palette.font()
	for index: int in _left:
		var top := -BLOCK * float(index + 1)
		draw_rect(Rect2(-BLOCK * 0.5, top, BLOCK, BLOCK - 1.0), Palette.DANGER)
		var letter := letters[letters.length() - 1 - index]
		draw_string(
			font,
			Vector2(-BLOCK * 0.5, top + BLOCK - LETTER_BASELINE),
			letter,
			HORIZONTAL_ALIGNMENT_CENTER,
			BLOCK,
			LETTER_SIZE,
			Palette.TEXT
		)


## Принимает попадание отладчика: выбивает верхнюю букву.
func hit() -> void:
	if _left <= 0:
		return
	_left -= 1
	queue_redraw()
	if _left == 0:
		_destroy()
	else:
		_resize_shape()


## Сообщает, сколько букв ещё осталось.
## Возвращает число невыбитых блоков.
func letters_left() -> int:
	return _left


## Запоминает разбитый тотем, лечит этаж и запускает волну восстановления.
func _destroy() -> void:
	_shape.set_deferred("disabled", true)
	World.mark(_mark())
	World.mark("first_totem")
	Infection.heal(Infection.current_floor, heal_amount)
	SaveSystem.save_game()
	destroyed.emit()
	var wave := ColorRect.new()
	wave.color = Color(1.0, 1.0, 1.0, 0.85)
	wave.size = Vector2(4.0, WAVE_HEIGHT)
	wave.position = Vector2(-2.0, -WAVE_HEIGHT + 6.0)
	wave.z_index = 20
	add_child(wave)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(wave, "size:x", WAVE_WIDTH * 2.0, WAVE_SEC)
	tween.tween_property(wave, "position:x", -WAVE_WIDTH, WAVE_SEC)
	tween.tween_property(wave, "color:a", 0.0, WAVE_SEC)
	tween.chain().tween_callback(queue_free)


## Подгоняет область попадания под оставшиеся блоки.
func _resize_shape() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(BLOCK, BLOCK * float(_left))
	_shape.shape = rect
	_shape.position = Vector2(0.0, -BLOCK * float(_left) * 0.5)


## Собирает имя отметки разбитого тотема.
## Возвращает строку вида "totem_<id>".
func _mark() -> String:
	return "totem_%s" % totem_id
