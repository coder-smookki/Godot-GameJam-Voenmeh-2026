class_name Elevator
extends RefCounted
## Правила лифта: какой этаж открыт и что нужно сделать, чтобы открыть следующий.
##
## Между этажами герой ездит только на лифте. Этаж открывается отметкой мира:
## второй после спасения Вани, каждый следующий после победы над боссом предыдущего.

const STATE_HERE := "here"
const STATE_GOAL := "goal"
const STATE_OPEN := "open"
const STATE_LOCKED := "locked"
const USED_MARK := "elevator_used"
const SPAWN := "elevator"
const FLOORS: Array[int] = [5, 4, 3, 2, 1]
const ROOMS: Dictionary = {
	1: "vestibule",
	2: "corridor_2",
	3: "corridor_3",
	4: "corridor_4",
	5: "corridor_5",
}
const REQUIRED_MARKS: Dictionary = {
	2: "vanya_saved",
	3: "boss_2",
	4: "boss_3",
	5: "boss_4",
}


## Сообщает, работает ли лифт вообще.
## Возвращает true, когда открыт хотя бы второй этаж.
static func is_working() -> bool:
	return is_open(2)


## Сообщает, открыт ли этаж.
## [param level] - номер этажа от 1 до 5.
## Возвращает true, если на этаж можно ехать: сделано всё, что открывает его и этажи ниже.
static func is_open(level: int) -> bool:
	if not ROOMS.has(level):
		return false
	for required: int in REQUIRED_MARKS:
		if required <= level and not World.is_marked(REQUIRED_MARKS[required]):
			return false
	return true


## Находит этаж, куда сейчас ведёт сюжет.
## Возвращает номер самого верхнего открытого этажа.
static func goal_floor() -> int:
	for level: int in FLOORS:
		if is_open(level):
			return level
	return 1


## Определяет вид кнопки этажа на панели лифта.
## [param level] - номер этажа кнопки.
## [param current] - этаж, на котором стоит герой.
## Возвращает "here", "goal", "open" или "locked".
static func state(level: int, current: int) -> String:
	if level == current:
		return STATE_HERE
	if not is_open(level):
		return STATE_LOCKED
	return STATE_GOAL if level == goal_floor() else STATE_OPEN


## Выбирает картинку кабины и панели кнопок: сколько кнопок уже вернулось.
## Возвращает номер от 1 (горят кнопки 1 и 2 этажей) до 4 (горят все пять).
static func stage() -> int:
	return clampi(goal_floor() - 1, 1, 4)


## Возвращает комнату, в которую лифт привозит на этаже.
## [param level] - номер этажа.
## Возвращает код локации или пустую строку, если этажа нет.
static func room(level: int) -> String:
	return ROOMS.get(level, "")


## Собирает ключ названия этажа на кнопке.
## [param level] - номер этажа.
## Возвращает ключ перевода, например "ELEVATOR_FLOOR_2".
static func title_key(level: int) -> String:
	return "ELEVATOR_FLOOR_%d" % level


## Собирает ключ текста, который объясняет, как открыть этаж.
## [param level] - номер этажа.
## Возвращает ключ перевода, например "ELEVATOR_LOCK_3".
static func lock_key(level: int) -> String:
	return "ELEVATOR_LOCK_%d" % level


## Перечисляет все ключи текстов, которые нужны лифту.
## Возвращает массив ключей перевода для проверки в тестах.
static func text_keys() -> Array[String]:
	var result: Array[String] = []
	for level: int in FLOORS:
		result.append(title_key(level))
		if REQUIRED_MARKS.has(level):
			result.append(lock_key(level))
	return result
