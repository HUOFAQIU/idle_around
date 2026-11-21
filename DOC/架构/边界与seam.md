# 边界与 seam

> 类型：实现 | 状态：有效 | 核对：2026-11-21
> 何时读：改模块边界、拆分或深化模块、收敛入口、判断某处该不该加 seam 时
> 关键词：seam interface module adapter locality 深模块 边界 autoload TestAPI 重构
> 代码：`Scripts/`、`game/`、`Windows/`、`Main/`
> 相关：`00_总览.md`、`现状与注意.md`、`指南/AI测试接口.md`、`INDEX.md`

## 1. 结论

- 已成立的真 seam：`SaveParticipant`（3 个生产 adapter + fake）、`SaveStorage`（磁盘 / 内存 adapter）、战斗事件总线 + 遥测 adapter、TestAPI 按域拆分（门面浅、域内有 depth）、`BattleClock`（生产/手动两模式）。
- 仍需处理：会话状态所有权分散，UI 持有领域策略；入口与命名不唯一，检索命中多处（命名已收敛一部分）。
- 本文只记录结构判断和证据；具体行为以各模块文档为准。

## 2. 模块判决

| module | interface 规模 | seam / adapters | 测试面 | 判决 |
|---|---|---|---|---|
| SaveManager | 17 公方法 | 组装 `SavePipeline` + 3 个生产 participant | save 域 | 组合根 + 会话状态；对外签名不变 |
| SavePipeline / SaveLoadResult | 9 / 5 字段 | storage ×2 adapter、participant ×3 + fake | save 域 | 深模块：版本/主备回退/顺序集中在内部 |
| SaveStorage / SaveScheduler / SaveDocument | 9 / 5 / 5 | `DiskSaveStorage` / `MemorySaveStorage` | save 域 | 接口薄、实现深；scheduler 的时间由 `tick(delta)` 注入 |
| ModLoader | 15 公方法 | 无接口、无 FS adapter，外部直接调用 | mod 域 | 不是 seam 意义的深模块 |
| ContentKind / ContentKindSpec | enum / 2 static | 非 seam | 无 | 枚举与共享数据表 |
| BattleManager | 16 公方法 | spawn/loot Callable + 事件总线 | battle 域 | 较深，但时钟是静态读 |
| BattleSession | 4 公方法 | `units_root`/`map`/`observers` 注入；直接调用 5 个全局 | battle 域 | 会话状态第三所有者，测试钩子混入 |
| BattleUnit / ChargedAbility | 16 / 22 | `notify_*` 事件出口 | 间接 | 接口偏胖，测试方法在公有面 |
| GameFlow | 10 公方法 | 无注入，直连 SaveManager/GBIS | save 域 | 名义 owner，会话状态不完整 |
| CombatTelemetry | 14 公方法 | port = 事件总线，adapter ×2 | debug 域直读单例 | port 成立，消费者未走接口 |
| TestAPI 门面 | 157 static | 无 | 自身 | 纯转发；depth 在各域 |
| commands | registry 4 / catalog 5 + 域命令 | actions → TestAPI 反向依赖 | 仅补全 | 有意架构债（见 `指南/命令控制台.md`） |
| terminal | Buffer 15 / Parser 3 | 无 adapter | 经 terminal 域 | 行为划分清楚 |
| UI 面板 | — | 多数直调 autoload，节点路径当接口 | window/cube 域 | 薄壳 + 局部胖面板 |

## 3. 问题分级

### P0：阻断可测性或所有权混乱

1. **会话状态三个所有者**：`GameFlow`（状态/角色）、`BattleSession`（run_id/slots/souls/map）、`SaveManager`（活动槽），另外 `BattleWindow` 创建 session。
2. **测试面混进生产类**：`BattleSession::spawn_monster_for_test()`、`get_state()` 快照与 `_test_monster_id` 都在生产类。
3. **UI 持有领域策略**：`MapBoardContent`（自动入槽/满槽留中心/拖拽交接）、`SoulVesselWindow`（容器注册簿记）、`BattleWindow`（魂灵排序 + 每帧刷新）、`CollectionWindow`（标题按钮直调 `unlock_all`）、`ModWindow`（排序合法性校验）。

