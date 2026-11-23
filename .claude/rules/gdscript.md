---
paths:
  - "**/*.gd"
---

# GDScript 风格

- 遵循 Godot 官方风格指南的 Formatting、Naming conventions、Code order 三节：`U:\Godot_Doc\Godot Engine 4.7 documentation in English MD\gdd_0308_GDScript_style_guide.md`。
- 文件/函数/变量/信号 snake_case；类/节点/枚举 PascalCase；常量/枚举成员 CONSTANT_CASE。
- 代码顺序按指南 01～17：公有在前、私有在后。
- 首方 `.gd` 不写注释，why、边界、坑写进 `DOC/`；例外见 `DOC/指南/代码检查.md`「注释策略」。
