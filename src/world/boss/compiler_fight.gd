class_name CompilerFight
extends BossFight
## Кабинет 202: разговор с Вальштейном и бой с заражённым Компилятором на мониторе.
##
## При первом входе камера смотрит на Вальштейна, пока он говорит; на словах о компиляторе
## экран просыпается и камера переходит на злой монитор, после разговора возвращается к герою.
## Бой начинается, когда герой подходит к монитору: экран просыпается, его порты открыты,
## Вальштейн говорит «Ну всё, теперь можно атаковать», камера показывает весь кабинет и потом
## держит героя на половинном увеличении: ареной служит весь кабинет, сверху и снизу чёрные
## полосы, на них экран боя. Компилятор пускает по полу ошибки - низкие и высокие столбики
## шахматки, через них нужно только перепрыгивать.
## Фаза 1: за каждые несколько перепрыгнутых ошибок (сколько - задаёт сложность) Вальштейн
## бросает бомбу в порт. Камера наезжает на бросок и летит за бомбой. Три бомбы снимают всё
## здоровье.
## Фаза 2: «это был не конец» - за отведённое время нарисовать капибару ([DrawGame]).
## После победы экран разбит, Вальштейн освобождается, герой получает умение, в лифте
## возвращается кнопка третьего этажа. Три попадания по герою срывают фазу и отнимают сердце;
## фаза начинается заново.

signal finished

enum Phase { WAIT, INTRO, BOMBS, BOMB_SCENE, FINISH, OUTRO, DONE, FAILED }

const BOSS_MARK := "boss_2"
const ABILITY_MARK := "ability_2"
const TALK := "valshtein"
const COMPILER_LINE := "TALK_VALSHTEIN_3"
const FREE_TALK := "valshtein_free"
const ROOM_WIDTH := 1700.0
const MONITOR := Vector2(980.0, 135.0)
const FLOOR_Y := 254.0
const TRIGGER := Rect2(790.0, 60.0, 20.0, 200.0)
const OVERVIEW_ZOOM := 480.0 / 1700.0
const BOMBS := 3
const SPAWN_AHEAD := 520.0
const SPAWN_MIN_GAP := 280.0
const HAND := Vector2(61.0, -159.0)
const BUBBLE_Y := -170.0
const INVULNERABLE_SEC := 1.2
const PUSH := Vector2(240.0, -200.0)
const BOMB_TEXTURE: Texture2D = preload("res://assets/props/bomb.png")
const BOMB_SEC := 1.1
const BOMB_ARC := 60.0
const PAIR_GAP_SEC := 1.0
const HIGH_CHANCE := 0.3
const HIGH_CHANCE_PER_BOMB := 0.15
const HIGH_BONUS_SPEED := 25.0
const PAIR_CHANCE := 0.35
const ORANGE := Color("ff8a1c")
const FIRE: Array[Color] = [Color("ffe066"), Color("ff8a1c"), Color("d81e1e"), Color("2a2a2a")]

@export var valshtein: Npc = null
@export var exit_door: Door = null

var phase: Phase = Phase.WAIT
var integrity_max: int = 3
var dodges_needed: int = 5
var integrity: int = 3
var bombs_done: int = 0
var dodges: int = 0

var _spawn_left: float = 0.0
var _invulnerable: float = 0.0
var _screen: BossScreen = null
var _errors: Node2D = null
var _trigger: Area2D = null
var _meeting: bool = false