### P1：边界泄漏与反向依赖

- 存档服务摸 UI/战斗状态：`SaveManager` 查 `GBIS.has_moving_item()`，清 `SoulRuntimeDB` 并广播 `GBIS.sig_inv_refresh`；已限制在组合根，`SavePipeline` 本身不碰这些全局。
- 下层反向依赖上层：`CollectionDB` → `ModLoader` 的 warning 表。
- 编解码耦合运行时：`SaveCodec` 直接查 `CollectionDB` / `MapCatalog`。
- content 反向依赖 battle：`TargetRule::resolve()`、`SkillCastContext`、`SoulTargetRule`。
- 测试用节点路径当接口：`test_api/window.gd`、`test_api/cube.gd`。
- 项目代码写第三方私有字段：`ModCueRegistrar` 写 `GameplayCueManager._cue_scenes`；`DebugWindow` 读 `_cue_scenes`。

### P2：命名与入口（直接影响检索）

- 开战 4 个入口、战斗快照 4 个出口、开窗 5 种写法。
- `tick` 仍有两义：固定 tick 与 `ChargedAbility::tick_charge/tick_status`（单位刻）。
- 6 个 autoload 没有 `class_name`，按类名 grep 搜不到。不靠 `class_name` 解决（Godot 下与 autoload 同名会冲突），靠文件名与本文路由。
- 同义 TestAPI 入口：`add_soul` / `add_soul_to_warehouse`、`load_save_slot` / `load_save_slot_raw`。

### P3：浅但可接受（低优先）

`TestAPI` 门面与 commands actions 的纯转发（稳定入口，有意为之）；`GameGlobal` 单常量；`ContentKind` 枚举；`WindowPinSettings`；`CollectionSaveParticipant`。`Warehouse.page_index` 疑似死代码，未确认。

## 4. 深化记录

- **已完成（2026-11-21）**
  - C1 地图板 intent：`MapBoard.submit()` / `settle_pending()` + `MapPlaceResult`；面内容只做动画/提示；TestAPI 补 `submit_map_to_board()` / `settle_pending_map()`。
  - C2 战斗时钟：`BattleClock` + 四处物理帧统一门控 + `pause_battle()` / `step_battle()`；GAS 侧在 addons 加了 `AbilitySystemComponent.advance_time()` / `manual_time`。
  - C3 命名收敛：`SaveStorage.SLOT_COUNT` 单一来源；`ModLoader.get_user_order()`；`MapRun.advance()`；`CombatEvent` → `CombatTelemetrySchema`。
  - C4 存档注入：抽出 `SavePipeline` + `SaveLoadResult`；`SaveStorage` 变 seam（`DiskSaveStorage` / `MemorySaveStorage`）；加 `FakeSaveParticipant`；TestAPI `check_save_pipeline()`。
- **待做**：无。

## 5. 未确认

- `CombatTelemetry` 是否设计为可替换 port（消费者直连单例）。
- `Scripts/ui/` 是否需要 TestAPI 入口。
- Shop 窗口是占位还是由 GBIS 驱动。
- GBIS 的 `inventory_names`/`opened_containers` 是否官方扩展点。
- `Warehouse.page_index` 是否死代码。
- `EngineTools/modkit/` 是否直接调用 ModLoader/SaveManager。

## 6. 维护

- 改动边界后更新判决表和核对日期；不抄函数清单与行号，引用用 `file.gd::function`。
- 加 seam 前先确认存在第二个 adapter（通常是生产 + 测试）；单 adapter 只算 indirection。
- internal seam 留给模块自己的测试，不暴露到 interface。
