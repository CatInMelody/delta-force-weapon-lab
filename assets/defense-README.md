# 三角洲行动护甲与头盔图片

采集日期：2026-10-24。
共 53 张原始透明背景 PNG：Armor 26 件护甲，Helmet 27 件头盔/头部防具。
每件装备保存一个基础物品原图，包含 1—6 级装备、夜视头盔、帽子和赤枭头甲，不按耐久状态重复保存。

图片均来自腾讯 playerhub.df.qq.com 公开 CDN，保留原始字节、尺寸和透明通道，没有裁切、放大或重绘。
文件用物品名称命名，移除名称中的空格，例如 Armor/金刚防弹衣.png、Helmet/H70夜视精英头盔.png。

核对过程：
- DFTTK 防具计算目录列出 25 件护甲、26 件头盔。
- 中文物品目录额外列出赤枭重装突击背心、赤枭装甲防弹面具。
- 这两件装备另与独立物品图鉴及赛季装备介绍交叉核对，补入对应分类。
- 使用独立防具数据集及 Wiki 核对其他物品 ID 和名称。
- 部分装备存在新旧名称差异，如“泰坦防弹装甲/犀牛重型防弹衣”，按同一物品 ID 保存一次，别名记录在清单中。

清单文件：
- defense-sources.json：名称、别名、物品 ID、等级、原图来源、尺寸、透明通道、SHA-256。
- 旧 CSV 简表已清理，来源和物品映射以 JSON 为准。

资料入口：
- https://dfttk.com/data/v3/combat/defense/armors.json
- https://dfttk.com/data/v3/combat/defense/helmets.json
- https://dfttk.com/data/v3/locales/zh-CN/items.json
- https://github.com/jiansenc/DeltaForceData
- https://sjzwiki.com/game/armor
- https://sjzwiki.com/game/helmets
- https://orzice.com/v/info/p1388
- https://news.17173.com/content/01232026/233446084.shtml
