# 背包 / 仓库系统（GBIS）

> 类型：实现 | 状态：有效 | 核对：2026-11-21
> 何时读：改背包/仓库/魂器容器/魂器网格、拖拽、商店容器、存档
> 关键词：GBIS 背包 仓库 inventory container 物品大类 category 魂器 vessel vessel_cells 魂器网格 地图 MAP STONE 数量石 拖拽 Tooltip 存档 分页 Warehouse 商店 Shop
> 代码：game/inventory/grid_base_inventory_system/、Scripts/warehouse.gd
> 不覆盖：仓库玩法设计（见 DOC/窗口/仓库窗口.md）

## 1. 背包 / 仓库系统（GBIS）

### 1.1 接入方式

- 框架代码在 `game/inventory/grid_base_inventory_system/`，属 `game/` 领域层，不是 `addons/` 第三方；`SoulData`、`ItemView` 等已按项目需求改造。
- 框架的 autoload 脚本是 `game/inventory/grid_base_inventory_system/core/grid_base_inventory_system.gd`，全局名必须是 `GBIS`；autoload 按 UID 引用，目录移动不改 `project.godot`。
- `GBIS` 在启动时 `new` 出所有 Service，外部不要自己再 `new`：
  - `inventory_service`、`shop_service`、`equipment_slot_service`、`moving_item_service`、`item_focus_service`。
- `ContainerRepository` / `EquipmentSlotRepository` 是 `Resource` 单例（`static var instance`），通过 `GBIS` 的 Service 访问。
- 视图层通过 `GBIS` 的信号刷新，不直接互相引用。
- 游戏层另有 `Warehouse` autoload（`Scripts/warehouse.gd`）：启动时预注册 `inventory_0..inventory_9` 十页仓库，并提供 `add_item()` 跨页找空位；它只调用 GBIS 的公开接口，不修改框架本身。每页用独立数组，避免多个 `ContainerData` 共享同一只只读常量。
- `Service` 不在场景树里，没有 `get_tree()`；需要取根时走 `GBIS.get_root()`。
- 容器名常量集中在 `Scripts/container_ids.gd`（`inventory_0`、`shop_0`、`vessel_cells`）；场景 `.tscn` 里的 `container_name` 仍是字面量，改名时必须两边一起改。
- 场景漂移校验：`--headless --script res://EngineTools/modkit/validate_container_ids.gd` 对比场景字面量与常量；运行中的主场景可用 `TestAPI.validate_container_ids()` 检查容器是否都已注册。

### 1.2 分层与主要类

`core/` 按 `model/`（`ItemData` / `SoulData` / `SoulVesselData` / `ContainerData`）、`repository/`（`ContainerRepository`）、`service/`（容器 / 背包 / 拖拽 / 悬停）、`view/`（容器与物品绘制）分层，类清单以目录为准；`grid_base_inventory_system.gd` 是 autoload 入口。`SoulData` 的技能/触发规则在基类上，运行期状态在游戏层 `SoulRuntime`。

未接入的 `StackableData`、`ConsumableData`、`EquipmentData`、`EquipmentSlot*`、`DropAreaView` 见 1.8；商店见 1.7。

`SoulData.triggers` 在 `soul_data.gd` 基类上，主动/被动魂灵通用；`PassiveSoulData`（`game/content/passive_soul_data.gd`）只额外新增 `passive_effects`。`PassiveTrigger` 位于 `game/content/passive_trigger.gd`。它们属于游戏内容层，不修改 GBIS 框架本身。

`ItemView` 对魂灵、魂器、地图和数量石会额外创建 `ItemNameLabel`：铺满图标区域、居中显示 `item_name`，字号随卡面宽度缩放并自动换行。背包、装备槽、拖拽幽灵共用同一个 `ItemView`，三处显示一致；见闻窗口和调试窗口各自已有名字文本，不重复加。

### 1.3 GBIS 信号

信号声明在 `core/grid_base_inventory_system.gd`，参数以声明为准；视图只监听，不互相引用。

当前项目实际监听：

