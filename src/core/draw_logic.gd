class_name DrawLogic
extends RefCounted
## Правила добивания «Нарисуй капибару»: закрасить на сетке все клетки силуэта, пока не кончилось
## время.
##
## Силуэт виден бледными точками. Клетка силуэта закрашивается один раз; клетка мимо силуэта
## отнимает полсекунды и не закрашивается. Курсор ходит по сетке, кисть можно держать нажатой.

signal solved
signal failed
signal missed(cell: Vector2i)

const TIME_SEC := 30.0
const MISS_SEC := 0.5
const SHAPE: Array[String] = [
	"........X...",
	"..XXXXXXXX..",
	".XXXXXXXXXX.",
	"XXXXXXXXXXXX",
	"XXXXXXXXXXXX",
	".XXXXXXXXXX.",
	".X..X..X..X.",
]

var cursor: Vector2i = Vector2i(0, 3)
var time_left: float = TIME_SEC

var _painted: Dictionary = {}
var _result: int = 0


## Возвращает размер сетки в клетках.
static func grid_size() -> Vector2i:
	return Vector2i(SHAPE[0].length(), SHAPE.size())


## Проверяет, входит ли клетка в силуэт капибары.
## [param cell] - клетка сетки.
static func in_shape(cell: Vector2i) -> bool:
	var size := grid_size()
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return false
	return SHAPE[cell.y][cell.x] == "X"


## Считает клетки силуэта.
static func shape_cells() -> int:
	var count := 0
	for row: String in SHAPE:
		count += row.count("X")
	return count


## Сообщает, закрашена ли клетка.
## [param cell] - клетка сетки.
func is_painted(cell: Vector2i) -> bool:
	return _painted.has(cell)


## Считает, сколько клеток силуэта ещё не закрашено.
func cells_left() -> int:
	return shape_cells() - _painted.size()


## Сообщает, нарисована ли капибара.
func is_solved() -> bool:
	return _result > 0


## Сообщает, кончилось ли время.
func is_failed() -> bool:
	return _result < 0


## Сообщает, закончилось ли рисование победой или поражением.
func is_done() -> bool:
	return _result != 0


## Двигает курсор по сетке, не выпуская его за края.
## [param step] - на сколько клеток сдвинуть.
func move(step: Vector2i) -> void:
	var size := grid_size()
	cursor = (cursor + step).clamp(Vector2i.ZERO, size - Vector2i.ONE)


## Закрашивает клетку: клетка силуэта засчитывается, клетка мимо отнимает время.
## [param cell] - клетка сетки.
## Возвращает true, если закрашена новая клетка силуэта.
func paint(cell: Vector2i) -> bool:
	if is_done() or _painted.has(cell):
		return false
	var size := grid_size()
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return false
	if not in_shape(cell):
		time_left -= MISS_SEC
		missed.emit(cell)
		if time_left <= 0.0:
			_fail()
		return false
	_painted[cell] = true
	if cells_left() == 0:
		_result = 1
		solved.emit()
	return true


## Отсчитывает время; когда оно кончается, рисование провалено.
## [param delta] - прошедшее время в секундах.
func advance(delta: float) -> void:
	if is_done():
		return
	time_left -= delta
	if time_left <= 0.0:
		_fail()


## Заканчивает рисование поражением.
func _fail() -> void:
	time_left = 0.0
	_result = -1
	failed.emit()
