class_name Player
extends CharacterBody2D
## Герой: ходьба и прыжок с видом сбоку, взаимодействие с объектами и выстрел отладчика.
##
## Начало координат находится у ног. Ввод обрабатывается только когда мир не на паузе.
## Тень и отражение остаются на полу, когда герой прыгает.

const SPEED := 150.0
const ACCELERATION := 1200.0
const JUMP_VELOCITY := -400.0
const GRAVITY := 1300.0
const SHOT_RANGE := 420.0
const WALK_FROM_SPEED := 8.0
const SHOT_COOLDOWN_SEC := 0.25
const SHOT_MASK := 9
const DEBUGGER_MARK := "ability_debugger"
const SHADOW_FADE_HEIGHT := 160.0
const SHADOW_MIN_SCALE := 0.45

var facing: int = 1

var _nearby: Array[Interactable] = []
var _focus: Interactable = null
var _cooldown: float = 0.0
var _shot_requested: bool = false
var _floor_y: float = 0.0
var _landed: bool = false

@onready var _zone: Area2D = $InteractZone
@onready var _muzzle: Marker2D = $Muzzle
@onready var _aim: Aim = $Aim
@onready var _camera: Camera2D = $Camera
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _reflection: AnimatedSprite2D = $Reflection
@onready var _shadow: Node2D = $Shadow


## Подписывается на объекты, которые входят в зону взаимодействия и выходят из неё.
func _ready() -> void:
	_zone.area_entered.connect(_on_zone_area_entered)
	_zone.area_exited.connect(_on_zone_area_exited)


## Возвращает обычную скорость времени, если герой исчезает во время прицеливания.
func _exit_tree() -> void:
	Game.set_slow_motion(false)


## Двигает героя, выбирает ближайший объект и обрабатывает прицел и выстрел.
## [param delta] - шаг физики в секундах.
func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()
	if direction != 0.0:
		facing = 1 if direction > 0.0 else -1
	_update_animation()
	_update_ground_effects()
	_update_focus()
	_update_debugger(delta)


## Обрабатывает прыжок, взаимодействие и выстрел.
## Нажатие, которым игрок закрыл диалог или мини-игру, сюда не доходит: герой от него не прыгает.
## [param event] - событие ввода, не обработанное интерфейсом.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		_shot_requested = true
	elif event.is_action_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
	elif _focus != null and event.is_action_pressed(_focus.action):
		get_viewport().set_input_as_handled()
		_focus.interact(self)


## Ограничивает камеру границами комнаты.
## [param width] - ширина комнаты в пикселях.
## [param height] - высота комнаты в пикселях.
func set_camera_limits(width: int, height: int) -> void:
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = width
	_camera.limit_bottom = height
	_camera.reset_smoothing()


## Поворачивает спрайт по направлению и выбирает анимацию: шаг в движении, стойка на месте.
func _update_animation() -> void:
	_sprite.flip_h = facing < 0
	var walking := is_on_floor() and absf(velocity.x) > WALK_FROM_SPEED
	var animation := &"walk" if walking else &"idle"
	if _sprite.animation != animation:
		_sprite.play(animation)


## Держит тень и отражение на полу и повторяет в отражении кадр героя.
## В прыжке тень уменьшается, а отражение уходит ниже.
func _update_ground_effects() -> void:
	if is_on_floor() or not _landed:
		_floor_y = global_position.y
		_landed = _landed or is_on_floor()
	var lift := maxf(_floor_y - global_position.y, 0.0)
	var shrink := clampf(1.0 - lift / SHADOW_FADE_HEIGHT, SHADOW_MIN_SCALE, 1.0)
	_shadow.global_position.y = _floor_y
	_shadow.scale = Vector2(shrink, shrink)
	_reflection.global_position.y = _floor_y + lift * _reflection.scale.y
	_reflection.flip_h = _sprite.flip_h
	if _reflection.animation != _sprite.animation:
		_reflection.animation = _sprite.animation
	_reflection.frame = _sprite.frame


## Выбирает ближайший объект рядом с героем и переключает подсказки.
func _update_focus() -> void:
	var best: Interactable = null
	var best_distance := INF
	for item: Interactable in _nearby:
		var distance := absf(item.global_position.x - global_position.x)
		if distance < best_distance:
			best = item
			best_distance = distance
	if best == _focus:
		return
	if is_instance_valid(_focus):
		_focus.set_focused(false)
	_focus = best
	if _focus != null:
		_focus.set_focused(true)


## Включает режим отладчика, пока зажата клавиша, и выполняет запрошенный выстрел.
## [param delta] - шаг физики в секундах.
func _update_debugger(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var aiming := Input.is_action_pressed("debugger") and World.is_marked(DEBUGGER_MARK)
	Game.set_slow_motion(aiming)
	_aim.set_aiming(aiming, _muzzle.position)
	if _shot_requested and aiming and _cooldown <= 0.0:
		_shoot()
	_shot_requested = false


## Стреляет лучом отладчика в сторону курсора и сообщает цели о попадании.
func _shoot() -> void:
	_cooldown = SHOT_COOLDOWN_SEC
	var from := _muzzle.global_position
	var to := from + (get_global_mouse_position() - from).normalized() * SHOT_RANGE
	var query := PhysicsRayQueryParameters2D.create(from, to, SHOT_MASK)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	var end: Vector2 = result.get("position", to)
	_aim.flash(_muzzle.position, to_local(end))
	if not result.is_empty() and result["collider"].has_method("hit"):
		result["collider"].hit()


## Запоминает объект, вошедший в зону взаимодействия.
## [param area] - область, которая вошла в зону.
func _on_zone_area_entered(area: Area2D) -> void:
	if area is Interactable and area not in _nearby:
		_nearby.append(area)


## Забывает объект, вышедший из зоны взаимодействия.
## [param area] - область, которая вышла из зоны.
func _on_zone_area_exited(area: Area2D) -> void:
	_nearby.erase(area)
