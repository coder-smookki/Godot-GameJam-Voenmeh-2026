class_name TestCase
extends RefCounted
## Основа для набора тестов: проверки и сброс состояния игры перед каждым тестом.
##
## Наследник объявляет функции с именами на "test_"; их находит и запускает [TestRunner].

const TALK_STEPS_LIMIT := 200
const CHOICES_LIMIT := 4

var tree: SceneTree = null
var failures: Array[String] = []
var checks: int = 0


## Возвращает игру к чистому состоянию перед каждым тестом.
func before_each() -> void:
	Ui.close_all_modals()
	World.reset()
	Journal.clear()
	Infection.reset()
	SaveSystem.session = {}
	SaveSystem.delete_save()


## Начинает новую игру и дочитывает разговор, которым герой встречает вестибюль.
func start_game() -> void:
	await Game.new_game()
	finish_talk()


## Дочитывает открытый разговор до конца, выбирая первый из предложенных ответов.
func finish_talk() -> void:
	var steps := 0
	while Ui.dialogue.visible and steps < TALK_STEPS_LIMIT:
		Ui.dialogue.advance()
		for index: int in CHOICES_LIMIT:
			Ui.dialogue.choose(index)
		steps += 1


## Проверяет, что условие истинно.
## [param condition] - проверяемое условие.
## [param message] - что именно проверялось; попадает в отчёт при провале.
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Проверяет, что значение равно ожидаемому.
## [param actual] - полученное значение.
## [param expected] - ожидаемое значение.
## [param message] - что именно проверялось; попадает в отчёт при провале.
func equal(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: получено %s, ожидалось %s" % [message, actual, expected])
