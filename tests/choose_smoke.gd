extends SceneTree
## Godot --headless --path . --script res://tests/choose_smoke.gd
## 加 -- --screenshots 可在有图形界面的运行中保存预览图。

var failures: Array[String] = []
var scene: Control
var choose: Control
var captures := false


func _initialize() -> void:
	captures = "--screenshots" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _frames() -> void:
	await process_frame
	await process_frame


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await _frames()


func _wheel(point: Vector2) -> void:
	for index in range(5):
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN
			event.pressed = pressed
			root.push_input(event)
		await process_frame


func _capture(filename: String) -> void:
	if captures:
		await create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/" + filename + ".png")
	else:
		await _frames()


func _pick_index(index: int) -> void:
	var button: Button = choose.picker.grid.get_child(index)
	choose.picker.scroll.ensure_control_visible(button)
	await _frames()
	await _click(button.get_global_rect().get_center())


func _run() -> void:
	root.size = Vector2i(1152, 648)
	scene = load("res://Scene/main.tscn").instantiate()
	root.add_child(scene)
	choose = scene.get_node("Information/Chosse")
	await _frames()
	_check(choose.weapons.size() == 74, "74 weapons loaded")
	_check(choose.helmets.size() == 27, "27 helmets loaded")
	_check(choose.armors.size() == 26, "26 armors loaded")
	_check(choose.selected_weapon.name == "M7", "Initial weapon preserved")
	var damage: Control = scene.get_node("Information/GunInformation/Margin/Column/Damage")
	var magnification: Control = scene.get_node("Information/GunInformation/Margin/Column/Magnification")
	_check(damage.text == "秒肉伤：400.22\n秒甲伤：432.67\n肉伤：37\n甲伤：40\n射速：649\n射程：50 米\nTTK：0.37 秒", "Initial M7 information and rounded DPS")
	_check(magnification.text == "头部倍率：1.9\n胸部倍率：1.0\n腹部倍率：1.0\n四肢倍率：0.35", "M7 specific body multipliers")
	_check(choose.selected_bullet.level == 4, "Initial bullet level preserved")
	_check(choose.selected_helmet.name == "DICH训练头盔", "Initial helmet preserved")
	_check(choose.selected_armor.name == "重型突击背心", "Initial armor preserved")
	_check(choose.removed_ammo_ids.size() == 18, "All 18 requested ammo types removed")
	for ammo_id in choose.removed_ammo_ids:
		_check(choose.ammo_data.ammo[ammo_id].display_name == choose.removed_ammo_ids[ammo_id], "Removed ID matches exact caliber and name")
	var special_icons := {
		"37210400002": "5.7x28mm-HT-plus.webp", "37210300002": "5.7x28mm-HT.webp",
		"37260500002": "4.6x30mm-AP-ST.webp", "37260000002": "4.6x30mm-CT.webp",
		"37260400002": "4.6x30mm-FMJ-ST.webp", "37170500002": "7.62x51mm-LS.webp",
	}
	var seen_special := {}
	for weapon in choose.weapons:
		choose._select_weapon(weapon)
		_check(choose.gun.texture.resource_path == weapon.icon, "Weapon image: " + weapon.name)
		var choices: Array[Dictionary] = choose.get_bullet_choices()
		_check(not choices.is_empty(), "Weapon has ammo: " + weapon.name)
		for option in choices:
			_check(not choose.removed_ammo_ids.has(option.id), "Removed ammo absent from all weapon choices")
			if special_icons.has(option.id):
				_check(option.icon == "res://assets/Bullet/Special/" + special_icons[option.id], "Updated special ammo icon: " + option.display_name)
				seen_special[option.id] = true
			if option.level == 0:
				var expected_background := "4级_紫色.png" if option.id == "37260000002" else "3级_蓝色.png"
				_check(option.background == "res://assets/Bullet/Background/" + expected_background, "Zero level ammo background follows caliber exception")
			choose._select_bullet(option)
			_check(choose.bullet.texture.resource_path == option.icon, "Bullet icon: " + weapon.name)
			_check(choose.bullet_background.texture.resource_path == option.background, "Bullet background: " + weapon.name)
			_check(option.ammo_type_id == weapon.ammo_type_id, "Matching caliber type: " + weapon.name)
	_check(seen_special.size() == 6, "All six updated special icons encountered")
	for kind in ["helmet", "armor"]:
		var defenses: Array[Dictionary] = choose.helmets if kind == "helmet" else choose.armors
		for defense in defenses:
			choose._select_defense(kind, defense)
			var image: TextureRect = choose.helmet if kind == "helmet" else choose.armor
			_check(image.texture.resource_path == defense.icon, "Defense image: " + defense.name)
	choose._select_weapon(choose._find_by_name(choose.weapons, "M7"))
	choose._select_bullet(choose._find_by_name(choose.get_bullet_choices(), "FMJ"))
	choose._select_weapon(choose._find_by_name(choose.weapons, "AKM"))
	_check(choose.selected_bullet.level == 4, "Preserve available grade across calibers")
	choose._select_weapon(choose._find_by_name(choose.weapons, "M82"))
	_check(choose.selected_bullet.level == 6, "Clamp to available M82 grade")
	choose._select_bullet(choose.get_bullet_choices()[-1])
	_check(choose.selected_bullet.level == 7, "M82 can select level 7")
	choose._select_weapon(choose._find_by_name(choose.weapons, "MP5"))
	_check(choose.selected_bullet.level == 4, "Clamp to MP5 maximum")
	choose._select_weapon(choose._find_by_name(choose.weapons, "AWM"))
	_check(choose.get_bullet_choices().size() == 1, "AWM only offers locally collected grade")
	choose._select_weapon(choose._find_by_name(choose.weapons, "M7"))
	choose._select_bullet(choose._find_by_name(choose.get_bullet_choices(), "FMJ"))
	choose._select_defense("helmet", choose._find_by_name(choose.helmets, "DICH训练头盔"))
	choose._select_defense("armor", choose._find_by_name(choose.armors, "重型突击背心"))
	await _frames()
	await _capture("choose-main")
	# 用真实 Viewport 输入验证命中区域、图标卡片与滚轮冒泡。
	for kind in ["weapon", "bullet", "helmet", "armor"]:
		if kind == "bullet":
			choose._select_weapon(choose._find_by_name(choose.weapons, "M7"))
			choose._select_bullet(choose._find_by_name(choose.get_bullet_choices(), "FMJ"))
		await _click(choose.launchers[kind].get_global_rect().get_center())
		_check(choose.picker.visible, "Click opens " + kind)
		if not choose.picker.visible:
			print("Hovered: ", root.gui_get_hovered_control(), " mouse: ", root.get_mouse_position())
			quit(1)
			return
		_check(choose.picker.current_kind == kind, "Correct popup kind: " + kind)
		_check(root.get_visible_rect().encloses(choose.picker.panel.get_global_rect()), "Popup stays in viewport: " + kind)
		_check(choose.picker.panel.position.y >= choose.launchers[kind].get_global_rect().end.y + 8, "Popup opens below the clicked icon: " + kind)
		_check(choose.picker.scroll.get_global_rect().encloses(choose.picker.selected_button.get_global_rect()), "Current selection visible: " + kind)
		if not choose.picker.scroll.get_global_rect().encloses(choose.picker.selected_button.get_global_rect()):
			print("Selection rect ", kind, ": ", choose.picker.selected_button.get_global_rect(), " scroll rect: ", choose.picker.scroll.get_global_rect(), " offset: ", choose.picker.scroll.scroll_vertical)
		if kind == "weapon":
			var counts := {"AR": 30, "SMG": 16, "LMG": 6, "DMR": 14, "SR": 7}
			var selected_id: String = choose.selected_weapon.id
			for category in counts:
				await _click(choose.picker.category_buttons[category].get_global_rect().get_center())
				_check(choose.picker.grid.get_child_count() == counts[category], "Category count: " + category)
				var preceding_base_id := ""
				for item_index in range(choose.picker.items.size()):
					var item: Dictionary = choose.picker.items[item_index]
					_check(item.category == category, "Only requested category shown")
					_check(choose.picker.grid.get_child(item_index).get_node("Caption").text == item.name, "Weapon card shows only its name")
					if item.has("base_weapon_id"):
						_check(item.base_weapon_id == preceding_base_id, "Variant immediately follows its original weapon group: " + item.name)
					else:
						preceding_base_id = item.weapon_id
				_check(choose.selected_weapon.id == selected_id, "Filtering alone does not change weapon")
			await _click(choose.picker.category_buttons.AR.get_global_rect().get_center())
			choose.picker.scroll.scroll_vertical = 0
			await _frames()
			var before: int = choose.picker.scroll.scroll_vertical
			await _wheel(choose.picker.grid.get_child(0).get_global_rect().get_center())
			_check(choose.picker.scroll.scroll_vertical > before, "Wheel scrolls while hovering icon")
			await _capture("choose-weapons")
		if kind == "bullet":
			_check(not choose.picker.get_node("Panel/Margin/Content/Categories").visible, "Categories hidden for non-weapon picker")
			_check(choose.picker.grid.get_child_count() == 3, "M7 offers FMJ, Hybrid and AP after removing PLY")
			await _capture("choose-bullets")
		var expected: Dictionary = choose.picker.items[0]
		await _pick_index(0)
		_check(not choose.picker.visible, "Select closes " + kind)
		var actual: Dictionary
		match kind:
			"weapon": actual = choose.selected_weapon
			"bullet": actual = choose.selected_bullet
			"helmet": actual = choose.selected_helmet
			"armor": actual = choose.selected_armor
		_check(actual.id == expected.id, "Click selects correct " + kind)
		if kind == "weapon":
			_check(choose.selected_bullet.caliber == "5.45x39mm", "UI weapon selection updates ammo")
			_check(damage.text.begins_with("秒肉伤：367.5\n秒甲伤：514.5\n肉伤：30\n甲伤：42\n射速：735\n射程：40 米\nTTK："), "UI weapon selection updates AK-12 information")
	await _click(choose.launchers.weapon.get_global_rect().get_center())
	await _click(Vector2(20, 20))
	_check(not choose.picker.visible, "Backdrop closes picker")
	await _click(choose.launchers.weapon.get_global_rect().get_center())
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await _frames()
	_check(not choose.picker.visible, "Escape closes picker")
	await _click(choose.launchers.weapon.get_global_rect().get_center())
	scene.get_node("Information").hide()
	_check(not choose.picker.visible, "Hiding information closes picker")
	scene.get_node("Information").show()
	choose._select_weapon(choose._find_by_name(choose.weapons, "MP5"))
	choose._open_picker("weapon")
	await _frames()
	_check(choose.picker.current_category == "SMG" and choose.picker.grid.get_child_count() == 16, "Reopen selects current weapon category")
	var expected_smg: Dictionary = choose.picker.items[0]
	await _pick_index(0)
	_check(choose.selected_weapon.id == expected_smg.id, "Selecting filtered SMG updates weapon")
	root.size = Vector2i(500, 480)
	root.content_scale_size = Vector2i(500, 480)
	await _frames()
	choose._open_picker("weapon")
	await _frames()
	_check(choose.picker.grid.columns == 2, "Narrow popup uses two columns")
	_check(root.get_visible_rect().encloses(choose.picker.panel.get_global_rect()), "Narrow popup stays in viewport")
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(1152, 648)
	await _frames()
	_check(not choose.picker.visible, "Resize closes picker")
	# 输入保持按下，验证图片的实际压下反馈；释放后仍按正常路径打开弹层。
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(1152, 648)
	await _frames()
	var point: Vector2 = choose.launchers.weapon.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press)
	await create_timer(0.12).timeout
	_check(absf(choose.gun.scale.x - 0.94) < 0.01, "Icon visibly compresses when pressed")
	await _capture("choose-pressed")
	press = InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = false
	root.push_input(press)
	await _frames()
	_check(choose.picker.visible, "Release opens picker after press feedback")
	choose.picker.close_picker()
	choose.picker.open_picker("helmet", choose.helmets, str(choose.selected_helmet.id), Rect2(1020, 610, 80, 20))
	await _frames()
	_check(choose.picker.panel.get_global_rect().end.y <= 602, "Bottom-edge picker flips above the icon")
	_check(root.get_visible_rect().encloses(choose.picker.panel.get_global_rect()), "Flipped picker remains inside window")
	choose.picker.close_picker()
	print("CHOOSE_SMOKE: %s; weapons=74 helmets=27 armors=26; failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
