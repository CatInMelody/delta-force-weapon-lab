extends Control
## 读取选择器提供的枪械基础数据，更新信息面板。

const WeaponMultipliers = preload("res://Code/weapon_multipliers.gd")
const DamageCalculator = preload("res://Code/damage_calculator.gd")
const HIGH_COLOR := Color("ff5c5c")
const LOW_COLOR := Color("68dca3")

@export var head_multiplier: float = 1.9
@export var chest_multiplier: float = 1.0
@export var abdomen_multiplier: float = 0.9
@export var limbs_multiplier: float = 0.4

@onready var damage: Control = $Margin/Column/Damage
@onready var magnification: Control = $Margin/Column/Magnification
@onready var refresh: Control = $"../RefreshLayer/GunRefresh"
@onready var multiplier_refresh: Control = $"../RefreshLayer/MultiplierRefresh"
@onready var choose: Control = $"../Chosse"
@onready var ttk_label: Label = $Margin/Column/Damage/TTK


func _ready() -> void:
	choose.weapon_changed.connect(_update_weapon)
	choose.bullet_changed.connect(_on_bullet_changed)
	damage.tooltip_text = "秒肉伤 = 肉伤 × 射速 ÷ 60\n秒甲伤 = 甲伤 × 射速 ÷ 60\n射速单位：发/分钟；射程单位：米"
	# 无论两个兄弟节点以什么顺序初始化，都能显示默认武器的数据。
	if not choose.selected_weapon.is_empty():
		_update_weapon(choose.selected_weapon)


func _on_bullet_changed(_bullet: Dictionary) -> void:
	if not choose.selected_weapon.is_empty():
		_update_weapon(choose.selected_weapon)


func _update_weapon(weapon: Dictionary) -> void:
	var flesh := float(weapon["flesh_damage"])
	var armor := float(weapon["armor_damage"])
	var rate := DamageCalculator.effective_fire_rate(weapon, choose.selected_bullet)
	var ttk := ttk_summary_for(weapon)
	damage.tooltip_text = "秒伤按持续射速计算；AN94前两发1800，后续600。" if weapon.has("initial_fire_rate_rpm") else "秒肉伤 = 肉伤 × 射速 ÷ 60\n秒甲伤 = 甲伤 × 射速 ÷ 60"
	var ttk_text := "%.2f 秒" % float(ttk["seconds"]) if int(ttk["shots"]) >= 0 else "无法击倒"
	var updated_text := "秒肉伤：%s\n秒甲伤：%s\n肉伤：%s\n甲伤：%s\n射速：%s\n射程：%s 米\nTTK：%s" % [
		_format_number(flesh * rate / 60.0),
		_format_number(armor * rate / 60.0),
		_format_number(flesh),
		_format_number(armor),
		DamageCalculator.fire_rate_text(weapon, choose.selected_bullet),
		_format_number(float(weapon["range_m"])),
		ttk_text,
	]
	if not ttk["bullet"].is_empty():
		ttk_label.tooltip_text = "%s · %d级弹\n满耐久重型突击背心（%s耐久），100血，全胸命中\n从第一发命中计时：(%d - 1) × 60 ÷ %s\n独立于右侧所选弹药和防具" % [ttk["bullet"]["display_name"], int(ttk["bullet"]["level"]), _format_number(float(ttk["armor_durability"])), int(ttk["shots"]), _format_number(float(ttk["fire_rate"]))]
		if weapon.has("initial_fire_rate_rpm"):
			ttk_label.tooltip_text = "前两发1800发/分钟，后续600发/分钟。\nTTK按用户指定参考值0.26秒展示；不由恒定600射速公式推算。"
	var updates: Array[Dictionary] = []
	var lines := updated_text.split("\n")
	for index in range(lines.size()):
		updates.append({"label": damage.get_child(index), "text": lines[index]})
	refresh.apply_updates(updates)
	_update_multipliers(weapon)


func ttk_summary_for(weapon: Dictionary) -> Dictionary:
	var choices: Array[Dictionary] = choose.get_bullet_choices_for_weapon(weapon)
	var selected: Dictionary = {}
	for bullet in choices:
		if int(bullet["level"]) == 5:
			if selected.is_empty() or (bool(selected.get("is_season_limited", false)) and not bool(bullet.get("is_season_limited", false))):
				selected = bullet
	if selected.is_empty():
		for bullet in choices:
			if selected.is_empty() or int(bullet["level"]) > int(selected["level"]):
				selected = bullet
	if selected.is_empty():
		return {"bullet": {}, "shots": -1, "seconds": -1.0, "fire_rate": 0.0}
	var armor: Dictionary = choose._find_by_name(choose.armors, "重型突击背心")
	var result := DamageCalculator.calculate(weapon, selected, {"level": 0, "max_durability": 0}, armor, get_multipliers(weapon))
	var shots := int(result["chest"])
	var rate := DamageCalculator.effective_fire_rate(weapon, selected)
	return {"bullet": selected, "armor_durability": armor["max_durability"], "shots": shots, "seconds": float(weapon.get("reference_ttk_seconds", DamageCalculator.shot_time(maxi(shots - 1, 0), weapon, selected))) if shots >= 0 else -1.0, "fire_rate": rate}


func get_default_multipliers() -> Dictionary:
	return {"head": head_multiplier, "chest": chest_multiplier, "abdomen": abdomen_multiplier, "limbs": limbs_multiplier}


func get_multipliers(weapon: Dictionary) -> Dictionary:
	return WeaponMultipliers.for_weapon(weapon, get_default_multipliers())


func _update_multipliers(weapon: Dictionary) -> void:
	var defaults := get_default_multipliers()
	var values := get_multipliers(weapon)
	var keys := ["head", "chest", "abdomen", "limbs"]
	var titles := ["头部倍率", "胸部倍率", "腹部倍率", "四肢倍率"]
	var updates: Array[Dictionary] = []
	for index in range(keys.size()):
		var value: float = values[keys[index]]
		var normal: float = defaults[keys[index]]
		var color := magnification.get_theme_color("font_color", "Label")
		if value > normal:
			color = HIGH_COLOR
		elif value < normal:
			color = LOW_COLOR
		var number := _format_number(value)
		if not number.contains("."):
			number += ".0"
		updates.append({"label": magnification.get_child(index), "text": titles[index] + "：" + number, "color": color})
	multiplier_refresh.apply_updates(updates)


func _format_number(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")
