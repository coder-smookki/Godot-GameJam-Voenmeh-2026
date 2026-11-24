extends Control
## Финал после основной концовки: эпилог на кафедре (после исправления ЛАБЫ) и титры.
##
## Эпилог - кадры художниц 1-4 на весь экран, по репликам из сценария: кадр меняется с
## каждой репликой, Мажайцев в конце делает «тшшш», затем надпись END. Титры едут снизу
## вверх: название игры, команда с пиксельными фотографиями, музыка, благодарность и
## последняя надпись «ВОЕНМЕХ - лучше всех!». Подтверждение ускоряет титры; после них
## игра возвращается в главное меню.

const FRAMES: Array[Texture2D] = [
	preload("res://assets/epilogue/1.png"),
	preload("res://assets/epilogue/2.png"),
	preload("res://assets/epilogue/3.png"),
	preload("res://assets/epilogue/4.png"),
]
const TEAM: Array[Dictionary] = [
	{"name": "Ильин Кирилл Русланович", "photo": "res://assets/credits/kirill.png"},
	{"name": "Мошникова Екатерина Александровна", "photo": "res://assets/credits/katya.png"},
	{"name": "Щетинина Анастасия Петровна", "photo": "res://assets/credits/nastya.png"},
	{"name": "Яковлева Татьяна Алексеевна", "photo": "res://assets/credits/tanya.png"},
]
const MUSIC_CREDITS: Array[String] = [
	"Elektronomia - Sky High [NCS Release]",
	"Mr Smith - Roundup",
	"а также треки, подобранные командой",
]
const GOOD_ENDINGS: Array[String] = ["retake", "capybara"]
const SCROLL_SPEED := 22.0
const FAST_SCROLL := 90.0
const PHOTO_SIZE := 72.0
const ROW_GAP := 92.0
const FRAME_FADE_SEC := 0.4
const END_SEC := 2.2

var _frame: TextureRect = null
var _credits: Control = null
var _scrolling: bool = false
var _fast: bool = false
var _end_y: float = 0.0
var _done: bool = false


## Собирает кадр эпилога и ленту титров и запускает финал.
func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_frame = TextureRect.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_frame.modulate.a = 0.0
	add_child(_frame)
	_credits = Control.new()
	_credits.hide()
	add_child(_credits)
	_build_credits()
	_run.call_deferred()


## Проводит эпилог (после хорошей концовки) и титры.
func _run() -> void:
	if Game.last_ending in GOOD_ENDINGS:
		await _epilogue()
	if is_inside_tree():
		await _roll_credits()


## Эпилог: кадры художниц под реплики из сценария, затем END.
func _epilogue() -> void:
	Music.play("epilogue")
	_frame.texture = FRAMES[0]
	create_tween().tween_property(_frame, "modulate:a", 1.0, FRAME_FADE_SEC)
	await get_tree().create_timer(FRAME_FADE_SEC + 0.3).timeout
	if not is_inside_tree():
		return
	Ui.dialogue.line_shown.connect(_on_line_shown)
	await Ui.dialogue.play(DialogueCatalog.talk("epilogue"))
	Ui.dialogue.line_shown.disconnect(_on_line_shown)
	if not is_inside_tree():
		return
	var end := _label(tr("EPILOGUE_END"), 32, Color.WHITE)
	end.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	end.modulate.a = 0.0
	add_child(end)
	var fade := create_tween()
	fade.tween_property(_frame, "modulate", Color(0.3, 0.3, 0.3), 0.8)
	fade.parallel().tween_property(end, "modulate:a", 1.0, 0.8)
	await get_tree().create_timer(END_SEC).timeout
	if not is_inside_tree():
		return
	var out := create_tween().set_parallel()
	out.tween_property(_frame, "modulate:a", 0.0, 0.8)
	out.tween_property(end, "modulate:a", 0.0, 0.8)
	await out.finished


