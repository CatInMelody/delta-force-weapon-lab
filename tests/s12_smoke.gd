extends SceneTree
const Store = preload("res://Code/data_store.gd")
const Calc = preload("res://Code/damage_calculator.gd")
var failures: Array[String] = []
var scene: Control
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, detail: String) -> void:
	if not value:
		failures.append(detail)
		push_error(detail)
func snap(filename: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + filename + ".png")
func _run() -> void:
	Store.storage_root = "user://s12_smoke_isolated"
	scene = load("res://Scene/main.tscn").instantiate()
	scene.get_node("Information/BuildCode").save_path = "user://s12_smoke_plans.json"
	root.add_child(scene)
	await process_frame
	await process_frame
	var choose: Control = scene.get_node("Information/Chosse")
	var info: Control = scene.get_node("Information/GunInformation")
	check(choose.weapons.size() == 74, "74 guns including AN94")
	var an: Dictionary = choose._find_by_name(choose.weapons, "AN94")
	check(an.flesh_damage == 34 and an.armor_damage == 42 and an.range_m == 35, "AN94 base stats")
	check(is_equal_approx(Calc.shot_time(1, an, {}), 1.0/30) and is_equal_approx(Calc.shot_time(2, an, {}), 1.0/30+0.1), "AN94 first gap 1800, later gap 600")
	choose._select_weapon(an)
	check(is_equal_approx(info.ttk_summary_for(an).seconds, 0.26), "AN94 explicit reference TTK")
	check(info.damage.text.contains("1800→600"), "AN94 two-stage rate displayed")
	var ar: Dictionary = choose._find_by_name(choose.weapons, "AR57")
	choose._select_weapon(ar)
	check(ar.armor_damage == 32, "AR57 armor damage buff")
	check(scene.get_node("Information/BTK").special_description.text.contains("手臂伤害倍率0.5"), "AR57 gun note in ammo explanation")
	var naked := {"level": 0, "max_durability": 0}
	var multipliers := {"head": 1.9, "chest": 1.0, "abdomen": 0.9, "limbs": 0.4}
	var ar_bullet: Dictionary = choose.get_bullet_choices()[0]
	check(Calc.calculate(ar, ar_bullet, naked, naked, multipliers).arms == ceili(100.0/(30*0.5*Calc.base_damage_ratio_for(ar_bullet))), "AR57 BTK uses arms .5 independently of legs .4")
	check(choose._find_by_name(choose.weapons,"K416").flesh_damage == 32, "K416 flesh damage buff")
	check(info.get_multipliers(choose._find_by_name(choose.weapons,"隔热MCX")).abdomen == 1.0, "Insulated MCX abdomen multiplier")
	var effects := Store.read_json("res://data/ammo_special_effects.json")
	var ammo: Dictionary = Store.read_json("res://data/ammo_armor_factors.json").ammo
	for id in ["s12:cinder", "s12:tiv", "s12:ttv", "s12:spall"]:
		check(ammo.has(id) and effects.has(id), "New ammo linked: " + id)
		check(Store.load_texture(ammo[id].godot_icon_path) != null, "New ammo icon loads")
	var weapon := {"flesh_damage":24.0,"armor_damage":0.0,"fire_rate_rpm":60.0}
	var cinder: Dictionary = ammo["s12:cinder"].duplicate()
	cinder.level=4
	check(Calc.calculate(weapon,cinder,naked,naked,multipliers).chest == 4, "CINDER real-time independent burn ticks")
	weapon.fire_rate_rpm=1500.0
	check(Calc.calculate(weapon,cinder,naked,naked,multipliers).chest == 5, "CINDER does not front-load delayed damage")
	var tiv: Dictionary = ammo["s12:tiv"].duplicate()
	tiv.level=4
	check(Calc.base_damage_ratio_for(tiv)==0.95, "TIV base damage 95 percent")
	check(Calc.calculate(weapon,tiv,naked,naked,multipliers).chest == 4, "Fourth hit true damage triggers")
	var heavy := {"level":6,"max_durability":10000.0}
	check(Calc.calculate(weapon,tiv,naked,heavy,multipliers).chest == 36, "True damage repeats each fourth hit through armor")
	heavy={"level":5,"max_durability":24.0}
	weapon.flesh_damage=30.0
	check(Calc.calculate(weapon,tiv,naked,heavy,multipliers).chest == 11, "Proc armor damage breaks armor using ordinary loss factor")
	var base := {"level":4,"penetration_level":4,"caliber":"5.56x45mm","armor_damage_factors":[1,1,1,1,1,0.6],"helmet_damage_factors":[1,1,1,1,1,0.6]}
	var spall: Dictionary = ammo["s12:spall"].duplicate()
	spall.level=4
	check(Calc.calculate(weapon,spall,naked,heavy,multipliers).chest == Calc.calculate(weapon,base,naked,heavy,multipliers).chest, "SPALL repair note has no fabricated combat damage")
	check(Store.metadata().season=="S12", "Season S12")
	check(scene.get_node("Rank").flesh_ranking.size()==74, "Ranking includes AN94")
	if "--screenshots" in OS.get_cmdline_user_args():
		choose._select_weapon(an)
		await snap("s12-an94")
		choose._select_weapon(ar)
		await snap("s12-ar57")
		for gun in choose.weapons:
			if gun.ammo_type_id == ammo["s12:tiv"].ammo_type_id:
				choose._select_weapon(gun)
				break
		for bullet in choose.get_bullet_choices():
			if bullet.name == "TIV":
				choose._select_bullet(bullet)
				break
		await snap("s12-tiv")
	print("S12_SMOKE: ", "PASS" if failures.is_empty() else "FAIL", "; failures=",failures.size())
	scene.free()
	quit(0 if failures.is_empty() else 1)
