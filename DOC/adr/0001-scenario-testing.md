# ADR 0001：用情景测试作为领域行为验收

> 类型：记录 | 状态：有效 | 核对：2026-11-21
> 何时读：新增领域行为、决定验收方式，或想知道为什么不用纯脚本测试
> 关键词：ADR 情景测试 ScenarioCase 领域行为 验收 check.sh 无头 Godot
> 代码：`tools/scenarios/`、`tools/check.sh`
> 相关：`指南/代码检查.md` §情景测试、`spec/README.md`

**决策状态**：已接受 · 2026-11-21

## 背景

领域行为横跨 autoload、真实场景和固定战斗时钟，纯函数单测够不到这些接缝；`godot --script` 不加载 autoload 和场景，无法驱动存档、地图板或战斗；手动点一遍不可回归，也不会在提交前自动变红。

## 决策

用 `tools/scenarios/` 作为领域行为的验收层：

- 用例继承 `ScenarioCase`，实现 `case_name()` 与 `run(ctx)`，在 `tools/scenarios/run.gd` 的 `CASES` 注册；
- 运行器加载 `run.tscn`，autoload 已就绪；需要主场景的用例实现 `needs_main_scene()`；
- 用 `bash tools/check.sh --scenario <名>` 调试单例，`bash tools/check.sh --all` 跑全量；
- 领域行为变更必须新增或更新对应情景，没有情景覆盖的新行为不算做完；
- 无头运行把 `APPDATA` / `XDG_DATA_HOME` 指到临时目录，不碰真实存档。

## 后果

- 好处：断言直接落在玩家可见状态和真实入口上；失败输出实际值与期望值；与 lint、编译共用同一条提交前命令。
- 代价：每例都要启动 Godot 场景；用例必须自行清理改过的全局状态；异步结算要用 `await process_frame` 推进。
- 约束：空用例判失败；缺 `SCENARIO_TOTAL`、未知用例名或 `SCENARIO_FAILED` 非 0 一律判红。

## 替代方案

- `godot --script` 纯脚本：没有 autoload 和场景，覆盖不到真实入口。
- 纯函数单测：适合规则和数值，无法验证场景接线与时序。
- 手动验收：不可回归，无法在提交前自动执行。

## 相关

- 运行器与现有用例：`指南/代码检查.md` §情景测试
- 验收命令的选择：`spec/README.md` §验收
