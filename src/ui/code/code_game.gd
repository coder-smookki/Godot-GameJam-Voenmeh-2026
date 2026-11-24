class_name CodeGame
extends Modal
## Экран боя в кабинете 418: программа с пропуском прямо на стекле телевизора.
##
## Сверху номер задачи, условие и время, ниже программа: пропуск подсвечен и заполняется
## тем, что игрок печатает в строке ввода. Enter «компилирует и запускает» программу:
## верный ответ печатает нужный вывод зелёным, неверный - красную ошибку и штраф времени.
## Всё рисуется в коде в прямоугольнике стекла, который передаёт бой; поверх бегут строки
## развёртки и помехи. Правила - [CodeLogic].

signal answered(correct: bool)
signal finished

const LINE := 12.0
const PAD := 8.0
const BACK := Color(0.02, 0.05, 0.03)
const CODE := Color("c8f7c5")
const DIM := Color("6f8f73")
const GOAL := Color("ffc62e")
const GOOD := Color("2ee05a")
const BAD := Color("ff3b3b")
const BLANK_BACK := Color(1.0, 0.12, 0.7, 0.35)
const RESULT_SEC := 1.1
const SHAKE_SEC := 0.3

var _logic: CodeLogic = null
var _screen: Rect2 = Rect2(30.0, 68.0, 420.0, 134.0)
var _input: LineEdit = null
var _result: String = ""
var _result_good: bool = false
var _busy: bool = false
var _clock: float = 0.0
var _shake: float = 0.0


## Создаёт строку ввода без рамок, зелёным моноширинным текстом.
func _ready() -> void:
	closable = false
	set_process(false)
	_input = LineEdit.new()
	_input.flat = true
	_input.max_length = 40
	_input.context_menu_enabled = false
	_input.add_theme_color_override("font_color", CODE)
	_input.add_theme_color_override("caret_color", GOOD)
	_input.add_theme_font_size_override("font_size", Palette.FONT_SIZE)
	_input.text_changed.connect(_on_text_changed)
	_input.text_submitted.connect(submit)
	add_child(_input)


## Проводит бой до победы или поражения.
## [param screen] - прямоугольник стекла телевизора на экране.
## [param seed_value] - зерно случайных чисел; тесты задают его, чтобы бой повторялся.
## Возвращает true, если решено нужное число задач.
func play(screen: Rect2, seed_value: int = -1) -> bool:
	_screen = screen
	_logic = CodeLogic.new(seed_value)
	_logic.configure()
	_logic.penalized.connect(_on_penalized)
	_result = ""
	_busy = false
	_input.position = Vector2(_screen.position.x + PAD + 16.0, _input_y() - 10.0)
	_input.size = Vector2(_screen.size.x - PAD * 2.0 - 16.0, 14.0)
	open()
	_next_task()
	set_process(true)
	await finished
	set_process(false)
	var won := _logic.is_won()
	close()
	return won


## Возвращает правила текущего боя; нужно тестам.
func logic() -> CodeLogic:
	return _logic


## Отправляет ответ: «компилирует» программу и показывает вывод или ошибку.
## [param text] - то, что вписано в пропуск.
func submit(text: String) -> void:
	if _busy or _logic == null or _logic.is_done():
		return
	var output := _logic.output()
	var correct := _logic.submit(text)
	_result_good = correct
	_result = output if correct else tr("CODE_WRONG")
	answered.emit(correct)
	if not correct:
		_shake = SHAKE_SEC
		return
	_busy = true
	_input.editable = false
	await get_tree().create_timer(RESULT_SEC, true, false, true).timeout
	if _logic.is_done():
		finished.emit()
		return
	_next_task()


## Ведёт время задачи, помехи и тряску.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	_shake = maxf(_shake - delta, 0.0)
	if not _busy:
		_logic.advance(delta)
		if _logic.is_done() and not _logic.is_won():
			_busy = true
			_result = tr("CODE_TIME_UP")
			_result_good = false
			_input.editable = false
			await get_tree().create_timer(RESULT_SEC, true, false, true).timeout
			finished.emit()
	queue_redraw()


