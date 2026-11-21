---
name: package-mod
description: Package this project's Godot mods with modkit — example mod PCK, new mod setup, manifest/container validators, and publish layout. Use when building, validating, or releasing a mod under mods/ or base_mods/core/.
---

# 打包 / 校验 Mod

详细规则以 `EngineTools/modkit/README.md` 和 `DOC/指南/Mod制作.md` 为准；这里只放执行步骤。

## 1. 打包示例 mod

```text
"U:/Godot_ver/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" --headless --path "U:/Godot_Project/idle_around" --script res://EngineTools/modkit/pack_example.gd
```

输出：

```text
%APPDATA%/Godot/app_userdata/idle_around/mods/example_souls/content.pck
%APPDATA%/Godot/app_userdata/idle_around/mods/example_souls/mod.json
```

- PCK 里是 mod 内容，`mod.json` 必须在 PCK 外面。
- 打包前关闭游戏，避免 PCK 被占用。
- 打包脚本走 `--script`，`SaveManager` 检测不到主场景会跳过读档，不会碰存档。

## 2. 新建/改造 mod

1. 复制 `mods/example_souls/` 为 `mods/<mod_id>/`。
2. 同步修改 `mod.json` 的 `id`、`name`、`version`、`author`、`content`，以及所有内容 ID。
3. 复制 `EngineTools/modkit/pack_example.gd` 并改 `MOD_ID`；或临时改原脚本后记得改回。
4. 命名规则：
   - 魂灵/怪物：`<mod_id>:<local_id>`，local_id 小写 snake_case，魂灵以 `_soul` 结尾、怪物以 `_monster` 结尾。
   - 技能：`Mod.<PascalModId>.<PascalName>`。
   - Cue：`Cue.Mod.<PascalModId>.<Name>`。
5. 重新打包；游戏不会自动重载 PCK，需要重启。

## 3. 校验

改完官方内容或容器名后按需运行：

```text
godot --headless --path "U:/Godot_Project/idle_around" --script res://EngineTools/modkit/validate_core_manifest.gd
godot --headless --path "U:/Godot_Project/idle_around" --script res://EngineTools/modkit/validate_container_ids.gd
```

- `validate_core_manifest.gd`：`base_mods/core/mod.json` 与实际文件是否一一对应、ID/路径重复、技能 ID 派生是否一致。退出码 `0` 通过。
- `validate_container_ids.gd`：场景里的 `container_name` 与 `Scripts/container_ids.gd` 是否一致。
- 运行时等价接口：`TestAPI.validate_core_manifest()`、`TestAPI.validate_container_ids()`。

## 4. 发布

发布目录只需要：

```text
<mod_id>/
  mod.json
  content.pck
```

整个文件夹压缩上传即可。不要把 `mods/`、`EngineTools/` 打进正式游戏包；导出排除规则见 `DOC/指南/Mod制作.md`。
