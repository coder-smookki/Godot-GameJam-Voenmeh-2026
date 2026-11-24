class_name CatsBowl
extends Node2D
## Миска серого кота из рисунков художниц: пустая или с кормом.
##
## Отладчик досыпает корм: сверху сыплются гранулы, миска подпрыгивает. Пока в миске есть
## корм, кот ест, и из миски время от времени вылетают крошки. Начало координат - середина
## дна миски на полу.

signal shot

const EMPTY_TEXTURE: Texture2D = preload("res://assets/props/bowl_empty.png")
const FULL_TEXTURE: Texture2D = preload("res://assets/props/bowl_full.png")
const BOTTOM := 63.0
const FULL_FROM := 0.15
const CRUMB_SEC := 0.7
const FOOD := Color("8a5a2b")

var food: float = 0.0

var _sprite: Sprite2D = null
var _fall: CPUParticles2D = null
var _crumbs: CPUParticles2D = null
var _crumb_left: float = 0.0


## Собирает рисунок, цель для отладчика и частицы корма.
func _ready() -> void:
	z_index = -5
	_sprite = Sprite2D.new()
	_sprite.texture = EMPTY_TEXTURE
	_sprite.centered = false
	_sprite.offset = Vector2(-EMPTY_TEXTURE.get_width() * 0.5, -BOTTOM)
	add_child(_sprite)
	var target := DebugTarget.new(Vector2(80.0, 40.0), Vector2(0.0, -16.0))
	target.shot.connect(shot.emit)
	add_child(target)
	_fall = CPUParticles2D.new()
	_fall.position = Vector2(0.0, -60.0)
	_fall.emitting = false
	_fall.one_shot = true
	_fall.amount = 22
	_fall.lifetime = 0.55
	_fall.explosiveness = 0.5
	_fall.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fall.emission_rect_extents = Vector2(14.0, 3.0)
	_fall.direction = Vector2.DOWN
	_fall.spread = 10.0
	_fall.gravity = Vector2(0.0, 400.0)
	_fall.initial_velocity_min = 10.0
	_fall.initial_velocity_max = 30.0
	_fall.scale_amount_min = 2.0
	_fall.scale_amount_max = 3.0
	_fall.color = FOOD
	add_child(_fall)
	_crumbs = CPUParticles2D.new()
	_crumbs.position = Vector2(-10.0, -22.0)
	_crumbs.emitting = false
	_crumbs.one_shot = true
	_crumbs.amount = 4
	_crumbs.lifetime = 0.5
	_crumbs.explosiveness = 1.0
	_crumbs.direction = Vector2(-1.0, -1.0)
	_crumbs.spread = 40.0
	_crumbs.gravity = Vector2(0.0, 300.0)
	_crumbs.initial_velocity_min = 30.0
	_crumbs.initial_velocity_max = 60.0
	_crumbs.scale_amount_min = 1.0
	_crumbs.scale_amount_max = 2.0
	_crumbs.color = FOOD
	add_child(_crumbs)


## Показывает, сколько корма в миске.
## [param value] - корм от 0 до 1.
func set_food(value: float) -> void:
	food = value
	_sprite.texture = FULL_TEXTURE if food >= FULL_FROM else EMPTY_TEXTURE


## Сыплет корм сверху; миска подпрыгивает.
func pour() -> void:
	_fall.restart()
	_sprite.scale = Vector2(1.15, 0.85)
	create_tween().tween_property(_sprite, "scale", Vector2.ONE, 0.25).set_delay(0.3).set_trans(
		Tween.TRANS_BACK
	)


## Пока в миске есть корм, время от времени из неё вылетают крошки: кот ест.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if food < FULL_FROM:
		return
	_crumb_left -= delta
	if _crumb_left <= 0.0:
		_crumb_left = CRUMB_SEC * randf_range(0.7, 1.4)
		_crumbs.restart()
