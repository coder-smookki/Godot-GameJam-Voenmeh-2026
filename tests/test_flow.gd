extends TestCase
## Сквозной тест первых минут: вестибюль, спасение Вани, лифт, второй этаж, концовки.


## Новая игра ставит героя в вестибюль, даёт первое задание и начинает с реплики героя.
func test_new_game_starts_in_vestibule() -> void:
	await Game.new_game()
	check(Ui.dialogue.visible and tree.paused, "герой удивляется пустому вестибюлю")
	check(not World.is_marked("seen_vestibule_arrival"), "недочитанный разговор не засчитан")
	finish_talk()
	check(World.is_marked("seen_vestibule_arrival"), "разговор запомнен")
	equal(Game.room_code, "vestibule", "стартовая комната")
	equal(Game.task_key, Story.START_TASK, "первое задание")
	var room := tree.current_scene as Room
	check(room != null and room.player != null, "герой создан")
	equal(room.get_node("Actors").get_child_count(), 1, "в вестибюле только герой")
	check(tree.current_scene.get_node("Props/Scream").visible, "из гардероба слышен крик")
	check(not tree.paused, "мир не на паузе")
	check(SaveSystem.has_save(), "вход в комнату сохранён")


## Герой стоит на полу вестибюля, прыгает по нажатию клавиши и меняет кадры в прыжке.
func test_hero_jumps() -> void:
	await start_game()
	var player := (tree.current_scene as Room).player
	for frame: int in 3:
		await tree.physics_frame
	check(player.is_on_floor(), "герой стоит на полу")
	var press := InputEventAction.new()
	press.action = "jump"
	press.pressed = true
	Input.parse_input_event(press)
	for frame: int in 3:
		await tree.physics_frame
	check(not player.is_on_floor(), "герой в прыжке")
	equal(_puffs(player.get_parent()), 1, "от толчка поднялась пыль")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	check(sprite.scale.y > 1.0, "в толчке герой вытянулся")
	equal(sprite.animation, &"jump", "в воздухе кадр прыжка")
	var frames := 0
	while not player.is_on_floor() and frames < 240:
		await tree.physics_frame
		frames += 1
	await tree.physics_frame
	equal(sprite.animation, &"land", "после приземления кадр приседа")
	check(_puffs(player.get_parent()) >= 1, "от приземления поднялась пыль")
	check(sprite.scale.y < 1.0, "при посадке герой сплющился")
	for frame: int in 30:
		await tree.physics_frame
	equal(sprite.animation, &"idle", "потом обычная стойка")
	equal(sprite.scale, Vector2.ONE, "пропорции вернулись")
	var release := InputEventAction.new()
	release.action = "jump"
	Input.parse_input_event(release)


## Выход работает один раз и только пока герой не уехал на лифте.
func test_exit_door() -> void:
	await start_game()
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
	await start_game()
	await Game.goto_room("wardrobe", "door")
	var room := tree.current_scene as Room
	var vanya: StuckVanya = room.get_node("Actors/Vanya")
	check(not Elevator.is_working(), "до спасения лифт не едет")
	check(vanya.get_node("Art/Mass").visible, "ком шахматки на месте")
	vanya.interact(room.player)
	check(Ui.pull.visible and tree.paused, "мини-игра открыта и мир стоит")
	check(not room.player.visible, "героя рисует кадр мини-игры")
	equal(vanya.get_node("Art/Pull").texture, StuckVanya.FRAMES[0], "спасение с первого кадра")
	check(not Ui.hud.visible, "задание спрятано на время мини-игры")
	var presses := 0
	while Ui.pull.visible and presses < 100:
		Ui.pull.press()
		presses += 1
	equal(presses, 18, "три рывка по шесть нажатий нужной клавиши")
	equal(vanya.get_node("Art/Pull").texture, StuckVanya.FRAMES[0], "без промахов кадр не менялся")
	equal(World.f["hearts"], 3, "сердца целы")
	check(Ui.hud.visible, "задание вернулось")
	check(World.is_marked("vanya_saved"), "Ваня спасён")
	equal(Game.task_key, "TASK_GO_FLOOR_2", "новое задание")
	check(room.player.visible, "герой снова на ногах")
	check(not vanya.get_node("Art/Mass").visible, "ком шахматки отступил")
	check(vanya.get_node("Art/Remnant").visible, "остался маленький остаток")
	equal(vanya.position.x, StuckVanya.FREE_X, "Ваня стоит свободно")
	check(not Ui.dialogue.visible, "сначала шахматка сжимается")
	var body: Sprite2D = vanya.get_node("Body")
	check(body.visible and body.texture != null, "Ваня нарисован")
	check(body.position.x > 0.0, "Ваня вылетает из шахматки")
	await tree.create_timer(StuckVanya.SHRINK_SEC + 0.2).timeout
	equal(body.position, Vector2.ZERO, "Ваня приземлился на своё место")
	check(body.flip_h, "Ваня повернулся к герою")
	check(Ui.dialogue.visible, "Ваня говорит спасибо")
	finish_talk()
	check(not Ui.dialogue.visible and not tree.paused, "разговор закончен, мир идёт")
	check(Elevator.is_working(), "лифт поедет на второй этаж")
	await Game.goto_room("vestibule", "door")
	check(not tree.current_scene.get_node("Props/Scream").visible, "крика больше нет")


