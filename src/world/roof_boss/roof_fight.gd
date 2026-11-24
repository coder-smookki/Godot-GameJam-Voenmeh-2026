class_name RoofFight
extends BossFight
## Крыша: финальный бой с ЛАБОЙ, спасение героя Ваней и последний выбор.
##
## Герой и Мажайцев выходят на крышу и идут вправо. Камера проезжает над городом, который
## захватывают пиксели, к Троицкому собору; над крышей из пикселей собирается голограмма ЛАБЫ.
## Бой как первая фаза Компилятора: ЛАБА пускает по крыше ошибки (через них прыгают), а на
## крыше выдвигаются терминалы с бегущими числами, которые чинят отладчиком. Три подхода -
## три правила ЛАБЫ; в третьем подходе Мажайцев подходит к одному терминалу и чинит его сам.
## Всё время город захватывается: если пиксели дойдут до собора, это концовка №2.
## После третьего правила у ЛАБЫ вырастает рука из пикселей (камера летит за ней) и хватает
## героя. Прибегает Ваня и вытаскивает друга мини-игрой «Тяни!». ЛАБА сжимается в шоке, перед
## героями из крыши поднимается терминал с выбором: удалить ЛАБУ или исправить её.

signal finished

enum Phase { WAIT, INTRO, ROUND, BREAK, GRAB, RESCUE, CHOICE, LOST, DONE }

const RULES := 3
const TRIGGER_X := 1300.0
const BOSS_POS := Vector2(900.0, 112.0)
const CATHEDRAL_VIEW := Vector2(1100.0, 120.0)
const FLOOR_Y := 251.0
const GRAB_X := 1150.0
const ROUNDS: Array = [[560.0, 1250.0], [380.0, 1180.0, 1520.0], [460.0, 760.0, 1350.0, 1600.0]]
const HELPER_ROUND := 2
const HAND_FRAMES: Array[Texture2D] = [
	preload("res://assets/boss/roof/hand_1.png"),
	preload("res://assets/boss/roof/hand_2.png"),
	preload("res://assets/boss/roof/hand_4.png"),
]
const GRAB_FRAMES: Array[Texture2D] = [
	preload("res://assets/boss/roof/grab_1.png"),
	preload("res://assets/boss/roof/grab_2.png"),
]
const VANYA_PULL: Texture2D = preload("res://assets/characters/vanya/pull_friend.png")
const HAND_SCALE := 0.9
const HAND_HERO := Vector2(234.0, 277.0)
const GRAB_FPS := 5.0
const ROOF_ZOOM := 0.6
const FRAME_BOSS := 0.35
const INVULNERABLE_SEC := 1.2
const PUSH := Vector2(240.0, -200.0)
const SPAWN_GAP := 130.0
const PINK := Color(1.0, 0.0, 1.0)
const DARK := Color(0.0, 0.07, 0.0)
const HOLO := Color(0.45, 0.85, 1.0)

var phase: Phase = Phase.WAIT
var rule: int = 0
var integrity: int = 3
var integrity_max: int = 3
var time_total: float = 300.0
var time_left: float = 300.0

var _laba: LabaHologram = null
var _city: CityCapture = null
var _mozh: Walker = null
var _vanya: Walker = null
var _hand: Sprite2D = null
var _terminal: FinalTerminal = null
var _errors: Node2D = null
var _columns: Array[FixColumn] = []
var _clock: float = 0.0
var _spawn_left: float = 0.0
var _invulnerable: float = 0.0
var _round_token: int = 0


