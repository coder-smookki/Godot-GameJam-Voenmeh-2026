class_name QuizGame
extends Modal
## Викторина по программированию у сгустка ошибки: панель справа, сгусток виден слева.
##
## Сверху здоровье сгустка (сколько правильных ответов осталось) и полоска времени на вопрос,
## ниже вопрос и четыре варианта. Ответ выбирают стрелками и Enter, цифрами 1-4 или мышью.
## После ответа правильный вариант загорается зелёным, неверный выбранный - красным, и через
## мгновение идёт следующий вопрос. Сам сгусток слушает сигнал [signal answered] и реагирует
## в мире. Правила - [QuizLogic].

signal answered(correct: bool)
signal finished

const FEEDBACK_SEC := 0.8
const BUTTON_WIDTH := 204.0
const GOOD := Color("2ea043")
const BAD := Color("d81e1e")
const HP := Color("ff1fb4")
const TIME := Color("ffc62e")

var _logic: QuizLogic = null
var _buttons: Array[Button] = []
var _locked: bool = false
var _pressed: int = -1
var _correct: int = -1

@onready var _meter: Control = $Panel/Box/Meter
@onready var _question: Label = $Panel/Box/Question
@onready var _options: VBoxContainer = $Panel/Box/Options
@onready var _footer: Label = $Panel/Box/Footer


## Создаёт четыре кнопки ответа и подписывает полоски на перерисовку.
func _ready() -> void:
	closable = false
	set_process(false)
	for slot: int in QuizLogic.OPTIONS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(BUTTON_WIDTH, 16.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_choose.bind(slot))
		button.mouse_entered.connect(button.grab_focus)
		_options.add_child(button)
		_buttons.append(button)
	_meter.draw.connect(_draw_meter)


## Проводит викторину до победы или поражения.
## [param seed_value] - зерно случайных чисел; тесты задают его, чтобы викторина повторялась.
## Возвращает true, если сгусток побеждён.
func play(seed_value: int = -1) -> bool:
	_logic = QuizLogic.new(seed_value)
	_logic.configure()
	_logic.answered.connect(_on_answered)
	_locked = false
	open()
	_refresh()
	set_process(true)
	await finished
	set_process(false)
	var won := _logic.is_won()
	close()
	return won


## Возвращает правила текущей викторины; нужно тестам.
func logic() -> QuizLogic:
	return _logic


## Выбирает вариант ответа.
## [param slot] - номер варианта от 0 до 3.
func choose(slot: int) -> void:
	_choose(slot)


## Ведёт время на вопрос и полоски.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if not _locked:
		_logic.advance(delta)
	_meter.queue_redraw()


## Отвечает цифрами 1-4.
## [param event] - событие ввода.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).physical_keycode
	if key >= KEY_1 and key <= KEY_4:
		_choose(key - KEY_1)
		get_viewport().set_input_as_handled()


## Передаёт выбор правилам, если сейчас можно отвечать.
## [param slot] - номер варианта.
func _choose(slot: int) -> void:
	if _locked or _logic == null or _logic.is_done():
		return
	_pressed = slot
	_logic.answer(slot)


## Показывает, верен ли ответ, сообщает о нём сгустку и через мгновение задаёт новый вопрос
## или заканчивает викторину.
## [param correct] - true, если ответ правильный.
func _on_answered(correct: bool) -> void:
	_locked = true
	for slot: int in _buttons.size():
		_buttons[slot].disabled = slot != _correct and slot != _pressed
	_paint(_buttons[_correct], GOOD)
	if _pressed >= 0 and _pressed != _correct:
		_paint(_buttons[_pressed], BAD)
	answered.emit(correct)
	await get_tree().create_timer(FEEDBACK_SEC, true, false, true).timeout
	if _logic.is_done():
		finished.emit()
		return
	_refresh()


## Показывает новый вопрос, варианты с цифрами и сколько ошибок ещё можно.
func _refresh() -> void:
	_locked = false
	_pressed = -1
	_correct = _logic.correct_slot()
	_question.text = tr(_logic.question_key())
	for slot: int in _buttons.size():
		var button := _buttons[slot]
		button.text = "%d. %s" % [slot + 1, tr(_logic.option_key(slot))]
		button.disabled = false
		for state: String in ["font_color", "font_disabled_color", "font_focus_color"]:
			button.remove_theme_color_override(state)
	_buttons[0].grab_focus()
	_footer.text = tr("QUIZ_MISTAKES").format({"left": _logic.mistakes_left()})


## Окрашивает текст кнопки.
## [param button] - кнопка.
## [param color] - цвет.
func _paint(button: Button, color: Color) -> void:
	for state: String in ["font_color", "font_disabled_color", "font_focus_color"]:
		button.add_theme_color_override(state, color)


## Рисует здоровье сгустка ячейками и полоску времени на вопрос.
func _draw_meter() -> void:
	if _logic == null:
		return
	var width := _meter.size.x
	var cells := _logic.needed
	var gap := 3.0
	var cell := (width - gap * (cells - 1)) / cells
	for index: int in cells:
		var box := Rect2(index * (cell + gap), 0.0, cell, 6.0)
		_meter.draw_rect(box, Color(0.2, 0.05, 0.15))
		if index < _logic.hits_left():
			_meter.draw_rect(box, HP)
	var share := clampf(_logic.time_left / _logic.time_per_question, 0.0, 1.0)
	_meter.draw_rect(Rect2(0.0, 9.0, width, 3.0), Color(0.15, 0.15, 0.2))
	var color := TIME if share > 0.3 else BAD
	_meter.draw_rect(Rect2(0.0, 9.0, width * share, 3.0), color)