## Титры едут снизу вверх; после последней надписи - главное меню.
func _roll_credits() -> void:
	Music.play("credits")
	_credits.position.y = size.y
	_credits.show()
	_scrolling = true
	while _scrolling and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().create_timer(END_SEC).timeout
	if is_inside_tree():
		_finish()


## Двигает титры.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	if not _scrolling:
		return
	_credits.position.y -= (FAST_SCROLL if _fast else SCROLL_SPEED) * delta
	var stop := size.y * 0.5 - _end_y
	if _credits.position.y <= stop:
		_credits.position.y = stop
		_scrolling = false


## Ускоряет титры, пока зажато подтверждение; Esc сразу ведёт в меню.
## [param event] - событие ввода.
func _unhandled_input(event: InputEvent) -> void:
	if Ui.dialogue.visible:
		return
	if event.is_action("ui_accept") or event.is_action("jump"):
		_fast = event.is_pressed()
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_finish()


## Возвращает в главное меню один раз.
func _finish() -> void:
	if _done:
		return
	_done = true
	_scrolling = false
	Game.to_main_menu()


## Строит ленту титров: название, команда с фотографиями, музыка, спасибо, Военмех.
func _build_credits() -> void:
	var y := 0.0
	var width := 480.0
	y = _add_line("MAKE A ERROR,", 16, Palette.VIRUS, y, width)
	y = _add_line("and you're an error", 16, Palette.VIRUS, y, width)
	y += 30.0
	y = _add_line(tr("CREDITS_TEAM"), 16, Palette.GOAL, y, width)
	y += 16.0
	for member: Dictionary in TEAM:
		var photo := TextureRect.new()
		photo.texture = load(member["photo"])
		photo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.size = Vector2(PHOTO_SIZE, PHOTO_SIZE)
		photo.position = Vector2((width - PHOTO_SIZE) * 0.5, y)
		_credits.add_child(photo)
		var frame := Panel.new()
		frame.position = photo.position - Vector2(3.0, 3.0)
		frame.size = photo.size + Vector2(6.0, 6.0)
		frame.show_behind_parent = true
		frame.add_theme_stylebox_override("panel", Palette.frame(Palette.VIRUS, 2))
		_credits.add_child(frame)
		_credits.move_child(frame, photo.get_index())
		_add_line(member["name"], 8, Palette.TEXT, y + PHOTO_SIZE + 8.0, width)
		y += ROW_GAP + 14.0
	y += 10.0
	y = _add_line(tr("CREDITS_MUSIC"), 16, Palette.GOAL, y, width)
	y += 8.0
	for track: String in MUSIC_CREDITS:
		y = _add_line(track, 8, Palette.NEUTRAL, y, width)
		y += 4.0
	y += 40.0
	y = _add_line(tr("CREDITS_THANKS"), 8, Palette.TEXT, y, width)
	y += 60.0
	_end_y = y
	_add_line(tr("CREDITS_LAST"), 16, Palette.VIRUS, y, width)


## Добавляет строку титров по центру.
## [param text] - текст.
## [param font_size] - размер шрифта.
## [param color] - цвет.
## [param y] - верх строки.
## [param width] - ширина ленты.
## Возвращает низ строки.
func _add_line(text: String, font_size: int, color: Color, y: float, width: float) -> float:
	var label := _label(text, font_size, color)
	label.position = Vector2(0.0, y)
	label.size = Vector2(width, font_size + 6.0)
	_credits.add_child(label)
	return y + font_size + 8.0


## Создаёт подпись.
## [param text] - текст.
## [param font_size] - размер шрифта.
## [param color] - цвет.
func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label


## Меняет кадр эпилога по реплике.
## [param line] - показанная реплика.
func _on_line_shown(line: Dictionary) -> void:
	var pose := int(str(line.get("pose", "0")))
	if pose >= 1 and pose <= FRAMES.size():
		_frame.texture = FRAMES[pose - 1]
