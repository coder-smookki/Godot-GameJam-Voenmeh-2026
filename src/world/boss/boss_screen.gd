class_name BossScreen
extends Node2D
## Лицо заражённого Компилятора на мониторе кабинета 202, нарисованное поверх фона.
##
## Экран включается с помехами, глаза моргают и следят за героем, при атаке рот раскрывается,
## от бомбы по экрану идут трещины. Внизу три порта: закрыты, открыты (светятся) и разбиты.
## После победы экран рассыпается на клетки, и под ним остаётся спокойная капибара фона.

enum Face { IDLE, ATTACK, HURT, TEXT }
enum Port { CLOSED, OPEN, BROKEN }

const RECT := Rect2(774.0, 29.0, 414.0, 131.0)
const BACK := Color("07090e")
const EYE := Color("ff2b3a")
const EYE_GLOW := Color(1.0, 0.17, 0.23, 0.25)
const PORT_OPEN := Color("00c2e0")
const PORT_CLOSED := Color("2a3146")
const CRACK := Color(0.85, 0.9, 1.0, 0.8)
const SCAN := Color(0.0, 0.0, 0.0, 0.25)
const PORT_SIZE := Vector2(46.0, 14.0)
const BOOT_SEC := 0.9
const HURT_SEC := 0.7
const ATTACK_SEC := 0.35

var face: Face = Face.IDLE
var text: String = ""
var ports: Array[Port] = [Port.CLOSED, Port.CLOSED, Port.CLOSED]
var cracks: int = 0
var watch_x: float = 0.0

var _power: float = 0.0
var _clock: float = 0.0
var _face_left: float = 0.0
var _glitch: float = 0.0
var _crack_lines: Array[PackedVector2Array] = []


## Готовит выключенный экран.
func _ready() -> void:
	z_index = -20


## Ведёт моргание, помехи и возврат лица к покою.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	_glitch = maxf(_glitch - delta, 0.0)
	if _face_left > 0.0:
		_face_left -= delta
		if _face_left <= 0.0 and face != Face.TEXT:
			face = Face.IDLE
	queue_redraw()


## Включает экран с помехами.
func boot() -> void:
	_glitch = BOOT_SEC
	create_tween().tween_property(self, "_power", 1.0, BOOT_SEC)


## Гасит экран; под ним снова виден рисунок фона.
## [param sec] - длительность в секундах.
func power_off(sec: float) -> void:
	create_tween().tween_property(self, "_power", 0.0, sec)


## Сообщает, насколько экран включён.
func power() -> float:
	return _power


## Раскрывает рот для атаки.
func attack() -> void:
	_show(Face.ATTACK, ATTACK_SEC)


## Показывает боль от взрыва и добавляет трещину.
func hurt() -> void:
	_show(Face.HURT, HURT_SEC)
	_glitch = HURT_SEC
	cracks += 1
	_crack_lines.append(_make_crack())


## Пишет на экране текст вместо лица.
## [param value] - текст; пустая строка возвращает лицо.
func say(value: String) -> void:
	text = value
	face = Face.TEXT if not value.is_empty() else Face.IDLE
	_glitch = 0.4


## Встряхивает изображение помехами.
## [param sec] - длительность помех.
func glitch(sec: float) -> void:
	_glitch = maxf(_glitch, sec)


## Рисует экран: фон, лицо или текст, порты, трещины, строки развёртки и помехи.
func _draw() -> void:
	if _power <= 0.0:
		return
	var alpha := _power
	draw_rect(RECT, Color(BACK, alpha))
	var center := RECT.get_center() + Vector2(0.0, -12.0)
	if _glitch > 0.0:
		center.x += randf_range(-6.0, 6.0) * _glitch
	if face == Face.TEXT:
		_draw_text(center, alpha)
	else:
		_draw_face(center, alpha)
	_draw_ports(alpha)
	for line: PackedVector2Array in _crack_lines:
		draw_polyline(line, Color(CRACK, alpha), 1.0)
	for y: int in range(int(RECT.position.y), int(RECT.end.y), 3):
		draw_line(Vector2(RECT.position.x, y), Vector2(RECT.end.x, y), Color(SCAN, SCAN.a * alpha))
	if _glitch > 0.0:
		for band: int in 3:
			var y := randf_range(RECT.position.y, RECT.end.y - 6.0)
			var shift := randf_range(-14.0, 14.0)
			var strip := Rect2(
				RECT.position.x + maxf(shift, 0.0), y, RECT.size.x - absf(shift), 4.0
			)
			draw_rect(strip, Color(EYE, 0.25 * alpha))


