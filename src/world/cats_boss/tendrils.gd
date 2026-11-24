class_name Tendrils
extends Node2D
## Нити заражения от Логуновой к трём котам: так видно, что она ими управляет.
##
## Каждая нить - изогнутая колышущаяся линия, по которой бегут клетки шахматки от Логуновой
## к коту. Нить довольного кота бледнеет и рвётся пунктиром. Когда заражение что-то портит,
## по нити бежит яркий импульс. После победы нити втягиваются обратно и гаснут.

const SEGMENTS := 24
const ARC := 55.0
const WAVE := 4.0
const VIRUS := Color(1.0, 0.0, 1.0)
const DARK := Color(0.0, 0.07, 0.0)
const BEADS := 3
const BEAD_SPEED := 0.45
const PULSE_SEC := 0.6

var origin: Vector2 = Vector2.ZERO
var ends: Array[Vector2] = []
var calm: Array[bool] = []
var reach: float = 0.0

var _clock: float = 0.0
var _pulse: Array[float] = []


## Задаёт начало и концы нитей.
## [param from] - откуда тянутся нити (руки Логуновой).
## [param points] - головы котов.
func setup(from: Vector2, points: Array[Vector2]) -> void:
	origin = from
	ends = points
	calm.resize(points.size())
	calm.fill(false)
	_pulse.resize(points.size())
	_pulse.fill(0.0)


## Пускает по нити яркий импульс от Логуновой.
## [param index] - номер нити.
func pulse(index: int) -> void:
	if index >= 0 and index < _pulse.size():
		_pulse[index] = PULSE_SEC


## Ведёт колыхание и импульсы.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	for index: int in _pulse.size():
		_pulse[index] = maxf(_pulse[index] - delta, 0.0)
	queue_redraw()


## Рисует нити, бегущие клетки и импульсы.
func _draw() -> void:
	if reach <= 0.0:
		return
	for index: int in ends.size():
		var points := _curve(index)
		var count := maxi(int(points.size() * reach), 2)
		var shown := points.slice(0, count)
		if calm[index]:
			for step: int in range(0, shown.size() - 1, 2):
				draw_line(shown[step], shown[step + 1], Color(VIRUS, 0.25), 1.0)
			continue
		draw_polyline(shown, Color(DARK, 0.8), 3.0)
		var glow := 1.0 + _pulse[index] / PULSE_SEC
		draw_polyline(shown, Color(VIRUS, 0.75 * glow), 1.0 + _pulse[index] * 3.0)
		for bead: int in BEADS:
			var t := fposmod(_clock * BEAD_SPEED + bead / float(BEADS), 1.0)
			if t > reach:
				continue
			var at := points[mini(int(t * (points.size() - 1)), points.size() - 1)]
			var color := VIRUS if bead % 2 == 0 else DARK
			draw_rect(Rect2(at - Vector2(2.0, 2.0), Vector2(4.0, 4.0)).abs(), color)


## Строит точки изогнутой колышущейся нити.
## [param index] - номер нити.
func _curve(index: int) -> PackedVector2Array:
	var end := ends[index]
	var middle := (origin + end) * 0.5 + Vector2(0.0, -ARC)
	var normal := (end - origin).orthogonal().normalized()
	var points := PackedVector2Array()
	for step: int in SEGMENTS + 1:
		var t := step / float(SEGMENTS)
		var at := origin.lerp(middle, t).lerp(middle.lerp(end, t), t)
		at += normal * sin(t * PI * 3.0 + _clock * 4.0 + index) * WAVE * sin(t * PI)
		points.append(at)
	return points
