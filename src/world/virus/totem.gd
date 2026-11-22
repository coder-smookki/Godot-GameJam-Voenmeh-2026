class_name Totem
extends Interactable
## Надпись ERROR из шахматки: стоит стеной поперёк коридора и не пускает героя дальше.
##
## Буквы нарисованы художницей одной картинкой; надпись вырезает из неё по букве. Начало
## координат - на полу перед надписью, со стороны героя. Кто подходит вплотную, того надпись
## отталкивает и кричит битыми символами. С отладчиком у неё можно отладить код (мини-игра
## [DebugGame]); первый раз мини-игра открывается сама, как только герой получил отладчик.
## Победа печатает послание ЛАБЫ, буквы осыпаются справа налево, по комнате проходит волна
## восстановления, заражение этажа падает, стена исчезает. Проигрыш по времени отнимает сердце.

signal destroyed

const ART: Texture2D = preload("res://assets/props/error.png")
const LETTERS: Array[Vector2] = [
	Vector2(0, 31), Vector2(32, 63), Vector2(64, 95), Vector2(97, 122), Vector2(125, 154)
]
const DEBUGGER_MARK := "ability_debugger"
const MESSAGES := "messages"
const AUTO_DEBUG_SEC := 1.4
const PUSH := Vector2(300.0, -220.0)
const GLITCH := "<>@#%&*+=?/\\|{}[]~^$0123456789abcdefghijklmnopqrstuvwxyz"
const GLITCH_LENGTH := 11
const SHOUT_SEC := 1.5
const HIT_SEC := 0.18
const SHATTER_STEP_SEC := 0.16
const WAVE_SEC := 0.6
const WAVE_WIDTH := 1200.0
const WAVE_HEIGHT := 270.0
const SHARD_COLORS: Array[Color] = [Color(1.0, 0.0, 1.0), Color(0.0, 0.07, 0.0)]

@export var totem_id: String = ""
@export var heal_amount: float = 8.0
@export var message_mark: String = "message_1"
@export var art_offset: Vector2 = Vector2(-110.0, -104.0)

var _left: int = 0
var _shake: float = 0.0
var _running: bool = false
var _shout_left: float = 0.0

@onready var _wall: CollisionShape2D = $Wall/Shape
@onready var _guard: Area2D = $Guard
@onready var _voice: SpeechBubble = $Voice


## Убирает уже разбитую надпись или ставит целую стеной поперёк коридора.
func _ready() -> void:
	if World.is_marked(_mark()):
		queue_free()
		return
	super()
	_left = LETTERS.size()
	_voice.hide()
	_guard.body_entered.connect(_on_guard_body_entered)
	World.marked.connect(_on_world_marked)


## Прячет крик надписи, когда он отзвучал.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if _shout_left <= 0.0:
		return
	_shout_left -= delta
	if _shout_left <= 0.0:
		_voice.hide()


## Рисует оставшиеся буквы; задетая буква вздрагивает.
func _draw() -> void:
	var width := LETTERS[LETTERS.size() - 1].y
	for index: int in _left:
		var span := LETTERS[index]
		var source := Rect2(span.x, 0.0, span.y - span.x, ART.get_height())
		var target := source
		target.position = art_offset + Vector2(span.x - width * 0.5, -ART.get_height())
		target.position.x += _shake * (1.0 if index % 2 == 0 else -1.0)
		draw_texture_rect_region(ART, target, source)


## Собирает подсказку: без отладчика надпись можно только осмотреть.
## Возвращает строку подсказки с клавишей.
func prompt_text() -> String:
	prompt_key = "PROMPT_DEBUG_CODE" if World.is_marked(DEBUGGER_MARK) else "PROMPT_INSPECT"
	return super()


## Сообщает, сколько букв ещё осталось.
## Возвращает число невыбитых букв.
func letters_left() -> int:
	return _left


## Сообщает, идёт ли сейчас отладка у этой надписи.
func is_debugging() -> bool:
	return _running


## Кричит битыми символами: в облачке над надписью случайная строка.
## Возвращает показанную строку.
func shout() -> String:
	var text := ""
	for index: int in GLITCH_LENGTH:
		text += GLITCH[randi() % GLITCH.length()]
	_voice.say("«%s»" % text)
	_shout_left = SHOUT_SEC
	var tween := create_tween()
	tween.tween_method(_set_shake, 3.0, 0.0, HIT_SEC * 2.0)
	return text


## Открывает отладку кода надписи; без отладчика надпись только кричит.
## [param _player] - герой, который подошёл к надписи.
func _interact(_player: Player) -> void:
	if not World.is_marked(DEBUGGER_MARK):
		shout()
		Ui.toast(tr("LOCK_ERROR"), ToastStack.KIND_HINT)
		return
	await debug()


