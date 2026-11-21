class_name SpeakerCatalog
extends RefCounted
## Каталог говорящих: имя, портрет и цвет заглушки портрета.
##
## Портрет ищется по правилу именования: assets/portraits/<код>.png. Пока художник
## портрет не нарисовал, окно разговора показывает цветную заглушку.

const PORTRAITS_DIR := "res://assets/portraits/"
const COLORS: Dictionary = {
	"demyan": Color("3f7a4a"),
	"vanya": Color("3168d8"),
	"naurusova": Color("8a5a9c"),
}


## Возвращает коды всех говорящих.
static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(COLORS.keys())
	return result


## Проверяет, есть ли говорящий в каталоге.
## [param id] - код говорящего; пустая строка означает текст от автора.
## Возвращает true для известного кода.
static func has(id: String) -> bool:
	return COLORS.has(id)


## Возвращает ключ текста с именем говорящего.
## [param id] - код говорящего.
static func name_key(id: String) -> String:
	return "NAME_%s" % id.to_upper()


## Возвращает цвет заглушки портрета.
## [param id] - код говорящего.
static func color(id: String) -> Color:
	return COLORS.get(id, Palette.NPC)


## Возвращает портрет говорящего.
## [param id] - код говорящего.
## Возвращает картинку художника или null, если портрет ещё не нарисован.
static func portrait(id: String) -> Texture2D:
	var path := "%s%s.png" % [PORTRAITS_DIR, id]
	if not ResourceLoader.exists(path):
		return null
	return load(path)


## Собирает ключи имён, чтобы тест проверил, что у каждого есть текст.
static func text_keys() -> Array[String]:
	var result: Array[String] = []
	for id: String in COLORS:
		result.append(name_key(id))
	return result
