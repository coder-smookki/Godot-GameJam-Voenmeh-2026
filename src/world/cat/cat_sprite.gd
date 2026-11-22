class_name CatSprite
extends Node2D
## Рисунок кошки из кадров художниц: поза, бег по кругу кадров, поворот и высота над полом.
##
## Начало координат - точка на полу под кошкой. Кадры смотрят влево; при движении вправо
## рисунок отражается. Кадр «на окне» нарисован со спины и в отражении не нуждается.
## Бег - все четыре кадра по кругу в порядке, который назвал владелец: «кошк1 4», «кошк1 1»,
## «кошк1 3», «кошк1 2» (здесь ready, stretch, sit, jump).

const SIT := &"sit"
const READY := &"ready"
const JUMP := &"jump"
const STRETCH := &"stretch"
const WINDOW := &"window"
const POSES: Dictionary = {
	SIT: preload("res://assets/characters/cat/sit.png"),
	READY: preload("res://assets/characters/cat/ready.png"),
	JUMP: preload("res://assets/characters/cat/jump.png"),
	STRETCH: preload("res://assets/characters/cat/stretch.png"),
	WINDOW: preload("res://assets/characters/cat/window.png"),
}
const OFFSETS: Dictionary = {WINDOW: Vector2(-21.0, -53.0)}
const FRAME_OFFSET := Vector2(-44.0, -65.0)
const RUN_CYCLE: Array[StringName] = [READY, STRETCH, SIT, JUMP]
const RUN_FRAME_SEC := 0.08
const SHADOW_FADE_HEIGHT := 120.0
const SHADOW_MIN_SCALE := 0.4

var _pose: StringName = SIT
var _run_clock: float = 0.0
var _run_index: int = 0
var _running: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _shadow: Node2D = $Shadow


## Меняет кадр кошки и останавливает бег.
## [param frame] - имя кадра: sit, ready, jump, stretch или window.
func pose(frame: StringName) -> void:
	_running = false
	_show(frame)


## Сообщает, какой кадр показан сейчас.
## Возвращает имя кадра.
func current_pose() -> StringName:
	return _pose


## Продвигает бег: кадры сменяют друг друга по кругу.
## [param delta] - время кадра в секундах.
## Возвращает true в тот момент, когда лапы коснулись пола (начался новый круг).
func run(delta: float) -> bool:
	if not _running:
		_running = true
		_run_clock = 0.0
		_run_index = 0
		_show(RUN_CYCLE[0])
		return true
	_run_clock += delta
	if _run_clock < RUN_FRAME_SEC:
		return false
	_run_clock -= RUN_FRAME_SEC
	_run_index = (_run_index + 1) % RUN_CYCLE.size()
	_show(RUN_CYCLE[_run_index])
	return _run_index == 0


## Сообщает, бежит ли кошка.
func is_running() -> bool:
	return _running


## Поворачивает кошку в сторону движения или взгляда.
## [param direction] - положительное число для взгляда вправо, отрицательное влево; ноль
## оставляет кошку как есть.
func face(direction: float) -> void:
	if direction != 0.0:
		_sprite.flip_h = direction > 0.0


## Поднимает кошку над полом; тень остаётся на полу и уменьшается с высотой.
## [param height] - высота в пикселях, ноль ставит кошку на пол.
func lift(height: float) -> void:
	_sprite.position.y = -height
	var shrink := clampf(1.0 - height / SHADOW_FADE_HEIGHT, SHADOW_MIN_SCALE, 1.0)
	_shadow.scale = Vector2(shrink, shrink)


## Показывает кадр, не трогая бег.
## [param frame] - имя кадра.
func _show(frame: StringName) -> void:
	_pose = frame
	_sprite.texture = POSES[frame]
	_sprite.offset = OFFSETS.get(frame, FRAME_OFFSET)
	_shadow.visible = frame != WINDOW
