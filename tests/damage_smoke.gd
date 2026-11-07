extends SceneTree

const Calculator = preload("res://Code/damage_calculator.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _expect_hit(bullet_level: int, defense_level: int, durability: float, factor: float, multiplier: float, expected_flesh: float, expected_durability: float) -> void:
	var result := Calculator.apply_hit(40.0, 20.0, bullet_level, defense_level, durability, factor, multiplier)
	_check(absf(result.flesh_damage - expected_flesh) < 0.000001, "Hit damage: %s" % str(result))
	_check(absf(result.durability - expected_durability) < 0.000001, "Remaining durability: %s" % str(result))


func _run() -> void:
	var ratios_by_caliber := {
		"9x19mm": [1.4, 1.1, 1.1, 1.0, 1.0, 1.0, 1.0, 1.0],
		".45 ACP": [1.35, 1.1, 1.1, 1.0, 1.0, 0.85, 1.0, 1.0],
		"5.7x28mm": [1.4, 1.2, 1.2, 1.0, 1.0, 1.0, 1.0, 1.0],
	}
	for caliber in ratios_by_caliber:
		for level in range(8):
			var ratio: float = ratios_by_caliber[caliber][level]
			var bullet := {"caliber": caliber, "level": level}
			_check(is_equal_approx(Calculator.base_damage_ratio_for(bullet), ratio), "Base damage ratio: %s level %d" % [caliber, level])
			var result := Calculator.calculate({"flesh_damage": 30, "armor_damage": 20}, bullet, {"level": 0, "max_durability": 0}, {"level": 0, "max_durability": 0}, {"head": 1.9, "chest": 1.0, "abdomen": 0.9, "limbs": 0.4})
			for key in ["head", "chest", "abdomen", "arms"]:
				var multiplier: float = {"head": 1.9, "chest": 1.0, "abdomen": 0.9, "arms": 0.4}[key]
				_check(result[key] == ceili((100.0 - 0.000000001) / (30 * ratio * multiplier)), "Ammo ratio combines with body multiplier: " + key)
			for count in range(1, 5):
				var hp := maxf(100 - count * 30 * ratio * 0.4, 0)
				_check(result.arms_then_chest[count - 1] == ceili(maxf(hp - 0.000000001, 0) / (30 * ratio)), "Ammo ratio applies to arm and chest mixed hits")
	var reduced_bullet := {"caliber": ".45 ACP", "level": 5, "armor_damage_factors": [1, 1, 1, 1, 1, 1], "helmet_damage_factors": [1, 1, 1, 1, 1, 1]}
	var broken_armor := {"level": 5, "max_durability": 10}
	var reduced_result := Calculator.calculate({"flesh_damage": 40, "armor_damage": 20}, reduced_bullet, broken_armor, broken_armor, {"head": 1.0, "chest": 1.0, "abdomen": 1.0, "limbs": 0.4})
	_check(reduced_result.head == 4 and reduced_result.chest == 4 and reduced_result.abdomen == 4, "0.85 scales protected and overflow damage without scaling armor damage")
	# 完整护甲的四个弹甲等级档位，以及恰好破甲和本发破甲溢出。
	_expect_hit(6, 4, 100, 1, 1, 40, 80)
	_expect_hit(5, 4, 100, 1, 1, 30, 80)
	_expect_hit(4, 4, 100, 1, 1, 20, 80)
	_expect_hit(3, 4, 100, 1, 1, 0, 80)
	_expect_hit(4, 4, 20, 1, 1, 20, 0)
	_expect_hit(4, 4, 10, 1, 1, 30, 0)
	_expect_hit(3, 4, 10, 1, 1, 20, 0)
	_expect_hit(4, 4, 10, 1, 1.9, 57, 0)
	_expect_hit(3, 4, 0, 1, 1, 40, 0)
	# 甲伤不乘头部倍率，零甲伤不发生除零。
	_expect_hit(4, 4, 25, 0.5, 1.9, 38, 15)
	_expect_hit(3, 4, 25, 0, 1, 0, 25)
	_check(Calculator.shots_to_kill(40, 20, 3, 4, 25, 0, 1) == -1, "Impossible kill terminates")
	_check(Calculator.shots_to_kill(40, 20, 4, 4, 25, 0, 1) == 5, "Zero armor damage can still kill through penetration")
	_check(Calculator.shots_to_kill(40, 20, 4, 4, 50, 1, 1) == 4, "Durability carried between consecutive shots")
	_check(Calculator.shots_to_kill(10, 20, 4, 0, 0, 1, 1) == 10, "Exact 100 HP kill")
	_check(Calculator.shots_to_kill(25, 20, 4, 0, 0, 1, 0.4) == 10, "Limb multiplier does not add an extra shot")
	var expected_mixed := [4, 3, 3, 2]
	for index in range(4):
		_check(Calculator.chest_shots_after_arms(index + 1, 40, 20, 4, 4, 50, 1, 1, 0.4) == expected_mixed[index], "Only additional chest hits counted")
	_check(Calculator.chest_shots_after_arms(7, 40, 20, 4, 4, 50, 1, 1, 0.4) == 0, "Arms already killed: zero chest hits")
	_check(Calculator.chest_shots_after_arms(1, 100, 100, 4, 5, 100, 1, 1, 0.4) == 2, "Unprotected arms do not consume armor")
	_check(Calculator.chest_shots_after_arms(1, 100, 100, 4, 5, 100, 1, 1, 0.4, true) == 1, "Protected arms share chest durability")
	# 用户逐件指定的腹部覆盖范围；所有 26 件护甲都要核对。
	var defenses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_stats.json"))
	var abdomen_ids := ["11050003003", "11050003004", "11050004002", "11050004003", "11050004004"]
	for armor in defenses.armors.values():
		var expected: bool = int(armor.level) >= 5 or armor.item_id in abdomen_ids
		_check(Calculator.protects_abdomen(armor) == expected, "Abdomen coverage: " + armor.name)
	var scene: Control = load("res://Scene/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var choose: Control = scene.get_node("Information/Chosse")
	var btk: Control = scene.get_node("Information/BTK")
	var default_results: Dictionary = btk.results.duplicate(true)
	_check(default_results == {"head": 2, "chest": 6, "abdomen": 6, "arms": 8, "arms_then_chest": [6, 6, 5, 5]}, "M7 FMJ versus default full defenses: " + str(default_results))
	_check(btk.single.text == "全头：2 枪\n全胸：6 枪\n全腹：6 枪\n全手：8 枪", "Single label populated")
	_check(btk.complex.text == "马一枪手：6 枪\n马二枪手：6 枪\n马三枪手：5 枪\n马四枪手：5 枪", "Mixed label populated")
	choose._select_bullet(choose.get_bullet_choices()[-1])
	_check(btk.results.chest == 4 and btk.results.arms_then_chest == [4, 3, 3, 2], "Changing bullet recalculates BTK")
	choose._select_bullet(choose._find_by_name(choose.get_bullet_choices(), "FMJ"))
	choose._select_defense("helmet", choose._find_by_name(choose.helmets, "H70精英头盔"))
	_check(btk.results.head == 4 and btk.results.chest == 6, "Helmet durability independent of body armor")
	choose._select_defense("armor", choose._find_by_name(choose.armors, "摩托马甲"))
	_check(btk.results.chest == 3 and btk.results.abdomen == 3, "Armor selection recalculates and exposes abdomen")
	choose._select_defense("armor", choose._find_by_name(choose.armors, "重型突击背心"))
	choose._select_weapon(choose._find_by_name(choose.weapons, "AWM"))
	_check(btk.results.chest == 1 and btk.results.arms == 3 and btk.results.arms_then_chest == [1, 1, 0, 0], "Weapon change and already-dead mixed scenarios")
	# 同等级弹种保持独立 ID，实际系数读取用户指定的 raw 字段。
	choose._select_weapon(choose._find_by_name(choose.weapons, "M4A1"))
	var tier_three: Array[Dictionary] = []
	for ammo in choose.get_bullet_choices():
		if ammo.level == 3:
			tier_three.append(ammo)
	_check(tier_three.size() == 1 and tier_three[0].name == "M855", "Only ordinary M855 remains at level three")
	_check(Calculator.factor_for(tier_three[0], {"level": 5}) == 0.5, "Raw factor used without adding independent multiplier")
	# 不同部位读取各自的系数数组，忽略未约定的独立甲伤倍率。
	var synthetic := {"armor_damage_factors": [0.5], "helmet_damage_factors": [0.7], "ammo_armor_damage_multiplier": 9}
	_check(Calculator.factor_for(synthetic, {"level": 1}) == 0.5, "Body factor array")
	_check(Calculator.factor_for(synthetic, {"level": 1}, true) == 0.7, "Helmet factor array")
	_check(choose._find_by_name(choose.armors, "重型突击背心").max_durability == 125, "Simulations leave equipment data unchanged")
	print("DAMAGE_SMOKE: %s; checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
