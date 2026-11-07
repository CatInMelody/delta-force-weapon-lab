extends RefCounted

const DataStore = preload("res://Code/data_store.gd")
## 原始数据保持不变，用户配置以独立 ID 合并到统一目录。

const BASE_PATH := "res://data/GunsTool_烽火地带_枪械基础数据.json"
const VARIANTS_PATH := "res://data/weapon_variants.json"


static func load_weapons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var by_id: Dictionary = {}
	var variants_by_base: Dictionary = {}
	var source: Dictionary = DataStore.read_json(BASE_PATH)
	for weapon in source["weapons"]:
		by_id[str(weapon["weapon_id"])] = weapon
	var variants: Dictionary = DataStore.read_json(VARIANTS_PATH)
	for definition in variants["weapons"]:
		var base_id := str(definition["base_weapon_id"])
		var item: Dictionary = by_id[base_id].duplicate(true)
		item.merge(definition.get("overrides", {}), true)
		item["weapon_id"] = definition["weapon_id"]
		item["base_weapon_id"] = base_id
		item["name"] = definition["name"]
		item["body_multipliers"] = definition.get("multipliers", {}).duplicate()
		if not variants_by_base.has(base_id):
			variants_by_base[base_id] = []
		variants_by_base[base_id].append(item)
	for weapon in source["weapons"]:
		result.append(weapon.duplicate(true))
		for variant in variants_by_base.get(str(weapon["weapon_id"]), []):
			result.append(variant)
	return result
