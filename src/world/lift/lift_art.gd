class_name LiftArt
extends Sprite2D
## Фон кабины лифта: на панели горит столько кнопок, сколько этажей уже открыто.

const ART: Array[Texture2D] = [
	preload("res://assets/rooms/lift_1.png"),
	preload("res://assets/rooms/lift_2.png"),
	preload("res://assets/rooms/lift_3.png"),
	preload("res://assets/rooms/lift_4.png"),
]


## Выбирает картинку и подписывается на новые отметки мира.
func _ready() -> void:
	centered = false
	refresh()
	World.marked.connect(_on_world_marked)


## Ставит картинку кабины по числу вернувшихся кнопок.
func refresh() -> void:
	texture = ART[Elevator.stage() - 1]


## Меняет картинку, когда вернулась кнопка следующего этажа.
## [param _id] - имя новой отметки; число кнопок считается заново.
func _on_world_marked(_id: String) -> void:
	refresh()
