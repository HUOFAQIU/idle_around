## 一条掉落：物品 + 触发几率。
##
## 怪物在场景根节点的 drops 数组里配置多项，死亡时每项各掷一次骰子。

class_name DropEntry extends Resource

## 掉什么（仓库里能放的 ItemData，比如 SoulData）
@export var item: ItemData
## 掉落几率（0~1）
@export_range(0.0, 1.0, 0.01) var chance: float = 0.2
