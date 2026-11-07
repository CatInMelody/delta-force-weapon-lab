extends "res://tests/choose_smoke.gd"

const ProgramUpdate = preload("res://Code/program_update.gd")
const ReleaseInfo = preload("res://Code/release_info.gd")


func _release(tag: String) -> Dictionary:
	return {"tag_name": tag, "draft": false, "prerelease": false, "body": "测试更新说明", "assets": [
		{"name": "WeaponLab.exe", "state": "uploaded", "browser_download_url": ReleaseInfo.REPOSITORY_URL + "/releases/download/" + tag + "/WeaponLab.exe"}
	]}


func _run() -> void:
	root.size = Vector2i(1152, 648)
	scene = load("res://Scene/main.tscn").instantiate()
	scene.get_node("Information/BuildCode").save_path = "user://program_update_smoke_plans.json"
	root.add_child(scene)
	await _frames()
	scene._show_page("Update")
	var updater: VBoxContainer = scene.get_node("Update/Surface/Margin/Content/Program")
	var data_updater: Control = scene.get_node("Update")
	_check(ProgramUpdate.is_newer("v1.10.0", "1.9.9"), "Numeric semantic versions avoid string sorting")
	_check(not ProgramUpdate.is_newer("v1.1.0", "1.1.0"), "Same version does not prompt")
	_check(not ProgramUpdate.is_newer("v1.0.9", "1.1.0"), "Older release does not downgrade")
	_check(not ProgramUpdate.is_newer("v2.0.0-rc1", "1.1.0"), "Unsupported prerelease rejected")
	var release := _release("v1.2.0")
	_check(not ProgramUpdate.parse_release(release).is_empty(), "Public Windows EXE accepted")
	var hostile := release.duplicate(true)
	hostile.assets[0].browser_download_url = "https://example.com/WeaponLab.exe"
	_check(ProgramUpdate.parse_release(hostile).is_empty(), "External download link rejected")
	hostile = release.duplicate(true)
	hostile.prerelease = true
	_check(ProgramUpdate.parse_release(hostile).is_empty(), "Preview release rejected")
	updater._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(release).to_utf8_buffer())
	_check(updater.latest.version == "1.2.0" and not updater.download_button.disabled, "New version enables download")
	_check(data_updater.latest.is_empty() and data_updater.phase.is_empty(), "Program check leaves data updater independent")
	updater.latest = {}
	updater.download_button.disabled = true
	updater._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(_release("v" + ReleaseInfo.VERSION)).to_utf8_buffer())
	_check(updater.status.text.contains("最新版本") and updater.download_button.disabled, "Installed version remains current")
	updater._completed(HTTPRequest.RESULT_SUCCESS, 403, PackedStringArray(), PackedByteArray())
	_check(updater.status.text.contains("受限制") and not updater.check_button.disabled, "Rate limit is actionable and retryable")
	updater._completed(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())
	_check(updater.status.text.contains("超时"), "Transport failure distinguished from HTTP status")
	updater._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer())
	_check(updater.status.text.contains("无效"), "Malformed release rejected")
	updater.status.text = "当前程序已是最新版本（V%s）。" % ReleaseInfo.VERSION
	_check(FileAccess.get_file_as_string("res://licenses/Godot-LICENSE.txt").contains("MIT"), "Godot license bundled for standalone EXE")
	_check(FileAccess.get_file_as_string("res://licenses/Godot-COPYRIGHT.txt").length() > 10000, "Third party notices bundled")
	await _capture("program-update")
	var content: VBoxContainer = scene.get_node("Update/Surface/Margin/Content")
	_check(content.size.y <= scene.get_node("Update").size.y, "Update sections fit available height")
	if "--online-test" in OS.get_cmdline_user_args():
		updater.check_updates()
		var deadline := Time.get_ticks_msec() + 40000
		while updater.busy and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		_check(not updater.busy and updater.status.text.contains("最新版本"), "Live GitHub latest release reaches current version")
		print("PROGRAM_ONLINE: ", updater.status.text)
	print("PROGRAM_UPDATE_SMOKE: %d failures" % failures.size())
	scene.queue_free()
	await _frames()
	quit(0 if failures.is_empty() else 1)
