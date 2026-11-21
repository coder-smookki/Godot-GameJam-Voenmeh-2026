class_name Epilogue
extends RefCounted
## Правила слайдов эпилога.
##
## По решениям игрока выбирает для каждого персонажа вариант слайда «А» или «Б».
## Сами тексты лежат в файле перевода и находятся по ключам.

const VARIANT_A := "A"
const VARIANT_B := "B"
const CATS_FOR_HAPPY_LOGUNOVA := 4
const RAGE_FOR_ANGRY_ZEML := 3
const NOTES_TOTAL := 6
const STUDENTS_TOTAL := 6
const LABA_VARIANTS: Dictionary = {"retake": VARIANT_A, "capybara": VARIANT_A, "rm_rf": VARIANT_B}


## Собирает слайды эпилога для полученной концовки.
## [param ending_id] - код концовки из каталога.
## Возвращает массив словарей {who, variant} по порядку показа; для концовок без эпилога пустой.
static func slides(ending_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not EndingCatalog.is_final(ending_id) or ending_id == "experiment_405":
		return result
	var f: Dictionary = World.f
	result.append(_slide("valshtein", f["compiler"] == "fixed"))
	var happy_logunova: bool = f["logunova"] == "kind" and int(f["cats"]) >= CATS_FOR_HAPPY_LOGUNOVA
	result.append(_slide("logunova", happy_logunova))
	result.append(_slide("zemlyanskaya", int(f["rage"]) < RAGE_FOR_ANGRY_ZEML))
	result.append(_slide("mozhaytsev", f["mozh"] == "clone"))
	result.append(_slide("naurusova", f["naurusova"] == "student"))
	result.append(_slide("lestenko", int(f["notes"]) >= NOTES_TOTAL))
	result.append(_slide("group", int(f["students"]) >= STUDENTS_TOTAL))
	if LABA_VARIANTS.has(ending_id):
		result.append({"who": "laba", "variant": LABA_VARIANTS[ending_id]})
	return result


## Собирает ключ имени персонажа слайда.
## [param who] - код персонажа, например "valshtein".
## Возвращает ключ перевода, например "EPI_VALSHTEIN".
static func title_key(who: String) -> String:
	return "EPI_%s" % who.to_upper()


## Собирает ключ текста слайда.
## [param slide] - словарь {who, variant} из [method slides].
## Возвращает ключ перевода, например "EPI_VALSHTEIN_A".
static func text_key(slide: Dictionary) -> String:
	return "%s_%s" % [title_key(slide["who"]), slide["variant"]]


## Собирает ключ строки «потому что» с причиной варианта.
## [param slide] - словарь {who, variant} из [method slides].
## Возвращает ключ перевода с окончанием "_WHY".
static func why_key(slide: Dictionary) -> String:
	return text_key(slide) + "_WHY"


## Перечисляет все ключи текстов, которые нужны эпилогу.
## Возвращает массив ключей перевода для проверки в тестах.
static func text_keys() -> Array[String]:
	var result: Array[String] = []
	for who: String in [
		"valshtein",
		"logunova",
		"zemlyanskaya",
		"mozhaytsev",
		"naurusova",
		"lestenko",
		"group",
		"laba",
	]:
		result.append(title_key(who))
		for variant: String in [VARIANT_A, VARIANT_B]:
			var slide: Dictionary = {"who": who, "variant": variant}
			result.append(text_key(slide))
			result.append(why_key(slide))
	return result


## Собирает один слайд.
## [param who] - код персонажа.
## [param is_a] - true для варианта «А», false для варианта «Б».
## Возвращает словарь {who, variant}.
static func _slide(who: String, is_a: bool) -> Dictionary:
	return {"who": who, "variant": VARIANT_A if is_a else VARIANT_B}
