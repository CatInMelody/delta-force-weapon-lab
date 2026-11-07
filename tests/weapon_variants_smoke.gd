extends "res://tests/choose_smoke.gd"

const Calculator = preload("res://Code/damage_calculator.gd")
const SAVE_PATH := "user://weapon_variants_smoke.json"
const CASES := {
	"提风M7": ["M7", {"flesh_damage": 39, "armor_damage": 42, "range_m": 65}, {}],
	"鏖战MK47": ["MK47", {"range_m": 25, "flesh_damage": 46, "armor_damage": 47}, {}],
	"余烬MK47": ["MK47", {"range_m": 35, "flesh_damage": 45, "armor_damage": 46}, {}],
	"长枪管K437": ["K437", {"range_m": 53, "armor_damage": 35}, {}],
	"高导腾龙": ["腾龙", {"fire_rate_rpm": 759}, {}],
	"隔热MCX": ["MCX-LT", {"fire_rate_rpm": 870, "flesh_damage": 36}, {}],
	"先进汤姆逊": ["汤姆逊", {"flesh_damage": 37, "armor_damage": 37}, {}],
	"深空MK4": ["MK4", {"flesh_damage": 34, "armor_damage": 30, "fire_rate_rpm": 872, "range_m": 25}, {"head": 1.9, "chest": 1.0, "abdomen": 0.9, "limbs": 0.4}],
	"击剑MK4": ["MK4", {"flesh_damage": 34, "armor_damage": 35, "fire_rate_rpm": 793, "range_m": 26}, {"head": 2.0, "chest": 1.0, "abdomen": 1.0, "limbs": 0.5}],
	"高导QCQ": ["QCQ171", {"fire_rate_rpm": 848}, {}],
	"高导QJB": ["QJB201", {"fire_rate_rpm": 873}, {}],
	"长枪管M250": ["M250", {"range_m": 52}, {"abdomen": 0.9}],
	"蜂鸟Marlin": ["Marlin杠杆步枪", {"fire_rate_rpm": 200, "flesh_damage": 75, "armor_damage": 59}, {"head": 1.5}],
	"犀牛Marlin": ["Marlin杠杆步枪", {"fire_rate_rpm": 75, "flesh_damage": 100, "armor_damage": 25, "range_m": 20}, {"head": 1.41, "abdomen": 0.67, "limbs": 0.34}],
	"高导PSG": ["PSG-1", {"fire_rate_rpm": 353}, {}],
	"高导SR9": ["SR9", {"fire_rate_rpm": 307}, {}],
	"旋风M700": ["M700", {"fire_rate_rpm": 420}, {"limbs": 0.25, "abdomen": 0.5}],
	"旋风一体消音M700": ["M700", {"fire_rate_rpm": 494}, {"limbs": 0.25, "abdomen": 0.5}],
}


func _run() -> void:
	root.size = Vector2i(1152, 648)
	_check(not FileAccess.file_exists(SAVE_PATH), "Isolated save initially absent")
	if FileAccess.file_exists(SAVE_PATH):
		quit(1)
		return
	scene = load("res://Scene/main.tscn").instantiate()
	scene.get_node("Information/BuildCode").save_path = SAVE_PATH
	root.add_child(scene)
	choose = scene.get_node("Information/Chosse")
	await _frames()
	var info: Control = scene.get_node("Information/GunInformation")
	var btk: Control = scene.get_node("Information/BTK")
	var compare: Control = scene.get_node("Compare")
	var rank_panel: Control = scene.get_node("Rank")
	var build: Control = scene.get_node("Information/BuildCode")
	var ids := {}
	for weapon in choose.weapons:
		_check(not ids.has(weapon.weapon_id), "Unique stable ID: " + weapon.name)
		ids[weapon.weapon_id] = true
	for name in CASES:
		var variant: Dictionary = choose._find_by_name(choose.weapons, name)
		var base: Dictionary = choose._find_by_name(choose.weapons, CASES[name][0])
		_check(not variant.is_empty(), "Selectable variant: " + name)
		if variant.is_empty():
			continue
		_check(variant.base_weapon_id == base.weapon_id and variant.weapon_id != base.weapon_id, "Independent variant identity: " + name)
		for key in ["flesh_damage", "armor_damage", "range_m", "fire_rate_rpm", "icon", "category", "ammo_type_id", "caliber"]:
			_check(variant[key] == CASES[name][1].get(key, base[key]), "Override or inherited property: " + name + "/" + key)
		var expected: Dictionary = info.get_multipliers(base)
		expected.merge(CASES[name][2], true)
		_check(info.get_multipliers(variant) == expected, "Inherited and explicit multipliers: " + name)
		choose._select_weapon(variant)
		_check(not choose.get_bullet_choices().is_empty(), "Inherited ammo selectable: " + name)
		_check(btk.results == Calculator.calculate(variant, choose.selected_bullet, choose.selected_helmet, choose.selected_armor, expected), "Information BTK uses variant: " + name)
		compare._select_weapon(0, variant)
		_check(compare.sides[0].metrics.fire_rate == variant.fire_rate_rpm, "Comparison rate uses variant: " + name)
		var found := false
		for row in rank_panel.flesh_ranking:
			if row.weapon_id == variant.weapon_id:
				found = true
				_check(is_equal_approx(row.flesh_dps, float(variant.flesh_damage) * float(variant.fire_rate_rpm) / 60), "Rank DPS uses variant: " + name)
		_check(found, "Rank contains variant: " + name)
		for field in [build.text_a, build.text_b, build.text_c]:
			field.text = name + "/" + str(field.name)
			field.text_changed.emit(field.text)
		choose._select_weapon(base)
		_check(build.text_a.text.is_empty() and build.text_b.text.is_empty() and build.text_c.text.is_empty(), "Variant plans do not overwrite original: " + name)
	_check(info.get_multipliers(choose._find_by_name(choose.weapons, "MK4")) == {"head": 2.0, "chest": 1.0, "abdomen": 1.0, "limbs": 0.5}, "Original MK4 updated")
	scene.queue_free()
	await _frames()
	scene = load("res://Scene/main.tscn").instantiate()
	scene.get_node("Information/BuildCode").save_path = SAVE_PATH
	root.add_child(scene)
	choose = scene.get_node("Information/Chosse")
	build = scene.get_node("Information/BuildCode")
	await _frames()
	for name in CASES:
		choose._select_weapon(choose._find_by_name(choose.weapons, name))
		for field in [build.text_a, build.text_b, build.text_c]:
			_check(field.text == name + "/" + str(field.name), "Variant plan persists after restart: " + name)
	choose._select_weapon(choose._find_by_name(choose.weapons, "提风M7"))
	await _capture("variants-m7")
	scene.queue_free()
	await _frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("WEAPON_VARIANTS_SMOKE: %s; variants=18 failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
