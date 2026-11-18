# AI 测试接口 TestAPI

> 类型：指南 | 状态：有效 | 核对：2026-11-18
> 何时读：写自动化测试/探针、构造战斗或背包场景、验证新功能
> 关键词：测试 TestAPI 探针 自动化 战斗快照 地图 map MapCatalog MapBoard 地图板 数量石 魂灵 魂器 vessel 仓库 见闻 商店 冷却 冻结 触发器 类型 标签 尺寸 充能 卡面 tooltip 伤害缩放 动态伤害 静态预览 SoulDamagePreview get_equipped_soul_damage_preview is_dynamic has_runtime 多重触发 cast_times releases 颜色 色板 色板目录 分组 别名 主屏幕 六槽 存档位 角色选择 GameFlow 锁定 锁图 存档 save 删档 删除存档 确认 爪痕 play_claw_cue mod ModLoader ModWindow 加载顺序 order mod_cue_registrar cue Cue 特效 manifest 创意工坊 内置 core content_id validate_core_manifest manifest 校验 技能 ID ability_tag 命名 主窗口置顶 单窗口 浮层 CanvasLayer PetPanel 主菜单 位置不持久化 CubePlacement PanelManager 激活面板 遮挡 穿透 mouse_passthrough WindowPassthrough 立方体 cube 面 02 背面 层级 CubeView CubeInputSurface CubeProjection CubeScenePaths get_cube_layering_state view_layer 终端 字符网格 TerminalView TerminalBuffer TerminalSpan 跨格大字 ANSI SGR 回看 scrollback auto_scroll
> 代码：`Scripts/test_api.gd`、`Windows/Battle/battle_window.gd`、`Scripts/collection_db.gd`、`Scripts/save/`、`Scripts/mod/`、`base_mods/core/mod.json`
> 约定：新增功能/内容时，同步补 TestAPI 方法并更新本文。

## 用法

`TestAPI` 是全局静态类，不用挂节点。探针场景里直接调用：

```gdscript
TestAPI.set_unlock_all(false)
TestAPI.clear_container("inventory_0")
var soul_id: StringName = TestAPI.get_soul_ids()[0]
var vessel_id: StringName = TestAPI.get_vessel_ids()[0]
TestAPI.add_soul(soul_id)
TestAPI.add_vessel(vessel_id)
TestAPI.equip_vessel(vessel_id)
TestAPI.vessel_add_soul(soul_id, 0)
TestAPI.start_battle()
await get_tree().physics_frame
var state := TestAPI.get_battle_state()
print(state)
TestAPI.stop_battle()
```

魂灵/怪物 ID 用 `TestAPI.get_soul_ids()`、`TestAPI.get_monster_ids()` 查，必须是 `content_id`（core 不带前缀；第三方带 `<mod_id>:` 前缀）。技能标签用 `TestAPI.get_skill_tags()` 查：core 形如 `Skill.<PascalName>`，第三方形如 `Skill.Mod.<PascalModId>.<PascalName>`（示例 mod 为 `Skill.Mod.ExampleSouls.FireWolf`）。

## 背包 / 见闻

