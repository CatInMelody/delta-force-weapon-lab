# 特殊弹药独立图标

来源核对日期：2026-10-26。6个文件，96×96，原始WebP，透明底。

| 弹药 | 文件名 |
|---|---|
| 5.7x28mm HT+ | 5.7x28mm-HT-plus.webp |
| 5.7x28mm HT | 5.7x28mm-HT.webp |
| 4.6x30mm AP ST | 4.6x30mm-AP-ST.webp |
| 4.6x30mm CT | 4.6x30mm-CT.webp |
| 4.6x30mm FMJ ST | 4.6x30mm-FMJ-ST.webp |
| 7.62x51mm LS | 7.62x51mm-LS.webp |

AP ST与FMJ ST在来源中共用同一张图片，两个文件内容相同。

名称、物品ID和图片地址逐项核对：[数据库弹药目录](https://deltaforce.th.gl/zh-CN/db/ammo)。
来源与哈希、Godot路径见 `special-ammo-icons.json`。

Godot对应路径：`res://assets/Bullet/Special/文件名.webp`。
项目选择器已按物品 ID 接入此映射，优先使用这 6 张独立图标；其他子弹继续使用通用口径图标。0级子弹使用蓝色背景，穿透等级仍为0。

## S12 补充

300BLK-TIV.webp、300BLK-TTV.webp、545-SPALL.webp 来自用户提供的原图，以无损 WebP 保存。556-CINDER.webp 使用用户指定的红色包装图标；300BLK-TTV.webp 使用用户指定的绿色包装图标。当前物品映射及伤害机制以 JSON 为准。
