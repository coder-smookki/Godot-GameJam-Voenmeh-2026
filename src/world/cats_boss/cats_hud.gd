class_name CatsHud
extends Control
## Экран боя в кабинете 316 сверху кадра на тёмных плашках: время, градусник, коты, шкала.
##
## Бой идёт в обычном виде, поэтому всё лежит сверху и не закрывает котов на полу. Слева
## время и температура, под ними градусник: колба и трубка, деления через 2 градуса, зелёная
## зона, где рыжему тепло, столбик ртути плавно идёт к температуре комнаты, в нём бегут
## пузырьки. В холоде ртуть синеет и у колбы искрится иней, в тепле над трубкой дрожит воздух;
## число градусов подпрыгивает при каждом изменении. Справа под плашкой этажа три кота:
## доволен ли каждый, у серого ещё столбик корма. Посередине шкала «все довольны».

const BULB := Vector2(18.0, 42.0)
const BULB_RADIUS := 6.0
const TUBE := Rect2(23.0, 39.0, 132.0, 6.0)
const TICK_STEP := 2.0
const GLASS := Color(0.85, 0.92, 1.0, 0.9)
const GLASS_DARK := Color(0.2, 0.25, 0.35)
const WARM := Color("ff3b2f")
const COLD := Color("4aa8ff")
const ZONE := Color(0.18, 0.63, 0.26, 0.45)
const ROW_X := 376.0
const ROW_Y: Array[float] = [52.0, 65.0, 78.0]
const CAT_COLORS: Array[Color] = [Color("ff8a1c"), Color("9aa3b5"), Color("2b2b33")]
const HOLD_BAR := Rect2(170.0, 34.0, 140.0, 5.0)
const POP_SEC := 0.25
const PANEL := Color(0.047, 0.071, 0.125, 0.82)
const PANELS: Array[Rect2] = [Rect2(8.0, 8.0, 156.0, 44.0), Rect2(370.0, 40.0, 102.0, 44.0)]

var logic: CatsLogic = null

var _shown_heat: float = 0.0
var _last_degrees: int = -100
var _pop: float = 0.0
var _clock: float = 0.0


## Растягивает экран на весь кадр и выключает мышь.
func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Ведёт ртуть к температуре комнаты и подбрасывает число при изменении.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	_pop = maxf(_pop - delta, 0.0)
	if logic != null:
		_shown_heat = move_toward(_shown_heat, logic.heat, delta * 0.8)
		var degrees := roundi(logic.celsius())
		if degrees != _last_degrees:
			if _last_degrees > -100:
				_pop = POP_SEC
			_last_degrees = degrees
	queue_redraw()


## Рисует все части экрана.
func _draw() -> void:
	if logic == null:
		return
	var font := Palette.font()
	for panel: Rect2 in PANELS:
		draw_rect(panel, PANEL)
		draw_rect(Rect2(panel.position, Vector2(panel.size.x, 1.0)), Palette.VIRUS)
	_draw_thermometer(font)
	for cat: int in CatsLogic.CATS:
		_draw_cat_row(font, cat)
	var seconds := ceili(logic.time_left)
	var timer := "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
	var low := logic.time_left < 10.0 and int(_clock * 4.0) % 2 == 0
	_text(font, Vector2(13.0, 26.0), timer, Palette.DANGER if low else Palette.TEXT, 16)
	draw_rect(HOLD_BAR.grow(1.0), Palette.UI_SOLID)
	var fill := HOLD_BAR
	fill.size.x *= logic.hold_ratio()
	draw_rect(fill, Palette.OK)
	if logic.happy_count() == CatsLogic.CATS:
		_text(
			font,
			Vector2(HOLD_BAR.position.x, HOLD_BAR.end.y + 10.0),
			tr("BOSS_CATS_HOLD"),
			Palette.OK,
			8
		)


