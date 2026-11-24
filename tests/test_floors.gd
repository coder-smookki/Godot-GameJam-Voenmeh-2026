extends TestCase
## Сквозные тесты этажей: кабина лифта, второй этаж с надписью ERROR и отладчиком, сердца,
## этажи 3-4.


## Двери лифта ведут в кабину; в первый раз герой замечает пропавшие кнопки.
## Панель кнопок открывается у стены кабины, двери кабины выводят на тот же этаж.
func test_elevator_first_look() -> void:
	await start_game()
	var room := tree.current_scene as Room
	var doors: ElevatorDoor = room.get_node("Props/Elevator")
	doors.interact(room.player)
	check(not Game.is_busy() and not Ui.dialogue.visible, "пока Ваня не спасён, лифт не работает")
	World.mark("vanya_saved")
	doors.interact(room.player)
	await Game.room_entered
	equal(Game.room_code, Game.LIFT_ROOM, "герой в кабине лифта")
	equal(Game.current_floor(), 1, "кабина помнит этаж, где герой вошёл")
	equal(Infection.current_floor, 1, "в кабине этаж на плашке прежний")
	check(Ui.dialogue.visible, "сначала реплика о кнопках")
	finish_talk()
	var cabin := tree.current_scene as Room
	var art: LiftArt = cabin.get_node("Backdrop/Art")
	equal(art.texture, LiftArt.ART[0], "горят кнопки первого и второго этажей")
	var buttons: LiftButtons = cabin.get_node("Props/Buttons")
	buttons.interact(cabin.player)
	check(Ui.elevator.visible, "у стены открылась панель кнопок")
	Ui.elevator.close()
	var exit: LiftExit = cabin.get_node("Props/Exit")
	exit.interact(cabin.player)
	await Game.room_entered
	equal(Game.room_code, "vestibule", "герой вышел на свой этаж")
	equal(Game.spawn_id, Elevator.SPAWN, "у дверей лифта")
	room = tree.current_scene as Room
	room.get_node("Props/Elevator").interact(room.player)
	await Game.room_entered
	check(not Ui.dialogue.visible, "во второй раз реплики нет")


## На третьем этаже у лифта героя встречает Лестенко: разговор по сценарию с его позами,
## подарок над головой героя, потом Лестенко уходит к лифту и больше не появляется.
func test_floor_3_lestenko() -> void:
	await start_game()
	World.mark("vanya_saved")
	World.mark("boss_2")
	await Game.enter_lift()
	finish_talk()
	check(tree.current_scene.get_node_or_null("Actors/Lestenko") == null, "в кабине его нет")
	await Game.goto_room("corridor_3", Elevator.SPAWN)
	var room := tree.current_scene as Room
	var lestenko: Npc = room.get_node("Actors/Lestenko")
	check(Ui.dialogue.visible, "Лестенко встречает героя")
	equal(lestenko.current_texture(), lestenko.poses["stand"], "пока говорит герой, он стоит")
	Ui.dialogue.advance()
	Ui.dialogue.advance()
	equal(lestenko.current_texture(), lestenko.poses["talk"], "на своей реплике говорит")
	finish_talk()
	check(World.is_marked("seen_lestenko"), "разговор запомнен")
	check(_announced(room.player, "ANNOUNCE_RAM"), "над головой плашка с подарком")
	equal(lestenko.current_texture(), lestenko.poses["stand"], "после разговора снова стоит")
	await _until(func() -> bool: return not is_instance_valid(lestenko))
	await Game.enter_lift()
	await Game.leave_lift()
	check(tree.current_scene.get_node_or_null("Actors/Lestenko") == null, "Лестенко уехал")


