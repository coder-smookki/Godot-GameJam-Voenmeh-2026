class_name MarkZone
extends Area2D
## Невидимая зона на полу: когда в неё входит герой, в мире ставится отметка.
##
## Нужна для событий «герой проходит мимо», например крик из гардероба слышен только рядом
## с его дверью. Отметка ставится один раз; что из неё следует, описано в [Story].

const LAYER_PLAYER := 2

@export var mark_id: String = ""
@export var size: Vector2 = Vector2(400.0, 200.0)


## Создаёт форму зоны над полом и ждёт героя; если отметка уже есть, зона не нужна.
func _ready() -> void:
	if mark_id.is_empty() or World.is_marked(mark_id):
		queue_free()
		return
	collision_layer = 0
	collision_mask = LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(shape)
	body_entered.connect(_on_body_entered)


## Ставит отметку, когда в зону вошёл герой, и убирает зону.
## [param body] - тело, вошедшее в зону.
func _on_body_entered(body: Node2D) -> void:
	if body is Player and not World.is_marked(mark_id):
		World.mark(mark_id)
		SaveSystem.save_game()
		queue_free()