| 方法 | 说明 |
|---|---|
| `add_soul(id, container := "") -> bool` | 按 content_id 放入指定容器；`container` 为空时放仓库第 1 页 |
| `add_soul_to_warehouse(id) -> bool` | 按 content_id 放入仓库，从第 1 页开始找空位 |
| `show_shop() -> bool` | 显示商店窗口；找不到窗口返回 `false` |
| `shop_add_soul(id) -> bool` | 按 content_id 往 `shop_0` 追加一颗魂灵；清空用 `clear_container("shop_0")` |
| `pick_up_item(container, grid_id) -> bool` | 模拟左键从格子拿起物品，进入拖拽状态 |
| `drop_moving_item(container, grid_id) -> bool` | 把正在拖拽的物品放到指定格子；`grid_id` 是鼠标点击格，物品左上角 = `grid_id` - 抓取偏移 |
| `sell_moving_item() -> bool` | 在商店出售正在拖拽的物品 |
| `cancel_moving_item() -> bool` | 模拟右键取消拿起；优先放回原格 |
| `quick_sell(container, grid_id) -> bool` | 直接出售格子里的物品；商店和该容器都打开才生效 |
| `set_warehouse_page(page) -> bool` | 切换仓库窗口到指定页（0 起）；窗口不存在返回 `false` |
| `get_warehouse_page() -> int` | 当前仓库页码（0 起）；找不到窗口返回 `-1` |
| `add_vessel(id, container := "") -> bool` | 按 content_id 把魂器放进指定容器；`container` 为空时放仓库第 1 页 |
| `equip_vessel(id) -> bool` | 把战斗魂器装进角色魂器网格；网格放不下返回 `false` |
| `vessel_add_soul(soul_id, vessel_slot := 0) -> bool` | 往魂器网格里第 `vessel_slot` 个魂器的内部容器放一颗魂灵 |
| `get_vessel_contents(vessel_slot := 0) -> Array[String]` | 魂器网格里第 `vessel_slot` 个魂器中的魂灵名 |
| `get_vessel_ids() -> Array[StringName]` | 已加载的魂器 content_id（core + 第三方 mod） |
| `clear_container(container) -> void` | 清空容器并刷新 |
| `get_container_items(container) -> Array[String]` | 容器内物品名 |
| `validate_container_ids() -> Array[String]` | 校验 `ContainerIds` 里的仓库、商店、魂器网格是否都已注册；主场景运行后调用 |
| `set_unlock_all(enabled) -> void` | 切换见闻全解锁（不写存档） |
| `unlock_all_collection() -> bool` | 永久解锁全部见闻并触发写档；返回是否新增记录 |
| `get_seen_ids(kind) -> Array[StringName]` | 真实已解锁 ID |
| `is_seen(kind, id) -> bool` | 单个条目是否解锁 |
| `get_soul_ids()` / `get_monster_ids()` | 列出内容条目（core + 第三方 mod） |
| `get_monster_spawn_distances(id) -> Array[int]` | 怪物的可选刷新距离（格），默认 `[3]` |
| `get_soul_types(id) -> Array[StringName]` | 魂灵类型，如 `Soul.types.Wolf`、`Soul.types.Animal` |
| `get_soul_tags(id) -> Array[StringName]` | 魂灵见闻标签，如 `Soul.tags.Small`、`Soul.tags.Burn` |
| `get_soul_size_tag(id) -> StringName` | 魂灵尺寸标签，如 `Soul.tags.Medium` |
| `get_skill_tags() -> Array[Dictionary]` | 所有魂灵的 `content_id`、技能 ID 和 `ability_tag`，用于核对技能命名规范 |
| `get_soul_card_info(id) -> Dictionary` | 魂灵卡面：`icon` 路径、`columns`/`rows`、`label` 名称文本 |
| `get_soul_damage_scaling(id) -> Dictionary` | 从所有 `UnitSkillStep` 里找第一个直接伤害的 `base_damage` / `bonus_per_matching_soul` / `matching_soul_types` |
| `get_soul_steps(id) -> Array[Dictionary]` | 技能步骤：`index` / `type` / `domain` / `target_rule` / 效果数量 / `status_magnitude` / 状态时长 |
| `get_soul_cast_times(id) -> int` | 魂灵技能的多重触发次数；未知魂灵或无技能返回 `0` |
| `get_soul_tooltip_text(id) -> String` | 魂灵 tooltip 完整纯文本；第一行是标题，后面是正文（格式见 `魂灵/魂灵.md`） |
| `get_soul_tooltip_bbcode(id) -> String` | 魂灵 tooltip 的 BBCode 文本；正文状态词带颜色标签，用于验证上色 |
| `get_soul_tooltip_ansi(id) -> String` | 魂灵 tooltip 的 ANSI 文本；标题粗体，可直接传给 `terminal_set_ansi_content()` |
| `get_equipped_soul_tooltip_text(id)` / `get_equipped_soul_tooltip_bbcode(id)` / `get_equipped_soul_tooltip_ansi(id)` | 已装备魂灵的动态 tooltip；伤害带 `*` 前缀（战斗中运行期值，否则“装上后”静态预览），未装备回退静态 tooltip |
| `get_equipped_soul_damage_preview(id) -> Dictionary` | 已装备魂灵的伤害预览：战斗中优先运行期值，否则按当前魂器网格静态预览；含基础/匹配数量/玩家与魂器加成/最终值/`is_dynamic`/`has_runtime`；未装备返回 `{}` |
| `get_vessel_tooltip_text(id)` / `get_vessel_tooltip_bbcode(id)` / `get_vessel_tooltip_ansi(id)` | 魂器模板的 tooltip；模板不带运行时内容，网格为满格 `*`；`ansi` 可直接传给终端 |
| `get_equipped_vessel_tooltip_text(slot := 0)` / `get_equipped_vessel_tooltip_bbcode(slot := 0)` / `get_equipped_vessel_tooltip_ansi(slot := 0)` | 魂器网格里第 `slot` 个魂器的 tooltip；网格反映内部魂灵；`ansi` 可直接传给终端 |

仓库/见闻悬停的 `TooltipWindow` 正文现在由内嵌 `TerminalView` 渲染：传入 `SoulTooltip.build(..., Format.PLAIN)` / `VesselTooltip.build(..., Format.PLAIN)`，窗口内部转 ANSI 并显示调试网格；`text` 方法返回的就是这份输入，`bbcode` / `ansi` 用于对比和直接喂终端。

`kind` 用 `ContentKind.Kind.SOUL` / `ContentKind.Kind.MONSTER` / `ContentKind.Kind.VESSEL`。见闻窗口的魂灵/魂器条目悬停使用与仓库相同的 tooltip（魂灵 `SoulTooltip.build()`，魂器 `VesselTooltip.build()`）；右键已遇见魂灵等价于 `add_soul_to_warehouse(id)`，右键已遇见魂器等价于 `add_vessel(id)`。魂器首次进入任意容器即解锁：

