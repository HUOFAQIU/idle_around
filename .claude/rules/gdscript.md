---
paths:
  - "**/*.gd"
---

# GDScript 风格

- 遵循 Godot 官方风格指南的 Formatting、Naming conventions、Code order 三节。
- 文件/函数/变量/信号 snake_case；类/节点/枚举 PascalCase；常量/枚举成员 CONSTANT_CASE。
- 代码顺序按指南 01～17：公有在前、私有在后。
- 首方 `.gd` 禁普通注释，长篇设计/数据流写进 `docs/`；允许单行 `# why:` / `# invariant:`（≤120 字符）就近标注关键不变量，其余例外见 `docs/指南/代码检查.md`「注释策略」。
