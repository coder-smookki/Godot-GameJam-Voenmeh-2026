class_name EndingCatalog
extends RefCounted
## Каталог пяти концовок.
##
## Хранит номер и вид каждой концовки. Вид определяет, что происходит после слайда:
## шуточная и плохая возвращают в игру, основная и секретная ведут в главное меню.

const KIND_JOKE := "joke"
const KIND_BAD := "bad"
const KIND_MAIN := "main"
const KIND_SECRET := "secret"

const ENDINGS: Dictionary = {
	"expelled": {"number": 1, "kind": KIND_JOKE},
	"not_found": {"number": 2, "kind": KIND_BAD},
	"rm_rf": {"number": 3, "kind": KIND_MAIN},
	"retake": {"number": 4, "kind": KIND_MAIN},
	"capybara": {"number": 5, "kind": KIND_SECRET},
}


## Проверяет, есть ли концовка в каталоге.
## [param ending_id] - код концовки, например "retake".
## Возвращает true, если такая концовка существует.
static func has(ending_id: String) -> bool:
	return ENDINGS.has(ending_id)


## Перечисляет коды концовок по порядку номеров.
## Возвращает массив из пяти строк.
static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(ENDINGS.keys())
	return result


## Возвращает число концовок в игре.
## Возвращает 5; нужно для подписей вида «Концовка №3 из 5».
static func total() -> int:
	return ENDINGS.size()


## Возвращает номер концовки для интерфейса.
## [param ending_id] - код концовки.
## Возвращает число от 1 до 5 или 0, если кода нет.
static func number(ending_id: String) -> int:
	return int(ENDINGS.get(ending_id, {}).get("number", 0))


## Сообщает, заканчивает ли концовка прохождение.
## [param ending_id] - код концовки.
## Возвращает true для основных и секретных концовок, false для шуточных и плохой.
static func is_final(ending_id: String) -> bool:
	var kind: String = ENDINGS.get(ending_id, {}).get("kind", "")
	return kind == KIND_MAIN or kind == KIND_SECRET


## Собирает ключ названия концовки.
## [param ending_id] - код концовки.
## Возвращает ключ перевода, например "END_RETAKE".
static func title_key(ending_id: String) -> String:
	return "END_%s" % ending_id.to_upper()


## Собирает ключ текста слайда концовки.
## [param ending_id] - код концовки.
## Возвращает ключ перевода с окончанием "_TEXT".
static func text_key(ending_id: String) -> String:
	return title_key(ending_id) + "_TEXT"


## Перечисляет все ключи текстов, которые нужны каталогу.
## Возвращает массив ключей перевода для проверки в тестах.
static func text_keys() -> Array[String]:
	var result: Array[String] = []
	for ending_id: String in ENDINGS:
		result.append(title_key(ending_id))
		result.append(text_key(ending_id))
	return result
