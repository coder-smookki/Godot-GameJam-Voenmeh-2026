class_name TvFight
extends BossFight
## Кабинет 418: заражённый телевизор, преграда и Землянская, прибитая вирусом к стене.
##
## При первом входе камера показывает Землянскую: она бьётся у стены (кадры 1-2-3-3-2-1),
## рассказчик и её реплика из сценария, потом камера переходит на телевизор, он просыпается
## со злым лицом, и начинается бой: на стекле программы с пропусками ([CodeGame]). Каждая
## решённая задача ранит экран, трясёт и раскалывает преграду. Если время на задачу вышло,
## герой теряет сердце и бой начинается заново. После победы экран разбит, преграда
## рассыпается, Землянская падает со стены, заражение слетает с неё, она стоит свободная
## и говорит с героем; в лифте возвращается кнопка пятого этажа. На время боя узел живёт
## и на паузе: экран задач - модальное окно, а трещины и вспышки должны идти под ним.

signal finished

enum Phase { WAIT, INTRO, FIGHT, OUTRO, DONE }

const BOSS_MARK := "boss_4"
const TALK := "zemlyanskaya"
const FREE_TALK := "zemlyanskaya_free"
const GLASS := Rect2(770.0, 28.0, 418.0, 134.0)
const TV_VIEW := Vector2(979.0, 95.0)
const ZEML_VIEW := Vector2(1460.0, 135.0)
const PINNED_AT := Vector2(1520.0, 236.0)
const FREE_X := 1500.0
const FLOOR_Y := 248.0
const PINNED_FRAMES: Array[Texture2D] = [
	preload("res://assets/characters/zemlyanskaya/pinned_1.png"),
	preload("res://assets/characters/zemlyanskaya/pinned_2.png"),
	preload("res://assets/characters/zemlyanskaya/pinned_3.png"),
]
const PINNED_ORDER: Array[int] = [0, 1, 2, 2, 1, 0]
const PINNED_FPS := 6.0
const CRACK_SEC := 0.35

@export var exit_door: Door = null
@export var barrier: Node2D = null
@export var wall: CollisionShape2D = null
@export var zemlyanskaya: Npc = null

var phase: Phase = Phase.WAIT

var _screen: BossScreen = null
var _pinned: Sprite2D = null
var _pinned_clock: float = 0.0
var _cracks: int = 0


## Собирает экран телевизора, прибитую Землянскую, камеру и экран боя; после победы
## оставляет разбитый экран, без преграды и со свободной Землянской.
func _ready() -> void:
	_build_director(TV_VIEW)
	_build_bars()
	_build_hud()
	_screen = BossScreen.new()
	_screen.rect = GLASS
	_screen.ports.clear()
	add_child(_screen)
	_pinned = Sprite2D.new()
	_pinned.texture = PINNED_FRAMES[0]
	_pinned.centered = false
	_pinned.offset = Vector2(-PINNED_FRAMES[0].get_width() * 0.5, -PINNED_FRAMES[0].get_height())
	_pinned.position = PINNED_AT
	_pinned.z_index = -6
	_pinned.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pinned)
	if World.is_marked(BOSS_MARK):
		phase = Phase.DONE
		_screen.shatter()
		_pinned.hide()
		_remove_barrier()
		return
	if zemlyanskaya != null:
		zemlyanskaya.hide()
		zemlyanskaya.set_deferred("monitorable", false)
	Game.room_entered.connect(_on_room_entered, CONNECT_ONE_SHOT)


## Двигает кадры прибитой Землянской: 1-2-3-3-2-1 по кругу, и во время пауз тоже.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if not _pinned.visible:
		return
	_pinned_clock += delta
	var step := int(_pinned_clock * PINNED_FPS) % PINNED_ORDER.size()
	_pinned.texture = PINNED_FRAMES[PINNED_ORDER[step]]


## Сообщает, идёт ли бой прямо сейчас (между началом и победой).
func is_running() -> bool:
	return phase != Phase.WAIT and phase != Phase.DONE


## Начинает бой: камера на Землянской, её анимация и разговор, потом телевизор и задачи.
func start() -> void:
	if phase != Phase.WAIT:
		return
	var room := get_tree().current_scene as Room
	if room == null or room.player == null:
		return
	phase = Phase.INTRO
	_player = room.player
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lock_door(exit_door, true)
	_freeze(true)
	Ui.hud.hide_task(true)
	_director.global_position = _hero_view()
	_director.zoom = Vector2.ONE
	_take_view()
	await _pan(ZEML_VIEW, 1.1)
	await _wait(2.4)
	await Story.play_once(TALK)
	if not is_inside_tree():
		return
	await _pan(TV_VIEW, 0.9)
	_screen.boot()
	_screen.glitch(0.8)
	_shake_camera(4.0, 0.5)
	_hud.show()
	_hud.boss_name = tr("BOSS_TV")
	_hud.integrity_max = 0
	_hud.charge_max = 0
	_hud.hp_max = Difficulty.value("code_tasks")
	_hud.hp = _hud.hp_max
	_hud.banner(tr("BOSS_TV_INTRO"), BossHud.BOSS_COLOR)
	_hud.flash(Color(1.0, 0.1, 0.2, 0.35))
	await _wait(1.6)
	phase = Phase.FIGHT
	await _fight()


