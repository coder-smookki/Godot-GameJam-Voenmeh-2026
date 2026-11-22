class_name DrawGame
extends Modal
## Добивание «Нарисуй капибару»: сетка с бледным силуэтом, курсор-кисть, таймер.
##
## Правила считает [DrawLogic]. Стрелки или WASD двигают курсор (при удержании он бежит сам),
## пробел или E закрашивают клетку, а с зажатой кистью курсор красит на ходу. Мышью можно
## водить с зажатой левой кнопкой. Готовая капибара подпрыгивает и вспыхивает.

signal finished

const CELL := 16.0
const TOP := 74.0
const STEP_SEC := 0.075
const FIRST_STEP_SEC := 0.18
const BACKGROUND := Color("0b0f17")
const GHOST := Color(1.0, 1.0, 1.0, 0.22)
const GRID := Color(1.0, 1.0, 1.0, 0.05)
const FUR := Color("9a6534")
const FUR_LIGHT := Color("c98e52")
const MISS := Color(0.85, 0.12, 0.12, 0.8)
const DONE_HOLD_SEC := 1.6
const FAILED_HOLD_SEC := 1.3
const LOW_TIME := 8.0
const KEYS: Dictionary = {
	KEY_LEFT: Vector2i.LEFT,
	KEY_A: Vector2i.LEFT,
	KEY_RIGHT: Vector2i.RIGHT,
	KEY_D: Vector2i.RIGHT,
	KEY_UP: Vector2i.UP,
	KEY_W: Vector2i.UP,
	KEY_DOWN: Vector2i.DOWN,
	KEY_S: Vector2i.DOWN,
}
const BRUSH_KEYS: Array[Key] = [KEY_SPACE, KEY_E, KEY_ENTER]

var _logic: DrawLogic = null
var _clock: float = 0.0
var _held: Vector2i = Vector2i.ZERO
var _repeat: float = 0.0
var _brush: bool = false
var _mouse: bool = false
var _misses: Dictionary = {}
var _bounce: float = 0.0


## Выключает покадровую обработку до начала игры.
func _ready() -> void:
	set_process(false)


## Отсчитывает время, ведёт курсор при удержании стрелки и гасит красные промахи.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	for cell: Vector2i in _misses.keys():
		_misses[cell] -= delta
		if _misses[cell] <= 0.0:
			_misses.erase(cell)
	if _logic != null and not _logic.is_done():
		_logic.advance(delta)
		if _held != Vector2i.ZERO:
			_repeat -= delta
			if _repeat <= 0.0:
				_repeat = STEP_SEC
				_step(_held)
		if _mouse:
			_paint_at_mouse()
	queue_redraw()


## Принимает стрелки, WASD, кисть с клавиатуры и мышь.
## [param event] - событие ввода.
func _input(event: InputEvent) -> void:
	if not visible or _logic == null:
		return
	get_viewport().set_input_as_handled()
	if _logic.is_done():
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		_mouse = mouse.pressed
		if _mouse:
			_paint_at_mouse()
		return
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	var code := key.physical_keycode
	if KEYS.has(code):
		var direction: Vector2i = KEYS[code]
		if key.pressed:
			_held = direction
			_repeat = FIRST_STEP_SEC
			_step(direction)
		elif _held == direction:
			_held = Vector2i.ZERO
	elif code in BRUSH_KEYS:
		_brush = key.pressed
		if _brush:
			_logic.paint(_logic.cursor)


## Проводит рисование до победы или до конца времени.
## Возвращает true, если капибара нарисована вовремя.
func play() -> bool:
	_logic = DrawLogic.new()
	_logic.solved.connect(_on_solved)
	_logic.failed.connect(_on_failed)
	_logic.missed.connect(_on_missed)
	open()
	await finished
	var won := _logic.is_solved()
	close()
	return won


## Сообщает правила текущего рисования; нужно тестам.
func logic() -> DrawLogic:
	return _logic


## Прячет задание и тосты и сбрасывает кисть.
func _opened() -> void:
	Ui.hud.hide()
	Ui.toasts.hide()
	_clock = 0.0
	_held = Vector2i.ZERO
	_brush = false
	_mouse = false
	_misses.clear()
	_bounce = 0.0
	set_process(true)


## Возвращает задание и тосты на экран.
func _closed() -> void:
	set_process(false)
	Ui.hud.show()
	Ui.toasts.show()


