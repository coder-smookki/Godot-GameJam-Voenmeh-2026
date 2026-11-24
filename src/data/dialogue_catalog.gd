class_name DialogueCatalog
extends RefCounted
## Каталог разговоров: кто говорит, какой текст и какие ответы может выбрать игрок.
##
## Реплика - словарь с ключами speaker (код из [SpeakerCatalog], пустой для текста от автора),
## text (ключ текста), необязательными choices и pose (поза говорящего, если у него есть кадры).
## Ответ - словарь с ключами text, tag и reply.
## Ответ с меткой «сюжет» ведёт разговор дальше, после остальных игрок возвращается к выбору.

const TAG_STORY := "story"
const TAG_CHAT := "chat"
const TAG_SIDE := "side"
const TAGS: Array[String] = [TAG_STORY, TAG_CHAT, TAG_SIDE]
const TALKS: Dictionary = {
	"vestibule_arrival":
	[
		{"speaker": "demyan", "text": "TALK_VESTIBULE_1"},
		{"speaker": "demyan", "text": "TALK_VESTIBULE_2"},
	],
	"notice_board":
	[
		{"speaker": "demyan", "text": "TALK_BOARD_1"},
		{"speaker": "", "text": "TALK_BOARD_2"},
	],
	"elevator_first":
	[
		{"speaker": "", "text": "TALK_ELEVATOR_1"},
		{"speaker": "demyan", "text": "TALK_ELEVATOR_2"},
	],
	"vanya_rescue":
	[
		{
			"speaker": "vanya",
			"text": "TALK_VANYA_1",
			"choices":
			[
				{
					"text": "TALK_VANYA_ASK_HOW",
					"tag": TAG_STORY,
					"reply":
					[
						{"speaker": "vanya", "text": "TALK_VANYA_HOW_1"},
						{"speaker": "vanya", "text": "TALK_VANYA_HOW_2"},
					],
				},
				{
					"text": "TALK_VANYA_ASK_STATE",
					"tag": TAG_CHAT,
					"reply": [{"speaker": "vanya", "text": "TALK_VANYA_STATE"}],
				},
			],
		},
	],
	"vanya_after": [{"speaker": "vanya", "text": "TALK_VANYA_AFTER"}],
	"corridor_2_arrival":
	[
		{"speaker": "demyan", "text": "TALK_CORRIDOR_2_1"},
		{"speaker": "", "text": "TALK_CORRIDOR_2_2"},
		{"speaker": "demyan", "text": "TALK_CORRIDOR_2_3"},
		{"speaker": "", "text": "TALK_CORRIDOR_2_4"},
		{"speaker": "demyan", "text": "TALK_CORRIDOR_2_5"},
	],
	"naurusova":
	[
		{"speaker": "naurusova", "text": "TALK_NAURUSOVA_1", "pose": "neutral2"},
		{"speaker": "naurusova", "text": "TALK_NAURUSOVA_2", "pose": "questioning"},
		{"speaker": "naurusova", "text": "TALK_NAURUSOVA_3", "pose": "neutral"},
		{"speaker": "naurusova", "text": "TALK_NAURUSOVA_4", "pose": "angry"},
	],
	"valshtein":
	[
		{"speaker": "valshtein", "text": "TALK_VALSHTEIN_1"},
		{"speaker": "demyan", "text": "TALK_VALSHTEIN_2"},
		{"speaker": "valshtein", "text": "TALK_VALSHTEIN_3"},
	],
	"valshtein_free":
	[
		{"speaker": "valshtein", "text": "TALK_VALSHTEIN_FREE_1"},
		{"speaker": "demyan", "text": "TALK_VALSHTEIN_FREE_2"},
	],
	"logunova":
	[
		{"speaker": "", "text": "TALK_LOGUNOVA_1"},
		{"speaker": "", "text": "TALK_LOGUNOVA_2"},
		{"speaker": "", "text": "TALK_LOGUNOVA_3"},
	],
	"logunova_free":
	[
		{"speaker": "", "text": "TALK_LOGUNOVA_FREE_1"},
	],
	"zemlyanskaya":
	[
		{"speaker": "", "text": "TALK_ZEML_1"},
		{"speaker": "zemlyanskaya", "text": "TALK_ZEML_2"},
		{"speaker": "", "text": "TALK_ZEML_3"},
	],
	"zemlyanskaya_free":
	[
		{"speaker": "zemlyanskaya", "text": "TALK_ZEML_FREE_1"},
		{"speaker": "demyan", "text": "TALK_ZEML_FREE_2"},
		{"speaker": "zemlyanskaya", "text": "TALK_ZEML_FREE_3"},
	],
	"zemlyanskaya_after":
	[
		{"speaker": "zemlyanskaya", "text": "TALK_ZEML_AFTER"},
	],
	"mozhaitsev_far":
	[
		{"speaker": "demyan", "text": "TALK_MOZH_FAR_1"},
		{"speaker": "mozhaitsev", "text": "TALK_MOZH_FAR_2"},
	],
	"mozhaitsev_clone":
	[
		{"speaker": "", "text": "TALK_MOZH_CLONE_1"},
		{"speaker": "mozhaitsev", "text": "TALK_MOZH_CLONE_2"},
	],
	"mozhaitsev_hint":
	[
		{"speaker": "mozhaitsev", "text": "TALK_MOZH_HINT_1"},
		{"speaker": "mozhaitsev", "text": "TALK_MOZH_HINT_2"},
		{"speaker": "mozhaitsev", "text": "TALK_MOZH_HINT_3"},
	],
	"mozhaitsev_retry":
	[
		{"speaker": "mozhaitsev", "text": "TALK_MOZH_RETRY"},
	],
	"mozhaitsev_free":
	[
		{"speaker": "mozhaitsev", "text": "TALK_MOZH_FREE_1"},
		{"speaker": "demyan", "text": "TALK_MOZH_FREE_2"},
		{"speaker": "mozhaitsev", "text": "TALK_MOZH_FREE_3"},
	],
	"lestenko":
	[
		{"speaker": "demyan", "text": "TALK_LESTENKO_1"},
		{"speaker": "lestenko", "text": "TALK_LESTENKO_2"},
		{"speaker": "", "text": "TALK_LESTENKO_3"},
	],
}


