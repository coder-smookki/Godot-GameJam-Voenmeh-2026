class_name Blast
extends Node2D
## Кольцо взрыва: белый круг быстро расходится, тускнеет и исчезает.

const RADIUS := 70.0
const SEC := 0.45
const CORE := Color(1.0, 0.95, 0.75)

var _progress: float = 0.0


## Запускает расширение кольца и убирает узел после него.
func _ready() -> void:
	z_index = 28
	var tween := create_tween()
	tween.tween_property(self, "_progress", 1.0, SEC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


## Перерисовывает кольцо каждый кадр, пока оно растёт.
## [param _delta] - время кадра; кольцо читает долю из анимации.
func _process(_delta: float) -> void:
	queue_redraw()


## Рисует вспышку в центре и расходящееся кольцо.
func _draw() -> void:
	var fade := 1.0 - _progress
	draw_circle(Vector2.ZERO, RADIUS * 0.45 * fade, Color(CORE, fade))
	draw_arc(Vector2.ZERO, RADIUS * _progress, 0.0, TAU, 32, Color(CORE, fade), 4.0 * fade + 1.0)
