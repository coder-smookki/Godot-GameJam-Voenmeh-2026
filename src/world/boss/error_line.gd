class_name ErrorLine
extends Area2D
## Ошибка, которой стреляет Компилятор: столбик шахматки едет по полу к герою.
##
## Через неё надо перепрыгнуть. Столбики бывают двух видов из рисунков художниц: низкий
## и высокий; высокий труднее, поэтому он едет чуть быстрее и проходит под героем за меньшее
## время. Ошибка, которая проехала героя и не задела его, засчитывается как прыжок через неё.
## Область касания немного меньше рисунка, чтобы прыжок впритык не наказывался.

signal touched(line: ErrorLine)
signal dodged(line: ErrorLine)

const LOW_TEXTURE: Texture2D = preload("res://assets/props/obstacle_low.png")
const HIGH_TEXTURE: Texture2D = preload("res://assets/props/obstacle_high.png")
const HIT_INSET := Vector2(10.0, 7.0)
const TRAIL := 3
const TRAIL_GAP := 9.0
const TRAIL_COLOR := Color(1.0, 0.2, 0.3, 0.3)
const WOBBLE := 0.06
const WOBBLE_RATE := 14.0
const FADE_SEC := 0.25
const LAYER_PLAYER := 2

var speed: float = 220.0
var direction: float = 1.0
var target: Node2D = null
var floor_y: float = 254.0
var high: bool = false

var _texture: Texture2D = LOW_TEXTURE
var _counted: bool = false
var _gone: bool = false
var _clock: float = 0.0


## Готовит ошибку, которая едет по полу.
## [param from_x] - откуда она выезжает.
## [param move_right] - true, если она едет вправо.
## [param line_speed] - скорость в пикселях в секунду.
## [param hero] - герой, через которого надо перепрыгнуть.
## [param tall] - true для высокого столбика.
func setup_slide(
	from_x: float, move_right: bool, line_speed: float, hero: Node2D, tall: bool = false
) -> void:
	direction = 1.0 if move_right else -1.0
	speed = line_speed
	target = hero
	high = tall
	_texture = HIGH_TEXTURE if tall else LOW_TEXTURE
	position = Vector2(from_x, floor_y)


## Возвращает размер области касания: рисунок без краёв.
func hit_size() -> Vector2:
	return _texture.get_size() - HIT_INSET


## Создаёт область касания по размеру рисунка.
func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hit_size()
	shape.shape = rect
	shape.position = Vector2(0.0, -rect.size.y * 0.5)
	add_child(shape)
	body_entered.connect(_on_body_entered)
	z_index = 5


## Двигает ошибку и проверяет, проехала ли она героя.
## [param delta] - время кадра в секундах.
func _physics_process(delta: float) -> void:
	if _gone:
		return
	_clock += delta
	position.x += speed * direction * delta
	_check_dodge()
	queue_redraw()


## Рисует столбик с бегущим красным следом; столбик слегка качается на ходу.
func _draw() -> void:
	var size := _texture.get_size()
	var box := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	for index: int in TRAIL:
		var ghost := box
		ghost.position.x -= direction * TRAIL_GAP * (index + 1)
		draw_texture_rect(_texture, ghost, false, Color(TRAIL_COLOR, TRAIL_COLOR.a - index * 0.08))
	draw_set_transform(Vector2.ZERO, sin(_clock * WOBBLE_RATE) * WOBBLE * direction)
	draw_texture_rect(_texture, box, false)
	draw_set_transform(Vector2.ZERO)


## Сообщает, засчитана ли ошибка как прыжок через неё.
func is_counted() -> bool:
	return _counted


## Растворяет ошибку: она гаснет и исчезает.
func vanish() -> void:
	if _gone:
		return
	_gone = true
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	tween.tween_callback(queue_free)


## Засчитывает прыжок, когда ошибка целиком проехала героя.
func _check_dodge() -> void:
	if _counted or not is_instance_valid(target):
		return
	var tail := position.x - direction * _texture.get_width() * 0.5
	var passed := tail > target.global_position.x + 18.0
	if direction < 0.0:
		passed = tail < target.global_position.x - 18.0
	if passed:
		_counted = true
		dodged.emit(self)


## Сообщает бою, что ошибка задела героя.
## [param body] - тело, которого коснулась ошибка.
func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _gone:
		_counted = true
		touched.emit(self)