## Возвращает коды всех разговоров.
static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(TALKS.keys())
	return result


## Проверяет, есть ли разговор в каталоге.
## [param id] - код разговора.
static func has(id: String) -> bool:
	return TALKS.has(id)


## Возвращает реплики разговора.
## [param id] - код разговора.
## Возвращает массив реплик в формате окна разговора; пустой массив для неизвестного кода.
static func talk(id: String) -> Array:
	return TALKS.get(id, [])


## Возвращает ключ текста для метки ответа.
## [param tag] - метка ответа: сюжет, болтовня или побочное.
static func tag_key(tag: String) -> String:
	return "DIALOGUE_TAG_%s" % tag.to_upper()


## Собирает все реплики разговора вместе с репликами внутри ответов.
## [param id] - код разговора.
## Возвращает плоский массив реплик; нужен тестам и проверке текстов.
static func all_lines(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_collect(talk(id), result)
	return result


## Собирает ключи всех текстов, чтобы тест проверил, что у каждого есть перевод.
static func text_keys() -> Array[String]:
	var result: Array[String] = []
	for tag: String in TAGS:
		result.append(tag_key(tag))
	for id: String in TALKS:
		for line: Dictionary in all_lines(id):
			result.append(line["text"])
			for option: Dictionary in line.get("choices", []):
				result.append(option["text"])
	return result


## Обходит реплики и ответы в глубину.
## [param lines] - реплики одного уровня.
## [param into] - массив, в который добавляются найденные реплики.
static func _collect(lines: Array, into: Array[Dictionary]) -> void:
	for line: Dictionary in lines:
		into.append(line)
		for option: Dictionary in line.get("choices", []):
			_collect(option.get("reply", []), into)
