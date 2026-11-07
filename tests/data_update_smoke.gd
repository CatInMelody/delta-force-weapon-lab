extends "res://tests/choose_smoke.gd"

const DataStore = preload("res://Code/data_store.gd")
const Multipliers = preload("res://Code/weapon_multipliers.gd")
const Calculator = preload("res://Code/damage_calculator.gd")
const TEST_ROOT := "user://data_update_smoke"
const PLANS := "user://data_update_smoke_plans.json"
const HTTP_ROOT := "res://tests/update_http_fixture"
var old_root := ""


func _new_scene() -> Control:
	var instance: Control = load("res://Scene/main.tscn").instantiate()
	instance.get_node("Information/BuildCode").save_path = PLANS
	root.add_child(instance)
	return instance


func _bytes(bundle: Dictionary) -> PackedByteArray:
	return JSON.stringify(bundle).to_utf8_buffer()


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _wait_request(updater: Control) -> void:
	var end := Time.get_ticks_msec() + 8000
	while not updater.phase.is_empty() and Time.get_ticks_msec() < end:
		await create_timer(0.02).timeout
	_check(updater.phase.is_empty(), "HTTP request completes within test deadline")


func _run() -> void:
	old_root = DataStore.storage_root
	DataStore.storage_root = TEST_ROOT
	DataStore.reset_cache()
	if FileAccess.file_exists(TEST_ROOT + "/active.json") or FileAccess.file_exists(PLANS):
		push_error("Isolated fixture already exists; preserve and inspect it before rerunning")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	scene = _new_scene()
	choose = scene.get_node("Information/Chosse")
	var build: Control = scene.get_node("Information/BuildCode")
	var updater: Control = scene.get_node("Update")
	await _frames()
	_check(DataStore.metadata().data_version == 3 and choose.weapons.size() == 74, "Built-in data works without network or update")
	_check(Multipliers.for_weapon(choose.selected_weapon).head == 1.9, "Prime original multiplier cache")
	_check(Calculator.base_damage_ratio_for({"caliber": ".45 ACP", "level": 5}) == 0.85, "Prime original ammo cache")
	var configured_url: String = updater.manifest_url
	updater.manifest_url = ""
	updater.check_updates()
	_check(updater.status.text.contains("未配置") and updater.phase.is_empty(), "Unconfigured endpoint gives clear status")
	updater.manifest_url = configured_url
	build.text_a.text = "更新前未保存方案"
	build.text_a.text_changed.emit(build.text_a.text)
	build.title_a.text = "保留我的标题"
	build.title_a.text_changed.emit(build.title_a.text)
	var bundle := {"schema_version": 1, "min_data_api": 2, "data_version": 4, "version_name": "1.0.1-test", "season": "S12", "files": {}, "images": {}}
	for path in DataStore.FILES:
		bundle.files[path] = DataStore.builtin_json("res://" + path)
	var guns: Array = bundle.files[DataStore.FILES[0]].weapons
	var original: Dictionary = {}
	for weapon in guns:
		if weapon.name == "M7":
			weapon.flesh_damage = 45
			weapon.fire_rate_rpm = 700
			original = weapon
	var added := original.duplicate(true)
	added.weapon_id = "test:new-gun"
	added.name = "测试新增武器"
	added.flesh_damage = 52
	added.icon_relative_path = "AR/update-fixture.png"
	guns.append(added)
	bundle.files[DataStore.FILES[2]].weapons[added.weapon_id] = bundle.files[DataStore.FILES[2]].weapons[original.weapon_id].duplicate(true)
	bundle.files[DataStore.FILES[1]].weapons.append({"weapon_id": "test:new-variant", "base_weapon_id": original.weapon_id, "name": "测试新增配置", "overrides": {"range_m": 88}})
	bundle.files[DataStore.FILES[3]].weapons[original.weapon_id].multipliers.head = 2.2
	bundle.files[DataStore.FILES[5]].by_caliber_and_level[".45 ACP"]["5"] = 0.8
	bundle.images["assets/AR/update-fixture.png"] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes("res://assets/AR/M7.png"))
	_check(DataStore.validate_bundle(bundle).is_empty(), "Valid cross-linked gun data and new picture accepted")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HTTP_ROOT))
	var bytes := _bytes(bundle)
	var manifest := {"schema_version": 1, "min_data_api": 2, "data_version": 4, "version_name": bundle.version_name, "season": "S12", "size": bytes.size(), "sha256": DataStore.sha256(bytes), "package_url": "data-2.json", "notes": "本地集成测试：修改旧枪、新增武器与图片。"}
	_write(HTTP_ROOT + "/data-2.json", bytes)
	_write(HTTP_ROOT + "/data-version.json", _bytes(manifest))
	scene._show_page("Update")
	if "--online-test" in OS.get_cmdline_user_args():
		updater.allow_local_test_urls = true
		updater.manifest_url = "http://127.0.0.1:18763/data-version.json"
		updater.check_updates()
		await _wait_request(updater)
		_check(not updater.latest.is_empty() and not updater.download_button.disabled, "Real HTTP manifest enables download")
		await _capture("data-update-available")
		if updater.latest.is_empty():
			push_error(updater.status.text)
			_cleanup()
			quit(1)
			return
		updater.download_update()
		await _wait_request(updater)
	else:
		updater._install(bytes)
	_check(updater.pending_reload and updater.reload_button.visible, "Downloaded/imported data staged until reload")
	_check(choose.weapons.size() == 74 and DataStore.metadata().data_version == 3, "Live scene retains consistent old snapshot until reload")
	await _capture("data-update-installed")
	scene.free()
	scene = _new_scene()
	choose = scene.get_node("Information/Chosse")
	build = scene.get_node("Information/BuildCode")
	updater = scene.get_node("Update")
	await _frames()
	_check(DataStore.metadata().data_version == 4 and DataStore.metadata().season == "S12", "Installed version and season persist across scene restart")
	_check(choose.weapons.size() == 76 and choose.selected_weapon.flesh_damage == 45, "Updated existing gun and two new records loaded")
	_check(build.text_a.text == "更新前未保存方案" and build.title_a.text == "保留我的标题", "Personal plans and titles preserved")
	_check(Multipliers.for_weapon(choose.selected_weapon).head == 2.2 and Calculator.base_damage_ratio_for({"caliber": ".45 ACP", "level": 5}) == 0.8, "All static data caches refresh together")
	_check(updater.version.text.contains("S12"), "Update page displays installed season")
	var new_gun: Dictionary = choose._find_by_name(choose.weapons, "测试新增武器")
	choose._select_weapon(new_gun)
	_check(choose.gun.texture is ImageTexture and choose.gun.texture.get_width() > 0, "New downloaded image is rendered")
	var compare: Control = scene.get_node("Compare")
	compare._select_weapon(0, new_gun)
	_check(compare.sides[0].image.texture == choose.gun.texture and compare.sides[0].metrics.flesh_dps > 600, "Compare uses new data and downloaded image")
	var rank_panel: Control = scene.get_node("Rank")
	_check(rank_panel.flesh_ranking.size() == 76 and rank_panel.flesh_ranking[0].name == "测试新增武器", "Rank uses updated catalogue and recomputed DPS")
	choose._open_picker("weapon")
	await _frames()
	_check(choose.picker.selected_button.get_node("Image").texture == choose.gun.texture, "Picker uses downloaded icon")
	choose.picker.close_picker()
	await _capture("data-update-new-gun")
	var installed := FileAccess.get_file_as_bytes(TEST_ROOT + "/active.json")
	var invalid := bundle.duplicate(true)
	invalid.data_version = 5
	invalid.files[DataStore.FILES[0]].weapons[-1].fire_rate_rpm = 0
	_check(not DataStore.install(_bytes(invalid)).is_empty(), "Invalid gun data rejected")
	invalid = bundle.duplicate(true)
	invalid.data_version = 5
	invalid.files[DataStore.FILES[2]].weapons.erase("test:new-gun")
	_check(not DataStore.install(_bytes(invalid)).is_empty(), "Missing ammo mapping rejected")
	invalid = bundle.duplicate(true)
	invalid.data_version = 5
	invalid.images["assets/../Code/payload.gd"] = "payload"
	_check(not DataStore.install(_bytes(invalid)).is_empty(), "Non-image and traversal payload rejected")
	_check(not DataStore.install("broken json".to_utf8_buffer()).is_empty(), "Broken JSON rejected")
	_check(FileAccess.get_file_as_bytes(TEST_ROOT + "/active.json") == installed, "Failed installs do not modify active data")
	if "--online-test" in OS.get_cmdline_user_args():
		var newer := bundle.duplicate(true)
		newer.data_version = 5
		var bad := manifest.duplicate()
		bad.data_version = 5
		bad.package_url = "bad-package.json"
		bad.sha256 = "0".repeat(64)
		bad.size = _bytes(newer).size()
		_write(HTTP_ROOT + "/bad-package.json", _bytes(newer))
		_write(HTTP_ROOT + "/bad-manifest.json", _bytes(bad))
		updater.allow_local_test_urls = true
		updater.manifest_url = "http://127.0.0.1:18763/bad-manifest.json"
		updater.check_updates()
		await _wait_request(updater)
		updater.download_update()
		await _wait_request(updater)
		_check(not updater.pending_reload and updater.status.text.contains("校验失败"), "Bad network checksum rejected")
		_check(FileAccess.get_file_as_bytes(TEST_ROOT + "/active.json") == installed, "Checksum failure retains installed snapshot")
	var newer := bundle.duplicate(true)
	newer.data_version = 5
	_check(DataStore.install(_bytes(newer)).is_empty(), "Next valid data revision installs")
	_check(JSON.parse_string(FileAccess.get_file_as_string(TEST_ROOT + "/previous.json")).data_version == 4, "Previous snapshot retained before replacement")
	_write(TEST_ROOT + "/active.json", "corrupted local file".to_utf8_buffer())
	DataStore.reset_cache()
	_check(DataStore.metadata().data_version == 3 and not DataStore.last_error.is_empty(), "Corrupt local data falls back to built-in data")
	_write(TEST_ROOT + "/active.json", installed)
	DataStore.reset_cache()
	_check(DataStore.metadata().data_version == 4, "Valid snapshot remains readable after fallback")
	_check(not updater.has_method("import_file") and not updater.has_method("restore_builtin"), "Removed local update actions have no handlers")
	_check(not updater.has_node("ImportDialog") and not updater.has_node("Surface/Margin/Content/LocalActions"), "Removed local update controls are absent from scene")
	_cleanup()
	print("DATA_UPDATE_SMOKE: %s; failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _cleanup() -> void:
	if is_instance_valid(scene):
		scene.free()
	for name in ["active.json", "active.json.tmp", "previous.json", "disabled.json"]:
		var path := TEST_ROOT.path_join(name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for path in [PLANS, PLANS + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DataStore.storage_root = old_root
	DataStore.reset_cache()
