extends TestCase
## Тесты настроек: значения по умолчанию, границы, запись в файл и громкость шин.


## Возвращает настройки к значениям по умолчанию перед каждым тестом.
func before_each() -> void:
	super()
	Settings.reset()


## Настройки начинаются со значений по умолчанию, шины звука существуют.
func test_defaults() -> void:
	equal(Settings.value("master_volume"), 80, "общая громкость")
	equal(Settings.value("fullscreen"), false, "оконный режим")
	equal(Settings.value("hold_to_pull"), false, "режим «удерживать» выключен")
	equal(Settings.value("screen_effects"), true, "эффекты экрана включены")
	for key: String in Settings.BUSES:
		check(AudioServer.get_bus_index(Settings.BUSES[key]) >= 0, "шина для %s" % key)


## Громкость приводится к границам и сразу попадает на шину.
func test_volume_applies_to_bus() -> void:
	var bus := AudioServer.get_bus_index(&"Music")
	check(Settings.set_value("music_volume", 50), "значение принято")
	check(absf(AudioServer.get_bus_volume_linear(bus) - 0.5) < 0.01, "половина громкости на шине")
	check(not AudioServer.is_bus_mute(bus), "шина звучит")
	Settings.set_value("music_volume", 0)
	check(AudioServer.is_bus_mute(bus), "ноль выключает шину")
	Settings.set_value("music_volume", 250)
	equal(Settings.value("music_volume"), 100, "выше предела не бывает")
	Settings.set_value("music_volume", -5)
	equal(Settings.value("music_volume"), 0, "ниже нуля не бывает")


## Неизвестные настройки и чужие типы отклоняются.
func test_validation() -> void:
	check(not Settings.set_value("nope", 1), "неизвестная настройка")
	check(not Settings.set_value("fullscreen", 1), "число вместо флага")
	check(not Settings.set_value("sfx_volume", "loud"), "строка вместо числа")
	equal(Settings.value("sfx_volume"), 80, "значение не изменилось")
	Settings.set_value("window_scale", 99)
	equal(Settings.value("window_scale"), Settings.max_window_scale(), "окно не больше экрана")
	Settings.set_value("window_scale", 0)
	equal(Settings.value("window_scale"), 1, "окно не меньше одного размера")


## Настройки переживают перезапуск, а испорченный файл даёт значения по умолчанию.
func test_roundtrip_and_broken_file() -> void:
	Settings.set_value("sfx_volume", 30)
	Settings.set_value("hold_to_pull", true)
	Settings.set_value("vsync", false)
	Settings.load_settings()
	equal(Settings.value("sfx_volume"), 30, "громкость прочитана")
	equal(Settings.value("hold_to_pull"), true, "флаг прочитан")
	equal(Settings.value("vsync"), false, "выключенный флаг прочитан")
	var file := FileAccess.open(Settings.dir + Settings.FILE, FileAccess.WRITE)
	file.store_string('[settings]\nsfx_volume="loud"\nmaster_volume=40\nfullscreen=7\n')
	file.close()
	Settings.load_settings()
	equal(Settings.value("sfx_volume"), 80, "мусор заменён значением по умолчанию")
	equal(Settings.value("master_volume"), 40, "хорошее значение из того же файла принято")
	equal(Settings.value("fullscreen"), false, "число вместо флага отброшено")


## Сигнал сообщает о каждой изменённой настройке, а повтор того же значения молчит.
func test_changed_signal() -> void:
	var seen: Array[String] = []
	var listener := func(key: String) -> void: seen.append(key)
	Settings.changed.connect(listener)
	Settings.set_value("master_volume", 60)
	Settings.set_value("master_volume", 60)
	Settings.changed.disconnect(listener)
	equal(seen, ["master_volume"] as Array[String], "один сигнал на одно изменение")
