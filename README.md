# 三角洲武器实验室

基于 Godot 4.7.1 的 Windows 武器信息工具，当前程序版本 **V1.1.0 / S12**。

[下载最新 EXE](https://github.com/CatInMelody/delta-force-weapon-lab/releases/latest)

## 使用

下载 Releases 中的 EXE 即可运行，无需解压或安装 Godot。包含武器信息、个人改枪方案、双枪对比、肉伤/甲伤排行与更新页面。数值刷新保留逐文本白色扫光动画。

- **程序更新**：在“更新”页点击“检查程序更新”，从 GitHub Releases 下载新版 EXE，关闭旧版后替换。
- **数据更新**：在同一页面检查、下载 Cloudflare 数据包，再点击“重新加载数据”。只调整已支持的武器、弹药、防具数值和图片时无需替换 EXE。
- 方案 A/B/C 及自定义标题保存在本机 Godot 用户目录，更新 EXE 时保留；不要主动删除该目录。
- 两种检查互相独立，检查失败仍可离线使用已有数据。新增计算机制或界面需要程序更新。

旧版程序需要手动下载一次 V1.1.0，才能使用 GitHub 程序更新入口。程序检查不要求用户登录，也不包含发布账号的令牌。

数据可能存在误差，仅供参考。本项目不是游戏官方工具。

## 开发与导出

使用 Godot 4.7.1 打开 `project.godot`。纯 GDScript，无需 .NET。界面节点位于 `Scene/`，计算和更新逻辑位于 `Code/`，JSON 位于 `data/`。

默认使用 Compatibility / OpenGL 和不可拖动缩放的窗口。导出为未加密的单个 EXE，Godot 与第三方许可已内置，可在更新页面查看。

精简模板需安装 Visual Studio 2022 C++、Windows SDK、Python 与 SCons，再执行：

```powershell
./tools/build_release.ps1 -GodotEditor '你的 Godot 控制台程序路径' -CompileTemplate
```

以后仅改项目时去掉 `-CompileTemplate`。也可以在 Godot 导出设置中清空自定义模板路径，改用匹配版本的官方导出模板；不要上传模板二进制到源码仓库。

验证示例：

```powershell
godot --headless --path . --script res://tests/program_update_smoke.gd
godot --headless --path . --script res://tests/damage_smoke.gd
godot --headless --path . --script res://tests/s12_smoke.gd
```

发布步骤见 [发布数据更新.md](发布数据更新.md)。程序版本常量在 `Code/release_info.gd`，导出文件版本在 `export_presets.cfg`。

## 发布边界

源码仓库不包含 `.private`、`.godot`、密钥、导出凭据、部署令牌、构建缓存与导出二进制。EXE 通过 Releases 发布；Cloudflare 只上传 `publish/` 中公开的数据文件。

Godot 及第三方组件的许可见 `licenses/`。游戏名称、图片等素材的相关权利属于各自权利人；这些素材不因本仓库公开而自动获得新的许可。项目源码许可证尚未单独指定。