## Собирает город, голограмму, ошибки, камеру и экраны; ждёт героя.
func _ready() -> void:
	_build_director(CATHEDRAL_VIEW)
	_build_bars()
	var layer := _build_hud()
	var timer_hud := RoofHud.new()
	timer_hud.fight = self
	layer.add_child(timer_hud)
	_city = CityCapture.new()
	add_child(_city)
	_laba = LabaHologram.new()
	_laba.position = BOSS_POS
	add_child(_laba)
	_errors = Node2D.new()
	add_child(_errors)
	_hand = Sprite2D.new()
	_hand.centered = false
	_hand.scale = Vector2(HAND_SCALE, HAND_SCALE)
	_hand.z_index = 6
	_hand.hide()
	add_child(_hand)
	integrity_max = Difficulty.value("boss_integrity")
	integrity = integrity_max
	time_total = World.final_timer_sec() * float(Difficulty.value("roof_time"))
	time_left = time_total
	Game.room_entered.connect(_on_room_entered, CONNECT_ONE_SHOT)


## Ведёт время города, камеру, атаки ЛАБЫ, мигание героя и хватку руки.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	if phase == Phase.WAIT:
		_check_trigger()
		return
	if phase in [Phase.ROUND, Phase.BREAK, Phase.RESCUE, Phase.CHOICE] and not get_tree().paused:
		time_left = maxf(time_left - delta, 0.0)
		_city.progress = lerpf(CityCapture.START, 1.0, 1.0 - time_left / time_total)
		if time_left <= 0.0:
			_city_lost()
			return
	if _hand.visible and phase in [Phase.GRAB, Phase.RESCUE] and _hand.texture in GRAB_FRAMES:
		_hand.texture = GRAB_FRAMES[int(_clock * GRAB_FPS) % GRAB_FRAMES.size()]
	if not is_instance_valid(_player):
		return
	if _invulnerable > 0.0:
		_invulnerable -= delta
		var blink := int(_invulnerable * 12.0) % 2 == 0 and _invulnerable > 0.0
		_player.modulate.a = 0.35 if blink else 1.0
	for line: Node in _errors.get_children():
		var error := line as ErrorLine
		if error != null and (error.position.x < -60.0 or error.position.x > 1760.0):
			error.vanish()
	if phase == Phase.ROUND:
		var target := lerpf(_player.global_position.x, BOSS_POS.x, FRAME_BOSS)
		var follow := 1.0 - exp(-FOLLOW_RATE * delta)
		_director.global_position.x = lerpf(_director.global_position.x, target, follow)
		_spawn_left -= delta
		if _spawn_left <= 0.0:
			_spawn_left = _next_interval()
			_attack()


## Сообщает, идёт ли бой.
func is_running() -> bool:
	return phase != Phase.WAIT and phase != Phase.DONE


## Возвращает терминалы текущего подхода; нужно тестам.
func columns() -> Array[FixColumn]:
	return _columns


## Возвращает Мажайцева; нужно тестам.
func mozhaitsev() -> Walker:
	return _mozh


## Возвращает Ваню; нужно тестам.
func vanya() -> Walker:
	return _vanya


## Возвращает терминал выбора; нужно тестам.
func terminal() -> FinalTerminal:
	return _terminal


## Возвращает голограмму ЛАБЫ; нужно тестам.
func laba() -> LabaHologram:
	return _laba


## Начинает бой: город, собор, голограмма, слова героя, первый подход.
func start() -> void:
	if phase != Phase.WAIT:
		return
	phase = Phase.INTRO
	process_mode = Node.PROCESS_MODE_ALWAYS
	_freeze(true)
	_player.facing = -1
	Ui.hud.hide_task(true)
	Music.play("roof")
	_director.global_position = _hero_view()
	_director.zoom = Vector2.ONE
	_take_view()
	if _mozh != null:
		_mozh.follow(null)
	await _pan(CATHEDRAL_VIEW, 1.8, 0.8)
	await _wait(0.6)
	await _pan(BOSS_POS + Vector2(0.0, 20.0), 1.2, 1.0)
	_converge(BOSS_POS)
	await _wait(0.5)
	_shake_camera(6.0, 1.4)
	_hud.show()
	_hud.flash(Color(0.5, 0.9, 1.0, 0.6))
	await _laba.materialize(1.4)
	_laba.roar()
	_burst(BOSS_POS, HOLO, 40, 260.0, 2.0, 5.0)
	_shake_camera(10.0, 0.6)
	_hud.boss_name = tr("BOSS_LABA")
	_hud.hp_max = RULES
	_hud.hp = RULES
	_hud.charge_max = 0
	_hud.integrity_max = integrity_max
	_hud.integrity = integrity
	_hud.banner(tr("BOSS_LABA_INTRO"), BossHud.BOSS_COLOR)
	await _wait(1.4)
	await Story.play_once("roof")
	if not is_inside_tree():
		return
	await _pan(Vector2(_player.global_position.x, VIEW_Y), 1.0, ROOF_ZOOM)
	if _mozh != null:
		_mozh.follow(_player)
	_start_round()


