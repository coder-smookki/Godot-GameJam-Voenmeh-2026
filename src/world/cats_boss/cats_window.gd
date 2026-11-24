class_name CatsWindow
extends Node2D
## Окно кабинета 316 из рисунков художниц: открытое или закрытое, чёрному коту нужно закрытое.
##
## Открытое окно впускает холод: внутрь летят снег и листья, стекло синеет. Когда заражение
## распахивает окно, створки бьют наружу и камера вздрагивает (это делает бой). Закрытое
## отладчиком окно хлопает, с подоконника поднимается пыль. Начало координат - середина
## верхнего края рамы; рама ровно ложится на окно, нарисованное на фоне.

signal shot

const OPEN_TEXTURE: Texture2D = preload("res://assets/props/window_open.png")
const CLOSED_TEXTURE: Texture2D = preload("res://assets/props/window_closed.png")
const ART_SCALE := 1.0
const CONTENT_TOP := 19.0
const OPEN_CENTER := 216.0
const CLOSED_CENTER := 134.0
const GLASS := Rect2(-110.0, 11.0, 220.0, 116.0)
const COLD := Color(0.55, 0.8, 1.0)
const SLAM_SEC := 0.18

var open: bool = true

var _sprite: Sprite2D = null
var _wind: CPUParticles2D = null
var _dust: CPUParticles2D = null
var _clock: float = 0.0
var _cold: float = 1.0


## Собирает рисунок, цель для отладчика, ветер и пыль.
func _ready() -> void:
	z_index = -20
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	add_child(_sprite)
	var target := DebugTarget.new(GLASS.size, GLASS.get_center())
	target.shot.connect(shot.emit)
	add_child(target)
	_wind = CPUParticles2D.new()
	_wind.position = GLASS.get_center()
	_wind.z_index = 40
	_wind.amount = 26
	_wind.lifetime = 2.2
	_wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_wind.emission_rect_extents = GLASS.size * 0.4
	_wind.direction = Vector2(1.0, 0.4)
	_wind.spread = 25.0
	_wind.gravity = Vector2(10.0, 35.0)
	_wind.initial_velocity_min = 40.0
	_wind.initial_velocity_max = 90.0
	_wind.angular_velocity_min = -200.0
	_wind.angular_velocity_max = 200.0
	_wind.scale_amount_min = 1.5
	_wind.scale_amount_max = 3.0
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.5, 0.51, 1.0])
	colors.colors = PackedColorArray(
		[Color.WHITE, Color.WHITE, Color("ffb347"), Color(1.0, 0.6, 0.2, 0.0)]
	)
	_wind.color_initial_ramp = colors
	add_child(_wind)
	_dust = CPUParticles2D.new()
	_dust.position = Vector2(0.0, GLASS.end.y + 8.0)
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 20
	_dust.lifetime = 0.6
	_dust.explosiveness = 1.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(GLASS.size.x * 0.5, 2.0)
	_dust.direction = Vector2.UP
	_dust.spread = 60.0
	_dust.gravity = Vector2(0.0, 80.0)
	_dust.initial_velocity_min = 15.0
	_dust.initial_velocity_max = 45.0
	_dust.color = Color(0.9, 0.85, 0.8, 0.8)
	add_child(_dust)
	set_open(open, false)


## Открывает или закрывает окно.
## [param value] - true, чтобы окно было открыто.
## [param animated] - false ставит состояние сразу, без хлопка.
func set_open(value: bool, animated: bool = true) -> void:
	open = value
	var texture := OPEN_TEXTURE if open else CLOSED_TEXTURE
	_sprite.texture = texture
	var center := OPEN_CENTER if open else CLOSED_CENTER
	_sprite.position = (
		Vector2(texture.get_width() * 0.5 - center, texture.get_height() * 0.5 - CONTENT_TOP)
		* ART_SCALE
	)
	_wind.emitting = open
	if not animated:
		_cold = 1.0 if open else 0.0
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_cold", 1.0 if open else 0.0, 0.6)
	_sprite.scale = Vector2(ART_SCALE * (1.12 if open else 0.94), ART_SCALE)
	tween.tween_property(_sprite, "scale", Vector2(ART_SCALE, ART_SCALE), SLAM_SEC).set_trans(
		Tween.TRANS_BACK
	)
	if not open:
		_dust.restart()


## Перерисовывает холодное стекло.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	if _cold > 0.0:
		queue_redraw()


## Рисует синеву холодного воздуха поверх стекла и полосы ветра.
func _draw() -> void:
	if _cold <= 0.01:
		return
	draw_rect(GLASS, Color(COLD, 0.16 * _cold))
	for line: int in 4:
		var y := GLASS.position.y + 20.0 + line * 28.0
		var x := (
			fposmod(_clock * 120.0 + line * 70.0, GLASS.size.x + 60.0) + GLASS.position.x - 30.0
		)
		draw_line(
			Vector2(x, y), Vector2(x + 24.0, y + 4.0), Color(1.0, 1.0, 1.0, 0.35 * _cold), 1.0
		)
