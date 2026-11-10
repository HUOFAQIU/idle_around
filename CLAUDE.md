# idle_around

## 环境

- Godot 4.7：`U:\Godot_ver\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`
- 工程：`U:\Godot_Project\idle_around`
- Godot 文档：`U:\Godot_Doc\Godot Engine 4.7 documentation in English MD`
- GodotGAS Framework：`U:\Godot_Doc\GodotGAS Framework`
- UE5 GAS：`U:\Godot_Doc\UE5 GAS`

本文件只放每次会话都适用的约束；项目细节以 `DOC/INDEX.md` 为唯一入口。

## 开发注意

1、现在是开发阶段，存档和设置不要在意是否会被破坏。

## 必须遵守

1. 交流、文档记录用中文；思考过程用英文。
2. 先方案后动手：用户提需求，先输出方案，等确认后再改代码。功能改动必须确认；临时探针（用完即拆的调试代码）可直接插，跑完即拆，保证 git diff 干净。
3. `addons/` 下文件阅读随意，非必要不修改，必须修改时先说明。
4. 始终以干净、模块化的方式构建代码，并采用适当的架构和关注点分离。永远不要仅仅因为我要求就简单地拼凑一个功能。如果你找不到一种自然的方式来构建它，并且你建议进行重构以使整个系统更加干净，请提前停止工作并说明情况。
5. 先定位再读：先搜索，再按 offset/limit 只读命中段落，不整篇读文档。
6. 新增功能/内容时，同步在 `Scripts/test_api.gd` 暴露测试方法，并更新 `DOC/指南/AI测试接口.md`。
7. 新建资源（含 `GameplayEffect`）不设中文 `resource_name`，文件名不带固定数值；数值走数据/SetByCaller（详见 `DOC/架构/现状与注意.md`）。

## 文档

- 唯一入口 `DOC/INDEX.md`：先查「需求 → 文档 / 代码」路由表，按表找文档和代码入口，不猜文件名。
- 检索协议、写作约定、文档头规范都在 `DOC/INDEX.md`，本文件不重复。
- 改代码时同一次改动内更新对应文档头的「核对」日期；新增/删除文档时更新 `DOC/INDEX.md`。

## GDScript 风格

- 遵循 Godot 官方风格指南（本地）：`U:\Godot_Doc\Godot Engine 4.7 documentation in English MD\gdd_0308_GDScript_style_guide.md` 的 Formatting、Naming conventions、Code order 三节。
- 速记：文件/函数/变量/信号 snake_case；类/节点/枚举 PascalCase；常量/枚举成员 CONSTANT_CASE；代码顺序按指南 01～17，公有在前、私有在后。