```gdscript
var vessel_id: StringName = TestAPI.get_vessel_ids()[0]
TestAPI.add_vessel(vessel_id)
print(TestAPI.is_seen(ContentKind.Kind.VESSEL, vessel_id))  # true
```

仓库有 10 页（`inventory_0..inventory_9`）。测试时用 `add_soul_to_warehouse()` 自动入页，或 `set_warehouse_page()` 切到指定页观察显示；页码从 0 开始。

拖拽取消可以这样验证：

```gdscript
TestAPI.clear_container("inventory_0")
TestAPI.add_soul(TestAPI.get_soul_ids()[0])  # 落在 (0, 0)
TestAPI.pick_up_item("inventory_0", Vector2i.ZERO)
TestAPI.cancel_moving_item()               # 物品回到 (0, 0)

TestAPI.pick_up_item("inventory_0", Vector2i.ZERO)
TestAPI.drop_moving_item("inventory_0", Vector2i(5, 0))  # 放到指定格
```

## 存档与开局

| 方法 | 说明 |
|---|---|
| `save_now() -> bool` | 立即写当前活动槽；没有活动槽返回 false |
| `load_save_slot(slot) -> bool` | 完整流程读档：保存当前槽（如有）、结束战斗/关面板、读取目标槽、锁 04/解锁 02、翻到 02 面 |
| `load_save_slot_raw(slot) -> bool` | 直接调 `SaveManager.load_slot()`，不改变 `GameFlow` 状态和立方体朝向；用于存档格式/迁移测试 |
| `new_game(character_id = &"small_coal_lamp") -> bool` | 完整新游戏流程：01 面新游戏 → 04 面选角 → 02 面；占第一个空槽 |
| `delete_save_slot(slot) -> bool` | 绕过 UI 直接删除指定槽的磁盘文件；删活动槽会断开活动槽，`GameFlow` 回到 `NO_SESSION`/01 面 |
| `has_save() -> bool` | 是否存在任意可读槽 |
| `get_save_slots() -> Array[Dictionary]` | 六个槽的视图数据：`slot` / `occupied` / `character_name` / `active` |
| `get_active_slot() -> int` | 当前活动槽；启动停在 01 面时为 -1 |
| `get_game_flow_state() -> Dictionary` | `state`（`NO_SESSION` / `CHARACTER_SELECT` / `IN_GAME`）/ `active_slot` / `character_id` / `character_name` |
| `get_save_path(slot) -> String` | 指定槽的 `user://saves/slot_N.json`；绝对路径用 `ProjectSettings.globalize_path()` |
| `get_save_status() -> Dictionary` | `ready` / `read_only` / `missing_containers` / `active_slot`；缺容器时只读，不读也不写 |
| `dump_save() -> Dictionary` | 当前内存状态的存档快照，不写盘；用于检查序列化结果 |

```gdscript
TestAPI.new_game()                       # 占第一个空槽并进入 IN_GAME
print(TestAPI.get_game_flow_state())
print(TestAPI.get_save_slots())
TestAPI.clear_container("inventory_0")
TestAPI.add_soul(TestAPI.get_soul_ids()[0])
TestAPI.save_now()
print(TestAPI.get_save_path(0))
TestAPI.clear_container("inventory_0")
TestAPI.load_save_slot_raw(0)            # 只验证存档恢复
print(TestAPI.get_container_items("inventory_0"))
TestAPI.delete_save_slot(0)
```

- 启动不再自动读档：先 `new_game()` 或 `load_save_slot(0)` 才有活动槽；否则 `save_now()` 返回 false。
- `delete_save_slot()` 是绕过 UI 的后端直删；游戏内删除走 `click_cube_delete_save_slot()`，第一次确认、第二次才删，活动槽不可删。
- 读档会保留物品的左上角格子，所以验证魂器网格相邻关系时可以直接比较读档前后的锚点。
- 无头测试建议把 `APPDATA` 指到临时目录，避免写到真实 `user://`；完整流程回归见 `指南/存档排查.md`。
- 存档结构、六槽、备份/迁移规则见 `架构/存档.md`；面锁定和状态机见 `架构/开局流程.md`。

## Mod

