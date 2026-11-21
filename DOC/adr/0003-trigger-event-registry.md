# ADR 0003：触发器事件用 GAS 标签注册表，冻结/减速对称派发

> 类型：记录 | 状态：有效 | 核对：2026-11-21
> 何时读：新增触发器事件、改冻结/减速派发，或排查触发器不触发
> 关键词：ADR 触发器 GameplayEvent SoulTriggerAbility 监听者注册表 冻结 减速 max_range
> 代码：`game/content/passive_trigger.gd`、`game/battle/soul_loadout.gd`、`game/battle/battle_unit.gd`、`game/battle/battle_manager.gd`
> 相关：`架构/战斗数据与魂灵.md` §魂灵触发器、`架构/GAS.md`、`adr/0002-pointer-docs.md`

**决策状态**：已接受 · 2026-11-21

## 背景

触发器最初用枚举描述事件，每加一种事件都要改 schema 和多处分支；冻结与减速的派发路径也不一致，一个由单位直接通知，另一个从魂灵减速绕回单位。若每次都扫描全场单位，单位多时成本随数量平方增长。

## 决策

触发器事件统一走 GAS 标签注册表：

- `PassiveTrigger.event_tag` 选 `Event.*`，`SoulLoadout` 为每条触发器建 `SoulTriggerAbility`，grant 到 ASC 并写 `trigger_event_tag`；
- 事件产生处调用 `ASC.send_gameplay_event()`，只唤醒标签匹配的技能；
- 需要跨单位广播的事件由 `BattleManager` 维护监听者注册表，只向注册了该触发器的敌对单位派发，不扫全场；
- 冻结走 `BattleUnit.notify_freeze_applied()`，减速走 `ChargedAbility.apply_slow()` → `BattleUnit.notify_slow_applied()`，两者都按「敌对 + 已注册监听者」派发；
- 新增事件只需在 `tag_registry.tres` 注册标签，并在事件产生处 `send_gameplay_event()`，不改 `SoulTriggerAbility` 核心；
- 事件清单、payload 和 `max_range` 的权威说明只在 `架构/战斗数据与魂灵.md` §魂灵触发器维护。

## 后果

- 好处：新增事件成本低；无监听者时不发事件，避免刷屏；冻结与减速共享同一套派发语义。
- 代价：payload 约定必须稳定（至少 `target` / `trace`，事件特有字段按事件补）；触发器行为分散在事件产生处，排查时要顺着 `send_gameplay_event()` 找。
- 已知边界：单位级 `State.Slowed` 尚未实现，目前只有魂灵级减速会发 `SlowApplied`；冻结不区分来源，重复冻结同一目标会重复触发。

## 替代方案

- 枚举事件：类型安全，但每加事件都要改 schema、加载校验和多处分支。
- 全场扫描：实现简单，但每次事件都遍历所有单位，和单位数量平方相关。
- 每个事件单独写通知接口：调用点直观，但冻结/减速会继续分叉，新增事件也要复制派发逻辑。

## 相关

- 权威事件清单：`架构/战斗数据与魂灵.md` §魂灵触发器
- GAS 标签与事件：`架构/GAS.md`
