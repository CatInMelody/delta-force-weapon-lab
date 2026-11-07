extends RefCounted

const DataStore = preload("res://Code/data_store.gd")
## 按项目约定逐发结算；只对肉伤应用部位倍率，甲伤不乘部位倍率。

const EPSILON := 0.000000001
const AMMO_RATIOS_PATH := "res://data/ammo_base_damage_ratios.json"
static var ammo_ratios: Dictionary = {}
static var ammo_special_effects: Dictionary = {}
static var data_generation := -1


static func special_effect_for(bullet: Dictionary) -> Dictionary:
	if data_generation != DataStore.generation:
		ammo_ratios = {}
		ammo_special_effects = {}
		data_generation = DataStore.generation
	if ammo_special_effects.is_empty():
		ammo_special_effects = DataStore.read_json("res://data/ammo_special_effects.json")
	return ammo_special_effects.get(str(bullet.get("item_id", bullet.get("id", ""))), {})


static func effective_body_multipliers(bullet: Dictionary, weapon_multipliers: Dictionary) -> Dictionary:
	var special := special_effect_for(bullet)
	if special.has("fixed_body_multipliers"):
		return special["fixed_body_multipliers"].duplicate()
	var result := weapon_multipliers.duplicate()
	var corrections: Dictionary = special.get("body_multipliers", {})
	for part in corrections:
		result[part] = float(result[part]) * float(corrections[part])
	return result


static func base_damage_ratio_for(bullet: Dictionary) -> float:
	var special := special_effect_for(bullet)
	if special.has("base_damage_ratio"):
		return float(special["base_damage_ratio"])
	if ammo_ratios.is_empty():
		ammo_ratios = DataStore.read_json(AMMO_RATIOS_PATH)
	var level := str(int(bullet.get("level", bullet.get("penetration_level", 0))))
	var exceptions: Dictionary = ammo_ratios["by_caliber_and_level"].get(str(bullet.get("caliber", "")), {})
	return float(exceptions.get(level, ammo_ratios["by_level"].get(level, 1.0)))


static func effective_fire_rate(weapon: Dictionary, bullet: Dictionary) -> float:
	return float(weapon["fire_rate_rpm"]) * float(special_effect_for(bullet).get("fire_rate_multiplier", 1.0))


static func shot_time(index: int, weapon: Dictionary, bullet: Dictionary) -> float:
	var speed := float(special_effect_for(bullet).get("fire_rate_multiplier", 1.0))
	var fast := mini(index, maxi(int(weapon.get("initial_burst_shots", 1)) - 1, 0))
	return fast * 60.0 / (float(weapon.get("initial_fire_rate_rpm", weapon["fire_rate_rpm"])) * speed) + (index - fast) * 60.0 / effective_fire_rate(weapon, bullet)


static func fire_rate_text(weapon: Dictionary, bullet: Dictionary) -> String:
	if weapon.has("initial_fire_rate_rpm"):
		return "%s→%s" % [("%.2f" % float(weapon["initial_fire_rate_rpm"])).rstrip("0").rstrip("."), ("%.2f" % effective_fire_rate(weapon, bullet)).rstrip("0").rstrip(".")]
	return ("%.2f" % effective_fire_rate(weapon, bullet)).rstrip("0").rstrip(".")


static func _effect_shots(weapon: Dictionary, bullet: Dictionary, defense: Dictionary, multiplier: float, arm_shots: int = 0, arm_multiplier: float = 0.4, armored_arms: bool = false) -> int:
	var special := special_effect_for(bullet)
	var health := 100.0
	var durability := float(defense.get("max_durability", 0))
	var profile := projectile_damage_profile(weapon, bullet)
	var factor := factor_for(bullet, defense, bool(defense.get("is_helmet", false)))
	var events: Array[float] = []
	for index in range(4096):
		var time := shot_time(index, weapon, bullet)
		while not events.is_empty() and events[0] <= time + EPSILON:
			events.pop_front()
			health -= float(special.get("dot_tick_damage", 0))
			if health <= EPSILON:
				return maxi(index - arm_shots, 0)
		var is_arm := index < arm_shots
		var protected := not is_arm or armored_arms
		var hit := apply_hit(profile.flesh_damage, profile.armor_damage, int(bullet["level"]), int(defense.get("level", 0)) if protected else 0, durability, factor, arm_multiplier if is_arm else multiplier, health_rate_for(bullet, defense))
		health -= float(hit.flesh_damage)
		durability = float(hit.durability)
		var trigger := int(special.get("proc_hits", 0))
		if trigger > 0 and (index + 1) % trigger == 0:
			health -= float(special.get("proc_true_damage", 0))
			if protected and int(defense.get("level", 0)) > 0:
				durability = maxf(0, durability - float(special.get("proc_armor_damage", 0)) * factor)
		if health <= EPSILON:
			return maxi(index + 1 - arm_shots, 0)
		var ticks := int(special.get("dot_ticks", 0))
		for tick in range(ticks):
			events.append(time + float(special.get("dot_duration", 0)) * (tick + 1) / ticks)
		events.sort()
	return -1