## Собирает камеру, экран босса и чёрные полосы; после победы оставляет разбитый
## экран и освобождённого Вальштейна, до боя ждёт героя у монитора.
func _ready() -> void:
	_screen = BossScreen.new()
	add_child(_screen)
	_errors = Node2D.new()
	add_child(_errors)
	integrity_max = Difficulty.value("boss_integrity")
	dodges_needed = Difficulty.value("bomb_dodges")
	integrity = integrity_max
	_build_director(MONITOR)
	_build_bars()
	_build_hud()
	if World.is_marked(BOSS_MARK):
		phase = Phase.DONE
		_screen.shatter()
		if valshtein != null:
			valshtein.idle_pose = "neutral"
			valshtein.set_pose("neutral")
			valshtein.talk_id = FREE_TALK
		return
	_build_trigger()
	if World.is_marked(Story.SEEN_PREFIX + TALK):
		_screen.power_on()
	else:
		Game.room_entered.connect(_on_room_entered, CONNECT_ONE_SHOT)


## Ведёт камеру за героем, атаки Компилятора, мигание неуязвимого героя и уборку строк.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_screen.watch_x = _player.global_position.x
	if _invulnerable > 0.0:
		_invulnerable -= delta
		var blink := int(_invulnerable * 12.0) % 2 == 0 and _invulnerable > 0.0
		_player.modulate.a = 0.35 if blink else 1.0
	for line: Node in _errors.get_children():
		var error := line as ErrorLine
		if error != null and (error.position.x < -80.0 or error.position.x > ROOM_WIDTH + 80.0):
			error.vanish()
	if phase == Phase.BOMBS:
		_follow_hero(delta)
		_spawn_left -= delta
		if _spawn_left <= 0.0:
			_spawn_left = _next_interval()
			_attack()


## Сообщает, идёт ли сейчас первая встреча с Вальштейном.
func is_meeting() -> bool:
	return _meeting


## Сообщает, идёт ли бой прямо сейчас (между началом и победой).
func is_running() -> bool:
	return phase != Phase.WAIT and phase != Phase.DONE


## Первый вход: Вальштейн говорит под камерой, на словах о компиляторе экран просыпается
## и камера переходит на монитор, после разговора камера возвращается к герою.
func meet() -> void:
	var room := get_tree().current_scene as Room
	if room == null or room.player == null or valshtein == null:
		return
	_player = room.player
	_meeting = true
	_freeze(true)
	_director.global_position = _valshtein_view()
	_director.zoom = Vector2.ONE * SCENE_ZOOM
	_take_view()
	Ui.dialogue.line_shown.connect(_on_meet_line)
	await Story.play_once(TALK)
	if Ui.dialogue.line_shown.is_connected(_on_meet_line):
		Ui.dialogue.line_shown.disconnect(_on_meet_line)
	if not is_inside_tree():
		return
	_screen.power_on()
	await _pan(_hero_view(), 0.8)
	_meeting = false
	if phase == Phase.WAIT:
		_give_view()
		_freeze(false)


## Начинает бой: камера на мониторе, открытые порты, реплика Вальштейна, весь кабинет,
## потом камера держит героя, и Компилятор начинает стрелять ошибками.
func start() -> void:
	if phase != Phase.WAIT or _meeting:
		return
	var room := get_tree().current_scene as Room
	if room == null or room.player == null:
		return
	phase = Phase.INTRO
	_player = room.player
	Music.play("boss2")
	_trigger.set_deferred("monitoring", false)
	_lock_door(exit_door, true)
	_freeze(true)
	Ui.hud.hide_task(true)
	get_parent().texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_director.global_position = _player.get_viewport().get_camera_2d().get_screen_center_position()
	_director.zoom = Vector2.ONE
	_take_view()
	await _pan(MONITOR, 0.7)
	if _screen.power() < 1.0:
		_screen.boot()
	_screen.glitch(0.6)
	_shake_camera(4.0, 0.5)
	_hud.show()
	_hud.boss_name = tr("BOSS_COMPILER")
	_hud.banner(tr("BOSS_COMPILER_INTRO"), BossHud.BOSS_COLOR)
	_hud.flash(Color(1.0, 0.1, 0.2, 0.35))
	await _wait(1.3)
	for index: int in _screen.ports.size():
		_screen.ports[index] = BossScreen.Port.OPEN
	_screen.glitch(0.6)
	_shake_camera(3.0, 0.4)
	_hud.banner(tr("BOSS_PORTS_OPEN"), Palette.DEBUGGER)
	await _wait(1.0)
	await _pan(_valshtein_view(), 0.8)
	_say(tr("TALK_VALSHTEIN_ATTACK"))
	await _wait(2.2)
	await _pan(Vector2(ROOM_WIDTH * 0.5, VIEW_Y), 1.0, OVERVIEW_ZOOM)
	await _wait(1.2)
	await _pan(Vector2(_player.global_position.x, VIEW_Y), 0.9, PLAY_ZOOM)
	_hud.integrity_max = integrity_max
	_hud.integrity = integrity
	_hud.hint = tr("BOSS_HINT_BOMBS")
	_hud.charge_max = dodges_needed
	_hud.charge = 0
	dodges = 0
	_spawn_left = 1.2
	phase = Phase.BOMBS
	_freeze(false)


