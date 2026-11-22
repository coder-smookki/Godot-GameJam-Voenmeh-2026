class_name PaperButton
extends TextureButton
## Кнопка главного меню из картинки художника.
##
## У картинки одно состояние, поэтому выбор, нажатие и недоступность показываются кодом:
## выбранная кнопка выезжает влево и светлеет, недоступная темнеет.

const SLIDE := Vector2(-6.0, 0.0)
const MOVE_SEC := 0.08
const TINT_IDLE := Color(0.8, 0.8, 0.8, 1.0)
const TINT_FOCUSED := Color(1.0, 1.0, 1.0, 1.0)
const TINT_PRESSED := Color(0.68, 0.68, 0.68, 1.0)
const TINT_DISABLED := Color(0.4, 0.4, 0.45, 1.0)

var _home: Vector2 = Vector2.ZERO
var _tween: Tween = null


## Запоминает место кнопки и подписывается на фокус, мышь и нажатие.
func _ready() -> void:
	_home = position
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	button_down.connect(_refresh)
	button_up.connect(_refresh)
	mouse_entered.connect(_on_mouse_entered)
	_refresh()


## Делает кнопку доступной или недоступной.
## [param enabled] - true разрешает нажатие и выбор с клавиатуры.
func set_enabled(enabled: bool) -> void:
	disabled = not enabled
	focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	_refresh()


## Плавно переводит кнопку в вид, который соответствует её состоянию.
func _refresh() -> void:
	var tint := TINT_IDLE
	var target := _home
	if disabled:
		tint = TINT_DISABLED
	elif has_focus():
		tint = TINT_PRESSED if button_pressed else TINT_FOCUSED
		target = _home + SLIDE
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position", target, MOVE_SEC)
	_tween.tween_property(self, "self_modulate", tint, MOVE_SEC)


## Выбирает кнопку, когда на неё наводят мышь: выделена всегда одна кнопка.
func _on_mouse_entered() -> void:
	if not disabled:
		grab_focus()
