# idle_around

## 环境

- Godot 4.7：`U:\Godot_ver\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`
- 工程：`U:\Godot_Project\idle_around`
- Godot 文档：`U:\Godot_Doc\Godot Engine 4.7 documentation in English MD`
- GodotGAS Framework：`U:\Godot_Doc\GodotGAS Framework`
- UE5 GAS：`U:\Godot_Doc\UE5 GAS`

## 开发注意

1、现在是开发阶段，存档和设置的格式/内容可以破坏，不保证兼容；但无头/自动化测试仍要隔离 `user://`，不要误写真实存档。
2、改功能时直接删旧代码、旧命名、旧迁移和旧文档描述，不为旧名字写兼容；通用容错（如存档 `orphaned`）保留。第三方/上游库和明确保留的占位不在此列，见 `DOC/架构/现状与注意.md` 的「清理保留项」。

## 必须遵守

1. 交流、文档记录用中文。
2. 先方案后动手：用户提需求，先输出方案，等确认后再改代码。功能改动必须确认；临时探针（用完即拆的调试代码）可直接插、自行运行和删除，不必每次先出方案，但不得动 `addons/`；新增文件、改接口、动场景结构不算探针，仍须先确认。跑完即拆并把「探针已拆、git diff 干净」报给用户。
3. `addons/` 下文件阅读随意，非必要不修改，必须修改时先说明。
4. 始终以干净、模块化的方式构建代码，并采用适当的架构和关注点分离。永远不要仅仅因为我要求就简单地拼凑一个功能。如果你找不到一种自然的方式来构建它，并且你建议进行重构以使整个系统更加干净，请提前停止工作并说明情况。
5. 先定位再读：先搜索，再按 offset/limit 只读命中段落，不整篇读文档。
6. 新增功能/内容时，同步暴露 TestAPI 并更新文档，细则见 `DOC/INDEX.md` 写作约定 8。
7. 跨 3 个以上文件的搜索优先派 Explore 子代理；只取结论和 `file:line`，不把大段文件内容带进主上下文。
8. 超过 200 行的命令输出先落盘，再 `grep`/`tail` 取关键行，不整段读入上下文。

## 文档

- 本文件只放每次会话都适用的约束；项目细节以 `DOC/INDEX.md` 为唯一入口：先查「需求 → 文档 / 代码」路由表，按表找文档和代码入口，不猜文件名。
- 检索协议、写作约定、文档头规范都在 `DOC/INDEX.md`，本文件不重复。

## GDScript 风格

- 遵循 Godot 官方风格指南（本地）：`U:\Godot_Doc\Godot Engine 4.7 documentation in English MD\gdd_0308_GDScript_style_guide.md` 的 Formatting、Naming conventions、Code order 三节。
- 速记：文件/函数/变量/信号 snake_case；类/节点/枚举 PascalCase；常量/枚举成员 CONSTANT_CASE；代码顺序按指南 01～17，公有在前、私有在后。
