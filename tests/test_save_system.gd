extends TestCase
## Тесты сохранений: полный круг, испорченные файлы, снимки развилок и профиль.


## Сохранение и загрузка возвращают мир, журнал, заражение и место героя.
func test_roundtrip() -> void:
	World.decide("P6", 4)
	World.bump("capy", 12)
	World.mark("laba_launched")
	Infection.start(2, 31.0)
	SaveSystem.session = {"room": "1-05", "spawn": "from_1_01", "task": "TASK_BREAK_TOTEM"}
	check(SaveSystem.save_game(), "файл записан")
	World.reset()
	Journal.clear()
	Infection.reset()
	SaveSystem.session = {}
	check(SaveSystem.load_game(), "файл прочитан")
	equal(World.f["first_floor"], 4, "целое число вернулось целым")
	equal(World.f["capy"], 12, "счётчик")
	check(World.is_marked("laba_launched"), "отметка")
	equal(Journal.entries(), [{"key": "first_floor", "value": 4}] as Array[Dictionary], "журнал")
	equal(Infection.percent(2), 31, "заражение")
	equal(SaveSystem.session["room"], "1-05", "комната")


## Испорченный файл не роняет игру и не считается сохранением.
func test_corrupted_file() -> void:
	var file := FileAccess.open(SaveSystem.dir + SaveSystem.SAVE_FILE, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	check(not SaveSystem.load_game(), "испорченный файл отклонён")
	equal(World.f, World.defaults(), "мир не изменился")


## Без файла загрузка сообщает об отсутствии сохранения.
func test_missing_file() -> void:
	check(not SaveSystem.has_save(), "сохранения нет")
	check(not SaveSystem.load_game(), "загрузка без файла")


## Снимок возвращает игру в состояние до развилки.
func test_snapshot_restores_before_fork() -> void:
	World.bump("cats", 2)
	World.decide("P9", "strict")
	World.bump("cats", 3)
	check(SaveSystem.load_snapshot("P9"), "снимок прочитан")
	equal(World.f["logunova"], "", "решение ещё не принято")
	equal(World.f["cats"], 2, "счётчик как до развилки")
	check(not SaveSystem.load_snapshot("P12"), "снимка другой развилки нет")


## Профиль помнит концовки между играми, «Петля» открывает «Новую игру+».
func test_profile() -> void:
	World.set_value("messages", 4)
	SaveSystem.unlock_ending("retake")
	SaveSystem.unlock_ending("retake")
	equal(SaveSystem.unlocked_endings().count("retake"), 1, "концовка записана один раз")
	check(not SaveSystem.is_ng_plus_unlocked(), "«Новая игра+» ещё закрыта")
	SaveSystem.unlock_ending("loop")
	SaveSystem.load_profile()
	check(SaveSystem.is_ending_unlocked("retake"), "концовка пережила перезагрузку профиля")
	check(SaveSystem.is_ng_plus_unlocked(), "«Новая игра+» открыта")
	equal(SaveSystem.best_messages(), 4, "лучший счёт посланий")
	SaveSystem.unlock_ending("no_such_ending")
	check(not SaveSystem.is_ending_unlocked("no_such_ending"), "чужая концовка не записана")