| 方法 | 说明 |
|---|---|
| `get_mod_list() -> Array[Dictionary]` | 已发现 mod 的概况：`id`、`name`、`version`、`author`、`description`、`source`（`builtin`/`local`）、`builtin`、`locked`、`enabled`、`blocked`、`loaded`、`mounted`、`load_index`、内容数量、错误和警告 |
| `get_mod_errors() -> Array[String]` | `ModLoader` 的错误汇总；加载失败/ID 冲突/依赖缺失/Cue 注册失败都看这里 |
| `get_mod_warnings() -> Array[String]` | 不阻止加载的诊断：未知 manifest 字段、技能 ID 冲突等 |
| `is_builtin_mod(id) -> bool` | 某个 mod 是否为内置 mod（core） |
| `get_mod_content_ids(id) -> Dictionary` | 某个 mod 注册的 `souls` / `monsters` / `cues` ID 列表 |
| `validate_core_manifest() -> Array[String]` | 校验 `base_mods/core/mod.json` 与 `souls/`、`monsters/`、`cues/` 文件是否一一对应；空数组表示通过 |
| `get_mod_cues() -> Array[Dictionary]` | Cue 的 `tag`、`mod`、`path`、`registered`；包含 core 和第三方 |
| `is_mod_cue_registered(tag) -> bool` | 某个 mod Cue 标签是否已注册到 `GameplayCueManager` |
| `show_mod_window() -> bool` | 打开 Mod 管理窗口并刷新 |
| `get_mod_window_state() -> Dictionary` | 窗口状态：`visible`、`mods`、`loaded`、`pending`、`order_pending`、`order`、`load_order`、`errors`、`summary` |
| `get_mod_load_order() -> Array[StringName]` | 本次实际加载顺序（只含已启用且未被阻止的 mod） |
| `get_mod_order() -> Array[StringName]` | 用户指定的基础加载顺序；内置 mod 固定在最前 |
| `set_mod_order(ids) -> bool` | 写 `user://mods.cfg` 的 `[order]`；内置 mod 会被强制归位到最前，运行期不重排，重启后生效 |
| `set_mod_enabled(id, enabled) -> bool` | 写 `user://mods.cfg`；内置 mod 返回 false，当前运行期不会卸载/重载，重启后生效 |
| `get_orphaned_records() -> Array[Dictionary]` | 当前存档里因 mod 缺失/容器满而保留的原始记录 |

```gdscript
print(TestAPI.get_mod_list())
print(TestAPI.get_mod_errors())
print(TestAPI.get_mod_warnings())
print(TestAPI.is_builtin_mod(&"core"))
print(TestAPI.get_mod_content_ids(&"core"))  # souls 19 / monsters 2 / cues 5
print(TestAPI.validate_core_manifest())
print(TestAPI.get_mod_cues())
print(TestAPI.is_mod_cue_registered(&"Cue.Status.Burn"))
print(TestAPI.is_mod_cue_registered(&"Cue.Mod.ExampleSouls.Fire"))
print(TestAPI.show_mod_window())
print(TestAPI.get_mod_window_state())
print(TestAPI.get_mod_order())
print(TestAPI.get_mod_load_order())
```

- 内置 core 清单在 `base_mods/core/mod.json`，固定启用、排序最前；第三方 mod 目录是 `user://mods/<mod_id>/`，最小结构 `mod.json` + `content.pck`，开发期可以只放 loose 目录。
- 制作和字段说明见 `指南/Mod制作.md`，加载规则见 `架构/Mod系统.md`。core 内容 ID 不带前缀，第三方内容 ID 带 `<mod_id>:` 前缀，都可以直接传给 `add_soul()` / `get_soul_ids()`。
- 装好示例 mod 后，可以用 `TestAPI.add_soul_to_warehouse(&"example_souls:fire_wolf_soul")` 验证。示例源码在 `mods/example_souls/`，打包脚本是 `modkit/pack_example.gd`。

## 窗口

| 方法 | 说明 |
|---|---|
| `set_window_pinned(window_name, pinned) -> bool` | 设置主窗口（整个应用）置顶；单窗口模式只有 `MainWindow` 有效，其他名字返回 false；写入 `user://Settings.cfg`，键 `main_window` |
| `is_window_pinned(window_name) -> bool` | 查询主窗口置顶状态；其他名字返回 false |
| `get_window_pin_states() -> Dictionary` | 主窗口置顶状态：`{"MainWindow": bool}` |
| `get_cube_screen_position() -> Vector2` | 立方体中心的屏幕像素坐标；找不到返回 `(-1, -1)` |
| `set_cube_screen_position(position) -> bool` | 把立方体移到指定屏幕坐标（仅本次运行有效，不写盘）；找不到返回 `false` |
| `get_active_panel_name() -> String` | 当前激活面板的节点名；没有返回 `""` |
| `get_visible_panel_rects() -> Array[Rect2]` | 所有可见 `BaseWindow` 面板的矩形（主视口坐标），给遮挡/穿透测试用 |
| `set_cube_passthrough_enabled(enabled) -> bool` | 开关透明覆盖层点击穿透；找不到模块返回 `false` |
| `is_cube_passthrough_enabled() -> bool` | 穿透总开关是否开启 |
| `get_cube_passthrough_state() -> Dictionary` | `enabled` / `locked` / `rects`（游戏 UI + HUD + 拖动圆点矩形数量）/ `polygon_points`（窗口区域多边形顶点数） |

