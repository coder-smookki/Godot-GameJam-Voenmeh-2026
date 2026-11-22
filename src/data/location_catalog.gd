class_name LocationCatalog
extends RefCounted
## Каталог локаций корпуса из раскадровки.
##
## Хранит этаж каждой локации. Сцена комнаты и тексты находятся по соглашению об именах,
## поэтому новая комната подключается добавлением файла сцены без правки каталога.

const FLOOR_FIRST := 1
const FLOOR_ROOF := 6
const ROOMS_DIR := "res://src/world/rooms/"

const LOCATIONS: Dictionary = {
	"lift": 0,
	"vestibule": 1,
	"wardrobe": 1,
	"corridor_2": 2,
	"kafedra": 2,
	"214": 2,
	"corridor_3": 3,
	"316": 3,
	"corridor_4": 4,
	"418": 4,
	"corridor_5": 5,
	"server": 5,
	"roof": FLOOR_ROOF,
}


## Проверяет, есть ли локация в каталоге.
## [param code] - код локации, например "vestibule" или "214".
## Возвращает true, если код известен.
static func has(code: String) -> bool:
	return LOCATIONS.has(code)


## Перечисляет коды всех локаций.
## Возвращает массив строк в порядке раскадровки.
static func codes() -> Array[String]:
	var result: Array[String] = []
	result.assign(LOCATIONS.keys())
	return result


## Возвращает этаж локации.
## [param code] - код локации.
## Возвращает номер этажа: 1-5 - этажи, 6 - крыша, 0 - кабина лифта между этажами;
## -1, если кода нет.
static func floor_of(code: String) -> int:
	return int(LOCATIONS.get(code, -1))


## Собирает путь к сцене комнаты по коду локации.
## [param code] - код локации.
## Возвращает путь вида "res://src/world/rooms/room_vestibule.tscn"; файла может ещё не быть.
static func scene_path(code: String) -> String:
	return "%sroom_%s.tscn" % [ROOMS_DIR, code.to_lower()]


## Проверяет, собрана ли уже комната для локации.
## [param code] - код локации.
## Возвращает true, если локация известна и файл её сцены существует.
static func is_built(code: String) -> bool:
	return has(code) and ResourceLoader.exists(scene_path(code))


## Собирает ключ названия локации.
## [param code] - код локации.
## Возвращает ключ перевода, например "LOC_VESTIBULE".
static func title_key(code: String) -> String:
	return "LOC_%s" % code.to_upper()


## Собирает ключ названия этажа.
## [param level] - номер этажа от 1 до 6.
## Возвращает ключ перевода, например "FLOOR_2".
static func floor_key(level: int) -> String:
	return "FLOOR_%d" % level


## Перечисляет все ключи текстов, которые нужны каталогу.
## Возвращает массив ключей перевода для проверки в тестах.
static func text_keys() -> Array[String]:
	var result: Array[String] = []
	for code: String in LOCATIONS:
		result.append(title_key(code))
	for level: int in range(FLOOR_FIRST, FLOOR_ROOF + 1):
		result.append(floor_key(level))
	return result
