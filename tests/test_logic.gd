extends TestCase
## Тесты правил эпилога, плана финального боя и условий дверей.


## Слайды эпилога выбирают вариант по решениям игрока.
func test_epilogue_variants() -> void:
	World.set_value("compiler", "fixed")
	World.set_value("logunova", "kind")
	World.set_value("cats", 4)
	World.set_value("mozh", "clone")
	World.set_value("naurusova", "student")
	World.set_value("notes", 6)
	World.set_value("students", 6)
	var slides := Epilogue.slides("retake")
	equal(slides.size(), 8, "восемь слайдов у «Пересдачи»")
	for slide: Dictionary in slides:
		equal(slide["variant"], "A", "вариант А у %s" % slide["who"])
	World.reset()
	World.set_value("rage", 3)
	slides = Epilogue.slides("rm_rf")
	for slide: Dictionary in slides:
		equal(slide["variant"], "B", "вариант Б у %s" % slide["who"])


## У «Петли» нет слайда ЛАБЫ, у шуточных концовок нет эпилога.
func test_epilogue_shape() -> void:
	equal(Epilogue.slides("loop").size(), 7, "семь слайдов у «Петли»")
	equal(Epilogue.slides("expelled").size(), 0, "шуточная концовка без эпилога")
	equal(Epilogue.slides("not_found").size(), 0, "плохая концовка без эпилога")
	World.set_value("logunova", "kind")
	World.set_value("cats", 3)
	equal(Epilogue.slides("retake")[1]["variant"], "B", "переубедили, но котов мало")


## План финала собирает помощников из решений.
func test_final_plan_helpers() -> void:
	equal(FinalPlan.helpers().size(), 0, "без решений помощников нет")
	World.set_value("compiler", "fixed")
	World.set_value("logunova", "kind")
	World.set_value("cats", 5)
	World.set_value("zeml", "calm")
	World.set_value("mozh", "clone")
	var plan := FinalPlan.build()
	equal(
		plan["helpers"],
		["compiler_turret", "cat_shield", "shield", "terminal_repair"] as Array[String],
		"помощники «отличника»"
	)
	equal(plan["cats"], 5, "коты-защитники")
	equal(plan["phase_one_scale"], 0.5, "первая фаза вдвое короче")
	equal(plan["confidence"], 100, "полная уверенность ЛАБЫ")


## Жёсткие решения дают атакующих помощников и короткий таймер.
func test_final_plan_harsh() -> void:
	World.set_value("compiler", "deleted")
	World.set_value("logunova", "strict")
	World.set_value("cats", 5)
	World.set_value("zeml", "storm")
	World.set_value("rage", 3)
	World.set_value("mozh", "off")
	World.set_value("messages", 3)
	var plan := FinalPlan.build()
	equal(
		plan["helpers"],
		["manual_bombs", "stamps", "storm", "confidence_cut"] as Array[String],
		"помощники «спидраннера»"
	)
	equal(plan["cats"], 0, "после разбитого кристалла коты не защищают")
	equal(plan["confidence"], 50, "уверенность срезана")
	equal(plan["timer_sec"], 300.0, "пять минут")
	check(plan["fix_hint"], "подсказка к «ИСПРАВИТЬ» при 3 посланиях")
	World.set_value("mozh", "stay")
	equal(FinalPlan.build()["late_timer_speed"], 2.0, "таймер вдвое быстрее с третьей фазы")


## Условия читают переменные и функции мира, а ошибка в условии держит дверь закрытой.
func test_conditions() -> void:
	check(Condition.new("").is_met(), "пустое условие")
	var stairs := Condition.new("logunova != '' and zeml != ''")
	check(not stairs.is_met(), "этажи не вылечены")
	World.set_value("logunova", "kind")
	World.set_value("zeml", "storm")
	check(stairs.is_met(), "оба этажа вылечены")
	var marked := Condition.new("is_marked('key') and method() <= 0")
	check(not marked.is_met(), "отметки нет")
	World.mark("key")
	check(marked.is_met(), "отметка и функция мира")
	check(not Condition.new("cats >= 3").is_met(), "счётчик ниже порога")
	World.set_value("cats", 3)
	check(Condition.new("cats >= 3").is_met(), "счётчик на пороге")
