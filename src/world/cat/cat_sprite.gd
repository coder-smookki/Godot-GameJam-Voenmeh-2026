class_name CatSprite
extends Node2D
## Рисунок кошки из кадров художниц: поза, поворот и высота над полом с тенью.
##
## Начало координат - точка на полу под кошкой. Кадры смотрят влево; при движении вправо
## рисунок отражается. Этим рисунком пользуются и Капи, и кот в коридоре.

const SIT := &"sit"
const CROUCH := &"crouch"
const LEAP := &"leap"
const LAND := &"land"
const POSES: Dictionary = {
	SIT: preload("res://assets/characters/cat/sit.png"),
	CROUCH: preload("res://assets/characters/cat/crouch.png"),
	LEAP: preload("res://assets/characters/cat/leap.png"),
	LAND: preload("res://assets/characters/cat/land.png"),
}
const SHADOW_FADE_HEIGHT := 120.0
const SHADOW_MIN_SCALE := 0.4

var _pose: StringName = SIT

@onready var _sprite: Sprite2D = $Sprite
@onready var _shadow: Node2D = $Shadow


## Меняет кадр кошки.
## [param frame] - имя кадра: sit, crouch, leap или land.
func pose(frame: StringName) -> void:
	_pose = frame
	_sprite.texture = POSES[frame]


## Сообщает, какой кадр показан сейчас.
## Возвращает имя кадра.
func current_pose() -> StringName:
	return _pose


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