## Второй этаж по сценарию и заметкам: паника, Наурусова у надписи ERROR в позах художниц,
## отладчик над головой, мини-игра открывается сама.
func test_floor_2_story() -> void:
	await start_game()
	World.mark("vanya_saved")
	await Game.goto_room("corridor_2", Elevator.SPAWN)
	finish_talk()
	var room := tree.current_scene as Room
	var crowd: RunnerCrowd = room.get_node("Actors/Crowd")
	equal(crowd.size(), 8, "по коридору бегают люди")
	check(room.get_node_or_null("Props/Kafedra") == null, "у двери 201 нет входа")
	var naurusova: Npc = room.get_node("Actors/Naurusova")
	var totem: Totem = room.get_node("Actors/Totem")
	check(naurusova.global_position.x - totem.global_position.x < 250.0, "Наурусова у надписи")
	equal(naurusova.current_texture(), naurusova.poses["neutral"], "Наурусова нарисована")
	room.player.global_position.x = naurusova.global_position.x + 120.0
	await crowd.vanished
	await tree.process_frame
	check(room.get_node_or_null("Actors/Crowd") == null, "у Наурусовой паника стихла")
	naurusova.interact(room.player)
	check(Ui.dialogue.visible, "Наурусова заговорила")
	equal(naurusova.current_texture(), naurusova.poses["neutral2"], "первая реплика в своей позе")
	Ui.dialogue.advance()
	Ui.dialogue.advance()
	equal(naurusova.current_texture(), naurusova.poses["questioning"], "зовёт с собой жестом")
	finish_talk()
	check(World.is_marked("ability_debugger"), "Наурусова дала отладчик")
	check(_announced(room.player, "ANNOUNCE_DEBUGGER"), "над головой плашка «Получен отладчик»")
	equal(Game.task_key, "TASK_DEBUG_CODE", "задание: отладить код")
	equal(naurusova.current_texture(), naurusova.poses["neutral"], "после разговора обычная поза")
	await tree.create_timer(Totem.AUTO_DEBUG_SEC + 0.2).timeout
	check(Ui.debug.visible, "мини-игра с кодом на C открылась сама")
	Ui.close_all_modals()


## Надпись ERROR не пускает героя дальше и кричит битыми символами. Отладка её кода печатает
## послание ЛАБЫ, буквы осыпаются, этаж лечится, кабинет 202 открывается, 203 остаётся заражён.
func test_error_barrier() -> void:
	await start_game()
	await Game.goto_room("corridor_2", Elevator.SPAWN)
	finish_talk()
	var room := tree.current_scene as Room
	var totem: Totem = room.get_node("Actors/Totem")
	var door: Door = room.get_node("Props/Room202")
	var sealed: Door = room.get_node("Props/Room203")
	check(not door.is_open() and not sealed.is_open(), "кабинеты за надписью закрыты")
	equal(door.plate_text(), "", "номер кабинета нарисован на фоне, табличка не нужна")
	room.player.global_position.x = totem.global_position.x + 4.0
	for frame: int in 4:
		await tree.physics_frame
	check(room.player.is_stunned(), "надпись оттолкнула героя")
	check(room.player.velocity.x > 0.0, "героя отбросило назад, к лифту")
	check(totem.get_node("Voice").visible, "надпись кричит битыми символами")
	World.mark("ability_debugger")
	await tree.create_timer(Totem.AUTO_DEBUG_SEC + 0.2).timeout
	check(Ui.debug.visible and tree.paused, "отладка открылась сама")
	var before := Infection.percent(2)
	var logic := Ui.debug.logic()
	logic.point(logic.bug_line())
	Ui.debug.choose()
	logic.point(logic.answer())
	Ui.debug.choose()
	check(logic.is_solved(), "код исправлен")
	await tree.create_timer(DebugGame.SOLVED_HOLD_SEC + 0.4).timeout
	check(not Ui.debug.visible, "окно отладчика закрылось")
	equal(World.f["messages"], 1, "послание ЛАБЫ найдено")
	check(World.is_marked("message_1"), "послание запомнено")
	await tree.create_timer(Totem.SHATTER_STEP_SEC * 6.0 + 0.2).timeout
	check(World.is_marked("totem_corridor_2") and World.is_marked("first_totem"), "надпись разбита")
	equal(Infection.percent(2), before - 8, "заражение этажа упало на 8%")
	check(door.is_open(), "кабинет 202 открылся")
	check(not sealed.is_open(), "заражённый кабинет остался закрыт")
	equal(Game.task_key, "TASK_TALK_VALSHTEIN", "новое задание")
	equal(World.f["hearts"], 3, "сердца целы")
	await Game.goto_room("202", "door")
	await Game.goto_room("corridor_2", "from_202")
	room = tree.current_scene as Room
	check(room.get_node_or_null("Actors/Totem") == null, "разбитая надпись не вернулась")
	check(room.get_node_or_null("Actors/Naurusova") == null, "Наурусова ушла")
	check(room.get_node_or_null("Backdrop/Seal") != null, "шахматка на двери 203 осталась")