- `InventoryView`：`sig_inv_item_added/removed/updated` 做增量更新，`sig_inv_refresh` 只置脏；
- `ShopView`：`sig_inv_refresh` 只置脏；
- `EquipmentSlotView`：`sig_slot_refresh` 只置脏。
- `TooltipWindow`：`sig_item_focused` / `sig_item_focus_lost`，用来显示/隐藏 `ITEM` 层；`SoulData` / `SoulVesselData` / `MapItemData` / `QuantityStoneData` 分别由 `SoulTooltip.build()` / `VesselTooltip.build()` / `MapTooltip.build()` / `QuantityStoneTooltip.build()` 生成正文，其他物品只有标题。仓库、角色魂器网格、魂器窗口、05 面地图按钮共用这一套悬停提示。

### 1.4 数据流

**注册容器**

```
InventoryView._ready()
  → GBIS.inventory_service.regist(name, columns, rows, false, avilable_types)
  → ContainerRepository.add_container()  （同名直接返回已有容器）
  → ContainerData（建立 grid_item_map）
  → InventoryView 创建 GridContainer + 格子 View + 物品容器
  → 连接 GBIS 信号
```

- `InventoryView._ready()` 在编辑器模式下只重算尺寸，不注册容器。
- 仓库页由 `Warehouse` 预注册；`InventoryView._ready()` 再注册同名容器时 `regist()` 直接返回已有容器，不会重建数据。
- 容器可见时会把名字加入 `GBIS.opened_containers`，不可见时移除；快速移动和快速出售只考虑打开着的容器。`_ready()` 用 `is_visible_in_tree()` 判断，隐藏窗口里的视图不会提前登记。
- 所有视图继承 `RefreshableView`：数据变化只调 `mark_dirty()`。可见时在本帧末合并重建一次；隐藏时只记脏，下次显示、布局结算后重建。重建后清脏；没有脏标记时显示只调 `_on_shown_without_refresh()` 把 ItemView 按当前格子坐标重新摆放，避免隐藏阶段布局未结算导致物品叠在容器原点。
- 仓库翻页调用 `InventoryView.change_data_source()`：目标页行列不变时保留格子 Control 和信号连接（仓库 10 页均为 26×24），只清物品与占用状态；行列变化时才重建格子层。翻页后同样只置脏。
- `await process_frame` 之后若窗口又被关掉，本次不刷新，脏标记留到下次显示。

**添加物品**

```
GBIS.add_item(inv_name, item_data)
  → InventoryService.add_item()
      → item_data.duplicate()          （每件物品独立实例）
      → ContainerData.add_item()
          → is_item_avilable()         （类型 + 魂器类型/件数检查）
          → 找第一个放得下的位置
      → sig_inv_item_added.emit()
  → InventoryView._on_item_added()     （只处理自己的容器；不可见时只置脏）
  → 创建 ItemView                       （不可见时等下次显示统一重建）
```

**拖拽物品**

```
左键点在有物品的格子
  → InventoryGridView._gui_input()
  → InventoryView.handle_grid_click()
      → MovingItemService.pick_from_grid()
          → 从 ContainerData 移除（发 sig_inv_item_removed）
          → DragPresenter 创建幽灵 ItemView，ItemWindow.hold(抓取偏移)
  → ItemWindow._process() 每帧跟随鼠标

左键点在目标格子
  → InventoryView.handle_grid_click()
      → MovingItemService.drop_on_grid()
          → ContainerData.drop_state_at() 判定空格 / 堆叠 / 禁止
          → InventoryService.place_moving_item() 或 stack_moving_item()
          → 成功后 finish() 清状态并发 drag_ended
```

