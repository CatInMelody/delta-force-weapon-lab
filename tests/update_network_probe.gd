extends SceneTree

const Network = preload("res://Code/update_network.gd")
const Store = preload("res://Code/data_store.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(Network.parse_proxy("http://127.0.0.1:7890").port == 7890)
	assert(Network.parse_proxy("http=localhost:123;https=localhost:456").port == 456)
	assert(Network.parse_proxy("socks5://localhost:123").is_empty())
	assert(Network.parse_proxy("http://user:secret@localhost:123").is_empty())
	assert(Network.parse_proxy("localhost:99999").is_empty())
	assert(Network.error_message(HTTPRequest.RESULT_TIMEOUT, 0).contains("超时"))
	assert(Network.error_message(HTTPRequest.RESULT_CANT_RESOLVE, 0).contains("域名"))
	assert(Network.error_message(HTTPRequest.RESULT_SUCCESS, 404).contains("更新文件"))
	var updater: Control = load("res://Scene/update.tscn").instantiate()
	root.add_child(updater)
	var responses: Array = []
	updater.request.request_completed.connect(func(result, code, headers, body): responses.append([result, code, headers, body]))
	updater.check_updates()
	var deadline := Time.get_ticks_msec() + 40000
	while not updater.phase.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if responses.is_empty() or (updater.latest.is_empty() and not updater.status.text.contains("最新版本")):
		push_error("LIVE_UPDATE_CHECK_FAILED: " + updater.status.text)
		quit(1)
		return
	var manifest: Dictionary = Store.parse_json(responses.back()[3].get_string_from_utf8())
	if not updater._manifest_error(manifest).is_empty():
		push_error("LIVE_UPDATE_MANIFEST_INVALID")
		quit(1)
		return
	var package_url: String = manifest.package_url
	if not package_url.contains(":"):
		package_url = updater.manifest_url.get_base_dir().path_join(package_url)
	print("LIVE_UPDATE_CHECK_PASS proxy=", not updater.network_proxy.is_empty(), " version=", manifest.version_name)
	updater.request.request_completed.disconnect(updater._completed)
	updater.request.body_size_limit = Store.MAX_PACKAGE_BYTES
	var error: int = updater._send_request(package_url)
	if error != OK:
		quit(1)
		return
	var response: Array = await updater.request.request_completed
	var bytes: PackedByteArray = response[3]
	var valid: bool = response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200 and bytes.size() == int(manifest.size) and Store.sha256(bytes) == manifest.sha256
	if valid:
		valid = Store.validate_bundle(Store.parse_json(bytes.get_string_from_utf8())).is_empty()
	print("LIVE_UPDATE_PACKAGE_PASS=", valid, " bytes=", bytes.size())
	updater.queue_free()
	quit(0 if valid else 1)
