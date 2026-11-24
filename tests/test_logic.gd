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


## Мини-игра «Тяни!»: нужная клавиша растит шкалу, чужая уменьшает, рывки идут всё труднее.
func test_pull_logic() -> void:
	var pull := PullLogic.new(7)
	equal(pull.jerk, 0, "первый рывок")
	equal(pull.level, PullLogic.START_LEVEL, "шкала начинается не с нуля")
	equal(pull.pressure(), 1, "спасение начинается с первого кадра")
	var wrong := (pull.key + 1) % PullLogic.KEY_COUNT
	check(not pull.press(wrong), "чужая клавиша не считается")
	check(pull.level < PullLogic.START_LEVEL, "чужая клавиша уменьшает шкалу")
	check(pull.press(pull.key), "нужная клавиша принята")
	var first_key := pull.key
	var presses := 0
	while pull.jerk == 0 and presses < 50:
		pull.press(pull.key)
		presses += 1
	equal(pull.jerk, 1, "шкала заполнена, рывок засчитан")
	check(pull.key != first_key, "в новом рывке другая клавиша")
	equal(pull.level, PullLogic.START_LEVEL, "новый рывок начинается с той же шкалы")
	equal(pull.pressure(), 1, "рывок кадр не меняет")
	pull.level = 0.9
	pull.advance(0.5)
	var second := 0.9 - pull.level
	pull.jerk = 2
	pull.level = 0.9
	pull.advance(0.5)
	check(0.9 - pull.level > second, "в третьем рывке шкала утекает быстрее")
	check(not pull.is_done(), "игра ещё идёт")
	pull.level = 0.95
	pull.press(pull.key)
	check(pull.is_won() and pull.is_done() and not pull.is_lost(), "три рывка сделаны")
	check(not pull.press(pull.key), "после конца нажатия не считаются")


## Пустая шкала даёт промах и приближает шахматку, три промаха проигрывают игру.
func test_pull_misses() -> void:
	var pull := PullLogic.new(3)
	var counts: Array[int] = []
	pull.missed.connect(func(count: int) -> void: counts.append(count))
	pull.advance(3.2)
	equal(pull.misses, 1, "шкала утекла до нуля: промах")
	equal(pull.level, PullLogic.START_LEVEL, "после промаха шкала возвращается к началу")
	equal(pull.pressure(), 2, "после промаха второй кадр")
	check(not pull.is_done(), "один промах игру не заканчивает")
	pull.advance(3.2)
	equal(pull.pressure(), 3, "после второго промаха третий кадр")
	pull.advance(3.2)
	equal(counts, [1, 2, 3] as Array[int], "о каждом промахе сообщено")
	check(pull.is_lost() and pull.is_done() and not pull.is_won(), "три промаха: поражение")
	equal(pull.pressure(), PullLogic.MAX_PRESSURE, "шахматка поглотила героя")
	pull.advance(5.0)
	equal(pull.misses, PullLogic.MISSES, "после поражения счёт не растёт")


## Клавиша не меняется внутри первого рывка, меняется внутри следующих и не повторяет прежнюю.
func test_pull_key_switch() -> void:
	var pull := PullLogic.new(11)
	var first := pull.key
	for step: int in 30:
		pull.level = 0.9
		pull.advance(0.1)
	equal(pull.key, first, "в первом рывке клавиша одна")
	pull.jerk = 1
	var changes := 0
	var last := pull.key
	for step: int in 60:
		pull.level = 0.9
		pull.advance(0.1)
		if pull.key != last:
			changes += 1
			last = pull.key
	check(changes >= 2, "во втором рывке клавиша меняется по ходу")
	var same := PullLogic.new(11)
	equal(same.key, first, "одно зерно даёт ту же первую клавишу")
	equal(PullGame.KEY_CODES.size(), PullLogic.KEY_COUNT, "у каждой клавиши есть код")
	equal(PullGame.KEY_LABELS.size(), PullLogic.KEY_COUNT, "у каждой клавиши есть подпись")


## Режим «удерживать» позволяет пройти мини-игру без частых нажатий.
func test_pull_hold_mode() -> void:
	var pull := PullLogic.new(5)
	var seconds := 0.0
	while not pull.is_done() and seconds < 120.0:
		pull.advance(0.1, pull.key)
		seconds += 0.1
	check(pull.is_won(), "удержание нужной клавиши проходит все три рывка")
	check(seconds < 30.0, "удержание занимает меньше полминуты")


