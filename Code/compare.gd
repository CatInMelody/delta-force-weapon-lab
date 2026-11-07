extends Control

const DataStore = preload("res://Code/data_store.gd")
## 左右各自保存武器和默认弹种；共用对比防具，不修改信息页的选择。

const DamageCalculator = preload("res://Code/damage_calculator.gd")
const NORMAL_COLOR := Color("e5eaf0")
const BETTER_COLOR := Color("ff5c5c")
const METRICS := ["fire_rate", "flesh_dps", "armor_dps", "head", "chest", "abdomen", "mixed_1", "mixed_2", "mixed_3", "arms"]
const ROW_NODES := ["FireRate", "FleshDps", "ArmorDps", "Head", "Chest", "Abdomen", "Mixed1", "Mixed2", "Mixed3", "Arms"]

var sides: Array[Dictionary] = []
var helmet: Dictionary = {}
var armor: Dictionary = {}
var active_side := 0

@onready var refresh: Control = $RefreshLayer/ValuesRefresh
@onready var picker: Control = $ComparePopupLayer/IconPicker
@onready var catalog: Control = $"../Information/Chosse"
@onready var gun_information: Control = $"../Information/GunInformation"


func _ready() -> void:
	helmet = _find_by_name(catalog.helmets, "GN重型头盔")
	armor = _find_by_name(catalog.armors, "重型突击背心")
	$Content/Conditions.text = "%s（%d级 / 耐久%s） · %s（%d级 / 耐久%s）" % [helmet["name"], int(helmet["level"]), str(helmet["max_durability"]), armor["name"], int(armor["level"]), str(armor["max_durability"])]

	sides.append(_bind_side($Content/TableScroll/Table/LeftWeapon, 0))
	sides.append(_bind_side($Content/TableScroll/Table/RightWeapon, 1))
	picker.item_selected.connect(_on_item_selected)
	_select_weapon(0, _find_by_name(catalog.weapons, "M7"))
	_select_weapon(1, _find_by_name(catalog.weapons, "M4A1"))
	visibility_changed.connect(_close_when_hidden)


func _bind_side(panel: PanelContainer, index: int) -> Dictionary:
	var column: VBoxContainer = panel.get_node("Margin/Column")
	var button: Button = column.get_node("WeaponHeader/WeaponButton")
	button.pressed.connect(_open_picker.bind(index))
	var labels: Dictionary = {}
	for metric_index in range(METRICS.size()):
		labels[METRICS[metric_index]] = column.get_node("Metrics/" + ROW_NODES[metric_index] + "/Value")
	return {
		"weapon": {}, "bullet": {}, "metrics": {}, "labels": labels,
		"name_label": column.get_node("WeaponHeader/WeaponName"),
		"image": button.get_node("Image"), "button": button,
		"ammo_label": column.get_node("WeaponHeader/Ammo"),
	}


func _select_weapon(index: int, weapon: Dictionary) -> void:
	if weapon.is_empty():
		return
	var side: Dictionary = sides[index]
	var bullet := _default_ammo(weapon)
	if bullet.is_empty():
		return
	side["weapon"] = weapon
	side["bullet"] = bullet
	side["name_label"].text = ("左侧 · " if index == 0 else "右侧 · ") + weapon["name"] + " ▾"
	side["image"].texture = DataStore.load_texture(weapon["icon"])
	side["ammo_label"].text = "%s · %d级弹" % [bullet["display_name"], bullet["level"]]
	side["ammo_label"].tooltip_text = "默认优先5级，其次4级；两者都没有时使用最接近5级的可用弹药。\n基础伤害比例：%s" % str(bullet["base_damage_ratio"])
	if weapon.has("initial_fire_rate_rpm"):
		side["ammo_label"].tooltip_text += "\n前两发1800发/分钟，后续600；秒伤及高低比较按持续射速600计算。"
	var results := DamageCalculator.calculate(weapon, bullet, helmet, armor, gun_information.get_multipliers(weapon))
	var rate := DamageCalculator.effective_fire_rate(weapon, bullet)
	var metrics: Dictionary = {
		"fire_rate": rate,
		"flesh_dps": float(weapon["flesh_damage"]) * rate / 60.0,
		"armor_dps": float(weapon["armor_damage"]) * rate / 60.0,
		"head": results["head"], "chest": results["chest"], "abdomen": results["abdomen"], "arms": results["arms"],
	}
	for mixed_index in range(3):
		metrics["mixed_%d" % (mixed_index + 1)] = results["arms_then_chest"][mixed_index]
	side["metrics"] = metrics
	_refresh_highlights()


func _default_ammo(weapon: Dictionary) -> Dictionary:
	var choices: Array[Dictionary] = catalog.get_bullet_choices_for_weapon(weapon)
	for level in [5, 4]:
		# 同级优先普通弹种；同等级的多种普通弹按数据清单顺序选取。
		for choice in choices:
			if int(choice["level"]) == level and not bool(choice.get("is_season_limited", false)):
				return choice
		for choice in choices:
			if int(choice["level"]) == level:
				return choice
	if choices.is_empty():
		return {}
	var closest: Dictionary = choices[0]
	for choice in choices:
		if absi(int(choice["level"]) - 5) < absi(int(closest["level"]) - 5):
			closest = choice
	return closest


func _refresh_highlights() -> void:
	if sides[0]["metrics"].is_empty() or sides[1]["metrics"].is_empty():
		return
	var updates: Array[Dictionary] = []
	for metric in METRICS:
		var left: float = sides[0]["metrics"][metric]
		var right: float = sides[1]["metrics"][metric]
		var higher_is_better: bool = metric in ["fire_rate", "flesh_dps", "armor_dps"]
		if not higher_is_better:
			left = INF if left < 0 else left
			right = INF if right < 0 else right
		var winner := -1
		if left != right:
			winner = 0 if (left > right if higher_is_better else left < right) else 1
		for index in range(2):
			var value: float = sides[index]["metrics"][metric]
			var text: String
			if higher_is_better:
				text = ("%.2f" % value).rstrip("0").rstrip(".")
			else:
				text = str(int(value)) if value >= 0 else "无法击杀"
			if metric == "fire_rate":
				text = DamageCalculator.fire_rate_text(sides[index]["weapon"], sides[index]["bullet"])
			updates.append({"label": sides[index]["labels"][metric], "text": text, "color": BETTER_COLOR if winner == index else NORMAL_COLOR})
	refresh.apply_updates(updates)


func _open_picker(index: int) -> void:
	active_side = index
	picker.open_picker("weapon", catalog.weapons, str(sides[index]["weapon"]["id"]), sides[index]["button"].get_global_rect())


func _on_item_selected(_kind: String, item: Dictionary) -> void:
	_select_weapon(active_side, item)


func _close_when_hidden() -> void:
	if not is_visible_in_tree():
		picker.close_picker()


func _find_by_name(items: Array[Dictionary], wanted: String) -> Dictionary:
	for item in items:
		if item["name"] == wanted:
			return item
	return {}
