class_name IntroScreen
extends Modal
## Открывающая катсцена перед новой игрой: видео команды на весь экран.
##
## Видео лежит в assets/video/intro.ogv (Ogg Theora: другие форматы Godot не проигрывает).
## Музыка на время видео гаснет. Через полсекунды катсцену можно пропустить клавишей
## подтверждения, пробелом, Esc или кликом; подсказка внизу появляется и гаснет.

signal finished

const VIDEO_PATH := "res://assets/video/intro.ogv"
const SKIP_AFTER_SEC := 0.5

var _player: VideoStreamPlayer = null
var _hint: Label = null
var _clock: float = 0.0
var _playing: bool = false


## Создаёт чёрный фон, видео и подсказку.
func _ready() -> void:
	closable = false
	set_process(false)
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_player = VideoStreamPlayer.new()
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.expand = true
	_player.bus = &"Music"
	_player.finished.connect(_end)
	add_child(_player)
	_hint = Label.new()
	_hint.text = "INTRO_SKIP"
	_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(370.0, 256.0)
	add_child(_hint)


## Проигрывает катсцену до конца или до пропуска.
func play() -> void:
	var stream := load(VIDEO_PATH) as VideoStream
	if stream == null:
		return
	Music.stop()
	_player.stream = stream
	_clock = 0.0
	_playing = true
	open()
	_player.play()
	set_process(true)
	await finished


## Сообщает, идёт ли катсцена.
func is_playing() -> bool:
	return _playing


## Пропускает катсцену.
func skip() -> void:
	if _playing and _clock >= SKIP_AFTER_SEC:
		_end()


## Ведёт время и подсказку.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	_hint.modulate.a = clampf(1.0 - absf(_clock - 2.0) / 2.0, 0.0, 1.0) if _clock < 4.0 else 0.0


## Пропуск клавишей или кликом.
## [param event] - событие ввода.
func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	var key := event.is_action_pressed("ui_accept") or event.is_action_pressed("pause")
	key = key or event.is_action_pressed("jump")
	if event is InputEventMouseButton and event.pressed:
		key = true
	if key:
		get_viewport().set_input_as_handled()
		skip()


## Заканчивает катсцену один раз.
func _end() -> void:
	if not _playing:
		return
	_playing = false
	_player.stop()
	set_process(false)
	close()
	finished.emit()
