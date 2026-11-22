@tool
class_name Pill
extends Node2D
## Заглушка персонажа в виде цветной «пилюли», как на макетах дизайн-документа.
##
## Стоит на месте будущего спрайта: начало координат находится у ног.
## Когда появится арт, узел заменяется на спрайт без правки кода.

@export var size: Vector2 = Vector2(12.0, 38.0):
	set(value):
		size = value
		queue_redraw()
@export var color: Color = Color("6b7280"):
	set(value):
		color = value
		queue_redraw()


## Рисует капсулу заданного размера и цвета: вертикальную или горизонтальную.
func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	if size.x > size.y:
		draw_rect(Rect2(-size.x * 0.5 + radius, -size.y, size.x - radius * 2.0, size.y), color)
		draw_circle(Vector2(-size.x * 0.5 + radius, -radius), radius, color)
		draw_circle(Vector2(size.x * 0.5 - radius, -radius), radius, color)
	else:
		draw_rect(Rect2(-size.x * 0.5, -size.y + radius, size.x, size.y - radius * 2.0), color)
		draw_circle(Vector2(0.0, -size.y + radius), radius, color)
		draw_circle(Vector2(0.0, -radius), radius, color)