## Рисует окно: заголовок, таймер, сетку, силуэт, закрашенные клетки и курсор.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.72))
	if _logic == null:
		return
	var grid := DrawLogic.grid_size()
	var origin := Vector2((size.x - grid.x * CELL) * 0.5, TOP)
	var frame := Rect2(origin - Vector2(14.0, 46.0), Vector2(grid.x * CELL + 28.0, 196.0))
	draw_rect(frame, BACKGROUND)
	draw_rect(frame, Palette.GOAL, false, 1.0)
	var font := Palette.font()
	_text(font, frame.position + Vector2(10.0, 16.0), tr("DRAW_TITLE"), Palette.GOAL)
	var low := _logic.time_left <= LOW_TIME and int(_clock * 4.0) % 2 == 0
	var timer := "0:%02d" % ceili(_logic.time_left)
	var right := frame.end.x - 10.0 - timer.length() * 8.0
	_text(
		font,
		Vector2(right, frame.position.y + 16.0),
		timer,
		Palette.DANGER if low else Palette.TEXT
	)
	var left := tr("DRAW_LEFT").format({"count": _logic.cells_left()})
	_text(font, frame.position + Vector2(10.0, 32.0), left, Palette.NEUTRAL)
	var jump := -absf(sin(_bounce * PI * 3.0)) * 8.0 * (1.0 - _bounce)
	for y: int in grid.y:
		for x: int in grid.x:
			var cell := Vector2i(x, y)
			var box := Rect2(
				origin + Vector2(x, y) * CELL + Vector2(0.0, jump), Vector2(CELL, CELL)
			)
			draw_rect(box.grow(-0.5), GRID, false, 1.0)
			if _logic.is_painted(cell):
				draw_rect(box, FUR_LIGHT if (x + y) % 3 == 0 else FUR)
			elif DrawLogic.in_shape(cell):
				draw_rect(Rect2(box.get_center() - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), GHOST)
			if _misses.has(cell):
				draw_rect(box, Color(MISS, _misses[cell] * 2.0))
	if _logic.is_solved():
		var eye := origin + Vector2(9.0, 2.0) * CELL + Vector2(CELL * 0.5, CELL * 0.5 + jump)
		draw_rect(Rect2(eye - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color.BLACK)
		_text(font, frame.position + Vector2(10.0, 186.0), tr("DRAW_DONE"), Palette.OK)
		return
	if _logic.is_failed():
		_text(font, frame.position + Vector2(10.0, 186.0), tr("DEBUG_TIMEOUT"), Palette.DANGER)
		return
	var cursor := Rect2(origin + Vector2(_logic.cursor) * CELL, Vector2(CELL, CELL))
	var pulse := 0.6 + 0.4 * sin(_clock * 10.0)
	draw_rect(cursor.grow(1.0), Color(Palette.GOAL, pulse), false, 2.0)
	_text(font, frame.position + Vector2(10.0, 186.0), tr("DRAW_HELP"), Palette.NEUTRAL)


## Двигает курсор и, если кисть зажата, красит клетку под ним.
## [param direction] - шаг по сетке.
func _step(direction: Vector2i) -> void:
	_logic.move(direction)
	if _brush:
		_logic.paint(_logic.cursor)


## Ставит курсор под мышь и красит клетку.
func _paint_at_mouse() -> void:
	var grid := DrawLogic.grid_size()
	var origin := Vector2((size.x - grid.x * CELL) * 0.5, TOP)
	var at := get_local_mouse_position() - origin
	var cell := Vector2i(floori(at.x / CELL), floori(at.y / CELL))
	if cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y:
		return
	_logic.cursor = cell
	_logic.paint(cell)


## Рисует строку текста.
## [param font] - шрифт.
## [param at] - точка начала базовой линии.
## [param value] - текст.
## [param color] - цвет.
func _text(font: Font, at: Vector2, value: String, color: Color) -> void:
	draw_string(font, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Palette.FONT_SIZE, color)


## Запоминает промах, чтобы клетка мигнула красным.
## [param cell] - клетка мимо силуэта.
func _on_missed(cell: Vector2i) -> void:
	_misses[cell] = 0.5


## Заставляет готовую капибару подпрыгнуть и через паузу заканчивает игру.
func _on_solved() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_bounce", 1.0, DONE_HOLD_SEC)
	tween.tween_callback(finished.emit)


## Через паузу заканчивает игру поражением.
func _on_failed() -> void:
	var tween := create_tween()
	tween.tween_interval(FAILED_HOLD_SEC)
	tween.tween_callback(finished.emit)
