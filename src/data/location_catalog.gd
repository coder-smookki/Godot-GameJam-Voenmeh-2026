class_name LocationCatalog
extends RefCounted
## Каталог всех 46 локаций корпуса.
##
## Хранит этаж каждой локации. Сцена комнаты и тексты находятся по соглашению об именах,
## поэтому новая комната подключается добавлением файла сцены без правки каталога.

const FLOOR_BASEMENT := 0
const FLOOR_ROOF := 5
const ROOMS_DIR := "res://src/world/rooms/"

const LOCATIONS: Dictionary = {
	"1-01": 1,
	"1-02": 1,
	"1-03": 1,
	"1-04": 1,
	"1-05": 1,
	"1-06": 1,
	"1-07": 1,
	"1-08": 1,
	"1-09": 1,
	"1-10": 1,
	"1-11": 1,
	"1-12": 1,
	"1-13": 1,
	"214": 2,
	"201": 2,
	"203": 2,
	"205": 2,
	"207": 2,
	"209": 2,
	"211": 2,
	"216": 2,
	"2-K": 2,
	"218": 2,
	"301": 3,
	"303": 3,
	"302": 3,
	"305": 3,
	"304": 3,
	"307": 3,
	"309": 3,
	"311": 3,
	"411": 4,
	"401": 4,
	"403": 4,
	"405": 4,
	"407": 4,
	"409": 4,
	"402": 4,
	"P-0": FLOOR_BASEMENT,
	"P-1": FLOOR_BASEMENT,
	"P-2": FLOOR_BASEMENT,
	"P-3": FLOOR_BASEMENT,
	"P-4": FLOOR_BASEMENT,
	"P-5": FLOOR_BASEMENT,
	"P-6": FLOOR_BASEMENT,
	"K-1": FLOOR_ROOF,
}


## Проверяет, есть ли локация в каталоге.
## [param code] - код локации, например "1-01" или "214".
## Возвращает true, если код известен.
static func has(code: String) -> bool:
	return LOCATIONS.has(code)


## Перечисляет коды всех локаций.
## Возвращает массив из 46 строк в порядке документа.
static func codes() -> Array[String]:
	var result: Array[String] = []
	result.assign(LOCATIONS.keys())
	return result


## Возвращает этаж локации.
## [param code] - код локации.
## Возвращает номер этажа: 0 - подвал, 1-4 - этажи, 5 - крыша; -1, если кода нет.
static func floor_of(code: String) -> int:
	return int(LOCATIONS.get(code, -1))


## Собирает путь к сцене комнаты по коду локации.
## [param code] - код локации.
## Возвращает путь вида "res://src/world/rooms/room_1_01.tscn"; файла может ещё не быть.
static func scene_path(code: String) -> String:
	return "%sroom_%s.tscn" % [ROOMS_DIR, code.to_lower().replace("-", "_")]


## Проверяет, собрана ли уже комната для локации.
## [param code] - код локации.
## Возвращает true, если локация известна и файл её сцены существует.
static func is_built(code: String) -> bool:
	return has(code) and ResourceLoader.exists(scene_path(code))


## Собирает ключ названия локации.
## [param code] - код локации.
## Возвращает ключ перевода, например "LOC_1_01".
static func title_key(code: String) -> String:
	return "LOC_%s" % code.to_upper().replace("-", "_")


## Собирает ключ названия этажа.
## [param level] - номер этажа от 0 до 5.
## Возвращает ключ перевода, например "FLOOR_2".
static func floor_key(level: int) -> String:
	return "FLOOR_%d" % level


## Перечисляет все ключи текстов, которые нужны каталогу.
## Возвращает массив ключей перевода для проверки в тестах.
static func text_keys() -> Array[String]:
	var result: Array[String] = []
	for code: String in LOCATIONS:
		result.append(title_key(code))
	for level: int in range(FLOOR_BASEMENT, FLOOR_ROOF + 1):
		result.append(floor_key(level))
	return result