## Отладчик: неверная строка и неверное исправление отнимают секунды, верное исправление
## заменяет строку и заканчивает игру победой.
func test_debug_logic() -> void:
	for index: int in DebugLogic.PUZZLES.size():
		var item: Dictionary = DebugLogic.PUZZLES[index]
		var program: Array = item["lines"]
		check(program[item["bug"]] != item["fixes"][0], "программа %d: в строке ошибка" % index)
		for line: String in program:
			check(line.length() <= 50, "программа %d: строка помещается в окно" % index)
	var debug := DebugLogic.new(5, 0)
	var lost: Array[float] = []
	debug.penalized.connect(func(seconds: float) -> void: lost.append(seconds))
	equal(debug.time_left, DebugLogic.TIME_SEC, "время полное")
	debug.point(0)
	check(not debug.select(), "в первой строке ошибки нет")
	equal(debug.time_left, DebugLogic.TIME_SEC - DebugLogic.WRONG_LINE_SEC, "штраф за строку")
	debug.move(-1)
	equal(debug.cursor, debug.lines.size() - 1, "курсор ходит по кругу")
	debug.point(debug.bug_line())
	check(debug.select() and debug.picking, "строка с ошибкой найдена")
	debug.cancel()
	check(not debug.picking, "можно вернуться к коду")
	debug.select()
	debug.point((debug.answer() + 1) % debug.choices.size())
	check(not debug.select(), "неверное исправление")
	equal(lost, [DebugLogic.WRONG_LINE_SEC, DebugLogic.WRONG_FIX_SEC] as Array[float], "штрафы")
	debug.point(debug.answer())
	check(debug.select() and debug.is_solved(), "код исправлен")
	equal(debug.lines[debug.bug_line()], DebugLogic.PUZZLES[0]["fixes"][0], "строка заменена")
	debug.advance(100.0)
	check(not debug.is_failed(), "после победы время не тикает")


## Время отладки кончается, и игра проиграна; штраф тоже может её закончить.
func test_debug_timeout() -> void:
	var debug := DebugLogic.new(1)
	debug.advance(DebugLogic.TIME_SEC - 1.0)
	check(not debug.is_done(), "время ещё есть")
	debug.advance(1.5)
	check(debug.is_failed() and debug.is_done(), "время вышло")
	check(not debug.select(), "после конца выбор не считается")
	var hasty := DebugLogic.new(2)
	hasty.advance(DebugLogic.TIME_SEC - 1.0)
	hasty.point(posmod(hasty.bug_line() + 1, hasty.lines.size()))
	hasty.select()
	check(hasty.is_failed(), "штраф съел последние секунды")


## Капибара: клетки силуэта засчитываются один раз, промах отнимает полсекунды, все клетки - победа.
func test_draw_logic() -> void:
	var drawing := DrawLogic.new()
	equal(drawing.cells_left(), DrawLogic.shape_cells(), "ничего не нарисовано")
	check(not drawing.paint(Vector2i(0, 0)), "угол сетки мимо силуэта")
	equal(drawing.time_left, DrawLogic.TIME_SEC - DrawLogic.MISS_SEC, "промах стоит полсекунды")
	check(drawing.paint(Vector2i(0, 3)), "клетка силуэта закрашена")
	check(not drawing.paint(Vector2i(0, 3)), "второй раз та же клетка не считается")
	drawing.move(Vector2i(-5, 0))
	equal(drawing.cursor, Vector2i(0, 3), "курсор не выходит за край")
	var size := DrawLogic.grid_size()
	for y: int in size.y:
		for x: int in size.x:
			if DrawLogic.in_shape(Vector2i(x, y)):
				drawing.paint(Vector2i(x, y))
	check(drawing.is_solved() and drawing.cells_left() == 0, "капибара нарисована")
	var late := DrawLogic.new()
	late.advance(DrawLogic.TIME_SEC + 0.1)
	check(late.is_failed(), "время вышло")
	check(not late.paint(Vector2i(0, 3)), "после конца не рисуется")


