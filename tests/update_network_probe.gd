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
	updater.check_updates()
	var deadline := Time.get_ticks_msec() + 40000
	while not updater.phase.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if updater.latest.is_empty():
		push_error("LIVE_UPDATE_CHECK_FAILED: " + updater.status.text)
		quit(1)
		return
	print("LIVE_UPDATE_CHECK_PASS proxy=", not updater.network_proxy.is_empty(), " version=", updater.latest.version_name)
	updater.request.request_completed.disconnect(updater._completed)
	updater.request.body_size_limit = Store.MAX_PACKAGE_BYTES
	var error: int = updater._send_request(updater.latest.package_url)
	if error != OK:
		quit(1)
		return
	var response: Array = await updater.request.request_completed
	var bytes: PackedByteArray = response[3]
	var valid: bool = response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200 and bytes.size() == int(updater.latest.size) and Store.sha256(bytes) == updater.latest.sha256
	if valid:
		valid = Store.validate_bundle(Store.parse_json(bytes.get_string_from_utf8())).is_empty()
	print("LIVE_UPDATE_PACKAGE_PASS=", valid, " bytes=", bytes.size())
	updater.queue_free()
	quit(0 if valid else 1)
