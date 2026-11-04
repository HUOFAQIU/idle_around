# 背包 / 仓库系统（GBIS）

> 类型：实现 | 状态：有效 | 核对：2026-11-05
> 何时读：改背包/仓库/装备槽/容器、拖拽、商店容器、存档
> 关键词：GBIS 背包 仓库 inventory container 物品大类 category 装备槽 拖拽 Tooltip 存档
> 代码：Windows/Inventory/grid_base_inventory_system/
> 不覆盖：仓库玩法设计（见 DOC/窗口/仓库.md）
>
> 旧版架构长文第 7 节。

## 7. 背包 / 仓库系统（GBIS）

### 7.1 接入方式

- 框架的 autoload 脚本是 `Windows/Inventory/grid_base_inventory_system/core/grid_base_inventory_system.gd`，全局名必须是 `GBIS`。
- `GBIS` 在启动时 `new` 出所有 Service，外部不要自己再 `new`：
  - `inventory_service`、`shop_service`、`equipment_slot_service`、`moving_item_service`、`item_focus_service`。
- `ContainerRepository` / `EquipmentSlotRepository` 是 `Resource` 单例（`static var instance`），通过 `GBIS` 的 Service 访问。
- 视图层通过 `GBIS` 的信号刷新，不直接互相引用。

### 7.2 分层与主要类

```
core/
├─ grid_base_inventory_system.gd        GBIS autoload：信号、Service、全局配置
├─ model/
│  ├─ item/ItemData                     物品基类：名称、类型、图标、占格、材质、shader 参数
│  ├─ item/SoulData                     extends ItemData：skill + equip_part + 战斗显示用剩余秒数
│  └─ container/ContainerData           网格容器：格子↔物品映射、放置规则
├─ repository/
│  └─ ContainerRepository               所有 ContainerData 的存取与存档
├─ service/
│  ├─ BaseContainerService              注册容器、按格子/名字查物品、放置物品
│  ├─ InventoryService                  背包：添加/移除/使用/分割/快速移动
│  ├─ MovingItemService                 拖拽中的物品与跟随鼠标的 ItemView
│  └─ ItemFocusService                  鼠标当前悬停的物品（tooltip 用）
└─ view/
   ├─ container/BaseContainerView       容器视图基类：网格 + 物品绘制
   ├─ container/InventoryView           背包视图（可配置类型/部位）
   ├─ container/BaseGridView            单个格子的绘制与悬停
   ├─ container/InventoryGridView       背包格子输入：左键拿/放、右键用、Shift+左键快移、中键分割
   └─ item/ItemView                     物品图标 + 魂灵名称 Label + 堆叠数字 + shader 参数 + 魂灵加速/减速/冻结徽章
```

未接入的 `StackableData`、`ConsumableData`、`EquipmentData`、`EquipmentSlot*`、`Shop*`、`DropAreaView` 见 7.7。

`SoulData.triggers` 在 `soul_data.gd` 基类上，主动/被动魂灵通用；`PassiveSoulData`（`game/content/passive_soul_data.gd`）只额外新增 `passive_effects`。`PassiveTrigger` 位于 `game/content/passive_trigger.gd`。它们属于游戏内容层，不修改 GBIS 框架本身。

`ItemView` 对 `SoulData` 会额外创建 `SoulNameLabel`：铺满图标区域、居中显示 `item_name`，字号随卡面宽度缩放并自动换行。背包、装备槽、拖拽幽灵共用同一个 `ItemView`，三处显示一致；见闻窗口和调试窗口各自已有名字文本，不重复加。

### 7.3 GBIS 信号

| 信号 | 参数 | 用途 |
|---|---|---|
| `sig_inv_item_added` | `inv_name, item_data, grids` | 背包新增物品 |
| `sig_inv_item_removed` | `inv_name, item_data` | 背包移除物品 |
| `sig_inv_item_updated` | `inv_name, grid_id` | 物品数量/外观更新 |
| `sig_inv_refresh` | 无 | 整包刷新 |
| `sig_item_focused` | `item_data, container_name` | 鼠标悬停到物品 |
| `sig_item_focus_lost` | `item_data` | 鼠标离开物品 |

当前项目实际监听：

- `InventoryView`：`sig_inv_item_added/removed/updated/refresh`；
- `InventoryWindow`：`sig_item_focused` / `sig_item_focus_lost`，用来显示/隐藏 TooltipWindow 的 `ITEM` 层；`SoulData` 会附带 `SoulTooltip.build()` 生成的正文，其他物品仍只有标题。

### 7.4 数据流

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
- 容器可见时会把名字加入 `GBIS.opened_containers`，不可见时移除；快速移动只考虑打开着的背包。

**添加物品**

```
GBIS.add_item(inv_name, item_data)
  → InventoryService.add_item()
      → item_data.duplicate()          （每件物品独立实例）
      → ContainerData.add_item()
          → is_item_avilable()         （类型 + 部位检查）
          → 找第一个放得下的位置
      → sig_inv_item_added.emit()
  → InventoryView._on_item_added()     （只处理自己的容器，且必须可见）
  → 创建 ItemView
```