## Время отладки вышло: минус сердце, надпись стоит, отладку можно начать снова.
func test_debug_timeout_costs_heart() -> void:
	await start_game()
	World.mark("seen_corridor_2_arrival")
	await Game.goto_room("corridor_2", Elevator.SPAWN)
	World.mark("ability_debugger")
	var room := tree.current_scene as Room
	var totem: Totem = room.get_node("Actors/Totem")
	await tree.create_timer(Totem.AUTO_DEBUG_SEC + 0.2).timeout
	check(Ui.debug.visible, "отладка открыта")
	Ui.debug.logic().advance(DebugLogic.TIME_SEC)
	await tree.create_timer(DebugGame.FAILED_HOLD_SEC + DebugGame.SHAKE_SEC * 2.0 + 0.3).timeout
	check(not Ui.debug.visible, "окно закрылось")
	equal(World.f["hearts"], 2, "минус сердце")
	equal(totem.letters_left(), Totem.LETTERS.size(), "надпись цела")
	check(not World.is_marked("message_1"), "послание не найдено")
	totem.interact(room.player)
	check(Ui.debug.visible, "отладку можно начать снова")
	Ui.close_all_modals()


## Сгусток ошибки на четвёртом этаже: три попадания, после первого он показан раненым.
func test_blob() -> void:
	await start_game()
	await Game.goto_room("corridor_4", Elevator.SPAWN)
	var room := tree.current_scene as Room
	var blob: Blob = room.get_node("Actors/Blob")
	var door: Door = room.get_node("Props/Room418")
	check(not door.is_open(), "сгусток держит дверь 418")
	blob.hit()
	equal(blob.get_node("Sprite").texture, Blob.HURT, "после попадания кадр с уроном")
	blob.hit()
	check(not World.is_marked(blob.mark_name()), "после двух попаданий сгусток жив")
	blob.hit()
	check(World.is_marked(blob.mark_name()), "третье попадание его лопнуло")
	check(door.is_open(), "дверь 418 открыта")
	await Game.goto_room("corridor_2", Elevator.SPAWN)
	finish_talk()
	await Game.goto_room("corridor_4", Elevator.SPAWN)
	room = tree.current_scene as Room
	check(room.get_node_or_null("Actors/Blob") == null, "лопнувший сгусток не вернулся")
	check(room.get_node_or_null("Props/Seal") == null, "шахматка с двери ушла")