## Три промаха в мини-игре: кадры идут 1-2-3-4, шахматка отбрасывает героя, он теряет сердце,
## Ваня не спасён, можно пробовать снова.
func test_vanya_rescue_lost() -> void:
	await start_game()
	await Game.goto_room("wardrobe", "door")
	var room := tree.current_scene as Room
	var vanya: StuckVanya = room.get_node("Actors/Vanya")
	var pull: Sprite2D = vanya.get_node("Art/Pull")
	vanya.interact(room.player)
	var presses := 0
	while Ui.pull.visible and presses < 100:
		Ui.pull.press_key((Ui.pull.current_key() + 1) % PullLogic.KEY_COUNT)
		presses += 1
		if presses == 8:
			equal(pull.texture, StuckVanya.FRAMES[1], "после первого промаха второй кадр")
		if presses == 16:
			equal(pull.texture, StuckVanya.FRAMES[2], "после второго промаха третий кадр")
	equal(presses, 24, "по восемь чужих клавиш на промах")
	check(not tree.paused, "мини-игра закрыта")
	equal(pull.texture, StuckVanya.FRAMES[3], "шахматка поглотила героя")
	equal(World.f["hearts"], 3, "сердце ещё не отнято")
	await tree.create_timer(StuckVanya.SWALLOW_SEC + 0.1).timeout
	check(room.player.visible and room.player.is_stunned(), "героя отбросило")
	equal(World.f["hearts"], 2, "минус сердце")
	var hearts: Hearts = Ui.hud.get_node("FloorPanel/Box/Hearts")
	equal(hearts.shown(), 2, "на плашке два сердца")
	await tree.create_timer(1.0).timeout
	check(
		room.player.global_position.x < StuckVanya.HERO_THROWN_FROM - 80.0, "герой отлетел от кома"
	)
	check(not World.is_marked("vanya_saved"), "Ваня не спасён")
	check(vanya.get_node("Art/Mass").visible, "ком шахматки на месте")
	vanya.interact(room.player)
	check(Ui.pull.visible, "можно попробовать ещё раз")
	while Ui.pull.visible:
		Ui.pull.press()
	check(World.is_marked("vanya_saved"), "со второй попытки Ваня спасён")


## Лифт везёт только на открытые этажи и закрывает выход домой.
func test_elevator_ride() -> void:
	await start_game()
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
	check(Ui.dialogue.visible, "герой осматривается на этаже")
	check(not Infection.is_active(2), "до конца разговора этаж не заражается")
	finish_talk()
	equal(Game.task_key, "TASK_FIND_HELP", "после разговора нужно найти, кто объяснит")
	check(Infection.is_active(2), "второй этаж заражается")
	equal(Game.spawn_id, Elevator.SPAWN, "герой вышел из лифта")
	equal(Infection.current_floor, 2, "этаж сменился")
	check(World.is_marked(Elevator.USED_MARK), "поездка запомнена")
	check(not tree.paused, "панель закрыта")


## Шуточная концовка возвращает в комнату, основная ведёт в главное меню.
func test_endings_route() -> void:
	await start_game()
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
	await start_game()
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
	await start_game()
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


## Ответ с меткой «болтовня» возвращает к выбору, ответ «сюжет» ведёт разговор дальше.
func test_dialogue_choices() -> void:
	await start_game()
	var finished: Array[bool] = []
	var listener := func() -> void:
		finished.append(await Ui.dialogue.play(DialogueCatalog.talk("vanya_rescue")))
	listener.call()
	check(Ui.dialogue.visible and tree.paused, "разговор открыт")
	var choices: VBoxContainer = Ui.dialogue.get_node("Pick/Choices")
	Ui.dialogue.choose(0)
	equal(choices.get_child_count(), 0, "пока текст печатается, ответов нет")
	Ui.dialogue.advance()
	equal(choices.get_child_count(), 2, "предложены два ответа")
	check(Ui.dialogue.get_node("Pick").visible, "ответы показаны плашками посреди экрана")
	Ui.dialogue.choose(5)
	equal(choices.get_child_count(), 2, "ответа с таким номером нет")
	Ui.dialogue.choose(1)
	Ui.dialogue.advance()
	Ui.dialogue.advance()
	equal(choices.get_child_count(), 1, "после болтовни остался сюжетный ответ")
	Ui.dialogue.choose(1)
	equal(choices.get_child_count(), 1, "второй раз о том же не спросить")
	Ui.dialogue.choose(0)
	finish_talk()
	check(not Ui.dialogue.get_node("Pick").visible, "плашки ответов убраны")
	check(not Ui.dialogue.visible and not tree.paused, "разговор закончен")
	equal(finished, [true] as Array[bool], "разговор дошёл до конца")


## Закрытый раньше времени разговор не считается оконченным и не мешает следующему.
func test_dialogue_interrupted() -> void:
	await start_game()
	var finished: Array[bool] = []
	var listener := func() -> void:
		finished.append(await Ui.dialogue.play(DialogueCatalog.talk("vanya_after")))
	listener.call()
	Ui.close_all_modals()
	listener.call()
	finish_talk()
	equal(
		finished,
		[false, true] as Array[bool],
		"прерванный разговор вернул false, новый дошёл до конца"
	)


## Доска объявлений читается сколько угодно раз, а капибара на листке находится один раз.
func test_notice_board() -> void:
	await start_game()
	var room := tree.current_scene as Room
	var board: Npc = room.get_node("Props/Board")
	board.interact(room.player)
	check(Ui.dialogue.visible, "герой читает объявление")
	equal(World.f["capy"], 0, "до конца чтения капибара не засчитана")
	finish_talk()
	equal(World.f["capy"], 1, "капибара найдена")
	check(World.is_marked("capy_board"), "находка запомнена")
	board.interact(room.player)
	finish_talk()
	equal(World.f["capy"], 1, "второй раз та же капибара не считается")


## Считает облачка пыли, которые сейчас висят в комнате.
## [param actors] - узел с персонажами комнаты.
## Возвращает число узлов [Puff].
func _puffs(actors: Node) -> int:
	var count := 0
	for child: Node in actors.get_children():
		if child is Puff:
			count += 1
	return count
