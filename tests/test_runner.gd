class_name TestRunner
extends Node
## Запускает все наборы тестов из папки tests и завершает игру с кодом результата.
##
## Живёт в корне дерева, а не в текущей сцене, поэтому тесты могут менять сцены.

const TESTS_DIR := "res://tests/"
const SAVE_DIR := "user://tests/"


## Готовит отдельную папку сохранений и настроек и запускает тесты.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveSystem.dir = SAVE_DIR
	SaveSystem.delete_save()
	for file: String in [SaveSystem.PROFILE_FILE, SaveSystem.PROFILE_FILE + SaveSystem.TMP_SUFFIX]:
		if FileAccess.file_exists(SAVE_DIR + file):
			DirAccess.remove_absolute(SAVE_DIR + file)
	SaveSystem.load_profile()
	Settings.dir = SAVE_DIR
	Settings.reset()
	var failed := await _run_all()
	await Game.to_main_menu()
	get_tree().quit(1 if failed > 0 else 0)


## Находит наборы тестов и выполняет в каждом все функции с именами на "test_".
## Возвращает число проваленных проверок.
func _run_all() -> int:
	var failed := 0
	var total := 0
	var files := Array(DirAccess.get_files_at(TESTS_DIR))
	files.sort()
	for file: String in files:
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		var script: GDScript = load(TESTS_DIR + file)
		if script == null or script.get_base_script() != TestCase:
			continue
		var case: TestCase = script.new()
		case.tree = get_tree()
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			case.failures.clear()
			case.before_each()
			await case.call(method_name)
			total += 1
			if case.failures.is_empty():
				print("  ok    %s.%s" % [file, method_name])
			else:
				failed += case.failures.size()
				for message: String in case.failures:
					print("  FAIL  %s.%s: %s" % [file, method_name, message])
	print("Тестов: %d, провалено проверок: %d" % [total, failed])
	return failed
