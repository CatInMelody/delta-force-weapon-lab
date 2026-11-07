extends Control

const DataStore = preload("res://Code/data_store.gd")
## 两个榜单按未舍入的基础秒伤排序，显示时最多保留两位小数。

const WeaponCatalog = preload("res://Code/weapon_catalog.gd")
const Calculator = preload("res://Code/damage_calculator.gd")

var flesh_ranking: Array[Dictionary] = []
var armor_ranking: Array[Dictionary] = []
@export var column_widths := PackedInt32Array([44, 118, 80, 48, 48, 55])

@onready var flesh_table: Tree = $Leaderboards/FleshBoard/Margin/Column/Table
@onready var armor_table: Tree = $Leaderboards/ArmorBoard/Margin/Column/Table


func _ready() -> void:
	for weapon in WeaponCatalog.load_weapons():
		var item: Dictionary = weapon.duplicate(true)
		item["flesh_dps"] = float(item["flesh_damage"]) * float(item["fire_rate_rpm"]) / 60.0
		item["armor_dps"] = float(item["armor_damage"]) * float(item["fire_rate_rpm"]) / 60.0
		flesh_ranking.append(item)
		armor_ranking.append(item)
	_sort_ranking(flesh_ranking, "flesh_dps")
	_sort_ranking(armor_ranking, "armor_dps")

	_fill_table(flesh_table, "秒肉伤", "基础肉伤 × 射速 ÷ 60", flesh_ranking, "flesh_dps", $Leaderboards/FleshBoard/Margin/Column/Title.get_theme_color("font_color"))
	_fill_table(armor_table, "秒甲伤", "基础甲伤 × 射速 ÷ 60", armor_ranking, "armor_dps", $Leaderboards/ArmorBoard/Margin/Column/Title.get_theme_color("font_color"))


func _sort_ranking(items: Array[Dictionary], key: String) -> void:
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a[key] == b[key]:
			return str(a["weapon_id"]).casecmp_to(str(b["weapon_id"])) < 0
		return float(a[key]) > float(b[key])
	)


func _fill_table(table: Tree, dps_title: String, formula: String, ranking: Array[Dictionary], dps_key: String, accent: Color) -> void:
	table.clear()
	var headers := ["排名", "枪械", dps_title, "肉伤", "甲伤", "射速"]
	for index in range(6):
		table.set_column_title(index, headers[index])
		table.set_column_custom_minimum_width(index, column_widths[index])
		table.set_column_expand(index, index == 1)
	table.set_column_title_tooltip_text(2, formula + "；按未舍入数值降序排列")
	table.set_column_title_tooltip_text(5, "射速单位：发/分钟")
	var root_item := table.create_item()
	for index in range(ranking.size()):
		var weapon: Dictionary = ranking[index]
		var row := table.create_item(root_item)
		row.set_metadata(0, weapon)
		var values := [str(index + 1), weapon["name"], _number(weapon[dps_key]), _number(weapon["flesh_damage"]), _number(weapon["armor_damage"]), _number(weapon["fire_rate_rpm"])]
		if weapon.has("initial_fire_rate_rpm"):
			values[5] = Calculator.fire_rate_text(weapon, {})
		for cell in range(6):
			row.set_text(cell, values[cell])
			row.set_text_alignment(cell, HORIZONTAL_ALIGNMENT_LEFT if cell == 1 else HORIZONTAL_ALIGNMENT_CENTER)
			row.set_tooltip_text(cell, "%s\n%s：%s\n肉伤：%s　甲伤：%s\n射速：%s 发/分钟" % [weapon["name"], dps_title, values[2], values[3], values[4], values[5]])
			if weapon.has("initial_fire_rate_rpm"):
				row.set_tooltip_text(cell, row.get_tooltip_text(cell) + "\n前两发1800，后续600；本排行榜秒伤按持续射速600计算。")
		row.set_custom_color(2, accent)
		if index < 3:
			row.set_custom_color(0, Color("f0cb83"))


func _number(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")
