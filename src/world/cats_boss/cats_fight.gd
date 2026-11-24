class_name CatsFight
extends BossFight
## Кабинет 316: заражённая Логунова управляет тремя котами, и их нужно удовлетворить разом.
##
## При первом входе камера показывает Логунову, рассказчик объясняет задачу, от Логуновой
## к котам вытягиваются нити заражения. Потом камера держит героя на половинном увеличении.
## Рыжему коту (спутнику героя, он садится у батареи) нужно тепло, серому - корм в миске,
## чёрному - закрытое окно. Отладчик (Q + ЛКМ) подкручивает батарею, досыпает корм и
## закрывает окно; правила - [CatsLogic]. Когда все трое довольны нужное время, нити рвутся,
## заражение слетает с Логуновой и с комнаты, в лифте возвращается кнопка четвёртого этажа.
## Если время вышло, герой теряет сердце и попытка начинается заново.

signal finished

enum Phase { WAIT, INTRO, PLAY, FAILED, OUTRO, DONE }

const BOSS_MARK := "boss_3"
const TALK := "logunova"
const FREE_TALK := "logunova_free"
const LOGUNOVA := Vector2(950.0, 135.0)
const HANDS := Vector2(950.0, 178.0)
const FLOOR_Y := 255.0
const WINDOW_AT := Vector2(571.0, 16.0)
const BOWL_X := 628.0
const RADIATOR_X := 1265.0
const GINGER_X := 1215.0
const BLACK_HEAD := Vector2(482.0, 208.0)
const GRAY_HEAD := Vector2(694.0, 205.0)
const GINGER_HEAD_Y := -38.0
const MOOD_LIFT := 16.0
const OVERVIEW_ZOOM := 480.0 / 1700.0
const CURED_ART: Texture2D = preload("res://assets/rooms/room_316_cured.png")
const CURE_SEC := 1.4
const REACH_SEC := 1.0

@export var exit_door: Door = null

var phase: Phase = Phase.WAIT
var logic: CatsLogic = null

var _window: CatsWindow = null
var _bowl: CatsBowl = null
var _radiator: Radiator = null
var _tendrils: Tendrils = null
var _moods: Array[CatMood] = []
var _cats_hud: CatsHud = null
var _cat: CatFollower = null
var _cured: Sprite2D = null
var _glow: CPUParticles2D = null


## Собирает окно, миску, батарею, нити, облачка котов, камеру и экран боя; после победы
## оставляет вылеченную комнату, до неё ждёт входа героя.
func _ready() -> void:
	_build_director(LOGUNOVA)
	_build_bars()
	var layer := _build_hud()
	_cats_hud = CatsHud.new()
	_cats_hud.hide()
	layer.add_child(_cats_hud)
	_build_props()
	logic = CatsLogic.new()
	logic.configure()
	logic.window_changed.connect(_on_window_changed)
	logic.mood_changed.connect(_on_mood_changed)
	logic.sabotaged.connect(_on_sabotaged)
	logic.won.connect(_on_won)
	logic.lost.connect(_on_lost)
	_cats_hud.logic = logic
	if World.is_marked(BOSS_MARK):
		phase = Phase.DONE
		_show_cured()
		return
	_show_props()
	Game.room_entered.connect(_on_room_entered, CONNECT_ONE_SHOT)


## Ведёт бой: правила, камеру за героем, облачко рыжего кота над ним.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if is_instance_valid(_cat) and _moods.size() > CatsLogic.GINGER:
		_moods[CatsLogic.GINGER].position = _cat.global_position + Vector2(0.0, GINGER_HEAD_Y)
		if not _tendrils.ends.is_empty():
			_tendrils.ends[CatsLogic.GINGER] = _cat.global_position + Vector2(0.0, -20.0)
	if phase != Phase.PLAY or not is_instance_valid(_player):
		return
	logic.advance(delta)
	_show_props()
	_follow_hero(delta)


## Сообщает, идёт ли бой прямо сейчас (между началом и победой).
func is_running() -> bool:
	return phase != Phase.WAIT and phase != Phase.DONE