```gdscript
print(TestAPI.set_window_pinned("MainWindow", true))
print(TestAPI.is_window_pinned("MainWindow"))
print(TestAPI.get_window_pin_states())
print(TestAPI.set_cube_screen_position(Vector2(160, 800)))
print(TestAPI.get_cube_screen_position())
print(TestAPI.get_active_panel_name())
print(TestAPI.get_visible_panel_rects())
print(TestAPI.set_cube_passthrough_enabled(true))
print(TestAPI.get_cube_passthrough_state())
```

窗口置顶状态存在 `user://Settings.cfg` 的 `[window_pins]` 段，只有 `main_window` 一个键。立方体位置不持久化：拖动圆点或调用 `set_cube_screen_position()` 只改内存坐标，重启回到屏幕中心，`Settings.cfg` 不再有 `[cube]` 段。面板置顶/激活由 `Main/panel_manager.gd` 统一管理：打开或点击面板时 `move_to_front()`，`get_active_panel_name()` 读当前激活面板。透明区域点击穿透由 `Main/Cube/Scripts/window_passthrough.gd` 管理：用 `mouse_passthrough_polygon` 把立方体投影凸包 + 可见游戏面板 + Tooltip/Item + HUD Toast + 拖动圆点合成一个窗口区域，区域外点击落到桌面；`get_cube_passthrough_state()` 返回当前开关、是否处于拖动锁定、矩形数量和区域多边形顶点数。单窗口模式下面板没有独立系统置顶；`BaseWindow` 的标题栏只负责拖动和关闭。`TooltipWindow` / `ItemWindow` 是主视口内的浮层（CanvasLayer 1026 / 1025），不参与置顶。

## 立方体外壳

| 方法 | 说明 |
|---|---|
| `get_cube_state() -> Dictionary` | `cube_scale` / `screen_center` / `view_layer` / `orientation` / `front_face_index` / `ui_face_index` / `ui_face_viewport_size` / `passthrough` |
| `get_cube_layering_state() -> Dictionary` | `cube_layer` / `game_ui_layer` / `hud_layer` / `tooltip_layer` / `drag_layer`、`above_game_ui` / `above_hud` / `hud_above_cube` / `below_tooltip` / `below_drag_ghost`、`input_ready` / `hull_points` / `viewport_size` |
| `set_cube_face_front(index) -> bool` | 立即把指定面转到正对相机（测试用，跳过动画） |
| `get_cube_face_content(index) -> String` | `save_slots` / `pet_panel` / `character_select` / `face_ui` / `unknown` |
| `get_cube_face_lock_state(index) -> bool` | 面是否锁定；02 只在 `IN_GAME` 解锁，04 只在 `CHARACTER_SELECT` 解锁 |
| `click_cube_face_button(index) -> bool` | 触发普通 FaceUI 面的识别按钮；非 FaceUI 面返回 false |
| `click_cube_new_game() -> bool` | 点击 01 面「新游戏」按钮 |
| `click_cube_save_slot(slot) -> bool` | 点击 01 面指定存档位（0..5） |
| `click_cube_delete_save_slot(slot) -> bool` | 点击 01 面指定存档位的删除按钮；第一次确认、第二次才删；活动槽返回 false |
| `click_cube_character(character_id) -> bool` | 点击 04 面指定角色（当前 `&"small_coal_lamp"`） |
| `click_cube_pet_button(panel_id) -> bool` | 触发面 02 主菜单按钮（id 如 `inventory`），走完整信号链，窗口在主视口打开 |

```gdscript
print(TestAPI.get_cube_state())
print(TestAPI.get_cube_layering_state())
print(TestAPI.get_cube_face_content(0))       # save_slots
print(TestAPI.get_cube_face_lock_state(1))     # 启动 true
print(TestAPI.click_cube_new_game())           # → 04 面
print(TestAPI.click_cube_character(&"small_coal_lamp"))  # → 02 面
print(TestAPI.click_cube_save_slot(0))
print(TestAPI.click_cube_pet_button(&"inventory"))
```

- 面索引：0 正面（存档位）、1 背面（主菜单）、2 左面（FaceUI）、3 右面（角色选择）、4 上面、5 下面；启动正对 01 面。
- 01/02/04 面是 300×300 子视口，03/05/06 仍是 512×512；`get_cube_state().ui_face_index` 仍指面 02 主菜单视口。
- 立方体渲染在 `CubeView`（layer 1024）的透明子视口里；HUD 也在 1024 但树中更靠后，Toast 压在立方体上。`get_cube_layering_state()` 应返回 `above_game_ui=true`、`above_hud=false`、`hud_above_cube=true`、`below_tooltip=true`、`below_drag_ghost=true`；`input_ready=true` 表示子视口、相机、朝向、CubeRig 和拖动圆点都解析成功。
- 锁定面仍可拖动旋转；`Face3D` 的指针方法全部被拦，锁图覆盖在内容上。
- `set_cube_face_front(1)` 后可直接点击/测试主菜单；启动/读档流程应使用 `new_game()` / `load_save_slot()`，让 `GameFlow` 负责解锁和翻面。
- 面板坐标和 `get_visible_panel_rects()` 返回的是主视口像素坐标。
- 面内容的信号链与锁定规则见 `架构/开局流程.md`；翻面动画在 `CubeOrientation.rotate_to_face()`，`set_cube_face_front()` 是瞬移版本。

