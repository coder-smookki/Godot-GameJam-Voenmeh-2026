class_name BossFight
extends Node2D
## Общая основа боёв с боссами: своя камера, чёрные полосы, экран боя и короткие эффекты.
##
## Бой - один узел в комнате. Камера боя создаётся выключенной (включённая камера, которая
## входит в дерево раньше камеры героя, забирает кадр) и включается только на сцены и сам бой;
## она и её движения работают и на паузе, чтобы двигаться во время разговора. Чёрные полосы
## сверху и снизу видны, когда камера отдалена. Наследники описывают ход своего боя.

const VIEW_Y := 135.0
const ARENA_HEIGHT := 270.0
const PLAY_ZOOM := 0.5
const SCENE_ZOOM := 1.0
const FOLLOW_RATE := 5.0

var arena_width: float = 1700.0

var _player: Player = null
var _hud: BossHud = null
var _director: Camera2D = null
var _shake: Tween = null
var _move: Tween = null


## Возвращает камеру боя; нужно тестам.
func director() -> Camera2D:
	return _director


## Создаёт выключенную камеру боя: по горизонтали она не выходит за комнату, по вертикали
## стоит на середине, чтобы при отдалении сверху и снизу были чёрные полосы.
## [param at] - куда камера смотрит сначала.
func _build_director(at: Vector2) -> void:
	_director = Camera2D.new()
	_director.enabled = false
	_director.process_mode = Node.PROCESS_MODE_ALWAYS
	_director.limit_left = 0
	_director.limit_right = int(arena_width)
	_director.limit_top = -10000
	_director.limit_bottom = 10000
	_director.global_position = at
	add_child(_director)


## Создаёт чёрные полосы над и под комнатой, видные при отдалённой камере.
func _build_bars() -> void:
	for top: float in [-1000.0, ARENA_HEIGHT]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.position = Vector2(-500.0, top)
		bar.size = Vector2(arena_width + 1000.0, 1000.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.z_index = 50
		add_child(bar)


## Создаёт экран боя поверх игры на своём слое; он спрятан до начала боя.
## Возвращает слой, на который можно положить и другие части экрана боя.
func _build_hud() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud = BossHud.new()
	_hud.hide()
	layer.add_child(_hud)
	return layer


## Ведёт камеру боя за героем по горизонтали.
## [param delta] - время кадра в секундах.
func _follow_hero(delta: float) -> void:
	var follow := 1.0 - exp(-FOLLOW_RATE * delta)
	_director.global_position.x = lerpf(
		_director.global_position.x, _player.global_position.x, follow
	)


## Возвращает точку, куда смотрит камера героя, чтобы передать ей кадр без скачка.
func _hero_view() -> Vector2:
	return Vector2(clampf(_player.global_position.x, 240.0, arena_width - 240.0), VIEW_Y)


## Плавно переводит камеру боя в точку и меняет увеличение; работает и на паузе (в разговоре).
## [param to] - точка, куда смотрит камера.
## [param sec] - длительность в секундах.
## [param zoom] - новое увеличение; меньше нуля оставляет прежнее.
func _pan(to: Vector2, sec: float, zoom: float = -1.0) -> void:
	if _move != null and _move.is_valid():
		_move.kill()
	_move = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_move.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move.tween_property(_director, "global_position", to, sec)
	if zoom > 0.0:
		_move.tween_property(_director, "zoom", Vector2(zoom, zoom), sec)
	await _move.finished


## Ждёт указанное время игры.
## [param sec] - сколько секунд ждать.
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


## Трясёт камеру боя; дрожь затухает сама.
## [param strength] - наибольшее смещение в пикселях.
## [param sec] - длительность дрожи.
func _shake_camera(strength: float, sec: float) -> void:
	if _shake != null and _shake.is_valid():
		_shake.kill()
	_shake = create_tween()
	_shake.tween_method(_set_offset, strength, 0.0, sec)


## Смещает камеру боя на случайный вектор.
## [param strength] - длина смещения.
func _set_offset(strength: float) -> void:
	_director.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength


## Включает или выключает управление героем.
## [param frozen] - true забирает управление.
func _freeze(frozen: bool) -> void:
	if is_instance_valid(_player):
		_player.set_controls(not frozen)


## Делает камеру боя текущей.
func _take_view() -> void:
	_director.enabled = true
	_director.make_current()


## Возвращает кадр камере героя и выключает камеру боя.
func _give_view() -> void:
	if is_instance_valid(_player):
		_player.take_camera()
	_director.enabled = false
	_director.zoom = Vector2.ONE
	get_parent().texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE


## Закрывает или открывает дверь из комнаты на время боя.
## [param door] - дверь; null ничего не делает.
## [param locked] - true не даёт выйти.
func _lock_door(door: Door, locked: bool) -> void:
	if door != null:
		door.set_deferred("monitorable", not locked)


## Выбрасывает горсть частиц одного цвета.
## [param at] - откуда.
## [param color] - цвет.
## [param amount] - сколько частиц.
## [param speed] - наибольшая скорость.
## [param small] - наименьший размер.
## [param big] - наибольший размер.
func _burst(at: Vector2, color: Color, amount: int, speed: float, small: float, big: float) -> void:
	var sparks := CPUParticles2D.new()
	sparks.global_position = at
	sparks.amount = amount
	sparks.lifetime = 0.8
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.spread = 180.0
	sparks.gravity = Vector2(0.0, 300.0)
	sparks.initial_velocity_min = speed * 0.3
	sparks.initial_velocity_max = speed
	sparks.scale_amount_min = small
	sparks.scale_amount_max = big
	sparks.color = color
	sparks.z_index = 30
	sparks.finished.connect(sparks.queue_free)
	add_child(sparks)
	sparks.emitting = true


## Слетающие клетки заражения в момент, когда человек или вещь освобождается.
## [param at] - середина фигуры.
func _cure_burst(at: Vector2) -> void:
	_burst(at, Color(1.0, 0.0, 1.0), 24, 160.0, 2.0, 4.0)
	_burst(at, Color(0.0, 0.07, 0.0), 16, 140.0, 2.0, 4.0)
	_burst(at, Color.WHITE, 12, 90.0, 1.0, 3.0)


## Собирает переход цветов «розовый - тёмный» для клеток шахматки.
func _checker_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.0, 1.0))
	ramp.set_color(1, Color(0.0, 0.07, 0.0, 0.0))
	return ramp