## Сцена броска: камера на Вальштейне, замах, бросок, полёт бомбы и взрыв в порту.
func _throw_bomb() -> void:
	phase = Phase.BOMB_SCENE
	_freeze(true)
	_clear_errors()
	var hint := _hud.hint
	_hud.hint = ""
	await _pan(_valshtein_view() + Vector2(0.0, 15.0), 0.6, 1.3)
	valshtein.face_right(true)
	valshtein.set_pose("throw_1")
	var windup := create_tween()
	windup.tween_property(valshtein, "scale", Vector2(0.94, 1.05), 0.25)
	windup.tween_property(valshtein, "scale", Vector2.ONE, 0.2)
	await _wait(0.55)
	valshtein.set_pose("throw_2")
	_shake_camera(2.0, 0.15)
	var port := bombs_done
	var target := _port_position(port)
	var bomb := Sprite2D.new()
	bomb.texture = BOMB_TEXTURE
	bomb.z_index = 30
	bomb.global_position = valshtein.global_position + HAND
	add_child(bomb)
	_add_fuse(bomb)
	var from := bomb.global_position
	var fly := create_tween().set_parallel()
	fly.tween_method(_fly.bind(bomb, from, target), 0.0, 1.0, BOMB_SEC)
	fly.tween_property(_director, "zoom", Vector2.ONE * SCENE_ZOOM, BOMB_SEC * 0.7)
	await fly.finished
	bomb.queue_free()
	_explode(target)
	_screen.ports[port] = BossScreen.Port.BROKEN
	_screen.hurt()
	_hud.damage()
	_hud.banner(tr("BOSS_HIT"), ORANGE)
	await _wait(0.4)
	valshtein.set_pose(valshtein.idle_pose)
	await _wait(1.0)
	bombs_done += 1
	dodges = 0
	_hud.charge = 0
	if bombs_done >= BOMBS:
		_hud.charge_max = 0
		await _finish()
		return
	await _pan(Vector2(_player.global_position.x, VIEW_Y), 0.7, PLAY_ZOOM)
	_hud.hint = hint
	_spawn_left = 1.2
	phase = Phase.BOMBS
	_freeze(false)


## Последний этап: Компилятор не сдаётся, и капибару нужно нарисовать за отведённое время.
func _finish() -> void:
	phase = Phase.FINISH
	_screen.say(tr("BOSS_NOT_OVER"))
	_screen.glitch(1.2)
	_shake_camera(5.0, 0.6)
	_hud.banner(tr("BOSS_NOT_OVER_BANNER"), BossHud.BOSS_COLOR)
	await _pan(MONITOR, 0.6, SCENE_ZOOM)
	await _wait(1.6)
	_hud.hint = tr("BOSS_HINT_DRAW")
	while true:
		var drawn: bool = await Ui.drawing.play()
		if not is_inside_tree():
			return
		if drawn:
			break
		Game.lose_heart()
		if int(World.f[Game.HEARTS]) <= 0:
			return
		_hud.banner(tr("BOSS_RETRY"), Palette.DANGER)
		await _wait(1.6)
		if not is_inside_tree():
			return
	await _outro()