- `MovingItemService` 是拖拽状态的唯一入口：`pick_from_grid / pick_from_slot / begin_detached` 开始，`drop_on_grid / drop_on_slot / sell_dragged / drop_to_world / cancel` 结束；只有 `finish()` 清状态并发出 `drag_ended`。
- `DragOrigin` 记录来源（GRID / SLOT / NONE）。右键取消时 GRID 放回原格，SLOT 放回原槽，NONE（分割等）保持原样；原格被占用则放同容器第一个空位，容器满则留在手上并 warning。
- 能否放下由 `ContainerData.drop_state_at()`（BLOCKED / PLACE / STACK）和 `EquipmentSlotData.can_accept()` 判定，高亮预览、实际放置和装备共用同一套规则。
- 堆叠要求同名、未满，且移动形状被同一颗物品完整覆盖（不能有空格）。
- `DragPresenter` 只管幽灵视图、`ItemWindow` 和 `DropAreaView` 显隐；`MovingItemService` 不再直接碰这些视图。
- 多格物品内部跨格会「先离格再进格」，焦点丢失延迟到本帧末结算；回到同一物品就撤销。窗口关闭时要手动调用焦点丢失，防止 tooltip 残留。
- `auto_register = false` 的视图在绑定数据源前没有容器，显示时先留空。
- `clear()` 只清显示，不动数据库；先摘出树再 `queue_free()`，翻页重建时新旧 `ItemView` 不会同帧叠在一起。
- 没有 `ItemWindow` 时幽灵视图从未入树，需要自己释放，否则泄漏。
- Godot 4 的 `Dictionary` 是引用类型，`duplicate()` 出来的物品共用 `shader_params`；改前必须先复制一份，否则会连带改掉所有同类实例和预制资源。
- 运行期状态变化只改材质参数和徽章，不重绘整个 `ItemView`；冻结直接改材质参数，不依赖 `shader_params` 里是否登记 `freeze`。
- 各 service 只做存储操作，不再自己清拖拽状态；`InventoryView` / `EquipmentSlotView` 收到 `drag_ended` 后清残留高亮。
- `ItemWindow` 是主视口内的 `Control` 浮层（`DragLayer`，layer 1025），每帧跟主视口鼠标，整棵子树 `mouse_filter = IGNORE`，不会挡住放置/取消事件。单窗口模式下不再需要独立无边框窗口、topmost、屏幕外预热或焦点降级；幽灵只在主窗口内，拖出窗口会被裁掉。

### 1.5 本项目的扩展：魂器容器与魂器网格

框架原本只有 `category`（物品大类）限制；本项目在三个地方加了“魂器类型/件数”限制：

| 位置 | 字段 | 作用 |
|---|---|---|
| `ItemData` | `container_kind_tag()`（默认空） | `SoulVesselData` 返回 `COMBAT / TOOL`，供容器过滤 |
| `ContainerData` | `vessel_kind`（空 = 不限制） | 只收对应类型的魂器；角色魂器网格填 `COMBAT` |
| `ContainerData` | `max_items`（0 = 不限制） | 可选的件数上限；角色魂器网格不设，能放几件由格子和魂器占格决定 |
| `InventoryView` | `vessel_kind` / `max_items` | 编辑器里配置；`_ready()` / `change_data_source()` 写进 `ContainerData` |

`ContainerData.is_item_avilable()` 的判定顺序：

1. `avilable_types` 必须是 `ANY` 或包含物品的 `category`；
2. `max_items > 0` 时件数不能超限（正在移动的同一件不算）；
3. 容器有 `vessel_kind` 时，物品的 `container_kind_tag()` 必须相同；
4. 否则允许。

容器清单：

| 容器名 | 节点 | 尺寸 | 类型/限制 | 用途 |
|---|---|---|---|---|
| `vessel_cells` | `CharacterWindow/.../VesselGrid` | 9×3 | `VESSEL` + `COMBAT` | 角色装备战斗魂器；能放几件由格子和魂器占格决定 |
| 魂器内部容器 | 运行时按 `vessel_<id>` 注册 | 由魂器数据决定（示例 6×2） | `SOUL` | 魂器窗口里的实际容器；内容随魂器物品存档 |
| `inventory_0..inventory_9` | `InventoryWindow/InventoryView`（只挂当前页） | 26×24 | `SOUL` + `VESSEL` + `MAP` + `STONE` | 仓库 10 页；掉落和见闻右键入仓从第 1 页开始找空位；地图/数量石也放这里 |

仓库页由 `Warehouse` autoload 启动时预注册，未翻到的页也在 `GBIS.inventory_names` 里，因此存档会覆盖全部页。`inventory_0` 仍是第 1 页。

