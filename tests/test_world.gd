extends TestCase
## Тесты сюжетного состояния: концовки, таймер финала, отметки, проверка значений.


## Новая игра начинается со значений схемы.
func test_defaults() -> void:
	equal(World.f.size(), World.SCHEMA.size(), "все переменные схемы на месте")
	equal(World.f, World.defaults(), "значения по умолчанию")
	equal(World.f["mozh"], "", "рубильник ещё не решён")


## Терминалы дают концовки по правилам раскадровки.
func test_endings_by_terminal() -> void:
	equal(World.ending("delete"), "rm_rf", "удалить доступно всегда")
	World.set_value("messages", 1)
	equal(World.ending("fix"), "", "исправить закрыт при одном послании")
	World.set_value("messages", 2)
	equal(World.ending("fix"), "retake", "исправить при двух посланиях из трёх")
	World.set_value("capy", 4)
	equal(World.ending("fix"), "retake", "четырёх капибар мало для секретной концовки")
	World.set_value("capy", 5)
	equal(World.ending("fix"), "capybara", "исправить и все пять капибар")
	equal(World.ending("delete"), "rm_rf", "удалить не зависит от находок")
	equal(World.ending("reset"), "", "терминала «откатить» больше нет")


## Таймер финала: 5 минут и 3 минуты, если карантин выключен.
func test_final_timer() -> void:
	equal(World.final_timer_sec(), 300.0, "обычный таймер")
	World.set_value("mozh", "capy")
	equal(World.final_timer_sec(), 300.0, "Капи держит рубильник")
	World.set_value("mozh", "stay")
	equal(World.final_timer_sec(), 300.0, "Можайцев держит рубильник")
	World.set_value("mozh", "off")
	equal(World.final_timer_sec(), 180.0, "карантин выключен")


## Недопустимые значения и неизвестные переменные отклоняются.
func test_validation() -> void:
	check(not World.is_valid("mozh", "broken"), "чужое значение")
	check(not World.is_valid("mozh", 1), "чужой тип")
	check(not World.is_valid("nope", 1), "неизвестная переменная")
	check(not World.is_valid("messages", 4), "счётчик выше предела")
	check(not World.is_valid("messages", -1), "отрицательный счётчик")
	check(World.is_valid("capy", 3.0), "число из JSON")
	check(World.is_valid("escape_tried", true), "флаг")
	check(not World.set_value("mozh", "maybe"), "тихая запись отклоняет мусор")
	equal(World.f["mozh"], "", "значение не изменилось")


## Счётчики не выходят за границы схемы.
func test_bump_clamps() -> void:
	equal(World.bump("capy", 3), 3, "плюс три")
	equal(World.bump("capy", 9), 5, "упор в предел")
	equal(World.bump("capy", -99), 0, "упор в ноль")
	equal(World.bump("mozh"), 0, "не счётчик")


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
		"f": {"capy": 4.0, "mozh": "hacked", "messages": 99, "extra": 1, "escape_tried": true},
		"marks": {"a": 3.0, "b": "bad"},
		"clock": 50.0,
	}
	World.from_dict(saved)
	equal(World.f["capy"], 4, "дробное число стало целым")
	equal(World.f["mozh"], "", "мусор заменён значением по умолчанию")
	equal(World.f["messages"], 0, "счётчик вне границ отброшен")
	equal(World.f["escape_tried"], true, "флаг восстановлен")
	check(not World.f.has("extra"), "лишний ключ не попал в состояние")
	check(World.is_marked("a") and not World.is_marked("b"), "отметки отфильтрованы")
	equal(World.marked_ago("a"), 47.0, "часы и время отметки восстановлены")
	World.from_dict({"f": "not a dict", "marks": [], "clock": "x"})
	equal(World.f, World.defaults(), "полностью испорченное сохранение даёт начало игры")


## Решение развилки меняет мир, пишется в журнал, сохраняется и оставляет снимок.
func test_decide_records_everything() -> void:
	check(World.decide("P2", "capy"), "решение принято")
	equal(World.f["mozh"], "capy", "переменная записана")
	equal(Journal.entries().size(), 1, "запись в журнале")
	equal(Journal.entries()[0], {"key": "mozh", "value": "capy"}, "содержимое записи")
	check(SaveSystem.has_save(), "автосохранение сделано")
	check(SaveSystem.has_snapshot("P2"), "снимок перед развилкой сделан")
	check(not World.decide("P2", "nonsense"), "чужой вариант отклонён")
	check(not World.decide("P99", "capy"), "чужая развилка отклонена")
	equal(Journal.entries().size(), 1, "отклонённые решения в журнал не попали")
