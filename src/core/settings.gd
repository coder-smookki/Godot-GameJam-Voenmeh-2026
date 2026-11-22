extends Node
## Настройки игры: громкость, окно, эффекты экрана и удобство управления.
##
## Хранит значения в файле settings.cfg рядом с сохранениями и сразу применяет их.
## Музыка играет через шину Music, звуки через шину Sfx: узлу звука достаточно указать шину.

signal changed(key: String)

const FILE := "settings.cfg"
const SECTION := "settings"
const BASE_SIZE := Vector2i(480, 270)
const VOLUME_MAX := 100
const VOLUME_STEP := 10
const BUSES: Dictionary = {
	"master_volume": &"Master",
	"music_volume": &"Music",
	"sfx_volume": &"Sfx",
}
const DEFAULTS: Dictionary = {
	"master_volume": 80,
	"music_volume": 80,
	"sfx_volume": 80,
	"fullscreen": false,
	"window_scale": 3,
	"pixel_perfect": true,
	"vsync": true,
	"hold_to_pull": false,
	"screen_effects": true,
}

var dir: String = "user://"

var _values: Dictionary = {}


## Читает настройки с диска и применяет их при запуске игры.
func _ready() -> void:
	load_settings()


## Возвращает значение настройки.
## [param key] - имя настройки из [constant DEFAULTS].
## Возвращает число для громкости и размера окна, true или false для переключателей.
func value(key: String) -> Variant:
	return _values[key]


## Меняет настройку, применяет её и записывает файл.
## [param key] - имя настройки из [constant DEFAULTS].
## [param new_value] - новое значение; число приводится к допустимым границам.
## Возвращает true, если настройка существует и значение подходит по типу.
func set_value(key: String, new_value: Variant) -> bool:
	if not _is_valid(key, new_value):
		return false
	var clean: Variant = _clean(key, new_value)
	if _values[key] == clean:
		return true
	_values[key] = clean
	_apply(key)
	save_settings()
	changed.emit(key)
	return true


## Возвращает все настройки к значениям по умолчанию.
func reset() -> void:
	for key: String in DEFAULTS:
		_values[key] = _clean(key, DEFAULTS[key])
	_apply_all()
	save_settings()
	for key: String in DEFAULTS:
		changed.emit(key)


## Считает, во сколько раз можно увеличить окно на этом мониторе.
## Возвращает наибольший целый множитель размера 480x270, при котором окно помещается.
func max_window_scale() -> int:
	if _is_headless():
		return int(DEFAULTS["window_scale"])
	var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	var fit := minf(float(area.x) / float(BASE_SIZE.x), float(area.y) / float(BASE_SIZE.y))
	return maxi(floori(fit), 1)


## Считает размер окна для множителя.
## [param window_scale] - множитель размера 480x270.
## Возвращает размер окна в пикселях.
func window_size(window_scale: int) -> Vector2i:
	return BASE_SIZE * window_scale


## Читает настройки из файла; неизвестные и испорченные значения заменяет значениями по умолчанию.
func load_settings() -> void:
	var file := ConfigFile.new()
	var loaded := file.load(dir + FILE) == OK
	for key: String in DEFAULTS:
		var stored: Variant = DEFAULTS[key]
		if loaded and _is_valid(key, file.get_value(SECTION, key, stored)):
			stored = file.get_value(SECTION, key, stored)
		_values[key] = _clean(key, stored)
	_apply_all()


## Записывает настройки в файл.
## Возвращает true, если файл записан.
func save_settings() -> bool:
	var file := ConfigFile.new()
	for key: String in _values:
		file.set_value(SECTION, key, _values[key])
	return file.save(dir + FILE) == OK


## Проверяет, подходит ли значение настройке по типу.
## [param key] - имя настройки.
## [param candidate] - проверяемое значение.
## Возвращает true, если настройка существует и тип значения совпадает с типом по умолчанию.
func _is_valid(key: String, candidate: Variant) -> bool:
	if not DEFAULTS.has(key):
		return false
	if typeof(DEFAULTS[key]) == TYPE_BOOL:
		return typeof(candidate) == TYPE_BOOL
	return typeof(candidate) == TYPE_INT or typeof(candidate) == TYPE_FLOAT


## Приводит значение к допустимым границам настройки.
## [param key] - имя настройки.
## [param candidate] - значение подходящего типа.
## Возвращает значение, которое можно хранить и применять.
func _clean(key: String, candidate: Variant) -> Variant:
	if typeof(DEFAULTS[key]) == TYPE_BOOL:
		return candidate
	if key == "window_scale":
		return clampi(int(candidate), 1, max_window_scale())
	return clampi(int(candidate), 0, VOLUME_MAX)


## Применяет все настройки разом.
func _apply_all() -> void:
	for key: String in BUSES:
		_apply_volume(key)
	_apply_window()
	_apply("pixel_perfect")
	_apply("vsync")


## Применяет одну настройку.
## [param key] - имя настройки.
func _apply(key: String) -> void:
	if BUSES.has(key):
		_apply_volume(key)
	elif key == "fullscreen" or key == "window_scale":
		_apply_window()
	elif _is_headless():
		return
	elif key == "pixel_perfect":
		var stretch := Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		if _values[key]:
			stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
		get_window().content_scale_stretch = stretch
	elif key == "vsync":
		var mode := DisplayServer.VSYNC_ENABLED if _values[key] else DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(mode)


## Ставит громкость шины звука.
## [param key] - имя настройки громкости.
func _apply_volume(key: String) -> void:
	var bus := AudioServer.get_bus_index(BUSES[key])
	if bus < 0:
		return
	var volume := int(_values[key])
	AudioServer.set_bus_mute(bus, volume == 0)
	AudioServer.set_bus_volume_linear(bus, float(volume) / float(VOLUME_MAX))


## Переключает полный экран или ставит размер окна и возвращает его в центр экрана.
func _apply_window() -> void:
	if _is_headless():
		return
	var window := get_window()
	if _values["fullscreen"]:
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	window.size = window_size(int(_values["window_scale"]))
	window.move_to_center()


## Сообщает, запущена ли игра без окна (тесты и сборка).
## Возвращает true, если окна нет и оконные настройки применять некуда.
func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