## Победа: экран разбивается, Вальштейн освобождается и благодарит, герой получает умение,
## в лифте возвращается кнопка третьего этажа.
func _outro() -> void:
	phase = Phase.OUTRO
	_hud.hint = ""
	_screen.say("")
	_crumble()
	_screen.shatter()
	_hud.flash(Color(1.0, 1.0, 1.0, 0.85))
	_hud.banner(tr("BOSS_WIN"), Palette.OK)
	_shake_camera(10.0, 0.9)
	_hud.boss_name = ""
	_hud.integrity_max = 0
	await _wait(1.8)
	await _pan(_valshtein_view(), 0.9)
	_cure_burst(valshtein.global_position + Vector2(0.0, -80.0))
	valshtein.idle_pose = "neutral"
	valshtein.set_pose("neutral")
	valshtein.talk_id = FREE_TALK
	_hud.flash(Color(1.0, 1.0, 1.0, 0.5))
	await _wait(1.0)
	await _pan(_hero_view(), 0.8)
	_give_view()
	_player.modulate.a = 1.0
	await Ui.dialogue.play(DialogueCatalog.talk(FREE_TALK))
	if not is_inside_tree():
		return
	_freeze(false)
	_lock_door(exit_door, false)
	Ui.hud.hide_task(false)
	_hud.hide()
	World.mark(ABILITY_MARK)
	SaveSystem.save_game()
	await _wait(2.4)
	World.mark(BOSS_MARK)
	SaveSystem.save_game()
	phase = Phase.DONE
	Music.play_room()
	finished.emit()


## Срывает фазу после трёх попаданий: минус сердце, короткая пауза, фаза заново.
func _fail_phase() -> void:
	phase = Phase.FAILED
	_freeze(true)
	_clear_errors()
	_hud.banner(tr("BOSS_FAILED"), Palette.DANGER)
	_hud.flash(Color(1.0, 0.0, 0.0, 0.5))
	_screen.say(tr("BOSS_LAUGH"))
	Game.lose_heart()
	if int(World.f[Game.HEARTS]) <= 0:
		return
	await _wait(1.6)
	if not is_inside_tree():
		return
	_screen.say("")
	integrity = integrity_max
	_hud.integrity = integrity
	dodges = 0
	_hud.charge = 0
	_spawn_left = 1.2
	phase = Phase.BOMBS
	_hud.banner(tr("BOSS_RETRY"))
	_freeze(false)


## Засчитывает ошибку, через которую герой перепрыгнул; набранный заряд зовёт бомбу.
## [param _line] - перепрыгнутая ошибка.
func on_dodged(_line: ErrorLine = null) -> void:
	if phase != Phase.BOMBS:
		return
	dodges += 1
	_hud.charge = dodges
	if dodges >= dodges_needed:
		_throw_bomb()


## Отнимает у героя целостность, отбрасывает его и даёт секунду неуязвимости.
## [param line] - ошибка, которая задела героя.
func on_touched(line: ErrorLine) -> void:
	if _invulnerable > 0.0 or phase != Phase.BOMBS:
		return
	line.vanish()
	integrity -= 1
	_hud.integrity = integrity
	var side := 1.0 if _player.global_position.x >= line.global_position.x else -1.0
	_player.knock_back(Vector2(PUSH.x * side, PUSH.y))
	_shake_camera(6.0, 0.35)
	_hud.flash(Color(1.0, 0.0, 0.0, 0.35))
	_invulnerable = INVULNERABLE_SEC
	if integrity <= 0:
		_invulnerable = 0.0
		_player.modulate.a = 1.0
		_fail_phase()


