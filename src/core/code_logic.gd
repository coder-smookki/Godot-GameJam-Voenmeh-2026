class_name CodeLogic
extends RefCounted
## Правила боя в кабинете 418: на телевизоре короткая программа на C с пропуском.
##
## Игрок вписывает в пропуск код, чтобы программа вывела нужное или чтобы ввод заработал.
## Ответ сравнивается без пробелов и без точки с запятой в конце, у задачи может быть
## несколько верных ответов. Верный ответ решает задачу и бьёт вирус в телевизоре, неверный
## отнимает время. На каждую задачу своё время; если оно вышло, бой проигран. Когда решено
## нужное число задач, бой выигран. Задачи берутся по кругу из перемешанного набора.
## Текст программ - это код, он не переводится; условия задач лежат в text/ru.po
## (CODE_TASK_<n>). Числа по умолчанию - средний уровень.

signal answered(correct: bool)
signal penalized(seconds: float)
signal won
signal lost

const BLANK := "____"
const NEEDED := 3
const TIME_SEC := 80.0
const PENALTY_SEC := 6.0
const TASKS: Array[Dictionary] = [
	{
		"code": ["int code = 400;", "code = code ____;", 'printf("%d", code);'],
		"answers": ["+4"],
		"output": "404",
	},
	{"code": ["printf(____);"], "answers": ['"Hello"', '"Hello\\n"'], "output": "Hello"},
	{
		"code": ["for (int i = 0; i ____ 3; i++)", '    printf("%d ", i);'],
		"answers": ["<", "!="],
		"output": "0 1 2",
	},
	{
		"code": ["int a[] = {4, 0, 4, 1, 8};", 'printf("%d", sizeof(a) / ____);'],
		"answers": ["sizeof(a[0])", "sizeof(int)", "sizeof(*a)", "sizeofa[0]", "sizeof*a"],
		"output": "5",
	},
	{
		"code": ["int x = 10;", "int *p = ____;", 'printf("%d", *p);'],
		"answers": ["&x"],
		"output": "10",
	},
	{
		"code": ["int n = 6;", "if (n ____ 2 == 0)", '    printf("even");'],
		"answers": ["%"],
		"output": "even",
	},
	{
		"code": ["int sum(int a, int b) {", "    return ____;", "}", 'printf("%d", sum(2, 2));'],
		"answers": ["a+b", "b+a"],
		"output": "4",
	},
	{
		"code": ["int n;", 'scanf("%d", ____);', 'printf("n = %d", n);'],
		"answers": ["&n"],
		"output": "n = 7",
		"input": "7",
	},
	{
		"code": ["char c = 'A' ____;", 'printf("%c", c);'],
		"answers": ["+1"],
		"output": "B",
	},
	{"code": ['printf("____", 404);'], "answers": ["%d", "%i"], "output": "404"},
]

var needed: int = NEEDED
var time_per_task: float = TIME_SEC
var penalty_sec: float = PENALTY_SEC
var solved: int = 0
var time_left: float = TIME_SEC

var _order: Array[int] = []
var _next: int = 0
var _task: int = 0
var _result: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Перемешивает задачи и берёт первую.
## [param seed_value] - зерно случайных чисел; тесты задают его, чтобы бой повторялся.
func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	for index: int in TASKS.size():
		_order.append(index)
	for index: int in range(_order.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var keep := _order[index]
		_order[index] = _order[other]
		_order[other] = keep
	_take()


## Возвращает ключи условий всех задач.
static func text_keys() -> Array[String]:
	var keys: Array[String] = []
	for index: int in TASKS.size():
		keys.append("CODE_TASK_%d" % (index + 1))
	return keys


## Приводит ответ к виду для сравнения: без пробелов и без точки с запятой в конце.
## [param text] - ответ игрока.
static func normalize(text: String) -> String:
	var result := ""
	for character: String in text:
		if character != " " and character != "\t":
			result += character
	while result.ends_with(";"):
		result = result.left(-1)
	return result


## Задаёт числа уровня сложности.
## [param level] - уровень из [Difficulty]; пустая строка берёт уровень этой игры.
func configure(level: String = "") -> void:
	needed = Difficulty.value("code_tasks", level)
	time_per_task = Difficulty.value("code_time", level)
	penalty_sec = Difficulty.value("code_penalty", level)
	time_left = time_per_task


## Возвращает ключ условия текущей задачи.
func goal_key() -> String:
	return "CODE_TASK_%d" % (_task + 1)


## Возвращает строки программы текущей задачи с пропуском [constant BLANK].
func code() -> Array:
	return TASKS[_task]["code"]


## Возвращает, что программа выводит, когда пропуск заполнен верно.
func output() -> String:
	return TASKS[_task]["output"]


## Возвращает, что программа читает с клавиатуры, или пустую строку.
func stdin() -> String:
	return str(TASKS[_task].get("input", ""))


## Возвращает первый верный ответ текущей задачи; нужно тестам.
func solution() -> String:
	return TASKS[_task]["answers"][0]


## Проверяет ответ: верный решает задачу, неверный отнимает время.
## [param text] - то, что игрок вписал в пропуск.
## Возвращает true, если ответ верный.
func submit(text: String) -> bool:
	if is_done():
		return false
	var answer := normalize(text)
	var correct := false
	for variant: String in TASKS[_task]["answers"]:
		if normalize(variant) == answer and not answer.is_empty():
			correct = true
	if correct:
		solved += 1
		answered.emit(true)
		if solved >= needed:
			_result = 1
			won.emit()
		else:
			_take()
		return true
	answered.emit(false)
	time_left -= penalty_sec
	penalized.emit(penalty_sec)
	_check_time()
	return false


## Ведёт время на задачу.
## [param delta] - прошедшее время в секундах.
func advance(delta: float) -> void:
	if is_done():
		return
	time_left -= delta
	_check_time()


## Сообщает, выигран ли бой.
func is_won() -> bool:
	return _result > 0


## Сообщает, закончился ли бой.
func is_done() -> bool:
	return _result != 0


## Заканчивает бой поражением, если время на задачу вышло.
func _check_time() -> void:
	if time_left <= 0.0 and not is_done():
		time_left = 0.0
		_result = -1
		lost.emit()


## Берёт следующую задачу и даёт на неё полное время.
func _take() -> void:
	_task = _order[_next % _order.size()]
	_next += 1
	time_left = time_per_task
