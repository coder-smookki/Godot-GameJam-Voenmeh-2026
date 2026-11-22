class_name Trim
extends Control
## Отделка панели интерфейса в теме игры: розовая линия по верху и шахматка вируса в углу.
##
## Кладётся внутрь панели и рисует поверх её рамки. Клетки шахматки время от времени
## меняются, как будто вирус понемногу выедает интерфейс.

const TICK_SEC := 0.7
const LINE_HEIGHT := 2.0
const CORNER := 3.0
const CELL := 2.0
const ROWS := 4

@export var inset: float = 4.0
@export var columns: int = 14
@export var animated: bool = true

var _tick: int = 0


## Отключает перехват мыши и запускает редкую смену клеток.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not animated:
		return
	var timer := Timer.new()
	timer.wait_time = TICK_SEC
	timer.timeout.connect(_on_tick)
	add_child(timer)
	timer.start()


## Рисует линию и ступенчатое пятно шахматки, которое сползает из правого верхнего угла.
func _draw() -> void:
	var origin := Vector2(-inset, -inset)
	var width := size.x + inset * 2.0
	draw_rect(
		Rect2(origin + Vector2(CORNER, 0.0), Vector2(width - CORNER * 2.0, LINE_HEIGHT)),
		Palette.VIRUS
	)
	for column: int in columns:
		var rows := ROWS - column * ROWS / columns
		for row: int in rows:
			if _roll(column, row) < 0.22:
				continue
			var cell := Vector2(width - CORNER - (column + 1) * CELL, row * CELL)
			var color := Palette.VIRUS if (column + row) % 2 == 0 else Palette.UI_SOLID
			draw_rect(Rect2(origin + cell, Vector2(CELL, CELL)), color)


## Даёт псевдослучайное число для клетки, одинаковое до следующей смены.
## [param column] - столбец клетки от правого края.
## [param row] - строка клетки от верхнего края.
## Возвращает число от 0 до 1.
func _roll(column: int, row: int) -> float:
	var mixed := sin(float(column * 127 + row * 311 + _tick * 53) * 12.9898) * 43758.5453
	return mixed - floorf(mixed)


## Меняет узор клеток.
func _on_tick() -> void:
	_tick += 1
	queue_redraw()