## Начинает бой: камера на Логуновой, рассказ о трёх котах, нити, весь кабинет, герой.
func start() -> void:
	if phase != Phase.WAIT:
		return
	var room := get_tree().current_scene as Room
	if room == null or room.player == null:
		return
	phase = Phase.INTRO
	_player = room.player
	_cat = room.cat
	if _cat != null:
		_cat.stay_at(GINGER_X)
	_lock_door(exit_door, true)
	_freeze(true)
	Ui.hud.hide_task(true)
	get_parent().texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_director.global_position = _hero_view()
	_director.zoom = Vector2.ONE
	_take_view()
	await _pan(LOGUNOVA, 0.9, SCENE_ZOOM)
	_glow.emitting = true
	await Story.play_once(TALK)
	if not is_inside_tree():
		return
	_hud.show()
	_hud.boss_name = tr("BOSS_LOGUNOVA")
	_hud.hp_max = CatsLogic.CATS
	_hud.hp = CatsLogic.CATS
	_hud.integrity_max = 0
	_hud.charge_max = 0
	_hud.banner(tr("BOSS_LOGUNOVA_INTRO"), Palette.VIRUS)
	_hud.flash(Color(1.0, 0.0, 1.0, 0.3))
	_shake_camera(4.0, 0.5)
	var grow := create_tween()
	grow.tween_property(_tendrils, "reach", 1.0, REACH_SEC).set_trans(Tween.TRANS_CUBIC)
	await _wait(1.4)
	await _pan(Vector2(arena_width * 0.5, VIEW_Y), 1.0, OVERVIEW_ZOOM)
	await _wait(1.2)
	await _pan(Vector2(_player.global_position.x, VIEW_Y), 0.9, PLAY_ZOOM)
	_begin()


## Запускает попытку: свежие числа уровня, подсказка, экран котов, управление герою.
func _begin() -> void:
	logic.reset(Difficulty.value("cats_time"))
	_window.set_open(true, false)
	_show_props()
	for cat: int in CatsLogic.CATS:
		_moods[cat].set_happy(false)
		_tendrils.calm[cat] = false
	_hud.hint = tr("BOSS_HINT_CATS")
	_hud.hp = CatsLogic.CATS
	_cats_hud.show()
	phase = Phase.PLAY
	_freeze(false)


## Время вышло: минус сердце, короткая пауза, попытка заново.
func _fail() -> void:
	phase = Phase.FAILED
	_freeze(true)
	_cats_hud.hide()
	_hud.banner(tr("BOSS_TIME_UP"), Palette.DANGER)
	_hud.flash(Color(1.0, 0.0, 0.0, 0.5))
	_shake_camera(6.0, 0.5)
	for index: int in CatsLogic.CATS:
		_tendrils.pulse(index)
	Game.lose_heart()
	if int(World.f[Game.HEARTS]) <= 0:
		return
	await _wait(1.8)
	if not is_inside_tree():
		return
	_hud.banner(tr("BOSS_RETRY"))
	_begin()


## Победа: нити рвутся, заражение слетает с Логуновой и комнаты, коты счастливы.
func _outro() -> void:
	phase = Phase.OUTRO
	_freeze(true)
	_cats_hud.hide()
	_hud.hint = ""
	_hud.hp = 0
	_hud.flash(Color(1.0, 1.0, 1.0, 0.85))
	_shake_camera(8.0, 0.8)
	var snap := create_tween()
	snap.tween_property(_tendrils, "reach", 0.0, 0.5).set_trans(Tween.TRANS_BACK)
	await _pan(LOGUNOVA, 0.9, SCENE_ZOOM)
	_glow.emitting = false
	_cure_burst(HANDS + Vector2(0.0, -40.0))
	_cure_burst(Vector2(330.0, 140.0))
	_cure_burst(Vector2(1475.0, 140.0))
	_cured.show()
	_cured.modulate.a = 0.0
	create_tween().tween_property(_cured, "modulate:a", 1.0, CURE_SEC)
	_hud.banner(tr("BOSS_CATS_WIN"), Palette.OK)
	for mood: CatMood in _moods:
		mood.set_happy(true)
	await _wait(CURE_SEC + 0.4)
	await _pan(_hero_view(), 0.8)
	_give_view()
	_hud.hide()
	await Ui.dialogue.play(DialogueCatalog.talk(FREE_TALK))
	if not is_inside_tree():
		return
	_freeze(false)
	_lock_door(exit_door, false)
	Ui.hud.hide_task(false)
	if is_instance_valid(_cat):
		_cat.release()
	phase = Phase.DONE
	World.mark(BOSS_MARK)
	SaveSystem.save_game()
	finished.emit()


## Показывает вылеченный кабинет: чистый фон, закрытое окно, полная миска, тёплая батарея,
## довольные коты.
func _show_cured() -> void:
	_cured.show()
	_glow.emitting = false
	_window.set_open(false, false)
	_bowl.set_food(1.0)
	_radiator.heat = 0.8
	for mood: CatMood in _moods:
		mood.set_happy(true)


## Переносит числа правил на окно, миску, батарею и шкалу босса.
func _show_props() -> void:
	_bowl.set_food(logic.food)
	_radiator.heat = logic.heat
	_hud.hp = CatsLogic.CATS - logic.happy_count()