## Пускает по полу низкую или высокую ошибку; высокие с каждой бомбой чаще. После второй
## бомбы низкие иногда идут парой, с промежутком, в который успевает уложиться второй прыжок.
func _attack() -> void:
	_screen.attack()
	var from_left := _spawn_from_left()
	var speed := _line_speed()
	var chance: float = (
		HIGH_CHANCE + HIGH_CHANCE_PER_BOMB * bombs_done + Difficulty.value("attack_high")
	)
	var tall := randf() < chance
	if tall:
		_slide(from_left, speed + HIGH_BONUS_SPEED, true)
		return
	_slide(from_left, speed)
	if bombs_done >= 2 and randf() < PAIR_CHANCE:
		await _wait(PAIR_GAP_SEC)
		if phase == Phase.BOMBS:
			_slide(from_left, speed)


## Выбирает сторону, откуда поедет ошибка: так, чтобы до героя было не меньше полэкрана.
## Возвращает true, если ошибка поедет слева.
func _spawn_from_left() -> bool:
	var x := _player.global_position.x
	var left_room := x - SPAWN_MIN_GAP >= 0.0
	var right_room := x + SPAWN_MIN_GAP <= ROOM_WIDTH
	if left_room and right_room:
		return randf() < 0.5
	return left_room


## Выпускает ошибку за краем экрана; она едет к герою.
## [param from_left] - true, если ошибка едет слева направо.
## [param speed] - скорость в пикселях в секунду.
## [param tall] - true для высокого столбика.
func _slide(from_left: bool, speed: float, tall: bool = false) -> void:
	var line := ErrorLine.new()
	var hero := _player.global_position.x
	var x := clampf(hero - SPAWN_AHEAD, -20.0, ROOM_WIDTH + 20.0)
	if not from_left:
		x = clampf(hero + SPAWN_AHEAD, -20.0, ROOM_WIDTH + 20.0)
	line.setup_slide(x, from_left, speed, _player, tall)
	_add_line(line)


## Добавляет ошибку на арену и подписывается на её события.
## [param line] - готовая ошибка.
func _add_line(line: ErrorLine) -> void:
	line.touched.connect(on_touched)
	line.dodged.connect(on_dodged)
	_errors.add_child(line)


## Выбирает паузу до следующей атаки: с каждой бомбой атаки чаще, на высокой сложности
## тоже чаще.
func _next_interval() -> float:
	return randf_range(1.9, 2.5) * pow(0.9, bombs_done) * float(Difficulty.value("attack_pause"))


## Выбирает скорость ошибки: с каждой бомбой и на высокой сложности быстрее.
func _line_speed() -> float:
	return (randf_range(200.0, 230.0) + bombs_done * 15.0) * float(Difficulty.value("attack_speed"))


## Убирает с арены все ошибки.
func _clear_errors() -> void:
	for line: Node in _errors.get_children():
		if line is ErrorLine:
			line.vanish()


## Ведёт бомбу по дуге в порт; камера летит за ней.
## [param progress] - доля полёта от 0 до 1.
## [param bomb] - бомба.
## [param from] - откуда она летит.
## [param to] - куда она летит.
func _fly(progress: float, bomb: Sprite2D, from: Vector2, to: Vector2) -> void:
	var at := from.lerp(to, progress)
	at.y -= BOMB_ARC * 4.0 * progress * (1.0 - progress)
	bomb.global_position = at
	bomb.rotation = progress * TAU * 2.0
	_director.global_position = Vector2(at.x, VIEW_Y)


## Возвращает точку порта на экране Компилятора.
## [param index] - номер порта слева направо.
func _port_position(index: int) -> Vector2:
	var center := BossScreen.RECT.get_center()
	return Vector2(center.x + (index - 1) * 120.0, BossScreen.RECT.end.y - 15.0)


## Возвращает точку, куда смотрит камера, когда показывает Вальштейна.
func _valshtein_view() -> Vector2:
	if valshtein == null:
		return MONITOR
	return Vector2(valshtein.global_position.x + 40.0, VIEW_Y)


