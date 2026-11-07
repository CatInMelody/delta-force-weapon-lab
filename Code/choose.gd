extends Control

const DataStore = preload("res://Code/data_store.gd")
## 保留原场景 Chosse 节点名，选择结果及信号可供后续伤害计算面板使用。

signal selection_changed(kind: String, item: Dictionary)
signal weapon_changed(weapon: Dictionary)
signal bullet_changed(bullet: Dictionary)
signal helmet_changed(helmet: Dictionary)
signal armor_changed(armor: Dictionary)

const DamageCalculator = preload("res://Code/damage_calculator.gd")
const WeaponCatalog = preload("res://Code/weapon_catalog.gd")

var weapons: Array[Dictionary] = []
var helmets: Array[Dictionary] = []
var armors: Array[Dictionary] = []
var bullet_icons: Dictionary = {}
var backgrounds: Dictionary = {}
var ammo_data: Dictionary = {}
var removed_ammo_ids: Dictionary = {}
var ammo_icon_overrides: Dictionary = {}
var selected_weapon: Dictionary = {}
var selected_bullet: Dictionary = {}
var selected_helmet: Dictionary = {}
var selected_armor: Dictionary = {}
var launchers: Dictionary = {}
var captions: Dictionary = {}

@onready var picker: Control = $ChoosePopupLayer/IconPicker
@onready var gun: TextureRect = $"../GunInformation/Margin/Column/WeaponButton/Gun"
@onready var bullet: TextureRect = $Margin/Column/Equipment/Bullet/Select/Bullet
@onready var bullet_background: TextureRect = $Margin/Column/Equipment/Bullet/Select/BulletBackground
@onready var helmet: TextureRect = $Margin/Column/Equipment/Helmet/Select/Helmet
@onready var armor: TextureRect = $Margin/Column/Equipment/Armor/Select/Armor


func _ready() -> void:
	_load_catalogs()
	launchers = {
		"weapon": $"../GunInformation/Margin/Column/WeaponButton",
		"bullet": $Margin/Column/Equipment/Bullet/Select,
		"helmet": $Margin/Column/Equipment/Helmet/Select,
		"armor": $Margin/Column/Equipment/Armor/Select,
	}
	captions = {
		"weapon": $"../GunInformation/Margin/Column/WeaponCaption",
		"bullet": $Margin/Column/Equipment/Bullet/Caption,
		"helmet": $Margin/Column/Equipment/Helmet/Caption,
		"armor": $Margin/Column/Equipment/Armor/Caption,
	}
	for kind in launchers:
		launchers[kind].pressed.connect(_open_picker.bind(kind))
	picker.item_selected.connect(_on_item_selected)
	_select_weapon(_find_by_name(weapons, "M7"))
	_select_defense("helmet", _find_by_name(helmets, "DICH训练头盔"))
	_select_defense("armor", _find_by_name(armors, "重型突击背心"))
	visibility_changed.connect(_close_when_hidden)
	get_parent().visibility_changed.connect(_close_when_hidden)


func _load_catalogs() -> void:
	var ammo_links: Dictionary = _read_json("res://data/weapon_ammo.json").get("weapons", {})
	ammo_data = _read_json("res://data/ammo_armor_factors.json")
	removed_ammo_ids = _read_json("res://data/removed_ammo.json").get("ammo", {})
	ammo_icon_overrides = _read_json("res://assets/Bullet/Special/special-ammo-icons.json").get("icons", {})
	var defense_data := _read_json("res://data/defense_stats.json")
	var bullets_data := _read_json("res://assets/Bullet/bullet-sources.json")
	backgrounds = bullets_data.get("background_level_mapping", {})
	for entry in bullets_data.get("icons", []):
		bullet_icons[entry["filename"]] = entry
	for entry in WeaponCatalog.load_weapons():
		var item: Dictionary = entry.duplicate(true)
		var link: Dictionary = ammo_links.get(item.get("base_weapon_id", item["weapon_id"]), {})
		if link.is_empty() or not bullet_icons.has(link.get("icon_file", "")):
			push_error("缺少武器口径映射：" + str(item["name"]))
			continue
		item["id"] = item["weapon_id"]
		item["icon"] = "res://assets/" + item["icon_relative_path"]
		item["caliber"] = link["caliber"]
		item["ammo_type_id"] = link["ammo_type_id"]
		item["bullet_icon_file"] = link["icon_file"]
		item["detail"] = item["category_name"] + " · " + link["caliber"]
		weapons.append(item)
	for entry in _read_json("res://assets/defense-sources.json").get("items", []):
		var item: Dictionary = entry.duplicate(true)
		var section := "helmets" if item["category"] == "Helmet" else "armors"
		var stats: Dictionary = defense_data.get(section, {}).get(item["item_id"], {})
		if stats.is_empty():
			push_error("缺少防具耐久：" + str(item["name"]))
			continue
		item["level"] = stats["level"]
		item["max_durability"] = stats["max_durability"]
		item["id"] = item["item_id"]
		item["icon"] = "res://assets/" + item["relative_path"]
		item["detail"] = "%d 级 · 耐久 %s" % [int(item["level"]), str(item["max_durability"])]
		if item["category"] == "Helmet":
			helmets.append(item)
		else:
			armors.append(item)


