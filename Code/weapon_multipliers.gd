extends RefCounted

const DataStore = preload("res://Code/data_store.gd")
## 按稳定武器 ID 读取专属倍率；未指定的部位使用默认值。

const DEFAULTS := {"head": 1.9, "chest": 1.0, "abdomen": 0.9, "limbs": 0.4}
const DATA_PATH := "res://data/weapon_multipliers.json"
static var overrides: Dictionary = {}
static var data_generation := -1


static func for_weapon(weapon: Dictionary, defaults: Dictionary = DEFAULTS) -> Dictionary:
	if data_generation != DataStore.generation:
		overrides = {}
		data_generation = DataStore.generation
	if overrides.is_empty():
		overrides = DataStore.read_json(DATA_PATH)["weapons"]
	var values := defaults.duplicate()
	var weapon_id := str(weapon.get("weapon_id", weapon.get("id", "")))
	var entry: Dictionary = overrides.get(str(weapon.get("base_weapon_id", weapon_id)), {})
	values.merge(entry.get("multipliers", {}), true)
	values.merge(weapon.get("body_multipliers", {}), true)
	return values
