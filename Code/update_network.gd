extends RefCounted
## 跟随已启用的 Windows 手动代理；其他平台兼容 HTTP(S)_PROXY。

static func parse_proxy(value: String) -> Dictionary:
	var candidate := value.strip_edges()
	if candidate.contains(";") or candidate.begins_with("https=") or candidate.begins_with("http="):
		var protocols := {}
		for part in candidate.split(";"):
			var pair := part.split("=", true, 1)
			if pair.size() == 2:
				protocols[pair[0].strip_edges()] = pair[1].strip_edges()
		candidate = str(protocols.get("https", protocols.get("http", "")))
	if candidate.begins_with("http://"):
		candidate = candidate.trim_prefix("http://").trim_suffix("/")
	# HTTP CONNECT 代理；不把 SOCKS、带凭据或 PAC 地址误当成 HTTP 代理。
	if candidate.contains("/") or candidate.contains("@"):
		return {}
	var separator := candidate.rfind(":")
	if separator <= 0:
		return {}
	var host := candidate.left(separator)
	var port := candidate.substr(separator + 1)
	if not port.is_valid_int() or int(port) < 1 or int(port) > 65535:
		return {}
	return {"host": host, "port": int(port)}


static func detect_proxy() -> Dictionary:
	if OS.get_name() == "Windows":
		var output: Array = []
		var exit_code := OS.execute("reg.exe", ["query", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"], output, false, false)
		if exit_code == 0:
			var enabled := false
			var server := ""
			for line in "\n".join(output).split("\n"):
				var trimmed := line.strip_edges()
				if trimmed.begins_with("ProxyEnable "):
					enabled = trimmed.ends_with("0x1")
				elif trimmed.begins_with("ProxyServer "):
					var marker := trimmed.find("REG_SZ")
					if marker >= 0:
						server = trimmed.substr(marker + 6).strip_edges()
			if enabled:
				var proxy := parse_proxy(server)
				if not proxy.is_empty():
					return proxy
	for name in ["HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy"]:
		var proxy := parse_proxy(OS.get_environment(name))
		if not proxy.is_empty():
			return proxy
	return {}


static func error_message(result: int, code: int) -> String:
	if result == HTTPRequest.RESULT_SUCCESS:
		if code == 404:
			return "找不到更新文件（HTTP 404），请检查完整版本文件网址。"
		return "更新服务器返回 HTTP %d。" % code
	var reasons := {
		HTTPRequest.RESULT_CANT_RESOLVE: "更新域名解析失败，请检查 DNS 或网络。",
		HTTPRequest.RESULT_CANT_CONNECT: "无法连接更新服务器，请检查网络或代理。",
		HTTPRequest.RESULT_CONNECTION_ERROR: "更新连接中断，请稍后重试。",
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "HTTPS 证书握手失败，请检查系统时间及代理证书。",
		HTTPRequest.RESULT_TIMEOUT: "连接更新服务器超时，请检查网络或代理。",
		HTTPRequest.RESULT_NO_RESPONSE: "更新服务器未响应，请稍后重试。",
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: "更新文件超出大小限制。",
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED: "更新文件解压失败，请重新下载。",
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: "更新网址重定向次数过多。"
	}
	return str(reasons.get(result, "数据更新网络请求失败（错误 %d）。" % result))
