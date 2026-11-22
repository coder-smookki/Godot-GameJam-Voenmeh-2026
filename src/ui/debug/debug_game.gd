class_name DebugGame
extends Modal
## Мини-игра «Отладчик»: окно терминала с кодом на C, таймер и выбор исправления.
##
## Правила считает [DebugLogic], экран рисует код, курсор, таймер и варианты, принимает
## стрелки (или W и S), E или Enter для выбора и Esc для возврата к коду. Ошибка трясёт окно
## и отнимает секунды. После победы программа компилируется и печатает послание ЛАБЫ.

signal finished

const WINDOW := Rect2(20.0, 14.0, 440.0, 242.0)
const CODE_TOP := 44.0
const LINE_HEIGHT := 12.0
const NUMBER_X := 30.0
const CODE_X := 52.0
const MESSAGE_Y := 166.0
const CHOICES_TOP := 182.0
const CHOICE_HEIGHT := 14.0
const HELP_Y := 244.0
const BACKGROUND := Color("0b0f17")
const BORDER := Palette.DEBUGGER
const CODE := Color("c9d4e6")
const NUMBER := Color("4a5570")
const CURSOR := Color(0.0, 0.76, 0.88, 0.22)
const WRONG := Color(0.85, 0.12, 0.12, 0.45)
const RIGHT := Color(0.18, 0.63, 0.26, 0.5)
const OPEN_SEC := 0.18
const SHAKE_SEC := 0.3
const SHAKE := 5.0
const MARK_SEC := 0.45
const OUTPUT_SEC := 1.0
const SOLVED_HOLD_SEC := 2.4
const FAILED_HOLD_SEC := 1.4
const LOW_TIME := 10.0

var _logic: DebugLogic = null
var _offset: Vector2 = Vector2.ZERO
var _open: float = 1.0
var _mark_line: int = -1
var _mark_color: Color = Color.TRANSPARENT
var _penalty: String = ""
var _output: float = 0.0
var _clock: float = 0.0


## Выключает покадровую обработку до начала игры.
func _ready() -> void:
	set_process(false)


## Отсчитывает время и перерисовывает окно, пока идёт отладка.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	if _logic != null and not _logic.is_done():
		_logic.advance(delta)
	queue_redraw()


