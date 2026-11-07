extends "res://tests/choose_smoke.gd"

const Multipliers = preload("res://Code/weapon_multipliers.gd")
const Calculator = preload("res://Code/damage_calculator.gd")
const EXPECTED := {
	"MK4": {"limbs": 0.5, "abdomen": 1.0, "chest": 1.0, "head": 2.0},
	"汤姆逊": {"abdomen": 1.0, "limbs": 0.35}, "SMG-45": {"limbs": 0.45},
	"QJB201": {"head": 2.1}, "M250": {"head": 1.82, "abdomen": 0.7},
	"MCX-LT": {"limbs": 0.35}, "K437": {"limbs": 0.3}, "腾龙": {"head": 2.1},
	"SCAR-H": {"limbs": 0.5}, "AK-12": {"limbs": 0.45}, "M7": {"abdomen": 1.0, "limbs": 0.35},
	"AUG": {"head": 2.0, "chest": 1.1}, "ASh-12": {"head": 1.6, "limbs": 0.45}, "QBZ95-1": {"head": 2.3},
	"M700": {"head": 2.5}, "SV-98": {"head": 2.5}, "R93": {"head": 2.5},
	"Marlin杠杆步枪": {"limbs": 0.45}, "PSG-1": {"head": 2.1},
	"SR-25": {"head": 2.1, "abdomen": 1.0, "limbs": 0.5}, "SVD": {"head": 2.3},
	"VSS": {"abdomen": 1.0, "limbs": 0.5}, "Mini-14": {"limbs": 0.5},
}


func _run() -> void:
	root.size = Vector2i(1152, 648)
	scene = load("res://Scene/main.tscn").instantiate()
	root.add_child(scene)
	choose = scene.get_node("Information/Chosse")
	var info: Control = scene.get_node("Information/GunInformation")
	var btk: Control = scene.get_node("Information/BTK")
	var compare: Control = scene.get_node("Compare")
	await _frames()
	var matched := 0
	for weapon in choose.weapons:
		var expected: Dictionary = Multipliers.DEFAULTS.duplicate()
		if weapon.has("base_weapon_id"):
			var base: Dictionary = {}
			for candidate in choose.weapons:
				if candidate.weapon_id == weapon.base_weapon_id:
					base = candidate
					break
			expected.merge(EXPECTED.get(base.name, {}), true)
			expected.merge(weapon.body_multipliers, true)
		if EXPECTED.has(weapon.name):
			matched += 1
			expected.merge(EXPECTED[weapon.name], true)
		_check(info.get_multipliers(weapon) == expected, "Weapon mapping and fallback: " + weapon.name)
		choose._select_weapon(weapon)
		for index in range(4):
			var key: String = ["head", "chest", "abdomen", "limbs"][index]
			var label: Label = info.magnification.get_child(index)
			var color: Color = info.HIGH_COLOR if expected[key] > Multipliers.DEFAULTS[key] else (info.LOW_COLOR if expected[key] < Multipliers.DEFAULTS[key] else info.magnification.get_theme_color("font_color", "Label"))
			_check(label.get_theme_color("font_color") == color, "Multiplier color: " + weapon.name + "/" + key)
		var scaled_flesh := float(weapon.flesh_damage) * Calculator.base_damage_ratio_for(choose.selected_bullet)
		var actual: Dictionary = Calculator.calculate(weapon, choose.selected_bullet, {"level": 0, "max_durability": 0}, {"level": 0, "max_durability": 0}, expected)
		for key in ["head", "chest", "abdomen", "limbs"]:
			var result_key: String = "arms" if key == "limbs" else key
			_check(actual[result_key] == ceili(100.0 / (scaled_flesh * expected[key])), "Unprotected body damage: " + weapon.name + "/" + key)
		for count in range(1, 5):
			var hp: float = maxf(0, 100 - count * scaled_flesh * expected.limbs)
			_check(actual.arms_then_chest[count - 1] == ceili(hp / (scaled_flesh * expected.chest)), "Mixed damage: " + weapon.name)
		compare._select_weapon(0, weapon)
		var result: Dictionary = Calculator.calculate(weapon, compare.sides[0].bullet, compare.helmet, compare.armor, expected)
		for key in ["head", "chest", "abdomen", "arms"]:
			_check(compare.sides[0].metrics[key] == result[key], "Compare uses its own weapon: " + weapon.name)
	_check(matched == 23, "All 23 named weapons matched")
	choose._select_weapon(choose._find_by_name(choose.weapons, "M4A1"))
	await create_timer(0.35).timeout
	choose._select_weapon(choose._find_by_name(choose.weapons, "M250"))
	_check(info.magnification.text.begins_with("头部倍率：1.82"), "1.82 shown without rounding to 1.8")
	_check(info.multiplier_refresh.active.size() == 2, "Only two changed multipliers sweep")
	await _capture("multipliers-m250")
	await create_timer(0.35).timeout
	choose._select_weapon(choose._find_by_name(choose.weapons, "M7"))
	_check(btk.results.arms == 8 and btk.results.abdomen == btk.results.chest, "M7 limbs and abdomen use specific values")
	await _capture("multipliers-m7")
	await create_timer(0.35).timeout
	choose._select_weapon(choose._find_by_name(choose.weapons, "MCX-LT"))
	_check(info.multiplier_refresh.active.size() == 1 and info.multiplier_refresh.active[0].label.name == "Abdomen", "Equal 0.35 limbs stay static")
	var animation: Tween = info.multiplier_refresh.active[0].tween
	choose._select_weapon(choose.selected_weapon)
	_check(info.multiplier_refresh.active.size() == 1 and info.multiplier_refresh.active[0].tween == animation, "Unchanged values do not restart sweep")
	await create_timer(0.35).timeout
	choose._select_weapon(choose._find_by_name(choose.weapons, "M4A1"))
	_check(info.magnification.get_node("Limbs").get_theme_color("font_color") == info.magnification.get_theme_color("font_color", "Label"), "Switching to default resets green color")
	compare._select_weapon(0, choose._find_by_name(choose.weapons, "M7"))
	compare._select_weapon(1, choose._find_by_name(choose.weapons, "M4A1"))
	var before: Dictionary = compare.sides[0].metrics.duplicate()
	choose._select_weapon(choose._find_by_name(choose.weapons, "M700"))
	_check(compare.sides[0].metrics == before and compare.sides[0].metrics.arms == 8, "Information selection cannot leak multipliers into comparison")
	print("WEAPON_MULTIPLIERS_SMOKE: %s; specified=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", matched, failures.size()])
	quit(0 if failures.is_empty() else 1)
