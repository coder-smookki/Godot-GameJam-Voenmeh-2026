class_name Aim
extends Node2D
## Прицел отладчика: линия от героя к курсору и короткая вспышка выстрела.
##
## Перерисовывается только во время прицеливания и вспышки.

const FLASH_SEC := 0.08
const DASH := 4.0

var _aiming: bool = false
var _origin: Vector2 = Vector2.ZERO
var _flash_from: Vector2 = Vector2.ZERO
var _flash_to: Vector2 = Vector2.ZERO
var _flash_left: float = 0.0


## Выключает покадровую обработку, пока прицел не нужен.
func _ready() -> void:
	set_process(false)


## Уменьшает время вспышки и перерисовывает прицел.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_flash_left = maxf(_flash_left - delta, 0.0)
	queue_redraw()
	if not _aiming and _flash_left <= 0.0:
		set_process(false)


## Рисует пунктир прицела и линию выстрела.
func _draw() -> void:
	if _aiming:
		draw_dashed_line(_origin, get_local_mouse_position(), Palette.DEBUGGER, 1.0, DASH)
	if _flash_left > 0.0:
		draw_line(_flash_from, _flash_to, Palette.TEXT, 2.0)


## Включает или выключает линию прицела.
## [param aiming] - true, пока герой целится.
## [param origin] - точка в координатах героя, откуда идёт линия.
func set_aiming(aiming: bool, origin: Vector2) -> void:
	_origin = origin
	if aiming == _aiming:
		return
	_aiming = aiming
	set_process(true)
	queue_redraw()


## Показывает короткую вспышку выстрела.
## [param from] - начало линии в координатах героя.
## [param to] - конец линии в координатах героя.
func flash(from: Vector2, to: Vector2) -> void:
	_flash_from = from
	_flash_to = to
	_flash_left = FLASH_SEC
	set_process(true)
	queue_redraw()