## Выдвигает терминалы подхода; в третьем подходе Мажайцев идёт чинить один из них.
func _start_round() -> void:
	_round_token += 1
	_clear_columns()
	var wanted: Array[int] = [2, 5, 7, 3, 8, 4, 6, 9, 1]
	wanted.shuffle()
	var positions: Array = ROUNDS[mini(rule, ROUNDS.size() - 1)]
	for index: int in positions.size():
		var column := FixColumn.new()
		column.position = Vector2(positions[index], FLOOR_Y)
		column.z_index = -5
		column.fixed.connect(_on_column_fixed)
		column.missed.connect(_on_column_missed)
		add_child(column)
		column.rise(wanted[index])
		_columns.append(column)
		_burst(column.position + Vector2(0.0, -20.0), PINK, 10, 120.0, 2.0, 4.0)
	_hud.hint = tr("BOSS_HINT_LABA").format({"n": rule + 1, "total": RULES})
	integrity = integrity_max
	_hud.integrity = integrity
	_spawn_left = 1.4
	phase = Phase.ROUND
	_freeze(false)
	if rule == HELPER_ROUND:
		_hud.banner(tr("BOSS_MOZH_HELPS"), Palette.DEBUGGER)
		_helper(_round_token)


## Мажайцев подходит к случайному непочиненному терминалу и чинит его сам.
## [param token] - номер подхода; если подход сменился, Мажайцев не чинит.
func _helper(token: int) -> void:
	if _mozh == null:
		return
	await _wait(1.0)
	var open: Array[FixColumn] = []
	for column: FixColumn in _columns:
		if not column.is_fixed:
			open.append(column)
	if open.is_empty() or token != _round_token:
		return
	var target: FixColumn = open[randi() % open.size()]
	_mozh.follow(null)
	await _mozh.walk_to(target.position.x - 26.0, 160.0)
	if token != _round_token or phase != Phase.ROUND or not is_instance_valid(target):
		_mozh.follow(_player)
		return
	_mozh.face(1.0)
	await _wait(0.4)
	if token == _round_token and phase == Phase.ROUND and is_instance_valid(target):
		_burst(target.global_position + Vector2(0.0, -90.0), Palette.DEBUGGER, 16, 140.0, 1.0, 3.0)
		target.assist()
	_mozh.follow(_player)


## Отключает правило: терминалы уходят, ЛАБУ корёжит, камера бьёт ближе.
func _rule_off() -> void:
	phase = Phase.BREAK
	_round_token += 1
	_freeze(true)
	_clear_errors()
	_hud.hint = ""
	for column: FixColumn in _columns:
		_burst(column.global_position + Vector2(0.0, -60.0), Palette.OK, 14, 180.0, 2.0, 4.0)
		column.sink()
	rule += 1
	_hud.damage()
	_laba.hurt()
	var ring := Blast.new()
	ring.global_position = BOSS_POS
	add_child(ring)
	_burst(BOSS_POS, PINK, 30, 260.0, 2.0, 6.0)
	_burst(BOSS_POS, HOLO, 20, 220.0, 1.0, 3.0)
	_hud.flash(Color(1.0, 1.0, 1.0, 0.7))
	_hud.banner(tr("BOSS_RULE_OFF").format({"n": rule}), Palette.OK)
	_shake_camera(9.0, 0.7)
	await _pan(BOSS_POS + Vector2(0.0, 30.0), 0.5, 1.0)
	await _wait(1.2)
	if rule >= RULES:
		await _grab()
		return
	await _pan(Vector2(_player.global_position.x, VIEW_Y), 0.7, ROOF_ZOOM)
	_start_round()


