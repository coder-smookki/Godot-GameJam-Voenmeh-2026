class_name DialogueBox
extends Modal
## Окно разговора: полупрозрачная панель с портретом, именем и печатающимся текстом.
##
## Реплики приходят готовым списком из [DialogueCatalog]. Ответы игрока появляются
## плашками посреди экрана. Ответ с меткой «сюжет» ведёт разговор дальше; после остальных
## ответов игрок возвращается к выбору.

signal typed
signal advanced
signal picked(index: int)
signal line_shown(line: Dictionary)

const CHARS_PER_SEC := 45.0
const SLIDE_SEC := 0.16
const BLINK_SEC := 0.35
const REST_OFFSET := 100.0
const ROW_SIZE := Vector2(320.0, 24.0)
const ROW_FADE_SEC := 0.14
const ROW_DELAY_SEC := 0.06
const MARKER := "▶"
const NARRATION_COLOR := Color("b9c2d6")
const ROW_BORDER := Color(0.33, 0.39, 0.56)
const ROW_ACTIVE := Color(0.1, 0.13, 0.23, 0.96)
const ROW_MARGINS := Vector4(20.0, 7.0, 8.0, 5.0)
const TAG_COLORS: Dictionary = {
	DialogueCatalog.TAG_STORY: Palette.GOAL,
	DialogueCatalog.TAG_CHAT: Palette.NEUTRAL,
	DialogueCatalog.TAG_SIDE: Palette.DEBUGGER,
}

var _typing: bool = false
var _waiting: bool = false
var _shown: float = 0.0
var _session: int = 0
var _offered: Array[int] = []

@onready var _sheet: Control = $Sheet
@onready var _frame: Panel = $Sheet/Frame
@onready var _portrait: Portrait = $Sheet/Frame/Portrait
@onready var _tag: PanelContainer = $Sheet/Tag
@onready var _name: Label = $Sheet/Tag/Name
@onready var _text: Label = $Sheet/Text
@onready var _pick: Control = $Pick
@onready var _choices: VBoxContainer = $Pick/Choices
@onready var _more: Label = $Sheet/More


## Выключает покадровую обработку, пока текст не печатается, и запускает мигание стрелки.
func _ready() -> void:
	set_process(false)
	_more.hide()
	var tween := create_tween().set_loops()
	tween.tween_property(_more, "modulate:a", 0.25, BLINK_SEC)
	tween.tween_property(_more, "modulate:a", 1.0, BLINK_SEC)


## Печатает текст реплики по буквам.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_shown += CHARS_PER_SEC * delta
	_text.visible_characters = int(_shown)
	if _text.visible_characters >= _text.get_total_character_count():
		_finish_typing()


## Пропускает печать или переходит к следующей реплике по клавише или клику.
## Пока игрок выбирает ответ, клавиша взаимодействия нажимает выбранную плашку.
## [param event] - событие ввода.
func _input(event: InputEvent) -> void:
	if visible and not _offered.is_empty() and event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null and focused.get_parent() == _choices:
			get_viewport().set_input_as_handled()
			focused.pressed.emit()
		return
	if not visible or not (_typing or _waiting):
		return
	var pressed := event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	advance()


## Допечатывает реплику целиком или переходит к следующей, если она уже напечатана.
func advance() -> void:
	if _typing:
		_finish_typing()
	elif _waiting:
		_set_waiting(false)
		advanced.emit()


## Выбирает ответ, если он сейчас предложен игроку.
## [param index] - номер ответа в реплике.
func choose(index: int) -> void:
	if visible and not _typing and index in _offered:
		picked.emit(index)


## Проигрывает разговор от первой реплики до последней.
## [param lines] - реплики в формате [DialogueCatalog].
## Возвращает true, если разговор дошёл до конца, и false, если окно закрыли раньше
## или оно уже было занято другим разговором.
func play(lines: Array) -> bool:
	if visible or lines.is_empty():
		return false
	open()
	var session := _session
	await _run(lines, session)
	if session != _session:
		return false
	close()
	return true


## Выезжает снизу и очищает прошлый разговор.
func _opened() -> void:
	_frame.hide()
	_tag.hide()
	_text.text = ""
	var rest := size.y - REST_OFFSET
	_sheet.position.y = size.y
	create_tween().tween_property(_sheet, "position:y", rest, SLIDE_SEC)


## Останавливает печать и отменяет разговор, который ещё ждал игрока.
func _closed() -> void:
	_session += 1
	_typing = false
	_set_waiting(false)
	set_process(false)
	_clear_choices()


## Показывает реплики по порядку; реплика с ответами ждёт выбора игрока.
## [param lines] - реплики одного уровня разговора.
## [param session] - номер разговора; если окно закрыли, показ прекращается.
func _run(lines: Array, session: int) -> void:
	for line: Dictionary in lines:
		_fill_line(line)
		await _type_line()
		if session != _session:
			return
		var options: Array = line.get("choices", [])
		if options.is_empty():
			_set_waiting(true)
			await advanced
		else:
			await _ask(line, options, session)
		if session != _session:
			return