## Кот на третьем этаже замечает героя, бежит к кабинету 316 и ждёт у двери; когда герой
## входит в 316, кошка становится спутником и ходит за ним по всем комнатам.
func test_cat_runs_away() -> void:
	await start_game()
	await Game.goto_room("corridor_3", Elevator.SPAWN)
	finish_talk()
	var room := tree.current_scene as Room
	var cat: Cat = room.get_node("Actors/Cat")
	for frame: int in 3:
		await tree.physics_frame
	check(not cat.is_running(), "кот сидит, пока герой далеко")
	cat.exit_x = cat.global_position.x + 60.0
	room.player.global_position.x = cat.global_position.x - 60.0
	for frame: int in 4:
		await tree.physics_frame
	check(cat.is_running(), "кот заметил героя")
	check(cat.get_node("Meow").visible, "кот мяукнул")
	await cat.arrived
	check(World.is_marked("cat_316"), "кот добежал до двери")
	check(cat.is_at_door(), "и ждёт у неё")
	equal(cat.global_position.y, cat.floor_y, "кот спрыгнул на пол")
	await tree.create_timer(0.5).timeout
	check(is_instance_valid(cat) and cat.visible, "в дверь кот не ушёл")
	await Game.goto_room("vestibule", "elevator")
	await Game.goto_room("corridor_3", Elevator.SPAWN)
	var waiting: Cat = tree.current_scene.get_node("Actors/Cat")
	check(waiting.is_at_door(), "кот снова ждёт у двери 316")
	check((tree.current_scene as Room).cat == null, "спутника ещё нет")
	World.mark("boss_3")
	await Game.goto_room("316", "door")
	room = tree.current_scene as Room
	check(World.is_marked("cat_joined"), "в 316 кошка присоединилась")
	check(room.cat != null, "кошка в кабинете рядом с героем")
	room.player.global_position.x += 300.0
	await tree.create_timer(0.2).timeout
	check(not room.cat.is_resting(), "герой ушёл, кошка бежит следом")
	await tree.create_timer(2.0).timeout
	check(room.cat.is_resting(), "кошка догнала героя и села")
	await Game.goto_room("corridor_3", "from_316")
	room = tree.current_scene as Room
	check(room.get_node_or_null("Actors/Cat") == null, "кот у двери больше не нужен")
	check(room.cat != null, "кошка ходит за героем и в коридоре")


## Без сердец игра показывает заставку и начинается заново, а открытые концовки остаются.
func test_game_over_restarts() -> void:
	await start_game()
	World.mark("vanya_saved")
	SaveSystem.unlock_ending("expelled")
	World.set_value("hearts", 1)
	Game.lose_heart()
	await tree.process_frame
	check(Ui.game_over.visible and tree.paused, "заставка проигрыша")
	check(not Ui.hud.visible, "интерфейс комнаты спрятан")
	await tree.create_timer(GameOverScreen.HINT_AT + 0.1).timeout
	check(Ui.game_over.can_skip(), "заставку можно закончить")
	Ui.game_over.skip()
	await Game.room_entered
	check(not Ui.game_over.visible, "заставка закрыта")
	equal(Game.room_code, "vestibule", "игра началась с вестибюля")
	equal(World.f["hearts"], 3, "сердца снова полные")
	check(not World.is_marked("vanya_saved"), "прохождение сброшено")
	check(SaveSystem.is_ending_unlocked("expelled"), "открытые концовки остались")
	finish_talk()


## У кнопок лифта нет рамки: выбранная кнопка показана оранжевым номером.
func test_lift_panel_frames() -> void:
	await start_game()
	World.mark("vanya_saved")
	Ui.elevator.open()
	var keys: Control = Ui.elevator.get_node("Art/Keys")
	equal(keys.get_child_count(), 5, "пять кнопок")
	var second: Button = keys.get_child(1)
	check(second.has_focus(), "выбран второй этаж")
	check(second.get_theme_stylebox("focus") is StyleBoxEmpty, "рамки фокуса нет")
	equal(second.get_theme_color("font_focus_color"), ElevatorPanel.CHOSEN, "номер оранжевый")
	equal(second.get_theme_color("font_hover_color"), ElevatorPanel.CHOSEN, "и при наведении")
	Ui.elevator.close()


## Проверяет, висит ли над героем плашка с этим текстом.
## [param player] - герой.
## [param text_key] - ключ текста плашки.
func _announced(player: Player, text_key: String) -> bool:
	for child: Node in player.get_children():
		if child is Label and child.text == tr(text_key):
			return true
	return false


