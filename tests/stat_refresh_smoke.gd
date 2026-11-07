extends "res://tests/choose_smoke.gd"


func _capture_at(effects: Array, prefix: String) -> void:
	if not captures:
		return
	for effect in effects:
		for entry in effect.active:
			entry.tween.pause()
	for index in range(11):
		for effect in effects:
			effect._set_progress(float(index) / 10.0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/%s-%02d.png" % [prefix, index])
	for effect in effects:
		effect._clear()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	scene = load("res://Scene/main.tscn").instantiate()
	root.add_child(scene)
	choose = scene.get_node("Information/Chosse")
	var info: Control = scene.get_node("Information/GunInformation")
	var btk: Control = scene.get_node("Information/BTK")
	var compare: Control = scene.get_node("Compare")
	await _frames()
	_check(not info.refresh.running and not btk.refresh.running, "Initial display has no sweep")
	choose._select_defense("helmet", choose._find_by_name(choose.helmets, "H70精英头盔"))
	_check(btk.refresh.active.size() == 1 and btk.refresh.active[0].label.name == "Head", "Only changed head BTK animates")
	var unchanged_tween: Tween = btk.refresh.active[0].tween
	choose._select_defense("helmet", choose._find_by_name(choose.helmets, "H70夜视精英头盔"))
	_check(btk.refresh.active.size() == 1 and btk.refresh.active[0].tween == unchanged_tween, "Same BTK on different helmet does not restart sweep")
	await create_timer(0.35).timeout
	choose._select_defense("helmet", choose._find_by_name(choose.helmets, "DICH训练头盔"))
	await create_timer(0.35).timeout
	var old_damage: String = info.damage.text
	choose._select_weapon(choose._find_by_name(choose.weapons, "AWM"))
	_check(info.refresh.running and btk.refresh.running, "Weapon change animates information and changed BTK")
	_check(btk.refresh.active.size() == 8, "Eight changed BTKs create eight independent sweeps")
	_check(info.refresh.active.size() == 7, "Seven changed weapon stats including TTK create independent sweeps")
	for entry in btk.refresh.active:
		_check(entry.beam.size.y < 40, "Each sweep is confined to one text row")
		_check(entry.ghost.material == entry.old_mask, "Each old text has its own reveal mask")
	_check(info.refresh.duration == 0.3, "Sweep duration is 0.3 seconds")
	_check(info.refresh.active[0].ghost.text == old_damage.get_slice("\n", 0), "Old text retained until light passes")
	_check(info.damage.text.begins_with("秒肉伤：58.33\n"), "Latest numeric model committed immediately")
	await _capture_at([info.refresh, btk.refresh], "refresh-information")
	choose._select_weapon(choose._find_by_name(choose.weapons, "M7"))
	choose._select_weapon(choose._find_by_name(choose.weapons, "Vector"))
	choose._select_weapon(choose._find_by_name(choose.weapons, "AK-12"))
	await create_timer(0.38).timeout
	_check(not info.refresh.running and info.damage.material == null, "Animation ends and restores original material")
	_check(info.damage.text.begins_with("秒肉伤：367.5\n"), "Rapid changes finish on newest weapon")
	for label in info.damage.get_children():
		_check(label.get_child_count() == 0 and label.material == null, "Each text row overlay removed")
	choose._select_weapon(choose.selected_weapon)
	_check(not info.refresh.running and not btk.refresh.running, "Unchanged numbers do not replay sweep")
	choose._select_weapon(choose._find_by_name(choose.weapons, "M7"))
	choose._select_bullet(choose._find_by_name(choose.get_bullet_choices(), "FMJ"))
	await create_timer(0.35).timeout
	choose._select_bullet(choose.get_bullet_choices()[-1])
	_check(btk.refresh.running and not info.refresh.running, "Ammo changes animate BTK only")
	_check(btk.refresh.active.size() == 6, "Ammo change leaves unchanged head and limbs static")
	await create_timer(0.35).timeout
	choose._select_defense("helmet", choose._find_by_name(choose.helmets, "H70精英头盔"))
	_check(btk.refresh.running, "Helmet BTK change starts sweep")
	_check(btk.refresh.active.size() == 1 and btk.refresh.active[0].label.name == "Head", "Helmet changes only animate head text")
	scene._show_page("Compare")
	_check(not btk.refresh.running, "Hidden information immediately clears overlay")
	await _frames()
	compare._select_weapon(0, compare._find_by_name(choose.weapons, "Vector"))
	_check(compare.refresh.running, "Comparison values and colors animate")
	_check(compare.sides[0].labels.fire_rate.material != null, "Changed fire rate has its own white sweep")
	for label in compare.sides[1].labels.values():
		_check(label.material == null and label.get_child_count() == 0, "Unchanged opposite-side numbers never flash, even when color changes")
	for entry in compare.refresh.active:
		_check(entry.beam.size.y < 40 and entry.ghost.text != entry.label.text, "Comparison sweeps only changed individual values")
	await _capture_at([compare.refresh], "refresh-compare")
	compare._select_weapon(0, compare._find_by_name(choose.weapons, "M7"))
	compare._select_weapon(0, compare._find_by_name(choose.weapons, "AWM"))
	await create_timer(0.38).timeout
	_check(not compare.refresh.running and compare.sides[0].labels.head.text == "1", "Comparison rapid updates keep latest BTK")
	for side in compare.sides:
		for label in side.labels.values():
			_check(label.material == null and label.get_child_count() == 0, "Comparison overlays fully cleaned")
	print("STAT_REFRESH_SMOKE: %s; failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
