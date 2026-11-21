class_name Palette
extends RefCounted
## Цвета интерфейса и заглушек из дизайн-документа.
##
## Одно место для всех цветов: правка здесь меняет их во всей игре.

const VIRUS := Color("ff1fb4")
const GOAL := Color("ffc62e")
const DEBUGGER := Color("00c2e0")
const DANGER := Color("d81e1e")
const OK := Color("2ea043")
const NEUTRAL := Color("8a93a8")
const ORDER := Color("e08a00")
const TEXT := Color("e8ecf4")
const UI_BACKGROUND := Color(0.047, 0.071, 0.125, 0.92)
const UI_SOLID := Color("0c1220")
const PLAYER := Color("ff1fb4")
const CAPI := Color("a8703a")
const NPC := Color("6b7280")
const FONT_SIZE := 8


## Возвращает цвет для тона варианта развилки.
## [param tone_id] - тон из каталога развилок: fix, delete, neutral или order.
## Возвращает цвет рамки и заголовка карточки.
static func tone(tone_id: String) -> Color:
	match tone_id:
		ForkCatalog.TONE_FIX:
			return DEBUGGER
		ForkCatalog.TONE_DELETE:
			return VIRUS
		ForkCatalog.TONE_ORDER:
			return ORDER
	return NEUTRAL


## Собирает плоскую рамку панели в стиле интерфейса.
## [param border] - цвет рамки.
## [param width] - толщина рамки в пикселях.
## Возвращает новый стиль для панелей и кнопок.
static func frame(border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UI_BACKGROUND
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(4.0)
	return style


## Возвращает пиксельный шрифт проекта для рисования текста в мире.
## Возвращает шрифт из темы проекта или запасной шрифт движка, если тема не задана.
static func font() -> Font:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.default_font != null:
		return theme.default_font
	return ThemeDB.fallback_font