**拖拽物品**

```
左键点在有物品的格子
  → MovingItemService.move_item_by_grid()
      → 从 ContainerData 移除（发 sig_inv_item_removed）
      → ItemWindow.hold(ItemView, 抓取偏移)
  → ItemWindow._process() 每帧跟随鼠标

左键点在目标格子
  → InventoryService.place_moving_item()
      → ContainerData.try_add_to_grid()
      → sig_inv_item_added
```

- `MovingItemService` 里保存 `moving_item`、`moving_item_view`、`moving_item_offset`；
- `ItemWindow` 是独立无边框窗口，物品拖出原窗口也不会被画布裁掉；
- 取消/放下时 `MovingItemService.clear_moving_item()` 会清掉 `ItemWindow`。

### 7.5 本项目的扩展：魂灵部位限制

框架原本只有 `category`（物品大类）限制；本项目在三个地方加了“装备部位”：

| 位置 | 字段 | 作用 |
|---|---|---|
| `SoulData` | `equip_part`：`ANY / HEADSOUL / TORSOSOUL / ARMSSOUL / LEGSSOUL` | 这颗魂灵能装在哪个部位 |
| `ContainerData` | `equip_part`（空 = 不限制） | 这个容器只收对应部位的魂灵；`ANY` 魂灵不受限 |
| `InventoryView` | `equip_part`：`NONE / HEADSOUL / ...` | 编辑器里配置；`_ready()` / `change_data_source()` 时把 `NONE` 归一成 `""` 写进 `ContainerData` |

`ContainerData.is_item_avilable()` 的判定顺序：

1. `avilable_types` 必须是 `ANY` 或包含物品的 `category`；
2. 如果容器有 `equip_part` 且物品是 `SoulData`，则 `soul.equip_part` 必须是 `ANY` 或与容器部位相同；
3. 否则允许。

魂灵窗口的四个容器就是四个“只收指定部位魂灵的小背包”，不是传统的单槽装备系统：

| 容器名 | 节点 | 部位 | 尺寸（实际） | 类型 |
|---|---|---|---|---|
| `cell_0` | `EquipmentWindow/VBoxContainer/Cell0/SoulView` | `HEADSOUL` | 10 列 × 2 行 | `SOUL` |
| `cell_1` | `EquipmentWindow/VBoxContainer/Cell1/SoulView` | `TORSOSOUL` | 10 列 × 2 行 | `SOUL` |
| `cell_2` | `EquipmentWindow/VBoxContainer/Cell2/SoulView` | `ARMSSOUL` | 10 列 × 2 行 | `SOUL` |
| `cell_3` | `EquipmentWindow/VBoxContainer/Cell3/SoulView` | `LEGSSOUL` | 10 列 × 2 行 | `SOUL` |

> 注意：`DOC/魂灵/开发指导文件.md` 写的是“每个部位均有 10 格”，但当前 `InventoryView` 只设置了 `container_columns = 10`，`container_rows` 用默认值 2，所以实际是 10×2 = 20 格。后续要么改文档，要么在场景里显式设置 `container_rows`。

仓库容器：

| 容器名 | 节点 | 尺寸 | 类型 | 用途 |
|---|---|---|---|---|
| `inventory_0` | `InventoryWindow/InventoryView` | 26×24 | `SOUL` | 仓库，也是怪物掉落的目的地 |

### 7.6 交互键位

| 操作 | 输入 | 代码入口 |
|---|---|---|
| 拿起物品 | 左键点有物品的格子 | `InventoryGridView._gui_input()` |
| 放下物品 | 左键点空/可放置格子 | `InventoryService.place_moving_item()` |
| 堆叠 | 左键点同类型可堆叠物品 | `InventoryService.stack_moving_item()` |
| 快速移动 | Shift + 左键 | `InventoryService.quick_move()` |
| 使用 | 右键 | `InventoryService.use_item()` |
| 分割 | 中键（且当前没有拖拽物） | `InventoryService.split_item()` |

框架还支持装备槽的“点物品穿装备”和“右键脱装备”，但当前魂灵窗口用的是 `InventoryView`，不是 `EquipmentSlotView`，所以这套交互暂时没有接入魂灵。

### 7.7 框架自带、当前未接入的部分

这些代码还在，但当前游戏没有使用：

- `EquipmentSlotView` / `EquipmentSlotData` / `EquipmentSlotRepository` / `EquipmentSlotService`：传统单槽装备系统；
- `ShopView` / `ShopGridView` / `ShopService`：商店，`ShopWindow` 目前是空壳；
- `DropAreaView`：把物品拖出窗口丢弃；
- `ConsumableData` / `EquipmentData` / `StackableData`：消耗品、可穿戴装备、可堆叠物品；
- `GBIS.add_quick_move_relation()`：背包间快速移动关系；
- `GBIS.save()` / `GBIS.load()`：框架自带的 Resource 存档，当前仍不接入；游戏层存档由 `SaveManager` 负责，见 `架构/存档.md`；
- `GBIS.item_material`：全局物品材质，当前未设置。