## Рисует градусник: колбу, трубку, зону тепла, деления, ртуть, пузырьки, иней или жар,
## и температуру крупным числом.
## [param font] - шрифт.
func _draw_thermometer(font: Font) -> void:
	var span := CatsLogic.HOT_C - CatsLogic.COLD_C
	var warm_share := (CatsLogic.warm_celsius() - CatsLogic.COLD_C) / span
	var zone_from := TUBE.position.x + TUBE.size.x * warm_share
	var zone := Rect2(zone_from, TUBE.position.y - 3.0, TUBE.end.x - zone_from, TUBE.size.y + 6.0)
	draw_rect(zone, ZONE)
	draw_rect(TUBE.grow(2.0), GLASS_DARK)
	draw_rect(TUBE.grow(1.0), GLASS)
	draw_rect(TUBE, Color(0.1, 0.12, 0.18))
	draw_circle(BULB, BULB_RADIUS + 2.0, GLASS_DARK)
	draw_circle(BULB, BULB_RADIUS + 1.0, GLASS)
	var mercury := COLD.lerp(WARM, clampf(_shown_heat / CatsLogic.HEAT_OK, 0.0, 1.0))
	draw_circle(BULB, BULB_RADIUS - 1.0, mercury)
	var level := TUBE.size.x * _shown_heat
	var column := Rect2(TUBE.position + Vector2(-2.0, 1.0), Vector2(level + 2.0, TUBE.size.y - 2.0))
	draw_rect(column, mercury)
	draw_rect(Rect2(column.position, Vector2(column.size.x, 1.0)), mercury.lightened(0.4))
	for bubble: int in 4:
		var x := fposmod(_clock * 30.0 + bubble * 37.0, maxf(level, 1.0))
		draw_rect(Rect2(TUBE.position + Vector2(x, 2.0), Vector2.ONE), mercury.lightened(0.6))
	var degrees := CatsLogic.COLD_C
	while degrees <= CatsLogic.HOT_C + 0.01:
		var x := TUBE.position.x + TUBE.size.x * (degrees - CatsLogic.COLD_C) / span
		var big := int(degrees) % 6 == 0
		var top := TUBE.position.y - (5.0 if big else 3.0)
		draw_line(Vector2(x, top), Vector2(x, TUBE.position.y - 1.0), GLASS, 1.0)
		degrees += TICK_STEP
	var size_px := 16 if _pop <= 0.0 else 16 + int(4.0 * _pop / POP_SEC)
	var temp_color := WARM if logic.is_happy(CatsLogic.GINGER) else COLD
	_text(font, Vector2(90.0, 26.0), "%d°C" % _last_degrees, temp_color, size_px)
	if not logic.is_happy(CatsLogic.GINGER):
		for flake: int in 5:
			var angle := TAU * flake / 5.0 + _clock
			var at := BULB + Vector2(cos(angle), sin(angle)) * (BULB_RADIUS + 4.0)
			if int(_clock * 6.0 + flake) % 3 != 0:
				draw_rect(Rect2(at.round(), Vector2.ONE), Color.WHITE)
	else:
		for wave: int in 3:
			var x := TUBE.position.x + level - 30.0 + wave * 12.0
			var y := TUBE.position.y - 6.0 - fposmod(_clock * 10.0 + wave * 4.0, 6.0)
			draw_line(Vector2(x, y), Vector2(x + 2.0, y - 3.0), Color(WARM, 0.6), 1.0)


## Рисует строку кота: голову, имя, у серого столбик корма, и отметку.
## [param font] - шрифт.
## [param cat] - номер кота.
func _draw_cat_row(font: Font, cat: int) -> void:
	var y := ROW_Y[cat]
	var head := Vector2(ROW_X, y - 7.0)
	draw_rect(Rect2(head, Vector2(9.0, 7.0)), CAT_COLORS[cat])
	draw_rect(Rect2(head + Vector2(0.0, -2.0), Vector2(2.0, 2.0)), CAT_COLORS[cat])
	draw_rect(Rect2(head + Vector2(7.0, -2.0), Vector2(2.0, 2.0)), CAT_COLORS[cat])
	if cat == CatsLogic.BLACK:
		draw_rect(Rect2(head, Vector2(9.0, 7.0)), Color(1.0, 1.0, 1.0, 0.3), false, 1.0)
	var names: Array[String] = ["CATS_GINGER", "CATS_GRAY", "CATS_BLACK"]
	_text(font, Vector2(ROW_X + 13.0, y), tr(names[cat]), Palette.TEXT, 8)
	if cat == CatsLogic.GRAY:
		var bar := Rect2(ROW_X + 64.0, y - 9.0, 4.0, 10.0)
		draw_rect(bar.grow(1.0), Palette.UI_SOLID)
		var fill := bar.size.y * logic.food
		draw_rect(Rect2(bar.position.x, bar.end.y - fill, bar.size.x, fill), Color("c08040"))
		var need := bar.end.y - bar.size.y * CatsLogic.FOOD_OK
		draw_line(
			Vector2(bar.position.x - 2.0, need), Vector2(bar.end.x + 1.0, need), Palette.OK, 1.0
		)
	var mark := Vector2(ROW_X + 76.0, y - 8.0)
	if logic.is_happy(cat):
		Hearts.draw_heart(self, mark, Hearts.FULL)
	else:
		var shake := roundf(sin(_clock * 30.0))
		draw_line(mark + Vector2(shake, 0.0), mark + Vector2(7.0 + shake, 7.0), Palette.DANGER, 2.0)
		draw_line(mark + Vector2(7.0 + shake, 0.0), mark + Vector2(shake, 7.0), Palette.DANGER, 2.0)


## Рисует строку с тёмной обводкой.
## [param font] - шрифт.
## [param at] - начало базовой линии.
## [param text] - строка.
## [param color] - цвет.
## [param font_size] - размер шрифта.
func _text(font: Font, at: Vector2, text: String, color: Color, font_size: int) -> void:
	draw_string_outline(
		font, at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, Palette.UI_SOLID
	)
	draw_string(font, at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