## Рука ЛАБЫ: растёт из пикселей, камера летит за ней, рука хватает героя.
func _grab() -> void:
	phase = Phase.GRAB
	_clear_columns()
	_laba.roar()
	_hud.banner(tr("BOSS_LABA_GRAB"), BossHud.BOSS_COLOR)
	if _mozh != null:
		_mozh.follow(null)
		_mozh.walk_to(GRAB_X + 260.0, 200.0)
	var drag := create_tween()
	drag.tween_property(_player, "global_position:x", GRAB_X, 0.5).set_trans(Tween.TRANS_QUAD)
	_player.facing = -1
	await drag.finished
	var origin := Vector2(GRAB_X, FLOOR_Y) - HAND_HERO * HAND_SCALE
	_hand.position = origin
	_hand.texture = HAND_FRAMES[0]
	_hand.show()
	var root := origin + Vector2(86.0, 165.0) * HAND_SCALE
	_burst(root, PINK, 24, 160.0, 2.0, 5.0)
	_shake_camera(6.0, 0.4)
	await _pan(root, 0.45, 1.7)
	await _wait(0.35)
	_hand.texture = HAND_FRAMES[1]
	_burst(root + Vector2(60.0, 10.0), PINK, 20, 200.0, 2.0, 5.0)
	_shake_camera(7.0, 0.35)
	await _pan(origin + Vector2(150.0, 170.0) * HAND_SCALE, 0.35, 1.4)
	await _wait(0.25)
	_hand.texture = HAND_FRAMES[2]
	_burst(Vector2(GRAB_X, FLOOR_Y - 80.0), DARK, 20, 220.0, 2.0, 5.0)
	await _pan(Vector2(GRAB_X - 40.0, 160.0), 0.3, 1.3)
	_player.hide()
	_hand.texture = GRAB_FRAMES[0]
	_hud.flash(Color(1.0, 0.0, 0.3, 0.6))
	_shake_camera(12.0, 0.8)
	await _wait(0.6)
	await Ui.dialogue.play(DialogueCatalog.talk("roof_grabbed"))
	if not is_inside_tree():
		return
	await _rescue()


## Прибегает Ваня и вытаскивает друга; ЛАБА сжимается в шоке.
func _rescue() -> void:
	phase = Phase.RESCUE
	Music.play("roof_rescue")
	_vanya = Walker.vanya()
	_vanya.name = "Vanya"
	_vanya.position = Vector2(1760.0, FLOOR_Y)
	get_parent().get_node("Actors").add_child(_vanya)
	await _pan(Vector2(1500.0, 150.0), 0.6, 1.0)
	var follow := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	follow.tween_property(_director, "global_position:x", GRAB_X + 60.0, 1.6)
	await _vanya.walk_to(GRAB_X + 70.0, 240.0)
	_vanya.face(1.0)
	_vanya.set_pose(VANYA_PULL)
	_burst(Vector2(GRAB_X + 40.0, FLOOR_Y - 70.0), Color.WHITE, 12, 120.0, 1.0, 3.0)
	await Ui.dialogue.play(DialogueCatalog.talk("roof_vanya"))
	if not is_inside_tree():
		return
	Ui.pull.pulled.connect(_on_pulled)
	Ui.pull.jerk_done.connect(_on_jerk)
	while true:
		var won: bool = await Ui.pull.play()
		if not is_inside_tree():
			return
		if won:
			break
		_hud.flash(Color(1.0, 0.0, 0.0, 0.5))
		Game.lose_heart()
		if int(World.f[Game.HEARTS]) <= 0:
			return
		await _wait(1.0)
	Ui.pull.pulled.disconnect(_on_pulled)
	Ui.pull.jerk_done.disconnect(_on_jerk)
	await _free_hero()


