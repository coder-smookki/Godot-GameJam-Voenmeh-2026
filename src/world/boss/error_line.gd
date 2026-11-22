class_name ErrorLine
extends Area2D
## Строка ошибки, которой стреляет Компилятор: красная плашка с текстом едет по полу.
##
## Через неё надо перепрыгнуть. Строка, которая проехала героя и не задела его, засчитывается
## как прыжок через ошибку. Вид «падение» - кусок кода, который падает сверху туда, где стоял
## герой; перед падением на полу мигает метка.

signal touched(line: ErrorLine)
signal dodged(line: ErrorLine)

enum Kind { SLIDE, DROP }

const TEXTS: Array[String] = [
	"error", "segfault", "NULL", "0xDEAD", "undef", "warning", "EOF", "ld: err", "core"
]
const HEIGHT := 13.0
const PADDING := 5.0
const RED := Color("d81e1e")
const RED_DARK := Color("6e0f12")
const INK := Color("fff1f1")
const TRAIL := 3
const TRAIL_GAP := 7.0
const DROP_SIZE := Vector2(26.0, 26.0)
const DROP_FROM := 30.0
const DROP_SPEED := 620.0
const WARN_SEC := 0.75
const FADE_SEC := 0.25
const LAYER_PLAYER := 2

var kind: Kind = Kind.SLIDE
var speed: float = 220.0
var direction: float = 1.0
var target: Node2D = null
var floor_y: float = 254.0

var _text: String = ""
var _size: Vector2 = Vector2.ZERO
var _counted: bool = false
var _warn: float = 0.0
var _landed: bool = false
var _gone: bool = false


## Готовит строку, которая едет по полу.
## [param from_x] - откуда строка выезжает.
## [param move_right] - true, если строка едет вправо.
## [param line_speed] - скорость в пикселях в секунду.
## [param hero] - герой, через которого надо перепрыгнуть.
func setup_slide(from_x: float, move_right: bool, line_speed: float, hero: Node2D) -> void:
	kind = Kind.SLIDE
	direction = 1.0 if move_right else -1.0
	speed = line_speed
	target = hero
	_text = TEXTS[randi() % TEXTS.size()]
	var width := Palette.font().get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8).x
	_size = Vector2(width + PADDING * 2.0, HEIGHT)
	position = Vector2(from_x, floor_y)


## Готовит кусок кода, который упадёт на место героя.
## [param at_x] - куда он упадёт.
## [param hero] - герой.
func setup_drop(at_x: float, hero: Node2D) -> void:
	kind = Kind.DROP
	target = hero
	_text = "{ }"
	_size = DROP_SIZE
	_warn = WARN_SEC
	position = Vector2(at_x, DROP_FROM)


## Создаёт область касания по размеру строки.
func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _size - Vector2(2.0, 2.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -_size.y * 0.5)
	add_child(shape)
	monitoring = kind == Kind.SLIDE
	body_entered.connect(_on_body_entered)
	z_index = 5


## Двигает строку и проверяет, проехала ли она героя.
## [param delta] - время кадра в секундах.
func _physics_process(delta: float) -> void:
	if _gone:
		return
	if kind == Kind.DROP:
		_fall(delta)
	else:
		position.x += speed * direction * delta
		_check_dodge()
	queue_redraw()


## Рисует строку с бегущим следом или метку и падающий кусок кода.
func _draw() -> void:
	if kind == Kind.DROP and _warn > 0.0:
		var blink := 0.35 + 0.35 * sin(_warn * 30.0)
		var mark := Rect2(
			Vector2(-_size.x * 0.5, floor_y - position.y - 3.0), Vector2(_size.x, 3.0)
		)
		draw_rect(mark, Color(RED, blink))
		return
	var box := Rect2(Vector2(-_size.x * 0.5, -_size.y), _size)
	if kind == Kind.SLIDE:
		for index: int in TRAIL:
			var ghost := box
			ghost.position.x -= direction * TRAIL_GAP * (index + 1)
			draw_rect(ghost, Color(RED, 0.18 - index * 0.05))
	draw_rect(box, RED_DARK)
	draw_rect(box.grow(-1.0), RED)
	var font := Palette.font()
	var baseline := Vector2(box.position.x + PADDING, box.end.y - 3.0)
	if kind == Kind.DROP:
		baseline = Vector2(box.position.x + 1.0, box.end.y - 9.0)
	draw_string(font, baseline.round(), _text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, INK)


## Сообщает, засчитана ли строка как прыжок через неё.
func is_counted() -> bool:
	return _counted


## Растворяет строку: она гаснет и исчезает.
func vanish() -> void:
	if _gone:
		return
	_gone = true
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	tween.tween_callback(queue_free)


## Ведёт кусок кода: сначала мигает метка, потом он падает и разбивается о пол.
## [param delta] - время кадра в секундах.
func _fall(delta: float) -> void:
	if _warn > 0.0:
		_warn -= delta
		if _warn <= 0.0:
			monitoring = true
		return
	if _landed:
		return
	position.y = minf(position.y + DROP_SPEED * delta, floor_y)
	if position.y >= floor_y:
		_landed = true
		Puff.spawn(get_parent(), position, Puff.STEP_AMOUNT * 2)
		vanish()


## Засчитывает прыжок, когда строка целиком проехала героя.
func _check_dodge() -> void:
	if _counted or not is_instance_valid(target):
		return
	var tail := position.x - direction * _size.x * 0.5
	var passed := tail > target.global_position.x + 18.0
	if direction < 0.0:
		passed = tail < target.global_position.x - 18.0
	if passed:
		_counted = true
		dodged.emit(self)


## Сообщает бою, что строка задела героя.
## [param body] - тело, которого коснулась строка.
func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _gone:
		_counted = true
		touched.emit(self)
