extends VBoxContainer
## 只查询公开 Releases；下载交给浏览器，程序不保存 GitHub 凭据。

const ReleaseInfo = preload("res://Code/release_info.gd")
const UpdateNetwork = preload("res://Code/update_network.gd")
var busy := false
var latest: Dictionary = {}
var proxy: Dictionary = {}
var using_proxy := false
var retried_direct := false
@onready var request: HTTPRequest = $HTTPRequest
@onready var status: Label = $Status
@onready var check_button: Button = $Actions/Check
@onready var download_button: Button = $Actions/Download


func _ready() -> void:
	proxy = UpdateNetwork.detect_proxy()
	check_button.pressed.connect(check_updates)
	download_button.pressed.connect(download_update)
	request.request_completed.connect(_completed)
	$Links/Source.pressed.connect(func(): OS.shell_open(ReleaseInfo.REPOSITORY_URL))
	$Links/Licenses.pressed.connect(_show_licenses)


static func version_parts(value: String) -> Array[int]:
	var parts := value.trim_prefix("v").split(".")
	if parts.size() != 3:
		return []
	var result: Array[int] = []
	for part in parts:
		if part.is_empty() or not part.is_valid_int() or int(part) < 0 or str(int(part)) != part:
			return []
		result.append(int(part))
	return result


static func is_newer(candidate: String, current: String) -> bool:
	var left := version_parts(candidate)
	var right := version_parts(current)
	if left.size() != 3 or right.size() != 3:
		return false
	for index in range(3):
		if left[index] != right[index]:
			return left[index] > right[index]
	return false


static func parse_release(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("draft", false) or value.get("prerelease", false):
		return {}
	var tag := str(value.get("tag_name", ""))
	if version_parts(tag).size() != 3 or not value.get("assets") is Array:
		return {}
	var prefix := ReleaseInfo.REPOSITORY_URL + "/releases/download/" + tag.uri_encode() + "/"
	for asset in value.assets:
		if not asset is Dictionary or asset.get("state") != "uploaded":
			continue
		var name := str(asset.get("name", ""))
		var url := str(asset.get("browser_download_url", ""))
		if name.to_lower().ends_with(".exe") and url.begins_with(prefix) and not url.contains("?") and not url.contains("#"):
			return {"version": tag.trim_prefix("v"), "url": url, "notes": str(value.get("body", "")).left(1500)}
	return {}


func check_updates() -> void:
	if busy:
		return
	latest = {}
	busy = true
	check_button.disabled = true
	download_button.disabled = true
	status.text = "正在检查 GitHub 程序更新…"
	retried_direct = false
	if _send_request(true) != OK:
		_finish("无法开始检查程序更新。数据更新仍可独立使用。")


func _send_request(permit_proxy: bool) -> Error:
	using_proxy = permit_proxy and not proxy.is_empty()
	var host := str(proxy.get("host", "")) if using_proxy else ""
	var port := int(proxy.get("port", -1)) if using_proxy else -1
	request.set_http_proxy(host, port)
	request.set_https_proxy(host, port)
	return request.request(ReleaseInfo.API_URL, PackedStringArray([
		"Accept: application/vnd.github+json", "User-Agent: DeltaForceWeaponLab/" + ReleaseInfo.VERSION,
		"X-GitHub-Api-Version: 2022-11-28", "Cache-Control: no-cache"
	]))


func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if using_proxy and not retried_direct and result != HTTPRequest.RESULT_SUCCESS:
		retried_direct = true
		status.text = "代理连接失败，正在尝试直接连接 GitHub…"
		if _send_request(false) == OK:
			return
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish(UpdateNetwork.error_message(result, code) + "可从项目主页下载程序。")
		return
	if code == 404:
		_finish("GitHub 尚无公开正式版本。可从项目主页查看发布情况。")
		return
	if code in [403, 429]:
		_finish("GitHub 请求暂受限制，请稍后重试或从项目主页下载。")
		return
	if code != 200:
		_finish("GitHub 返回 HTTP %d。数据更新仍可独立使用。" % code)
		return
	var parsed := parse_release(JSON.parse_string(body.get_string_from_utf8()))
	if parsed.is_empty():
		_finish("GitHub 版本信息无效或没有 Windows EXE，请从项目主页查看。")
		return
	if not is_newer(parsed.version, ReleaseInfo.VERSION):
		_finish("当前程序已是最新版本（V%s）。" % ReleaseInfo.VERSION)
		return
	latest = parsed
	download_button.disabled = false
	_finish("发现新版程序 V%s，点击下载后关闭旧版并替换 EXE。个人方案会保留。" % latest.version)
	status.tooltip_text = latest.notes


func _finish(message: String) -> void:
	busy = false
	check_button.disabled = false
	status.text = message


func download_update() -> void:
	if latest.is_empty() or busy:
		return
	if OS.shell_open(str(latest.url)) != OK:
		status.text = "无法打开浏览器，请通过项目主页下载新版程序。"


func _show_licenses() -> void:
	$LicenseDialog/Content.text = FileAccess.get_file_as_string("res://licenses/Godot-LICENSE.txt") + "\n\n" + FileAccess.get_file_as_string("res://licenses/Godot-COPYRIGHT.txt")
	$LicenseDialog.popup_centered(Vector2i(800, 520))
