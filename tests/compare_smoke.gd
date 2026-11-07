extends "res://tests/choose_smoke.gd"


func _run() -> void:
	# 不进入场景树、不执行 _ready，也应已经存在全部可编辑布局节点。
	var layout: Control = load("res://Scene/compare.tscn").instantiate()
	_check(layout.has_node("Content/TableScroll/Table/MetricLabels/Column/Metrics/Mixed3"), "Metric column serialized in scene")
	for side_name in ["LeftWeapon", "RightWeapon"]:
		var path: String = "Content/TableScroll/Table/" + side_name + "/Margin/Column/"
		_check(layout.has_node(path + "WeaponHeader/WeaponButton/Image"), "Editable weapon image: " + side_name)
		_check(layout.get_node(path + "Metrics").get_child_count() == 10, "All value rows serialized: " + side_name)
	_check(layout.has_node("ComparePopupLayer/IconPicker/Panel/Margin/Content/Scroll/Grid"), "Picker layout serialized in scene")
	layout.free()
	root.size = Vector2i(1152, 648)
	scene = load("res://Scene/main.tscn").instantiate()
	root.add_child(scene)
	choose = scene.get_node("Information/Chosse")
	var compare: Control = scene.get_node("Compare")
	await _frames()
	_check(compare.helmet.name == "GN重型头盔" and compare.helmet.max_durability == 50, "Shared default GN helmet")
	_check(compare.armor.name == "重型突击背心" and compare.armor.max_durability == 125, "Shared default heavy armor")
	_check(compare.sides[0].weapon.name == "M7" and compare.sides[1].weapon.name == "M4A1", "Initial left and right weapons")
	_check(compare.sides[0].bullet.level == 5 and compare.sides[1].bullet.level == 5, "Default level five ammo")
	_check(compare.sides[0].metrics.head == 2 and compare.sides[1].metrics.head == 3, "BTK calculated against shared GN helmet")
	_check(compare.sides[0].metrics.chest == 5 and compare.sides[1].metrics.chest == 5, "Equal chest BTK")
	_check(compare.sides[0].labels.fire_rate.text == "649" and compare.sides[1].labels.fire_rate.text == "800", "Fire rate in rounds per minute displayed")
	_check(compare.sides[1].labels.fire_rate.get_theme_color("font_color") == compare.BETTER_COLOR, "Higher fire rate red")
	_check(compare.sides[0].labels.flesh_dps.text == "400.22" and compare.sides[1].labels.flesh_dps.text == "413.33", "Basic flesh DPS displayed")
	_check(compare.sides[0].labels.armor_dps.text == "432.67" and compare.sides[1].labels.armor_dps.text == "440", "Basic armor DPS displayed")
	_check(compare.sides[0].labels.flesh_dps.get_theme_color("font_color") == compare.NORMAL_COLOR, "Lower DPS stays normal")
	_check(compare.sides[1].labels.flesh_dps.get_theme_color("font_color") == compare.BETTER_COLOR, "Higher DPS red")
	_check(compare.sides[0].labels.head.get_theme_color("font_color") == compare.BETTER_COLOR, "Lower BTK red")
	_check(compare.sides[1].labels.head.get_theme_color("font_color") == compare.NORMAL_COLOR, "Higher BTK stays normal")
	_check(compare.sides[0].labels.chest.get_theme_color("font_color") == compare.NORMAL_COLOR and compare.sides[1].labels.chest.get_theme_color("font_color") == compare.NORMAL_COLOR, "Equal BTK neutral on both sides")
	var original_weapon: String = choose.selected_weapon.id
	var original_bullet: String = choose.selected_bullet.id
	for weapon in choose.weapons:
		var ammo: Dictionary = compare._default_ammo(weapon)
		_check(not choose.removed_ammo_ids.has(ammo.id), "Comparison default excludes removed ammo: " + weapon.name)
		var expected_level := 5
		if weapon.ammo_type_id == "20":
			expected_level = 4
		elif weapon.name == "AWM":
			expected_level = 7
		elif weapon.name == "M82":
			expected_level = 6
		_check(ammo.level == expected_level, "Ammo fallback: " + weapon.name)
		compare._select_weapon(0, weapon)
		_check(compare.sides[0].metrics.size() == 10, "All comparison metrics: " + weapon.name)
	compare._select_weapon(0, compare._find_by_name(choose.weapons, "M7"))
	compare._select_weapon(1, compare._find_by_name(choose.weapons, "M7"))
	for metric in compare.METRICS:
		_check(compare.sides[0].labels[metric].get_theme_color("font_color") == compare.NORMAL_COLOR and compare.sides[1].labels[metric].get_theme_color("font_color") == compare.NORMAL_COLOR, "Same weapon resets previous color: " + metric)
	compare._select_weapon(0, compare._find_by_name(choose.weapons, "Vector"))
	compare._select_weapon(1, compare._find_by_name(choose.weapons, "AWM"))
	_check(compare.sides[0].labels.flesh_dps.get_theme_color("font_color") == compare.BETTER_COLOR, "DPS winner can switch sides")
	_check(compare.sides[1].labels.head.get_theme_color("font_color") == compare.BETTER_COLOR and compare.sides[0].labels.head.get_theme_color("font_color") == compare.NORMAL_COLOR, "BTK winner can switch sides")
	compare._select_weapon(0, compare._find_by_name(choose.weapons, "M7"))
	compare._select_weapon(1, compare._find_by_name(choose.weapons, "M4A1"))
	await _click(scene.get_node("Menu/Compare").get_global_rect().get_center())
	_check(compare.visible and not scene.get_node("Information").visible, "Compare menu navigation")
	for index in range(compare.METRICS.size()):
		var metric: String = compare.METRICS[index]
		var label: Label = compare.get_node("Content/TableScroll/Table/MetricLabels/Column/Metrics/" + compare.ROW_NODES[index])
		for side in compare.sides:
			var value: Label = side.labels[metric]
			_check(absf(label.get_global_rect().get_center().y - value.get_global_rect().get_center().y) < 1.0, "Shared row alignment: " + metric)
	await _capture("compare-main")
	for side_index in range(2):
		var other_id: String = compare.sides[1 - side_index].weapon.id
		await _click(compare.sides[side_index].button.get_global_rect().get_center())
		_check(compare.picker.visible and compare.picker.grid.get_child_count() == 31, "Icon opens current rifle category on side %d" % side_index)
		_check(compare.picker.panel.position.y >= compare.sides[side_index].button.get_global_rect().end.y + 8, "Comparison picker opens directly below icon")
		_check(root.get_visible_rect().encloses(compare.picker.panel.get_global_rect()), "Comparison picker fits below without leaving window")
		if not compare.picker.visible:
			quit(1)
			return
		if side_index == 0:
			await _click(compare.picker.category_buttons.SMG.get_global_rect().get_center())
			_check(compare.picker.grid.get_child_count() == 16, "Comparison chooser filters SMGs")
			await _click(compare.picker.category_buttons.AR.get_global_rect().get_center())
			compare.picker.scroll.scroll_vertical = 0
			await _frames()
			await _wheel(compare.picker.grid.get_child(0).get_global_rect().get_center())
			_check(compare.picker.scroll.scroll_vertical > 0, "Weapon chooser mouse wheel")
			await _capture("compare-picker")
		var button: Button = compare.picker.grid.get_child(0)
		compare.picker.scroll.ensure_control_visible(button)
		await _frames()
		await _click(button.get_global_rect().get_center())
		_check(compare.sides[side_index].weapon.name == "AK-12", "Click changes requested side only")
		_check(compare.sides[1 - side_index].weapon.id == other_id, "Other weapon preserved")
		_check(not compare.picker.visible, "Picker closes after choosing")
	_check(choose.selected_weapon.id == original_weapon and choose.selected_bullet.id == original_bullet, "Comparison does not mutate Information selection")
	for metric in compare.METRICS:
		_check(compare.sides[0].labels[metric].get_theme_color("font_color") == compare.NORMAL_COLOR and compare.sides[1].labels[metric].get_theme_color("font_color") == compare.NORMAL_COLOR, "UI equal selections reset color: " + metric)
	await _click(scene.get_node("Menu/Information").get_global_rect().get_center())
	await _click(scene.get_node("Menu/Compare").get_global_rect().get_center())
	_check(compare.sides[0].weapon.name == "AK-12" and compare.sides[1].weapon.name == "AK-12", "Page switching preserves comparison")
	await _click(compare.sides[0].button.get_global_rect().get_center())
	scene._show_page("Rank")
	_check(not compare.picker.visible, "Hiding Compare closes popup")
	print("COMPARE_SMOKE: %s; weapons=74 failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
