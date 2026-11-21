class_name DropEntry extends Resource

## 掉什么（仓库里能放的 ItemData，比如 SoulData）
@export var item: ItemData
## 掉落几率（0~1）
@export_range(0.0, 1.0, 0.01) var chance: float = 0.2
