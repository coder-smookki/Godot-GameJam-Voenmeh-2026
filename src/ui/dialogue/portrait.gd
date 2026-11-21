class_name Portrait
extends Control
## Портрет говорящего в окне разговора: картинка художника или цветная заглушка.
##
## Заглушка повторяет макет: голова и плечи цвета персонажа.

const SKIN := Color("efbf9b")
const HEAD_CENTER := Vector2(0.5, 0.4)
const HEAD_RADIUS := 0.27
const SHOULDERS := Rect2(0.22, 0.72, 0.56, 0.22)
const SHOULDERS_RADIUS := 4

var _texture: Texture2D = null
var _color: Color = Palette.NPC


## Показывает портрет говорящего.
## [param id] - код говорящего из [SpeakerCatalog].
func show_speaker(id: String) -> void:
	_texture = SpeakerCatalog.portrait(id)
	_color = SpeakerCatalog.color(id)
	queue_redraw()


## Рисует картинку, а если её нет, заглушку из круга и скруглённого прямоугольника.
func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
		return
	draw_circle(HEAD_CENTER * size, HEAD_RADIUS * size.x, SKIN)
	var shoulders := StyleBoxFlat.new()
	shoulders.bg_color = _color
	shoulders.set_corner_radius_all(SHOULDERS_RADIUS)
	shoulders.anti_aliasing = false
	draw_style_box(shoulders, Rect2(SHOULDERS.position * size, SHOULDERS.size * size))
