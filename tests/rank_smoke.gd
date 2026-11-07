extends "res://tests/choose_smoke.gd"
## 复用 Viewport 鼠标输入和截图工具，验证排行入口与左右独立滚动。


func _run() -> void:
	var layout: Control = load("res://Scene/rank.tscn").instantiate()
	for board in ["FleshBoard", "ArmorBoard"]:
		var path: String = "Leaderboards/" + board + "/Margin/Column/"
		_check(layout.has_node(path + "Title"), "Board labels serialized: " + board)
		_check(layout.has_node(path + "Table") and layout.get_node(path + "Table").columns == 6, "Six-column table serialized: " + board)
	layout.free()
	root.size = Vector2i(1152, 648)
	scene = load("res://Scene/main.tscn").instantiate()
	root.add_child(scene)
	choose = scene.get_node("Information/Chosse")
	var rank_panel: Control = scene.get_node("Rank")
	await _frames()
	_check(scene.get_node("Information").visible and not rank_panel.visible, "Default page remains Information")
	_check(rank_panel.flesh_ranking.size() == 74 and rank_panel.armor_ranking.size() == 74, "Both boards include 74 weapons")
	_check(rank_panel.flesh_ranking[0].name == "Vector", "Flesh DPS leader is Vector")
	_check(rank_panel.armor_ranking[0].name == "AS-Val", "Armor DPS leader is AS-Val")
	for key in ["flesh", "armor"]:
		var ranking: Array[Dictionary] = rank_panel.flesh_ranking if key == "flesh" else rank_panel.armor_ranking
		for index in range(1, ranking.size()):
			_check(ranking[index - 1][key + "_dps"] >= ranking[index][key + "_dps"], key + " descending order")
		var table: Tree = rank_panel.flesh_table if key == "flesh" else rank_panel.armor_table
		_check(table.get_root().get_child_count() == 74 and table.columns == 6, "All six columns and 74 rows in " + key)
	var flesh_table: Tree = rank_panel.flesh_table
	var armor_table: Tree = rank_panel.armor_table
	var flesh_first := flesh_table.get_root().get_first_child()
	var armor_first := armor_table.get_root().get_first_child()
	var flesh_values: Array[String] = []
	var armor_values: Array[String] = []
	for index in range(6):
		flesh_values.append(flesh_first.get_text(index))
		armor_values.append(armor_first.get_text(index))
	_check(flesh_values == ["1", "Vector", "581.87", "32", "28", "1091"], "Flesh row shows rank, name, DPS, flesh, armor, RPM")
	_check(armor_values == ["1", "AS-Val", "712.8", "28", "44", "972"], "Armor row shows rank, name, DPS, flesh, armor, RPM")
	var precise: Array[Dictionary] = [
		{"weapon_id": "2", "dps": 100.001},
		{"weapon_id": "1", "dps": 100.004},
	]
	rank_panel._sort_ranking(precise, "dps")
	_check(precise[0].weapon_id == "1", "Sorting retains precision when displayed DPS ties")
	choose._select_weapon(choose._find_by_name(choose.weapons, "AKM"))
	var selected_id: String = choose.selected_weapon.id
	await _click(scene.get_node("Menu/Rank").get_global_rect().get_center())
	_check(rank_panel.visible and not scene.get_node("Information").visible, "Rank menu opens Rank and hides Information")
	_check(scene.get_node("Menu/Rank").button_pressed, "Rank menu highlighted")
	_check(flesh_table.get_global_rect().end.x < armor_table.get_global_rect().position.x, "Flesh board left and armor board right")
	await _capture("rank-main")
	var left_before := flesh_table.get_scroll()
	var right_before := armor_table.get_scroll()
	await _wheel(flesh_table.get_global_rect().get_center())
	await _frames()
	_check(flesh_table.get_scroll().y > left_before.y, "Mouse wheel scrolls flesh board")
	_check(armor_table.get_scroll() == right_before, "Left scrolling leaves right board unchanged")
	var left_after := flesh_table.get_scroll()
	await _wheel(armor_table.get_global_rect().get_center())
	await _frames()
	_check(armor_table.get_scroll().y > right_before.y, "Mouse wheel scrolls armor board")
	_check(flesh_table.get_scroll() == left_after, "Right scrolling leaves left board unchanged")
	await _capture("rank-scrolled")
	await _click(scene.get_node("Menu/Information").get_global_rect().get_center())
	_check(scene.get_node("Information").visible and not rank_panel.visible, "Information menu returns to Information")
	_check(choose.selected_weapon.id == selected_id, "Page switching preserves weapon selection")
	await _click(scene.get_node("Menu/Rank").get_global_rect().get_center())
	_check(flesh_table.get_scroll() == left_after, "Reopening Rank preserves scroll position")
	print("RANK_SMOKE: %s; flesh=74 armor=74 failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