魂器内部容器平时不在 `ContainerRepository` 里：打开魂器窗口时按实例名注册，供 `InventoryView`、拖拽服务和悬停提示使用；容器内容随魂器物品记录嵌套保存，详见 `魂灵/魂器.md` 和 `架构/存档.md`。

### 1.6 交互键位

| 操作 | 输入 | 代码入口 |
|---|---|---|
| 拿起物品 | 左键点有物品的格子 | `InventoryGridView._gui_input()` → `InventoryView.handle_grid_click()` → `MovingItemService.pick_from_grid()` |
| 取消拿起 | 手上有物品时按右键 | `InventoryView._input()` → `MovingItemService.cancel()` |
| 放下物品 | 左键点空/可放置格子 | `MovingItemService.drop_on_grid()` → `InventoryService.place_moving_item()` |
| 堆叠 | 左键点同类型可堆叠物品 | `MovingItemService.drop_on_grid()` → `InventoryService.stack_moving_item()` |
| 快速移动 | Shift + 左键 | `InventoryService.quick_move()` |
| 快速出售 | Shift + 右键 | `InventoryService.quick_sell()`（商店和该仓库页都打开时） |
| 使用/激活 | 右键 | `InventoryService.use_item()`；魂器 `activate()` 返回 true 时发 `GBIS.sig_item_activated`，魂器窗口监听后打开 |
| 分割 | 中键（且当前没有拖拽物） | `InventoryService.split_item()` |

角色魂器网格和魂器窗口都用 `InventoryView`，拖拽规则与仓库一致；装备槽的 `EquipmentSlotView` 仍未接入。右键魂器时如果正在拖拽，先走“取消拿起”，不会误开窗口。

### 1.7 商店

`ShopWindow`（`Windows/Shop/shop_window.tscn`）内嵌 `ShopView`，容器名 `shop_0`，20 列 × 10 行（32 px 格子，640×320；窗口 640×356）。`ShopView._ready()` 会注册商店容器，并清空后重新加载场景 `goods` 数组里的货物。

- 点击货物：`ShopService.buy()` 检查 `ItemData.can_buy()`，把物品复制进第一个有空位的背包，再调 `cost()`；默认 `can_buy()` 恒为 `true`，`cost()` 只打警告。购买链路只在服务层，模型不再反向调用 `inventory_service`。
- 拖着物品点商店格子：`MovingItemService.sell_dragged()` → `ShopService.sell_item()` → `ItemData.can_sell()` / `sold()`；默认 `can_sell()` 为 `true`，`sold()` 只打警告，物品从手上消失，拖拽由 `finish()` 统一结束。
- Shift + 右键点仓库物品：`InventoryService.quick_sell()` 直接结算并移除原格物品；要求商店和该仓库页都在 `GBIS.opened_containers` 里，否则不生效。
- 商店与背包共用数据源；保存背包时会一并保存商店，不需要单独保存商店。
- 价格、货币、货物配置都还没定义。正式做买卖需要具体的 `ItemData` 子类重写 `can_buy()` / `cost()` / `can_sell()` / `sold()`，货物可填 `ShopView.goods` 或调 `ShopService.load_goods()`。

### 1.8 框架自带、当前未接入的部分

这些代码还在，但当前游戏没有使用；按“保留 GBIS 库完整、便于同步上游”的项目决策，本轮不删除：

- `EquipmentSlotView` / `EquipmentSlotData` / `EquipmentSlotRepository` / `EquipmentSlotService`：传统单槽装备系统；
- `DropAreaView`：把物品拖出窗口丢弃；
- `ConsumableData` / `EquipmentData` / `StackableData`：消耗品、可穿戴装备、可堆叠物品；
- `GBIS.add_quick_move_relation()`：背包间快速移动关系；
- `GBIS.save()` / `GBIS.load()`：框架自带的 Resource 存档，当前仍不接入；游戏层存档由 `SaveManager` 负责，见 `架构/存档.md`；
- `GBIS.item_material`：全局物品材质，当前未设置。
