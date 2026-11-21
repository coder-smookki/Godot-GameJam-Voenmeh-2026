extends Control
## Главное меню: играть, загрузить сохранение, настройки и выход.
##
## Фон, логотип и кнопки нарисованы художником; меню только расставляет их и оживляет.

const LOGO_FLOAT := 2.0
const LOGO_FLOAT_SEC := 1.8

@onready var _play: PaperButton = $Buttons/Play
@onready var _load: PaperButton = $Buttons/Load
@onready var _settings: PaperButton = $Buttons/Settings
@onready var _quit: PaperButton = $Buttons/Quit
@onready var _logo: TextureRect = $Logo
@onready var _endings: Label = $Endings
@onready var _version: Label = $Version


## Привязывает кнопки, показывает счёт концовок и версию, запускает покачивание логотипа.
func _ready() -> void:
	_play.pressed.connect(_on_play_pressed)
	_load.pressed.connect(_on_load_pressed)
	_settings.pressed.connect(_on_settings_pressed)
	_quit.pressed.connect(get_tree().quit)
	var counts: Dictionary = {
		"found": SaveSystem.unlocked_endings().size(),
		"total": EndingCatalog.total(),
	}
	_endings.text = tr("MENU_ENDINGS").format(counts)
	_version.text = str(ProjectSettings.get_setting("application/config/version", ""))
	_set_locked(false)
	_play.grab_focus()
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_logo, "position:y", _logo.position.y - LOGO_FLOAT, LOGO_FLOAT_SEC)
	tween.tween_property(_logo, "position:y", _logo.position.y, LOGO_FLOAT_SEC)


## Начинает новое прохождение; если есть сохранение, сначала спрашивает разрешение его стереть.
func _on_play_pressed() -> void:
	if SaveSystem.has_save() and not await Ui.confirm.ask("MENU_CONFIRM_NEW_GAME"):
		return
	_set_locked(true)
	Game.new_game()


## Продолжает сохранённое прохождение; если сохранение не читается, возвращает кнопки
## и выключает «Загрузить».
func _on_load_pressed() -> void:
	_set_locked(true)
	if not await Game.continue_game():
		_set_locked(false)
		_load.set_enabled(false)
		_play.grab_focus()


## Открывает экран настроек.
func _on_settings_pressed() -> void:
	Ui.settings.open()


## Блокирует кнопки на время перехода, чтобы игра не запустилась дважды.
## [param locked] - true блокирует кнопки, false возвращает их.
func _set_locked(locked: bool) -> void:
	_play.set_enabled(not locked)
	_load.set_enabled(not locked and SaveSystem.has_save())
	_settings.set_enabled(not locked)
	_quit.set_enabled(not locked)