## Проводит мини-игру отладки и отвечает на её исход.
## Возвращает true, если код исправлен.
func debug() -> bool:
	if _running or _left <= 0:
		return false
	_running = true
	set_focused(false)
	var solved: bool = await Ui.debug.play()
	_running = false
	if not is_inside_tree():
		return solved
	if solved:
		_on_solved()
	else:
		shout()
		Ui.toast(tr("DEBUG_LOST"), ToastStack.KIND_LABA)
		Game.lose_heart()
	return solved


## Засчитывает послание ЛАБЫ, убирает стену и осыпает буквы одну за другой.
func _on_solved() -> void:
	if World.mark(message_mark):
		World.bump(MESSAGES)
		Ui.toast(tr("TOAST_MESSAGE").format(World.f), ToastStack.KIND_LABA)
	_wall.set_deferred("disabled", true)
	_guard.set_deferred("monitoring", false)
	monitorable = false
	for step: int in LETTERS.size():
		_knock_letter()
		await get_tree().create_timer(SHATTER_STEP_SEC).timeout
		if not is_inside_tree():
			return
	_destroy()


## Выбивает крайнюю правую букву с горстью клеток и дрожью.
func _knock_letter() -> void:
	if _left <= 0:
		return
	_left -= 1
	_burst(_letter_center(_left))
	var tween := create_tween()
	tween.tween_method(_set_shake, 3.0, 0.0, HIT_SEC)
	queue_redraw()


## Запоминает разбитую надпись, лечит этаж и пускает волну восстановления.
func _destroy() -> void:
	World.mark(_mark())
	World.mark("first_totem")
	Infection.heal(Infection.current_floor, heal_amount)
	SaveSystem.save_game()
	destroyed.emit()
	var wave := ColorRect.new()
	wave.color = Color(1.0, 1.0, 1.0, 0.85)
	wave.size = Vector2(4.0, WAVE_HEIGHT)
	wave.position = Vector2(art_offset.x - 2.0, -position.y)
	wave.z_index = 20
	add_child(wave)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(wave, "size:x", WAVE_WIDTH * 2.0, WAVE_SEC)
	tween.tween_property(wave, "position:x", art_offset.x - WAVE_WIDTH, WAVE_SEC)
	tween.tween_property(wave, "color:a", 0.0, WAVE_SEC)
	tween.chain().tween_callback(queue_free)


## Выбрасывает горсть клеток шахматки из выбитой буквы.
## [param at] - центр буквы в координатах надписи.
func _burst(at: Vector2) -> void:
	var shards := CPUParticles2D.new()
	shards.position = at
	shards.amount = 16
	shards.lifetime = 0.5
	shards.one_shot = true
	shards.explosiveness = 0.95
	shards.spread = 180.0
	shards.gravity = Vector2(0.0, 380.0)
	shards.initial_velocity_min = 40.0
	shards.initial_velocity_max = 120.0
	shards.scale_amount_min = 2.0
	shards.scale_amount_max = 4.0
	shards.color = SHARD_COLORS[_left % SHARD_COLORS.size()]
	shards.finished.connect(shards.queue_free)
	add_child(shards)
	shards.emitting = true


## Возвращает центр буквы в координатах надписи.
## [param index] - номер буквы слева направо.
func _letter_center(index: int) -> Vector2:
	var width := LETTERS[LETTERS.size() - 1].y
	var span := LETTERS[index]
	return art_offset + Vector2((span.x + span.y) * 0.5 - width * 0.5, -ART.get_height() * 0.5)


## Сдвигает буквы и перерисовывает надпись.
## [param offset] - смещение в пикселях.
func _set_shake(offset: float) -> void:
	_shake = offset * (1.0 if int(offset * 10.0) % 2 == 0 else -1.0)
	queue_redraw()


## Собирает имя отметки разбитой надписи.
## Возвращает строку вида "totem_<id>".
func _mark() -> String:
	return "totem_%s" % totem_id


## Отталкивает героя, который подошёл к надписи вплотную, и кричит на него.
## [param body] - тело, вошедшее в зону у надписи.
func _on_guard_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	var side := 1.0 if player.global_position.x >= global_position.x + art_offset.x else -1.0
	player.knock_back(Vector2(PUSH.x * side, PUSH.y))
	shout()


## Сама открывает отладку, когда герой только что получил отладчик.
## [param id] - имя новой отметки мира.
func _on_world_marked(id: String) -> void:
	if id != DEBUGGER_MARK:
		return
	await get_tree().create_timer(AUTO_DEBUG_SEC).timeout
	if is_inside_tree() and not Ui.is_modal_open() and not Game.is_busy():
		debug()
