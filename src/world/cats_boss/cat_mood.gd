class_name CatMood
extends Node2D
## Облачко над котом: чего он хочет и доволен ли он.
##
## Недовольный кот показывает своё желание значком (снежинка - холодно, миска - голоден,
## ветер - открыто окно) в красной рамке и дрожит, рядом мигает «!». Довольный кот показывает
## сердце в зелёной рамке, и над ним время от времени всплывают сердечки. Облачко покачивается,
## а при смене настроения подпрыгивает.

enum Want { HEAT, FOOD, WINDOW }

const BOX := Vector2(17.0, 15.0)
const TAIL := 4.0
const PAPER := Color("f7f3e8")
const INK := Color("14161d")
const GOOD := Color("2ea043")
const BAD := Color("d81e1e")
const SNOW := Color("7fd8ff")
const BOB := 1.5
const BOB_RATE := 3.0
const HEART_SEC := 0.9
const POP_SEC := 0.18

var want: Want = Want.HEAT
var happy: bool = false

var _clock: float = 0.0
var _heart_left: float = 0.0
var _hearts: CPUParticles2D = null


## Готовит всплывающие сердечки.
func _ready() -> void:
	z_index = 35
	_hearts = CPUParticles2D.new()
	_hearts.emitting = false
	_hearts.one_shot = true
	_hearts.amount = 3
	_hearts.lifetime = 0.9
	_hearts.explosiveness = 0.6
	_hearts.direction = Vector2.UP
	_hearts.spread = 30.0
	_hearts.gravity = Vector2(0.0, -30.0)
	_hearts.initial_velocity_min = 10.0
	_hearts.initial_velocity_max = 25.0
	_hearts.scale_amount_min = 2.0
	_hearts.scale_amount_max = 3.0
	_hearts.color = Hearts.FULL
	_hearts.position = Vector2(0.0, -BOX.y - TAIL)
	add_child(_hearts)


## Меняет настроение кота; облачко подпрыгивает.
## [param value] - true, если кот доволен.
func set_happy(value: bool) -> void:
	if value == happy:
		return
	happy = value
	scale = Vector2(1.35, 1.35)
	create_tween().tween_property(self, "scale", Vector2.ONE, POP_SEC)
	if happy:
		_hearts.restart()


## Покачивает облачко и время от времени выпускает сердечки над довольным котом.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	if happy:
		_heart_left -= delta
		if _heart_left <= 0.0:
			_heart_left = HEART_SEC
			_hearts.restart()
	queue_redraw()


## Рисует облачко со значком.
func _draw() -> void:
	var shake := 0.0 if happy else roundf(sin(_clock * 40.0)) * 0.6
	var top := Vector2(-BOX.x * 0.5 + shake, -BOX.y - TAIL + roundf(sin(_clock * BOB_RATE) * BOB))
	var box := Rect2(top.round(), BOX)
	var border := GOOD if happy else BAD
	draw_rect(box.grow(1.0), border)
	draw_rect(box, PAPER)
	var tail := PackedVector2Array(
		[
			box.end - Vector2(BOX.x * 0.5 + 3.0, 0.0),
			box.end - Vector2(BOX.x * 0.5 - 3.0, 0.0),
			Vector2(box.get_center().x, box.end.y + TAIL)
		]
	)
	draw_colored_polygon(tail, border)
	var icon := box.position + Vector2(4.0, 3.0)
	if happy:
		Hearts.draw_heart(self, icon, Hearts.FULL)
	else:
		_draw_want(icon)
		if int(_clock * 3.0) % 2 == 0:
			draw_rect(Rect2(box.end + Vector2(2.0, -BOX.y), Vector2(2.0, 6.0)), BAD)
			draw_rect(Rect2(box.end + Vector2(2.0, -BOX.y + 8.0), Vector2(2.0, 2.0)), BAD)


## Рисует значок желания: снежинку, миску или ветер.
## [param at] - левый верхний угол значка 9x9.
func _draw_want(at: Vector2) -> void:
	match want:
		Want.HEAT:
			draw_rect(Rect2(at + Vector2(4.0, 0.0), Vector2(1.0, 9.0)), SNOW)
			draw_rect(Rect2(at + Vector2(0.0, 4.0), Vector2(9.0, 1.0)), SNOW)
			for step: int in 7:
				draw_rect(Rect2(at + Vector2(1.0 + step, 1.0 + step), Vector2.ONE), SNOW)
				draw_rect(Rect2(at + Vector2(7.0 - step, 1.0 + step), Vector2.ONE), SNOW)
		Want.FOOD:
			draw_rect(Rect2(at + Vector2(0.0, 5.0), Vector2(9.0, 2.0)), Color("8a93a8"))
			draw_rect(Rect2(at + Vector2(1.0, 7.0), Vector2(7.0, 1.0)), Color("5a6378"))
			draw_rect(Rect2(at + Vector2(3.0, 1.0), Vector2(1.0, 3.0)), INK)
			draw_rect(Rect2(at + Vector2(5.0, 1.0), Vector2(1.0, 3.0)), INK)
		Want.WINDOW:
			for row: int in 3:
				var length := 7.0 - row * 2.0
				var y := 1.0 + row * 3.0
				var x := fmod(_clock * 12.0 + row * 3.0, 3.0)
				draw_rect(Rect2(at + Vector2(x, y), Vector2(length, 1.0)), Color("5a6378"))
