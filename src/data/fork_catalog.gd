class_name ForkCatalog
extends RefCounted
## Каталог решений-развилок, которые меняют переменные мира.
##
## Описывает, какую переменную мира меняет развилка и какие у неё варианты.
## Тексты хранятся в файле перевода и находятся по ключам, собранным из кода развилки.
## Развилки P1 (уйти домой) и P3 (два терминала) решаются прямо в мире:
## их правила лежат во входной двери и в [method World.ending].

const TONE_FIX := "fix"
const TONE_DELETE := "delete"
const TONE_NEUTRAL := "neutral"

const FORKS: Dictionary = {
	"P2":
	{
		"key": "mozh",
		"options":
		[
			{"value": "capy", "tone": TONE_FIX},
			{"value": "stay", "tone": TONE_NEUTRAL},
			{"value": "off", "tone": TONE_DELETE},
		],
	},
}


## Возвращает описание развилки.
## [param fork_id] - код развилки, например "P2".
## Возвращает словарь с ключами key и options или пустой словарь, если кода нет.
static func get_fork(fork_id: String) -> Dictionary:
	return FORKS.get(fork_id, {})


## Перечисляет коды всех развилок каталога в порядке сюжета.
## Возвращает массив строк вида "P2".
static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(FORKS.keys())
	return result


## Находит развилку по переменной мира, которую она меняет.
## [param key] - имя переменной, например "mozh".
## Возвращает код развилки или пустую строку, если переменная не относится к развилкам.
static func id_by_key(key: String) -> String:
	for fork_id: String in FORKS:
		if FORKS[fork_id]["key"] == key:
			return fork_id
	return ""


## Собирает ключ текста с вопросом развилки.
## [param fork_id] - код развилки.
## Возвращает ключ перевода, например "FORK_P2_TITLE".
static func title_key(fork_id: String) -> String:
	return "FORK_%s_TITLE" % fork_id


## Собирает ключ названия варианта.
## [param fork_id] - код развилки.
## [param value] - значение варианта.
## Возвращает ключ перевода, например "FORK_P2_CAPY".
static func option_key(fork_id: String, value: Variant) -> String:
	return "FORK_%s_%s" % [fork_id, str(value).to_upper()]


## Собирает ключ текста «что будет сразу» для варианта.
## [param fork_id] - код развилки.
## [param value] - значение варианта.
## Возвращает ключ перевода с окончанием "_NOW".
static func now_key(fork_id: String, value: Variant) -> String:
	return option_key(fork_id, value) + "_NOW"


## Собирает ключ текста «что это изменит потом» для варианта.
## [param fork_id] - код развилки.
## [param value] - значение варианта.
## Возвращает ключ перевода с окончанием "_LATER".
static func later_key(fork_id: String, value: Variant) -> String:
	return option_key(fork_id, value) + "_LATER"


## Собирает ключ тоста «ЛАБА запомнила» для варианта.
## [param fork_id] - код развилки.
## [param value] - значение варианта.
## Возвращает ключ перевода с окончанием "_TOAST".
static func toast_key(fork_id: String, value: Variant) -> String:
	return option_key(fork_id, value) + "_TOAST"


## Перечисляет все ключи текстов, которые нужны каталогу.
## Возвращает массив ключей перевода; тесты проверяют, что у каждого есть текст.
static func text_keys() -> Array[String]:
	var result: Array[String] = []
	for fork_id: String in FORKS:
		result.append(title_key(fork_id))
		for option: Dictionary in FORKS[fork_id]["options"]:
			var value: Variant = option["value"]
			result.append(option_key(fork_id, value))
			result.append(now_key(fork_id, value))
			result.append(later_key(fork_id, value))
			result.append(toast_key(fork_id, value))
	return result
