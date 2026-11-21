extends TestCase
## Тесты правил: план финала, условия, лифт и мини-игра «Тяни!».


## План финала зависит от решения у рубильника и от числа посланий.
func test_final_plan() -> void:
	var plan := FinalPlan.build()
	equal(plan["timer_sec"], 300.0, "обычный таймер")
	check(plan["capi_present"], "Капи идёт с героем")
	check(not plan["mozhaitsev_present"], "Можайцев ещё не решён")
	check(not plan["fix_available"], "«ИСПРАВИТЬ» закрыт без посланий")
	World.set_value("mozh", "capy")
	World.set_value("messages", 2)
	plan = FinalPlan.build()
	check(not plan["capi_present"], "Капи осталась у рубильника")
	check(plan["mozhaitsev_present"], "Можайцев пришёл на крышу")
	check(plan["fix_available"], "«ИСПРАВИТЬ» открыт")
	World.set_value("mozh", "stay")
	plan = FinalPlan.build()
	check(plan["capi_present"] and not plan["mozhaitsev_present"], "Можайцев остался держать")
	World.set_value("mozh", "off")
	plan = FinalPlan.build()
	equal(plan["timer_sec"], 180.0, "три минуты без карантина")
	check(plan["mozhaitsev_present"], "вылеченный Можайцев на крыше")


## Условия читают переменные и функции мира, а ошибка в условии держит дверь закрытой.
func test_conditions() -> void:
	check(Condition.new("").is_met(), "пустое условие")
	var roof := Condition.new("mozh != '' and is_marked('boss_5')")
	check(not roof.is_met(), "рубильник не решён")
	World.set_value("mozh", "stay")
	check(not roof.is_met(), "босс пятого этажа не побеждён")
	World.mark("boss_5")
	check(roof.is_met(), "решение и отметка")
	check(not Condition.new("messages >= 2").is_met(), "счётчик ниже порога")
	World.set_value("messages", 2)
	check(Condition.new("messages >= 2").is_met(), "счётчик на пороге")
	check(Condition.new("ending('fix') == 'retake'").is_met(), "функция мира в условии")
	check(not Condition.new("no_such_variable > 1").is_met(), "ошибка в условии")


## Лифт открывает этажи по порядку: после Вани второй, дальше после каждого босса.
func test_elevator_opens_floors_in_order() -> void:
	check(not Elevator.is_working(), "в начале лифт не едет")
	equal(Elevator.state(1, 1), Elevator.STATE_HERE, "герой на первом этаже")
	for level: int in [2, 3, 4, 5]:
		equal(Elevator.state(level, 1), Elevator.STATE_LOCKED, "%d этаж закрыт" % level)
	World.mark("vanya_saved")
	check(Elevator.is_working(), "после спасения Вани лифт едет")
	equal(Elevator.goal_floor(), 2, "сюжет ведёт на второй этаж")
	equal(Elevator.state(2, 1), Elevator.STATE_GOAL, "второй этаж подсвечен")
	equal(Elevator.state(3, 1), Elevator.STATE_LOCKED, "третий ещё закрыт")
	World.mark("boss_2")
	equal(Elevator.state(3, 2), Elevator.STATE_GOAL, "после Компилятора цель на третьем")
	equal(Elevator.state(1, 2), Elevator.STATE_OPEN, "на первый можно вернуться")
	equal(Elevator.state(2, 2), Elevator.STATE_HERE, "герой на втором")
	World.mark("boss_3")
	World.mark("boss_4")
	equal(Elevator.goal_floor(), 5, "все этажи открыты")
	equal(Elevator.room(5), "corridor_5", "комната пятого этажа")
	equal(Elevator.room(9), "", "этажа нет")
	check(not Elevator.is_open(9), "чужой этаж закрыт")


## Босса нельзя пропустить: отметка верхнего этажа не открывает его без нижних.
func test_elevator_needs_every_boss() -> void:
	World.mark("vanya_saved")
	World.mark("boss_3")
	check(Elevator.is_open(2), "второй этаж открыт")
	check(not Elevator.is_open(3), "третий этаж закрыт без победы на втором")
	check(not Elevator.is_open(4), "четвёртый этаж закрыт, пока закрыт третий")
	equal(Elevator.goal_floor(), 2, "цель осталась на втором этаже")


## Мини-игра «Тяни!»: три рывка, шкала утекает всё быстрее и не наказывает за ноль.
func test_pull_logic() -> void:
	var pull := PullLogic.new()
	equal(pull.jerk, 0, "первый рывок")
	check(not pull.press(), "одного нажатия мало")
	check(pull.level > 0.0, "шкала выросла")
	pull.advance(60.0, false)
	equal(pull.level, 0.0, "шкала утекла до нуля")
	equal(pull.jerk, 0, "за ноль рывок не отнимают")
	var presses := 0
	while pull.jerk == 0:
		pull.press()
		presses += 1
	equal(presses, 9, "девять нажатий подряд заполняют шкалу")
	equal(pull.level, 0.0, "новый рывок начинается с пустой шкалы")
	pull.level = 0.5
	pull.advance(1.0, false)
	var second := 0.5 - pull.level
	pull.jerk = 2
	pull.level = 0.5
	pull.advance(1.0, false)
	check(0.5 - pull.level > second, "в третьем рывке шкала утекает быстрее")
	check(not pull.is_done(), "игра ещё идёт")
	pull.level = 0.95
	check(pull.press(), "последнее нажатие завершает рывок")
	check(pull.is_done(), "три рывка сделаны")
	check(not pull.press(), "после конца нажатия не считаются")


## Режим «удерживать» позволяет пройти мини-игру без частых нажатий.
func test_pull_hold_mode() -> void:
	var pull := PullLogic.new()
	var seconds := 0.0
	while not pull.is_done() and seconds < 120.0:
		pull.advance(0.1, true)
		seconds += 0.1
	check(pull.is_done(), "удержание проходит все три рывка")
	check(seconds < 30.0, "удержание занимает меньше полминуты")