## 颜色

| 方法 | 说明 |
|---|---|
| `get_game_color(name) -> String` | 按常量名取 `GameColors` 的十六进制色值，如 `"DAMAGE"`、`"TEXT_PRIMARY"`；`Color` 常量会转成 HTML 色值 |
| `get_color_catalog() -> Dictionary` | 色板目录：`groups`（分组/名称/hex/color）、`aliases`（同色别名）、`ungrouped`、`status`、`terminal` |
| `validate_color_groups() -> Array[String]` | 校验 `GameColors.GROUPS`：返回未归类、拼错、重复归类等问题；空数组表示全部归类正确 |

## 终端

| 方法 | 说明 |
|---|---|
| `terminal_write_line(text) -> bool` | 向当前场景里的 `TerminalView` 写一行；预览场景/终端窗口用，找不到返回 `false` |
| `terminal_write_ansi(text) -> bool` | 按 ANSI 转义序列写入当前 `TerminalView`（支持 SGR 颜色/样式）；找不到返回 `false` |
| `terminal_set_content(text) -> bool` | 整屏替换为多行纯文本（`\n` 分行），清空历史并回到底部 |
| `terminal_set_ansi_content(text) -> bool` | 同 `terminal_set_content`，但按 ANSI 解析 |
| `terminal_scroll(lines) -> bool` | 往历史翻 `lines` 行；正值向上、负值向下 |
| `terminal_scroll_to_bottom() -> bool` | 回到实时屏幕并恢复自动滚底 |
| `terminal_clear() -> bool` | 清空当前 `TerminalView`（屏幕 + 历史）；找不到返回 `false` |
| `terminal_set_grid(enabled) -> bool` | 开关当前 `TerminalView` 的调试网格；找不到返回 `false` |
| `terminal_snapshot() -> Dictionary` | 返回 `{cols, rows, cell, cursor, history, view_offset, auto_scroll, spans}`；`spans` 是跨格大字矩形数组；找不到返回 `{}` |
| `tooltip_snapshot() -> Dictionary` | 浮动 `TooltipWindow` 内容终端状态（标题 span + 正文）：`{grid, debug_grid, body_visible, tooltip_size, spans}`；未显示返回 `{}` |
| `show_terminal() -> bool` | 打开终端窗口；找不到窗口返回 `false` |
| `is_terminal_open() -> bool` | 终端窗口当前是否可见；找不到窗口返回 `false` |
| `terminal_show_soul_tooltip(id, equipped := false, grid := true) -> bool` | 把魂灵 tooltip（标题粗体 + ANSI 正文）写进终端并打开窗口；`equipped` 时用动态预览值，`grid` 默认打开调试网格 |
| `terminal_show_vessel_tooltip(id, grid := true) -> bool` | 把魂器模板 tooltip 写进终端并打开窗口；`grid` 默认打开调试网格 |
| `terminal_show_equipped_vessel_tooltip(slot := 0, grid := true) -> bool` | 把魂器网格里第 `slot` 个魂器的 tooltip 写进终端并打开窗口；`grid` 默认打开调试网格 |

## 地图 / 数量石

| 方法 | 说明 |
|---|---|
| `get_map_ids() -> Array[StringName]` | 硬编码地图 id；当前只有 `forest_map` |
| `validate_maps() -> Array[String]` | 校验地图配置、怪物 id 和数量石资源；空数组表示通过 |
| `add_map_to_warehouse(map_id := &"forest_map") -> bool` | 生成一张地图并放进仓库 |
| `add_quantity_stone_to_warehouse() -> bool` | 生成一颗数量石并放进仓库 |
| `get_map_board_state() -> Dictionary` | 05 面快照：8 个槽位的 `occupied/map_id/name` + `pending` |
| `add_map_to_board(map_id := &"forest_map", slot_index := -1) -> int` | 直接往地图板放一张图；返回槽位，失败 `-1` |
| `eject_map_from_board(slot_index) -> bool` | 走地图按钮右上角 ⬇ 的退回仓库流程 |
| `start_map_battle_from_board(slot_index) -> bool` | 走 05 面按钮点击：打开战斗窗口并按这张图开战 |
| `click_map_drop_slot() -> bool` | 模拟点击中心槽；先把地图拿在手上，再调用它 |

## 战斗