static func health_rate_for(bullet: Dictionary, defense: Dictionary) -> float:
	var level := int(defense.get("level", 0))
	var special := special_effect_for(bullet)
	if special.has("fixed_chest_damage") and level > 0:
		# 直接使用给定的胸部伤害表（例如3级甲27.8），不重建成近似等级减伤率。
		return float(special["fixed_chest_damage"][str(level)]) / float(special["fixed_chest_damage"]["0"])
	var rates: Array = special.get("health_rates", [])
	return float(rates[level - 1]) if level > 0 and level <= rates.size() else -1.0


static func projectile_damage_profile(weapon: Dictionary, bullet: Dictionary) -> Dictionary:
	var special := special_effect_for(bullet)
	if special.has("fixed_chest_damage"):
		return {"flesh_damage": float(special["fixed_chest_damage"]["0"]), "armor_damage": float(special["fixed_armor_damage"])}
	return {"flesh_damage": float(weapon["flesh_damage"]) * base_damage_ratio_for(bullet), "armor_damage": float(weapon["armor_damage"])}


static func protects_abdomen(armor: Dictionary) -> bool:
	var level := int(armor.get("level", 0))
	var item_id := str(armor.get("item_id", ""))
	if level <= 2:
		return false
	if level == 3:
		return item_id in ["11050003003", "11050003004"] # TG-H、射手
	if level == 4:
		return item_id not in ["11050004001", "11050004007"] # 武士、HMP
	return true


static func penetration_ratio(bullet_level: int, defense_level: int) -> float:
	var difference := bullet_level - defense_level
	if difference >= 2:
		return 1.0
	if difference == 1:
		return 0.75
	if difference == 0:
		return 0.5
	return 0.0


static func apply_hit(flesh: float, armor_damage: float, bullet_level: int, defense_level: int, durability: float, factor: float, multiplier: float, health_rate: float = -1.0) -> Dictionary:
	var flesh_damage := maxf(flesh * multiplier, 0.0)
	var remaining := maxf(durability, 0.0)
	if defense_level <= 0 or remaining <= 0.0:
		return {"flesh_damage": flesh_damage, "durability": remaining}
	var actual_armor_damage := maxf(armor_damage * factor, 0.0)
	# 零甲伤且仍有甲时，整发仍受防具等级减伤，避免除以零。
	var overflow_fraction := 0.0
	if actual_armor_damage > 0.0:
		# 图中约定：剩余耐久 >= 甲伤时，先按甲伤截断剩余耐久。
		overflow_fraction = (actual_armor_damage - minf(remaining, actual_armor_damage)) / actual_armor_damage
	var penetration := health_rate if health_rate >= 0.0 else penetration_ratio(bullet_level, defense_level)
	var armor_reduction := 1.0 - penetration
	return {
		# 肉伤 × [(1 - 护甲减伤率) + 护甲减伤率 × 破甲溢出比例]。
		"flesh_damage": flesh_damage * (1.0 - armor_reduction + armor_reduction * overflow_fraction),
		"durability": maxf(remaining - actual_armor_damage, 0.0),
	}


static func shots_to_kill(flesh: float, armor_damage: float, bullet_level: int, defense_level: int, durability: float, factor: float, multiplier: float, health: float = 100.0, projectiles: int = 1, health_rate: float = -1.0) -> int:
	var shots := 0
	while health > EPSILON:
		shots += 1
		for projectile in range(maxi(projectiles, 1)):
			var hit := apply_hit(flesh, armor_damage, bullet_level, defense_level, durability, factor, multiplier, health_rate)
			if float(hit["flesh_damage"]) <= 0.0 and float(hit["durability"]) >= durability:
				return -1 # 没有肉伤且无法破甲，这个方案无法击杀。
			health -= float(hit["flesh_damage"])
			durability = float(hit["durability"])
			if health <= EPSILON:
				break
	return shots


