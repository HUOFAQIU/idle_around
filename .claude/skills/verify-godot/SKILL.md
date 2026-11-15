---
name: verify-godot
description: Verify GDScript changes in this Godot 4.7 project — headless parse/import check and optional save-isolated runtime probe. Use after editing .gd/.tscn/.tres files or before committing.
---

# 验证 Godot 改动

## 何时用

- 改完 `.gd` / `.tscn` / `.tres`，提交前确认没有解析错误。
- 需要跑运行期逻辑（战斗、背包、窗口、Cue）但不想碰真实存档。

## 1. 解析检查（默认先做）

```text
"U:/Godot_ver/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" --headless --path . --import
```

- 只认 `Parse Error` / `SCRIPT ERROR`；退出时的 RID / ObjectDB / 资源泄漏警告可忽略。
- `--import` 不跑主场景，不会写存档。
- 新增 `class_name` 脚本后必须先跑一次，刷新 `.godot/global_script_class_cache.cfg` 和 `.uid`，否则运行期会报全局类未注册。

## 2. 运行期探针（需要时才做）

不要用 `--headless --script`：该模式不注册 autoload 全局名，脚本里出现 `GBIS`、`SaveManager`、`TestAPI` 等会直接编译失败。用临时探针场景，并把用户目录隔离：

1. 新建 `res://_probe_xxx.tscn` + `res://_probe_xxx.gd`。
2. 运行前把 `APPDATA` 指到临时目录（Windows 上 Godot 的 `user://` 会跟着走），避免写到真实存档；探针结束删掉该目录。
3. 探针里 `add_child(load("res://Main/Cube/Scenes/main.tscn").instantiate())` 后再操作；启动不再自动读档，需要先用 `TestAPI.new_game()` 或 `TestAPI.load_save_slot(slot)` 建立会话。
4. `--quit-after 600` 结束后过滤输出；探针自己负责在失败时 `quit(1)`。
5. 运行命令示例：

```bash
APPDATA="C:/Users/<you>/AppData/Local/Temp/idle_around_probe" \
"U:/Godot_ver/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --headless --path . res://_probe_xxx.tscn 2>&1 | rg -i "PROBE|script error|parse error|invalid"
```

6. 跑完删除探针 `.gd` / `.tscn` / `.uid` 和临时 `APPDATA` 目录，确认 `git status` 只剩预期改动。

## 3. 报告

- 列出实际执行的命令和关键输出；不要只说“应该没问题”。
- 失败时贴 `Parse Error` / `SCRIPT ERROR` 原文和文件位置。
- 探针属于临时调试代码，用完即拆；正式功能改动仍要先出方案等确认。
