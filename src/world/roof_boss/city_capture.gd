class_name CityCapture
extends Node2D
## Пиксели заражения, которые захватывают город за крышей и ползут к Троицкому собору.
##
## Город на фоне крыши поделён на клетки; небо не трогается: линия крыш находится по контурам
## рисунка. Клетки дальше от собора заражаются раньше.
## Доля заражённых клеток - [member progress]: в начале боя вирус уже покрывает большую
## часть города, к концу времени он доходит до куполов. Заражённые клетки мерцают розовым
## и тёмным, свежие вспыхивают. Когда [method swallow] вызван, вирус за секунду накрывает
## и собор. Живёт и на паузе.

const CELL := 8.0
const AREA := Rect2(0.0, 40.0, 1700.0, 206.0)
const CATHEDRAL := Vector2(1098.0, 60.0)
const START := 0.35
const PINK := Color(1.0, 0.0, 1.0)
const DARK := Color(0.0, 0.07, 0.0)
const FRESH_SEC := 0.6
const ART: Texture2D = preload("res://assets/rooms/roof.png")
const OUTLINE := 0.3

var progress: float = START

var _cells: Array[Vector2] = []
var _born: Dictionary = {}
var _clock: float = 0.0
var _shown: int = 0


## Раскладывает клетки от дальних к ближним к собору.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = -25
	var rows := int(AREA.size.y / CELL)
	var columns := int(AREA.size.x / CELL)
	var noise := RandomNumberGenerator.new()
	noise.seed = 404
	var skyline := _skyline()
	var scored: Array = []
	for row: int in rows:
		for column: int in columns:
			var at := AREA.position + Vector2(column * CELL, row * CELL)
			if at.y + CELL * 0.5 < skyline[column]:
				continue
			var distance := Vector2((at.x - CATHEDRAL.x) * 0.6, at.y - CATHEDRAL.y).length()
			scored.append([distance + noise.randf_range(-90.0, 90.0), at])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for item: Array in scored:
		_cells.append(item[1])


## Находит по рисунку верх города в каждом столбце клеток: первый тёмный контур сверху.
## Возвращает высоту линии крыш для каждого столбца.
func _skyline() -> Array[float]:
	var image := ART.get_image()
	var result: Array[float] = []
	for column: int in int(AREA.size.x / CELL):
		var x := int(column * CELL + CELL * 0.5)
		var top := AREA.end.y
		for y: int in range(int(AREA.position.y), int(AREA.end.y)):
			if image.get_pixel(x, y).get_luminance() < OUTLINE:
				top = y
				break
		result.append(top)
	return result


## Возвращает, сколько клеток уже заражено.
func infected() -> int:
	return int(clampf(progress, 0.0, 1.0) * _cells.size())


## Накрывает собор за отведённое время.
## [param sec] - сколько длится захват.
func swallow(sec: float = 1.2) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "progress", 1.0, sec)
	await tween.finished


## Запоминает время появления новых клеток и перерисовывает город.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	var count := infected()
	while _shown < count:
		_born[_shown] = _clock
		_shown += 1
	queue_redraw()


## Рисует заражённые клетки шахматкой; свежие вспыхивают белым.
func _draw() -> void:
	var count := infected()
	var flip := int(_clock * 3.0)
	for index: int in count:
		var at := _cells[index]
		var odd := (int(at.x / CELL) + int(at.y / CELL) + flip) % 2 == 0
		var color := PINK if odd else DARK
		var age := _clock - float(_born.get(index, -10.0))
		if age < FRESH_SEC:
			color = Color.WHITE.lerp(color, age / FRESH_SEC)
		draw_rect(Rect2(at, Vector2(CELL, CELL)), Color(color, 0.85))