## Рисует глаза и рот; глаза смотрят в сторону героя.
## [param center] - середина лица.
## [param alpha] - яркость экрана.
func _draw_face(center: Vector2, alpha: float) -> void:
	var look := clampf((watch_x - center.x) / 300.0, -1.0, 1.0) * 10.0
	var blink := fmod(_clock, 3.2) < 0.12
	for side: float in [-1.0, 1.0]:
		var eye := center + Vector2(side * 70.0 + look, -18.0)
		draw_rect(Rect2(eye - Vector2(26.0, 16.0), Vector2(52.0, 32.0)), Color(EYE_GLOW, alpha))
		if face == Face.HURT:
			draw_line(eye - Vector2(14.0, 10.0), eye + Vector2(14.0, 10.0), Color(EYE, alpha), 4.0)
			draw_line(
				eye + Vector2(-14.0, 10.0), eye + Vector2(14.0, -10.0), Color(EYE, alpha), 4.0
			)
			continue
		var height := 4.0 if blink else 16.0
		var angry := 6.0 if face == Face.ATTACK else 3.0
		var bottom := height * 0.5
		var top := PackedVector2Array(
			[
				eye + Vector2(-20.0, minf(-bottom - angry * side, bottom - 1.0)),
				eye + Vector2(20.0, minf(-bottom + angry * side, bottom - 1.0)),
				eye + Vector2(20.0, bottom),
				eye + Vector2(-20.0, bottom),
			]
		)
		draw_colored_polygon(top, Color(EYE, alpha))
	var mouth := center + Vector2(0.0, 30.0)
	if face == Face.ATTACK:
		draw_rect(Rect2(mouth - Vector2(36.0, 10.0), Vector2(72.0, 20.0)), Color(EYE, alpha))
		draw_rect(Rect2(mouth - Vector2(30.0, 5.0), Vector2(60.0, 10.0)), Color(BACK, alpha))
	else:
		draw_rect(Rect2(mouth - Vector2(44.0, 2.0), Vector2(88.0, 4.0)), Color(EYE, alpha))


## Рисует текст по центру экрана.
## [param center] - середина экрана.
## [param alpha] - яркость экрана.
func _draw_text(center: Vector2, alpha: float) -> void:
	var font := Palette.font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x
	var at := (center + Vector2(-width * 0.5, 8.0)).round()
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(EYE, alpha))


## Рисует три порта внизу экрана.
## [param alpha] - яркость экрана.
func _draw_ports(alpha: float) -> void:
	for index: int in ports.size():
		var x := RECT.get_center().x + (index - 1) * 120.0 - PORT_SIZE.x * 0.5
		var box := Rect2(Vector2(x, RECT.end.y - PORT_SIZE.y - 8.0), PORT_SIZE)
		match ports[index]:
			Port.CLOSED:
				draw_rect(box, Color(PORT_CLOSED, alpha))
				draw_rect(box, Color(EYE, 0.6 * alpha), false, 1.0)
			Port.OPEN:
				var pulse := 0.6 + 0.4 * sin(_clock * 8.0 + index)
				draw_rect(box.grow(3.0), Color(PORT_OPEN, 0.25 * pulse * alpha))
				draw_rect(box, Color(PORT_OPEN, pulse * alpha))
			Port.BROKEN:
				draw_rect(box, Color(0.0, 0.0, 0.0, alpha))
				draw_line(box.position, box.end, Color(CRACK, alpha), 1.0)


## Меняет лицо на время.
## [param value] - новое лицо.
## [param sec] - сколько секунд его держать.
func _show(value: Face, sec: float) -> void:
	if face == Face.TEXT:
		return
	face = value
	_face_left = sec


## Строит ломаную трещину из случайной точки экрана.
## Возвращает точки трещины.
func _make_crack() -> PackedVector2Array:
	var points := PackedVector2Array()
	var at := Vector2(
		randf_range(RECT.position.x + 40.0, RECT.end.x - 40.0),
		randf_range(RECT.position.y + 10.0, RECT.end.y - 30.0)
	)
	points.append(at)
	for step: int in 6:
		at += Vector2(randf_range(-26.0, 26.0), randf_range(4.0, 18.0))
		at = at.clamp(RECT.position, RECT.end)
		points.append(at)
	return points