static func factor_for(bullet: Dictionary, defense: Dictionary, is_helmet: bool = false) -> float:
	var level := int(defense.get("level", 0))
	if level <= 0:
		return 0.0
	if special_effect_for(bullet).has("fixed_armor_damage"):
		return 1.0 # 固定甲伤已经是最终耐久损伤，不再乘枪械甲伤或旧弹药系数。
	var key := "helmet_damage_factors" if is_helmet else "armor_damage_factors"
	return float(bullet[key][level - 1])


static func chest_shots_after_arms(arm_shots: int, flesh: float, armor_damage: float, bullet_level: int, defense_level: int, durability: float, factor: float, chest_multiplier: float, limbs_multiplier: float, armored_limbs: bool = false, projectiles: int = 1, health_rate: float = -1.0) -> int:
	var health := 100.0
	for index in range(arm_shots):
		for projectile in range(maxi(projectiles, 1)):
			if health <= EPSILON:
				return 0
			var hit := apply_hit(flesh, armor_damage, bullet_level, defense_level if armored_limbs else 0, durability, factor, limbs_multiplier, health_rate)
			health -= float(hit["flesh_damage"])
			durability = float(hit["durability"])
	return shots_to_kill(flesh, armor_damage, bullet_level, defense_level, durability, factor, chest_multiplier, health, projectiles, health_rate)


static func calculate(weapon: Dictionary, bullet: Dictionary, helmet: Dictionary, armor: Dictionary, multipliers: Dictionary, armored_limbs: bool = false) -> Dictionary:
	multipliers = effective_body_multipliers(bullet, multipliers)
	var arms_multiplier := float(weapon.get("arms_multiplier", multipliers["limbs"]))
	if weapon.has("arms_multiplier"):
		arms_multiplier *= float(special_effect_for(bullet).get("body_multipliers", {}).get("limbs", 1.0))
	var special := special_effect_for(bullet)
	if special.has("dot_ticks") or special.has("proc_hits"):
		var unprotected := {"level": 0, "max_durability": 0}
		var head := helmet.duplicate()
		head["is_helmet"] = true
		var mixed_effects: Array[int] = []
		for count in range(1, 5):
			mixed_effects.append(_effect_shots(weapon, bullet, armor, multipliers.chest, count, arms_multiplier, armored_limbs))
		return {"head": _effect_shots(weapon, bullet, head, multipliers.head), "chest": _effect_shots(weapon, bullet, armor, multipliers.chest), "abdomen": _effect_shots(weapon, bullet, armor if protects_abdomen(armor) else unprotected, multipliers.abdomen), "arms": _effect_shots(weapon, bullet, armor if armored_limbs else unprotected, arms_multiplier), "arms_then_chest": mixed_effects}
	var profile := projectile_damage_profile(weapon, bullet)
	var flesh := float(profile["flesh_damage"])
	var armor_damage := float(profile["armor_damage"])
	var bullet_level := int(bullet["level"])
	var armor_level := int(armor["level"])
	var armor_durability := float(armor["max_durability"])
	var factor := factor_for(bullet, armor)
	var projectiles := int(special_effect_for(bullet).get("projectiles_per_round", 1))
	var body_health_rate := health_rate_for(bullet, armor)
	var helmet_health_rate := health_rate_for(bullet, helmet)
	var mixed: Array[int] = []
	for arms in range(1, 5):
		mixed.append(chest_shots_after_arms(arms, flesh, armor_damage, bullet_level, armor_level, armor_durability, factor, multipliers["chest"], arms_multiplier, armored_limbs, projectiles, body_health_rate))
	return {
		"head": shots_to_kill(flesh, armor_damage, bullet_level, int(helmet["level"]), float(helmet["max_durability"]), factor_for(bullet, helmet, true), multipliers["head"], 100.0, projectiles, helmet_health_rate),
		"chest": shots_to_kill(flesh, armor_damage, bullet_level, armor_level, armor_durability, factor, multipliers["chest"], 100.0, projectiles, body_health_rate),
		"abdomen": shots_to_kill(flesh, armor_damage, bullet_level, armor_level if protects_abdomen(armor) else 0, armor_durability, factor, multipliers["abdomen"], 100.0, projectiles, body_health_rate),
		"arms": shots_to_kill(flesh, armor_damage, bullet_level, armor_level if armored_limbs else 0, armor_durability, factor, arms_multiplier, 100.0, projectiles, body_health_rate),
		"arms_then_chest": mixed,
	}
