extends Control
## Главное меню: новая игра, продолжение сохранённой и выход.

@onready var _new_game: Button = $Box/NewGame
@onready var _continue: Button = $Box/Continue
@onready var _quit: Button = $Box/Quit
@onready var _version: Label = $Version


## Привязывает кнопки и показывает версию сборки.
func _ready() -> void:
	_new_game.pressed.connect(_on_new_game_pressed)
	_continue.pressed.connect(_on_continue_pressed)
	_quit.pressed.connect(get_tree().quit)
	_continue.disabled = not SaveSystem.has_save()
	_version.text = str(ProjectSettings.get_setting("application/config/version", ""))
	_new_game.grab_focus()


## Начинает новое прохождение.
func _on_new_game_pressed() -> void:
	_set_buttons_disabled(true)
	Game.new_game()


## Продолжает сохранённое прохождение; при испорченном сохранении возвращает кнопки.
func _on_continue_pressed() -> void:
	_set_buttons_disabled(true)
	if not await Game.continue_game():
		_set_buttons_disabled(false)
		_continue.disabled = true


## Блокирует кнопки на время перехода, чтобы игра не запустилась дважды.
## [param disabled] - true блокирует кнопки, false возвращает их.
func _set_buttons_disabled(disabled: bool) -> void:
	_new_game.disabled = disabled
	_continue.disabled = disabled or not SaveSystem.has_save()
	_quit.disabled = disabled
