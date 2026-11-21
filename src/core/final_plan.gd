class_name FinalPlan
extends RefCounted
## План финального боя на крыше, собранный из решений игрока.
##
## Определяет длительность таймера города и то, кто стоит рядом с героем.
## Бой читает этот план и ничего не решает сам.


## Собирает план боя из текущего состояния мира.
## Возвращает словарь: timer_sec - таймер города в секундах,
## capi_present - идёт ли Капи с героем (false, если она осталась у рубильника),
## mozhaitsev_present - пришёл ли Можайцев на крышу, чтобы починить один терминал,
## fix_available - открыт ли терминал «ИСПРАВИТЬ».
static func build() -> Dictionary:
	var choice: String = World.f["mozh"]
	return {
		"timer_sec": World.final_timer_sec(),
		"capi_present": choice != "capy",
		"mozhaitsev_present": choice == "capy" or choice == "off",
		"fix_available": not World.ending("fix").is_empty(),
	}
