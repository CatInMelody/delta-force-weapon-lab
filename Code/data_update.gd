extends Control
## 数据包下载/导入后写入本机；重新加载界面才切换到完整新快照。

const DataStore = preload("res://Code/data_store.gd")
const UpdateNetwork = preload("res://Code/update_network.gd")
const ReleaseInfo = preload("res://Code/release_info.gd")
@export var manifest_url := ""
var allow_local_test_urls := false
var phase := ""
var latest: Dictionary = {}
var pending_reload := false
var network_proxy: Dictionary = {}
var using_proxy := false
var retried_direct := false
var request_url := ""
var request_headers := PackedStringArray()
@onready var request: HTTPRequest = $HTTPRequest
@onready var status: Label = $Surface/Margin/Content/Status
@onready var version: Label = $Surface/Margin/Content/Version
@onready var data_version: Label = $Surface/Margin/Content/DataVersion
@onready var notes: Label = $Surface/Margin/Content/Notes
@onready var check_button: Button = $Surface/Margin/Content/Actions/Check
@onready var download_button: Button = $Surface/Margin/Content/Actions/Download
@onready var reload_button: Button = $Surface/Margin/Content/Reload


func _ready() -> void:
	network_proxy = UpdateNetwork.detect_proxy()
	if manifest_url.is_empty():
		manifest_url = str(DataStore.builtin_json("res://data/update_config.json").get("manifest_url", ""))
	var meta := DataStore.metadata()
	version.text = "当前程序：V%s\n当前赛季%s" % [ReleaseInfo.VERSION, str(meta["season"])]
	data_version.text = "数据版本：%s（%d）" % [str(meta["version_name"]), int(meta["data_version"])]
	if not DataStore.last_error.is_empty():
		status.text = DataStore.last_error
	elif manifest_url.is_empty():
		status.text = "在线更新地址尚未配置。"
	check_button.pressed.connect(check_updates)
	download_button.pressed.connect(download_update)
	reload_button.pressed.connect(reload_data)
	request.request_completed.connect(_completed)
	visibility_changed.connect(_update_progress)
	_set_busy(false)


func _allowed_url(url: String) -> bool:
	return url.begins_with("https://") or (allow_local_test_urls and url.begins_with("http://127.0.0.1:"))


func _set_busy(busy: bool) -> void:
	check_button.disabled = busy or pending_reload
	download_button.disabled = busy or pending_reload or latest.is_empty()
	reload_button.visible = pending_reload


func _process(_delta: float) -> void:
	if phase == "package" and is_visible_in_tree():
		_update_progress()


func _update_progress() -> void:
	if phase == "package" and is_instance_valid(request):
		status.text = "正在下载数据：%d / %d KiB" % [request.get_downloaded_bytes() / 1024, int(latest.get("size", 0)) / 1024]


func check_updates() -> void:
	if not phase.is_empty() or pending_reload:
		return
	latest = {}
	notes.text = ""
	if not _allowed_url(manifest_url):
		status.text = "尚未配置有效的HTTPS更新地址。"
		_set_busy(false)
		return
	phase = "manifest"
	status.text = "正在检查数据更新…"
	request.body_size_limit = 128 * 1024
	_set_busy(true)
	retried_direct = false
	if _send_request(manifest_url, PackedStringArray(["Cache-Control: no-cache"])) != OK:
		_fail("无法发起更新检查，请稍后重试。")


func _manifest_error(value: Variant) -> String:
	if not value is Dictionary or value.get("schema_version") != 1 or not DataStore._integer(value.get("data_version"), 1, 2147483647):
		return "版本信息格式无效。"
	if not DataStore._integer(value.get("min_data_api", 1), 1, DataStore.API_VERSION):
		return "此次数据更新需要新版程序，请点击下方“检查程序更新”。"
	for key in ["version_name", "season", "package_url", "sha256"]:
		if not value.get(key) is String or value[key].is_empty():
			return "版本信息缺少字段：" + key
	if not value.get("notes", "") is String or not DataStore._number(value.get("size"), 1, DataStore.MAX_PACKAGE_BYTES):
		return "更新包大小或说明无效。"
	if value["sha256"].length() != 64 or not value["sha256"].is_valid_hex_number(false):
		return "更新包校验值无效。"
	return ""


func download_update() -> void:
	if latest.is_empty() or not phase.is_empty() or pending_reload:
		return
	phase = "package"
	request.body_size_limit = DataStore.MAX_PACKAGE_BYTES
	_set_busy(true)
	status.text = "正在下载数据更新…"
	retried_direct = false
	if _send_request(latest["package_url"]) != OK:
		_fail("无法开始下载，请稍后重试。")


func _send_request(url: String, headers := PackedStringArray(), permit_proxy := true) -> Error:
	request_url = url
	request_headers = headers
	using_proxy = permit_proxy and not network_proxy.is_empty() and not url.begins_with("http://127.0.0.1:")
	var host := str(network_proxy.get("host", "")) if using_proxy else ""
	var port := int(network_proxy.get("port", -1)) if using_proxy else -1
	request.set_http_proxy(host, port)
	request.set_https_proxy(host, port)
	return request.request(url, headers)


func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# 代理关闭或失效时再尝试直连，不影响无需代理的用户。
	if using_proxy and not retried_direct and result in [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR, HTTPRequest.RESULT_NO_RESPONSE, HTTPRequest.RESULT_TIMEOUT]:
		retried_direct = true
		status.text = "代理连接失败，正在尝试直接连接…"
		if _send_request(request_url, request_headers, false) == OK:
			return
	var completed_phase := phase
	phase = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail(UpdateNetwork.error_message(result, code) + "现有数据仍可使用。")
		return
	if completed_phase == "manifest":
		var value = DataStore.parse_json(body.get_string_from_utf8())
		var error := _manifest_error(value)
		if not error.is_empty():
			_fail(error)
			return
		if int(value["data_version"]) <= int(DataStore.metadata()["data_version"]):
			status.text = "当前数据已是最新版本。"
			_set_busy(false)
			return
		var url: String = value["package_url"]
		if not url.contains(":") and not url.begins_with("/") and not url.contains(".."):
			url = manifest_url.get_base_dir().path_join(url)
		if not _allowed_url(url):
			_fail("下载地址无效。")
			return
		latest = value
		latest["package_url"] = url
		status.text = "发现数据更新：%s（%.1f KiB）" % [value["version_name"], float(value["size"]) / 1024.0]
		notes.text = str(value.get("notes", "")).left(1000)
		_set_busy(false)
	elif completed_phase == "package":
		if body.size() != int(latest["size"]) or DataStore.sha256(body) != str(latest["sha256"]).to_lower():
			_fail("更新包校验失败，未修改原有数据。")
			return
		var value = DataStore.parse_json(body.get_string_from_utf8())
		if not value is Dictionary or value.get("data_version") != latest["data_version"] or value.get("version_name") != latest["version_name"] or value.get("season") != latest["season"]:
			_fail("数据包与版本信息不一致，未安装。")
			return
		_install(body)


func _install(bytes: PackedByteArray) -> void:
	var error := DataStore.install(bytes)
	if not error.is_empty():
		_fail("未安装更新：" + error)
		return
	pending_reload = true
	status.text = "数据更新已保存，点击“重新加载数据”后生效。改枪码会保留。"
	_set_busy(false)


func reload_data() -> void:
	get_node("../Information/BuildCode")._save_codes()
	get_tree().reload_current_scene()


func _fail(message: String) -> void:
	phase = ""
	status.text = message
	_set_busy(false)
