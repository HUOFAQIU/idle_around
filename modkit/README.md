# Modkit 与示例 mod

示例 mod 的源码在 `mods/example_souls/`，打包工具在 `modkit/pack_example.gd`。

示例包含：

- 一颗新魂灵 `example_souls:fire_wolf_soul`；
- 一条技能 `Mod.ExampleSouls.FireWolf`（ability tag `Skill.Mod.ExampleSouls.FireWolf`）：4 秒冷却，3 格内最近敌人 12 点伤害；
- 一个自定义 Cue `Cue.Mod.ExampleSouls.Fire`：火焰粒子爆发。

## 快速开始

1. 用 Godot 4.7.x 打开本工程。
2. 修改 `mods/example_souls/` 下的 `mod.json`、魂灵、技能或 Cue。
3. 在项目根目录运行打包脚本：

```text
"U:\Godot_ver\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" ^
  --headless --path "U:\Godot_Project\idle_around" ^
  --script res://modkit/pack_example.gd
```

4. 脚本会生成：

```text
user://mods/example_souls/content.pck
user://mods/example_souls/mod.json
```

Windows 下 `user://` 是 `%APPDATA%\Godot\app_userdata\idle_around\`。

5. 重启游戏，打开主界面的“Mod”按钮，应该能看到 `Example Souls`。
6. 用测试接口把示例魂灵放进仓库：

```gdscript
TestAPI.add_soul_to_warehouse(&"example_souls:fire_wolf_soul")
```

## 校验内置 core manifest

官方内容清单 `base_mods/core/mod.json` 是手工维护的。改完魂灵/怪物/魂器/Cue 后运行：

```text
"U:\Godot_ver\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" ^
  --headless --path "U:\Godot_Project\idle_around" ^
  --script res://modkit/validate_core_manifest.gd
```

检查项：manifest 格式、`id=core` / `content_namespace=global`、魂灵/怪物/魂器/Cue 条目与目录文件是否一一对应、重复 ID/路径、ID/标签格式、魂灵技能 ID 是否与 content_id 派生值一致。退出码 `0` 表示通过，`1` 表示有错误。

运行时也可以用 `TestAPI.validate_core_manifest()` 查询同一份校验结果。

## 校验容器名

场景里的 `container_name` 是字面量，不能直接引用 `ContainerIds` 常量。改场景或常量后运行：

```text
"U:\Godot_ver\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" ^
  --headless --path "U:\Godot_Project\idle_around" ^
  --script res://modkit/validate_container_ids.gd
```

对比角色（魂器网格）/仓库/商店场景的 `container_name` 与 `Scripts/container_ids.gd`。运行时可用 `TestAPI.validate_container_ids()` 检查容器是否都注册成功。

## 发布 mod

发布目录只需要两个文件：

```text
example_souls/
  mod.json
  content.pck
```

把整个文件夹压缩或上传即可。`mod.json` 必须在 PCK 外面，`ModLoader` 在挂载前读取它。

改 `mod.json` 时至少同步：

- `id`：小写 snake_case，全局唯一；改 id 后所有内容 ID、Cue 前缀和 PCK 目标路径也要一起改。
- `name` / `version` / `author` / `description`：Mod 窗口展示用。
- `content`：魂灵、怪物、魂器、Cue 的路径列表。

## 内容规则

- 魂灵/怪物/魂器 ID：`<mod_id>:<local_id>`；local_id 用小写 snake_case，魂灵以 `_soul` 结尾、怪物以 `_monster` 结尾、魂器以 `_vessel` 结尾。
- 技能 ID：`Mod.<PascalModId>.<PascalName>`，示例是 `Mod.ExampleSouls.FireWolf`；留空时 `ModLoader` 会按魂灵 content_id 自动派生。
- Cue 标签：`Cue.Mod.<PascalModId>.<Name>`，示例是 `Cue.Mod.ExampleSouls.Fire`。
- Cue 场景根节点必须继承 `GameplayCueNotify`。
- 技能、效果可以引用原版脚本和资源；新魂灵/怪物/魂器/Cue 必须在 `mod.json` 的 `content` 里登记。
- 详细字段、覆盖和加载顺序见 `DOC/指南/Mod制作.md`。

## 说明

- `mods/` 和 `modkit/` 已从正式游戏导出中排除，不会打进基础包。
- 打包脚本以无头模式启动工程，会加载 autoload；`SaveManager` 检测到没有主场景会跳过读档，不会碰存档。建议打包前关闭游戏，避免 PCK 文件被占用。
- 示例魂灵的技能用 `res://mods/example_souls/...` 引用同目录资源，所以请用打包脚本安装；直接把源码目录复制到 `user://mods` 的 loose 模式只适合临时调数据。
- 修改源码后必须重新运行打包脚本；游戏不会自动重载 PCK。
- 启用状态和加载顺序在 Mod 窗口里改，重启游戏后生效。