## Каждый следующий уровень сложности труднее по каждому числу, на ультра одно сердце.
func test_difficulty_table() -> void:
	var harder_up: Array[String] = [
		"pull_drain",
		"debug_penalty",
		"bomb_dodges",
		"attack_speed",
		"attack_high",
		"cats_hold",
		"cats_cool",
		"cats_eat",
		"quiz_answers",
		"code_tasks",
		"code_penalty",
	]
	for key: String in Difficulty.TABLE:
		var values: Array = Difficulty.TABLE[key]
		equal(values.size(), Difficulty.LEVELS.size(), "%s: число на каждый уровень" % key)
		for index: int in range(1, values.size()):
			var before := float(values[index - 1])
			var now := float(values[index])
			if key == "cats_sabotage":
				check(now >= before, "%s не слабеет" % key)
			elif key in harder_up:
				check(now > before, "%s растёт к ультра" % key)
			else:
				check(now < before, "%s падает к ультра" % key)
	equal(Difficulty.value("hearts", Difficulty.ULTRA), 1, "на ультра одно сердце")
	equal(Difficulty.value("hearts", Difficulty.MEDIUM), 3, "на среднем три")


## Бой с котами: тепло, корм и закрытое окно разом, удержание до победы; время выходит.
func test_cats_logic() -> void:
	var cats := CatsLogic.new(5)
	cats.configure(Difficulty.MEDIUM)
	check(cats.window_open, "окно открыто в начале")
	equal(cats.happy_count(), 0, "в начале все недовольны")
	var moods: Array[int] = []
	cats.mood_changed.connect(
		func(cat: int, happy: bool) -> void: moods.append(cat if happy else -1)
	)
	for step: int in 3:
		cats.warm()
		cats.feed()
	check(cats.is_happy(CatsLogic.GINGER) and cats.is_happy(CatsLogic.GRAY), "тепло и сыто")
	check(cats.celsius() > CatsLogic.warm_celsius(), "градусник в зелёной зоне")
	cats.advance(1.0)
	equal(cats.hold, 0.0, "пока окно открыто, удержание не копится")
	cats.close_window()
	equal(cats.happy_count(), CatsLogic.CATS, "все трое довольны")
	check(CatsLogic.GINGER in moods and CatsLogic.BLACK in moods, "о каждом коте сообщено")
	var won := [false]
	cats.won.connect(func() -> void: won[0] = true)
	var steps := 0
	while not cats.is_done() and steps < 100:
		cats.advance(0.1)
		steps += 1
	check(won[0] and cats.is_won(), "удержали - победа")
	var cold := CatsLogic.new(5)
	cold.configure(Difficulty.MEDIUM)
	cold.close_window()
	var heat := cold.heat
	cold.advance(1.0)
	var closed_loss := heat - cold.heat
	cold.open_window()
	heat = cold.heat
	cold.advance(1.0)
	check(heat - cold.heat > closed_loss, "через открытое окно тепло уходит быстрее")
	var late := CatsLogic.new(5)
	late.configure(Difficulty.MEDIUM)
	late.close_window()
	late.advance(Difficulty.value("cats_wind") * 1.25)
	check(late.window_open, "заражение снова распахивает окно")
	var lost := [false]
	late.lost.connect(func() -> void: lost[0] = true)
	late.advance(late.time_left + 1.0)
	check(lost[0] and late.is_done() and not late.is_won(), "время вышло - проигрыш")
	var ultra := CatsLogic.new(5)
	ultra.configure(Difficulty.ULTRA)
	check(
		ultra.sabotage and ultra.time_left < cats.time_left, "на ультра меньше времени и вредитель"
	)


## Викторина: правильные ответы до победы, ошибки и вышедшее время до поражения.
func test_quiz_logic() -> void:
	var quiz := QuizLogic.new(3)
	quiz.configure(Difficulty.MEDIUM)
	var first := quiz.question_key()
	var texts: Array[String] = []
	for slot: int in QuizLogic.OPTIONS:
		texts.append(quiz.option_key(slot))
	equal(texts.size(), 4, "четыре варианта")
	check(quiz.option_key(quiz.correct_slot()).ends_with("_A"), "правильный - вариант A")
	check(quiz.answer(quiz.correct_slot()), "правильный ответ принят")
	equal(quiz.hits, 1, "удар засчитан")
	check(quiz.question_key() != first, "следующий вопрос другой")
	check(not quiz.answer((quiz.correct_slot() + 1) % 4), "неверный ответ")
	equal(quiz.mistakes, 1, "ошибка засчитана")
	quiz.advance(quiz.time_per_question + 0.1)
	equal(quiz.mistakes, 2, "вышедшее время - тоже ошибка")
	var won := [false]
	quiz.won.connect(func() -> void: won[0] = true)
	while not quiz.is_done():
		quiz.answer(quiz.correct_slot())
	check(won[0] and quiz.is_won(), "набрал нужное число ответов - победа")
	var hard := QuizLogic.new(3)
	hard.configure(Difficulty.ULTRA)
	var lost := [false]
	hard.lost.connect(func() -> void: lost[0] = true)
	hard.answer((hard.correct_slot() + 1) % 4)
	check(lost[0] and hard.is_done() and not hard.is_won(), "на ультра первая ошибка проигрывает")
	var seen := {}
	var all := QuizLogic.new(1)
	all.needed = QuizLogic.QUESTIONS
	for step: int in QuizLogic.QUESTIONS:
		seen[all.question_key()] = true
		all.answer(all.correct_slot())
	equal(seen.size(), QuizLogic.QUESTIONS, "вопросы не повторяются")


