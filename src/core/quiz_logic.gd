class_name QuizLogic
extends RefCounted
## Правила викторины у сгустка ошибки на четвёртом этаже: вопросы по программированию.
##
## Каждый правильный ответ бьёт сгусток; когда набрано нужное число правильных ответов, он
## лопается. Неверный ответ или вышедшее время на вопрос - ошибка; если ошибок больше, чем
## позволено, викторина проиграна. Вопросы берутся из перемешанного набора без повторов,
## варианты ответа тоже перемешиваются. Тексты лежат в text/ru.po: QUIZ_Q<n> - вопрос,
## QUIZ_Q<n>_A - правильный ответ, QUIZ_Q<n>_B..D - неверные.
## Числа по умолчанию - средний уровень; экран подставляет числа выбранного уровня.

signal answered(correct: bool)
signal won
signal lost

const QUESTIONS := 20
const OPTIONS := 4
const LETTERS: Array[String] = ["A", "B", "C", "D"]
const NEEDED := 4
const MISTAKES := 2
const TIME_SEC := 15.0

var needed: int = NEEDED
var mistakes_allowed: int = MISTAKES
var time_per_question: float = TIME_SEC
var hits: int = 0
var mistakes: int = 0
var time_left: float = TIME_SEC

var _order: Array[int] = []
var _next: int = 0
var _question: int = 0
var _slots: Array[int] = []
var _result: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Перемешивает вопросы и задаёт первый.
## [param seed_value] - зерно случайных чисел; тесты задают его, чтобы викторина повторялась.
func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	for index: int in QUESTIONS:
		_order.append(index + 1)
	for index: int in range(_order.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var keep := _order[index]
		_order[index] = _order[other]
		_order[other] = keep
	_ask()


## Возвращает ключи всех текстов викторины: вопросы и варианты.
static func text_keys() -> Array[String]:
	var keys: Array[String] = []
	for number: int in range(1, QUESTIONS + 1):
		keys.append("QUIZ_Q%d" % number)
		for letter: String in LETTERS:
			keys.append("QUIZ_Q%d_%s" % [number, letter])
	return keys


## Задаёт числа уровня сложности.
## [param level] - уровень из [Difficulty]; пустая строка берёт уровень этой игры.
func configure(level: String = "") -> void:
	needed = Difficulty.value("quiz_answers", level)
	mistakes_allowed = Difficulty.value("quiz_mistakes", level)
	time_per_question = Difficulty.value("quiz_time", level)
	time_left = time_per_question


## Возвращает ключ текста текущего вопроса.
func question_key() -> String:
	return "QUIZ_Q%d" % _question


## Возвращает ключ текста варианта в ячейке.
## [param slot] - номер ячейки от 0 до 3.
func option_key(slot: int) -> String:
	return "QUIZ_Q%d_%s" % [_question, LETTERS[_slots[slot]]]


## Возвращает ячейку с правильным ответом; нужно тестам.
func correct_slot() -> int:
	return _slots.find(0)


## Принимает ответ: правильный бьёт сгусток, неверный считается ошибкой.
## [param slot] - выбранная ячейка.
## Возвращает true, если ответ правильный.
func answer(slot: int) -> bool:
	if is_done() or slot < 0 or slot >= OPTIONS:
		return false
	var correct := _slots[slot] == 0
	_score(correct)
	return correct


## Ведёт время на вопрос; вышедшее время считается ошибкой.
## [param delta] - прошедшее время в секундах.
func advance(delta: float) -> void:
	if is_done():
		return
	time_left -= delta
	if time_left <= 0.0:
		_score(false)


## Сообщает, сколько правильных ответов ещё нужно.
func hits_left() -> int:
	return maxi(needed - hits, 0)


## Сообщает, сколько ещё ошибок можно сделать.
func mistakes_left() -> int:
	return maxi(mistakes_allowed - mistakes, 0)


## Сообщает, выиграна ли викторина.
func is_won() -> bool:
	return _result > 0


## Сообщает, закончилась ли викторина.
func is_done() -> bool:
	return _result != 0


## Засчитывает ответ, проверяет конец викторины и задаёт следующий вопрос.
## [param correct] - true, если ответ правильный.
func _score(correct: bool) -> void:
	if correct:
		hits += 1
	else:
		mistakes += 1
	answered.emit(correct)
	if hits >= needed:
		_result = 1
		won.emit()
	elif mistakes > mistakes_allowed:
		_result = -1
		lost.emit()
	else:
		_ask()


## Берёт следующий вопрос и перемешивает его варианты.
func _ask() -> void:
	_question = _order[_next % _order.size()]
	_next += 1
	_slots = [0, 1, 2, 3]
	for index: int in range(OPTIONS - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var keep := _slots[index]
		_slots[index] = _slots[other]
		_slots[other] = keep
	time_left = time_per_question
