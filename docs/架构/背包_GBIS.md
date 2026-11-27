# 背包 / 仓库系统（GBIS）

> 类型：实现 | 状态：有效 | 核对：2026-11-27
> 何时读：改背包/仓库/魂器容器/魂器网格、拖拽、商店容器或 GBIS 接入边界
> 关键词：GBIS Warehouse ContainerData MovingItemService RefreshableView vessel_cells 仓库 拖拽 商店
> 代码：`game/inventory/grid_base_inventory_system/`、`scripts/warehouse.gd`、`scripts/container_ids.gd`
> 相关：`架构/窗口与场景.md`、`架构/存档.md`、`架构/见闻窗口.md`、`设计/魂器.md`
> 不覆盖：单窗口浮层 `ItemWindow` / `TooltipWindow` 细节（见 `架构/窗口与场景.md` §3）

## 符号地图

| 文件 | 核心入口 | 职责 |
|---|---|---|
| `scripts/warehouse.gd` | `page_name` / `add_item` / `add_item_to_page` | 预注册 10 页仓库与跨页入库 |
| `scripts/container_ids.gd` | `warehouse_page` / 常量表 | 全项目容器 ID 单一真相 |
| `game/inventory/grid_base_inventory_system/core/grid_base_inventory_system.gd` | `GBIS` autoload / `add_item` / `sig_inv_*` | 背包网格服务与刷新信号 |
| `windows/Inventory/inventory_window.gd` / `windows/Vessel/vessel_window.gd` | 面板视图 | 仓库分页与魂器内部网格展示 |

## 1. 接入方式与分层

- `game/inventory/grid_base_inventory_system/` 属项目领域层（已按需改造 `SoulData`/`ItemView`），autoload `GBIS` 按 UID 引用，启动时统一 `new` 出 5 个 Service（外部禁止再 `new`，取场景树根走 `GBIS.get_root()`）；`ContainerRepository` / `EquipmentSlotRepository` 为 `Resource` 单例。
- **`Warehouse` autoload**（`scripts/warehouse.gd`）启动预注册 `inventory_0..inventory_9` 十页仓库（每页独立数组），提供跨页 `add_item()`；容器名常量集中在 `scripts/container_ids.gd`，场景字面量漂移由 `engine_tools/modkit/validate_container_ids.gd` 与 `TestAPI.validate_container_ids()` 校验。
- `SoulData.triggers` 在基类上（主动/被动通用），`PassiveSoulData` 仅额外加 `passive_effects`；`ItemView` 对魂灵/魂器/地图/数量石自动叠 `ItemNameLabel`。
- 视图层只监听 `GBIS` 信号刷新：`InventoryView` 增量监听 `sig_inv_item_added/removed/updated`，`sig_inv_refresh` 置脏；`TooltipWindow` 监听 `sig_item_focused/focus_lost` 分派各 `*Tooltip.build()`。

## 2. 刷新、添加与拖拽不变量

- **延迟刷新（`RefreshableView`）**：数据变化只 `mark_dirty()`，可见时本帧末合并重建，隐藏时记脏待下次显示重建；无脏标记显示时走 `_on_shown_without_refresh()` 重摆物品防叠原点。仓库翻页走 `change_data_source()`，行列不变（10 页均为 26×24）时复用格子 Control 与信号。`GBIS.opened_containers` 按 `is_visible_in_tree()` 维护。
- **拖拽唯一入口（`MovingItemService`）**：`pick_from_grid/slot`、`begin_detached` 开启，`drop_on_grid/slot`、`sell_dragged`、`drop_to_world`、`cancel` 结束，仅 `finish()` 清状态并发 `drag_ended`。`DragOrigin`（GRID/SLOT/NONE）决定右键取消回退原格或首个空位；`DragPresenter` 专管幽灵与显隐；能否放置/堆叠统一由 `ContainerData.drop_state_at()` 判定。
- **常见坑**：
  - 多格物品跨格焦点丢失延迟到帧末撤销，关窗需手动清焦点防 tooltip 残留。
  - `clear()` 先摘树再 `queue_free()` 防翻页同帧重叠；无 `ItemWindow` 时需手动释放未入树幽灵。
  - Godot 4 `Dictionary` 为引用类型，`duplicate()` 共用 `shader_params`，改前必须先复制；运行期状态只改材质参数与徽章，不重绘 `ItemView`。

## 3. 魂器扩展与容器清单

本项目在 `ItemData.container_kind_tag()`、`ContainerData`（`vessel_kind` / `max_items`）与 `InventoryView` 新增过滤：`is_item_avilable()` 依次校验 `avilable_types` → `max_items`（不计当前拖拽物）→ `vessel_kind` 匹配。

| 容器名 | 位置 | 尺寸 | 限制 | 说明 |
|---|---|---|---|---|
| `vessel_cells` | `CharacterWindow/.../VesselGrid` | 9×3 | `VESSEL` + `COMBAT` | 角色战斗魂器网格 |
| `vessel_<id>` | 魂器窗口运行时注册 | 由魂器定义（如 6×2） | `SOUL` | 平时不在仓库，内容随魂器存档 |
| `inventory_0..9` | `InventoryWindow/InventoryView` | 26×24 | `SOUL/VESSEL/MAP/STONE` | 10 页仓库（扩页改 `PAGE_COUNT`） |
| `shop_0` | `ShopWindow/ShopView` | 20×10 | 商店货物 | `ShopView._ready()` 重载 `goods` |

## 4. 交互键位、商店与未接入保留项

- **键位**：左键拿起/放下/堆叠；右键取消拿起（拖拽中）或使用/打开魂器（非拖拽，`sig_item_activated`）；Shift+左键 `quick_move()`；Shift+右键 `quick_sell()`（需商店与当前仓库页均打开）；中键 `split_item()`。
- **商店**：`ShopService.buy()` / `sell_item()` 走 `ItemData.can_buy/cost/can_sell/sold()`（当前默认放行仅打警告，货币与价格待定义）。
- **未接入保留项（便于同步上游，不删除）**：`EquipmentSlot*`、`DropAreaView`、`ConsumableData` / `EquipmentData` / `StackableData`、`GBIS.add_quick_move_relation()`、`GBIS.save()/load()`、`GBIS.item_material`。