| 方法 | 说明 |
|---|---|
| `start_battle(map_id := &"forest_map") -> bool` | 用指定地图打开战斗窗口并开战；没有地图资源返回 `false` |
| `stop_battle() -> void` | 结束当前战斗 |
| `spawn_monster(monster_id) -> bool` | 在远处空位刷一只指定怪 |
| `apply_burn(target := "player") -> bool` | 对战斗单位施加灼烧（测试状态与火焰 Cue） |
| `apply_poison(target := "player") -> bool` | 对战斗单位施加剧毒（测试飞溅与气泡 Cue） |
| `apply_regen(target := "player") -> bool` | 对战斗单位施加生命再生（测试剧毒/生命再生相减） |
| `apply_freeze(target := "player", seconds := 3.0) -> bool` | 对战斗单位施加冻结（测试冻结 Cue 与 `State.Frozen`）；会广播 `Event.Combat.FreezeApplied` |
| `play_claw_cue(target := "enemy", direction := 1) -> bool` | 在单位身上播放爪痕 Cue；`direction` 1 = 左→右，-1 = 右→左 |
| `apply_soul_freeze(soul_name, seconds := 1.0, target := "player") -> bool` | 对已装备的指定魂灵施加魂灵级冻结（测试冰霜 shader 与徽章） |
| `simulate_soul_used(soul_name, target := "player") -> bool` | 模拟“魂灵被使用”（不动冷却），确定性验证 `Event.Combat.SoulUsed` 触发器；触发充能满时会走同帧待释放队列，调用后等一帧再读状态 |
| `charge_soul(soul_name, seconds, target := "player") -> bool` | 给已装备魂灵直接充能，用于快速触发主动技能；不经过触发器队列 |
| `damage_unit(target := "player", amount := 1.0) -> bool` | 对单位造成伤害，用于把生命值打到阈值以下（测半血触发）；`amount` 先向下取整，不足 1 点不生效 |
| `has_status(tag, target := "player") -> bool` | 单位是否拥有某个状态标签 |
| `get_battle_state() -> Dictionary` | 战斗快照；含 `map_id` / `map_finished` / `map` / `map_kills` / `pending_spawns` |
| `get_enemy_count() -> int` | 当前存活敌人数 |
| `get_nearest_enemy_distance() -> float` | 最近敌人到角色的像素距离；没有敌人返回 -1 |
| `get_enemies_in_attack_range() -> int` | 当前在角色攻击范围内的敌人数（即时制下只有这些怪才充能） |
| `get_perf_snapshot() -> Dictionary` | 性能快照：FPS、节点数、敌人数、范围内敌人数、最近距离 |
| `get_battle_log() -> String` | 当前战斗日志纯文本（`InfoWindow` 的 500 行缓冲，含时间前缀） |
| `get_fps_text() -> String` | 战斗窗口右上角的 FPS 文本 |

`target` 支持 `"player"`、`"enemy"` 或单位名。灼烧测试可用：

```gdscript
TestAPI.apply_burn("player")
print(TestAPI.has_status(&"State.Burning", "player"))

TestAPI.apply_poison("enemy")
print(TestAPI.has_status(&"State.Poisoned", "enemy"))

# 剧毒/生命再生直接相减：毒 8、生命再生 5 时每秒净扣 3 点生命
TestAPI.apply_regen("enemy")
await get_tree().create_timer(1.3).timeout
print(TestAPI.get_battle_state()["enemies"][0]["hp"])

TestAPI.apply_freeze("enemy", 3.0)
print(TestAPI.has_status(&"State.Frozen", "enemy"))
TestAPI.apply_soul_freeze("<魂灵名>", 1.0)  # 参数是已装备魂灵的显示名

# 爪痕：分别看左右两个方向
TestAPI.play_claw_cue("enemy", 1)
await get_tree().create_timer(0.2).timeout
TestAPI.play_claw_cue("enemy", -1)

# 半血触发：把玩家打到阈值以下，再检查触发器效果
TestAPI.damage_unit("player", 300.0)
print(TestAPI.has_status(&"State.Frozen", "enemy"))

# 伤害缩放：清空魂器网格，装上任意魂器并放入任意魂灵
TestAPI.clear_container("vessel_cells")
var vessel_id: StringName = TestAPI.get_vessel_ids()[0]
var soul_id: StringName = TestAPI.get_soul_ids()[0]
TestAPI.equip_vessel(vessel_id)
TestAPI.vessel_add_soul(soul_id, 0)
print(TestAPI.get_soul_damage_scaling(soul_id))
TestAPI.vessel_add_soul(soul_id, 0)
print(TestAPI.get_soul_damage_scaling(soul_id))

# 未开战也按“装上这份魂器后”预览
print(TestAPI.get_equipped_soul_damage_preview(soul_id))

# 直接充能触发主动技能；替换成一颗有主动技能的魂灵
TestAPI.start_battle()
# 战斗中优先运行期值；tooltip 的伤害数值带 * 前缀
print(TestAPI.get_equipped_soul_damage_preview(soul_id))
print(TestAPI.get_equipped_soul_tooltip_text(soul_id))
var soul_name: String = TestAPI.get_soul_card_info(soul_id)["label"]
TestAPI.charge_soul(soul_name, 6.5)
await get_tree().physics_frame
print(TestAPI.get_battle_state()["player_souls"])

# 模拟“魂灵被使用”事件；当前没有魂灵配置 SoulUsed 触发器，接口保留
TestAPI.simulate_soul_used(soul_name)
print(TestAPI.get_battle_state()["player_souls"])
```