## Создаёт окно, миску, батарею, нити, облачка котов, вылеченный фон и свечение Логуновой.
func _build_props() -> void:
	_cured = Sprite2D.new()
	_cured.texture = CURED_ART
	_cured.centered = false
	_cured.z_index = -29
	_cured.hide()
	add_child(_cured)
	_window = CatsWindow.new()
	_window.position = WINDOW_AT
	_window.shot.connect(_on_window_shot)
	add_child(_window)
	_bowl = CatsBowl.new()
	_bowl.position = Vector2(BOWL_X, FLOOR_Y)
	_bowl.shot.connect(_on_bowl_shot)
	add_child(_bowl)
	_radiator = Radiator.new()
	_radiator.position = Vector2(RADIATOR_X, FLOOR_Y)
	_radiator.shot.connect(_on_radiator_shot)
	add_child(_radiator)
	_tendrils = Tendrils.new()
	_tendrils.z_index = -6
	add_child(_tendrils)
	var heads: Array[Vector2] = [Vector2(GINGER_X, FLOOR_Y - 20.0), GRAY_HEAD, BLACK_HEAD]
	_tendrils.setup(HANDS, heads)
	var wants: Array[CatMood.Want] = [CatMood.Want.HEAT, CatMood.Want.FOOD, CatMood.Want.WINDOW]
	var spots: Array[Vector2] = [Vector2(GINGER_X, FLOOR_Y + GINGER_HEAD_Y), GRAY_HEAD, BLACK_HEAD]
	for cat: int in CatsLogic.CATS:
		var mood := CatMood.new()
		mood.want = wants[cat]
		mood.position = spots[cat] - Vector2(0.0, MOOD_LIFT)
		add_child(mood)
		_moods.append(mood)
	_glow = CPUParticles2D.new()
	_glow.position = HANDS + Vector2(0.0, -50.0)
	_glow.emitting = false
	_glow.amount = 18
	_glow.lifetime = 1.2
	_glow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_glow.emission_rect_extents = Vector2(40.0, 60.0)
	_glow.direction = Vector2.UP
	_glow.spread = 30.0
	_glow.gravity = Vector2(0.0, -30.0)
	_glow.initial_velocity_min = 5.0
	_glow.initial_velocity_max = 20.0
	_glow.scale_amount_min = 2.0
	_glow.scale_amount_max = 4.0
	_glow.color_ramp = _checker_ramp()
	add_child(_glow)


## Попадание в окно закрывает его; закрытое окно только искрит.
func _on_window_shot() -> void:
	if phase != Phase.PLAY:
		return
	if logic.window_open:
		logic.close_window()
		_shake_camera(2.0, 0.15)
	else:
		_burst(WINDOW_AT + Vector2(0.0, 70.0), Palette.DEBUGGER, 6, 60.0, 1.0, 2.0)


## Попадание в миску досыпает корм.
func _on_bowl_shot() -> void:
	if phase != Phase.PLAY:
		return
	logic.feed()
	_bowl.pour()
	_show_props()


## Попадание в батарею прибавляет тепла.
func _on_radiator_shot() -> void:
	if phase != Phase.PLAY:
		return
	logic.warm()
	_radiator.pulse()
	_show_props()


## Открывает или закрывает окно на экране; распахнутое заражением окно бьёт по камере.
## [param open] - true, если окно открылось.
func _on_window_changed(open: bool) -> void:
	_window.set_open(open)
	if open and phase == Phase.PLAY:
		_tendrils.pulse(CatsLogic.BLACK)
		_shake_camera(4.0, 0.3)
		_hud.banner(tr("BOSS_WINDOW_OPEN"), Palette.DEBUGGER)


## Меняет облачко и нить кота, когда он стал доволен или недоволен.
## [param cat] - номер кота.
## [param happy] - true, если кот доволен.
func _on_mood_changed(cat: int, happy: bool) -> void:
	_moods[cat].set_happy(happy)
	_tendrils.calm[cat] = happy


## Заражение вредит коту: импульс по его нити и вспышка.
## [param cat] - номер кота, которому навредили.
func _on_sabotaged(cat: int) -> void:
	_tendrils.pulse(cat)
	_hud.flash(Color(1.0, 0.0, 1.0, 0.2))


## Все трое довольны нужное время.
func _on_won() -> void:
	_outro()


## Время вышло.
func _on_lost() -> void:
	_fail()


## Начинает бой после того, как комната показалась на экране.
## [param _code] - код комнаты.
func _on_room_entered(_code: String) -> void:
	start()