## Принимает стрелки, W и S, E и Enter, Esc и щелчки мышью.
## [param event] - событие ввода.
func _input(event: InputEvent) -> void:
	if not visible or _logic == null or _logic.is_done():
		return
	if event is InputEventMouseButton:
		_on_click(event)
		return
	if not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	var code := key.physical_keycode if key != null else KEY_NONE
	if event.is_action_pressed("ui_up") or event.is_action_pressed("enter"):
		_logic.move(-1)
	elif event.is_action_pressed("ui_down") or code == KEY_S:
		_logic.move(1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		choose()
	elif event.is_action_pressed("ui_cancel"):
		_logic.cancel()
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()


## Проводит отладку до победы или до конца времени.
## [param seed_value] - зерно случайных чисел; тесты задают его, чтобы игра повторялась.
## [param index] - номер программы; -1 выбирает случайную.
## Возвращает true, если код исправлен вовремя.
func play(seed_value: int = -1, index: int = -1) -> bool:
	_logic = DebugLogic.new(seed_value, index)
	_logic.penalized.connect(_on_penalized)
	_logic.solved.connect(_on_solved)
	_logic.failed.connect(_on_failed)
	open()
	await finished
	var won := _logic.is_solved()
	close()
	return won


## Сообщает правила текущей отладки; нужно тестам и меню разработчика.
## Возвращает правила или null вне игры.
func logic() -> DebugLogic:
	return _logic


## Выбирает строку или исправление под курсором и показывает, верно ли.
func choose() -> void:
	if _logic == null or _logic.is_done():
		return
	var line := _logic.cursor
	var picking := _logic.picking
	if _logic.select() and not picking:
		_mark(line, CURSOR)
	elif not _logic.is_done() and not picking:
		_mark(line, WRONG)
	queue_redraw()


## Разворачивает окно как старый монитор и прячет задание и тосты.
func _opened() -> void:
	Ui.hud.hide()
	Ui.toasts.hide()
	_clock = 0.0
	_output = 0.0
	_penalty = ""
	_mark_line = -1
	_offset = Vector2.ZERO
	_open = 0.0
	create_tween().tween_property(self, "_open", 1.0, OPEN_SEC)
	set_process(true)


## Возвращает задание и тосты на экран.
func _closed() -> void:
	set_process(false)
	Ui.hud.show()
	Ui.toasts.show()


## Рисует окно терминала: заголовок, таймер, код, сообщение компилятора и варианты.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.7))
	if _logic == null:
		return
	var window := WINDOW
	window.position += _offset
	window.size.y = WINDOW.size.y * _open
	window.position.y += (WINDOW.size.y - window.size.y) * 0.5
	draw_rect(window, BACKGROUND)
	draw_rect(window, BORDER, false, 1.0)
	if _open < 1.0:
		return
	var font := Palette.font()
	var origin := _offset
	_text(font, origin + Vector2(30.0, 30.0), tr("DEBUG_TITLE"), BORDER)
	var timer := "0:%02d" % ceili(_logic.time_left)
	var low := _logic.time_left <= LOW_TIME and int(_clock * 4.0) % 2 == 0
	_text(font, origin + Vector2(430.0 - timer.length() * 8.0, 30.0), timer, _timer_color(low))
	if not _penalty.is_empty():
		_text(font, origin + Vector2(356.0, 30.0), _penalty, Palette.DANGER)
	draw_line(origin + Vector2(24.0, 36.0), origin + Vector2(456.0, 36.0), NUMBER)
	_draw_code(font, origin)
	_draw_bottom(font, origin)


## Рисует строки кода с номерами, курсор и подсветку только что выбранной строки.
## [param font] - шрифт окна.
## [param origin] - сдвиг окна при тряске.
func _draw_code(font: Font, origin: Vector2) -> void:
	for index: int in _logic.lines.size():
		var top := origin.y + CODE_TOP + index * LINE_HEIGHT
		var bar := Rect2(origin.x + 26.0, top - 2.0, 428.0, LINE_HEIGHT)
		if index == _mark_line:
			draw_rect(bar, _mark_color)
		elif not _logic.picking and not _logic.is_done() and index == _logic.cursor:
			draw_rect(bar, CURSOR)
		var number := Vector2(origin.x + NUMBER_X, top + 7.0)
		_text(font, number, "%d" % (index + 1), NUMBER)
		_text(font, Vector2(origin.x + CODE_X, top + 7.0), _logic.lines[index], CODE)


## Рисует низ окна: подсказку компилятора, варианты исправления или вывод программы.
## [param font] - шрифт окна.
## [param origin] - сдвиг окна при тряске.
func _draw_bottom(font: Font, origin: Vector2) -> void:
	draw_line(origin + Vector2(24.0, 156.0), origin + Vector2(456.0, 156.0), NUMBER)
	if _logic.is_solved():
		_text(font, origin + Vector2(30.0, MESSAGE_Y), tr("DEBUG_RUN"), NUMBER)
		var shown := DebugLogic.OUTPUT.left(int(DebugLogic.OUTPUT.length() * _output))
		_text(font, origin + Vector2(30.0, CHOICES_TOP + 4.0), shown, Palette.VIRUS)
		if _output >= 1.0:
			_text(font, origin + Vector2(30.0, CHOICES_TOP + 24.0), tr("DEBUG_SOLVED"), Palette.OK)
		return
	if _logic.is_failed():
		_text(font, origin + Vector2(30.0, MESSAGE_Y), tr("DEBUG_TIMEOUT"), Palette.DANGER)
		return
	_text(font, origin + Vector2(30.0, MESSAGE_Y), tr(_logic.puzzle["hint"]), Palette.DANGER)
	if _logic.picking:
		var ask := tr("DEBUG_ASK").format({"line": _logic.bug_line() + 1})
		_text(font, origin + Vector2(30.0, CHOICES_TOP), ask, Palette.GOAL)
		for index: int in _logic.choices.size():
			var top := origin.y + CHOICES_TOP + 6.0 + index * CHOICE_HEIGHT
			if index == _logic.cursor:
				draw_rect(Rect2(origin.x + 26.0, top, 428.0, CHOICE_HEIGHT - 2.0), CURSOR)
			var line: String = _logic.choices[index].strip_edges()
			_text(font, Vector2(origin.x + 34.0, top + 9.0), line, CODE)
	var help := "DEBUG_HELP_FIX" if _logic.picking else "DEBUG_HELP_FIND"
	_text(font, origin + Vector2(30.0, HELP_Y), tr(help), NUMBER)


## Рисует строку текста.
## [param font] - шрифт.
## [param at] - точка начала базовой линии.
## [param value] - текст.
## [param color] - цвет.
func _text(font: Font, at: Vector2, value: String, color: Color) -> void:
	draw_string(font, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Palette.FONT_SIZE, color)


## Выбирает цвет таймера: жёлтый, а в последние секунды мигающий красный.
## [param low] - true, если сейчас красная фаза мигания.
func _timer_color(low: bool) -> Color:
	return Palette.DANGER if low else Palette.GOAL


## Подсвечивает строку кода цветом и гасит подсветку.
## [param line] - номер строки.
## [param color] - цвет подсветки.
func _mark(line: int, color: Color) -> void:
	_mark_line = line
	_mark_color = color
	var tween := create_tween()
	tween.tween_interval(MARK_SEC)
	tween.tween_callback(_unmark.bind(line))


## Снимает подсветку строки, если она ещё не сменилась другой.
## [param line] - номер строки, подсветку которой нужно снять.
func _unmark(line: int) -> void:
	if _mark_line == line:
		_mark_line = -1


## Трясёт окно и пишет у таймера, сколько секунд отнято.
## [param seconds] - сколько секунд отнято за ошибку.
func _on_penalized(seconds: float) -> void:
	_penalty = "-%d" % int(seconds)
	var tween := create_tween()
	tween.tween_method(_shake, SHAKE, 0.0, SHAKE_SEC)
	tween.tween_callback(_set_penalty.bind(""))


## Сдвигает окно на случайную величину.
## [param strength] - наибольший сдвиг в пикселях.
func _shake(strength: float) -> void:
	_offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength) * 0.5)
	_offset = _offset.round()