快照结构：

```gdscript
{
  "running": true,
  "elapsed": 12.3,
  "player": {"name", "hp", "max_hp", "shield", "regen", "poison", "dead", "frozen",
             "cell", "position", "distance_to_player", "in_attack_range", "souls"},
  "enemies": [{"name", "hp", "max_hp", "shield", "regen", "poison", "dead", "frozen",
               "cell", "position", "distance_to_player", "in_attack_range", "souls"}],
  "player_souls": [{"name", "cooldown", "charge_ratio", "charge_seconds", "haste", "slow",
                    "freeze", "frozen", "active", "activation_lock"}],
  "map_id": "forest_map",
  "map_finished": false,
  "map": {
	"map_id": "forest_map",
	"entries": [
	  {"monster_id": "snake_monster", "condition": "time", "spawned": 12,
	   "count": 200, "kill_progress": 0, "kill_threshold": 1},
	  {"monster_id": "fu_monster", "condition": "kill", "spawned": 0,
	   "count": 0, "kill_progress": 3, "kill_threshold": 10}
	]
  },
  "map_kills": {"snake_monster": 10},
  "pending_spawns": 0
}
```

`player_souls[].freeze` 是魂灵级冻结剩余秒数；`frozen` 是 `is_frozen()`（自身冻结或单位冻结）。单位的 `frozen` 只表示 `State.Frozen` 标签。`charge_seconds` 用于精确验证充能触发（例如相邻魂灵被使用后 +1 秒）。`active` 是技能是否还在执行中（投射物发射后不再占用它）；`activation_lock` 是 20 刻激活锁的剩余秒数，用于验证 1 秒最多 6 次的限制。

即时制下 `cell` 只是“当前压在地图哪一格”，真实位置看 `position`（像素）；`distance_to_player` 和 `in_attack_range` 用来验证“进范围才充能”。

## 调试 / 遥测

| 方法 | 说明 |
|---|---|
| `get_debug_events(category := "", limit := 200) -> Array` | 最近调试事件；`category` 见 `CombatEvent`（`battle`/`cast`/`soul`/`trigger`/`effect`/`attribute`/`tag`/`cue`/`log`/`system`） |
| `get_debug_stats() -> Dictionary` | 缓冲大小、丢失数、场次、关注单位、文件录制状态 |
| `get_debug_snapshot() -> Dictionary` | 当前战斗快照（玩家完整详情、敌人摘要） |
| `get_soul_runtime(soul_name, target := "player") -> Dictionary` | 某颗已装备魂灵的运行期状态（冷却/充能/状态/统计/触发器） |
| `get_trigger_state(soul_name, target := "player") -> Array` | 某颗魂灵的触发器列表与 `fired` 状态 |
| `clear_debug_events() -> void` | 清空事件缓冲 |
| `export_debug_log(path := "user://debug/test.jsonl") -> String` | 导出 JSONL，返回绝对路径 |
| `set_debug_recording(enabled) -> void` | 开关遥测；关闭后 `record()` 直接返回 |
| `watch_unit_for_debug(target := "player") -> bool` | 设置关注单位，详细事件只记录它 |

事件里带 `trace_id / parent_trace_id / root_trace_id`，可用 `CombatTelemetry.get_trace_chain(trace_id)` 还原因果链。

## 注意

- 只用于测试/探针；会改运行时状态。
- `set_unlock_all(false)` 后，`add_soul` 仍会走正常入包流程，并打上存档脏标记，由 `SaveManager` 写入当前活动槽。
- `set_unlock_all` 只改判定，不会自动刷新已打开的见闻窗口；切页签或重开窗口即可。
- `player.souls` 是场景配置（玩家通常为空）；玩家装备的魂灵看 `player_souls`。
- `start_battle` 会显示战斗窗口并按指定地图开战；找不到 `BattleWindow` 或地图资源时返回 `false`。战斗窗口不能空开，必须先有地图。
- 地图刷怪进度只在运行期；探针里验证完成/重开需要真实等待 5 秒，或用 `TestAPI.damage_unit("enemy", 大数字)` 快速清场。
- 游戏已移除倍速功能，`TestAPI` 不再提供 `set_time_scale`；需要验证长流程时用真实时间等待或多跑几帧。
- 新增全局类后，如果 headless 直接跑提示 `TestAPI` 未声明，先跑一次 `--headless --path . --import` 刷新全局类缓存。
- 新增魂灵/怪物/技能/窗口时，先看这里要不要补方法。
