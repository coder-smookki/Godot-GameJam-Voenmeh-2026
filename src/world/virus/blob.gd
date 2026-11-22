class_name Blob
extends StaticBody2D
## Сгусток ошибки: живой ком шахматки, который перекрывает дверь.
##
## Покачивается, как желе. Каждое попадание отладчика сплющивает его, и он краснеет;
## после первого попадания показан кадр «с уроном». После трёх попаданий сгусток
## лопается, шахматка на двери (seal) и надпись над ним (label) растворяются.

signal destroyed

const LAYER_SHOOTABLE := 8
const WHOLE: Texture2D = preload("res://assets/props/blob.png")
const HURT: Texture2D = preload("res://assets/props/blob_hit.png")
const WOBBLE := 0.05
const WOBBLE_SEC := 0.55
const HIT_SQUASH := Vector2(1.18, 0.82)
const HIT_SEC := 0.25
const FLASH := Color(2.0, 0.6, 0.6)
const RED_PER_HIT := 0.22
const POP_SEC := 0.45

@export var blob_id: String = ""
@export var hits: int = 3
@export var heal_amount: float = 8.0
@export var seal: CanvasItem = null
@export var label: CanvasItem = null

var _left: int = 0
var _hit_tween: Tween = null

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $Shape
@onready var _burst: CPUParticles2D = $Burst


## Убирает уже лопнувший сгусток вместе с шахматкой или запускает покачивание.
func _ready() -> void:
	collision_layer = LAYER_SHOOTABLE
	collision_mask = 0
	if World.is_marked(mark_name()):
		for item: CanvasItem in [seal, label]:
			if item != null:
				item.queue_free()
		queue_free()
		return
	_left = hits
	var wobble := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	wobble.tween_property(_sprite, "scale", Vector2(1.0 + WOBBLE, 1.0 - WOBBLE), WOBBLE_SEC)
	wobble.tween_property(_sprite, "scale", Vector2(1.0 - WOBBLE, 1.0 + WOBBLE), WOBBLE_SEC)


## Принимает попадание: сплющивание, вспышка, кадр с уроном; на последнем лопается.
func hit() -> void:
	if _left <= 0:
		return
	_left -= 1
	_sprite.texture = HURT
	var red := 1.0 - RED_PER_HIT * float(hits - _left)
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_sprite.modulate = FLASH
	_sprite.position.y = 0.0
	_hit_tween = create_tween()
	_hit_tween.tween_property(_sprite, "modulate", Color(1.0, red, red), HIT_SEC)
	var squash := create_tween()
	squash.tween_property(self, "scale", HIT_SQUASH, HIT_SEC * 0.3)
	squash.tween_property(self, "scale", Vector2.ONE, HIT_SEC).set_trans(Tween.TRANS_BACK)
	_burst.restart()
	_burst.emitting = true
	if _left == 0:
		_pop()


## Сообщает, сколько попаданий сгусток ещё выдержит.
func hits_left() -> int:
	return _left


## Возвращает имя отметки лопнувшего сгустка: "blob_<id>".
func mark_name() -> String:
	return "blob_%s" % blob_id


## Лопает сгусток: запоминает победу, лечит этаж и растворяет всё, что он держал.
func _pop() -> void:
	_shape.set_deferred("disabled", true)
	World.mark(mark_name())
	Infection.heal(Infection.current_floor, heal_amount)
	SaveSystem.save_game()
	destroyed.emit()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(1.6, 0.1), POP_SEC).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, "modulate:a", 0.0, POP_SEC)
	for item: CanvasItem in [seal, label]:
		if item != null:
			tween.tween_property(item, "modulate:a", 0.0, POP_SEC * 1.5)
	tween.chain().tween_callback(_cleanup)


## Убирает сгусток, шахматку и надпись после того, как они растворились.
func _cleanup() -> void:
	for item: CanvasItem in [seal, label]:
		if item != null:
			item.queue_free()
	queue_free()
