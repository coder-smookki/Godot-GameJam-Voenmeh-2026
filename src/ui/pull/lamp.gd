class_name Lamp
extends Control
## Круглая лампочка-индикатор: тёмная, пока выключена, и светится с ореолом, когда горит.

const PULSE_SEC := 0.4

@export var color: Color = Palette.DANGER

var lit: bool = false:
	set(value):
		if lit == value:
			return
		lit = value
		_pulse()
		queue_redraw()

var _tween: Tween = null


## Рисует кружок: приглушённый или яркий с ореолом.
func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 2.0
	if lit:
		draw_circle(center, radius + 2.0, Color(color, 0.35))
		draw_circle(center, radius, color)
		draw_circle(center - Vector2(1.0, 1.0), 1.0, Color(1.0, 1.0, 1.0, 0.8))
	else:
		draw_circle(center, radius, color.darkened(0.72))


## Запускает или останавливает мерцание горящей лампочки.
func _pulse() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate = Color.WHITE
	if not lit:
		return
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "modulate", Color(1.5, 1.2, 1.2), PULSE_SEC)
	_tween.tween_property(self, "modulate", Color.WHITE, PULSE_SEC)
