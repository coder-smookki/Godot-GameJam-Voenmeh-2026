extends TestCase
## Тесты сюжетного состояния: метод, линия ЛАБЫ, концовки, таймер, отметки, проверка значений.


## Новая игра начинается со значений схемы и нейтральной ЛАБЫ.
func test_defaults() -> void:
	equal(World.f.size(), World.SCHEMA.size(), "все переменные схемы на месте")
	equal(World.method(), 0, "метод в начале")
	equal(World.laba_line(), "system", "линия в начале")


## Метод лежит в границах от -6 до +5 из документа.
func test_method_bounds() -> void:
	for pair: Array in [
		["compiler", "fixed"],
		["naurusova", "student"],
		["logunova", "kind"],
		["zeml", "calm"],
		["mozh", "clone"],
	]:
		World.set_value(pair[0], pair[1])
	equal(World.method(), 5, "все починил")
	equal(World.laba_line(), "student", "линия ученицы")
	for pair: Array in [
		["compiler", "deleted"],
		["naurusova", "error"],
		["logunova", "strict"],
		["zeml", "storm"],
		["mozh", "off"],
		["unsafe", 3],
	]:
		World.set_value(pair[0], pair[1])
	equal(World.method(), -6, "всё удалил и три хака")
	equal(World.laba_line(), "auditor", "линия ревизора")


## Линия ЛАБЫ меняется ровно на порогах +2 и -2.
func test_laba_line_thresholds() -> void:
	World.set_value("compiler", "fixed")
	equal(World.laba_line(), "system", "метод +1")
	World.set_value("zeml", "calm")
	equal(World.laba_line(), "student", "метод +2")
	World.reset()
	World.set_value("compiler", "deleted")
	equal(World.laba_line(), "system", "метод -1")
	World.set_value("zeml", "storm")
	equal(World.laba_line(), "auditor", "метод -2")


## Два хака метод не меняют, а «уйти» у рубильника нейтрально.
func test_method_neutral_choices() -> void:
	World.set_value("unsafe", 2)
	World.set_value("mozh", "stay")
	World.set_value("naurusova", "unknown")
	equal(World.method(), 0, "нейтральные выборы")


## Терминалы дают концовки по правилам документа.
func test_endings_by_terminal() -> void:
	equal(World.ending("delete"), "rm_rf", "удалить")
	equal(World.ending("reset"), "loop", "откатить")
	World.set_value("messages", 2)
	equal(World.ending("fix"), "", "исправить закрыт при 2 посланиях")
	World.set_value("messages", 3)
	equal(World.ending("fix"), "retake", "исправить при 3 посланиях")
	World.set_value("capy", 44)
	equal(World.ending("fix"), "capybara", "исправить и 44 капибары")
	equal(World.ending("other"), "", "неизвестный терминал")


## Таймер финала: 10 минут, 5 без карантина, +20 секунд за одногруппника.
func test_final_timer() -> void:
	equal(World.final_timer_sec(), 600.0, "обычный таймер")
	World.set_value("students", 6)
	equal(World.final_timer_sec(), 720.0, "шесть спасённых")
	World.set_value("mozh", "off")
	equal(World.final_timer_sec(), 420.0, "карантин выключен")


## Недопустимые значения и неизвестные переменные отклоняются.
func test_validation() -> void:
	check(not World.is_valid("compiler", "broken"), "чужое значение")
	check(not World.is_valid("compiler", 1), "чужой тип")
	check(not World.is_valid("nope", 1), "неизвестная переменная")
	check(not World.is_valid("cats", 6), "счётчик выше предела")
	check(not World.is_valid("cats", -1), "отрицательный счётчик")
	check(World.is_valid("first_floor", 3.0), "число из JSON")
	check(World.is_valid("escape_tried", true), "флаг")
	check(not World.set_value("gosha", "maybe"), "тихая запись отклоняет мусор")
	equal(World.f["gosha"], "", "значение не изменилось")


## Счётчики не выходят за границы схемы.
func test_bump_clamps() -> void:
	equal(World.bump("cats", 3), 3, "плюс три")
	equal(World.bump("cats", 9), 5, "упор в предел")
	equal(World.bump("cats", -99), 0, "упор в ноль")
	equal(World.bump("compiler"), 0, "не счётчик")


## Отметка ставится один раз и помнит своё время.
func test_marks() -> void:
	check(not World.is_marked("x"), "отметки нет")
	equal(World.marked_ago("x"), INF, "давность без отметки")
	check(World.mark("x"), "первая отметка")
	check(not World.mark("x"), "повторная отметка")
	World.clock += 12.5
	equal(World.marked_ago("x"), 12.5, "давность отметки")


## Загрузка чинит типы из JSON и отбрасывает мусор.
func test_from_dict_sanitizes() -> void:
	var saved: Dictionary = {
		"f": {"first_floor": 4.0, "compiler": "hacked", "cats": 99, "extra": 1, "capy": 7.0},
		"marks": {"a": 3.0, "b": "bad"},
		"clock": 50.0,
	}
	World.from_dict(saved)
	equal(World.f["first_floor"], 4, "дробное число стало целым")
	equal(World.f["compiler"], "", "мусор заменён значением по умолчанию")
	equal(World.f["cats"], 0, "счётчик вне границ отброшен")
	equal(World.f["capy"], 7, "счётчик восстановлен")
	check(not World.f.has("extra"), "лишний ключ не попал в состояние")
	check(World.is_marked("a") and not World.is_marked("b"), "отметки отфильтрованы")
	equal(World.marked_ago("a"), 47.0, "часы и время отметки восстановлены")
	World.from_dict({"f": "not a dict", "marks": [], "clock": "x"})
	equal(World.f, World.defaults(), "полностью испорченное сохранение даёт начало игры")


## Решение развилки меняет мир, пишется в журнал, сохраняется и оставляет снимок.
func test_decide_records_everything() -> void:
	check(World.decide("P4", "fixed"), "решение принято")
	equal(World.f["compiler"], "fixed", "переменная записана")
	equal(Journal.entries().size(), 1, "запись в журнале")
	equal(Journal.entries()[0], {"key": "compiler", "value": "fixed"}, "содержимое записи")
	check(SaveSystem.has_save(), "автосохранение сделано")
	check(SaveSystem.has_snapshot("P4"), "снимок перед развилкой сделан")
	check(not World.decide("P4", "nonsense"), "чужой вариант отклонён")
	check(not World.decide("P99", "fixed"), "чужая развилка отклонена")
	equal(Journal.entries().size(), 1, "отклонённые решения в журнал не попали")
