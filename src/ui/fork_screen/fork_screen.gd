class_name ForkScreen
extends Modal
## Экран важной развилки: вопрос и карточки вариантов с честной ценой каждого.
##
## Содержимое собирается из каталога развилок. Выбор записывается через мир,
## поэтому снимок перед развилкой, журнал, тост и автосохранение срабатывают сами.

signal chosen(fork_id: String, value: Variant)

const CARD_HEIGHT := 150.0

var _fork_id: String = ""

@onready var _title: Label = $Box/Title
@onready var _cards: HBoxContainer = $Box/Cards


## Открывает экран для развилки и ждёт выбора игрока.
## [param fork_id] - код развилки из каталога, например "P4".
## Возвращает выбранное значение или null, если такой развилки нет.
func ask(fork_id: String) -> Variant:
	var fork: Dictionary = ForkCatalog.get_fork(fork_id)
	if fork.is_empty():
		push_error("ForkScreen.ask: развилки %s нет в каталоге" % fork_id)
		return null
	_fork_id = fork_id
	_title.text = tr(ForkCatalog.title_key(fork_id))
	_clear_cards()
	for option: Dictionary in fork["options"]:
		_cards.add_child(_make_card(option))
	open()
	_cards.get_child(0).grab_focus()
	var result: Array = await chosen
	return result[1]


## Собирает карточку варианта.
## [param option] - словарь варианта из каталога: value и tone.
## Возвращает кнопку-карточку с названием, ценой сейчас и последствием потом.
func _make_card(option: Dictionary) -> Button:
	var value: Variant = option["value"]
	var color := Palette.tone(option["tone"])
	var card := Button.new()
	card.custom_minimum_size.y = CARD_HEIGHT
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("normal", Palette.frame(color, 1))
	card.add_theme_stylebox_override("hover", Palette.frame(color, 2))
	card.add_theme_stylebox_override("focus", Palette.frame(color, 2))
	card.add_theme_stylebox_override("pressed", Palette.frame(color, 2))
	card.pressed.connect(_on_card_pressed.bind(value))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	box.add_child(_make_label(tr(ForkCatalog.option_key(_fork_id, value)), color))
	box.add_child(_make_label(tr(ForkCatalog.now_key(_fork_id, value)), Palette.TEXT))
	box.add_child(_make_label(tr(ForkCatalog.later_key(_fork_id, value)), Palette.GOAL))
	return card


## Собирает строку текста для карточки.
## [param text] - готовый текст.
## [param color] - цвет текста.
## Возвращает подпись с переносом по словам.
func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	return label


## Убирает карточки прошлой развилки.
func _clear_cards() -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()


## Записывает выбор игрока и закрывает экран.
## [param value] - значение выбранного варианта.
func _on_card_pressed(value: Variant) -> void:
	var fork_id := _fork_id
	close()
	World.decide(fork_id, value)
	chosen.emit(fork_id, value)
