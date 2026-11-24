extends CanvasLayer
## Весь интерфейс поверх игры: задания, тосты, диалоги, развилки, лифт, мини-игры, настройки,
## меню и заставка проигрыша.
##
## Игровые сцены обращаются к интерфейсу только через этот узел.

const FADE_SEC := 0.2
const FX_SETTING := "screen_effects"

var _modals: Array[Modal] = []
var _focus_before: Dictionary = {}
var _fade_tween: Tween = null

@onready var hud: Hud = $Hud
@onready var toasts: ToastStack = $Toasts
@onready var dialogue: DialogueBox = $DialogueBox
@onready var fork: ForkScreen = $ForkScreen
@onready var phone: Phone = $Phone
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var dev_menu: DevMenu = $DevMenu
@onready var elevator: ElevatorPanel = $ElevatorPanel
@onready var pull: PullGame = $PullGame
@onready var debug: DebugGame = $DebugGame
@onready var drawing: DrawGame = $DrawGame
@onready var quiz: QuizGame = $QuizGame
@onready var code: CodeGame = $CodeGame
@onready var mirror: MirrorGame = $MirrorGame
@onready var game_over: GameOverScreen = $GameOverScreen
@onready var settings: SettingsScreen = $SettingsScreen
@onready var confirm: ConfirmScreen = $ConfirmScreen
@onready var difficulty: DifficultyScreen = $DifficultyScreen
@onready var _screen_fx: ColorRect = $ScreenFx
@onready var _fade: ColorRect = $Fade


## Подписывается на решения мира, чтобы показывать тост «ЛАБА запомнила»,
## и на настройки, чтобы включать и выключать эффекты экрана.
func _ready() -> void:
	World.decided.connect(_on_world_decided)
	Settings.changed.connect(_on_setting_changed)
	_screen_fx.visible = Settings.value(FX_SETTING)


## Обрабатывает клавиши паузы, телефона и меню разработчика.
## [param event] - событие ввода, не обработанное игрой и элементами интерфейса.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_top_or(pause_menu)
	elif event.is_action_pressed("phone"):
		_toggle_top_or(phone)
	elif event.is_action_pressed("dev_menu"):
		_toggle_top_or(dev_menu)
	else:
		return
	get_viewport().set_input_as_handled()


## Показывает тост.
## [param text] - готовый текст тоста.
## [param kind] - вид тоста из [ToastStack]: от него зависит цвет рамки.
func toast(text: String, kind: String = ToastStack.KIND_LABA) -> void:
	toasts.show_toast(text, kind)


## Показывает экран поверх игры и ставит мир на паузу.
## [param modal] - экран, который нужно открыть.
func open_modal(modal: Modal) -> void:
	if modal in _modals:
		return
	_modals.append(modal)
	_focus_before[modal] = get_viewport().gui_get_focus_owner()
	Game.set_slow_motion(false)
	modal.show()
	get_tree().paused = true


## Прячет экран, возвращает фокус туда, где он был, и снимает паузу после последнего экрана.
## [param modal] - экран, который нужно закрыть.
func close_modal(modal: Modal) -> void:
	_modals.erase(modal)
	modal.hide()
	get_tree().paused = not _modals.is_empty()
	var previous: Variant = _focus_before.get(modal)
	_focus_before.erase(modal)
	if is_instance_valid(previous) and previous.is_visible_in_tree():
		if previous.focus_mode != Control.FOCUS_NONE:
			previous.grab_focus()


## Закрывает все открытые экраны, например перед сменой сцены.
func close_all_modals() -> void:
	for modal: Modal in _modals.duplicate():
		modal.close()
	get_tree().paused = false


## Сообщает, открыт ли сейчас какой-нибудь экран поверх игры.
## Возвращает true, если мир стоит на паузе из-за интерфейса.
func is_modal_open() -> bool:
	return not _modals.is_empty()


## Плавно затемняет экран.
func fade_out() -> void:
	await _fade_to(1.0)


## Плавно возвращает изображение после затемнения.
func fade_in() -> void:
	await _fade_to(0.0)


## Меняет прозрачность затемнения и ждёт конца анимации.
## [param alpha] - целевая непрозрачность от 0 до 1.
func _fade_to(alpha: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.set_ignore_time_scale(true)
	_fade_tween.tween_property(_fade, "color:a", alpha, FADE_SEC)
	await _fade_tween.finished


## Закрывает верхний экран, если его можно закрыть, иначе открывает указанный.
## [param modal] - экран, который открывается, когда других экранов нет.
func _toggle_top_or(modal: Modal) -> void:
	if Game.is_busy():
		return
	if not _modals.is_empty():
		if _modals.back().closable:
			_modals.back().close()
	elif Game.in_room:
		modal.open()


## Включает или выключает затемнение краёв и зерно, когда меняется настройка.
## [param key] - имя изменённой настройки.
func _on_setting_changed(key: String) -> void:
	if key == FX_SETTING:
		_screen_fx.visible = Settings.value(FX_SETTING)


## Показывает тост о том, что мир запомнил решение.
## [param _key] - имя переменной, тосту не нужно.
## [param _value] - выбранное значение, тосту не нужно.
## [param toast_key] - ключ текста тоста; пустой означает «без тоста».
func _on_world_decided(_key: String, _value: Variant, toast_key: String) -> void:
	if not toast_key.is_empty():
		toast(tr(toast_key), ToastStack.KIND_LABA)
