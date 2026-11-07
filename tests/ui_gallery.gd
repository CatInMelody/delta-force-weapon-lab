extends "res://tests/choose_smoke.gd"
## Export the complete Aurora UI at standard and wide window sizes.

func _run() -> void:
	root.size = Vector2i(1152, 648)
	scene = load("res://Scene/main.tscn").instantiate()
	root.add_child(scene)
	choose = scene.get_node("Information/Chosse")
	await _frames()
	_check(not scene.has_node("Appreciate") and not scene.has_node("Menu/Appreciate"), "Donation panel and menu removed")
	for page in ["Information", "Compare", "Rank", "Update"]:
		await _click(scene.get_node("Menu/" + page).get_global_rect().get_center())
		_check(scene.get_node(page).visible, "Menu opens page: " + page)
		if page == "Update":
			_check(scene.get_node("Update/Surface/Margin/Content/Version").text == "当前版本：V1.1.0\n当前赛季S12", "Current version and season text")
			_check(scene.get_node("Menu/Rank").position.y < scene.get_node("Menu/Update").position.y, "Update menu follows rank")
		await _frames()
		await _capture("aurora-" + page.to_lower())
	scene._show_page("Information")
	for card in ["GunInformation", "Chosse", "BuildCode"]:
		var panel: Control = scene.get_node("Information/" + card)
		_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Standard window contains " + card)
	choose._open_picker("weapon")
	await _frames()
	await _capture("aurora-picker")
	choose.picker.close_picker()
	root.size = Vector2i(1600, 900)
	await _frames()
	await _capture("aurora-wide")
	for card in ["GunInformation", "Chosse", "BuildCode"]:
		var panel: Control = scene.get_node("Information/" + card)
		_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Wide window contains " + card)
	print("UI_GALLERY: %s; failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
