extends TestCase
## Капибары: спрятанные находки, ожившая капибара из 202 и секретная концовка на крыше.


## Все пять капибар: исправление ЛАБЫ открывает секретный финал - ЛАБА становится
## капибарой, город очищается, концовка №5.
func test_roof_capybara_ending() -> void:
	await start_game()
	World.mark("boss_5")
	World.bump("messages", 2)
	World.set_value("capy", World.CAPY_TOTAL)
	await Game.goto_room("roof", "start")
	var room := tree.current_scene as Room
	var fight: RoofFight = room.get_node("Fight")
	finish_talk()
	equal(World.ending("fix"), "capybara", "терминал ведёт к секретной концовке")
	Engine.time_scale = 4.0
	fight.phase = RoofFight.Phase.CHOICE
	fight._on_terminal_chosen("fix")
	await _until(func() -> bool: return Ui.dialogue.visible)
	check(fight.laba().form > 0.99, "ЛАБА превратилась в капибару")
	check(
		(
			(
				room
				. get_node("Actors")
				. get_children()
				. filter(func(node: Node) -> bool: return node is CapyPixel)
				. size()
			)
			== World.CAPY_TOTAL
		),
		"на крышу выбежали пять капибар"
	)
	finish_talk()
	await _until(func() -> bool: return Game.last_ending == "capybara")
	Engine.time_scale = 1.0
	await _until(func() -> bool: return not Game.is_busy())
	await Game.to_main_menu()


## Спрятанные капибары висят выше головы героя: достать можно только прыжком; найденная
## засчитывается один раз и больше не появляется.
func test_hidden_capybaras() -> void:
	await start_game()
	for room_code: String in ["316", "corridor_4", "corridor_5"]:
		World.mark("boss_2")
		await Game.goto_room(room_code)
		finish_talk()
		var room := tree.current_scene as Room
		var pickup: CapyPickup = room.get_node("Props/Capy")
		var head := room.player.global_position.y - 150.0
		check(pickup.global_position.y + CapyPickup.RADIUS < head, "%s: выше головы" % room_code)
		check(
			pickup.global_position.y - CapyPickup.RADIUS > head - 61.0,
			"%s: прыжком достать можно" % room_code
		)
		var before: int = World.f["capy"]
		pickup.collect()
		pickup.collect()
		equal(World.f["capy"], before + 1, "%s: капибара засчитана один раз" % room_code)
	await Game.goto_room("316")
	finish_talk()
	await tree.process_frame
	check(
		not is_instance_valid(tree.current_scene.get_node_or_null("Props/Capy")),
		"найденная не появляется"
	)


## Ждёт условия до 20 секунд.
## [param condition] - условие.
func _until(condition: Callable) -> void:
	var limit := Time.get_ticks_msec() + 20000
	while not condition.call() and Time.get_ticks_msec() < limit:
		await tree.process_frame
	check(condition.call(), "дождались условия")
