class_name RunnerCrowd
extends Node2D
## Паника в коридоре: тёмные размытые фигуры бегают туда-сюда.
##
## Фигуры нарисованы художницей шестью кадрами бега. Когда герой подходит к тому, кто
## объяснит происходящее, толпа растворяется. После отметки gone_mark толпы больше нет.

signal vanished

const FRAMES: Array[Texture2D] = [
	preload("res://assets/characters/runners/run_1.png"),
	preload("res://assets/characters/runners/run_2.png"),
	preload("res://assets/characters/runners/run_3.png"),
	preload("res://assets/characters/runners/run_4.png"),
	preload("res://assets/characters/runners/run_5.png"),
	preload("res://assets/characters/runners/run_6.png"),
]
const FRAME_OFFSET := Vector2(-86.0, -169.0)
const FRAME_SEC := 0.07
const SPEED_MIN := 150.0
const SPEED_MAX := 260.0
const TURN_CHANCE_PER_SEC := 0.25
const TINT := Color(1.0, 1.0, 1.0, 0.82)
const FADE_SEC := 0.6

@export var count: int = 7
@export var left: float = 400.0
@export var right: float = 2000.0
@export var gone_mark: String = ""
@export var vanish_x: float = 0.0
@export var vanish_distance: float = 380.0
@export var seed_value: int = 404

var _runners: Array[Sprite2D] = []
var _speeds: Array[float] = []
var _clocks: Array[float] = []
var _random := RandomNumberGenerator.new()
var _leaving: bool = false


## Убирает толпу, если паника уже прошла, иначе расставляет бегущих по коридору.
func _ready() -> void:
	if not gone_mark.is_empty() and World.is_marked(gone_mark):
		queue_free()
		return
	_random.seed = seed_value
	for index: int in count:
		var runner := Sprite2D.new()
		runner.texture = FRAMES[_random.randi() % FRAMES.size()]
		runner.centered = false
		runner.offset = FRAME_OFFSET
		runner.modulate = TINT
		runner.position.x = _random.randf_range(left, right)
		runner.flip_h = _random.randf() < 0.5
		add_child(runner)
		_runners.append(runner)
		_speeds.append(_random.randf_range(SPEED_MIN, SPEED_MAX))
		_clocks.append(_random.randf_range(0.0, FRAME_SEC))


## Сообщает, сколько фигур сейчас бегает.
func size() -> int:
	return _runners.size()


## Растворяет всю толпу.
func vanish() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	tween.tween_callback(_finish)


## Двигает фигуры, меняет кадры бега и следит, не подошёл ли герой к цели.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	for index: int in _runners.size():
		_step(index, delta)
	var room := get_tree().current_scene as Room
	if room != null and is_instance_valid(room.player):
		if absf(room.player.global_position.x - vanish_x) <= vanish_distance:
			vanish()


## Двигает одну фигуру: бег, разворот у края или случайный разворот посреди коридора.
## [param index] - номер фигуры.
## [param delta] - время кадра в секундах.
func _step(index: int, delta: float) -> void:
	var runner := _runners[index]
	var direction := 1.0 if runner.flip_h else -1.0
	runner.position.x += direction * _speeds[index] * delta
	var turn := _random.randf() < TURN_CHANCE_PER_SEC * delta
	if runner.position.x < left or runner.position.x > right or turn:
		runner.position.x = clampf(runner.position.x, left, right)
		runner.flip_h = not runner.flip_h
	_clocks[index] += delta
	if _clocks[index] >= FRAME_SEC:
		_clocks[index] -= FRAME_SEC
		var next := (FRAMES.find(runner.texture) + 1) % FRAMES.size()
		runner.texture = FRAMES[next]


## Убирает толпу после растворения.
func _finish() -> void:
	vanished.emit()
	queue_free()
