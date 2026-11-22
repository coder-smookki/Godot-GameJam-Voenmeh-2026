class_name DebugLogic
extends RefCounted
## Правила мини-игры «Отладчик»: в коротком коде на C одна строка с ошибкой. Её нужно найти
## и выбрать правильное исправление, пока не кончилось время.
##
## Неверно указанная строка и неверное исправление отнимают секунды. Время вышло - отладка
## провалена. Исправленная программа печатает первое послание ЛАБЫ. Код программ лежит здесь,
## а не в переводе: это текст программы, его не переводят.

signal solved
signal failed
signal penalized(seconds: float)

const TIME_SEC := 45.0
const WRONG_LINE_SEC := 3.0
const WRONG_FIX_SEC := 6.0
const OUTPUT := "Я только учусь"
const PUZZLES: Array[Dictionary] = [
	{
		"lines":
		[
			"#include <stdio.h>",
			"",
			"int main(void) {",
			'    char *msg = "Я только учусь"',
			'    printf("%s\\n", msg);',
			"    return 0;",
			"}",
		],
		"bug": 3,
		"fixes":
		[
			'    char *msg = "Я только учусь";',
			'    char msg = "Я только учусь";',
			'    char *msg == "Я только учусь";',
		],
		"hint": "DEBUG_HINT_SEMICOLON",
	},
	{
		"lines":
		[
			"#include <stdio.h>",
			"",
			"int main(void) {",
			"    int errors = 0;",
			"    if (errors = 1)",
			"        return 1;",
			'    puts("Я только учусь");',
			"    return 0;",
			"}",
		],
		"bug": 4,
		"fixes": ["    if (errors == 1)", "    if (errors =! 1)", "    if (errors := 1)"],
		"hint": "DEBUG_HINT_ASSIGN",
	},
	{
		"lines":
		[
			"#include <stdio.h>",
			"",
			"int main(void) {",
			'    const char *msg = "Я только учусь";',
			'    printf("%d\\n", msg);',
			"    return 0;",
			"}",
		],
		"bug": 4,
		"fixes":
		[
			'    printf("%s\\n", msg);',
			'    printf("%c\\n", msg);',
			'    printf("%f\\n", msg);',
		],
		"hint": "DEBUG_HINT_FORMAT",
	},
	{
		"lines":
		[
			"#include <stdio.h>",
			"",
			"int main(void) {",
			'    const char *w[3] = {"Я", "только", "учусь"};',
			"    for (int i = 0; i <= 3; i++)",
			'        printf("%s ", w[i]);',
			"    return 0;",
			"}",
		],
		"bug": 4,
		"fixes":
		[
			"    for (int i = 0; i < 3; i++)",
			"    for (int i = 1; i <= 3; i++)",
			"    for (int i = 0; i <= 3; i--)",
		],
		"hint": "DEBUG_HINT_BOUNDS",
	},
]

var puzzle: Dictionary = {}
var lines: Array[String] = []
var choices: Array[String] = []
var cursor: int = 0
var picking: bool = false
var time_left: float = TIME_SEC

var _answer: int = 0
var _result: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Выбирает программу и перемешивает варианты исправления.
## [param seed_value] - зерно случайных чисел; тесты задают его, чтобы игра повторялась.
## [param index] - номер программы из [constant PUZZLES]; -1 выбирает случайную.
func _init(seed_value: int = -1, index: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	if index < 0:
		index = _rng.randi_range(0, PUZZLES.size() - 1)
	puzzle = PUZZLES[index]
	lines.assign(puzzle["lines"])
	var fixes: Array = puzzle["fixes"]
	var order: Array[int] = []
	for option: int in fixes.size():
		order.insert(_rng.randi_range(0, order.size()), option)
	for option: int in order:
		choices.append(fixes[option])
	_answer = order.find(0)


## Собирает ключи подсказок компилятора, чтобы тест проверил, что у каждой есть текст.
static func text_keys() -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in PUZZLES:
		result.append(item["hint"])
	return result


## Сообщает, исправлен ли код.
func is_solved() -> bool:
	return _result > 0


## Сообщает, кончилось ли время.
func is_failed() -> bool:
	return _result < 0


## Сообщает, закончилась ли отладка победой или поражением.
func is_done() -> bool:
	return _result != 0


## Возвращает номер строки с ошибкой; нужен экрану после победы и тестам.
func bug_line() -> int:
	return int(puzzle["bug"])


## Возвращает номер правильного исправления среди [member choices]; нужен тестам.
func answer() -> int:
	return _answer


## Двигает курсор по строкам кода или по вариантам исправления, по кругу.
## [param step] - на сколько строк сдвинуть: -1 вверх, 1 вниз.
func move(step: int) -> void:
	if is_done():
		return
	var count := choices.size() if picking else lines.size()
	cursor = posmod(cursor + step, count)


## Ставит курсор на строку кода или на вариант исправления.
## [param index] - номер строки или варианта.
func point(index: int) -> void:
	var count := choices.size() if picking else lines.size()
	if not is_done() and index >= 0 and index < count:
		cursor = index


## Выбирает то, на чём стоит курсор: строку кода или вариант исправления.
## Возвращает true, если выбор верный.
func select() -> bool:
	if is_done():
		return false
	if picking:
		return _pick(cursor)
	if cursor != bug_line():
		_penalize(WRONG_LINE_SEC)
		return false
	picking = true
	cursor = 0
	return true


## Возвращается от вариантов исправления к строкам кода.
func cancel() -> void:
	if picking and not is_done():
		picking = false
		cursor = bug_line()


## Отсчитывает время; когда оно кончается, отладка провалена.
## [param delta] - прошедшее время в секундах.
func advance(delta: float) -> void:
	if is_done():
		return
	time_left -= delta
	if time_left <= 0.0:
		_fail()


## Проверяет вариант исправления: верный заменяет строку и заканчивает отладку.
## [param index] - номер варианта в [member choices].
## Возвращает true, если вариант верный.
func _pick(index: int) -> bool:
	if index != _answer:
		_penalize(WRONG_FIX_SEC)
		return false
	lines[bug_line()] = choices[index]
	picking = false
	cursor = bug_line()
	_result = 1
	solved.emit()
	return true


## Отнимает секунды за ошибку; если время кончилось, отладка провалена.
## [param seconds] - сколько секунд отнять.
func _penalize(seconds: float) -> void:
	time_left -= seconds
	penalized.emit(seconds)
	if time_left <= 0.0:
		_fail()


## Заканчивает отладку поражением.
func _fail() -> void:
	time_left = 0.0
	_result = -1
	failed.emit()
