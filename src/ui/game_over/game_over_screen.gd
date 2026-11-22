class_name GameOverScreen
extends Modal
## Заставка проигрыша: сердца кончились, шахматка заливает экран, ЛАБА перезапускает эксперимент.
##
## Клетки вируса появляются по экрану в случайном порядке, потом падает заголовок, под ним
## три разбитых сердца, а ЛАБА печатает строку о перезапуске. После этого любая клавиша
## (или пауза в несколько секунд) заканчивает заставку, и игра начинается заново.

signal finished

const CELL := 15.0
const FILL_SEC := 1.3
const TITLE_AT := 1.35
const TYPE_AT := 1.9
const TYPE_SEC := 1.3
const HINT_AT := 3.5
const AUTO_SEC := 7.0
const SLAM_FROM := 2.6
const SLAM_SEC := 0.25
const FLASH_SEC := 0.35
const PINK := Color(1.0, 0.0, 1.0)
const DARK := Color(0.0, 0.07, 0.0)
const SHADE := Color(0.02, 0.02, 0.05, 0.86)
const BROKEN := Color("b3243c")
const HEART_SCALE := 3.0
const HEARTS_Y := 150.0
const GLITCH_CHANCE := 0.08

var _order: Array[int] = []
var _clock: float = 0.0
var _done: bool = true
var _columns: int = 0
var _rows: int = 0

@onready var _title: Label = $Title
@onready var _text: Label = $Text
@onready var _hint: Label = $Hint
@onready var _flash: ColorRect = $Flash


## Выключает покадровую обработку до начала заставки.
func _ready() -> void:
	set_process(false)


## Показывает заставку и ждёт, пока игрок её не закончит.
func play() -> void:
	open()
	await finished


## Заканчивает заставку; вызывается клавишей, по таймеру и из тестов.
func skip() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	finished.emit()


## Сообщает, можно ли уже закончить заставку клавишей.
func can_skip() -> bool:
	return not _done and _clock >= HINT_AT


## Готовит пустой экран, перемешивает клетки и прячет интерфейс комнаты.
func _opened() -> void:
	Ui.hud.hide()
	Ui.toasts.hide()
	_columns = ceili(size.x / CELL)
	_rows = ceili(size.y / CELL)
	_order.clear()
	for index: int in _columns * _rows:
		_order.append(index)
	_order.shuffle()
	_clock = 0.0
	_done = false
	_title.hide()
	_text.visible_ratio = 0.0
	_hint.hide()
	_flash.color.a = 0.0
	set_process(true)
	queue_redraw()


## Возвращает интерфейс комнаты.
func _closed() -> void:
	set_process(false)
	Ui.hud.show()
	Ui.toasts.show()


## Ведёт заставку по времени: клетки, заголовок, текст ЛАБЫ, подсказка, автоматический конец.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	if _clock >= TITLE_AT and not _title.visible:
		_slam_title()
	if _title.visible:
		_title.position.x = (
			_title_x() + (randf_range(-3.0, 3.0) if randf() < GLITCH_CHANCE else 0.0)
		)
	_text.visible_ratio = clampf((_clock - TYPE_AT) / TYPE_SEC, 0.0, 1.0)
	_hint.visible = _clock >= HINT_AT and int(_clock * 2.0) % 2 == 0
	if _clock >= AUTO_SEC:
		skip()
	queue_redraw()


## Заканчивает заставку по любой клавише или щелчку, когда показана подсказка.
## [param event] - событие ввода.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	var pressed := (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed()
	if pressed and can_skip():
		skip()


## Рисует тёмную подложку, клетки шахматки и разбитые сердца.
func _draw() -> void:
	var fill := clampf(_clock / FILL_SEC, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(SHADE, SHADE.a * fill))
	var count := int(_order.size() * fill)
	for step: int in count:
		var index := _order[step]
		var column := index % _columns
		var row := floori(index / float(_columns))
		var color := PINK if (column + row) % 2 == 0 else DARK
		color.a = 0.55
		draw_rect(Rect2(Vector2(column, row) * CELL, Vector2(CELL, CELL)), color)
	if _clock < TITLE_AT:
		return
	var width := Hearts.WIDTH * HEART_SCALE
	var total := int(World.SCHEMA[Game.HEARTS]["max"])
	var left := (size.x - total * (width + HEART_SCALE * 4.0)) * 0.5
	draw_set_transform(Vector2(left, HEARTS_Y), 0.0, Vector2(HEART_SCALE, HEART_SCALE))
	var split := clampf((_clock - TITLE_AT) * 3.0, 0.0, 1.0) * 2.0
	for index: int in total:
		var at := Vector2(index * (Hearts.WIDTH + 4.0), 0.0)
		Hearts.draw_heart(self, at + Vector2(-split, split * 0.5), BROKEN, -1)
		Hearts.draw_heart(self, at + Vector2(split, split * 0.5), BROKEN, 1)
	draw_set_transform(Vector2.ZERO)


## Роняет заголовок на экран с белой вспышкой.
func _slam_title() -> void:
	_title.show()
	_title.reset_size()
	_title.position.x = _title_x()
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2(SLAM_FROM, SLAM_FROM)
	var slam := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_property(_title, "scale", Vector2.ONE, SLAM_SEC)
	_flash.color = Color(Palette.DANGER, 0.7)
	create_tween().tween_property(_flash, "color:a", 0.0, FLASH_SEC)


## Возвращает левый край заголовка, при котором он стоит посередине экрана.
func _title_x() -> float:
	return (size.x - _title.size.x) * 0.5
