class_name Glint
extends Control
## Блик на стекле или металле: светлая косая полоса время от времени пробегает по поверхности.
##
## Размер узла задаёт поверхность; всё, что выходит за неё, обрезается.

const COLOR := Color(1.0, 1.0, 1.0, 0.16)

@export var band_width: float = 14.0
@export var slant: float = 22.0
@export var sweep_sec: float = 0.9
@export var pause_sec: float = 4.5
@export var delay_sec: float = 0.0

var _phase: float = 0.0


## Включает обрезку по границам и запускает повторяющийся пробег блика.
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween().set_loops()
	tween.tween_interval(maxf(delay_sec, 0.01))
	tween.tween_method(_set_phase, 0.0, 1.0, sweep_sec)
	tween.tween_interval(pause_sec)


## Рисует две косые полосы: широкую и узкую.
func _draw() -> void:
	if _phase <= 0.0 or _phase >= 1.0:
		return
	var travel := size.x + slant + band_width * 2.0
	var left := -slant - band_width * 2.0 + travel * _phase
	_draw_band(left, band_width)
	_draw_band(left + band_width * 1.4, band_width * 0.3)


## Рисует одну косую полосу от верха до низа поверхности.
## [param left] - координата x нижнего левого угла полосы.
## [param width] - ширина полосы.
func _draw_band(left: float, width: float) -> void:
	var points := PackedVector2Array(
		[
			Vector2(left + slant, 0.0),
			Vector2(left + slant + width, 0.0),
			Vector2(left + width, size.y),
			Vector2(left, size.y),
		]
	)
	draw_colored_polygon(points, COLOR)


## Запоминает положение блика и перерисовывает его.
## [param phase] - от 0 (слева за краем) до 1 (справа за краем).
func _set_phase(phase: float) -> void:
	_phase = phase
	queue_redraw()
