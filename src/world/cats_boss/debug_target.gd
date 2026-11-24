class_name DebugTarget
extends StaticBody2D
## Невидимая цель для луча отладчика: окно, миска, батарея в бою кабинета 316.
##
## Тело лежит только на слое «shootable», поэтому герой сквозь него проходит, а луч отладчика
## в него попадает. Попадание просто сообщается сигналом; что из него следует, решает бой.

signal shot

const LAYER_SHOOTABLE := 8


## Создаёт тело цели нужного размера.
## [param size] - размер прямоугольника в пикселях.
## [param center] - середина прямоугольника относительно узла.
func _init(size: Vector2 = Vector2(40.0, 40.0), center: Vector2 = Vector2.ZERO) -> void:
	collision_layer = LAYER_SHOOTABLE
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = center
	add_child(shape)


## Сообщает о попадании луча отладчика.
func hit() -> void:
	shot.emit()
