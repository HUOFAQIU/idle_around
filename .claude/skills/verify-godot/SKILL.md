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

不要用 `--headless --script`：该模式不注册 autoload 全局名，脚本里出现 `GBIS`、`SaveManager`、`TestAPI` 等会直接编译失败。用临时探针场景：

1. 新建 `res://_probe_xxx.tscn` + `res://_probe_xxx.gd`。
2. `_ready()` **第一行**就调用 `SaveManager.set_process(false)`：无头跑主场景时，启动帧的 `delta` 可能超过自动写档的 2 秒阈值，晚一帧就来不及。
3. 需要读档时，等 2～4 帧让 `SaveManager` 完成加载，再 `SaveManager.set("_read_only", true)`；探针自己不要在战斗/拖拽中调用 `save_now()`。
4. 需要 `TestAPI` 找窗口时，在探针里 `add_child(load("res://Main/control.tscn").instantiate())`；探针场景本身就是 `SceneTree.current_scene`，`TestAPI` 从它往下找。
5. 运行并过滤输出：

```text
"U:/Godot_ver/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" --headless --path . --quit-after 600 res://_probe_xxx.tscn
```

```bash
... 2>&1 | rg -i "PROBE|script error|parse error|invalid"
```

6. 跑完删除探针 `.gd` / `.tscn` / `.uid`，确认 `git status` 只剩预期改动。

## 3. 报告

- 列出实际执行的命令和关键输出；不要只说“应该没问题”。
- 失败时贴 `Parse Error` / `SCRIPT ERROR` 原文和文件位置。
- 探针属于临时调试代码，用完即拆；正式功能改动仍要先出方案等确认。
