class_name FixColumn
extends StaticBody2D
## Терминал с числом на крыше: герой чинит его отладчиком, отключая правило ЛАБЫ.
##
## Сверху написано нужное число, на экранчике колонны бегут числа от 0 до 9. Попадание
## отладчика в момент, когда число совпало с нужным, чинит колонну. Промах сбивает число
## и злит ЛАБУ. С зажатым отладчиком время идёт вдвое медленнее, поэтому поймать число
## легче. Терминал выезжает из крыши и уходит обратно. Мажайцев может починить терминал сам
## ([method assist]).

signal fixed(column: FixColumn)
signal missed(column: FixColumn)

const LAYER_SHOOTABLE := 8
const WIDTH := 40.0
const HEIGHT := 110.0
const SCREEN := Rect2(-15.0, -100.0, 30.0, 26.0)
const FONT_SIZE := 16
const STEP_SEC := 0.55
const METAL := Color("2b3142")
const METAL_LIGHT := Color("47506a")
const GLASS := Color("0b0f17")
const WRONG := Color("ff3b3b")
const RIGHT := Color("3ad35a")
const RISE_SEC := 0.5
const FLASH_SEC := 0.3

var target: int = 0
var value: int = 0
var is_fixed: bool = false

var _clock: float = 0.0
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
var _rise: float = 0.0


## Ставит колонну на слой попаданий отладчика и создаёт её форму.
func _ready() -> void:
	collision_layer = LAYER_SHOOTABLE
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH, HEIGHT)
	shape.shape = rect
	shape.position = Vector2(0.0, -HEIGHT * 0.5)
	add_child(shape)
	set_process(false)


## Выдвигает колонну с новым нужным числом и запускает бег чисел.
## [param wanted] - число, которое нужно поймать.
func rise(wanted: int) -> void:
	target = wanted
	value = (wanted + 5) % 10
	is_fixed = false
	_clock = 0.0
	set_process(true)
	create_tween().tween_property(self, "_rise", 1.0, RISE_SEC).set_trans(Tween.TRANS_BACK)


## Прячет колонну обратно в пол.
func sink() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_rise", 0.0, RISE_SEC)
	tween.tween_callback(set_process.bind(false))
	tween.tween_callback(queue_redraw)


## Перебирает числа на экранчике.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	if not is_fixed:
		_clock += delta
		if _clock >= STEP_SEC:
			_clock -= STEP_SEC
			value = (value + 1) % 10
	queue_redraw()


## Рисует колонну, нужное число над ней и число на экранчике.
func _draw() -> void:
	if _rise <= 0.01:
		return
	var lift := HEIGHT * (1.0 - _rise)
	draw_set_transform(Vector2(0.0, lift))
	var body := Rect2(-WIDTH * 0.5, -HEIGHT, WIDTH, HEIGHT)
	draw_rect(body, METAL)
	draw_rect(Rect2(body.position, Vector2(3.0, HEIGHT)), METAL_LIGHT)
	for row: int in 4:
		draw_rect(Rect2(-WIDTH * 0.5 + 6.0, -56.0 + row * 12.0, WIDTH - 12.0, 3.0), METAL_LIGHT)
	draw_rect(SCREEN, GLASS)
	var font := Palette.font()
	var shown := RIGHT if is_fixed else WRONG
	_digit(font, Vector2(0.0, SCREEN.end.y - 5.0), str(value), shown)
	if not is_fixed:
		_digit(font, Vector2(0.0, -HEIGHT - 8.0), "=%d" % target, Palette.GOAL)
	if _flash > 0.0:
		draw_rect(body, Color(_flash_color, _flash / FLASH_SEC * 0.7))
	draw_set_transform(Vector2.ZERO)


## Принимает попадание отладчика: совпавшее число чинит колонну, другое сбивает его.
func hit() -> void:
	if is_fixed or _rise < 0.9:
		return
	if value == target:
		is_fixed = true
		_blink(RIGHT)
		Puff.spawn(get_parent(), global_position + Vector2(0.0, -HEIGHT), 6)
		fixed.emit(self)
	else:
		value = randi() % 10
		_blink(WRONG)
		missed.emit(self)


## Чинит терминал без отладчика: так помогает Мажайцев.
func assist() -> void:
	if is_fixed:
		return
	value = target
	is_fixed = true
	_blink(RIGHT)
	Puff.spawn(get_parent(), global_position + Vector2(0.0, -HEIGHT), 6)
	fixed.emit(self)


## Сообщает, выдвинут ли терминал.
func is_up() -> bool:
	return _rise >= 0.9


## Вспыхивает цветом.
## [param color] - цвет вспышки.
func _blink(color: Color) -> void:
	_flash = FLASH_SEC
	_flash_color = color


## Рисует строку по центру.
## [param font] - шрифт.
## [param at] - середина базовой линии.
## [param text] - строка.
## [param color] - цвет.
func _digit(font: Font, at: Vector2, text: String, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x
	var left := (at - Vector2(width * 0.5, 0.0)).round()
	draw_string_outline(
		font, left, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, 4, Color.BLACK
	)
	draw_string(font, left, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, color)
