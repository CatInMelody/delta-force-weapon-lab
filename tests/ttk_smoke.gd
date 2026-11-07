extends "res://tests/choose_smoke.gd"


func _run() -> void:
	root.size = Vector2i(1152, 648)
	scene = load("res://Scene/main.tscn").instantiate()
	root.add_child(scene)
	choose = scene.get_node("Information/Chosse")
	var info: Control = scene.get_node("Information/GunInformation")
	await _frames()
	for weapon in choose.weapons:
		var choices: Array[Dictionary] = choose.get_bullet_choices_for_weapon(weapon)
		var highest := 0
		var has_five := false
		for ammo in choices:
			highest = maxi(highest, int(ammo.level))
			has_five = has_five or ammo.level == 5
		var summary: Dictionary = info.ttk_summary_for(weapon)
		_check(summary.bullet.level == (5 if has_five else highest), "TTK uses five or highest grade: " + weapon.name)
		_check(not choose.removed_ammo_ids.has(summary.bullet.id), "TTK does not use removed ammo")
		_check(is_equal_approx(summary.seconds, (summary.shots - 1) * 60.0 / summary.fire_rate), "TTK starts at first hit")
	choose._select_weapon(choose._find_by_name(choose.weapons, "MDR"))
	var summary: Dictionary = info.ttk_summary_for(choose.selected_weapon)
	_check(summary.shots == 4 and summary.fire_rate == 650 and info.ttk_label.text == "TTK：0.28 秒", "User MDR example: three shot intervals at 650 RPM")
	var before: String = info.ttk_label.text
	choose._select_bullet(choose.get_bullet_choices()[0])
	choose._select_defense("armor", choose._find_by_name(choose.armors, "摩托马甲"))
	_check(info.ttk_label.text == before, "Chosen equipment and ammo do not alter standard TTK")
	await _capture("ttk-mdr")
	_check(root.get_visible_rect().encloses(info.get_global_rect()), "Extra TTK row fits standard viewport")
	choose._select_weapon(choose._find_by_name(choose.weapons, "AWM"))
	_check(info.ttk_summary_for(choose.selected_weapon).bullet.level == 7 and info.ttk_label.text == "TTK：0.00 秒", "Highest-grade one-shot kill is zero time")
	choose._select_weapon(choose._find_by_name(choose.weapons, "M82"))
	_check(info.ttk_summary_for(choose.selected_weapon).bullet.level == 7, "No five uses maximum seven, rather than compare's default six")
	choose._select_weapon(choose._find_by_name(choose.weapons, "MP7"))
	before = info.ttk_label.text
	choose._select_bullet(choose._find_by_name(choose.get_bullet_choices(), "CT"))
	_check(info.ttk_label.text == before and info.ttk_summary_for(choose.selected_weapon).fire_rate == 950, "TTK uses reference ammo rate, independent of selected CT slowdown")
	print("TTK_SMOKE: %s; weapons=73 failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