## Показывает реплику Вальштейна облачком над ним.
## [param text] - готовый текст.
func _say(text: String) -> void:
	var bubble := SpeechBubble.new()
	bubble.z_index = 40
	bubble.global_position = valshtein.global_position + Vector2(10.0, BUBBLE_Y)
	add_child(bubble)
	bubble.say(text)
	var tween := create_tween()
	tween.tween_interval(2.4)
	tween.tween_callback(bubble.queue_free)


## Взрыв бомбы: огонь, клетки шахматки, кольцо, вспышка и сильная тряска.
## [param at] - точка взрыва.
func _explode(at: Vector2) -> void:
	for color: Color in FIRE:
		_burst(at, color, 14, 260.0, 2.0, 6.0)
	_burst(at, Color(1.0, 0.0, 1.0), 12, 200.0, 3.0, 6.0)
	var ring := Blast.new()
	ring.global_position = at
	add_child(ring)
	_hud.flash(Color(1.0, 0.95, 0.8, 0.8))
	_shake_camera(10.0, 0.7)


## Осыпает экран Компилятора падающими клетками и осколками стекла.
func _crumble() -> void:
	var shards := CPUParticles2D.new()
	shards.position = BossScreen.RECT.get_center()
	shards.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	shards.emission_rect_extents = BossScreen.RECT.size * 0.5
	shards.amount = 160
	shards.lifetime = 1.4
	shards.one_shot = true
	shards.explosiveness = 0.85
	shards.direction = Vector2.DOWN
	shards.spread = 40.0
	shards.gravity = Vector2(0.0, 520.0)
	shards.initial_velocity_min = 20.0
	shards.initial_velocity_max = 90.0
	shards.scale_amount_min = 3.0
	shards.scale_amount_max = 6.0
	shards.color_ramp = _checker_ramp()
	shards.z_index = 25
	shards.finished.connect(shards.queue_free)
	add_child(shards)
	shards.emitting = true
	_burst(BossScreen.RECT.get_center(), Color(0.85, 0.9, 1.0), 30, 240.0, 1.0, 3.0)


## Вешает на бомбу искрящий фитиль.
## [param bomb] - бомба.
func _add_fuse(bomb: Sprite2D) -> void:
	var fuse := CPUParticles2D.new()
	fuse.position = Vector2(10.0, -14.0)
	fuse.amount = 12
	fuse.lifetime = 0.3
	fuse.spread = 180.0
	fuse.gravity = Vector2.ZERO
	fuse.initial_velocity_min = 20.0
	fuse.initial_velocity_max = 50.0
	fuse.scale_amount_min = 1.0
	fuse.scale_amount_max = 2.0
	fuse.color = Color("ffe066")
	fuse.local_coords = false
	bomb.add_child(fuse)


## Создаёт зону у монитора, в которой начинается бой.
func _build_trigger() -> void:
	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = TRIGGER.size
	shape.shape = rect
	shape.position = TRIGGER.get_center()
	_trigger.add_child(shape)
	_trigger.body_entered.connect(_on_trigger_body_entered)
	add_child(_trigger)


## Переводит камеру на монитор, когда Вальштейн заговорил о компиляторе.
## [param line] - реплика, которая сейчас показана.
func _on_meet_line(line: Dictionary) -> void:
	if str(line.get("text", "")) != COMPILER_LINE:
		return
	_screen.boot()
	_pan(MONITOR, 0.9)


## Начинает встречу с Вальштейном после того, как комната показалась на экране.
## [param _code] - код комнаты.
func _on_room_entered(_code: String) -> void:
	meet()


## Начинает бой, когда герой подошёл к монитору.
## [param body] - тело, вошедшее в зону.
func _on_trigger_body_entered(body: Node2D) -> void:
	if body is Player and phase == Phase.WAIT and not Ui.is_modal_open():
		start()