## Запоминает надпись о штрафе.
## [param value] - текст; пустая строка убирает надпись.
func _set_penalty(value: String) -> void:
	_penalty = value


## Подсвечивает исправленную строку, печатает вывод программы и через паузу заканчивает игру.
func _on_solved() -> void:
	_mark(_logic.bug_line(), RIGHT)
	var tween := create_tween()
	tween.tween_property(self, "_output", 1.0, OUTPUT_SEC).set_delay(0.3)
	tween.tween_interval(SOLVED_HOLD_SEC - OUTPUT_SEC)
	tween.tween_callback(finished.emit)


## Трясёт окно и через паузу заканчивает игру поражением.
func _on_failed() -> void:
	var tween := create_tween()
	tween.tween_method(_shake, SHAKE * 1.6, 0.0, SHAKE_SEC * 2.0)
	tween.tween_interval(FAILED_HOLD_SEC)
	tween.tween_callback(finished.emit)


## Ставит курсор на строку или вариант под мышью и выбирает его щелчком.
## [param event] - нажатие кнопки мыши.
func _on_click(event: InputEventMouseButton) -> void:
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	var at := get_local_mouse_position() - _offset
	var index := -1
	if _logic.picking:
		index = floori((at.y - CHOICES_TOP - 6.0) / CHOICE_HEIGHT)
	else:
		index = floori((at.y - CODE_TOP + 2.0) / LINE_HEIGHT)
	var count := _logic.choices.size() if _logic.picking else _logic.lines.size()
	if index < 0 or index >= count:
		return
	_logic.point(index)
	choose()
