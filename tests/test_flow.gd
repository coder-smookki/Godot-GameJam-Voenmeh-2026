extends TestCase
## Сквозной тест пролога: новая игра, двери, запуск ЛАБЫ, тотем, концовка и продолжение.


## Новая игра ставит героя в вестибюль и даёт первое задание.
func test_new_game_starts_in_vestibule() -> void:
	await Game.new_game()
	equal(Game.room_code, "1-01", "стартовая комната")
	equal(Game.task_key, Story.START_TASK, "первое задание")
	var room := tree.current_scene as Room
	check(room != null and room.player != null, "герой создан")
	check(not tree.paused, "мир не на паузе")
	check(SaveSystem.has_save(), "вход в комнату сохранён")


## Дверь в коридор закрыта, пока не взят отладчик.
func test_door_opens_with_debugger() -> void:
	await Game.new_game()
	var door: Door = tree.current_scene.get_node("Props/Corridor")
	check(not door.is_open(), "без отладчика закрыто")
	World.mark("ability_debugger")
	check(door.is_open(), "с отладчиком открыто")
	equal(Game.task_key, "TASK_BREAK_TOTEM", "задание сменилось")


## Выход открыт только 60 секунд после запуска ЛАБЫ, и запуск заражает первый этаж.
func test_exit_window() -> void:
	await Game.new_game()
	var door: ExitDoor = tree.current_scene.get_node("Props/Exit")
	check(not door.is_open(), "до запуска уйти нельзя")
	World.mark("laba_launched")
	check(door.is_open(), "после запуска окно открыто")
	check(Infection.is_active(1), "первый этаж заражается")
	World.clock += 61.0
	check(not door.is_open(), "через минуту дверь заражена")
	door.refresh()
	equal(door.plate_text(), str(TranslationServer.translate("DOOR_404")), "табличка 404")


## Пять попаданий разбивают тотем: этаж лечится, лестница открывается, состояние сохраняется.
func test_totem_break() -> void:
	await Game.new_game()
	World.mark("laba_launched")
	World.mark("ability_debugger")
	await Game.goto_room("1-05", "from_1_01")
	equal(Game.room_code, "1-05", "коридор первого этажа")
	var totem: Totem = tree.current_scene.get_node("Actors/Totem")
	var stairs: Door = tree.current_scene.get_node("Props/Stairs")
	check(not stairs.is_open(), "лестница на карантине")
	var before := Infection.percent(1)
	for shot: int in 4:
		totem.hit()
	equal(totem.letters_left(), 1, "осталась одна буква")
	check(not World.is_marked("totem_1_05"), "тотем ещё стоит")
	totem.hit()
	check(World.is_marked("totem_1_05") and World.is_marked("first_totem"), "тотем разбит")
	equal(Infection.percent(1), before - 8, "заражение этажа упало на 8%")
	check(stairs.is_open(), "лестница открылась")
	equal(Game.task_key, "TASK_FIND_STAIRS", "новое задание")
	await Game.goto_room("1-01", "from_1_05")
	await Game.goto_room("1-05", "from_1_01")
	check(tree.current_scene.get_node_or_null("Actors/Totem") == null, "разбитый тотем не вернулся")


## Шуточная концовка возвращает в комнату, основная ведёт в главное меню.
func test_endings_route() -> void:
	await Game.new_game()
	await Game.show_ending("expelled")
	check(SaveSystem.is_ending_unlocked("expelled"), "концовка открыта в профиле")
	check(not Game.in_room, "экран концовки вне комнаты")
	await Game.finish_ending()
	equal(Game.room_code, "1-01", "после шутки герой снова в вестибюле")
	check(Game.in_room, "игра продолжается")
	await Game.show_ending("rm_rf")
	await Game.finish_ending()
	check(not Game.in_room, "после основной концовки открыто меню")
	equal(Game.pending_ending, "", "ожидающей концовки нет")


## «Продолжить» возвращает в сохранённую комнату с прежним состоянием.
func test_continue_restores_room() -> void:
	await Game.new_game()
	World.mark("ability_debugger")
	await Game.goto_room("1-05", "from_1_01")
	World.reset()
	await Game.to_main_menu()
	check(await Game.continue_game(), "сохранение загружено")
	equal(Game.room_code, "1-05", "комната восстановлена")
	check(World.is_marked("ability_debugger"), "отметки восстановлены")
	equal(Game.task_key, "TASK_BREAK_TOTEM", "задание восстановлено")


## Экраны поверх игры ставят мир на паузу и снимают её при закрытии.
func test_modals_pause_world() -> void:
	await Game.new_game()
	Ui.phone.open()
	check(tree.paused and Ui.is_modal_open(), "телефон ставит паузу")
	Ui.phone.close()
	check(not tree.paused, "пауза снята")
	Ui.dev_menu.open()
	Ui.pause_menu.open()
	Ui.close_all_modals()
	check(not tree.paused and not Ui.is_modal_open(), "все экраны закрыты")
