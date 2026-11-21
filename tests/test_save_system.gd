extends TestCase
## Тесты сохранений: полный круг, испорченные файлы, снимки развилок и профиль.


## Сохранение и загрузка возвращают мир, журнал, заражение и место героя.
func test_roundtrip() -> void:
	World.decide("P2", "off")
	World.bump("capy", 3)
	World.mark("vanya_saved")
	Infection.start(2, 31.0)
	SaveSystem.session = {"room": "corridor_2", "spawn": "elevator", "task": "TASK_BREAK_TOTEM"}
	check(SaveSystem.save_game(), "файл записан")
	World.reset()
	Journal.clear()
	Infection.reset()
	SaveSystem.session = {}
	check(SaveSystem.load_game(), "файл прочитан")
	equal(World.f["mozh"], "off", "решение")
	equal(World.f["capy"], 3, "целое число вернулось целым")
	check(World.is_marked("vanya_saved"), "отметка")
	equal(Journal.entries(), [{"key": "mozh", "value": "off"}] as Array[Dictionary], "журнал")
	equal(Infection.percent(2), 31, "заражение")
	equal(SaveSystem.session["room"], "corridor_2", "комната")


## Испорченный файл не роняет игру и не считается сохранением.
func test_corrupted_file() -> void:
	var file := FileAccess.open(SaveSystem.dir + SaveSystem.SAVE_FILE, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	check(not SaveSystem.load_game(), "испорченный файл отклонён")
	equal(World.f, World.defaults(), "мир не изменился")


## Сохранение от прежней версии сюжета не загружается и не меняет мир.
func test_old_version_rejected() -> void:
	World.bump("capy", 2)
	check(SaveSystem.save_game(), "файл записан")
	var path := SaveSystem.dir + SaveSystem.SAVE_FILE
	var text := FileAccess.get_file_as_string(path)
	var current := '"version": %d' % SaveSystem.VERSION
	check(text.contains(current), "версия записана в файл")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text.replace(current, '"version": 1'))
	file.close()
	World.reset()
	check(not SaveSystem.load_game(), "старое сохранение отклонено")
	equal(World.f["capy"], 0, "мир не изменился")


## Без файла загрузка сообщает об отсутствии сохранения.
func test_missing_file() -> void:
	check(not SaveSystem.has_save(), "сохранения нет")
	check(not SaveSystem.load_game(), "загрузка без файла")


## Снимок возвращает игру в состояние до развилки.
func test_snapshot_restores_before_fork() -> void:
	World.bump("capy", 2)
	World.decide("P2", "stay")
	World.bump("capy", 3)
	check(SaveSystem.load_snapshot("P2"), "снимок прочитан")
	equal(World.f["mozh"], "", "решение ещё не принято")
	equal(World.f["capy"], 2, "счётчик как до развилки")
	check(not SaveSystem.load_snapshot("P9"), "снимка другой развилки нет")


## Профиль помнит концовки между играми.
func test_profile() -> void:
	SaveSystem.unlock_ending("retake")
	SaveSystem.unlock_ending("retake")
	equal(SaveSystem.unlocked_endings().count("retake"), 1, "концовка записана один раз")
	SaveSystem.unlock_ending("rm_rf")
	SaveSystem.load_profile()
	check(SaveSystem.is_ending_unlocked("retake"), "концовка пережила перезагрузку профиля")
	check(SaveSystem.is_ending_unlocked("rm_rf"), "вторая концовка тоже в профиле")
	SaveSystem.unlock_ending("no_such_ending")
	check(not SaveSystem.is_ending_unlocked("no_such_ending"), "чужая концовка не записана")
