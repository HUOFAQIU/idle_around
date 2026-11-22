# idle_around

## 环境

- Godot 4.7：`U:\Godot_ver\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`
- 工程：`U:\Godot_Project\idle_around`
- Godot 文档：`U:\Godot_Doc\Godot Engine 4.7 documentation in English MD`
- GodotGAS Framework：`U:\Godot_Doc\GodotGAS Framework`
- UE5 GAS：`U:\Godot_Doc\UE5 GAS`

## 开发注意

1、开发阶段默认按「格式可破坏」处理：存档和设置的格式/内容随功能直接改，不做兼容。无头/自动化测试默认把 `user://` 指到临时目录，只有明确要验证真实存档时才用真实目录。
2、改功能时默认直接替换：旧代码、旧命名、旧迁移和旧文档描述随改动一起删除，新名字只保留一套；通用容错（如存档 `orphaned`）保留。第三方/上游库和明确保留的占位按原样保留，见 `DOC/架构/现状与注意.md` 的「清理保留项」。

## 必须遵守

1. 交流、文档记录默认用中文。
2. 先方案后动手：用户提需求时，默认先输出方案、等确认后再改代码，功能改动一律走确认。临时探针（用完即拆的调试代码）按例外处理：可直接插、自行运行和删除，跑完即拆并把「探针已拆、git diff 干净」报给用户；期间 `addons/` 保持只读。新增文件、改接口、动场景结构按功能改动处理，先确认。方案按 `DOC/spec/README.md` 的触发条件落成 `DOC/spec/NNNN-<slug>.md`：确认前标「草稿」，确认后改「已约定」再动手，实现完改「已实现」并按「退出」处理。
3. `addons/` 默认只读：阅读随意，改动前先说明并等确认。
4. 始终以干净、模块化的方式构建代码，采用适当的架构和关注点分离；每个功能都按系统能自然容纳的方式落地，需求大小不改变这个标准。如果找不到自然构建方式、需要重构才能干净落地，先停下说明情况并等确认。
5. 先定位再读：先搜索，再按 offset/limit 只读命中段落；全文读只用于短文件或已确认需要全文时。
6. 新增功能/内容时，同步暴露 TestAPI（域模块实现 + 门面转发）并更新文档；`指南/AI测试接口.md` 在新增域或入口语义变化时更新，细则见 `DOC/INDEX.md` 写作约定 8。
7. 跨 3 个以上文件、或预计读入超过 200 行的搜索，默认派 Explore 子代理；派发时写明回报格式：只回结论和 `file:line`，不写长报告、不贴大段代码；主上下文也只保留这些。
8. 超过 200 行的命令输出先落盘，再用 `grep`/`tail` 取关键行进上下文。
9. 相互独立的工具调用合并到一条消息并行执行；同一文件的多个改动先读完、规划好再一次改完。
10. 改完统一跑一次 `tools/check.sh --all`（全量 lint + 编译）；一批改动只跑一轮，失败后再修一轮。提交前顺序固定：check → review（spec 保持「已实现」）→ spec 退出 → commit → 交接；细则见 `指南/代码检查.md`。

## 文档

- 本文件只放每次会话都适用的约束；项目细节以 `DOC/INDEX.md` 为唯一入口：先查「需求 → 文档 / 代码」路由表，按表找文档和代码入口，不猜文件名。
- 检索协议、写作约定、文档头规范都在 `DOC/INDEX.md`，本文件不重复。

## GDScript 风格

- 遵循 Godot 官方风格指南（本地）：`U:\Godot_Doc\Godot Engine 4.7 documentation in English MD\gdd_0308_GDScript_style_guide.md` 的 Formatting、Naming conventions、Code order 三节。
- 速记：文件/函数/变量/信号 snake_case；类/节点/枚举 PascalCase；常量/枚举成员 CONSTANT_CASE；代码顺序按指南 01～17，公有在前、私有在后。
