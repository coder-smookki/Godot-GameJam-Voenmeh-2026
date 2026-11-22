@tool
class_name Shadow
extends Node2D
## Мягкая тень под персонажем или предметом: тёмный овал на полу.
##
## Начало координат - середина тени, её ставят к ногам.

const COLOR := Color(0.0, 0.0, 0.0, 0.28)
const POINTS := 20

@export var radius: Vector2 = Vector2(24.0, 4.0):
	set(value):
		radius = value
		queue_redraw()


## Рисует овал заданного размера.
func _draw() -> void:
	var points := PackedVector2Array()
	for index: int in POINTS:
		var angle := TAU * float(index) / float(POINTS)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, COLOR)