## Рука отпускает героя и уходит, ЛАБА в шоке, из крыши поднимается терминал выбора.
func _free_hero() -> void:
	_hud.flash(Color(1.0, 1.0, 1.0, 0.85))
	_shake_camera(10.0, 0.7)
	_burst(Vector2(GRAB_X, FLOOR_Y - 90.0), PINK, 40, 260.0, 2.0, 6.0)
	_player.show()
	_player.global_position.x = GRAB_X + 10.0
	_vanya.set_pose(null)
	for index: int in range(HAND_FRAMES.size() - 1, -1, -1):
		_hand.texture = HAND_FRAMES[index]
		await _wait(0.12)
	_hand.hide()
	_laba.shock()
	_hud.banner(tr("BOSS_LABA_SHOCK"), Palette.GOAL)
	await _pan(BOSS_POS + Vector2(0.0, 30.0), 0.7, 1.1)
	await _wait(1.2)
	_player.facing = -1
	_vanya.face(-1.0)
	_terminal = FinalTerminal.new()
	_terminal.position = Vector2(GRAB_X - 110.0, FLOOR_Y)
	_terminal.chosen.connect(_on_terminal_chosen)
	get_parent().get_node("Props").add_child(_terminal)
	await _pan(Vector2(GRAB_X - 50.0, VIEW_Y), 0.8, 1.0)
	await _terminal.rise()
	_burst(_terminal.position + Vector2(0.0, -40.0), Palette.DEBUGGER, 24, 180.0, 1.0, 4.0)
	await Ui.dialogue.play(DialogueCatalog.talk("roof_choice"))
	if not is_inside_tree():
		return
	Music.play("ending")
	_give_view()
	_hud.hint = tr("BOSS_HINT_CHOICE")
	phase = Phase.CHOICE
	_freeze(false)


## Город захвачен: пиксели накрывают собор, концовка №2.
func _city_lost() -> void:
	phase = Phase.LOST
	_freeze(true)
	_clear_errors()
	_clear_columns()
	_director.global_position = (
		_director.get_screen_center_position() if _director.enabled else _hero_view()
	)
	_take_view()
	await _pan(CATHEDRAL_VIEW, 0.9, 0.9)
	await _city.swallow(1.4)
	_shake_camera(10.0, 0.8)
	_hud.flash(Color(1.0, 0.0, 1.0, 0.8))
	await _wait(1.0)
	Game.show_ending("not_found")


## Терминал выбран: концовка по выбору.
## [param chosen_terminal] - "delete" или "fix".
func _on_terminal_chosen(chosen_terminal: String) -> void:
	if phase != Phase.CHOICE:
		return
	phase = Phase.DONE
	_freeze(true)
	_hud.hint = ""
	var ending_id := World.ending(chosen_terminal)
	if chosen_terminal == "delete":
		_laba.glitch(2.0)
		_city.progress = CityCapture.START
	World.mark("roof_done")
	SaveSystem.save_game()
	finished.emit()
	Game.show_ending(ending_id)


## Пускает ошибку от голограммы по крыше к герою; позже ошибки идут чаще и бывают высокими.
func _attack() -> void:
	_laba.roar()
	var from := BOSS_POS.x
	var hero := _player.global_position.x
	if absf(hero - from) < SPAWN_GAP:
		from = hero + (SPAWN_GAP + 200.0) * (1.0 if randf() < 0.5 else -1.0)
		from = clampf(from, 20.0, 1680.0)
	var line := ErrorLine.new()
	var speed := (190.0 + rule * 20.0) * float(Difficulty.value("attack_speed"))
	var tall := randf() < 0.25 + 0.15 * rule + float(Difficulty.value("attack_high"))
	line.floor_y = FLOOR_Y
	line.setup_slide(from, hero > from, speed + (25.0 if tall else 0.0), _player, tall)
	line.touched.connect(_on_touched)
	_errors.add_child(line)
	_burst(Vector2(from, FLOOR_Y - 20.0), PINK, 10, 140.0, 2.0, 4.0)


## Выбирает паузу до следующей атаки: с каждым правилом короче.
func _next_interval() -> float:
	return randf_range(1.8, 2.5) * pow(0.88, rule) * float(Difficulty.value("attack_pause"))


