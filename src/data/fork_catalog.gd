class_name ForkCatalog
extends RefCounted
## Каталог решений-развилок, которые игрок принимает явно.
##
## Описывает, какую переменную мира меняет развилка и какие у неё варианты.
## Тексты хранятся в файле перевода и находятся по ключам, собранным из кода развилки.

const TONE_FIX := "fix"
const TONE_DELETE := "delete"
const TONE_NEUTRAL := "neutral"
const TONE_ORDER := "order"

const FORKS: Dictionary = {
	"P4":
	{
		"key": "compiler",
		"in_world": false,
		"options":
		[
			{"value": "fixed", "tone": TONE_FIX},
			{"value": "deleted", "tone": TONE_DELETE},
		],
	},
	"P5":
	{
		"key": "naurusova",
		"in_world": false,
		"options":
		[
			{"value": "error", "tone": TONE_DELETE},
			{"value": "student", "tone": TONE_FIX},
			{"value": "unknown", "tone": TONE_NEUTRAL},
		],
	},
	"P6":
	{
		"key": "first_floor",
		"in_world": false,
		"options":
		[
			{"value": 3, "tone": TONE_ORDER},
			{"value": 4, "tone": TONE_ORDER},
		],
	},
	"P9":
	{
		"key": "logunova",
		"in_world": false,
		"options":
		[
			{"value": "kind", "tone": TONE_FIX},
			{"value": "strict", "tone": TONE_DELETE},
		],
	},
	"P11":
	{
		"key": "zeml",
		"in_world": false,
		"options":
		[
			{"value": "calm", "tone": TONE_FIX},
			{"value": "storm", "tone": TONE_DELETE},
		],
	},
	"P12":
	{
		"key": "mozh",
		"in_world": true,
		"options":
		[
			{"value": "clone", "tone": TONE_FIX},
			{"value": "stay", "tone": TONE_NEUTRAL},
			{"value": "off", "tone": TONE_DELETE},
		],
	},
}


## Возвращает описание развилки.
## [param fork_id] - код развилки, например "P4".
## Возвращает словарь с ключами key, in_world и options или пустой словарь, если кода нет.
static func get_fork(fork_id: String) -> Dictionary:
	return FORKS.get(fork_id, {})


## Перечисляет коды всех развилок в порядке сюжета.
## Возвращает массив строк вида "P4".
static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(FORKS.keys())
	return result


## Находит развилку по переменной мира, которую она меняет.
## [param key] - имя переменной, например "compiler".
## Возвращает код развилки или пустую строку, если переменная не относится к развилкам.
static func id_by_key(key: String) -> String:
	for fork_id: String in FORKS:
		if FORKS[fork_id]["key"] == key:
			return fork_id
	return ""


## Собирает ключ текста с вопросом развилки.
## [param fork_id] - код развилки.
## Возвращает ключ перевода, например "FORK_P4_TITLE".
static func title_key(fork_id: String) -> String:
	return "FORK_%s_TITLE" % fork_id


## Собирает ключ названия варианта.
## [param fork_id] - код развилки.
## [param value] - значение варианта.
## Возвращает ключ перевода, например "FORK_P4_FIXED".
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