## Бой в 418: верный код решает задачу, неверный отнимает время, вышедшее время проигрывает.
func test_code_logic() -> void:
	equal(CodeLogic.normalize(" &x ; "), "&x", "пробелы и точка с запятой не мешают")
	var code := CodeLogic.new(2)
	code.configure(Difficulty.MEDIUM)
	var has_blank := false
	for line: String in code.code():
		has_blank = has_blank or line.contains(CodeLogic.BLANK)
	check(has_blank, "в программе есть пропуск")
	var first := code.goal_key()
	var time := code.time_left
	check(not code.submit("нечто"), "неверный код")
	equal(code.time_left, time - code.penalty_sec, "минус время за ошибку")
	check(not code.submit(""), "пустой ответ не принят")
	check(code.submit(code.solution() + " "), "верный код принят")
	equal(code.solved, 1, "задача решена")
	check(code.goal_key() != first, "следующая задача другая")
	equal(code.time_left, code.time_per_task, "на новую задачу полное время")
	var won := [false]
	code.won.connect(func() -> void: won[0] = true)
	while not code.is_done():
		code.submit(code.solution())
	check(won[0] and code.is_won(), "нужное число задач - победа")
	var late := CodeLogic.new(2)
	late.configure(Difficulty.ULTRA)
	var lost := [false]
	late.lost.connect(func() -> void: lost[0] = true)
	late.advance(late.time_per_task + 1.0)
	check(lost[0] and late.is_done() and not late.is_won(), "время вышло - проигрыш")
	for task: Dictionary in CodeLogic.TASKS:
		var lines: Array = task["code"]
		check(lines.size() <= 4, "программа помещается на экран")


## Клон шагает зеркально, взрывает бомбы и проигрывает герою; любая раскладка проходима.
func test_mirror_logic() -> void:
	equal(MirrorLogic.mirror(MirrorLogic.HERO_START), MirrorLogic.CLONE_START, "углы напротив")
	var mirror := MirrorLogic.new(4)
	mirror.bombs = [Vector2i(1, 3), Vector2i(3, 3), Vector2i(5, 3)] as Array[Vector2i]
	mirror.move_limit = 99
	check(not mirror.step(Vector2i.UP), "за край поля не шагнуть")
	var hits: Array[Vector2i] = []
	mirror.clone_hit.connect(func(cell: Vector2i) -> void: hits.append(cell))
	for step: int in 5:
		mirror.step(Vector2i.LEFT)
		equal(mirror.clone, MirrorLogic.mirror(mirror.hero), "клон всегда напротив героя")
	equal(hits.size(), 3, "клон наступил на три бомбы")
	check(mirror.is_won(), "победа")
	var boom := MirrorLogic.new(4)
	boom.bombs = [Vector2i(5, 0), Vector2i(3, 3), Vector2i(4, 2)] as Array[Vector2i]
	boom.move_limit = 99
	boom.step(Vector2i.LEFT)
	check(boom.is_done() and not boom.is_won(), "герой на бомбе - проигрыш")
	var tired := MirrorLogic.new(4)
	tired.bombs = [Vector2i(1, 3), Vector2i(3, 3), Vector2i(5, 3)] as Array[Vector2i]
	tired.move_limit = 1
	tired.step(Vector2i.DOWN)
	check(tired.is_done() and not tired.is_won(), "ходы кончились - проигрыш")
	for seed: int in 40:
		var layout := MirrorLogic.new(seed)
		layout.configure(Difficulty.ULTRA)
		equal(layout.bombs.size(), MirrorLogic.BOMBS, "три бомбы")
		for bomb: Vector2i in layout.bombs:
			check(
				not MirrorLogic.mirror(bomb) in layout.bombs, "бомбы не стоят друг напротив друга"
			)
		check(layout.shortest_tour() > 0, "раскладка проходима")
		equal(layout.move_limit, layout.shortest_tour() + layout.slack, "запас ходов по уровню")