## Ошибка задела героя: минус целостность, отброс, неуязвимость; ноль - минус сердце.
## [param line] - ошибка.
func _on_touched(line: ErrorLine) -> void:
	if _invulnerable > 0.0 or phase != Phase.ROUND:
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
		_fail_round()


## Подход сорван: минус сердце, подход заново.
func _fail_round() -> void:
	phase = Phase.BREAK
	_round_token += 1
	_freeze(true)
	_clear_errors()
	_hud.banner(tr("BOSS_FAILED"), Palette.DANGER)
	_laba.roar()
	Game.lose_heart()
	if int(World.f[Game.HEARTS]) <= 0:
		return
	await _wait(1.6)
	if not is_inside_tree():
		return
	_hud.banner(tr("BOSS_RETRY"))
	_start_round()


## Отвечает на починку терминала: все починены - правило отключено.
## [param _column] - починенный терминал.
func _on_column_fixed(_column: FixColumn) -> void:
	_laba.glitch(0.4)
	_shake_camera(3.0, 0.25)
	if phase != Phase.ROUND:
		return
	for column: FixColumn in _columns:
		if not column.is_fixed:
			return
	_rule_off()


## Промах по терминалу: ЛАБА сразу стреляет.
## [param _column] - терминал, по которому промахнулись.
func _on_column_missed(_column: FixColumn) -> void:
	if phase == Phase.ROUND:
		_attack()


## Ваня рванул: рука дёргается.
func _on_pulled() -> void:
	_hand.position.x += 2.0
	var back := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	back.tween_property(_hand, "position:x", _hand.position.x - 2.0, 0.1)


## Рывок сделан: клетки летят из руки.
## [param _index] - номер рывка.
func _on_jerk(_index: int) -> void:
	_burst(Vector2(GRAB_X, FLOOR_Y - 90.0), PINK, 20, 200.0, 2.0, 5.0)
	_laba.glitch(0.5)


## Убирает ошибки.
func _clear_errors() -> void:
	for line: Node in _errors.get_children():
		if line is ErrorLine:
			line.vanish()


## Убирает терминалы.
func _clear_columns() -> void:
	for column: FixColumn in _columns:
		if is_instance_valid(column):
			column.queue_free()
	_columns.clear()


## Пиксели со всей крыши слетаются в точку, где появится голограмма.
## [param at] - точка сбора.
func _converge(at: Vector2) -> void:
	for color: Color in [PINK, DARK, HOLO]:
		var cells := CPUParticles2D.new()
		cells.global_position = at
		cells.amount = 40
		cells.lifetime = 1.2
		cells.one_shot = true
		cells.explosiveness = 0.6
		cells.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		cells.emission_sphere_radius = 220.0
		cells.gravity = Vector2.ZERO
		cells.radial_accel_min = -260.0
		cells.radial_accel_max = -200.0
		cells.scale_amount_min = 3.0
		cells.scale_amount_max = 6.0
		cells.color = color
		cells.z_index = 30
		cells.finished.connect(cells.queue_free)
		add_child(cells)
		cells.emitting = true


## Начинает бой, когда герой прошёл крышу вправо.
func _check_trigger() -> void:
	if not is_instance_valid(_player) or Ui.is_modal_open() or Game.is_busy():
		return
	if _player.global_position.x >= TRIGGER_X:
		start()


## Ставит Мажайцева рядом с героем: он вышел на крышу вместе с ним.
## [param _code] - код комнаты.
func _on_room_entered(_code: String) -> void:
	var room := get_tree().current_scene as Room
	if room == null or room.player == null:
		return
	_player = room.player
	_mozh = Walker.mozhaitsev()
	_mozh.name = "Mozhaitsev"
	_mozh.position = Vector2(_player.global_position.x - 70.0, FLOOR_Y)
	room.get_node("Actors").add_child(_mozh)
	_mozh.follow(_player)
	Story.play_once("roof_arrival")
