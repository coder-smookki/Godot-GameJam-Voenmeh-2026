class_name Phone
extends Modal
## Телефон героя: журнал решений, открытые концовки и коллекции.
##
## Делает логику игры прозрачной: игрок видит, что выбрал и к чему это привело.

const COLLECTIONS: Array[String] = ["messages", "capy"]

@onready var _tabs: TabContainer = $Panel/Tabs
@onready var _journal: VBoxContainer = $Panel/Tabs/Journal/List
@onready var _endings: GridContainer = $Panel/Tabs/Endings
@onready var _collections: VBoxContainer = $Panel/Tabs/Collections


## Подписывает вкладки телефона.
func _ready() -> void:
	_tabs.set_tab_title(0, tr("PHONE_JOURNAL"))
	_tabs.set_tab_title(1, tr("PHONE_ENDINGS"))
	_tabs.set_tab_title(2, tr("PHONE_COLLECTIONS"))


## Перечитывает все вкладки при открытии телефона.
func _opened() -> void:
	_fill_journal()
	_fill_endings()
	_fill_collections()
	_tabs.get_tab_bar().grab_focus()


## Заполняет журнал решений.
func _fill_journal() -> void:
	_clear(_journal)
	var entries := Journal.entries()
	if entries.is_empty():
		_journal.add_child(_make_label(tr("PHONE_JOURNAL_EMPTY"), Palette.NEUTRAL))
	for entry: Dictionary in entries:
		_journal.add_child(_make_label(_entry_text(entry), Palette.TEXT))


## Собирает строку журнала для решения.
## [param entry] - запись журнала {key, value}.
## Возвращает текст вида «P2 · вопрос развилки: выбранный вариант».
func _entry_text(entry: Dictionary) -> String:
	var fork_id := ForkCatalog.id_by_key(entry["key"])
	if fork_id.is_empty():
		return "%s: %s" % [entry["key"], entry["value"]]
	return (
		"%s · %s: %s"
		% [
			fork_id,
			tr(ForkCatalog.title_key(fork_id)),
			tr(ForkCatalog.option_key(fork_id, entry["value"])),
		]
	)


## Заполняет сетку концовок: открытые показаны названием, закрытые вопросом.
func _fill_endings() -> void:
	_clear(_endings)
	for ending_id: String in EndingCatalog.ids():
		var unlocked := SaveSystem.is_ending_unlocked(ending_id)
		var title := tr(EndingCatalog.title_key(ending_id)) if unlocked else "?"
		var text := "№%d\n%s" % [EndingCatalog.number(ending_id), title]
		var label := _make_label(text, Palette.VIRUS if unlocked else Palette.NEUTRAL)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_endings.add_child(label)


## Заполняет полоски коллекций.
func _fill_collections() -> void:
	_clear(_collections)
	for key: String in COLLECTIONS:
		var total: int = World.SCHEMA[key]["max"]
		var value: int = World.f[key]
		var caption := "%s %d/%d" % [tr("COLLECTION_%s" % key.to_upper()), value, total]
		_collections.add_child(_make_label(caption, Palette.TEXT))
		_collections.add_child(_make_bar(value, total))


## Собирает строку текста.
## [param text] - готовый текст.
## [param color] - цвет текста.
## Возвращает подпись с переносом по словам.
func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	return label


## Собирает полоску прогресса.
## [param value] - текущее значение.
## [param total] - наибольшее значение.
## Возвращает полоску без подписи процента.
func _make_bar(value: int, total: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = total
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size.y = 4.0
	return bar


## Убирает все строки из контейнера.
## [param container] - контейнер, который нужно очистить.
func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
