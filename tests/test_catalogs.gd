extends TestCase
## Тесты каталогов: развилки согласованы с миром, у каждого ключа есть текст, сцены загружаются.

const SCENES_DIR := "res://src/"
const TEXT_WIDTH := 386.0
const LINES_LIMIT := 3
const LINE_SPACING := 3.0


## Каждая развилка меняет существующую переменную допустимыми значениями.
func test_forks_match_schema() -> void:
	for fork_id: String in ForkCatalog.ids():
		var fork := ForkCatalog.get_fork(fork_id)
		check(World.SCHEMA.has(fork["key"]), "%s: переменная есть в схеме" % fork_id)
		for option: Dictionary in fork["options"]:
			check(
				World.is_valid(fork["key"], option["value"]),
				"%s: значение %s допустимо" % [fork_id, option["value"]]
			)
		equal(ForkCatalog.id_by_key(fork["key"]), fork_id, "%s находится по переменной" % fork_id)


## В каталогах 12 локаций (с кабиной лифта) и 5 концовок, как в раскадровке.
func test_catalog_sizes() -> void:
	equal(LocationCatalog.codes().size(), 12, "локации вместе с кабиной лифта")
	equal(EndingCatalog.total(), 5, "концовки")
	for index: int in EndingCatalog.ids().size():
		equal(EndingCatalog.number(EndingCatalog.ids()[index]), index + 1, "номера по порядку")


## У каждого ключа, который используют каталоги, есть текст в переводе.
func test_every_key_has_text() -> void:
	var keys: Array[String] = []
	keys.append_array(ForkCatalog.text_keys())
	keys.append_array(EndingCatalog.text_keys())
	keys.append_array(LocationCatalog.text_keys())
	keys.append_array(Elevator.text_keys())
	keys.append_array(DialogueCatalog.text_keys())
	keys.append_array(SpeakerCatalog.text_keys())
	keys.append_array(DebugLogic.text_keys())
	keys.append_array(QuizLogic.text_keys())
	keys.append_array(CodeLogic.text_keys())
	for level: String in Difficulty.LEVELS:
		keys.append(Difficulty.name_key(level))
		keys.append(Difficulty.hint_key(level))
	for key: String in Settings.DEFAULTS:
		keys.append("SETTINGS_%s" % key.to_upper())
	for key: String in Story.STEPS:
		for field: String in ["task", "announce"]:
			if Story.STEPS[key].has(field):
				keys.append(Story.STEPS[key][field])
	for key: String in keys:
		check(TranslationServer.translate(key) != key, "нет текста для ключа %s" % key)
	equal(str(TranslationServer.translate("")), "", "пустой ключ даёт пустой текст")


## В разговорах говорят известные персонажи, а из каждого выбора есть ровно один сюжетный выход.
func test_dialogues_are_consistent() -> void:
	for arrivals: Array in Story.ARRIVALS.values():
		for arrival: String in arrivals:
			check(DialogueCatalog.has(arrival), "разговор %s есть в каталоге" % arrival)
	for talk_id: String in Story.ARRIVAL_CONDITIONS:
		check(DialogueCatalog.has(talk_id), "условие для разговора %s" % talk_id)
	for id: String in DialogueCatalog.ids():
		check(not DialogueCatalog.talk(id).is_empty(), "%s: есть реплики" % id)
		for line: Dictionary in DialogueCatalog.all_lines(id):
			var speaker: String = line["speaker"]
			check(
				speaker.is_empty() or SpeakerCatalog.has(speaker), "%s: говорит %s" % [id, speaker]
			)
			var options: Array = line.get("choices", [])
			if options.is_empty():
				continue
			var story := 0
			for option: Dictionary in options:
				check(option["tag"] in DialogueCatalog.TAGS, "%s: метка %s" % [id, option["tag"]])
				story += int(option["tag"] == DialogueCatalog.TAG_STORY)
			equal(story, 1, "%s: один сюжетный ответ" % id)
	check(SpeakerCatalog.portrait("demyan") != null, "портрет героя нарисован")
	check(SpeakerCatalog.portrait("nobody") == null, "у неизвестного портрета нет")


## Каждая реплика помещается в окно разговора: не больше трёх строк текста.
func test_dialogue_lines_fit() -> void:
	var font := Palette.font()
	var limit := font.get_height(Palette.FONT_SIZE) * LINES_LIMIT + LINE_SPACING * (LINES_LIMIT - 1)
	for id: String in DialogueCatalog.ids():
		for line: Dictionary in DialogueCatalog.all_lines(id):
			var text := str(TranslationServer.translate(line["text"]))
			var size := font.get_multiline_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, TEXT_WIDTH, Palette.FONT_SIZE
			)
			check(size.y <= limit + 0.5, "%s: реплика %s длиннее трёх строк" % [id, line["text"]])


## Стартовая комната и крыша собраны, несобранная локация определяется верно.
func test_built_rooms() -> void:
	check(LocationCatalog.is_built(Game.START_ROOM), "стартовая комната")
	check(LocationCatalog.is_built(DevMenu.ROOF), "крыша")
	check(LocationCatalog.is_built(Elevator.room(2)), "коридор второго этажа")
	for level: int in [3, 4, 5]:
		check(LocationCatalog.is_built(Elevator.room(level)), "коридор этажа %d" % level)
	check(LocationCatalog.is_built(Game.LIFT_ROOM), "кабина лифта")
	check(LocationCatalog.is_built("202"), "кабинет 202")
	check(LocationCatalog.is_built("316") and LocationCatalog.is_built("418"), "кабинеты 316 и 418")
	check(not LocationCatalog.is_built("server"), "серверная ещё не собрана")
	check(not LocationCatalog.is_built("9-99"), "чужой код")
	equal(LocationCatalog.floor_of("wardrobe"), 1, "гардероб на первом этаже")
	equal(LocationCatalog.floor_of("roof"), LocationCatalog.FLOOR_ROOF, "крыша")
	for level: int in Elevator.FLOORS:
		equal(
			LocationCatalog.floor_of(Elevator.room(level)),
			level,
			"лифт привозит на %d этаж" % level
		)


## Каждая сцена проекта загружается и создаётся без ошибок.
func test_all_scenes_instantiate() -> void:
	var paths: Array[String] = []
	_collect_scenes(SCENES_DIR, paths)
	check(paths.size() >= 20, "сцены найдены")
	for path: String in paths:
		var scene: PackedScene = load(path)
		check(scene != null and scene.can_instantiate(), "сцена %s загружается" % path)
		if scene != null:
			scene.instantiate().free()


## Рекурсивно собирает пути ко всем сценам в папке.
## [param folder] - папка, с которой начинается обход.
## [param into] - массив, в который добавляются найденные пути.
func _collect_scenes(folder: String, into: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".tscn"):
			into.append(folder + file)
	for sub: String in DirAccess.get_directories_at(folder):
		_collect_scenes("%s%s/" % [folder, sub], into)


## У каждой реплики разговоров есть озвучка.
func test_every_line_is_voiced() -> void:
	for talk_id: String in DialogueCatalog.ids():
		for line: Dictionary in DialogueCatalog.talk(talk_id):
			var key := str(line.get("text", ""))
			check(ResourceLoader.exists(DialogueBox.VOICE_DIR + key + ".mp3"), "озвучка %s" % key)
