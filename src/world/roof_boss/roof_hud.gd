class_name RoofHud
extends Control
## Время города в финальном бою: сколько осталось, пока пиксели не дошли до собора.
##
## Под полоской босса - значок собора с куполами и полоса времени; когда времени мало, всё
## краснеет и мигает. Значок понемногу заливается розовыми клетками.

const BAR := Rect2(170.0, 40.0, 140.0, 5.0)
const ICON := Vector2(152.0, 46.0)
const DOME := Color("2f6b4a")
const WALL := Color("d9b35a")
const LOW := 0.25

var fight: RoofFight = null

var _clock: float = 0.0


## Растягивается на весь кадр и не ловит мышь.
func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Мигает, когда времени мало.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## Рисует собор, полосу и время.
func _draw() -> void:
	if fight == null or fight.phase in [RoofFight.Phase.WAIT, RoofFight.Phase.INTRO]:
		return
	if fight.phase == RoofFight.Phase.DONE:
		return
	var share := clampf(fight.time_left / fight.time_total, 0.0, 1.0)
	var low := share < LOW and int(_clock * 4.0) % 2 == 0
	var color := Palette.DANGER if low else Palette.GOAL
	draw_rect(Rect2(ICON + Vector2(-6.0, -6.0), Vector2(12.0, 8.0)), WALL)
	for x: float in [-5.0, 0.0, 5.0]:
		var top := ICON + Vector2(x, -8.0 - (3.0 if x == 0.0 else 0.0))
		draw_circle(top, 2.5 if x == 0.0 else 2.0, DOME)
	var infected := int((1.0 - share) * 6.0)
	for cell: int in infected:
		draw_rect(Rect2(ICON + Vector2(-6.0 + cell * 2.0, -2.0), Vector2(2.0, 2.0)), Palette.VIRUS)
	draw_rect(BAR.grow(1.0), Palette.UI_SOLID)
	draw_rect(Rect2(BAR.position, Vector2(BAR.size.x * share, BAR.size.y)), color)
	var seconds := ceili(fight.time_left)
	var text := tr("ROOF_TIMER").format(
		{"time": "%d:%02d" % [floori(seconds / 60.0), seconds % 60]}
	)
	var font := Palette.font()
	var at := Vector2(BAR.end.x + 6.0, BAR.end.y + 1.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, 4, Palette.UI_SOLID)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, color)
