class_name Walker
extends Node2D
## Персонаж для сцен: идёт по кадрам шага, стоит, говорит и показывает особые позы.
##
## Кадры художниц смотрят в одну сторону (faces_right); при ходьбе персонаж поворачивается
## по направлению. Может идти в точку ([method walk_to]) или следовать за героем на
## расстоянии ([method follow]). Если задан speaker, на своих репликах в разговоре он
## показывает кадр talk. Живёт и на паузе, чтобы двигаться в сценах с разговорами.
## Начало координат - ступни.

const STEP_FPS := 8.0
const FOLLOW_SPEED := 150.0
const FOLLOW_GAP := 70.0
const FOLLOW_START := 20.0

@export var walk_frames: Array[Texture2D] = []
@export var stand: Texture2D = null
@export var talk: Texture2D = null
@export var faces_right: bool = true
@export var speaker: String = ""
@export var speed: float = 110.0

var _sprite: Sprite2D = null
var _shadow: Node2D = null
var _clock: float = 0.0
var _walking: bool = false
var _hero: Node2D = null
var _pose: Texture2D = null


## Создаёт рисунок и тень и слушает разговоры.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shadow = Node2D.new()
	_shadow.set_script(load("res://src/world/effects/shadow.gd"))
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	_show(stand)
	if not speaker.is_empty():
		Ui.dialogue.line_shown.connect(_on_line_shown)
		Ui.dialogue.visibility_changed.connect(_on_dialogue_toggled)


## Шагает к точке и ждёт, пока не дойдёт.
## [param x] - куда идти по полу.
## [param pace] - скорость в пикселях в секунду; ноль берёт обычную.
func walk_to(x: float, pace: float = 0.0) -> void:
	_hero = null
	var distance := absf(x - position.x)
	if distance < 1.0:
		return
	face(x - position.x)
	_walking = true
	var walk := create_tween()
	walk.tween_property(self, "position:x", x, distance / (pace if pace > 0.0 else speed))
	await walk.finished
	_walking = false
	_show(_pose if _pose != null else stand)


## Начинает идти за героем на небольшом расстоянии; null останавливает.
## [param hero] - герой.
func follow(hero: Node2D) -> void:
	_hero = hero


## Поворачивает персонажа.
## [param direction] - знак показывает, куда смотреть: больше нуля - вправо.
func face(direction: float) -> void:
	if direction != 0.0:
		_sprite.flip_h = (direction > 0.0) != faces_right


## Показывает особую позу вместо стойки; null возвращает стойку.
## [param texture] - кадр позы.
func set_pose(texture: Texture2D) -> void:
	_pose = texture
	if not _walking:
		_show(texture if texture != null else stand)


## Сообщает, идёт ли персонаж.
func is_walking() -> bool:
	return _walking


## Возвращает показанный кадр; нужно тестам.
func current_texture() -> Texture2D:
	return _sprite.texture


## Сменяет кадры шага и ведёт следование за героем.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	if is_instance_valid(_hero) and not get_tree().paused:
		var goal := _hero.global_position.x + FOLLOW_GAP
		var gap := goal - global_position.x
		if absf(gap) > FOLLOW_START or (_walking and absf(gap) > 2.0):
			_walking = true
			face(gap)
			global_position.x += signf(gap) * minf(FOLLOW_SPEED * delta, absf(gap))
		elif _walking:
			_walking = false
			face(_hero.global_position.x - global_position.x)
			_show(stand)
	if _walking and not walk_frames.is_empty():
		_show(walk_frames[int(_clock * STEP_FPS) % walk_frames.size()])


## Показывает кадр, выравнивая его по ступням.
## [param texture] - кадр.
func _show(texture: Texture2D) -> void:
	if texture == null:
		return
	_sprite.texture = texture
	_sprite.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())


## Открывает рот на своей реплике.
## [param line] - показанная реплика.
func _on_line_shown(line: Dictionary) -> void:
	if _walking:
		return
	var mine := str(line.get("speaker", "")) == speaker
	_show(talk if mine and talk != null else (_pose if _pose != null else stand))


## Закрывает рот после разговора.
func _on_dialogue_toggled() -> void:
	if not Ui.dialogue.visible and not _walking:
		_show(_pose if _pose != null else stand)


## Создаёт Мажайцева: идёт, стоит, говорит и делает «тшш». Кадры смотрят вправо.
static func mozhaitsev() -> Walker:
	var walker := Walker.new()
	walker.walk_frames = [
		load("res://assets/characters/mozhaitsev/walk_1.png"),
		load("res://assets/characters/mozhaitsev/walk_2.png"),
		load("res://assets/characters/mozhaitsev/walk_3.png"),
		load("res://assets/characters/mozhaitsev/walk_4.png"),
	]
	walker.stand = load("res://assets/characters/mozhaitsev/stand.png")
	walker.talk = load("res://assets/characters/mozhaitsev/talk.png")
	walker.faces_right = true
	walker.speaker = "mozhaitsev"
	return walker


## Создаёт Ваню в очках: идёт по четырём кадрам. Кадры смотрят вправо, поэтому, когда Ваня
## идёт влево, они зеркалятся.
static func vanya() -> Walker:
	var walker := Walker.new()
	walker.walk_frames = [
		load("res://assets/characters/vanya/walk_1.png"),
		load("res://assets/characters/vanya/walk_2.png"),
		load("res://assets/characters/vanya/walk_3.png"),
		load("res://assets/characters/vanya/walk_4.png"),
	]
	walker.stand = walker.walk_frames[1]
	walker.faces_right = true
	walker.speaker = "vanya"
	walker.speed = 190.0
	return walker
