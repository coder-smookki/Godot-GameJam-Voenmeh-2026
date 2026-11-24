class_name CapyPixel
extends Node2D
## Пиксельная капибара: одна и та же на тайниках, в секретной концовке и в титрах.
##
## Рисуется в коде по карте пикселей, два кадра шага. Размер пикселя задаёт величину, в шаге
## ноги переступают. Начало координат - середина под лапами.

const PALETTE: Dictionary = {
	"o": Color8(59, 36, 20),
	"b": Color8(168, 113, 58),
	"l": Color8(201, 143, 82),
	"d": Color8(122, 77, 37),
	"e": Color8(20, 12, 8),
	"n": Color8(40, 26, 16),
	"r": Color8(107, 66, 32),
	"w": Color.WHITE,
}
const BODY: Array[String] = [
	"................rr....",
	"...............orro...",
	"......ooooooooobbbboo.",
	"....oobblllllllbbwebo.",
	"...obbbbbbbbbbbbbbbbbo",
	"..obbbbbbbbbbbbbbbbbnno",
	"..obbbbbbbbbbbbbbbbbdo",
	".obdbbbbbbbbbbbbbbbbo.",
	".obddbbbbbbbbbbbdddo..",
	".obdddddddddddddddddo.",
]
const LEGS: Array = [
	["..odo.odo.....odo.odo.", "..oo..oo......oo..oo.."],
	["...odoodo.....odoodo..", "...oo.oo......oo.oo..."],
]
const STEP_FPS := 7.0
const WIDTH := 23

@export var pixel: float = 2.0
@export var walking: bool = false
@export var faces_right: bool = true
@export var tint: Color = Color.WHITE

var _clock: float = 0.0


## Живёт и на паузе, чтобы шагать в сценах с разговорами.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Ведёт кадры шага.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	if walking:
		queue_redraw()


## Возвращает высоту капибары в пикселях сцены.
func height() -> float:
	return (BODY.size() + 2) * pixel


## Рисует капибару по карте.
func _draw() -> void:
	var frame: int = int(_clock * STEP_FPS) % 2 if walking else 0
	var rows: Array[String] = BODY.duplicate()
	for row: String in LEGS[frame]:
		rows.append(row)
	var top := -rows.size() * pixel
	for y: int in rows.size():
		var line := rows[y]
		for x: int in line.length():
			var key := line[x]
			if not PALETTE.has(key):
				continue
			var column := x if faces_right else WIDTH - 1 - x
			var at := Vector2((column - WIDTH * 0.5) * pixel, top + y * pixel)
			var color: Color = PALETTE[key] * tint
			draw_rect(Rect2(at, Vector2(pixel, pixel)), color)
