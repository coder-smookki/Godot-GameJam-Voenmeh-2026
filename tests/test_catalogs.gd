extends TestCase
## Тесты каталогов: развилки согласованы с миром, у каждого ключа есть текст, сцены загружаются.

const SCENES_DIR := "res://src/"


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


## В каталогах 12 локаций и 5 концовок, как в раскадровке.
func test_catalog_sizes() -> void:
	equal(LocationCatalog.codes().size(), 12, "локации")
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
	for key: String in Settings.DEFAULTS:
		keys.append("SETTINGS_%s" % key.to_upper())
	for key: String in Story.STEPS:
		keys.append(Story.STEPS[key]["task"])
	keys.append(Story.START_TASK)
	for key: String in keys:
		check(TranslationServer.translate(key) != key, "нет текста для ключа %s" % key)
	equal(str(TranslationServer.translate("")), "", "пустой ключ даёт пустой текст")


## Стартовая комната и крыша собраны, несобранная локация определяется верно.
func test_built_rooms() -> void:
	check(LocationCatalog.is_built(Game.START_ROOM), "стартовая комната")
	check(LocationCatalog.is_built(DevMenu.ROOF), "крыша")
	check(LocationCatalog.is_built(Elevator.room(2)), "коридор второго этажа")
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
