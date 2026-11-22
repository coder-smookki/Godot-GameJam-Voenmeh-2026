class_name Player
extends CharacterBody2D
## Герой: ходьба и прыжок с видом сбоку, взаимодействие с объектами и выстрел отладчика.
##
## Начало координат находится у ног. Ввод обрабатывается только когда мир не на паузе.
## Тень и отражение остаются на полу, когда герой прыгает. Толчок, приземление и шаги
## поднимают пыль, а спрайт на мгновение вытягивается и сплющивается. Шахматка и надпись ERROR
## могут отбросить героя: на короткое время он не слушается клавиш и краснеет.

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
const LAND_SEC := 0.12
const LAND_PUFF_FROM_SEC := 0.15
const JUMP_STRETCH := Vector2(0.9, 1.08)
const LAND_SQUASH := Vector2(1.1, 0.9)
const SQUASH_SEC := 0.2
const STEP_BACK := 10.0
const WALK := &"walk"
const ANNOUNCE_Y := -196.0
const ANNOUNCE_RISE := 8.0
const ANNOUNCE_SCREEN_TOP := 56.0
const ANNOUNCE_SEC := 2.2
const ANNOUNCE_FADE_SEC := 0.5
const KNOCK_SEC := 0.45
const KNOCK_BRAKE := 0.3
const KNOCK_TINT := Color(1.8, 0.55, 0.55)

var facing: int = 1

var _nearby: Array[Interactable] = []
var _focus: Interactable = null
var _cooldown: float = 0.0
var _shot_requested: bool = false
var _floor_y: float = 0.0
var _landed: bool = false
var _airborne: bool = false
var _land_left: float = 0.0
var _air_sec: float = 0.0
var _squash: Tween = null
var _stun: float = 0.0

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
	_sprite.frame_changed.connect(_on_sprite_frame_changed)


## Возвращает обычную скорость времени, если герой исчезает во время прицеливания.
func _exit_tree() -> void:
	Game.set_slow_motion(false)


## Двигает героя, выбирает ближайший объект и обрабатывает прицел и выстрел.
## [param delta] - шаг физики в секундах.
func _physics_process(delta: float) -> void:
	var direction := 0.0 if _stun > 0.0 else Input.get_axis("move_left", "move_right")
	var brake := KNOCK_BRAKE if _stun > 0.0 else 1.0
	_stun = maxf(_stun - delta, 0.0)
	velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * brake * delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()
	if direction != 0.0:
		facing = 1 if direction > 0.0 else -1
	_update_animation(delta)
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
			_kick_up_dust(JUMP_STRETCH)
	elif _focus != null and event.is_action_pressed(_focus.action):
		get_viewport().set_input_as_handled()
		_focus.interact(self)


## Плавно приближает или отдаляет камеру; работает и когда мир стоит на паузе.
## [param zoom] - увеличение: 1 обычный вид, больше 1 ближе к герою.
## [param sec] - длительность перехода в секундах.
func zoom_camera(zoom: float, sec: float) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_camera, "zoom", Vector2(zoom, zoom), sec)


## Коротко встряхивает камеру; дрожь затухает сама.
## [param strength] - наибольшее смещение в пикселях.
## [param sec] - длительность дрожи в секундах.
func shake_camera(strength: float, sec: float) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_shake, strength, 0.0, sec)


## Отбрасывает героя: он отлетает, на миг краснеет и не слушается клавиш.
## [param push] - скорость толчка в пикселях в секунду; отрицательный y подбрасывает вверх.
func knock_back(push: Vector2) -> void:
	velocity = push
	_stun = KNOCK_SEC
	if push.x != 0.0:
		facing = -1 if push.x > 0.0 else 1
	_sprite.modulate = KNOCK_TINT
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, KNOCK_SEC)
	shake_camera(4.0, 0.25)


## Сообщает, летит ли герой после толчка и не слушается клавиш.
func is_stunned() -> bool:
	return _stun > 0.0


## Показывает над головой героя плашку с полученной вещью или умением; она всплывает и гаснет.
## Плашка не заходит выше полосы, где интерфейс показывает задание и сообщения.
## [param text] - готовый текст плашки.
func announce(text: String) -> void:
	var plate := Label.new()
	plate.text = text
	plate.top_level = true
	plate.z_index = 60
	plate.add_theme_color_override("font_color", Palette.GOAL)
	plate.add_theme_stylebox_override("normal", Palette.frame(Palette.GOAL))
	add_child(plate)
	plate.reset_size()
	var start := global_position + Vector2(-plate.size.x * 0.5, ANNOUNCE_Y)
	var view := get_viewport().get_canvas_transform()
	var on_screen := view * start
	on_screen.y = maxf(on_screen.y, ANNOUNCE_SCREEN_TOP + ANNOUNCE_RISE)
	start = view.affine_inverse() * on_screen
	plate.global_position = start
	plate.scale = Vector2(0.6, 0.6)
	plate.pivot_offset = plate.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(plate, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tween.tween_property(plate, "global_position:y", start.y - ANNOUNCE_RISE, ANNOUNCE_SEC)
	tween.chain().tween_property(plate, "modulate:a", 0.0, ANNOUNCE_FADE_SEC)
	tween.chain().tween_callback(plate.queue_free)


## Ограничивает камеру границами комнаты.
## [param width] - ширина комнаты в пикселях.
## [param height] - высота комнаты в пикселях.
func set_camera_limits(width: int, height: int) -> void:
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = width
	_camera.limit_bottom = height
	_camera.reset_smoothing()


## Смещает камеру на случайный вектор заданной длины.
## [param strength] - наибольшее смещение в пикселях; ноль возвращает камеру на место.
func _set_shake(strength: float) -> void:
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength


## Поворачивает спрайт по направлению и выбирает анимацию: полёт в прыжке, присед сразу
## после приземления, шаг в движении, стойка на месте.
## [param delta] - шаг физики в секундах.
func _update_animation(delta: float) -> void:
	_sprite.flip_h = facing < 0
	if is_on_floor() and _airborne:
		_land_left = LAND_SEC
		if _air_sec > LAND_PUFF_FROM_SEC:
			_kick_up_dust(LAND_SQUASH)
	_airborne = not is_on_floor()
	_air_sec = _air_sec + delta if _airborne else 0.0
	_land_left = maxf(_land_left - delta, 0.0)
	var animation := &"idle"
	if _airborne:
		animation = &"jump"
	elif _land_left > 0.0:
		animation = &"land"
	elif absf(velocity.x) > WALK_FROM_SPEED:
		animation = WALK
	if _sprite.animation != animation:
		_sprite.play(animation)


## Поднимает облачко пыли у ног и на мгновение меняет пропорции спрайта.
## [param shape] - масштаб спрайта в первый момент: вытянутый при толчке, сплющенный при посадке.
func _kick_up_dust(shape: Vector2) -> void:
	Puff.spawn(get_parent(), global_position)
	if _squash != null and _squash.is_valid():
		_squash.kill()
	_sprite.scale = shape
	_squash = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_squash.tween_property(_sprite, "scale", Vector2.ONE, SQUASH_SEC)


## Пускает пару пылинок из-под ноги на каждом втором кадре шага.
func _on_sprite_frame_changed() -> void:
	if _sprite.animation == WALK and _sprite.frame % 2 == 0 and is_on_floor():
		var heel := global_position - Vector2(STEP_BACK * facing, 0.0)
		Puff.spawn(get_parent(), heel, Puff.STEP_AMOUNT)


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
