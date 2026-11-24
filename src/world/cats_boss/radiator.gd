class_name Radiator
extends Node2D
## Батарея в кабинете 316, нарисованная в коде: от неё зависит, тепло ли рыжему коту.
##
## Рёбра батареи краснеют по мере нагрева, вокруг светится ореол, вверх тянется дрожащий
## тёплый воздух. Попадание отладчика вспыхивает и выпускает клуб пара. Начало координат -
## середина низа батареи на полу.

signal shot

const SIZE := Vector2(60.0, 34.0)
const LIFT := 8.0
const RIBS := 7
const COLD := Color("8a93a8")
const HOT := Color("ff5a2a")
const PIPE := Color("5a6378")
const GLOW := Color(1.0, 0.45, 0.15)
const FLASH_SEC := 0.3

var heat: float = 0.0

var _clock: float = 0.0
var _flash: float = 0.0
var _air: CPUParticles2D = null
var _steam: CPUParticles2D = null


## Создаёт цель для отладчика, тёплый воздух и пар.
func _ready() -> void:
	z_index = -5
	var target := DebugTarget.new(SIZE + Vector2(10.0, 10.0), Vector2(0.0, -LIFT - SIZE.y * 0.5))
	target.shot.connect(shot.emit)
	add_child(target)
	_air = CPUParticles2D.new()
	_air.position = Vector2(0.0, -LIFT - SIZE.y)
	_air.amount = 14
	_air.lifetime = 1.4
	_air.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_air.emission_rect_extents = Vector2(SIZE.x * 0.45, 2.0)
	_air.direction = Vector2.UP
	_air.spread = 8.0
	_air.gravity = Vector2(0.0, -12.0)
	_air.initial_velocity_min = 10.0
	_air.initial_velocity_max = 22.0
	_air.tangential_accel_min = -20.0
	_air.tangential_accel_max = 20.0
	_air.scale_amount_min = 1.0
	_air.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.8, 0.55, 0.5))
	fade.set_color(1, Color(1.0, 0.8, 0.55, 0.0))
	_air.color_ramp = fade
	add_child(_air)
	_steam = CPUParticles2D.new()
	_steam.position = _air.position
	_steam.emitting = false
	_steam.one_shot = true
	_steam.amount = 16
	_steam.lifetime = 0.8
	_steam.explosiveness = 0.9
	_steam.direction = Vector2.UP
	_steam.spread = 50.0
	_steam.gravity = Vector2(0.0, -40.0)
	_steam.initial_velocity_min = 20.0
	_steam.initial_velocity_max = 60.0
	_steam.scale_amount_min = 2.0
	_steam.scale_amount_max = 4.0
	_steam.color = Color(1.0, 1.0, 1.0, 0.7)
	add_child(_steam)


## Вспыхивает и пускает пар: батарею подкрутили отладчиком.
func pulse() -> void:
	_flash = FLASH_SEC
	_steam.restart()


## Ведёт тепло, вспышку и тёплый воздух.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	_flash = maxf(_flash - delta, 0.0)
	_air.emitting = heat > 0.2
	_air.modulate.a = clampf(heat, 0.2, 1.0)
	queue_redraw()


## Рисует ореол, трубы и рёбра батареи.
func _draw() -> void:
	var body := Rect2(Vector2(-SIZE.x * 0.5, -LIFT - SIZE.y), SIZE)
	if heat > 0.05:
		var pulse := 0.8 + 0.2 * sin(_clock * 3.0)
		for ring: int in 3:
			var glow := Color(GLOW, 0.08 * heat * pulse * (3 - ring))
			draw_rect(body.grow(4.0 + ring * 5.0), glow)
	draw_rect(Rect2(body.position + Vector2(-6.0, SIZE.y - 8.0), Vector2(SIZE.x + 12.0, 4.0)), PIPE)
	draw_rect(Rect2(Vector2(-SIZE.x * 0.5 + 4.0, -LIFT), Vector2(3.0, LIFT)), PIPE)
	draw_rect(Rect2(Vector2(SIZE.x * 0.5 - 7.0, -LIFT), Vector2(3.0, LIFT)), PIPE)
	var color := COLD.lerp(HOT, heat)
	if _flash > 0.0:
		color = color.lerp(Color.WHITE, _flash / FLASH_SEC)
	var rib := SIZE.x / RIBS
	for index: int in RIBS:
		var cell := Rect2(
			body.position + Vector2(index * rib + 1.0, 0.0), Vector2(rib - 2.0, SIZE.y)
		)
		draw_rect(cell, color.darkened(0.35))
		draw_rect(cell.grow(-1.0), color)
		draw_rect(
			Rect2(cell.position + Vector2(2.0, 3.0), Vector2(1.0, SIZE.y - 6.0)),
			color.lightened(0.3)
		)
