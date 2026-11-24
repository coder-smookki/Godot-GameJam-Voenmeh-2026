class_name BossScreen
extends Node2D
## Лицо заражённого Компилятора на мониторе кабинета 202, нарисованное поверх фона.
##
## Экран включается с помехами, глаза моргают и следят за героем, при атаке рот раскрывается,
## от бомбы по экрану идут трещины. Внизу три порта: закрыты, открыты (светятся) и разбиты.
## После победы экран разбит: тёмное стекло с трещинами от удара, выбитые осколки и редкие
## искры; так он выглядит и при следующих визитах. Экран живёт и на паузе, чтобы ожить во время
## разговора с Вальштейном. Прямоугольник экрана (rect) можно задать: так же выглядит
## заражённый телевизор в кабинете 418, у него нет портов.

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

var rect: Rect2 = RECT
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
var _broken: bool = false
var _holes: Array[PackedVector2Array] = []
var _impact: Vector2 = Vector2.ZERO


## Готовит выключенный экран.
func _ready() -> void:
	z_index = -20
	process_mode = Node.PROCESS_MODE_ALWAYS


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


## Сразу включает экран без помех, например когда герой вернулся в комнату до боя.
func power_on() -> void:
	_power = 1.0


## Разбивает экран: тёмное стекло, трещины лучами от места удара и выбитые осколки.
func shatter() -> void:
	_broken = true
	_power = 0.0
	face = Face.IDLE
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	_impact = Vector2(rect.position.x + rect.size.x * 0.58, rect.position.y + rect.size.y * 0.42)
	_crack_lines.clear()
	for ray: int in 11:
		var angle := TAU * ray / 11.0 + rng.randf_range(-0.2, 0.2)
		var points := PackedVector2Array([_impact])
		var at := _impact
		for step: int in 6:
			var reach := rng.randf_range(14.0, 34.0)
			var bend := angle + rng.randf_range(-0.35, 0.35)
			at = (at + Vector2(cos(bend), sin(bend)) * reach).clamp(rect.position, rect.end)
			points.append(at)
		_crack_lines.append(points)
	_holes.clear()
	for hole: int in 5:
		var center := _impact + Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-30.0, 30.0))
		var size := rng.randf_range(6.0, 14.0)
		(
			_holes
			. append(
				PackedVector2Array(
					[
						center + Vector2(-size, -size * 0.4),
						center + Vector2(size * 0.7, -size),
						center + Vector2(size, size * 0.6),
					]
				)
			)
		)


## Сообщает, разбит ли экран.
func is_broken() -> bool:
	return _broken


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
	if _broken:
		_draw_broken()
		return
	if _power <= 0.0:
		return
	var alpha := _power
	draw_rect(rect, Color(BACK, alpha))
	var center := rect.get_center() + Vector2(0.0, -12.0)
	if _glitch > 0.0:
		center.x += randf_range(-6.0, 6.0) * _glitch
	if face == Face.TEXT:
		_draw_text(center, alpha)
	else:
		_draw_face(center, alpha)
	_draw_ports(alpha)
	for line: PackedVector2Array in _crack_lines:
		draw_polyline(line, Color(CRACK, alpha), 1.0)
	for y: int in range(int(rect.position.y), int(rect.end.y), 3):
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(SCAN, SCAN.a * alpha))
	if _glitch > 0.0:
		for band: int in 3:
			var y := randf_range(rect.position.y, rect.end.y - 6.0)
			var shift := randf_range(-14.0, 14.0)
			var strip := Rect2(
				rect.position.x + maxf(shift, 0.0), y, rect.size.x - absf(shift), 4.0
			)
			draw_rect(strip, Color(EYE, 0.25 * alpha))


## Рисует разбитый экран: тёмное стекло, трещины, дыры и искру, которая иногда проскакивает.
func _draw_broken() -> void:
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55))
	for hole: PackedVector2Array in _holes:
		draw_colored_polygon(hole, Color(0.0, 0.0, 0.0, 0.95))
		draw_polyline(hole + PackedVector2Array([hole[0]]), CRACK, 1.0)
	for line: PackedVector2Array in _crack_lines:
		draw_polyline(line, CRACK, 1.0)
	draw_circle(_impact, 5.0, Color(CRACK, 0.9))
	if fmod(_clock, 2.7) < 0.12:
		var spark := _impact + Vector2(randf_range(-40.0, 40.0), randf_range(-20.0, 20.0))
		draw_rect(Rect2(spark, Vector2(3.0, 3.0)), Color("ffe066"))
		draw_rect(Rect2(spark + Vector2(4.0, -3.0), Vector2(2.0, 2.0)), Color.WHITE)


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
		var x := rect.get_center().x + (index - 1) * 120.0 - PORT_SIZE.x * 0.5
		var box := Rect2(Vector2(x, rect.end.y - PORT_SIZE.y - 8.0), PORT_SIZE)
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
		randf_range(rect.position.x + 40.0, rect.end.x - 40.0),
		randf_range(rect.position.y + 10.0, rect.end.y - 30.0)
	)
	points.append(at)
	for step: int in 6:
		at += Vector2(randf_range(-26.0, 26.0), randf_range(4.0, 18.0))
		at = at.clamp(rect.position, rect.end)
		points.append(at)
	return points
