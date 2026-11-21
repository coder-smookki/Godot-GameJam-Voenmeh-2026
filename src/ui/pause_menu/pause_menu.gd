class_name PauseMenu
extends Modal
## Меню паузы: продолжить, настройки, выход в главное меню или закрытие игры.

@onready var _resume: Button = $Panel/Box/Resume
@onready var _settings: Button = $Panel/Box/Settings
@onready var _to_menu: Button = $Panel/Box/ToMenu
@onready var _quit: Button = $Panel/Box/Quit


## Привязывает кнопки меню к действиям.
func _ready() -> void:
	_resume.pressed.connect(close)
	_settings.pressed.connect(_on_settings_pressed)
	_to_menu.pressed.connect(_on_to_menu_pressed)
	_quit.pressed.connect(_on_quit_pressed)


## Ставит фокус на первую кнопку при открытии.
func _opened() -> void:
	_resume.grab_focus()


## Открывает экран настроек поверх паузы.
func _on_settings_pressed() -> void:
	Ui.settings.open()


## Сохраняет игру и возвращает в главное меню.
func _on_to_menu_pressed() -> void:
	SaveSystem.save_game()
	Game.to_main_menu()


## Сохраняет игру и закрывает её.
func _on_quit_pressed() -> void:
	SaveSystem.save_game()
	get_tree().quit()
