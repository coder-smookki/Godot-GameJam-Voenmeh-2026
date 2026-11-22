class_name Flicker
extends CanvasItem
## Мерцание света: узел то ярче, то тусклее, как неисправная лампа или вывеска.
##
## Вешается на любой видимый узел: пятно света, табличку, кнопку.

@export var alpha_min: float = 0.25
@export var alpha_max: float = 0.6
@export var tick_sec: float = 0.11
@export var dip_chance: float = 0.12


## Запускает таймер мерцания.
func _ready() -> void:
	modulate.a = alpha_max
	var timer := Timer.new()
	timer.wait_time = tick_sec
	timer.timeout.connect(_on_tick)
	add_child(timer)
	timer.start()


## Изредка роняет яркость и плавно возвращает её обратно.
func _on_tick() -> void:
	if randf() < dip_chance:
		modulate.a = alpha_min
	else:
		modulate.a = move_toward(modulate.a, alpha_max, (alpha_max - alpha_min) * 0.5)