## Предлагает ответы, пока игрок не выберет сюжетный или не спросит обо всём.
## [param line] - реплика, к которой относятся ответы.
## [param options] - ответы этой реплики.
## [param session] - номер разговора; если окно закрыли, показ прекращается.
func _ask(line: Dictionary, options: Array, session: int) -> void:
	var asked: Array[int] = []
	while asked.size() < options.size():
		_show_options(options, asked)
		var index: int = await picked
		if session != _session:
			return
		asked.append(index)
		var option: Dictionary = options[index]
		_clear_choices()
		await _run(option.get("reply", []), session)
		if session != _session:
			return
		if option.get("tag", DialogueCatalog.TAG_STORY) == DialogueCatalog.TAG_STORY:
			return
		_fill_line(line)


## Ставит портрет, имя и текст реплики; текст от автора идёт без портрета и имени.
## [param line] - словарь реплики.
func _fill_line(line: Dictionary) -> void:
	_clear_choices()
	var speaker := str(line.get("speaker", ""))
	var known := SpeakerCatalog.has(speaker)
	_frame.visible = known
	_tag.visible = known
	if known:
		_name.text = tr(SpeakerCatalog.name_key(speaker))
		_tag.reset_size()
		_portrait.show_speaker(speaker)
	var color := Palette.TEXT if known else NARRATION_COLOR
	_text.add_theme_color_override("font_color", color)
	_text.text = tr(str(line.get("text", "")))
	_text.visible_characters = -1
	line_shown.emit(line)


## Печатает текущую реплику по буквам и ждёт конца печати.
func _type_line() -> void:
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	set_process(true)
	await typed


## Показывает реплику целиком и сообщает, что печать закончена.
func _finish_typing() -> void:
	_typing = false
	set_process(false)
	_text.visible_characters = -1
	typed.emit()


## Включает или выключает ожидание игрока и стрелку «дальше».
## [param waiting] - true, пока окно ждёт нажатия.
func _set_waiting(waiting: bool) -> void:
	_waiting = waiting
	_more.visible = waiting


## Строит посреди экрана плашки ответов, о которых игрок ещё не спрашивал.
## Плашки проявляются по очереди, фокус стоит на первой; тосты на это время спрятаны.
## [param options] - все ответы реплики.
## [param asked] - номера ответов, которые игрок уже выбирал.
func _show_options(options: Array, asked: Array[int]) -> void:
	_clear_choices()
	for index: int in options.size():
		if index in asked:
			continue
		var row := _make_row(index, options[index])
		row.modulate.a = 0.0
		var fade := row.create_tween()
		fade.tween_interval(ROW_DELAY_SEC * _offered.size())
		fade.tween_property(row, "modulate:a", 1.0, ROW_FADE_SEC)
		_offered.append(index)
		_choices.add_child(row)
	_pick.show()
	Ui.toasts.hide()
	_choices.get_child(0).grab_focus()


## Собирает плашку ответа: маркер выбора слева, текст и метка справа.
## [param index] - номер ответа в реплике.
## [param option] - словарь ответа.
## Возвращает кнопку, готовую к добавлению в список.
func _make_row(index: int, option: Dictionary) -> Button:
	var row := Button.new()
	row.text = tr(str(option.get("text", "")))
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = ROW_SIZE
	row.add_theme_stylebox_override("normal", _row_style(Palette.UI_BACKGROUND, ROW_BORDER))
	for state: String in ["hover", "pressed", "focus"]:
		row.add_theme_stylebox_override(state, _row_style(ROW_ACTIVE, Palette.GOAL))
	row.pressed.connect(choose.bind(index))
	row.mouse_entered.connect(row.grab_focus)
	var marker := _row_label(MARKER, HORIZONTAL_ALIGNMENT_LEFT, Palette.TEXT)
	marker.offset_left = 7.0
	marker.hide()
	row.add_child(marker)
	row.focus_entered.connect(marker.show)
	row.focus_exited.connect(marker.hide)
	var tag := str(option.get("tag", DialogueCatalog.TAG_STORY))
	var tag_color: Color = TAG_COLORS.get(tag, Palette.NEUTRAL)
	var tag_label := _row_label(
		tr(DialogueCatalog.tag_key(tag)), HORIZONTAL_ALIGNMENT_RIGHT, tag_color
	)
	tag_label.offset_right = -8.0
	row.add_child(tag_label)
	return row


## Собирает надпись внутри строки ответа, растянутую на всю строку.
## [param value] - текст надписи.
## [param alignment] - выравнивание по горизонтали.
## [param color] - цвет текста.
## Возвращает надпись, которая не перехватывает мышь.
func _row_label(value: String, alignment: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label


## Собирает рамку плашки ответа.
## [param color] - цвет фона.
## [param border] - цвет рамки; у выбранной плашки он жёлтый.
## Возвращает стиль с отступом под маркер выбора.
func _row_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := Palette.frame(border)
	style.bg_color = color
	style.content_margin_left = ROW_MARGINS.x
	style.content_margin_top = ROW_MARGINS.y
	style.content_margin_right = ROW_MARGINS.z
	style.content_margin_bottom = ROW_MARGINS.w
	return style


## Убирает плашки ответов прошлой реплики.
func _clear_choices() -> void:
	_offered.clear()
	_pick.hide()
	Ui.toasts.show()
	for child: Node in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
