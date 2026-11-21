extends TestCase
## Сквозной тест первых минут: вестибюль, спасение Вани, лифт, второй этаж, концовки.


## Новая игра ставит героя в вестибюль и даёт первое задание.
func test_new_game_starts_in_vestibule() -> void:
	await Game.new_game()
	equal(Game.room_code, "vestibule", "стартовая комната")
	equal(Game.task_key, Story.START_TASK, "первое задание")
	var room := tree.current_scene as Room
	check(room != null and room.player != null, "герой создан")
	equal(room.get_node("Actors").get_child_count(), 1, "Капи ещё не с героем")
	check(tree.current_scene.get_node("Props/Scream").visible, "из гардероба слышен крик")
	check(not tree.paused, "мир не на паузе")
	check(SaveSystem.has_save(), "вход в комнату сохранён")


## Выход работает один раз и только пока герой не уехал на лифте.
func test_exit_door() -> void:
	await Game.new_game()
	var door: ExitDoor = tree.current_scene.get_node("Props/Exit")
	check(door.is_open(), "в начале можно уйти домой")
	equal(door.plate_text(), "", "табличка не нужна, пока дверь работает")
	World.mark(Elevator.USED_MARK)
	check(not door.is_open(), "после лифта выхода нет")
	equal(door.plate_text(), str(TranslationServer.translate("DOOR_404")), "табличка 404")
	World.reset()
	check(door.is_open(), "в новой игре дверь снова работает")
	World.set_value("escape_tried", true)
	check(not door.is_open(), "второй раз уйти нельзя")


## Мини-игра вытаскивает Ваню: появляется отметка, новое задание и разговор, лифт начинает ездить.
func test_vanya_rescue() -> void:
	await Game.new_game()
	await Game.goto_room("wardrobe", "door")
	var room := tree.current_scene as Room
	var vanya: StuckVanya = room.get_node("Actors/Vanya")
	check(not Elevator.is_working(), "до спасения лифт не едет")
	vanya.interact(room.player)
	check(Ui.pull.visible and tree.paused, "мини-игра открыта и мир стоит")
	var presses := 0
	while Ui.pull.visible and presses < 100:
		Ui.pull.press()
		presses += 1
	equal(presses, 27, "три рывка по девять нажатий")
	check(World.is_marked("vanya_saved"), "Ваня спасён")
	equal(Game.task_key, "TASK_GO_FLOOR_2", "новое задание")
	check(Ui.dialogue.visible, "Ваня говорит спасибо")
	for step: int in StuckVanya.RESCUE_LINES.size() * 2:
		Ui.dialogue.advance()
	check(not Ui.dialogue.visible and not tree.paused, "разговор закончен, мир идёт")
	check(Elevator.is_working(), "лифт поедет на второй этаж")
	await Game.goto_room("vestibule", "door")
	check(not tree.current_scene.get_node("Props/Scream").visible, "крика больше нет")


## Лифт везёт только на открытые этажи и закрывает выход домой.
func test_elevator_ride() -> void:
	await Game.new_game()
	Ui.elevator.open()
	Ui.elevator.ride(2)
	check(Ui.elevator.visible, "на закрытый этаж лифт не едет")
	Ui.elevator.close()
	World.mark("vanya_saved")
	Ui.elevator.open()
	check(tree.paused, "панель лифта ставит мир на паузу")
	Ui.elevator.ride(1)
	equal(Game.room_code, "vestibule", "на свой этаж лифт не едет")
	Ui.elevator.ride(2)
	await Game.room_entered
	equal(Game.room_code, "corridor_2", "герой на втором этаже")
	equal(Game.spawn_id, Elevator.SPAWN, "герой вышел из лифта")
	equal(Infection.current_floor, 2, "этаж сменился")
	check(World.is_marked(Elevator.USED_MARK), "поездка запомнена")
	check(not tree.paused, "панель закрыта")