func get_bullet_choices() -> Array[Dictionary]:
	return get_bullet_choices_for_weapon(selected_weapon)


func get_bullet_choices_for_weapon(weapon: Dictionary) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if weapon.is_empty():
		return choices
	var by_level: Dictionary = ammo_data.get("by_ammo_type_and_level", {}).get(weapon["ammo_type_id"], {})
	var levels: Array[int] = []
	for level in by_level:
		levels.append(int(level))
	levels.sort()
	for level in levels:
		for ammo_id in by_level[str(level)]:
			if removed_ammo_ids.has(str(ammo_id)):
				continue
			var item: Dictionary = ammo_data["ammo"][ammo_id].duplicate(true)
			item["id"] = item["item_id"]
			item["level"] = int(item["penetration_level"])
			item["base_damage_ratio"] = DamageCalculator.base_damage_ratio_for(item)
			item["icon"] = ammo_icon_overrides.get(str(ammo_id), {}).get("godot_icon_path", item["godot_icon_path"])
			var background_level := int(DamageCalculator.special_effect_for(item).get("background_level", level))
			item["background"] = "res://assets/Bullet/" + backgrounds[str(background_level)]
			item["detail"] = "%d 级 · %s" % [level, item["caliber"]]
			item["tooltip"] = "%s\n%d 级子弹\n基础伤害比例：%s" % [item["display_name"], level, str(item["base_damage_ratio"])]
			var special := DamageCalculator.special_effect_for(item)
			if special.has("fixed_chest_damage"):
				item["tooltip"] = "%s\n%d 级子弹\n每颗无甲胸伤：%s\n每颗甲伤：%s\n每枪2弹头" % [item["display_name"], level, str(special["fixed_chest_damage"]["0"]), str(special["fixed_armor_damage"])]
			choices.append(item)
	return choices


func _open_picker(kind: String) -> void:
	var choices: Array[Dictionary] = []
	var current: Dictionary
	match kind:
		"weapon":
			choices = weapons
			current = selected_weapon
		"bullet":
			choices = get_bullet_choices()
			current = selected_bullet
		"helmet":
			choices = helmets
			current = selected_helmet
		"armor":
			choices = armors
			current = selected_armor
	if not choices.is_empty():
		picker.open_picker(kind, choices, str(current.get("id", "")), launchers[kind].get_global_rect())


func _on_item_selected(kind: String, item: Dictionary) -> void:
	match kind:
		"weapon": _select_weapon(item)
		"bullet": _select_bullet(item)
		"helmet", "armor": _select_defense(kind, item)


func _select_weapon(item: Dictionary) -> void:
	if item.is_empty():
		return
	var previous_level := int(selected_bullet.get("level", 4))
	selected_weapon = item
	gun.texture = DataStore.load_texture(item["icon"])
	captions["weapon"].text = item["name"] + "  ▾"
	launchers["weapon"].tooltip_text = item["detail"] + "\n点击选择武器"
	var choices := get_bullet_choices()
	if not choices.is_empty():
		var best: Dictionary = choices[0]
		for choice in choices:
			if choice["id"] == selected_bullet.get("id", ""):
				best = choice
				break
			if absi(choice["level"] - previous_level) < absi(best["level"] - previous_level):
				best = choice
		_select_bullet(best)
	weapon_changed.emit(selected_weapon)
	selection_changed.emit("weapon", selected_weapon)


func _select_bullet(item: Dictionary) -> void:
	selected_bullet = item
	bullet.texture = DataStore.load_texture(item["icon"])
	bullet_background.texture = DataStore.load_texture(item["background"])
	captions["bullet"].text = "%s\n%d 级 ▾" % [item["name"], item["level"]]
	launchers["bullet"].tooltip_text = item["tooltip"] + "\n点击选择弹种与等级"
	bullet_changed.emit(selected_bullet)
	selection_changed.emit("bullet", selected_bullet)


func _select_defense(kind: String, item: Dictionary) -> void:
	if item.is_empty():
		return
	var image: TextureRect = helmet if kind == "helmet" else armor
	image.texture = DataStore.load_texture(item["icon"])
	captions[kind].text = "%s\n%d 级 ▾" % [item["name"], item["level"]]
	launchers[kind].tooltip_text = captions[kind].text + "\n满耐久：" + str(item["max_durability"]) + "\n点击选择装备"
	if kind == "armor":
		launchers[kind].tooltip_text += "\n防护范围：" + ("胸部、腹部" if DamageCalculator.protects_abdomen(item) else "胸部")
	if kind == "helmet":
		selected_helmet = item
		helmet_changed.emit(item)
	else:
		selected_armor = item
		armor_changed.emit(item)
	selection_changed.emit(kind, item)


func _close_when_hidden() -> void:
	if not is_visible_in_tree():
		picker.close_picker()


func _find_by_name(items: Array[Dictionary], wanted: String) -> Dictionary:
	for item in items:
		if item["name"] == wanted:
			return item
	return items[0] if not items.is_empty() else {}


func _read_json(path: String) -> Dictionary:
	return DataStore.read_json(path)
