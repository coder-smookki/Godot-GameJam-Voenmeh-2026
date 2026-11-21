class_name SettingsScreen
extends Modal
## Экран настроек: громкость, окно и удобство управления.
##
## Строки собираются из списка настроек. Каждая правка сразу применяется и сохраняется,
## поэтому кнопки «применить» нет.

const ROWS: Array[String] = [
	"master_volume",
	"music_volume",
	"sfx_volume",
	"fullscreen",
	"window_scale",
	"pixel_perfect",
	"vsync",
	"hold_to_pull",
	"screen_effects",
]
const SCALE_KEY := "window_scale"
const FULLSCREEN_KEY := "fullscreen"
const CONTROL_WIDTH := 124.0

var _controls: Dictionary = {}
var _labels: Dictionary = {}

@onready var _grid: GridContainer = $Panel/Box/Grid
@onready var _defaults: Button = $Panel/Box/Buttons/Defaults
@onready var _back: Button = $Panel/Box/Buttons/Back


## Собирает строки настроек и привязывает кнопки.
func _ready() -> void:
	for key: String in ROWS:
		_add_row(key)
	_defaults.pressed.connect(Settings.reset)
	_back.pressed.connect(close)
	Settings.changed.connect(_on_setting_changed)


## Перечитывает значения и ставит фокус на первую строку при открытии.
func _opened() -> void:
	for key: String in ROWS:
		_refresh(key)
	_controls[ROWS[0]].grab_focus()


## Добавляет строку: название настройки слева и элемент управления справа.
## [param key] - имя настройки из [Settings].
func _add_row(key: String) -> void:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(label)
	_labels[key] = label
	var control: Control
	if Settings.BUSES.has(key):
		var slider := HSlider.new()
		slider.max_value = Settings.VOLUME_MAX
		slider.step = Settings.VOLUME_STEP
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_slider_changed.bind(key))
		control = slider
	else:
		var button := Button.new()
		button.pressed.connect(_on_button_pressed.bind(key))
		control = button
	control.custom_minimum_size.x = CONTROL_WIDTH
	_grid.add_child(control)
	_controls[key] = control


## Показывает текущее значение настройки в её строке.
## [param key] - имя настройки.
func _refresh(key: String) -> void:
	var title := tr("SETTINGS_%s" % key.to_upper())
	var control: Control = _controls[key]
	var current: Variant = Settings.value(key)
	if control is HSlider:
		control.set_value_no_signal(float(current))
		_labels[key].text = "%s %d%%" % [title, current]
		return
	_labels[key].text = title
	if key == SCALE_KEY:
		var size := Settings.window_size(current)
		control.text = "x%d · %dx%d" % [current, size.x, size.y]
		control.disabled = Settings.value(FULLSCREEN_KEY)
	else:
		control.text = tr("SETTINGS_ON") if current else tr("SETTINGS_OFF")


## Записывает громкость, выбранную ползунком.
## [param new_value] - положение ползунка от 0 до 100.
## [param key] - имя настройки громкости.
func _on_slider_changed(new_value: float, key: String) -> void:
	Settings.set_value(key, int(new_value))


## Переключает настройку по нажатию её кнопки: размер окна идёт по кругу, остальные да/нет.
## [param key] - имя настройки.
func _on_button_pressed(key: String) -> void:
	if key == SCALE_KEY:
		Settings.set_value(key, int(Settings.value(key)) % Settings.max_window_scale() + 1)
	else:
		Settings.set_value(key, not Settings.value(key))


## Обновляет строку изменённой настройки; размер окна зависит ещё и от полного экрана.
## [param key] - имя изменённой настройки.
func _on_setting_changed(key: String) -> void:
	_refresh(key)
	if key == FULLSCREEN_KEY:
		_refresh(SCALE_KEY)
