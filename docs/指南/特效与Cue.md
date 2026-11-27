# 给游戏加特效（GameplayCue）

> 类型：指南 | 状态：有效 | 核对：2026-11-27
> 何时读：新增/调试 GameplayCue 特效
> 关键词：特效 GameplayCue Cue 场景 对象池 补间 注册 挂钩 灼烧 剧毒 冻结 爪痕 hit_cue_tag 命中特效 mod 内置 core manifest
> 代码：`base_mods/core/mod.json`、`godot_gas/cue_registry.tres`、`addons/GodotGAS/cues/gameplay_cue_notify.gd`、`scripts/mod/mod_cue_registrar.gd`
> 相关：`架构/GAS.md`

## 1. 机制与接线三步

Cue 是「标签 → 场景」映射，挂在目标单位下（`(0, 0)` 即单位位置），播完还对象池复用；单位销毁时随之销毁。启动时 `GameplayCueManager` 读空的 `godot_gas/cue_registry.tres`，`ModCueRegistrar` 随后注册 core 与第三方 mod 的 Cue，并校验 `hit_cue_tag` 与效果 Cue 字段（缺失记入 `ModLoader.get_errors()`）。

| 步骤 | 做法 | 约束 / 入口 |
|---|---|---|
| 1. 写场景 | 根节点继承 `GameplayCueNotify`，重写 `play_cue()` | 3D 内置特效由 `windows/Battle/view_3d/battle_3d_bridge.gd` 与 `battle_fx_pool.gd` 驱动；第三方 2D/自定义 Cue 放 `content/cues/`。因对象池复用，`play_cue()` 开头必须 `kill()` 旧 `_tween` 并复位属性 |
| 2. 登记 | 在 `mod.json` 的 `content.cues` 填 `{ "tag", "scene" }` | 官方写 `base_mods/core/mod.json`（全局标签无前缀）；第三方标签须为 `Cue.Mod.<PascalModId>.<Name>`；勿往 `godot_gas/cue_registry.tres` 加官方 Cue |
| 3. 挂钩 | 挂到 `GameplayEffect` 四类字段或技能 `UnitSkillStep.hit_cue_tag` | 见下表与 §2；内置示例以 `base_mods/core/mod.json` 和 `effects/*.tres` 为准 |

| `GameplayEffect` 字段 | 触发时机 | 典型用途 |
|---|---|---|
| `application_cue_tags` | 施加时（重复施加刷新周期效果也会再触发） | 命中火花、施毒爆发、受击音效 |
| `persistent_cue_tags` | 持续期间常驻（效果被压制时自动暂停） | Buff 光环、灼烧/剧毒常驻特效 |
| `periodic_cue_tags` | 每次周期 tick | 中毒/灼烧跳字闪光 |
| `removal_cue_tags` | 效果结束时 | 光环消散 |

## 2. 代码触发、Payload 与基类要点

- **手动触发**：`unit.asc.execute_cue(&"Cue.Combat.Hit", payload)`；技能内部用 `execute_cue(tag)`（等价于 `owner_asc.execute_cue`）。
- **读取 Payload**：基类不向 `play_cue()` 传 payload，需重写 `execute_cue(target, payload)` 先存字段再调 `super.execute_cue(target, payload)`。
- **技能命中特效**：`UnitSkillStep.hit_cue_tag` 由 `AutoCastAbility` 触发并传 `{"direction": ±1.0}`（按每颗魂灵命中次数交替，打空不计数）；若该击击杀目标导致单位当场 `queue_free()`，改挂到战场单位层并传 `{"position": 世界坐标}`。
- **基类成员**：`finish_cue()` 提前还池（适合连 `AudioStreamPlayer.finished`）；持续型设 `auto_destroy = false`，在 `end_cue()` 做淡出收尾；`destroy_delay`（默认 2.0）是还池超时，不是动画时长；`gameplay_cue_tag` 为本次触发标签。
- **UI 魂灵例外**：魂灵格子是 `Control` 而非战场节点，冻结走 `SoulRuntime.freeze_seconds` 驱动 `soul_scanline.gdshader` 与 `game/content/Kits/bingdong.tscn`，不走 Cue。

## 3. 踩坑与排查

| 现象 / 坑 | 原因与规避 |
|---|---|
| 复用时残留上次动画 | `destroy_delay` 短于动画时长；必须 `destroy_delay >= 动画时长` 且 `play_cue()` 开头 `kill()` 旧补间并复位 |
| 还池后节点仍可见 | 管理器还池只设 `process_mode = DISABLED` 并隐藏**直接子节点**；可视节点须为直接子节点或自行在 `end_cue()` 隐藏 |
| 静默不播且无报错 | `GameplayCueManager` 查不到标签直接 return；先查 `GameplayCueManager._cue_scenes.has(tag)` 与大小写/层级（建议在 `godot_gas/tag_registry.tres` 登记以获补全） |
| 视觉太小太淡看不见 | 透明度先保持 1～2 帧满不透明再淡出；排查顺序：`._cue_scenes.has(tag)` → `play_cue()` 打点 → 钉死大尺寸/满 alpha 后在 `frame_post_draw` 读 `get_viewport().get_texture().get_image().get_pixel()` |