## Бой с Компилятором в кабинете 202: Вальштейн у капибары, бой у монитора, прыжки через
## ошибки, три бомбы Вальштейна, капибара, победа и кнопка третьего этажа.
func test_compiler_fight() -> void:
	await start_game()
	World.mark("totem_corridor_2")
	await Game.goto_room("202", "door")
	var room := tree.current_scene as Room
	var fight: CompilerFight = room.get_node("Fight")
	check(Ui.dialogue.visible, "Вальштейн заговорил при входе")
	check(fight.director().is_current(), "камера боя снимает разговор")
	check(fight.director().global_position.x < 300.0, "камера на Вальштейне")
	for press: int in 4:
		Ui.dialogue.advance()
	await tree.create_timer(1.2).timeout
	check(fight.director().global_position.x > 800.0, "на словах о компиляторе камера на мониторе")
	finish_talk()
	await _until(func() -> bool: return not fight.is_meeting())
	equal(Game.task_key, "TASK_FIGHT_COMPILER", "задание: к монитору")
	check(room.get_viewport().get_camera_2d().get_parent() is Player, "камера вернулась к герою")
	check(room.player.controls_enabled, "герой снова идёт сам")
	var valshtein: Npc = room.get_node("Actors/Valshtein")
	check(valshtein.global_position.x < 245.0, "Вальштейн левее капибары")
	equal(valshtein.current_texture(), valshtein.poses["infected"], "Вальштейн заражён")
	Engine.time_scale = 4.0
	room.player.global_position.x = 800.0
	for frame: int in 3:
		await tree.physics_frame
	check(fight.is_running(), "у монитора начался бой")
	check(not room.player.controls_enabled, "на облёте камеры герой ждёт")
	await _until(func() -> bool: return fight.phase != CompilerFight.Phase.INTRO)
	equal(fight.phase, CompilerFight.Phase.BOMBS, "сразу прыжки через ошибки и бомбы")
	equal(
		fight.director().zoom, Vector2.ONE * CompilerFight.PLAY_ZOOM, "камера отдалена на кабинет"
	)
	check(room.player.controls_enabled, "герой снова управляем")
	check(room.find_children("*", "FixColumn", true, false).is_empty(), "терминалов в бою нет")
	for bomb: int in CompilerFight.BOMBS:
		for dodge: int in fight.dodges_needed:
			fight.on_dodged()
		check(fight.phase == CompilerFight.Phase.BOMB_SCENE, "бомба %d летит" % (bomb + 1))
		await _until(func() -> bool: return fight.phase != CompilerFight.Phase.BOMB_SCENE)
	equal(fight.bombs_done, CompilerFight.BOMBS, "три бомбы в портах")
	await _until(func() -> bool: return Ui.drawing.visible)
	var drawing := Ui.drawing.logic()
	var size := DrawLogic.grid_size()
	for y: int in size.y:
		for x: int in size.x:
			if DrawLogic.in_shape(Vector2i(x, y)):
				drawing.paint(Vector2i(x, y))
	await _until(func() -> bool: return Ui.dialogue.visible)
	equal(valshtein.current_texture(), valshtein.poses["neutral"], "Вальштейн освобождён")
	finish_talk()
	await _until(func() -> bool: return not fight.is_running())
	Engine.time_scale = 1.0
	check(
		World.is_marked("boss_2") and World.is_marked("ability_2"), "босс побеждён, умение получено"
	)
	equal(Game.task_key, "TASK_GO_FLOOR_3", "задание: на третий этаж")
	equal(World.f["hearts"], 3, "сердца целы")
	await Game.goto_room("corridor_2", "from_202")
	await Game.goto_room("202", "door")
	fight = tree.current_scene.get_node("Fight")
	check(not fight.is_running(), "бой не повторяется")
	var again: Npc = tree.current_scene.get_node("Actors/Valshtein")
	equal(again.talk_id, "valshtein_free", "Вальштейн благодарит")
	equal(again.current_texture(), again.poses["neutral"], "и стоит без заражения")


