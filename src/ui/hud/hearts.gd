class_name Hearts
extends Control
## Сердца героя на плашке этажа: сколько ещё мини-игр и боёв можно проиграть.
##
## Сердца нарисованы по пикселям прямо в коде. Потерянное сердце вздрагивает, вспыхивает
## и раскалывается на две половинки, которые разлетаются и гаснут. Значение берётся из мира.

const SHAPE: Array[String] = [
	".XXX.XXX.",
	"XXXXXXXXX",
	"XXXXXXXXX",
	"XXXXXXXXX",
	".XXXXXXX.",
	"..XXXXX..",
	"...XXX...",
	"....X....",
]
const WIDTH := 9
const HEIGHT := 8
const MIDDLE := 4
const GAP := 3
const FULL := Color("ff3355")
const SHINE := Color("ffc2cc")
const EMPTY := Color("2a2f42")
const BREAK_SEC := 0.8
const SHAKE_PART := 0.25
const SPLIT := 6.0
const DROP := 8.0

var _shown: int = 0
var _breaking: int = -1
var _break: float = 0.0
var _tween: Tween = null


## Рисует пиксельное сердце.
## [param item] - узел, на котором рисуется сердце.
## [param at] - левый верхний угол сердца.
## [param color] - цвет заливки.
## [param half] - 0 рисует сердце целиком, -1 только левую половину, 1 только правую.
static func draw_heart(item: CanvasItem, at: Vector2, color: Color, half: int = 0) -> void:
	for row: int in HEIGHT:
		for column: int in WIDTH:
			if SHAPE[row][column] != "X":
				continue
			if half < 0 and column > MIDDLE or half > 0 and column <= MIDDLE:
				continue
			var pixel := color
			if row == 1 and (column == 1 or column == 2) and color == FULL:
				pixel = SHINE
			item.draw_rect(Rect2(at + Vector2(column, row), Vector2.ONE), pixel)


## Подбирает размер под все сердца и подписывается на изменения мира.
func _ready() -> void:
	custom_minimum_size = Vector2(_total() * (WIDTH + GAP) - GAP, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	World.changed.connect(_on_world_changed)
	World.reloaded.connect(_on_world_reloaded)
	_shown = int(World.f[Game.HEARTS])


## Рисует сердца справа налево от края плашки; раскалывающееся сердце рисуется половинками.
func _draw() -> void:
	var total := _total()
	var left := size.x - (total * (WIDTH + GAP) - GAP)
	for index: int in total:
		var at := Vector2(left + index * (WIDTH + GAP), 0.0)
		if index == _breaking:
			_draw_breaking(at)
		else:
			draw_heart(self, at, FULL if index < _shown else EMPTY)


## Сообщает, сколько сердец сейчас нарисовано целыми.
## Возвращает число полных сердец.
func shown() -> int:
	return _shown


## Рисует сердце, которое только что потеряно: дрожь, вспышка, две разлетающиеся половинки.
## [param at] - левый верхний угол сердца.
func _draw_breaking(at: Vector2) -> void:
	draw_heart(self, at, EMPTY)
	if _break < SHAKE_PART:
		var shake := Vector2(1.0 if int(_break * 40.0) % 2 == 0 else -1.0, 0.0)
		draw_heart(self, at + shake, Color.WHITE if _break > SHAKE_PART * 0.5 else FULL)
		return
	var part := (_break - SHAKE_PART) / (1.0 - SHAKE_PART)
	var spread := 1.0 - pow(1.0 - part, 3.0)
	var color := Color(FULL, 1.0 - part * part)
	draw_heart(self, at + Vector2(-SPLIT * spread - 1.0, DROP * part).round(), color, -1)
	draw_heart(self, at + Vector2(SPLIT * spread + 1.0, DROP * part).round(), color, 1)


## Возвращает, сколько сердец бывает у героя.
func _total() -> int:
	return int(World.SCHEMA[Game.HEARTS]["max"])


## Меняет долю анимации раскола и перерисовывает сердца.
## [param value] - доля от 0 до 1.
func _set_break(value: float) -> void:
	_break = value
	queue_redraw()


## Раскалывает потерянное сердце или просто перерисовывает сердца, если их стало больше.
## [param key] - имя изменённой переменной мира.
## [param value] - новое значение.
func _on_world_changed(key: String, value: Variant) -> void:
	if key != Game.HEARTS:
		return
	var left := int(value)
	if left < _shown:
		_breaking = left
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.tween_method(_set_break, 0.0, 1.0, BREAK_SEC)
		_tween.tween_callback(_set_breaking.bind(-1))
	_shown = left
	queue_redraw()


## Перечитывает сердца после новой игры или загрузки сохранения.
func _on_world_reloaded() -> void:
	_set_breaking(-1)
	_shown = int(World.f[Game.HEARTS])
	queue_redraw()


## Запоминает, какое сердце раскалывается, и перерисовывает сердца.
## [param index] - номер сердца или -1, если ни одно не раскалывается.
func _set_breaking(index: int) -> void:
	_breaking = index
	queue_redraw()
