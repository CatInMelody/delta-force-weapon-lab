extends "res://tests/choose_smoke.gd"

const TEST_PATH := "user://weapon_build_codes_smoke_24da21.json"


func _new_scene(path: String) -> Control:
	var instance: Control = load("res://Scene/main.tscn").instantiate()
	instance.get_node("Information/BuildCode").save_path = path
	root.add_child(instance)
	return instance


func _edit(field: LineEdit, text: String) -> void:
	field.text = text
	field.text_changed.emit(text)


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var writing := "--write" in OS.get_cmdline_user_args()
	if writing:
		_check(not FileAccess.file_exists(TEST_PATH), "Isolated test save starts absent")
	scene = _new_scene(TEST_PATH)
	choose = scene.get_node("Information/Chosse")
	var build: Control = scene.get_node("Information/BuildCode")
	await _frames()
	if writing:
		_edit(build.title_a, "近距离突击")
		_edit(build.title_b, "  静音方案  ")
		_edit(build.title_c, "远程架枪")
		_edit(build.text_a, "M7方案A #123")
		_edit(build.text_b, "M7方案B 中文")
		_edit(build.text_c, "M7方案C #789")
		await create_timer(0.55).timeout
		_check(FileAccess.file_exists(TEST_PATH) and not build.dirty, "Debounced edit reaches real local file")
		choose._select_weapon(choose._find_by_name(choose.weapons, "AKM"))
		_check(build.text_a.text.is_empty() and build.text_b.text.is_empty(), "New weapon starts with empty plans")
		_check(build.text_c.text.is_empty() and build.button_c.disabled, "New weapon starts with empty C")
		_check(build.title_a.text == "方案 A" and build.title_c.text == "方案 C", "New gun defaults to original titles")
		_edit(build.title_a, "AKM专属标题")
		_edit(build.text_a, "  AKM方案A  ")
		_edit(build.text_b, "AKM方案B #456")
		_edit(build.text_c, "AKM独立方案C")
		choose._select_weapon(choose._find_by_name(choose.weapons, "M7"))
		_check(build.text_a.text == "M7方案A #123" and build.text_b.text == "M7方案B 中文", "Switch restores M7 plans")
		_check(build.text_c.text == "M7方案C #789", "Switch restores independent M7 C")
		_check(build.title_a.text == "近距离突击" and build.title_b.text == "  静音方案  " and build.title_c.text == "远程架枪", "Switch restores independent titles exactly")
		if DisplayServer.get_name() != "headless":
			var previous_clipboard := DisplayServer.clipboard_get()
			await _click(build.button_c.get_global_rect().get_center())
			_check(DisplayServer.clipboard_get() == "M7方案C #789", "C button copies only C")
			DisplayServer.clipboard_set(previous_clipboard)
		_check(not build.dirty, "Switch immediately flushes outgoing weapon")
		await _capture("build-code-saved")
		# 不等待自动保存；下一次独立进程必须能读取退出前最后的编辑。
		_edit(build.text_a, "M7退出前最终方案A")
		print("BUILD_CODE_WRITE: ", "PASS" if failures.is_empty() else "FAIL")
		print("Production save path: ", ProjectSettings.globalize_path(build.DEFAULT_SAVE_PATH))
		quit(0 if failures.is_empty() else 1)
		return
	_check(build.text_a.text == "M7退出前最终方案A" and build.text_b.text == "M7方案B 中文", "New process restores final M7 edit saved on shutdown")
	_check(build.text_c.text == "M7方案C #789", "New process restores C")
	_check(build.title_a.text == "近距离突击" and build.title_b.text == "  静音方案  " and build.title_c.text == "远程架枪", "New process restores all custom titles")
	choose._select_weapon(choose._find_by_name(choose.weapons, "AKM"))
	_check(build.text_a.text == "  AKM方案A  " and build.text_b.text == "AKM方案B #456", "New process restores independent AKM plans without trimming")
	_check(build.text_c.text == "AKM独立方案C", "New process restores AKM C")
	_check(build.title_a.text == "AKM专属标题" and build.title_b.text == "方案 B", "AKM titles independent after restart")
	_edit(build.title_a, "")
	_edit(build.text_a, "")
	_edit(build.text_b, "")
	_edit(build.text_c, "")
	build._save_codes()
	scene.free()
	scene = _new_scene(TEST_PATH)
	choose = scene.get_node("Information/Chosse")
	build = scene.get_node("Information/BuildCode")
	choose._select_weapon(choose._find_by_name(choose.weapons, "AKM"))
	_check(build.text_a.text.is_empty() and build.text_b.text.is_empty(), "Cleared plans remain cleared after reload")
	_check(build.button_a.disabled and build.button_b.disabled, "Empty saved plans disable copy")
	_check(build.text_c.text.is_empty() and build.button_c.disabled, "Cleared C persists and disables copy")
	_check(build.title_a.text.is_empty() and build.title_a.placeholder_text == "方案 A", "Empty title persists with default placeholder")
	choose._select_weapon(choose._find_by_name(choose.weapons, "M7"))
	_check(build.text_a.text == "M7退出前最终方案A", "Clearing AKM does not clear M7")
	var m7_id: String = choose.selected_weapon.weapon_id
	scene.free()
	# 旧版本只有 A/B：读取不丢失，新增 C 后再次保存保留 A/B。
	var legacy_path := TEST_PATH + ".legacy"
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"schema_version": 1, "weapons": {m7_id: {"a": "原方案A", "b": "原方案B"}}}))
	legacy_file.close()
	scene = _new_scene(legacy_path)
	build = scene.get_node("Information/BuildCode")
	_check(build.storage_readable and build.text_a.text == "原方案A" and build.text_b.text == "原方案B" and build.text_c.text.is_empty(), "Legacy A/B save compatible")
	_check(build.title_a.text == "方案 A" and build.title_b.text == "方案 B" and build.title_c.text == "方案 C", "Legacy save falls back to default titles")
	_edit(build.title_a, "旧存档新标题")
	_edit(build.text_c, "新增方案C")
	build._save_codes()
	scene.free()
	scene = _new_scene(legacy_path)
	build = scene.get_node("Information/BuildCode")
	_check(build.text_a.text == "原方案A" and build.text_b.text == "原方案B" and build.text_c.text == "新增方案C", "Legacy upgrade retains A/B and new C")
	_check(build.title_a.text == "旧存档新标题", "Legacy upgrade retains edited title")
	scene.free()
	var corrupt_path := TEST_PATH + ".corrupt"
	var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("broken json fixture")
	file.close()
	scene = _new_scene(corrupt_path)
	build = scene.get_node("Information/BuildCode")
	_check(not build.storage_readable, "Corrupt file detected")
	_edit(build.text_a, "不能覆盖原文件")
	build._save_codes()
	scene.free()
	_check(FileAccess.get_file_as_string(corrupt_path) == "broken json fixture", "Corrupt existing file preserved")
	for path in [TEST_PATH, TEST_PATH + ".tmp", corrupt_path, corrupt_path + ".tmp", legacy_path, legacy_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("BUILD_CODE_READ: %s; failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