## Три попадания срывают фазу боя: минус сердце, фаза начинается заново.
func test_compiler_fight_hits() -> void:
	await start_game()
	World.mark("seen_valshtein")
	await Game.goto_room("202", "door")
	var room := tree.current_scene as Room
	var fight: CompilerFight = room.get_node("Fight")
	Engine.time_scale = 4.0
	fight.start()
	await _until(func() -> bool: return fight.phase != CompilerFight.Phase.INTRO)
	for hit: int in fight.integrity_max:
		var line := ErrorLine.new()
		line.setup_slide(room.player.global_position.x, true, 0.0, room.player)
		fight.add_child(line)
		fight.on_touched(line)
		await tree.create_timer(CompilerFight.INVULNERABLE_SEC + 0.05).timeout
	await tree.create_timer(0.6).timeout
	equal(World.f["hearts"], 2, "минус сердце")
	equal(fight.phase, CompilerFight.Phase.BOMBS, "фаза начинается заново")
	equal(fight.integrity, fight.integrity_max, "целостность снова полная")
	Engine.time_scale = 1.0


## Через низкую и высокую ошибку можно перепрыгнуть, если прыгнуть вовремя; стоящего героя
## ошибка задевает.
func test_error_obstacles_are_jumpable() -> void:
	await start_game()
	World.mark("seen_valshtein")
	await Game.goto_room("202", "door")
	var room := tree.current_scene as Room
	room.player.global_position.x = 400.0
	for frame: int in 5:
		await tree.physics_frame
	check(not await _run_obstacle(room, false, 0.0), "стоящего героя ошибка задела")
	check(await _run_obstacle(room, false, 70.0), "через низкую ошибку можно перепрыгнуть")
	check(await _run_obstacle(room, true, 70.0), "через высокую тоже")
	var low := ErrorLine.new()
	low.setup_slide(0.0, true, 0.0, room.player)
	var high := ErrorLine.new()
	high.setup_slide(0.0, true, 0.0, room.player, true)
	check(high.hit_size().y > low.hit_size().y, "одна ошибка ниже, другая выше")
	low.free()
	high.free()


## Пускает ошибку на героя и прыгает, когда она подъехала на заданное расстояние.
## [param room] - комната с героем.
## [param tall] - true для высокой ошибки.
## [param jump_at] - на каком расстоянии прыгнуть; 0 - не прыгать.
## Возвращает true, если ошибка проехала, не задев героя.
func _run_obstacle(room: Room, tall: bool, jump_at: float) -> bool:
	var hero := room.player
	var speed := 215.0 + (CompilerFight.HIGH_BONUS_SPEED if tall else 0.0)
	var line := ErrorLine.new()
	line.setup_slide(hero.global_position.x + 260.0, false, speed, hero, tall)
	var hit := [false]
	line.touched.connect(func(_line: ErrorLine) -> void: hit[0] = true)
	room.add_child(line)
	var jumped := false
	var frames := 0
	while not line.is_counted() and frames < 300:
		await tree.physics_frame
		frames += 1
		if jump_at > 0.0 and not jumped and line.position.x - hero.global_position.x <= jump_at:
			jumped = true
			var press := InputEventAction.new()
			press.action = "jump"
			press.pressed = true
			Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = "jump"
	Input.parse_input_event(release)
	line.queue_free()
	while not hero.is_on_floor():
		await tree.physics_frame
	for frame: int in 10:
		await tree.physics_frame
	return not hit[0]