## Проводит задачи до победы; проигрыш отнимает сердце, и задачи начинаются заново.
func _fight() -> void:
	Ui.code.answered.connect(_on_answered)
	while true:
		await get_tree().process_frame
		var won: bool = await Ui.code.play(_glass_on_screen())
		if not is_inside_tree():
			return
		if won:
			break
		_screen.say(tr("BOSS_LAUGH"))
		_hud.banner(tr("BOSS_FAILED"), Palette.DANGER)
		_hud.flash(Color(1.0, 0.0, 0.0, 0.5))
		Game.lose_heart()
		if int(World.f[Game.HEARTS]) <= 0:
			return
		await _wait(1.8)
		if not is_inside_tree():
			return
		_screen.say("")
		_hud.hp = _hud.hp_max
		_hud.banner(tr("BOSS_RETRY"))
	Ui.code.answered.disconnect(_on_answered)
	await _outro()


## Победа: экран разбит, преграда рассыпается, Землянская падает со стены свободной и говорит.
func _outro() -> void:
	phase = Phase.OUTRO
	_screen.say("")
	_screen.shatter()
	_hud.flash(Color(1.0, 1.0, 1.0, 0.85))
	_hud.boss_name = ""
	_shake_camera(10.0, 0.9)
	await _wait(1.2)
	await _pan(ZEML_VIEW, 0.9)
	_crumble_barrier()
	await _wait(0.9)
	_cure_burst(PINNED_AT + Vector2(0.0, -80.0))
	_pinned.hide()
	if zemlyanskaya != null:
		zemlyanskaya.show()
		zemlyanskaya.global_position = Vector2(FREE_X, FLOOR_Y - 50.0)
		var fall := create_tween()
		(
			fall
			. tween_property(zemlyanskaya, "global_position:y", FLOOR_Y, 0.35)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN)
		)
		await fall.finished
		Puff.spawn(get_parent(), Vector2(FREE_X, FLOOR_Y), Puff.JUMP_AMOUNT * 2)
	_hud.banner(tr("BOSS_TV_WIN"), Palette.OK)
	await _wait(1.4)
	_hud.hide()
	await Ui.dialogue.play(DialogueCatalog.talk(FREE_TALK))
	if not is_inside_tree():
		return
	await _pan(_hero_view(), 0.9)
	_give_view()
	if zemlyanskaya != null:
		zemlyanskaya.set_deferred("monitorable", true)
	_freeze(false)
	_lock_door(exit_door, false)
	Ui.hud.hide_task(false)
	phase = Phase.DONE
	process_mode = Node.PROCESS_MODE_INHERIT
	World.mark(BOSS_MARK)
	SaveSystem.save_game()
	finished.emit()


## Возвращает прямоугольник стекла телевизора на экране при текущей камере.
func _glass_on_screen() -> Rect2:
	var view := get_viewport().get_canvas_transform()
	return Rect2(view * GLASS.position, GLASS.size * view.get_scale())


## Раскалывает преграду: она вздрагивает, темнеет и теряет клетки.
func _crack_barrier() -> void:
	if barrier == null:
		return
	_cracks += 1
	var darker := 1.0 - 0.12 * _cracks
	barrier.modulate = Color(2.0, 2.0, 2.0)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(barrier, "modulate", Color(darker, darker, darker), CRACK_SEC)
	var shake := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var base := barrier.position
	for step: int in 4:
		var side := 4.0 if step % 2 == 0 else -4.0
		shake.tween_property(barrier, "position", base + Vector2(side, 0.0), 0.04)
	shake.tween_property(barrier, "position", base, 0.04)
	_burst(
		barrier.global_position + Vector2(0.0, -120.0), Color(1.0, 0.0, 1.0), 14, 160.0, 2.0, 5.0
	)
	_burst(
		barrier.global_position + Vector2(0.0, -60.0), Color(0.0, 0.07, 0.0), 10, 140.0, 2.0, 5.0
	)


## Рассыпает преграду: клетки летят вниз, она оседает и гаснет, проход открыт.
func _crumble_barrier() -> void:
	if barrier == null:
		return
	for height: float in [40.0, 100.0, 160.0, 210.0]:
		_burst(
			barrier.global_position + Vector2(0.0, -height),
			Color(1.0, 0.0, 1.0),
			16,
			200.0,
			3.0,
			7.0
		)
		_burst(
			barrier.global_position + Vector2(0.0, -height),
			Color(0.0, 0.07, 0.0),
			12,
			180.0,
			3.0,
			7.0
		)
	_shake_camera(8.0, 0.6)
	var tween := create_tween().set_parallel()
	tween.tween_property(barrier, "scale", Vector2(1.2, 0.05), 0.7).set_ease(Tween.EASE_IN)
	tween.tween_property(barrier, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(_remove_barrier)


## Убирает преграду и её стену.
func _remove_barrier() -> void:
	if wall != null:
		wall.set_deferred("disabled", true)
	if barrier != null:
		barrier.hide()


## Отвечает на решение задачи: верное ранит экран и раскалывает преграду, неверное злит экран.
## [param correct] - true, если задача решена.
func _on_answered(correct: bool) -> void:
	if correct:
		_screen.hurt()
		_hud.damage()
		_crack_barrier()
		_shake_camera(5.0, 0.35)
		_pinned_clock += 0.5
	else:
		_screen.attack()
		_screen.glitch(0.5)
		_hud.flash(Color(1.0, 0.0, 0.0, 0.3))
		_shake_camera(3.0, 0.25)


## Начинает бой после того, как комната показалась на экране.
## [param _code] - код комнаты.
func _on_room_entered(_code: String) -> void:
	start()
