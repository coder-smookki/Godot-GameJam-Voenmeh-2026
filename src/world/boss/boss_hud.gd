class_name BossHud
extends Control
## Экран боя с боссом поверх игры: имя и здоровье босса, подсказка фазы, целостность героя,
## заряд бомбы помощника, большие надписи и вспышки.
##
## Всё рисуется в коде шрифтом проекта; бой только меняет поля и вызывает [method banner]
## и [method flash].

const BAR := Rect2(170.0, 22.0, 140.0, 6.0)
const NAME_Y := 17.0
const HINT_Y := 42.0
const BOTTOM_Y := 258.0
const SEGMENT_GAP := 3.0
const BOSS_COLOR := Color("ff2b3a")
const BACK := Color(0.047, 0.071, 0.125, 0.86)
const BANNER_SEC := 1.6
const SLAM_SEC := 0.22

var boss_name: String = ""
var hp: int = 3
var hp_max: int = 3
var hint: String = ""
var integrity: int = 3
var integrity_max: int = 3
var charge: int = 0
var charge_max: int = 0

var _shown_hp: float = 3.0
var _banner: String = ""
var _banner_color: Color = Color.WHITE
var _banner_left: float = 0.0
var _flash: Color = Color.TRANSPARENT
var _hp_flash: float = 0.0


## Растягивает экран на весь кадр и выключает мышь.
func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Ведёт полоску здоровья, надпись и вспышку.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_shown_hp = move_toward(_shown_hp, hp, delta * 1.5)
	_banner_left = maxf(_banner_left - delta, 0.0)
	_hp_flash = maxf(_hp_flash - delta, 0.0)
	_flash.a = maxf(_flash.a - delta * 2.5, 0.0)
	queue_redraw()


## Показывает большую надпись посреди экрана: она падает сверху и гаснет.
## [param text] - текст надписи.
## [param color] - цвет текста.
func banner(text: String, color: Color = Palette.GOAL) -> void:
	_banner = text
	_banner_color = color
	_banner_left = BANNER_SEC


## Заливает экран цветом, который быстро гаснет.
## [param color] - цвет вспышки с непрозрачностью.
func flash(color: Color) -> void:
	_flash = color


## Отнимает у босса здоровье: полоска мигает и плавно уменьшается.
func damage() -> void:
	hp = maxi(hp - 1, 0)
	_hp_flash = 0.5


## Рисует все части экрана боя.
func _draw() -> void:
	var font := Palette.font()
	if not boss_name.is_empty():
		_center(font, NAME_Y, boss_name, BOSS_COLOR, 8)
		draw_rect(BAR.grow(2.0), BACK)
		var width := (BAR.size.x - SEGMENT_GAP * (hp_max - 1)) / hp_max
		for index: int in hp_max:
			var cell := Rect2(
				BAR.position + Vector2((width + SEGMENT_GAP) * index, 0.0),
				Vector2(width, BAR.size.y)
			)
			draw_rect(cell, Color(0.2, 0.05, 0.07))
			var fill := clampf(_shown_hp - index, 0.0, 1.0)
			var color := (
				Color.WHITE if _hp_flash > 0.0 and int(_hp_flash * 12.0) % 2 == 0 else BOSS_COLOR
			)
			draw_rect(Rect2(cell.position, Vector2(width * fill, BAR.size.y)), color)
	if not hint.is_empty():
		_center(font, HINT_Y, hint, Palette.TEXT, 8)
	if integrity_max > 0:
		_text(font, Vector2(8.0, BOTTOM_Y), tr("BOSS_INTEGRITY"), Palette.DEBUGGER)
		for index: int in integrity_max:
			var pip := Rect2(Vector2(104.0 + index * 11.0, BOTTOM_Y - 8.0), Vector2(8.0, 8.0))
			draw_rect(pip, Palette.DEBUGGER if index < integrity else Color(0.15, 0.18, 0.26))
	if charge_max > 0:
		var label := tr("BOSS_BOMB")
		var right := size.x - 8.0 - charge_max * 9.0
		_text(font, Vector2(right - label.length() * 8.0 - 6.0, BOTTOM_Y), label, Palette.GOAL)
		for index: int in charge_max:
			var pip := Rect2(Vector2(right + index * 9.0, BOTTOM_Y - 8.0), Vector2(7.0, 8.0))
			draw_rect(pip, Palette.GOAL if index < charge else Color(0.25, 0.2, 0.1))
	if _banner_left > 0.0:
		var age := BANNER_SEC - _banner_left
		var drop := clampf(age / SLAM_SEC, 0.0, 1.0)
		var alpha := clampf(_banner_left / 0.3, 0.0, 1.0)
		var y := lerpf(70.0, 112.0, 1.0 - pow(1.0 - drop, 3.0))
		draw_rect(Rect2(0.0, y - 20.0, size.x, 28.0), Color(0.0, 0.0, 0.0, 0.55 * alpha))
		_center(font, y, _banner, Color(_banner_color, alpha), 16)
	if _flash.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), _flash)


## Рисует строку по центру экрана.
## [param font] - шрифт.
## [param y] - базовая линия.
## [param text] - строка.
## [param color] - цвет.
## [param font_size] - размер шрифта.
func _center(font: Font, y: float, text: String, color: Color, font_size: int) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var at := Vector2((size.x - width) * 0.5, y).round()
	draw_string_outline(
		font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, Palette.UI_SOLID
	)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


## Рисует строку с тёмной обводкой.
## [param font] - шрифт.
## [param at] - начало базовой линии.
## [param text] - строка.
## [param color] - цвет.
func _text(font: Font, at: Vector2, text: String, color: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, 4, Palette.UI_SOLID)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, color)