## Кабинет 316: Логунова и три кота. Рыжий спутник садится у батареи, отладчик попадает
## в батарею, миску и окно, все довольны - победа, комната вылечена, задание на 4 этаж.
func test_cats_fight() -> void:
	await start_game()
	World.mark("boss_2")
	World.mark("ability_debugger")
	await Game.goto_room("316", "door")
	var room := tree.current_scene as Room
	var fight: CatsFight = room.get_node("Fight")
	check(fight.is_running(), "бой начался при входе")
	check(room.cat != null, "рыжий кот вошёл вместе с героем")
	await _until(func() -> bool: return Ui.dialogue.visible)
	check(fight.director().is_current(), "камера боя показывает Логунову")
	finish_talk()
	Engine.time_scale = 4.0
	await _until(func() -> bool: return fight.phase == CatsFight.Phase.PLAY)
	equal(fight.director().zoom, Vector2.ONE * BossFight.PLAY_ZOOM, "камера отдалена на кабинет")
	check(room.player.controls_enabled, "герой управляем")
	var radiator: Radiator = null
	var bowl: CatsBowl = null
	var window: CatsWindow = null
	for child: Node in fight.get_children():
		if child is Radiator:
			radiator = child
		elif child is CatsBowl:
			bowl = child
		elif child is CatsWindow:
			window = child
	room.player.global_position.x = 1000.0
	for frame: int in 3:
		await tree.physics_frame
	var from := room.player.global_position + Vector2(0.0, -100.0)
	var query := PhysicsRayQueryParameters2D.create(
		from, radiator.global_position + Vector2(0.0, -25.0), Player.SHOT_MASK
	)
	var ray := room.get_world_2d().direct_space_state.intersect_ray(query)
	check(not ray.is_empty() and ray["collider"] is DebugTarget, "луч отладчика попадает в батарею")
	for step: int in 3:
		_shoot_target(radiator)
		_shoot_target(bowl)
	check(fight.logic.is_happy(CatsLogic.GINGER), "рыжему тепло")
	check(fight.logic.is_happy(CatsLogic.GRAY), "серый сыт")
	_shoot_target(window)
	check(not window.open, "окно закрыто")
	equal(fight.logic.happy_count(), CatsLogic.CATS, "все трое довольны")
	await _until(func() -> bool: return Ui.dialogue.visible)
	finish_talk()
	await _until(func() -> bool: return not fight.is_running())
	Engine.time_scale = 1.0
	check(World.is_marked("boss_3"), "Логунова свободна")
	equal(Game.task_key, "TASK_GO_FLOOR_4", "задание: на четвёртый этаж")
	equal(World.f["hearts"], 3, "сердца целы")
	await Game.goto_room("corridor_3", "from_316")
	finish_talk()
	await Game.goto_room("316", "door")
	fight = tree.current_scene.get_node("Fight")
	check(not fight.is_running(), "бой не повторяется")


## Время боя с котами вышло: минус сердце и новая попытка.
func test_cats_fight_timeout() -> void:
	await start_game()
	World.mark("boss_2")
	World.mark("seen_logunova")
	await Game.goto_room("316", "door")
	var fight: CatsFight = tree.current_scene.get_node("Fight")
	Engine.time_scale = 4.0
	await _until(func() -> bool: return fight.phase == CatsFight.Phase.PLAY)
	fight.logic.time_left = 0.05
	await _until(func() -> bool: return int(World.f["hearts"]) == 2)
	await _until(func() -> bool: return fight.phase == CatsFight.Phase.PLAY)
	Engine.time_scale = 1.0
	check(fight.logic.time_left > 10.0, "новая попытка с полным временем")


## Попадает лучом отладчика в цель боя.
## [param target] - окно, миска или батарея.
func _shoot_target(target: Node) -> void:
	for child: Node in target.get_children():
		if child is DebugTarget:
			(child as DebugTarget).hit()


## Ждёт, пока условие не станет верным, но не дольше 20 секунд.
## [param condition] - функция без параметров, которая возвращает bool.
func _until(condition: Callable) -> void:
	var limit := Time.get_ticks_msec() + 20000
	while not condition.call() and Time.get_ticks_msec() < limit:
		await tree.process_frame
	check(condition.call(), "дождались условия")
