extends Node
## Copy into Code temporarily for a QA export; never include in production.

const Store = preload("res://Code/data_store.gd")
const TEST_ROOT := "user://plain_release_qa"
const TEST_PLANS := "user://plain_release_qa_plans.json"
var failures: Array[String] = []
var scene: Control
@onready var window: Window = get_tree().root

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		push_error(description)

func frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func capture(name: String) -> void:
	await frames()
	RenderingServer.force_draw()
	var output := OS.get_environment("WEAPON_LAB_QA_OUTPUT")
	if not output.is_empty():
		window.get_texture().get_image().save_png(output.path_join("release-" + name + ".png"))

func wait_request(updater: Control) -> void:
	var deadline := Time.get_ticks_msec() + 40000
	while not updater.phase.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
	check(updater.phase.is_empty(), "Network request finishes")

func _run() -> void:
	print("PLAIN_RELEASE_QA_START")
	if FileAccess.file_exists(TEST_ROOT + "/active.json") or FileAccess.file_exists(TEST_PLANS):
		push_error("Pre-existing isolated QA save found; preserve it and inspect")
		get_tree().quit(1)
		return
	Store.storage_root = TEST_ROOT
	scene = load("res://Scene/main.tscn").instantiate()
	scene.get_node("Information/BuildCode").save_path = TEST_PLANS
	add_child(scene)
	await frames()
	check(window.unresizable, "Window border resizing remains disabled")
	check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "Compatibility renderer retained")
	for file in Store.FILES:
		check(not Store.read_json("res://" + file).is_empty(), "Runtime JSON readable")
	check(not FileAccess.file_exists("res://.private/pck-encryption.gdkey"), "Private key excluded")
	var choose: Control = scene.get_node("Information/Chosse")
	var info: Control = scene.get_node("Information/GunInformation")
	check(choose.weapons.size() == 74, "74 weapons loaded")
	for item in choose.weapons + choose.helmets + choose.armors:
		check(Store.load_texture(item.icon) != null, "Weapon/defense image readable")
	for weapon in choose.weapons:
		for bullet in choose.get_bullet_choices_for_weapon(weapon):
			check(Store.load_texture(bullet.icon) != null and Store.load_texture(bullet.background) != null, "Bullet icon and background readable")
	choose._select_weapon(choose._find_by_name(choose.weapons, "AWM"))
	check(info.refresh.running and info.refresh.active.size() > 0, "Per-text white flash starts")
	await get_tree().create_timer(0.04).timeout
	await capture("flash")
	await get_tree().create_timer(0.4).timeout
	check(not info.refresh.running, "White flash finishes")
	choose._select_weapon(choose._find_by_name(choose.weapons, "M7"))
	await get_tree().create_timer(0.4).timeout
	var plans: Control = scene.get_node("Information/BuildCode")
	plans.text_a.text = "发布版验证方案"
	plans.text_a.text_changed.emit(plans.text_a.text)
	plans.title_a.text = "验证标题"
	plans.title_a.text_changed.emit(plans.title_a.text)
	plans._save_codes()
	check(FileAccess.file_exists(TEST_PLANS), "Personal plans save in user directory")
	await capture("information")
	for page in ["Compare", "Rank"]:
		scene._show_page(page)
		check(scene.get_node(page).visible, "Panel opens: " + page)
		await capture(page.to_lower())
	check(scene.get_node("Rank").flesh_ranking.size() == 74, "Ranking retains all weapons")
	scene._show_page("Update")
	var updater: Control = scene.get_node("Update")
	updater.check_updates()
	await wait_request(updater)
	check(not updater.latest.is_empty() or updater.status.text.contains("最新版本"), "HTTPS version check works")
	await capture("update")
	var program: VBoxContainer = updater.get_node("Surface/Margin/Content/Program")
	program.check_updates()
	var deadline := Time.get_ticks_msec() + 40000
	while program.busy and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
	check(not program.busy and (program.status.text.contains("最新版本") or program.status.text.contains("尚无公开正式版本")), "GitHub HTTPS release check works")
	program._show_licenses()
	check(program.get_node("LicenseDialog/Content").text.contains("MIT License"), "Standalone EXE includes Godot license")
	program.get_node("LicenseDialog").hide()
	var expected_version := Store.BUILTIN_VERSION
	if not updater.latest.is_empty():
		expected_version = int(updater.latest.data_version)
		updater.download_update()
		await wait_request(updater)
		check(updater.pending_reload, "HTTPS download, checksum and installation work")
	scene.free()
	scene = load("res://Scene/main.tscn").instantiate()
	scene.get_node("Information/BuildCode").save_path = TEST_PLANS
	add_child(scene)
	await frames()
	check(Store.metadata().data_version == expected_version, "Data version retained after reload")
	check(scene.get_node("Information/BuildCode").text_a.text == "发布版验证方案", "Plan survives reload")
	check(scene.get_node("Information/BuildCode").title_a.text == "验证标题", "Title survives reload")
	scene.free()
	for name in ["active.json", "previous.json", "active.json.tmp"]:
		var path := TEST_ROOT.path_join(name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for path in [TEST_PLANS, TEST_PLANS + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PLAIN_RELEASE_QA: ", "PASS" if failures.is_empty() else "FAIL", "; failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