## Рисует стекло, условие, время, программу с пропуском, строку ввода и вывод.
func _draw() -> void:
	if _logic == null:
		return
	var font := Palette.font()
	var shift := Vector2(randf_range(-2.0, 2.0) * _shake / SHAKE_SEC, 0.0)
	var box := Rect2(_screen.position + shift, _screen.size)
	draw_rect(box, BACK)
	var x := box.position.x + PAD
	var y := box.position.y + PAD + 8.0
	var head := tr("CODE_HEAD").format({"n": _logic.solved + 1, "total": _logic.needed})
	_line(font, Vector2(x, y), head, DIM)
	var seconds := ceili(_logic.time_left)
	var timer := "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
	var low := _logic.time_left < 10.0 and int(_clock * 4.0) % 2 == 0
	var timer_x := box.end.x - PAD - font.get_string_size(timer, 0, -1.0, Palette.FONT_SIZE).x
	_line(font, Vector2(timer_x, y), timer, BAD if low else GOAL)
	y += LINE
	_line(font, Vector2(x, y), tr(_logic.goal_key()), GOAL)
	y += LINE + 2.0
	var typed := _input.text if not _input.text.is_empty() else CodeLogic.BLANK
	for source: String in _logic.code():
		var at := source.find(CodeLogic.BLANK)
		if at < 0:
			_line(font, Vector2(x, y), source, CODE)
		else:
			var before := source.left(at)
			var after := source.substr(at + CodeLogic.BLANK.length())
			var left := font.get_string_size(before, 0, -1.0, Palette.FONT_SIZE).x
			var width := font.get_string_size(typed, 0, -1.0, Palette.FONT_SIZE).x
			var pulse := 0.6 + 0.4 * sin(_clock * 6.0)
			draw_rect(
				Rect2(x + left - 1.0, y - 9.0, width + 2.0, 11.0), Color(BLANK_BACK, pulse * 0.6)
			)
			_line(font, Vector2(x, y), before, CODE)
			_line(font, Vector2(x + left, y), typed, Color.WHITE)
			_line(font, Vector2(x + left + width, y), after, CODE)
		y += LINE
	_line(font, Vector2(x, _input_y()), ">", GOOD)
	if not _result.is_empty():
		var run := "$ gcc task.c && ./a.out"
		if not _logic.stdin().is_empty():
			run += " <<< " + _logic.stdin()
		_line(font, Vector2(x, box.end.y - PAD - LINE), run, DIM)
		_line(font, Vector2(x, box.end.y - PAD), _result, GOOD if _result_good else BAD)
	else:
		_line(font, Vector2(x, box.end.y - PAD), tr("CODE_HINT"), DIM)
	for row: int in range(int(box.position.y), int(box.end.y), 3):
		draw_line(Vector2(box.position.x, row), Vector2(box.end.x, row), Color(0, 0, 0, 0.18))


## Готовит следующую задачу: пустая строка ввода с фокусом.
func _next_task() -> void:
	_busy = false
	_result = ""
	_input.text = ""
	_input.editable = true
	_input.grab_focus()


## Возвращает базовую линию строки ввода.
func _input_y() -> float:
	return _screen.end.y - PAD - LINE * 2.0 - 4.0


## Рисует одну строку текста.
## [param font] - шрифт.
## [param at] - начало базовой линии.
## [param text] - строка.
## [param color] - цвет.
func _line(font: Font, at: Vector2, text: String, color: Color) -> void:
	draw_string(font, at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Palette.FONT_SIZE, color)


## Убирает прошлый вывод, когда игрок снова печатает.
## [param _text] - новый текст строки ввода.
func _on_text_changed(_text: String) -> void:
	if not _busy:
		_result = ""


## Трясёт стекло при штрафе.
## [param _seconds] - сколько времени отнято.
func _on_penalized(_seconds: float) -> void:
	_shake = SHAKE_SEC