## Пять попаданий разбивают тотем: этаж лечится, кабинет 214 открывается, состояние сохраняется.
func test_totem_break() -> void:
	await Game.new_game()
	World.mark("laba_seen")
	World.mark("ability_debugger")
	await Game.goto_room("corridor_2", Elevator.SPAWN)
	var totem: Totem = tree.current_scene.get_node("Actors/Totem")
	var door: Door = tree.current_scene.get_node("Props/Room214")
	check(not door.is_open(), "кабинет 214 заражён")
	check(Infection.is_active(2), "второй этаж заражается после катсцены ЛАБЫ")
	var before := Infection.percent(2)
	for shot: int in 4:
		totem.hit()
	equal(totem.letters_left(), 1, "осталась одна буква")
	check(not World.is_marked("totem_corridor_2"), "тотем ещё стоит")
	totem.hit()
	check(World.is_marked("totem_corridor_2") and World.is_marked("first_totem"), "тотем разбит")
	equal(Infection.percent(2), before - 8, "заражение этажа упало на 8%")
	check(door.is_open(), "кабинет 214 открылся")
	equal(Game.task_key, "TASK_TALK_VALSHTEIN", "новое задание")
	await Game.goto_room("kafedra", "door")
	await Game.goto_room("corridor_2", "from_kafedra")
	check(tree.current_scene.get_node_or_null("Actors/Totem") == null, "разбитый тотем не вернулся")


## Капи появляется в момент, когда присоединяется, и остаётся у рубильника, если так решено.
func test_capi_joins() -> void:
	await Game.new_game()
	await Game.goto_room("kafedra", "door")
	var actors := tree.current_scene.get_node("Actors")
	var before := actors.get_child_count()
	World.mark("laba_seen")
	equal(Game.task_key, "TASK_GET_DEBUGGER", "после катсцены нужно взять отладчик")
	World.mark("capi_joined")
	equal(actors.get_child_count(), before + 1, "Капи вылезла из монитора")
	World.set_value("mozh", "capy")
	await Game.goto_room("corridor_2", "from_kafedra")
	var corridor := tree.current_scene.get_node("Actors")
	for actor: Node in corridor.get_children():
		check(not actor is Capi, "Капи осталась у рубильника")


## Шуточная концовка возвращает в комнату, основная ведёт в главное меню.
func test_endings_route() -> void:
	await Game.new_game()
	await Game.show_ending("expelled")
	check(SaveSystem.is_ending_unlocked("expelled"), "концовка открыта в профиле")
	check(not Game.in_room, "экран концовки вне комнаты")
	await Game.finish_ending()
	equal(Game.room_code, "vestibule", "после шутки герой снова в вестибюле")
	check(Game.in_room, "игра продолжается")
	await Game.show_ending("rm_rf")
	await Game.finish_ending()
	check(not Game.in_room, "после основной концовки открыто меню")
	equal(Game.pending_ending, "", "ожидающей концовки нет")


## «Загрузить» возвращает в сохранённую комнату с прежним состоянием.
func test_continue_restores_room() -> void:
	await Game.new_game()
	World.mark("vanya_saved")
	await Game.goto_room("corridor_2", Elevator.SPAWN)
	World.reset()
	await Game.to_main_menu()
	check(await Game.continue_game(), "сохранение загружено")
	equal(Game.room_code, "corridor_2", "комната восстановлена")
	check(World.is_marked("vanya_saved"), "отметки восстановлены")
	equal(Game.task_key, "TASK_GO_FLOOR_2", "задание восстановлено")


## Экраны поверх игры ставят мир на паузу и снимают её при закрытии.
func test_modals_pause_world() -> void:
	await Game.new_game()
	Ui.phone.open()
	check(tree.paused and Ui.is_modal_open(), "телефон ставит паузу")
	Ui.phone.close()
	check(not tree.paused, "пауза снята")
	Ui.pause_menu.open()
	Ui.settings.open()
	Ui.settings.close()
	check(tree.paused and Ui.pause_menu.visible, "после настроек пауза осталась")
	Ui.dev_menu.open()
	Ui.close_all_modals()
	check(not tree.paused and not Ui.is_modal_open(), "все экраны закрыты")


## Настройки открываются из главного меню, а закрытый вопрос считается ответом «нет».
func test_menu_screens() -> void:
	await Game.to_main_menu()
	Ui.settings.open()
	check(Ui.settings.visible and tree.paused, "настройки открыты в главном меню")
	Ui.settings.close()
	check(not tree.paused, "меню снова отвечает")
	var answers: Array[bool] = []
	var listener := func(accepted: bool) -> void: answers.append(accepted)
	Ui.confirm.answered.connect(listener)
	Ui.confirm.ask("MENU_CONFIRM_NEW_GAME")
	check(Ui.confirm.visible, "вопрос показан")
	Ui.close_all_modals()
	Ui.confirm.answered.disconnect(listener)
	equal(answers, [false] as Array[bool], "закрытие без выбора означает «нет»")
