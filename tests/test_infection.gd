extends TestCase
## Тесты заражения этажей: рост, пределы, лечение и сохранение.


## Заражение растёт только там, где игрока нет, на 1% в минуту.
func test_grows_away_from_player() -> void:
	Infection.start(1, 10.0)
	Infection.start(2, 10.0)
	Infection.current_floor = 1
	Infection.advance(180.0)
	equal(Infection.percent(1), 10, "этаж с игроком не растёт")
	equal(Infection.percent(2), 13, "другой этаж вырос на 3%")


## Сам по себе рост останавливается на 85%, действия игрока могут довести до 100%.
func test_caps() -> void:
	Infection.start(3, 84.0)
	Infection.current_floor = 1
	Infection.advance(6000.0)
	equal(Infection.percent(3), 85, "предел роста")
	Infection.add(3, 50.0)
	equal(Infection.percent(3), 100, "предел заражения")


## Тотем снижает заражение, вылеченный этаж больше не заражается.
func test_heal_and_cure() -> void:
	Infection.start(2, 34.0)
	Infection.heal(2, 8.0)
	equal(Infection.percent(2), 26, "волна восстановления")
	Infection.heal(2, 500.0)
	equal(Infection.percent(2), 0, "ниже нуля не падает")
	Infection.cure(2)
	check(Infection.is_cured(2) and not Infection.is_active(2), "этаж вылечен")
	Infection.start(2, 40.0)
	equal(Infection.percent(2), 0, "вылеченный этаж не заражается снова")


## Заражение переживает сохранение и загрузку через JSON.
func test_roundtrip() -> void:
	Infection.start(1, 12.5)
	Infection.start(4, 60.0)
	Infection.cure(4)
	Infection.current_floor = 3
	var restored: Variant = JSON.parse_string(JSON.stringify(Infection.to_dict()))
	Infection.reset()
	Infection.from_dict(restored)
	equal(Infection.percent(1), 12, "уровень восстановлен")
	check(Infection.is_cured(4), "вылеченный этаж восстановлен")
	equal(Infection.current_floor, 3, "текущий этаж восстановлен")
	Infection.from_dict({"levels": "bad", "cured": 5})
	equal(Infection.percent(1), 0, "испорченные данные дают чистое состояние")
