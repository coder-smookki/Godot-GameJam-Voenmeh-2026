class_name ChoiceScreen
extends Modal
## Последний выбор на терминале крыши: удалить ЛАБУ или исправить её.
##
## Экран терминала рисуется в коде: зелёная консоль, мигающий курсор, две команды. Команда
## исправления закрыта, пока не найдено достаточно посланий ЛАБЫ; под ней написано, чего не
## хватает. Выбор стрелками и Enter, клавишами 1 и 2 или мышью. После выбора команда
## печатается в консоли, и экран закрывается.

signal chosen(terminal: String)

const PANEL := Rect2(70.0, 50.0, 340.0, 170.0)
const GREEN := Color("2ee05a")
const DIM := Color("6f8f73")
const BACK := Color(0.01, 0.04, 0.02, 0.96)
const TYPE_SEC := 0.04
const OPTIONS: Array[String] = ["delete", "fix"]

var _focus: int = 0
var _typed: String = ""
var _busy: bool = false
var _clock: float = 0.0


## Готовит экран: закрыть его без выбора нельзя.
func _ready() -> void:
	closable = false
	set_process(false)


## Показывает выбор и ждёт его.
## Возвращает "delete" или "fix".
func ask() -> String:
	_focus = 0
	_typed = ""
	_busy = false
	open()
	set_process(true)
	var terminal: String = await chosen
	set_process(false)
	close()
	return terminal


## Выбирает команду; закрытую выбрать нельзя.
## [param index] - 0 удалить, 1 исправить.
func pick(index: int) -> void:
	if _busy or index < 0 or index >= OPTIONS.size() or not _available(index):
		return
	_busy = true
	_focus = index
	var command := tr("CHOICE_COMMAND_%s" % OPTIONS[index].to_upper())
	for length: int in command.length() + 1:
		_typed = command.left(length)
		await get_tree().create_timer(TYPE_SEC, true, false, true).timeout
	await get_tree().create_timer(0.6, true, false, true).timeout
	chosen.emit(OPTIONS[index])


## Сообщает, открыта ли команда.
## [param index] - номер команды.
func _available(index: int) -> bool:
	return not World.ending(OPTIONS[index]).is_empty()


## Двигает выбор стрелками, выбирает Enter и цифрами.
## [param event] - событие ввода.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _busy:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_focus = 0
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_focus = 1
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		pick(_focus)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_1 or key == KEY_2:
			pick(key - KEY_1)
		else:
			return
	elif event is InputEventMouseButton and event.pressed:
		var row := _row_at((event as InputEventMouseButton).position)
		if row >= 0:
			pick(row)
		return
	else:
		return
	get_viewport().set_input_as_handled()


## Мигает курсором.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## Рисует консоль, вопрос, две команды и печатаемую команду.
func _draw() -> void:
	var font := Palette.font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.5))
	draw_rect(PANEL.grow(3.0), Color("2b3142"))
	draw_rect(PANEL, BACK)
	var x := PANEL.position.x + 10.0
	var y := PANEL.position.y + 18.0
	_line(font, Vector2(x, y), "laba@roof:~$", DIM)
	y += 16.0
	_line(font, Vector2(x, y), tr("CHOICE_TITLE"), Palette.GOAL)
	y += 24.0
	for index: int in OPTIONS.size():
		var open := _available(index)
		var focused := index == _focus
		var color := GREEN if open else DIM
		if focused and open:
			draw_rect(Rect2(x - 4.0, y - 11.0, PANEL.size.x - 12.0, 16.0), Color(GREEN, 0.15))
		var mark := "> " if focused else "  "
		var text := "%s%d. %s" % [mark, index + 1, tr("CHOICE_%s" % OPTIONS[index].to_upper())]
		_line(font, Vector2(x, y), text, color)
		y += 14.0
		var note_key := "CHOICE_%s_NOTE" % OPTIONS[index].to_upper()
		if not open:
			note_key = "CHOICE_FIX_LOCKED"
		_line(font, Vector2(x + 16.0, y), tr(note_key).format(World.f), DIM)
		y += 22.0
	var cursor := "_" if int(_clock * 2.0) % 2 == 0 else " "
	_line(font, Vector2(x, PANEL.end.y - 12.0), "$ " + _typed + cursor, GREEN)
	for row: int in range(int(PANEL.position.y), int(PANEL.end.y), 3):
		draw_line(Vector2(PANEL.position.x, row), Vector2(PANEL.end.x, row), Color(0, 0, 0, 0.2))


## Находит команду под курсором мыши.
## [param at] - точка на экране.
## Возвращает номер команды или -1.
func _row_at(at: Vector2) -> int:
	for index: int in OPTIONS.size():
		var top := PANEL.position.y + 47.0 + index * 36.0
		if Rect2(PANEL.position.x, top, PANEL.size.x, 30.0).has_point(at):
			return index
	return -1


## Рисует строку.
## [param font] - шрифт.
## [param at] - начало базовой линии.
## [param text] - строка.
## [param color] - цвет.
func _line(font: Font, at: Vector2, text: String, color: Color) -> void:
	draw_string(font, at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Palette.FONT_SIZE, color)
