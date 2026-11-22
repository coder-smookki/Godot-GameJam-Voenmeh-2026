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


## После победы над боссом в кабине стоит Лестенко: разговор, подарок над головой героя,
## на панели загорается третья кнопка.
func test_lift_lestenko() -> void:
	await start_game()
	World.mark("vanya_saved")
	World.mark("seen_elevator_first")
	World.mark("boss_2")
	await Game.goto_room("corridor_2", Elevator.SPAWN)
	finish_talk()
	await Game.enter_lift()
	var cabin := tree.current_scene as Room
	check(cabin.get_node_or_null("Actors/Lestenko") != null, "Лестенко в кабине")
	equal(cabin.get_node("Backdrop/Art").texture, LiftArt.ART[1], "горят три кнопки")
	check(Ui.dialogue.visible, "Лестенко заговорил")
	finish_talk()
	check(World.is_marked("seen_lift_lestenko"), "разговор запомнен")
	check(_announced(cabin.player, "ANNOUNCE_RAM"), "над головой плашка с подарком")
	await Game.leave_lift()
	equal(Game.room_code, "corridor_2", "кабина вернула героя на второй этаж")
	await Game.enter_lift()
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
	var kafedra: Door = room.get_node("Props/Kafedra")
	check(not kafedra.is_open(), "дверь кафедры заблокирована")
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


## Кот на третьем этаже замечает героя, убегает к кабинету 316 и больше не появляется.
func test_cat_runs_away() -> void:
	await start_game()
	await Game.goto_room("corridor_3", Elevator.SPAWN)
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
	await cat.ran_away
	check(World.is_marked("cat_316"), "побег запомнен")
	equal(cat.global_position.y, cat.floor_y, "кот спрыгнул на пол")
	await Game.goto_room("vestibule", "elevator")
	await Game.goto_room("corridor_3", Elevator.SPAWN)
	check(tree.current_scene.get_node_or_null("Actors/Cat") == null, "убежавший кот не вернулся")


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


## Рамка выбранной кнопки лифта охватывает номер и нарисованный круг этой кнопки.
func test_lift_panel_frames() -> void:
	await start_game()
	World.mark("vanya_saved")
	Ui.elevator.open()
	var keys: Control = Ui.elevator.get_node("Art/Keys")
	equal(keys.get_child_count(), 5, "пять кнопок")
	for index: int in keys.get_child_count():
		var button: Button = keys.get_child(index)
		var rect := Rect2(button.position, button.size)
		var circle := Vector2(91.5, ElevatorPanel.CIRCLE_Y[index])
		check(rect.grow(-14.0).has_point(circle), "кнопка %d: круг внутри рамки" % (index + 1))
		var right_gap := rect.end.x - 106.0
		check(right_gap >= 3.0 and right_gap <= 8.0, "кнопка %d: рамка не режет круг" % (index + 1))
	Ui.elevator.close()


## Проверяет, висит ли над героем плашка с этим текстом.
## [param player] - герой.
## [param text_key] - ключ текста плашки.
func _announced(player: Player, text_key: String) -> bool:
	for child: Node in player.get_children():
		if child is Label and child.text == tr(text_key):
			return true
	return false
