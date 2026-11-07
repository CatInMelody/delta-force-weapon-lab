extends Control

const DamageCalculator = preload("res://Code/damage_calculator.gd")

@export var armored_limbs := false

var results: Dictionary = {}

@onready var refresh: Control = $"../RefreshLayer/BTKRefresh"
@onready var single: Control = $"../Chosse/Margin/Column/BTKColumns/SingleColumn/Single"
@onready var complex: Control = $"../Chosse/Margin/Column/BTKColumns/MixedColumn/Complex"
@onready var choose: Control = $"../Chosse"
@onready var information: Control = $"../GunInformation"
@onready var special_panel: Control = $"../Chosse/Margin/Column/SpecialAmmo"
@onready var special_description: Label = $"../Chosse/Margin/Column/SpecialAmmo/Content/Description"


func _ready() -> void:
	choose.selection_changed.connect(_on_selection_changed)
	single.tooltip_text = "每种方案均从 100 血、所选头盔及护甲满耐久开始计算。\n头部由头盔防护；胸部由护甲防护；腹部按具体护甲的防护范围计算。"
	complex.tooltip_text = "先命中对应枪数的手臂后，还需要的胸部命中枪数。\n手臂命中若已击杀，显示 0 枪。"
	_update_results()


func _on_selection_changed(_kind: String, _item: Dictionary) -> void:
	_update_results()


func _update_results() -> void:
	if choose.selected_weapon.is_empty() or choose.selected_bullet.is_empty() or choose.selected_helmet.is_empty() or choose.selected_armor.is_empty():
		return
	special_description.text = str(DamageCalculator.special_effect_for(choose.selected_bullet).get("description", ""))
	var gun_note := str(choose.selected_weapon.get("special_description", ""))
	if not gun_note.is_empty():
		special_description.text += ("\n" if not special_description.text.is_empty() else "") + gun_note
	special_panel.visible = not special_description.text.is_empty()
	results = DamageCalculator.calculate(choose.selected_weapon, choose.selected_bullet, choose.selected_helmet, choose.selected_armor, information.get_multipliers(choose.selected_weapon), armored_limbs)
	var single_text := "全头：%s 枪\n全胸：%s 枪\n全腹：%s 枪\n全手：%s 枪" % [
		_count(results["head"]), _count(results["chest"]), _count(results["abdomen"]), _count(results["arms"]),
	]
	var mixed: Array = results["arms_then_chest"]
	var complex_text := "马一枪手：%s 枪\n马二枪手：%s 枪\n马三枪手：%s 枪\n马四枪手：%s 枪" % [
		_count(mixed[0]), _count(mixed[1]), _count(mixed[2]), _count(mixed[3]),
	]
	var updates: Array[Dictionary] = []
	var single_lines := single_text.split("\n")
	var mixed_lines := complex_text.split("\n")
	for index in range(4):
		updates.append({"label": single.get_child(index), "text": single_lines[index]})
		updates.append({"label": complex.get_child(index), "text": mixed_lines[index]})
	refresh.apply_updates(updates)


func _count(shots: int) -> String:
	return str(shots) if shots >= 0 else "无法击杀"
